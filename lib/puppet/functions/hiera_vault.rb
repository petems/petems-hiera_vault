# Handle required libraries
['set','json','vault','debouncer'].each do |lib|
  begin
    require lib
  rescue LoadError
    raise Puppet::DataBinding::LookupError, 
      _("[hiera-vault] Must install #{lib} gem to use hiera-vault backend")
  end
end

# Globally cache these things, we'll re-configure the
# client every time we call, but really only want to have
# one such that we don't create more connections to vault than
# we can handle.
$vault               = Vault::Client.new
$shutdown            = Debouncer.new(10) { $vault.shutdown() }

Puppet::Functions.create_function(:hiera_vault) do

  # Expect these things from Puppet
  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  # This is the main function that Puppet/Hiera Calls
  def lookup_key(key, options, context)
    return context.cached_value("HIERA_VAULT_VALUE_CACHE_#{key}") if context.cache_has_key("HIERA_VAULT_VALUE_CACHE_#{key}")

    context.explain {"#{Time.now.to_f} Starting"}

    # We need to cache these per cache in the event that we're using environtment
    # caching. We'll re-configure the vault client for each call

    config_check        = context.cached_value('HIERA_VAULT_CACHE_config_check')
    token_expiry        = context.cached_value('HIERA_VAULT_CACHE_token_expiry')
    seal_checked        = context.cached_value('HIERA_VAULT_CACHE_seal_checked')
    confine_keys_regexp = context.cached_value('HIERA_VAULT_CACHE_confine_keys_regexp')
    strip_from_keys     = context.cached_value('HIERA_VAULT_CACHE_strip_from_keys')

    unless config_check
      # We need a uri to check for the key, based on the eyaml function the following
      # check cannot be done in an argument_mismatch
      unless options.include?('uri')
        raise ArgumentError,
        _("[hiera-vault] 'uri' or 'uris' must be declared in hiera.yaml"\
          " when using this lookup_key function")
      end

      # Check Options
      unless ['string','json',nil].include?(options['default_field_parse'])
        raise ArgumentError,
          _("[hiera-vault] invalid value for default_field_parse: "\
            "#{options['default_field_parse']}', should be one of 'string','json'")
      end

      unless ['ignore','only',nil].include?(options['default_field_behavior'])
        raise ArgumentError, 
          _("[hiera-vault] invalid value for default_field_behavior: "\
            "#{options['default_field_behavior']}', should be one of 'ignore','only'")
      end

      unless options['environment_delimeter'].is_a?(String)
        raise ArgumentError,
          _("[hiera-vault] invalid value for environment_delimeter: "\
            "#{options['environment_delimeter']} must be a string")
      end

      # While the vault client _does_ default the address to https://127.0.0.1:8200
      # this address is rarely used, forcing one will ensure explicit configuration
      if ENV['VAULT_ADDR'].nil? and options['address'].nil?
        raise ArgumentError, 
        _("[hiera-vault] no address set in options and no address in VAULT_ADDR")
      end

      # Interacting with vault without a token is _almost_ pointless
      # this value _can_ be interpolated in the hiera.yaml using an agent fact
      if ENV['VAULT_TOKEN'].nil? and options['token'].nil?
        raise ArgumentError,
        _("[hiera-vault] no token set in options and no token in VAULT_TOKEN")
      end

      # Let's pre-compile the regex for key confinement
      if confine_keys_regexp.nil? and !options['confine_to_keys'].nil?
        unless options['confine_to_keys'].is_a?(Array)
          raise ArgumentError, 
            _("[hiera-vault] confine_to_keys must be an array")
        end

        begin
          confine_keys_regexp = context.cache(
            'HIERA_VAULT_CACHE_confine_keys_regexp',
            Regexp.union(options['confine_to_keys'].map { |r| Regexp.new(r) })
          )
        rescue StandardError => e
          raise Puppet::DataBinding::LookupError,
            _("[hiera-vault] creating regexp failed with: #{e}")
        end
      end

      # Let's pre-compile the strip_keys regex
      if strip_from_keys.nil? and !options['strip_from_keys'].nil?
        unless options['strip_from_keys'].is_a?(Array)
          raise ArgumentError,
            _("[hiera-vault] strip_from_keys must be an array")
        end

        begin
          strip_from_keys = context.cache(
            'HIERA_VAULT_CACHE_strip_from_keys',
            options['strip_from_keys'].map { |r| Regexp.new(r) }
          )
        rescue StandardError => e
          raise Puppet::DataBinding::LookupError,
            _("[hiera-vault] creating regexp failed with: #{e}")
        end
      end
    end

    # We made it through all the hard config failures, let's not do that again
    context.cache('HIERA_VAULT_CACHE_config_check', true)

    # This allows us to skip this backend completely if the puppet run doesn't need it
    if (ENV['VAULT_TOKEN'] == 'IGNORE-VAULT' or options['token'] == 'IGNORE-VAULT')
      context.explain { "Token set to IGNORE-VAULT - Ignoring" }
      context.not_found
    end

    # We'll use the same vault client, but re-configure it every time?
    # This should reduce the number established connections...
    # and be cache safe
    $vault.configure do |config|
      config.address = options['address']
      if options['token'].start_with?('/') and File.exist?(options['token'])
        # Puppet will cache the file contents, and verify they are fresh
        context.cached_file_data(options['token']) do |content|
          config.token = content
        end
      else
        config.token = options['token']
      end
      config.ssl_pem_file = options['ssl_pem_file'] unless options['ssl_pem_file'].nil?
      config.ssl_verify   = options['ssl_verify']   unless options['ssl_verify'].nil?
      config.ssl_ca_cert  = options['ssl_ca_cert'] if config.respond_to? :ssl_ca_cert
      config.ssl_ca_path  = options['ssl_ca_path'] if config.respond_to? :ssl_ca_path
      config.ssl_ciphers  = options['ssl_ciphers'] if config.respond_to? :ssl_ciphers
    end
    context.explain { "Configured Vault Client #{$vault.address}"}

    # Check token and seal state
    begin
      # Set the token expiry so we don't have to check every time
      if token_expiry.nil?
        token         = $vault.auth_token.lookup_self
        token_expiry = context.cache(
          'HIERA_VAULT_CACHE_token_expiry',
          Time.now + token.data[:ttl]
        )

        context.explain { "Token TTL: #{token.data[:ttl]} Renewable: #{token.data[:renewable]}"}
        context.explain { "Token Renew By: #{token_expiry - 10}"}
      end
      # If the current time is greater than the expiry time minus a buffer
      # and the token is renewable, do the thing
      if Time.now >= token_expiry - 10 and token.data[:renewable]
        $vault.auth_token.renew_self
        context.explain { "Renewed Vault Token"}
      end
      # We can't talk to a sealed vault...Check every time
      unless seal_checked
        if $vault.sys.seal_status.sealed?
          raise Puppet::DataBinding::LookupError,
            _("[hiera-vault] Vault #{vault.address} is sealed")
        end
        seal_checked = context.cache('HIERA_VAULT_CACHE_seal_checked', true)
      end
    rescue StandardError => e
      $shutdown.call
      $vault = nil
      raise Puppet::DataBinding::LookupError,
        _("[hiera-vault] Skipping backend. Error: #{e}")
    end

    unless confine_keys_regexp.nil?
      unless key[confine_keys_regexp] == key
        context.explain { "Skipping '#{key}' no match in confine_to_keys" }
        context.not_found
      end
    end

    # Before looking up the value in vault, strip this regex from the key
    # This allows for a prefx like vault_ to be used in puppet, and friendlier
    # names to be used in vault pathing, could be misleading though.
    vault_key = key.dup

    if strip_from_keys.is_a?(Array)
      strip_from_keys.each do |prefix|
        vault_key = key.gsub(prefix, '')
      end
    end

    # Allow hiera to look beyond vault if the value is not found
    continue_if_not_found = options['continue_if_not_found'] or false

    # Lookup this key in vault
    result = vault_get(vault_key, options, context)

    # Keep looking if we didn't find it here, or return the value found
    # TODO: Decide how to handle continuing or returning nil if not found...
    if result.nil? and continue_if_not_found
      context.explain { "#{Time.now.to_f} Finished Checking"}
      context.not_found
    else
      context.cache(key, result)
    end
  end

  def vault_get(vault_key, options, context)
    # Assume and default to kv v1 backend
    # Use the first part of the uri as the mount name
    mount      = options['uri'].split('/').first
    mount_opts = { 'version'=> 1, 'type' => 'kv', }

    # Check mount configuration for this uri
    if options['mounts'].is_a?(Hash)
      options['mounts'].each do |mount_name, opts|
        if options['uri'].start_with?(mount_name)
          mount      = mount_name
          mount_opts = opts
          break
        end
      end
    end

    # Here we decide which secret mount to use
    case mount_opts['type']
    when 'kv'
      mount_opts['version'] = 1 unless mount_opts.has_key?('version')
      context.explain {"kv version: #{mount_opts['version']}" }
      return kv_lookup(vault_key, options['uri'], mount, mount_opts['version'], options, context)
    else
      context.explain { "Backend #{mount_opts['type']} is not yet supported" }
      context.not_found
    end
  end

  # Read from a KV backend with v1 and v2 support
  def kv_lookup(vault_key, uri, mount, mount_version, options, context)
    v2 = mount_version == 2

    # /data/ part is injected for v2
    kv_uri = v2 ?
      File.join(mount, 'data', uri.delete_prefix(mount), vault_key) :
      File.join(uri, vault_key)
    context.explain { "Final uri: #{kv_uri}"}
    keys_uri = v2 ?
      File.join('v1', mount, 'metadata', uri.delete_prefix(mount)) :
      File.join('v1',uri)

    # Get the keys available at this endpoint
    # and cache the results to reduce the number of calls
    # we have to make to vault.
    # The trade of here is that if values are added or removed
    # during the compile process, we won't know.
    available_keys = context.cached_value('HIERA_VAULT_CACHE_available_keys')

    # If there is no cached value, let's go get one
    if available_keys.nil?
      context.explain { "#{Time.now.to_f} Getting key list from #{keys_uri}"}
      raw_available_keys = vault_list(keys_uri, context)
      if raw_available_keys.nil?
        # If we got nothing, that's fine, just set an empty array
        # This path won't be checked anymore
        available_keys = []
      else
        available_keys = v2 ?
          raw_available_keys[:data][:keys] :
          raw_available_keys # Not sure this is exactly correct for v1?
      end
      context.cache('HIERA_VAULT_CACHE_available_keys', available_keys)
    end

    context.explain { "#{Time.now.to_f} Got key list #{available_keys}"}

    raw_secret = nil

    # We are pretty sure that there will be a value at the end of this path
    # So let's get it!
    if available_keys.is_a?(Array) and available_keys.include? (vault_key)
      raw_secret = vault_read(kv_uri, context)
    end

    return nil if raw_secret.nil?
    secret = v2 ? raw_secret.data[:data] : raw_secret.data
    return parse_secret(secret, options, context)
  end

  # Pretty generic list from vault (needs our vault gem 0.12.3+)
  def vault_list(path, context)
    begin
      context.explain { "Calling vault #{Time.now.to_f}"}
      resp = $vault.request(:list,path)
      context.explain { "Resp from vault #{Time.now.to_f}"}
    rescue Vault::HTTPConnectionError => e
      raise Puppet::DataBinding::LookupError,
        _("[hiera-vault] Vault connect problems: #{e}")
    rescue Vault::HTTPError => e
      # Don't fail hard as the token might not have access to the path, but may later on
      context.explain { "Could not read secret #{path}: #{e.errors.join("\n").rstrip}" }
      return nil
    end
    $shutdown.call # We might be done with vault
    return resp
  end

  # Pretty generic read from vault
  def vault_read(path, context)
    begin
      context.explain { "Calling vault #{Time.now.to_f}"}
      resp = $vault.logical.read(path)
      context.explain { "Resp from vault #{Time.now.to_f}"}
    rescue Vault::HTTPConnectionError => e
      raise Puppet::DataBinding::LookupError,
        _("[hiera-vault] Vault connect problems: #{e}")
    rescue Vault::HTTPError => e
      # Don't fail hard as the token might not have access to the path, but may later on
      context.explain { "Could not read secret #{path}: #{e.errors.join("\n").rstrip}" }
    end
    $shutdown.call # We might be done with vault
    return resp
  end

  # Turn the returned secret into something that Puppet can use
  def parse_secret(secret, options, context)
    # Parse the secret into a hash to return in the event that
    # we don't have a default_field OR
    # the returned value is missing the default_field
    answer = secret.inject({}) { |h, (k, v)| h[k.to_s] = stringify_keys v; h }

    # If we have an environment delimiter, let's adjust the hash
    # such that we only have fields with _this_ environment OR
    # without _any_ environment
    unless options['environment_delimeter'].nil?
      # Collect the base_fields
      delim = options['environment_delimeter']

      context.explain { "Getting Environment values based on #{delim}"}
      env   = context.environment_name()

      # Grab a unique set of fields from the answer
      # Using a set means we don't have to do the unique
      # field calculations, it's built in to the object
      base_fields = answer.keys.inject(Set[]) do |s, f|
        s.add(f.split(delim)[-1])
      end
      context.explain{ "Base fields: #{base_fields.to_a}"}

      # Pull values for fields into the answer
      answer = base_fields.inject({}) do |a, field|
        env_field = "#{env}#{delim}#{field}"
        a[field] = answer[field]
        if answer.has_key?(env_field)
          context.explain { "Found environment #{env} value for #{field}" }
          a[field] = answer[env_field]
        end
        a
      end
    end

    # If we have configured a `default_field`
    # return **that field** based on the following conditions
    # - the secret has the `default_field`
    # - the secret contains _only_ the default_field
    # - the secrets contains other fields AND `default_field_behavior` is `ignore`
    # When ignore_other_fields is false (ie `default_field_behavior: 'only'`),
    # _only_ single field secrets return the `default_field`, all others will
    # be returned as a Hash no matter what fields they contain.
    unless options['default_field'].nil?
      default_field       = options['default_field']
      ignore_other_fields = ['ignore', nil].include?(options['default_field_behavior'])
      has_default         = answer.has_key?(default_field)
      single_key_secret   = answer.length == 1

      # If we have the default and we're ignoring other fields, use that
      # If we have the default and NOT ignoring other fields
      # use the default if it's the only key
      if has_default and (ignore_other_fields or single_key_secret)

        answer = answer[default_field]

        if options['default_field_parse'] == 'json'
          begin
            answer = JSON.parse(answer, :quirks_mode => true)
          rescue JSON::ParserError => e
            context.explain { "Could not parse string as json: #{e}" }
          end
        end
      end
    end

    return answer
  end

  # Stringify key:values so user sees expected results and nested objects
  def stringify_keys(value)
    case value
    when Hash
      result = {}
      value.each_pair { |k, v| result[k.to_s] = stringify_keys v }
      result
    when Array
      value.map { |v| stringify_keys v }
    else
      value
    end
  end
end

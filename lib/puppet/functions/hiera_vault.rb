Puppet::Functions.create_function(:hiera_vault) do

  begin
    require 'json'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-vault] Must install json gem to use hiera-vault backend"
  end
  begin
    require 'vault'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-vault] Must install vault gem to use hiera-vault backend"
  end
  begin
    require 'debouncer'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-vault] Must install debouncer gem to use hiera-vault backend"
  end


  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  $vault    = Vault::Client.new
  $shutdown = Debouncer.new(10) { $vault.shutdown() }

  def lookup_key(key, options, context)

    if confine_keys = options['confine_to_keys']
      raise ArgumentError, '[hiera-vault] confine_to_keys must be an array' unless confine_keys.is_a?(Array)

      begin
        confine_keys = confine_keys.map { |r| Regexp.new(r) }
      rescue StandardError => e
        raise Puppet::DataBinding::LookupError, "[hiera-vault] creating regexp failed with: #{e}"
      end

      regex_key_match = Regexp.union(confine_keys)

      unless key[regex_key_match] == key
        context.explain { "[hiera-vault] Skipping hiera_vault backend because key '#{key}' does not match confine_to_keys" }
        context.not_found
      end
    end

    if strip_from_keys = options['strip_from_keys']
      raise ArgumentError, '[hiera-vault] strip_from_keys must be an array' unless strip_from_keys.is_a?(Array)

      strip_from_keys.each do |prefix|
        key = key.gsub(Regexp.new(prefix), '')
      end
    end

    if (ENV['VAULT_TOKEN'] == 'IGNORE-VAULT' || options['token'] == 'IGNORE-VAULT')
      context.explain { "[hiera-vault] token set to IGNORE-VAULT - Quitting early" }
      return context.not_found
    end

    if ENV['VAULT_TOKEN'].nil? && options['token'].nil?
      raise ArgumentError, '[hiera-vault] no token set in options and no token in VAULT_TOKEN'
    end

    result = vault_get(key, options, context)

    # Allow hiera to look beyond vault if the value is not found
    continue_if_not_found = options['continue_if_not_found'] || false

    if result.nil? and continue_if_not_found
      context.not_found
    else
      return result
    end
  end


  def vault_get(key, options, context)

    if ! ['string','json',nil].include?(options['default_field_parse'])
      raise ArgumentError, "[hiera-vault] invalid value for default_field_parse: '#{options['default_field_parse']}', should be one of 'string','json'"
    end

    if ! ['ignore','only',nil].include?(options['default_field_behavior'])
      raise ArgumentError, "[hiera-vault] invalid value for default_field_behavior: '#{options['default_field_behavior']}', should be one of 'ignore','only'"
    end

    begin
      $vault.configure do |config|
        config.address = options['address'] unless options['address'].nil?
        if options['token'].start_with?('/') and File.exist?(options['token'])
          config.token = File.read(options['token']).strip.chomp
        else
          config.token = options['token']
        end
        config.ssl_pem_file = options['ssl_pem_file'] unless options['ssl_pem_file'].nil?
        config.ssl_verify = options['ssl_verify'] unless options['ssl_verify'].nil?
        config.ssl_ca_cert = options['ssl_ca_cert'] if config.respond_to? :ssl_ca_cert
        config.ssl_ca_path = options['ssl_ca_path'] if config.respond_to? :ssl_ca_path
        config.ssl_ciphers = options['ssl_ciphers'] if config.respond_to? :ssl_ciphers
      end

      if $vault.sys.seal_status.sealed?
        raise Puppet::DataBinding::LookupError, "[hiera-vault] vault is sealed"
      end

      context.explain { "[hiera-vault] Client configured to connect to #{$vault.address}" }
    rescue StandardError => e
      $shutdown.call
      $vault = nil
      raise Puppet::DataBinding::LookupError, "[hiera-vault] Skipping backend. Configuration error: #{e}"
    end

    answer = nil

    if options['mounts']['generic']
      raise ArgumentError, "[hiera-vault] generic is no longer valid - change to kv"
    else
      kv_mounts = options['mounts'].dup
    end

    # Only kv mounts supported so far
    kv_mounts.each_pair do |mount, paths|
      paths.each do |path|

        # Default to kv v1
        secretpath = context.interpolate(File.join(mount, path, key))

        context.explain { "[hiera-vault] Looking in path #{secretpath}" }

        begin
          secret = $vault.logical.read(secretpath)
        rescue Vault::HTTPConnectionError
          context.explain { "[hiera-vault] Could not connect to read secret: #{secretpath}" }
        rescue Vault::HTTPError => e
          context.explain { "[hiera-vault] Could not read secret #{secretpath}: #{e.errors.join("\n").rstrip}" }
        end

        next if secret.nil?

        context.explain { "[hiera-vault] Read secret: #{key}" }
        if (options['default_field'] and ( ['ignore', nil].include?(options['default_field_behavior']) ||
           (secret.data.has_key?(options['default_field'].to_sym) && secret.data.length == 1) ) )

          return nil if ! secret.data.has_key?(options['default_field'].to_sym)

          new_answer = secret.data[options['default_field'].to_sym]

          if options['default_field_parse'] == 'json'
            begin
              new_answer = JSON.parse(new_answer, :quirks_mode => true)
            rescue JSON::ParserError => e
              context.explain { "[hiera-vault] Could not parse string as json: #{e}" }
            end
          end

        else
          # Turn secret's hash keys into strings allow for nested arrays and hashes
          # this enables support for create resources etc
          new_answer = secret.data.inject({}) { |h, (k, v)| h[k.to_s] = stringify_keys v; h }
        end

        unless new_answer.nil?
          answer = new_answer
          break
        end
      end

      break unless answer.nil?
    end

    answer = context.not_found if answer.nil?
    $shutdown.call
    return answer
  end

  # Stringify key:values so user sees expected results and nested objects
  def stringify_keys(value)
    case value
    when String
      value
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

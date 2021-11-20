# Cache will keep track of all the results gotten from the Vault server.
# To avoid leaking secrets both the key looked for and the options are used as
# the key for the cache so that using the same key with different options will
# not risk leaking a secret.
# To keep things fast and not have the pruning method take longer as the number
# of entries grow we create a Hash for each value of cache_for and keep entries
# in this hash ordered from the oldest one to the most recent. When looking for
# entries to evict we iterate over each Hash in order and stop when we find the
# first entry that we must keep: because all the subsequent entries will be
# younger there is no need to continue as we will need to keep them all. Doing
# this make time spent pruning the cache proportional to number of entries that
# actually need to be evicted, and not to the total number of entries in the
# cache.
# We avoid keeping secrets in memory for longer than necessary by calling prune
# before each operation of the cache, we always evict secret from memory as soon
# as we can.
# Note that we don't need synchronization primitives in Cache because we always
# hold hiera_vault_mutex when accessing the cache.
class Cache
  CacheKey = Struct.new(:key, :options)
  CacheValue = Struct.new(:value, :until)

  def initialize
    @caches = Hash.new {|hash, key| hash[key] = {} }
  end

  def set(key, value, options)
    prune

    cache_for = options['cache_for']

    # Early exit if the cache is deactivated
    return nil if cache_for.nil?

    k = CacheKey.new(key, options)
    cache = @caches[cache_for]

    # We first delete the key from the cache so it will always be ordered from
    # oldest entries to most recent
    cache.delete(k)

    cache[k] = CacheValue.new(value, Time.now + cache_for)
  end

  def get(key, options)
    prune

    cache_for = options['cache_for']

    # Early exit if the cache is deactivated
    return nil if cache_for.nil?

    k = CacheKey.new(key, options)
    cache = @caches[cache_for]

    # We don't need to check whether the value has expired because it would
    # have been removed during prune
    return cache[k]
  end

  # Removes all the expired entries from the cache
  def prune
    @caches.each_value do |cache|
      cache.each do |key, value|
        # Because the entries in each cache are ordered we can stop as soon as
        # we find one that we need to keep, all the following ones will be
        # younger and need to be kept too
        if value.until >= Time.now
          break
        end

        cache.delete(key)
      end
    end
  end
end

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
  begin
    require 'thread'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-vault] Must install thread gem to use hiera-vault backend"
  end


  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  $cache = Cache.new

  $hiera_vault_mutex = Mutex.new
  $hiera_vault_client = Vault::Client.new
  $hiera_vault_shutdown = Debouncer.new(10) {
    $hiera_vault_mutex.synchronize do
      $hiera_vault_client.shutdown()
      $hiera_vault_client = nil
    end
  }

  def vault_token(options)
    token = nil

    token = ENV['VAULT_TOKEN'] unless ENV['VAULT_TOKEN'].nil?
    token ||= options['token'] unless options['token'].nil?

    if token.to_s.start_with?('/') and File.exist?(token)
      token = File.read(token).strip.chomp
    end

    token
  end

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

    if vault_token(options) == 'IGNORE-VAULT'
      context.explain { "[hiera-vault] token set to IGNORE-VAULT - Quitting early" }
      return context.not_found
    end

    if vault_token(options).nil?
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

    if (! options['cache_for'].nil?) &&  (! options['cache_for'].is_a? Numeric)
      raise ArgumentError, "[hiera-vault] invalid value for cache_for: '#{options['cache_for']}', should be a number or nil"
    end

    $hiera_vault_mutex.synchronize do
      cached_value = $cache.get(key, options)
      return cached_value.value if ! cached_value.nil?

      # If our Vault client has got cleaned up by a previous shutdown call, reinstate it
      if $hiera_vault_client.nil?
        $hiera_vault_client = Vault::Client.new
      end


      begin
        $hiera_vault_client.configure do |config|
          config.address = options['address'] unless options['address'].nil?
          config.token = vault_token(options)
          config.ssl_pem_file = options['ssl_pem_file'] unless options['ssl_pem_file'].nil?
          config.ssl_verify = options['ssl_verify'] unless options['ssl_verify'].nil?
          config.ssl_ca_cert = options['ssl_ca_cert'] if config.respond_to? :ssl_ca_cert
          config.ssl_ca_path = options['ssl_ca_path'] if config.respond_to? :ssl_ca_path
          config.ssl_ciphers = options['ssl_ciphers'] if config.respond_to? :ssl_ciphers
        end

        if $hiera_vault_client.sys.seal_status.sealed?
          raise Puppet::DataBinding::LookupError, "[hiera-vault] vault is sealed"
        end

        context.explain { "[hiera-vault] Client configured to connect to #{$hiera_vault_client.address}" }
      rescue StandardError => e
        $hiera_vault_shutdown.call
        $hiera_vault_client = nil
        raise Puppet::DataBinding::LookupError, "[hiera-vault] Skipping backend. Configuration error: #{e}"
      end

      answer = nil
      strict_mode = (options.key?('strict_mode') and options['strict_mode'])

      if options['mounts']['generic']
        raise ArgumentError, "[hiera-vault] generic is no longer valid - change to kv"
      else
        kv_mounts = options['mounts'].dup
      end

      # Only kv mounts supported so far
      kv_mounts.each_pair do |mount, paths|
        interpolate(context, paths).each do |path|
          secretpath = context.interpolate(File.join(mount, path))

          context.explain { "[hiera-vault] Looking in path #{secretpath} for #{key}" }

          secret = nil

          paths = []

          if options.fetch("v2_guess_mount", true)
            paths << [:v2, File.join(mount, path, 'data', key).chomp('/')]
            paths << [:v2, File.join(mount, 'data', path, key).chomp('/')]
          else
            paths << [:v2, File.join(mount, path, key).chomp('/')]
            paths << [:v2, File.join(mount, key).chomp('/')] if key.start_with?(path)
          end

          paths << [:v1, File.join(mount, path, key)] if options.fetch("v1_lookup", true)

          paths.each do |version_path|
            begin
              version, path = version_path[0], version_path[1]
              context.explain { "[hiera-vault] Checking path: #{path}" }
              response = $hiera_vault_client.logical.read(path)
              next if response.nil?
              secret = version == :v1 ? response.data : response.data[:data]
            rescue Vault::HTTPConnectionError
              msg = "[hiera-vault] Could not connect to read secret: #{secretpath}"
              context.explain { msg }
              raise Puppet::DataBinding::LookupError, msg
            rescue Vault::HTTPError => e
              msg = "[hiera-vault] Could not read secret #{secretpath}: #{e.errors.join("\n").rstrip}"
              context.explain { msg }
              raise Puppet::DataBinding::LookupError, "#{msg} - (strict_mode is true so raising as error)" if strict_mode
            end
          end

          next if secret.nil?

          context.explain { "[hiera-vault] Read secret: #{key}" }
          if (options['default_field'] and ( ['ignore', nil].include?(options['default_field_behavior']) ||
          (secret.has_key?(options['default_field'].to_sym) && secret.length == 1) ) )

          if ! secret.has_key?(options['default_field'].to_sym)
            $cache.set(key, nil, options)
            return nil
          end

          new_answer = secret[options['default_field'].to_sym]

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
            new_answer = secret.inject({}) { |h, (k, v)| h[k.to_s] = stringify_keys v; h }
          end

          unless new_answer.nil?
            answer = new_answer
            break
          end
        end

        break unless answer.nil?
      end

      raise Puppet::DataBinding::LookupError, "[hiera-vault] Could not find secret #{key}" if answer.nil? and strict_mode

      answer = context.not_found if answer.nil?
      $hiera_vault_shutdown.call

      $cache.set(key, answer, options)
      return answer
    end
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

  def interpolate(context, paths)
    allowed_paths = []
    paths.each do |path|
      path = context.interpolate(path)
      # TODO: Unify usage of '/' - File.join seems to be a mistake, since it won't work on Windows
      # secret/puppet/scope1,scope2 => [[secret], [puppet], [scope1, scope2]]
      segments = path.split('/').map { |segment| segment.split(',') }
      allowed_paths += build_paths(segments) unless segments.empty?
    end
    allowed_paths
  end

  # [[secret], [puppet], [scope1, scope2]] => ['secret/puppet/scope1', 'secret/puppet/scope2']
  def build_paths(segments)
    paths = [[]]
    segments.each do |segment|
      p = paths.dup
      paths.clear
      segment.each do |option|
        p.each do |path|
          paths << path + [option]
        end
      end
    end
    paths.map { |p| File.join(*p) }
  end
end

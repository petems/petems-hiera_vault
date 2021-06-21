def authenticate(options, client, context)

  auth_types = {
    'aws_iam' => method(:aws_iam_auth)
  }

  auth_types[options['type']].(options['config'], client)

end


def aws_iam_auth(config, client)

  # require set in method to avoid necessary installation of every gem for every auth method, even if not used
  # Possibly inefficient if we're constantly calling this function
  # The alternative is to add the require to hiera_vault.rb
  begin
    require 'aws-sdk-core'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-vault] Must install aws-sdk-core gem to use AWS IAM authentication"
  end

  role = config['role']

  client.auth.aws_iam(role, Aws::InstanceProfileCredentials.new)

end


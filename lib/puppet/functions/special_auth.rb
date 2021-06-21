def authenticate(options, client, context)

  auth_types = {
    'aws_iam' => method(:aws_iam_auth)
  }

  auth_types[options['type']].(options['config'], client, context)

end


def aws_iam_auth(config, client, context)

  begin
    require 'aws-sdk-core'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "[hiera-vault] Must install aws-sdk-core gem to use AWS IAM authentication"
  end

  context.explain { "[hiera-vault] Starting aws_iam authentication with config: #{config}" }

  role = config['role']

  client.auth.aws_iam(role, Aws::InstanceProfileCredentials.new)

end


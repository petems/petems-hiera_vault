require 'spec_helper'
require 'support/vault_server'
require 'puppet/functions/hiera_vault'

VAULT_PATH ='puppetv2_interpolation'

describe FakeFunction do
  let :function do
    described_class.new
  end

  let :context do
    ctx = instance_double('Puppet::LookupContext')
    allow(ctx).to receive(:cache_has_key).and_return(false)
    if ENV['DEBUG']
      allow(ctx).to receive(:explain) { |&block| puts(block.call) }
    else
      allow(ctx).to receive(:explain).and_return(:nil)
    end
    allow(ctx).to receive(:not_found)
    allow(ctx).to receive(:cache).with(String, anything) do |_, val|
      val
    end
    allow(ctx).to receive(:interpolate).with(anything) do |val|
      val
    end
    ctx
  end


  let :vault_options do
    {
      'address' => RSpec::VaultServer.address,
      'token' => RSpec::VaultServer.token,
      'v2_guess_mount' => false,
      'v1_lookup' => false,
      'mounts' => {
        VAULT_PATH + "/data" => [
          'common',
          'rproxy,api'
        ]
      }
    }
  end

  def vault_test_client
    Vault::Client.new(
      address: RSpec::VaultServer.address,
      token: RSpec::VaultServer.token
    )
  end

  describe '#lookup_key' do
    context 'when paths contain options' do
      context 'when vault is unsealed' do
        before(:context) do
          vault_test_client.sys.mount(VAULT_PATH, 'kv', 'puppet secrets v2', { "options" => {"version": "2" }})
          vault_test_client.kv(VAULT_PATH).write("common/test_key", { value: 'default'} )
          vault_test_client.kv(VAULT_PATH).write("rproxy/ssl", { value: 'ssl'} )
          vault_test_client.kv(VAULT_PATH).write("api/oauth", { value: 'oauth'} )
          vault_test_client.kv(VAULT_PATH).write("api", { value: 'api_specific'}  )
        end

        context 'reading secrets' do
          it 'returns key from first option' do
            expect(function.lookup_key('ssl', vault_options, context))
              .to include('value' => 'ssl')
          end

          it 'returns key from second option' do
            expect(function.lookup_key('oauth', vault_options, context))
              .to include('value' => 'oauth')
          end

          it 'returns key from second option without leaf node' do
            expect(function.lookup_key('api', vault_options, context))
              .to include('value' => 'api_specific')
          end

          it 'returns key from second option with full path to node' do
            expect(function.lookup_key('api/oauth', vault_options, context))
              .to include('value' => 'oauth')
          end
        end
      end
    end
  end
end

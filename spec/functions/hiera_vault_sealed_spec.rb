require 'spec_helper'
require 'support/vault_server'
require 'puppet/functions/hiera_vault'

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
      'mounts' => {
        'puppet' => [
          'common'
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
    context 'accessing vault' do

      context 'when vault is sealed' do
        before(:context) do
          vault_test_client.sys.seal
        end
        it 'should raise error for Vault being sealed' do
          expect { function.lookup_key('test_key', vault_options, context) }
            .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] Skipping backend. Configuration error: [hiera-vault] vault is sealed')
        end
        after(:context) do
          vault_test_client.sys.unseal(RSpec::VaultServer.unseal_token)
        end
      end

    end
  end
end

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
        'puppetcache' => [
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


    context 'when vault is unsealed' do
      before(:context) do
        vault_test_client.sys.mount('puppetcache', 'kv', 'puppet secrets v1', { "options" => {"version": "1" }})
      end

      it 'should error when cache_for is not nil or a number' do
        expect { function.lookup_key('test_key', vault_options.merge('cache_for' => 'invalid'), context) }
          .to raise_error(ArgumentError, '[hiera-vault] invalid value for cache_for: \'invalid\', should be a number or nil')
      end

      it 'should not cache the response when cache_for is not set' do
        vault_test_client.logical.write('puppetcache/common/test_key', value: 'default')

        expect(function.lookup_key('test_key', vault_options, context))
          .to eq('value' => 'default')

        vault_test_client.logical.write('puppetcache/common/test_key', value: 'overwritten')

        expect(function.lookup_key('test_key', vault_options, context))
          .to eq('value' => 'overwritten')
      end

      it 'should cache the response for cache_for seconds when cache_for is set' do
        vault_test_client.logical.write('puppetcache/common/test_key', value: 'default')

        expect(function.lookup_key('test_key', vault_options.merge('cache_for' => 1), context))
          .to eq('value' => 'default')

        vault_test_client.logical.write('puppetcache/common/test_key', value: 'overwritten')

        expect(function.lookup_key('test_key', vault_options.merge('cache_for' => 1), context))
          .to eq('value' => 'default')

        sleep(2)

        expect(function.lookup_key('test_key', vault_options.merge('cache_for' => 1), context))
          .to eq('value' => 'overwritten')
      end

      it 'should cache even if there is no value in Vault' do
        expect(function.lookup_key('missed', vault_options.merge('cache_for' => 1), context))
          .to eq(nil)

        vault_test_client.logical.write('puppetcache/common/missed', value: 'overwritten')

        expect(function.lookup_key('missed', vault_options.merge('cache_for' => 1), context))
          .to eq(nil)
      end

      it 'should not cache the response when options changes' do
        vault_test_client.logical.write('puppetcache/common/options_change', value: 'default')

        expect(function.lookup_key('options_change', vault_options.merge('cache_for' => 1), context))
          .to eq('value' => 'default')

        vault_test_client.logical.write('puppetcache/common/options_change', value: 'overwritten')

        expect(function.lookup_key('options_change', vault_options.merge('cache_for' => 2), context))
          .to eq('value' => 'overwritten')
      end
    end
  end
end

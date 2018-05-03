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
    #allow(ctx).to receive(:explain).and_return(:nil)
    allow(ctx).to receive(:explain) { |&block| puts(block.call()) }
    allow(ctx).to receive(:not_found).and_throw(:no_such_key)
    allow(ctx).to receive(:cache).with(String, anything) do |_, val|
      val
    end
    allow(ctx).to receive(:interpolate).with(anything) do |val|
      val + '/'
    end
    ctx
  end

  let :vault_options do
    {
        'address' => RSpec::VaultServer.address,
        'token' => RSpec::VaultServer.token,
        'mounts' => {
            'generic' => [
                'puppet'
            ]
        }
    }
  end

  def vault_test_client
    Vault::Client.new(
        address: RSpec::VaultServer.address,
        token:   RSpec::VaultServer.token,
        )
  end

  describe "#lookup_key" do

    context 'supplied with invalid parameters' do
      it 'should die when default_field_parse is not in [ string, json ]' do
        expect { function.lookup_key( 'test_key', {'default_field_parse' => 'invalid'}, context ) }
            .to raise_error(ArgumentError, '[hiera-vault] invalid value for default_field_parse: \'invalid\', should be one of \'string\',\'json\'')
      end
      it 'should die when default_field_behavior is not in [ ignore, only ]' do
        expect { function.lookup_key( 'test_key', {'default_field_behavior' => 'invalid'}, context ) }
            .to raise_error(ArgumentError, '[hiera-vault] invalid value for default_field_behavior: \'invalid\', should be one of \'ignore\',\'only\'')
      end
      it 'should die when confine_to_keys is no array' do
        expect { function.lookup_key( 'test_key', {'confine_to_keys' => '^vault.*$'}, context ) }
            .to raise_error(ArgumentError, '[hiera-vault] confine_to_keys must be an array')
      end
      it 'should die when passing invalid regexes' do
        expect { function.lookup_key( 'test_key', {'confine_to_keys' => [ '[' ]}, context ) }
            .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] creating regexp failed with: premature end of char-class: /[/')
      end
      it 'should return "not found"' do
        expect { function.lookup_key( 'test_key', {'confine_to_keys' => [ '^vault.*$' ]}, context ) }
            .to throw_symbol(:no_such_key)
      end

      context 'accessing vault' do
        let :options do
          {
              'address' => RSpec::VaultServer.address,
              'mounts' => {
                  'generic' => [
                      'puppet'
                  ]
              }
          }
        end
        it 'without a token should return nil' do
          expect { function.lookup_key( 'test_key', {'confine_to_keys' => [ '^vault.*$' ]}, context ) }
            .to throw_symbol(:no_such_key)
        end
      end
    end

    context 'when accessing a sealed vault' do
      before(:context) do
        vault_test_client.sys.seal
      end
      it 'should crash' do
        expect { function.lookup_key( 'test_key', vault_options, context ) }
            .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] Skipping backend. Configuration error: [hiera-vault] vault is sealed')
      end
      after(:context) do
        vault_test_client.sys.unseal(RSpec::VaultServer::unseal_token)
      end
    end

    context 'when accessing vault' do
      before(:context) do
        vault_test_client.sys.mount('puppet', 'kv', 'puppet secrets')
        vault_test_client.logical.write('puppet/test_key', value: 'default')
        vault_test_client.logical.write('puppet/array_key', value: '["a", "b", "c"]')
        vault_test_client.logical.write('puppet/hash_key', value: '{"a": 1, "b": 2, "c": 3}')
        vault_test_client.logical.write('puppet/multiple_values_key', a: 1, b: 2, c:3)
        vault_test_client.logical.write('puppet/values_key', value: 123, a: 1, b: 2, c:3)
        vault_test_client.logical.write('puppet/broken_json_key', value: '[,')
      end

      it 'should accept the local dev vault' do
        expect( function.lookup_key( 'test_key', vault_options, context ) )
            .to include('value' => 'default')
      end

      it 'should return error on non-existant key' do
        expect { function.lookup_key( 'doenst_exist', vault_options, context ) }
            .to throw_symbol(:no_such_key)
      end

      it 'should return the default_field value if present' do
        expect( function.lookup_key('test_key', { 'default_field' => 'value' }.merge(vault_options), context) )
            .to eq('default')
      end

      it 'should return a hash lacking a default field' do
        expect(function.lookup_key('multiple_values_key', vault_options, context))
            .to include( 'a' => 1, 'b' => 2, 'c' => 3 )
      end

      it 'should return an array parsed from json' do
        expect( function.lookup_key('array_key', {
            'default_field' => 'value',
            'default_field_parse' => 'json'
        }.merge(vault_options), context) )
            .to contain_exactly('a', 'b', 'c')
      end

      it 'should return a hash parsed from json' do
        expect( function.lookup_key('hash_key', {
            'default_field' => 'value',
            'default_field_parse' => 'json'
        }.merge(vault_options), context) )
            .to include('a' => 1, 'b' => 2, 'c' => 3)
      end

      it 'should return the string value on broken json content' do
        expect( function.lookup_key('broken_json_key', {
            'default_field' => 'value',
            'default_field_parse' => 'json'
        }.merge(vault_options), context) )
            .to eq('[,')
      end

      it 'should return *only* the default_field value if present' do
        expect( function.lookup_key('test_key', {
            'default_field' => 'value',
            'default_field_behavior' => 'only',
        }.merge(vault_options), context) )
            .to eq('default')

        expect( function.lookup_key('values_key', {
            'default_field' => 'value',
            'default_field_behavior' => 'only',
        }.merge(vault_options), context) )
            .to include('a' => 1, 'b' => 2, 'c' => 3, 'value' => 123)
        expect( function.lookup_key('values_key', {
            'default_field' => 'value',
        }.merge(vault_options), context) )
            .to eq(123)
      end

      it 'should return nil with value field not existing and default_field_behavior set to ignore' do
        expect( function.lookup_key('multiple_values_key', {
            'default_field' => 'value',
            'default_field_behavior' => 'ignore'
        }.merge(vault_options), context) )
            .to be_nil
      end
    end
  end
end

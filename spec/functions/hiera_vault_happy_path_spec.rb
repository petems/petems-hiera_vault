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
    context 'accessing vault with v1 path' do

      context 'when vault is unsealed' do
        before(:context) do
          vault_test_client.sys.mount('puppet', 'kv', 'puppet secrets v1', { "options" => {"version": "1" }})
          vault_test_client.logical.write('puppet/common/test_key', value: 'default')
          vault_test_client.logical.write('puppet/common/array_key', value: '["a", "b", "c"]')
          vault_test_client.logical.write('puppet/common/hash_key', value: '{"a": 1, "b": 2, "c": 3}')
          vault_test_client.logical.write('puppet/common/multiple_values_key', a: 1, b: 2, c: 3)
          vault_test_client.logical.write('puppet/common/values_key', value: 123, a: 1, b: 2, c: 3)
          vault_test_client.logical.write('puppet/common/broken_json_key', value: '[,')
          vault_test_client.logical.write('puppet/common/confined_vault_key', value: 'find_me')
          vault_test_client.logical.write('puppet/common/stripped_key', value: 'regexed_key')
        end

        context 'configuring vault' do
          let :context do
            ctx = instance_double('Puppet::LookupContext')
            allow(ctx).to receive(:cache_has_key).and_return(false)
            allow(ctx).to receive(:explain) { |&block| puts(block.call) }
            allow(ctx).to receive(:not_found)
            allow(ctx).to receive(:cache).with(String, anything) do |_, val|
              val
            end
            allow(ctx).to receive(:interpolate).with(anything) do |val|
              val
            end
            ctx
          end

          it 'should exit early if ENV VAULT_TOKEN is set to IGNORE-VAULT' do
            ENV['VAULT_TOKEN'] = 'IGNORE-VAULT'
            expect(context).to receive(:not_found)
            expect { function.lookup_key('test_key', vault_options.merge({'token' => nil}), context) }.
              to output(/token set to IGNORE-VAULT - Quitting early/).to_stdout
          end

          it 'should exit early if token is set to IGNORE-VAULT' do
            expect(context).to receive(:not_found)
            expect { function.lookup_key('test_key', vault_options.merge({'token' => 'IGNORE-VAULT'}), context) }.
              to output(/token set to IGNORE-VAULT - Quitting early/).to_stdout
          end

          it 'should exit early if token is set to IGNORE-VAULT in a file' do
            vault_token_tmpfile = Tempfile.open('w')
            vault_token_tmpfile.puts('IGNORE-VAULT')
            vault_token_tmpfile.close
            expect { function.lookup_key('test_key', vault_options.merge({'token' => vault_token_tmpfile.path}), context) }.
              to output(/token set to IGNORE-VAULT - Quitting early/).to_stdout
          end

          it 'should allow the configuring of a vault token from a file' do
            vault_token_tmpfile = Tempfile.open('w')
            vault_token_tmpfile.puts(RSpec::VaultServer.token)
            vault_token_tmpfile.close
            expect { function.lookup_key('test_key', vault_options.merge({'token' => vault_token_tmpfile.path}), context) }.
              to output(/Read secret: test_key/).to_stdout
          end

        end

        context 'reading secrets' do
          it 'should return the full key if no default_field specified' do
            expect(function.lookup_key('test_key', vault_options, context))
              .to include('value' => 'default')
          end

          it 'should return the key if regex matches confine_to_keys' do
            expect(function.lookup_key('confined_vault_key', vault_options.merge('confine_to_keys' => ['^vault.*$']), context))
              .to include('value' => 'find_me')
          end

          it 'should not return the key if regex does not match confine_to_keys' do
            expect(context).to receive(:not_found)
            expect(function.lookup_key('puppet/data/test_key', vault_options.merge('confine_to_keys' => ['^vault.*$']), context))
              .to be_nil
          end

          it 'should return nil on non-existant key' do
            expect(context).to receive(:not_found)
            expect(function.lookup_key('doesnt_exist', vault_options, context)).to be_nil
          end

          it 'should return the default_field value if present' do
            expect(function.lookup_key('test_key', { 'default_field' => 'value' }.merge(vault_options), context))
              .to eq('default')
          end

          it 'should return a hash lacking a default field' do
            expect(function.lookup_key('multiple_values_key', vault_options, context))
              .to include('a' => 1, 'b' => 2, 'c' => 3)
          end

          it 'should return an array parsed from json' do
            expect(function.lookup_key('array_key', {
              'default_field' => 'value',
              'default_field_parse' => 'json'
            }.merge(vault_options), context))
              .to contain_exactly('a', 'b', 'c')
          end

          it 'should return a hash parsed from json' do
            expect(function.lookup_key('hash_key', {
              'default_field' => 'value',
              'default_field_parse' => 'json'
            }.merge(vault_options), context))
              .to include('a' => 1, 'b' => 2, 'c' => 3)
          end

          it 'should return the string value on broken json content' do
            expect(function.lookup_key('broken_json_key', {
              'default_field' => 'value',
              'default_field_parse' => 'json'
            }.merge(vault_options), context))
              .to eq('[,')
          end

          it 'should return *only* the default_field value if present' do
            expect(function.lookup_key('test_key', {
              'default_field' => 'value',
              'default_field_behavior' => 'only'
            }.merge(vault_options), context))
              .to eq('default')

            expect(function.lookup_key('values_key', {
              'default_field' => 'value',
              'default_field_behavior' => 'only'
            }.merge(vault_options), context))
              .to include('a' => 1, 'b' => 2, 'c' => 3, 'value' => 123)
            expect(function.lookup_key('values_key', {
              'default_field' => 'value'
            }.merge(vault_options), context))
              .to eq(123)
          end

          it 'should return nil with value field not existing and default_field_behavior set to ignore' do
            expect(function.lookup_key('multiple_values_key', {
              'default_field' => 'value',
              'default_field_behavior' => 'ignore'
            }.merge(vault_options), context))
              .to be_nil
          end

          it 'should return nil but continue to look if continue_if_not_found is present' do
            expect(context).to receive(:not_found)
            expect(function.lookup_key('doesnt_exist', vault_options.merge('continue_if_not_found' => true), context))
              .to be_nil
          end

          it 'should gsub the path string if strip_from_keys is present' do
            expect(function.lookup_key('stripped_key12345', vault_options.merge('strip_from_keys' => [/[0-9]*/], 'default_field' => 'value'), context))
              .to eql('regexed_key')
          end

        end
      end
    end
  end
end

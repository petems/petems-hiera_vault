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
      context 'supplied with invalid parameters' do
        it 'should error when default_field_parse is not in [ string, json ]' do
          expect { function.lookup_key('test_key', vault_options.merge('default_field_parse' => 'invalid'), context) }
            .to raise_error(ArgumentError, '[hiera-vault] invalid value for default_field_parse: \'invalid\', should be one of \'string\',\'json\'')
        end

        it 'should error when default_field_behavior is not in [ ignore, only ]' do
          expect { function.lookup_key('test_key', vault_options.merge('default_field_behavior' => 'invalid'), context) }
            .to raise_error(ArgumentError, '[hiera-vault] invalid value for default_field_behavior: \'invalid\', should be one of \'ignore\',\'only\'')
        end

        it 'should error when confine_to_keys is no array' do
          expect { function.lookup_key('test_key', { 'confine_to_keys' => '^vault.*$' }, context) }
            .to raise_error(ArgumentError, '[hiera-vault] confine_to_keys must be an array')
        end

        it 'should error when passing invalid regexes' do
          expect { function.lookup_key('test_key', { 'confine_to_keys' => ['['] }, context) }
            .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] creating regexp failed with: premature end of char-class: /[/')
        end

        it 'should error when passing invalid regexes' do
          expect { function.lookup_key('test_key', { 'confine_to_keys' => ['['] }, context) }
            .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] creating regexp failed with: premature end of char-class: /[/')
        end

        it 'should error when strip_from_keys isnst an array' do
          expect { function.lookup_key('test_key', vault_options.merge('strip_from_keys' => 'Not an array'), context) }
            .to raise_error(ArgumentError, '[hiera-vault] strip_from_keys must be an array')
        end

        it 'should error when no token present and no VAULT_TOKEN env set' do
          expect { function.lookup_key('test_key', vault_options.delete('token'), context) }
            .to raise_error(ArgumentError, '[hiera-vault] no token set in options and no token in VAULT_TOKEN')
        end
      end

      context 'when vault is unsealed' do

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

          it 'should show error when file token is not valid' do
            vault_token_tmpfile = Tempfile.open('w')
            vault_token_tmpfile.puts('not-valid-token')
            vault_token_tmpfile.close
            expect { function.lookup_key('test_key', vault_options.merge({'token' => vault_token_tmpfile.path}), context) }.
              to output(/Could not read secret .+ permission denied/).to_stdout
          end
        end

      end
    end
  end
end

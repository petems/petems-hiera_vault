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
        'puppet_resource' => [
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

        it 'should error when convert_paths_to_resources is no array' do
          expect { function.lookup_key('test_key', { 'convert_paths_to_resources' => '^vault.*$' }, context) }
            .to raise_error(ArgumentError, '[hiera-vault] convert_paths_to_resources must be an array')
        end

        it 'should error when passing invalid regexes to convert_paths_to_resources' do
          expect { function.lookup_key('test_key', { 'convert_paths_to_resources' => ['['] }, context) }
            .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] creating regexp for convert_paths_to_resources failed with: premature end of char-class: /[/')
        end

      end
    end
  end

  describe '#lookup_key with ' do
    context 'accessing vault with v2 path' do

      context 'when vault is unsealed' do
        before(:context) do
          vault_test_client.sys.mount('puppet_resource', 'kv', 'puppet secrets for resources', { "options" => {"version": "2" }})
          vault_test_client.logical.write('puppet_resource/data/common/test/resources/resource_1', { "data" => {:number_property => 10, :array_property => ['a', 'b', 'c'], :hash_property => {a: 1, b: 2, c: 3}, :text_property => 'text1'}} )
          vault_test_client.logical.write('puppet_resource/data/common/test/resources/resource_2', { "data" => {:number_property => 20, :array_property => ['d', 'e', 'f'], :hash_property => {d: 4, e: 5, f: 6}, :text_property => 'text2'}} )
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

          context 'reading resources' do
            it 'should return the resource if regex matches convert_paths_to_resources and path exists' do
              expect(function.lookup_key('test/resources', vault_options.merge('convert_paths_to_resources' => ['.*\/resources']), context))
                .to eql({
                          'resource_1' => {
                            'text_property' => 'text1',
                            'number_property' => 10,
                            'array_property' => ['a', 'b', 'c'],
                            'hash_property' => { 'a' => 1, 'b' => 2, 'c' => 3 },
                          },
                          'resource_2' => {
                            'text_property' => 'text2',
                            'number_property' => 20,
                            'array_property' => ['d', 'e', 'f'],
                            'hash_property' => { 'd' => 4, 'e' => 5, 'f' => 6 },
                          },
                        })
            end

            context "regex matches convert_paths_to_resources but the path doesn\'t path exists" do
              it 'should return nil' do
                expect(function.lookup_key('nonexisting/resources', vault_options.merge('convert_paths_to_resources' => ['.*\/resources']), context))
                  .to be_nil
              end

              it 'should throw error when strict_mode is set to true' do
                expect { function.lookup_key('nonexisting/resources', vault_options.merge('convert_paths_to_resources' => ['.*\/resources'], 'strict_mode' => true), context) }
                  .to raise_error(Puppet::DataBinding::LookupError, '[hiera-vault] Could not find resources for nonexisting/resources - (strict_mode is true so raising as error)')
              end
            end

            it 'should not return the resource if regex does not match convert_paths_to_resources' do
              expect(context).to receive(:not_found)
              expect(function.lookup_key('blahblah', vault_options.merge('convert_paths_to_resources' => ['.*\/resources']), context))
                .to be_nil
            end
          end
        end
      end
    end
  end
end

## hiera_vault : a vault data provider function (backend) for Hiera 5

### Description

This is a back end function for Hiera 5 that allows lookup to be sourced from Hashicorp's Vault.

[Vault](https://vaultproject.io) secures, stores, and tightly controls access to tokens, passwords, certificates, API keys, and other secrets in modern computing. Vault handles leasing, key revocation, key rolling, and auditing. Vault presents a unified API to access multiple backends: HSMs, AWS IAM, SQL databases, raw key/value, and more.

For an old example repo of it in action, check out the [hashicorp/webinar-vault-hiera-puppet](https://github.com/hashicorp/webinar-vault-hiera-puppet) repo and webinar ['How to Use HashiCorp Vault with Hiera 5 for Secret Management with Puppet'](https://www.hashicorp.com/resources/hashicorp-vault-with-puppet-hiera-5-for-secret-management)

### Overview

This hiera backend works a bit differently that others, and the previous version. Here is a conceptual overview of the workflow.

- A secret (hiera lookup key) lives at a path `hiera/common/my_secret`
- A secret is composed of `fields`
  - `hiera_vault` has a `environment_delimeter` setting, we set it to `'--'`
    - for each field found at the specified path
    - use the environment specific field if available
    - else use the contents of the bare field
- `hiera_vault` has `default_field setting`, we set it to `'value'`
- `hiera_vault` has `default_field_behavior` setting, we set it to `'only'`
    - if `value` is the only field at the specified path, return the contents of that field
    - otherwise return a hash of all of the fields

It is probably best to check the [examples](####Examples)

### Compatibility

* This module is only compatible with Hiera 5 (ships with Puppet 4.9+)
* This module supports merging as you would normally expect [NEW]
* Vault KV engine version 1 [Untested with this verision]
* Vault KV engine version 2 (Vault 0.10+) [NEW]

### Requirements

The `vault` gem must be installed and loadable from Puppet

```
# /opt/puppetlabs/puppet/bin/gem install vault
# puppetserver gem install vault
```

On Puppetserver <= 5, you will need to switch Puppetserver to use the new JRuby 9K, as the gem requires Ruby 2+, and Puppetserver uses the 1.9.2 JRuby
On Puppetserver >= 6, this is not needed as the default has been moved to the newer JRuby.

Some example Puppetcode to do so:

```
ini_setting { "Change jruby to 9k for Puppetserver <= 5":
  ensure            => present,
  setting           => 'JRUBY_JAR',
  path              => "/etc/sysconfig/puppetserver",
  key_val_separator => '=',
  section           => '',
  value             => '"/opt/puppetlabs/server/apps/puppetserver/jruby-9k.jar"',
  show_diff         => true,
  notify            => Service['puppetserver']
}

package { 'vault-puppetserver-gem':
  ensure   => 'present',
  name     => 'vault',
  provider => 'puppetserver_gem',
}
->
package { 'vault-puppetpath-gem':
  ensure   => 'present',
  name     => 'vault',
  provider => 'puppet_gem',
}
->
package { 'debouncer-puppetserver-gem':
  ensure   => 'present',
  name     => 'debouncer',
  provider => 'puppetserver_gem',
}
->
package { 'debouncer-puppetpath-gem':
  ensure   => 'present',
  name     => 'debouncer',
  provider => 'puppet_gem',
}
~> Service['puppetserver']

```

### Installation

The data provider is available by installing the `petems/hiera_vault` module into your environment:

This will avaliable on the forge, and installable with the module command:

```
# puppet module install petems/hiera_vault
```

You can also download the module directly:

```shell
git clone https://github.com/petems/petems-hiera_vault /etc/puppetlabs/code/environments/production/modules/hiera_vault
```

Or add it to your Puppetfile

```ruby
mod 'hiera_vault',
  :git => 'https://github.com/petems/petems-hiera_vault'
```

### Hiera Configuration

See [The official Puppet documentation](https://docs.puppet.com/puppet/latest/hiera_intro.html) for more details on configuring Hiera 5.

The following is an example Hiera 5 hiera.yaml configuration for use with hiera-vault

```yaml
---

version: 5

hierarchy:
  - name: "Hiera-vault lookup"
    lookup_key: hiera_vault
    uris:
      - puppet/%{::trusted.certname}
      - puppet/common
    options:
      address: https://vault.foobar.com:8200
      token: <insert-your-vault-token-here>
      confine_to_keys:
        - '^vault_.*'
        - '^.*_password$'
        - '^password.*'
      default_field: value
      default_field_behavior: only
      default_field_parse: string
      environment_delimiter: '--'
      mounts:
        puppet:
          type: kv
          version: 2
      ssl_verify: true
```

#### Configuration Options

The following mandatory Hiera 5 options must be set for each level of the hierarchy.

`name`: A human readable name for the lookup

`lookup_key`: This option must be set to `hiera_vault`

`uris`: The list of secret paths to use for the lookup.

The following are optional configuration parameters supported in the `options` hash of the Hiera 5 config

`address`: The address of the Vault server, also read as `ENV["VAULT_ADDR"]`

`token`: The token to authenticate with Vault, also read as `ENV["VAULT_TOKEN"]` or a full path to the file with the token (eg. `/etc/vault_token.txt`). 
         When bootstrapping, you can set this token as `IGNORE-VAULT` and the backend will be stubbed, which can be useful when bootstrapping.

`confine_to_keys:`: Only use this backend if the key matches one of the regexes in the array, to avoid constantly reaching out to Vault for every parameter lookup

```yaml
confine_to_keys:
  - "application.*"
  - "apache::.*"
```

`strip_from_keys`: An array of regular expressions to be globally replace with `''` _before_ the lookup is performed against vault.

`environment_delimiter`: A string for splitting secret fields and collecting by environment prior to parsing and returning the results. See [examples](####Examples)

`default_field`: The default field within data to return. If not present, the lookup will be the full contents of the secret data.

`default_field_behavior`: When set to `only` [default], the value of the default field will be returned if it is the _only_ field in the secret. When set to `ignore`, fields which are not the default will be ignored, any the value of the default field will be returned. In this case, the full secret hash will only be returned if the default field is _not_ part of the secret.

`default_field_parse`: Whether or not to do aditional parsing to the value of the default field before returning. `string` [default], will not parse the contents of the default field in any way. `json`, will JSON parse the contents of the default field before returning

`mounts`: Configuration for the mounts found in the `uris` setting. the name of the `mount` must match the mount for the secret backend. This is optional as the backend will assume kv version 1 if there is no mount stanza for the uri See [Mounts](####Mounts)

```yaml
mounts:
  puppet:      # The vault mount path is `puppet/`, this will be used when stepping through the uris
    type: kv   # This is the only currently supported option, and the default
    version: 2 # Version 1 and 2 have different calls to vault, the default is 1
```

`ssl_pem_file`: The combined client cert and key for TLS auth to vault
`ssl_verify`: Specify whether to verify SSL certificates (default: true)
`ssl_ca_cert`: The file path directly to the ca certificate corresponding to vault
`ssl_ca_path`: A path to a directory of trusted ca certificates.
`ssl_ciphers`: The ciphersuite which the vault client should use. [NOTE: This will be the ciphers suppored by `jruby-openssl` which can be outdated.]


### Debugging

The `--explain` option provides quite a bit of out put to describe what appened including times for ruby proccessing and wrapped around calls to vault. The function is pretty heavily commented, take a look there for rational and techniques used for ensuring things stay fast.

```
puppet lookup vault_hash_secret --explain --compile --node=node1.vm
Searching for "vault_hash_secret"
  Global Data Provider (hiera configuration version 5)
    Using configuration "/etc/puppetlabs/puppet/hiera.yaml"
    No such key: "vault_hash_secret"
  Environment Data Provider (hiera configuration version 5)
    Using configuration "/etc/puppetlabs/code/environments/production/hiera.yaml"
    Hierarchy entry "Hiera-vault lookup"
      URI "hiera/nodes/"
        Original uri: "hiera/nodes/%{::certname}/"
        No such key: "vault_hash_secret"
        1559816099.6045368 Starting
        Configured Vault Client http://127.0.0.1:8200
        kv version: 2
        Final uri: hiera/data/nodes/node1.vm
        1559816099.6045845 Getting key list from v1/hiera/metadata/nodes/
        Calling vault 1559816099.604589
        Could not read secret v1/hiera/metadata/nodes/: 
        1559816099.6068976 Got key list []
        1559816099.6069062 Finished Checking
      URI "hiera/common/"
        Original uri: "hiera/common/"
        Found key: "vault_hash_secret" value: {
          "field_4" => nil,
          "field_1" => "value_1",
          "field_2" => "value_2",
          "field_3" => "value_3"
        }
        1559816099.606976 Starting
        Configured Vault Client http://127.0.0.1:8200
        kv version: 2
        Final uri: hiera/data/common/vault_hash_secret
        1559816099.607021 Getting key list from v1/hiera/metadata/common/
        Calling vault 1559816099.6070263
        Resp from vault 1559816099.6087668
        1559816099.6087997 Got key list ["vault_fall_through_secret", "vault_hash_secret", "vault_test_secret"]
        Calling vault 1559816099.60882
        Resp from vault 1559816099.610817
        Getting Environment values based on --
        Base fields: ["field_4", "field_1", "field_2", "field_3"]
```

### Vault Configuration

NOTE: Support requires some changes upstream in the `vault` gem. See the wf_master branch of this fork [`vault-ruby`](https://github.com/wayfair/vault-ruby) for code that works with the this branch.

#### Mounts

It is recomended to have a specific mount for your Puppet secrets, to avoid conflicts with an existing secrets backend.

From the command line:

```
vault secrets enable -version=2 -path=puppet kv
```

We will then configure this in our hiera config:

```yaml
uris:
  - puppet/%{::trusted.certname}
  - puppet/common
default_value: default_value
mounts:
  puppet:
    type: kv
    version: 2
```

Then when a hiera call is made with lookup on a machine with the certname of `foo.example.com`:

```
$cool_key = lookup({"name" => "cool_key", "default_value" => "No Vault Secret Found"})
```

Secrets will then be looked up with the following path: `http://vault.example.com:8200/v1/puppet/data/foo.example.com/cool_key`

#### Examples

Due to the number of configuration options about how to pull values out of vault, the following are examples of how different settings impact the results.

Given the following settings:
```yaml
uris:
  - hiera/common
options:
  environment_delimiter: --
  default_field: value
  default_field_behavior: only
```
The expected evaluations of a lookup are below:

##### Default Field Examples

NOTE: with `only` set as the `default_field_behavior, other secret path contents will be treated like [Dictionary Field Examples](#####Dictionary)

Simple default field only example

```
Environment:   production
Lookup:        vault_test_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
  'value': 'a secret'
}
Puppet:        $test_secret = lookup('vault_test_secret')
Yeilds:        $test_secret = 'a secret'
```

Default field only not running on environment with specific default field

```
Environment:   production
Lookup:        vault_test_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
            'value': 'a secret',
  'test_env--value': 'env secret'
}
Puppet:        $test_secret = lookup('vault_test_secret')
Yields:        $test_secret = 'a secret'
```

Default field only whith environment specific default field

```
Environment:   test_env
Lookup:        vault_test_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
            'value': 'a secret',
  'test_env--value': 'env secret'
}
Puppet:        $test_secret = lookup('vault_test_secret')
Yields:        $test_secret = 'env secret'
```

Default field has no bare value, not running on envirenment with default field

```
Environment:   production
Lookup:        vault_test_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
  'test_env--value': 'env secret'
}
Puppet:        $test_secret = lookup('vault_test_secret')
!!! This will fall through to eyaml then yaml, and fail or return the default if nothing is found !!!
```

##### Dictionary Field Examples

NOTE: if `ignore` is set as the `default_field_behavior` any secret paths which contain the `default_field` will be treated like the examples in [Default Field Examples](#####Default)

Only bare fields are returned, as the environment doesn't match the environment specific field

```
Environment:   production
Lookup:        vault_hash_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
            'field_a': 'field_a secret',
  'test_env--field_a': 'field_a env secret',
            'field_b': 'another field'
}
Puppet:        $test_secret = lookup('vault_test_secret')
Yields:        $test_secret = {
                 'field_a': 'field_a secret',
                 'field_b': 'another field'
               }
```

The environment specific field is returned with the environment specific ones.

```
Environment:   test_env
Lookup:        vault_hash_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
               'field_a': 'field_a secret',
  'test_branch--field_a': 'field_a env secret',
               'field_b': 'another field'
}
Puppet:        $test_secret = lookup('vault_test_secret')
Yields:        $test_secret = {
                 'field_a': 'field_a env secret',
                 'field_b': 'another field'
               }
```

A field exists which is has neither a bare, nor environment specific value

```
Environment:   production
Lookup:        vault_hash_secret
Path:          hiera/common/vault_test_secret
Path Contents: {
            'field_a': 'field_a secret',
  'test_env--field_a': 'field_a env secret',
  'test_env--field_b': 'another env field'
}
Puppet:        $test_secret = lookup('vault_test_secret')
Yields:        $test_secret = {
                 'field_a': 'field_a branch secret',
                 'field_b': nil
               }
```

### Author

* Original - David Alden <dave@alden.name>
* wf_master version - Travis Cosgrave <tcosgrave@wayfair.com>
* Transfered and maintained by Peter Souter

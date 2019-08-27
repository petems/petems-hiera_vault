## hiera_vault : a vault data provider function (backend) for Hiera 5

### Description

> Warning: master may be broken whilst this repo is upgraded for k/v v2 and newer Vault version upgrades! Please use the 0.1.0 tagged release in the meantime. This message will be removed and a 1.0.0 breaking release will be tagged on the Forge in the future.

This is a back end function for Hiera 5 that allows lookup to be sourced from Hashicorp's Vault.

[Vault](https://vaultproject.io) secures, stores, and tightly controls access to tokens, passwords, certificates, API keys, and other secrets in modern computing. Vault handles leasing, key revocation, key rolling, and auditing. Vault presents a unified API to access multiple backends: HSMs, AWS IAM, SQL databases, raw key/value, and more.

For an example repo of it in action, check out the [hashicorp/webinar-vault-hiera-puppet](https://github.com/hashicorp/webinar-vault-hiera-puppet) repo and webinar ['How to Use HashiCorp Vault with Hiera 5 for Secret Management with Puppet'](https://www.hashicorp.com/resources/hashicorp-vault-with-puppet-hiera-5-for-secret-management)

### Compatibility

* This moduel is only compatible with Hiera 5 (ships with Puppet 4.9+) and Vault KV engine version 2 (Vault 0.10+)

### Requirements

The `vault` and `debouncer` gems must be installed and loadable from Puppet

```
# /opt/puppetlabs/puppet/bin/gem install vault
# /opt/puppetlabs/puppet/bin/gem install debouncer
# puppetserver gem install vault
# puppetserver gem install debouncer
```

On Puppetserver <= 5, you will need to switch Puppetserver to use the new JRuby 9K, as the gem requires Ruby 2+, and Puppetserver uses the 1.9.2 JRuby

Some example Puppetcode to do so:

```
ini_setting { "Change jruby to 9k":
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

On Puppetserver >= 6, this is not needed as the default has been moved to the newer JRuby.

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

See [The official Puppet documentation](https://docs.puppet.com/puppet/4.9/hiera_intro.html) for more details on configuring Hiera 5.

The following is an example Hiera 5 hiera.yaml configuration for use with hiera-vault

```yaml
---

version: 5

hierarchy:
  - name: "Hiera-vault lookup"
    lookup_key: hiera_vault
    options:
      confine_to_keys:
        - '^vault_.*'
        - '^.*_password$'
        - '^password.*'
      ssl_verify: false
      address: https://vault.foobar.com:8200
      token: <insert-your-vault-token-here>
      default_field: value
      mounts:
        some_secret:
          - %{::trusted.certname}
          - common
        another_secret:
          - %{::trusted.certname}
          - common
```

The following mandatory Hiera 5 options must be set for each level of the hierarchy.

`name`: A human readable name for the lookup

`lookup_key`: This option must be set to `hiera_vault`

The following are optional configuration parameters supported in the `options` hash of the Hiera 5 config

`address`: The address of the Vault server, also read as `ENV["VAULT_ADDR"]`

`token`: The token to authenticate with Vault, also read as `ENV["VAULT_TOKEN"]` or a full path to the file with the token (eg. `/etc/vault_token.txt`). When bootstrapping, you can set this token as `IGNORE-VAULT` and the backend will be stubbed, which can be useful when bootstrapping.

`confine_to_keys:`: Only use this backend if the key matches one of the regexes in the array, to avoid constantly reaching out to Vault for every parameter lookup

      confine_to_keys:
        - "application.*"
        - "apache::.*"

`default_field:`: The default field within data to return. If not present, the lookup will be the full contents of the secret data.

`mounts:`: The list of mounts you want to do lookups against. This is treated as the backend hiearchy for lookup. It is recomended you use [Trusted Facts](https://puppet.com/docs/puppet/5.3/lang_facts_and_builtin_vars.html#trusted-facts) within the hierachy to ensure lookups are restricted to the correct hierachy points. See [Mounts](####Mounts)

`:ssl_verify`: Specify whether to verify SSL certificates (default: true)


### Debugging

```
puppet lookup vault_notify --explain --compile --node=node1.vm
Searching for "vault_notify"
  Global Data Provider (hiera configuration version 3)
    Using configuration "/etc/puppetlabs/code/hiera.yaml"
    Hierarchy entry "yaml"
      Path "/etc/puppetlabs/code/environments/production/hieradata/node1.yaml"
        Original path: "%{::hostname}"
        No such key: "vault_notify"
      Path "/etc/puppetlabs/code/environments/production/hieradata/common.yaml"
        Original path: "common"
        Path not found
  Environment Data Provider (hiera configuration version 5)
    Using configuration "/etc/puppetlabs/code/environments/production/hiera.yaml"
    Hierarchy entry "Hiera-vault lookup"
      Found key: "vault_notify" value: "hello123"
```

### Vault Configuration

#### Mounts

It is recomended to have a specific mount for your Puppet secrets, to avoid conflicts with an existing secrets backend.

From the command line:

```
vault secrets enable -version=2 -path=some_secret kv
```

We will then configure this in our hiera config:

```yaml
mounts:
  some_secret:
    - %{::trusted.certname}
    - common
```

Then when a hiera call is made with lookup on a machine with the certname of `foo.example.com`:

```
$cool_key = lookup({"name" => "cool_key", "default_value" => "No Vault Secret Found"})
```

Secrets will then be looked up with the following paths:
* http://vault.foobar.com:8200/some_secret/foo.example.com/cool_key (for v1)
* http://vault.foobar.com:8200/some_secret/foo.example.com/data/cool_key (for v2)
* http://vault.foobar.com:8200/some_secret/common/cool_key (for v1)
* http://vault.foobar.com:8200/some_secret/common/data/cool_key (for v2)
* http://vault.foobar.com:8200/another_secret/foo.example.com/cool_key (for v1)
* http://vault.foobar.com:8200/another_secret/foo.example.com/data/cool_key (for v2)
* http://vault.foobar.com:8200/another_secret/common/cool_key (for v1)
* http://vault.foobar.com:8200/another_secret/common/data/cool_key (for v2)

### Author

* Original - David Alden <dave@alden.name>
* Transfered and maintained by Peter Souter

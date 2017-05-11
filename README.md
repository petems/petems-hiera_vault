## hiera_vault : a vault data provider function (backend) for Hiera 5

### Description

This is a back end function for Hiera 5 that allows lookup to be sourced from Hashicorp's Vault.

[Vault](https://vaultproject.io) secures, stores, and tightly controls access to tokens, passwords, certificates, API keys, and other secrets in modern computing. Vault handles leasing, key revocation, key rolling, and auditing. Vault presents a unified API to access multiple backends: HSMs, AWS IAM, SQL databases, raw key/value, and more.

### Compatibility

* This moduel is only compatible with Hiera 5 (ships with Puppet 4.9+)

### Requirements

The `vault` gem must be installed and loadable from Puppet

```
# /opt/puppetlabs/puppet/bin/gem install vault
# puppetserver gem install vault
```


### Installation

The data provider is available by installing the `davealden/hiera_vault` module into your environment.

```
# puppet module install davealden/hiera_vault
```

### Configuration

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
        generic:
          - secret/puppet/%{::trusted.certname}/
          - secret/puppet/common/
```

The following mandatory Hiera 5 options must be set for each level of the hierarchy.

`name`: A human readable name for the lookup

`lookup_key`: This option must be set to `hiera_vault`


The following are optional configuration parameters supported in the `options` hash of the Hiera 5 config

`address`: The address of the Vault server, also read as ENV["VAULT_ADDR"]

`token`: The token to authenticate with Vault, also read as ENV["VAULT_TOKEN"]

`:confine_to_keys: ` : Only use this backend if the key matches one of the regexes in the array

      confine_to_keys:
        - "application.*"
        - "apache::.*"

`:ssl_verify`: Specify whether to verify SSL certificates (default: true)

### Author

* David Alden <dave@alden.name>

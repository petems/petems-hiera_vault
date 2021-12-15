# sandbox

This is a basic docker-compose sandbox that creates a Puppetserver with the working directory of hiera-vault, a vault server with a KV mounted, and a puppet agent.

## Setup

```
$ docker compose up -d --build
Building puppet
[+] Building 0.2s (11/11) FINISHED
 => [internal] load build definition from Dockerfile.puppetserver                                                                                                                                      0.0s
 => => transferring dockerfile: 387B                                                                                                                                                                   0.0s
 => [internal] load .dockerignore                                                                                                                                                                      0.0s
 => => transferring context: 2B                                                                                                                                                                        0.0s
 => [internal] load metadata for docker.io/puppet/puppetserver:6.14.1                                                                                                                                  0.0s
 => [1/6] FROM docker.io/puppet/puppetserver:6.14.1                                                                                                                                                    0.0s
 => [internal] load build context                                                                                                                                                                      0.0s
 => => transferring context: 88B                                                                                                                                                                       0.0s
 => CACHED [2/6] RUN puppetserver gem install vault --no-document                                                                                                                                      0.0s
 => CACHED [3/6] RUN puppetserver gem install debouncer --no-document                                                                                                                                  0.0s
 => CACHED [4/6] RUN /opt/puppetlabs/puppet/bin/gem install vault --no-document                                                                                                                        0.0s
 => CACHED [5/6] RUN /opt/puppetlabs/puppet/bin/gem install debouncer --no-document                                                                                                                    0.0s
 => CACHED [6/6] COPY ./hiera.yaml /etc/puppetlabs/puppet/hiera.yaml                                                                                                                                   0.0s
 => exporting to image                                                                                                                                                                                 0.0s
 => => exporting layers                                                                                                                                                                                0.0s
 => => writing image sha256:8e00693e69c4838475063fd05c3872c83dbf37d6560d13250ee51cc6aa041809                                                                                                           0.0s
 => => naming to docker.io/library/sandbox_puppet                                                                                                                                                      0.0s

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
Building agent1
[+] Building 2.2s (12/12) FINISHED
 => [internal] load build definition from Dockerfile.ubuntu_agent                                                                                                                                      0.0s
 => => transferring dockerfile: 498B                                                                                                                                                                   0.0s
 => [internal] load .dockerignore                                                                                                                                                                      0.0s
 => => transferring context: 2B                                                                                                                                                                        0.0s
 => [internal] load metadata for docker.io/library/ubuntu:xenial                                                                                                                                       2.0s
 => [1/8] FROM docker.io/library/ubuntu:xenial@sha256:0f71fa8d4d2d4292c3c617fda2b36f6dabe5c8b6e34c3dc5b0d17d4e704bd39c                                                                                 0.0s
 => CACHED [2/8] RUN apt-get update                                                                                                                                                                    0.0s
 => CACHED [3/8] RUN apt-get -y install curl                                                                                                                                                           0.0s
 => CACHED [4/8] RUN curl -o /tmp/puppet6-release-xenial.deb https://apt.puppetlabs.com/puppet6-release-xenial.deb                                                                                     0.0s
 => CACHED [5/8] RUN dpkg -i /tmp/puppet6-release-xenial.deb                                                                                                                                           0.0s
 => CACHED [6/8] RUN apt-get update                                                                                                                                                                    0.0s
 => CACHED [7/8] RUN apt-get -y update && apt-get -y install puppet-agent puppet-lint                                                                                                                  0.0s
 => CACHED [8/8] RUN cp /opt/puppetlabs/bin/puppet /bin/puppet                                                                                                                                         0.0s
 => exporting to image                                                                                                                                                                                 0.0s
 => => exporting layers                                                                                                                                                                                0.0s
 => => writing image sha256:c0aa470bb0da03a44173c5f0f09ff49651776cc939c352b5c95b81d8a7147861                                                                                                           0.0s
 => => naming to docker.io/library/sandbox_agent1                                                                                                                                                      0.0s

Use 'docker scan' to run Snyk tests against images to find vulnerabilities and learn how to fix them
Creating sandbox_puppet_1 ... done
Creating sandbox_agent1_1 ... done
Creating sandbox_vault_1  ... done
Creating vault_enabler    ... done
Creating vault_writer_one ... done
$ docker-compose ps
      Name                    Command                       State                            Ports
--------------------------------------------------------------------------------------------------------------------
sandbox_agent1_1   /bin/bash                        Up
sandbox_puppet_1   dumb-init /docker-entrypoi ...   Up (health: starting)   0.0.0.0:8140->8140/tcp,:::8140->8140/tcp
sandbox_vault_1    docker-entrypoint.sh serve ...   Up                      0.0.0.0:8200->8200/tcp,:::8200->8200/tcp
vault_enabler      docker-entrypoint.sh vault ...   Exit 0
vault_writer_one   docker-entrypoint.sh vault ...   Exit 0
```

You can now jump into the agent or the Puppetserver and test things.

For example, to quickly test the module is working as expected:

```
$ docker-compose run --entrypoint='puppet lookup vault_notify --explain --compile --node=node1.vm' puppet
Creating sandbox_puppet_run ... done
Searching for "lookup_options"
  Global Data Provider (hiera configuration version 5)
    Using configuration "/etc/puppetlabs/puppet/hiera.yaml"
    Hierarchy entry "Hiera-vault lookup"
      No such key: "lookup_options"
      [hiera-vault] Skipping hiera_vault backend because key 'lookup_options' does not match confine_to_keys
Searching for "vault_notify"
  Global Data Provider (hiera configuration version 5)
    Using configuration "/etc/puppetlabs/puppet/hiera.yaml"
    Hierarchy entry "Hiera-vault lookup"
      Found key: "vault_notify" value: "'Hello World'"
      [hiera-vault] Client configured to connect to http://vault:8200
      [hiera-vault] Looking in path some_secret/common for vault_notify
      [hiera-vault] Checking path: some_secret/common/data/vault_notify
      [hiera-vault] Checking path: some_secret/data/common/vault_notify
      [hiera-vault] Checking path: some_secret/common/vault_notify
      [hiera-vault] Read secret: vault_notify
```

We can see that things are working.

Then, lets say we change some code, and add an extra line: 

```
$ docker-compose run --entrypoint='puppet lookup vault_notify --explain --compile --node=node1.vm' puppet | grep 'just added'
Creating sandbox_puppet_run ... done
      [hiera-vault] Hello Docker, I just added some code
```


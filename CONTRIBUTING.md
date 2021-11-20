This module has grown over time based on a range of contributions from
people using it. If you follow these contributing guidelines your patch
will likely make it into a release a little quicker.

## Contributing

1. Fork the repo.

1. Create a separate branch for your change.

1. Run the tests. We only take pull requests with passing tests, and
   documentation.

1. Add a test for your change. Only refactoring and documentation
   changes require no new tests. If you are adding functionality
   or fixing a bug, please add a test.

1. Squash your commits down into logical components. Make sure to rebase
   against the current master.

1. Push the branch to your fork and submit a pull request.

Please be prepared to repeat some of these steps as our contributors review
your code.

## Dependencies

The testing and development tools have a bunch of dependencies,
all managed by [bundler](http://bundler.io/).

By default the tests use a baseline version of Puppet.

Install the dependencies like so...

    bundle install

## Syntax and style

Run `rubocop` to detect style issues and perform fixes:

    bundle exec rubocop -a .

## Running the unit tests

The unit test suite covers most of the code, as mentioned above please
add tests if you're adding new functionality.

The unit tests currently run against a real vault instance running in `server -dev` mode.
This can be seen in [./spec/support/vault_server.rb](vault_server.rb)).

You will need Vault in your path for this to work.

To run your all the unit tests

    bundle exec rake spec SPEC_OPTS='--format documentation'

To run a specific spec test set the `SPEC` variable:

    bundle exec rake spec SPEC=spec/foo_spec.rb:123

The tests require a version of `vault` to be avaliable on the command-line.

```
#!/bin/bash
VAULT_VERSION=1.3.0
cd /tmp/
curl -sLo vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault.zip
mkdir -p /usr/local/bin
mv vault /usr/local/bin
export PATH="/usr/local/bin:$PATH"
```

### Docker enviroment for tests

If you want a quick Docker lab to run the tests on, we have a `docker-compose` environment setup:

```
docker-compose up --build
```

If you have any errors, you can create and then attach to the container with run:

```
docker-compose run hiera_vault /bin/bash
```
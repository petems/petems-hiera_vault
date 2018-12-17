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



## Integration tests

The unit tests just check the code runs, not that it does exactly what
we want on a real machine. For that we're using
[beaker](https://github.com/puppetlabs/beaker).

This fires up a simple Docker cluster and runs a series of
simple tests against it after applying the module. You can run this
with:

    bundle exec rake acceptance

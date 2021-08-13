# Changelog

## [v2.0.0](https://github.com/petems/petems-hiera_vault/tree/v2.0.0) (2021-07-29)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v1.0.1...v2.0.0)

**Implemented enhancements:**

- Sample vault secrets in README, Documentation of default\_field\_\* [\#46](https://github.com/petems/petems-hiera_vault/issues/46)

**Fixed bugs:**

- IGNORE-VAULT doesn't work correctly if set in the file. [\#59](https://github.com/petems/petems-hiera_vault/issues/59)

**Merged pull requests:**

- Adds test for file containing ignore [\#70](https://github.com/petems/petems-hiera_vault/pull/70) ([petems](https://github.com/petems))
- Add comma based multi-pathing [\#69](https://github.com/petems/petems-hiera_vault/pull/69) ([scoiatael](https://github.com/scoiatael))
- Bump addressable from 2.7.0 to 2.8.0 [\#68](https://github.com/petems/petems-hiera_vault/pull/68) ([dependabot[bot]](https://github.com/apps/dependabot))
- Fix issues with race conditions connecting to Vault [\#65](https://github.com/petems/petems-hiera_vault/pull/65) ([rmc47](https://github.com/rmc47))
- Bump puppet from 6.11.1 to 6.21.1 [\#64](https://github.com/petems/petems-hiera_vault/pull/64) ([dependabot[bot]](https://github.com/apps/dependabot))
- Fix reading vault token from ENV [\#63](https://github.com/petems/petems-hiera_vault/pull/63) ([SasSwart](https://github.com/SasSwart))
- Add --user-install flag to gem install as specified here:  [\#62](https://github.com/petems/petems-hiera_vault/pull/62) ([SasSwart](https://github.com/SasSwart))
- Add bundler [\#58](https://github.com/petems/petems-hiera_vault/pull/58) ([petems](https://github.com/petems))

## [v1.0.1](https://github.com/petems/petems-hiera_vault/tree/v1.0.1) (2020-05-17)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v1.0.0...v1.0.1)

## [v1.0.0](https://github.com/petems/petems-hiera_vault/tree/v1.0.0) (2020-05-17)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.4.4...v1.0.0)

**Merged pull requests:**

- cleanup syntax highlighting / please md linter [\#53](https://github.com/petems/petems-hiera_vault/pull/53) ([bastelfreak](https://github.com/bastelfreak))
- Fixes approach for V1 pathing [\#52](https://github.com/petems/petems-hiera_vault/pull/52) ([petems](https://github.com/petems))
- Continue with next path on vault error [\#50](https://github.com/petems/petems-hiera_vault/pull/50) ([Thor77](https://github.com/Thor77))
- Add note about using with Vault Agent [\#49](https://github.com/petems/petems-hiera_vault/pull/49) ([yakatz](https://github.com/yakatz))
- Adds newer Vault versions to Travis [\#45](https://github.com/petems/petems-hiera_vault/pull/45) ([petems](https://github.com/petems))
- Adds v2 fix for `default_field` [\#44](https://github.com/petems/petems-hiera_vault/pull/44) ([petems](https://github.com/petems))
- Fix kv2 support [\#43](https://github.com/petems/petems-hiera_vault/pull/43) ([maxadamo](https://github.com/maxadamo))
- Add documentation for strip\_from\_keys option [\#42](https://github.com/petems/petems-hiera_vault/pull/42) ([Thor77](https://github.com/Thor77))
- Makes it compatible with Vault KV version 1 and 2 [\#41](https://github.com/petems/petems-hiera_vault/pull/41) ([arcenik](https://github.com/arcenik))
- Fixes VAULT\_TOKEN usage and multiple paths per mount [\#32](https://github.com/petems/petems-hiera_vault/pull/32) ([fuero](https://github.com/fuero))

## [v0.4.4](https://github.com/petems/petems-hiera_vault/tree/v0.4.4) (2020-05-17)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.4.3...v0.4.4)

## [v0.4.3](https://github.com/petems/petems-hiera_vault/tree/v0.4.3) (2020-05-17)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.4.2...v0.4.3)

## [v0.4.2](https://github.com/petems/petems-hiera_vault/tree/v0.4.2) (2020-05-15)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.4.1...v0.4.2)

**Closed issues:**

- handshake\_failure [\#39](https://github.com/petems/petems-hiera_vault/issues/39)
- How to protect the token? [\#35](https://github.com/petems/petems-hiera_vault/issues/35)
- Secret search path joined into one path instead of iteration over paths [\#29](https://github.com/petems/petems-hiera_vault/issues/29)
- tag is not in sync with the version [\#28](https://github.com/petems/petems-hiera_vault/issues/28)
- Supporting k/v v2 [\#23](https://github.com/petems/petems-hiera_vault/issues/23)

## [v0.4.1](https://github.com/petems/petems-hiera_vault/tree/v0.4.1) (2019-06-21)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.3.1...v0.4.1)

**Merged pull requests:**

- Update Rspec setup [\#37](https://github.com/petems/petems-hiera_vault/pull/37) ([petems](https://github.com/petems))
- Fixed bug with multiple paths in mount [\#31](https://github.com/petems/petems-hiera_vault/pull/31) ([kozl](https://github.com/kozl))

## [v0.3.1](https://github.com/petems/petems-hiera_vault/tree/v0.3.1) (2019-05-02)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.2.2...v0.3.1)

**Closed issues:**

- Token Field does not Support JSON Files [\#34](https://github.com/petems/petems-hiera_vault/issues/34)
- Feature Request: Renew Token Key [\#33](https://github.com/petems/petems-hiera_vault/issues/33)
- can't use standby node [\#27](https://github.com/petems/petems-hiera_vault/issues/27)
- Lots of CLOSE\_WAITS to Vault [\#25](https://github.com/petems/petems-hiera_vault/issues/25)

**Merged pull requests:**

- fix vault.address message [\#30](https://github.com/petems/petems-hiera_vault/pull/30) ([kokovikhinkv](https://github.com/kokovikhinkv))
- Updating README to reflect kv v1 engine compatibility [\#20](https://github.com/petems/petems-hiera_vault/pull/20) ([radupantiru](https://github.com/radupantiru))
- read a token from file when exists [\#16](https://github.com/petems/petems-hiera_vault/pull/16) ([pulecp](https://github.com/pulecp))

## [v0.2.2](https://github.com/petems/petems-hiera_vault/tree/v0.2.2) (2019-01-10)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.2.1...v0.2.2)

## [v0.2.1](https://github.com/petems/petems-hiera_vault/tree/v0.2.1) (2019-01-10)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/v0.1.1...v0.2.1)

**Closed issues:**

- Add note to readme about puppetserver JRUBY [\#24](https://github.com/petems/petems-hiera_vault/issues/24)
- Backend fails without gems [\#18](https://github.com/petems/petems-hiera_vault/issues/18)
- debouncer issue? [\#14](https://github.com/petems/petems-hiera_vault/issues/14)
- can't setup puppet module [\#12](https://github.com/petems/petems-hiera_vault/issues/12)
- Returned value should be not\_found\(\) if secret not found [\#10](https://github.com/petems/petems-hiera_vault/issues/10)

## [v0.1.1](https://github.com/petems/petems-hiera_vault/tree/v0.1.1) (2018-12-09)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/0.1.0...v0.1.1)

**Closed issues:**

- No value returned by hiera-vault backend [\#17](https://github.com/petems/petems-hiera_vault/issues/17)

## [0.1.0](https://github.com/petems/petems-hiera_vault/tree/0.1.0) (2018-06-21)

[Full Changelog](https://github.com/petems/petems-hiera_vault/compare/559943d3606b7d490e88db06d0c568411d6282fe...0.1.0)

**Closed issues:**

- Problems with later versions of vault gem and puppetserver [\#5](https://github.com/petems/petems-hiera_vault/issues/5)

**Merged pull requests:**

- Unit tests [\#9](https://github.com/petems/petems-hiera_vault/pull/9) ([fuero](https://github.com/fuero))
- caching vault object for entire run and closing sockets when done [\#8](https://github.com/petems/petems-hiera_vault/pull/8) ([traviscosgrave](https://github.com/traviscosgrave))
- allow hiera to keep looking if value is not found [\#7](https://github.com/petems/petems-hiera_vault/pull/7) ([traviscosgrave](https://github.com/traviscosgrave))
- adding support for deeply nested object stored in Vault [\#6](https://github.com/petems/petems-hiera_vault/pull/6) ([traviscosgrave](https://github.com/traviscosgrave))
- Add some functionality [\#4](https://github.com/petems/petems-hiera_vault/pull/4) ([jovandeginste](https://github.com/jovandeginste))
- Meet basic Ruby coding standards [\#3](https://github.com/petems/petems-hiera_vault/pull/3) ([davealden](https://github.com/davealden))



\* *This Changelog was automatically generated by [github_changelog_generator](https://github.com/github-changelog-generator/github-changelog-generator)*

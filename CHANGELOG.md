# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 1.2.2 (2022-06-20)

### Fixed

- Connection leak from the connection pool when `after_commit` called outside Rails executor without connection checked out *and* some connections were already checked out from another threads.

  See discussion at [issue #20](https://github.com/Envek/after_commit_everywhere/issues/20) for details.

  [Pull request #22](https://github.com/Envek/after_commit_everywhere/pull/22) by [@Envek][].

## 1.2.1 (2022-06-10)

### Fixed

- Connection leak from the connection pool when `after_commit` called outside Rails executor without connection checked out

  Usually all invocations of `after_commit` (whether it happens during serving HTTP request in Rails controller or performing job in Sidekiq worker process) are made inside [Rails executor](https://guides.rubyonrails.org/threading_and_code_execution.html#executor) which checks in any connections back to the connection pool that were checked out inside its block.

  However, in cases when a) `after_commit` was called outside of Rails executor (3-rd party gems or non-Rails apps using ActiveRecord) **and** b) database connection hasn't been checked out yet, then connection will be checked out by `after_commit` implicitly by call to `ActiveRecord::Base.connection` and not checked in back afterwards causing it to _leak_ from the connection pool.

  But in that case we can be sure that there is no transaction in progress ('cause one need to checkout connection and issue `BEGIN` to it), so we don't need to check it out at all and can fast-forward to `without_tx` action.

  See discussion at [issue #20](https://github.com/Envek/after_commit_everywhere/issues/20) for details.

  [Pull request #21](https://github.com/Envek/after_commit_everywhere/pull/21) by [@Envek][].

## 1.2.0 (2022-03-26)

### Added

- Allow to change callbacks' behavior when they are called outside transaction:

  ```ruby
  AfterCommitEverywhere.after_commit(without_tx: :raise) do
    # Will be executed only if was called within transaction
    # Error will be raised otherwise
  end
  ```

  Available values for `without_tx` keyword argument:
   - `:execute` to execute callback immediately
   - `:warn_and_execute` to print warning and execute immediately
   - `:raise` to raise an exception instead of executing

  [Pull request #18](https://github.com/Envek/after_commit_everywhere/pull/18) by [@lolripgg][].

## 1.1.0 (2021-08-05)

### Added

- Allow to call transactional callbacks directly on `AfterCommitEverywhere` module:

  ```ruby
  AfterCommitEverywhere.after_commit { puts "If you see me then transaction has been successfully commited!" }
  ```

- Allow to call `in_transaction?` helper method from instance methods in classes that includes `AfterCommitEverywhere` module.

## 1.0.0 (2021-02-17)

Declare gem as stable. No changes since 0.1.5.

See [#11](https://github.com/Envek/after_commit_everywhere/issues/11) for discussion.

## 0.1.5 (2020-03-22)

### Fixed

- [PR [#8](https://github.com/Envek/after_commit_everywhere/pull/8)] Callback registration when callback methods are aliased. ([@stokarenko])

## 0.1.4 (2019-09-10)

- [PR [#6](https://github.com/Envek/after_commit_everywhere/pull/6)] ActiveRecord 6.0 compatibility. ([@joevandyk])

## 0.1.3 (2019-02-18)

- Make `in_transaction?` helper method public. ([@Envek])

## 0.1.2 (2018-05-01)

- [PR [#1](https://github.com/Envek/after_commit_everywhere/pull/1)] Enable ActiveRecord 4.2 support. ([@arjun810], [@Envek])

## 0.1.1 (2018-03-29)

- Do not issue warning on `after_commit` invocation outside of transaction as it is expected behaviour. ([@Envek])

## 0.1.0 (2018-03-18)

- Initial version with `after_commit`, `before_commit`. and `after_rollback` callbacks. ([@Envek])

[@Envek]: https://github.com/Envek "Andrey Novikov"
[@arjun810]: https://github.com/arjun810 "Arjun Singh" 
[@joevandyk]: https://github.com/joevandyk "Joe Van Dyk"
[@stokarenko]: https://github.com/stokarenko "Sergey Tokarenko"
[@lolripgg]: https://github.com/lolripgg "James Brewer"

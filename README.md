[![Gem Version](https://badge.fury.io/rb/after_commit_everywhere.svg)](https://rubygems.org/gems/after_commit_everywhere)

# `after_commit` everywhere

Allows to use ActiveRecord transactional callbacks **outside** of ActiveRecord models, literally everywhere in your application.

Inspired by these articles:

 - https://evilmartians.com/chronicles/rails-after_commit-everywhere
 - https://blog.arkency.com/2015/10/run-it-in-background-job-after-commit/

<a href="https://evilmartians.com/?utm_source=after_commit_everywhere&utm_campaign=project_page"><img src="https://evilmartians.com/badges/sponsored-by-evil-martians.svg" alt="Sponsored by Evil Martians" width="236" height="54"></a>


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'after_commit_everywhere'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install after_commit_everywhere


## Usage

Recommended usage is to include it to your base service class or anything:

```ruby
class ServiceObjectBtw
  include AfterCommitEverywhere

  def call
    ActiveRecord::Base.transaction do
      after_commit { puts "We're all done!" }
    end
  end
end
```

Or just extend it whenever you need it:

```ruby
extend AfterCommitEverywhere

ActiveRecord::Base.transaction do
  after_commit { puts "We're all done!" }
end
```

Or call it directly on module:

```ruby
AfterCommitEverywhere.after_commit { puts "We're all done!" }
```

That's it!

But the main benefit is that it works with nested `transaction` blocks (may be even spread across many files in your codebase):

```ruby
include AfterCommitEverywhere

ActiveRecord::Base.transaction do
  puts "We're in transaction now"

  ActiveRecord::Base.transaction do
    puts "More transactions"
    after_commit { puts "We're all done!" }
  end

  puts "Still in transaction…"
end
```

Will output:

```
We're in transaction now
More transactions
Still in transaction…
We're all done!
```

### Available callbacks

#### `after_commit`

Will be executed right after outermost transaction have been successfully committed and data become available to other DBMS clients.

If called outside transaction will execute callback immediately.

#### `before_commit`

Will be executed right before outermost transaction will be commited _(I can't imagine use case for it but if you can, please open a pull request or issue)_.

If called outside transaction will execute callback immediately.

Supported only starting from ActiveRecord 5.0.

#### `after_rollback`

Will be executed right after transaction in which it have been declared was rolled back (this might be nested savepoint transaction block with `requires_new: true`).

If called outside transaction will raise an exception!

Please keep in mind ActiveRecord's [limitations for rolling back nested transactions](http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Nested+transactions). See [`in_transaction`](#in_transaction) for a workaround to this limitation. 

### Available helper methods

#### `in_transaction`

Makes sure the provided block is running in a transaction.

This method aims to provide clearer intention than a typical `ActiveRecord::Base.transaction` block - `in_transaction` only cares that _some_ transaction is present, not that a transaction is nested in any way.

If a transaction is present, it will yield without taking any action. Note that this means `ActiveRecord::Rollback` errors will not be trapped by `in_transaction` but will propagate up to the nearest parent transaction block.

If no transaction is present, the provided block will open a new transaction.

```rb
class ServiceObjectBtw
  include AfterCommitEverywhere

  def call
    in_transaction do
      an_update
      another_update
      after_commit { puts "We're all done!" }
    end
  end
end
```

Our service object can run its database operations safely when run in isolation. 

```rb
ServiceObjectBtw.new.call # This opens a new #transaction block
```

If it is later called from code already wrapped in a transaction, the existing transaction will be utilized without any nesting:

```rb
ActiveRecord::Base.transaction do
  new_update
  next_update
  # This no longer opens a new #transaction block, because one is already present
  ServiceObjectBtw.new.call
end
```

This can be called directly on the module as well:

```rb
AfterCommitEverywhere.in_transaction do
  AfterCommitEverywhere.after_commit { puts "We're all done!" }
end
```

#### `in_transaction?`

Returns `true` when called inside an open transaction, `false` otherwise.

```rb
def check_for_transaction
  if in_transaction?
    puts "We're in a transaction!"
  else
    puts "We're not in a transaction..."
  end
end

check_for_transaction
# => prints "We're not in a transaction..."

in_transaction do
  check_for_transaction
end
# => prints "We're in a transaction!"
```

### Available callback options

 - `without_tx` allows to change default callback behavior if called without transaction open.

   Available values:
    - `:execute` to execute callback immediately
    - `:warn_and_execute` to print warning and execute immediately
    - `:raise` to raise an exception instead of executing

### FAQ

#### Does it works with transactional_test or DatabaseCleaner

**Yes**.

### Be aware of mental traps

While it is convenient to have `after_commit` method at a class level to be able to call it from anywhere, take care not to call it on models.

So, **DO NOT DO THIS**:

```ruby
class Post < ActiveRecord::Base
  def self.bulk_ops
    find_each do
      after_commit { raise "Some doesn't expect that this screw up everything, but they should" }
    end
  end
end
```

By calling [the class level `after_commit` method on models](https://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#method-i-after_commit), you're effectively adding callback for all `Post` instances, including **future** ones.

See https://github.com/Envek/after_commit_everywhere/issues/13 for details.

#### But what if I want to use it inside models anyway?

In class-level methods call `AfterCommitEverywhere.after_commit` directly:

```ruby
class Post < ActiveRecord::Base
  def self.bulk_ops
    find_each do
       AfterCommitEverywhere.after_commit { puts "Now it works as expected!" }
    end
  end
end
```

For usage in instance-level methods include this module to your model class (or right into your `ApplicationRecord`):

```ruby
class Post < ActiveRecord::Base
  include AfterCommitEverywhere

  def do_some_stuff
    after_commit { puts "Now it works!" }
  end
end
```

However, if you do something in models that requires defining such ad-hoc transactional callbacks, it may indicate that your models have too many responsibilities and these methods should be extracted to separate specialized layers (service objects, etc).

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

### Releasing new versions

1. Bump version number in `lib/after_commit_everywhere/version.rb`

   In case of pre-releases keep in mind [rubygems/rubygems#3086](https://github.com/rubygems/rubygems/issues/3086) and check version with command like `Gem::Version.new(AfterCommitEverywhere::VERSION).to_s`

2. Fill `CHANGELOG.md` with missing changes, add header with version and date.

3. Make a commit:

   ```sh
   git add lib/after_commit_everywhere/version.rb CHANGELOG.md
   version=$(ruby -r ./lib/after_commit_everywhere/version.rb -e "puts Gem::Version.new(AfterCommitEverywhere::VERSION)")
   git commit --message="${version}: " --edit
   ```

4. Create annotated tag:

   ```sh
   git tag v${version} --annotate --message="${version}: " --edit --sign
   ```

5. Fill version name into subject line and (optionally) some description (list of changes will be taken from `CHANGELOG.md` and appended automatically)

6. Push it:

   ```sh
   git push --follow-tags
   ```

7. GitHub Actions will create a new release, build and push gem into [rubygems.org](https://rubygems.org)! You're done!


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Envek/after_commit_everywhere.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

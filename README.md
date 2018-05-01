[![Gem Version](https://badge.fury.io/rb/after_commit_everywhere.svg)](https://rubygems.org/gems/after_commit_everywhere)
[![Build Status](https://travis-ci.org/Envek/after_commit_everywhere.svg?branch=master)](https://travis-ci.org/Envek/after_commit_everywhere)

# `after_commit` everywhere

Allows to use ActiveRecord transactional callbacks outside of ActiveRecord models, literally everywhere in your application.

Inspired by these articles:

 - https://dev.to/evilmartians/rails-aftercommit-everywhere--4j9g
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

Please keep in mind ActiveRecord's [limitations for rolling back nested transactions](http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Nested+transactions).

### FAQ

#### Does it works with transactional_test or DatabaseCleaner

**Yes**.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Envek/after_commit_everywhere.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

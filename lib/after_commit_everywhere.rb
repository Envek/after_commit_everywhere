# frozen_string_literal: true

require "active_record"
require "active_support/core_ext/module/delegation"

require "after_commit_everywhere/version"
require "after_commit_everywhere/wrap"

# Module allowing to use ActiveRecord transactional callbacks outside of
# ActiveRecord models, literally everywhere in your application.
#
# Include it to your classes (e.g. your base service object class or whatever)
module AfterCommitEverywhere
  class NotInTransaction < RuntimeError; end

  delegate :after_commit, :before_commit, :after_rollback, to: AfterCommitEverywhere
  delegate :in_transaction?, :in_transaction, to: AfterCommitEverywhere

  # Causes {before_commit} and {after_commit} to raise an exception when
  # called outside a transaction.
  RAISE = :raise
  # Causes {before_commit} and {after_commit} to execute the given callback
  # immediately when called outside a transaction.
  EXECUTE = :execute
  # Causes {before_commit} and {after_commit} to log a warning before calling
  # the given callback immediately when called outside a transaction.
  WARN_AND_EXECUTE = :warn_and_execute

  class << self
    # Runs +callback+ after successful commit of outermost transaction for
    # database +connection+.
    #
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] Database connection to operate in. Defaults to +ActiveRecord::Base.connection+
    # @param without_tx [Symbol] Determines the behavior of this function when
    #   called without an open transaction.
    #
    #   Must be one of: {RAISE}, {EXECUTE}, or {WARN_AND_EXECUTE}.
    #
    # @param callback   [#call] Callback to be executed
    # @return           void
    def after_commit(
      connection: nil,
      without_tx: EXECUTE,
      &callback
    )
      register_callback(
        connection: connection,
        name: __method__,
        callback: callback,
        without_tx: without_tx,
      )
    end

    # Runs +callback+ before committing of outermost transaction for +connection+.
    #
    # Available only since Ruby on Rails 5.0. See https://github.com/rails/rails/pull/18936
    #
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] Database connection to operate in. Defaults to +ActiveRecord::Base.connection+
    # @param without_tx [Symbol] Determines the behavior of this function when
    #   called without an open transaction.
    #
    #   Must be one of: {RAISE}, {EXECUTE}, or {WARN_AND_EXECUTE}.
    #
    # @param callback   [#call] Callback to be executed
    # @return           void
    def before_commit(
      connection: nil,
      without_tx: WARN_AND_EXECUTE,
      &callback
    )
      if ActiveRecord::VERSION::MAJOR < 5
        raise NotImplementedError, "#{__method__} works only with Rails 5.0+"
      end

      register_callback(
        connection: connection,
        name: __method__,
        callback: callback,
        without_tx: without_tx,
      )
    end

    # Runs +callback+ after rolling back of transaction or savepoint (if declared
    # in nested transaction) for database +connection+.
    #
    # Caveat: do not raise +ActivRecord::Rollback+ in nested transaction block!
    # See http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Nested+transactions
    #
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] Database connection to operate in. Defaults to +ActiveRecord::Base.connection+
    # @param callback   [#call] Callback to be executed
    # @return           void
    # @raise            [NotInTransaction] if called outside transaction.
    def after_rollback(connection: nil, &callback)
      register_callback(
        connection: connection,
        name: __method__,
        callback: callback,
        without_tx: RAISE,
      )
    end

    # @api private
    def register_callback(connection: nil, name:, without_tx:, callback:)
      raise ArgumentError, "Provide callback to #{name}" unless callback

      unless in_transaction?(connection)
        case without_tx
        when WARN_AND_EXECUTE
          warn "#{name}: No transaction open. Executing callback immediately."
          return callback.call
        when EXECUTE
          return callback.call
        when RAISE
          raise NotInTransaction, "#{name} is useless outside transaction"
        else
          raise ArgumentError, "Invalid \"without_tx\": \"#{without_tx}\""
        end
      end

      connection ||= default_connection
      wrap = Wrap.new(connection: connection, "#{name}": callback)
      connection.add_transaction_record(wrap)
    end

    # Helper method to determine whether we're currently in transaction or not
    def in_transaction?(connection = nil)
      # Don't establish new connection if not connected: we apparently not in transaction
      return false unless connection || ActiveRecord::Base.connection_pool.active_connection?

      connection ||= default_connection
      # service transactions (tests and database_cleaner) are not joinable
      connection.transaction_open? && connection.current_transaction.joinable?
    end

    # Makes sure the provided block runs in a transaction. If we are not currently in a transaction, a new transaction is started.
    #
    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] Database connection to operate in. Defaults to +ActiveRecord::Base.connection+
    # @return           void
    def in_transaction(connection = nil)
      connection ||= default_connection

      if in_transaction?(connection)
        yield
      else
        connection.transaction { yield }
      end
    end

    private

    def default_connection
      ActiveRecord::Base.connection
    end
  end
end

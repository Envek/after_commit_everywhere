# frozen_string_literal: true

require 'active_record'

require 'after_commit_everywhere/version'
require 'after_commit_everywhere/wrap'

# Module allowing to use ActiveRecord transactional callbacks outside of
# ActiveRecord models, literally everywhere in your application.
#
# Include it to your classes (e.g. your base service object class or whatever)
module AfterCommitEverywhere
  class NotInTransaction < RuntimeError; end

  # Runs +callback+ after successful commit of outermost transaction for
  # database +connection+.
  #
  # If called outside transaction it will execute callback immediately.
  #
  # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
  # @param callback   [#call] Callback to be executed
  # @return           void
  def after_commit(connection: ActiveRecord::Base.connection, &callback)
    AfterCommitEverywhere.register_callback(
      connection: connection,
      name: __callee__,
      callback: callback,
      no_tx_action: :execute,
    )
  end

  # Runs +callback+ before committing of outermost transaction for +connection+.
  #
  # If called outside transaction it will execute callback immediately.
  #
  # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
  # @param callback   [#call] Callback to be executed
  # @return           void
  def before_commit(connection: ActiveRecord::Base.connection, &callback)
    AfterCommitEverywhere.register_callback(
      connection: connection,
      name: __callee__,
      callback: callback,
      no_tx_action: :warn_and_execute,
    )
  end

  # Runs +callback+ after rolling back of transaction or savepoint (if declared
  # in nested transaction) for database +connection+.
  #
  # Caveat: do not raise +ActivRecord::Rollback+ in nested transaction block!
  # See http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Nested+transactions
  #
  # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter]
  # @param callback   [#call] Callback to be executed
  # @return           void
  # @raise            [NotInTransaction] if called outside transaction.
  def after_rollback(connection: ActiveRecord::Base.connection, &callback)
    AfterCommitEverywhere.register_callback(
      connection: connection,
      name: __callee__,
      callback: callback,
      no_tx_action: :exception,
    )
  end

  class << self
    def register_callback(connection:, name:, no_tx_action:, callback:)
      raise ArgumentError, "Provide callback to #{name}" unless callback
      unless in_transaction?(connection)
        case no_tx_action
        when :warn_and_execute
          warn "#{name}: No transaction open. Executing callback immediately."
          return callback.call
        when :execute
          return callback.call
        when :exception
          raise NotInTransaction, "#{name} is useless outside transaction"
        end
      end
      wrap = Wrap.new(connection: connection, "#{name}": callback)
      connection.add_transaction_record(wrap)
    end

    private

    def in_transaction?(connection)
      # service transactions (tests and database_cleaner) are not joinable
      connection.transaction_open? && connection.current_transaction.joinable?
    end
  end
end

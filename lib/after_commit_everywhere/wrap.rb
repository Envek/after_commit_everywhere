# frozen_string_literal: true

module AfterCommitEverywhere
  # ActiveRecord model-like class to fake ActiveRecord to make it believe
  # that it calls transactional callbacks on real model objects.
  class Wrap
    def initialize(connection: ActiveRecord::Base.connection, **handlers)
      @connection = connection
      @handlers = handlers
    end

    # rubocop: disable Naming/PredicateName
    def has_transactional_callbacks?
      true
    end
    # rubocop: enable Naming/PredicateName

    def before_committed!(*)
      @handlers[:before_commit]&.call
    end

    def committed!(*)
      @handlers[:after_commit]&.call
    end

    def rolledback!(*)
      @handlers[:after_rollback]&.call
    end

    # Required for +transaction(requires_new: true)+
    def add_to_transaction(*)
      @connection.add_transaction_record(self)
    end
  end
end

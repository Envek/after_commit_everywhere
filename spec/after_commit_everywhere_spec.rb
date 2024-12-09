# frozen_string_literal: true

RSpec.configure do |config|
  next unless config.respond_to?(:use_transactional_fixtures=)

  config.use_transactional_fixtures = false
end

RSpec.describe AfterCommitEverywhere do
  it "has a version number" do
    expect(AfterCommitEverywhere::VERSION).not_to be nil
  end

  let(:example_class) do
    Class.new do
      include ::AfterCommitEverywhere
      alias_method :aliased_after_commit, :after_commit
    end
  end
  let(:handler) { spy("handler") }

  describe "#after_commit" do
    subject do
      example_class.new.after_commit do
        handler.call
        expect(ActiveRecord::Base.connection.transaction_open?).to(be_falsey) if ActiveRecord::Base.connection_pool.active_connection?
      end
    end

    context "within transaction" do
      let(:handler_1) { spy("handler_1") }
      let(:handler_2) { spy("handler_2") }

      context 'when prepend is true' do
        it 'executes prepended callback first' do
          ActiveRecord::Base.transaction do
            example_class.new.after_commit { handler_1.call }
            example_class.new.after_commit(prepend: true) { handler_2.call }
          end
          expect(handler_2).to have_received(:call).ordered
          expect(handler_1).to have_received(:call).ordered
        end

        it 'works even if it is the first callback in transaction' do
          expect do
            ActiveRecord::Base.transaction do
              example_class.new.after_commit(prepend: true) { handler_2.call }
              example_class.new.after_commit { handler_1.call }
            end
          end.not_to raise_error
          expect(handler_2).to have_received(:call).ordered
          expect(handler_1).to have_received(:call).ordered
        end
      end

      context 'when prepend is not specified' do
        it 'executes callbacks in the order they were defined' do
          ActiveRecord::Base.transaction do
            example_class.new.after_commit { handler_1.call }
            example_class.new.after_commit { handler_2.call }
          end
          expect(handler_1).to have_received(:call).ordered
          expect(handler_2).to have_received(:call).ordered
        end
      end

      it "executes code only after commit" do
        ActiveRecord::Base.transaction do
          subject
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute callback on rollback" do
        ActiveRecord::Base.transaction do
          subject
          raise ActiveRecord::Rollback
        end
        expect(handler).not_to have_received(:call)
      end

      context "aliased DSL method" do
        subject do
          example_class.new.aliased_after_commit do
            handler.call
            expect(ActiveRecord::Base.connection.transaction_open?).to be_falsey
          end
        end

        it "executes code only after commit" do
          ActiveRecord::Base.transaction do
            subject
            expect(handler).not_to have_received(:call)
          end
          expect(handler).to have_received(:call)
        end
      end

      it 'propagates an error raised in one of multiple callbacks' do
        expect do
          ActiveRecord::Base.transaction do
            example_class.new.after_commit { raise 'this should prevent other callbacks being executed' }
            example_class.new.after_commit { handler_1.call }
            example_class.new.after_commit { handler_2.call }
          end
        end.to raise_error('this should prevent other callbacks being executed')
        expect(handler_1).not_to have_received(:call)
        expect(handler_2).not_to have_received(:call)
      end
    end

    context "without transaction" do
      let(:without_tx) { nil }

      subject do
        example_class.new.after_commit(**{without_tx: without_tx}.compact) do
          handler.call
          expect(ActiveRecord::Base.connection.transaction_open?).to be_falsey
        end
      end

      it "executes code immediately" do
        subject
        expect(handler).to have_received(:call)
      end

      it "doesn't print any warnings as it is expected behaviour" do
        expect { subject }.not_to output.to_stderr
      end

      context "with without_tx set to WARN_AND_EXECUTE" do
        it "logs a warning and executes the block" do
          expect { subject }.to output(anything).to_stderr
          expect(handler).to have_received(:call)
        end
      end

      context "with without_tx set to RAISE" do
        let(:without_tx) { described_class::RAISE }

        it "raises an exception" do
          expect { subject }.to raise_error(
            AfterCommitEverywhere::NotInTransaction
          )
          expect(handler).not_to have_received(:call)
        end
      end

      context "with without_tx set to an invalid value" do
        let(:without_tx) { "INVALID-NO-TX-ACTION" }

        it "raises an execption" do
          expect { subject }.to raise_error(
            ArgumentError,
            "Invalid \"without_tx\": \"INVALID-NO-TX-ACTION\""
          )
          expect(handler).not_to have_received(:call)
        end
      end
    end

    context "with nested transactions" do
      it "executes code after commit of outer block of single transaction" do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "executes code after commit of outer block of nested transaction" do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute callback when rollback issued from :requires_new transaction" do
        outer_handler = spy("outer")
        ActiveRecord::Base.transaction do
          example_class.new.after_commit { outer_handler.call }
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
            raise ActiveRecord::Rollback
          end
        end
        expect(outer_handler).to have_received(:call)
        expect(handler).not_to have_received(:call)
      end

      it "executes callbacks when rollback issued from default nested transaction" do
        outer_handler = spy("outer")
        ActiveRecord::Base.transaction do
          described_class.after_commit { outer_handler.call }
          ActiveRecord::Base.transaction do
            raise ActiveRecord::Rollback
          end
        end
  
        expect(outer_handler).to have_received(:call)
        expect(handler).not_to have_received(:call)
      end
    end

    context "with transactions to different databases" do
      let(:subject) do
        example_class.new.after_commit(connection: AnotherDb.connection) do
          handler.call
        end
      end

      it "executes code after commit of its transaction" do
        ActiveRecord::Base.transaction do
          AnotherDb.transaction do
            subject
            expect(handler).not_to have_received(:call)
          end
          expect(handler).to have_received(:call)
        end
      end

      it "doesn't execute callback when rollback issued" do
        ActiveRecord::Base.transaction do
          AnotherDb.transaction do
            subject
            raise ActiveRecord::Rollback
          end
        end
        expect(handler).not_to have_received(:call)
      end
    end

    it "doesn't leak connections" do
      expect { subject }.not_to change { ActiveRecord::Base.connection_pool.connections.size }
    end

    context "when connection to the database isn't established" do
      before { ActiveRecord::Base.connection_pool.disconnect! }

      it "doesn't leak connections" do
        expect { subject }.not_to change { ActiveRecord::Base.connection_pool.connections.size }
      end
    end

    context "when connection to the database has been established in another thread" do
      before { ActiveRecord::Base.connection }

      it "doesn't leak connections" do
        expect { Thread.new { subject }.join }.not_to change { ActiveRecord::Base.connection_pool.connections.size }
      end
    end
  end

  describe "#before_commit" do
    subject do
      example_class.new.before_commit do
        handler.call
        expect(ActiveRecord::Base.connection.transaction_open?).to be_truthy
      end
    end

    if ActiveRecord::VERSION::MAJOR < 5
      it "fails because it is unsupported in Rails 4" do
        expect { subject }.to raise_error(NotImplementedError) do |ex|
          expect(ex.message).to match(/Rails 5\.0\+/)
        end
      end

      next
    end

    context "within transaction" do
      it "executes code only before commit" do
        ActiveRecord::Base.transaction do
          subject
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute callback on rollback" do
        ActiveRecord::Base.transaction do
          subject
          raise ActiveRecord::Rollback
        end
        expect(handler).not_to have_received(:call)
      end
    end

    context "without transaction" do
      let(:without_tx) { described_class::WARN_AND_EXECUTE }

      subject do
        example_class.new.before_commit(**{without_tx: without_tx}.compact) do
          handler.call
        end
      end

      it "executes code immediately" do
        subject
        expect(handler).to have_received(:call)
      end

      it "warns as it is unclear whether it is expected behaviour or not" do
        expect { subject }.to output(anything).to_stderr
      end

      context "with without_tx set to EXECUTE" do
        let(:without_tx) { described_class::EXECUTE }

        it "executes the handler without logging a warning" do
          expect { subject }.not_to output.to_stderr
          expect(handler).to have_received(:call)
        end
      end

      context "with without_tx set to RAISE" do
        let(:without_tx) { described_class::RAISE }

        it "raises an exception" do
          expect { subject }.to raise_error(
            AfterCommitEverywhere::NotInTransaction
          )
          expect(handler).not_to have_received(:call)
        end
      end

      context "with without_tx set to an invalid value" do
        let(:without_tx) { "INVALID-NO-TX-ACTION" }

        it "raises an execption" do
          expect { subject }.to raise_error(
            ArgumentError,
            "Invalid \"without_tx\": \"INVALID-NO-TX-ACTION\""
          )
          expect(handler).not_to have_received(:call)
        end
      end

      it "doesn't leak connections" do
        expect { subject }.not_to change { ActiveRecord::Base.connection_pool.connections.size }
      end

      context "when connection to the database isn't established" do
        before { ActiveRecord::Base.connection_pool.disconnect! }

        it "doesn't leak connections" do
          expect { subject }.not_to change { ActiveRecord::Base.connection_pool.connections.size }
        end
      end
    end

    context "with nested transactions" do
      it "executes code before commit of outer block of single transaction" do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "executes code before commit of outer block of nested transaction" do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute callback when rollback issued" do
        outer_handler = spy("outer")
        ActiveRecord::Base.transaction do
          example_class.new.before_commit { outer_handler.call }
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
            raise ActiveRecord::Rollback
          end
        end
        expect(outer_handler).to have_received(:call)
        expect(handler).not_to have_received(:call)
      end
    end

    context "with transactions to different databases" do
      let(:subject) do
        example_class.new.before_commit(connection: AnotherDb.connection) do
          handler.call
        end
      end

      it "executes code before commit of its transaction" do
        ActiveRecord::Base.transaction do
          AnotherDb.transaction do
            subject
            expect(handler).not_to have_received(:call)
          end
          expect(handler).to have_received(:call)
        end
      end

      it "doesn't execute callback when rollback issued" do
        ActiveRecord::Base.transaction do
          AnotherDb.transaction do
            subject
            raise ActiveRecord::Rollback
          end
        end
        expect(handler).not_to have_received(:call)
      end
    end
  end

  describe "#after_rollback" do
    subject { example_class.new.after_rollback { handler.call } }

    context "within transaction" do
      it "executes code only after rollback" do
        ActiveRecord::Base.transaction do
          subject
          expect(handler).not_to have_received(:call)
          raise ActiveRecord::Rollback
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute code on commit" do
        ActiveRecord::Base.transaction do
          subject
        end
        expect(handler).not_to have_received(:call)
      end
    end

    context "without transaction" do
      it "raises an exception" do
        expect { subject }.to \
          raise_error(AfterCommitEverywhere::NotInTransaction)
        expect(handler).not_to have_received(:call)
      end
    end

    context "with nested transactions" do
      it "executes code after rollback of whole single transaction" do
        outer_handler = spy("outer")
        begin
          ActiveRecord::Base.transaction do
            example_class.new.after_rollback { outer_handler.call }
            ActiveRecord::Base.transaction do
              subject
              raise "boom" # ActiveRecord::Rollback doesn't work here
              # see http://api.rubyonrails.org/classes/ActiveRecord/Transactions/ClassMethods.html#module-ActiveRecord::Transactions::ClassMethods-label-Nested+transactions
            end
          end
        rescue RuntimeError
          # Nothing to do here
        ensure
          expect(handler).to have_received(:call)
          expect(outer_handler).to have_received(:call)
        end
      end

      it "executes code after rollback of inner block of nested transaction" do
        outer_handler = spy("outer")
        ActiveRecord::Base.transaction do
          example_class.new.after_rollback { outer_handler.call }
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
            raise ActiveRecord::Rollback
          end
          expect(handler).to have_received(:call)
        end
        expect(outer_handler).not_to have_received(:call)
      end
    end

    context "with transactions to different databases" do
      let(:subject) do
        example_class.new.after_rollback(connection: AnotherDb.connection) do
          handler.call
        end
      end

      it "executes code after rollback of its transaction" do
        outer_handler = spy("outer")
        ActiveRecord::Base.transaction do
          example_class.new.after_rollback { outer_handler.call }
          AnotherDb.transaction do
            subject
            raise ActiveRecord::Rollback
          end
        end
        expect(handler).to have_received(:call)
        expect(outer_handler).not_to have_received(:call)
      end

      it "doesn't execute callback when another transaction rolled back" do
        ActiveRecord::Base.transaction do
          AnotherDb.transaction do
            subject
          end
          raise ActiveRecord::Rollback
        end
        expect(handler).not_to have_received(:call)
      end
    end
  end

  describe "#in_transaction?" do
    subject { example_class.new.in_transaction? }

    it "returns true when in transaction" do
      ActiveRecord::Base.transaction do
        is_expected.to be_truthy
      end
    end

    it "returns false when not in transaction" do
      is_expected.to be_falsey
    end
  end

  describe ".after_commit" do
    subject do
      described_class.after_commit do
        handler.call
        expect(ActiveRecord::Base.connection.transaction_open?).to be_falsey
      end
    end

    it "executes code only after commit" do
      ActiveRecord::Base.transaction do
        subject
        expect(handler).not_to have_received(:call)
      end
      expect(handler).to have_received(:call)
    end

    # Here we're checking only happy path. for other tests see "#after_commit"
  end

  describe ".after_rollback" do
    subject { described_class.after_rollback { handler.call } }

    it "executes code only after rollback" do
      ActiveRecord::Base.transaction do
        subject
        expect(handler).not_to have_received(:call)
        raise ActiveRecord::Rollback
      end
      expect(handler).to have_received(:call)
    end

    # Here we're checking only happy path. for other tests see "#after_rollback"
  end

  describe ".in_transaction?" do
    subject { described_class.in_transaction? }

    it "returns true when in transaction" do
      ActiveRecord::Base.transaction do
        is_expected.to be_truthy
      end
    end

    it "returns false when not in transaction" do
      is_expected.to be_falsey
    end
  end

  shared_examples "verify in_transaction behavior" do
    it "rollbacks propogate up to the top level transaction block" do
      outer_handler = spy("outer")
      ActiveRecord::Base.transaction do
        described_class.after_commit { outer_handler.call }
        receiver.in_transaction do
          raise ActiveRecord::Rollback
        end
      end

      expect(outer_handler).not_to have_received(:call)
      expect(handler).not_to have_received(:call)
    end

    it "runs in a new transaction if no wrapping transaction is available" do
      expect(ActiveRecord::Base.connection.transaction_open?).to be_falsey
      receiver.in_transaction do
        expect(ActiveRecord::Base.connection.transaction_open?).to be_truthy
      end
    end

    it "runs new transaction even inside existing transaction if requires_new is true" do
      outer_handler, inner_handler = spy("outter"), spy("inner")
      expect(ActiveRecord::Base.connection.transaction_open?).to be_falsey
      ActiveRecord::Base.transaction do
        expect(ActiveRecord::Base.connection.transaction_open?).to be_truthy
        described_class.after_commit { outer_handler.call }
        receiver.in_transaction(requires_new: true) do
          receiver.after_commit { inner_handler.call }
          raise ActiveRecord::Rollback
        end
      end
      expect(outer_handler).to have_received(:call)
      expect(inner_handler).not_to have_received(:call)
    end

    context "when rolling back, the rollback propogates to the parent transaction block" do
      subject { receiver.after_rollback { handler.call } }

      it "executes all after_rollback calls, even when raising an ActiveRecord::Rollback" do
        outer_handler = spy("outer")
        ActiveRecord::Base.transaction do
          receiver.after_rollback { outer_handler.call }
          described_class.in_transaction do
            subject
            # ActiveRecord::Rollback works here because `in_transaction` yields without creating a new nested transaction
            raise ActiveRecord::Rollback
          end
        end

        expect(handler).to have_received(:call)
        expect(outer_handler).to have_received(:call)
      end
    end
  end

  describe "#in_transaction" do
    let(:receiver) { example_class.new }
    include_examples "verify in_transaction behavior"
  end

  describe ".in_transaction" do
    let(:receiver) { described_class }
    include_examples "verify in_transaction behavior"
  end
end

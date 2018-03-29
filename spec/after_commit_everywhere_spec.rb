# frozen_string_literal: true

RSpec.describe AfterCommitEverywhere do
  it 'has a version number' do
    expect(AfterCommitEverywhere::VERSION).not_to be nil
  end

  let(:example_class) { Class.new.include(described_class) }
  let(:handler) { spy('handler') }

  describe '#after_commit' do
    subject do
      example_class.new.after_commit do
        handler.call
        expect(ActiveRecord::Base.connection.transaction_open?).to be_falsey
      end
    end

    context 'within transaction' do
      it 'executes code only after commit' do
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

    context 'without transaction' do
      it 'executes code immediately' do
        subject
        expect(handler).to have_received(:call)
      end

      it "doesn't print any warnings as it is expected behaviour" do
        expect { subject }.not_to output.to_stderr
      end
    end

    context 'with nested transactions' do
      it 'executes code after commit of outer block of single transaction' do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it 'executes code after commit of outer block of nested transaction' do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute callback when rollback issued" do
        outer_handler = spy('outer')
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
    end

    context 'with transactions to different databases' do
      let(:subject) do
        example_class.new.after_commit(connection: AnotherDb.connection) do
          handler.call
        end
      end

      it 'executes code after commit of its transaction' do
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

  describe '#before_commit' do
    subject do
      example_class.new.before_commit do
        handler.call
        expect(ActiveRecord::Base.connection.transaction_open?).to be_truthy
      end
    end

    context 'within transaction' do
      it 'executes code only before commit' do
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

    context 'without transaction' do
      subject { example_class.new.before_commit { handler.call } }

      it 'executes code immediately' do
        subject
        expect(handler).to have_received(:call)
      end

      it 'warns as it is unclear whether it is expected behaviour or not' do
        expect { subject }.to output(anything).to_stderr
      end
    end

    context 'with nested transactions' do
      it 'executes code before commit of outer block of single transaction' do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it 'executes code before commit of outer block of nested transaction' do
        ActiveRecord::Base.transaction do
          ActiveRecord::Base.transaction(requires_new: true) do
            subject
          end
          expect(handler).not_to have_received(:call)
        end
        expect(handler).to have_received(:call)
      end

      it "doesn't execute callback when rollback issued" do
        outer_handler = spy('outer')
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

    context 'with transactions to different databases' do
      let(:subject) do
        example_class.new.before_commit(connection: AnotherDb.connection) do
          handler.call
        end
      end

      it 'executes code before commit of its transaction' do
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

  describe '#after_rollback' do
    subject { example_class.new.after_rollback { handler.call } }

    context 'within transaction' do
      it 'executes code only after rollback' do
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

    context 'without transaction' do
      it 'raises an exception' do
        expect { subject }.to \
          raise_error(AfterCommitEverywhere::NotInTransaction)
        expect(handler).not_to have_received(:call)
      end
    end

    context 'with nested transactions' do
      it 'executes code after rollback of whole single transaction' do
        outer_handler = spy('outer')
        begin
          ActiveRecord::Base.transaction do
            example_class.new.after_rollback { outer_handler.call }
            ActiveRecord::Base.transaction do
              subject
              raise 'boom' # ActiveRecord::Rollback doesn't work here
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

      it 'executes code after rollback of inner block of nested transaction' do
        outer_handler = spy('outer')
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

    context 'with transactions to different databases' do
      let(:subject) do
        example_class.new.after_rollback(connection: AnotherDb.connection) do
          handler.call
        end
      end

      it 'executes code after rollback of its transaction' do
        outer_handler = spy('outer')
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
end

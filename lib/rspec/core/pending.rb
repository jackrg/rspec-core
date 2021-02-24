module RSpec
  module Core
    # Provides methods to mark examples as pending. These methods are available
    # to be called from within any example or hook.
    module Pending
      # Raised in the middle of an example to indicate that it should be marked
      # as skipped.
      class SkipDeclaredInExample < StandardError
        attr_reader :argument

        def initialize(argument)
          @argument = argument
        end
      end

      # If Test::Unit is loaded, we'll use its error as baseclass, so that
      # Test::Unit will report unmet RSpec expectations as failures rather than
      # errors.
      begin
        class PendingExampleFixedError < Test::Unit::AssertionFailedError; end
      rescue
        class PendingExampleFixedError < StandardError; end
      end

      # @private
      NO_REASON_GIVEN = 'No reason given'

      # @private
      NOT_YET_IMPLEMENTED = 'Not yet implemented'

      # @overload pending()
      # @overload pending(message)
      #
      # Marks an example as pending. The rest of the example will still be
      # executed, and if it passes the example will fail to indicate that the
      # pending can be removed.
      #
      # @param message [String] optional message to add to the summary report.
      #
      # @example
      #     describe "some behaviour" do
      #       # reported as "Pending: no reason given"
      #       it "is pending with no message" do
      #         pending
      #         raise "broken"
      #       end
      #
      #       # reported as "Pending: something else getting finished"
      #       it "is pending with a custom message" do
      #         pending("something else getting finished")
      #         raise "broken"
      #       end
      #     end
      #
      # @note When using `pending` inside an example body using this method
      # hooks such as `before(:example) have already be run, this means that
      # a failure from the code in the `before` hook will prevent the example
      # from being considered as pending, as the example body wouldn't be
      # executed. If you need to consider hooks as pending as well you can use
      # the pending metadata as an alternative, e.g. `it "does something", pending: "message".`
      #
      #     describe "SomeClass" do
      #       pending "does not implement something yet" do
      #         # ...
      #       end
      #     end
      #
      #   or specify metadata on an example:
      #
      #     it "does this", :pending => "is not yet implemented" do
      #        # ...
      #     end
      #
      #   even without an explicit pending message:
      #
      #     it "does something", :pending do
      #       # ...
      #     end
      #
      # @note There is a difference between using `pending` inside the example
      # body and `pending` example group alias/`pending` metadata. In the case
      # when the failure is caused by the code in the `before` hook, the example
      # would not be considered pending, as the example body wouldn't be reached.
      # If you intend the failure in the `before` hook to be considered a part
      # of the example, use the latter.
      #
      # @example Failure in `before` hook causes the example to fail
      #     before { fail 'BOOM' }
      #     it 'fails' do
      #       pending 'this never gets executed'
      #     end
      #
      #     pending 'is considered pending' do
      #       not_implemented
      #     end
      def pending(message=nil)
        current_example = RSpec.current_example

        if block_given?
          raise ArgumentError, <<-EOS.gsub(/^\s+\|/, '')
            |The semantics of `RSpec::Core::Pending#pending` have changed in
            |RSpec 3. In RSpec 2.x, it caused the example to be skipped. In
            |RSpec 3, the rest of the example is still run but is expected to
            |fail, and will be marked as a failure (rather than as pending) if
            |the example passes.
            |
            |Passing a block within an example is now deprecated. Marking the
            |example as pending provides the same behavior in RSpec 3 which was
            |provided only by the block in RSpec 2.x.
            |
            |Move the code in the block provided to `pending` into the rest of
            |the example body.
            |
            |Called from #{CallerFilter.first_non_rspec_line}.
            |
          EOS
        elsif current_example
          Pending.mark_pending! current_example, message
        else
          raise "`pending` may not be used outside of examples, such as in " \
                "before(:context). Maybe you want `skip`?"
        end
      end

      # @overload skip()
      # @overload skip(message)
      #
      # Marks an example as pending and skips execution.
      #
      # @param message [String] optional message to add to the summary report.
      #
      # @example
      #     describe "an example" do
      #       # reported as "Pending: no reason given"
      #       it "is skipped with no message" do
      #         skip
      #       end
      #
      #       # reported as "Pending: something else getting finished"
      #       it "is skipped with a custom message" do
      #         skip "something else getting finished"
      #       end
      #     end
      def skip(message=nil)
        current_example = RSpec.current_example

        Pending.mark_skipped!(current_example, message) if current_example

        raise SkipDeclaredInExample.new(message)
      end

      # @private
      #
      # Mark example as skipped.
      #
      # @param example [RSpec::Core::Example] the example to mark as skipped
      # @param message_or_bool [Boolean, String] the message to use, or true
      def self.mark_skipped!(example, message_or_bool)
        Pending.mark_pending! example, message_or_bool
        example.metadata[:skip] = true
      end

      # @private
      #
      # Mark example as pending.
      #
      # @param example [RSpec::Core::Example] the example to mark as pending
      # @param message_or_bool [Boolean, String] the message to use, or true
      def self.mark_pending!(example, message_or_bool)
        message = if !message_or_bool || !(String === message_or_bool)
                    NO_REASON_GIVEN
                  else
                    message_or_bool
                  end

        example.metadata[:pending] = true
        example.execution_result.pending_message = message
        example.execution_result.pending_fixed = false
      end

      # @private
      #
      # Mark example as fixed.
      #
      # @param example [RSpec::Core::Example] the example to mark as fixed
      def self.mark_fixed!(example)
        example.execution_result.pending_fixed = true
      end
    end
  end
end

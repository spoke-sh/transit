# frozen_string_literal: true
module Transit
  module Internal
    class Ticket
      def initialize
        @mutex, @ready, @done = Mutex.new, ConditionVariable.new, false
      end
      def complete(value, error)
        @mutex.synchronize { @value, @error, @done = value, error, true; @ready.broadcast }
      end
      def value
        @mutex.synchronize do
          @ready.wait(@mutex) until @done
          raise @error if @error
          @value
        end
      end
    end

    # Internal package interface shared with Station. Cancelling a controller's
    # wait cannot cancel or disown the one admitted job on this worker.
    class Worker
      attr_reader :evidence
      def initialize(&factory)
        @mutex, @queue = Mutex.new, SizedQueue.new(1)
        @busy, @closed = false, false
        ready = Ticket.new
        Thread.handle_interrupt(Exception => :never) do
          @thread = Thread.new do
            Thread.current.report_on_exception = false
            state = nil
            begin
              state = factory.call
              ready.complete(true, nil)
              while (job = @queue.pop)
                ticket, work = job
                result = error = nil
                begin
                  result = work.call(state)
                rescue Exception => caught # Preserve callback/control failure outside the native process.
                  error = caught
                ensure
                  @mutex.synchronize { @busy = false }
                  ticket.complete(result, error)
                end
              end
            rescue Exception => error
              ready.complete(nil, error)
            ensure
              if state
                begin
                  @evidence = state.evidence
                rescue Exception => error
                  @cleanup_error = error
                ensure
                  begin
                    state.close
                  rescue Exception => error
                    @cleanup_error ||= error
                  end
                end
              end
            end
          end
          begin
            ready.value
          rescue Exception
            @thread.join
            raise
          end
        end
      end
      def call(&work)
        ticket = nil
        Thread.handle_interrupt(Exception => :never) do
          @mutex.synchronize do
            raise Closed, 'Client or runner is closed' if @closed
            raise Busy, 'One admitted operation per client or runner' if @busy || Thread.current == @thread
            @busy = true
            ticket = Ticket.new
            @queue.push([ticket, work])
          end
        end
        ticket.value
      end
      def close
        raise Busy, 'A callback cannot join its own worker' if Thread.current == @thread
        Thread.handle_interrupt(Exception => :never) do
          first = @mutex.synchronize { previous = @closed; @closed = true; !previous }
          @queue.push(nil) if first
          @thread.join
          raise CleanupError.new(@evidence), cause: @cleanup_error if @cleanup_error
          @evidence
        end
      end
    end
  end
end

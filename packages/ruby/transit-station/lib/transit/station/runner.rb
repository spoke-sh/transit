# frozen_string_literal: true
module Transit
  module Station
    class Handler
      def on_start(_turn); end
      def on_message(_turn, _input) = raise HandlerError, 'No message handler'
      def on_control(_turn, _input) = raise HandlerError, 'No control handler'
      def on_result(_turn, _input) = raise HandlerError, 'No query result handler'
    end
    class Runner
      class State
        def initialize(config, handler, codec, failure, recovery, stop)
          unless recovery == :fence_on_restart || %i[before_dispatch confirmed].all? { |method| recovery.respond_to?(method) }
            raise ArgumentError, 'Select fence_on_restart or provide a recovery store'
          end
          @bridge = Bridge.open(config, failure)
          @handler, @codec, @failure, @store, @stop = handler, codec, failure, recovery == :fence_on_restart ? nil : recovery, stop
          @process = config.activation.process
          @attempted = false
        end
        def record(event) = @last_event = event
        def pause(error, phase, receipt = nil)
          @paused = record(NeedsRecovery.new(mutation: @pending, phase: phase, error: error, receipt: receipt))
        end
        def accept(event)
          @confirmed = event
          value = event['confirmation']
          unless value && value['kind'] == @pending.purpose.to_s && value['input'] == @pending.input_position
            return pause(IncompatibleNative.new('Confirmation identity mismatch'), :confirm)
          end
          begin
            receipt = MutationReceipt.new(position: value.fetch('receipt').fetch('position'))
          rescue StandardError
            return pause(IncompatibleNative.new('Invalid confirmation receipt'), :confirm)
          end
          if @store
            begin
              @store.confirmed(@pending.identity, receipt)
            rescue Exception => error
              return pause(error, :confirm, receipt)
            end
          end
          outcome = if event['event'] == 'blocked'
                      Blocked.new(input: @pending.input_position, receipt: receipt)
                    elsif @pending.purpose == :commit
                      Committed.new(input: @pending.input_position, receipt: receipt)
                    else Progress.new
                    end
          @pending = @confirmed = @paused = nil
          @attempted = false
          record(outcome)
        end
        def attempt
          raise Closed, 'No pending mutation' unless @pending
          return accept(@confirmed) if @confirmed
          if @attempted
            begin
              event = @bridge.confirmation(@pending)
              return accept(event) if event
            rescue Error => error
              return pause(error, :observe_confirmation)
            end
          end
          return nil if @stop.stopped?
          if @store
            begin
              @store.before_dispatch(@pending)
            rescue Exception => error
              return pause(error, :persist)
            end
          end
          return nil if @stop.stopped?
          @attempted = true
          begin
            accept(@bridge.dispatch)
          rescue Error => error
            pause(error, :dispatch)
          end
        end
        def handle(event)
          turn = Turn.new(@bridge, event, @process, @stop)
          failure = nil
          begin
            input = event.fetch('input')
            kind = input.fetch('kind')
            metadata = { position: input.fetch('position'), origin: Value.origin(input.fetch('origin'), @process.realm) }
            decoded = case kind
                      when 'cast', 'call', 'reply'
                        value = Value.decode(@codec, Internal.unhex(input.fetch('payload'), @bridge.caps.fetch('message_bytes')), @bridge.caps.fetch('message_bytes'))
                        if kind == 'cast'
                          Cast.new(value: value, **metadata)
                        else
                          (kind == 'call' ? Call : Reply).new(value: value, correlation: Value.wide(input.fetch('correlation'), min: 1), **metadata)
                        end
                      when 'cancel', 'timeout'
                        Control.new(kind: kind.to_sym, correlation: Value.wide(input.fetch('correlation'), min: 1), **metadata)
                      when 'result_complete'
                        ResultComplete.new(correlation: Value.wide(input.fetch('correlation'), min: 1), **metadata)
                      else raise HandlerError, 'Unsupported native input'
                      end
            @handler.on_start(turn) if event.fetch('initializing') && !@stop.stopped?
            unless @stop.stopped?
              case decoded
              when Control then @handler.on_control(turn, decoded)
              when ResultComplete then @handler.on_result(turn, decoded)
              else @handler.on_message(turn, decoded)
              end
            end
          rescue Exception => error
            failure = error.is_a?(Error) ? error : HandlerError.new('Handler callback failed')
          ensure
            turn.__send__(:end_scope!)
          end
          scope = turn.__send__(:scope)
          if @stop.stopped?
            @bridge.discard(scope)
            return false
          end
          if (poison = turn.__send__(:poison))
            @bridge.discard(scope)
            raise poison
          end
          begin
            @bridge.finish(scope, !failure.nil?)
          rescue Error => error
            raise failure if failure && @failure == :stop && error.code == 'ForeignHandlerFailure'
            raise
          end
          true
        end
        def next
          return @paused if @paused
          return nil if @stop.stopped?
          return attempt if @pending
          16.times do
            return nil if @stop.stopped?
            event = @bridge.prepare
            case event.fetch('event')
            when 'pending'
              @pending = @bridge.pending(event)
              return attempt
            when 'idle' then return record(Idle.new)
            when 'blocked' then return record(Blocked.new(input: nil, receipt: nil))
            when 'ready' then return nil unless handle(event)
            when 'progress' then next
            else raise IncompatibleNative, 'Unknown native event'
            end
          end
          record(Progress.new)
        end
        def evidence = Shutdown.new(pending: @pending, last_event: @last_event)
        def document_read(action)
          raise Busy, 'Resolve the saved mutation before reading Documents' if @pending
          @bridge.document_read(action)
        end
        def document_codec(action) = @bridge.document_codec(action)
        def http_read(action)
          raise Busy, 'Resolve the saved mutation before reading HTTP capture' if @pending
          @bridge.http_read(action)
        end
        def http_open(outcome, policy)
          unless outcome.is_a?(HttpOutcome) && outcome.phase == :observed && outcome.reference && outcome.resource.realm == @process.realm
            raise ArgumentError, 'Expected a complete HTTP outcome in this realm'
          end
          raise ArgumentError, 'Select an HTTP replay policy' unless %i[captured require_unredacted].include?(policy)
          http_read({ 'open' => { 'reference' => outcome.reference.unpack1('H*'), 'policy' => policy.to_s } }).fetch('opened')
        end
        def grpc_read(action)
          raise Busy, 'Resolve the saved mutation before reading RPC capture' if @pending
          @bridge.grpc_read(action)
        end
        def grpc_open(outcome, policy)
          unless outcome.is_a?(GrpcOutcome) && outcome.phase == :observed && outcome.reference && outcome.resource.realm == @process.realm
            raise ArgumentError, 'Expected a complete RPC outcome in this realm'
          end
          raise ArgumentError, 'Select an RPC replay policy' unless %i[captured require_unredacted].include?(policy)
          grpc_read({ 'open' => { 'reference' => outcome.reference.unpack1('H*'), 'policy' => policy.to_s } }).fetch('opened')
        end
        def close = @bridge.close
      end
      private_constant :State
      attr_reader :stop_token
      def self.open(config, **options)
        return new(config, **options) unless block_given?
        Thread.handle_interrupt(Object => :never) do
          runner = new(config, **options)
          begin
            Thread.handle_interrupt(Object => :immediate) { yield runner }
          ensure
            runner.close
          end
        end
      end
      def initialize(config, handler:, codec:, failure: :stop, recovery: :fence_on_restart)
        raise ArgumentError, 'Expected ServiceConfig' unless config.is_a?(ServiceConfig)
        @realm = config.activation.process.realm
        @stop_token = StopToken.new
        @worker = Internal::Worker.new { State.new(config, handler, codec, failure, recovery, @stop_token) }
      end
      def next = @worker.call(&:next)
      def reconcile = @worker.call(&:attempt)
      def evidence = @shutdown || @worker.call(&:evidence)
      def stop = stop_token.stop
      def documents
        DocumentReader.new(@realm, ->(action) { @worker.call { |state| state.document_read(action) } },
          ->(action) { @worker.call { |state| state.document_codec(action) } })
      end
      def http_diagnostic(outcome, kind: :capture_failure)
        raise ArgumentError, 'Expected a Http outcome in this realm' unless outcome.is_a?(HttpOutcome) && outcome.resource.realm == @realm
        raise ArgumentError, 'Invalid exchange diagnostic kind' unless %i[capture_failure native_effect].include?(kind)
        @worker.call do |state|
          value = state.http_read({ 'diagnostic' => { 'identity' => { 'resource' => outcome.resource.resource, 'exchange' => outcome.exchange.to_s }, 'kind' => kind.to_s } }).fetch('diagnostic')
          value.nil? ? nil : Value.diagnostic(value)
        end
      end
      def open_http(outcome, policy: :captured)
        # Avoid interruption between acquiring the native slot and returning its
        # wrapper. The enclosing runner owns joined cleanup after host wait loss.
        Thread.handle_interrupt(Object => :never) do
          identity = @worker.call { |state| state.http_open(outcome, policy) }
          HttpReader.new(identity) { |action| @worker.call { |state| state.http_read(action) } }
        end
      end
      def grpc_diagnostic(outcome, kind: :capture_failure)
        raise ArgumentError, 'Expected a Grpc outcome in this realm' unless outcome.is_a?(GrpcOutcome) && outcome.resource.realm == @realm
        raise ArgumentError, 'Invalid exchange diagnostic kind' unless %i[capture_failure native_effect].include?(kind)
        @worker.call do |state|
          value = state.grpc_read({ 'diagnostic' => { 'identity' => { 'resource' => outcome.resource.resource, 'exchange' => outcome.exchange.to_s }, 'kind' => kind.to_s } }).fetch('diagnostic')
          value.nil? ? nil : Value.diagnostic(value)
        end
      end
      def open_grpc(outcome, policy: :captured)
        # Avoid interruption between acquiring the native slot and returning its
        # wrapper. The enclosing runner owns joined cleanup after host wait loss.
        Thread.handle_interrupt(Object => :never) do
          identity = @worker.call { |state| state.grpc_open(outcome, policy) }
          GrpcReader.new(identity) { |action| @worker.call { |state| state.grpc_read(action) } }
        end
      end
      def each
        return enum_for(:each) unless block_given?
        while (event = self.next)
          yield event
          break if event.is_a?(NeedsRecovery)
        end
      end
      def close
        @worker.check_close!
        stop
        @shutdown ||= @worker.close
      end
    end
  end
end

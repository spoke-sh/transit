# frozen_string_literal: true
require_relative 'client/values'
require_relative 'client/worker'
require_relative 'client/port'
require_relative 'client/operations'

module Transit
  class Client
    VERSION = '0.0.1'
    class State
      attr_reader :port
      attr_accessor :last_admission, :last_mutation
      def initialize(config)
        executable = config.native_host
        unless executable
          require 'transit/native_client'
          raise IncompatibleNative, 'Native gem version mismatch' unless NativeClient::VERSION == VERSION
          executable = NativeClient::HOST
        end
        schemas = Internal::SCHEMAS
        @port = Internal::Port.new(executable, { 'url' => config.url, 'timeout_ms' => config.timeout_ms }, schemas, 'ClientHostRequest')
        begin
          hello = port.request({ 'hello' => {} }, phase: :hello)
          unless hello == { 'host_version' => 1, 'transit_version' => 1 }
            raise IncompatibleNative, 'Native client protocol version mismatch'
          end
          caps = port.request({ 'capabilities' => {} }, phase: :native_capabilities, response: 'ClientCapabilities')
          unless caps['version'] == 1 && %w[operation_metadata opaque_retry native_v1].all? { |name| caps[name] } &&
                 caps['max_line_bytes'] == Internal::LIMITS['host_line_bytes'] && caps['value_bytes'] == Internal::LIMITS['value_bytes'] &&
                 caps['max_counter'] == Internal::LIMITS['max_counter']
            raise UnsupportedCapability, 'Native client lacks the required operation/profile capabilities'
          end
        rescue Exception
          port.close
          raise
        end
      rescue LoadError
        raise IncompatibleNative, 'Install transit-native-client 0.0.1 or supply native_host'
      end
      def evidence = Shutdown.new(last_admission: last_admission, last_mutation: last_mutation)
      def close = port.close
    end
    private_constant :State

    def self.open(config)
      return new(config) unless block_given?
      Thread.handle_interrupt(Object => :never) do
        client = new(config)
        begin
          Thread.handle_interrupt(Object => :immediate) { yield client }
        ensure
          client.close
        end
      end
    end
    def initialize(config)
      raise ArgumentError, 'Expected ClientConfig' unless config.is_a?(ClientConfig)
      @worker = Internal::Worker.new { State.new(config) }
    end
    def capabilities(credential)
      raise ArgumentError, 'Expected Credential' unless credential.is_a?(Credential)
      @worker.call { |state| Internal.authority_capabilities(state.port, credential) }
    end
    def prepare_send(peer, value, credential:, sequence:)
      raise ArgumentError, 'Expected ProcessRef and Credential' unless peer.is_a?(ProcessRef) && credential.is_a?(Credential)
      raise ArgumentError, 'Peer and credential must share a realm' unless peer.realm == credential.realm
      payload = Internal.bytes(value, Internal::LIMITS.fetch('value_bytes'))
      next_sequence = Internal.integer(sequence)
      @worker.call do |state|
        bytes = Internal.prepare(state.port, 6, credential, { 'realm' => credential.realm, 'principal' => credential.principal,
          'sequence' => next_sequence, 'command' => { 'send' => { 'pid' => peer.pid, 'value' => payload.unpack1('H*') } } })
        Internal.recover(state.port, bytes, send_only: true)
      end
    end
    def recover_send(value)
      bytes = Internal.bytes(value)
      @worker.call { |state| Internal.recover(state.port, bytes, send_only: true) }
    end
    def recover_mutation(value)
      bytes = Internal.bytes(value)
      @worker.call { |state| Internal.recover(state.port, bytes, send_only: false) }
    end
    def dispatch(pending)
      raise ArgumentError, 'Expected PendingSend' unless pending.is_a?(PendingSend)
      exchange(pending.export, true)
    end
    def dispatch_mutation(pending)
      raise ArgumentError, 'Expected PendingMutation' unless pending.is_a?(PendingMutation)
      exchange(pending.export, false)
    end
    def evidence = @shutdown || @worker.call(&:evidence)
    def close = @shutdown ||= @worker.close

    private
    def exchange(bytes, send_only)
      @worker.call do |state|
        Internal.recover(state.port, bytes, send_only: send_only)
        send_only ? state.last_admission = nil : state.last_mutation = nil
        begin
          value = state.port.request({ 'call' => Internal.text(bytes) }, phase: :dispatch, mutation: true)
          position = Internal.integer(Internal.hash(value)['position'])
          if send_only
            state.last_admission = AdmissionReceipt.new(position: position)
            Admitted.new(receipt: state.last_admission)
          else
            state.last_mutation = MutationReceipt.new(position: position)
            Confirmed.new(receipt: state.last_mutation)
          end
        rescue AuthorityRejected => error
          Rejected.new(error: error)
        rescue UnknownOutcome => error
          Uncertain.new(bytes, error)
        rescue IncompatibleNative, ArgumentError
          Uncertain.new(bytes, UnknownOutcome.new('Invalid mutation receipt', status: 6, phase: :receipt))
        end
      end
    end
  end
end

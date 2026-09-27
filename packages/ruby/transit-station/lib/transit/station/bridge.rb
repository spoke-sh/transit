# frozen_string_literal: true
module Transit
  module Station
    class Bridge
      attr_reader :port, :caps
      def self.local(native_host = nil) = new({ 'local_codec' => true }, native_host)
      def self.open(config, failure)
        raise ArgumentError, 'Select stop or block_input' unless %i[stop block_input].include?(failure)
        activation, client = config.activation, config.client
        bridge = new({ 'url' => client.url, 'seed_file' => activation.credential.seed_file, 'timeout_ms' => client.timeout_ms,
          'growing_server' => { 'profile' => 'growing_v3', 'realm' => activation.process.realm, 'principal' => activation.credential.principal,
            'pid' => activation.process.pid, 'generation' => activation.generation, 'association' => config.association,
            'timeout_ms' => client.timeout_ms, 'failure_policy' => failure.to_s, 'query_results' => config.query_results } }, client.native_host)
        begin
          raise UnsupportedCapability, 'Native query results unavailable' if config.query_results && !bridge.caps['query_results']
          authority = Internal.authority_capabilities(bridge.port, activation.credential)
          unless authority.association_lookup && authority.scoped_retry && authority.retained_versions
            raise UnsupportedCapability, 'Authority lacks growing state/recovery primitives'
          end
          bridge
        rescue Exception
          bridge.close
          raise
        end
      end
      def initialize(configuration, executable)
        unless executable
          require 'transit/native_station'
          raise IncompatibleNative, 'Native Station gem version mismatch' unless NativeStation::VERSION == '0.2.0'
          executable = NativeStation::HOST
        end
        schemas = Internal::SCHEMAS.merge(JSON.parse(File.binread(File.join(__dir__, 'schemas.json'))))
        @port = Internal::Port.new(executable, configuration, schemas, 'HostRequest')
        begin
          hello = port.request({ 'hello' => {} }, phase: :hello)
          unless hello == { 'host_version' => 1, 'station_version' => 1, 'transit_version' => 1 }
            raise IncompatibleNative, 'Native Station protocol version mismatch'
          end
          @caps = port.request({ 'growing_capabilities' => {} }, phase: :native_capabilities, response: 'GrowingCapabilities').freeze
          unless caps['version'] == 1 && caps['profile'] == 'growing_v3' &&
                 %w[gated_dispatch retained_confirmation scoped_turns paged_state tables retained_sources].all? { |name| caps[name] }
            raise UnsupportedCapability, 'Native Station lacks required capabilities'
          end
        rescue Exception
          port.close
          raise
        end
      rescue LoadError
        raise IncompatibleNative, 'Install transit-native-station 0.2.0 or supply native_host'
      end
      def prepare
        port.request({ 'growing_prepare' => (Time.now.to_r * 1000).to_i + 30_000 }, phase: :prepare_turn, response: 'GrowingEvent')
      end
      def apply(scope, action)
        port.request({ 'growing_apply' => { 'scope' => scope, 'action' => action } }, phase: :apply, response: 'GrowingResult')
      end
      def document_codec(action)
        raise UnsupportedCapability, 'Native Document codecs unavailable' unless caps['document_codecs']
        port.request({ 'document_codec' => action }, phase: :document_codec, response: 'DocumentCodecResult')
      end
      def document_read(action)
        raise UnsupportedCapability, 'Native Document reads unavailable' unless caps['document_reads']
        port.request({ 'growing_document_read' => action }, phase: :document_read, response: 'DocumentReadResult')
      end
      def http_codec(action, release: false)
        raise UnsupportedCapability, 'Native HTTP requests unavailable' unless caps['http_requests']
        raise UnsupportedCapability, 'Native HTTP disposal unavailable' if release && !caps['http_release']
        port.request({ 'http_codec' => action }, phase: :http_codec, response: 'HttpCodecResult')
      end
      def http_read(action)
        raise UnsupportedCapability, 'Native HTTP replay unavailable' unless caps['http_replay']
        port.request({ 'growing_http_read' => action }, phase: :http_read, response: 'HttpReadResult')
      end
      def grpc_codec(action, release: false)
        raise UnsupportedCapability, 'Native RPC requests unavailable' unless caps['grpc_requests']
        raise UnsupportedCapability, 'Native RPC disposal unavailable' if release && !caps['grpc_release']
        port.request({ 'grpc_codec' => action }, phase: :grpc_codec, response: 'GrpcCodecResult')
      end
      def grpc_read(action)
        raise UnsupportedCapability, 'Native RPC replay unavailable' unless caps['grpc_replay']
        port.request({ 'growing_grpc_read' => action }, phase: :grpc_read, response: 'GrpcReadResult')
      end
      def finish(scope, failed)
        port.request({ 'growing_finish_result' => { 'scope' => scope, 'failed' => failed } }, phase: :finish)
      end
      def discard(scope) = port.request({ 'growing_discard' => scope }, phase: :discard)
      def dispatch = port.request({ 'growing_dispatch' => {} }, phase: :dispatch, mutation: true, response: 'GrowingEvent')
      def pending(event)
        purpose = event.fetch('pending_kind').to_sym
        bytes = Internal.bytes(Internal.text(port.request({ 'growing_pending' => {} }, phase: :pending)))
        info = Internal.metadata(port, bytes)
        commands = { permit: %w[begin_turn], open: %w[open_view], commit: %w[turn turn_with_versions] }
        unless info['kind'] == 'growing_command' && info['profile'] == 'growing_v3' && commands.fetch(purpose, []).include?(info['command'])
          raise IncompatibleNative, 'Pending mutation differs from its native purpose'
        end
        FrozenMutation.new(OperationIdentity.new(sha256: info['identity']), purpose, event.fetch('pending_input'), bytes)
      end
      def confirmation(pending)
        event = port.request({ 'growing_confirmation' => {} }, phase: :observe_confirmation, response: 'GrowingEvent')
        value = event['confirmation']
        value && value['kind'] == pending.purpose.to_s && value['input'] == pending.input_position ? event : nil
      rescue TurnExpired
        nil
      end
      def evidence = nil
      def close = port.close
    end
    private_constant :Bridge
    def self.encode_cast(value, codec:, native_host: nil)
      worker = Internal::Worker.new { Bridge.local(native_host) }
      begin
        bound = worker.call { |bridge| bridge.caps.fetch('message_bytes') }
        bytes = Value.encode(codec, value, bound)
        worker.call do |bridge|
          encoded = bridge.port.request({ 'frame' => { 'kind' => 1, 'correlation' => '0', 'payload' => bytes.unpack1('H*') } }, phase: :encode_cast)
          Internal.unhex(encoded, bound + 13)
        end
      ensure
        worker.close
      end
    end
  end
end

# frozen_string_literal: true
module Transit
  module Station
    GrpcSecretRef = Data.define(:binding, :version) do
      def initialize(binding:, version:) = super(binding: Internal.text(binding, 128).freeze, version: Internal.integer(version, max: U64_MAX))
    end
    GrpcMethod = Data.define(:path, :shape, :descriptor_digest) do
      def initialize(path:, shape:, descriptor_digest:)
        raise ArgumentError, 'Invalid RPC shape' unless %i[unary server_streaming client_streaming bidi].include?(shape)
        digest = Internal.bytes(descriptor_digest, 32)
        raise ArgumentError, 'Expected a 32-byte descriptor digest' unless digest.bytesize == 32
        super(path: Internal.text(path, 512).freeze, shape: shape, descriptor_digest: digest.freeze)
      end
    end
    GrpcMetadata = Data.define(:name, :value) do
      def initialize(name:, value:)
        super(name: Internal.text(name, 8192).freeze, value: value.is_a?(GrpcSecretRef) ? value : Internal.bytes(value, 8192).freeze)
      end
      def inspect = '#<Transit::Station::GrpcMetadata>'
    end
    GrpcRequest = Data.define(:method, :metadata) do
      def initialize(method:, metadata: [])
        unless method.is_a?(GrpcMethod) && metadata.is_a?(Array) && metadata.length <= 64 && metadata.all? { |field| field.is_a?(GrpcMetadata) }
          raise ArgumentError, 'Expected RPC method and ordered metadata'
        end
        super(method: method, metadata: metadata.dup.freeze)
      end
      def inspect = '#<Transit::Station::GrpcRequest>'
    end
    module GrpcValue
      module_function
      def codec(action, native_host, release: false)
        worker = Internal::Worker.new { Bridge.local(native_host) }
        begin
          worker.call { |bridge| bridge.grpc_codec(action, release: release) }
        ensure
          worker.close
        end
      end
      def request(input)
        method = input.method
        { 'method' => { 'path' => method.path, 'shape' => method.shape.to_s, 'descriptor_digest' => method.descriptor_digest.unpack1('H*') },
          'metadata' => input.metadata.map do |field|
            value = field.value
            { 'name' => field.name, 'value' => value.is_a?(GrpcSecretRef) ?
              { 'secret' => { 'binding' => value.binding, 'version' => value.version.to_s } } : { 'literal' => value.unpack1('H*') } }
          end }
      end
    end
    private_constant :GrpcValue
    def self.grpc_method(descriptor, path, native_host: nil)
      value = GrpcValue.codec({ 'descriptor' => { 'bytes' => Internal.bytes(descriptor, 65_536).unpack1('H*'), 'method' => Internal.text(path, 512) } }, native_host).fetch('descriptor').fetch('method')
      GrpcMethod.new(path: value.fetch('path'), shape: value.fetch('shape').to_sym, descriptor_digest: Internal.unhex(value.fetch('descriptor_digest'), 32))
    end
    PreparedGrpcRequest = Data.define(:resource, :namespace, :reference, :metadata, :batch) do
      def initialize(resource:, namespace:, reference:, metadata:, batch:)
        raise ArgumentError, 'Expected ResourceRef' unless resource.is_a?(ResourceRef)
        super(resource: resource, namespace: Internal.integer(namespace, max: U64_MAX),
          reference: Internal.bytes(reference, 145).freeze, metadata: Internal.bytes(metadata, 8192).freeze, batch: Internal.bytes(batch, 65_544).freeze)
      end
      def inspect = '#<Transit::Station::PreparedGrpcRequest owned bytes>'
    end
    def self.prepare_grpc(resource, namespace, request, messages:, endpoint_revision:, reconcile_before_ms:, max_attempts: 1, native_host: nil)
      raise ArgumentError, 'Expected ResourceRef and GrpcRequest' unless resource.is_a?(ResourceRef) && request.is_a?(GrpcRequest)
      raise ArgumentError, 'Expected at most 64 original protobuf messages' unless messages.is_a?(Array) && messages.length <= 64
      namespace = Internal.integer(namespace, max: U64_MAX)
      result = GrpcValue.codec({ 'prepare' => { 'resource' => resource.resource, 'namespace' => namespace.to_s,
        'request' => GrpcValue.request(request), 'messages' => messages.map { |message| Internal.bytes(message, 16_384).unpack1('H*') },
        'endpoint_revision' => Internal.integer(endpoint_revision, max: U64_MAX).to_s,
        'reconcile_before_ms' => Internal.integer(reconcile_before_ms), 'max_attempts' => Internal.integer(max_attempts, max: (1 << 32) - 1) } }, native_host).fetch('prepared')
      PreparedGrpcRequest.new(resource: resource, namespace: namespace,
        reference: Internal.unhex(result.fetch('reference'), 145), metadata: Internal.unhex(result.fetch('metadata'), 8192), batch: Internal.unhex(result.fetch('batch'), 65_544))
    end
    GrpcOutcome = Data.define(:phase, :resource, :exchange, :effect, :attempt, :status, :reference, :diagnostic) do
      def initialize(phase:, resource:, exchange:, effect:, attempt:, status:, reference:, diagnostic:)
        raise ArgumentError, 'Invalid RPC phase or resource' unless %i[observed closed_unknown not_dispatched].include?(phase) && resource.is_a?(ResourceRef)
        super(phase: phase, resource: resource, exchange: Internal.integer(exchange, max: U64_MAX),
          effect: Internal.integer(effect, min: 0), attempt: Internal.integer(attempt, min: 0),
          status: status.nil? ? nil : Internal.integer(status, min: 0, max: 16),
          reference: reference.nil? ? nil : Internal.bytes(reference, 256).freeze, diagnostic: Value.diagnostic(diagnostic))
      end
      def inspect = "#<Transit::Station::GrpcOutcome #{phase}>"
    end
    GrpcRejected = Data.define(:reason, :diagnostic) do
      def initialize(reason:, diagnostic:)
        super(reason: reason, diagnostic: Value.diagnostic(diagnostic))
      end
    end
    GrpcReleased = Data.define(:resource, :exchange) do
      def initialize(resource:, exchange:)
        raise ArgumentError, 'Expected ResourceRef' unless resource.is_a?(ResourceRef)
        super(resource: resource, exchange: Internal.integer(exchange, max: U64_MAX))
      end
    end
    def self.decode_grpc_reply(realm, bytes, native_host: nil)
      Internal.integer(realm)
      bytes = Internal.bytes(bytes, 73)
      result = GrpcValue.codec({ 'outcome' => bytes.unpack1('H*') }, native_host, release: bytes.start_with?('GRK1'.b))
      return GrpcRejected.new(reason: result.fetch('rejected').fetch('reason').to_sym, diagnostic: result.fetch('rejected').fetch('diagnostic')) if result.key?('rejected')
      if result.key?('released')
        value = result.fetch('released')
        return GrpcReleased.new(resource: ResourceRef.new(realm: realm, resource: value.fetch('resource')),
          exchange: Value.wide(value.fetch('exchange'), min: 1))
      end
      value = result.fetch('outcome')
      GrpcOutcome.new(phase: value.fetch('phase').to_sym,
        resource: ResourceRef.new(realm: realm, resource: value.fetch('resource')),
        exchange: Value.wide(value.fetch('exchange'), min: 1), effect: value.fetch('effect'), attempt: value.fetch('attempt'),
        status: value.fetch('status'), reference: value['reference'] && Internal.unhex(value['reference'], 256), diagnostic: value.fetch('diagnostic'))
    end
    class GrpcReplyCodec
      attr_reader :type_id
      def initialize(application, realm:, native_host: nil)
        @application, @realm, @native_host = application, Internal.integer(realm), native_host
        @type_id = "transit.grpc.reply+#{Internal.text(application.type_id)}".freeze
        freeze
      end
      def version = 1
      def max_encoded_bytes = [73, @application.max_encoded_bytes].max
      def encode(value)
        raise CodecError, 'RPC outcome records are receive-only' if value.is_a?(GrpcOutcome) || value.is_a?(GrpcRejected) || value.is_a?(GrpcReleased)
        @application.encode(value)
      end
      def decode(bytes)
        if ['GRR1'.b, 'GRF1'.b, 'GRK1'.b].include?(bytes.byteslice(0, 4))
          Station.decode_grpc_reply(@realm, bytes, native_host: @native_host)
        else @application.decode(bytes)
        end
      end
    end
    GrpcPart = Data.define(:kind, :data, :complete) do
      def initialize(kind:, data:, complete:)
        super(kind: kind, data: Internal.bytes(data, 256).freeze, complete: Internal.boolean(complete))
      end
      def inspect = "#<Transit::Station::GrpcPart #{kind} complete=#{complete}>"
    end
    class GrpcReader
      attr_reader :complete
      def initialize(identity, &call)
        @identity, @call, @complete, @closed = identity, call, false, false
      end
      def read
        raise Closed, 'RPC reader is closed' if @closed
        value = @call.call({ 'next' => @identity }).fetch('part')
        if value.nil?
          raise IncompatibleNative, 'RPC reader ended without verified completion' unless @complete
          return nil
        end
        part = GrpcPart.new(kind: value.fetch('kind').to_sym, data: Internal.unhex(value.fetch('bytes'), 256), complete: value.fetch('complete'))
        @complete = part.complete
        part
      end
      def close
        unless @closed
          raise IncompatibleNative, 'RPC reader disposal failed' unless @call.call({ 'close' => @identity }).fetch('closed')
          @closed = true
        end
        nil
      end
    end
  end
end

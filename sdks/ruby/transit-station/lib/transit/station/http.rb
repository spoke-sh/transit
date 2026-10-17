# frozen_string_literal: true
module Transit
  module Station
    HttpLiteral = Data.define(:value) do
      def initialize(value:) = super(value: Internal.text(value, 8192).freeze)
      def inspect = '#<Transit::Station::HttpLiteral>'
    end
    HttpVariable = Data.define(:name, :value) do
      def initialize(name:, value:) = super(name: Internal.text(name, 128).freeze, value: Internal.text(value, 8192).freeze)
      def inspect = '#<Transit::Station::HttpVariable>'
    end
    HttpSecretRef = Data.define(:binding, :version) do
      def initialize(binding:, version:) = super(binding: Internal.text(binding, 128).freeze, version: Internal.integer(version, max: U64_MAX))
    end
    module HttpValue
      module_function
      def pieces(values)
        raise ArgumentError, 'Expected at most 128 HTTP pieces' unless values.is_a?(Array) && values.length <= 128
        values.map do |value|
          case value
          when HttpLiteral then { 'literal' => value.value }
          when HttpVariable then { 'variable' => { 'name' => value.name, 'value' => value.value } }
          when HttpSecretRef then { 'secret' => { 'binding' => value.binding, 'version' => value.version.to_s } }
          else raise ArgumentError, 'Expected typed HTTP pieces'
          end
        end
      end
      def codec(action, native_host, release: false)
        worker = Internal::Worker.new { Bridge.local(native_host) }
        begin
          worker.call { |bridge| bridge.http_codec(action, release: release) }
        ensure
          worker.close
        end
      end
    end
    private_constant :HttpValue
    HttpHeader = Data.define(:name, :value) do
      def initialize(name:, value:)
        HttpValue.pieces(value)
        super(name: Internal.text(name, 8192).freeze, value: value.dup.freeze)
      end
      def inspect = '#<Transit::Station::HttpHeader>'
    end
    HttpRequest = Data.define(:method, :target, :headers) do
      def initialize(method:, target:, headers: [])
        raise ArgumentError, 'Unsupported HTTP method' unless %i[get head post put patch delete options].include?(method)
        HttpValue.pieces(target)
        unless headers.is_a?(Array) && headers.length <= 64 && headers.all? { |header| header.is_a?(HttpHeader) }
          raise ArgumentError, 'Expected at most 64 HttpHeader values'
        end
        super(method: method, target: target.dup.freeze, headers: headers.dup.freeze)
      end
      def inspect = '#<Transit::Station::HttpRequest>'
    end
    PreparedHttpRequest = Data.define(:resource, :namespace, :reference, :metadata, :body) do
      def initialize(resource:, namespace:, reference:, metadata:, body:)
        raise ArgumentError, 'Expected ResourceRef' unless resource.is_a?(ResourceRef)
        super(resource: resource, namespace: Internal.integer(namespace, max: U64_MAX),
          reference: Internal.bytes(reference, 112).freeze, metadata: Internal.bytes(metadata, 8192).freeze,
          body: Internal.bytes(body, 65_536).freeze)
      end
      def inspect = '#<Transit::Station::PreparedHttpRequest owned bytes>'
    end
    def self.prepare_http(resource, namespace, request, body: ''.b, endpoint_revision:, reconcile_before_ms:, max_attempts: 1, native_host: nil)
      raise ArgumentError, 'Expected ResourceRef and HttpRequest' unless resource.is_a?(ResourceRef) && request.is_a?(HttpRequest)
      namespace = Internal.integer(namespace, max: U64_MAX)
      bytes = Internal.bytes(body, 65_536)
      result = HttpValue.codec({ 'prepare' => { 'resource' => resource.resource, 'namespace' => namespace.to_s,
        'request' => { 'method' => request.method.to_s.upcase, 'target' => HttpValue.pieces(request.target),
          'headers' => request.headers.map { |header| { 'name' => header.name, 'value' => HttpValue.pieces(header.value) } } },
        'body' => bytes.unpack1('H*'), 'endpoint_revision' => Internal.integer(endpoint_revision, max: U64_MAX).to_s,
        'reconcile_before_ms' => Internal.integer(reconcile_before_ms), 'max_attempts' => Internal.integer(max_attempts, max: (1 << 32) - 1) } }, native_host).fetch('prepared')
      PreparedHttpRequest.new(resource: resource, namespace: namespace,
        reference: Internal.unhex(result.fetch('reference'), 112), metadata: Internal.unhex(result.fetch('metadata'), 8192), body: bytes)
    end
    HttpOutcome = Data.define(:phase, :resource, :exchange, :effect, :attempt, :status, :reference, :diagnostic) do
      def initialize(phase:, resource:, exchange:, effect:, attempt:, status:, reference:, diagnostic:)
        raise ArgumentError, 'Invalid HTTP phase or resource' unless %i[observed closed_unknown not_dispatched].include?(phase) && resource.is_a?(ResourceRef)
        super(phase: phase, resource: resource, exchange: Internal.integer(exchange, max: U64_MAX),
          effect: Internal.integer(effect, min: 0), attempt: Internal.integer(attempt, min: 0),
          status: status.nil? ? nil : Internal.integer(status, min: 200, max: 599),
          reference: reference.nil? ? nil : Internal.bytes(reference, 256).freeze, diagnostic: Value.diagnostic(diagnostic))
      end
      def inspect = "#<Transit::Station::HttpOutcome #{phase}>"
    end
    HttpRejected = Data.define(:reason, :diagnostic) do
      def initialize(reason:, diagnostic:)
        super(reason: reason, diagnostic: Value.diagnostic(diagnostic))
      end
    end
    HttpReleased = Data.define(:resource, :exchange) do
      def initialize(resource:, exchange:)
        raise ArgumentError, 'Expected ResourceRef' unless resource.is_a?(ResourceRef)
        super(resource: resource, exchange: Internal.integer(exchange, max: U64_MAX))
      end
    end
    def self.decode_http_reply(realm, bytes, native_host: nil)
      Internal.integer(realm)
      bytes = Internal.bytes(bytes, 232)
      result = HttpValue.codec({ 'outcome' => bytes.unpack1('H*') }, native_host, release: bytes.start_with?('HTK1'.b))
      return HttpRejected.new(reason: result.fetch('rejected').fetch('reason').to_sym, diagnostic: result.fetch('rejected').fetch('diagnostic')) if result.key?('rejected')
      if result.key?('released')
        value = result.fetch('released')
        return HttpReleased.new(resource: ResourceRef.new(realm: realm, resource: value.fetch('resource')),
          exchange: Value.wide(value.fetch('exchange'), min: 1))
      end
      value = result.fetch('outcome')
      HttpOutcome.new(phase: value.fetch('phase').to_sym,
        resource: ResourceRef.new(realm: realm, resource: value.fetch('resource')),
        exchange: Value.wide(value.fetch('exchange'), min: 1), effect: value.fetch('effect'), attempt: value.fetch('attempt'),
        status: value.fetch('status'), reference: value['reference'] && Internal.unhex(value['reference'], 256), diagnostic: value.fetch('diagnostic'))
    end
    class HttpReplyCodec
      attr_reader :type_id
      def initialize(application, realm:, native_host: nil)
        @application, @realm, @native_host = application, Internal.integer(realm), native_host
        @type_id = "transit.http.reply+#{Internal.text(application.type_id)}".freeze
        freeze
      end
      def version = 1
      def max_encoded_bytes = [232, @application.max_encoded_bytes].max
      def encode(value)
        raise CodecError, 'HTTP outcome records are receive-only' if value.is_a?(HttpOutcome) || value.is_a?(HttpRejected) || value.is_a?(HttpReleased)
        @application.encode(value)
      end
      def decode(bytes)
        if ['HTR1'.b, 'HTF1'.b, 'HTK1'.b].include?(bytes.byteslice(0, 4))
          Station.decode_http_reply(@realm, bytes, native_host: @native_host)
        else @application.decode(bytes)
        end
      end
    end
    HttpPart = Data.define(:kind, :data, :complete) do
      def initialize(kind:, data:, complete:)
        super(kind: kind, data: Internal.bytes(data, 256).freeze, complete: Internal.boolean(complete))
      end
      def inspect = "#<Transit::Station::HttpPart #{kind} complete=#{complete}>"
    end
    class HttpReader
      attr_reader :complete
      def initialize(identity, &call)
        @identity, @call, @complete, @closed = identity, call, false, false
      end
      def read
        raise Closed, 'HTTP reader is closed' if @closed
        value = @call.call({ 'next' => @identity }).fetch('part')
        if value.nil?
          raise IncompatibleNative, 'HTTP reader ended without verified completion' unless @complete
          return nil
        end
        part = HttpPart.new(kind: value.fetch('kind').to_sym, data: Internal.unhex(value.fetch('bytes'), 256), complete: value.fetch('complete'))
        @complete = part.complete
        part
      end
      def close
        unless @closed
          raise IncompatibleNative, 'HTTP reader disposal failed' unless @call.call({ 'close' => @identity }).fetch('closed')
          @closed = true
        end
        nil
      end
    end
  end
end

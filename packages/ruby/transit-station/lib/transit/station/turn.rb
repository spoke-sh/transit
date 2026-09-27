# frozen_string_literal: true
module Transit
  module Station
    class State
      def initialize(turn, version = nil)
        @turn, @version = turn, version
      end
      def find(key)
        @turn.__send__(:operation, read: true) do
          name = key_bytes(key)
          action = @version ? { 'version_get' => { 'id' => Value.version_wire(@version), 'key' => name } } : { 'get' => name }
          bytes = apply(action, read: true).fetch('value')
          bytes.nil? ? nil : Found.new(value: Value.decode(key.codec, Internal.unhex(bytes, caps.fetch('value_bytes')), caps.fetch('value_bytes')))
        end
      end
      def require(key)
        found = find(key)
        raise MissingValue, 'Required associated state is absent' unless found
        found.value
      end
      def put(key, value)
        @turn.__send__(:operation, read: false) do
          name = key_bytes(key)
          writable!
          bytes = Value.encode(key.codec, value, caps.fetch('value_bytes'))
          apply({ 'put' => { 'key' => name, 'value' => bytes.unpack1('H*') } })
          nil
        end
      end
      def delete(key)
        @turn.__send__(:operation, read: false) do
          name = key_bytes(key)
          writable!
          apply({ 'delete' => name })
          nil
        end
      end
      def page(cursor = nil)
        @turn.__send__(:operation, read: true) do
          cursor = Value.cursor(cursor)
          action = @version ? { 'version_page' => { 'id' => Value.version_wire(@version), 'cursor' => cursor } } : { 'page' => cursor }
          result = apply(action, read: true).fetch('page')
          entries = result.fetch('entries').compact.map do |entry|
            KVEntry.new(key: Internal.unhex(entry.fetch('key'), caps.fetch('key_bytes')).freeze,
              value: Internal.unhex(entry.fetch('value'), caps.fetch('value_bytes')).freeze, revision: entry.fetch('revision'))
          end
          Page.new(entries: entries.freeze, cursor: result['next']&.freeze, basis: nil)
        end
      end
      private
      def caps = @turn.__send__(:caps)
      def apply(action, read: false) = @turn.__send__(:raw_native, action)
      def key_bytes(key)
        raise ArgumentError, 'Expected Key' unless key.is_a?(Key)
        Internal.bytes(key.name, caps.fetch('key_bytes')).unpack1('H*')
      end
      def writable!
        raise HandlerError, 'Retained sources are read-only' if @version
      end
    end
    class Source
      attr_reader :identity
      def initialize(turn, identity)
        @turn, @identity = turn, identity
      end
      def state
        @turn.__send__(:check!)
        State.new(@turn, identity)
      end
      def table(schema)
        @turn.__send__(:check!)
        Table.new(@turn, schema, identity)
      end
    end
    class Turn
      attr_reader :process, :resource, :resource_revision
      def initialize(bridge, event, process, stop)
        @bridge, @event, @process, @stop = bridge, event, process, stop
        @scope, @active, @thread, @fiber, @mutex = event.fetch('scope'), true, Thread.current, Fiber.current, Mutex.new
        @resource = ResourceRef.new(realm: process.realm, resource: event.fetch('resource'))
        @resource_revision = event.fetch('resource_revision')
      end
      def state
        check!
        State.new(self)
      end
      def budgets
        values = apply_native({ 'budgets' => {} }).fetch('budgets')
        Budgets.new(**values.transform_keys(&:to_sym))
      end
      def cast(peer, value, codec:)
        pid = peer_id(peer)
        operation do
          bytes = Value.encode(codec, value, caps.fetch('message_bytes'))
          raw_native({ 'cast' => { 'pid' => pid, 'value' => bytes.unpack1('H*') } })
          nil
        end
      end
      def call(peer, value, codec:, wait:)
        pid = peer_id(peer)
        operation do
          raise ArgumentError, 'Select WaitPolicy' unless wait.is_a?(WaitPolicy)
          bytes = Value.encode(codec, value, caps.fetch('message_bytes'))
          result = raw_native({ 'call' => { 'pid' => pid, 'value' => bytes.unpack1('H*'), 'deadline_ms' => wait.deadline_ms, 'observer' => wait.observer } })
          Value.wide(result.fetch('correlation'), min: 1)
        end
      end
      def reply(value, codec:)
        operation do
          bytes = Value.encode(codec, value, caps.fetch('message_bytes'))
          raw_native({ 'reply' => bytes.unpack1('H*') })
          nil
        end
      end
      def require_reply(reply, peer:, correlation:)
        pid = peer_id(peer)
        Internal.integer(correlation, max: U64_MAX)
        input = @event.fetch('input')
        origin = input.fetch('origin')['process']
        unless reply.is_a?(Reply) && input['kind'] == 'reply' && origin && origin['pid'] == pid &&
               Value.wide(input.fetch('correlation')) == correlation && reply.position == input['position'] && reply.correlation == correlation
          raise HandlerError, 'Reply differs from the authenticated input, peer or saved correlation'
        end
        nil
      end
      def cancel_call(correlation)
        apply_native({ 'cancel' => Internal.integer(correlation, max: U64_MAX).to_s }).fetch('cancelled')
      end
      def table(schema)
        check!
        Table.new(self, schema)
      end
      def create_table(schema)
        check!
        raise ArgumentError, 'Expected TableSchema' unless schema.is_a?(TableSchema)
        [schema.key_name, schema.value_name].each { |name| Internal.text(name, caps.fetch('table_name_bytes')) }
        apply_native({ 'table_create' => { 'id' => schema.id, 'key_name' => schema.key_name, 'value_name' => schema.value_name, 'value_type' => schema.value_type.to_s } })
        table(schema)
      end
      def retain = Value.version(apply_native({ 'retain' => {} }).fetch('version'))
      def stage_http(request)
        http_request!(request)
        apply_native({ 'http_stage' => { 'reference' => request.reference.unpack1('H*'),
          'metadata' => request.metadata.unpack1('H*'), 'body' => request.body.unpack1('H*') } }).fetch('staged')
      end
      def call_http(peer, request)
        pid = peer_id(peer)
        http_request!(request)
        Value.wide(apply_native({ 'http_call' => { 'pid' => pid, 'reference' => request.reference.unpack1('H*') } }).fetch('correlation'), min: 1)
      end
      def release_http(peer, resource, exchange)
        pid = peer_id(peer)
        raise ArgumentError, 'HTTP capture must belong to the current realm' unless resource.is_a?(ResourceRef) && resource.realm == self.resource.realm
        raise UnsupportedCapability, 'Native HTTP disposal unavailable' unless caps['http_release']
        Value.wide(apply_native({ 'http_release' => { 'pid' => pid, 'resource' => resource.resource,
          'exchange' => Internal.integer(exchange, max: U64_MAX).to_s } }).fetch('correlation'), min: 1)
      end
      def followup_http(peer, parent, reason, request)
        pid = peer_id(peer)
        http_request!(request)
        raise ArgumentError, 'HTTP parent must belong to the current realm' unless parent.is_a?(HttpOutcome) && parent.resource.realm == resource.realm
        raise ArgumentError, 'Expected an HTTP followup reason' unless %i[retry redirect reconcile cancel].include?(reason)
        raise UnsupportedCapability, 'Native HTTP followup unavailable' unless caps['http_followup']
        Value.wide(apply_native({ 'http_followup' => { 'pid' => pid, 'resource' => parent.resource.resource,
          'parent' => Internal.integer(parent.exchange, max: U64_MAX).to_s, 'reason' => reason.to_s,
          'reference' => request.reference.unpack1('H*') } }).fetch('correlation'), min: 1)
      end
      def stage_grpc(request)
        grpc_request!(request)
        apply_native({ 'grpc_stage' => { 'reference' => request.reference.unpack1('H*'),
          'metadata' => request.metadata.unpack1('H*'), 'batch' => request.batch.unpack1('H*') } }).fetch('staged')
      end
      def call_grpc(peer, request)
        pid = peer_id(peer)
        grpc_request!(request)
        Value.wide(apply_native({ 'grpc_call' => { 'pid' => pid, 'reference' => request.reference.unpack1('H*') } }).fetch('correlation'), min: 1)
      end
      def document(identity) = DocumentOwner.new(self, identity)
      def release_grpc(peer, resource, exchange)
        pid = peer_id(peer)
        raise ArgumentError, 'RPC capture must belong to the current realm' unless resource.is_a?(ResourceRef) && resource.realm == self.resource.realm
        raise UnsupportedCapability, 'Native RPC disposal unavailable' unless caps['grpc_release']
        Value.wide(apply_native({ 'grpc_release' => { 'pid' => pid, 'resource' => resource.resource,
          'exchange' => Internal.integer(exchange, max: U64_MAX).to_s } }).fetch('correlation'), min: 1)
      end
      def retry_grpc(peer, parent, request)
        pid = peer_id(peer)
        grpc_request!(request)
        raise ArgumentError, 'RPC parent must belong to the current realm' unless parent.is_a?(GrpcOutcome) && parent.resource.realm == resource.realm
        raise UnsupportedCapability, 'Native RPC followup unavailable' unless caps['grpc_followup']
        Value.wide(apply_native({ 'grpc_followup' => { 'pid' => pid, 'resource' => parent.resource.resource,
          'parent' => Internal.integer(parent.exchange, max: U64_MAX).to_s,
          'reference' => request.reference.unpack1('H*') } }).fetch('correlation'), min: 1)
      end
      def open_version(identity)
        check!
        Value.version_wire(identity)
        Source.new(self, identity)
      end
      def release(identity)
        apply_native({ 'release' => Value.version_wire(identity) })
        nil
      end
      private
      def http_request!(request)
        check!
        raise ArgumentError, 'HTTP publication must use the current resource' unless request.is_a?(PreparedHttpRequest) && request.resource == resource
        raise UnsupportedCapability, 'Native HTTP requests unavailable' unless caps['http_requests']
      end
      def grpc_request!(request)
        check!
        raise ArgumentError, 'RPC publication must use the current resource' unless request.is_a?(PreparedGrpcRequest) && request.resource == resource
        raise UnsupportedCapability, 'Native RPC requests unavailable' unless caps['grpc_requests']
      end
      attr_reader :scope, :poison
      def end_scope! = @active = false
      def caps = @bridge.caps
      def check!
        raise TurnExpired, 'Turn scope has ended' unless @active
        raise Busy, 'Turn operations belong to the handler thread and fiber' unless Thread.current == @thread && Fiber.current == @fiber
        raise Busy, 'One operation per turn' if @mutex.locked?
        raise Closed, 'Local stop requested' if @stop.stopped?
        raise @poison if @poison
      end
      def peer_id(peer)
        check!
        raise ArgumentError, 'Expected a ProcessRef in this realm' unless peer.is_a?(ProcessRef) && peer.realm == process.realm
        peer.pid
      end
      def raw_native(action) = @bridge.apply(@scope, action)
      def apply_native(action, read: false)
        operation(read: read) { raw_native(action) }
      end
      def operation(read: false)
        check!
        raise Busy, 'One operation per turn' unless @mutex.try_lock
        begin
          yield
        rescue Exception => error
          # A caught codec/materialization failure is still a failed read.
          @poison ||= error.is_a?(Error) ? error : HandlerError.new('Scoped read failed') if read
          raise
        ensure
          @mutex.unlock
        end
      end
    end
  end
end

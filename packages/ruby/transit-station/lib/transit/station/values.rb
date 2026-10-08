# frozen_string_literal: true
module Transit
  module Station
    U64_MAX = (1 << 64) - 1
    I64_MIN = -(1 << 63)
    I64_MAX = (1 << 63) - 1
    module Value
      module_function
      # Diagnostic collections must not borrow a mutable decoded response.
      def diagnostic(value)
        Internal.validate!(Internal::SCHEMAS.fetch('Diagnostic'), value)
        copy = lambda do |item|
          case item
          when Hash then item.to_h { |key, child| [key.dup.freeze, copy.call(child)] }.freeze
          when Array then item.map { |child| copy.call(child) }.freeze
          when String then item.dup.freeze
          else item
          end
        end
        copy.call(value)
      end
      def codec_bound(codec, bound)
        unless %i[type_id version max_encoded_bytes encode decode].all? { |method| codec.respond_to?(method) }
          raise CodecError, 'Expected an explicit versioned codec'
        end
        raise CodecError, 'Codec type ID is empty' if Internal.text(codec.type_id).empty?
        Internal.integer(codec.version, max: (1 << 32) - 1)
        Internal.integer(codec.max_encoded_bytes, max: bound)
      rescue ArgumentError
        raise CodecError, 'Invalid codec contract'
      end
      def encode(codec, value, bound)
        size = codec_bound(codec, bound)
        Internal.bytes(codec.encode(value), size)
      rescue StandardError
        raise CodecError, 'Application encoding failed', cause: nil
      end
      def decode(codec, bytes, bound)
        size = codec_bound(codec, bound)
        codec.decode(Internal.bytes(bytes, size))
      rescue StandardError
        raise CodecError, 'Application decoding failed', cause: nil
      end
      def cursor(value) = value.nil? ? nil : Internal.text(value)
      def digest(value)
        raise IncompatibleNative, 'Invalid native digest' unless value.is_a?(Array) && value.length == 32
        value.map { |byte| Internal.integer(byte, min: 0, max: 255) }.pack('C*').freeze
      end
      def wide(value, min: 0, max: U64_MAX)
        raise IncompatibleNative, 'Invalid decimal integer' unless value.is_a?(String) && /\A-?(0|[1-9][0-9]*)\z/.match?(value)
        parsed = Internal.integer(Integer(value, 10), min: min, max: max)
        raise IncompatibleNative, 'Noncanonical decimal integer' unless parsed.to_s == value
        parsed
      end
      def basis(value, realm)
        Basis.new(resource: ResourceRef.new(realm: realm, resource: value.fetch('resource')),
                  revision: Internal.integer(value.fetch('revision'), min: 0), schema: digest(value.fetch('schema')))
      end
      def version(value)
        ReadVersion.new(pid: value.fetch('pid'), input: value.fetch('input'), index: value.fetch('index'))
      end
      def version_wire(value)
        raise ArgumentError, 'Expected ReadVersion' unless value.is_a?(ReadVersion)
        { 'pid' => value.pid, 'input' => value.input, 'index' => value.index }
      end
      def origin(value, realm)
        if (source = value['external'])
          ExternalOrigin.new(principal: source.fetch('principal'), policy_revision: source.fetch('policy_revision'))
        elsif (source = value['process'])
          ProcessOrigin.new(process: ProcessRef.new(realm: realm, pid: source.fetch('pid')), turn: source.fetch('turn'), output: source.fetch('output'))
        elsif (source = value['effect'])
          EffectOrigin.new(effect: source.fetch('id'), attempt: source.fetch('attempt'), executor: source.fetch('executor'))
        else raise IncompatibleNative, 'Unknown native origin'
        end
      end
    end
    class Key
      attr_reader :name, :codec
      def initialize(name, codec:)
        @name, @codec = Internal.bytes(name, Internal::LIMITS.fetch('value_bytes')).freeze, codec
        raise ArgumentError, 'Application key must be nonempty and outside the reserved prefix' if @name.empty? || @name.getbyte(0).zero?
        freeze
      end
      def inspect = '#<Transit::Station::Key application codec>'
    end
    Found = Data.define(:value) do
      def inspect = '#<Transit::Station::Found application value>'
    end
    Basis = Data.define(:resource, :revision, :schema)
    Page = Data.define(:entries, :cursor, :basis)
    KVEntry = Data.define(:key, :value, :revision) do
      def inspect = '#<Transit::Station::KVEntry owned bytes>'
    end
    ReadVersion = Data.define(:pid, :input, :index) do
      def initialize(pid:, input:, index:)
        super(pid: Internal.integer(pid), input: Internal.integer(input), index: Internal.integer(index, min: 0, max: 255))
      end
    end
    Budgets = Data.define(:mutations, :outputs, :views, :retained_reads, :retains, :releases)
    Activation = Data.define(:process, :generation, :credential) do
      def initialize(process:, generation:, credential:)
        unless process.is_a?(ProcessRef) && credential.is_a?(Credential) && process.realm == credential.realm
          raise ArgumentError, 'Activation needs a process and credential in the same realm'
        end
        super(process: process, generation: Internal.integer(generation), credential: credential)
      end
    end
    ServiceConfig = Data.define(:client, :activation, :association, :query_results) do
      def initialize(client:, activation:, association: 'data', query_results: false)
        raise ArgumentError, 'Expected ClientConfig and Activation' unless client.is_a?(ClientConfig) && activation.is_a?(Activation)
        association = Internal.text(association, Internal::LIMITS.fetch('value_bytes')).freeze
        raise ArgumentError, 'Association must be nonempty' if association.empty?
        Internal.boolean(query_results)
        super(client: client, activation: activation, association: association, query_results: query_results)
      end
    end
    WaitPolicy = Data.define(:deadline_ms, :observer) do
      def self.untimed = new(deadline_ms: nil, observer: nil)
      def self.until(deadline_ms:, observer:) = new(deadline_ms: deadline_ms, observer: observer)
      def initialize(deadline_ms:, observer:)
        raise ArgumentError, 'Timed waits require both deadline and observer' unless deadline_ms.nil? == observer.nil?
        unless deadline_ms.nil?
          Internal.integer(deadline_ms)
          Internal.integer(observer)
        end
        super
      end
    end
    ExternalOrigin = Data.define(:principal, :policy_revision)
    ProcessOrigin = Data.define(:process, :turn, :output)
    EffectOrigin = Data.define(:effect, :attempt, :executor)
    Cast = Data.define(:value, :position, :origin)
    Call = Data.define(:value, :position, :origin, :correlation)
    Reply = Data.define(:value, :position, :origin, :correlation)
    Control = Data.define(:kind, :position, :origin, :correlation)
    ResultComplete = Data.define(:position, :origin, :correlation)
    QueryFailure = Data.define(:position, :origin, :correlation, :result, :reason)
    class FrozenMutation
      attr_reader :identity, :purpose, :input_position
      def initialize(identity, purpose, input_position, bytes)
        @identity, @purpose, @input_position = identity, purpose, Internal.integer(input_position)
        @bytes = Internal.bytes(bytes).freeze
        freeze
      end
      def export = @bytes.dup
      def inspect = "#<Transit::Station::FrozenMutation #{purpose} #{identity.sha256}>"
    end
    Committed = Data.define(:input, :receipt)
    Blocked = Data.define(:input, :receipt)
    NeedsRecovery = Data.define(:mutation, :phase, :error, :receipt)
    Idle = Data.define
    Progress = Data.define
    Shutdown = Data.define(:pending, :last_event)
    class StopToken
      def initialize
        @mutex, @stopped = Mutex.new, false
      end
      def stop = @mutex.synchronize { @stopped = true }
      def stopped? = @mutex.synchronize { @stopped }
    end
  end
end

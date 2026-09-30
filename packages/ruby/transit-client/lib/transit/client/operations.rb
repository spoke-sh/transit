# frozen_string_literal: true
module Transit
  SendInfo = Data.define(:identity, :peer, :principal, :sequence)
  MutationInfo = Data.define(:identity, :realm, :principal, :sequence, :command)
  class Pending
    attr_reader :info
    def initialize(info, bytes)
      @info, @bytes = info, Internal.bytes(bytes).freeze
    end
    def identity = info.identity
    def export
      raise Closed, 'Pending operation is closed' unless @bytes
      @bytes.dup
    end
    def close = @bytes = nil
    def inspect = "#<#{self.class} #{identity.sha256}>"
  end
  class PendingSend < Pending; end
  class PendingMutation < Pending; end
  Admitted = Data.define(:receipt)
  Confirmed = Data.define(:receipt)
  Rejected = Data.define(:error)
  class Uncertain
    attr_reader :error
    def initialize(bytes, error)
      @bytes, @error = Internal.bytes(bytes).freeze, error
      freeze
    end
    def recovery = @bytes.dup
    def inspect = "#<Transit::Uncertain status=#{error.status}>"
  end
  Capabilities = Data.define(:realm, :observed_at, :principal_sequence, :page_size, :mutations_per_turn,
                             :outputs_per_turn, :retained_versions, :association_lookup, :scoped_retry, :station)
  Shutdown = Data.define(:last_admission, :last_mutation)

  module Internal
    module_function
    def prepare(port, kind, credential, document)
      value = port.request({ 'prepare' => { 'kind' => kind, 'seed_file' => credential.seed_file, 'document' => JSON.generate(document) } }, phase: :prepare)
      bytes(text(value))
    end
    def metadata(port, bytes)
      result = port.request({ 'metadata' => text(bytes) }, phase: :metadata, response: 'OperationMetadata')
      raise IncompatibleNative, 'Unsupported metadata version' unless result['version'] == 1
      OperationIdentity.new(sha256: result['identity'])
      integer(result['realm']); integer(result['principal'], min: 0)
      result
    end
    def sequence(value)
      raise IncompatibleNative, 'Invalid native sequence' unless value.is_a?(String) && /\A[1-9][0-9]{0,15}\z/.match?(value)
      integer(Integer(value, 10))
    end
    def recover(port, bytes, send_only:)
      meta = metadata(port, bytes)
      unless meta['profile'] == 'native_v1' && meta['kind'] == 'growing_command' && meta['command'] && (!send_only || meta['command'] == 'send')
        raise UnsupportedCapability, 'Recovery material is not the requested growing operation'
      end
      identity = OperationIdentity.new(sha256: meta['identity'])
      next_sequence = sequence(meta['sequence'])
      if send_only
        PendingSend.new(SendInfo.new(identity: identity, peer: ProcessRef.new(realm: meta['realm'], pid: meta['destination']),
                                    principal: meta['principal'], sequence: next_sequence), bytes)
      else
        PendingMutation.new(MutationInfo.new(identity: identity, realm: meta['realm'], principal: meta['principal'],
                                            sequence: next_sequence, command: meta['command'].dup.freeze), bytes)
      end
    end
    def authority_capabilities(port, credential)
      frozen = prepare(port, 7, credential, { 'realm' => credential.realm, 'principal' => credential.principal, 'kind' => { 'capabilities' => {} } })
      value = hash(port.request({ 'call' => text(frozen) }, phase: :authority_capabilities))
      caps = hash(hash(value['body'])['capabilities'])
      unless value['version'] == 1 && caps['version'] == 1 && caps['profile'] == 'growing_v1'
        raise UnsupportedCapability, 'Authority lacks the growing profile'
      end
      Capabilities.new(realm: integer(value['realm']), observed_at: integer(value['position'], min: 0),
        principal_sequence: integer(value['principal_sequence'], min: 0), page_size: integer(caps['page_entries']),
        mutations_per_turn: integer(caps['mutation_budget']), outputs_per_turn: integer(caps['output_budget']),
        retained_versions: boolean(caps['retained_read_versions']), association_lookup: boolean(caps['association_lookup']),
        scoped_retry: boolean(caps['scoped_retry']), station: boolean(caps['station']))
    end
  end
end

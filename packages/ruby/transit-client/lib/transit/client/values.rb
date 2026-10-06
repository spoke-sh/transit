# frozen_string_literal: true
require 'json'
require 'uri'

module Transit
  class Error < StandardError
    attr_reader :status, :code, :phase, :diagnostic, :diagnostic_invalid
    def initialize(message = 'Transit operation failed', status: nil, code: nil, phase: :preflight, diagnostic: nil, diagnostic_invalid: false)
      super(message)
      @status, @code, @phase = status, code&.dup&.freeze, phase
      @diagnostic = diagnostic.nil? ? nil : JSON.parse(JSON.generate(diagnostic))
      @diagnostic_invalid = diagnostic_invalid
    end
  end
  class Busy < Error; end
  class Closed < Error; end
  class IncompatibleNative < Error; end
  class UnsupportedCapability < Error; end
  class AuthorityRejected < Error; end
  class AccessDenied < AuthorityRejected; end
  class StaleOwnership < AuthorityRejected; end
  class ProcessRetired < AuthorityRejected; end
  class HistoryUnavailable < Error; end
  class ReadFailed < Error; end
  class TurnExpired < Error; end
  class CodecError < Error; end
  class HandlerError < Error; end
  class MissingValue < Error; end
  class UnknownOutcome < Error; end
  class CleanupError < Error
    attr_reader :evidence
    def initialize(evidence)
      super('Native cleanup failed; inspect retained shutdown evidence', phase: :close)
      @evidence = evidence
    end
  end

  module Internal
    CONTRACT = JSON.parse(File.binread(File.join(__dir__, 'contract.json'))).freeze
    SCHEMAS = JSON.parse(File.binread(File.join(__dir__, 'schemas.json'))).freeze
    LIMITS = CONTRACT.fetch('limits').freeze
    module_function
    def integer(value, min: 1, max: LIMITS.fetch('max_counter'))
      raise ArgumentError, 'Expected an Integer within the operation bound' unless value.is_a?(Integer) && value.between?(min, max)
      value
    end
    def bytes(value, bound = LIMITS.fetch('max_body'))
      raise ArgumentError, 'Expected a bounded binary String' unless value.is_a?(String) && value.bytesize <= bound
      value.b.dup
    end
    def text(value, bound = LIMITS.fetch('max_body'))
      result = bytes(value, bound).force_encoding(Encoding::UTF_8)
      raise ArgumentError, 'Expected valid UTF-8 text' unless result.valid_encoding?
      result
    end
    def hash(value)
      raise IncompatibleNative, 'Expected a native object' unless value.is_a?(Hash)
      value
    end
    def boolean(value)
      raise IncompatibleNative, 'Expected a native boolean' unless [true, false].include?(value)
      value
    end
    def unhex(value, bound)
      raise IncompatibleNative, 'Invalid native bytes' unless value.is_a?(String) && value.bytesize <= bound * 2 && /\A(?:[0-9a-f]{2})*\z/.match?(value)
      [value].pack('H*')
    end
    def native_error(status, value, phase)
      code = value.is_a?(Hash) ? value['protocol_error'] || value['err'] : nil
      code = nil unless code.is_a?(String) && code.bytesize <= 256
      category = case code
                 when 'ProcessExpired', 'ProcessTerminated' then ProcessRetired
                 when 'HistoryReclaimed', 'QueryExpired' then HistoryUnavailable
                 when 'StaleActivation' then StaleOwnership
                 else { 3 => AuthorityRejected, 4 => AccessDenied, 5 => AuthorityRejected,
                        6 => UnknownOutcome, 7 => ReadFailed, 8 => ReadFailed, 9 => Busy,
                        10 => IncompatibleNative, 11 => StaleOwnership, 13 => TurnExpired }.fetch(status, Error)
                 end
      category = UnknownOutcome if status == 6
      diagnostic, invalid = nil, false
      candidate = value.is_a?(Hash) ? value['diagnostic'] : nil
      unless candidate.nil?
        begin
          if JSON.generate(candidate).bytesize <= 32768 && valid?(SCHEMAS.fetch('Diagnostic'), candidate)
            diagnostic = candidate
          else
            invalid = true
          end
        rescue StandardError
          invalid = true
        end
      end
      category.new("Transit #{phase} failed", status: status, code: code, phase: phase, diagnostic: diagnostic, diagnostic_invalid: invalid)
    end
    # This small validator accepts only the keywords emitted by the Zig schema
    # generator. Unknown schema keywords fail closed, rather than being ignored.
    def valid?(schema, value)
      validate_rule(schema, value, schema, {}, 0)
    rescue SystemStackError, RegexpError, TypeError, KeyError
      false
    end
    def validate_rule(schema, value, root, active, depth)
      return false unless schema.is_a?(Hash) && depth <= 128
      # References are local to one generated root. Detect non-consuming cycles;
      # recursive data may revisit the same schema with a different child value.
      pair = [schema.object_id, value.object_id]
      return false if active.key?(pair)
      active[pair] = true
      begin
        validate_body(schema, value, root, active, depth)
      ensure
        active.delete(pair)
      end
    end
    def validate_body(schema, value, root, active, depth)
      known = %w[$defs $ref type properties additionalProperties required maxProperties anyOf oneOf enum const minimum maximum maxLength pattern items minItems maxItems]
      return false unless (schema.keys - known).empty?
      return false if %w[anyOf oneOf].any? { |key| schema.key?(key) && (!schema[key].is_a?(Array) || schema[key].empty?) }
      return false if schema.key?('$defs') && (!schema.equal?(root) || !schema['$defs'].is_a?(Hash))
      if schema.key?('$ref')
        reference = schema['$ref']
        return false unless reference.is_a?(String) && /\A#\/\$defs\/[A-Za-z0-9_]+\z/.match?(reference)
        return false unless (schema.keys - %w[$ref $defs]).empty?
        target = root.fetch('$defs', {})[reference.delete_prefix('#/$defs/')]
        return validate_rule(target, value, root, active, depth)
      end
      return false if schema.key?('anyOf') && !schema['anyOf'].any? { |item| validate_rule(item, value, root, active, depth) }
      return false if schema.key?('oneOf') && schema['oneOf'].count { |item| validate_rule(item, value, root, active, depth) } != 1
      return false if schema.key?('const') && schema['const'] != value
      return false if schema.key?('enum') && !schema['enum'].include?(value)
      case schema['type']
      when nil then true
      when 'null' then value.nil?
      when 'boolean' then value == true || value == false
      when 'integer', 'number'
        value.is_a?(Integer) && value >= schema.fetch('minimum', value) && value <= schema.fetch('maximum', value)
      when 'string'
        value.is_a?(String) && value.valid_encoding? && value.length <= schema.fetch('maxLength', value.length) &&
          (!schema.key?('pattern') || Regexp.new("\\A(?:#{schema['pattern']})\\z").match?(value))
      when 'array'
        value.is_a?(Array) && value.length.between?(schema.fetch('minItems', 0), schema.fetch('maxItems', value.length)) &&
          value.all? { |item| validate_rule(schema.fetch('items'), item, root, active, depth + 1) }
      when 'object'
        return false unless value.is_a?(Hash) && value.length <= schema.fetch('maxProperties', value.length)
        properties = schema.fetch('properties', {})
        (schema.fetch('required', []) - value.keys).empty? &&
          (schema['additionalProperties'] != false || (value.keys - properties.keys).empty?) &&
          properties.all? { |name, child| !value.key?(name) || validate_rule(child, value[name], root, active, depth + 1) }
      else false
      end
    end
    def validate!(schema, value)
      raise IncompatibleNative, 'Value does not match the generated native contract' unless valid?(schema, value)
      value
    end
  end

  ProcessRef = Data.define(:realm, :pid) do
    def initialize(realm:, pid:)
      super(realm: Internal.integer(realm), pid: Internal.integer(pid))
    end
  end
  ResourceRef = Data.define(:realm, :resource) do
    def initialize(realm:, resource:)
      super(realm: Internal.integer(realm), resource: Internal.integer(resource))
    end
  end
  OperationIdentity = Data.define(:sha256) do
    def initialize(sha256:)
      raise ArgumentError, 'Expected a native SHA-256 operation identity' unless sha256.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(sha256)
      super(sha256: sha256.dup.freeze)
    end
  end
  class Credential
    attr_reader :realm, :principal, :seed_file
    def initialize(realm:, principal:, seed_file:)
      @realm, @principal = Internal.integer(realm), Internal.integer(principal, min: 0)
      @seed_file = Internal.text(seed_file).freeze
      raise ArgumentError, 'An explicit seed file is required' if @seed_file.empty?
      freeze
    end
    def inspect = "#<Transit::Credential realm=#{realm} principal=#{principal}>"
  end
  AdmissionReceipt = Data.define(:position) do
    def initialize(position:) = super(position: Internal.integer(position))
  end
  MutationReceipt = Data.define(:position) do
    def initialize(position:) = super(position: Internal.integer(position))
  end
  ClientConfig = Data.define(:url, :profile, :timeout_ms, :native_host) do
    def initialize(url:, profile:, timeout_ms: 5000, native_host: nil)
      raise ArgumentError, 'Select the explicit native_v1 profile' unless profile == :native_v1
      endpoint = Internal.text(url)
      parsed = URI.parse(endpoint)
      unless %w[http https].include?(parsed.scheme) && parsed.host && !parsed.userinfo && !parsed.query && !parsed.fragment
        raise ArgumentError, 'Expected an HTTP endpoint without credentials, query or fragment'
      end
      super(url: endpoint.freeze, profile: profile, timeout_ms: Internal.integer(timeout_ms, max: 60_000),
            native_host: native_host.nil? ? nil : Internal.text(native_host).freeze)
    end
  end
end

# frozen_string_literal: true
require 'json'
require 'set'
require 'transit/sdk_examples'
include Transit
S = Transit::Station
E = Transit::Examples

def check(value)
  raise 'Proof assertion failed' unless value
end
def expect(type)
  begin
    yield
  rescue type
    return
  end
  raise "Expected #{type}"
end
def report(value)
  puts JSON.generate(value)
  STDOUT.flush
end
def wait_file(path)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 30
  until File.exist?(path)
    check Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    sleep 0.01
  end
end
class InjectedException < Exception; end
class CounterProof < E::Counter
  attr_reader :initialized, :handled, :escaped
  def initialize
    @initialized = @handled = 0
  end
  def on_start(turn)
    @initialized += 1
    check turn.budgets.mutations == 3
    super
  end
  def on_message(turn, input)
    @handled += 1
    @escaped = turn.state
    Thread.new { expect(Busy) { @escaped.require(E::TOTAL) } }.join
    Fiber.new { expect(Busy) { @escaped.require(E::TOTAL) } }.resume
    codec = E::U64.dup
    codec.define_singleton_method(:decode) do |bytes|
      expect(Busy) { turn.budgets }
      E::U64.dup.decode(bytes)
    end
    @escaped.require(S::Key.new('total'.b, codec: codec))
    super
  end
end
class TableProof < E::TableService
  def initialize(peer, output)
    super(peer)
    @output = output
  end
  def on_message(turn, input)
    saved = File.join(@output, 'version.json')
    if input.is_a?(S::Cast) && input.value.is_a?(E::Rows)
      table = turn.table(E::TABLE)
      cursor = nil
      rows = []
      pages = 0
      loop do
        page = table.page(cursor)
        check page.entries.length <= 8 && page.basis == table.basis
        rows.concat(page.entries)
        pages += 1
        cursor = page.cursor
        break unless cursor
      end
      check rows.length == 41 && pages == 6 && rows[0].key == -(1 << 63) && rows[0].value.nil?
      version = turn.retain
      File.write(saved, JSON.generate(version.to_h))
      table.update(S::Row.new(key: -(1 << 63), value: 17))
    elsif input.value.is_a?(E::Initialize) && File.exist?(saved)
      version = S::ReadVersion.new(**JSON.parse(File.read(saved), symbolize_names: true))
      check turn.table(E::TABLE).get(-(1 << 63)).value == 17
      source = turn.open_version(version)
      check source.table(E::TABLE).get(-(1 << 63)).value.nil?
      check source.table(E::TABLE).page.entries.length == 8 && source.state.page.entries.length <= 8
      turn.release(version)
    else super
    end
  end
end
class QueryProof < E::QueryRequester
  def initialize(peer, output)
    @output, @segments = output, []
    super(peer) { |segment| @segments << segment }
  end
  def on_message(turn, input)
    path = File.join(@output, 'manifest.json')
    if File.exist?(path)
      manifest = JSON.parse(File.read(path))
      reader = turn.result(Integer(manifest.fetch('correlation'), 10))
      check reader.manifest.rows == 41
      File.write(File.join(@output, 'ready'), '')
      wait_file(File.join(@output, 'continue'))
      reader.segment(0)
    else super
    end
  end
  def on_result(turn, complete)
    super
    manifest = turn.result(complete.correlation).manifest
    File.write(File.join(@output, 'manifest.json'), JSON.generate(rows: manifest.rows, segments: manifest.segments,
      correlation: manifest.correlation.to_s, source: manifest.source.pid, destination: manifest.destination.pid,
      resource: manifest.basis.resource.resource, revision: manifest.basis.revision, bytes: manifest.byte_count))
  end
  def save_owned
    @segments.each do |segment|
      original = segment.ipc
      segment.ipc.replace('changed')
      check segment.ipc == original
      File.binwrite(File.join(@output, "#{segment.ordinal}.arrow"), original)
    end
  end
end
class Store
  attr_accessor :runner
  attr_reader :before_failed, :confirm_failed, :saved, :confirmations
  def initialize(mode, pending)
    @mode, @pending = mode, pending
    @before_failed, @confirm_failed, @saved, @confirmations = Set.new, Set.new, {}, {}
  end
  def before_dispatch(mutation)
    @current = mutation
    if @mode == 'gates'
      expect(Busy) { runner.next }
      expect(Busy) { runner.close }
      if @before_failed.add?(mutation.purpose)
        raise InjectedException, 'Persistence exception' if mutation.purpose == :permit
        raise 'Persistence failed'
      end
    end
    bytes = mutation.export
    identity = mutation.identity.sha256
    check @saved[identity] == bytes if @saved.key?(identity)
    @saved[identity] = bytes
    File.open(@pending, 'wb', 0o600) { |file| file.write(bytes); file.fsync }
  end
  def confirmed(identity, receipt)
    check @saved.key?(identity.sha256) && receipt.position.positive?
    if @mode == 'gates' && @confirm_failed.add?(@current.purpose)
      raise InjectedException, 'Confirmation exception' if @current.purpose == :open
      raise 'Confirmation failed'
    end
    @confirmations[identity.sha256] = receipt
  end
end

class HttpBytes
  def type_id = 'test.http-control'
  def version = 1
  def max_encoded_bytes = 243
  def encode(value) = value.b.dup
  def decode(value) = value.b.dup
end
class HttpHandler < S::Handler
  attr_reader :result, :escaped
  def initialize(peer, request, disposal, followup_reason)
    @peer, @request, @disposal, @followup_reason = peer, request, disposal, followup_reason
    @correlation = S::Key.new('http-correlation'.b, codec: E::U64)
    @release_correlation = S::Key.new('http-release-correlation'.b, codec: E::U64)
    @followup_correlation = S::Key.new('http-followup-correlation'.b, codec: E::U64)
  end
  def on_message(turn, input)
    @escaped = turn
    if input.is_a?(S::Cast)
      if input.value == 'followup'.b
        wrong = @disposal.with(resource: ResourceRef.new(realm: 73, resource: @disposal.resource.resource))
        expect(ArgumentError) { turn.followup_http(@peer, wrong, @followup_reason, @request) }
        expect(ArgumentError) { turn.followup_http(@peer, @disposal, :automatic, @request) }
        correlation = turn.followup_http(@peer, @disposal, @followup_reason, @request)
        turn.state.put(@followup_correlation, correlation)
        @result = { followup: false }
      elsif input.value == 'dispose'.b
        expect(ArgumentError) { turn.release_http(@peer, ResourceRef.new(realm: 73, resource: @disposal.resource.resource), @disposal.exchange) }
        correlation = turn.release_http(@peer, @disposal.resource, @disposal.exchange)
        turn.state.put(@release_correlation, correlation)
        @result = { released: false }
      elsif turn.state.find(@correlation)
        @result = { called: true }
      elsif turn.stage_http(@request)
        correlation = turn.call_http(@peer, @request)
        turn.state.put(@correlation, correlation)
        @result = { called: true }
      else @result = { called: false }
      end
    else
      if input.is_a?(S::Reply) && input.value.is_a?(S::HttpRejected)
        correlation = turn.state.require(@followup_correlation)
        turn.require_reply(input, peer: @peer, correlation: correlation)
        check input.value.reason == :denied
        facts = input.value.diagnostic.fetch('facts').compact.to_h { |f| [f.fetch('field'), f] }
        check facts.fetch('field_path').fetch('availability') == 'provided'
        check facts.fetch('native_input').fetch('value').fetch('unsigned').to_i > 0
        check facts.fetch('proposal').fetch('value').fetch('digest').length == 32
        turn.state.put(S::Key.new('http-followup-denied'.b, codec: E::U64), correlation)
        @result = { followup: true }
        return
      end
      if input.is_a?(S::Reply) && input.value.is_a?(S::HttpReleased)
        turn.require_reply(input, peer: @peer, correlation: turn.state.require(@release_correlation))
        check input.value.resource == @disposal.resource && input.value.exchange == @disposal.exchange
        turn.state.put(S::Key.new('http-disposed'.b, codec: E::U64), input.value.exchange)
        @result = { released: true }
        return
      end
      check input.is_a?(S::Reply) && input.value.is_a?(S::HttpOutcome)
      turn.require_reply(input, peer: @peer, correlation: turn.state.require(@correlation))
      check input.value.phase == :observed && input.value.status == 200
      check input.value.diagnostic.fetch('code') == 'http.response_observed'
      check input.value.diagnostic.fetch('outcome') == 'completed'
      turn.state.put(S::Key.new('http-status'.b, codec: E::U64), 200)
      @result = { observed: true }
    end
  end
end
def http_consumer(mode, cfg)
  body = [cfg.fetch('body')].pack('H*')
  request = S.prepare_http(ResourceRef.new(realm: 72, resource: cfg.fetch('resource')), (1 << 64) - 1,
    S::HttpRequest.new(method: :post, target: [S::HttpLiteral.new(value: '/items/'), S::HttpVariable.new(name: 'id', value: 'λ /')], headers: [
      S::HttpHeader.new(name: 'X-Tag', value: [S::HttpLiteral.new(value: 'one')]),
      S::HttpHeader.new(name: 'X-Tag', value: [S::HttpLiteral.new(value: 'two')]),
      S::HttpHeader.new(name: 'Authorization', value: [S::HttpLiteral.new(value: 'Bearer '), S::HttpSecretRef.new(binding: 'api', version: 7)])]),
    body: body, endpoint_revision: 7, reconcile_before_ms: cfg.fetch('deadline'))
  body.replace('changed')
  check request.body.frozen? && request.metadata.frozen? && request.reference.frozen? && request.body.bytesize == 513
  config = S::ServiceConfig.new(client: ClientConfig.new(url: cfg.fetch('url'), profile: :native_v1),
    activation: S::Activation.new(process: ProcessRef.new(realm: 72, pid: cfg.fetch('pid')), generation: cfg.fetch('generation'),
      credential: Credential.new(realm: 72, principal: cfg.fetch('principal'), seed_file: cfg.fetch('seed_file'))))
  disposal = cfg['outcome'] && S.decode_http_reply(72, [cfg['outcome']].pack('H*'))
  handler = HttpHandler.new(ProcessRef.new(realm: 72, pid: cfg.fetch('peer')), request, disposal, cfg.fetch('followup_reason', 'retry').to_sym)
  owned = ''.b
  S::Runner.open(config, handler: handler, codec: S::HttpReplyCodec.new(HttpBytes.new, realm: 72), failure: :stop, recovery: :fence_on_restart) do |runner|
    if mode == 'http-async'
      outcome = S.decode_http_reply(72, [cfg.fetch('outcome')].pack('H*'))
      reader = runner.open_http(outcome)
      first = reader.read
      check !first.data.empty? && !first.complete
      File.write(cfg.fetch('ready'), '')
      wait_file(cfg.fetch('continue'))
      interrupted = false
      controller = Thread.new do
        begin
          reader.read
        rescue InjectedException
          interrupted = true
        end
      end
      controller.report_on_exception = false
      wait_file(cfg.fetch('accepted'))
      expect(Busy) { reader.read }
      controller.raise(InjectedException)
      controller.join
      check interrupted
      runner.stop
      closing = Thread.new { runner.close }
      beats = 0
      until closing.join(0.01)
        beats += 1
      end
      closing.value
      check beats > 5 && !first.data.empty?
      expect(Closed) { reader.read }
      report(joined: true)
      return
    end
    reader = outcome = nil
    STDIN.each_line do |line|
      case line.strip
      when 'step'
        committed = false
        32.times do
          if runner.next.is_a?(S::Committed)
            committed = true
            break
          end
        end
        check committed
        expect(TurnExpired) { handler.escaped.stage_http(request) }
        expect(TurnExpired) { handler.escaped.release_http(ProcessRef.new(realm: 72, pid: cfg.fetch('peer')), request.resource, 1) }
        expect(TurnExpired) { handler.escaped.followup_http(ProcessRef.new(realm: 72, pid: cfg.fetch('peer')), disposal, :retry, request) }
        report(handler.result)
      when 'open'
        outcome = S.decode_http_reply(72, [cfg.fetch('outcome')].pack('H*'))
        check runner.http_diagnostic(outcome).nil?
        evidence = runner.http_diagnostic(outcome, kind: :native_effect)
        check evidence['code'] == 'effect.result_recorded' && evidence['outcome'] == 'completed'
        check evidence['identity']['id'] == outcome.effect.to_s
        reader = runner.open_http(outcome)
        expect(Busy) { runner.open_http(outcome) }
        first = reader.read
        check !first.data.empty? && !first.complete
        report(prefix: true)
      when 'denied'
        expect(AccessDenied) { runner.http_diagnostic(outcome) }
        expect(AccessDenied) { runner.http_diagnostic(outcome, kind: :native_effect) }
        expect(AccessDenied) { reader.read }
        report(denied: true)
      when 'reopen'
        begin
          reader.read
          raise 'Failed reader resumed'
        rescue ReadFailed => error
          check error.code == 'HttpReplayFailed'
        end
        reader.close
        reader.close
        reader = runner.open_http(outcome)
        while (part = reader.read)
          owned << part.data if part.kind == :response_body
        end
        check reader.complete
        reader.close
        report(complete: true, body: owned.unpack1('H*'))
      when 'close' then break
      else raise 'Unexpected HTTP consumer command'
      end
    end
  end
  report(closed: true, owned: owned.unpack1('H*'))
end
class GrpcBytes
  def type_id = 'test.grpc-control'
  def version = 1
  def max_encoded_bytes = 243
  def encode(value) = value.b.dup
  def decode(value) = value.b.dup
end
class GrpcHandler < S::Handler
  attr_reader :result, :escaped
  def initialize(peer, request, disposal, followup_reason)
    @peer, @request, @disposal, @followup_reason = peer, request, disposal, followup_reason
    @correlation = S::Key.new('grpc-correlation'.b, codec: E::U64)
    @release_correlation = S::Key.new('grpc-release-correlation'.b, codec: E::U64)
    @followup_correlation = S::Key.new('grpc-followup-correlation'.b, codec: E::U64)
  end
  def on_message(turn, input)
    @escaped = turn
    if input.is_a?(S::Cast)
      if input.value == 'followup'.b
        wrong = @disposal.with(resource: ResourceRef.new(realm: 73, resource: @disposal.resource.resource))
        expect(ArgumentError) { turn.retry_grpc(@peer, wrong, @request) }
        correlation = turn.retry_grpc(@peer, @disposal, @request)
        turn.state.put(@followup_correlation, correlation)
        @result = { followup: false }
      elsif input.value == 'dispose'.b
        expect(ArgumentError) { turn.release_grpc(@peer, ResourceRef.new(realm: 73, resource: @disposal.resource.resource), @disposal.exchange) }
        correlation = turn.release_grpc(@peer, @disposal.resource, @disposal.exchange)
        turn.state.put(@release_correlation, correlation)
        @result = { released: false }
      elsif turn.state.find(@correlation)
        @result = { called: true }
      elsif turn.stage_grpc(@request)
        correlation = turn.call_grpc(@peer, @request)
        turn.state.put(@correlation, correlation)
        @result = { called: true }
      else @result = { called: false }
      end
    else
      if input.is_a?(S::Reply) && input.value.is_a?(S::GrpcRejected)
        correlation = turn.state.require(@followup_correlation)
        turn.require_reply(input, peer: @peer, correlation: correlation)
        check input.value.reason == :denied
        facts = input.value.diagnostic.fetch('facts').compact.to_h { |f| [f.fetch('field'), f] }
        check facts.fetch('field_path').fetch('availability') == 'provided'
        check facts.fetch('native_input').fetch('value').fetch('unsigned').to_i > 0
        check facts.fetch('proposal').fetch('value').fetch('digest').length == 32
        turn.state.put(S::Key.new('grpc-followup-denied'.b, codec: E::U64), correlation)
        @result = { followup: true }
        return
      end
      if input.is_a?(S::Reply) && input.value.is_a?(S::GrpcReleased)
        turn.require_reply(input, peer: @peer, correlation: turn.state.require(@release_correlation))
        check input.value.resource == @disposal.resource && input.value.exchange == @disposal.exchange
        turn.state.put(S::Key.new('grpc-disposed'.b, codec: E::U64), input.value.exchange)
        @result = { released: true }
        return
      end
      check input.is_a?(S::Reply) && input.value.is_a?(S::GrpcOutcome)
      turn.require_reply(input, peer: @peer, correlation: turn.state.require(@correlation))
      check input.value.phase == :observed && input.value.status == 0
      check input.value.diagnostic.fetch('code') == 'grpc.ok_observed'
      check input.value.diagnostic.fetch('outcome') == 'completed'
      turn.state.put(S::Key.new('grpc-status'.b, codec: E::U64), 0)
      @result = { observed: true }
    end
  end
end
def grpc_consumer(mode, cfg)
  body = [cfg.fetch('body')].pack('H*')
  request = S.prepare_grpc(ResourceRef.new(realm: 72, resource: cfg.fetch('resource')), (1 << 64) - 1,
    S::GrpcRequest.new(method: S.grpc_method([cfg.fetch('descriptor')].pack('H*'), cfg.fetch('method')), metadata: [
      S::GrpcMetadata.new(name: 'x-tag', value: 'one'.b), S::GrpcMetadata.new(name: 'x-tag', value: 'two'.b),
      S::GrpcMetadata.new(name: 'x-data-bin', value: [0, 255].pack('C*')),
      S::GrpcMetadata.new(name: 'authorization', value: S::GrpcSecretRef.new(binding: 'api', version: 7))]),
    messages: [body, ''.b], endpoint_revision: 7, reconcile_before_ms: cfg.fetch('deadline'))
  body.replace('changed')
  check request.batch.frozen? && request.metadata.frozen? && request.reference.frozen? && request.batch.bytesize > 513
  config = S::ServiceConfig.new(client: ClientConfig.new(url: cfg.fetch('url'), profile: :native_v1),
    activation: S::Activation.new(process: ProcessRef.new(realm: 72, pid: cfg.fetch('pid')), generation: cfg.fetch('generation'),
      credential: Credential.new(realm: 72, principal: cfg.fetch('principal'), seed_file: cfg.fetch('seed_file'))))
  disposal = cfg['outcome'] && S.decode_grpc_reply(72, [cfg['outcome']].pack('H*'))
  handler = GrpcHandler.new(ProcessRef.new(realm: 72, pid: cfg.fetch('peer')), request, disposal, cfg.fetch('followup_reason', 'retry').to_sym)
  owned = ''.b
  S::Runner.open(config, handler: handler, codec: S::GrpcReplyCodec.new(GrpcBytes.new, realm: 72), failure: :stop, recovery: :fence_on_restart) do |runner|
    if mode == 'grpc-async'
      outcome = S.decode_grpc_reply(72, [cfg.fetch('outcome')].pack('H*'))
      reader = runner.open_grpc(outcome)
      first = reader.read
      check !first.data.empty? && !first.complete
      File.write(cfg.fetch('ready'), '')
      wait_file(cfg.fetch('continue'))
      interrupted = false
      controller = Thread.new do
        begin
          reader.read
        rescue InjectedException
          interrupted = true
        end
      end
      controller.report_on_exception = false
      wait_file(cfg.fetch('accepted'))
      expect(Busy) { reader.read }
      controller.raise(InjectedException)
      controller.join
      check interrupted
      runner.stop
      closing = Thread.new { runner.close }
      beats = 0
      until closing.join(0.01)
        beats += 1
      end
      closing.value
      check beats > 5 && !first.data.empty?
      expect(Closed) { reader.read }
      report(joined: true)
      return
    end
    reader = outcome = nil
    STDIN.each_line do |line|
      case line.strip
      when 'step'
        committed = false
        32.times do
          if runner.next.is_a?(S::Committed)
            committed = true
            break
          end
        end
        check committed
        expect(TurnExpired) { handler.escaped.stage_grpc(request) }
        expect(TurnExpired) { handler.escaped.release_grpc(ProcessRef.new(realm: 72, pid: cfg.fetch('peer')), request.resource, 1) }
        expect(TurnExpired) { handler.escaped.retry_grpc(ProcessRef.new(realm: 72, pid: cfg.fetch('peer')), disposal, request) }
        report(handler.result)
      when 'open'
        outcome = S.decode_grpc_reply(72, [cfg.fetch('outcome')].pack('H*'))
        check runner.grpc_diagnostic(outcome).nil?
        evidence = runner.grpc_diagnostic(outcome, kind: :native_effect)
        check evidence['code'] == 'effect.result_recorded' && evidence['outcome'] == 'completed'
        check evidence['identity']['id'] == outcome.effect.to_s
        reader = runner.open_grpc(outcome)
        expect(Busy) { runner.open_grpc(outcome) }
        first = reader.read
        check !first.data.empty? && !first.complete
        report(prefix: true)
      when 'denied'
        expect(AccessDenied) { runner.grpc_diagnostic(outcome) }
        expect(AccessDenied) { runner.grpc_diagnostic(outcome, kind: :native_effect) }
        expect(AccessDenied) { reader.read }
        report(denied: true)
      when 'reopen'
        begin
          reader.read
          raise 'Failed reader resumed'
        rescue ReadFailed => error
          check error.code == 'GrpcReplayFailed'
        end
        reader.close
        reader.close
        reader = runner.open_grpc(outcome)
        while (part = reader.read)
          owned << part.data if part.kind == :response_body
        end
        check reader.complete
        reader.close
        report(complete: true, body: owned.unpack1('H*'))
      when 'close' then break
      else raise 'Unexpected RPC consumer command'
      end
    end
  end
  report(closed: true, owned: owned.unpack1('H*'))
end
class DocumentBytes
  def type_id = 'test.document.tick'
  def version = 1
  def max_encoded_bytes = 32
  def encode(value) = value.dup.b
  def decode(value) = value.dup.b
end
class DocumentHandler < S::Handler
  attr_reader :phase, :escaped
  def initialize(document, changes)
    @document, @changes = document, changes
  end
  def clear = @phase = nil
  def on_start(turn) = turn.document(@document).create
  def on_message(turn, incoming)
    @escaped = turn.document(@document)
    case incoming.value
    when 'initialize' then nil
    when '0', '1'
      index = incoming.value.to_i
      @phase = @escaped.stage(index+1, @changes[index], node_limit: 256).phase
    when 'checkpoint' then @phase = @escaped.checkpoint(90).phase
    when 'window' then @escaped.merge_window(2)
    when 'retire' then @escaped.retire
    else raise 'Unexpected Document tick'
    end
  end
end

def document_consumer(mode, cfg)
  document, replica = Integer(cfg.fetch('document')), (1 << 64)-1
  resource = ResourceRef.new(realm: 72, resource: cfg.fetch('resource'))
  if mode == 'document-codecs'
    fixtures = JSON.parse(File.binread(cfg.fetch('document_fixtures')))
    fixtures.fetch('changes').each do |entry|
      bytes = [entry.fetch('wire_hex')].pack('H*')
      decoded = S.decode_document(bytes)
      check S.prepare_document(decoded).data == bytes
      [0, 1, bytes.bytesize-1].each { |length| expect(Error) { S.decode_document(bytes.byteslice(0, length)) } }
    end
    ref = S::DocumentReference.decode(72, [fixtures.fetch('reference_hex')].pack('H*'))
    check ref.document == replica && ref.revision == replica && ref.encode.unpack1('H*') == fixtures.fetch('reference_hex')
    text = '🙂'.dup
    bootstrap = S::DocumentChange.new(document: document, epoch: 1, replica: replica, first: 1, operations: [
      S::DocumentOperation.assign('value', S::DocumentValue.new(kind: :signed, value: -(1 << 63))),
      S::DocumentOperation.assign('body', S::DocumentValue.new(kind: :text)),
      S::DocumentOperation.insert(S::DocumentDot.new(counter: 2, replica: replica), S::DocumentValue.new(kind: :character, value: text))])
    prepared = S.prepare_document(bootstrap)
    text.replace('changed')
    check prepared.data.unpack1('H*') == cfg.fetch('changes')[0] && prepared.data.frozen?
    ['', 'é', "\xed\xa0\x80".dup.force_encoding('UTF-8')].each { |bad| expect(ArgumentError) { S::DocumentValue.new(kind: :character, value: bad) } }
    report(codecs: true)
    return
  end
  changes = cfg.fetch('changes').map { |bytes| S::PreparedDocumentChange.new(document: document, data: [bytes].pack('H*')) }
  config = S::ServiceConfig.new(client: ClientConfig.new(url: cfg.fetch('url'), profile: :native_v1, timeout_ms: 15_000),
    activation: S::Activation.new(process: ProcessRef.new(realm: 72, pid: cfg.fetch('pid')), generation: cfg.fetch('generation'),
      credential: Credential.new(realm: 72, principal: cfg.fetch('principal'), seed_file: cfg.fetch('seed_file'))))
  handler = DocumentHandler.new(document, changes)
  saved = nil
  S::Runner.open(config, handler: handler, codec: DocumentBytes.new) do |runner|
    STDIN.each_line do |line|
      action = line.strip
      case action
      when 'close'
        report(closed: true)
        break
      when 'one'
        handler.clear
        event = nil
        12.times do
          event = runner.next
          break if event.is_a?(S::Committed)
          check event.is_a?(S::Progress)
        end
        check event.is_a?(S::Committed)
        expect(TurnExpired) { handler.escaped.retire } if handler.escaped
        report(event: 'committed', phase: handler.phase)
      when 'read'
        description = runner.documents.describe(resource, document)
        ref = description.reference
        check description.floor.zero? && description.merge_window.zero?
        field = runner.documents.path(ref, ['value']).field
        page = runner.documents.sequence(ref, S::DocumentDot.new(counter: 2, replica: replica))
        check page.next.nil? && page.items.map { |item| item.field.assignments[0].value.value }.join == (ref.revision == 2 ? '🙂' : '🙂́')
        check field.assignments[0].value.value == -(1 << 63)
        check runner.documents.path(ref, ['missing']).field.status == :missing
        check S.prepare_document(runner.documents.accepted_change(ref)).data.unpack1('H*') == cfg.fetch('changes')[ref.revision-2]
        saved ||= ref
        report(revision: ref.revision.to_s, items: page.items.length, status: field.status)
      when 'old'
        check runner.documents.path(saved, ['value']).field.status == :scalar
        report(retained: true)
      when 'denied'
        expect(AccessDenied) { runner.documents.path(saved, ['value']) }
        report(denied: true)
      when 'resynchronize'
        sync = runner.documents.resynchronize(resource, document, replica)
        check sync.reference.revision == 3
        report(previous: sync.previous_counter.to_s, clock: sync.clock.to_s)
      when 'retired'
        check runner.documents.describe(resource, document).retired
        begin runner.documents.path(saved, ['value']); raise 'Retired read succeeded'
        rescue Error => error
          check error.code == 'DocumentRetired'
        end
        report(retired: true)
      when 'async-close'
        other = S::Runner.open(config, handler: handler, codec: DocumentBytes.new)
        reader = other.documents
        active = Thread.new do
          begin reader.describe(resource, document)
          rescue Closed
          end
        end
        Thread.pass
        other.close
        active.join
        expect(Closed) { reader.describe(resource, document) }
        report(joined: true)
      else raise 'Unexpected Document command'
      end
    end
  end
end

mode, config_file = ARGV
cfg = JSON.parse(File.binread(config_file))
check Gem.loaded_specs.fetch('transit-station').full_gem_path.start_with?(File.dirname(config_file))
check cfg.fetch('profile') == 'native_v1'
if mode.start_with?('document-')
  document_consumer(mode, cfg)
  exit
end
if mode.start_with?('grpc-')
  grpc_consumer(mode, cfg)
  exit
end
if mode.start_with?('http-')
  http_consumer(mode, cfg)
  exit
end
if mode == 'codecs'
  codecs = { 'counter' => E::CounterCodec.new, 'query' => E::QueryCodec.new, 'u64' => E::U64 }
  fixtures = JSON.parse(File.read(cfg.fetch('fixtures')))
  fixtures.fetch('valid').each do |item|
    codec = codecs.fetch(item.fetch('codec'))
    bytes = [item.fetch('hex')].pack('H*')
    value = codec.decode(bytes)
    check codec.encode(value) == bytes
    if item['codec'] == 'u64'
      check value == Integer(item.fetch('value'), 10)
    else
      check value.class.name.split('::').last == item.fetch('variant')
      %w[key value].each { |name| check(value.public_send(name) == (item[name].nil? ? nil : Integer(item[name], 10))) if item.key?(name) }
    end
  end
  fixtures.fetch('invalid').each { |item| expect(ArgumentError) { codecs.fetch(item.fetch('codec')).decode([item.fetch('hex')].pack('H*')) } }
  [true, -1, 1 << 64, 1.0].each { |value| expect(ArgumentError) { E::U64.encode(value) } }
  value = E::Add.new(value: (1 << 53) + 1)
  check S.encode_cast(value, codec: E::COUNTER) == "STN1\x01".b + [0].pack('Q<') + E::COUNTER.encode(value)
  fixture = JSON.parse(File.read(cfg.fetch('http_fixtures')))
  request = S::HttpRequest.new(method: :post, target: [S::HttpLiteral.new(value: '/write')])
  prepared = S.prepare_http(ResourceRef.new(realm: 72, resource: 8), (1 << 64) - 1, request,
    body: [fixture.fetch('body')].pack('H*'), endpoint_revision: 7, reconcile_before_ms: 9000, max_attempts: 2)
  check prepared.reference.unpack1('H*') == fixture.fetch('reference') && prepared.metadata == fixture.fetch('metadata')
  outcome = S.decode_http_reply(72, [fixture.fetch('outcome')].pack('H*'))
  check outcome.exchange == (1 << 64) - 1 && outcome.status == 200 && outcome.phase == :observed && outcome.reference
  check outcome.diagnostic.fetch('code') == 'http.response_observed' && outcome.diagnostic.frozen?
  check outcome.diagnostic.fetch('identity').fetch('id') == ((1 << 64) - 1).to_s
  rejected = S.decode_http_reply(72, [fixture.fetch('rejection')].pack('H*'))
  check rejected.reason == :denied && rejected.diagnostic.fetch('code') == 'http.request_denied'
  codec = S::HttpReplyCodec.new(E::U64, realm: 72)
  check codec.decode([fixture.fetch('outcome')].pack('H*')) == outcome
  release = [JSON.parse(File.read(cfg.fetch('http_release_fixtures'))).fetch('reply')].pack('H*')
  released = codec.decode(release)
  check released == S::HttpReleased.new(resource: ResourceRef.new(realm: 72, resource: 7), exchange: (1 << 64) - 1) && released.frozen?
  expect(CodecError) { codec.encode(released) }
  expect(Error) { S.decode_http_reply(72, release.byteslice(0, 19)) }
  check codec.decode(codec.encode((1 << 64) - 1)) == (1 << 64) - 1
  expect(Error) { S.decode_http_reply(72, [fixture.fetch('outcome')].pack('H*').byteslice(0, 70)) }
  expect(Error) { S.prepare_http(ResourceRef.new(realm: 72, resource: 8), 1,
    S::HttpRequest.new(method: :get, target: [S::HttpLiteral.new(value: '//other/')]), endpoint_revision: 1, reconcile_before_ms: 9000) }
  exit
end
if mode == 'recover'
  Client.open(ClientConfig.new(url: cfg.fetch('url'), profile: :native_v1)) do |client|
    result = client.dispatch_mutation(client.recover_mutation(File.binread(cfg.fetch('pending'))))
    check result.is_a?(Confirmed)
    report(receipt: result.receipt.position)
  end
  exit
end
peer = ProcessRef.new(realm: cfg.fetch('realm'), pid: cfg.fetch('peer'))
handler, codec = case cfg.fetch('role')
                 when 'service' then [CounterProof.new, E::COUNTER]
                 when 'requester' then [E::Requester.new(peer), E::REQUESTER]
                 when 'table' then [TableProof.new(peer, cfg.fetch('output')), E::QUERY_SERVICE]
                 when 'query' then [QueryProof.new(peer, cfg.fetch('output')), E::QUERY_REQUESTER]
                 end
if mode.start_with?('handler-', 'exception-')
  handler.define_singleton_method(:on_message) do |turn, _input|
    turn.state.put(E::TOTAL, 73)
    raise(mode.start_with?('exception-') ? InjectedException : RuntimeError, 'Injected handler failure')
  end
elsif mode == 'fiber-handler'
  handler.define_singleton_method(:on_start) { |turn| Fiber.new { turn.state.put(E::TOTAL, 73) }.resume }
elsif mode == 'codec-poison'
  handler.define_singleton_method(:on_message) do |turn, _input|
    codec = E::U64.dup
    codec.define_singleton_method(:decode) { |_bytes| raise 'Injected decode failure' }
    expect(CodecError) { turn.state.require(S::Key.new('total'.b, codec: codec)) }
  end
elsif mode == 'poison'
  handler.define_singleton_method(:on_message) { |turn, _input| expect(ReadFailed) { turn.state.require(E::TOTAL) } }
end
config = S::ServiceConfig.new(client: ClientConfig.new(url: cfg.fetch('url'), profile: :native_v1), query_results: cfg.fetch('query_results'),
  activation: S::Activation.new(process: ProcessRef.new(realm: cfg.fetch('realm'), pid: cfg.fetch('pid')), generation: cfg.fetch('generation'),
    credential: Credential.new(realm: cfg.fetch('realm'), principal: cfg.fetch('principal'), seed_file: cfg.fetch('seed_file'))))
store = Store.new(mode, cfg.fetch('pending'))
options = { handler: handler, codec: codec, failure: mode.end_with?('-block') || mode == 'codec-poison' ? :block_input : :stop, recovery: store }
if mode == 'denied'
  expect(AccessDenied) { S::Runner.open(config, **options) }
  exit
end
runner = S::Runner.open(config, **options)
store.runner = runner
begin
  if mode == 'gates'
    phases, done = Set.new, false
    40.times do
      event = runner.next
      if event.is_a?(S::NeedsRecovery)
        phases.add(event.phase)
        check event.receipt if event.phase == :confirm
        check runner.next.equal?(event)
        event = runner.reconcile
      end
      if event.is_a?(S::Committed)
        done = true
        break
      end
    end
    check done && phases == Set[:persist, :confirm]
    check store.confirmations.length == 3 && handler.initialized == 1 && handler.handled == 1
    expect(TurnExpired) { handler.escaped.require(E::TOTAL) }
    report(gates: store.confirm_failed.to_a.map(&:to_s).sort, handled: handler.handled, dispatches: store.saved.length)
  elsif mode == 'async'
    check !runner.next.is_a?(S::Committed)
    controller = Thread.new { loop { break if runner.next.is_a?(S::Committed) } }
    wait_file(File.join(cfg.fetch('output'), 'accepted'))
    expect(Busy) { runner.next }
    controller.kill.join
    runner.stop
    closing = Thread.new { runner.close }
    beats = 0
    while closing.alive?
      beats += 1
      sleep 0.01
    end
    evidence = closing.value
    check beats > 5 && evidence.pending.nil? && evidence.last_event.is_a?(S::Committed) && handler.handled == 1
    report(committed: true, beats: beats)
  elsif mode.start_with?('decode-', 'handler-', 'exception-') || mode == 'fiber-handler'
    stopped = false
    8.times do
      begin
        event = runner.next
      rescue Error => error
        check !mode.end_with?('-block')
        check error.is_a?(mode.start_with?('decode-') ? CodecError : mode == 'fiber-handler' ? Busy : HandlerError)
        stopped = true
        break
      end
      if event.is_a?(S::Blocked)
        check mode.end_with?('-block') && event.receipt
        stopped = true
        break
      end
    end
    check stopped
  elsif %w[stale expired revoked-result poison codec-poison].include?(mode)
    expected = { 'stale' => StaleOwnership, 'expired' => ProcessRetired, 'revoked-result' => AccessDenied, 'poison' => ReadFailed, 'codec-poison' => CodecError }.fetch(mode)
    expect(expected) { 8.times { runner.next } }
    report(denied: true)
  else
    STDIN.each_line do |line|
      if line.chomp == 'ready'
        report(ready: true)
        next
      end
      if line.chomp == 'close'
        runner.close
        handler.save_owned if handler.respond_to?(:save_owned)
        report(closed: true)
        break
      end
      check %w[one reconcile].include?(line.chomp)
      event = nil
      begin
        32.times do |index|
          event = line.chomp == 'reconcile' && index.zero? ? runner.reconcile : runner.next
          break unless event.is_a?(S::Progress)
        end
      rescue ReadFailed => error
        raise unless error.status == 7
        report(event: 'ReadUnavailable', code: error.code)
        next
      end
      check event.mutation.export == File.binread(cfg.fetch('pending')) if event.is_a?(S::NeedsRecovery)
      response = { event: event.class.name.split('::').last }
      response.merge!(phase: event.phase, code: event.error.code) if event.is_a?(S::NeedsRecovery)
      report(response)
    end
  end
ensure
  runner.close
end

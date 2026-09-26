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

mode, config_file = ARGV
cfg = JSON.parse(File.binread(config_file))
check Gem.loaded_specs.fetch('transit-station').full_gem_path.start_with?(File.dirname(config_file))
check cfg.fetch('profile') == 'growing_v3'
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
  exit
end
if mode == 'recover'
  Client.open(ClientConfig.new(url: cfg.fetch('url'), profile: :growing_v3)) do |client|
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
config = S::ServiceConfig.new(client: ClientConfig.new(url: cfg.fetch('url'), profile: :growing_v3), query_results: cfg.fetch('query_results'),
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
      if line.chomp == 'close'
        runner.close
        handler.save_owned if handler.respond_to?(:save_owned)
        report(closed: true)
        break
      end
      check line.chomp == 'one'
      event = nil
      32.times do
        event = runner.next
        break unless event.is_a?(S::Progress)
      end
      check event.mutation.export == File.binread(cfg.fetch('pending')) if event.is_a?(S::NeedsRecovery)
      report(event: event.class.name.split('::').last)
    end
  end
ensure
  runner.close
end

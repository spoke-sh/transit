# frozen_string_literal: true
require 'json'
require 'transit/station'
$stdout.sync = true
M = Transit::Station::Catalog
L = Transit::Station::Logical
raise 'Catalog caller did not load installed gem' unless Gem.loaded_specs.fetch('transit-station').full_gem_path.start_with?(ENV.fetch('GEM_HOME'))

def connect(config)
  c = config.fetch('connection'); s = c.fetch('scope')
  scope = M::Scope.new(resource: Transit::ResourceRef.new(realm: s.fetch('realm'), resource: s.fetch('resource')), catalog: Integer(s.fetch('catalog'), 10))
  connection = M::Connection.new(owner: Transit::ProcessRef.new(realm: s.fetch('realm'), pid: c.fetch('owner')), scope: scope)
  M::Client.new(Transit::ClientConfig.new(url: config.fetch('url'), profile: :native_v1, timeout_ms: 10000),
    Transit::Credential.new(realm: s.fetch('realm'), principal: c.fetch('principal'), seed_file: config.fetch('seed_file')), connection)
end

def persist(path, bytes)
  File.open(path, 'wb', 0o600) { |file| file.write(bytes); file.flush; file.fsync }
end

def finish(client, compiled, directory)
  persist(File.join(directory, 'intent.json'), JSON.generate(definition: compiled.saved.definition, bytes: compiled.saved.bytes.unpack1('H*')))
  reference = compiled.intent.reference
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 120
  loop do
    raise 'Table operation exceeded its budget' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
    step = client.next(reference)
    return step.outcome if step.kind == :terminal
    next if step.kind == :running
    raise 'Unexpected upload cancellation' unless step.kind == :send
    persist(File.join(directory, 'step.json'), step.prepared.data)
    position = client.submit(step.prepared)
    persist(File.join(directory, 'receipt.json'), JSON.generate(position: position))
    loop do
      raise 'Table progress exceeded its budget' if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      progress = client.progress(reference, step.prepared, position, wait: true)
      next if progress.observation == :pending
      raise "Unexpected input disposition #{progress.disposition}" unless progress.disposition.nil?
      return progress.outcome if progress.outcome&.terminal
      break
    end
  end
end

def atom(kind, value) = L::Present.new(value: L::Atom.new(kind: kind, value: value))
def assignment(column, value) = M::Assignment.new(column: column, value: value)
def check(value)
  raise 'Installed Table assertion failed' unless value
end

def scenario(client, config, directory, index)
  base = 1100 + index * 100; object = 12001 + index * 10; name = "sdk_people_#{index}"
  identity = ->(offset) { M::Identity.new(operation: base + offset, namespace: base + offset + 100000) }
  description = client.describe
  check(description.configuration.scope == client.connection.scope && description.policy.principal == config.fetch('connection').fetch('principal'))
  compiled = client.compile_sql("CREATE TABLE #{name} (id INTEGER PRIMARY KEY, payload STRUCT(data BINARY, label UTF8), amount DECIMAL(38,2))", identity.call(0), object)
  check(finish(client, compiled, directory).phase == :applied)
  original = client.lookup(name)
  check(original.schema.columns.length == 3 && original.schema.columns[1].type.is_a?(L::Structure))
  payload = L::Present.new(value: L::Sequence.new(kind: :structure, cells: [atom(:binary, [0, 128, 255].pack('C*')), atom(:utf8, '東京')]))
  amount = atom(:decimal, 123456789012345678901234567890)
  insert = client.prepare(name, identity.call(1), M::Mutate.new(basis: original.metadata.basis,
    mutation: M::Insert.new(rows: [[assignment(3, amount), assignment(1, atom(:signed, 1)), assignment(2, payload)]])))
  applied = finish(client, insert, directory)
  check(applied.counts == M::Counts.new(matched: 1, changed: 1))
  predicate = [M::Comparison.new(column: 1, op: :eq, value: L::Atom.new(kind: :signed, value: 1))]
  unchanged = client.prepare(name, identity.call(2), M::Mutate.new(basis: original.metadata.basis,
    mutation: M::Update.new(assignments: [assignment(3, amount)], predicate: predicate)))
  check(finish(client, unchanged, directory).counts == M::Counts.new(matched: 1, changed: 0))
  alter = client.prepare(name, identity.call(3), M::Alter.new(basis: original.metadata.basis,
    change: M::AddColumn.new(name: 'enabled', type: L::Scalar.new(kind: :boolean), nullable: false, default: atom(:boolean, true))))
  check(finish(client, alter, directory).phase == :applied)
  begin
    client.prepare(name, identity.call(4), M::Drop.new(basis: original.metadata.basis))
  rescue Transit::Error
    # The native caller rejects this exact stale basis before staging work.
  else
    raise 'Stale metadata retargeted Table work'
  end
  current = client.lookup(name)
  delete = client.prepare(name, identity.call(5), M::Mutate.new(basis: current.metadata.basis, mutation: M::Delete.new(predicate: predicate)))
  check(finish(client, delete, directory).counts == M::Counts.new(matched: 1, changed: 1))
  check(finish(client, client.prepare(name, identity.call(6), M::Drop.new(basis: current.metadata.basis)), directory).phase == :applied)
  check(finish(client, client.compile_sql("CREATE TABLE #{name} (replacement TEXT)", identity.call(7), object + 1), directory).phase == :applied)
  client.close
  replacement = connect(config)
  begin
    saved = insert.saved
    loaded = replacement.load(M::SavedIntent.new(definition: saved.definition, bytes: saved.bytes))
    check(loaded.object == object)
    check(replacement.status(loaded.reference).outcome == applied)
    check(replacement.lookup(name).metadata.object == object + 1)
    historical = replacement.definition(object, original.metadata.revision)
    check(historical.metadata == original.metadata && historical.schema == original.schema && !historical.respond_to?(:head))
    check(replacement.definition(object, 999).nil?)
    check(!replacement.list.entries.empty?)
  ensure
    replacement.close
  end
  { profile: 'installed-ruby-general-table', original_object: object.to_s, replacement_object: (object + 1).to_s, counts: { matched: '1', changed: '1' } }
end

path = ARGV.fetch(0); config = JSON.parse(File.binread(path)); client = connect(config)
begin
  puts JSON.generate(ready: true)
  $stdin.each_line do |line|
    action = JSON.parse(line)
    break if action.key?('close')
    result = scenario(client, config, File.dirname(path), action.fetch('scenario').fetch('index'))
    puts JSON.generate(status: 0, value: result)
  end
ensure
  client.close
end
puts JSON.generate(closed: true)

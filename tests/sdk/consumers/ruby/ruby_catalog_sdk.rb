# frozen_string_literal: true
require 'json'
require 'fileutils'
require 'transit/station'
$stdout.sync = true
M = Transit::Station::Catalog
L = Transit::Station::Logical
raise 'Catalog caller did not load installed gem' unless Gem.loaded_specs.fetch('transit-station').full_gem_path.start_with?(ENV.fetch('GEM_HOME'))
def check(value)
  raise 'Installed direct catalog assertion failed' unless value
end
def persist(path, bytes)
  File.open(path, 'wb', 0o600) { |file| file.write(bytes); file.flush; file.fsync }
end
def atom(kind, value) = L::Present.new(value: L::Atom.new(kind: kind, value: value))
def complete(client, work, directory)
  persist(File.join(directory, 'work.json'), work.saved.save)
  original = client.stage(work.intent)
  persist(File.join(directory, 'work-reference.json'), original.save)
  observed = client.admit(original)
  16.times do
    break unless observed.state == :admitted
    observed = client.execute(original, steps: 32)
  end
  check(observed.state == :committed)
  observed
end
def uncertain(original)
  begin
    yield
  rescue M::Uncertain => error
    check(error.original.save == original.save && error.status == 6 && error.diagnostic.fetch('outcome') == 'unknown' && !error.diagnostic_invalid)
    return
  end
  raise 'Expected original operation uncertainty'
end
config = JSON.parse(File.read(ARGV.fetch(0)))
c = config.fetch('connection'); s = c.fetch('scope')
scope = M::Scope.new(resource: Transit::ResourceRef.new(realm: s.fetch('realm'), resource: s.fetch('resource')), catalog: Integer(s.fetch('catalog'), 10))
connection = M::Connection.new(scope: scope, audience: c.fetch('audience'), branch: Integer(c.fetch('branch'), 10), role: c['role'])
client = M::Client.new(Transit::ClientConfig.new(url: config.fetch('url'), profile: :native_v1, timeout_ms: 10000),
  Transit::Credential.new(realm: s.fetch('realm'), principal: c.fetch('principal'), seed_file: config.fetch('seed_file')), connection, service_url: config.fetch('service_url'))
directory = File.join(File.dirname(ARGV.fetch(0)), 'ruby'); FileUtils.mkdir_p(directory)
name = 'ruby_items'; object = (1<<64)-2
compile = ->(sql, operation, create = nil) { client.compile_sql(sql, M::Identity.new(operation: operation), create) }
load_snapshot = -> { M::Snapshot.restore(File.read(File.join(directory, 'snapshot.json'))) }
begin
  puts JSON.generate(ready: true)
  $stdin.each_line do |line|
    action = JSON.parse(line); command = action.keys.fetch(0)
    break if command == 'close'
    result = case command
    when 'prepare'
      check(client.describe.subject.principal == c.fetch('principal'))
      check(client.namespace(1).name == 'public')
      check(client.namespaces.entries.map(&:id).include?(1))
      complete(client, compile.call("CREATE TABLE #{name} (id BIGINT PRIMARY KEY, payload BINARY)", 1, object), directory)
      current = client.lookup(name)
      check(current.row_count == 0 && current.basis.object == object)
      rows = 9.times.map do |i|
        [M::Assignment.new(column: 1, value: atom(:signed, i)), M::Assignment.new(column: 2, value: atom(:binary, i.chr * 32768))]
      end
      work = client.prepare(name, M::Identity.new(operation: 2), M::Mutate.new(basis: current.basis, mutation: M::Insert.new(rows: rows), ingestion: :bulk))
      check(client.preview(work.intent).current.row_count == 0)
      persist(File.join(directory, 'intent.json'), work.saved.save)
      loaded = client.load(M::SavedIntent.restore(File.read(File.join(directory, 'intent.json'))))
      original = client.stage(loaded)
      persist(File.join(directory, 'original.json'), original.save)
      check(client.admit(original).state == :admitted)
      uncertain(original) { client.execute(original, steps: 32) }
      {uncertain: true}
    when 'recover'
      original = M::Reference.restore(File.read(File.join(directory, 'original.json')))
      observed = client.inspect(original)
      check(observed.state == :committed && [observed.commit.matched,observed.commit.affected,observed.commit.live_rows] == [9,9,9])
      check(client.execute(original, steps: 32) == observed)
      current = client.lookup(name)
      acquisition = client.prepare_snapshot(current.basis, current.position, 90000)
      persist(File.join(directory, 'basis.json'), current.basis.save)
      persist(File.join(directory, 'acquisition.json'), acquisition.save)
      uncertain(acquisition) { client.acquire_snapshot(acquisition) }
      {retention_uncertain: true}
    when 'retained'
      acquisition = M::SnapshotAcquisition.restore(File.read(File.join(directory, 'acquisition.json')))
      status = client.snapshot_status(acquisition.owner)
      check(!status.released && status.snapshot)
      persist(File.join(directory, 'snapshot.json'), status.snapshot.save)
      metadata = client.snapshot_metadata(status.snapshot)
      check(metadata.accepted == acquisition.expected && metadata.row_count == 9 && metadata.schema.columns.length == 2)
      {retained: true}
    when 'denied'
      begin
        client.snapshot_metadata(load_snapshot.call)
      rescue Transit::AccessDenied => error
        check(error.status == 4 && error.diagnostic.fetch('category') == 'access')
      else raise 'Revoked retained metadata was disclosed'
      end
      {denied: true}
    when 'metadata'
      metadata = client.snapshot_metadata(load_snapshot.call)
      basis = M::Basis.restore(File.read(File.join(directory, 'basis.json')))
      check(metadata.interpretation == basis.interpretation)
      {rows: metadata.row_count, columns: metadata.schema.columns.length}
    when 'retire'
      unchanged = complete(client, compile.call("UPDATE #{name} SET id=0 WHERE id=0", 3), directory)
      check([unchanged.commit.matched,unchanged.commit.affected] == [1,0])
      deleted = complete(client, compile.call("DELETE FROM #{name} WHERE id=8", 4), directory)
      check([deleted.commit.matched,deleted.commit.affected] == [1,1])
      old = client.lookup(name)
      complete(client, client.prepare(name, M::Identity.new(operation: 5), M::Alter.new(basis: old.basis, change: M::AddColumn.new(name: 'extra', type: L::Scalar.new(kind: :int64)))), directory)
      begin
        client.prepare(name, M::Identity.new(operation: 55), M::Drop.new(basis: old.basis))
      rescue Transit::Error => error
        check(error.code == 'TableDefinitionChanged')
      else raise 'Stale basis retargeted a newer definition'
      end
      complete(client, compile.call("ALTER TABLE #{name} RENAME TO #{name}_old", 6), directory)
      complete(client, compile.call("DROP TABLE #{name}_old", 7), directory)
      complete(client, compile.call("CREATE TABLE #{name} (replacement BIGINT)", 8, object-1), directory)
      check(client.lookup(name).basis.object == object-1)
      check(client.snapshot_metadata(load_snapshot.call).row_count == 9)
      {original: true}
    when 'release'
      snapshot = load_snapshot.call
      check(!client.snapshot_status(snapshot.owner).released)
      uncertain(snapshot) { client.release_snapshot(snapshot) }
      {release_uncertain: true}
    when 'verify'
      snapshot = load_snapshot.call
      check(client.snapshot_status(snapshot.owner).released)
      client.release_snapshot(snapshot)
      original = M::Reference.restore(File.read(File.join(directory, 'original.json')))
      check(client.inspect(original).commit.affected == 9)
      check(client.load(M::SavedIntent.restore(File.read(File.join(directory, 'intent.json')))).identity.operation == 2)
      check(client.lookup(name).basis.object == object-1 && client.tables.consistency == :independent)
      {recovered: true}
    else raise "Unknown proof phase: #{command}"
    end
    puts JSON.generate(status: 0, value: result)
  end
ensure
  client.close
end
puts JSON.generate(closed: true)

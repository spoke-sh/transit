# frozen_string_literal: true
require 'transit/station'
require 'timeout'
M = Transit::Station::Catalog
I = Transit.const_get(:Internal)
def rejects(*kinds)
  begin
    yield
  rescue *kinds => error
    return error
  end
  raise "Expected #{kinds}"
end
scope = M::Scope.new(resource: Transit::ResourceRef.new(realm: 46, resource: 7), catalog: (1 << 64)-1)
rejects(ArgumentError) { M::Scope.new(resource: scope.resource, catalog: true) }
rejects(ArgumentError) { M::Scope.new(resource: scope.resource, catalog: 1 << 64) }
rejects(ArgumentError) { M::Connection.new(owner: Transit::ProcessRef.new(realm: 47, pid: 1), scope: scope) }
rejects(ArgumentError) { M::PolicyChange.new(expected_revision: -1, policy: nil) }
text = +'opaque recovery bytes'
prepared = M::Prepared.new(data: text); text.clear
raise 'Prepared borrowed caller bytes' unless prepared.data == 'opaque recovery bytes' && prepared.data.frozen?
names = [+'id', +'value']; schema = M::Schema.new(names: names, value_type: :utf8)
names[0].clear; names.clear
raise 'Schema borrowed caller names' unless schema.names == %w[id value] && schema.names.frozen? && schema.names.all?(&:frozen?)
request = M::CreateTable.new(scope: scope, operation: (1 << 64)-1, object: (1 << 64)-1, table: (1 << 32)-1, name: 'items', schema: schema)
bytes = +'canonical'; compiled = M::Compiled.new(request: request, canonical: bytes); bytes.clear
raise 'Compiled bytes were borrowed' unless compiled.canonical == 'canonical' && compiled.canonical.frozen?

class Reply
  attr_accessor :response, :entered, :release
  attr_reader :closed
  def catalog(_)
    if entered
      entered << true
      release.pop
    end
    raise response if response.is_a?(Exception)
    response
  end
  def evidence = nil
  def close = @closed = true
end
def owner(reply)
  client = M::Client.allocate
  client.instance_variable_set(:@worker, I::Worker.new { reply })
  client
end
reply = Reply.new; client = owner(reply)
client.instance_variable_set(:@connection, M::Connection.new(owner: Transit::ProcessRef.new(realm: 46, pid: 3), scope: scope))
begin
  [NoMemoryError.new('injected result allocation'), nil, {}, {'receipt'=>{'position'=>0}}, {'receipt'=>{'position'=>'1'}}, {'receipt'=>{'position'=>1.5}},
   {'receipt'=>{'position'=>1},'extra'=>true}, {'receipt'=>{'position'=>1,'extra'=>true}}].each do |value|
    reply.response = value
    error = rejects(M::Uncertain) { client.submit(prepared) }
    raise 'Uncertainty changed recovery value' unless error.prepared.equal?(prepared)
  end
  reply.response = {'receipt'=>{'position'=>1}}
  raise 'Wrong admission' unless client.submit(prepared) == 1
  reply.response = Transit::AccessDenied.new('Denied', status: 4, code: 'AccessDenied')
  raise 'Definite rejection changed' unless rejects(Transit::AccessDenied) { client.submit(prepared) }.equal?(reply.response)
  reply.response = {'status'=>{'request'=>request.wire,'principal'=>17,'input'=>1,'outcome'=>'applied'}}
  raise 'Lost full-width identity' unless client.status(request).request.object == (1 << 64)-1
  reply.response['status']['request']['object'] = '1'
  rejects(Transit::IncompatibleNative) { client.status(request) }
  [(1 << 64)-1, '01', '+1', '18446744073709551616'].each do |bad|
    reply.response['status']['request']['object'] = bad
    rejects(Transit::IncompatibleNative, ArgumentError) { client.status(request) }
  end
  metadata = { 'scope' => scope.wire, 'object' => ((1 << 64)-1).to_s, 'revision' => ((1 << 64)-1).to_s, 'name' => 'items',
    'source' => { 'table' => { 'id' => (1 << 32)-1, 'schema' => schema.wire } }, 'principal' => 17, 'operation' => ((1 << 64)-1).to_s, 'input' => 2 }
  token = { 'definition' => I::CONTRACT.fetch('definition'), 'scope' => scope.wire, 'resource_revision' => 3, 'after' => 'items' }
  page = { 'resource_revision' => 3, 'entries' => [metadata] + [nil] * 7, 'next' => token }
  copy = ->(value) { JSON.parse(JSON.generate(value)) }
  reply.response = { 'page' => copy.call(page) }
  retained = client.list
  raise 'Lost definition width' unless retained.entries.first.object == (1 << 64)-1 && retained.entries.first.revision == (1 << 64)-1
  raise 'Lost Table width' unless retained.entries.first.source.table == (1 << 32)-1
  reply.response['page']['entries'][0]['source']['table']['schema']['names'][0].clear
  raise 'Borrowed metadata names' unless retained.entries.first.source.schema.names == %w[id value]
  raise 'Mutable metadata page' unless retained.frozen? && retained.entries.frozen? && retained.next.after.frozen?
  entries = retained.entries.dup
  public_page = M::Page.new(resource_revision: 3, entries: entries, next: retained.next)
  entries.clear
  raise 'Borrowed page entries' unless public_page.entries == retained.entries
  reply.response = { 'definition' => copy.call(metadata) }
  raise 'Wrong name lookup' unless client.lookup('items') == retained.entries.first
  raise 'Wrong exact lookup' unless client.definition((1 << 64)-1, (1 << 64)-1) == retained.entries.first
  rejects(Transit::IncompatibleNative) { client.lookup('other') }
  rejects(Transit::IncompatibleNative) { client.definition(1, 1) }
  %i[hole order scope cut next_name missing_definition foreign_definition numeric_object unknown_source].each do |defect|
    bad = copy.call(page)
    case defect
    when :hole then bad['entries'][1], bad['entries'][0] = bad['entries'][0], nil
    when :order then bad['entries'][1] = copy.call(metadata)
    when :scope then bad['entries'][0]['scope']['catalog'] = '1'
    when :cut then bad['next']['resource_revision'] += 1
    when :next_name then bad['next']['after'] = 'other'
    when :missing_definition then bad['next'].delete('definition')
    when :foreign_definition then bad['next']['definition'] = '0' * 64
    when :numeric_object then bad['entries'][0]['object'] = (1 << 64)-1
    when :unknown_source then bad['entries'][0]['source'] = { 'document' => {} }
    end
    reply.response = { 'page' => bad }
    rejects(Transit::IncompatibleNative) { client.list }
  end
  reply.response = { 'page' => copy.call(page) }
  rejects(Transit::IncompatibleNative) { client.list(retained.next) }
  reply.response = { 'page' => { 'resource_revision' => 4, 'entries' => [nil] * 8, 'next' => nil } }
  rejects(Transit::IncompatibleNative) { client.list(retained.next) }
  reply.response['page']['resource_revision'] = 3
  raise 'Missing empty terminal page' unless client.list(retained.next).entries.empty?
  reply.response = { 'definition' => nil }
  raise 'Missing definition was not absent' unless client.lookup('absent').nil? && client.definition(1, 1).nil?
ensure
  client.close
end
raise 'Owner did not close' unless reply.closed
rejects(Transit::Closed) { client.capabilities }

# A real owned child exercises generated response validation and transport loss.
require 'tmpdir'
Dir.mktmpdir('transit-catalog-replies-') do |directory|
  schemas = I::SCHEMAS.merge(JSON.parse(File.binread(File.join(Gem.loaded_specs.fetch('transit-station').full_gem_path,
    'lib/transit/station/schemas.json'))))
  [nil, {'status'=>0,'value'=>{'receipt'=>{'position'=>'1'}}},
   {'status'=>0,'value'=>{'receipt'=>{'position'=>1},'extra'=>true}}].each_with_index do |response, index|
    host = File.join(directory, "host-#{index}")
    program = "#!/usr/bin/env ruby\nrequire 'json'\n$stdout.sync = true\n$stdin.gets\n"
    program += response.nil? ? "exit 0\n" : "puts #{JSON.generate(response).inspect}\n$stdin.each_line {}\n"
    File.write(host, program); File.chmod(0o700, host)
    bridge = Transit::Station.const_get(:Bridge).allocate
    bridge.instance_variable_set(:@port, I::Port.new(host, {}, schemas, 'HostRequest'))
    client = owner(bridge)
    begin
      error = rejects(M::Uncertain) { client.submit(prepared) }
      raise 'Port failure changed recovery value' unless error.prepared.equal?(prepared)
    ensure
      client.close
    end
  end
end

# A cancelled waiting thread must not release the worker's active operation.
reply = Reply.new; reply.entered = Queue.new; reply.release = Queue.new
reply.response = {'receipt'=>{'position'=>2}}; client = owner(reply)
pending = Thread.new { client.submit(prepared) }
begin
  Timeout.timeout(5) { reply.entered.pop }
  pending.kill; pending.join
  rejects(Transit::Busy) { client.capabilities }
  closing = Thread.new { client.close }
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
  Thread.pass until closing.status == 'sleep' || Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
  raise 'Close released active work' unless closing.alive? && !reply.closed
  reply.release << true
  Timeout.timeout(5) { closing.value }
  raise 'Close did not join cleanup' unless reply.closed
ensure
  reply.release << true
  pending.kill; pending.join
  client.close
end
puts 'Ruby catalog values, owned full-width definitions/pages, strict continuations, uncertain receipts and joined cancellation passed.'

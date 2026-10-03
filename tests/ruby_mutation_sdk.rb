# frozen_string_literal: true
require 'json'
require 'transit/station'
$stdout.sync = true
M = Transit::Station::Mutations
cfg = JSON.parse(File.binread(ARGV.fetch(0)))
c = cfg.fetch('connection')
connection = M::Connection.new(writer: Transit::ProcessRef.new(realm: c.fetch('realm'),pid: c.fetch('writer')),
  resource: Transit::ResourceRef.new(realm: c.fetch('realm'),resource: c.fetch('resource')),table: c.fetch('table'))
config = Transit::ClientConfig.new(url: cfg.fetch('url'),profile: :native_v1,timeout_ms: 10000)
credential = Transit::Credential.new(realm: c.fetch('realm'),principal: c.fetch('principal'),seed_file: cfg.fetch('seed_file'))

def reference(value) = M::Reference.new(data: [value].pack('H*'))
def prepared(value) = M::Prepared.new(data: value)
def compiled(value)
  bytes = [value.fetch('request')].pack('H*')
  ref = [value.fetch('reference')].pack('H*')
  result = M::Compiled.new(request: bytes,reference: M::Reference.new(data: ref))
  bytes.clear; ref.clear
  raise 'Mutation bytes were borrowed' unless result.request.unpack1('H*') == value.fetch('request') &&
    result.reference.data.unpack1('H*') == value.fetch('reference') && result.request.frozen? && result.reference.data.frozen?
  result
end

def call(client,action)
  name,value = action.first
  case name
  when 'capabilities' then {capabilities: {version: 1,max_rows: 3}}
  when 'describe'
    v = client.describe
    {description: {resource: v.resource.resource,table: v.table,names: v.names,value_type: v.value_type,
      resource_revision: v.resource_revision,policy_revision: v.policy_revision.to_s,declaration: v.declaration.unpack1('H*'),
      permissions: v.permissions,active: v.active&.to_s}}
  when 'compile'
    v = client.compile_sql(value.fetch('name'),value.fetch('sql'),Integer(value.fetch('namespace'),10))
    {compiled: {request: v.request.unpack1('H*'),reference: v.reference.data.unpack1('H*')}}
  when 'next' then {prepared: client.prepare_next(compiled(value))&.data}
  when 'prepare'
    control,ref = value.first
    raise 'Unsupported control' unless %w[apply cancel].include?(control)
    {prepared: client.public_send("prepare_#{control}",reference(ref)).data}
  when 'submit' then {receipt: {position: client.submit(prepared(value))}}
  when 'observe' then {observation: client.observe(prepared(value.fetch('prepared')),value.fetch('input'))}
  when 'rejection'
    v = client.rejection(prepared(value.fetch('prepared')),value.fetch('input'))
    {rejection: v && {principal: v.principal,input: v.input,payload: v.payload.unpack1('H*'),reason: v.reason,diagnostic: v.diagnostic}}
  when 'status'
    v = client.status(reference(value))
    {status: v && {reference: v.reference.data.unpack1('H*'),principal: v.principal,table: v.table,
      declaration: v.declaration.unpack1('H*'),policy_revision: v.policy_revision.to_s,phase: v.phase,
      affected_rows: v.affected_rows,reason: v.reason,input: v.input,diagnostic: v.diagnostic,conflict: v.conflict && {key: v.conflict.key.to_s,row: v.conflict.row}}}
  else raise 'Unsupported mutation test action'
  end
end

M::Client.open(config,credential,connection) do |client|
  puts JSON.generate(ready: true)
  $stdin.each_line do |line|
    action = JSON.parse(line)
    break if action.key?('close')
    begin
      puts JSON.generate(status: 0,value: call(client,action))
    rescue Transit::Error => error
      if error.is_a?(M::Uncertain)
        raise 'Uncertainty lost the original command' unless error.prepared.data == action.fetch('submit')
      end
      puts JSON.generate(status: error.status,value: {err: error.code, diagnostic: error.diagnostic, diagnostic_invalid: error.diagnostic_invalid})
    end
  end
end
puts JSON.generate(closed: true)

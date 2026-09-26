# frozen_string_literal: true
require 'transit/client'
require 'json'

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
mode, config_file = ARGV
cfg = JSON.parse(File.binread(config_file))
check Gem.loaded_specs.fetch('transit-client').full_gem_path.start_with?(File.dirname(config_file))
check !Gem.loaded_specs.key?('transit-station')
config = Transit::ClientConfig.new(url: cfg.fetch('url'), profile: :growing_v3, timeout_ms: 3000)
credential = Transit::Credential.new(realm: 72, principal: 65_536, seed_file: cfg.fetch('seed'))
peer = Transit::ProcessRef.new(realm: 72, pid: cfg.fetch('pid'))
expect(ArgumentError) { Transit::ProcessRef.new(realm: 72, pid: true) }
expect(ArgumentError) { Transit::ProcessRef.new(realm: 72, pid: 1 << 53) }
expect(Transit::IncompatibleNative) { Transit::Client.open(config.with(native_host: '/missing-transit')) }
case mode
when 'first'
  # Trusted-path overrides still need compatible framing and versions. Exercise
  # failures through the installed artifact, with bounded fake native children.
  fake = File.join(File.dirname(config_file), 'native-fixture')
  File.write(fake, "#!#{RbConfig.ruby}\nrequire 'json'\nSTDOUT.sync=true\nwhile STDIN.gets; puts JSON.generate(status:0,value:{host_version:99,transit_version:1}); end\n")
  File.chmod(0o700, fake)
  expect(Transit::IncompatibleNative) { Transit::Client.open(config.with(native_host: fake)) }
  schemas = { 'Request' => { 'type' => 'object', 'additionalProperties' => false, 'properties' => {}, 'required' => [] } }
  ['STDOUT.write("x" * 540673)', 'STDOUT.write("\\xff\\n".b)', 'puts JSON.generate(status:99,value:nil)', 'STDOUT.write("{")'].each do |body|
    File.write(fake, "#!#{RbConfig.ruby}\nrequire 'json'\nSTDIN.gets\n#{body}\n")
    [false, true].each do |mutation|
      port = Transit::Internal::Port.new(fake, {}, schemas, 'Request')
      begin
        expect(mutation ? Transit::UnknownOutcome : Transit::ReadFailed) { port.request({}, phase: :fixture, mutation: mutation) }
      ensure
        port.close
      end
    end
  end
  # Block acquisition defers interruption until its ensure owns the new client.
  # Interrupt while a real native host is starting, then prove both owners join.
  require 'transit/native_client'
  marker = File.join(File.dirname(config_file), 'opening-native-pid')
  File.write(fake, "#!#{RbConfig.ruby}\nFile.write(#{marker.inspect}, Process.pid.to_s)\nsleep 0.3\nexec(#{Transit::NativeClient::HOST.inspect}, ARGV.fetch(0))\n")
  before = Thread.list.length
  opening = Thread.new { Transit::Client.open(config.with(native_host: fake)) { raise 'Interrupted open must not yield' } }
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 10
  until File.exist?(marker)
    check Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    sleep 0.005
  end
  opening.kill.join
  check Thread.list.length == before
  expect(Errno::ESRCH) { Process.kill(0, Integer(File.read(marker), 10)) }
  File.unlink(fake)
  Transit::Client.open(config) do |client|
    caps = client.capabilities(credential)
    check caps.principal_sequence.zero? && caps.page_size == 8 && caps.retained_versions
    payload = 'wide'.b
    pending = client.prepare_send(peer, payload, credential: credential, sequence: 1)
    bytes = pending.export
    payload.replace('changed')
    pending.export.replace('changed')
    check pending.export == bytes
    check !pending.inspect.include?('signature') && !credential.inspect.include?(cfg['seed'])
    File.binwrite(cfg.fetch('pending'), bytes)
    result = client.dispatch(pending)
    check result.is_a?(Transit::Uncertain) && result.error.status == 6 && result.recovery == bytes
    pending.close
    expect(Transit::Closed) { pending.export }
  end
when 'recover'
  check !File.exist?(cfg.fetch('seed'))
  Transit::Client.open(config) do |client|
    pending = client.recover_send(File.binread(cfg.fetch('pending')))
    receipt = client.dispatch(pending).receipt
    check client.evidence.last_admission == receipt && client.dispatch(pending).receipt == receipt
    puts JSON.generate(position: receipt.position)
    expect(Transit::UnsupportedCapability) { client.recover_send(File.binread(cfg.fetch('spawn'))) }
    expect(Transit::Error) { client.recover_send(' ' + pending.export) }
  end
when 'async'
  client = Transit::Client.open(config)
  begin
    pending = client.prepare_send(peer, 'async'.b, credential: credential, sequence: 2)
    bytes = pending.export
    controller = Thread.new { client.dispatch(pending); raise 'Controller should be interrupted before native completion' }
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 15
    until File.exist?(cfg.fetch('accepted'))
      check Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      sleep 0.005
    end
    expect(Transit::Busy) { client.capabilities(credential) }
    controller.kill.join
    closing = Thread.new { client.close }
    beats = 0
    while closing.alive?
      beats += 1
      sleep 0.01
    end
    evidence = closing.value
    check beats > 5 && evidence.last_admission
    expect(Transit::Closed) { client.recover_send(bytes) }
    Transit::Client.open(config) do |fresh|
      check fresh.dispatch(fresh.recover_send(bytes)).receipt == evidence.last_admission
    end
    puts JSON.generate(scenario: 'blocking-owner-disposal', observations: {
      controller_wait_abandoned: true, responsive_during_join: beats > 5, owned_work_joined: true, receipt_recovered: true })
  ensure
    client.close
  end
when 'denied'
  Transit::Client.open(config) do |client|
    pending = client.recover_send(File.binread(cfg.fetch('pending')))
    result = client.dispatch(pending)
    check result.is_a?(Transit::Rejected) && result.error.is_a?(Transit::AccessDenied) && result.error.status == 4
  end
else raise 'Unknown mode'
end

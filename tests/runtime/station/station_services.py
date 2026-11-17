"""Qualify framework services and their separately credentialed controllers."""
import json
import struct
import signal
import time
from pathlib import Path

from interfaces.inspection.inspection import System
from harness.services import wait_ready
from runner.paths import ROOT
from runtime.station.station_service_transport import configure as configure_transport
from runtime.station.station import frame
from runtime.station.station_ledger import AUDIT, audit_state, audit_total, provision


def run(server, cli, worker):
    with System(server, cli, clock_error_ms=10000, request_timeout_ms=5000, server=server, server_setup=configure_transport) as s:
        configs = {}
        resources = {}
        serial = 0

        def command(pid, payload):
            return s.command({"send": {"pid": pid, "value": frame(payload)}})

        def worker_once(pid, success=True):
            nonlocal serial
            serial += 1
            path = s.root / f"worker-{serial}.json"
            path.write_text(json.dumps(configs[pid]))
            process = s.start(worker, "--once", path)
            assert (process.wait(timeout=20) == 0) == success

        def create(principal, role, destination=None):
            pid = s.command({"create": {"required": [b"data".hex(), None, None, None]}})
            resource = s.command({"create_resource": {"writer": pid}})
            seed, public = s.key(role)
            if role == 'coordinator':
                s.command({"grant": {"subject": principal, "public_key": public, "permissions": 88, "pid": pid}})
            for subject in ((0, principal) if role == 'coordinator' else (0,)):
                s.command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
            s.command({"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}})
            command(pid, b"init")
            s.command({"initialize": {"pid": pid, "expected_generation": 1}})
            configs[pid] = {"url": s.url, "realm": 72, "principal": principal, "pid": pid,
                            "generation": 3, "seed_file": str(seed), "role": role,
                            "destination": destination, "observer": 5}
            resources[pid] = resource
            return pid

        ledger = create(1, "ledger")
        requester = create(2, "requester", ledger)
        coordinator = create(4, "coordinator", ledger)
        provision(s, [(resources[pid], configs[pid]) for pid in (ledger, requester)])
        for pid in (ledger, requester, coordinator):
            s.command({'own': dict(pid=pid, worker=configs[pid]['principal'], expected_generation=2)})
            worker_once(pid)
        # A PID-scoped actuator reads its supervisor's intent through an explicit
        # optional association as well as a separate read grant.
        s.command({"suspend": {"pid": ledger, "expected_generation": 3,
                               "resume_before_ms": int(time.time() * 1000) + 60000}})
        s.command({"associate": {"pid": ledger, "name": b"supervisor".hex(),
                                "resource": resources[coordinator], "required": False}})
        s.command({"resume": {"pid": ledger, "expected_generation": 5}})
        s.command({"own": {"pid": ledger, "worker": 1, "expected_generation": 6}})
        configs[ledger]["generation"] = 7
        configs[requester]["registry"] = coordinator
        observer_seed, public = s.key("observer")
        s.command({"grant": {"subject": 5, "public_key": public, "permissions": 20}})
        admin_seed, public = s.key("scoped-admin")
        s.command({"grant": {"subject": 6, "public_key": public, "permissions": 17, "pid": ledger}})
        for resource, subject in ((resources[requester], 5), (resources[coordinator], 5), (resources[coordinator], 6)):
            s.command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 3}})

        manifest = s.root / 'station-services.json'
        manifest.write_text(json.dumps(dict(version=1,
            definition=json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'],
            realm=72, services=[
                dict(name='observer', principal=5, seed_file=str(observer_seed), mode='observe',
                     watches=[dict(pid=requester, resource=resources[requester]), dict(pid=coordinator, resource=resources[coordinator])]),
                dict(name='lifecycle', principal=6, seed_file=str(admin_seed), mode='lifecycle',
                     watches=[dict(pid=coordinator, resource=resources[coordinator], child=ledger)])])))
        s.server.config['station'] = dict(file=str(manifest))
        s.server.path.write_text(json.dumps(s.server.config))
        original = manifest.read_bytes()
        # Invalid initial declarations must not freeze an unusable registration.
        for fault, cause in (('realm', 'InvalidStationManifest'), ('writer', 'InvalidWatch'), ('credential', 'FileNotFound')):
            s.server.stop()
            invalid = json.loads(original)
            if fault == 'realm': invalid['realm'] += 1
            elif fault == 'writer': invalid['services'][0]['watches'][0]['pid'] = coordinator
            else: invalid['services'][0]['seed_file'] = str(s.root / 'absent-private-seed')
            manifest.write_text(json.dumps(invalid))
            s.server.start()
            assert s.server.process.wait(timeout=45) != 0
            assert cause in Path(s.server.logs[-1].name).read_text()
            assert s.server.record()['station_manifest'] is None
            assert not (s.server.installation / 'server-ready').exists()
        manifest.write_bytes(original)
        s.restart_authority()
        assert s.native_query({'capabilities': {}})['principal_sequence'] == s.sequence
        previous_boot = json.loads((s.server.installation / 'station/observer/status.json').read_text())['boot']
        s.server.signal_role('/station/observer/config.json', signal.SIGSTOP)
        s.server.ready(timeout=40)
        assert json.loads((s.server.installation / 'station/observer/status.json').read_text())['boot'] != previous_boot

        def control(mode, watches):
            # The continuously running server role must finish fresh passes,
            # including watches after the first durable page.
            name = 'observer' if mode == 'observe' else 'lifecycle'
            path = s.server.installation / 'station' / name / 'status.json'
            previous = json.loads(path.read_text())
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                current = json.loads(path.read_text())
                if current['ready'] and current['boot'] == previous['boot'] and current['completed_passes'] >= previous['completed_passes'] + 2:
                    return
                assert s.server.process.poll() is None
                time.sleep(.05)
            raise AssertionError(('Station progress stalled', name, current))

        def await_input(pid):
            for _ in range(200):
                if s.native_query({"process": pid})["body"]["process"]["input"] is not None:
                    return
                time.sleep(.025)
            raise AssertionError(("missing input", pid))

        # Explicit admission refusals must withdraw readiness without replacing
        # a live sequencer or exhausting its transport-failure restart budget.
        status_path = s.server.installation / 'station/observer/status.json'
        pressure_boot = json.loads(status_path.read_text())['boot']
        pressure = s.server.root / 'station-pressure.json'
        pressure.with_suffix('.tmp').write_text(json.dumps(dict(until=time.monotonic() + 4)))
        pressure.with_suffix('.tmp').replace(pressure)
        deadline = time.monotonic() + 3
        while (s.server.installation / 'server-ready').exists() or json.loads(status_path.read_text())['ready']:
            assert time.monotonic() < deadline, 'Station admission pressure did not withdraw readiness'
            assert s.server.process.poll() is None
            time.sleep(.025)
        assert not json.loads(status_path.read_text())['ready']
        wait_ready(s.server.http, s.server.process, s.url + '/health')
        assert json.loads(status_path.read_text())['boot'] == pressure_boot
        assert json.loads((s.server.root / 'station-pressure-observed.json').read_text())['count'] >= 3
        pressure.unlink()
        control('observe', [])
        print('Station service admission: readiness withdrawal and same-boot recovery after repeated capacity refusals passed.', flush=True)

        def value(pid, key):
            resource = resources[pid]
            revision = s.native_query({'resource': resource})['body']['resource']['revision']
            entry = s.native_query({'entries': {'resource': resource, 'revision': revision, 'key': key.hex()}})['body']['entries']['page']['entries'][0]
            return bytes.fromhex(entry['value']) if entry else None

        def pump_until(predicate, pids=(ledger, requester)):
            until = time.monotonic() + 60
            while not predicate():
                assert time.monotonic() < until, 'Staged ledger work did not complete'
                progressed = False
                for pid in pids:
                    if s.native_query({'process': pid})['body']['process']['input'] is not None:
                        worker_once(pid)
                        progressed = True
                if not progressed: time.sleep(.025)

        command(ledger, b'prepare-table')
        prepared = command(ledger, b'0')
        pump_until(lambda: value(ledger, AUDIT + prepared.to_bytes(8, 'big')) is not None)

        # Coordinator initialization records a separate self-turn to respect
        # the shared four-mutation bound.
        await_input(coordinator)
        worker_once(coordinator)

        def registration(operation, revision, destination):
            return b"RGQ1" + bytes([operation]) + struct.pack("<IQQB", 1, revision, destination, 6) + b"ledger"

        # Mutations and lookup rights are independent; revisions are durable.
        command(coordinator, f"lookup-peer:{requester}".encode())
        worker_once(coordinator)
        command(coordinator, registration(2, 0, ledger))
        worker_once(coordinator)
        lookup_input = command(requester, b"lookup")
        worker_once(requester)
        await_input(coordinator)
        worker_once(coordinator)
        # Rebind before the caller processes its resolved-PID reply.
        command(coordinator, registration(3, 1, requester))
        worker_once(coordinator)
        await_input(requester)
        worker_once(requester)
        resolved = value(requester, b"\x00r" + lookup_input.to_bytes(8, "little") + b"\x00")
        assert int.from_bytes(resolved[24:32], "little") == ledger
        await_input(ledger)
        # Registry.route sends an uncorrelated cast to the recorded old PID.
        # Its second audit entry proves completion even though the value is zero.
        pump_until(lambda: audit_state(s.native_query, resources[ledger]) == (0, 2))

        # Deadline observations are explicit mailbox input. The worker can be
        # replaced while a call waits without losing its timeout or correlation.
        deadline = int(time.time() * 1000) - 1
        timed_input = command(requester, f"wait:{deadline}:7".encode())
        worker_once(requester)
        s.command({"own": {"pid": requester, "worker": 2, "expected_generation": 3}})
        configs[requester]["generation"] = 4
        s.server.stop(kill=True)
        s.restart_authority()
        control("observe", [{"pid": requester, "resource": resources[requester]}])
        await_input(requester)
        worker_once(requester)
        assert value(requester, b"answer") == b"timeout"
        waiting = value(requester, b"\x00w" + timed_input.to_bytes(8, "little"))
        assert len(waiting) == 34
        assert waiting[1] == 3
        pump_until(lambda: audit_total(s.native_query, resources[ledger]) == 7)
        pump_until(lambda: value(requester, b'\x00disposition') == b'station.closed-reply.v1')
        assert value(requester, b"answer") == b"timeout"

        # A supervisor records intent; only the separately scoped admin applies it.
        bad_input = command(ledger, b"invalid")
        pump_until(lambda: (s.native_query({'process': ledger})['body']['process']['input'] or {}).get('position') == bad_input, (ledger,))
        worker_once(ledger, success=False)
        watch = [{"pid": coordinator, "resource": resources[coordinator], "child": ledger}]
        control("observe", watch)
        await_input(coordinator)
        child_key = b"\x00c" + ledger.to_bytes(8, "little") + b"\x00"
        pump_until(lambda: (value(coordinator, child_key) or bytes(15))[13] == 1, (coordinator,))
        child = value(coordinator, child_key)
        assert child[13] == 1 and child[14] == 3  # one durable retry request
        s.command({"own": {"pid": coordinator, "worker": 4, "expected_generation": 3}})
        configs[coordinator]["generation"] = 4
        control("lifecycle", watch)
        process = s.inspect("process", ledger)["processes"][0]
        assert process["failure"] is None
        attempts = [json.loads(line) for line in (s.server.root / 'lifecycle-transport.jsonl').read_text().splitlines()]
        assert attempts and len({(attempt['sha256'], attempt['sequence'], attempt['position']) for attempt in attempts}) == 1

        assert s.native_query({"process": ledger})["body"]["process"]["input"]["position"] == bad_input
        # Manager loss preserves accepted retry progress and its original input.
        s.restart_authority()
        control("lifecycle", watch)
        assert s.inspect("process", ledger)["processes"][0]["generation"] == process["generation"]
        control("observe", watch)
        await_input(coordinator)
        pump_until(lambda: value(coordinator, child_key)[14] == 1, (coordinator,))
        generation = process["generation"]
        s.command({"own": {"pid": ledger, "worker": 1, "expected_generation": generation}})
        configs[ledger]["generation"] = generation + 1
        worker_once(ledger, success=False)
        control("observe", watch)
        await_input(coordinator)
        pump_until(lambda: value(coordinator, child_key)[14] == 4, (coordinator,))
        assert value(coordinator, child_key)[14] == 4  # exhausted; head retained
        s.command({"terminate": ledger})
        control("observe", watch)
        await_input(coordinator)
        pump_until(lambda: value(coordinator, child_key)[14] == 5, (coordinator,))
        assert value(coordinator, child_key)[14] == 5
        control("lifecycle", watch)  # retirement never becomes retry/spawn
        assert s.inspect("process", ledger)["processes"][0]["lifecycle"] == "terminated"
        # One configured supervisor contains more children than a read page.
        # A complete server pass must reach every terminal child.
        children = []
        for _ in range(9):
            child = s.command({"spawn": {}})
            children.append(child)
            command(coordinator, f"watch:{child}".encode())
            pump_until(lambda: value(coordinator, b"\x00c" + child.to_bytes(8, "little") + b"\x00") is not None, (coordinator,))
            s.command({"terminate": child})
        control("observe", [{"pid": coordinator, "resource": resources[coordinator]}])
        pump_until(lambda: all(value(coordinator, b"\x00c" + child.to_bytes(8, "little") + b"\x00")[14] == 5 for child in children), (coordinator,))
        for child in children:
            assert value(coordinator, b"\x00c" + child.to_bytes(8, "little") + b"\x00")[14] == 5
        # Frozen registration cannot be changed or silently removed on restart.
        accepted_manifest = manifest.read_bytes()

        def rejected_restart(cause):
            s.server.stop()
            s.server.start()
            assert s.server.process.wait(timeout=45) != 0
            assert cause in Path(s.server.logs[-1].name).read_text()
            assert not (s.server.installation / 'server-ready').exists()

        s.server.stop()
        record_path = s.server.installation / 'installation.json'
        retained_record = record_path.read_bytes()
        missing_obligation = json.loads(retained_record)
        missing_obligation.pop('station_manifest')
        record_path.write_text(json.dumps(missing_obligation))
        rejected_restart('MissingField')
        record_path.write_bytes(retained_record)
        changed = json.loads(accepted_manifest)
        changed['services'][0]['watches'].pop()
        manifest.write_text(json.dumps(changed))
        rejected_restart('StationManifestChanged')
        manifest.write_bytes(accepted_manifest)
        s.server.config.pop('station')
        s.server.path.write_text(json.dumps(s.server.config))
        rejected_restart('MissingStationManifest')
        s.server.config['station'] = dict(file=str(manifest))
        s.server.path.write_text(json.dumps(s.server.config))
        s.restart_authority()
        # No due work is needed to detect a revoked read grant.
        s.command({'grant_resource': dict(resource=resources[requester], subject=5, permissions=0)})
        assert s.server.process.wait(timeout=45) != 0
        assert not (s.server.installation / 'server-ready').exists()
        rejected_restart('AccessDenied')
        print("Station services: durable registry/rebind routing, observed timeout/late-result closure, scoped bounded supervision and recovery passed.")

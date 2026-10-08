"""Station state survives worker loss, while opted-in recovery bounds stay final."""
import json
import os
from pathlib import Path
import time

from inspection import System
from station import frame
from station_ledger import audit_total
from storage import wait_ready


def run(node, cli, worker, courier):
    with System(node, cli, clock_error_ms=10000, request_timeout_ms=5000) as s:
        deadline = int(time.time() * 1000) + 120000
        pid = s.command({"create": {"required": [b"data".hex(), None, None, None]}})
        resource = s.command({"create_resource": {"writer": pid, "deadline_ms": deadline, "history_ms": 0}})
        seed, public = s.key("worker")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 88, "pid": pid}})
        for principal in (0, 1):
            s.command({"grant_resource": {"resource": resource, "subject": principal, "permissions": 7}})
        s.command({"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}})
        s.command({"initialize": {"pid": pid, "expected_generation": 1}})
        s.command({"own": {"pid": pid, "worker": 1, "expected_generation": 2}})
        config = s.root / "station.json"
        courier_seed, courier_public = s.key('courier')
        s.command({'grant': {'subject': 3, 'public_key': courier_public, 'permissions': 132}})
        courier_config = s.root / 'courier.json'
        courier_config.write_text(json.dumps(dict(url=s.url, realm=72, principal=3, seed_file=str(courier_seed), interval_ms=10)))
        s.start(courier, courier_config)

        def once(generation, error=None):
            config.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 1,
                "pid": pid, "generation": generation, "seed_file": str(seed)}))
            # Zig's build runner can force color even in redirected child logs.
            # This fixture compares an exact error, so use unstyled diagnostics.
            child = s.start(worker, "--once", config, env=dict(os.environ, NO_COLOR="1"))
            status = child.wait(timeout=20)
            output = Path(s.logs[-1].name).read_text()
            if error: assert status != 0 and f"error: {error}" in output, (status, output)
            else: assert status == 0, (status, output)

        def query(kind, **values):
            # Reclamation can publish between acquiring and validating a
            # current read. Restart only that read; retain no mixed-cut values.
            until = time.monotonic() + 5
            while True:
                status, response = s.native_query({'resource': resource}, status=None)
                if status == 200:
                    metadata = response['body']['resource']
                    break
                assert status == 409 and response == {'err': 'Conflict'} and time.monotonic() < until, (status, response)
                time.sleep(.025)
            if kind == 'resources': return {'resources': [metadata]}
            return s.native_query({'entries': {'resource': resource, 'revision': metadata['revision'], **values}})['body']['entries']['page']

        def rejection(command, name):
            body = s.post("/v1/command", s.signed(command, s.sequence + 1), 422)
            assert body["err"] == name, body

        s.command({"send": {"pid": pid, "value": frame(b"init")}})
        once(3)
        s.command({'send': {'pid': pid, 'value': frame(b'prepare-table')}})
        s.command({"send": {"pid": pid, "value": frame(b"7")}})
        def applied(generation, expected):
            until = time.monotonic() + 45
            while audit_total(s.native_query, resource) != expected:
                assert time.monotonic() < until
                if s.native_query({'process': pid})['body']['process']['input'] is not None:
                    once(generation)
                else: time.sleep(.025)
        applied(3, 7)
        captured = query("entries")
        s.authority.kill(); s.authority.wait(timeout=10)
        s.store.stop(); s.store.start()
        s.authority = s.start(node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        assert query("entries") == captured
        rejection({"suspend": {"pid": pid, "expected_generation": 3,
            "resume_before_ms": deadline + 1}}, "StateResourceExpired")
        s.command({"suspend": {"pid": pid, "expected_generation": 3,
            "resume_before_ms": int(time.time() * 1000) + 30000}})
        s.command({"send": {"pid": pid, "value": frame(b"5")}})
        s.command({"resume": {"pid": pid, "expected_generation": 4}})
        s.command({"own": {"pid": pid, "worker": 1, "expected_generation": 5}})
        applied(6, 12)
        # Admission must also fit the full configured uncertainty bound, not
        # just the smaller error reported by a particular developer machine.
        bound = int(time.time() * 1000) + 15000
        s.command({"suspend": {"pid": pid, "expected_generation": 6, "resume_before_ms": bound}})
        # The profile admits up to 10s of trusted-clock uncertainty. Wait beyond
        # that full bound; local wall time alone is not proof of known expiry.
        while int(time.time() * 1000) <= bound + 10050: time.sleep(.05)
        # PID-owned required state shares the expired suspension horizon; that
        # dependency is checked before the resume transition's own deadline.
        rejection({"resume": {"pid": pid, "expected_generation": 7}}, "DeadlineExpired")
        maintenance_config = s.root / "maintenance.json"
        maintenance_config.write_text(json.dumps({**json.loads(s.config.read_text()), "maintenance": {
            "principal": 0, "seed_file": str(s.seed), "interval_ms": 25}}))
        maintenance = s.start(node, maintenance_config, "--maintain")
        until = time.monotonic() + 15
        while query("resources")["resources"][0]["phase"] != "reclaimed":
            assert time.monotonic() < until and maintenance.poll() is None
            time.sleep(.1)
        maintenance.terminate(); maintenance.wait(timeout=10)
        assert s.inspect("process", pid)["processes"][0]["lifecycle"] == "expired"
        once(6, "ProcessExpired")
        s.authority.kill(); s.authority.wait(timeout=10)
        s.authority = s.start(node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        assert query("resources")["resources"][0]["phase"] == "reclaimed"
        once(6, "ProcessExpired")
    print("Station lifetime: associated Tables survive recovery, suspension fits dependencies, expiry is permanent and owned state is reclaimed")

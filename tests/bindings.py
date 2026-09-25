"""Real-authority qualification shared by every foreign Station caller."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time

from inspection import System
from station import frame

ROOT = Path(__file__).resolve().parents[1]


def pair(node, cli, courier, library, raw_library, host, service_command, requester_command, label):
    with System(node, cli, clock_error_ms=10000) as s:
        records = []
        for principal in (1, 2):
            pid = s.command({"lifecycle": {"create": {"required": [b"data".hex(), None, None, None]}}})
            resource = s.command({"state": {"create": {"writer": pid}}})
            seed, public = s.key(f"foreign-{principal}")
            s.command({"grant": {"subject": principal, "public_key": public, "permissions": 88, "pid": pid}})
            for subject in (0, principal):
                s.command({"state": {"grant": {"resource": resource, "subject": subject, "permissions": 7}}})
            s.command({"state": {"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}}})
            s.command({"send": {"pid": pid, "value": frame(b"init")}})
            s.command({"lifecycle": {"initialize": {"pid": pid, "expected_generation": 1}}})
            s.command({"own": {"pid": pid, "worker": principal, "expected_generation": 2}})
            config = s.root / f"host-{principal}.json"
            config.write_text(json.dumps({"url": s.url, "seed_file": str(seed), "server": {
                "realm": 72, "principal": principal, "pid": pid, "generation": 3}}))
            records.append((pid, resource, config))
        seed, public = s.key("courier")
        s.command({"grant": {"subject": 3, "public_key": public, "permissions": 132}})
        delivery = s.root / "delivery.json"
        delivery.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 3,
            "seed_file": str(seed), "interval_ms": 10}))
        s.start(courier, delivery)
        libraries = s.root / "libraries"
        libraries.mkdir()
        for name, source in (("station", library), ("client", raw_library)):
            (libraries / f"libtransit_{name}.so").symlink_to(Path(source).resolve())
        env = os.environ | {"TRANSIT_LIBRARY_DIR": str(libraries),
            "TRANSIT_HOST": str(Path(host).resolve()),
            "PYTHONPATH": str(ROOT / "packages/python/transit-station"),
            "ERL_FLAGS": "+S 2:2 +SDcpu 1 +SDio 1"}
        def once(index):
            pid, _, config = records[index]
            for _ in range(300):
                if s.post("/v2/view", s.signed({"inspect": pid}))["input"] is not None:
                    break
                time.sleep(.025)
            else:
                raise AssertionError((label, "undelivered", pid))
            command = service_command if index == 0 else requester_command
            child = s.start(*command, config, "service" if index == 0 else "requester", records[1-index][0], env=env)
            assert child.wait(timeout=30) == 0, (label, command)
        def observed():
            query = s.root / "entries.json"
            query.write_text(json.dumps({"realm": 72, "principal": 0, "kind": "entries",
                "resource": records[1][1], "key": b"observed".hex()}))
            entry = s.post("/v2/state", s.invoke("sign-state", s.seed, query))["entries"][0]
            return bytes.fromhex(entry["value"]) if entry else None
        once(0)
        once(1)
        s.command({"send": {"pid": records[1][0], "value": frame(b"call")}})
        once(1)
        once(0)  # durable capture
        once(0)  # captured publication, in a new foreign/native host
        for _ in range(4):
            if observed() is not None:
                break
            once(1)
        assert observed() == b"9007199254740993", label
        once(0)  # acknowledgement, without deleting the result
        print(f"Bindings {label}: handler, associated Table, correlation, host restart and exact Arrow int64 passed")


def run(node, cli, courier, library, raw_library, host):
    from station_abi import run as abi_proof
    abi_proof(node, cli, library, raw_library, host)
    python = [sys.executable, str(ROOT / "examples/station-bindings/python/main.py")]
    pair(node, cli, courier, library, raw_library, host, python, python, "Python")


if __name__ == "__main__":
    run(*sys.argv[1:])

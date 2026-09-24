"""Public state contract against a real disk-backed authority; no storage access."""
import hashlib
import json
from pathlib import Path
import sys
import time
from inspection import System
from storage import wait_ready


def run(node, cli, counter):
    with System(node, cli, clock_error_ms=10000) as s:
        def query(kind, principal=0, seed=None, status=200, **options):
            path = s.root / "state-query.json"
            path.write_text(json.dumps({"realm": 72, "principal": principal, "kind": kind, **options}))
            signed = s.invoke("sign-state", seed or s.seed, path)
            return s.post("/v2/state", signed, status)

        fixture = json.loads((Path(__file__).resolve().parents[1] / "packages/zig/transit-protocol/src/fixtures/state-v1.json").read_text())
        assert hashlib.sha256(b"rey.transit.state.v1\0" + fixture["canonical"].encode()).hexdigest() == fixture["sha256"]
        assert query("capabilities")["capabilities"]["keys_per_resource"] == 32
        pid = s.command({"spawn": {"initial_state": b"legacy".hex()}})
        resource = s.command({"state": {"create": {"writer": pid, "history_ms": 0}}})
        seed, public = s.key("observer")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16, "pid": pid}})
        s.command({"state": {"grant": {"resource": resource, "subject": 0, "permissions": 7}}})
        association = s.command({"state": {"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}}})
        assert all(v is None for v in query("resources", principal=1, seed=seed)["resources"])
        assert all(v is None for v in query("associations", pid=pid, principal=1, seed=seed)["associations"])
        query("entries", resource=resource, principal=1, seed=seed, status=403)
        s.command({"state": {"grant": {"resource": resource, "subject": 1, "permissions": 1}}})
        assert query("associations", pid=pid, principal=1, seed=seed)["associations"][0]["revision"] == association
        query("entries", resource=resource, principal=1, seed=seed, status=403)
        s.command({"own": {"pid": pid, "worker": 0, "expected_generation": 1}})
        for index in range(10):
            message = s.command({"send": {"pid": pid, "value": b"work".hex()}})
            process = s.inspect("process", pid)["processes"][0]
            revision = query("resources", resource=resource)["resources"][0]["revision"]
            view = s.command({"state": {"open": {"pid": pid, "generation": 2, "input": message,
                "expected_revision": process["revision"], "resource": resource, "revision": revision,
                "deadline_ms": int(time.time() * 1000) + 30000}}})
            page = query("view", pid=pid, view=view)
            assert page["view"]["revision"] == revision
            command = {"state": {"turn": {"turn": {"pid": pid, "generation": 2, "input": message,
                "expected_revision": process["revision"], "result": b"legacy".hex()},
                "views": [view, None, None, None], "write_view": view,
                "mutations": [{"key": str(index).encode().hex(), "value": b"opaque".hex()}, None, None, None]}}}
            position = s.command(command)
            # A lost receipt is reconciled by the exact signed operation.
            assert s.post("/v2/command", s.signed(command, s.sequence))["position"] == position
            query("view", pid=pid, view=view, status=422)
        first = query("entries", resource=resource)
        second = query("entries", resource=resource, cut=first["cut"], after=first["next"])
        assert len([v for v in first["entries"] + second["entries"] if v]) == 10
        assert second["next"] is None
        s.command({"state": {"grant": {"resource": resource, "subject": 1, "permissions": 3}}})
        read = query("entries", resource=resource, principal=1, seed=seed)
        s.command({"state": {"grant": {"resource": resource, "subject": 1, "permissions": 0}}})
        query("entries", resource=resource, principal=1, seed=seed, cut=read["cut"], status=403)
        query("entries", resource=resource, cut=first["cut"], after=first["next"], status=409)
        before = query("entries", resource=resource)
        s.authority.kill()
        s.authority.wait(timeout=10)
        s.store.stop()
        s.store.start()
        s.authority = s.start(s.node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        assert query("entries", resource=resource) == before
        assert s.inspect("process", pid)["processes"][0]["state"] == b"legacy".hex()
        # The actual Zig caller uses only Session and opaque application bytes.
        worker, public = s.key("caller")
        config = s.root / "counter.json"
        for generation, value in ((3, 7), (4, 5)):
            s.command({"grant": {"subject": 2, "public_key": public, "permissions": 24, "pid": pid}})
            s.command({"state": {"grant": {"resource": resource, "subject": 2, "permissions": 7}}})
            s.command({"own": {"pid": pid, "worker": 2, "expected_generation": generation - 1}})
            s.command({"send": {"pid": pid, "value": str(value).encode().hex()}})
            config.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 2, "pid": pid,
                "generation": generation, "seed_file": str(worker), "state_association": "data"}))
            child = s.start(counter, "--once", config)
            assert child.wait(timeout=15) == 0
        assert query("entries", resource=resource, key=b"value".hex())["entries"][0]["value"] == b"12".hex()
        assert s.inspect("process", pid)["processes"][0]["state"] == b"legacy".hex()
        metadata = query("resources", resource=resource)["resources"][0]
        assert metadata["last_turn"] == metadata["revision"] == s.inspect("process", pid)["processes"][0]["revision"]
    print("State API: signed reads, independent grants, frozen views, atomic turns, exact retries, pagination and disk recovery passed.")


if __name__ == "__main__":
    run(*[Path(p).resolve() for p in sys.argv[1:]])

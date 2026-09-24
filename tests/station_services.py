"""Qualify framework services and their separately credentialed controllers."""
import json
import struct
import time

from inspection import System
from station import frame


def run(node, cli, worker, courier, controller):
    with System(node, cli, clock_error_ms=10000) as s:
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
            pid = s.command({"lifecycle": {"create": {"required": [b"data".hex(), None, None, None]}}})
            resource = s.command({"state": {"create": {"writer": pid}}})
            seed, public = s.key(role)
            s.command({"grant": {"subject": principal, "public_key": public, "permissions": 88, "pid": pid}})
            for subject in (0, principal):
                s.command({"state": {"grant": {"resource": resource, "subject": subject, "permissions": 7}}})
            s.command({"state": {"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}}})
            command(pid, b"init")
            s.command({"lifecycle": {"initialize": {"pid": pid, "expected_generation": 1}}})
            s.command({"own": {"pid": pid, "worker": principal, "expected_generation": 2}})
            configs[pid] = {"url": s.url, "realm": 72, "principal": principal, "pid": pid,
                            "generation": 3, "seed_file": str(seed), "role": role,
                            "destination": destination, "observer": 5}
            resources[pid] = resource
            worker_once(pid)
            return pid

        ledger = create(1, "ledger")
        requester = create(2, "requester", ledger)
        coordinator = create(4, "coordinator", ledger)
        configs[requester]["registry"] = coordinator
        courier_seed, public = s.key("courier")
        s.command({"grant": {"subject": 3, "public_key": public, "permissions": 132}})
        courier_config = s.root / "courier.json"
        courier_config.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 3,
                                              "seed_file": str(courier_seed), "interval_ms": 10}))
        courier_process = s.start(courier, courier_config)
        observer_seed, public = s.key("observer")
        s.command({"grant": {"subject": 5, "public_key": public, "permissions": 20}})
        admin_seed, public = s.key("scoped-admin")
        s.command({"grant": {"subject": 6, "public_key": public, "permissions": 17, "pid": ledger}})
        for resource, subject in ((resources[requester], 5), (resources[coordinator], 5), (resources[coordinator], 6)):
            s.command({"state": {"grant": {"resource": resource, "subject": subject, "permissions": 3}}})

        def control(mode, watches):
            nonlocal serial
            serial += 1
            path = s.root / f"controller-{serial}.json"
            path.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 5 if mode == "observe" else 6,
                "seed_file": str(observer_seed if mode == "observe" else admin_seed), "mode": mode, "watches": watches}))
            process = s.start(controller, path, "--once")
            assert process.wait(timeout=20) == 0

        def await_input(pid):
            for _ in range(200):
                if s.post("/v2/view", s.signed({"inspect": pid}))["input"] is not None:
                    return
                time.sleep(.025)
            raise AssertionError(("missing input", pid))

        def value(pid, key):
            path = s.root / "query.json"
            path.write_text(json.dumps({"realm": 72, "principal": 0, "kind": "entries",
                                       "resource": resources[pid], "key": key.hex()}))
            entry = s.post("/v2/state", s.invoke("sign-state", s.seed, path))["entries"][0]
            return bytes.fromhex(entry["value"]) if entry else None

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
        worker_once(ledger)  # delivery used the recorded old PID

        # Deadline observations are explicit mailbox input. The worker can be
        # replaced while a call waits without losing its timeout or correlation.
        deadline = int(time.time() * 1000) - 1
        timed_input = command(requester, f"wait:{deadline}:7".encode())
        worker_once(requester)
        s.command({"own": {"pid": requester, "worker": 2, "expected_generation": 3}})
        configs[requester]["generation"] = 4
        control("observe", [{"pid": requester, "resource": resources[requester]}])
        await_input(requester)
        worker_once(requester)
        assert value(requester, b"answer") == b"timeout"
        waiting = value(requester, b"\x00w" + timed_input.to_bytes(8, "little"))
        assert waiting[1] == 3
        await_input(ledger)
        worker_once(ledger)  # accepted request may still finish after cancellation
        await_input(ledger)
        worker_once(ledger)  # cancellation is an ordered advisory message
        await_input(requester)
        worker_once(requester)  # late result is recorded, never reopens the wait
        assert value(requester, b"answer") == b"timeout"

        # A supervisor records intent; only the separately scoped admin applies it.
        bad_input = command(ledger, b"invalid")
        worker_once(ledger, success=False)
        watch = [{"pid": coordinator, "resource": resources[coordinator], "child": ledger}]
        control("observe", watch)
        await_input(coordinator)
        worker_once(coordinator)
        child_key = b"\x00c" + ledger.to_bytes(8, "little") + b"\x00"
        child = value(coordinator, child_key)
        assert child[14] == 1 and child[15] == 3  # one durable retry request
        s.command({"own": {"pid": coordinator, "worker": 4, "expected_generation": 3}})
        configs[coordinator]["generation"] = 4
        control("lifecycle", watch)
        process = s.inspect("process", ledger)["processes"][0]
        assert process["failure"] is None
        assert s.post("/v2/view", s.signed({"inspect": ledger}))["input"]["position"] == bad_input
        # A fresh controller sees accepted retry progress and makes no second retry.
        control("lifecycle", watch)
        control("observe", watch)
        await_input(coordinator)
        worker_once(coordinator)
        generation = process["generation"]
        s.command({"own": {"pid": ledger, "worker": 1, "expected_generation": generation}})
        configs[ledger]["generation"] = generation + 1
        worker_once(ledger, success=False)
        control("observe", watch)
        await_input(coordinator)
        worker_once(coordinator)
        assert value(coordinator, child_key)[15] == 4  # exhausted; head retained
        s.command({"terminate": ledger})
        control("observe", watch)
        await_input(coordinator)
        worker_once(coordinator)
        assert value(coordinator, child_key)[15] == 5
        control("lifecycle", watch)  # retirement never becomes retry/spawn
        assert s.inspect("process", ledger)["processes"][0]["lifecycle"] == "terminated"
        courier_process.terminate()
        courier_process.wait(timeout=10)
        print("Station services: durable registry/rebind routing, observed timeout/late-result closure, scoped bounded supervision and recovery passed.")

"""Shared Station Tables recover current rows from a checkpoint and its tail."""
import json
import os
from pathlib import Path
import time

from inspection import System
from station import frame
from storage import wait_ready


def run(node, cli, libraries):
    from transit_station import GenServer
    from station_abi import ready
    with System(node, cli, clock_error_ms=10000) as s:
        pid = s.command({"lifecycle": {"create": {"allow_trim": True, "required": [b"data".hex(), None, None, None]}}})
        resource = s.command({"state": {"create": {"writer": pid, "history_ms": 0}}})
        seed, public = s.key("materializer")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 88, "pid": pid}})
        for subject in (0, 1):
            s.command({"state": {"grant": {"resource": resource, "subject": subject, "permissions": 7}}})
        s.command({"state": {"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}}})
        s.command({"lifecycle": {"initialize": {"pid": pid, "expected_generation": 1}}})
        s.command({"own": {"pid": pid, "worker": 1, "expected_generation": 2}})
        config = {"realm": 72, "principal": 1, "pid": pid, "generation": 3}

        def turn(actions):
            command = {"send": {"pid": pid, "value": frame(b"change")}}
            position = s.command(command)
            assert s.post("/v2/command", s.signed(command, s.sequence))["position"] == position
            # Every turn uses a fresh host and reconstructs the Table snapshot.
            with GenServer(libraries, s.url, seed, config) as server:
                assert ready(server)["input"]["position"] == position
                results = [server.apply(action) for action in actions]
                server.finish()
                frozen = server.pending()
                for _ in range(10):
                    if server.next()["event"] == "committed": break
                else: raise AssertionError("Table turn did not commit")
            from transit_station import Client
            with Client(libraries, s.url) as client:
                # Retry after all Station handles are gone, never repeat effects.
                assert client.call(frozen) == client.call(frozen)
            return results

        def write(key, value, mode="upsert"):
            return {"table_write": {"id": 1, "mode": mode, "row": {"key": str(key), "value": {"int64": str(value)}}}}

        turn([{"table_create": {"id": 1, "key_name": "id", "value_name": "amount", "value_type": "int64"}}, write(1, 7), write(2, 5)])
        turn([write(1, 9, "update"), {"table_delete": {"id": 1, "key": "2"}}])
        maintenance_seed, maintenance_key = s.key("maintenance")
        s.command({"grant": {"subject": 2, "public_key": maintenance_key, "permissions": 1}})
        maintenance_config = s.root / "maintenance.json"
        maintenance_config.write_text(json.dumps({**json.loads(s.config.read_text()), "maintenance": {
            "principal": 2, "seed_file": str(maintenance_seed), "interval_ms": 25, "checkpoint_every_records": 4}}))
        maintenance = s.start(node, maintenance_config, "--maintain", env=os.environ | {"LOG_LEVEL": "info", "LOG_FORMAT": "json"})
        until = time.monotonic() + 15
        while s.inspect("history", pid)["history"] != "prefix_reclaimed":
            assert maintenance.poll() is None and time.monotonic() < until
            time.sleep(.1)
        # Let the checkpoint's physical publication/trim finish. The log records
        # that storage operation, not just the logical retained boundary.
        until = time.monotonic() + 15
        while '"operation":"trimmed"' not in Path(s.logs[-1].name).read_text():
            assert maintenance.poll() is None and time.monotonic() < until
            time.sleep(.05)
        maintenance.terminate(); maintenance.wait(timeout=10)
        # This update/reinsertion is in the tail after the published checkpoint.
        turn([write(1, 4, "update"), write(2, 3, "insert")])
        s.authority.kill(); s.authority.wait(timeout=10)
        s.store.stop(); s.store.start()
        s.authority = s.start(node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        rows = turn([{"table_get": {"id": 1, "key": str(key)}} for key in (1, 2)])
        assert rows == [{"row": {"key": "1", "value": {"int64": "4"}}}, {"row": {"key": "2", "value": {"int64": "3"}}}], rows
        result = turn([{"query": {"id": 1, "plan": {"aggregate": "sum", "projection": "value"}}}])[0]
        import pyarrow as pa
        table = pa.ipc.open_stream(bytes.fromhex(result["arrow"])).read_all()
        assert table.column(0).to_pylist() == [7], table
    print("Station materialization: duplicate admission/commit, update/delete/reinsert, checkpoint/tail recovery and current-row Arrow aggregate passed")

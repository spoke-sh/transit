"""A Python handler; all behavior, state, signing and query code lives in Zig."""
import asyncio
import json
import os
import sys

from transit_station import GenServer


async def main():
    config_path, role, peer = sys.argv[1:]
    config = json.load(open(config_path))
    async with GenServer(os.environ["TRANSIT_LIBRARY_DIR"], config["url"], config["seed_file"], config["server"]) as server:
        async def apply(action):
            return await server.apply_async(action)
        while True:
            event = await server.next_async()
            if event["event"] == "committed":
                return
            if event["event"] in ("idle", "blocked"):
                raise RuntimeError(event["event"])
            if event["event"] != "ready":
                continue
            try:
                if event["initializing"]:
                    await apply({"table_create": {"id": 1, "key_name": "id", "value_name": "value", "value_type": "int64"}})
                    if role == "service":
                        await apply({"query_policy": {"peer": int(peer), "table": 1, "expected_revision": 0, "allow": True}})
                        await apply({"table_write": {"id": 1, "mode": "insert", "row": {"key": "1", "value": {"int64": "9007199254740993"}}}})
                message = event["input"]
                if bytes.fromhex(message["payload"]) == b"init":
                    pass
                elif message["kind"] == "cast":
                    await apply({"call": {"pid": int(peer), "value": b"query".hex()}})
                elif message["kind"] == "call":
                    await apply({"query_reply": {"id": 1}})
                elif message["kind"] == "result_complete":
                    ipc = bytes.fromhex((await apply({"query_result": message["correlation"]}))["arrow"])
                    cell = server.arrow_cell(ipc, 0, 1)
                    assert cell["value"] == {"int64": "9007199254740993"}
                    # Expose the original IPC to ordinary Python Arrow consumers.
                    import pyarrow as pa
                    with pa.ipc.open_stream(ipc) as reader:
                        assert reader.read_all().to_pylist() == [{"id": 1, "value": 9007199254740993}]
                    await apply({"put": {"key": b"observed".hex(), "value": b"9007199254740993".hex()}})
                else:
                    raise RuntimeError("Unexpected message")
                server.finish()
            except Exception:
                server.finish(failed=True)
                # Explicit example policy: record handler failure before exiting.
                # Cancellation/host death instead leaves the head unacknowledged.
                assert (await server.next_async())["event"] == "blocked"
                raise


if __name__ == "__main__":
    asyncio.run(main())

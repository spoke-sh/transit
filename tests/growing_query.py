"""Incremental query staging/sealing through real callers and disk recovery."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import threading
import time

import pyarrow as pa

from storage import Fixture, free_port, wait_ready


def run(node, caller, *, finish_pages=64):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "growing_v3", "genesis": {
            "realm": 44, "root_key": public, "max_clock_error_ms": 10000},
            "ursula_url": fixture.url, "bucket": "growing-query", "journal": "authority",
            "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        manifest = fixture.root / "query.json"
        fault = {"stage": None, "seal": None, "publish": None, "receive": None,
                 "retries": set(), "queries": 0}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v3/query" and response.status == 200:
                        kind = envelope["query"]["kind"]
                        if "version_entries" in kind:
                            entries = kind["version_entries"]
                            if entries.get("key") is None:
                                assert entries.get("after", "").startswith(b"\x00r\x01\x00\x00\x00".hex())
                                page = json.loads(data)["body"]["version_entries"]["page"]
                                assert sum(item is not None for item in page["entries"]) <= 8
                                fault["queries"] += 1
                    if self.path == "/v3/command" and response.status == 200:
                        command = envelope["request"]["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        keys = [bytes.fromhex(item["key"]) for item in turn.get("mutations", []) if item]
                        publishing = any(item and item["value"] and
                                         bytes.fromhex(item["key"]).startswith(b"\x00Qj") and
                                         len(bytes.fromhex(item["value"])) == 108 and
                                         int.from_bytes(bytes.fromhex(item["value"])[106:108], "little") > 0
                                         for item in turn.get("mutations", []))
                        for name, selected in (("stage", any(key.startswith(b"\x00Qs") for key in keys)),
                                               ("seal", any(key.startswith(b"\x00Qm") for key in keys)),
                                               ("publish", publishing),
                                               ("receive", any(key.startswith(b"\x00Qd") for key in keys))):
                            if fault[name] is not None and body == fault[name][0]:
                                assert data == fault[name][1], "Lost result reply changed on exact retry"
                                fault["retries"].add(name)
                            elif fault[name] is None and selected:
                                fault[name] = (body, data)
                                data = b'{"position":0}'
                                break
                    self.send_response(response.status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        proxy_url = f"http://127.0.0.1:{proxy.server_port}"
        log = (fixture.root / "node.log").open("w+")
        authority = None
        timings = {}
        try:
            subprocess.run([node, str(config), "--initialize"], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=20)

            def start():
                child = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                try:
                    wait_ready(fixture.http, child, url + "/health")
                except BaseException:
                    child.kill()
                    child.wait(timeout=10)
                    raise
                return child

            authority = start()
            captured_queries = None
            for phase in ("write", "seal", "recover", "publish", "deliver"):
                started = time.monotonic()
                subprocess.run([caller, proxy_url, phase, str(manifest)], check=True, timeout=180)
                timings[phase] = round(time.monotonic() - started, 3)
                if phase == "recover":
                    captured_queries = fault["queries"]
                if phase in ("write", "seal", "publish"):
                    authority.kill()
                    authority.wait(timeout=10)
                    authority = None
                    fixture.stop()
                    fixture.start()
                    recovered = json.loads(config.read_text())
                    recovered["resident_pages"] = 1 if phase == "write" else finish_pages if phase == "seal" else 64
                    config.write_text(json.dumps(recovered))
                    authority = start()
            assert fault["retries"] == {"stage", "seal", "publish", "receive"}
            assert captured_queries == fault["queries"], "Publication must never reopen source rows"
            result = json.loads(Path(f"{manifest}.result.json").read_text())
            job, progress = result["job"], result["progress"]
            assert job["phase"] == "captured" and progress["finished"] == "source_end"
            actual, chain, total = [], bytes(32), 0
            for ordinal, segment in enumerate(result["segments"]):
                data = Path(f"{manifest}.{ordinal}.arrow").read_bytes()
                assert segment["result"] == job["result"] and segment["ordinal"] == ordinal
                assert segment["bytes"] == len(data) and bytes(segment["digest"]) == hashlib.sha256(data).digest()
                encoded = (b"GQS2" + struct.pack("<QQHB", job["result"], ordinal, len(data), segment["rows"])
                           + bytes(segment["digest"]))
                chain = hashlib.sha256(b"transit.station.query.segments.v2\x00" + chain + encoded).digest()
                with pa.ipc.open_stream(data) as reader:
                    batches = list(reader)
                    assert reader.schema == pa.schema([pa.field("id", pa.int64(), nullable=False), pa.field("value", pa.string())])
                assert len(batches) == 1 and batches[0].num_rows == segment["rows"]
                actual.extend(batches[0].to_pylist())
                total += len(data)
            assert actual == [{"id": i, "value": None if i % 5 == 0 else chr(ord("a") + i % 26) * 220} for i in range(41)]
            assert progress["rows"] == 41 and progress["segments"] == 6
            assert total == job["bytes"] > 672 and chain == bytes(job["chain"])
            received = json.loads(Path(f"{manifest}.received.json").read_text())
            completed = received["manifest"]
            assert completed["basis"] == progress["basis"] and completed["plan"] == progress["plan"]
            assert completed["rows"] == 41 and completed["bytes"] == total
            assert completed["chain"] == job["chain"] and received["segments"] == result["segments"]
            schema_hash = hashlib.sha256(b"transit.fuze.ipc.schema.v1\x00\x02\x02id\x01\x00\x05value\x03\x01").digest()
            assert bytes(completed["schema"]) == schema_hash
            for ordinal in range(completed["segments"]):
                captured_data = Path(f"{manifest}.{ordinal}.arrow").read_bytes()
                received_data = Path(f"{manifest}.received.{ordinal}.arrow").read_bytes()
                assert received_data == captured_data
                with pa.ipc.open_stream(received_data) as reader:
                    assert reader.read_all().num_rows == received["segments"][ordinal]["rows"]
            print("Growing query timing:", json.dumps({"initial_pages": 64, "seal_pages": 1, "finish_pages": finish_pages, **timings}), flush=True)
            print(f"Growing query: {len(actual)} rows/{total} bytes; staging, sealing, publication and partial consumption recover with exact retries, bounded Arrow validation, cancellation and retained acknowledgement.", flush=True)
        except BaseException:
            log.flush()
            log.seek(0)
            sys.stderr.write(log.read()[-12000:])
            raise
        finally:
            if authority is not None:
                if authority.poll() is None:
                    authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            log.close()


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("node")
    parser.add_argument("caller")
    parser.add_argument("--finish-pages", type=int, default=64)
    args = parser.parse_args()
    if not 0 <= args.finish_pages <= 1024:
        parser.error("--finish-pages must be between 0 and 1024")
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    run(args.node, args.caller, finish_pages=args.finish_pages)

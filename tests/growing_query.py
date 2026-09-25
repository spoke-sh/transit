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


def run(node, caller):
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
        fault = {"stage": None, "seal": None, "retries": set(), "queries": 0}

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
                        for name, tag in (("stage", b"s"), ("seal", b"m")):
                            if fault[name] is not None and body == fault[name][0]:
                                assert data == fault[name][1], "Lost result reply changed on exact retry"
                                fault["retries"].add(name)
                            elif fault[name] is None and any(key.startswith(b"\x00Q" + tag) for key in keys):
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
            for phase in ("write", "seal", "recover"):
                started = time.monotonic()
                subprocess.run([caller, proxy_url, phase, str(manifest)], check=True, timeout=180)
                timings[phase] = round(time.monotonic() - started, 3)
                if phase != "recover":
                    authority.kill()
                    authority.wait(timeout=10)
                    authority = None
                    fixture.stop()
                    fixture.start()
                    recovered = json.loads(config.read_text())
                    recovered["resident_pages"] = 1
                    config.write_text(json.dumps(recovered))
                    authority = start()
            assert fault["retries"] == {"stage", "seal"}
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
            print("Growing query timing:", json.dumps(timings), flush=True)
            print(f"Growing query: {len(actual)} rows/{total} captured bytes, partial staging and sealed progress survive two caller/node/provider replacements; lost stage/seal replies and independent Arrow verification passed.", flush=True)
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
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    run(*sys.argv[1:])

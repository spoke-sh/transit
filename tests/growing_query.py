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

from harness.ursula import Fixture
from harness.services import free_port, wait_ready


def run(node, caller, *, finish_pages=64):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "native_v1", "genesis": {
            "realm": 44, "root_key": public, "max_clock_error_ms": 10000},
            "ursula_url": fixture.url, "bucket": "query", "journal": "authority",
            "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        manifest = fixture.root / "query.json"
        fault = {"stage": None, "seal": None, "publish": None, "receive": None,
                 "retries": set(), "queries": 0}
        attempts = {"query": 0, "command": 0, "read_entries": 0}
        attempt_lock = threading.Lock()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                with attempt_lock:
                    if self.path == "/v1/query":
                        attempts["query"] += 1
                        attempts["read_entries"] += int("read_entries" in envelope["query"]["kind"])
                    elif self.path == "/v1/command":
                        attempts["command"] += 1
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v1/query" and response.status == 200:
                        kind = envelope["query"]["kind"]
                        if "version_entries" in kind:
                            entries = kind["version_entries"]
                            page = json.loads(data)["body"]["version_entries"]["page"]
                            assert sum(item is not None for item in page["entries"]) <= 8
                            fault["queries"] += 1
                    if self.path == "/v1/command" and response.status == 200:
                        command = envelope["request"]["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        keys = [bytes.fromhex(item["key"]) for item in turn.get("mutations", []) if item]
                        publishing = any(item and item["value"] and
                                         bytes.fromhex(item["key"]).startswith(b"\x00Qj") and
                                         len(bytes.fromhex(item["value"])) == 152 and
                                         int.from_bytes(bytes.fromhex(item["value"])[129:131], "little") > 0
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
            print("Growing query fixture:", fixture.root, flush=True)
            for phase in ("write", "seal", "recover", "publish", "deliver"):
                started = time.monotonic()
                # Complete delivery includes hundreds of durable paged turns.
                # Use the disk proof's finite phase allowance for that work;
                # memory-backed timing does not qualify its WAL cost.
                budget = 600 if phase == "deliver" else 180
                with attempt_lock:
                    before = attempts.copy()
                complete = False
                try:
                    subprocess.run([caller, proxy_url, phase, str(manifest)], check=True, timeout=budget)
                    complete = True
                finally:
                    timings[phase] = round(time.monotonic() - started, 3)
                    with attempt_lock:
                        counts = {key: value - before[key] for key, value in attempts.items()}
                    print("Growing query phase:", json.dumps({"phase": phase, "complete": complete,
                          "seconds": timings[phase], "native_attempts": counts}), flush=True)
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
            source = job['source']
            expected_job = (b'GQJ1' + struct.pack('<QQQQQQBQQHQBBQ',
                job['result'], job['destination'], job['correlation'], job['table'],
                source['pid'], source['input'], source['index'], job['resource'], job['revision'],
                job['plan_bytes'], job['policy_revision'], 2, 0, job['bytes'])
                + bytes(job['chain']) + struct.pack('<QHB', job['send_segment'], job['send_offset'], 0) + bytes(20))
            assert len(expected_job) == 152 and bytes.fromhex(result['job_wire']) == expected_job
            counters = progress['counters']
            expected_progress = (b'FQS1' + bytes(progress['binding']) + bytes(progress['plan'])
                + struct.pack('<QQQQQQBqB', progress['pages'], counters['scanned'], counters['selected'],
                    counters['value_count'], progress['segments'], progress['rows'], 0, 0, 1))
            assert counters['sum'] is None and len(expected_progress) == 126
            assert bytes.fromhex(result['progress_wire']) == expected_progress
            actual, chain, total = [], bytes(32), 0
            for ordinal, segment in enumerate(result["segments"]):
                data = Path(f"{manifest}.{ordinal}.arrow").read_bytes()
                assert segment["result"] == job["result"] and segment["ordinal"] == ordinal
                assert segment["bytes"] == len(data) and bytes(segment["digest"]) == hashlib.sha256(data).digest()
                encoded = (b"GQS1" + struct.pack("<QQHB", job["result"], ordinal, len(data), segment["rows"])
                           + bytes(segment["digest"]))
                chain = hashlib.sha256(b"transit.station.query.segments.v1\x00" + chain + encoded).digest()
                with pa.ipc.open_stream(data) as reader:
                    batches = list(reader)
                    from arrow import field
                    assert reader.schema == pa.schema([field("id", pa.int64()), field("value", pa.string())])
                    from fuze_file_query import descriptor
                    assert reader.schema.metadata == {
                        b'transit.definition': b'transit.fuze.logical-arrow.v1.2026-09-30',
                        b'transit.logical_schema': descriptor({'structure': [
                            {'name': 'id', 'type': {'int64': {}}, 'nullable': False, 'optional': False},
                            {'name': 'value', 'type': {'utf8': {}}, 'nullable': True, 'optional': False},
                        ]}).hex().encode(),
                    }
                    logical_descriptor = reader.schema.metadata[b"transit.logical_schema"]
                assert len(batches) == 1 and batches[0].num_rows == segment["rows"]
                from fuze_logical_arrow import arrow_cell
                batch = batches[0]
                for index in range(batch.num_rows):
                    number = len(actual)
                    text = None if number % 5 == 0 else chr(ord('a') + number % 26) * 220
                    assert arrow_cell(batch.column(0), index, {'int64': {}}) == b'\x03' + struct.pack('<q', number)
                    expected_value = b'\x01' if text is None else b'\x03' + struct.pack('<I', len(text)) + text.encode()
                    assert arrow_cell(batch.column(1), index, {'utf8': {}}) == expected_value
                    actual.append({'id': batch.column(0).field('value')[index].as_py(),
                                   'value': batch.column(1).field('value')[index].as_py()})
                total += len(data)
            assert actual == [{"id": i, "value": None if i % 5 == 0 else chr(ord("a") + i % 26) * 220} for i in range(41)]
            assert progress["rows"] == 41 and progress["segments"] == 6
            assert total == job["bytes"] > 672 and chain == bytes(job["chain"])
            received = json.loads(Path(f"{manifest}.received.json").read_text())
            completed = received["manifest"]
            assert completed["basis"] == {"resource": job["resource"], "revision": job["revision"], "head": progress["binding"]}
            assert completed["plan"] == progress["plan"]
            assert completed["rows"] == 41 and completed["bytes"] == total
            assert completed["chain"] == job["chain"] and received["segments"] == result["segments"]
            schema_hash = hashlib.sha256(bytes.fromhex(logical_descriptor.decode())).digest()
            assert bytes(completed["schema"]) == schema_hash
            for ordinal in range(completed["segments"]):
                captured_data = Path(f"{manifest}.{ordinal}.arrow").read_bytes()
                received_data = Path(f"{manifest}.received.{ordinal}.arrow").read_bytes()
                assert received_data == captured_data
                with pa.ipc.open_stream(received_data) as reader:
                    assert reader.read_all().num_rows == received["segments"][ordinal]["rows"]
            print("Growing query timing:", json.dumps({"initial_pages": 64, "seal_pages": 1, "finish_pages": finish_pages,
                  "delivery_limit_seconds": 600, "other_phase_limit_seconds": 180, **timings}), flush=True)
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

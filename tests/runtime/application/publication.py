"""Kill actual Station workers at publication boundaries over owned disk Ursula."""
from runner.paths import ROOT
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

from harness.ursula import Fixture
from harness.services import free_port, wait_ready


def check_fixtures():
    fixtures = ROOT / "packages/zig/transit-station/src/fixtures/publication.json"
    for row in json.loads(fixtures.read_text()):
        digest = hashlib.sha256(b"transit.station.publication.v1\0" + struct.pack("<II", row["format"], row["length"])).digest()
        for index, offset in enumerate(range(0, row["length"], 256)):
            chunk = bytes((37 * i + 11) % 256 for i in range(offset, min(offset + 256, row["length"])))
            digest = hashlib.sha256(b"\1" + digest + struct.pack("<IH", index, len(chunk)) + chunk).digest()
        assert digest.hex() == row["digest"], "Independent publication commitment drift"


def run(node, caller):
    check_fixtures()
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        configuration = {"profile": "native_v1", "genesis": {
            "realm": 46, "root_key": public, "max_clock_error_ms": 10000,
            "allow_history_trim": True},
            "ursula_url": fixture.url, "bucket": "publication", "journal": "authority",
            "port": port, "resident_pages": 64, "request_timeout_ms": 10000}
        config.write_text(json.dumps(configuration))
        manifest = fixture.root / "publication.json"
        faults, retries, failures = {}, set(), []
        observations = {"reads": 0, "max_value_bytes": 0, "turns": 0, "max_mutations": 0}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    envelope = json.loads(body)
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v1/query" and response.status == 200:
                        query = envelope["query"]
                        for name in ("entries", "version_entries"):
                            if name in query["kind"] and query["principal"] != 0:
                                entries = query["kind"][name]
                                assert entries.get("key") is not None, "Publication scanned the whole resource"
                                observations["reads"] += 1
                    if self.path == "/v1/command" and response.status == 200:
                        command = envelope["request"]["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        mutations = [item for item in turn.get("mutations", []) if item]
                        if turn:
                            observations["turns"] += 1
                            observations["max_mutations"] = max(observations["max_mutations"], len(mutations))
                        for item in mutations:
                            if item["value"] is not None:
                                observations["max_value_bytes"] = max(observations["max_value_bytes"], len(bytes.fromhex(item["value"])))
                        descriptors = [(bytes.fromhex(item["key"]), bytes.fromhex(item["value"]))
                                       for item in mutations if item["value"] and bytes.fromhex(item["value"]).startswith(b"SPR1")]
                        first = next((value for key, value in descriptors if int.from_bytes(key[15:23], "big") == 1), None)
                        selected = None
                        if first:
                            written, collected = struct.unpack_from("<II", first, 16)
                            if first[4] == 1 and written == 3:
                                selected = "append"
                            elif first[4] == 2:
                                selected = "publish"
                            elif first[4] == 4 and collected == 2:
                                selected = "collect"
                        for name, (request, receipt) in faults.items():
                            if body == request:
                                assert data == receipt, "Exact retry changed accepted receipt"
                                retries.add(name)
                        if selected is not None and selected not in faults:
                            faults[selected] = (body, data)
                            data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        proxy_url = f"http://127.0.0.1:{proxy.server_port}"
        node_log = (fixture.root / "node.log").open("w+")
        authority = child = None
        timings = {}
        try:
            subprocess.run([node, str(config), "--initialize"], stdout=node_log, stderr=subprocess.STDOUT, check=True, timeout=20)

            def start():
                process = subprocess.Popen([node, str(config)], stdout=node_log, stderr=subprocess.STDOUT)
                try:
                    wait_ready(fixture.http, process, url + "/health")
                except BaseException:
                    process.kill()
                    process.wait(timeout=10)
                    raise
                return process

            authority = start()
            for phase in ("stage", "seal", "publish", "cleanup", "finish"):
                began = time.monotonic()
                child = subprocess.Popen([caller, proxy_url, phase, str(manifest),
                                          str(configuration["genesis"]["max_clock_error_ms"])])
                if phase == "finish":
                    if child.wait(timeout=360) != 0:
                        raise RuntimeError("Publication finish failed")
                else:
                    while True:
                        if child.poll() is not None:
                            raise RuntimeError(f"Publication {phase} exited before crash boundary: {child.returncode}")
                        if time.monotonic() - began > 360:
                            raise TimeoutError(f"Publication {phase} boundary")
                        try:
                            saved = json.loads(manifest.read_text())
                        except (FileNotFoundError, json.JSONDecodeError):
                            saved = {}
                        if saved.get("phase") == phase:
                            break
                        time.sleep(0.05)
                    child.kill()
                    assert child.wait(timeout=10) == -9
                child = None
                timings[phase] = round(time.monotonic() - began, 3)
                print(f"Publication {phase}: {timings[phase]}s, resident_pages={configuration['resident_pages']}", flush=True)
                if phase != "finish":
                    authority.kill()
                    authority.wait(timeout=10)
                    authority = None
                    fixture.stop()
                    fixture.start()
                    configuration["resident_pages"] = 1 if phase in ("stage", "publish") else 64
                    config.write_text(json.dumps(configuration))
                    authority = start()
            assert not failures, failures
            assert retries == {"append", "publish", "collect"}, retries
            assert observations["max_value_bytes"] == 256
            assert observations["max_mutations"] == 4
            print("Publication evidence:", json.dumps({"record_bytes": 65536, "retained_records": 42,
                  "record_key_value_bytes": 65536 + 27 * 256 + 131,
                  "namespace_key_value_bytes": 59, "recovery_resident_pages": 1,
                  "killed_workers": 4, "exact_retries": sorted(retries),
                  "phase_seconds": timings, **observations}, sort_keys=True), flush=True)
        except BaseException:
            node_log.flush()
            node_log.seek(0)
            sys.stderr.write(node_log.read()[-12000:])
            raise
        finally:
            for process in (child, authority):
                if process is not None:
                    if process.poll() is None:
                        process.kill()
                    process.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            node_log.close()


if __name__ == "__main__":
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    run(*sys.argv[1:])

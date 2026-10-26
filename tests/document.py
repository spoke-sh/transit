"""Kill actual Document workers, node and owned disk store at durable boundaries."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

from harness.ursula import Fixture
from harness.services import free_port, wait_ready
from cold_storage import ColdStore


def run(node, caller):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        configuration = {"profile": "native_v1", "genesis": {
            "realm": 49, "root_key": public, "max_clock_error_ms": 10000,
            "allow_history_trim": True},
            "ursula_url": fixture.url, "bucket": "document", "journal": "authority",
            "port": port, "resident_pages": 64, "request_timeout_ms": 30000}
        config.write_text(json.dumps(configuration))
        manifest = fixture.root / "document.json"
        faults, retries, failures = {}, set(), []
        observations = {"reads": 0, "max_value_bytes": 0, "turns": 0, "max_mutations": 0}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                connection = HTTPConnection("127.0.0.1", port, timeout=35)
                try:
                    envelope = json.loads(body)
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v1/query" and response.status == 200:
                        query = envelope["query"]
                        if "entries" in query["kind"] and query["principal"] != 0:
                            assert query["kind"]["entries"].get("key") is not None
                            observations["reads"] += 1
                    if self.path == "/v1/command" and response.status == 200:
                        command = envelope["request"]["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        mutations = [item for item in turn.get("mutations", []) if item]
                        if turn:
                            observations["turns"] += 1
                            observations["max_mutations"] = max(observations["max_mutations"], len(mutations))
                        values = []
                        for item in mutations:
                            assert len(bytes.fromhex(item["key"])) <= 32
                            if item["value"] is not None:
                                value = bytes.fromhex(item["value"])
                                assert len(value) <= 256
                                observations["max_value_bytes"] = max(observations["max_value_bytes"], len(value))
                                values.append((bytes.fromhex(item["key"]), value))
                        selected = None
                        for key, value in values:
                            if value.startswith(b"SPR1"):
                                assert len(key) == 27 and key[:2] == b'\x00P'
                                if int.from_bytes(key[2:6], 'big') != 5:
                                    continue
                                record = int.from_bytes(key[15:23], "big")
                                written = int.from_bytes(value[16:20], "little")
                                collected = int.from_bytes(value[20:24], "little")
                                if record > 1 and value[4] == 1 and written == 1:
                                    selected = "node"
                                elif value[4] == 4 and collected > 0:
                                    selected = "collect"
                            elif value.startswith(b"SDJ1") and int.from_bytes(value[4:12], "little") == 1 and value[12] == 3:
                                selected = "accept"
                            elif value.startswith(b"SDP1") and value[12] == 2:
                                selected = "checkpoint"
                        for name, (request, receipt) in faults.items():
                            if body == request:
                                assert data == receipt, "Exact signed retry changed its receipt"
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
            for phase in ("stage", "accept", "checkpoint", "finish"):
                began = time.monotonic()
                child = subprocess.Popen([caller, proxy_url, phase, str(manifest)])
                if phase == "finish":
                    if child.wait(timeout=900) != 0:
                        raise RuntimeError("Document finish failed")
                else:
                    while True:
                        if child.poll() is not None:
                            raise RuntimeError(f"Document {phase} exited before crash boundary: {child.returncode}")
                        if time.monotonic() - began > 900:
                            raise TimeoutError(f"Document {phase} boundary")
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
                print(f"Document {phase}: {timings[phase]}s, resident_pages={configuration['resident_pages']}", flush=True)
                if phase != "finish":
                    authority.kill()
                    authority.wait(timeout=10)
                    authority = None
                    fixture.stop()
                    fixture.start()
                    configuration["resident_pages"] = 1 if phase == "checkpoint" else 64
                    config.write_text(json.dumps(configuration))
                    authority = start()
            assert not failures, failures
            assert retries == {"node", "accept", "checkpoint", "collect"}, retries
            # Compact index nodes need not fill a native value. Preserve the
            # ceiling (also checked on every write), not the retired byte size.
            assert 0 < observations["max_value_bytes"] <= 256
            assert observations["max_mutations"] == 4
            assert cold.data_objects() > 0
            print("Document evidence:", json.dumps({"recovery_resident_pages": 1, "hot_bytes": 8 * 1024 * 1024, "cold_objects": cold.data_objects(), "cold_bytes": cold.file_bytes(),
                  "killed_workers": 3, "exact_retries": sorted(retries),
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

"""Growing Station callers, bounded state access, faults and owned disk recovery."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
from harness.ursula import Fixture
from harness.services import free_port, wait_ready
from storage.providers.cold_storage import ColdStore


def run(node, caller, *, resident_pages=64):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with ColdStore() as cold, Fixture(storage_config=cold.config()) as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "native_v1", "genesis": {
            "realm": 43, "root_key": public, "max_clock_error_ms": 10000},
            "ursula_url": fixture.url, "bucket": "growing-station", "journal": "authority",
            "port": port, "resident_pages": resident_pages, "request_timeout_ms": 10000}))
        manifest = fixture.root / "pending.json"
        fault = {"read": False, "pending": None, "receipt": None, "retried": False,
                 "point_reads": 0,
                 "version_reads": 0, "version_steps": 0, "namespace_checks": 0, "history_head_reads": 0}
        view_faults = {name: {"pending": None, "receipt": None, "retried": False}
                       for name in ("open", "retain")}

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
                    if self.path == "/v1/query":
                        query = envelope["query"]
                        retained = "version_entries" in query["kind"]
                        entries = query["kind"].get("version_entries" if retained else "entries")
                        if query["principal"] != 0 and entries is not None and response.status == 200:
                            # Creation checks an empty namespace once. History
                            # replacement separately reads the exact head entry
                            # and its native commit revision in one bounded page.
                            # Neither operation scans the Table's rows.
                            if entries.get("key") is None:
                                assert not retained and entries.get("view") is not None
                                prefix = b"\x00P" + (8).to_bytes(4, "big") + (1).to_bytes(8, "big")
                                if entries.get("after") == prefix.hex():
                                    fault["namespace_checks"] += 1
                                else:
                                    head = prefix + b'h' + bytes(12)
                                    assert entries.get("after") == head[:-1].hex(), entries
                                    page = json.loads(data)['body']['entries']['page']
                                    observed = page['entries'][0]
                                    assert observed['key'] == head.hex() and observed['revision'] > 0, observed
                                    assert bytes.fromhex(observed['value']).startswith(b'STH1'), observed
                                    fault['history_head_reads'] += 1
                            else:
                                fault["version_reads" if retained else "point_reads"] += 1
                            if entries.get("key") == b"read-fault".hex() and not fault["read"]:
                                assert response.status == 200
                                changed = json.loads(data)
                                changed["realm"] += 1
                                data = json.dumps(changed).encode()
                                fault["read"] = True
                    elif self.path == "/v1/command" and any(kind in envelope["request"]["command"] for kind in ("turn", "turn_with_versions")):
                        proposal = envelope["request"]["command"]
                        turn = proposal["turn"] if "turn" in proposal else proposal["turn_with_versions"]["turn"]
                        mutations = turn["mutations"]
                        if response.status == 200 and any(item and item["key"] == b"version-progress".hex() for item in mutations):
                            fault["version_steps"] += 1
                        if fault["pending"] is None:
                            assert response.status == 200
                            fault["pending"], fault["receipt"] = body, data
                            data = b'{"position":0}'
                        elif body == fault["pending"] and response.status == 200:
                            assert data == fault["receipt"], "Exact retry changed the receipt"
                            fault["retried"] = True
                    if self.path == "/v1/command" and envelope["request"]["principal"] == 65541:
                        request = envelope["request"]
                        command = request["command"]
                        kind = ("open" if "open_view" in command and request["sequence"] == 2
                                else "retain" if any(command.get("turn_with_versions", {}).get("retain", []))
                                else None)
                        if kind is not None and response.status == 200:
                            retained = view_faults[kind]
                            if retained["pending"] is None:
                                retained["pending"], retained["receipt"] = body, data
                                data = b'{"position":0}'
                            elif body == retained["pending"]:
                                assert data == retained["receipt"], "View retry changed accepted identity"
                                retained["retried"] = True
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

            def call(mode, path, timeout):
                # Whole-schedule observation is separate from the unchanged
                # 10-second native request deadline and one-page recovery cache.
                phase_started = time.monotonic()
                print("Growing Station phase:", mode, "started", flush=True)
                subprocess.run([caller, proxy_url, mode, str(path)], check=True, timeout=timeout)
                print("Growing Station phase:", json.dumps({
                    "phase": mode, "seconds": round(time.monotonic() - phase_started, 3)
                }), flush=True)

            authority = start()
            started = time.monotonic()
            call("write", manifest, 240)
            write_seconds = round(time.monotonic() - started, 3)
            assert fault["read"] and fault["retried"] and fault["point_reads"] > 128
            call("views", str(manifest) + ".views", 60)
            assert all(value["retried"] for value in view_faults.values()), view_faults
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            # Keep the full recovery/fencing/read path at the smallest cache.
            # The repeated exchange uses a bounded 64-page test cache. Default
            # node configuration is unchanged; recovery still exceeds its cache.
            recovered = json.loads(config.read_text())
            recovered["resident_pages"] = 1
            config.write_text(json.dumps(recovered))
            authority = start()
            started = time.monotonic()
            call("views-recover", str(manifest) + ".views", 60)
            call("recover", manifest, 240)
            assert fault["namespace_checks"] == 1, "Only creation needs an empty-namespace prefix page"
            assert fault['history_head_reads'] > 0, "History must capture the native head commit coordinate"
            assert fault["version_steps"] == 1 and fault["version_reads"] > 0, ("Exactly one retained Table page before interruption", fault["version_steps"], fault["version_reads"])
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            authority = start()
            call("resume", manifest, 240)
            assert fault["version_steps"] == 6, "Retained continuation must resume without rescanning committed pages"
            print("Growing Station timing:", json.dumps({
                "write_resident_pages": resident_pages, "recover_resident_pages": 1,
                "write_seconds": write_seconds,
                "recover_seconds": round(time.monotonic() - started, 3),
                "namespace_checks": fault['namespace_checks'], "history_head_reads": fault['history_head_reads'],
                "retained_steps": fault["version_steps"], "cold_objects": cold.data_objects()}), flush=True)
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
    print("Growing Station: retained calls/Tables beyond 32 keys, bounded handler reads, poisoned read, lost turn reply and fresh-activation disk recovery passed.")


if __name__ == "__main__":
    import argparse
    import os
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("node")
    parser.add_argument("caller")
    parser.add_argument("--resident-pages", type=int, default=64)
    args = parser.parse_args()
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    run(args.node, args.caller, resident_pages=args.resident_pages)

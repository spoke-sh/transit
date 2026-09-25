"""Growing Station callers, bounded state access, faults and owned disk recovery."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time
from storage import Fixture, free_port, wait_ready


def run(node, caller, *, resident_pages=16):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "growing_v3", "genesis": {
            "realm": 43, "root_key": public, "max_clock_error_ms": 10000},
            "ursula_url": fixture.url, "bucket": "growing-station", "journal": "authority",
            "port": port, "resident_pages": resident_pages, "request_timeout_ms": 10000}))
        manifest = fixture.root / "pending.json"
        fault = {"read": False, "pending": None, "receipt": None, "retried": False, "point_reads": 0}

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
                    if self.path == "/v3/query":
                        query = envelope["query"]
                        entries = query["kind"].get("entries")
                        if query["principal"] != 0 and entries is not None:
                            assert entries.get("key") is not None, "Handler materialized a resource"
                            fault["point_reads"] += 1
                            if entries["key"] == b"read-fault".hex() and not fault["read"]:
                                assert response.status == 200
                                changed = json.loads(data)
                                changed["realm"] += 1
                                data = json.dumps(changed).encode()
                                fault["read"] = True
                    elif self.path == "/v3/command" and "turn" in envelope["request"]["command"]:
                        if fault["pending"] is None:
                            assert response.status == 200
                            fault["pending"], fault["receipt"] = body, data
                            data = b'{"position":0}'
                        elif body == fault["pending"] and response.status == 200:
                            assert data == fault["receipt"], "Exact retry changed the receipt"
                            fault["retried"] = True
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

            authority = start()
            started = time.monotonic()
            subprocess.run([caller, proxy_url, "write", str(manifest)], check=True, timeout=240)
            write_seconds = round(time.monotonic() - started, 3)
            assert fault["read"] and fault["retried"] and fault["point_reads"] > 128
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            # Keep the full recovery/fencing/read path at the smallest cache.
            # The ordinary exchange uses the node default instead of repeating
            # a deliberately thrashing cache configuration for every call.
            recovered = json.loads(config.read_text())
            recovered["resident_pages"] = 1
            config.write_text(json.dumps(recovered))
            authority = start()
            started = time.monotonic()
            subprocess.run([caller, proxy_url, "recover", str(manifest)], check=True, timeout=60)
            print("Growing Station timing:", json.dumps({
                "write_resident_pages": resident_pages, "recover_resident_pages": 1,
                "write_seconds": write_seconds,
                "recover_seconds": round(time.monotonic() - started, 3)}), flush=True)
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

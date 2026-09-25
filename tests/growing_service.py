"""Qualify the v3 public client/node with owned disk storage and reply faults."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
from storage import Fixture, free_port, wait_ready
from growing_maintenance import run as maintenance
from growing_station import run as station


def main(node, caller, station_caller):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "growing_v3", "genesis": {
            "realm": 42, "root_key": public, "max_clock_error_ms": 10000},
            "ursula_url": fixture.url, "bucket": "growing-service", "journal": "authority",
            "port": port, "resident_pages": 1, "request_timeout_ms": 10000}))
        manifest = fixture.root / "pending.json"
        fault = {"turns": 0, "pending": None, "receipt": None, "invalid_read": False, "retried": False}

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
                    if self.path == "/v3/command" and "turn" in envelope["request"]["command"]:
                        fault["turns"] += 1
                        if fault["turns"] == 16:
                            assert response.status == 200
                            fault["pending"], fault["receipt"] = body, data
                            data = b'{"position":0}'
                        elif body == fault["pending"] and response.status == 200:
                            assert data == fault["receipt"], "Historical retry changed receipt"
                            fault["retried"] = True
                    if fault["invalid_read"] and self.path == "/v3/query":
                        assert response.status == 200
                        changed = json.loads(data)
                        changed["realm"] += 1
                        data = json.dumps(changed).encode()
                        fault["invalid_read"] = False
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
            # Profile routes cannot silently select legacy semantics.
            connection = HTTPConnection("127.0.0.1", port, timeout=5)
            connection.request("POST", "/v2/command", b"{}", {"Content-Type": "application/json"})
            response = connection.getresponse()
            assert response.status == 404 and json.loads(response.read())["err"] == "NotFound"
            connection.close()
            subprocess.run([caller, proxy_url, "write", str(manifest)], check=True, timeout=180)
            assert fault["pending"] is not None
            fault["invalid_read"] = True
            subprocess.run([caller, proxy_url, "invalid-read", str(manifest)], check=True, timeout=20)
            assert not fault["invalid_read"]
            authority.kill()
            authority.wait(timeout=10)
            authority = None
            fixture.stop()
            fixture.start()
            authority = start()
            subprocess.run([caller, proxy_url, "recover", str(manifest)], check=True, timeout=40)
            assert fault["retried"]
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
    print("Growing public profile: signed paged reads/turns, invalid reply, exact retry after restart and revocation passed on one CPU.")
    maintenance(node, caller)
    station(node, station_caller)


if __name__ == "__main__":
    main(*sys.argv[1:])

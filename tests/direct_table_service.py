"""Real local Table HTTP owner, public typed caller, reply fault and disk restart."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import urllib.request

from storage import free_port, wait_ready


def run(node, caller):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with tempfile.TemporaryDirectory(prefix="transit-direct-table-") as directory:
        root = Path(directory)
        profile = root / "profile.json"
        config = root / "node.json"
        seed = root / "registrar.seed"
        seed.write_text("11" * 32)
        seed.chmod(0o600)
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        settings = {
            "genesis": {"realm": 42, "root_key": json.loads(subprocess.check_output([caller, "public"], timeout=15))},
            "local_directory": str(root / "native"),
            "port": port, "resident_pages": 1, "request_timeout_ms": 60000,
        }
        config.write_text(json.dumps(settings))
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        log = (root / "node.log").open("w+")
        authority = None
        proxy = None
        thread = None

        def start():
            child = subprocess.Popen([node, str(config), "--bootstrap"], stdout=log, stderr=subprocess.STDOUT)
            try:
                wait_ready(http, child, url + "/health")
            except BaseException:
                child.kill()
                child.wait(timeout=15)
                raise
            return child

        def stop(child):
            child.terminate()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=15)

        fault = {"changed": False, "execute": None, "requests": 0, "commands": []}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                headers = {"Content-Type": "application/json"}
                for name in ("x-transit-control", "x-transit-wait"):
                    if name in self.headers:
                        headers[name] = self.headers[name]
                connection = HTTPConnection("127.0.0.1", port, timeout=70)
                try:
                    connection.request("POST", self.path, body, headers)
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/table/v1":
                        fault["requests"] += 1
                        operation = envelope["action"].get("operation")
                        if operation and operation["command"] == "execute":
                            fault["execute"] = body
                            if operation["binding"]["identity"]["operation"] == 2 and not fault["changed"]:
                                assert response.status == 200, data
                                parsed = json.loads(data)
                                assert "committed" in parsed["result"]["rows"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                fault["changed"] = True
                    elif self.path == "/v1/command":
                        fault["commands"].append(next(iter(envelope["request"]["command"])))
                    self.send_response(response.status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()

        try:
            authority = start()
            subprocess.run([caller, url, "provision", str(profile)], check=True, timeout=180)
            stop(authority)
            authority = None
            settings["table"] = {"catalog": json.loads(profile.read_text())["catalog"], "registrar": {"principal": 0, "seed_file": str(seed)}}
            config.write_text(json.dumps(settings))
            authority = start()
            proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            endpoint = f"http://127.0.0.1:{proxy.server_port}"
            subprocess.run([caller, endpoint, "write", str(profile)], check=True, timeout=180)
            assert fault["changed"]
            segments = list((root / "native").rglob("*.tseg"))
            assert segments, "Bulk acceptance created no .tseg object"
            stop(authority)
            authority = None
            authority = start()
            subprocess.run([caller, endpoint, "recover", str(profile)], check=True, timeout=180)
            stop(authority)
            authority = None
            authority = start()
            subprocess.run([caller, endpoint, "lifecycle", str(profile)], check=True, timeout=180)
            assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
            assert fault["execute"] is not None
            # An admission hint cannot place ordinary execution in the reserve.
            connection = HTTPConnection("127.0.0.1", port, timeout=15)
            connection.request("POST", "/table/v1", fault["execute"], {"Content-Type": "application/json", "X-Transit-Control": "table"})
            response = connection.getresponse()
            assert response.status == 400 and json.loads(response.read())["err"] == "InvalidRequest"
            connection.close()
            print(f"Direct Table HTTP: {fault['requests']} typed calls, 64 KiB point row, {len(segments)} initial .tseg object(s), full CRUD/DDL, exact lost-reply recovery, retained pins across rewrite/drop/recreation and two restarts, current revocation and reserved-control rejection passed.")
        except BaseException:
            log.flush()
            log.seek(0)
            sys.stderr.write(log.read()[-48000:])
            raise
        finally:
            if proxy is not None:
                proxy.shutdown()
                proxy.server_close()
            if thread is not None:
                thread.join(timeout=15)
            if authority is not None:
                stop(authority)
            log.close()


if __name__ == "__main__":
    run(*sys.argv[1:])

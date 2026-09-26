"""Real public query daemons and installed shell over a disk-backed authority."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import select
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready


def run(node, host, cli, proof):
    node, host, cli, proof = (str(Path(path).resolve()) for path in (node, host, cli, proof))
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([proof, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "growing_v3", "genesis": {
            "realm": 45, "root_key": public, "max_clock_error_ms": 10000},
            "ursula_url": fixture.url, "bucket": "public-query", "journal": "authority",
            "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        processes, logs = [], []
        fault = {"lost": None, "retry": False, "stage": threading.Event(), "pause": threading.Event()}
        fault["pause"].set()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                message = json.loads(body)
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v3/command" and response.status == 200:
                        request = message["request"]
                        if request["principal"] == 1234 and "send" in request["command"]:
                            value = bytes.fromhex(request["command"]["send"]["value"])
                            if b"PQR1" in value:
                                if fault["lost"] is None:
                                    fault["lost"] = (body, data)
                                    data = b'{"position":0}'
                                elif body == fault["lost"][0]:
                                    assert data == fault["lost"][1]
                                    fault["retry"] = True
                        command = request["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        if request["principal"] == 65536 and any(item and bytes.fromhex(item["key"]).startswith(b"\x00Qs") for item in turn.get("mutations", [])):
                            fault["stage"].set()
                            fault["pause"].wait(timeout=20)
                    self.send_response(response.status)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass
                finally: connection.close()

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        proxy_url = f"http://127.0.0.1:{proxy.server_port}"
        def start(name, command):
            log = (fixture.root / f"{name}.log").open("w+")
            logs.append(log)
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            processes.append(process)
            return process
        def provision(mode):
            return subprocess.run([proof, url, mode, str(fixture.root if mode == "provision" else fixture.root / "cli.json")], check=True, timeout=60, capture_output=True)
        try:
            subprocess.run([node, str(config), "--initialize"], check=True, capture_output=True, timeout=30)
            authority = start("node", [node, str(config)])
            wait_ready(fixture.http, authority, url + "/health")
            provision("provision")
            for name in ("cli", "source", "requester", "courier", "inspector"):
                path = fixture.root / f"{name}.json"
                options = json.loads(path.read_text())
                options["url"] = proxy_url
                path.write_text(json.dumps(options))
            requester = start("requester", [host, str(fixture.root / "requester.json")])
            source = start("source", [host, str(fixture.root / "source.json")])
            courier = start("courier", [host, str(fixture.root / "courier.json")])
            inspector = subprocess.run([cli, "query", str(fixture.root / "inspector.json")], input="/schema\n/quit\n", text=True, capture_output=True, timeout=15)
            assert "QueryAccessDenied" in inspector.stdout, inspector.stdout
            shell = subprocess.Popen([cli, "query", str(fixture.root / "cli.json")], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1)
            processes.append(shell)
            def receive(timeout=20):
                ready, _, _ = select.select([shell.stdout], [], [], timeout)
                assert ready, "query shell did not respond"
                line = shell.stdout.readline().strip()
                assert line, f"query shell exited: {shell.poll()}"
                return json.loads(line) if line.startswith("{") else line
            def send(text):
                shell.stdin.write(text + "\n")
                shell.stdin.flush()
                return receive()
            assert "Transit query" in receive()
            assert send("/format json") == {"format": "json"}
            before = send("/schema")
            assert before["schema"]["value_type"] == "int64"
            assert str(send("DELETE FROM items")).startswith("error:")
            assert send("/schema")["sequence"] == before["sequence"], "unsupported SQL submitted work"
            fault["pause"].clear()
            assert send("SELECT id, value FROM items") == "error: InvalidAuthorityResponse"
            submitted = send("/retry")["submitted"]
            assert fault["retry"], "retry did not retain exact signed admission"
            assert fault["stage"].wait(timeout=30), "source never staged result"
            busy = json.loads(provision("submit-busy").stdout)["submitted"]
            until = time.monotonic() + 20
            while True:
                status = send(f"/resume {busy}")
                if isinstance(status, dict) and status["phase"] == "busy": break
                assert time.monotonic() < until, status
                time.sleep(0.05)
            assert send(f"/resume {submitted}")["phase"] == "capturing"
            source.kill(); source.wait(timeout=10)
            fault["pause"].set()
            same = subprocess.run([host, str(fixture.root / "source.json")], capture_output=True, timeout=15)
            assert same.returncode and b"FreshOwnershipRequired" in same.stderr
            provision("fence")
            path = fixture.root / "source.json"
            options = json.loads(path.read_text()); options["generation"] = 4; path.write_text(json.dumps(options))
            source = start("source-recovered", [host, str(path)])
            deadline = time.monotonic() + 90
            phases = set()
            while True:
                status = send("/status")
                if isinstance(status, dict):
                    phases.add(status["phase"])
                    if status["phase"] == "complete": break
                assert all(process.poll() is None for process in (source, requester, courier)), "query daemon exited"
                assert time.monotonic() < deadline, (phases, status)
                time.sleep(0.05)
            assert status["correlation"] == submitted
            assert status["manifest"]["rows"] == 41
            rows = []
            for index in range(status["manifest"]["segments"]):
                page = send("/next")
                assert isinstance(page, dict), page
                assert page["ordinal"] == index and page["manifest"] == status["manifest"]
                rows.extend(row for row in page["rows"] if row is not None)
            expected = [[{"int64": str(i)}, {"null": {}} if i % 5 == 0 else {"int64": str(9007199254740993 + i)}] for i in range(41)]
            assert rows == expected, (rows[:3], expected[:3])
            provision("revoke")
            denied = send(f"/resume {submitted}")
            assert denied == "error: AccessDenied", denied
            assert send("/status") == "error: NoQuery"
            provision("restore")
            assert send(f"/resume {submitted}")["phase"] == "complete"
            assert send("/next")["ordinal"] == 0
            # Schema changes are explicit rejections, not a rebound positional plan.
            wrong = json.loads(provision("bad-schema").stdout)["submitted"]
            until = time.monotonic() + 20
            while True:
                status = send(f"/resume {wrong}")
                if isinstance(status, dict) and status["phase"] == "rejected": break
                assert time.monotonic() < until, status
                time.sleep(0.05)
            # Pause a second capture, revoke during its incomplete delivery, and
            # explicitly cancel after restoring read rights. No partial page may pass.
            fault["stage"].clear(); fault["pause"].clear()
            second = send("SELECT value FROM items")["submitted"]
            assert fault["stage"].wait(timeout=30)
            incomplete = send("/next")
            assert incomplete == "error: IncompleteResult", incomplete
            provision("revoke")
            assert send("/status") == "error: AccessDenied"
            assert send("/next") == "error: NoQuery"
            provision("restore")
            assert send(f"/resume {second}")["phase"] == "capturing"
            assert "cancellation_submitted" in send("/cancel")
            until = time.monotonic() + 20
            while True:
                status = send("/status")
                if isinstance(status, dict) and status["phase"] == "cancelled": break
                assert time.monotonic() < until, status
                time.sleep(0.05)
            fault["pause"].set()
            shell.stdin.write("/quit\n"); shell.stdin.flush(); shell.wait(timeout=10)
            print("public query: real shell/hosts, 41 exact int64/null rows, exact retry, fenced crash recovery, busy admission, schema rejection, incomplete-result refusal, cancellation and read-time revocation passed")
        except BaseException:
            for log in logs:
                log.flush(); log.seek(0); sys.stderr.write(log.read()[-4000:])
            raise
        finally:
            fault["pause"].set()
            for process in reversed(processes):
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)
            for log in logs: log.close()


if __name__ == "__main__":
    run(*sys.argv[1:])

"""Real public query daemons and installed shell over a disk-backed authority."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore
from unified_shell import Shell


def run(node, host, cli, proof):
    node, host, cli, proof = (str(Path(path).resolve()) for path in (node, host, cli, proof))
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        public = json.loads(subprocess.check_output([proof, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "native_v1", "genesis": {
            "realm": 45, "root_key": public, "max_clock_error_ms": 10000},
            "local_directory": str(fixture.root / "authority"),
            "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        processes, logs = [], []
        fault = {"lost": None, "retry": False, "startup": set(), "stage": threading.Event(), "pause": threading.Event(), "wait_headers": 0}
        fault["pause"].set()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                message = json.loads(body)
                if self.path == "/v1/query":
                    query = message["query"]
                    principal = query["principal"]
                    if principal in (65536, 65537) and "process" in query["kind"] and principal not in fault["startup"]:
                        fault["startup"].add(principal)
                        data = b'{"err":"HttpCapacity"}'
                        self.send_response(503)
                        self.send_header("Content-Length", str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                        return
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    # Preserve native scheduling/control while injecting reply
                    # faults. Dropped waits make idle workers hammer authority.
                    headers = {"Content-Type": "application/json"}
                    for name in ("X-Transit-Wait", "X-Transit-Control", "traceparent"):
                        if value := self.headers.get(name):
                            headers[name] = value
                    if "X-Transit-Wait" in headers:
                        fault["wait_headers"] += 1
                    connection.request("POST", self.path, body, headers)
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v1/command" and response.status == 200:
                        request = message["request"]
                        if request["principal"] == 1234 and "send" in request["command"]:
                            value = bytes.fromhex(request["command"]["send"]["value"])
                            if value[13:].startswith(b"UQB1"):
                                if fault["lost"] is None:
                                    fault["lost"] = (body, data)
                                    data = b'{"position":0}'
                                elif body == fault["lost"][0]:
                                    assert data == fault["lost"][1]
                                    fault["retry"] = True
                        command = request["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        if request["principal"] == 65536 and not fault["stage"].is_set() and any(item and bytes.fromhex(item["key"]).startswith(b"\x00Us") for item in turn.get("mutations", [])):
                            fault["stage"].set()
                            fault["pause"].wait(timeout=60)
                    self.send_response(response.status)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass
                finally: connection.close()

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        proxy.daemon_threads = True
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
            return subprocess.run([proof, url, mode, str(fixture.root if mode == "provision" else fixture.root / "cli.json")], check=True, timeout=300 if mode == "provision" else 60, capture_output=True)
        try:
            subprocess.run([node, str(config), "--initialize"], check=True, capture_output=True, timeout=30)
            authority = start("node", [node, str(config)])
            wait_ready(fixture.http, authority, url + "/health")
            subprocess.run([proof, url, "catalog-bootstrap", str(fixture.root)], check=True, capture_output=True, timeout=300)
            authority.terminate(); authority.wait(timeout=10)
            settings = json.loads(config.read_text())
            settings['table'] = json.loads((fixture.root / 'catalog-node.json').read_text())
            config.write_text(json.dumps(settings))
            authority = start('node-catalog', [node, str(config)])
            wait_ready(fixture.http, authority, url + '/health')
            provision("provision")
            for name in ("cli", "source", "requester", "courier", "inspector"):
                path = fixture.root / f"{name}.json"
                options = json.loads(path.read_text())
                options["url"] = proxy_url
                if options.get("tables"): options["tables"]["url"] = proxy_url
                path.write_text(json.dumps(options))
            requester = start("requester", [host, str(fixture.root / "requester.json")])
            source = start("source", [host, str(fixture.root / "source.json")])
            courier = start("courier", [host, str(fixture.root / "courier.json")])
            inspector = subprocess.run([cli, "query", str(fixture.root / "inspector.json")], input=".schema\n.quit\n", text=True, capture_output=True, timeout=15)
            # Read-only inspection cannot impersonate the dedicated requester.
            assert "QueryConfigurationChanged" in inspector.stdout, (inspector.stdout, inspector.stderr)
            (fixture.root / "shell.json").write_text((fixture.root / "cli.json").read_text())
            shell = Shell(cli, fixture.root)
            processes.append(shell.process)
            send = shell.call
            def advance(progress):
                until = time.monotonic() + 120
                while "waiting_for_input" in progress:
                    assert time.monotonic() < until, progress
                    progress = send(".advance")
                return progress
            def submit(sql):
                receipt = send(sql)
                assert "receipt" in receipt, receipt
                return advance(shell.read())
            before = json.loads(provision("next-sequence").stdout)
            description = send(".schema")["description"]
            assert description["source"]["source"]["source"]["table"]["row_type"]["structure"][1]["type"] == {"int64": {}}
            assert send(".new 1")["status"] is None
            unsupported = send("DELETE FROM items")
            assert unsupported["err"] == "UnsupportedStatement", unsupported
            assert json.loads(provision("next-sequence").stdout) == before, "unsupported SQL submitted work"
            fault["pause"].clear()
            assert send("SELECT id, value FROM items") == {"err": "InvalidAuthorityResponse", "uncertain": True}
            assert "receipt" in send(".retry")
            assert advance(shell.read())["status"]["phase"] in ("admitted", "complete")
            assert fault["retry"], "retry did not retain exact signed admission"
            assert fault["stage"].wait(timeout=120), "source never staged result"
            partial = send(".status")["status"]
            assert partial["phase"] == "admitted" and partial["manifest"] is None
            assert send(".next")["err"] == "IncompleteResult"
            # A second shell shares the durable requester quota, not a local lock.
            competitor = Shell(cli, fixture.root)
            processes.append(competitor.process)
            assert competitor.call(".new 2")["status"] is None
            assert "receipt" in competitor.call("SELECT value FROM items")
            busy = competitor.read()
            assert bytes.fromhex(busy["rejected"]) == b"QueryBusy", busy
            competitor.close()
            source.kill(); source.wait(timeout=10)
            fault["pause"].set()
            same = subprocess.run([host, str(fixture.root / "source.json")], capture_output=True, timeout=15)
            assert same.returncode and b"FreshOwnershipRequired" in same.stderr
            generation = json.loads(provision("fence").stdout)["generation"]
            path = fixture.root / "source.json"
            options = json.loads(path.read_text()); options["generation"] = generation; path.write_text(json.dumps(options))
            # Keep the source stopped while checking current rights over its durable prefix.
            saved_bundle = send(".bundle")
            saved_sequence = provision("next-sequence").stdout
            provision("revoke")
            assert send(".next")["err"] == "IncompleteResult"
            assert send(".resume 1")["err"] == "AccessDenied"
            # Denial invalidates result access, not original recovery evidence.
            assert send(".next")["err"] == "IncompleteResult"
            assert send(".status")["status"]["phase"] == "admitted"
            assert send(".bundle") == saved_bundle
            assert provision("next-sequence").stdout == saved_sequence
            provision("restore")
            assert send(".resume 1")["status"]["phase"] == "admitted"
            source = start("source-recovered", [host, str(path)])
            # Current role/object checks add native reads to each private turn.
            # This bounds proof observation; it does not extend a source lease
            # or treat a still-admitted query as a successful result.
            deadline = time.monotonic() + 300
            while True:
                status = send(".status")["status"]
                if status["phase"] == "complete": break
                assert all(process.poll() is None for process in (source, requester, courier)), "query daemon exited"
                assert time.monotonic() < deadline, status
                time.sleep(0.05)
            rows, segments, manifest = [], 0, None
            while True:
                page = send(".next")
                assert page["ordinal"] == str(segments), page
                manifest = page["manifest"]
                rows.extend(page["cells"]); segments += 1
                if page["complete_coverage"]: break
            expected = [[{"value": {"atom": {"signed": str(i)}}}, {"null": {}} if i % 5 == 0 else {"value": {"atom": {"signed": str(9007199254740993 + i)}}}] for i in range(41)]
            assert rows == expected, (rows[:3], expected[:3])
            assert int(manifest["rows"]) == 41 and int(manifest["segments"]) == segments
            # A fresh HTTP exchange reconciles the original admission after later sequences.
            wire = HTTPConnection("127.0.0.1", port, timeout=15)
            wire.request("POST", "/v1/command", fault["lost"][0], {"Content-Type": "application/json"})
            response = wire.getresponse()
            assert response.status == 200 and response.read() == fault["lost"][1]
            wire.close()
            captured = json.loads(provision("capture:1").stdout)
            assert captured == {name: int(manifest[name]) for name in ("rows", "bytes", "segments")}
            provision("revoke-read")
            refused = subprocess.run([proof, url, "capture:1", str(fixture.root / "cli.json")], capture_output=True, timeout=15)
            assert refused.returncode and b"AccessDenied" in refused.stderr, refused.stderr
            provision("restore")
            provision("revoke")
            assert send(".resume 1")["err"] == "AccessDenied"
            assert send(".status")["status"]["phase"] == "complete"
            denied_page = send(".next")
            assert denied_page["err"] == "AccessDenied", denied_page
            provision("restore")
            assert send(".resume 1")["status"]["phase"] == "complete"
            assert send(".next")["ordinal"] == "0"
            # A configured schema change fails before native admission.
            wrong = json.loads((fixture.root / "cli.json").read_text())
            wrong["workspace"]["source"]["source"]["table"]["row_type"]["structure"][1]["type"] = {"utf8": {}}
            wrong_path = fixture.root / "wrong-schema.json"
            wrong_path.write_text(json.dumps(wrong))
            sequence = provision("next-sequence").stdout
            rejected = subprocess.run([cli, "query", str(wrong_path)], input=".schema\n.quit\n", text=True, capture_output=True, timeout=15)
            assert "TableSchemaChanged" in rejected.stdout, rejected.stdout
            assert provision("next-sequence").stdout == sequence
            # Pause another captured prefix and cancel explicitly after restoring access.
            fault["stage"].clear(); fault["pause"].clear()
            assert send(".new 3")["status"] is None
            assert submit("SELECT value FROM items")["status"]["phase"] == "admitted"
            assert fault["stage"].wait(timeout=120)
            assert send(".next")["err"] == "IncompleteResult"
            provision("revoke")
            assert send(".next")["err"] == "IncompleteResult"
            assert send(".resume 3")["err"] == "AccessDenied"
            assert send(".next")["err"] == "IncompleteResult"
            assert send(".status")["status"]["phase"] == "admitted"
            provision("restore")
            assert send(".resume 3")["status"]["phase"] == "admitted"
            assert submit(".cancel")["status"]["phase"] == "cancelled"
            fault["pause"].set()
            provision("retire-source")
            retired = send(".resume 1")
            assert retired["err"] in ("QuerySourceUnavailable", "ResourceUnavailable"), retired
            assert send(".next")["err"] == "IncompleteResult"
            assert send(".status")["status"]["phase"] == "cancelled"
            assert fault["startup"] == {65536, 65537}, fault["startup"]
            assert fault["wait_headers"] > 0, "native wait hints were not exercised"
            shell.close()
            print("public query: transient startup reads, real shell/hosts, 41 exact int64/null rows, exact retry, fenced crash recovery, busy admission, schema rejection, incomplete-result refusal, cancellation and read-time revocation passed")
        except BaseException as error:
            if isinstance(error, subprocess.CalledProcessError) and error.stderr:
                print(error.stderr.decode()[-5000:], file=sys.stderr)
            for log in logs:
                log.flush(); log.seek(0)
                content = log.read()
                tail = content if len(content) <= 4000 else content[-4000:].partition('\n')[2]
                print(json.dumps({'worker_log': Path(log.name).name}), file=sys.stderr)
                sys.stderr.write(tail)
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

"""Board's real growing inspection and separately credentialed query boundary."""
import json
import os
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import signal
import socket
import struct
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
from storage import Fixture, free_port, wait_ready


class UnavailableQueryReplies:
    """Replace one real preparation/acceptance reply; require identical recovery."""
    def __init__(self, port):
        self.saved, self.verified, self.errors = {}, set(), []
        owner = self
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                operation = next(iter(json.loads(body)))
                connection = HTTPConnection('127.0.0.1', port, timeout=10)
                try:
                    headers = {name: self.headers[name] for name in ('Origin', 'Content-Type')}
                    connection.request('POST', self.path, body, headers)
                    response = connection.getresponse()
                    data, status = response.read(), response.status
                    if status == 200 and operation in ('next', 'submit'):
                        if operation not in owner.saved:
                            owner.saved[operation] = (body, data)
                            print(f"Board query: injected unavailable {operation} reply after success", flush=True)
                            status, data = 503, b'{"err":"Unavailable"}'
                        elif operation not in owner.verified:
                            original, accepted = owner.saved[operation]
                            assert body == original, 'Query recovery changed the original request'
                            if operation == 'submit':
                                assert data == accepted, 'Exact submission returned another receipt'
                            owner.verified.add(operation)
                            print(f"Board query: verified identical {operation} recovery", flush=True)
                    self.send_response(status)
                    self.send_header('Content-Length', str(len(data)))
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Cache-Control', response.getheader('Cache-Control', ''))
                    self.end_headers()
                    self.wfile.write(data)
                except Exception as error:
                    owner.errors.append(type(error).__name__)
                    raise
                finally:
                    connection.close()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        self.url = f'http://127.0.0.1:{self.server.server_address[1]}'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        assert not self.thread.is_alive()


class QueryCapacityRefusals:
    """Refuse selected native calls from Board without forwarding them."""
    def __init__(self, port, principal):
        self.lock = threading.Lock()
        self.selection, self.remaining, self.attempts = None, 0, 0
        self.errors = []
        self.closed_replies = 0
        owner = self
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                signed = json.loads(body)
                call = signed.get('query', signed.get('request', {}))
                operation = call.get('kind', call.get('command'))
                if isinstance(operation, dict): operation = next(iter(operation))
                selected = (self.path, operation)
                refusal = None
                with owner.lock:
                    if call.get('principal') == principal and selected == owner.selection:
                        owner.attempts += 1
                        if owner.remaining:
                            owner.remaining -= 1
                            refusal = owner.refusal
                connection = None
                try:
                    if refusal:
                        status, code = refusal
                        data = json.dumps({'err': code}).encode()
                    else:
                        connection = HTTPConnection('127.0.0.1', port, timeout=10)
                        headers = {'Content-Type': 'application/json'}
                        if self.headers.get('traceparent'): headers['traceparent'] = self.headers['traceparent']
                        connection.request('POST', self.path, body, headers)
                        response = connection.getresponse()
                        data, status = response.read(), response.status
                    try:
                        self.send_response(status)
                        self.send_header('Content-Length', str(len(data)))
                        self.send_header('Content-Type', 'application/json')
                        self.end_headers()
                        self.wfile.write(data)
                    except (BrokenPipeError, ConnectionResetError):
                        # Board can cancel this read under its original deadline.
                        # Count the abandoned reply; upstream failures still reach
                        # the outer error check and fail the fixture.
                        with owner.lock:
                            owner.closed_replies += 1
                except Exception as error:
                    owner.errors.append(type(error).__name__)
                    raise
                finally:
                    if connection: connection.close()
        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        self.url = f'http://127.0.0.1:{self.server.server_address[1]}'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def arm(self, path, operation, count, code='HttpCapacity', status=503):
        with self.lock:
            assert self.remaining == 0
            self.selection, self.remaining, self.attempts = (path, operation), count, 0
            self.refusal = status, code

    def finish(self, *, attempts=None):
        with self.lock:
            assert self.remaining == 0, 'Expected capacity refusal was not reached'
            if attempts is not None: assert self.attempts == attempts, self.attempts
            self.selection = None
        assert not self.errors, self.errors

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        assert not self.thread.is_alive()


def check_capacity_disconnect():
    """A downstream reset after forwarding is not a failed proxy operation."""
    arrived, release = threading.Event(), threading.Event()
    class Upstream(BaseHTTPRequestHandler):
        def log_message(self, *_): pass
        def do_POST(self):
            self.rfile.read(int(self.headers['Content-Length']))
            arrived.set()
            assert release.wait(timeout=5), 'disconnect control was not released'
            data = b'{}'
            self.send_response(200)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
    upstream = ThreadingHTTPServer(('127.0.0.1', 0), Upstream)
    thread = threading.Thread(target=upstream.serve_forever, daemon=True)
    thread.start()
    proxy = QueryCapacityRefusals(upstream.server_port, 1234)
    downstream = socket.create_connection(proxy.server.server_address, timeout=5)
    try:
        body = b'{"query":{"principal":1234,"kind":{"resource":1}}}'
        downstream.sendall(b'POST /v1/query HTTP/1.1\r\nHost: localhost\r\nContent-Length: ' + str(len(body)).encode() + b'\r\n\r\n' + body)
        assert arrived.wait(timeout=5), 'disconnect control never reached upstream'
        downstream.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0))
        downstream.close()
        release.set()
        deadline = time.monotonic() + 5
        while not proxy.errors and not getattr(proxy, 'closed_replies', 0):
            assert time.monotonic() < deadline, 'proxy did not observe client reset'
            time.sleep(0.01)
        assert not proxy.errors, proxy.errors
        assert proxy.closed_replies == 1, proxy.closed_replies
    finally:
        release.set()
        downstream.close()
        proxy.close()
        upstream.shutdown(); upstream.server_close(); thread.join(timeout=5)
        assert not thread.is_alive()


def run(node, host, proof, board, browser=False):
    check_capacity_disconnect()
    node, host, proof, board = (str(Path(path).resolve()) for path in (node, host, proof, board))
    with Fixture() as fixture:
        processes, logs = [], []
        faults = capacity = None
        def start(name, command):
            log = (fixture.root / f"{name}.log").open("w+")
            logs.append(log)
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            processes.append(process)
            return process
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        public = json.loads(subprocess.check_output([proof, "public"], timeout=10))
        node_config = fixture.root / "node.json"
        node_config.write_text(json.dumps({"profile": "native_v1", "genesis": {"realm": 45, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "board-query", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        def admin(mode):
            # This is the same multi-turn catalog setup as public_query.py.
            # Its setup budget is separate from individual control/query waits.
            started = time.monotonic()
            result = subprocess.run([proof, url, mode, str(fixture.root if mode == "provision" else fixture.root / "cli.json")], capture_output=True, timeout=300 if mode == "provision" else 60)
            assert result.returncode == 0, result.stderr.decode()
            if mode == "provision":
                print(f"Board query provisioning: {time.monotonic() - started:.3f}s (300s setup budget)", flush=True)
            return result
        try:
            subprocess.run([node, str(node_config), "--initialize"], check=True, capture_output=True, timeout=30)
            authority = start("node", [node, str(node_config)])
            wait_ready(fixture.http, authority, url + "/health")
            admin("provision")
            workers = {name: start(name, [host, str(fixture.root / f"{name}.json")]) for name in ("source", "requester", "courier")}
            caller = json.loads((fixture.root / "cli.json").read_text())
            capacity = QueryCapacityRefusals(port, caller['connection']['principal'])
            board_port = free_port()
            origin = f"http://127.0.0.1:{board_port}"
            options = {"upstream": capacity.url, "realm": 45, "principal": 55, "profile": "native_v1", "seed_file": str(fixture.root / "inspector.seed"), "public_origin": origin, "port": board_port, "request_timeout_ms": 5000, "upstream_timeout_ms": 1500, "query": {"seed_file": caller["seed_file"], "connection": caller["connection"], "workspace": caller["workspace"]}}
            config = fixture.root / "board.json"
            config.write_text(json.dumps(options))
            serving = start("board", [board, str(config)])
            wait_ready(fixture.http, serving, origin + "/health")
            faults = UnavailableQueryReplies(board_port)
            def request(path, operation=None, *, status=200, headers=None, deadline=None, retry=True):
                body = None if operation is None else json.dumps(operation).encode()
                supplied = {"Origin": origin, "Content-Type": "application/json"} | (headers or {})
                endpoint = faults.url if path == "/api/v1/query" else origin
                req = urllib.request.Request(endpoint + path, body, supplied, method="GET" if operation is None else "POST")
                kind = None if operation is None else next(iter(operation))
                reading = operation is None or (path == "/api/v1/query" and kind in ("describe", "status", "page", "observe"))
                # next prepares without admitting work; submit carries an already
                # frozen signed token. Recovery reuses this exact encoded body.
                recovering = path == "/api/v1/query" and status == 200 and kind in ("next", "submit")
                if recovering and deadline is None: deadline = time.monotonic() + 10
                attempts = (12 if path.split("?", 1)[0] == "/api/v1/atlas" else 8) if reading or recovering else 1
                if not retry: attempts = 1
                for attempt in range(attempts):
                    time.sleep(0.12)
                    remaining = 10 if deadline is None else deadline - time.monotonic()
                    assert remaining > 0, "Board observation exceeded its existing deadline"
                    try: response = fixture.http.open(req, timeout=min(10, remaining))
                    except urllib.error.HTTPError as err: response = err
                    with response:
                        data = response.read()
                        value = json.loads(data)
                        unavailable = response.status == 503 and value.get("err") == "Unavailable"
                        changed = (status == 200 and response.status == 409 and
                                   value.get("err") == "QueryExpired" and
                                   (kind in ("describe", "status", "page") or path == "/api/v1/atlas"))
                        if (reading or recovering) and response.status != status and (unavailable or changed):
                            # Temporary unavailability cannot prove an expected
                            # denial or expired cut. Repeat the identical read,
                            # including its saved position, until that assertion
                            # is observable. Submission recovery retains the
                            # original token; it never prepares replacement work.
                            if kind == "observe" and status == 200 and unavailable:
                                return value  # settle owns the receipt deadline.
                            if attempt + 1 < attempts:
                                time.sleep(0.1)
                                continue
                        assert response.status == status, (response.status, data[:500])
                        assert response.headers["Cache-Control"] == "no-store"
                        return value
            def api(operation, **kwargs):
                return request("/api/v1/query", operation, **kwargs)
            def current_atlas():
                return request("/api/v1/atlas")
            caps = request("/api/v1/capabilities")
            assert caps["profile"] == "native_v1" and caps["query_enabled"] and caps["read_only"]
            atlas = current_atlas()
            assert [row["id"] for row in atlas["resources"]["entries"] if row] == [caller["connection"]["resource"], caller["connection"]["requests"]]
            assert atlas["identity"]["permissions"] == 16
            participant = json.loads(admin("participation").stdout)
            resource, pid = caller["connection"]["resource"], participant["pid"]
            path = f"/api/v1/resources/{resource}/participation"
            group = request(path)
            assert group["resource"]["id"] == resource and len(group["members"]) == 8
            assert group["process_position"] is not None
            selected = request(path + f"?pid={pid}")
            total, pages = 0, 0
            while True:
                assert selected["process_position"] is None
                members = [member for member in selected["members"] if member]
                assert len(members) == 1 and members[0]["pid"] == pid
                member = members[0]
                total += member["matches"]
                pages += 1
                assert member["matches"] <= 8 and pages <= 3
                if member["next"] is None: break
                selected = request(path + f"?pid={pid}&association_after={member['next']}&position={member['association_position']}")
            assert total == 10 and pages == 2
            assert "hidden-participation" not in json.dumps(group)
            admin("revoke-inspector-resource")
            request(path, status=403)
            admin("restore-inspector-resource")
            assert request(path)["resource"]["id"] == resource
            for suffix in ("?after=0", "?pid=0", "?association_after=1", "?after=1&pid=1", "?pid=1&pid=1"):
                request(path + suffix, status=400)
            request("/api/v1/resources/participation", status=400)
            assert api({"status": "9007199254740991"})["status"] is None
            api({"status": "not-an-id"}, status=400)
            description = api({"describe": {}})["description"]
            table = description["source"]["source"]["source"]["table"]
            assert table["row_type"] == {"structure": [
                {"name": "id", "type": {"int64": {}}, "nullable": False, "optional": False},
                {"name": "value", "type": {"int64": {}}, "nullable": True, "optional": False},
            ]}, table
            sql_caps = api({"sql_capabilities": {}})["sql_capabilities"]
            assert sql_caps["version"] == 1 and sql_caps["parameters"] and sql_caps["statement_bytes"] == 4096
            before = admin("next-sequence").stdout
            api({"compile": {"sql": "DELETE FROM items"}}, status=400)
            assert admin("next-sequence").stdout == before, "invalid SQL admitted a command"
            api({"describe": {}}, headers={"Origin": "https://untrusted.example"}, status=403)
            api({"describe": {}}, headers={"Content-Type": "text/plain"}, status=400)
            # Only typed finite query commands cross this optional route.
            invalid = {"version": 1, "signed": {"request": {"version": 1, "realm": 45, "principal": 1234, "sequence": 99, "command": {"checkpoint": {}}}, "signature": [0] * 64}}
            api({"submit": {"token": json.dumps(invalid)}}, status=400)
            compiled = api({"compile": {"sql": "SELECT value FROM items WHERE value = 9007199254740994 LIMIT 1"}})["compiled"]
            parameter_request = {"sql": "SELECT value FROM items WHERE value = $1 LIMIT $2",
                                 "parameters": [{"signed": "9007199254740994"}, {"unsigned": "1"}]}
            before = admin("next-sequence").stdout
            capacity.arm('/v1/query', 'read_entries', 2)
            parameterized = api({"compile": parameter_request}, retry=False)["compiled"]
            capacity.finish()
            assert parameterized == compiled, 'parameter binding changed the canonical query'
            assert admin("next-sequence").stdout == before, 'compilation recovery allocated a command sequence'
            before = admin("next-sequence").stdout
            for parameters in ([], [{"utf8": "wrong"}, {"unsigned": "1"}]):
                failure = api({"compile": parameter_request | {"parameters": parameters}}, status=400)
                assert failure['err'] == 'UnsupportedQuery'
                assert failure['diagnostic']['category'] == 'binding'
                assert failure['diagnostic']['outcome'] == 'not_submitted'
                assert failure['diagnostic']['evidence'] == 'local_before_dispatch'
                assert all(a is None or a['kind'] != 'resume_exact' for a in failure['diagnostic']['actions'])
            failure = api({"compile": {"sql": "SELECT value FROM items LIMIT $0", "parameters": []}}, status=400)
            assert failure['err'] == 'UnsupportedQuery' and failure['diagnostic']['code'] == 'sql.invalid_parameter_index'
            failure = api({"compile": {"sql": "SELECT value FROM items LIMIT $1"}}, status=400, retry=False)
            assert failure['err'] == 'UnsupportedQuery' and failure['diagnostic']['code'] == 'sql.unbound_parameters'
            assert failure['diagnostic']['outcome'] == 'not_submitted'
            invalid_cursor = api({"assist": {"sql": "SELECT value FROM items", "cursor": 1000, "generation": 1}}, status=400, retry=False)
            assert invalid_cursor['diagnostic']['code'] == 'query.invalid_sql_cursor'
            assert admin("next-sequence").stdout == before, 'parameter compilation allocated a command sequence'
            compiled = parameterized
            assert "9007199254740994" in json.dumps(compiled["plan"])
            prepared = api({"next": {"namespace": "1", "bundle": compiled["bundle"]}})["prepared"]
            malformed = json.loads(prepared["token"])
            malformed["signed"]["request"]["command"]["send"]["value"] = "00"
            api({"submit": {"token": json.dumps(malformed, separators=(",", ":"))}}, status=400)
            def settle(prepared, deadline=None):
                until = min(time.monotonic() + 60, deadline) if deadline is not None else time.monotonic() + 60
                receipt = api({"submit": prepared}, deadline=until)["receipt"]
                assert api({"submit": prepared}, deadline=until)["receipt"] == receipt
                while True:
                    response = api({"observe": receipt["position"]}, deadline=until)
                    # An unavailable receipt read says nothing new about the
                    # frozen submission. Observe the same receipt again without
                    # preparing or submitting another mutation.
                    if response.get("err") != "Unavailable":
                        observed = response["observation"]
                        if "pending" not in observed:
                            break
                    assert time.monotonic() < until
                    time.sleep(0.05)
                assert "committed" in observed, observed
                return receipt
            def upload(namespace, bundle):
                until = time.monotonic() + 120
                while True:
                    prepared = api({"next": {"namespace": namespace, "bundle": bundle}}, deadline=until)["prepared"]
                    if prepared is None: return
                    settle(prepared, deadline=until)
                    assert time.monotonic() < until
            initial_receipt = settle(prepared)
            upload("1", compiled["bundle"])
            deadline = time.monotonic() + 120
            while True:
                observation = api({"status": "1"}, deadline=deadline)["status"]
                if observation["phase"] == "complete": break
                assert time.monotonic() < deadline, observation
                assert all(process.poll() is None for process in processes)
                time.sleep(0.2)
            page = api({"page": {"namespace": "1"}})["page"]
            assert page["cells"] == [[{"value": {"atom": {"signed": "9007199254740994"}}}]]
            assert page["evidence"]["manifest"]["rows"] == "1" and page["evidence"]["next"] is None
            assert page["evidence"]["manifest"]["basis"]["contract"] == compiled["contract"]
            # One Board HTTP request must recover the classified read refusal.
            # The fixture's outer observation retry is disabled for each control.
            print('Board query capacity: recovering two native refusals in one page request', flush=True)
            capacity.arm('/v1/query', 'resource', 2)
            recovered = api({"page": {"namespace": "1"}}, retry=False)["page"]
            capacity.finish()
            assert recovered == page
            capacity.arm('/v1/query', 'resource', 4)
            api({"page": {"namespace": "1"}}, status=503, retry=False)
            capacity.finish(attempts=4)
            for code, native_status, board_status in [('Forbidden', 403, 403), ('AuthorityUnavailable', 503, 503)]:
                capacity.arm('/v1/query', 'resource', 1, code, native_status)
                api({"page": {"namespace": "1"}}, status=board_status, retry=False)
                capacity.finish(attempts=1)
            # A signed submission never enters the adapter's read retry. Its
            # explicit exact recovery still returns the original accepted receipt.
            capacity.arm('/v1/command', 'send', 1)
            api({"submit": prepared}, status=503, retry=False)
            capacity.finish(attempts=1)
            assert api({"submit": prepared})["receipt"] == initial_receipt
            print('Board query capacity: bounded native read recovery, exhaustion, denial, unknown failure and explicit exact submission recovery passed', flush=True)
            # Validate actual public responses using the generated JS boundary.
            values = {"description": description, "compiled": compiled, "prepared": prepared, "page": page}
            wire_fixture = Path(".cache/verification/native-v1-query-wire.json")
            wire_fixture.parent.mkdir(parents=True, exist_ok=True)
            wire_fixture.write_text(json.dumps(values))
            subprocess.run(["node", "tests/board_query_client.mjs"], input=json.dumps(values).encode(), check=True, timeout=15)
            admin("revoke")
            api({"compile": {"sql": "SELECT * FROM items"}}, status=403)
            api({"compile": parameter_request}, status=403)
            api({"page": {"namespace": "1"}}, status=403)
            admin("restore")
            # A paused source cannot expose an incomplete result. Cancellation is
            # a separate frozen command with its own exact retry identity.
            workers["source"].send_signal(signal.SIGSTOP)
            pending = api({"compile": {"sql": "SELECT * FROM items"}})["compiled"]
            upload("2", pending["bundle"])
            assert api({"status": "2"})["status"]["phase"] == "admitted"
            api({"page": {"namespace": "2"}}, status=409)
            cancellation = api({"prepare_control": {"namespace": "2", "operation": "cancel"}})["prepared"]
            malformed = json.loads(cancellation["token"])
            malformed["signed"]["request"]["command"]["send"]["value"] = "00"
            api({"submit": {"token": json.dumps(malformed, separators=(",", ":"))}}, status=400)
            settle(cancellation)
            assert api({"status": "2"})["status"]["phase"] == "cancelled"
            workers["source"].send_signal(signal.SIGCONT)
            admin("expand-inspector")
            request("/api/v1/capabilities", status=403)
            request(f"/api/v1/atlas?position={atlas['position']}", status=403)
            admin("restore-inspector")
            request(f"/api/v1/atlas?position={atlas['position']}", status=409)
            current_atlas()
            # An inspection-only growing instance must not acquire query access.
            readonly_port = free_port()
            readonly_origin = f"http://127.0.0.1:{readonly_port}"
            readonly = options | {"public_origin": readonly_origin, "port": readonly_port}
            readonly.pop("query")
            readonly_config = fixture.root / "readonly-board.json"
            readonly_config.write_text(json.dumps(readonly))
            readonly_process = start("readonly-board", [board, str(readonly_config)])
            wait_ready(fixture.http, readonly_process, readonly_origin + "/health")
            req = urllib.request.Request(readonly_origin + "/api/v1/query", b'{"describe":{}}', {"Origin": readonly_origin, "Content-Type": "application/json"})
            try: fixture.http.open(req, timeout=10); raise AssertionError("query enabled by default")
            except urllib.error.HTTPError as err:
                assert err.code == 404 and json.loads(err.read())["err"] == "QueryDisabled"
            if browser:
                assert faults.verified == {"next", "submit"} and not faults.errors
                env = os.environ | {"BOARD_TEST_URL": origin, "BOARD_QUERY_PROOF": proof, "BOARD_QUERY_AUTHORITY": url, "BOARD_QUERY_CONFIG": str(fixture.root / "cli.json"), "BOARD_QUERY_RESOURCE": str(caller["connection"]["resource"]), "BOARD_QUERY_SCREENSHOT": str(Path(".cache/verification/m13-board.png").resolve())}
                subprocess.run(["vp", "exec", "--filter", "@transit/board-web", "playwright", "test", "query.spec.ts"], env=env, check=True, timeout=240)
            else:
                admin("retire-source")
            api({"page": {"namespace": "1"}}, status=410)
            assert faults.verified == {"next", "submit"} and not faults.errors
            print("Board query recovery: identical preparation and accepted signed submission survived injected unavailable replies.")
            print("Board query: separate identity, SQL/frozen retry, exact typed page, malformed ingress, current grant/cut enforcement" + (", real Canvas/Browse and revocation" if browser else "") + " passed")
        except BaseException:
            for log in logs:
                log.flush(); log.seek(0); sys.stderr.write(log.read()[-2500:])
            raise
        finally:
            try:
                if faults is not None: faults.close()
                if capacity is not None: capacity.close()
            finally:
                for process in reversed(processes):
                    if process.poll() is None: process.kill()
                    process.wait(timeout=10)
                for log in logs: log.close()


if __name__ == "__main__":
    run(*sys.argv[1:5], browser="--browser" in sys.argv)

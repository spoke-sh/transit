"""Actual finite worker and disk Ursula: dropped receipts and killed executors."""
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import ssl
import struct
import subprocess
import sys
import threading
import time

from harness.ursula import Fixture
from harness.services import free_port, wait_ready
from cold_storage import ColdStore


def run(node, provision, worker, library, board=None, browser=False):
    started = time.monotonic()
    node, provision, worker, library = map(lambda value: str(Path(value).resolve()), (node, provision, worker, library))
    if board is not None: board = str(Path(board).resolve())
    payload = bytes((i * 29 + 5) % 256 for i in range(1027))
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        public = json.loads(subprocess.check_output([provision, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        node_config = fixture.root / "node.json"
        node_config.write_text(json.dumps({"profile": "native_v1", "genesis": {"realm": 47, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "http-worker", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        requests = []
        applied = set()
        cancelled = set()
        blocked = threading.Event()
        release = threading.Event()
        prepared_prefix = threading.Event()
        release_preparation = threading.Event()
        capture_prefix = threading.Event()
        release_capture = threading.Event()
        capture_kill_armed = False
        observation_kill_armed = False
        terminal_commit = threading.Event()
        release_terminal = threading.Event()
        dropped = {}
        recovered = set()
        failures = []
        failure_admitted = threading.Event()
        release_failure = threading.Event()
        failure_inputs = []
        failure_kill_armed = False
        signal_names = set()

        class Peer(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            def log_message(self, *_): pass
            def do_POST(self):
                assert self.rfile.read(int(self.headers["Content-Length"])) == b"body"
                assert self.headers["Authorization"] == "Bearer fixture-request-secret"
                requests.append(self.path)
                key = self.headers["Idempotency-Key"]
                assert key == {"/redirected": "/redirect", "/public-redirected": "/public-redirect"}.get(self.path, self.path)
                if self.path in ("/redirect", "/public-redirect"):
                    self.send_response(307)
                    self.send_header("Location", self.path + "ed")
                    self.send_header("Content-Length", "0")
                    self.end_headers()
                    return
                first_application = key not in applied
                applied.add(key)
                if self.path == "/failure-send":
                    self.close_connection = True
                    return
                if self.path in ("/kill", "/public-kill", "/public-retry") and first_application:
                    blocked.set()
                    release.wait(timeout=30)
                try:
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(payload)))
                    self.send_header("Set-Cookie", "fixture-secret")
                    self.end_headers()
                    self.wfile.write(payload)
                except (BrokenPipeError, ConnectionResetError): pass
            def do_GET(self):
                assert self.path == "/status/kill"
                key = self.headers["Idempotency-Key"]
                assert key in ("/kill", "/public-retry")
                assert self.headers["Authorization"] == "Bearer fixture-request-secret"
                assert int(self.headers["Content-Length"]) == 0
                requests.append(self.path)
                result = b"applied" if key in applied else b"unknown"
                self.send_response(200)
                self.send_header("Content-Length", str(len(result)))
                self.end_headers()
                self.wfile.write(result)
            def do_DELETE(self):
                assert self.path == "/operations/kill"
                key = self.headers["Idempotency-Key"]
                assert key in ("/kill", "/public-retry")
                assert self.headers["Authorization"] == "Bearer fixture-request-secret"
                assert int(self.headers["Content-Length"]) == 0
                requests.append(self.path)
                cancelled.add(key)
                self.send_response(204)
                self.end_headers()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v1/command" and response.status == 200:
                        request = json.loads(body)["request"]
                        command = request["command"]
                        selected = next((name for name in ("dispatch", "observe") if name in command), None)
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        for mutation in turn.get("mutations", []):
                            if mutation and mutation["value"]:
                                assert b"fixture-request-secret" not in bytes.fromhex(mutation["value"]), "Credential entered durable capture"
                        if any(m and m["value"] and bytes.fromhex(m["value"]).startswith(b"EXM1") for m in turn.get("mutations", [])):
                            selected = "seal"
                        if any(o and b"HTK1" in bytes.fromhex(o["value"]) for o in turn.get("outputs", [])):
                            selected = "caller_release"
                        if any(m and m["value"] and bytes.fromhex(m["value"]).startswith(b"EXL1") for m in turn.get("mutations", [])):
                            selected = "caller_followup"
                        if request["principal"] == 65536:
                            sent = bytes.fromhex(command.get("send", {}).get("value", ""))
                            if failure_kill_armed and sent[13:17] == b"EXF1" and not failure_admitted.is_set():
                                failure_inputs.append((sent[13:], json.loads(data)["position"]))
                                failure_admitted.set()
                                release_failure.wait(timeout=60)
                            if observation_kill_armed and "observe" in command and not terminal_commit.is_set():
                                terminal_commit.set()
                                release_terminal.wait(timeout=30)
                            if capture_kill_armed and not capture_prefix.is_set() and any(m and m["value"] and bytes.fromhex(m["value"]) == payload[:256] for m in turn.get("mutations", [])):
                                capture_prefix.set()
                                release_capture.wait(timeout=30)
                            if not prepared_prefix.is_set() and any(m and m["value"] and bytes.fromhex(m["value"]).startswith(b'{"version":1,"endpoint_revision":') for m in turn.get("mutations", [])):
                                prepared_prefix.set()
                                release_preparation.wait(timeout=30)
                            for name, (frozen, receipt) in dropped.items():
                                if body == frozen:
                                    assert data == receipt
                                    recovered.add(name)
                            if selected and selected not in dropped:
                                dropped[selected] = (body, data)
                                data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally: connection.close()

        peer = ThreadingHTTPServer(("127.0.0.1", 0), Peer)
        tls_key, tls_cert = fixture.root / "peer.key", fixture.root / "peer.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(tls_key), "-out", str(tls_cert), "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        tls_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        tls_context.load_cert_chain(tls_cert, tls_key)
        peer.socket = tls_context.wrap_socket(peer.socket, server_side=True)
        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        threads = [threading.Thread(target=server.serve_forever, daemon=True) for server in (peer, proxy)]
        for thread in threads: thread.start()
        proxy_url = f"http://127.0.0.1:{proxy.server_port}"
        state = fixture.root / "saved.json"
        config = fixture.root / "worker.json"
        seed = fixture.root / "worker.seed"
        seed.write_text("48" * 32)
        body_file = fixture.root / "request.body"
        body_file.write_bytes(b"body")
        credential = fixture.root / "api.credential"
        credential.write_text("fixture-request-secret")
        log = (fixture.root / "node.log").open("w+")
        authority = child = None
        try:
            subprocess.run([node, str(node_config), "--initialize"], check=True, stdout=log, stderr=subprocess.STDOUT, timeout=30)
            def start_node():
                process = subprocess.Popen([node, str(node_config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(fixture.http, process, url + "/health")
                return process
            authority = start_node()
            def admin(operation):
                extra = [str(config)] if operation in ("call", "publish-followup") else []
                return json.loads(subprocess.check_output([provision, url, operation, str(state), *extra], timeout=60))
            def configure(saved, path, mode, *, reconciliation_ms=240000):
                configuration = {"url": proxy_url, "realm": 47, "principal": 65536, "seed_file": str(seed), "pid": saved["pid"], "generation": saved["generation"], "activation_directory": str(fixture.root), "exchange": 1, "endpoint_revision": 1, "endpoint": {"host": "localhost", "address": "127.0.0.1", "port": peer.server_port, "tls": True, "ca_file": str(tls_cert), "timeout_ms": 120000}, "mode": mode, "request": {"method": "POST", "target": [{"literal": path}], "body_bytes": 4, "headers": [{"name": "Authorization", "value": [{"literal": "Bearer "}, {"secret": {"binding": "api", "version": 7}}]}]}, "credentials": [{"binding": "api", "version": 7, "header": "Authorization", "file": str(credential)}], "body_file": str(body_file), "reconcile_before_ms": int(time.time() * 1000) + reconciliation_ms}
                configuration.update(max_attempts=4, retry_policy={"id": 77, "revision": 1, "key_header": "Idempotency-Key"}, redirect_policy={"id": 78, "revision": 1}, reconcile_policy={"id": 79, "revision": 1, "method": "GET", "target": "/status/kill"}, cancel_policy={"id": 80, "revision": 1, "method": "DELETE", "target": "/operations/kill"})
                configuration["endpoint"]["response_headers"] = ["content-type", "content-length", "transfer-encoding", "trailer", "location"]
                configuration["request"]["headers"].append({"name": "Idempotency-Key", "value": [{"literal": path}]})
                config.write_text(json.dumps(configuration))
            def admission(saved, path, mode):
                configure(saved, path, mode)
                configuration = json.loads(config.read_text())
                configuration["admission"] = {"caller": saved["caller"]["pid"], "resource": saved["caller"]["resource"], "scope": {"method": "POST", "target": path, "headers": ["authorization", "idempotency-key"]}}
                configuration["reconcile_before_ms"] = saved["caller"]["deadline"]
                # These bytes must come from the authorized caller publication.
                configuration.pop("request")
                configuration.pop("body_file")
                config.write_text(json.dumps(configuration))
            def followup(saved, exchange, mode, reason="retry", path="/kill"):
                configure(saved, path, mode)
                configuration = json.loads(config.read_text())
                configuration.update(exchange=exchange, followup={"parent": 1, "reason": reason})
                if reason in ("reconcile", "cancel"):
                    action = configuration[reason + "_policy"]
                    configuration["request"].update(method=action["method"], target=[{"literal": action["target"]}], body_bytes=0)
                    configuration["body_file"] = None
                if reason == "redirect":
                    configuration["request"]["target"] = [{"literal": path + "ed"}]
                config.write_text(json.dumps(configuration))
            def public_followup(saved, exchange, mode, reason, path):
                followup(saved, exchange, mode, reason, path)
                configuration = json.loads(config.read_text())
                request = configuration.pop("request")
                configuration.pop("body_file")
                configuration["reconcile_before_ms"] = saved["caller"]["deadline"]
                configuration["admission"] = {"caller": saved["caller"]["pid"], "resource": saved["caller"]["resource"], "scope": {"method": request["method"], "target": request["target"][0]["literal"], "headers": ["authorization", "idempotency-key"]}}
                config.write_text(json.dumps(configuration))
            def public_retry(saved, mode):
                admission(saved, "/public-retry", mode)
                configuration = json.loads(config.read_text())
                configuration.update(exchange=2, followup={"parent": 1, "reason": "retry"})
                config.write_text(json.dumps(configuration))
            def invoke(sink="drained"):
                environment = os.environ | {"LOG_FORMAT": "json", "LOG_LEVEL": "debug" if sink == "stalled" else "info"}
                with subprocess.Popen([worker, str(config)], env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE) as process:
                    if sink == "stalled":
                        import fcntl
                        fcntl.fcntl(process.stderr.fileno(), fcntl.F_SETPIPE_SZ, 4096)
                        # Deliberately leave a full diagnostic pipe unread. Public
                        # authority reads and bounded shutdown must still finish.
                        process.wait(timeout=45)
                        stdout, stderr = process.stdout.read(), process.stderr.read()
                    else:
                        stdout, stderr = process.communicate(timeout=120)
                    assert process.returncode == 0, stderr[-2000:]
                for forbidden in (b"fixture-request-secret", b"fixture-secret", b"/status/kill", b"/public", proxy_url.encode(), str(credential).encode()):
                    assert forbidden not in stderr, (forbidden, stderr[-2000:])
                records = []
                for line in stderr.splitlines(keepends=True):
                    if not line.endswith(b"\n"):
                        assert sink == "stalled", line
                        continue  # Cancellation can leave a partial final record.
                    record = json.loads(line)
                    assert len(line) <= 2048
                    assert record["service_name"] == "transit-station-http-worker"
                    records.append(record)
                    if "event" in record: signal_names.add(record["event"]["name"])
                # Individual diagnostics may be dropped even with a drained
                # sink. Check vocabulary over the complete finite schedule.
                invoke.records = records
                return json.loads(stdout)

            saved = admin("provision")
            configure(saved, "/complete", "prepare")
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert prepared_prefix.wait(timeout=60), "Durable request prefix not reached"
            child.kill(); child.wait(timeout=10); child = None
            release_preparation.set()
            assert requests == []
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            configure(saved, "/complete", "prepare")
            prepared = invoke()
            assert prepared["phase"] == "ready" and prepared["outcome"] == "pending"
            saved = admin("own")
            configure(saved, "/complete", "execute")
            changed = json.loads(config.read_text())
            changed["endpoint"]["address"] = "127.0.0.2"
            config.write_text(json.dumps(changed))
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=15)
            assert refused.returncode != 0 and b"HttpEndpointChanged" in refused.stderr, refused
            assert requests == [] and admin("inspect")["effect"] == "pending"
            for override in ({"response_bytes": 1}, {"response_headers": []}, {"host": "metadata.invalid"},
                             {"address": "169.254.169.254"}, {"port": 443}, {"tls": False}):
                saved = admin("own")
                configure(saved, "/complete", "execute")
                changed = json.loads(config.read_text())
                changed["endpoint"].update(override)
                config.write_text(json.dumps(changed))
                refused = subprocess.run([worker, str(config)], capture_output=True, timeout=15)
                assert refused.returncode != 0 and b"HttpEndpointChanged" in refused.stderr, refused
                assert requests == [] and admin("inspect")["effect"] == "pending"
            frozen_trust = tls_cert.read_bytes()
            tls_cert.write_bytes(frozen_trust + b"\n")
            saved = admin("own")
            configure(saved, "/complete", "execute")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=15)
            assert refused.returncode != 0 and b"HttpEndpointChanged" in refused.stderr, refused
            tls_cert.write_bytes(frozen_trust)
            assert requests == [] and admin("inspect")["effect"] == "pending"
            for override in ({"version": 8}, {"header": "X-Other"}):
                saved = admin("own")
                configure(saved, "/complete", "execute")
                changed = json.loads(config.read_text())
                changed["credentials"][0].update(override)
                config.write_text(json.dumps(changed))
                refused = subprocess.run([worker, str(config)], capture_output=True, timeout=15)
                assert refused.returncode != 0 and b"HttpCredentialNotGranted" in refused.stderr, refused
                assert requests == [] and admin("inspect")["effect"] == "pending"
            saved = admin("own")
            configure(saved, "/complete", "execute")
            completed = invoke()
            assert completed["phase"] == "complete" and completed["outcome"] == "observed"
            sent = [record for record in invoke.records if record.get('event', {}).get('name') == 'http.transport.completed']
            assert len(sent) <= 1
            for record in sent:
                assert record['event']['status'] == 200 and record['event']['outcome'] == 'ok'
                assert record['event']['position'] > 0 and record['parent_span_id']
            assert admin("inspect")["effect"] == "observed"
            repeated = subprocess.run([worker, str(config)], capture_output=True, timeout=15)
            assert repeated.returncode != 0 and b"PathAlreadyExists" in repeated.stderr, repeated
            assert requests == ["/complete"]
            # Stop the remote peer from influencing replay and recover disk authority.
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            credential.unlink()
            result = admin("replay")
            assert result == {"bytes": len(payload), "sha256": hashlib.sha256(payload).hexdigest()}, result
            assert requests == ["/complete"]
            saved = admin("own")
            configure(saved, "/complete", "execute")
            assert invoke(sink="stalled")["phase"] == "complete"
            assert all(record.get('event', {}).get('name') != 'http.transport.completed' for record in invoke.records), 'Recovery invented another network attempt'
            assert requests == ["/complete"]
            assert set(dropped) == recovered == {"seal", "dispatch", "observe"}, (dropped.keys(), recovered)

            # Explicit disposal closes availability before bounded reclamation.
            # Restart disk authority partway through cleanup and resume it.
            saved = admin("own")
            configure(saved, "/complete", "release")
            changed = json.loads(config.read_text())
            changed["cleanup_steps"] = 2
            config.write_text(json.dumps(changed))
            assert invoke()["phase"] == "retired"
            state_after_release = admin("inspect")
            assert state_after_release["collected"] < state_after_release["segments"]
            refused = subprocess.run([provision, url, "replay", str(state)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"ExchangeUnavailable" in refused.stderr, refused
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            configure(saved, "/complete", "release")
            assert invoke()["phase"] == "retired"
            state_after_release = admin("inspect")
            assert state_after_release["collected"] == state_after_release["segments"]
            assert requests == ["/complete"]

            credential.write_text("fixture-request-secret")
            saved = admin("provision")
            configure(saved, "/kill", "prepare")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            configure(saved, "/kill", "execute")
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert blocked.wait(timeout=60), "Remote application boundary not reached"
            child.kill(); child.wait(timeout=10); child = None
            release.set()
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            configure(saved, "/kill", "execute")
            unknown = invoke()
            assert unknown["phase"] == "unknown" and unknown["outcome"] == "closed_unknown"
            assert admin("inspect")["effect"] == "closed_unknown"
            assert requests == ["/complete", "/kill"], requests

            # An explicit policy-authorized retry gets another effect identity;
            # it cannot change the request or replenish the original budget.
            saved = admin("own")
            followup(saved, 2, "prepare")
            body_file.write_bytes(b"evil")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"HttpRetryChanged" in refused.stderr, refused
            body_file.write_bytes(b"body")
            saved = admin("own")
            followup(saved, 2, "prepare")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            followup(saved, 2, "execute")
            assert invoke()["phase"] == "complete"
            assert requests == ["/complete", "/kill", "/kill"], requests
            assert applied == {"/complete", "/kill"}
            for exchange, reason in ((3, "reconcile"), (4, "cancel")):
                saved = admin("own")
                followup(saved, exchange, "prepare", reason)
                assert invoke()["phase"] == "ready"
                saved = admin("own")
                followup(saved, exchange, "execute", reason)
                assert invoke()["phase"] == "complete"
                # Independent followup evidence never rewrites the original
                # unknown effect or pretends to undo its remote application.
                assert admin("inspect")["effect"] == "closed_unknown"
            assert cancelled == {"/kill"} and applied == {"/complete", "/kill"}
            saved = admin("own")
            followup(saved, 5, "prepare")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"ExchangeAttemptBudgetExceeded" in refused.stderr, refused
            assert requests == ["/complete", "/kill", "/kill", "/status/kill", "/operations/kill"], requests

            saved = admin("provision")
            configure(saved, "/redirect", "prepare")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            configure(saved, "/redirect", "execute")
            assert invoke()["phase"] == "complete"
            assert requests[-1] == "/redirect" and "/redirected" not in requests
            saved = admin("own")
            followup(saved, 2, "prepare", "redirect", "/redirect")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            followup(saved, 2, "execute", "redirect", "/redirect")
            assert invoke()["phase"] == "complete"
            assert requests[-2:] == ["/redirect", "/redirected"]
            assert applied == {"/complete", "/kill", "/redirect"}

            # A distinct caller publishes immutable inputs and sends a correlated
            # process-origin call. Losing its read grant must prevent preparation.
            saved = admin("provision-public")
            configure(saved, "/public", "accept")
            saved = admin("call")
            admin("revoke-request")
            admission(saved, "/public", "accept")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"AccessDenied" in refused.stderr, refused
            admin("restore-request")
            saved = admin("own")
            admission(saved, "/public", "accept")
            assert invoke()["phase"] == "ready"
            # Recheck current request scope immediately before dispatch.
            saved = admin("own")
            admission(saved, "/admin", "execute")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"HttpRequestNotGranted" in refused.stderr, refused
            saved = admin("own")
            admission(saved, "/public", "execute")
            observation_kill_armed = True
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert terminal_commit.wait(timeout=90), "Kernel outcome was not committed"
            child.kill(); child.wait(timeout=10); child = None
            release_terminal.set()
            release_failure.set()
            assert admin("inspect")["effect"] == "observed"
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            admission(saved, "/public", "execute")
            assert invoke()["phase"] == "complete"
            # The correlated output has committed, but delivery has not run.
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            received = admin("receive")
            result = received["outcome"]
            assert result["phase"] == "observed" and result["status"] == 200
            assert result["effect"] > 0 and result["attempt"] > 0
            assert requests[-1] == "/public" and requests.count("/public") == 1

            if board is not None:
                from http_board import inspect_capture
                inspect_capture(fixture, admin, url, saved, board, provision, state, browser)

            from station_growing_abi import Native
            from abi_support import rejects
            libraries = fixture.root / "libraries"
            libraries.mkdir()
            (libraries / "libtransit_station.so").symlink_to(library)
            caller_seed = fixture.root / "caller.seed"
            caller_seed.write_text("49" * 32)
            reader = Native(libraries, url, caller_seed, {"profile": "native_v1", "realm": 47, "principal": 65537, "pid": saved["caller"]["pid"], "generation": 3, "association": "state", "failure_policy": "stop"})
            try:
                def native_read(action):
                    data = json.dumps(action).encode()
                    return reader.api.call("station_growing_http_read", reader.pointer, data, len(data))
                data = json.dumps({"outcome": received["wire"]}).encode()
                converted = reader.api.call("station_http_codec", data, len(data))["outcome"]
                reference = converted["reference"]
                evidence_read = {"diagnostic": {"identity": {"resource": converted["resource"], "exchange": converted["exchange"]}, "kind": "capture_failure"}}
                assert native_read(evidence_read) == {"diagnostic": None}
                # Capture grants do not confer inspection of the service PID.
                effect_read = {"diagnostic": {**evidence_read["diagnostic"], "kind": "native_effect"}}
                rejects(4, native_read, effect_read)
                identity = native_read({"open": {"reference": reference}})["opened"]
                rejects(9, native_read, {"open": {"reference": reference}})
                first = native_read({"next": identity})["part"]
                assert first["bytes"] and not first["complete"]
                admin("revoke-capture")
                rejects(4, native_read, evidence_read)
                rejects(4, native_read, effect_read)
                rejects(4, native_read, {"next": identity})
                admin("restore-capture")
                failed = rejects(7, native_read, {"next": identity})
                assert failed["err"] == "HttpReplayFailed" and failed["protocol_error"] is None
                assert native_read({"close": identity}) == {"closed": True}
                rejects(13, native_read, {"next": identity})
                credential.unlink()
                reopened = native_read({"open": {"reference": reference}})["opened"]
                assert reopened > identity
                owned_body = bytearray()
                complete = False
                while (part := native_read({"next": reopened})["part"]) is not None:
                    if part["kind"] == "response_body": owned_body.extend(bytes.fromhex(part["bytes"]))
                    complete = part["complete"]
                assert complete and bytes(owned_body) == payload
                native_read({"close": reopened})
            finally:
                reader.close()
                credential.write_text("fixture-request-secret")
            assert bytes(owned_body) == payload and requests.count("/public") == 1

            # Public durable disposal is separate from local reader destruction.
            # Lose its accepted receipt, restart node/store, then repeat the call.
            credential.unlink()
            saved = admin("release-call")
            saved = admin("own")
            admission(saved, "/public", "poll")
            assert invoke()["phase"] == "complete"
            disposed = admin("receive-release")
            assert disposed == {"resource": saved["resource"], "exchange": 1}
            assert "caller_release" in recovered
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("release-call")
            saved = admin("own")
            admission(saved, "/public", "poll")
            assert invoke()["phase"] == "complete"
            assert admin("receive-release") == disposed
            # Only the separately explicit retirement removes replay availability.
            reader = Native(libraries, url, caller_seed, {"profile": "native_v1", "realm": 47, "principal": 65537, "pid": saved["caller"]["pid"], "generation": 3, "association": "state", "failure_policy": "stop"})
            try:
                held = native_read({"open": {"reference": reference}})["opened"]
                assert native_read({"next": held})["part"]["bytes"]
                saved = admin("own")
                admission(saved, "/public", "release")
                assert invoke()["phase"] == "retired"
                failed = rejects(7, native_read, {"next": held})
                assert failed["err"] == "ExchangeUnavailable", failed
            finally:
                reader.close()
            # A lost application acknowledgement can be recovered even after GC.
            saved = admin("release-call")
            saved = admin("own")
            admission(saved, "/public", "poll")
            assert invoke()["phase"] == "retired"
            assert admin("receive-release") == disposed
            assert requests.count("/public") == 1
            credential.write_text("fixture-request-secret")

            # The original caller explicitly retries through its own durable
            # call. Admission validates the frozen policy before spending a slot.
            saved = admin("provision-public")
            # This composite schedule includes rejected attempts, two cold
            # restarts, retry, status and cancellation. Give it a finite budget
            # up front; later activations must never renew accepted deadlines.
            configure(saved, "/public-retry", "accept", reconciliation_ms=15 * 60 * 1000)
            saved = admin("call")
            original_deadline = saved["caller"]["deadline"]
            root_correlation = saved["caller"]["correlation"]
            admission(saved, "/public-retry", "accept")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            admission(saved, "/public-retry", "execute")
            blocked.clear(); release.clear()
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert blocked.wait(timeout=60), "Retry root never reached remote application"
            child.kill(); child.wait(timeout=10); child = None
            release.set()
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            admission(saved, "/public-retry", "execute")
            assert invoke()["outcome"] == "closed_unknown"
            root_outcome = admin("receive")["outcome"]
            assert root_outcome["phase"] == "closed_unknown"

            saved = admin("followup-call")
            saved = admin("own")
            public_retry(saved, "accept")
            changed = json.loads(config.read_text())
            changed["admission"]["scope"]["target"] = "/admin"
            config.write_text(json.dumps(changed))
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"MissingHttpCall" in refused.stderr, refused
            rejection = admin("receive-rejection")
            assert rejection["record"]["reason"] == "denied", rejection
            facts = {item["field"]: item["value"] for item in rejection["diagnostic"]["facts"] if item}
            assert facts["field_path"] == {"text": "request.target"}, rejection
            assert facts["expected_value"] == {"text": "/admin"}, rejection
            assert facts["supplied_value"] == {"text": "/public-retry"}, rejection
            assert rejection["diagnostic"]["outcome"] == "input_rejected", rejection
            assert requests.count("/public-retry") == 1

            saved = admin("followup-call")
            saved = admin("own")
            public_retry(saved, "accept")
            changed = json.loads(config.read_text())
            changed["retry_policy"]["revision"] += 1
            config.write_text(json.dumps(changed))
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"MissingHttpCall" in refused.stderr, refused
            rejection = admin("receive-rejection")
            assert rejection["record"]["reason"] == "denied", rejection
            facts = {item["field"]: item["value"] for item in rejection["diagnostic"]["facts"] if item}
            assert facts["field_path"] == {"text": "policy.retry_policy.revision"}, rejection
            assert facts["expected_value"] == {"unsigned": "1"}, rejection
            assert facts["supplied_value"] == {"unsigned": "2"}, rejection
            assert rejection["diagnostic"]["cause"] == "HttpFollowupChanged", rejection
            assert rejection["diagnostic"]["outcome"] == "input_rejected", rejection
            assert requests.count("/public-retry") == 1

            saved = admin("followup-call")
            followup_correlation = saved["caller"]["correlation"]
            assert followup_correlation != root_correlation
            saved = admin("own")
            public_retry(saved, "accept")
            admin("revoke-request")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"AccessDenied" in refused.stderr, refused
            admin("restore-request")
            saved = admin("own")
            public_retry(saved, "accept")
            assert invoke()["phase"] == "ready"
            assert "caller_followup" in recovered
            assert requests.count("/public-retry") == 1
            # Explicit caller disposal cannot remove evidence still needed by
            # an admitted child, even after the node and store lose their caches.
            saved = admin("own")
            admission(saved, "/public-retry", "release")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"ExchangeHasDependents" in refused.stderr, refused
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            admission(saved, "/public-retry", "release")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"ExchangeHasDependents" in refused.stderr, refused
            # Another fresh activation resumes the admitted child without a
            # second allocation, refreshed deadline or implicit send.
            saved = admin("own")
            public_retry(saved, "accept")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            public_retry(saved, "execute")
            assert invoke()["phase"] == "complete"
            result = admin("receive")["outcome"]
            assert result["phase"] == "observed" and result["exchange"] == 2
            assert result["effect"] != root_outcome["effect"]
            assert result["attempt"] != root_outcome["attempt"]
            assert saved["caller"]["correlation"] == followup_correlation
            assert admin("inspect")["effect"] == "closed_unknown"
            assert requests.count("/public-retry") == 2
            assert "/public-retry" in applied

            # Status and cancellation publish distinct empty-body requests. Each
            # caller-selected action gets its own correlation/effect and keeps
            # the original root closed unknown, even after a successful retry.
            correlations = {root_correlation, followup_correlation}
            effects = {root_outcome["effect"], result["effect"]}
            for exchange, reason in ((3, "reconcile"), (4, "cancel")):
                followup(saved, exchange, "accept", reason, "/public-retry")
                saved = admin("publish-followup")
                assert saved["caller"]["deadline"] == original_deadline, "Follow-up renewed the original deadline"
                assert saved["caller"]["correlation"] not in correlations
                correlations.add(saved["caller"]["correlation"])
                saved = admin("own")
                public_followup(saved, exchange, "accept", reason, "/public-retry")
                assert invoke()["phase"] == "ready"
                saved = admin("own")
                public_followup(saved, exchange, "execute", reason, "/public-retry")
                assert invoke()["phase"] == "complete"
                result = admin("receive")["outcome"]
                assert result["phase"] == "observed" and result["exchange"] == exchange
                assert result["status"] == (200 if reason == "reconcile" else 204)
                assert result["effect"] not in effects
                effects.add(result["effect"])
                assert admin("inspect")["effect"] == "closed_unknown"
            assert cancelled == {"/kill", "/public-retry"}
            saved = admin("own")
            admission(saved, "/public-retry", "release")
            assert invoke()["phase"] == "retired"

            # An observed redirect requires a newly published target and an
            # explicit caller call; the first response alone never follows it.
            saved = admin("provision-public")
            configure(saved, "/public-redirect", "accept")
            saved = admin("call")
            admission(saved, "/public-redirect", "accept")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            admission(saved, "/public-redirect", "execute")
            assert invoke()["phase"] == "complete"
            root_outcome = admin("receive")["outcome"]
            assert root_outcome["status"] == 307 and "/public-redirected" not in requests
            followup(saved, 2, "accept", "redirect", "/public-redirect")
            saved = admin("publish-followup")
            saved = admin("own")
            public_followup(saved, 2, "accept", "redirect", "/public-redirect")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            public_followup(saved, 2, "execute", "redirect", "/public-redirect")
            assert invoke()["phase"] == "complete"
            result = admin("receive")["outcome"]
            assert result["phase"] == "observed" and result["status"] == 200 and result["exchange"] == 2
            assert result["effect"] != root_outcome["effect"]
            assert requests[-2:] == ["/public-redirect", "/public-redirected"]
            assert admin("inspect")["effect"] == "observed"

            # Reconciliation belongs to the surviving connector PID. The caller
            # can terminate after application; its replacement receives nothing.
            saved = admin("provision-public")
            configure(saved, "/public-kill", "accept")
            saved = admin("call")
            saved = admin("name-caller")
            admission(saved, "/public-kill", "accept")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            admission(saved, "/public-kill", "execute")
            blocked.clear(); release.clear()
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert blocked.wait(timeout=60), "Public call never reached remote application"
            child.kill(); child.wait(timeout=10); child = None
            release.set()
            saved = admin("terminate-caller")
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("check-caller-name")
            saved = admin("own")
            admission(saved, "/public-kill", "execute")
            unknown = invoke()
            assert unknown["phase"] == "unknown" and unknown["outcome"] == "closed_unknown"
            result = admin("receive")["outcome"]
            assert result["phase"] == "closed_unknown" and result["attempt"] > 0
            assert requests.count("/public-kill") == 1

            # Kill after the first response chunk commits but before its receipt
            # returns. A durable body prefix is not a complete response, even
            # though the independent peer already completed its application.
            saved = admin("provision")
            configure(saved, "/capture-kill", "prepare")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            configure(saved, "/capture-kill", "execute")
            capture_kill_armed = True
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert capture_prefix.wait(timeout=60), "Durable response prefix was not reached"
            child.kill(); child.wait(timeout=10); child = None
            release_capture.set()
            assert admin("inspect")["phase"] == "capturing"
            refused = subprocess.run([provision, url, "replay", str(state)], capture_output=True, timeout=30)
            assert refused.returncode and b"IncompleteExchange" in refused.stderr, refused
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            configure(saved, "/capture-kill", "execute")
            unknown = invoke()
            assert unknown["phase"] == "unknown" and unknown["outcome"] == "closed_unknown"
            assert requests.count("/capture-kill") == 1
            saved = admin("own")
            configure(saved, "/capture-kill", "release")
            assert invoke()["phase"] == "retired"
            reclaimed = admin("inspect")
            assert reclaimed["collected"] == reclaimed["segments"] + 1, reclaimed
            assert not failures, failures
            assert {'http.worker.operation', 'http.transport.completed', 'service.ready'} <= signal_names
            assert len(requests) == 16 and len(applied) == 8
            # The remote application closes before responding. Admit the immutable
            # failure input but lose its receipt and the entire worker activation.
            # Replacement must retain that exact cause and must never redial.
            saved = admin("provision")
            configure(saved, "/failure-send", "prepare")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            configure(saved, "/failure-send", "execute")
            failure_kill_armed = True
            child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE)
            assert failure_admitted.wait(timeout=60), "Failure input was never admitted"
            child.kill(); child.wait(timeout=10); child = None
            release_failure.set()
            assert admin("inspect")["phase"] == "capturing"
            authority.kill(); authority.wait(timeout=10); authority = None
            fixture.stop(); fixture.start()
            authority = start_node()
            saved = admin("own")
            configure(saved, "/failure-send", "execute")
            unknown = invoke()
            assert unknown["phase"] == "unknown" and unknown["outcome"] == "closed_unknown"
            failure_bytes, failure_input = failure_inputs[0]
            # Independent fixed-layout decode of the admitted payload.
            witness = struct.unpack("<4s5QBBQ4IBB96sBQQIQ", failure_bytes)
            assert witness[0] == b"EXF1" and witness[6] == 4  # transport_failure
            original_cause = witness[15][:witness[13]].decode()
            diagnostic = unknown["capture_diagnostic"]
            assert diagnostic["code"] == "exchange.transport_failed", diagnostic
            assert diagnostic["cause"] == original_cause and original_cause
            assert diagnostic["outcome"] == "not_applicable"
            facts = {f["field"]: f["value"] for f in diagnostic["facts"] if f}
            assert facts["native_input"] == {"unsigned": str(failure_input)}
            assert unknown["effect_diagnostic"]["code"] == "effect.reconciliation_abandoned"
            assert requests.count("/failure-send") == 1
            def read_original_evidence(expected):
                inspection = Native(libraries, url, seed, {"profile": "native_v1", "realm": 47, "principal": 65536,
                    "pid": saved["pid"], "generation": saved["generation"], "association": "state", "failure_policy": "stop"})
                try:
                    for kind, field in (("capture_failure", "capture_diagnostic"), ("native_effect", "effect_diagnostic")):
                        action = json.dumps({"diagnostic": {"identity": {"resource": saved["resource"], "exchange": "1"}, "kind": kind}}).encode()
                        actual = inspection.api.call("station_growing_http_read", inspection.pointer, action, len(action))
                        assert actual["diagnostic"] == expected[field], (kind, actual, expected)
                finally: inspection.close()
            read_original_evidence(unknown)
            saved = admin("own")
            configure(saved, "/failure-send", "release")
            retired = invoke()
            assert retired["phase"] == "retired" and retired["capture_diagnostic"] == diagnostic
            read_original_evidence(retired)
            assert requests.count("/failure-send") == 1
            assert len(requests) == 17 and len(applied) == 9
            assert cold.data_objects() > 0, "Exchange history never spilled to durable cold storage"
            print("HTTP worker: disk recovery, exact Transit retry, replay, cleanup, explicit and public retry/redirect/status/cancel, public admission/disposal, caller termination, name rebinding and partial-capture loss passed; failure-input receipt loss, original cause recovery and retirement; seventeen sends, nine applications, two cancellation requests.")
            print(f"HTTP capture storage: 8 MiB hot limit, {cold.data_objects()} persisted cold objects, {cold.file_bytes()} object-store bytes.")
            print(f"HTTP worker proof wall time: {time.monotonic() - started:.2f}s (excludes compilation).")
        finally:
            release.set()
            release_preparation.set()
            release_capture.set()
            release_terminal.set()
            release_failure.set()
            for process in (child, authority):
                if process is not None:
                    process.kill(); process.wait(timeout=10)
            for server in (peer, proxy): server.shutdown(); server.server_close()
            for thread in threads: thread.join(timeout=5)
            log.seek(0)
            if sys.exc_info()[0]: print(log.read()[-6000:], file=sys.stderr)
            log.close()


if __name__ == "__main__":
    run(*sys.argv[1:6], browser="--browser" in sys.argv)

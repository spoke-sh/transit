"""Actual finite worker and disk Ursula: dropped receipts and killed executors."""
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import ssl
import subprocess
import sys
import threading
import time

from storage import Fixture, free_port, wait_ready


def run(node, provision, worker):
    node, provision, worker = map(lambda value: str(Path(value).resolve()), (node, provision, worker))
    payload = bytes((i * 29 + 5) % 256 for i in range(1027))
    with Fixture() as fixture:
        public = json.loads(subprocess.check_output([provision, "public"], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        node_config = fixture.root / "node.json"
        node_config.write_text(json.dumps({"profile": "growing_v3", "genesis": {"realm": 47, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "http-worker", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        requests = []
        applied = set()
        blocked = threading.Event()
        release = threading.Event()
        dropped = {}
        recovered = set()
        failures = []

        class Peer(BaseHTTPRequestHandler):
            protocol_version = "HTTP/1.1"
            def log_message(self, *_): pass
            def do_POST(self):
                assert self.rfile.read(int(self.headers["Content-Length"])) == b"body"
                assert self.headers["Authorization"] == "Bearer fixture-request-secret"
                requests.append(self.path)
                key = self.headers["Idempotency-Key"]
                assert key == self.path
                first_application = key not in applied
                applied.add(key)
                if self.path == "/kill" and first_application:
                    blocked.set()
                    release.wait(timeout=30)
                try:
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(payload)))
                    self.send_header("Set-Cookie", "fixture-secret")
                    self.end_headers()
                    self.wfile.write(payload)
                except (BrokenPipeError, ConnectionResetError): pass

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v3/command" and response.status == 200:
                        request = json.loads(body)["request"]
                        command = request["command"]
                        selected = next((name for name in ("dispatch", "observe") if name in command), None)
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        for mutation in turn.get("mutations", []):
                            if mutation and mutation["value"]:
                                assert b"fixture-request-secret" not in bytes.fromhex(mutation["value"]), "Credential entered durable capture"
                        if any(m and m["value"] and bytes.fromhex(m["value"]).startswith(b"EXM1") for m in turn.get("mutations", [])):
                            selected = "seal"
                        if request["principal"] == 65536:
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
                return json.loads(subprocess.check_output([provision, url, operation, str(state)], timeout=30))
            def configure(saved, path, mode):
                configuration = {"url": proxy_url, "realm": 47, "principal": 65536, "seed_file": str(seed), "pid": saved["pid"], "generation": saved["generation"], "activation_directory": str(fixture.root), "exchange": 1, "endpoint_revision": 1, "endpoint": {"host": "localhost", "address": "127.0.0.1", "port": peer.server_port, "tls": True, "ca_file": str(tls_cert), "timeout_ms": 120000}, "mode": mode, "request": {"method": "POST", "target": [{"literal": path}], "body_bytes": 4, "headers": [{"name": "Authorization", "value": [{"literal": "Bearer "}, {"secret": {"binding": "api", "version": 7}}]}]}, "credentials": [{"binding": "api", "version": 7, "header": "Authorization", "file": str(credential)}], "body_file": str(body_file), "reconcile_before_ms": int(time.time() * 1000) + 240000}
                configuration.update(max_attempts=2, retry_policy={"id": 77, "revision": 1, "key_header": "Idempotency-Key"})
                configuration["request"]["headers"].append({"name": "Idempotency-Key", "value": [{"literal": path}]})
                config.write_text(json.dumps(configuration))
            def followup(saved, exchange, mode):
                configure(saved, "/kill", mode)
                configuration = json.loads(config.read_text())
                configuration.update(exchange=exchange, retry_parent=1)
                config.write_text(json.dumps(configuration))
            def invoke():
                return json.loads(subprocess.check_output([worker, str(config)], timeout=120))

            saved = admin("provision")
            configure(saved, "/complete", "prepare")
            assert invoke()["phase"] == "ready"
            saved = admin("own")
            configure(saved, "/complete", "execute")
            changed = json.loads(config.read_text())
            changed["endpoint"]["address"] = "127.0.0.2"
            config.write_text(json.dumps(changed))
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=15)
            assert refused.returncode != 0 and b"HttpEndpointChanged" in refused.stderr, refused
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
            assert invoke()["phase"] == "complete"
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
            assert invoke()["phase"] == "complete"
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
            assert invoke()["phase"] == "unknown"
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
            saved = admin("own")
            followup(saved, 3, "prepare")
            refused = subprocess.run([worker, str(config)], capture_output=True, timeout=30)
            assert refused.returncode != 0 and b"ExchangeAttemptBudgetExceeded" in refused.stderr, refused
            assert requests == ["/complete", "/kill", "/kill"], requests
            assert not failures, failures
            print("HTTP worker: disk recovery, exact Transit retry, replay, killed-executor unknown closure and explicit bounded idempotent retry passed; three sends, two applications.")
        finally:
            release.set()
            for process in (child, authority):
                if process is not None:
                    process.kill(); process.wait(timeout=10)
            for server in (peer, proxy): server.shutdown(); server.server_close()
            for thread in threads: thread.join(timeout=5)
            log.seek(0)
            if sys.exc_info()[0]: print(log.read()[-6000:], file=sys.stderr)
            log.close()


if __name__ == "__main__":
    run(*sys.argv[1:])

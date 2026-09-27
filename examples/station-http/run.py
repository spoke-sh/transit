"""Run the finite Zig HTTP caller/connector against an owned synthetic TLS peer."""
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import socket
import ssl
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[2]


def port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def run():
    started = time.monotonic()
    binaries = {name: ROOT / "zig-out/bin" / name for name in
                ("rey-cli", "transit-node", "example-station-http", "transit-station-http-worker")}
    env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
    env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2", LOG_LEVEL="warn")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryDirectory(prefix="transit-http-example-") as directory:
        work = Path(directory)
        children, logs = [], []
        for role in ("operator", "caller", "connector", "delivery", "peer"):
            (work / role).mkdir(mode=0o700)

        def write(path, value):
            path = work / path
            path.write_text(json.dumps(value))
            path.chmod(0o600)
            return path

        def invoke(argv, timeout=120):
            result = subprocess.run(list(map(str, argv)), env=env, capture_output=True, timeout=timeout)
            if result.returncode:
                raise RuntimeError(result.stderr.decode()[-4000:])
            return json.loads(result.stdout)

        def start(label, argv):
            log = (work / f"{label}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen(list(map(str, argv)), env=env, stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            return child

        def ready(child, url):
            deadline = time.monotonic() + 30
            while child.poll() is None and time.monotonic() < deadline:
                try:
                    with opener.open(url, timeout=.5) as response:
                        if response.status == 200:
                            return
                except (urllib.error.URLError, TimeoutError, ConnectionError):
                    pass
                time.sleep(.05)
            raise RuntimeError("Example service did not become ready")

        keys, public = {}, {}
        for role in ("operator", "caller", "connector", "delivery"):
            keys[role] = work / role / "seed.key"
            keys[role].write_text(secrets.token_hex(32))
            keys[role].chmod(0o600)
            public[role] = invoke([binaries["rey-cli"], "public-key", keys[role]])
        realm = secrets.randbelow(2**30) + 1
        store_port, node_port = port(), port()
        url = f"http://127.0.0.1:{node_port}"
        store_url = f"http://127.0.0.1:{store_port}"
        store_config = work / "ursula.toml"
        store_config.write_text(f'''[server]
listen = "127.0.0.1:{store_port}"
admin_listen = "127.0.0.1:0"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "{work / 'wal'}"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
''')
        node_config = write("operator/node.json", {"profile": "growing_v3", "genesis": {
            "realm": realm, "root_key": public["operator"], "max_clock_error_ms": 10000},
            "ursula_url": store_url, "bucket": "http-example", "journal": "authority", "port": node_port,
            "resident_pages": 64, "request_timeout_ms": 10000})
        principals = {"operator": 0, "caller": 1, "connector": 2, "delivery": 3}
        sequences = dict.fromkeys(principals, 0)

        def query(kind, role="operator"):
            request = write(role + "/query.json", {"realm": realm, "principal": principals[role], "kind": kind})
            return invoke([binaries["rey-cli"], "growing-query", keys[role], request, url])

        def command(value, role="operator"):
            # Persist this exact request before I/O. A failed receipt never
            # allocates another sequence for the same requested mutation.
            sequences[role] = query({"capabilities": { }}, role)["principal_sequence"] + 1
            request = write(f"{role}/command-{sequences[role]}.json", {
                "realm": realm, "principal": principals[role], "sequence": sequences[role], "command": value})
            for attempt in range(3):
                try:
                    return invoke([binaries["rey-cli"], "growing-submit", keys[role], request, url])["position"]
                except RuntimeError:
                    if attempt == 2:
                        raise

        peer = None
        try:
            storage = start("ursula", ["ursula", "server", "--config", store_config])
            ready(storage, store_url + "/__ursula/ready")
            subprocess.run([binaries["transit-node"], node_config, "--initialize"], env=env,
                           check=True, stdout=subprocess.DEVNULL, timeout=30)
            authority = start("node", [binaries["transit-node"], node_config])
            ready(authority, url + "/health")
            records = {}
            for role in ("caller", "connector"):
                pid = command({"spawn": {}})
                resource = command({"create_resource": {"writer": pid, "owned": role == "caller"}})
                records[role] = {"pid": pid, "resource": resource, "generation": 1}
                rights = 4 | 8 | 16 | 64 | (32 if role == "connector" else 0)
                command({"grant": {"subject": principals[role], "public_key": public[role], "permissions": rights, "pid": pid}})
                command({"grant_resource": {"resource": resource, "subject": principals[role], "permissions": 7}})
                command({"grant_resource": {"resource": resource, "subject": 0, "permissions": 7}})
                command({"associate": {"pid": pid, "name": b"state".hex(), "resource": resource}})
            caller, connector = records["caller"], records["connector"]
            for role, other, name in (("caller", "connector", "capture"), ("connector", "caller", "request")):
                command({"associate": {"pid": records[role]["pid"], "name": name.encode().hex(),
                                       "resource": records[other]["resource"], "required": False}})
                command({"grant_resource": {"resource": records[other]["resource"], "subject": principals[role], "permissions": 3}})
            command({"grant": {"subject": 3, "public_key": public["delivery"], "permissions": 148}})

            # Signing has no I/O; granting caller execution does not grant admin
            # authority. Exercise both boundaries through the actual CLI.
            before = query({"capabilities": {}})["position"]
            denied = write("caller/denied.json", {"realm": realm, "principal": 1, "sequence": 1, "command": {"spawn": {}}})
            first = invoke([binaries["rey-cli"], "growing-sign", keys["caller"], denied])
            assert first == invoke([binaries["rey-cli"], "growing-sign", keys["caller"], denied])
            result = subprocess.run([binaries["rey-cli"], "growing-submit", keys["caller"], denied, url], env=env,
                                    capture_output=True, timeout=15)
            assert result.returncode and b"AccessDenied" in result.stderr
            extra_url = subprocess.run([binaries["rey-cli"], "growing-sign", keys["caller"], denied, url], env=env,
                                       capture_output=True, timeout=15)
            assert extra_url.returncode and b"ExpectedKeyAndRequestFile" in extra_url.stderr
            assert query({"capabilities": {}})["position"] == before

            cert, private = work / "connector/ca.pem", work / "peer/tls.key"
            subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", private,
                            "-out", cert, "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"],
                           check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            secret = secrets.token_hex(24)
            credential = work / "connector/credential"
            credential.write_text(secret)
            credential.chmod(0o600)
            payload = b"synthetic response\x00\xff" + " \u03bb".encode()
            requests = []

            class Peer(BaseHTTPRequestHandler):
                protocol_version = "HTTP/1.1"
                def log_message(self, *_): pass
                def do_POST(self):
                    if self.path != "/example" or self.headers.get("Authorization") != "Bearer " + secret or self.rfile.read(int(self.headers["Content-Length"])) != b"hello":
                        self.send_error(403)
                        return
                    requests.append(self.path)
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(payload)))
                    self.send_header("Set-Cookie", "omitted")
                    self.end_headers()
                    self.wfile.write(payload)

            peer = ThreadingHTTPServer(("127.0.0.1", 0), Peer)
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.load_cert_chain(cert, private)
            peer.socket = context.wrap_socket(peer.socket, server_side=True)
            thread = threading.Thread(target=peer.serve_forever, daemon=True)
            thread.start()
            deadline = int(time.time() * 1000) + 240000
            body = work / "caller/body"
            body.write_bytes(b"hello")
            caller_config = {"url": url, "realm": realm, "principal": 1, "pid": caller["pid"], "worker": connector["pid"],
                "seed_file": str(keys["caller"]), "reconcile_before_ms": deadline, "body_file": str(body),
                "request": {"method": "POST", "target": [{"literal": "/example"}], "body_bytes": 5,
                    "headers": [{"name": "Authorization", "value": [{"literal": "Bearer "}, {"secret": {"binding": "demo", "version": 1}}]}]}}
            connector_config = {"url": url, "realm": realm, "principal": 2, "pid": connector["pid"],
                "seed_file": str(keys["connector"]), "reconcile_before_ms": deadline, "activation_directory": str(work / "connector"),
                "exchange": 1, "endpoint_revision": 1, "endpoint": {"host": "localhost", "address": "127.0.0.1",
                    "port": peer.server_port, "tls": True, "ca_file": str(cert), "timeout_ms": 60000},
                "credentials": [{"binding": "demo", "version": 1, "header": "Authorization", "file": str(credential)}],
                "admission": {"caller": caller["pid"], "resource": caller["resource"],
                    "scope": {"method": "POST", "target": "/example", "headers": ["authorization"]}}}

            def activate(role, config, mode):
                record = records[role]
                record["generation"] = query({"process": record["pid"]})["body"]["process"]["process"]["generation"]
                command({"own": {"pid": record["pid"], "expected_generation": record["generation"], "worker": principals[role]}})
                record["generation"] += 1
                config.update(generation=record["generation"], mode=mode)
                path = write(role + "/config.json", config)
                name = "example-station-http" if role == "caller" else "transit-station-http-worker"
                return invoke([binaries[name], path])

            def deliver():
                after = None
                while True:
                    position = query({"capabilities": {}}, "delivery")["position"]
                    page = query({"outputs": {"after": after, "position": position}}, "delivery")["body"]["outputs"]
                    for entry in page["entries"]:
                        if entry and entry["phase"] == "pending":
                            command({"deliver": entry["id"]}, "delivery")
                    after = page["next"]
                    if after is None:
                        return

            called = activate("caller", caller_config, "publish")
            assert called["phase"] == "called"
            assert activate("caller", caller_config, "publish") == called, "Restart duplicated the durable call"
            deliver()
            assert activate("connector", connector_config, "accept")["phase"] == "ready"
            assert activate("connector", connector_config, "execute")["outcome"] == "observed"
            deliver()
            outcome = activate("caller", caller_config, "receive")
            assert outcome["phase"] == "observed" and outcome["status"] == 200
            # Recovery after node/store loss and with credentials unavailable.
            authority.kill(); authority.wait(timeout=10)
            storage.kill(); storage.wait(timeout=10)
            credential.unlink()
            peer.shutdown(); peer.server_close(); peer = None
            storage = start("ursula-recovered", ["ursula", "server", "--config", store_config])
            ready(storage, store_url + "/__ursula/ready")
            authority = start("node-recovered", [binaries["transit-node"], node_config])
            ready(authority, url + "/health")
            replay = activate("caller", caller_config, "replay")
            assert replay["body_bytes"] == len(payload) and replay["sha256"] == hashlib.sha256(payload).hexdigest()
            assert requests == ["/example"], requests
            print(json.dumps({"example": "station-http", "phase": "passed", "sends": len(requests),
                              "status": outcome["status"], "body_bytes": replay["body_bytes"],
                              "seconds": round(time.monotonic() - started, 2)}))
        except BaseException:
            for log in logs:
                log.flush()
                print(Path(log.name).read_text()[-4000:])
            raise
        finally:
            if peer is not None:
                peer.shutdown(); peer.server_close()
            for child in reversed(children):
                if child.poll() is None: child.kill()
                child.wait(timeout=10)
            for log in logs: log.close()


if __name__ == "__main__":
    run()

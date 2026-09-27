"""Run the finite Zig HTTP caller/connector against an owned synthetic TLS peer."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import selectors
import shutil
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


def run(profile="local", bootstrap=False):
    started = time.monotonic()
    binaries = {name: ROOT / "zig-out/bin" / name for name in
                ("rey-cli", "transit-node", "example-station-http", "transit-station-http-worker")}
    env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
    env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2", LOG_LEVEL="warn")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryDirectory(prefix="transit-http-example-") as directory:
        work = Path(directory)
        children, logs = [], []
        placement = None
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
            if placement is not None:
                child = placement.start(label.split("-")[0])
                children.append(child)
                return child
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
        if profile != "local":
            if profile == "reference":
                from reference import Reference
                placement = Reference(work)
                bootstrap = True
            else:
                from compose import Compose
                placement = Compose(work)
            (work / "wal").mkdir()
            (work / "activations").mkdir()
        store_config = work / "ursula.toml"
        store_config.write_text(f'''[server]
listen = "{'0.0.0.0:8080' if placement else f'127.0.0.1:{store_port}'}"
admin_listen = "127.0.0.1:0"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "{'/wal' if placement else work / 'wal'}"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
''')
        node_config = write("operator/node.json", {"profile": "growing_v3", "genesis": {
            "realm": realm, "root_key": public["operator"], "max_clock_error_ms": 10000},
            "ursula_url": "http://ursula:8080" if placement else store_url, "bucket": "http-example", "journal": "authority", "port": 8080 if placement else node_port,
            "listen": "0.0.0.0" if placement else "127.0.0.1",
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
            if placement: store_url = placement.url("ursula")
            ready(storage, store_url + "/__ursula/ready")
            if placement:
                placement.initialize()
            else:
                subprocess.run([binaries["transit-node"], node_config, "--initialize"], env=env,
                               check=True, stdout=subprocess.DEVNULL, timeout=30)
            authority = start("node", [binaries["transit-node"], node_config])
            if placement: url = placement.url("node")
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

            if placement:
                shutil.copyfile(cert, work / "peer/ca.pem")
                write("peer/config.json", {"secret": secret, "payload": payload.hex(), "requests": "/peer-output/requests.json" if profile == "reference" else "/peer/requests.json",
                    "certificate": "/peer/ca.pem", "private_key": "/peer/tls.key"})
                peer = placement.start("peer")
                children.append(peer)
                peer_address, peer_port = placement.address("peer", "effect"), 8443
                denied = [peer_address + ":8443", placement.address("ursula", "storage") + ":8080", "1.1.1.1:443"]
                assert placement.invoke("caller-probe", "probe", placement.authority, *denied) == {"authority": "reachable", "denied": 3}
            else:
                peer = ThreadingHTTPServer(("127.0.0.1", 0), Peer)
                context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                context.load_cert_chain(cert, private)
                peer.socket = context.wrap_socket(peer.socket, server_side=True)
                thread = threading.Thread(target=peer.serve_forever, daemon=True)
                thread.start()
                peer_address, peer_port = "127.0.0.1", peer.server_port
            deadline = int(time.time() * 1000) + 240000
            body = work / "caller/body"
            body.write_bytes(b"hello")
            caller_config = {"url": url, "realm": realm, "principal": 1, "pid": caller["pid"], "worker": connector["pid"],
                "seed_file": str(keys["caller"]), "reconcile_before_ms": deadline, "body_file": str(body),
                "request": {"method": "POST", "target": [{"literal": "/example"}], "body_bytes": 5,
                    "headers": [{"name": "Authorization", "value": [{"literal": "Bearer "}, {"secret": {"binding": "demo", "version": 1}}]}]}}
            connector_config = {"url": url, "realm": realm, "principal": 2, "pid": connector["pid"],
                "seed_file": str(keys["connector"]), "reconcile_before_ms": deadline, "activation_directory": str(work / "connector"),
                "exchange": 1, "endpoint_revision": 1, "endpoint": {"host": "localhost", "address": peer_address,
                    "port": peer_port, "tls": True, "ca_file": str(cert), "timeout_ms": 60000},
                "credentials": [{"binding": "demo", "version": 1, "header": "Authorization", "file": str(credential)}],
                "admission": {"caller": caller["pid"], "resource": caller["resource"],
                    "scope": {"method": "POST", "target": "/example", "headers": ["authorization"]}}}

            def activate(role, config, mode):
                record = records[role]
                record["generation"] = query({"process": record["pid"]})["body"]["process"]["process"]["generation"]
                if bootstrap and role == "caller":
                    configured = config | {"generation": record["generation"] + 1, "mode": mode, "body": body.read_bytes().hex()}
                    configured.pop("seed_file")
                    configured.pop("body_file")
                    if profile == "reference":
                        handle, registration = placement.register(configured)
                    else:
                        child = subprocess.Popen([binaries["example-station-http"], "--bootstrap-json", json.dumps(configured)],
                                                 env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                        children.append(child)
                        with selectors.DefaultSelector() as selector:
                            selector.register(child.stdout, selectors.EVENT_READ)
                            assert selector.select(timeout=15), "Missing growing public registration"
                        registration = json.loads(child.stdout.readline())["growing_bootstrap"]
                    assert registration == {"version": 1, "realm": realm, "pid": record["pid"], "principal": 1,
                                            "generation": configured["generation"], "public_key": registration["public_key"]}
                    assert len(registration["public_key"]) == 32 and registration["public_key"] != public["caller"]
                    public["caller"] = registration["public_key"]
                    command({"grant": {"subject": 1, "public_key": public["caller"], "permissions": 4 | 8 | 16 | 64, "pid": record["pid"]}})
                    for resource, permissions in ((caller["resource"], 7), (connector["resource"], 3)):
                        command({"grant_resource": {"resource": resource, "subject": 1, "permissions": permissions}})
                    command({"own": {"pid": record["pid"], "expected_generation": record["generation"], "worker": 1}})
                    if profile == "reference": return placement.finish(handle)
                    stdout, stderr = child.communicate(timeout=120)
                    if child.returncode: raise RuntimeError(stderr[-4000:])
                    return json.loads(stdout)
                command({"own": {"pid": record["pid"], "expected_generation": record["generation"], "worker": principals[role]}})
                record["generation"] += 1
                config.update(generation=record["generation"], mode=mode)
                if placement:
                    # Only this role's directory is mounted in its container.
                    mapped = json.loads(json.dumps(config).replace(str(work) + "/", "/"))
                    mapped["url"] = placement.authority
                    if role == "connector": mapped["activation_directory"] = "/activations"
                    write(role + "/config.json", mapped)
                    return placement.invoke(role)
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
            if profile == "reference": placement.kill_caller_worker()
            recovered = activate("caller", caller_config, "publish")
            assert recovered == called, ("Restart changed the durable call", called, recovered)
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
            if placement:
                requests = placement.peer_requests()
                placement.stop_peer(peer)
            else:
                peer.shutdown(); peer.server_close()
            peer = None
            storage = start("ursula-recovered", ["ursula", "server", "--config", store_config])
            if placement: store_url = placement.url("ursula")
            ready(storage, store_url + "/__ursula/ready")
            authority = start("node-recovered", [binaries["transit-node"], node_config])
            if placement: url = placement.url("node")
            ready(authority, url + "/health")
            replay = activate("caller", caller_config, "replay")
            assert replay["body_bytes"] == len(payload) and replay["sha256"] == hashlib.sha256(payload).hexdigest()
            assert requests == ["/example"], requests
            print(json.dumps({"example": "station-http", "profile": profile, "bootstrap": bootstrap, "phase": "passed", "sends": len(requests),
                              "status": outcome["status"], "body_bytes": replay["body_bytes"],
                              "seconds": round(time.monotonic() - started, 2)}))
        except BaseException:
            if placement:
                print(placement.call("ps", "--all", "--format", "json"))
                print(placement.call("logs", "--tail", "80"))
            for log in logs:
                log.flush()
                print(Path(log.name).read_text()[-4000:])
            raise
        finally:
            if peer is not None and placement is None:
                peer.shutdown(); peer.server_close()
            for child in reversed(children):
                if child.poll() is None: child.kill()
                child.wait(timeout=10)
            for log in logs: log.close()
            if placement: placement.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("local", "compose", "reference"), default="local")
    parser.add_argument("--bootstrap", action="store_true", help="Qualify fresh in-memory caller keys and explicit operator ownership")
    args = parser.parse_args()
    if args.bootstrap and args.profile == "compose": parser.error("Use local or reference for bootstrap qualification")
    run(args.profile, args.bootstrap)

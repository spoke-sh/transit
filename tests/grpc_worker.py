"""Real Zig RPC worker, public signed authority and owned disk/cold storage."""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import grpc
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import threading
import time
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory
from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore


def run(node, provision, worker):
    started = time.monotonic()
    node, provision, worker = [str(Path(path).resolve()) for path in (node, provision, worker)]
    descriptor_bytes = (Path(__file__).parent / "fixtures/grpc/peer.pb").read_bytes()
    descriptors = descriptor_pool.DescriptorPool()
    for file in descriptor_pb2.FileDescriptorSet.FromString(descriptor_bytes).file: descriptors.Add(file)
    Payload = message_factory.GetMessageClass(descriptors.FindMessageTypeByName("test.Payload"))
    payload = Payload(text="café 🌐", blob=bytes(range(256)), sequence=2**64-1).SerializeToString(deterministic=True)
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        port = free_port(); url = f"http://127.0.0.1:{port}"
        public = json.loads(subprocess.check_output([provision, "public"], timeout=10))
        node_config = fixture.root / "node.json"
        node_config.write_text(json.dumps({"profile": "growing_v3", "genesis": {"realm": 47, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "grpc-worker", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        key, cert = fixture.root / "peer.key", fixture.root / "peer.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key), "-out", str(cert), "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"], check=True, capture_output=True, timeout=20)
        sends, applied, failures, dropped, recovered = [], set(), [], {}, set()
        capture_prefix = threading.Event(); release_capture = threading.Event()
        capture_armed = False
        def begin(context, shape):
            fields = list(context.invocation_metadata())
            assert ("authorization", "Bearer fixture-rpc-secret") in fields
            assert [(k, v) for k, v in fields if k == "x-repeat"] == [("x-repeat", "first"), ("x-repeat", "second")]
            assert ("x-binary-bin", b"\x00\xff") in fields
            operation = next(v for k, v in fields if k == "idempotency-key")
            sends.append((shape, operation)); applied.add(operation)
            context.send_initial_metadata((("x-repeat", "one"), ("x-repeat", "two"), ("set-cookie", "fixture-rpc-response-secret")))
            context.set_trailing_metadata((("x-binary-bin", b"\x00\xff"),))
        def unary(request, context):
            begin(context, "unary"); assert request == payload; return request
        def server(request, context):
            begin(context, "server_streaming"); assert request == payload
            for _ in range(3): yield request
        def client(requests, context):
            begin(context, "client_streaming"); assert list(requests) == [payload]*3; return payload
        def bidi(requests, context):
            begin(context, "bidi")
            for request in requests:
                assert request == payload; yield request
        pool = ThreadPoolExecutor(max_workers=4)
        peer = grpc.server(pool, options=(("grpc.so_reuseport", 0),))
        peer.add_generic_rpc_handlers((grpc.method_handlers_generic_handler("test.Peer", {
            "Unary": grpc.unary_unary_rpc_method_handler(unary),
            "Server": grpc.unary_stream_rpc_method_handler(server),
            "Client": grpc.stream_unary_rpc_method_handler(client),
            "Bidi": grpc.stream_stream_rpc_method_handler(bidi),
        }),))
        peer_port = peer.add_secure_port("127.0.0.1:0", grpc.ssl_server_credentials(((key.read_bytes(), cert.read_bytes()),)))
        peer.start()
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse(); data = response.read()
                    if self.path == "/v3/command" and response.status == 200:
                        request = json.loads(body)["request"]; command = request["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        values = [bytes.fromhex(m["value"]) for m in turn.get("mutations", []) if m and m["value"]]
                        for value in values:
                            assert b"fixture-rpc-secret" not in value and b"fixture-rpc-response-secret" not in value
                        selected = next((name for name in ("dispatch", "observe") if name in command), None)
                        if any(value.startswith(b"EXM1") for value in values): selected = "seal"
                        if request["principal"] == 65536:
                            if capture_armed and not capture_prefix.is_set() and payload[:256] in values:
                                capture_prefix.set(); release_capture.wait(timeout=30)
                            for name, (original, receipt) in dropped.items():
                                if body == original:
                                    assert data == receipt; recovered.add(name)
                            if selected and selected not in dropped:
                                dropped[selected] = (body, data); data = b'{"position":0}'
                    self.send_response(response.status); self.send_header("Content-Length", str(len(data))); self.end_headers(); self.wfile.write(data)
                except (BrokenPipeError, ConnectionResetError): pass
                except BaseException as error:
                    failures.append(repr(error)); raise
                finally: connection.close()
        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        proxy_thread = threading.Thread(target=proxy.serve_forever, daemon=True); proxy_thread.start()
        state, config = fixture.root / "saved.json", fixture.root / "worker.json"
        seed, secret = fixture.root / "worker.seed", fixture.root / "secret"
        seed.write_text("48"*32); secret.write_bytes(b"Bearer fixture-rpc-secret")
        request_file, batch_file = fixture.root / "request.json", fixture.root / "batch.bin"
        node_log = (fixture.root / "node.log").open("w+")
        authority, child = None, None
        deadline = int(time.time()*1000) + 1800000
        def start_node():
            process = subprocess.Popen([node, str(node_config)], stdout=node_log, stderr=subprocess.STDOUT)
            wait_ready(fixture.http, process, url + "/health"); return process
        def admin(operation, exchange=None, *, expect=True):
            result = subprocess.run([provision, url, operation, str(state), *([] if exchange is None else [str(exchange)])], capture_output=True, timeout=120)
            if expect: assert result.returncode == 0, result.stderr[-2000:]
            return json.loads(result.stdout) if result.returncode == 0 else result
        def configure(saved, exchange, shape, method, operation, mode, followup=None):
            metadata = {"version": 1, "method": "/test.Peer/"+method, "shape": shape, "descriptor_digest": hashlib.sha256(descriptor_bytes).hexdigest(), "metadata": [
                {"name": "authorization", "value": {"secret": {"binding": "peer", "version": 1}}},
                {"name": "idempotency-key", "value": {"literal_hex": operation.encode().hex()}},
                {"name": "x-repeat", "value": {"literal_hex": b"first".hex()}},
                {"name": "x-repeat", "value": {"literal_hex": b"second".hex()}},
                {"name": "x-binary-bin", "value": {"literal_hex": b"\x00\xff".hex()}},
            ]}
            request_file.write_text(json.dumps(metadata, separators=(",", ":")))
            count = 1 if shape in ("unary", "server_streaming") else 3
            batch_file.write_bytes(b"GRB1" + struct.pack("<I", count) + (struct.pack("<I", len(payload))+payload)*count)
            value = {"url": f"http://127.0.0.1:{proxy.server_port}", "realm": 47, "principal": 65536, "seed_file": str(seed), "pid": saved["pid"], "generation": saved["generation"], "activation_directory": str(fixture.root), "exchange": exchange, "endpoint_revision": 1, "endpoint": {"host": "localhost", "address": "127.0.0.1", "port": peer_port, "tls": True, "ca_file": str(cert), "timeout_ms": 60000}, "mode": mode, "request_file": str(request_file), "batch_file": str(batch_file), "reconcile_before_ms": deadline, "credentials": [{"binding": "peer", "version": 1, "metadata": "authorization", "file": str(secret)}], "response_metadata": ["x-repeat", "x-binary-bin"], "max_attempts": 2, "retry_policy": {"id": 1, "revision": 1, "key_metadata": "idempotency-key"}, "followup": followup}
            config.write_text(json.dumps(value)); return value
        def invoke(expect=True):
            result = subprocess.run([worker, str(config)], capture_output=True, timeout=180, env=os.environ | {"LOG_FORMAT": "json"})
            if expect: assert result.returncode == 0, result.stderr[-3500:]
            assert b"fixture-rpc-secret" not in result.stderr and b"fixture-rpc-response-secret" not in result.stderr
            return json.loads(result.stdout) if result.returncode == 0 else result
        try:
            subprocess.run([node, str(node_config), "--initialize"], check=True, stdout=node_log, stderr=subprocess.STDOUT, timeout=30)
            authority = start_node(); saved = admin("provision")
            shapes = [("unary", "Unary", 1), ("server_streaming", "Server", 3), ("client_streaming", "Client", 1), ("bidi", "Bidi", 3)]
            for exchange, (shape, method, response_count) in enumerate(shapes, 1):
                if exchange != 1: saved = admin("own")
                configure(saved, exchange, shape, method, f"complete-{shape}", "prepare")
                assert invoke()["phase"] == "ready"
                saved = admin("own"); original = configure(saved, exchange, shape, method, f"complete-{shape}", "execute")
                if exchange == 1:
                    original["endpoint"]["address"] = "169.254.169.254"; config.write_text(json.dumps(original))
                    assert invoke(expect=False).returncode != 0 and sends == []
                    saved = admin("own"); configure(saved, exchange, shape, method, f"complete-{shape}", "execute")
                    admin("revoke"); assert invoke(expect=False).returncode != 0 and sends == []; admin("restore")
                    saved = admin("own"); configure(saved, exchange, shape, method, f"complete-{shape}", "execute")
                result = invoke(); assert result["phase"] == "complete" and result["outcome"] == "observed", result
                assert invoke(expect=False).returncode != 0, "Entered generation was reused"
                secret.unlink()
                replay = admin("replay", exchange)
                assert replay == dict(bytes=len(payload)*response_count, sha256=hashlib.sha256(payload*response_count).hexdigest(), status=0, messages=response_count), replay
                secret.write_bytes(b"Bearer fixture-rpc-secret")
            assert recovered == {"seal", "dispatch", "observe"}, (dropped.keys(), recovered)
            for exchange, (shape, method, _) in enumerate(shapes, 5):
                saved = admin("own"); configure(saved, exchange, shape, method, f"kill-{shape}", "prepare"); assert invoke()["phase"] == "ready"
                saved = admin("own"); configure(saved, exchange, shape, method, f"kill-{shape}", "execute")
                capture_prefix.clear(); release_capture.clear(); capture_armed = True
                child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                assert capture_prefix.wait(timeout=90), ("Durable response prefix not reached", shape, child.poll())
                child.kill(); child.communicate(timeout=10); child = None
                release_capture.set(); capture_armed = False
                authority.kill(); authority.wait(timeout=10); authority = None
                fixture.stop(); fixture.start(); authority = start_node()
                before = len(sends); saved = admin("own"); configure(saved, exchange, shape, method, f"kill-{shape}", "execute")
                result = invoke(); assert result["phase"] == "unknown" and result["outcome"] == "closed_unknown", result
                assert len(sends) == before
                assert admin("replay", exchange, expect=False).returncode != 0
            # An explicit new effect reuses the declared remote idempotency key;
            # the original attempt remains closed unknown forever.
            saved = admin("own"); configure(saved, 9, "unary", "Unary", "kill-unary", "prepare", {"parent": 5, "reason": "retry"})
            assert invoke()["phase"] == "ready"
            saved = admin("own"); configure(saved, 9, "unary", "Unary", "kill-unary", "execute", {"parent": 5, "reason": "retry"})
            assert invoke()["outcome"] == "observed"
            assert admin("inspect", 5)["effect"] == "closed_unknown"
            assert len(sends) == 9 and len(applied) == 8, (sends, applied)
            saved = admin("own"); configure(saved, 10, "unary", "Unary", "kill-unary", "prepare", {"parent": 5, "reason": "retry"})
            assert invoke(expect=False).returncode != 0 and len(sends) == 9
            # Explicit disposal closes current replay before bounded reclamation.
            for exchange in (9, 5, 1):
                for _ in range(8):
                    saved = admin("own"); value = configure(saved, exchange, "unary", "Unary", "unused", "release"); value["cleanup_steps"] = 8; config.write_text(json.dumps(value)); invoke()
                    status = admin("inspect", exchange)
                    assert status["phase"] == "retired"
                    assert admin("replay", exchange, expect=False).returncode != 0
                    if status["collected"] == status["segments"] + int(status["pending"]): break
                else: raise AssertionError("Bounded cleanup did not finish")
            assert not failures, failures
            assert cold.data_objects() > 0
            print(f"RPC worker: four shapes and partial-capture crashes, current-policy reads, receipt recovery, explicit retry and cleanup passed; {len(sends)} sends, {len(applied)} applications.")
            print(f"RPC capture storage: 8 MiB hot limit, {cold.data_objects()} cold objects, {cold.file_bytes()} object-store bytes.")
            print(f"RPC worker proof wall time: {time.monotonic()-started:.2f}s (excludes compilation).")
        finally:
            release_capture.set()
            if child is not None and child.poll() is None: child.kill(); child.communicate(timeout=10)
            if authority is not None: authority.kill(); authority.wait(timeout=10)
            proxy.shutdown(); proxy.server_close(); proxy_thread.join(timeout=5)
            peer.stop(0).wait(timeout=5); pool.shutdown(wait=True)
            node_log.seek(0)
            if sys.exc_info()[0]: print(node_log.read()[-6000:], file=sys.stderr)
            node_log.close()


if __name__ == "__main__":
    run(*sys.argv[1:])

"""Real Zig RPC worker, public signed authority and owned disk/cold storage."""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import grpc
import hashlib
import json
import os
from pathlib import Path
from runner.paths import ROOT
import struct
import subprocess
import sys
import threading
import time
from google.protobuf import descriptor_pb2, descriptor_pool, message_factory
from harness.ursula import Fixture
from harness.services import free_port, wait_ready
from storage.providers.cold_storage import ColdStore
from interfaces.grpc.grpc_faults import Boundary


def run(node, provision, worker, board=None, browser=None, *, control=False):
    control = control or board == 'control'
    faults = board in ('faults', 'control')
    assert not control or faults
    if faults: board = None
    boundary = Boundary()
    started = time.monotonic()
    node, provision, worker = [str(Path(path).resolve()) for path in (node, provision, worker)]
    descriptor_bytes = (ROOT / "tests/fixtures/grpc/peer.pb").read_bytes()
    descriptors = descriptor_pool.DescriptorPool()
    for file in descriptor_pb2.FileDescriptorSet.FromString(descriptor_bytes).file: descriptors.Add(file)
    Payload = message_factory.GetMessageClass(descriptors.FindMessageTypeByName("test.Payload"))
    payload = Payload(text="café 🌐", blob=bytes(range(256)), sequence=2**64-1).SerializeToString(deterministic=True)
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        port = free_port(); url = f"http://127.0.0.1:{port}"
        public = json.loads(subprocess.check_output([provision, "public"], timeout=10))
        node_config = fixture.root / "node.json"
        max_clock_error_ms = 10000
        node_config.write_text(json.dumps({"profile": "native_v1", "genesis": {"realm": 47, "root_key": public, "max_clock_error_ms": max_clock_error_ms}, "ursula_url": fixture.url, "bucket": "grpc-worker", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        key, cert = fixture.root / "peer.key", fixture.root / "peer.pem"
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", str(key), "-out", str(cert), "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost"], check=True, capture_output=True, timeout=20)
        sends, applied, failures, dropped, recovered = [], set(), [], {}, set()
        capture_diagnostics = {}
        capture_prefix = threading.Event(); release_capture = threading.Event()
        capture_armed = False
        blocked_peer = {}
        def begin(context, shape):
            fields = list(context.invocation_metadata())
            assert ("authorization", "Bearer fixture-rpc-secret") in fields
            assert [(k, v) for k, v in fields if k == "x-repeat"] == [("x-repeat", "first"), ("x-repeat", "second")]
            assert ("x-binary-bin", b"\x00\xff") in fields
            operation = next(v for k, v in fields if k == "idempotency-key")
            sends.append((shape, operation)); applied.add(operation)
            if operation == 'blocked-control': blocked_peer['context'] = context
            boundary.peer(operation)
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
                command = json.loads(body)["request"]["command"] if self.path == "/v1/command" else {}
                boundary.before(command)
                connection = HTTPConnection("127.0.0.1", port, timeout=15)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse(); data = response.read()
                    if self.path == "/v1/command" and response.status == 200:
                        request = json.loads(body)["request"]; command = request["command"]
                        turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                        values = [bytes.fromhex(m["value"]) for m in turn.get("mutations", []) if m and m["value"]]
                        for value in values:
                            assert b"fixture-rpc-secret" not in value and b"fixture-rpc-response-secret" not in value
                        selected = next((name for name in ("dispatch", "observe") if name in command), None)
                        if any(value.startswith(b"EXM1") for value in values): selected = "seal"
                        if request["principal"] == 65536:
                            boundary.after(command, values)
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
            # The control scenario crosses a finite process cutoff. Declare
            # the peer's existing 120-second block budget before preparing its
            # immutable request, so a separate RPC timeout cannot end the call
            # before that cutoff and its admitted clock uncertainty have passed.
            network_timeout_ms = 120000 if control else 60000
            value = {"url": f"http://127.0.0.1:{proxy.server_port}", "realm": 47, "principal": 65536, "seed_file": str(seed), "pid": saved["pid"], "generation": saved["generation"], "activation_directory": str(fixture.root), "exchange": exchange, "endpoint_revision": 1, "endpoint": {"host": "localhost", "address": "127.0.0.1", "port": peer_port, "tls": True, "ca_file": str(cert), "timeout_ms": network_timeout_ms}, "mode": mode, "request_file": str(request_file), "batch_file": str(batch_file), "reconcile_before_ms": deadline, "credentials": [{"binding": "peer", "version": 1, "metadata": "authorization", "file": str(secret)}], "response_metadata": ["x-repeat", "x-binary-bin"], "max_attempts": 2, "retry_policy": {"id": 1, "revision": 1, "key_metadata": "idempotency-key"}, "followup": followup}
            config.write_text(json.dumps(value)); return value
        def invoke(expect=True):
            result = subprocess.run([worker, str(config)], capture_output=True, timeout=180, env=os.environ | {"LOG_FORMAT": "json"})
            if expect: assert result.returncode == 0, result.stderr[-3500:]
            assert b"fixture-rpc-secret" not in result.stderr and b"fixture-rpc-response-secret" not in result.stderr
            return json.loads(result.stdout) if result.returncode == 0 else result
        try:
            subprocess.run([node, str(node_config), "--initialize"], check=True, stdout=node_log, stderr=subprocess.STDOUT, timeout=30)
            authority = start_node()
            if not control: saved = admin("provision")
            if not faults:
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
                if board:
                    from interfaces.grpc.grpc_board import inspect_capture
                    inspect_capture(fixture, admin, url, saved, str(Path(board).resolve()), provision, state, browser)
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
                    capture_diagnostics[exchange] = result["capture_diagnostic"]
                    assert result["capture_diagnostic"]["code"] == "exchange.recovered_incomplete", result
                    assert result["capture_diagnostic"]["cause"] is None
                    assert result["capture_diagnostic"]["outcome"] == "not_applicable"
                    assert result["effect_diagnostic"]["code"] == "effect.reconciliation_abandoned"
                    assert all(a is None or a["kind"] == "inspect_status" for a in result["capture_diagnostic"]["actions"])
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
                        saved = admin("own"); value = configure(saved, exchange, "unary", "Unary", "unused", "release"); value["cleanup_steps"] = 8; config.write_text(json.dumps(value)); retired = invoke()
                        if exchange in capture_diagnostics:
                            assert retired["capture_diagnostic"] == capture_diagnostics[exchange]
                        status = admin("inspect", exchange)
                        assert status["phase"] == "retired"
                        assert admin("replay", exchange, expect=False).returncode != 0
                        if status["collected"] == status["segments"] + int(status["pending"]): break
                    else: raise AssertionError("Bounded cleanup did not finish")
            elif not control:
                # Every stop occurs after a real accepted command, while its receipt
                # is withheld. Recovery crosses an actual node/store cold restart.
                for exchange, phase in enumerate(('preparation', 'dispatch', 'complete', 'observe'), 1):
                    if exchange != 1: saved = admin('own')
                    operation = 'boundary-' + phase
                    configure(saved, exchange, 'unary', 'Unary', operation, 'prepare')
                    if phase != 'preparation':
                        assert invoke()['phase'] == 'ready'
                        saved = admin('own'); configure(saved, exchange, 'unary', 'Unary', operation, 'execute')
                    before = len(sends)
                    boundary.arm(phase)
                    child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    assert boundary.reached.wait(timeout=90), (phase, child.poll())
                    child.kill(); child.communicate(timeout=10); child = None
                    boundary.close(); boundary.phase = None
                    authority.kill(); authority.wait(timeout=10); authority = None
                    fixture.stop(); fixture.start(); authority = start_node()
                    saved = admin('own'); configure(saved, exchange, 'unary', 'Unary', operation, 'prepare' if phase == 'preparation' else 'execute')
                    result = invoke()
                    if phase == 'preparation':
                        assert result['phase'] == 'ready' and len(sends) == before
                        saved = admin('own'); configure(saved, exchange, 'unary', 'Unary', operation, 'execute')
                        assert invoke()['outcome'] == 'observed' and len(sends) == before + 1
                    elif phase == 'dispatch':
                        assert result['phase'] == 'unknown' and result['outcome'] == 'closed_unknown'
                        assert len(sends) == before
                    else:
                        assert result['phase'] == 'complete' and result['outcome'] == 'observed'
                        assert len(sends) == before + 1
                    print('RPC boundary recovery passed:', phase, flush=True)
                # Change current effect permission after frozen validation, before
                # the actual dispatch request reaches authority.
                saved = admin('own'); configure(saved, 5, 'unary', 'Unary', 'revocation', 'prepare'); invoke()
                saved = admin('own'); configure(saved, 5, 'unary', 'Unary', 'revocation', 'execute')
                before = len(sends); boundary.arm('before_dispatch')
                child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                assert boundary.reached.wait(timeout=90)
                admin('deny-dispatch'); boundary.close(); boundary.phase = None
                child.communicate(timeout=30); assert child.returncode != 0; child = None
                assert len(sends) == before and admin('inspect', 5)['effect'] == 'pending'
                admin('allow-dispatch'); saved = admin('own'); configure(saved, 5, 'unary', 'Unary', 'revocation', 'execute')
                assert invoke()['outcome'] == 'observed' and len(sends) == before + 1
                print('RPC dispatch revocation passed.', flush=True)
            else:
                # A separate executor loses work authority by its declared cutoff.
                # Its blocked remote invocation cannot starve explicit closure.
                control_started = time.monotonic()
                # Two real publication preparations can take nearly a minute.
                # Choose the complete work window before spawning, then keep
                # that recorded cutoff unchanged through preparation/dispatch.
                cutoff = int(time.time()*1000) + 120000
                saved = admin('provision', cutoff)
                lifetime = {'work_before_ms': cutoff, 'settle_before_ms': cutoff + 120000}
                assert admin('lifetime') == lifetime
                configure(saved, 1, 'unary', 'Unary', 'blocked-control', 'prepare'); invoke()
                saved = admin('own'); configure(saved, 2, 'unary', 'Unary', 'never-dispatched', 'prepare'); invoke()
                assert admin('lifetime') == lifetime
                print(f'RPC control preparation: {time.monotonic()-control_started:.3f}s', flush=True)
                # Hold the RPC across the cutoff, without making fast setup wait
                # through the entire work lifetime inside a network operation.
                while time.time()*1000 < cutoff - 30000:
                    assert time.monotonic()-control_started < 100, 'Clock did not reach the dispatch window'
                    time.sleep(0.1)
                saved = admin('own'); configure(saved, 1, 'unary', 'Unary', 'blocked-control', 'execute')
                boundary.peer_release.clear()
                child = subprocess.Popen([worker, str(config)], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                if not boundary.peer_blocked.wait(timeout=60):
                    code = child.poll()
                    details = child.communicate(timeout=10)[1][-3500:] if code is not None else b''
                    raise AssertionError({'peer_not_reached': code, 'stderr': details})
                print(f'RPC control peer blocked: {time.monotonic()-control_started:.3f}s', flush=True)
                assert admin('forge-observation', 1, expect=False).returncode != 0
                while time.time()*1000 <= cutoff + max_clock_error_ms:
                    assert time.monotonic()-control_started < 140, 'Clock did not reach the declared cutoff'
                    time.sleep(0.1)
                before = len(sends)
                admin('dispatch-expired', 2)
                control_start = time.monotonic(); admin('close', 1)
                close_seconds = time.monotonic()-control_start
                closure = {'close_seconds': round(close_seconds, 3),
                           'worker_exit': child.poll(),
                           'peer_active': blocked_peer['context'].is_active(),
                           'schedule_seconds': round(time.monotonic()-control_started, 3)}
                print('RPC control closure:', json.dumps(closure), flush=True)
                assert close_seconds < 10 and closure['worker_exit'] is None and closure['peer_active'], closure
                assert admin('lifetime') == lifetime
                assert admin('inspect', 1)['effect'] == 'closed_unknown'
                assert admin('close', 1, expect=False).returncode != 0
                admin('terminate')
                assert admin('own', expect=False).returncode != 0
                admin('cancel', 2)
                boundary.close(); child.communicate(timeout=60); assert child.returncode != 0; child = None
                assert len(sends) == before and admin('inspect', 1)['effect'] == 'closed_unknown'
                assert admin('inspect', 2)['effect'] == 'cancelled'
                print('RPC work cutoff, forged observation, blocked-peer control and permanent retirement passed.', flush=True)
            assert not failures, failures
            if not control: assert cold.data_objects() > 0
            profile = 'control' if control else 'faults' if faults else 'shapes'
            print(f"RPC worker {profile}: {len(sends)} sends, {len(applied)} applications.")
            print(f"RPC capture storage: 8 MiB hot limit, {cold.data_objects()} cold objects, {cold.file_bytes()} object-store bytes.")
            print(f"RPC worker proof wall time: {time.monotonic()-started:.2f}s (excludes compilation).")
        finally:
            boundary.close()
            release_capture.set()
            if child is not None and child.poll() is None: child.kill(); child.communicate(timeout=10)
            if authority is not None: authority.kill(); authority.wait(timeout=10)
            proxy.shutdown(); proxy.server_close(); proxy_thread.join(timeout=5)
            peer.stop(0).wait(timeout=5); pool.shutdown(wait=True)
            node_log.seek(0)
            if sys.exc_info()[0]: print(node_log.read()[-6000:], file=sys.stderr)
            node_log.close()
    if faults and not control:
        # Keep the cutoff proof's admission window independent of accumulated
        # capture history from the preceding crash schedules.
        # Both installations use real disk storage; the first proves cold spill.
        run(node, provision, worker, 'faults', control=True)


if __name__ == "__main__":
    run(*sys.argv[1:])

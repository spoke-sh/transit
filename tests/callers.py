"""Infrastructure/fault harness; both application callers are independent Zig programs."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
import time
from harness.ursula import Fixture
from harness.services import free_port, wait_ready


def run(node, cli, counter, byte_log, probe, delivery):
    with Fixture() as store:
        children, logs = [], []
        def start():
            log = (store.root / f"node-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen([str(node), str(config)], stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            wait_ready(store.http, child, url + "/health")
            return child
        def key(name):
            path = store.root / name
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            public = json.loads(subprocess.check_output([str(cli), "public-key", str(path)], timeout=10))
            return path, public
        root, public = key("root.key")
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = store.root / "node.json"
        config.write_text(json.dumps({"genesis": {"realm": 61, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": store.url,
                                      "bucket": "caller-proof", "journal": "authority", "port": port}))
        sequence = 0
        def command(value):
            nonlocal sequence
            sequence += 1
            request = store.root / "request.json"
            request.write_text(json.dumps({"realm": 61, "principal": 0, "sequence": sequence, "command": value}))
            return json.loads(subprocess.check_output([str(cli), "submit", str(root), str(request), url], timeout=10))["position"]
        dropped = {}
        verified_retries = set()
        malformed_views = set()
        malformed_receipts = set()
        rejection_attempts = {}
        rejection_retries = set()
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def unavailable(self):
                body = b"upstream temporarily unavailable"
                self.send_response(503)
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                request = envelope.get("request", envelope.get("query"))
                principal = request["principal"]
                if self.path == "/v1/query" and principal in malformed_views:
                    malformed_views.remove(principal)
                    self.unavailable()
                    return
                connection = HTTPConnection("127.0.0.1", port, timeout=5)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    status = response.status
                    if status == 403 and request.get("command", {}).get("turn", {}).get("effect") is not None:
                        identity = (principal, request["sequence"])
                        if identity not in rejection_attempts:
                            rejection_attempts[identity] = body
                            status, data = 503, b'{"err":"AuthorityUnavailable"}'
                        else:
                            assert body == rejection_attempts[identity], "Rejection retry changed signed bytes"
                            rejection_retries.add(identity)
                    if response.status == 200 and any(kind in request.get("command", {}) for kind in ("turn", "deliver")):
                        if principal not in dropped:
                            dropped[principal] = (body, data, request["sequence"])
                            self.close_connection = True
                            return
                        original, receipt, sequence = dropped[principal]
                        if request["sequence"] == sequence:
                            assert body == original and data == receipt, "Uncertain commit changed identity or receipt"
                            if principal not in malformed_receipts:
                                malformed_receipts.add(principal)
                                self.unavailable()
                                return
                            verified_retries.add(principal)
                    self.send_response(status)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()
        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        try:
            subprocess.run([str(node), str(config), "--initialize"], check=True, timeout=15)
            authority = start()
            # Workload identifiers and data are caller-defined. The node binary
            # and configuration remain identical for both applications.
            pids = [command({"spawn": {"code": 101}}),
                    command({"spawn": {"code": 202}})]
            sink = command({"spawn": {}})
            configs = []
            for index, (pid, initial, expected) in enumerate(zip(pids, [b"7", b"alpha\0"], [b"7", b"alpha\0"]), 1):
                seed, public = key(f"worker-{index}.key")
                command({"grant": {"subject": index, "public_key": public, "permissions": 88, "pid": pid}})
                resource = command({"create_resource": {"writer": pid}})
                command({"grant_resource": {"resource": resource, "subject": index, "permissions": 7}})
                command({"grant_resource": {"resource": resource, "subject": 0, "permissions": 7}})
                association = "counter" if index == 1 else "data"
                command({"associate": {"pid": pid, "name": association.encode().hex(), "resource": resource}})
                command({"own": {"pid": pid, "expected_generation": 1, "worker": index}})
                command({"send": {"pid": pid, "value": initial.hex()}})
                configs.append({"url": f"http://127.0.0.1:{proxy.server_port}", "realm": 61, "principal": index,
                                "pid": pid, "publish_to": pids[1] if index == 1 else sink, "generation": 2, "state_association": association, "seed_file": str(seed),
                                "expected_state": expected.hex(), "consumed": 1})
            def check(index, phase):
                path = store.root / f"probe-{index}.json"
                path.write_text(json.dumps(configs[index]))
                subprocess.run([str(probe), str(path), phase], check=True, timeout=20)
            def call(index, expected_error=None):
                path = store.root / f"example-{index}.json"
                options = {k: v for k, v in configs[index].items() if k not in ("expected_state", "consumed")}
                path.write_text(json.dumps(options))
                first_turn = index + 1 not in verified_retries
                result = subprocess.run([str([counter, byte_log][index]), "--once", str(path)],
                                        capture_output=True, text=True, timeout=20,
                                        env=os.environ | {"LOG_FORMAT": "json", "LOG_LEVEL": "debug"})
                if expected_error:
                    assert result.returncode != 0 and expected_error in result.stderr, result
                    return
                assert result.returncode == 0, result.stderr
                receipt = json.loads(result.stdout)
                assert receipt["position"] > 0
                if first_turn:
                    attempts = [r for line in result.stderr.splitlines()
                                if (r := json.loads(line)).get("event", {}).get("name") == "transit.client.request"
                                and r["event"].get("operation") == "turn"]
                    # The proxy committed before dropping the first response.
                    # Neither transport loss nor a malformed 503 is a rejection.
                    assert len(attempts) == 3, attempts
                    assert [r["event"]["protocol_outcome"] for r in attempts] == ["uncertain", "uncertain", "receipt"]
                    assert attempts[-1]["event"]["position"] == receipt["position"]
                    assert len({r["span_id"] for r in attempts}) == 3
                    assert len({r["parent_span_id"] for r in attempts}) == 1
            for index in range(2):
                check(index, "reject")
                malformed_views.add(index + 1)
                call(index)
                check(index, "verify")
            assert set(dropped) == verified_retries == malformed_receipts == {1, 2}
            assert not malformed_views
            # The runnable courier, not the harness, advances committed outputs.
            seed, courier_public = key("courier.key")
            command({"grant": {"subject": 3, "public_key": courier_public, "permissions": 132}})
            courier_config = store.root / "courier.json"
            courier_config.write_text(json.dumps({"url": f"http://127.0.0.1:{proxy.server_port}", "realm": 61,
                                                 "principal": 3, "seed_file": str(seed), "interval_ms": 20}))
            courier_log = (store.root / "courier.log").open("w+")
            logs.append(courier_log)
            courier = subprocess.Popen([str(delivery), str(courier_config)], stdout=courier_log, stderr=subprocess.STDOUT)
            children.append(courier)
            read = store.root / "sink.json"
            read.write_text(json.dumps({"realm": 61, "principal": 0, "kind": {"process": sink}}))
            deadline = time.monotonic() + 20
            while True:
                sink_view = json.loads(subprocess.check_output([str(cli), "query", str(root), str(read), url], timeout=10))["body"]["process"]
                if sink_view["process"]["admitted"] == 1 and 3 in verified_retries:
                    break
                assert courier.poll() is None and time.monotonic() < deadline, "courier failed to make progress"
                time.sleep(.05)
            courier.kill()
            courier.wait(timeout=10)
            # Readiness and a restarted idle courier do not append or redeliver.
            subprocess.run([str(delivery), str(courier_config), "--check"], check=True, timeout=10)
            subprocess.run([str(delivery), str(courier_config), "--once"], check=True, timeout=10)
            status_query = store.root / "delivery-status.json"
            status_query.write_text(json.dumps({"realm": 61, "principal": 3, "kind": {"delivery": {}}}))
            status = json.loads(subprocess.check_output([str(cli), "query", str(seed), str(status_query), url], timeout=10))
            assert status["body"]["delivery"]["next"] is None and status["principal_sequence"] == 2, status
            source = sink_view["input"]["origin"]["process"]
            assert source["pid"] == pids[1] and source["output"] == 2
            assert sink_view["process"]["admitted"] == 1
            assert sink_view["input"]["value"] == b"alpha\0".hex()
            command({"send": {"pid": pids[0], "value": b"5".hex()}})
            authority.kill()
            authority.wait(timeout=10)
            store.stop()
            store.start()
            authority = start()
            for index, expected in enumerate([b"12", b"alpha\x007"]):
                command({"own": {"pid": pids[index], "expected_generation": 2, "worker": index+1}})
                check(index, "stale")
                call(index, expected_error="StaleActivation")
                configs[index].update(generation=3, expected_state=expected.hex(), consumed=2)
                check(index, "reject")
                call(index)
                check(index, "verify")
            # No application reducer is present during either restart/recovery.
            assert len(rejection_attempts) == len(rejection_retries) == 4
            assert {principal for principal, _ in rejection_retries} == {1, 2}
            authority.kill()
            authority.wait(timeout=10)
            authority = start()
            for index in range(2):
                check(index, "verify")
            # A delayed controller must still be able to read bootstrap evidence.
            # Expected pre-grant denials must not flood its bounded log transport.
            bootstrap_log = (store.root / "bootstrap.log").open("w+b")
            logs.append(bootstrap_log)
            waiting = subprocess.Popen([str(counter), "--bootstrap-json", json.dumps({
                "url": url, "realm": 61, "principal": 4, "pid": sink})],
                stdout=bootstrap_log, stderr=bootstrap_log,
                env=os.environ | {"LOG_FORMAT": "json", "LOG_LEVEL": "debug"})
            children.append(waiting)
            time.sleep(5)
            assert waiting.poll() is None
            waiting.kill()
            waiting.wait(timeout=5)
            captured = Path(bootstrap_log.name).read_bytes()
            assert captured.count(b'"bootstrap":') == 1 and len(captured) < 8192, len(captured)
            print("Runnable counter and byte-log examples: authenticated automatic delivery, courier recovery, opaque state, atomic outputs, lost/malformed responses, stale activation and authority/storage recovery passed.")
        except BaseException:
            for log in logs:
                log.flush()
                print(Path(log.name).read_text()[-4000:])
            raise
        finally:
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            for log in logs:
                log.close()

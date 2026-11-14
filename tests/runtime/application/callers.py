"""Infrastructure/fault harness; both application callers are independent Zig programs."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
import signal
import shutil
from pathlib import Path
import subprocess
import sys
import threading
import time
from harness.ursula import Fixture
from harness.local_installation import ExternalInstallation
from interfaces.installation.server_application_faults import install_peer, publish_evidence


def run(server, cli, counter, byte_log, probe):
    with Fixture() as store:
        children, logs = [], []
        fixture = ExternalInstallation(server, ursula=store.url)
        fixture.config['realm'] = 61
        install_peer(fixture)
        completed = False
        def start():
            fixture.stop()
            fixture.start()
            fixture.ready()
            return fixture.process
        def key(name):
            path = store.root / name
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            public = json.loads(subprocess.check_output([str(cli), "native", "public-key", str(path)], timeout=10))
            return path, public
        root = fixture.installation / 'root.seed'
        port = fixture.config['ports']['node']
        url = fixture.url
        sequence = None
        def command(value):
            nonlocal sequence
            sequence += 1
            request = store.root / "request.json"
            request.write_text(json.dumps({"realm": 61, "principal": 0, "sequence": sequence, "command": value}))
            return json.loads(subprocess.check_output([str(cli), "native", "submit", str(root), str(request), url], timeout=10))["position"]
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
            authority = start()
            basis = store.root / 'capabilities.json'
            basis.write_text(json.dumps(dict(realm=61, principal=0, kind={'capabilities': {}})))
            sequence = json.loads(subprocess.check_output([str(cli), 'native', 'query', str(root), str(basis), url], timeout=10))['principal_sequence']
            fixture.signal_role('/courier.json', signal.SIGSTOP)
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
            # The server owns courier placement and credentials. Its real node
            # fault peer drops one committed receipt and corrupts the next one.
            publish_evidence(fixture.root / 'drop-next', dict(command='deliver', label='callers', principal=22, malformed_once=True))
            (fixture.root / 'release-callers').touch()
            fixture.signal_role('/courier.json', signal.SIGCONT)
            read = store.root / "sink.json"
            read.write_text(json.dumps({"realm": 61, "principal": 0, "kind": {"process": sink}}))
            deadline = time.monotonic() + 20
            while True:
                sink_view = json.loads(subprocess.check_output([str(cli), "native", "query", str(root), str(read), url], timeout=10))["body"]["process"]
                if sink_view["process"]["admitted"] == 1 and (fixture.root / 'retried-callers').exists():
                    break
                assert fixture.process.poll() is None and time.monotonic() < deadline, "server courier failed to make progress"
                time.sleep(.05)
            assert (fixture.root / 'malformed-callers').exists()
            fixture.kill_role('/courier.json')
            fixture.ready()
            # Signed readiness and an idle replacement cannot append/redeliver.
            seed = fixture.installation / 'courier.seed'
            status_query = store.root / "delivery-status.json"
            status_query.write_text(json.dumps({"realm": 61, "principal": 22, "kind": {"delivery": {}}}))
            status = json.loads(subprocess.check_output([str(cli), "native", "query", str(seed), str(status_query), url], timeout=10))
            assert status["body"]["delivery"]["next"] is None and status["principal_sequence"] == 2, status
            source = sink_view["input"]["origin"]["process"]
            assert source["pid"] == pids[1] and source["output"] == 2
            assert sink_view["process"]["admitted"] == 1
            assert sink_view["input"]["value"] == b"alpha\0".hex()
            # Keep the original second-turn oracle isolated from later input
            # delivery. The old fixture stopped its courier here; retain that
            # fault window across manager recovery, then release it below.
            (fixture.root / 'block-delivery').touch()
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
            (fixture.root / 'block-delivery').unlink()
            deadline = time.monotonic() + 20
            while True:
                status = json.loads(subprocess.check_output([str(cli), 'native', 'query', str(seed), str(status_query), url], timeout=10))
                if status['body']['delivery']['next'] is None:
                    break
                assert fixture.process.poll() is None and time.monotonic() < deadline
                time.sleep(.05)
            assert status['principal_sequence'] == 4, status
            for pid, admitted, consumed in ((pids[1], 3, 2), (sink, 2, 0)):
                read.write_text(json.dumps(dict(realm=61, principal=0, kind={'process': pid})))
                view = json.loads(subprocess.check_output([str(cli), 'native', 'query', str(root), str(read), url], timeout=10))['body']['process']
                assert (view['process']['admitted'], view['process']['consumed']) == (admitted, consumed), view
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
            completed = True
        except BaseException:
            for log in logs:
                log.flush()
                print(Path(log.name).read_text()[-4000:])
            raise
        finally:
            fixture.cleanup()
            if completed:
                shutil.rmtree(fixture.root)
            else:
                print(f'Failed server evidence retained: {fixture.root}', file=sys.stderr)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            for log in logs:
                log.close()


if __name__ == '__main__':
    run(*(Path(path).resolve() for path in sys.argv[1:]))

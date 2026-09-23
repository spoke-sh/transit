"""Actual remote sends, paused authorization, bounded closure and no replay I/O."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from wire_values import encode_command, decode_view
import os
from pathlib import Path
import queue
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request

from storage import Fixture, free_port, wait_ready


def run(node, executor, cli):
    with Fixture() as store:
        children, logs, releases, sent = [], [], [], []
        received = queue.Queue()

        class Remote(BaseHTTPRequestHandler):
            def do_POST(self):
                count = int(self.headers["Content-Length"])
                assert 0 < count < 1024
                message = json.loads(self.rfile.read(count))
                release = threading.Event()
                releases.append(release)
                sent.append(message)
                received.put((message, release))
                if not release.wait(15):
                    return
                body = str(message["value"] + 1).encode()
                try:
                    self.send_response(200)
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                except (BrokenPipeError, ConnectionResetError):
                    pass  # Executor deliberately killed after remote acceptance.

            def log_message(self, *_):
                pass

        remote = ThreadingHTTPServer(("127.0.0.1", 0), Remote)
        thread = threading.Thread(target=remote.serve_forever, daemon=True)
        thread.start()

        def invoke(*args):
            return json.loads(subprocess.check_output([str(cli), *map(str, args)], timeout=10))

        def key(name):
            path = store.root / (name + ".key")
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            return path, invoke("public-key", path)

        root, public = key("root")
        executor_key, executor_public = key("executor")
        maintenance_key, maintenance_public = key("maintenance")
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = store.root / "node.json"
        config.write_text(json.dumps({"genesis": {"realm": 52, "root_key": public,
            "retry_policy": "last_per_principal"}, "ursula_url": store.url,
            "bucket": "transit-effect-io", "journal": "authority", "port": port,
            "maintenance": {"principal": 2, "seed_file": str(maintenance_key),
                "interval_ms": 50, "checkpoint_every_records": 4}}))
        sequence = 0

        def request(command, read=False):
            nonlocal sequence
            if not read:
                sequence += 1
            revision = request({"inspect": command["turn"]["pid"]}, read=True)["process"]["revision"] if "turn" in command else 0
            command = encode_command(command, revision)
            path = store.root / "request.json"
            path.write_text(json.dumps({"realm": 52, "principal": 0,
                "sequence": 0 if read else sequence, "command": command}))
            signed = invoke("sign", root, path)
            for _ in range(30):
                try:
                    response = store.http.open(urllib.request.Request(
                        url + ("/v2/view" if read else "/v2/command"), json.dumps(signed).encode(),
                        {"Content-Type": "application/json"}), timeout=5)
                except urllib.error.HTTPError as error:
                    response = error
                with response:
                    value = decode_view(json.load(response))
                    if response.status == 409:
                        time.sleep(0.05)
                        continue
                    assert response.status == 200, (response.status, value)
                    return value
            raise TimeoutError("Synthetic proof authority conflict")

        def command(value):
            return request(value)["position"]

        def start(binary, *args):
            log = (store.root / f"effect-child-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen([str(binary), *map(str, args)], stdin=subprocess.PIPE,
                stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            return child, log

        def stop(child):
            if child.poll() is None:
                child.kill()
            child.wait(timeout=10)

        def effect_view(pid):
            return next(effect for effect in request({"inspect": pid}, read=True)["effects"] if effect)

        def retained():
            try:
                with store.http.open(store.url + "/transit-effect-io/authority?record=0&max_records=1", timeout=2):
                    return True
            except urllib.error.HTTPError as error:
                assert error.code == 410
                return False

        try:
            authority, _ = start(node, config, "--bootstrap")
            wait_ready(store.http, authority, url + "/health")
            command({"grant": {"subject": 1, "public_key": executor_public, "permissions": 48}})
            command({"grant": {"subject": 2, "public_key": maintenance_public, "permissions": 33}})
            cases = []
            for scenario in ("success", "pause_before_send", "late_response", "crash_after_send"):
                pid = command({"spawn": {"allow_trim": True}})
                command({"own": {"pid": pid, "worker": 0, "expected_generation": 0}})
                input_id = command({"send": {"pid": pid, "value": 7}})
                effect = command({"turn": {"pid": pid, "generation": 1,
                    "input": input_id, "result": 7, "effect": 7}})
                options = store.root / (scenario + ".json")
                options.write_text(json.dumps({"authority": url, "endpoint": f"http://127.0.0.1:{remote.server_port}/attempt",
                    "realm": 52, "pid": pid, "principal": 1, "seed_file": str(executor_key), "effect": effect}))
                child, log = start(executor, options)
                limit = time.monotonic() + 10
                while True:
                    log.seek(0)
                    line = log.readline()
                    if line.startswith("authorized "):
                        attempt = int(line.split()[1])
                        break
                    assert child.poll() is None, line
                    assert time.monotonic() < limit
                    time.sleep(0.02)
                assert effect_view(pid)["phase"] == "authorized"
                before_sends = len(sent)
                # Ownership loss never authorizes a new external attempt.
                command({"own": {"pid": pid, "worker": 0, "expected_generation": 1}})
                if scenario == "pause_before_send":
                    command({"close_effect": {"pid": pid, "effect": effect, "attempt": attempt}})
                    assert len(sent) == before_sends
                child.stdin.write(b"\n")
                child.stdin.flush()
                body, release = received.get(timeout=5)
                assert body == {"effect": effect, "attempt": attempt, "value": 7}
                if scenario == "crash_after_send":
                    stop(child)
                if scenario in ("late_response", "crash_after_send"):
                    command({"close_effect": {"pid": pid, "effect": effect, "attempt": attempt}})
                release.set()
                assert (child.wait(timeout=10) == 0) == (scenario == "success")
                if scenario in ("pause_before_send", "late_response"):
                    assert "error: Rejected" in Path(log.name).read_text()
                view = request({"inspect": pid}, read=True)
                assert view["process"]["admitted"] == (2 if scenario == "success" else 1)
                assert view["process"]["state"] == 7
                assert effect_view(pid)["phase"] == ("observed" if scenario == "success" else "closed_unknown")
                assert len(sent) == before_sends + 1
                # A fresh executor cannot turn a historical dispatch into a send.
                duplicate, duplicate_log = start(executor, options)
                assert duplicate.wait(timeout=10) != 0
                assert "AttemptAlreadyAuthorized" in Path(duplicate_log.name).read_text()
                assert len(sent) == before_sends + 1
                command({"terminate": pid})
                cases.append((pid, options, effect_view(pid)))

            maintenance, _ = start(node, config, "--maintain")
            limit = time.monotonic() + 15
            while retained():
                assert maintenance.poll() is None
                assert time.monotonic() < limit
                time.sleep(0.05)
            stop(maintenance)
            stop(authority)
            store.stop()
            store.start()
            authority, _ = start(node, config)
            wait_ready(store.http, authority, url + "/health")
            for pid, options, expected in cases:
                assert effect_view(pid) == expected
                duplicate, log = start(executor, options)
                assert duplicate.wait(timeout=10) != 0
                assert "AttemptAlreadyAuthorized" in Path(log.name).read_text()
            assert len(sent) == 4  # Replay/trim/restart made no remote calls.
            print("Synthetic I/O: paused dispatch, late result rejection, unknown closure and replay without redispatch passed.")
        except BaseException:
            for log in logs:
                sys.stderr.write(Path(log.name).read_text()[-4000:])
            raise
        finally:
            for release in releases:
                release.set()
            for child in children:
                stop(child)
                child.stdin.close()
            for log in logs:
                log.close()
            remote.shutdown()
            remote.server_close()
            thread.join(timeout=5)

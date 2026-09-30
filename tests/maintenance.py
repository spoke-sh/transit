"""Background expiry and reclamation while an independent authority stays live."""
import json
from wire_values import encode_command
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
import urllib.error
import urllib.request

from storage import Fixture, free_port, wait_ready


def run(node, cli):
    with Fixture() as store:
        children, logs = [], []

        def key(name):
            path = store.root / (name + ".key")
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            public = json.loads(subprocess.check_output([str(cli), "public-key", str(path)], timeout=10))
            return path, public

        root, public = key("root")
        maint_key, maint_public = key("maintenance")
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = store.root / "node.json"
        genesis = {"realm": 51, "root_key": public, "allow_history_trim": True}
        if sys.platform == "linux":
            # A synchronized host can report >1s near the end of its NTP poll interval.
            genesis["max_clock_error_ms"] = 2000
        config.write_text(json.dumps({"genesis": genesis, "ursula_url": store.url,
            "bucket": "transit-maintenance", "journal": "authority", "port": port,
            "maintenance": {"principal": 1, "seed_file": str(maint_key), "interval_ms": 50,
                            "operation_timeout_ms": 2000, "checkpoint_every_records": 4}}))

        def start(*args):
            log = (store.root / f"maintenance-child-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen([str(node), str(config), *args], stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            return child

        sequence = 0

        def request(command, read=False, expected=200):
            nonlocal sequence
            if not read:
                sequence += 1
            revision = request({"process": command["turn"]["pid"]}, read=True)["process"]["revision"] if "turn" in command else 0
            command = encode_command(command, revision)
            path = store.root / "request.json"
            envelope = {"realm": 51, "principal": 0, "kind": {"inspection": {"resource": "process", "pid": command["process"]}}} if read else {"realm": 51, "principal": 0, "sequence": sequence, "command": command}
            path.write_text(json.dumps(envelope))
            body = subprocess.check_output([str(cli), "sign-query" if read else "sign", str(root), str(path)], timeout=10)
            for _ in range(40):
                try:
                    response = store.http.open(urllib.request.Request(url + ("/v1/query" if read else "/v1/command"), body,
                        {"Content-Type": "application/json"}), timeout=5)
                except urllib.error.HTTPError as error:
                    response = error
                with response:
                    value = json.load(response)
                    if response.status in (409, 503):
                        time.sleep(0.05)
                        continue
                    assert response.status == expected, (response.status, value)
                    return {"process": value["body"]["inspection"]["processes"][0]} if read and response.status == 200 else value
            raise TimeoutError(f"Maintenance proof authority/clock unavailable: {value}")

        def retained():
            # Read the genesis record through the same record coordinate API.
            endpoint = store.url + "/transit-maintenance/authority?record=0&max_records=1"
            try:
                with store.http.open(endpoint, timeout=2) as response:
                    return response.status != 410
            except urllib.error.HTTPError as error:
                if error.code == 410:
                    return False
                raise

        try:
            authority = start("--bootstrap")
            wait_ready(store.http, authority, url + "/health")
            request({"grant": {"subject": 1, "public_key": maint_public, "permissions": 161}})
            policy = {}
            if sys.platform == "linux":
                deadline = int(time.time() * 1000) + 5000
                policy.update(work_before_ms=deadline, settle_before_ms=deadline + 1000)
            pid = request({"spawn": policy})["position"]
            request({"send": {"pid": pid, "value": 7}})
            maintenance = start("--maintain")
            if sys.platform != "linux":
                request({"terminate": pid})
            limit = time.monotonic() + 25
            while True:
                view = request({"process": pid}, read=True)
                if view["process"]["lifecycle"] != "running" and not retained():
                    break
                assert time.monotonic() < limit, view
                assert maintenance.poll() is None
                time.sleep(0.1)
            assert view["process"]["cancelled"] == 1
            # The HTTP authority never restarted during another process's trim.
            assert authority.poll() is None
            # A stalled storage peer must not trap maintenance inside a scan.
            # Observe two deadlines to prove the bounded loop resumes afterward.
            maintenance_log = Path(logs[-1].name)
            timeouts = maintenance_log.read_text().count('"error_type":"MaintenanceTimeout"')
            store.server.send_signal(signal.SIGSTOP)
            try:
                limit = time.monotonic() + 8
                while maintenance_log.read_text().count('"error_type":"MaintenanceTimeout"') < timeouts + 2:
                    assert maintenance.poll() is None
                    assert time.monotonic() < limit, maintenance_log.read_text()
                    time.sleep(0.05)
            finally:
                store.server.send_signal(signal.SIGCONT)
            assert request({"process": pid}, read=True)["process"] == view["process"]
            for child in (authority, maintenance):
                child.kill()
                child.wait(timeout=10)
            store.stop()
            store.start()
            authority = start()
            wait_ready(store.http, authority, url + "/health")
            restored = request({"process": pid}, read=True)
            assert restored["process"]["lifecycle"] == ("expired" if sys.platform == "linux" else "terminated")
            rejection = request({"own": {"pid": pid, "worker": 1, "expected_generation": 0}}, expected=422)
            assert rejection["err"] == "RetiredProcess", rejection
            print("Background retirement, checkpoint/trim, live catch-up and permanent retirement passed.")
        except BaseException:
            for log in logs:
                sys.stderr.write(Path(log.name).read_text()[-5000:])
            raise
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            for log in logs:
                log.close()

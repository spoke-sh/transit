"""Independent maintenance deletes opted-in immutable payloads, keeping evidence."""
import json
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request

from storage import Fixture, free_port, wait_ready


def run(node, cli, proof):
    with Fixture() as store:
        subprocess.run([str(proof), store.url, "service_seed"], check=True, timeout=30)
        # Public test vector matching the isolated fixture's genesis, never a
        # deployment credential. Keep the same private-file transport as services.
        seed = store.root / "seed"
        seed.write_text("15" * 32)
        seed.chmod(0o600)
        public = json.loads(subprocess.check_output([str(cli), "public-key", str(seed)], timeout=10))
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = store.root / "node.json"
        config.write_text(json.dumps({"genesis": {"realm": 54, "root_key": public, "allow_history_trim": True},
            "ursula_url": store.url, "bucket": "transit-deletion", "journal": "authority", "port": port,
            "maintenance": {"principal": 0, "seed_file": str(seed), "interval_ms": 50, "checkpoint_every_records": 4}}))
        request = store.root / "request.json"
        request.write_text(json.dumps({"realm": 54, "principal": 0, "kind": {"inspection": {"resource": "payloads", "pid": 1}}}))
        signed = subprocess.check_output([str(cli), "sign-query", str(seed), str(request)], timeout=10)
        children, logs = [], []
        try:
            for args in ([], ["--maintain"]):
                log = (store.root / f"deletion-{len(logs)}.log").open("w+")
                logs.append(log)
                children.append(subprocess.Popen([str(node), str(config), *args], stdout=log, stderr=subprocess.STDOUT))
            wait_ready(store.http, children[0], url + "/health")
            limit = time.monotonic() + 20
            while True:
                try:
                    response = store.http.open(urllib.request.Request(url + "/v1/query", signed,
                        {"Content-Type": "application/json"}), timeout=5)
                except urllib.error.HTTPError as error:
                    assert error.code == 409
                    time.sleep(0.05)
                    continue
                with response:
                    view = json.load(response)["body"]["inspection"]
                payloads = {value["id"]: value for value in view["payloads"] if value}
                if payloads[2]["phase"] == "deleted":
                    assert payloads[3]["phase"] == "ready"
                    break
                assert all(child.poll() is None for child in children)
                assert time.monotonic() < limit, view
                time.sleep(0.05)
            subprocess.run([str(proof), store.url, "service_verify"], check=True, timeout=30)
            print("Background payload retirement/deletion preserves tombstones and unlimited-retention bytes.")
        except BaseException:
            for log in logs:
                sys.stderr.write(Path(log.name).read_text()[-4000:])
            raise
        finally:
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            for log in logs:
                log.close()

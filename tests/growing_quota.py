"""Finite service reserve with real Station pending work and disk replacement."""
import json
import os
from pathlib import Path
import subprocess
import sys

from storage import Fixture, free_port, wait_ready


def run(node, caller):
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    if hasattr(os, "sched_getaffinity"):
        os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    public = json.loads(subprocess.check_output([caller, "public"], timeout=10))
    with Fixture() as fixture:
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = fixture.root / "node.json"
        config.write_text(json.dumps({"profile": "native_v1", "genesis": {
            "realm": 45, "root_key": public, "max_clock_error_ms": 10000,
            "admission_ceiling": 24, "control_reserve": 4},
            "ursula_url": fixture.url, "bucket": "growing-quota", "journal": "authority",
            "port": port, "resident_pages": 1, "request_timeout_ms": 10000}))
        pending = fixture.root / "pending.json"
        with (fixture.root / "node.log").open("w+") as log:
            subprocess.run([node, str(config), "--initialize"], stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=20)
            for phase in ("write", "recover"):
                if phase == "recover":
                    fixture.start()
                authority = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                try:
                    wait_ready(fixture.http, authority, url + "/health")
                    subprocess.run([caller, url, phase, str(pending)], check=True, timeout=90)
                except BaseException:
                    log.flush()
                    log.seek(0)
                    sys.stderr.write(log.read()[-12000:])
                    raise
                finally:
                    authority.kill()
                    authority.wait(timeout=10)
                fixture.stop()
    print("Growing service/Station: explicit quota, retained pending request/backlog, reserve use and disk restart passed.")


if __name__ == "__main__":
    run(*sys.argv[1:])

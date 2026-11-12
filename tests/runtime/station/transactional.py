"""Installed private behavior and replacement schedules; preserve failed owners."""
import json
import os
from pathlib import Path
import signal
import subprocess
import time

from runner.capture import identity, provenance
from runner.paths import ROOT


CASES = ("small", "large", "head", "begin", "claim", "input", "acquire", "dispatch",
         "draft", "staged", "executed", "decision", "cleared", "poison", "exception",
         "capacity", "stop", "stale")
FAULTS = CASES[2:13]


def exercise(node, caller, root, profile, url, restart):
    selected = os.environ.get("TRANSIT_STATION_TRANSACTION_CASES")
    cases = tuple(selected.split(",")) if selected else CASES
    assert cases and all(case in CASES for case in cases)
    outcomes = []
    for case in cases:
        def command(phase):
            return [caller, url, f"station-transaction-{phase}-{case}", str(profile)]
        subprocess.run(command("setup"), check=True, timeout=180)
        saved = Path(f"{profile}.station-{case}")
        original = saved.read_bytes()
        if case in FAULTS:
            marker = Path(f"{saved}.ready")
            with (root / f"actor-{case}.log").open("w") as output:
                child = subprocess.Popen(command("execute"), stdout=output, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 180
                    while not marker.exists():
                        if child.poll() is not None:
                            raise RuntimeError(f"Actor {case} exited before its interruption boundary; see {root}")
                        if time.monotonic() >= deadline:
                            raise TimeoutError(f"Actor {case} did not reach its interruption boundary")
                        time.sleep(0.025)
                    assert json.loads(marker.read_text()) == {"point": case}
                    child.kill()
                    assert child.wait(timeout=15) == -signal.SIGKILL
                finally:
                    if child.poll() is None:
                        child.kill()
                        child.wait(timeout=15)
        else:
            subprocess.run(command("execute"), check=True, timeout=180)
        restart()
        subprocess.run(command("recover"), check=True, timeout=180)
        subprocess.run(command("verify"), check=True, timeout=180)
        restart()
        subprocess.run(command("verify"), check=True, timeout=180)
        assert saved.read_bytes() == original
        outcomes.append(dict(case=case, worker_sigkill=case in FAULTS,
                             owner_sigkill_restarts=2, replacement_principal=1000 + CASES.index(case),
                             original_binding_unchanged=True, passed=True))
    print(json.dumps(dict(profile="private_transactional_station", source=provenance(ROOT),
                          binaries=[identity(Path(path)) for path in (node, caller)],
                          complete=cases == CASES, outcomes=outcomes, passed=True)))

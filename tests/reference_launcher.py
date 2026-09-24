"""Persistent reference/update qualification in a newly owned installation."""
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "launchers"))
from common import lock
from kubernetes import Reference, ReferenceInstallation
from launcher_updates import candidate
from launchers import ports


def run():
    installation = ReferenceInstallation("update-" + secrets.token_hex(3), ports())
    launcher = Reference(installation)
    env = {k: v for k, v in os.environ.items() if not k.startswith("REY_") and k not in ("LOG_LEVEL", "LOG_FORMAT")}

    def invoke(action, *args, settings=None):
        result = subprocess.run([sys.executable, "-B", str(ROOT / "launchers/main.py"), "reference", action,
            "--name", installation.name, "--base-port", str(installation.base_port), *args], env={**env, **(settings or {})}, text=True, capture_output=True, timeout=1200)
        if result.returncode:
            raise RuntimeError(result.stdout[-3000:] + result.stderr[-5000:])
        return result.stdout

    def observe(value):
        return launcher.await_process(lambda p: bytes.fromhex(p["state"]).decode() == str(value), "counter state " + str(value))

    def pods():
        return {p["metadata"]["labels"].get("app.kubernetes.io/component"): p["metadata"]["uid"]
            for p in json.loads(launcher.kube("get", "pods", "-l", "app.kubernetes.io/instance=transit", "-o", "json", capture=True))["items"]}

    try:
        invoke("up")
        first = observe(12)
        before = pods()
        invoke("build", "board")
        assert pods() == before
        assert "no changes" in invoke("update", "board", "--no-build")
        candidate(installation, "transit-board")
        invoke("update", "board", "--no-build")
        after = pods()
        assert after["board"] != before["board"]
        assert all(after[role] == before[role] for role in ("node", "ursula", "maintenance", "controller"))
        assert observe(12)["generation"] == first["generation"]
        # Admit work with the old execution stopped; it must survive the switch.
        with lock(installation.lifecycle_lock):
            launcher.stop_workload("proof-pause")
            installation.command("queued-input", {"send": {"pid": first["pid"], "value": b"3".hex()}})
        candidate(installation, "example-counter")
        invoke("update", "counter", "--no-build")
        upgraded = observe(15)
        assert upgraded["pid"] == first["pid"]
        assert upgraded["binding"]["incarnation"] == first["binding"]["incarnation"]
        assert upgraded["binding"]["workload"] != first["binding"]["workload"]
        assert upgraded["binding"]["activation"]["worker_incarnation"] != first["binding"]["activation"]["worker_incarnation"]
        assert upgraded["generation"] > first["generation"]
        assert upgraded["consumed"] == first["consumed"] + 1
        assert "no changes" in invoke("update", "counter", "--no-build")
        invoke("send", "4", "--request-id", "after-upgrade")
        settled = observe(19)
        invoke("restart", "node")
        assert observe(19)["revision"] == settled["revision"]
        invoke("down")
        assert not launcher.services()
        assert "Counter template settings retained" in invoke("up", settings={"REY_COUNTER_LOG_LEVEL": "debug"})
        assert installation.load()["observability"]["counter"]["level"] == "info"
        recovered = observe(19)
        assert recovered["pid"] == first["pid"] and recovered["revision"] == settled["revision"]
        assert recovered["binding"]["incarnation"] == first["binding"]["incarnation"]
        assert recovered["binding"]["workload"] == upgraded["binding"]["workload"]
        assert recovered["binding"]["activation"]["worker_incarnation"] != upgraded["binding"]["activation"]["worker_incarnation"]
        invoke("down")
        invoke("reset")
    except BaseException:
        print("Reference launcher failure evidence retained at " + str(installation.path), file=sys.stderr)
        raise
    print("Reference launcher: complete stack, isolated Board update, same PID/Actor image upgrade with queued input, authority restart and stop/start recovery passed.")


if __name__ == "__main__":
    run()

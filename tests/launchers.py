#!/usr/bin/env python3
"""Exercise the real persistent launchers in an isolated, owned installation."""
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import sys
import time
import urllib.error

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "launchers"))
from common import Installation, write
from compose import Compose
from local import Local


def ports():
    for _ in range(100):
        listeners = []
        try:
            base = 22000 + secrets.randbelow(30000)
            for port in range(base, base + 3):
                listener = socket.socket()
                listeners.append(listener)
                listener.bind(("127.0.0.1", port))
            return base
        except OSError:
            pass
        finally:
            for listener in listeners:
                listener.close()
    raise RuntimeError("No free port range")


def proof(profile):
    os.umask(0o077)
    installation = Installation(profile, "proof-" + secrets.token_hex(3), ports())
    launcher = Local(installation) if profile == "local" else Compose(installation)

    def invoke(action, *args, success=True):
        command = [sys.executable, "-B", ROOT / "launchers/main.py", profile, action,
                   "--name", installation.name, "--base-port", str(installation.base_port), *args]
        result = subprocess.run(list(map(str, command)), cwd=ROOT, text=True, capture_output=True, timeout=600)
        if (result.returncode == 0) != success:
            raise AssertionError((command, result.returncode, result.stdout[-4000:], result.stderr[-4000:]))
        return result.stdout

    def observe(expected=None):
        deadline = time.monotonic() + 30
        last = None
        while time.monotonic() < deadline:
            try:
                page = installation.inspect()["observation"]
                rows = [p for p in page["processes"] if p]
                assert len(rows) == 1 and page["reader"]["permissions"] == 16, page
                last = rows[0]
                if expected is None or bytes.fromhex(last["state"]).decode() == str(expected):
                    return last
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                pass
            time.sleep(.2)
        raise AssertionError((expected, last))

    completed = False
    try:
        with socket.socket() as occupied:
            occupied.bind(("127.0.0.1", installation.base_port))
            occupied.listen()
            invoke("up", success=False)
            assert not launcher.services()
        invoke("up")
        first = observe(12)
        assert first["consumed"] == first["admitted"] == 2 and first["binding"] is None
        endpoints = json.loads(invoke("endpoints"))
        assert endpoints["board"] == installation.origin
        assert len(json.loads(invoke("status"))["services"]) >= 5
        invoke("reset", success=False)
        invoke("up", success=False)
        # Credentials must stay out of machine-readable output and service logs.
        access = (installation.path / "board/access.key").read_text()
        assert access not in json.dumps(endpoints)
        assert installation.path.stat().st_mode & 0o077 == 0
        credentials = []
        for path in installation.path.rglob("*.key"):
            assert path.stat().st_mode & 0o077 == 0, path
            credentials.append(path.read_text())
        for service in ("ursula", "node", "maintenance", "counter", "board"):
            output = invoke("logs", service)
            assert all(key not in output for key in credentials)
        admitted = json.loads(invoke("send", "9", "--request-id", "same-input"))
        retry = json.loads(invoke("send", "9", "--request-id", "same-input"))
        assert admitted == retry
        invoke("send", "8", "--request-id", "same-input", success=False)
        before = observe(21)
        assert before["admitted"] == before["consumed"] == 3
        # Keep an old caller's actual credentials/config, then stop that caller
        # and accumulate accepted input before replacing its activation.
        old_key = installation.path / "operator/old-worker.key"
        write(old_key, (installation.path / "counter/seed.key").read_text())
        old = json.loads((installation.path / "counter/config.json").read_text())
        old.update(url=installation.url, seed_file=str(old_key))
        old_config = installation.path / "operator/old-worker.json"
        write(old_config, old)
        if profile == "local":
            launcher.pc("process", "stop", "counter", capture=True)
        else:
            launcher.docker("stop", "counter", capture=True)
        invoke("send", "4", "--request-id", "pending-input")
        pending = observe(21)
        assert pending["admitted"] == 4 and pending["consumed"] == 3
        invoke("restart", "counter")
        current = observe(25)
        assert current["pid"] == first["pid"] and current["generation"] > before["generation"]
        rejected = subprocess.run([ROOT / "zig-out/bin/example-counter", "--once", old_config],
                                  capture_output=True, timeout=15)
        assert rejected.returncode != 0 and b"AccessDenied" in rejected.stderr, rejected.stderr
        # Simulate interruption after durable acceptance but before the local
        # operator saves its receipt: resume exactly the last signed request.
        state = json.loads((installation.path / "operator/sequence.json").read_text())
        receipts = [json.loads(p.read_text()) for p in (installation.path / "operator/receipts").glob("*.json")]
        last = next(r for r in receipts if r["request"]["sequence"] == state["sequence"])
        write(installation.path / "operator/sequence.json", {"sequence": state["sequence"] - 1,
              "pending": {"id": last["id"], "request": last["request"]}})
        invoke("send", "9", "--request-id", "same-input")
        assert observe(25)["admitted"] == 4
        root_key = (installation.path / "operator/root.key").read_bytes()
        invoke("down")
        assert installation.manifest.exists() and not launcher.services()
        invoke("up")
        recovered = observe(25)
        assert recovered["pid"] == first["pid"] and recovered["generation"] > current["generation"]
        assert recovered["consumed"] == recovered["admitted"] == 4
        assert (installation.path / "operator/root.key").read_bytes() == root_key
        assert (installation.path / "board/access.key").read_text() == access
        for service in ("ursula", "node", "board"):
            invoke("restart", service)
            assert observe(25)["pid"] == first["pid"]
        invoke("down")
        # An established installation with missing WAL must fail recovery.
        # It must not take the initial --initialize path or allocate new PIDs.
        saved_wal = installation.path / "saved-wal"
        (installation.path / "wal").rename(saved_wal)
        (installation.path / "wal").mkdir(mode=0o700)
        invoke("up", success=False)
        assert (installation.path / "initialized.json").exists()
        invoke("down")
        shutil.rmtree(installation.path / "wal")
        saved_wal.rename(installation.path / "wal")
        invoke("up")
        assert observe(25)["pid"] == first["pid"]
        installation.command("retire-counter", {"terminate": first["pid"]})
        assert observe(25)["lifecycle"] == "terminated"
        invoke("restart", "counter", success=False)
        assert observe(25)["lifecycle"] == "terminated"
        invoke("down")
        invoke("reset")
        assert not installation.path.exists()
        print(f"{profile}: persistent restart, bounded inspection, exact retries, fresh ownership and missing-store refusal passed.")
        completed = True
    finally:
        if installation.manifest.exists():
            if not completed and profile == "compose":
                result = subprocess.run(["docker", "compose", "--project-name", installation.load()["project"],
                    "--file", installation.path / "compose.json", "logs", "--no-color", "--tail", "100"],
                    capture_output=True, text=True, timeout=30)
                write(installation.path / "failure.log", result.stdout + result.stderr)
            try:
                launcher.down()
            except Exception:
                print(f"Cleanup incomplete; inspect {installation.path}", file=sys.stderr)
                raise
            if completed and not launcher.services():
                shutil.rmtree(installation.path)
            elif not completed:
                print(f"Failure evidence retained at {installation.path}", file=sys.stderr)


if __name__ == "__main__":
    proof(sys.argv[1])

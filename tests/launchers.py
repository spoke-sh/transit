#!/usr/bin/env python3
"""Exercise the real persistent launchers in an isolated, owned installation."""
import json
from http.client import HTTPConnection
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

    def invoke(action, *args, success=True, settings=None):
        command = [sys.executable, "-B", ROOT / "launchers/main.py", profile, action,
                   "--name", installation.name, "--base-port", str(installation.base_port), *args]
        # A developer's .env must never redirect proof resources or publish
        # credentials on their chosen development listener.
        env = {k: v for k, v in os.environ.items() if not k.startswith(("REY_BOARD_", "REY_LAUNCHER_"))}
        env.update(settings or {})
        result = subprocess.run(list(map(str, command)), cwd=ROOT, env=env, text=True, capture_output=True, timeout=600)
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
        # Change the endpoint of an existing installation, without resetting its
        # identity/history. Public DNS and probe transport are distinct.
        board_port = ports()
        remote_origin = f"http://devbox.local:{board_port}"
        remote = {"REY_BOARD_HOST": "0.0.0.0", "REY_BOARD_PORT": str(board_port),
                  "REY_BOARD_PUBLIC_ORIGIN": remote_origin, "REY_BOARD_ALLOW_INSECURE_HTTP": "true"}
        saved_manifest = installation.manifest.read_bytes()
        invoke("up", success=False, settings=remote)
        assert installation.manifest.read_bytes() == saved_manifest
        invoke("down")
        for invalid in ({**remote, "REY_BOARD_ALLOW_INSECURE_HTTP": "false"},
                        {**remote, "REY_BOARD_PORT": str(installation.base_port)},
                        {**remote, "REY_BOARD_PUBLIC_ORIGIN": "http://user@devbox.local"}):
            invoke("up", success=False, settings=invalid)
            assert installation.manifest.read_bytes() == saved_manifest
        invoke("up", settings=remote)
        assert observe(25)["pid"] == first["pid"]
        assert installation.origin == remote_origin
        assert installation.board["port"] == board_port and installation.board["host"] == "0.0.0.0"
        config = json.loads((installation.path / "node.json").read_text())
        if profile == "local":
            assert config["listen"] == "127.0.0.1"
            # A direct health check used to succeed while the manager's probe
            # failed with 403 and terminated Board after ~30 seconds. Require
            # the manager's readiness and survive that original failure window.
            deadline = time.monotonic() + 32
            while time.monotonic() < deadline:
                managed = next(row for row in launcher.services() if row["name"] == "board")
                assert managed["is_running"] and managed["is_ready"] == "Ready", managed
                time.sleep(.5)
        else:
            topology = json.loads((installation.path / "compose.json").read_text())
            assert topology["services"]["board"]["ports"][0]["host_ip"] == "0.0.0.0"
            for service in ("node", "ursula"):
                assert topology["services"][service]["ports"][0]["host_ip"] == "127.0.0.1"
        authority = f"devbox.local:{board_port}"
        def remote_request(path, *, host=authority, origin=remote_origin, method="GET", auth=True):
            headers = {"Host": host, "Origin": origin}
            if auth:
                headers["Authorization"] = "Bearer " + access
            connection = HTTPConnection("127.0.0.1", board_port, timeout=5)
            try:
                connection.request(method, path, headers=headers)
                response = connection.getresponse()
                response.read()
                return response.status, dict(response.getheaders())
            finally:
                connection.close()
        assert remote_request("/health", auth=False)[0] == 200
        assert remote_request("/health", host="evil.example")[0] == 403
        assert remote_request("/health", origin="http://evil.example")[0] == 403
        assert remote_request("/api/v1/processes", auth=False)[0] == 401
        status, headers = remote_request("/api/v1/session", method="POST")
        assert status == 200 and "HttpOnly" in headers["set-cookie"] and "SameSite=Strict" in headers["set-cookie"]
        assert "Secure" not in headers["set-cookie"]
        assert (installation.path / "operator/root.key").read_bytes() == root_key
        invoke("restart", "board")
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
        print(f"{profile}: persistence, retries, fencing, retirement, missing-store refusal and configurable Board origin/auth passed.")
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

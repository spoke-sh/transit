#!/usr/bin/env python3
"""Exercise the real persistent launchers in an isolated, owned installation."""
from runner.paths import ROOT
import json
from http.client import HTTPConnection
import os
from pathlib import Path
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import time
import urllib.error
import yaml

sys.path.insert(0, str(ROOT / "launchers"))
from common import Installation, write
from compose import Compose
from local import Local


def ports():
    # Builds can take minutes between selection and bind. Stay outside the OS
    # ephemeral range so unrelated outbound HTTP cannot claim a chosen listener.
    ephemeral = Path("/proc/sys/net/ipv4/ip_local_port_range")
    lower, upper = map(int, ephemeral.read_text().split()) if ephemeral.exists() else (49152, 65535)
    candidates = [port for port in range(20000, 65533) if port + 2 < lower or port > upper]
    for _ in range(100):
        listeners = []
        try:
            base = secrets.choice(candidates)
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
        if action == "up":
            command.append("--detach")
        # A developer's .env must never redirect proof resources or publish
        # credentials on their chosen development listener.
        env = {k: v for k, v in os.environ.items() if not k.startswith("TRANSIT_") and k not in ("LOG_LEVEL", "LOG_FORMAT")}
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
                # Wait for the example value before sampling process progress.
                # A turn can commit between these independent reads; returning
                # an earlier process row after observing its new value races
                # the caller's consumed/admitted assertions.
                value = installation.counter_value() if expected is not None else None
                page = installation.inspect()["observation"]
                rows = [p for p in page["processes"] if p]
                assert len(rows) == 1 and page["reader"]["permissions"] == 16, page
                last = rows[0]
                if expected is None or value == expected:
                    return last
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                pass
            time.sleep(.2)
        raise AssertionError((expected, last))

    completed = False
    try:
        # Prepare identified binaries under the launcher's build budgets before
        # the startup/fault deadlines. A cold ReleaseSafe build can outlast an
        # invocation's runtime budget; it is not evidence of failed readiness.
        installation.artifacts.initialize()
        with socket.socket() as occupied:
            occupied.bind(("127.0.0.1", installation.base_port))
            occupied.listen()
            invoke("up", success=False)
            assert not launcher.services()
        invoke("up", settings={"TRANSIT_LOG_FORMAT": "json", "TRANSIT_NODE_LOG_LEVEL": "debug"})
        first = observe(12)
        assert installation.load()["observability"]["node"]["level"] == "debug"
        time.sleep(.1)
        visible = invoke("logs", "board")
        assert 'board.http.request' in visible and '"route":"/api/v1/processes"' in visible
        if profile == "local":
            config = yaml.safe_load((ROOT / "process-compose.yaml").read_text())
            assert config["processes"]["board"]["log_configuration"]["rotation"]["max_size_mb"] == 5
            # Exercise the owned background manager-log retention process.
            for _ in range(3):
                with (installation.path / "manager.log").open("ab") as log:
                    log.write(b"rotation-proof\n" * 400000)
                limit = time.monotonic() + 5
                while (installation.path / "manager.log").stat().st_size >= 5 * 1024 * 1024:
                    assert time.monotonic() < limit
                    time.sleep(.05)
            assert (installation.path / "manager.log.1").stat().st_size <= 5 * 1024 * 1024
            assert (installation.path / "manager.log.2").stat().st_size <= 5 * 1024 * 1024
        else:
            config = json.loads(launcher.docker("config", "--format", "json", capture=True))
            assert config["services"]["node"]["environment"]["LOG_LEVEL"] == "debug"
            assert config["services"]["board"]["logging"]["options"]["max-size"] == "5m"
        assert first["consumed"] == first["admitted"] == 2 and first["binding"] is None, first
        from interfaces.deployment.launcher_updates import exercise
        exercise(installation, launcher, invoke, observe)
        first = observe(12)
        endpoints = json.loads(invoke("endpoints"))
        assert endpoints["board"] == installation.origin
        assert len(json.loads(invoke("status"))["services"]) >= 5
        invoke("reset", success=False)
        invoke("up", success=False)
        # Credentials must stay out of machine-readable output and service logs.
        assert not (installation.path / "board/access.key").exists()
        assert "access_key_file" not in endpoints
        assert installation.path.stat().st_mode & 0o077 == 0
        credentials = []
        for path in installation.path.rglob("*.key"):
            assert path.stat().st_mode & 0o077 == 0, path
            credentials.append(path.read_text())
        for service in ("ursula", "node", "maintenance", "delivery", "counter", "board"):
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
        # Launchers build into private artifact prefixes, never zig-out. Use
        # their selected native binary; Compose needs an explicit host build
        # because its selected executable targets the Docker engine's platform.
        if profile == "local":
            old_binary = installation.artifacts.binary("example-counter")
        else:
            old_binary = installation.artifacts.native(["example-counter"])["example-counter"]["path"]
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
        rejected = subprocess.run([old_binary, "--once", old_config],
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
        # Missing current artifacts and incompatible v1 definitions must not
        # select replacements, start services or alter the retained installation.
        selection = installation.artifacts.read("selected")
        installation.artifacts.select({k: v for k, v in selection.items() if k != "transit-delivery"})
        incomplete = (installation.artifacts.path / "selected.json").read_bytes()
        invoke("update", "board", "--no-build", success=False)
        invoke("update", "--no-build", success=False)
        invoke("up", success=False)
        assert (installation.artifacts.path / "selected.json").read_bytes() == incomplete
        installation.artifacts.select(selection)
        saved_manifest = installation.manifest.read_bytes()
        manifest = json.loads(saved_manifest)
        for definition in (None, "00" * 32):
            changed = dict(manifest)
            if definition is None:
                del changed["definition"]
            else:
                changed["definition"] = definition
            write(installation.manifest, changed)
            rejected_manifest = installation.manifest.read_bytes()
            invoke("up", success=False)
            invoke("update", "--no-build", success=False)
            assert installation.manifest.read_bytes() == rejected_manifest
        installation.manifest.write_bytes(saved_manifest)
        assert not launcher.services()
        assert (installation.path / "operator/root.key").read_bytes() == root_key
        invoke("up")
        recovered = observe(25)
        assert recovered["pid"] == first["pid"] and recovered["generation"] > current["generation"]
        assert recovered["consumed"] == recovered["admitted"] == 4
        assert (installation.path / "operator/root.key").read_bytes() == root_key
        assert not (installation.path / "board/access.key").exists()
        for service in ("ursula", "node", "board"):
            invoke("restart", service)
            assert observe(25)["pid"] == first["pid"]
        # Change the endpoint of an existing installation, without resetting its
        # identity/history. Public DNS and probe transport are distinct.
        board_port = ports()
        remote_origin = f"http://devbox.local:{board_port}"
        remote = {"TRANSIT_BOARD_HOST": "0.0.0.0", "TRANSIT_BOARD_PORT": str(board_port),
                  "TRANSIT_BOARD_PUBLIC_ORIGIN": remote_origin, "TRANSIT_BOARD_ALLOW_INSECURE_HTTP": "true"}
        saved_manifest = installation.manifest.read_bytes()
        invoke("up", success=False, settings=remote)
        assert installation.manifest.read_bytes() == saved_manifest
        invoke("down")
        for invalid in ({**remote, "TRANSIT_BOARD_ALLOW_INSECURE_HTTP": "false"},
                        {**remote, "TRANSIT_BOARD_PORT": str(installation.base_port)},
                        {**remote, "TRANSIT_BOARD_PUBLIC_ORIGIN": "http://user@devbox.local"}):
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
            topology = json.loads(launcher.docker("config", "--format", "json", capture=True))
            assert topology["services"]["board"]["ports"][0]["host_ip"] == "0.0.0.0"
            for service in ("node", "ursula"):
                assert topology["services"][service]["ports"][0]["host_ip"] == "127.0.0.1"
        authority = f"devbox.local:{board_port}"
        def remote_request(path, *, host=authority, origin=remote_origin, method="GET"):
            headers = {"Host": host, "Origin": origin}
            connection = HTTPConnection("127.0.0.1", board_port, timeout=5)
            try:
                connection.request(method, path, headers=headers)
                response = connection.getresponse()
                response.read()
                return response.status, dict(response.getheaders())
            finally:
                connection.close()
        assert remote_request("/health")[0] == 200
        assert remote_request("/health", host="evil.example")[0] == 403
        assert remote_request("/health", origin="http://evil.example")[0] == 403
        status, headers = remote_request("/api/v1/processes")
        assert status == 200 and "set-cookie" not in headers
        assert remote_request("/api/v1/session", method="POST")[0] == 404
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
        assert observe()["lifecycle"] == "terminated"
        invoke("restart", "counter", success=False)
        assert observe()["lifecycle"] == "terminated"
        from interfaces.deployment.launcher_readiness import exercise as readiness
        readiness(installation, launcher)
        invoke("down")
        invoke("reset")
        assert not installation.path.exists()
        print(f"{profile}: persistence, retries, fencing, retirement, missing-store refusal and configurable Board origin and direct access passed.")
        completed = True
    finally:
        if installation.manifest.exists():
            if not completed and profile == "compose":
                write(installation.path / "failure.log", launcher.docker("logs", "--no-color", "--tail", "100", capture=True, timeout=30))
            try:
                launcher.down()
            except Exception:
                print(f"Cleanup incomplete; inspect {installation.path}", file=sys.stderr)
                raise
            if completed and not launcher.services():
                shutil.rmtree(installation.path)
            elif not completed:
                print(f"Failure evidence retained at {installation.path}", file=sys.stderr)


def foreground_proof(profile):
    installation = Installation(profile, "foreground-" + secrets.token_hex(3), ports())
    launcher = Local(installation) if profile == "local" else Compose(installation)
    env = {k: v for k, v in os.environ.items() if not k.startswith("TRANSIT_") and k not in ("LOG_LEVEL", "LOG_FORMAT")}
    command = [sys.executable, "-B", str(ROOT / "launchers/main.py"), profile]
    selection = ["--name", installation.name, "--base-port", str(installation.base_port)]
    output = ROOT / ".cache" / (installation.name + ".log")
    child = None
    completed = False

    def invoke(action, *args):
        return subprocess.check_output([*command, action, *selection, *args], env=env, text=True,
                                       timeout=600 if action == "up" else 30)

    def wait_for(predicate, seconds=45):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                if predicate():
                    return
            except (urllib.error.URLError, ConnectionError, TimeoutError):
                pass
            assert child.poll() is None, output.read_text()[-5000:]
            time.sleep(.1)
        raise AssertionError(output.read_text()[-5000:])

    try:
        installation.artifacts.initialize()
        with output.open("w") as log:
            child = subprocess.Popen([*command, "up", *selection], env=env,
                                     stdout=log, stderr=log, start_new_session=True)
            wait_for(lambda: f"{profile.title()} stack ready." in output.read_text(), seconds=600 if profile == "compose" else 45)
            assert child.poll() is None
            first = next(p for p in installation.inspect()["observation"]["processes"] if p)
            wait_for(lambda: "board.http.request" in output.read_text())
            invoke("send", "3", "--request-id", "foreground-input")
            wait_for(lambda: installation.counter_value() == 15)
            # A real child signal exit must be visible even without stderr,
            # and status/client calls must not truncate the manager's evidence.
            if profile == "local":
                board = next(row for row in launcher.services() if row["name"] == "board")
                os.kill(board["pid"], signal.SIGKILL)
                wait_for(lambda: "Exited exit_code=-1 process=board" in output.read_text())
                invoke("status")
                assert "Exited exit_code=-1 process=board" in (installation.path / "manager.log").read_text()
                assert "Exited exit_code=-1 process=board" in invoke("logs", "manager")
            else:
                launcher.docker("kill", "--signal", "SIGKILL", "board")
                wait_for(lambda: "exited with code 137" in output.read_text())
                invoke("status")
                # A second foreground up must fail without stopping the first.
                duplicate = subprocess.run([*command, "up", *selection], env=env, capture_output=True, timeout=30)
                assert duplicate.returncode != 0 and b"already exist" in duplicate.stderr
            invoke("restart", "board")
            assert child.poll() is None
            assert next(p for p in installation.inspect()["observation"]["processes"] if p)["pid"] == first["pid"]
            child.send_signal(signal.SIGINT)
            assert child.wait(timeout=30) == 0
            assert not launcher.services()
            assert installation.manifest.exists() and (installation.path / "wal").exists()

        if profile == "compose":
            # Recover the same PID/state, then pause the old foreground owner
            # while another terminal runs down and starts a new detached stack.
            # Its eventual cleanup must not stop those replacement containers.
            with output.open("w") as log:
                child = subprocess.Popen([*command, "up", *selection], env=env,
                                         stdout=log, stderr=log, start_new_session=True)
                wait_for(lambda: "Compose stack ready." in output.read_text(), seconds=600)
                recovered = next(p for p in installation.inspect()["observation"]["processes"] if p)
                assert recovered["pid"] == first["pid"] and installation.counter_value() == 15
                child.send_signal(signal.SIGSTOP)
                try:
                    invoke("down")
                    invoke("up", "-d")
                    replacements = {row["ID"] for row in launcher.services()}
                finally:
                    child.send_signal(signal.SIGCONT)
                assert child.wait(timeout=30) == 0
                assert {row["ID"] for row in launcher.services()} == replacements
                assert all(row["State"] == "running" for row in launcher.services())
                invoke("down")

        # A startup failure must stream actual service stderr, exit nonzero,
        # and clean up its own manager without deleting the saved installation.
        wal = installation.path / "wal"
        saved_wal = installation.path / "saved-wal"
        wal.rename(saved_wal)
        wal.mkdir()
        with output.open("w") as log:
            child = subprocess.Popen([*command, "up", *selection], env=env,
                                     stdout=log, stderr=log, start_new_session=True)
            assert child.wait(timeout=600 if profile == "compose" else 60) != 0
        failure = "node failed" if profile == "local" else "node exited"
        transcript = output.read_text()
        service_failures = [line for line in transcript.splitlines() if "service.failed" in line]
        assert any("error_type" in line and "NotFound" in line for line in service_failures), transcript[-5000:]
        assert failure in transcript, transcript[-5000:]
        assert not launcher.services()
        shutil.rmtree(wal)
        saved_wal.rename(wal)

        # Termination during startup also stops the owned foreground manager.
        with output.open("w") as log:
            child = subprocess.Popen([*command, "up", *selection], env=env,
                                     stdout=log, stderr=log, start_new_session=True)
            if profile == "local":
                wait_for(lambda: "Process Compose v" in output.read_text())
            else:
                wait_for(lambda: any(row["Service"] == "ursula" for row in launcher.services()), seconds=600)
                assert "Compose stack ready." not in output.read_text()
            child.send_signal(signal.SIGTERM)
            assert child.wait(timeout=30) == 0
        assert not launcher.services()
        invoke("reset")
        completed = True
        print(f"{profile} foreground: live logs, visible signal exit, unlocked controls, Ctrl-C, startup failure and termination cleanup passed.")
    finally:
        if child is not None and child.poll() is None:
            child.terminate()
            child.wait(timeout=45)
        if installation.manifest.exists():
            launcher.down()
        if completed:
            output.unlink()
        else:
            print(f"Foreground proof evidence: {output}, {installation.path}", file=sys.stderr)


if __name__ == "__main__":
    proof(sys.argv[1])
    foreground_proof(sys.argv[1])

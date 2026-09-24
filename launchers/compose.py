"""Container packaging waypoint; host provisioning uses the same public client."""
import json
import os
import shutil
import signal
import subprocess
import time

from common import ROOT, SERVICES, healthy, lock, run, write


class Compose:
    def __init__(self, installation):
        self.installation = installation
        self.path = installation.path
        self.manager = None

    def docker(self, *args, spawn=False, **kwargs):
        values_file = self.path / "compose.env.json"
        env = dict(os.environ)
        if values_file.exists():
            env.update(json.loads(values_file.read_text()))
            config = ROOT / "docker-compose.yaml"
        else:
            # Allow existing installations to stop before their first new up.
            config = self.path / "compose.json"
        command = ["docker", "compose", "--project-name", self.installation.load()["project"],
                   "--env-file", os.devnull, "--file", config, *args]
        if spawn:
            return subprocess.Popen(list(map(str, command)), env=env,
                                    stdin=subprocess.DEVNULL, start_new_session=True)
        return run(command, env=env, **kwargs)

    def configured(self):
        return (self.path / "compose.env.json").exists() or (self.path / "compose.json").exists()

    def services(self):
        if not self.configured():
            return []
        output = self.docker("ps", "--all", "--format", "json", capture=True)
        return [json.loads(line) for line in output.splitlines() if line.strip()]

    def ready(self, name, url, headers=None):
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            if self.manager is not None and self.manager.poll() is not None:
                raise RuntimeError(f"Compose exited during startup ({self.manager.returncode}); data retained")
            if healthy(url, headers):
                return
            if any(row["Service"] == name and row["State"] == "exited" for row in self.services()):
                raise RuntimeError(f"{name} exited; inspect launcher logs. Data has been preserved.")
            time.sleep(.2)
        raise RuntimeError(f"{name} is not ready; inspect launcher status and logs")

    def images(self):
        architecture = run(["docker", "info", "--format", "{{.Architecture}}"], capture=True).strip()
        target = {"x86_64": "x86_64-linux-musl", "aarch64": "aarch64-linux-musl"}.get(architecture)
        if target is None:
            raise RuntimeError("Compose currently supports Linux Docker engines on x86_64 or aarch64")
        prefix = self.path / "build"
        run(["zig", "build", "apps", "examples", "transit-board", "-Dtarget=" + target,
             "-Doptimize=ReleaseSafe", "--prefix", prefix], cwd=ROOT, timeout=600)
        for name in ("transit-node", "example-counter", "transit-board"):
            context = self.path / "images" / name
            context.mkdir(parents=True, exist_ok=True)
            shutil.copy2(prefix / "bin" / name, context / name)
            (context / name).chmod(0o755)
            write(context / "Dockerfile", f'FROM scratch\nCOPY {name} /bin/{name}\nUSER 65532:65532\nENTRYPOINT ["/bin/{name}"]\n')
            run(["docker", "build", "--tag", self.installation.load()["project"] + "/" + name, context], timeout=300)

    def config(self):
        self.installation.configs()
        value = self.installation.load()
        base = value["base_port"]
        pins = json.loads((ROOT / "deploy/reference/versions.json").read_text())
        values = {"STATE": str(self.path), "IMAGE_PREFIX": value["project"],
                  "UID": str(os.getuid()), "GID": str(os.getgid()), "URSULA_IMAGE": pins["ursula"],
                  "URSULA_PORT": str(base), "TRANSIT_PORT": str(base + 1),
                  "BOARD_HOST": self.installation.board["host"], "BOARD_PORT": str(self.installation.board["port"])}
        for role in ("node", "board", "counter", "maintenance"):
            values.update({role.upper() + "_" + key: value for key, value in self.installation.service_environment(role).items()})
        write(self.path / "compose.env.json", {"REY_COMPOSE_" + key: value for key, value in values.items()})
        self.docker("config", "--quiet")

    def up(self, detached=True):
        if self.services():
            raise RuntimeError("Compose resources already exist; use restart or down before up")
        self.installation.configure_board()
        self.config()
        self.images()
        self.docker("up", "-d", "ursula", timeout=300)
        self.ready("ursula", f'http://127.0.0.1:{self.installation.load()["base_port"]}/__ursula/ready')
        self.installation.initialize()
        self.docker("up", "-d", "node")
        self.ready("node", self.installation.url + "/health")
        self.installation.provision()
        self.installation.activate()
        if detached:
            self.docker("up", "-d", "maintenance", "counter", "board")
        else:
            # Ursula and the node must be provisioned before application services
            # start. Attach to all services, including their earlier startup logs.
            self.manager = self.docker("up", "--no-recreate", "--no-build", "--menu=false",
                                       "--timeout", "10", spawn=True)
        self.ready("board", self.installation.board_url + "/health", self.installation.board_headers)
        if {row["Service"] for row in self.services() if row["State"] == "running"} != set(SERVICES):
            raise RuntimeError("A service exited during startup; inspect status and logs")

    def stop_attachment(self, graceful=False):
        if self.manager is None or self.manager.poll() is not None:
            return
        if graceful:
            self.manager.terminate()
            try:
                self.manager.wait(timeout=30)
                return
            except subprocess.TimeoutExpired:
                pass
        # The Docker CLI can have a Compose plugin child. Kill only this
        # invocation's session, never a container or a reused project name.
        try:
            os.killpg(self.manager.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass  # Attachment exited between poll and signal.
        self.manager.wait(timeout=5)

    def foreground(self):
        def interrupted(signum, frame):
            raise KeyboardInterrupt

        signals = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)
        previous = {sig: signal.signal(sig, interrupted) for sig in signals}
        owned = set()

        def ignore_signals():
            for sig in signals:
                signal.signal(sig, signal.SIG_IGN)

        try:
            with lock(self.installation.lifecycle_lock):
                self.installation.prepare()
                if self.services():
                    raise RuntimeError("Compose resources already exist; use restart or down before up")
                try:
                    self.up(detached=False)
                    owned = {row["ID"] for row in self.services()}
                except BaseException:
                    # Startup still holds the lifecycle lock, so any partially
                    # created containers belong to this invocation. Show their
                    # diagnostics before removing them, including early failures
                    # that happened before the attached Compose process started.
                    ignore_signals()
                    self.stop_attachment(graceful=True)
                    if self.configured():
                        try:
                            self.docker("logs", "--tail", "200")
                        finally:
                            self.down()
                    raise
                print(json.dumps(self.installation.endpoints(), indent=2), flush=True)
                print("Compose stack ready. Streaming logs; Ctrl-C stops services and preserves data.", flush=True)
            # Commands in other terminals must remain usable while attached.
            result = self.manager.wait()
            if result != 0:
                raise RuntimeError(f"Compose exited ({result}); data retained")
        except KeyboardInterrupt:
            print("\nStopping Compose services; data and keys retained.", flush=True)
        finally:
            ignore_signals()
            try:
                if owned:
                    with lock(self.installation.lifecycle_lock):
                        try:
                            current = {row["ID"] for row in self.services()}
                            # Another terminal may have run down then up. An old
                            # foreground invocation must not stop the new stack.
                            if current and current <= owned:
                                self.down()
                        finally:
                            self.stop_attachment()
            finally:
                for sig, handler in previous.items():
                    signal.signal(sig, handler)

    def down(self):
        if self.configured():
            self.docker("down", "--timeout", "10")

    def restart(self, name):
        if name not in SERVICES:
            raise ValueError("Unknown service")
        if not self.services():
            raise RuntimeError("Compose stack is stopped; use up")
        if name == "counter":
            self.docker("stop", "counter")
            self.installation.activate()
        self.docker("restart", name)

    def logs(self, name):
        if name not in SERVICES:
            raise ValueError("Unknown service")
        self.docker("logs", "--no-color", "--tail", "200", name)

"""Container packaging waypoint; host provisioning uses the same public client."""
import json
import os
import secrets
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
        values = json.loads(values_file.read_text())
        for role in self.installation.artifacts.roles([]):
            if "REY_COMPOSE_" + role.upper().replace("-", "_") + "_IMAGE" not in values:
                raise RuntimeError("Incomplete Compose configuration; preserve this installation and restore its matching build")
        env.update(values)
        config = self.installation.compose_topology
        command = ["docker", "compose", "--project-name", self.installation.load()["project"],
                   "--env-file", os.devnull, "--file", config, *args]
        if spawn:
            return subprocess.Popen(list(map(str, command)), env=env,
                                    stdin=subprocess.DEVNULL, start_new_session=True)
        return run(command, env=env, **kwargs)

    def configured(self):
        return (self.path / "compose.env.json").exists()

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

    def config(self):
        self.installation.configs()
        value = self.installation.load()
        base = value["base_port"]
        pins = json.loads((ROOT / "deploy/reference/versions.json").read_text())
        values = {"STATE": str(self.path),
                  "UID": str(os.getuid()), "GID": str(os.getgid()), "URSULA_IMAGE": pins["ursula"],
                  "URSULA_PORT": str(base), "TRANSIT_PORT": str(base + 1),
                  "BOARD_HOST": self.installation.board["host"], "BOARD_PORT": str(self.installation.board["port"])}
        selected = self.installation.artifacts.read("selected")
        for role in self.installation.artifacts.roles([]):
            prefix = role.upper().replace("-", "_")
            values[prefix + "_IMAGE"] = selected[self.installation.artifacts.mapping[role]]["image"]
            values.update({prefix + "_" + key: value for key, value in self.installation.service_environment(role).items()})
        write(self.path / "compose.env.json", {"REY_COMPOSE_" + key: value for key, value in values.items()})
        self.docker("config", "--quiet")

    def up(self, detached=True):
        if self.services():
            raise RuntimeError("Compose resources already exist; use restart or down before up")
        self.installation.artifacts.initialize()
        self.installation.configure_board()
        self.config()
        write(self.path / "session.json", {"id": secrets.token_hex(16)})
        self.docker("up", "-d", "ursula", timeout=300)
        self.ready("ursula", f'http://127.0.0.1:{self.installation.load()["base_port"]}/__ursula/ready')
        self.installation.initialize()
        self.docker("up", "-d", "node")
        self.ready("node", self.installation.url + "/health")
        self.installation.provision()
        self.installation.activate()
        self.docker("up", "-d", *[name for name in self.installation.service_names if name not in ("ursula", "node")])
        if not detached:
            self.manager = self.docker("logs", "--follow", "--tail", "200", spawn=True)
        self.ready("board", self.installation.board_url + "/health", self.installation.board_headers)
        if {row["Service"] for row in self.services() if row["State"] == "running"} != set(self.installation.service_names):
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
        owned = None

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
                    owned = json.loads((self.path / "session.json").read_text())
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
            # Reattach logs after intentional container replacement. A logs
            # follower is scoped to the containers it initially discovered.
            current_ids = {row["ID"] for row in self.services()}
            reported_exits = set()
            since = int(time.time())
            while self.session() == owned:
                time.sleep(.5)
                rows = self.services()
                if not rows:
                    break
                for row in rows:
                    if row["State"] == "exited" and row["ID"] not in reported_exits:
                        print(f'{row["Service"]} exited with code {row.get("ExitCode", "unknown")}; other services remain available.', flush=True)
                        reported_exits.add(row["ID"])
                ids = {row["ID"] for row in rows}
                if ids != current_ids:
                    self.stop_attachment()
                    self.manager = self.docker("logs", "--follow", "--since", str(since), spawn=True)
                    current_ids = ids
                elif self.manager.poll() is not None:
                    raise RuntimeError("Compose log attachment exited; inspect service logs")
                since = int(time.time()) - 1
        except KeyboardInterrupt:
            print("\nStopping Compose services; data and keys retained.", flush=True)
        finally:
            ignore_signals()
            try:
                if owned:
                    with lock(self.installation.lifecycle_lock):
                        try:
                            if self.session() == owned:
                                self.down()
                        finally:
                            self.stop_attachment()
            finally:
                for sig, handler in previous.items():
                    signal.signal(sig, handler)

    def session(self):
        path = self.path / "session.json"
        return json.loads(path.read_text()) if path.exists() else None

    def down(self):
        if self.configured():
            self.docker("down", "--timeout", "10")
            (self.path / "session.json").unlink(missing_ok=True)

    def restart(self, name):
        if name not in self.installation.service_names:
            raise ValueError("Unknown service")
        if not self.services():
            raise RuntimeError("Compose stack is stopped; use up")
        if name in self.installation.workloads:
            self.docker("stop", name)
            self.installation.activate(name)
        self.docker("restart", name)

    def validate_update(self, operation):
        for role in self.installation.workloads:
            if role in operation["services"]:
                self.installation.validate_workload_update(role)

    def apply_update(self, operation):
        from updates import publish, completed
        publish(self, operation)
        self.config()
        for role in operation["services"]:
            if role in operation["completed"]:
                continue
            if role in self.installation.workloads:
                self.docker("stop", role)
                self.installation.activate(role)
            self.docker("up", "-d", "--no-deps", "--force-recreate", "--no-build", role)
            if role == "board":
                self.ready(role, self.installation.board_url + "/health", self.installation.board_headers)
            elif role == "node":
                self.ready(role, self.installation.url + "/health")
                self.installation.provision()
            else:
                time.sleep(.5)
                if not any(r["Service"] == role and r["State"] == "running" for r in self.services()):
                    raise RuntimeError(f"{role} failed after replacement; update remains pending")
            completed(self, operation, role)

    def logs(self, name):
        if name not in self.installation.service_names:
            raise ValueError("Unknown service")
        self.docker("logs", "--no-color", "--tail", "200", name)

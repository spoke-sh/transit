"""Native services managed by the Nix-pinned Process Compose."""
import json
import os
import shlex
import signal
import subprocess
import sys
import time
import logs as log_retention

from common import ROOT, SERVICES, healthy, lock, run, wait_for, write


class Local:
    def __init__(self, installation):
        self.installation = installation
        self.path = installation.path
        self.manager = None
        self.manager_log = None

    def pc(self, *args, manager=False, spawn=False, **kwargs):
        env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_", "PC_")) and k not in ("LOG_LEVEL", "LOG_FORMAT")}
        env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2", XDG_CONFIG_HOME=str(self.path / "xdg"))
        (self.path / "xdg/process-compose").mkdir(parents=True, exist_ok=True, mode=0o700)
        # Every Process Compose invocation truncates its own log. Client calls
        # must never erase the daemon's startup, readiness or exit evidence.
        log = self.path / ("manager.log" if manager else "manager-client.log")
        command = ["process-compose", "-U", "-u", self.path / "pc.sock", "-L", log,
                   "--log-no-color", "--ordered-shutdown", *args]
        if spawn:
            return subprocess.Popen(list(map(str, command)), cwd=self.path, env=env,
                                    stdin=subprocess.DEVNULL, start_new_session=True)
        return run(command, cwd=self.path, env=env, **kwargs)

    def services(self):
        if not (self.path / "pc.sock").exists():
            return []
        # A broken manager is an error, never permission to launch duplicates
        # or delete files under potentially live processes.
        return json.loads(self.pc("process", "list", "-o", "json", capture=True, timeout=5))

    def up(self, detached=True):
        if self.services():
            raise RuntimeError("Local manager is already running; use status, restart or down")
        installation = self.installation
        installation.artifacts.initialize()
        installation.configure_board()
        installation.configs()
        # Startup readiness must refer to this worker launch, not the saved
        # configuration from the previous activation.
        (self.path / "counter/config.json").unlink(missing_ok=True)
        if len(os.fsencode(self.path / "pc.sock")) >= 104:
            raise RuntimeError("Checkout path is too long for the private Unix socket")
        values = {"ROOT_Q": shlex.quote(str(ROOT)), "PYTHON_Q": shlex.quote(sys.executable),
                  "NAME_Q": shlex.quote(installation.name), "STATE_DIR": str(self.path),
                  "STATE_DIR_Q": shlex.quote(str(self.path)),
                  "URSULA_PORT": installation.load()["base_port"],
                  "TRANSIT_PORT": installation.load()["base_port"] + 1}
        for role in ("node", "board", "counter", "maintenance"):
            values.update({role.upper() + "_" + key: value for key, value in installation.service_environment(role).items()})
        # Only values are generated. Disable Process Compose's environment
        # expansion so literal dollars in quoted paths cannot be reinterpreted.
        write(self.path / "process-compose.vars.json", {"disable_env_expansion": True, "vars": values})
        args = ("up", "-f", ROOT / "process-compose.yaml", "-f", self.path / "process-compose.vars.json", "--disable-dotenv")
        log_retention.rotate(self.path / "manager.log", force=True)
        if detached:
            self.pc(*args, "-D", manager=True, capture=True)
        else:
            write(self.path / "manager.log", "")
            self.manager_log = (self.path / "manager.log").open("rb")
            self.manager = self.pc(*args, "-t=false", manager=True, spawn=True)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            self.drain_manager_log()
            if self.manager is not None and self.manager.poll() is not None:
                raise RuntimeError(f"Local manager exited during startup ({self.manager.returncode}); data and logs retained")
            rows = self.services()
            # Report the failed dependency before services skipped because of it.
            for process in sorted(rows, key=lambda row: row["status"] == "Skipped"):
                if not process["is_running"] and process["exit_code"] != 0:
                    raise RuntimeError(f"{process['name']} failed; inspect {process['name']}.log. Data has been preserved.")
            ready = {p["name"] for p in rows if p["is_running"] and
                     (not p["has_ready_probe"] or p["is_ready"] == "Ready")}
            if set(SERVICES) <= ready and (self.path / "counter/config.json").exists():
                return
            time.sleep(.2)
        raise RuntimeError("A local service did not start; use status and logs. Data has been preserved.")

    def drain_manager_log(self):
        if self.manager_log is not None:
            if os.fstat(self.manager_log.fileno()).st_size < self.manager_log.tell():
                self.manager_log.seek(0)
            # Stream bounded chunks alongside the manager's live, prefixed
            # service output. Lifecycle/probe messages otherwise go only to disk.
            chunk = self.manager_log.read(65536)
            if chunk:
                print(chunk.decode(errors="replace"), end="", flush=True)

    def foreground(self):
        def interrupted(signum, frame):
            raise KeyboardInterrupt

        signals = (signal.SIGINT, signal.SIGTERM, signal.SIGHUP)
        previous = {sig: signal.signal(sig, interrupted) for sig in signals}
        try:
            # Hold the lifecycle lock only through startup. Other terminals
            # must be able to inspect, send, restart services, or run down.
            with lock(self.installation.lifecycle_lock):
                self.installation.prepare()
                self.up(detached=False)
                print(json.dumps(self.installation.endpoints(), indent=2), flush=True)
                print("Local stack ready. Streaming logs; Ctrl-C stops services and preserves data.", flush=True)
            while self.manager.poll() is None:
                self.drain_manager_log()
                time.sleep(.2)
            if self.manager.returncode != 0:
                raise RuntimeError(f"Local manager exited ({self.manager.returncode}); data and logs retained")
        except KeyboardInterrupt:
            print("\nStopping local services; data and keys retained.", flush=True)
        finally:
            # Signal only this invocation's manager. A later installation must
            # never be stopped through a reused socket or PID from a state file.
            for sig in signals:
                signal.signal(sig, signal.SIG_IGN)
            try:
                if self.manager is not None and self.manager.poll() is None:
                    self.manager.terminate()
                    self.manager.wait(timeout=40)
                self.drain_manager_log()
                if self.manager_log is not None:
                    self.manager_log.close()
            finally:
                for sig, handler in previous.items():
                    signal.signal(sig, handler)

    def down(self):
        if self.services():
            self.pc("down", capture=True)
            deadline = time.monotonic() + 30
            while (self.path / "pc.sock").exists() and time.monotonic() < deadline:
                time.sleep(.1)
            if (self.path / "pc.sock").exists():
                raise RuntimeError("Local manager did not finish shutdown")

    def restart(self, name):
        if name not in SERVICES and name != "log-retention":
            raise ValueError("Unknown service")
        if not self.services():
            raise RuntimeError("Local manager is stopped; use up")
        previous_pid = next((p["pid"] for p in self.services() if p["name"] == name), None)
        if name == "counter":
            (self.path / "counter/config.json").unlink(missing_ok=True)
        self.pc("process", "restart", name, capture=True)
        deadline = time.monotonic() + 30
        while time.monotonic() < deadline:
            process = next(p for p in self.services() if p["name"] == name)
            if process["is_running"] and process["pid"] != previous_pid:
                break
            if process["exit_code"] != 0:
                raise RuntimeError(f"{name} failed after replacement; inspect its logs")
            time.sleep(.1)
        else:
            raise RuntimeError(f"{name} did not acquire a new running process")
        if name == "counter":
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                process = next(p for p in self.services() if p["name"] == name)
                if not process["is_running"] and process["exit_code"] != 0:
                    raise RuntimeError("Counter activation failed; inspect counter logs")
                if process["is_running"] and (self.path / "counter/config.json").exists():
                    return
                time.sleep(.2)
            raise RuntimeError("Counter did not acquire a fresh activation; inspect counter logs")
        if name == "board":
            wait_for(self.installation.board_url + "/health", headers=self.installation.board_headers)
        elif name in ("node", "ursula"):
            port = self.installation.load()["base_port"] + {"ursula": 0, "node": 1}[name]
            wait_for(f'http://127.0.0.1:{port}' + ("/__ursula/ready" if name == "ursula" else "/health"))

    def validate_update(self, operation):
        if "counter" in operation["services"]:
            self.installation.validate_counter_update()

    def apply_update(self, operation):
        from updates import publish, completed
        publish(self, operation)
        for role in operation["services"]:
            if role not in operation["completed"]:
                self.restart(role)
                completed(self, operation, role)

    def logs(self, name):
        if name not in SERVICES and name not in ("provision", "manager", "log-retention"):
            raise ValueError("Unknown service")
        if name != "manager" and self.services():
            # The manager also records probe failures here; they are absent
            # from the child process's stdout/stderr file.
            self.pc("process", "logs", name, "--tail", "200")
            return
        # Logs remain inspectable after shutdown too. Bound the read to 64 KiB.
        path = self.path / (name + ".log")
        with path.open("rb") as stream:
            stream.seek(max(0, path.stat().st_size - 65536))
            print(stream.read().decode(errors="replace"), end="")

    def attach(self):
        self.pc("attach", timeout=None)

    def service(self, name):
        if name == "log-retention":
            log_retention.maintain(self.path)
            return
        if name == "board-probe":
            if not healthy(self.installation.board_url + "/health", self.installation.board_headers):
                raise RuntimeError("Board readiness failed for the configured public Host")
            return
        elif name == "node":
            self.installation.initialize()
            command = [self.installation.artifacts.binary("transit-node"), self.path / "node.json"]
        elif name == "provision":
            self.installation.provision()
            return
        elif name == "counter":
            self.installation.activate()
            command = [self.installation.artifacts.binary("example-counter"), self.path / "counter/config.json"]
        elif name == "board":
            command = [self.installation.artifacts.binary("transit-board"), self.path / "board/config.json"]
        elif name == "maintenance":
            command = [self.installation.artifacts.binary("transit-node"), self.path / "maintenance/config.json", "--maintain"]
        else:
            raise ValueError("Unknown internal service")
        os.environ.update(self.installation.service_environment(name))
        os.execv(str(command[0]), list(map(str, command)))

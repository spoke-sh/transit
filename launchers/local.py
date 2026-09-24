"""Native services managed by the Nix-pinned Process Compose."""
import json
import os
import shlex
import sys
import time

from common import ROOT, SERVICES, healthy, run, wait_for, write


class Local:
    def __init__(self, installation):
        self.installation = installation
        self.path = installation.path

    def pc(self, *args, **kwargs):
        env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_", "PC_"))}
        env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2", XDG_CONFIG_HOME=str(self.path / "xdg"))
        (self.path / "xdg/process-compose").mkdir(parents=True, exist_ok=True, mode=0o700)
        return run(["process-compose", "-U", "-u", self.path / "pc.sock", "-L", self.path / "manager.log",
                    "--ordered-shutdown", *args], cwd=self.path, env=env, **kwargs)

    def services(self):
        if not (self.path / "pc.sock").exists():
            return []
        # A broken manager is an error, never permission to launch duplicates
        # or delete files under potentially live processes.
        return json.loads(self.pc("process", "list", "-o", "json", capture=True, timeout=5))

    def up(self):
        if self.services():
            raise RuntimeError("Local manager is already running; use status, restart or down")
        installation = self.installation
        installation.check_ports()
        installation.configs()
        # Startup readiness must refer to this worker launch, not the saved
        # configuration from the previous activation.
        (self.path / "counter/config.json").unlink(missing_ok=True)
        if len(os.fsencode(self.path / "pc.sock")) >= 104:
            raise RuntimeError("Checkout path is too long for the private Unix socket")
        launcher = [sys.executable, "-B", ROOT / "launchers/main.py", "local", "service", "--name", installation.name]
        commands = {
            "ursula": ["ursula", "server", "--config", self.path / "ursula.toml"],
            "node": [*launcher, "node"], "provision": [*launcher, "provision"],
            "counter": [*launcher, "counter"],
            "maintenance": [ROOT / "zig-out/bin/transit-node", self.path / "maintenance/config.json", "--maintain"],
            "board": [ROOT / "zig-out/bin/board", self.path / "board/config.json"],
        }
        processes = {}
        for name, command in commands.items():
            processes[name] = {"command": shlex.join(list(map(str, command))), "working_dir": str(self.path),
                "log_location": str(self.path / (name + ".log")), "availability": {"restart": "no"},
                "shutdown": {"signal": 15, "timeout_seconds": 5}}
            if name != "ursula":
                dependency = "ursula" if name == "node" else "node" if name == "provision" else "provision"
                processes[name]["depends_on"] = {dependency: {"condition": "process_completed_successfully" if dependency == "provision" else "process_healthy"}}
        for name, offset, route in (("ursula", 0, "/__ursula/ready"), ("node", 1, "/health"), ("board", 2, "/health")):
            processes[name]["readiness_probe"] = {"http_get": {"host": "127.0.0.1", "port": installation.load()["base_port"] + offset,
                "scheme": "http", "path": route}, "period_seconds": 1, "timeout_seconds": 1, "failure_threshold": 30}
        write(self.path / "process-compose.json", {"version": "0.5", "is_strict": True, "processes": processes})
        self.pc("up", "-f", self.path / "process-compose.json", "--disable-dotenv", "-D", capture=True)
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            rows = self.services()
            for process in rows:
                if not process["is_running"] and process["exit_code"] != 0:
                    raise RuntimeError(f"{process['name']} failed; inspect {process['name']}.log. Data has been preserved.")
            running = {p["name"] for p in rows if p["status"] == "Running"}
            if set(SERVICES) <= running and (self.path / "counter/config.json").exists() and healthy(installation.origin + "/health"):
                return
            time.sleep(.2)
        raise RuntimeError("A local service did not start; use status and logs. Data has been preserved.")

    def down(self):
        if self.services():
            self.pc("down", capture=True)
            deadline = time.monotonic() + 30
            while (self.path / "pc.sock").exists() and time.monotonic() < deadline:
                time.sleep(.1)
            if (self.path / "pc.sock").exists():
                raise RuntimeError("Local manager did not finish shutdown")

    def restart(self, name):
        if name not in SERVICES:
            raise ValueError("Unknown service")
        if not self.services():
            raise RuntimeError("Local manager is stopped; use up")
        if name == "counter":
            (self.path / "counter/config.json").unlink(missing_ok=True)
        self.pc("process", "restart", name, capture=True)
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
        if name in ("node", "board", "ursula"):
            port = self.installation.load()["base_port"] + {"ursula": 0, "node": 1, "board": 2}[name]
            wait_for(f'http://127.0.0.1:{port}' + ("/__ursula/ready" if name == "ursula" else "/health"))

    def logs(self, name):
        if name not in SERVICES and name != "provision":
            raise ValueError("Unknown service")
        # Logs remain inspectable after shutdown too. Bound the read to 64 KiB.
        path = self.path / (name + ".log")
        with path.open("rb") as stream:
            stream.seek(max(0, path.stat().st_size - 65536))
            print(stream.read().decode(errors="replace"), end="")

    def attach(self):
        self.pc("attach", timeout=None)

    def service(self, name):
        if name == "node":
            self.installation.initialize()
            command = [ROOT / "zig-out/bin/transit-node", self.path / "node.json"]
        elif name == "provision":
            self.installation.provision()
            return
        elif name == "counter":
            self.installation.activate()
            command = [ROOT / "zig-out/bin/example-counter", self.path / "counter/config.json"]
        else:
            raise ValueError("Unknown internal service")
        os.execv(str(command[0]), list(map(str, command)))

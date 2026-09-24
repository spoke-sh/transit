"""Container packaging waypoint; host provisioning uses the same public client."""
import json
import os
import shutil
import time

from common import ROOT, SERVICES, healthy, run, write


class Compose:
    def __init__(self, installation):
        self.installation = installation
        self.path = installation.path

    def docker(self, *args, **kwargs):
        values_file = self.path / "compose.env.json"
        env = dict(os.environ)
        if values_file.exists():
            env.update(json.loads(values_file.read_text()))
            config = ROOT / "docker-compose.yaml"
        else:
            # Allow existing installations to stop before their first new up.
            config = self.path / "compose.json"
        return run(["docker", "compose", "--project-name", self.installation.load()["project"],
                    "--env-file", os.devnull, "--file", config, *args], env=env, **kwargs)

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
        run(["zig", "build", "apps", "examples", "board", "-Dtarget=" + target,
             "-Doptimize=ReleaseSafe", "--prefix", prefix], cwd=ROOT, timeout=600)
        for name in ("transit-node", "example-counter", "board"):
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

    def up(self):
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
        self.docker("up", "-d", "maintenance", "counter", "board")
        self.ready("board", self.installation.board_url + "/health", self.installation.board_headers)
        if {row["Service"] for row in self.services() if row["State"] == "running"} != set(SERVICES):
            raise RuntimeError("A service exited during startup; inspect status and logs")

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

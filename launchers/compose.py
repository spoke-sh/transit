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
        return run(["docker", "compose", "--project-name", self.installation.load()["project"],
                    "--file", self.path / "compose.json", *args], **kwargs)

    def services(self):
        if not (self.path / "compose.json").exists():
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
        image = lambda name: value["project"] + "/" + name
        def mount(source, target, readonly=True):
            return {"type": "bind", "source": str(self.path / source), "target": target,
                    "read_only": readonly, "bind": {"create_host_path": False}}
        def service(binary, args, mounts, networks):
            return {"image": image(binary), "command": args, "volumes": mounts, "networks": networks,
                    "user": f"{os.getuid()}:{os.getgid()}", "read_only": True, "cap_drop": ["ALL"],
                    "security_opt": ["no-new-privileges:true"], "restart": "no", "init": True,
                    "logging": {"driver": "json-file", "options": {"max-size": "5m", "max-file": "2"}}}
        services = {
            "node": service("transit-node", ["/node.json"], [mount("node.json", "/node.json")], ["storage", "client"]),
            "maintenance": service("transit-node", ["/maintenance/config.json", "--maintain"], [mount("maintenance", "/maintenance")], ["storage"]),
            "counter": service("example-counter", ["/counter/config.json"], [mount("counter", "/counter")], ["client"]),
            "board": service("board", ["/board/config.json"], [mount("board", "/board")], ["client"]),
        }
        for name, service_config in services.items():
            service_config["environment"] = self.installation.service_environment(name)
        pins = json.loads((ROOT / "deploy/reference/versions.json").read_text())
        services["ursula"] = {"image": pins["ursula"], "command": ["server", "--config", "/ursula.toml"],
            "user": f"{os.getuid()}:{os.getgid()}", "cap_drop": ["ALL"], "security_opt": ["no-new-privileges:true"],
            "environment": {"RUST_LOG": "warn", "TOKIO_WORKER_THREADS": "2"},
            "volumes": [mount("ursula.toml", "/ursula.toml"), mount("wal", "/wal", False)],
            "networks": ["storage"], "restart": "no", "init": True,
            "logging": {"driver": "json-file", "options": {"max-size": "5m", "max-file": "2"}}}
        for name, offset in (("ursula", 0), ("node", 1), ("board", 2)):
            services[name]["ports"] = [{"target": 8080, "published": str(base + offset), "host_ip": "127.0.0.1"}]
        services["board"]["ports"][0].update(published=str(self.installation.board["port"]), host_ip=self.installation.board["host"])
        # Ordinary bridges support loopback publication for host-side tools.
        # This separates direct service discovery/mounts, not hostile-workload
        # egress: the reference runtime owns that stronger isolation proof.
        write(self.path / "compose.json", {"services": services, "networks": {"storage": {}, "client": {}}})
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
        if (self.path / "compose.json").exists():
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

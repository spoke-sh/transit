"""Physical placement only; signed Transit operations stay in the example runner."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]


class Process:
    def __init__(self, placement, service, identity):
        self.placement, self.service, self.identity = placement, service, identity

    def poll(self):
        result = subprocess.run(["docker", "inspect", "--format", "{{.State.Running}}", self.identity], capture_output=True, text=True)
        return None if result.returncode == 0 and result.stdout.strip() == "true" else 0

    def kill(self):
        subprocess.run(["docker", "kill", self.identity], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=15)

    def wait(self, timeout):
        subprocess.run(["docker", "wait", self.identity], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=timeout)


class Compose:
    def __init__(self, work):
        self.work = work
        self.project = "transit-http-" + uuid.uuid4().hex[:10]
        self.env = os.environ | {"HTTP_UID": str(os.getuid()), "HTTP_GID": str(os.getgid()),
            "HTTP_WORK": str(work),
            "HTTP_URSULA_IMAGE": json.loads((ROOT / "deploy/reference/versions.json").read_text())["ursula"]}
        self.command = ["docker", "compose", "--project-name", self.project, "--env-file", os.devnull,
                        "--file", str(Path(__file__).with_name("docker-compose.yaml"))]
        self.build()

    def call(self, *args, timeout=120):
        result = subprocess.run([*self.command, *args], env=self.env, text=True, capture_output=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError(result.stderr[-4000:])
        return result.stdout

    def build(self):
        prefix = ROOT / ".cache/http-example/images"
        prefix.mkdir(parents=True, exist_ok=True)
        names = {"NODE": "transit-node", "CALLER": "example-station-http", "CONNECTOR": "transit-station-http-worker"}
        architecture = subprocess.check_output(["docker", "info", "--format", "{{.Architecture}}"], text=True).strip()
        target = {"x86_64": "x86_64-linux-musl", "aarch64": "aarch64-linux-musl"}[architecture]
        subprocess.run(["zig", "build", *names.values(), "-Doptimize=ReleaseSafe", "-Dtarget=" + target,
                        "--prefix", str(prefix / "static")], cwd=ROOT, check=True, timeout=900)
        for role, binary in names.items():
            context = prefix / binary
            context.mkdir(exist_ok=True)
            (context / "app").unlink(missing_ok=True)
            shutil.copyfile(prefix / "static/bin" / binary, context / "app")
            (context / "app").chmod(0o555)
            (context / "Dockerfile").write_text('FROM scratch\nCOPY app /bin/app\nENTRYPOINT ["/bin/app"]\n')
            self.env["HTTP_" + role + "_IMAGE"] = self.image(context)
        # Use the pinned Nix Python closure as an independent peer, without adding
        # a floating container dependency or a Python runtime to the Zig workers.
        context = prefix / "peer"
        context.mkdir(exist_ok=True)
        executable = Path(sys.executable).resolve()
        package = Path(*executable.parts[:4])
        closure = subprocess.check_output(["nix-store", "--query", "--requisites", str(package)], text=True).splitlines()
        for item in closure:
            destination = context / item.lstrip("/")
            if not destination.exists():
                shutil.copytree(item, destination, symlinks=True)
        shutil.copyfile(Path(__file__).with_name("peer.py"), context / "peer.py")
        (context / "Dockerfile").write_text('FROM scratch\nCOPY nix /nix\nCOPY peer.py /peer.py\nENTRYPOINT ' + json.dumps([str(executable), "-B", "/peer.py"]) + '\n')
        self.env["HTTP_PEER_IMAGE"] = self.image(context)

    def image(self, context):
        result = subprocess.run(["docker", "build", "--iidfile", str(context / "image.id"), str(context)],
                                capture_output=True, text=True, timeout=300)
        if result.returncode: raise RuntimeError(result.stderr[-4000:])
        return (context / "image.id").read_text().strip()

    def start(self, service):
        self.call("up", "-d", service)
        return Process(self, service, self.call("ps", "-q", service).strip())

    def address(self, service, network):
        identity = self.call("ps", "-q", service).strip()
        record = json.loads(subprocess.check_output(["docker", "inspect", identity], text=True))[0]
        return record["NetworkSettings"]["Networks"][self.project + "_" + network]["IPAddress"]

    @property
    def authority(self):
        return "http://node:8080"

    def url(self, service):
        return "http://" + self.address(service, "storage" if service == "ursula" else "client") + ":8080"

    def peer_requests(self):
        return json.loads((self.work / "peer/requests.json").read_text())

    def stop_peer(self, peer):
        peer.kill(); peer.wait(timeout=10)

    def invoke(self, service, *args):
        return json.loads(self.call("run", "--rm", "--no-deps", "-T", service, *args))

    def initialize(self):
        self.call("run", "--rm", "--no-deps", "-T", "node", "/node.json", "--initialize")

    def close(self):
        self.call("down", "--volumes", "--remove-orphans")

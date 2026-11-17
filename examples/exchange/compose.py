"""Physical placement only; signed Transit operations stay in the example runner."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "examples"))
from server_config import wait_started


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
    binary_names = None
    def __init__(self, work, protocol="http"):
        self.work = work
        (work / "authority").mkdir(mode=0o700, exist_ok=True)
        self.protocol = protocol
        assert protocol in ("http", "grpc", "document", "query", "serving", "flight", "sql-wire", "work-items")
        self.project = "transit-" + protocol + "-" + uuid.uuid4().hex[:10]
        self.env = os.environ | {"EXCHANGE_UID": str(os.getuid()), "EXCHANGE_GID": str(os.getgid()),
            "EXCHANGE_WORK": str(work)}
        self.command = ["docker", "compose", "--project-name", self.project, "--env-file", os.devnull,
                        "--file", str(Path(__file__).with_name("docker-compose.yaml"))]
        self.build()

    def prepare_storage_network(self):
        # Compose creates the isolated bridge and authority mount without
        # executing a node before its explicit configuration has been written.
        (self.work / 'operator/node.json').touch()
        self.call('create', 'node')

    def call(self, *args, timeout=120):
        result = subprocess.run([*self.command, *args], env=self.env, text=True, capture_output=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError(result.stderr[-4000:])
        return result.stdout

    def build(self):
        prefix = ROOT / f".cache/{self.protocol}-example/images"
        prefix.mkdir(parents=True, exist_ok=True)
        names = self.binary_names or {"NODE": "transit", "CALLER": f"example-station-{self.protocol}", "CONNECTOR": f"transit-station-{self.protocol}-worker"}
        architecture = subprocess.check_output(["docker", "info", "--format", "{{.Architecture}}"], text=True).strip()
        target = {"x86_64": "x86_64-linux-musl", "aarch64": "aarch64-linux-musl"}[architecture]
        # The composed server embeds SQL TLS. A musl target alone still picks
        # the development shell's shared OpenSSL; use the static toolchain.
        subprocess.run(["nix", "develop", str(ROOT) + "#release-checks", "--command", "zig", "build", *["test-native-authority-fixture" if name == "native-authority-fixture" else name for name in names.values()], "-Doptimize=ReleaseSafe", "-Dtarget=" + target,
                        "--prefix", str(prefix / "static")], cwd=ROOT, check=True, timeout=900)
        for role, binary in names.items():
            source = prefix / ("static/tests" if binary == "native-authority-fixture" else "static/bin") / binary
            if ('INTERP' in subprocess.check_output(['readelf', '-l', source], text=True) or
                    '(NEEDED)' in subprocess.check_output(['readelf', '-d', source], text=True)):
                raise RuntimeError(f'Container artifact {binary} requires a loader or shared library')
            context = prefix / binary
            context.mkdir(exist_ok=True)
            (context / "app").unlink(missing_ok=True)
            shutil.copyfile(source, context / "app")
            (context / "app").chmod(0o555)
            (context / "Dockerfile").write_text('FROM scratch\nCOPY app /bin/app\nENTRYPOINT ["/bin/app"]\n')
            self.env["EXCHANGE_" + role + "_IMAGE"] = self.image(context)
        # Use the pinned Nix Python closure as an independent peer, without adding
        # a floating container dependency or a Python runtime to the Zig workers.
        context = prefix / "peer"
        context.mkdir(exist_ok=True)
        executable = Path(sys.executable).resolve()
        package = Path(*executable.parts[:4])
        packages = [str(package)]
        python_paths = []
        if self.protocol == "grpc":
            import grpc
            site = Path(grpc.__file__).resolve().parent.parent
            python_paths.append(str(site))
            packages.append(str(Path(*site.parts[:4])))
        closure = subprocess.check_output(["nix-store", "--query", "--requisites", *packages], text=True).splitlines()
        for item in closure:
            destination = context / item.lstrip("/")
            if not destination.exists():
                shutil.copytree(item, destination, symlinks=True)
        shutil.copyfile(Path(__file__).with_name("peer.py"), context / "peer.py")
        (context / "Dockerfile").write_text('FROM scratch\nCOPY nix /nix\nCOPY peer.py /peer.py\nENV PYTHONPATH=' + json.dumps(':'.join(python_paths)) + '\nENTRYPOINT ' + json.dumps([str(executable), "-B", "/peer.py"]) + '\n')
        self.env["EXCHANGE_PEER_IMAGE"] = self.image(context)

    def image(self, context):
        result = subprocess.run(["docker", "build", "--iidfile", str(context / "image.id"), str(context)],
                                capture_output=True, text=True, timeout=300)
        if result.returncode: raise RuntimeError(result.stderr[-4000:])
        return (context / "image.id").read_text().strip()

    def start(self, service):
        self.call("up", "-d", service)
        process = Process(self, service, self.call("ps", "-q", service).strip())
        if service == "node" and self.server_owned:
            # Docker retains prior output when a stopped container is started
            # again. Readiness must belong to this start, including recovery.
            started = subprocess.check_output(["docker", "inspect", "--format",
                "{{.State.StartedAt}}", process.identity], text=True).strip()
            wait_started(process, lambda: subprocess.check_output([
                "docker", "logs", "--since", started, process.identity],
                text=True, stderr=subprocess.STDOUT))
        return process

    def address(self, service, network):
        identity = self.call("ps", "-q", service).strip()
        record = json.loads(subprocess.check_output(["docker", "inspect", identity], text=True))[0]
        return record["NetworkSettings"]["Networks"][self.project + "_" + network]["IPAddress"]

    @property
    def authority(self):
        return "http://node:8080"

    def url(self, service):
        return "http://" + self.address(service, "client") + ":8080"

    def peer_requests(self):
        return json.loads((self.work / "peer/requests.json").read_text())

    def stop_peer(self, peer):
        peer.kill(); peer.wait(timeout=10)

    def invoke(self, service, *args):
        return json.loads(self.call("run", "--rm", "--no-deps", "-T", service, *args))

    @property
    def server_owned(self):
        return self.binary_names is None or self.binary_names['NODE'] == 'transit'

    def initialize(self):
        if not self.server_owned:
            self.call("run", "--rm", "--no-deps", "-T", "node", "/node.json", "--initialize")
        # The product server initializes its retained installation on startup.

    def close(self):
        self.call("down", "--volumes", "--remove-orphans")

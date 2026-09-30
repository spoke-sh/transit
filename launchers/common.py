"""Development provisioning through the public CLI; never an execution authority."""
from contextlib import contextmanager
import fcntl
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlsplit

import settings

ROOT = Path(__file__).resolve().parents[1]
DEFINITION = json.loads((ROOT / "contracts/transit-v1.schema.json").read_text())["x-transit"]["definition"]
class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, url):
        return None


HTTP = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
SERVICES = ("ursula", "node", "maintenance", "delivery", "counter", "board")


def read_json(response, limit=256 * 1024):
    data = response.read(limit + 1)
    if len(data) > limit:
        raise RuntimeError("Response exceeded the public protocol size bound")
    return json.loads(data)


def run(argv, *, capture=False, timeout=60, **kwargs):
    result = subprocess.run(list(map(str, argv)), check=True, text=True,
                            stdout=subprocess.PIPE if capture else None,
                            timeout=timeout, **kwargs)
    return result.stdout if capture else None


def write(path, value):
    """Publish a complete private file, including across a launcher interruption."""
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = path.with_name(path.name + ".tmp-" + secrets.token_hex(4))
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w") as stream:
        stream.write(value if isinstance(value, str) else json.dumps(value, indent=2) + "\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temp, path)
    fd = os.open(path.parent, os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


@contextmanager
def lock(path):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    with path.open("a") as handle:
        fcntl.flock(handle, fcntl.LOCK_EX)
        yield


def healthy(url, headers=None):
    try:
        with HTTP.open(urllib.request.Request(url, headers=headers or {}), timeout=1) as response:
            return response.status == 200
    except (urllib.error.URLError, TimeoutError, ConnectionError):
        return False


def wait_for(url, seconds=45, headers=None):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if healthy(url, headers):
            return
        time.sleep(.2)
    raise RuntimeError(f"Not ready: {url}; inspect launcher status and logs")


class Installation:
    example = "counter"
    workloads = ("counter",)
    service_names = SERVICES
    local_topology = ROOT / "process-compose.yaml"
    compose_topology = ROOT / "docker-compose.yaml"
    def __init__(self, profile, name="default", base_port=None, board_settings=None):
        if not re.fullmatch(r"[a-z][a-z0-9-]{0,23}", name):
            raise ValueError("Name must be 1–24 lowercase letters, digits or hyphens, starting with a letter")
        self.profile, self.name = profile, name
        self.path = ROOT / ".cache/launchers" / profile / name
        self.base_port = base_port
        self.board_overrides = board_settings or {}
        self.manifest = self.path / "installation.json"
        self.lifecycle_lock = self.path.parent / (name + ".lock")

    @property
    def artifacts(self):
        from artifacts import Artifacts
        return Artifacts(self)

    @property
    def cli(self):
        return self.artifacts.binary("rey-cli")

    def load(self):
        value = json.loads(self.manifest.read_text())
        if (value["version"], value["profile"], value["name"]) != (1, self.profile, self.name):
            raise RuntimeError("Unrecognized launcher installation; refusing to adopt it")
        if value.get("protocol") != "native_v1":
            raise RuntimeError("Incompatible launcher protocol; preserve this installation and use its matching build")
        if value.get("definition") != DEFINITION:
            raise RuntimeError("Incompatible launcher definition; preserve this installation and use its matching build")
        if value.get("example", "counter") != self.example:
            raise RuntimeError("This installation runs another example; choose a new name")
        if self.path.is_symlink():
            raise RuntimeError("Launcher state must not be a symbolic link")
        return value

    @property
    def url(self):
        return f'http://127.0.0.1:{self.load()["base_port"] + 1}'

    @property
    def origin(self):
        return self.board["public_origin"]

    @property
    def board(self):
        config = self.load()
        return config.get("board", settings.defaults(config["base_port"]))

    @property
    def board_probe_host(self):
        return "127.0.0.1" if self.board["host"] == "0.0.0.0" else self.board["host"]

    @property
    def board_url(self):
        return f'http://{self.board_probe_host}:{self.board["port"]}'

    @property
    def board_headers(self):
        return {"Host": urlsplit(self.origin).netloc}

    def configure_board(self):
        # Called only after verifying that this installation is stopped.
        # Environment changes never alter status/down or a running listener.
        config = self.load()
        board = settings.resolve(self.board, self.board_overrides, config["base_port"])
        self.check_ports(board)
        diagnostics = settings.observability(config.get("observability", {}), self.profile, self.artifacts.roles([]))
        write(self.manifest, {**config, "board": board, "observability": diagnostics})

    def service_environment(self, name):
        values = self.load().get("observability", {}).get(name, {})
        return {"LOG_LEVEL": values.get("level", "info"),
                "LOG_FORMAT": values.get("format", "text" if self.profile == "local" else "json")}

    def key(self, relative):
        path = self.path / relative
        if not path.exists():
            write(path, secrets.token_hex(32))
        return json.loads(run([self.cli, "public-key", path], capture=True))

    def prepare(self):
        if self.manifest.exists():
            config = self.load()
            if self.base_port is not None and self.base_port != config["base_port"]:
                raise RuntimeError("Ports are persisted; choose another launcher name to use different ports")
            return
        if self.path.exists():
            raise RuntimeError("Incomplete installation directory; inspect and move it aside before provisioning")
        self.artifacts.initialize()
        base = self.base_port if self.base_port is not None else (18100 if self.profile == "local" else 18200)
        if not 1024 <= base <= 65533:
            raise ValueError("Base port must be between 1024 and 65533")
        self.path.mkdir(parents=True, mode=0o700)
        root_public = self.key("operator/root.key")
        self.key("board/seed.key")
        self.key("maintenance/seed.key")
        write(self.path / "operator/sequence.json", {"sequence": 0, "pending": None})
        (self.path / "wal").mkdir(mode=0o700)
        write(self.manifest, {"version": 1, "profile": self.profile, "name": self.name, "example": self.example,
              "protocol": "native_v1", "definition": DEFINITION,
              "project": "rey-" + self.profile + "-" + secrets.token_hex(6),
              "realm": secrets.randbelow(2**31 - 1) + 1, "base_port": base, "root_public": root_public})
        self.configs()

    def configs(self):
        config = self.load()
        container = self.profile == "compose"
        base = config["base_port"]
        storage = "http://ursula:8080" if container else f"http://127.0.0.1:{base}"
        self.upstream = "http://node:8080" if container else self.url
        node = {"genesis": {"realm": config["realm"], "root_key": config["root_public"]},
                "ursula_url": storage, "bucket": "development", "journal": "authority", "accept_trace_parent": True,
                "listen": "0.0.0.0" if container else "127.0.0.1", "port": 8080 if container else base + 1}
        node["genesis"]["max_clock_error_ms"] = 10000
        write(self.path / "node.json", node)
        write(self.path / "host-node.json", {**node, "ursula_url": f"http://127.0.0.1:{base}"})
        write(self.path / "maintenance/config.json", {**node, "maintenance": {
              "principal": 3, "seed_file": "/maintenance/seed.key" if container else str(self.path / "maintenance/seed.key")}})
        self.key("delivery/seed.key")
        write(self.path / "delivery/config.json", {"url": self.upstream, "realm": config["realm"],
              "principal": 5, "seed_file": "/delivery/seed.key" if container else str(self.path / "delivery/seed.key")})
        pid_file = self.path / "pid.json"
        pid = json.loads(pid_file.read_text()) if pid_file.exists() else None
        write(self.path / "board/config.json", {"upstream": self.upstream, "realm": config["realm"],
              "principal": 2, "seed_file": "/board/seed.key" if container else str(self.path / "board/seed.key"),
              "public_origin": self.origin, "listen": "0.0.0.0" if container else self.board["host"],
              "port": 8080 if container else self.board["port"],
              "development_allow_insecure_http": self.board["allow_insecure_http"]})
        address = "0.0.0.0:8080" if container else f"127.0.0.1:{base}"
        wal = "/wal" if container else str(self.path / "wal")
        write(self.path / "ursula.toml", f'''[server]
listen = "{address}"
admin_listen = "127.0.0.1:0"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = {json.dumps(wal)}
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
''')

    def initialize(self):
        # Only this explicit provisioning path can create history. Ordinary
        # service restarts fail closed if storage has disappeared.
        if not (self.path / "initialized.json").exists():
            run([self.artifacts.binary("transit-node"), self.path / "host-node.json", "--initialize"])
            write(self.path / "initialized.json", True)

    def check_ports(self, board=None):
        board = board or self.board
        base = self.load()["base_port"]
        listeners = []
        try:
            for host, port in (("127.0.0.1", base), ("127.0.0.1", base + 1), (board["host"], board["port"])):
                listener = socket.socket()
                listeners.append(listener)
                listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                listener.bind((host, port))
        except OSError as error:
            raise RuntimeError(f"Port {port} is already in use; refusing to adopt another service") from error
        finally:
            for listener in listeners:
                listener.close()

    def _flush(self, state):
        pending = state["pending"]
        if pending is None:
            return
        request_file = self.path / "operator/pending.json"
        write(request_file, pending["request"])
        signed = run([self.cli, "sign", self.path / "operator/root.key", request_file], capture=True).encode()
        deadline = time.monotonic() + 20
        while True:
            try:
                request = urllib.request.Request(self.url + "/v1/command", signed, {"Content-Type": "application/json"})
                with HTTP.open(request, timeout=6) as response:
                    receipt = read_json(response, 1024)
                if (not isinstance(receipt, dict) or set(receipt) != {"position"}
                        or type(receipt["position"]) is not int or not 1 <= receipt["position"] < 2**53):
                    raise RuntimeError("Invalid receipt; pending request preserved for an exact retry")
                break
            except urllib.error.HTTPError as error:
                if error.code not in (409, 503):
                    raise RuntimeError(f"Pending operation {pending['id']} rejected: {error.read(8192).decode(errors='replace')}") from error
            except (urllib.error.URLError, TimeoutError, ConnectionError):
                pass
            if time.monotonic() >= deadline:
                raise RuntimeError(f"Outcome uncertain for {pending['id']}; saved request will be retried unchanged")
            time.sleep(.2)
        write(self.path / "operator/receipts" / (pending["id"] + ".json"), {**pending, "receipt": receipt})
        state.update(sequence=pending["request"]["sequence"], pending=None)
        write(self.path / "operator/sequence.json", state)

    def command(self, identity, body):
        if not re.fullmatch(r"[a-zA-Z0-9_-]{1,80}", identity):
            raise ValueError("Request ID must contain 1–80 letters, digits, underscores or hyphens")
        with lock(self.path / "operator/lock"):
            state = json.loads((self.path / "operator/sequence.json").read_text())
            self._flush(state)
            receipt = self.path / "operator/receipts" / (identity + ".json")
            if receipt.exists():
                recorded = json.loads(receipt.read_text())
                if recorded["request"]["command"] != body:
                    raise RuntimeError("Request ID was already used with different content")
                return recorded["receipt"]["position"]
            state["pending"] = {"id": identity, "request": {"realm": self.load()["realm"],
                "principal": 0, "sequence": state["sequence"] + 1, "command": body}}
            write(self.path / "operator/sequence.json", state)
            self._flush(state)
            return json.loads(receipt.read_text())["receipt"]["position"]

    def provision(self):
        pid = self.command("spawn-counter", {"create": {"required": [b"counter".hex(), None, None, None]}})
        write(self.path / "pid.json", pid)
        for principal, label, permissions in ((2, "board", 16), (3, "maintenance", 161), (5, "delivery", 132)):
            self.command("grant-" + label, {"grant": {"subject": principal,
                "public_key": self.key(label + "/seed.key"), "permissions": permissions}})
        resource = self.command("create-counter-state", {"create_resource": {"writer": pid}})
        write(self.path / "state-resource.json", resource)
        self.command("inspect-counter-state", {"grant_resource": {"resource": resource, "subject": 0, "permissions": 7}})
        self.command("associate-counter-state", {"associate": {"pid": pid, "name": b"counter".hex(), "resource": resource}})
        self.command("board-counter-state", {"grant_resource": {"resource": resource, "subject": 2, "permissions": 1}})
        self.command("initialize-counter", {"initialize": {"pid": pid, "expected_generation": 1}})
        for value in (7, 5):
            self.command(f"seed-{value}", {"send": {"pid": pid, "value": str(value).encode().hex()}})
        self.configs()

    def activate(self, name="counter"):
        if name != "counter":
            raise ValueError("Unknown workload")
        # The launcher is a trusted operator for a caller without a provider
        # binding. Never manufacture Substrate observations or runtime authority.
        with lock(self.path / "activation.lock"):
            pid = json.loads((self.path / "pid.json").read_text())
            with lock(self.path / "operator/lock"):
                self._flush(json.loads((self.path / "operator/sequence.json").read_text()))
            view = self.native_query({"process": pid})["body"]["process"]["process"]
            if view["lifecycle"] != "running" or view["failure"] or view["binding"]:
                raise RuntimeError("Counter is retired, blocked or provider-bound; refusing automatic replacement")
            identity = secrets.token_hex(12)
            write(self.path / "counter/seed.key", secrets.token_hex(32))
            public = self.key("counter/seed.key")
            self.command("worker-grant-" + identity, {"grant": {"subject": 1, "public_key": public, "permissions": 24, "pid": pid}})
            self.grant_counter_state(identity)
            self.command("worker-own-" + identity, {"own": {"pid": pid, "worker": 1, "expected_generation": view["generation"]}})
            write(self.path / "counter/config.json", {"url": "http://node:8080" if self.profile == "compose" else self.url,
                "realm": self.load()["realm"], "principal": 1, "pid": pid, "generation": view["generation"] + 1,
                "seed_file": "/counter/seed.key" if self.profile == "compose" else str(self.path / "counter/seed.key"),
                **self.counter_config()})

    def counter_config(self):
        return {"state_association": "counter"}

    def grant_counter_state(self, identity):
        resource = json.loads((self.path / "state-resource.json").read_text())
        self.command("worker-state-" + identity, {"grant_resource": {"resource": resource, "subject": 1, "permissions": 7}})

    def native_query(self, kind):
        read = self.path / "operator/read.json"
        write(read, {"realm": self.load()["realm"], "principal": 0, "kind": kind})
        command = list(map(str, [self.cli, "query", self.path / "operator/root.key", read, self.url]))
        deadline = time.monotonic() + 20
        while True:
            result = subprocess.run(command, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                return json.loads(result.stdout)
            # Concurrent workers can occupy the authority's finite read slots.
            # Retry only a read with a classified transient transport result.
            transient = result.stderr.rstrip().endswith(("error: AuthorityUnavailable", "error: AuthorityTimeout", "error: HttpConnectionClosing"))
            if not transient or time.monotonic() >= deadline:
                print(result.stderr, file=sys.stderr, end="")
                result.check_returncode()
            time.sleep(.1)

    def counter_value(self):
        # Example-specific decoding belongs in the example/operator tools, not Board.
        resource = json.loads((self.path / "state-resource.json").read_text())
        entries = self.native_query({"read_entries": {"resource": resource,
            "keys": [b"value".hex()] + [None] * 7}})["body"]["read_entries"]["entries"]
        return int(bytes.fromhex(entries[0]["value"])) if entries[0] else 0

    def view(self):
        pid = json.loads((self.path / "pid.json").read_text())
        return self.native_query({"process": pid})["body"]["process"]["process"]

    def validate_counter_update(self):
        process = self.view()
        if process["code"] != 1 or process["failure"] or process["lifecycle"] != "running":
            raise RuntimeError("Counter update requires the compatible code=1 contract and a running, unblocked PID")
        if process["binding"] and self.profile != "reference":
            raise RuntimeError("Provider-bound code must be upgraded by its reference launcher")

    def validate_workload_update(self, name):
        if name != "counter":
            raise ValueError("Unknown workload")
        self.validate_counter_update()

    def send_value(self, value):
        number = int(value)
        if not -(2**63) <= number < 2**63:
            raise ValueError("Counter input must fit a signed 64-bit integer")
        return {"send": {"pid": self.endpoints()["pid"], "value": str(number).encode().hex()}}

    def endpoints(self):
        return {"profile": self.profile, "name": self.name, "realm": self.load()["realm"],
                "pid": json.loads((self.path / "pid.json").read_text()) if (self.path / "pid.json").exists() else None,
                "board": self.origin, "transit": self.url, "state": str(self.path),
                "board_host": self.board["host"], "board_port": self.board["port"]}

    def inspect(self):
        request = urllib.request.Request(self.board_url + "/api/v1/processes", headers=self.board_headers)
        with HTTP.open(request, timeout=5) as response:
            return read_json(response)

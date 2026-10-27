"""Private native-local installation setup and owned manager process mechanics."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request

from harness.services import free_port
from harness.processes import children, joined


def freeze_executables(fixture):
    """Keep a source-built fixture independent of later workspace builds."""
    directory = fixture.root / 'bin'
    directory.mkdir(mode=0o700)
    for key, name in [('node', 'transit-node'), ('query_host', 'transit-query-host'),
                      ('board', 'transit-board'), ('sql_gateway', 'transit-sql-gateway')]:
        destination = directory / name
        shutil.copy2(fixture.config['executables'][key], destination)
        fixture.config['executables'][key] = str(destination)


class LocalInstallation:
    def __init__(self, cli, node, host, parent="/var/tmp"):
        self.root = Path(tempfile.mkdtemp(prefix="transit-server-proof-", dir=parent))
        # Keep retained artifact identity stable if another build updates zig-out.
        self.cli = str(self.root / "transit")
        shutil.copy2(Path(cli).resolve(), self.cli)
        self.reserved_ports = set()
        ports = [self.reserve_port() for _ in range(3)]
        self.config = {"version": 1, "installation": str(self.root / "installation"), "realm": 73,
            "ports": dict(zip(("node", "gateway"), ports[:2])),
            "sql": {"health_port": ports[2]},
            "executables": {"node": str(Path(node).resolve()), "query_host": str(Path(host).resolve()),
                "sql_gateway": os.environ.get("TEST_TRANSIT_SQL_GATEWAY_BINARY", str(Path(cli).resolve().parent / "transit-sql-gateway")),
                "board": os.environ.get("TEST_TRANSIT_BOARD_BINARY", str(Path(cli).resolve().parent / "transit-board"))}}
        self.path = self.root / "transit.yaml"
        self.path.write_text(json.dumps(self.config))
        self.no_ui = True
        self.process = None
        self.logs = []
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.url = f"http://127.0.0.1:{self.config['ports']['gateway']}"

    def reserve_port(self):
        # Closing an ephemeral bind can let the OS return that same port again.
        # Keep every role in this fixture distinct, including later SQL roles.
        while True:
            port = free_port()
            if port not in self.reserved_ports:
                self.reserved_ports.add(port)
                return port

    @property
    def installation(self):
        return self.root / "installation"

    def record(self):
        return json.loads((self.installation / "installation.json").read_text())

    def start(self):
        assert self.process is None
        log = (self.root / f"manager-{len(self.logs)}.stderr").open("wb")
        self.logs.append(log)
        args = [self.cli, "server", "--config", str(self.path)]
        if self.no_ui:
            args.append("--no-ui")
        self.process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=log,
            cwd=self.root, env={"PATH": "/unavailable", "LANG": "C"})

    def stop(self, kill=False):
        if self.process is None:
            return
        owned = children(self.process.pid)
        running = self.process.poll() is None
        if running:
            self.process.kill() if kill else self.process.terminate()
        self.process.wait(timeout=20)
        if running and not kill:
            assert self.process.returncode == 0, Path(self.logs[-1].name).read_text()
        joined(owned)
        self.process.stdout.close()
        self.process = None

    def cleanup(self):
        self.stop()
        for log in self.logs:
            log.close()


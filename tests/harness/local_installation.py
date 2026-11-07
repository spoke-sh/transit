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
from harness.phases import phase


@phase("artifact-copy", "local-installation")
def freeze_executables(fixture):
    """Keep a source-built fixture independent of later workspace builds."""
    directory = fixture.root / 'bin'
    directory.mkdir(mode=0o700)
    cli_path = Path(fixture.cli)
    for key, name in [('node', 'transit-node'), ('query_host', 'transit-query-host'),
                      ('board', 'transit-board'), ('sql_gateway', 'transit-sql-gateway')]:
        source = Path(fixture.config['executables'][key])
        destination = directory / name
        if source.exists() and cli_path.exists() and os.path.samefile(source, cli_path):
            os.link(cli_path, destination)
        else:
            shutil.copy2(source, destination)
        fixture.config['executables'][key] = str(destination)


class LocalInstallation:
    def __init__(self, cli, node=None, host=None, parent="/var/tmp"):
        self.root = Path(tempfile.mkdtemp(prefix="transit-server-proof-", dir=parent))
        # Keep retained artifact identity stable if another build updates zig-out.
        self.cli = str(self.root / "transit")
        cli_resolved = Path(cli).resolve()
        shutil.copy2(cli_resolved, self.cli)
        node_resolved = cli_resolved if node is None else Path(node).resolve()
        host_resolved = cli_resolved if host is None else Path(host).resolve()
        default_gateway = cli_resolved.parent / "transit-sql-gateway"
        default_board = cli_resolved.parent / "transit-board"
        gateway_resolved = Path(os.environ.get("TEST_TRANSIT_SQL_GATEWAY_BINARY",
            str(default_gateway if default_gateway.exists() or host_resolved != cli_resolved else cli_resolved))).resolve()
        board_resolved = Path(os.environ.get("TEST_TRANSIT_BOARD_BINARY",
            str(default_board if default_board.exists() or host_resolved != cli_resolved else cli_resolved))).resolve()
        executables = {}
        for key, name, resolved in (
            ("node", "transit-node", node_resolved),
            ("query_host", "transit-query-host", host_resolved),
            ("sql_gateway", "transit-sql-gateway", gateway_resolved),
            ("board", "transit-board", board_resolved),
        ):
            if resolved == cli_resolved:
                role_path = self.root / name
                os.link(self.cli, role_path)
                executables[key] = str(role_path)
            else:
                executables[key] = str(resolved)
        self.reserved_ports = set()
        ports = [self.reserve_port() for _ in range(3)]
        self.config = {"version": 1, "installation": str(self.root / "installation"), "realm": 73,
            "ports": dict(zip(("node", "gateway"), ports[:2])),
            "sql": {"health_port": ports[2]},
            "executables": executables}
        self.path = self.root / "transit.yaml"
        self.path.write_text(json.dumps(self.config))
        self.no_ui = True
        self.runtime_directory = None
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

    def use_private_runtime(self):
        """Keep local SQL sockets on this fixture's filesystem across restarts."""
        self.runtime_directory = self.root / 'runtime'
        self.runtime_directory.mkdir(mode=0o700, exist_ok=True)

    @property
    def environment(self):
        values = {"PATH": "/unavailable", "LANG": "C"}
        if self.runtime_directory is not None:
            values['XDG_RUNTIME_DIR'] = str(self.runtime_directory)
        return values

    @phase("process-start", "local-installation")
    def start(self):
        assert self.process is None
        log = (self.root / f"manager-{len(self.logs)}.stderr").open("wb")
        self.logs.append(log)
        args = [self.cli, "server", "--config", str(self.path)]
        if self.no_ui:
            args.append("--no-ui")
        self.process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=log,
            cwd=self.root, env=self.environment)

    @phase("teardown", "local-installation")
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

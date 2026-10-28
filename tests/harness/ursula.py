"""Owned disk-backed Ursula fixture, separate from generic service mechanics."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.request

from .services import free_ports, wait_ready
from .phases import phase


class Fixture:
    """An isolated owned disk store, reusable by service and storage proofs."""
    def __init__(self, storage_config=None, *, retain_on_failure=False):
        self.retain_on_failure = retain_on_failure
        # Keep the original absolute paths: saved installation profiles can bind
        # them. Nix's temporary directory disappears when its shell exits.
        self.directory = tempfile.TemporaryDirectory(
            prefix="transit-storage-", dir="/var/tmp" if retain_on_failure else None,
            delete=not retain_on_failure,
        )
        self.root = Path(self.directory.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
        self.env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2")
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        # Ursula binds admin before public traffic. An ephemeral admin listener
        # can consume the selected public port, including during a restart.
        self.port, admin_port = free_ports(2)
        self.url = f"http://127.0.0.1:{self.port}"
        self.config = self.root / "ursula.toml"
        storage_config = storage_config or '''[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
'''
        self.config.write_text(f'''[server]
listen = "127.0.0.1:{self.port}"
admin_listen = "127.0.0.1:{admin_port}"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "{self.root / 'wal'}"
{storage_config}
''')
        self.server = None
        self.log = (self.root / "ursula.log").open("w+")

    @phase("provision", "ursula")
    def start(self):
        assert self.server is None
        self.server = subprocess.Popen(
            ["ursula", "server", "--config", str(self.config)],
            env=self.env, cwd=self.root, stdout=self.log, stderr=subprocess.STDOUT,
        )
        wait_ready(self.http, self.server, self.url + "/__ursula/ready")

    @phase("teardown", "ursula")
    def stop(self):
        if self.server is not None:
            if self.server.poll() is None:
                self.server.kill()
            self.server.wait(timeout=10)
            self.server = None

    def __enter__(self):
        try:
            self.start()
            return self
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise

    def __exit__(self, exc_type, *_):
        self.stop()
        if exc_type:
            self.log.flush()
            self.log.seek(0)
            sys.stderr.write(self.log.read()[-12000:])
        self.log.close()
        if exc_type and self.retain_on_failure:
            print(f"Failed private installation retained at {self.root}", file=sys.stderr)
        else:
            self.directory.cleanup()

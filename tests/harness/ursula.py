"""Owned disk-backed Ursula fixture, separate from generic service mechanics."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import urllib.request

from .services import free_port, wait_ready


class Fixture:
    """An isolated owned disk store, reusable by service and storage proofs."""
    def __init__(self, storage_config=None):
        self.directory = tempfile.TemporaryDirectory(prefix="transit-storage-")
        self.root = Path(self.directory.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
        self.env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2")
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.port = free_port()
        self.url = f"http://127.0.0.1:{self.port}"
        self.config = self.root / "ursula.toml"
        storage_config = storage_config or '''[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
'''
        self.config.write_text(f'''[server]
listen = "127.0.0.1:{self.port}"
admin_listen = "127.0.0.1:0"
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

    def start(self):
        assert self.server is None
        self.server = subprocess.Popen(
            ["ursula", "server", "--config", str(self.config)],
            env=self.env, cwd=self.root, stdout=self.log, stderr=subprocess.STDOUT,
        )
        wait_ready(self.http, self.server, self.url + "/__ursula/ready")

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
        self.directory.cleanup()


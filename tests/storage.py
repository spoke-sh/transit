#!/usr/bin/env python3
"""Own a loopback disk-backed Ursula fixture; kill and restart it between proofs."""
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request


class Fixture:
    """An isolated owned disk store, reusable by service and storage proofs."""
    def __init__(self):
        self.directory = tempfile.TemporaryDirectory(prefix="rey-storage-")
        self.root = Path(self.directory.name)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
        self.env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2")
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.port = free_port()
        self.url = f"http://127.0.0.1:{self.port}"
        self.config = self.root / "ursula.toml"
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
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
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


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def wait_ready(http, process, url):
    deadline = time.monotonic() + 30
    while True:
        if process.poll() is not None:
            raise RuntimeError("Service exited before readiness")
        try:
            with http.open(url, timeout=0.5) as response:
                if response.status == 200:
                    return
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            pass
        if time.monotonic() > deadline:
            raise TimeoutError("Service readiness deadline")
        time.sleep(0.05)


def run(binaries):
    with Fixture() as fixture:
        for index, phase in enumerate(("write", "recover", "checkpoint", "trim_recover")):
            if index:
                fixture.start()
            for binary in binaries:
                subprocess.run([str(binary), fixture.url, phase], env=fixture.env, check=True, timeout=120)
            # SIGKILL tests the WAL boundary, not graceful shutdown flushes.
            fixture.stop()
    print("Disk WAL survives SIGKILL; one conditional successor and bounded replay verified.")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    run([Path(arg).resolve(strict=True) for arg in sys.argv[1:]])

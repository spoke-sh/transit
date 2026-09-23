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


def run(binaries):
    env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
    env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2")
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with tempfile.TemporaryDirectory(prefix="rey-storage-") as directory:
        root = Path(directory)
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        url = f"http://127.0.0.1:{port}"
        config = root / "ursula.toml"
        config.write_text(f'''[server]
listen = "127.0.0.1:{port}"
admin_listen = "127.0.0.1:0"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "{root / 'wal'}"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
''')
        for phase in ("write", "recover", "checkpoint", "trim_recover"):
            with (root / f"{phase}.log").open("w+") as log:
                server = subprocess.Popen(
                    ["ursula", "server", "--config", str(config)],
                    env=env, cwd=root, stdout=log, stderr=subprocess.STDOUT,
                )
                try:
                    deadline = time.monotonic() + 30
                    while True:
                        if server.poll() is not None:
                            raise RuntimeError("Ursula exited before readiness")
                        try:
                            with http.open(url + "/__ursula/ready", timeout=0.5) as response:
                                if response.status == 200:
                                    break
                        except (urllib.error.URLError, TimeoutError):
                            pass
                        if time.monotonic() > deadline:
                            raise TimeoutError("Ursula readiness deadline")
                        time.sleep(0.05)
                    for binary in binaries:
                        subprocess.run([str(binary), url, phase], env=env, check=True, timeout=120)
                except BaseException:
                    log.flush()
                    log.seek(0)
                    sys.stderr.write(log.read()[-12000:])
                    raise
                finally:
                    # SIGKILL tests the WAL boundary, not graceful shutdown flushes.
                    if server.poll() is None:
                        server.kill()
                    server.wait(timeout=10)
        print("Disk WAL survives SIGKILL; one conditional successor and bounded replay verified.")


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: (_ for _ in ()).throw(KeyboardInterrupt()))
    run([Path(arg).resolve(strict=True) for arg in sys.argv[1:]])

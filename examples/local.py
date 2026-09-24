#!/usr/bin/env python3
"""Provision an owned local demo; application execution lives in the Zig examples."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def run(name, board=False):
    binaries = {n: ROOT / "zig-out/bin" / n for n in ("transit-node", "rey-cli", f"example-{name}")}
    if board:
        binaries["board"] = ROOT / "zig-out/bin/transit-board"
    for binary in binaries.values():
        if not binary.is_file():
            raise RuntimeError("Build first with: nix develop --command zig build apps examples")
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    env = {k: v for k, v in os.environ.items() if not k.startswith(("URSULA_", "OTEL_"))}
    env.update(RUST_LOG="warn", TOKIO_WORKER_THREADS="2")
    with tempfile.TemporaryDirectory(prefix=f"rey-example-{name}-") as directory:
        work = Path(directory)
        children, logs = [], []

        def start(argv):
            log = (work / f"service-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen(list(map(str, argv)), cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            return child

        def ready(child, url):
            deadline = time.monotonic() + 30
            while child.poll() is None and time.monotonic() < deadline:
                try:
                    with http.open(url, timeout=0.5) as response:
                        if response.status == 200:
                            return
                except (urllib.error.URLError, TimeoutError, ConnectionError):
                    pass
                time.sleep(0.05)
            raise RuntimeError(f"Service did not become ready: {url}")

        def invoke(*argv):
            return json.loads(subprocess.check_output(list(map(str, argv)), env=env, timeout=30))

        def key(label):
            path = work / f"{label}.key"
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            return path, invoke(binaries["rey-cli"], "public-key", path)

        def write(label, value):
            path = work / f"{label}.json"
            path.write_text(json.dumps(value))
            return path

        try:
            storage_port = free_port()
            ursula_url = f"http://127.0.0.1:{storage_port}"
            config = work / "ursula.toml"
            config.write_text(f'''[server]
listen = "127.0.0.1:{storage_port}"
admin_listen = "127.0.0.1:0"
[runtime]
core_count = 2
[raft]
node_id = 1
group_count = 1
[raft.wal]
backend = "disk"
path = "{work / 'wal'}"
[storage.cold]
backend = "none"
[storage.snapshot]
backend = "inline"
''')
            storage = start(["ursula", "server", "--config", config])
            ready(storage, ursula_url + "/__ursula/ready")
            root_key, root_public = key("root")
            worker_key, worker_public = key("caller")
            port = free_port()
            url = f"http://127.0.0.1:{port}"
            node = write("node", {"genesis": {"realm": 71, "root_key": root_public},
                "ursula_url": ursula_url, "bucket": f"example-{name}", "journal": "authority", "port": port})
            authority = start([binaries["transit-node"], node, "--bootstrap"])
            ready(authority, url + "/health")
            sequence = 0

            def command(value):
                nonlocal sequence
                sequence += 1
                request = write(f"request-{sequence}", {"realm": 71, "principal": 0, "sequence": sequence, "command": value})
                return invoke(binaries["rey-cli"], "submit", root_key, request, url)["position"]

            pid = command({"spawn": {"initial_state": (b"0" if name == "counter" else b"").hex()}})
            command({"grant": {"subject": 1, "public_key": worker_public, "permissions": 24, "pid": pid}})
            command({"own": {"pid": pid, "worker": 1, "expected_generation": 0}})
            values = [b"7", b"5"] if name == "counter" else [b"hello", b" world"]
            for value in values:
                command({"send": {"pid": pid, "value": value.hex()}})
            caller = write("caller", {"url": url, "realm": 71, "principal": 1, "pid": pid,
                                       "generation": 1, "seed_file": str(worker_key)})
            for _ in values:
                invoke(binaries[f"example-{name}"], "--once", caller)
            read = write("read", {"realm": 71, "principal": 0, "sequence": 0, "command": {"inspect": pid}})
            view = invoke(binaries["rey-cli"], "view", root_key, read, url)
            expected = b"12" if name == "counter" else b"hello world"
            actual = bytes.fromhex(view["process"]["state"])
            assert actual == expected and view["process"]["consumed"] == len(values), view
            print(f"{name}: state={actual.decode()!r}, consumed={len(values)}, pending={view['input']}")
            if board:
                reader_key, reader_public = key("board-reader")
                command({"grant": {"subject": 2, "public_key": reader_public, "permissions": 16}})
                board_port = free_port()
                origin = f"http://127.0.0.1:{board_port}"
                options = {"upstream": url, "realm": 71, "principal": 2, "seed_file": str(reader_key),
                           "public_origin": origin, "port": board_port}
                viewer = start([binaries["board"], write("board", options)])
                ready(viewer, origin + "/health")
                # Keep an admitted input visible; there is no worker executing it.
                command({"send": {"pid": pid, "value": (b"3" if name == "counter" else b"!").hex()}})
                print(f"Board: {origin}\nOpen the URL to inspect. Ctrl-C removes this disposable realm.", flush=True)
                while viewer.poll() is None:
                    time.sleep(.5)
                raise RuntimeError("Board stopped unexpectedly")
        except KeyboardInterrupt:
            if not board:
                raise
        except BaseException:
            for log in logs:
                log.flush()
                print(Path(log.name).read_text()[-4000:])
            raise
        finally:
            for child in reversed(children):
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            for log in logs:
                log.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", choices=("counter", "byte-log"))
    parser.add_argument("--board", action="store_true", help="Keep the demo open in Board")
    args = parser.parse_args()
    run(args.name, args.board)

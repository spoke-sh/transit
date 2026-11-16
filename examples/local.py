#!/usr/bin/env python3
"""Provision an owned local demo; application execution lives in the Zig examples."""
import argparse
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'examples'))
from server_config import configuration as server_configuration, ServerProcess, wait_started
sys.path.insert(0, str(ROOT / "launchers"))
from native_client import Client, public_key


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def run(name, board=False):
    binaries = {n: ROOT / "zig-out/bin" / n for n in ("transit", "transit-client-host", f"example-{name}")}
    if board:
        binaries["board"] = ROOT / "zig-out/bin/transit-board"
    for binary in binaries.values():
        if not binary.is_file():
            raise RuntimeError("Build first with: nix develop --command zig build apps examples")
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    env = {k: v for k, v in os.environ.items() if not k.startswith(("OTEL_",))}
    with tempfile.TemporaryDirectory(prefix=f"transit-example-{name}-") as directory:
        work = Path(directory)
        children, logs = [], []

        def start(argv):
            log = (work / f"service-{len(logs)}.log").open("w+")
            logs.append(log)
            process_type = ServerProcess if str(argv[0]) == str(binaries["transit"]) else subprocess.Popen
            child = process_type(list(map(str, argv)), cwd=work, env=env, stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            if str(argv[0]) == str(binaries["transit"]):
                wait_started(child, lambda: Path(log.name).read_text())
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
            return path, public_key(path)

        def write(label, value):
            path = work / f"{label}.json"
            path.write_text(json.dumps(value))
            return path

        try:
            root_key, root_public = key("root")
            worker_key, worker_public = key("caller")
            port = free_port()
            url = f"http://127.0.0.1:{port}"
            node = write("node", server_configuration(71, root_key,
                installation=work / 'installation', port=port, listen='127.0.0.1'))
            authority = start([binaries["transit"], "server", "--no-ui", "--config", node])
            ready(authority, url + "/health")
            sequence = Client(binaries["transit-client-host"], url).query(root_key,
                dict(realm=71, principal=0, kind=dict(capabilities={})))['principal_sequence']

            def command(value):
                nonlocal sequence
                sequence += 1
                request = write(f"request-{sequence}", {"realm": 71, "principal": 0, "sequence": sequence, "command": value})
                return Client(binaries["transit-client-host"], url).submit(root_key, json.loads(request.read_text()))["position"]

            pid = command({"spawn": {}})
            command({"grant": {"subject": 1, "public_key": worker_public, "permissions": 24, "pid": pid}})
            resource = command({"create_resource": {"writer": pid}})
            for subject in (0, 1):
                command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
            association = "counter" if name == "counter" else "data"
            command({"associate": {"pid": pid, "name": association.encode().hex(), "resource": resource}})
            command({"own": {"pid": pid, "worker": 1, "expected_generation": 1}})
            values = [b"7", b"5"] if name == "counter" else [b"hello", b" world"]
            for value in values:
                command({"send": {"pid": pid, "value": value.hex()}})
            caller = write("caller", {"url": url, "realm": 71, "principal": 1, "pid": pid,
                                       "generation": 2, "seed_file": str(worker_key)})
            for _ in values:
                invoke(binaries[f"example-{name}"], "--once", caller)
            def query(kind):
                request = write("read", {"realm": 71, "principal": 0, "kind": kind})
                return Client(binaries["transit-client-host"], url).query(root_key, json.loads(request.read_text()))["body"]
            view = query({"process": pid})["process"]
            entries = query({"read_entries": {"resource": resource, "keys": [b"value".hex()] + [None]*7}})["read_entries"]["entries"]
            expected = b"12" if name == "counter" else b"hello world"
            actual = bytes.fromhex(entries[0]["value"])
            assert actual == expected and view["process"]["consumed"] == len(values), view
            print(f"{name}: state={actual.decode()!r}, consumed={len(values)}, pending={view['input']}")
            if board:
                reader_key, reader_public = key("board-reader")
                command({"grant": {"subject": 2, "public_key": reader_public, "permissions": 16}})
                command({"grant_resource": {"resource": resource, "subject": 2, "permissions": 3}})
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

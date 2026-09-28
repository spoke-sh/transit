#!/usr/bin/env python3
"""Actual local CLI commands, disk providers and owned Linux child failure proofs."""
import ctypes
import json
import os
from pathlib import Path
import select
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

from cold_storage import IMAGE
from storage import free_port


def minio_binary():
    """Fixture setup only. The server itself receives a native executable path."""
    path = Path(".cache/dependencies/minio-14cea493").resolve()
    if not path.exists():
        path.parent.mkdir(parents=True, exist_ok=True)
        container = subprocess.check_output(["docker", "create", IMAGE], text=True).strip()
        try:
            subprocess.run(["docker", "cp", container + ":/usr/bin/minio", str(path)], check=True)
            path.chmod(0o755)
        finally:
            subprocess.run(["docker", "rm", container], check=True, stdout=subprocess.DEVNULL)
    return path


def children(pid):
    result = set()
    for path in Path(f"/proc/{pid}/task").glob("*/children"):
        try:
            result.update(map(int, path.read_text().split()))
        except FileNotFoundError:
            pass
    return result


def command(pid):
    try:
        return Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode()
    except FileNotFoundError:
        return ""


def joined(pids):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        remaining = []
        for pid in pids:
            try:
                os.waitpid(pid, os.WNOHANG)  # Test subreaper joins children after manager SIGKILL.
            except ChildProcessError:
                pass
            if Path(f"/proc/{pid}").exists():
                remaining.append(pid)
        if not remaining:
            return
        time.sleep(0.05)
    raise AssertionError(f"Unjoined children: {remaining}")


class Fixture:
    def __init__(self, cli, node, host):
        self.root = Path(tempfile.mkdtemp(prefix="transit-server-proof-", dir="/var/tmp"))
        self.cli = str(Path(cli).resolve())
        ports = []
        while len(ports) < 5:
            port = free_port()
            if port not in ports:
                ports.append(port)
        self.config = {"version": 1, "installation": str(self.root / "installation"), "realm": 73,
            "ports": dict(zip(("cold", "cold_console", "store", "node", "gateway"), ports)),
            "executables": {"minio": str(minio_binary()), "ursula": shutil.which("ursula"),
                "node": str(Path(node).resolve()), "query_host": str(Path(host).resolve())}}
        self.path = self.root / "server.json"
        self.path.write_text(json.dumps(self.config))
        self.process = None
        self.logs = []
        self.http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        self.url = f"http://127.0.0.1:{ports[-1]}"

    @property
    def installation(self):
        return self.root / "installation"

    def record(self):
        return json.loads((self.installation / "installation.json").read_text())

    def start(self, initialize=False):
        assert self.process is None
        log = (self.root / f"manager-{len(self.logs)}.stderr").open("wb")
        self.logs.append(log)
        args = [self.cli, "server", "--config", str(self.path)]
        if initialize:
            args.append("--initialize")
        self.process = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=log,
            cwd=self.root, env={"PATH": "/unavailable", "LANG": "C"})

    def ready(self, timeout=180):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise AssertionError(f"Manager exit {self.process.returncode}: {Path(self.logs[-1].name).read_text()}")
            if select.select([self.process.stdout], [], [], 0.1)[0]:
                line = self.process.stdout.readline()
                if not line:
                    raise AssertionError(Path(self.logs[-1].name).read_text())
                report = json.loads(line)
                assert report["ready"] and report["profile"] == "local_table_v1", report
                with self.http.open(self.url + "/health", timeout=5) as response:
                    assert response.status == 200
                return report
        raise TimeoutError(f"Server readiness at {self.root}")

    def stop(self, kill=False):
        if self.process is None:
            return
        owned = children(self.process.pid)
        if self.process.poll() is None:
            self.process.kill() if kill else self.process.terminate()
        self.process.wait(timeout=20)
        joined(owned)
        self.process.stdout.close()
        self.process = None

    def refusal(self, message, initialize=False):
        args = [self.cli, "server", "--config", str(self.path)]
        if initialize:
            args.append("--initialize")
        result = subprocess.run(args, capture_output=True, text=True, timeout=30, env={"PATH": "/unavailable"})
        assert result.returncode != 0 and message in result.stderr, result
        assert not result.stdout, result

    def console(self, text):
        result = subprocess.run([self.cli, "console", "--config", str(self.installation / "console.json"), "--format", "json"],
            input=text, text=True, capture_output=True, timeout=80, env={"PATH": "/unavailable"})
        assert result.returncode == 0, result
        return [json.loads(line) for line in result.stdout.splitlines()]

    def kill_role(self, match):
        candidates = [pid for pid in children(self.process.pid) if match in command(pid) and (match != "/transit-node " or "--maintain" not in command(pid))]
        assert len(candidates) == 1, [(pid, command(pid)) for pid in children(self.process.pid)]
        os.kill(candidates[0], signal.SIGKILL)

    def cleanup(self):
        self.stop()
        for log in self.logs:
            log.close()


def run(cli, node, host):
    # Own/reap grandchildren when deliberately killing the manager. Runtime
    # supervision uses PDEATHSIG and does not depend on this fixture facility.
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    fixture = Fixture(cli, node, host)
    start = time.monotonic()
    success = False
    print(f"Transit server proof: {fixture.root}", flush=True)
    try:
        fixture.refusal("FileNotFound")
        fixture.start(initialize=True)
        fixture.ready()
        original = fixture.record()
        fixture.refusal("InstallationInUse")
        from console import Console
        shell = Console(fixture.cli, fixture.installation / "console.json")
        try:
            assert shell.call('/schema')['description']['source']['capabilities']['table']
            assert shell.call('/new 1')['status'] is None
            assert 'receipt' in shell.call('SELECT COUNT(*) FROM items;')
            progress = shell.read()
            deadline = time.monotonic() + 90
            while 'waiting_for_input' in progress:
                assert time.monotonic() < deadline, progress
                progress = shell.call('/advance')
            while shell.call('/status')['status']['phase'] != 'complete':
                assert time.monotonic() < deadline
                time.sleep(.1)
            page = shell.call('/next')
            assert page['complete_coverage'] and page['manifest']['rows'] == '1', page
            assert page['cells'][0][0]['value']['uint64'] == '0', page
            shell.close()
        finally:
            if shell.process.poll() is None:
                shell.process.kill(); shell.process.wait(timeout=10)
        print("Transit server independent console: verified empty Table COUNT result", flush=True)
        fixture.stop()
        fixture.refusal("InstallationExists", initialize=True)
        fixture.start()
        fixture.ready()
        assert fixture.record()["provision"] == original["provision"]
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        assert fixture.record()["provision"] == original["provision"]
        for role in ("table_source", "/transit-node ", "ursula server"):
            fixture.kill_role(role)
            fixture.ready()
            assert fixture.record()["provision"] == original["provision"]
            fixture.console("/schema\n/quit\n")
        fixture.kill_role("/courier.json")
        assert fixture.process.wait(timeout=30) == 1
        assert "RestartBudgetExhausted" in Path(fixture.logs[-1].name).read_text()
        fixture.stop()
        for name in ("wal", "cold"):
            old = fixture.installation / name
            backup = fixture.installation / (name + "-absent")
            old.rename(backup)
            try:
                fixture.refusal("FileNotFound")
            finally:
                backup.rename(old)
        with socket.socket() as listener:
            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            listener.bind(("127.0.0.1", fixture.config["ports"]["gateway"]))
            listener.listen()
            fixture.refusal("AddressInUse")
        fixture.start()
        fixture.ready()
        fixture.console("/schema\n/quit\n")
        fixture.stop()
        success = True
        print(f"Transit server core lifecycle: passed in {time.monotonic() - start:.2f}s", flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f"Failed server evidence retained at {fixture.root}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    run(*sys.argv[1:])

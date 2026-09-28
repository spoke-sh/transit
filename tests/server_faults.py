"""Adversarial local server startup and native gateway proofs; all state is owned."""
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import time
import urllib.error
import urllib.request

from server import Fixture, children, command


def response(fixture, path, body=None, headers=None, direct=False):
    url = f"http://127.0.0.1:{fixture.config['ports']['node']}" if direct else fixture.url
    request = urllib.request.Request(url + path, data=body, headers=headers or {})
    try:
        result = fixture.http.open(request, timeout=6)
    except urllib.error.HTTPError as error:
        result = error
    with result:
        return result.status, result.read()


def gateway(fixture):
    # A wrong private key reaches native authentication. The gateway must not
    # replace it with its manager's root or the generated console's caller key.
    config = json.loads((fixture.installation / "console.json").read_text())
    (fixture.root / "wrong.seed").write_text(os.urandom(32).hex())
    invalid = dict(config, seed_file=str(fixture.root / "wrong.seed"), recovery_file=None)
    (fixture.root / "wrong.json").write_text(json.dumps(invalid))
    denied = subprocess.run([fixture.cli, "console", "--config", str(fixture.root / "wrong.json"), "--format", "json"],
        input="/schema\n", capture_output=True, text=True, timeout=10)
    assert denied.returncode == 1 and json.loads(denied.stdout)["err"] == "AccessDenied", denied
    assert response(fixture, "/v3/query", b"{}")[0] == 400
    assert response(fixture, "/v3/query", b"{}") == response(fixture, "/v3/query", b"{}", direct=True)
    for header in ("origin", "authorization", "forwarded", "x-forwarded-for", "x-real-ip"):
        assert response(fixture, "/health", headers={header: "private-must-not-appear"})[0] == 403
    assert response(fixture, "/missing")[0] == 404
    assert response(fixture, "/v3/query", b"x" * (262144 + 1))[0] == 413

    held = []
    try:
        for _ in range(4):
            peer = socket.create_connection(("127.0.0.1", fixture.config["ports"]["gateway"]), timeout=2)
            held.append(peer)
            peer.sendall((f"POST /v3/query HTTP/1.1\r\nHost: 127.0.0.1:{fixture.config['ports']['gateway']}\r\nContent-Length: 100\r\n\r\n{{").encode())
        time.sleep(.1)
        start = time.monotonic()
        assert response(fixture, "/health")[0] == 200
        elapsed = time.monotonic() - start
        assert elapsed < 2, elapsed
        assert response(fixture, "/v3/query", b"{}")[0] == 503
        # Whole-request deadlines close all slow bodies without retaining tasks.
        for peer in held:
            peer.settimeout(6)
            data = b""
            while block := peer.recv(4096):
                data += block
                assert len(data) <= 8192
            # A cancelled body reader may produce a bounded error response
            # before the joined deadline closes its connection.
            assert not data or data.startswith(b"HTTP/1.1 413"), data
    finally:
        for peer in held:
            peer.close()
    assert response(fixture, "/health")[0] == 200
    gateway_pid = next(pid for pid in children(fixture.process.pid) if "__transit_gateway_v1" in command(pid))
    status = Path(f"/proc/{gateway_pid}/status").read_text()
    rss = int(next(line.split()[1] for line in status.splitlines() if line.startswith("VmRSS:"))) * 1024
    assert rss < 64 * 1024**2, rss
    print(f"Transit gateway: native denial/status, private headers, body limit and stalled-data control passed; health {elapsed * 1000:.2f} ms, sampled RSS {rss} bytes", flush=True)


def partial_bootstrap(cli, node, host):
    fixture = Fixture(cli, node, host)
    success = False
    try:
        fixture.start(initialize=True)
        deadline = time.monotonic() + 60
        frozen = None
        while time.monotonic() < deadline:
            assert fixture.process.poll() is None
            try:
                before = fixture.record()
            except FileNotFoundError:
                time.sleep(.002)
                continue
            if before["pending"] and before["pending"]["effect"] == "provision":
                frozen = before["pending"]
                break
            time.sleep(.002)
        assert frozen, "Did not observe a persisted initial provisioning operation"
        fixture.stop(kill=True)
        fixture.start()
        fixture.ready()
        after = fixture.record()
        assert after["installation"] == before["installation"] and after["root_public"] == before["root_public"]
        for expected, actual in zip(before["provision"], after["provision"]):
            if expected is not None:
                assert expected == actual
        status, body = response(fixture, "/v3/command", json.dumps(frozen["signed"], separators=(",", ":")).encode())
        assert status == 200 and json.loads(body)["position"] == after["provision"][frozen["index"]], (status, body)
        fixture.console("/schema\n/quit\n")
        gateway(fixture)
        success = True
        print("Transit bootstrap: killed persisted intent recovers the same installation, accepted identities and exact receipt", flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f"Failed bootstrap evidence retained at {fixture.root}", flush=True)


def rollback(cli, node, host):
    fixture = Fixture(cli, node, host)
    success = False
    try:
        # Mutate only an owned executable copy when checking artifact identity.
        owned_node = fixture.root / "transit-node"
        shutil.copy2(fixture.config["executables"]["node"], owned_node)
        fixture.config["executables"]["node"] = str(owned_node)
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start(initialize=True)
        fixture.ready()
        fixture.stop()
        old = fixture.record()
        for name in ("wal", "cold"):
            shutil.copytree(fixture.installation / name, fixture.root / (name + "-snapshot"))
        fixture.start()
        fixture.ready()
        fixture.console("/schema\n/quit\n")
        fixture.stop()
        assert fixture.record()["position"] > old["position"]
        original_size = owned_node.stat().st_size
        with owned_node.open("ab") as file:
            file.write(b"changed-artifact")
        fixture.refusal("InstallationIdentityMismatch")
        with owned_node.open("r+b") as file:
            file.truncate(original_size)
        # This is a negative rollback test, not a supported backup/restore flow.
        for name in ("wal", "cold"):
            shutil.rmtree(fixture.installation / name)
            shutil.copytree(fixture.root / (name + "-snapshot"), fixture.installation / name)
        fixture.refusal("AuthorityRollback")
        assert fixture.record()["provision"] == old["provision"]
        success = True
        print("Transit recovery: changed executable and provider history below the recorded observation are refused", flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f"Failed rollback evidence retained at {fixture.root}", flush=True)


def run(cli, node, host):
    started = time.monotonic()
    partial_bootstrap(cli, node, host)
    rollback(cli, node, host)
    print(f"Transit server bootstrap/gateway/rollback faults: passed in {time.monotonic() - started:.2f}s", flush=True)


if __name__ == "__main__":
    import ctypes
    import sys
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    run(*sys.argv[1:])

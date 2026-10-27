"""Adversarial local server startup and native gateway proofs; all state is owned."""
from runner.paths import ROOT
import json
import http.client
import os
from pathlib import Path
import shutil
import socket
import socketserver
import subprocess
import threading
import time
import urllib.error
import urllib.request

from harness.processes import children, command
from interfaces.installation.server import Fixture


def response(fixture, path, body=None, headers=None, direct=False):
    url = f"http://127.0.0.1:{fixture.config['ports']['node']}" if direct else fixture.url
    request = urllib.request.Request(url + path, data=body, headers=headers or {})
    try:
        result = fixture.http.open(request, timeout=6)
    except urllib.error.HTTPError as error:
        result = error
    with result:
        return result.status, result.read()


def gateway_hosts(fixture):
    port = fixture.config["ports"]["gateway"]
    with fixture.http.open(f"http://localhost:{port}/health", timeout=5) as reply:
        assert reply.status == 200
    for host in [f"127.0.0.1:{port}", f"localhost:{port}", f"LOCALHOST:{port}", *fixture.config.get("gateway_allowed_hosts", [])]:
        assert response(fixture, "/health", headers={"Host": host})[0] == 200, host
        assert response(fixture, "/health", headers={"Host": host.upper()})[0] == 200, host
    for host in (f"localhost.attacker.test:{port}", f"127.0.0.1.attacker.test:{port}",
                 f"unknown.test:{port}", f"localhost.:{port}", "localhost", "localhost:1"):
        status, body = response(fixture, "/health", headers={"Host": host})
        assert status == 403 and json.loads(body) == {"err": "InvalidHost"}, (host, status, body)
    # A permitted alias must not relax browser or forwarded-identity checks.
    for header in ("Origin", "Authorization", "Forwarded", "X-Forwarded-Host", "X-Forwarded-For", "X-Real-IP"):
        assert response(fixture, "/health", headers={"Host": f"localhost:{port}", header: "untrusted"})[0] == 403
    for headers in ("", "Host: \r\n", f"Host: localhost:{port}\r\nHost: localhost:{port}\r\n",
                    f"Host: localhost:{port}\r\nhOsT: attacker.test:{port}\r\n",
                    f"Host: user@localhost:{port}\r\n", f"Host: localhost:{port},attacker.test:{port}\r\n"):
        with socket.create_connection(("127.0.0.1", port), timeout=3) as peer:
            peer.sendall(("GET /health HTTP/1.1\r\n" + headers + "\r\n").encode())
            data = b""
            try:
                while block := peer.recv(4096):
                    data += block
                    assert len(data) <= 8192
            except ConnectionResetError:
                pass
            assert not data or data.startswith((b"HTTP/1.1 400", b"HTTP/1.1 403")), data
    print("Transit gateway hosts: default/configured aliases, exact ports, unknown/malformed/duplicate hosts and identity-header refusal passed", flush=True)


def reusable_connections(fixture):
    for role in ('gateway', 'node'):
        # Exercise the actual node listener's reuse/admission contracts when
        # this fixture has a separate proxy for selective direct-write faults.
        port = fixture.boundary.upstream if role == 'node' and hasattr(fixture, 'boundary') else fixture.config['ports'][role]
        connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
        try:
            peer = None
            # Cross the listener's exact request cap, verifying advertised close
            # and fresh reconnection rather than reusing a retired socket.
            for index in range(66):
                connection.request('GET', '/health')
                if peer is None:
                    peer = connection.sock
                if index == 64:
                    assert connection.sock is not peer, role
                    peer = connection.sock
                else:
                    assert connection.sock is peer, role
                reply = connection.getresponse()
                assert reply.status == 200 and json.loads(reply.read())['ready']
                assert (reply.getheader('Connection') == 'close') == (index == 63)
            # Reading an incomplete body must not hold the authority lock or
            # monopolize accept. Health uses the separate admission reserve.
            slow = socket.create_connection(('127.0.0.1', port), timeout=3)
            try:
                slow.sendall(f'POST /v1/query HTTP/1.1\r\nHost: localhost:{port}\r\nContent-Length: 100\r\n\r\nx'.encode())
                connection.request('GET', '/health')
                reply = connection.getresponse()
                assert reply.status == 200 and json.loads(reply.read())['ready']
            finally:
                slow.close()
        finally:
            connection.close()
    # Priority hints cannot turn an ordinary operation into a release or grant.
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    query = {'query': {'version': 1, 'definition': definition, 'realm': fixture.config['realm'], 'principal': 0,
                      'kind': {'capabilities': {}}}, 'signature': [0] * 64}
    for direct in (False, True):
        assert response(fixture, '/v1/query', json.dumps(query).encode(), direct=direct)[0] == 403
        assert response(fixture, '/v1/query', json.dumps(query).encode(),
                        {'X-Transit-Control': 'snapshot'}, direct)[0] == 400
    from interfaces.installation.server_application_faults import ExistingKey, native
    root_key = ExistingKey(fixture.root, fixture.installation / 'root.seed')
    watched = native(root_key, fixture.config['realm'], 0, {'process': fixture.record()['provision'][4]})
    encoded = json.dumps(watched).encode()
    status, body = response(fixture, '/v1/query', encoded)
    assert status == 200
    position = json.loads(body)['position']
    started = time.monotonic()
    status, body = response(fixture, '/v1/query', encoded, {'X-Transit-Wait': f'{position}:150'})
    assert status == 200 and json.loads(body)['position'] >= position, (status, body)
    if json.loads(body)['position'] == position:
        assert time.monotonic() - started >= .12, 'gateway discarded notification hint'
    for invalid in ('1:0', '01:1', '1:1001'):
        assert response(fixture, '/v1/query', encoded, {'X-Transit-Wait': invalid})[0] == 400
    assert response(fixture, '/v1/query', encoded,
                    {'X-Transit-Wait': f'{position}:10', 'X-Transit-Control': 'snapshot'})[0] == 400
    closing_gateway_response(fixture)
    from interfaces.installation.server_write_observation import run as write_observation
    write_observation(fixture)
    print('Transit transport: socket reuse, partial-body isolation and checked control hints passed', flush=True)


def closing_gateway_response(fixture):
    """A consumed body and failed upstream still end advertised socket reuse."""
    attempts = []

    class Dropped(socketserver.BaseRequestHandler):
        def handle(self):
            self.request.settimeout(3)
            data = b''
            while b'\r\n\r\n' not in data:
                part = self.request.recv(4096)
                assert part, 'upstream request ended before headers'
                data += part
                assert len(data) < 8192
            head, body = data.split(b'\r\n\r\n', 1)
            while len(body) < 2:
                part = self.request.recv(2 - len(body))
                assert part, 'upstream request ended before body'
                body += part
            assert body == b'{}', body
            attempts.append(1)
            # No response: the gateway must report uncertainty and close once.

    with socketserver.ThreadingTCPServer(('127.0.0.1', 0), Dropped) as upstream:
        thread = threading.Thread(target=upstream.serve_forever, daemon=True)
        thread.start()
        from harness.services import free_port
        port = free_port()
        config = fixture.root / 'closing-gateway.json'
        config.write_text(json.dumps({'port': port, 'upstream': f'http://127.0.0.1:{upstream.server_address[1]}'}))
        with (fixture.root / 'closing-gateway.stderr').open('wb') as log:
            process = subprocess.Popen([fixture.cli, '__transit_gateway_v1', str(config)],
                                       stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=log)
            try:
                deadline = time.monotonic() + 10
                while True:
                    assert process.poll() is None
                    try:
                        peer = socket.create_connection(('127.0.0.1', port), timeout=3)
                        break
                    except ConnectionRefusedError:
                        assert time.monotonic() < deadline
                        time.sleep(.02)
                with peer:
                    request = f'POST /v1/query HTTP/1.1\r\nHost: localhost:{port}\r\nContent-Length: 2\r\n\r\n{{}}'.encode()
                    # Already-buffered successors must not dispatch after close.
                    peer.sendall(request + request)
                    result = bytearray()
                    while data := peer.recv(8192):
                        result.extend(data)
                        assert len(result) < 16384
                assert result.count(b'HTTP/1.1 503') == 1, result
                assert b'connection: close\r\n' in result.lower(), result
                assert len(attempts) == 1, attempts
            finally:
                process.terminate()
                process.wait(timeout=10)
                upstream.shutdown()
                thread.join(timeout=5)


def configured_hosts(cli, node, host):
    fixture = Fixture(cli, node, host)
    success = False
    try:
        # Invalid policy fails before initialization creates any runtime state.
        for invalid, error in ((["*:19905"], "exact host:port authorities"), (["localhost:19905"] * 9, "at most eight")):
            fixture.path.write_text(json.dumps(dict(fixture.config, gateway_allowed_hosts=invalid)))
            fixture.refusal(error)
            assert not fixture.installation.exists()
        port = fixture.config["ports"]["gateway"]
        tunnel_port = 29905 if port != 29905 else 29906
        fixture.config["gateway_allowed_hosts"] = [f"bank.local.test:{port}", f"localhost:{tunnel_port}"]
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready()
        gateway_hosts(fixture)
        # Only the explicitly selected host/port pair is added by tunnel config.
        assert response(fixture, "/health", headers={"Host": f"127.0.0.1:{tunnel_port}"})[0] == 403
        assert response(fixture, "/health", headers={"Host": f"bank.local.test:{tunnel_port}"})[0] == 403
        fixture.stop()
        before = fixture.record()
        original = fixture.config
        changed = dict(fixture.config, gateway_allowed_hosts=[f"other.test:{port}"])
        fixture.config = changed
        fixture.path.write_text(json.dumps(changed))
        fixture.start()
        fixture.ready()
        assert fixture.record()["installation"] == before["installation"]
        assert fixture.record()["authorization_steps"] == before["authorization_steps"]
        assert response(fixture, "/health", headers={"Host": f"other.test:{port}"})[0] == 200
        assert response(fixture, "/health", headers={"Host": f"bank.local.test:{port}"})[0] == 403
        fixture.stop()
        fixture.config = original
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready()
        assert fixture.record()["installation"] == before["installation"]
        gateway_hosts(fixture)
        fixture.console(".schema\n.quit\n")
        success = True
        print("Transit gateway configured hosts: validation before effects, explicit tunnel authority, mutable policy restart and retained installation/grants passed", flush=True)
    finally:
        fixture.cleanup()
        if success:
            shutil.rmtree(fixture.root)
        else:
            print(f"Failed configured-host evidence retained at {fixture.root}", flush=True)


def gateway(fixture):
    # The signed-native gateway must preserve the caller's signature. Native
    # SQL consoles no longer carry a signing key, so exercise this boundary
    # directly with an independently signed request claiming the root identity.
    from interfaces.installation.server_application_faults import ExistingKey, native
    wrong_seed = fixture.root / "wrong.seed"
    wrong_seed.write_text(os.urandom(32).hex())
    wrong_key = ExistingKey(fixture.root, wrong_seed)
    encoded = json.dumps(native(wrong_key, fixture.config['realm'], 0, {'capabilities': {}})).encode()
    forwarded = response(fixture, '/v1/query', encoded)
    assert forwarded[0] == 403 and forwarded == response(fixture, '/v1/query', encoded, direct=True), forwarded
    assert response(fixture, "/v1/query", b"{}")[0] == 400
    assert response(fixture, "/v1/query", b"{}") == response(fixture, "/v1/query", b"{}", direct=True)
    for header in ("origin", "authorization", "forwarded", "x-forwarded-for", "x-real-ip"):
        assert response(fixture, "/health", headers={header: "private-must-not-appear"})[0] == 403
    assert response(fixture, "/missing")[0] == 404
    assert response(fixture, "/v1/query", b"x" * (262144 + 1))[0] == 413

    held = []
    try:
        for _ in range(4):
            peer = socket.create_connection(("127.0.0.1", fixture.config["ports"]["gateway"]), timeout=2)
            held.append(peer)
            peer.sendall((f"POST /v1/query HTTP/1.1\r\nHost: 127.0.0.1:{fixture.config['ports']['gateway']}\r\nContent-Length: 100\r\n\r\n{{").encode())
        time.sleep(.1)
        start = time.monotonic()
        assert response(fixture, "/health")[0] == 200
        elapsed = time.monotonic() - start
        assert elapsed < 2, elapsed
        assert response(fixture, "/v1/query", b"{}")[0] == 503
        # The reserve admits cleanup-shaped requests even with data slots full;
        # parsing and signed authority checks remain mandatory after admission.
        assert response(fixture, "/v1/query", b"{}", headers={"X-Transit-Control": "snapshot"})[0] == 400
        release = {'query': {'version': 1, 'definition': fixture.record()['definition'], 'realm': fixture.config['realm'], 'principal': 0,
                            'kind': {'close_snapshot': {'epoch': [7] * 16, 'serial': 1}}},
                   'signature': [0] * 64}
        assert response(fixture, "/v1/query", json.dumps(release).encode(),
                        headers={"X-Transit-Control": "snapshot"})[0] == 403
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
        fixture.start()
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
        # Existing-only accepts a recorded partial bootstrap and preserves its
        # exact pending operation, rather than requiring completed readiness.
        fixture.config['startup'] = {'require_existing': True}
        fixture.path.write_text(json.dumps(fixture.config))
        fixture.start()
        fixture.ready()
        assert 'resuming installation' in Path(fixture.logs[-1].name).read_text()
        after = fixture.record()
        assert after["installation"] == before["installation"] and after["root_public"] == before["root_public"]
        for expected, actual in zip(before["provision"], after["provision"]):
            if expected is not None:
                assert expected == actual
        status, body = response(fixture, "/v1/command", json.dumps(frozen["signed"], separators=(",", ":")).encode())
        assert status == 200 and json.loads(body)["position"] == after["provision"][frozen["index"]], (status, body)
        fixture.console(".schema\n.quit\n")
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
        fixture.start()
        fixture.ready()
        fixture.stop()
        old = fixture.record()
        native = fixture.installation / 'data/native'
        snapshot = fixture.root / 'native-snapshot'
        shutil.copytree(native, snapshot)
        fixture.start()
        fixture.ready()
        fixture.console(".schema\n.quit\n")
        fixture.stop()
        assert fixture.record()["position"] > old["position"]
        original_size = owned_node.stat().st_size
        with owned_node.open("ab") as file:
            file.write(b"changed-artifact")
        fixture.refusal("configuration or executable differs from the recorded installation")
        with owned_node.open("r+b") as file:
            file.truncate(original_size)
        # This is a negative rollback test, not a supported backup/restore flow.
        shutil.rmtree(native)
        shutil.copytree(snapshot, native)
        fixture.refusal("retained authority is older than the recorded recovery position")
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
    from interfaces.installation.server_startup import empty_installation
    empty_installation(cli, node, host)
    configured_hosts(cli, node, host)
    partial_bootstrap(cli, node, host)
    rollback(cli, node, host)
    print(f"Transit server bootstrap/gateway/rollback faults: passed in {time.monotonic() - started:.2f}s", flush=True)


if __name__ == "__main__":
    import ctypes
    import sys
    assert ctypes.CDLL(None).prctl(36, 1, 0, 0, 0) == 0
    run(*sys.argv[1:])

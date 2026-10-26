"""Board's real API, embedded distribution, private access and recovery qualification."""
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
import json
import os
from pathlib import Path
import re
import shutil
import socket
import subprocess
import struct
import sys
import time
from inspection import System
from harness.services import free_port, wait_ready


def run(node, cli, board, browser=False):
    with System(node, cli, clock_error_ms=10000, allow_history_trim=True) as s:
        pids = [s.command({"spawn": {"code": 101}}),
                s.command({"spawn": {}}), s.command({"spawn": {}})]
        s.command({"send": {"pid": pids[2], "value": b"<script>window.pwned=true</script>".hex()}})
        s.command({"own": {"pid": pids[0], "expected_generation": 0, "worker": 0}})
        admission = s.command({"send": {"pid": pids[0], "value": b"7".hex()}})
        turn = s.command({"turn": {"pid": pids[0], "generation": 1, "input": admission,
                                  "expected_revision": 0, "effect": b"synthetic".hex(),
                                  "outputs": [{"pid": pids[1], "value": b"7".hex()}, None, None, None]}})
        output = next(item for item in s.native_query({"outputs": {}})["body"]["outputs"]["entries"] if item)
        delivered = s.command({"deliver": output["id"]})
        dispatch_policy = s.native_query({"authorization": {
            "role": None, "kind": {"identity": {}}
        }})["body"]["authorization"]["revision"]
        assert dispatch_policy > 0
        attempt = s.command({"dispatch": {"pid": pids[0], "effect": turn}})
        s.command({"observe": {"pid": pids[0], "effect": turn, "attempt": attempt, "result": None}})
        closure_input = s.command({"close_effect": {"pid": pids[0], "effect": turn, "attempt": attempt}})
        blocked = s.command({"send": {"pid": pids[0], "value": b"bad".hex()}})
        s.command({"turn": {"pid": pids[0], "generation": 1, "input": blocked, "expected_revision": turn,
                            "failed": True}})
        seed, public = s.key("board")
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16}})
        resource = s.command({"create_resource": {"writer": pids[1], "history_ms": 0}})
        hidden = s.command({"create_resource": {"writer": pids[2], "history_ms": 0}})
        for identifier in (resource, hidden):
            s.command({"grant_resource": {"resource": identifier, "subject": 0, "permissions": 7}})
            s.command({"associate": {"pid": pids[1], "name": str(identifier).encode().hex(), "resource": identifier}})
        s.command({"grant_resource": {"resource": resource, "subject": 1, "permissions": 1}})
        port = free_port()
        origin = f"http://127.0.0.1:{port}"
        config = s.root / "board.json"
        options = {"upstream": s.url, "realm": 72, "principal": 1, "seed_file": str(seed),
                   "public_origin": origin, "port": port, "profile": "native_v1"}
        config.write_text(json.dumps(options))
        isolated = s.root / "standalone"
        isolated.mkdir()
        binary = isolated / "transit-board"
        shutil.copyfile(board, binary)
        binary.chmod(0o755)
        running = s.start(binary, config, cwd=isolated, env={"PATH": "/no-executables", "LOG_FORMAT": "json"})
        board_log = Path(s.logs[-1].name)
        wait_ready(s.store.http, running, origin + "/health")

        def request(path, method="GET", headers=None, status=200, retry=True):
            extra = headers or {}
            for _ in range(20):
                conn = HTTPConnection("127.0.0.1", port, timeout=5)
                try:
                    conn.request(method, path, headers=extra)
                    response = conn.getresponse()
                    body = response.read()
                    values = dict(response.getheaders())
                    actual = response.status
                finally:
                    conn.close()
                if retry and actual == 429:
                    time.sleep(.12)
                    continue
                assert actual == status, (path, actual, body[:500], status)
                assert values["cache-control"] == "no-store"
                assert "set-cookie" not in values and "access-control-allow-origin" not in values
                return body, values
            raise AssertionError("Rate limit did not clear")

        def api(path, **kwargs):
            body, _ = request("/api/v1/" + path, **kwargs)
            return json.loads(body)

        def failure(path, status, code, action, **kwargs):
            result = api(path, status=status, **kwargs)
            detail = result["diagnostic"]
            assert detail["code"] == code, result
            assert detail["stage"] == "read" and detail["outcome"] == "not_applicable", detail
            assert detail["evidence"] == "none" and detail["identity"] is None, detail
            assert [item["kind"] for item in detail["actions"] if item] == [action], detail
            assert any(item and item["field"] == "completion" and item["value"] == {"boolean": False} for item in detail["facts"]), detail
            return result

        # The only running file in this cwd is the binary. Static dependencies
        # are loaded from it, including lazy chunks and the versioned OpenAPI.
        html, headers = request("/processes/1/journey")
        assert "text/html" in headers["content-type"]
        assert b"<script" in html and b"cdn" not in html
        assert "unsafe-eval" not in headers["content-security-policy"]
        openapi = json.loads(request("/openapi/v1.json")[0])
        assert openapi == json.loads((Path(__file__).resolve().parents[1] / "contracts/transit-board-v1.openapi.json").read_text())
        assets = re.findall(rb'(?:src|href)="(/assets/[^"]+)"', html)
        assert assets
        for asset in assets:
            content, _ = request(asset.decode())
            assert seed.read_bytes().strip() not in content
        for path in ("/assets/missing.js", "/api/missing"):
            body, _ = request(path, status=400 if path == "/api/missing" else 404)
            assert b"<!doctype" not in body
        # Declarative custom paths receive the static shell; current interface reads resolve them.
        assert b"<!doctype" in request("/unknown")[0]
        request("/api/v1/capabilities")
        request("/api/v1/capabilities", headers={"Host": "evil.example"}, status=403)
        request("/health", headers={"Host": f"localhost:{port}"}, status=403)
        request("/api/v1/capabilities", headers={"Origin": "https://evil.example"}, status=403)
        request("/api/v1/capabilities", headers={"X-Forwarded-Host": "evil.example"}, status=403)
        api("processes?url=http://metadata", status=400)
        request("/api/v1/processes", method="POST", status=404)
        request("/v1/command", method="POST", status=404)
        caps = api("capabilities")
        assert caps["read_only"] and caps["realm"] == 72 and caps["station"] is True
        snapshot = api("processes")
        assert [p["pid"] for p in snapshot["observation"]["processes"] if p] == pids
        detail = api(f"processes/{pids[0]}")
        assert "lens" not in detail
        assert [r["id"] for r in api("resources")["observation"]["resources"] if r] == [resource]
        assert [a["resource"] for a in api(f"processes/{pids[1]}/associations")["observation"]["associations"] if a] == [resource]
        failure(f"resources/{hidden}", 403, "inspection.denied", "inspect_scope")
        failure(f"resources/{resource}/entries", 403, "inspection.denied", "inspect_scope")
        s.command({"grant_resource": {"resource": resource, "subject": 1, "permissions": 3}})
        assert not any(api(f"resources/{resource}/entries")["observation"]["entries"])
        writer_generation = s.inspect("process", pids[1])["processes"][0]["generation"]
        s.command({"own": {"pid": pids[1], "worker": 0, "expected_generation": writer_generation}})
        writer_generation += 1
        resource_revision = api(f"resources/{resource}")["observation"]["resources"][0]["revision"]
        opened = s.command({"open_view": {"pid": pids[1], "generation": writer_generation, "input": delivered,
            "expected_revision": 0, "resource": resource, "revision": resource_revision, "deadline_ms": int(time.time()*1000)+30000}})
        # A valid typed head is metadata evidence. This fixture does not claim
        # to materialize its schema publication or application rows.
        from unified_contract import current_definition
        head_key = b'\0P' + struct.pack('>IQ', 8, 1) + b'h' + bytes(12)
        head = (b'STH1' + current_definition() + struct.pack('<QQQ', resource, 1, 1)
                + struct.pack('<QII', 1, 0x54534301, 500) + bytes([9]) * 32
                + b'\0' + struct.pack('<QQQ', 0, 2, 0) + b'\0')
        s.command({"turn": {"pid": pids[1], "generation": writer_generation, "input": delivered,
            "expected_revision": 0, "views": [opened, None, None, None], "write_view": opened,
            "mutations": [{"key": b"\x00station".hex(), "value": b"station.genserver.v1".hex()},
                          {"key": head_key.hex(), "value": head.hex()},
                          {"key": b"application".hex(), "value": b"station.genserver.v1".hex()}, None]}})
        framework = api(f"resources/{resource}/entries")
        lenses = [item for item in framework["framework"] if item]
        assert len(lenses) == 2 and {next(iter(item["declaration"])) for item in lenses} == {"behavior", "table"}
        table = next(item['declaration']['table'] for item in lenses if 'table' in item['declaration'])
        assert bytes.fromhex(table['object']) == b'1' and bytes.fromhex(table['rows']) == b'0'
        assert table['schema']['bytes'] == 500 and table['schema']['digest'] == [9] * 32
        assert table['pending'] is None and not table['retired']
        assert all(item["source"]["pid"] == pids[1] and item["source"]["resource"] == resource for item in lenses)
        s.command({"grant_resource": {"resource": resource, "subject": 1, "permissions": 1}})
        failure(f"resources/{resource}/entries", 403, "inspection.denied", "inspect_scope")  # lenses cannot bypass read revocation
        s.command({"grant_resource": {"resource": resource, "subject": 1, "permissions": 3}})
        process = detail["observation"]["processes"][0]
        assert process["failure"] == blocked and process["admitted"] - process["consumed"] == 1
        subprocess.run(["vp", "exec", "node", "tests/board_client.mjs"], input=json.dumps(detail), text=True, check=True, timeout=30)
        outbox = api(f"processes/{pids[0]}/outbox")
        assert outbox["edges"][1]["to"] == {"realm": 72, "pid": pids[1], "kind": "input", "id": delivered}
        effect_page = api(f"processes/{pids[0]}/effects")
        effect = effect_page["observation"]["effects"][0]
        effect_diagnostic = effect_page["effect_diagnostics"][0]
        assert effect["phase"] == "closed_unknown" and effect["closure"]["reason"] == "abandoned", effect
        assert effect["closed_at"] == closure_input and effect["authorization_policy"] == dispatch_policy, effect
        assert effect["last_observation"]["policy_revision"] == dispatch_policy, effect
        assert effect["closure"]["policy_revision"] == dispatch_policy, effect
        current_policy = s.native_query({"authorization": {
            "role": None, "kind": {"identity": {}}
        }})["body"]["authorization"]["revision"]
        assert current_policy > dispatch_policy, "Later grants must not rewrite original effect authority"
        assert effect_diagnostic["code"] == "effect.reconciliation_abandoned" and effect_diagnostic["outcome"] == "closed_unknown"
        assert effect_diagnostic["identity"] == {"domain":"effect","id":str(turn),"realm":"72","resource":None,"sequence":None}
        assert [item["kind"] for item in effect_diagnostic["actions"] if item] == ["inspect_status"]
        journey = api(f"processes/{pids[0]}/journey")
        assert any(edge and edge["from"]["id"] == admission and edge["to"]["id"] == turn for edge in journey["edges"])
        # Browser runtime tests open the real binary directly, without credentials.
        if browser:
            env = os.environ | {"BOARD_TEST_URL": origin,
                                "BOARD_TEST_OUTPUT": str(output["id"]),
                                "BOARD_TEST_TABLE_KEY": head_key.hex(),
                                "BOARD_TEST_RESOURCE": str(resource), "BOARD_TEST_PID": str(pids[0]), "BOARD_TEST_SINK": str(pids[1]), "BOARD_TEST_MALFORMED": str(pids[2]),
                                "BOARD_SCREENSHOT": str(Path(".cache/board.png").resolve())}
            subprocess.run(["vp", "exec", "--filter", "@transit/board-web", "playwright", "test", "board.spec.ts"], env=env, check=True, timeout=180)

        # The removed session endpoints cannot create or revoke Board access.
        request("/api/v1/session", method="POST", status=404)
        request("/api/v1/logout", method="POST", status=404)
        # Stale cookies and arbitrary bearer headers confer no authority. They
        # neither block private access nor bypass Host/Origin or Transit grants.
        ignored = {"Authorization": "Bearer ignored-bearer-marker", "Cookie": "board_session=ignored-cookie-marker"}
        api("capabilities", headers=ignored)
        api("capabilities", headers={**ignored, "Origin": "https://evil.example"}, status=403)
        # Principal scope applies to catalogs, edges, and current reads.
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16, "pid": pids[0]}})
        assert [p["pid"] for p in api("processes")["observation"]["processes"] if p] == pids[:1]
        assert not any(api(f"processes/{pids[0]}/outbox")["observation"]["outbox"])
        api(f"processes/{pids[1]}", status=403)
        s.command({"revoke": 1})
        api("processes", status=403)
        failure(f"processes/{pids[0]}/effects", 403, "inspection.denied", "inspect_scope")
        api("processes", headers=ignored, status=403)
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 17}})
        assert failure("capabilities", 403, "inspection.unsafe_principal", "contact_operator")["err"] == "UnsafePrincipal"
        s.command({"grant": {"subject": 1, "public_key": public, "permissions": 16}})
        # No stale response is served during an authority/storage outage.
        s.authority.kill()
        s.authority.wait(timeout=10)
        failure("processes", 503, "inspection.authority_unavailable", "retry_read")
        s.store.stop()
        s.store.start()
        s.authority = s.start(s.node, s.config)
        wait_ready(s.store.http, s.authority, s.url + "/health")
        assert api(f"processes/{pids[0]}")["observation"]["processes"][0]["revision"] == turn
        assert api(f"processes/{pids[0]}/effects")["effect_diagnostics"][0] == effect_diagnostic
        # Slow viewers consume only Board's bounded request slot, not a node
        # connection. A refresh flood is throttled and control keeps progressing.
        with socket.create_connection(("127.0.0.1", port), timeout=3) as slow:
            slow.sendall(b"GET /api/v1/processes HTTP/1.1\r\nHost:")
            health_started = time.monotonic()
            request('/health')
            assert time.monotonic() - health_started < .5
            started = time.monotonic()
            s.command({"send": {"pid": pids[1], "value": b"control".hex()}})
            assert time.monotonic() - started < 3
        # All data handlers may wait for bodies without occupying health's
        # reserved work slots. These requests have no admission or upstream I/O.
        stalled_bodies = []
        try:
            for _ in range(4):
                peer = socket.create_connection(('127.0.0.1', port), timeout=3)
                peer.sendall(f'POST /api/v1/processes HTTP/1.1\r\nHost: 127.0.0.1:{port}\r\nContent-Length: 100\r\n\r\nx'.encode())
                stalled_bodies.append(peer)
            time.sleep(.05)
            health_started = time.monotonic()
            request('/health')
            assert time.monotonic() - health_started < .5
            request('/api/v1/processes', status=503, retry=False)
        finally:
            for peer in stalled_bodies:
                peer.close()
        time.sleep(.1)
        statuses = []
        def flood():
            for _ in range(25):
                conn = HTTPConnection("127.0.0.1", port, timeout=5)
                conn.request("GET", "/api/v1/processes")
                response = conn.getresponse()
                statuses.append(response.status)
                response.read()
                conn.close()
        latencies = []
        with ThreadPoolExecutor(max_workers=1) as pool:
            future = pool.submit(flood)
            for _ in range(5):
                start = time.monotonic()
                s.command({"send": {"pid": pids[1], "value": b"progress".hex()}})
                latencies.append(time.monotonic() - start)
            future.result()
        assert 429 in statuses and max(latencies) < 3, (statuses, latencies)
        # Current state and explicit gaps remain visible after logical trim.
        before = api(f"processes/{pids[0]}/history")["observation"]["cut"]
        for pid in pids:
            s.command({"terminate": pid})
        s.command({"checkpoint": {}})
        from urllib.parse import urlencode
        assert failure(f"processes/{pids[0]}/history?" + urlencode(before), 409, "inspection.history_reclaimed", "refresh")["err"] == "HistoryReclaimed"
        trimmed = api(f"processes/{pids[0]}/history")["observation"]
        assert trimmed["history"] == "prefix_reclaimed" and not any(trimmed["events"])
        assert api(f"processes/{pids[0]}")["observation"]["processes"][0]["lifecycle"] == "terminated"
        # Request diagnostics contain only fixed routes and outcomes, not secrets.
        request("/?secret=private-query-marker")
        request("/", headers={"traceparent": "00-" + "a" * 32 + "-" + "b" * 16 + "-01"})
        with socket.create_connection(("127.0.0.1", port), timeout=3) as stalled:
            stalled.sendall(b"GET / HTTP/1.1\r\nHost:")
            time.sleep(1.7)
        time.sleep(.1)
        diagnostics = board_log.read_text()
        assert "ignored-bearer-marker" not in diagnostics and "ignored-cookie-marker" not in diagnostics
        assert seed.read_text().strip() not in diagnostics
        assert "private-query-marker" not in diagnostics and "metadata" not in diagnostics
        records = [json.loads(line) for line in diagnostics.splitlines()]
        requests = [r for r in records if r.get("event", {}).get("name") == "board.http.request"]
        assert any(r["event"]["status"] == 403 for r in requests if "status" in r["event"])
        assert any(r["event"]["route"] == "/api/v1/processes/{pid}" for r in requests)
        assert any(r["event"]["outcome"] == "timeout" and not r["event"]["response_written"] for r in requests)
        assert not any(r["event"]["route"] == "/health" and r["event"]["outcome"] == "ok" for r in requests)
        assert all(r["trace_id"] != "a" * 32 for r in requests)
        assert len({r["span_id"] for r in requests}) == len(requests)
        # Restart needs only the Transit signing seed; no access-key file or
        # session establishment is part of recovery.
        running.kill()
        running.wait(timeout=10)
        running = s.start(binary, config, cwd=isolated, env={"PATH": "/no-executables", "LOG_FORMAT": "json"})
        wait_ready(s.store.http, running, origin + "/health")
        assert api("capabilities")["realm"] == 72
        print(f"Board: embedded assets, direct private access, scope/revocation, gaps, effects, outage and load passed; max control latency {max(latencies):.3f}s.")


if __name__ == "__main__":
    run(*[Path(p).resolve() for p in sys.argv[1:4]], browser="--browser" in sys.argv)

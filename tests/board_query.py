"""Board's real growing inspection and separately credentialed query boundary."""
import json
import hashlib
import struct
import os
import signal
from pathlib import Path
import subprocess
import sys
import time
import urllib.error
import urllib.request
from storage import Fixture, free_port, wait_ready


def run(node, host, proof, board, browser=False):
    node, host, proof, board = (str(Path(path).resolve()) for path in (node, host, proof, board))
    with Fixture() as fixture:
        processes, logs = [], []
        def start(name, command):
            log = (fixture.root / f"{name}.log").open("w+")
            logs.append(log)
            process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
            processes.append(process)
            return process
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        public = json.loads(subprocess.check_output([proof, "public"], timeout=10))
        node_config = fixture.root / "node.json"
        node_config.write_text(json.dumps({"profile": "growing_v3", "genesis": {"realm": 45, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "board-query", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
        def admin(mode):
            result = subprocess.run([proof, url, mode, str(fixture.root if mode == "provision" else fixture.root / "cli.json")], capture_output=True, timeout=60)
            assert result.returncode == 0, result.stderr.decode()
            return result
        try:
            subprocess.run([node, str(node_config), "--initialize"], check=True, capture_output=True, timeout=30)
            authority = start("node", [node, str(node_config)])
            wait_ready(fixture.http, authority, url + "/health")
            admin("provision")
            workers = {name: start(name, [host, str(fixture.root / f"{name}.json")]) for name in ("source", "requester", "courier")}
            caller = json.loads((fixture.root / "cli.json").read_text())
            board_port = free_port()
            origin = f"http://127.0.0.1:{board_port}"
            options = {"upstream": url, "realm": 45, "principal": 55, "profile": "growing_v3", "seed_file": str(fixture.root / "inspector.seed"), "public_origin": origin, "port": board_port, "request_timeout_ms": 5000, "upstream_timeout_ms": 1500, "query": {"seed_file": caller["seed_file"], "connection": caller["connection"]}}
            config = fixture.root / "board.json"
            config.write_text(json.dumps(options))
            serving = start("board", [board, str(config)])
            wait_ready(fixture.http, serving, origin + "/health")
            def request(path, operation=None, *, status=200, headers=None):
                time.sleep(0.12)
                body = None if operation is None else json.dumps(operation).encode()
                supplied = {"Origin": origin, "Content-Type": "application/json"} | (headers or {})
                req = urllib.request.Request(origin + path, body, supplied, method="GET" if operation is None else "POST")
                try: response = fixture.http.open(req, timeout=10)
                except urllib.error.HTTPError as err: response = err
                with response:
                    data = response.read()
                    if status == 200 and response.status == 409 and operation is not None and next(iter(operation)) in ("describe", "status", "page") and json.loads(data).get("err") == "QueryExpired":
                        return json.loads(data)
                    if status == 200 and response.status == 409 and path == "/api/v1/atlas":
                        return json.loads(data)
                    assert response.status == status, (response.status, data[:500])
                    assert response.headers["Cache-Control"] == "no-store"
                    return json.loads(data)
            def api(operation, **kwargs):
                for _ in range(8):
                    value = request("/api/v1/query", operation, **kwargs)
                    if kwargs.get("status", 200) != 200 or value.get("err") != "QueryExpired": return value
                    time.sleep(0.1)
                raise AssertionError("resource observation did not stabilize within read retry budget")
            def current_atlas():
                # A fresh current observation can conflict with ongoing worker
                # cleanup. Retry the whole read, never reuse a changed cut.
                for _ in range(12):
                    value = request("/api/v1/atlas")
                    if value.get("err") != "QueryExpired": return value
                    time.sleep(0.1)
                raise AssertionError("atlas did not stabilize within read retry budget")
            caps = request("/api/v1/capabilities")
            assert caps["profile"] == "growing_v3" and caps["query_enabled"] and caps["read_only"]
            atlas = current_atlas()
            assert [row["id"] for row in atlas["resources"]["entries"] if row] == [caller["connection"]["resource"], caller["connection"]["requests"]]
            assert atlas["identity"]["permissions"] == 16
            participant = json.loads(admin("participation").stdout)
            resource, pid = caller["connection"]["resource"], participant["pid"]
            path = f"/api/v1/resources/{resource}/participation"
            group = request(path)
            assert group["resource"]["id"] == resource and len(group["members"]) == 8
            assert group["process_position"] is not None
            selected = request(path + f"?pid={pid}")
            total, pages = 0, 0
            while True:
                assert selected["process_position"] is None
                members = [member for member in selected["members"] if member]
                assert len(members) == 1 and members[0]["pid"] == pid
                member = members[0]
                total += member["matches"]
                pages += 1
                assert member["matches"] <= 8 and pages <= 3
                if member["next"] is None: break
                selected = request(path + f"?pid={pid}&association_after={member['next']}&position={member['association_position']}")
            assert total == 10 and pages == 2
            assert "hidden-participation" not in json.dumps(group)
            admin("revoke-inspector-resource")
            request(path, status=403)
            admin("restore-inspector-resource")
            assert request(path)["resource"]["id"] == resource
            for suffix in ("?after=0", "?pid=0", "?association_after=1", "?after=1&pid=1", "?pid=1&pid=1"):
                request(path + suffix, status=400)
            request("/api/v1/resources/participation", status=400)
            assert api({"status": {"correlation": 9007199254740991}})["status"]["phase"] == "unobserved"
            api({"status": {"correlation": 0}}, status=400)
            source = api({"describe": {}})["source"]
            assert source["schema"]["value_type"] == "int64"
            contract = api({"contract": {}})["contract"]
            assert contract["source"] == source
            names = [bytes(name["bytes"][:name["len"]]) for name in source["schema"]["names"]]
            schema_wire = b'TBL1\x01' + b''.join(bytes([len(name)]) + name for name in names)
            source_wire = b'UQS2' + struct.pack('<QBI', source["connection"]["resource"], 2, source["connection"]["table"]) + bytes([len(schema_wire)]) + schema_wire
            assert bytes(contract["fingerprint"]) == hashlib.sha256(b'transit.query.source.v2\0' + source_wire).digest()
            assert api({"describe": {}})["source"]["sequence"] == source["sequence"]
            api({"prepare": {"sql": "DELETE FROM items"}}, status=400)
            assert api({"describe": {}})["source"]["sequence"] == source["sequence"]
            api({"describe": {}}, headers={"Origin": "https://untrusted.example"}, status=403)
            api({"describe": {}}, headers={"Content-Type": "text/plain"}, status=400)
            # Arbitrary Transit operations cannot cross the optional query route.
            invalid = {"version": 1, "source": source, "plan": {}, "signed": {"request": {"version": 3, "realm": 45, "principal": 1234, "sequence": source["sequence"] + 1, "command": {"checkpoint": {}}}, "signature": [0] * 64}}
            api({"submit": {"token": json.dumps(invalid)}}, status=400)
            prepared = api({"prepare": {"sql": "SELECT value FROM items WHERE value = 9007199254740994 LIMIT 1"}})["prepared"]
            assert "9007199254740994" in prepared["frozen"]["token"]
            malformed = json.loads(prepared["frozen"]["token"])
            malformed["signed"]["request"]["command"]["send"]["value"] = "00"
            api({"submit": {"token": json.dumps(malformed)}}, status=400)
            receipt = api({"submit": prepared["frozen"]})["receipt"]
            # Same opaque bytes reconcile the same admission.
            assert api({"submit": prepared["frozen"]})["receipt"] == receipt
            correlation = receipt["position"]
            deadline = time.monotonic() + 120
            while True:
                observation = api({"status": {"correlation": correlation}})["status"]
                if observation["phase"] == "complete": break
                assert time.monotonic() < deadline, observation
                assert all(process.poll() is None for process in processes)
                time.sleep(0.2)
            page = api({"page": {"correlation": correlation, "ordinal": 0}})["page"]
            assert page["rows"][0][0] == {"int64": "9007199254740994"}
            assert page["manifest"]["rows"] == 1 and page["next"] is None
            # Validate the real wire body with the actual generated JS validators.
            wire_fixture = Path(".cache/verification/m13-query-wire.json")
            wire_fixture.parent.mkdir(parents=True, exist_ok=True)
            wire_fixture.write_text(json.dumps({"source": source, "prepared": prepared, "page": page}))
            subprocess.run(["node", "tests/board_query_client.mjs"], input=json.dumps({"source": source, "prepared": prepared, "page": page}).encode(), check=True, timeout=15)
            admin("revoke")
            api({"prepare": {"sql": "SELECT * FROM items"}}, status=403)
            api({"page": {"correlation": correlation, "ordinal": 0}}, status=403)
            admin("restore")
            # Hold the source before capture: partial/admitted work is unreadable,
            # and cancellation retains its own exact signed transport identity.
            workers["source"].send_signal(signal.SIGSTOP)
            pending = api({"prepare": {"sql": "SELECT * FROM items"}})["prepared"]
            active = api({"submit": pending["frozen"]})["receipt"]["position"]
            deadline = time.monotonic() + 20
            while api({"status": {"correlation": active}})["status"]["phase"] != "admitted":
                assert time.monotonic() < deadline
                time.sleep(0.1)
            api({"page": {"correlation": active, "ordinal": 0}}, status=409)
            cancellation = api({"prepare_cancel": {"correlation": active}})["cancellation"]
            malformed = json.loads(cancellation["token"])
            malformed["request"]["command"]["send"]["value"] = "00"
            api({"cancel": {"token": json.dumps(malformed)}}, status=400)
            cancelled = api({"cancel": cancellation})["receipt"]
            assert api({"cancel": cancellation})["receipt"] == cancelled
            deadline = time.monotonic() + 20
            while api({"status": {"correlation": active}})["status"]["phase"] != "cancelled":
                assert time.monotonic() < deadline
                time.sleep(0.1)
            workers["source"].send_signal(signal.SIGCONT)
            admin("expand-inspector")
            request("/api/v1/capabilities", status=403)
            request(f"/api/v1/atlas?position={atlas['position']}", status=403)
            admin("restore-inspector")
            request(f"/api/v1/atlas?position={atlas['position']}", status=409)
            current_atlas()
            # An inspection-only growing instance must not acquire query access.
            readonly_port = free_port()
            readonly_origin = f"http://127.0.0.1:{readonly_port}"
            readonly = options | {"public_origin": readonly_origin, "port": readonly_port}
            readonly.pop("query")
            readonly_config = fixture.root / "readonly-board.json"
            readonly_config.write_text(json.dumps(readonly))
            readonly_process = start("readonly-board", [board, str(readonly_config)])
            wait_ready(fixture.http, readonly_process, readonly_origin + "/health")
            req = urllib.request.Request(readonly_origin + "/api/v1/query", b'{"describe":{}}', {"Origin": readonly_origin, "Content-Type": "application/json"})
            try: fixture.http.open(req, timeout=10); raise AssertionError("query enabled by default")
            except urllib.error.HTTPError as err:
                assert err.code == 404 and json.loads(err.read())["err"] == "QueryDisabled"
            if browser:
                env = os.environ | {"BOARD_TEST_URL": origin, "BOARD_QUERY_PROOF": proof, "BOARD_QUERY_AUTHORITY": url, "BOARD_QUERY_CONFIG": str(fixture.root / "cli.json"), "BOARD_QUERY_RESOURCE": str(caller["connection"]["resource"]), "BOARD_QUERY_SCREENSHOT": str(Path(".cache/verification/m13-board.png").resolve())}
                subprocess.run(["vp", "exec", "--filter", "@rey/transit-board-web", "playwright", "test", "query.spec.ts"], env=env, check=True, timeout=240)
            else:
                admin("retire-source")
            api({"page": {"correlation": correlation, "ordinal": 0}}, status=410)
            print("Board query: separate identity, SQL/frozen retry, exact typed page, malformed ingress, current grant/cut enforcement" + (", real Canvas/Browse and revocation" if browser else "") + " passed")
        except BaseException:
            for log in logs:
                log.flush(); log.seek(0); sys.stderr.write(log.read()[-2500:])
            raise
        finally:
            for process in reversed(processes):
                if process.poll() is None: process.kill()
                process.wait(timeout=10)
            for log in logs: log.close()


if __name__ == "__main__":
    run(*sys.argv[1:5], browser="--browser" in sys.argv)

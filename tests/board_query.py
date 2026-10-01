"""Board's real growing inspection and separately credentialed query boundary."""
import json
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
        node_config.write_text(json.dumps({"profile": "native_v1", "genesis": {"realm": 45, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "board-query", "journal": "authority", "port": port, "resident_pages": 64, "request_timeout_ms": 10000}))
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
            options = {"upstream": url, "realm": 45, "principal": 55, "profile": "native_v1", "seed_file": str(fixture.root / "inspector.seed"), "public_origin": origin, "port": board_port, "request_timeout_ms": 5000, "upstream_timeout_ms": 1500, "query": {"seed_file": caller["seed_file"], "connection": caller["connection"], "workspace": caller["workspace"]}}
            config = fixture.root / "board.json"
            config.write_text(json.dumps(options))
            serving = start("board", [board, str(config)])
            wait_ready(fixture.http, serving, origin + "/health")
            def request(path, operation=None, *, status=200, headers=None, deadline=None):
                body = None if operation is None else json.dumps(operation).encode()
                supplied = {"Origin": origin, "Content-Type": "application/json"} | (headers or {})
                req = urllib.request.Request(origin + path, body, supplied, method="GET" if operation is None else "POST")
                kind = None if operation is None else next(iter(operation))
                reading = operation is None or (path == "/api/v1/query" and kind in ("describe", "status", "page", "observe"))
                attempts = (12 if path.split("?", 1)[0] == "/api/v1/atlas" else 8) if reading else 1
                for attempt in range(attempts):
                    time.sleep(0.12)
                    remaining = 10 if deadline is None else deadline - time.monotonic()
                    assert remaining > 0, "Board observation exceeded its existing deadline"
                    try: response = fixture.http.open(req, timeout=min(10, remaining))
                    except urllib.error.HTTPError as err: response = err
                    with response:
                        data = response.read()
                        value = json.loads(data)
                        unavailable = response.status == 503 and value.get("err") == "Unavailable"
                        changed = (status == 200 and response.status == 409 and
                                   value.get("err") == "QueryExpired" and
                                   (kind in ("describe", "status", "page") or path == "/api/v1/atlas"))
                        if reading and response.status != status and (unavailable or changed):
                            # Temporary unavailability cannot prove an expected
                            # denial or expired cut. Repeat the identical read,
                            # including its saved position, until that assertion
                            # is observable. Never retry a mutation here.
                            if kind == "observe" and status == 200 and unavailable:
                                return value  # settle owns the receipt deadline.
                            if attempt + 1 < attempts:
                                time.sleep(0.1)
                                continue
                        assert response.status == status, (response.status, data[:500])
                        assert response.headers["Cache-Control"] == "no-store"
                        return value
            def api(operation, **kwargs):
                return request("/api/v1/query", operation, **kwargs)
            def current_atlas():
                return request("/api/v1/atlas")
            caps = request("/api/v1/capabilities")
            assert caps["profile"] == "native_v1" and caps["query_enabled"] and caps["read_only"]
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
            assert api({"status": "9007199254740991"})["status"] is None
            api({"status": "not-an-id"}, status=400)
            description = api({"describe": {}})["description"]
            assert description["source"]["source"]["source"]["table"]["value_type"] == "int64"
            before = admin("next-sequence").stdout
            api({"compile": {"sql": "DELETE FROM items"}}, status=400)
            assert admin("next-sequence").stdout == before, "invalid SQL admitted a command"
            api({"describe": {}}, headers={"Origin": "https://untrusted.example"}, status=403)
            api({"describe": {}}, headers={"Content-Type": "text/plain"}, status=400)
            # Only typed finite query commands cross this optional route.
            invalid = {"version": 1, "signed": {"request": {"version": 1, "realm": 45, "principal": 1234, "sequence": 99, "command": {"checkpoint": {}}}, "signature": [0] * 64}}
            api({"submit": {"token": json.dumps(invalid)}}, status=400)
            compiled = api({"compile": {"sql": "SELECT value FROM items WHERE value = 9007199254740994 LIMIT 1"}})["compiled"]
            assert "9007199254740994" in json.dumps(compiled["plan"])
            prepared = api({"next": {"namespace": "1", "bundle": compiled["bundle"]}})["prepared"]
            malformed = json.loads(prepared["token"])
            malformed["signed"]["request"]["command"]["send"]["value"] = "00"
            api({"submit": {"token": json.dumps(malformed, separators=(",", ":"))}}, status=400)
            def settle(prepared):
                receipt = api({"submit": prepared})["receipt"]
                assert api({"submit": prepared})["receipt"] == receipt
                until = time.monotonic() + 60
                while True:
                    response = api({"observe": receipt["position"]}, deadline=until)
                    # An unavailable receipt read says nothing new about the
                    # frozen submission. Observe the same receipt again without
                    # preparing or submitting another mutation.
                    if response.get("err") != "Unavailable":
                        observed = response["observation"]
                        if "pending" not in observed:
                            break
                    assert time.monotonic() < until
                    time.sleep(0.05)
                assert "committed" in observed, observed
                return receipt
            def upload(namespace, bundle):
                until = time.monotonic() + 120
                while True:
                    prepared = api({"next": {"namespace": namespace, "bundle": bundle}})["prepared"]
                    if prepared is None: return
                    settle(prepared)
                    assert time.monotonic() < until
            settle(prepared)
            upload("1", compiled["bundle"])
            deadline = time.monotonic() + 120
            while True:
                observation = api({"status": "1"}, deadline=deadline)["status"]
                if observation["phase"] == "complete": break
                assert time.monotonic() < deadline, observation
                assert all(process.poll() is None for process in processes)
                time.sleep(0.2)
            page = api({"page": {"namespace": "1"}})["page"]
            assert page["cells"] == [[{"value": {"int64": "9007199254740994"}}]]
            assert page["evidence"]["manifest"]["rows"] == "1" and page["evidence"]["next"] is None
            assert page["evidence"]["manifest"]["basis"]["contract"] == compiled["contract"]
            # Validate actual public responses using the generated JS boundary.
            values = {"description": description, "compiled": compiled, "prepared": prepared, "page": page}
            wire_fixture = Path(".cache/verification/native-v1-query-wire.json")
            wire_fixture.parent.mkdir(parents=True, exist_ok=True)
            wire_fixture.write_text(json.dumps(values))
            subprocess.run(["node", "tests/board_query_client.mjs"], input=json.dumps(values).encode(), check=True, timeout=15)
            admin("revoke")
            api({"compile": {"sql": "SELECT * FROM items"}}, status=403)
            api({"page": {"namespace": "1"}}, status=403)
            admin("restore")
            # A paused source cannot expose an incomplete result. Cancellation is
            # a separate frozen command with its own exact retry identity.
            workers["source"].send_signal(signal.SIGSTOP)
            pending = api({"compile": {"sql": "SELECT * FROM items"}})["compiled"]
            upload("2", pending["bundle"])
            assert api({"status": "2"})["status"]["phase"] == "admitted"
            api({"page": {"namespace": "2"}}, status=409)
            cancellation = api({"prepare_control": {"namespace": "2", "operation": "cancel"}})["prepared"]
            malformed = json.loads(cancellation["token"])
            malformed["signed"]["request"]["command"]["send"]["value"] = "00"
            api({"submit": {"token": json.dumps(malformed, separators=(",", ":"))}}, status=400)
            settle(cancellation)
            assert api({"status": "2"})["status"]["phase"] == "cancelled"
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
            api({"page": {"namespace": "1"}}, status=410)
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

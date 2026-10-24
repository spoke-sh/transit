"""Real local Table HTTP owner, public typed caller, reply fault and disk restart."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import urllib.request

from storage import free_port, wait_ready


def run(node, caller, mode="tables"):
    if mode not in ("tables", "dependencies", "resources", "callers"):
        raise ValueError("Unknown direct service proof mode")
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with tempfile.TemporaryDirectory(prefix="transit-direct-table-") as directory:
        root = Path(directory)
        profile = root / "profile.json"
        config = root / "node.json"
        seed = root / "registrar.seed"
        seed.write_text("11" * 32)
        seed.chmod(0o600)
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        settings = {
            "genesis": {"realm": 42, "root_key": json.loads(subprocess.check_output([caller, "public"], timeout=15))},
            "local_directory": str(root / "native"),
            "port": port, "resident_pages": 1, "request_timeout_ms": 60000,
        }
        if mode == "resources":
            settings["genesis"]["max_clock_error_ms"] = 10000
        config.write_text(json.dumps(settings))
        http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        log = (root / "node.log").open("w+")
        authority = None
        proxy = None
        thread = None

        def start():
            child = subprocess.Popen([node, str(config), "--bootstrap"], stdout=log, stderr=subprocess.STDOUT)
            try:
                wait_ready(http, child, url + "/health")
            except BaseException:
                child.kill()
                child.wait(timeout=15)
                raise
            return child

        def stop(child):
            child.terminate()
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait(timeout=15)

        fault = {"changed": False, "assertion_changed": False, "namespace_changed": False, "pin_changed": False, "delegated_pin": False, "delegated_release": False, "history_pin": False, "history_release": False, "execute": None, "requests": 0, "commands": []}

        dependency_faults = set()
        resource_faults = set()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                headers = {"Content-Type": "application/json"}
                for name in ("x-transit-control", "x-transit-wait"):
                    if name in self.headers:
                        headers[name] = self.headers[name]
                connection = HTTPConnection("127.0.0.1", port, timeout=70)
                try:
                    connection.request("POST", self.path, body, headers)
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/table/v1":
                        fault["requests"] += 1
                        resource = envelope["action"].get("resource_operation")
                        if mode == "resources" and resource and resource["binding"]["operation"] in (80000, 80001) and resource["command"] != "inspect" and response.status == 200:
                            parsed = json.loads(data)
                            operation = parsed["result"]["resource_operation"]["operation"]
                            identity = (resource["binding"]["operation"], operation["phase"])
                            if identity not in resource_faults:
                                assert operation["binding"] == resource["binding"]
                                assert operation["phase"] in ("admitted", "prepared", "allocated", "complete")
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                resource_faults.add(identity)
                        dependency = envelope["action"].get("dependency_operation")
                        if (mode in ("dependencies", "resources") and dependency and dependency["command"] == "accept"
                                and dependency["binding"]["operation"] in ((70001, 70002) if mode == "dependencies" else (83000, 83001, 83010, 83011))
                                and dependency["binding"]["operation"] not in dependency_faults
                                and response.status == 200):
                            parsed = json.loads(data)
                            outcome = parsed["result"]["dependency_operation"]["outcome"]
                            assert outcome["phase"] == "applied" and outcome["changed"]
                            assert outcome["binding"] == dependency["binding"]
                            parsed["context"][0] ^= 1
                            data = json.dumps(parsed).encode()
                            dependency_faults.add(dependency["binding"]["operation"])
                        namespace = envelope["action"].get("namespace_operation")
                        if namespace and namespace["binding"]["operation"] == 65000 and namespace["command"] == "execute" and not fault["namespace_changed"]:
                            assert response.status == 200, data
                            parsed = json.loads(data)
                            assert parsed["result"]["namespace_operation"]["operation"]["phase"] == "applied"
                            parsed["context"][0] ^= 1
                            data = json.dumps(parsed).encode()
                            fault["namespace_changed"] = True
                        assertion = envelope["action"].get("name_assertion")
                        if assertion and assertion["binding"]["operation"] == 501 and assertion["command"] == "accept" and not fault["assertion_changed"]:
                            assert response.status == 200, data
                            parsed = json.loads(data)
                            assert parsed["result"]["name_assertion"]["outcome"]["state"] == "unchanged"
                            parsed["context"][0] ^= 1
                            data = json.dumps(parsed).encode()
                            fault["assertion_changed"] = True
                        pin = envelope["action"].get("pin")
                        if pin and envelope["delegation"] is None and pin["owner"]["operation"] != 90 and not fault["pin_changed"]:
                            assert response.status == 200, data
                            parsed = json.loads(data)
                            assert "pin" in parsed["result"]
                            parsed["context"][0] ^= 1
                            data = json.dumps(parsed).encode()
                            fault["pin_changed"] = True
                        release = envelope["action"].get("release")
                        history = envelope["action"].get("retain_history")
                        historical = envelope["delegation"] and envelope["delegation"]["binding"]["retention"] == "history"
                        for action, key, result in ((pin, "delegated_pin", "pin"), (history, "history_pin", "pin"), (release, "history_release" if historical else "delegated_release", "released")):
                            if action and envelope["delegation"] and envelope["delegation"]["binding"]["owner"]["operation"] not in (8201, 8202) and not fault[key]:
                                assert response.status == 200, data
                                parsed = json.loads(data)
                                assert result in parsed["result"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                fault[key] = True
                        operation = envelope["action"].get("operation")
                        if operation and operation["command"] == "execute":
                            fault["execute"] = body
                            if operation["binding"]["identity"]["operation"] == 2 and not fault["changed"]:
                                assert response.status == 200, data
                                parsed = json.loads(data)
                                assert "committed" in parsed["result"]["rows"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                fault["changed"] = True
                    elif self.path == "/v1/command":
                        fault["commands"].append(next(iter(envelope["request"]["command"])))
                    self.send_response(response.status)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()

        try:
            authority = start()
            subprocess.run([caller, url, "provision", str(profile)], check=True, timeout=180)
            stop(authority)
            authority = None
            settings["table"] = {"catalog": json.loads(profile.read_text())["catalog"], "registrar": {"principal": 0, "seed_file": str(seed)}}
            config.write_text(json.dumps(settings))
            authority = start()
            proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            endpoint = f"http://127.0.0.1:{proxy.server_port}"
            if mode == "callers":
                subprocess.run([caller, endpoint, "callers", str(profile)], check=True, timeout=240)
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(f"Direct Table callers: {fault['requests']} typed HTTP calls, shared SQL/typed preparation, frozen session restoration, wide bulk values, preview, explicit admission and retained receipts passed.")
                return
            if mode == "resources":
                subprocess.run([caller, endpoint, "resource-save", str(profile)], check=True, timeout=180)
                saved = profile.read_bytes()
                phases = ("admit", "prepare-0", "allocate-0", "prepare-1", "allocate-1", "initialize-0", "initialize-1", "initialize-2", "publish")
                for phase in phases:
                    subprocess.run([caller, endpoint, f"resource-{phase}", str(profile)], check=True, timeout=180)
                    assert profile.read_bytes() == saved, "Recovery changed the original resource binding"
                    authority.kill()
                    authority.wait(timeout=15)
                    authority = None
                    authority = start()
                subprocess.run([caller, endpoint, "resource-dependency-save", str(profile)], check=True, timeout=180)
                assert json.loads(profile.read_bytes())["named_resources"]["bindings"] == json.loads(saved)["named_resources"]["bindings"]
                saved = profile.read_bytes()
                for phase in ("register", "remove"):
                    subprocess.run([caller, endpoint, f"resource-dependency-{phase}", str(profile)], check=True, timeout=180)
                    assert profile.read_bytes() == saved, "Recovery changed the saved dependency bindings"
                    authority.kill()
                    authority.wait(timeout=15)
                    authority = None
                    authority = start()
                    if phase == "register":
                        subprocess.run([caller, endpoint, "resource-dependency-recover", str(profile)], check=True, timeout=180)
                subprocess.run([caller, endpoint, "resource-verify", str(profile)], check=True, timeout=240)
                assert resource_faults == {(identity, phase) for identity in (80000, 80001) for phase in ("admitted", "prepared", "allocated", "complete")}, resource_faults
                assert profile.read_bytes() == saved
                assert dependency_faults == {83000, 83001, 83010, 83011}, dependency_faults
                print(f"Named resources: {fault['requests']} typed catalog calls, 8 withheld stage replies, 4 withheld dependency replies and 11 abrupt node replacements, unchanged saved declarations and dependency bindings, serialized original caller allocation without data grants, actual Station KV/Document initialization, typed KV writes/deletes, Document publication, current data revocation, both graph directions, DROP RESTRICT and explicit original-edge cleanup passed.")
                return
            if mode == "dependencies":
                subprocess.run([caller, endpoint, "dependency-prepare", str(profile)], check=True, timeout=180)
                saved = profile.read_bytes()
                for phase, operation in (("dependency-register", 70001), ("dependency-remove", 70002)):
                    subprocess.run([caller, endpoint, phase, str(profile)], check=True, timeout=180)
                    assert operation in dependency_faults
                    assert profile.read_bytes() == saved, "Recovery changed the original saved binding"
                    authority.kill()
                    authority.wait(timeout=15)
                    authority = None
                    authority = start()
                    recovered = "dependency-recover" if operation == 70001 else "dependency-final"
                    subprocess.run([caller, endpoint, recovered, str(profile)], check=True, timeout=180)
                    assert profile.read_bytes() == saved
                assert set(fault["commands"]) <= {"authorization", "spawn", "create_resource", "grant_resource"}, fault["commands"]
                print(f"Direct dependencies: {fault['requests']} typed calls, exact registration/removal receipts after corrupt replies and abrupt node replacement, unchanged saved caller bindings, current metadata revocation, redacted RESTRICT blockers, reverse inspection, stale retry rejection and DROP/name replacement passed.")
                return
            subprocess.run([caller, endpoint, "write", str(profile)], check=True, timeout=180)
            assert fault["changed"]
            assert fault["pin_changed"]
            assert fault["assertion_changed"]
            assert fault["delegated_pin"] and fault["history_pin"]
            segments = list((root / "native").rglob("*.tseg"))
            assert segments, "Bulk acceptance created no .tseg object"
            stop(authority)
            authority = None
            authority = start()
            subprocess.run([caller, endpoint, "recover", str(profile)], check=True, timeout=180)
            saved = profile.read_bytes()
            checkpoint = json.loads(saved)['history']['checkpoint']
            assert checkpoint['version'] == 1 and checkpoint['definition'] == json.loads(saved)['definition']
            assert checkpoint['source']['point']['lease']['owner']['operation'] == 8300
            assert checkpoint['source']['object']['object'] == 7
            subprocess.run([caller, endpoint, "history-position", str(profile)], check=True, timeout=30)
            try:
                for missing in ('version', 'definition'):
                    malformed = json.loads(saved)
                    del malformed['history']['checkpoint'][missing]
                    profile.write_text(json.dumps(malformed))
                    rejected = subprocess.run([caller, endpoint, "history-position", str(profile)], capture_output=True, text=True, timeout=30)
                    assert rejected.returncode != 0 and 'MissingField' in rejected.stderr
                malformed = json.loads(saved)
                malformed['history']['checkpoint']['definition'] = 'foreign-definition'
                profile.write_text(json.dumps(malformed))
                rejected = subprocess.run([caller, endpoint, "history-position", str(profile)], capture_output=True, text=True, timeout=30)
                assert rejected.returncode != 0 and 'InvalidJsonShape' in rejected.stderr
                malformed = json.loads(saved)
                malformed['history']['checkpoint']['source']['point']['commitment'][0] ^= 1
                profile.write_text(json.dumps(malformed))
                rejected = subprocess.run([caller, endpoint, "history-position", str(profile)], capture_output=True, text=True, timeout=30)
                assert rejected.returncode != 0 and 'Conflict' in rejected.stderr
            finally:
                profile.write_bytes(saved)
            stop(authority)
            authority = None
            authority = start()
            subprocess.run([caller, endpoint, "lifecycle", str(profile)], check=True, timeout=180)
            assert fault["delegated_release"] and fault["history_release"] and fault["namespace_changed"]
            stop(authority)
            authority = None
            authority = start()
            subprocess.run([caller, endpoint, "delegated-closed", str(profile)], check=True, timeout=180)
            assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
            assert fault["execute"] is not None
            # An admission hint cannot place ordinary execution in the reserve.
            connection = HTTPConnection("127.0.0.1", port, timeout=15)
            connection.request("POST", "/table/v1", fault["execute"], {"Content-Type": "application/json", "X-Transit-Control": "table"})
            response = connection.getresponse()
            assert response.status == 400 and json.loads(response.read())["err"] == "InvalidRequest"
            connection.close()
            print(f"Direct Table HTTP: {fault['requests']} typed calls, 64 KiB point row, {len(segments)} initial .tseg object(s), full CRUD/DDL, typed SQL namespace lifecycle with lost-reply recovery and retained reads after namespace retirement, typed SQL predicate UPDATE/DELETE, finite SQL filter/count and retained joins, authorized metadata completion, durable SQL pin-journal cleanup, conditional SQL name evidence, exact lost-reply recovery, original-caller read delegation without executor Table grants, retained pins across rewrite/drop/recreation and three restarts, uncertain delegated acquisition/closure, saved direct change-reader checkpoints, paused backfill, paired changes, complete no-op/schema transactions, partial-delivery replay and original schemas through DROP/recreation, current revocation and reserved-control rejection passed.")
        except BaseException:
            log.flush()
            log.seek(0)
            sys.stderr.write(log.read()[-48000:])
            raise
        finally:
            if proxy is not None:
                proxy.shutdown()
                proxy.server_close()
            if thread is not None:
                thread.join(timeout=15)
            if authority is not None:
                stop(authority)
            log.close()


if __name__ == "__main__":
    run(*sys.argv[1:])

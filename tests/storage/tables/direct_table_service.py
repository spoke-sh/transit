"""Real local Table HTTP owner, public typed caller, reply fault and disk restart."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time
import urllib.request

from harness.services import free_port, wait_ready
from runner.capture import identity, provenance
from runner.paths import ROOT
from storage.tables import direct_table_maintenance


def run(node, caller, mode="tables", *artifacts):
    if mode not in ("tables", "maintenance", "growth", "resource-growth", "dependency-growth", "prepared", "count-ranges", "collations", "projection", "authorization", "dependencies", "resources", "callers", "abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node"):
        raise ValueError("Unknown direct service proof mode")
    assert len(artifacts) == (2 if mode in ("abi", "board", "board-browser", "relational", "relational-python", "relational-node") else 1 if mode in ("sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") else 0)
    node, caller = str(Path(node).resolve()), str(Path(caller).resolve())
    with direct_table_maintenance.directory(mode) as directory:
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
        request_memory = direct_table_maintenance.RequestMemory() if mode == "maintenance" else None
        if request_memory is not None or mode == "tables":
            settings["request_metrics"] = True
        if mode in ("resources", "resource-growth"):
            settings["genesis"]["max_clock_error_ms"] = 10000
        if mode == "resource-growth":
            # Match the installed native cache. The 139 live resources still
            # exceed both this cache and the direct catalog's 16 eight-entry pages.
            settings["resident_pages"] = 8
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

        fault = {"changed": False, "assertion_changed": False, "namespace_changed": False, "pin_changed": False, "delegated_pin": False, "delegated_release": False, "history_pin": False, "history_release": False, "relational_setup": False, "transaction_records_refused": set(), "transaction_quota_refused": False, "execute": None, "requests": 0, "commands": []}

        dependency_faults = set()
        resource_faults = set()
        abi_faults = set()
        retention_faults = set()
        accepted_inspections = []
        pressure_scan = []
        capture_pressure_scan = False
        board_fault = {"next": None, "accepted": []}

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
                        if request_memory is not None:
                            request_memory.observe(envelope["action"], response.getheader("x-transit-work"), len(data))
                        if capture_pressure_scan and "scan" in envelope["action"] and response.status == 200:
                            assert not pressure_scan, "Pressure oracle issued more than one scan"
                            metrics = json.loads(response.getheader("x-transit-work"))["request_memory"]
                            assert metrics["live_bytes"] == len(data)
                            pressure_scan.append((body, len(data), metrics["peak_bytes"]))
                        fault["requests"] += 1
                        record = envelope["action"].get("record", {}).get("stage")
                        if record and record["format"] in (0x54584331, 0x54585731, 0x54585431, 0x54584f31):
                            assert response.status == 400 and json.loads(data) == {"err": "InvalidRequest"}, data
                            fault["transaction_records_refused"].add(record["format"])
                        token = envelope["action"].get("client_token", {}).get("bind", {})
                        if "transaction" in token.get("intent", {}):
                            assert response.status == 503 and json.loads(data) == {"err": "StorageQuota"}, data
                            fault["transaction_quota_refused"] = True
                        operation = envelope["action"].get("operation")
                        if mode in ("tables", "maintenance") and not accepted_inspections and operation and operation["command"] == "inspect" and response.status == 200:
                            result = json.loads(data)["result"]
                            if "committed" in next(iter(result.values())):
                                accepted_inspections.append((body, result))
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
                        if mode not in ("maintenance", "growth", "prepared", "count-ranges", "collations", "projection", "authorization", "abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") and pin and envelope["delegation"] is None and pin["owner"]["operation"] != 90 and not fault["pin_changed"]:
                            assert response.status == 200, data
                            parsed = json.loads(data)
                            assert "pin" in parsed["result"]
                            parsed["context"][0] ^= 1
                            data = json.dumps(parsed).encode()
                            fault["pin_changed"] = True
                        release = envelope["action"].get("release")
                        for selected, tag in ((pin, "pin"), (release, "release")):
                            if mode in ("abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") and selected:
                                owner = selected["owner"] if tag == "pin" else selected["handle"]["owner"]
                                key = (owner["operation"], tag)
                                if owner["operation"] in (90000, 90010) and key not in retention_faults:
                                    assert response.status == 200, data
                                    parsed = json.loads(data)
                                    assert ("pin" if tag == "pin" else "released") in parsed["result"]
                                    parsed["context"][0] ^= 1
                                    data = json.dumps(parsed).encode()
                                    retention_faults.add(key)
                        if mode in ("board", "board-browser"):
                            for selected, tag in ((pin, "pin"), (release, "release")):
                                if selected and board_fault["next"] == tag:
                                    assert response.status == 200, data
                                    parsed = json.loads(data)
                                    assert ("pin" if tag == "pin" else "released") in parsed["result"]
                                    board_fault["accepted"].append(dict(action=selected, result=parsed["result"]))
                                    board_fault["next"] = None
                                    parsed["context"][0] ^= 1
                                    data = json.dumps(parsed).encode()
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
                            identity = operation["binding"]["identity"]["operation"]
                            if mode in ("relational", "relational-python", "relational-node") and identity == 1002 and not fault["relational_setup"]:
                                assert response.status == 200, data
                                parsed = json.loads(data)
                                assert "committed" in parsed["result"]["ddl"], parsed["result"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                fault["relational_setup"] = True
                            if mode in ("abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") and identity in (2, 12) and identity not in abi_faults:
                                assert response.status == 200, data
                                parsed = json.loads(data)
                                assert "committed" in parsed["result"]["rows"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                abi_faults.add(identity)
                            if mode not in ("abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") and operation["binding"]["identity"]["operation"] == 2 and not fault["changed"]:
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
            if mode == "maintenance":
                def restart(flush, physical=False, pressure=False, foreground=False):
                    nonlocal authority
                    authority.kill()
                    authority.wait(timeout=15)
                    authority = None
                    settings["maintenance"] = {"principal": 0, "seed_file": str(seed), "interval_ms": 50, "operation_timeout_ms": 2000}
                    settings["storage"] = {"maintenance": {"flush": {"enabled": flush},
                                                           "archive": {"enabled": physical},
                                                           "compact": physical}}
                    if foreground:
                        settings["storage"]["maintenance"]["flush"]["rows"] = 1
                    settings["request_timeout_ms"] = 5000 if pressure else 60000
                    if pressure:
                        settings["storage"]["requests"] = {"request_bytes": 1048576, "data_bytes": 1048576}
                    config.write_text(json.dumps(settings))
                    authority = start()
                direct_table_maintenance.exercise(caller, endpoint, profile, root, restart,
                                                  lambda: authority, node, request_memory,
                                                  port, accepted_inspections)
                return
            if mode == "growth":
                subprocess.run([caller, endpoint, "growth-write", str(profile)], check=True, timeout=600)
                saved = profile.read_bytes()
                authority.kill()
                authority.wait(timeout=15)
                authority = None
                settings["maintenance"] = {"principal": 0, "seed_file": str(seed), "interval_ms": 50, "operation_timeout_ms": 2000}
                settings["storage"] = {"maintenance": {"flush": {"enabled": True, "rows": 1},
                                                       "archive": {"enabled": True}, "compact": True}}
                config.write_text(json.dumps(settings))
                authority = start()
                before = direct_table_maintenance.process_usage(authority)
                began = time.monotonic()
                deadline = began + 600
                samples = []
                overlap = False
                while True:
                    remaining = deadline - time.monotonic()
                    assert remaining > 0, samples
                    result = subprocess.run([caller, endpoint, "growth-maintenance", str(profile)],
                                            check=True, timeout=min(180, remaining), capture_output=True, text=True)
                    progress = json.loads(result.stdout)
                    samples.append(dict(seconds=time.monotonic() - began, **progress))
                    with (root / 'growth-maintenance-observations.jsonl').open('a') as output:
                        output.write(json.dumps(samples[-1]) + '\n')
                    if progress["busy_tables"] == 0:
                        break
                    remaining = deadline - time.monotonic()
                    assert remaining > 0, samples
                    subprocess.run([caller, endpoint, "growth-read", str(profile)], check=True, timeout=min(180, remaining))
                    overlap = True
                    assert time.monotonic() - began < 600, samples
                assert overlap and samples[-1]["segments"] > 0, samples
                after = direct_table_maintenance.process_usage(authority)
                print(json.dumps(dict(profile="catalog_growth_maintenance", tables=139, rows=139,
                                      source=provenance(ROOT), binaries=[identity(Path(path)) for path in (node, caller)],
                                      clock_ticks_per_second=os.sysconf('SC_CLK_TCK'),
                                      node_before=before, node_after=after, samples=samples,
                                      storage=settings["storage"], resident_pages=settings["resident_pages"])), flush=True)
                subprocess.run([caller, endpoint, "growth-recover", str(profile)], check=True, timeout=180)
                assert profile.read_bytes() == saved, "Recovery replaced the original retained basis"
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(f"Direct catalog growth: 139 Tables, 139 retained rows in bounded pages, automatic maintenance convergence beyond host cache/lock stripes, original pin after node SIGKILL/restart and explicit cleanup passed ({fault['requests']} typed calls).", flush=True)
                return
            if mode == "dependency-growth":
                subprocess.run([caller, endpoint, "dependency-growth-write", str(profile)], check=True, timeout=600)
                saved = profile.read_bytes()
                authority.kill()
                authority.wait(timeout=15)
                authority = None
                authority = start()
                subprocess.run([caller, endpoint, "dependency-growth-recover", str(profile)], check=True, timeout=300)
                assert profile.read_bytes() == saved
                print(f"Direct dependency growth: 139 retained edges, bounded forward/reverse pages, current redaction and RESTRICT, original receipt after node SIGKILL/restart passed ({fault['requests']} typed calls).", flush=True)
                return
            if mode == "resource-growth":
                # Aggregate setup includes 139 real native owners and initialized
                # values. Individual caller requests retain their 30-second cap;
                # this is a growth/recovery proof, not an interactive latency gate.
                # Allow the complete native provisioning/initialization schedule
                # a separate 90-minute budget; its cost grows with retained state.
                subprocess.run([caller, endpoint, "resource-growth-write", str(profile)], check=True, timeout=5400)
                saved = profile.read_bytes()
                pending = Path(str(profile) + ".resource-growth").read_bytes()
                # Directory/value readback is a separate bounded phase, both
                # before and after replacement. Keep every original assertion
                # without charging the readback to the provisioning deadline.
                print("Named resource growth: verifying all resources before replacement.", flush=True)
                subprocess.run([caller, endpoint, "resource-growth-recover", str(profile)], check=True, timeout=900)
                authority.kill()
                authority.wait(timeout=15)
                authority = None
                authority = start()
                print("Named resource growth: verifying all resources after SIGKILL/restart.", flush=True)
                subprocess.run([caller, endpoint, "resource-growth-recover", str(profile)], check=True, timeout=900)
                assert profile.read_bytes() == saved
                assert Path(str(profile) + ".resource-growth").read_bytes() == pending
                print(f"Named resource growth: 139 initialized KV/Document objects, typed values and eight-entry directory pages, original first receipt after node SIGKILL/restart passed ({fault['requests']} typed catalog calls).", flush=True)
                return
            if mode == "authorization":
                subprocess.run([caller, endpoint, "initialize", str(profile)], check=True, timeout=60)
                subprocess.run([caller, endpoint, "authorization-lifetime", str(profile)], check=True, timeout=180)
                print("Direct Table authorization: explicit set-only role, no native resource/process access, SQL-issued future-only defaults, filtered metadata, SELECT-only write/DDL denial and retained-cut recovery after revocation/restoration passed.", flush=True)
                return
            if mode == "prepared":
                subprocess.run([caller, endpoint, "initialize", str(profile)], check=True, timeout=180)
                subprocess.run([caller, endpoint, "prepared-lifetime", str(profile)], check=True, timeout=180)
                print("Direct prepared Table: metadata-only binding, typed values, fresh snapshots, current denial and definition replacement passed.", flush=True)
                return
            if mode == "projection":
                subprocess.run([caller, endpoint, "initialize", str(profile)], check=True, timeout=180)
                subprocess.run([caller, endpoint, "projection", str(profile)], check=True, timeout=180)
                assert list((root / "native").rglob("*.tseg"))
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print("Direct Table projected reads and finite SQL passed.", flush=True)
                return
            if mode == "collations":
                subprocess.run([caller, endpoint, "initialize", str(profile)], check=True, timeout=180)
                subprocess.run([caller, endpoint, "collations", str(profile)], check=True, timeout=180)
                print("Direct Table collation declarations, comparison paths and retained mutations passed.", flush=True)
                return
            if mode == "count-ranges":
                subprocess.run([caller, endpoint, "initialize", str(profile)], check=True, timeout=180)
                subprocess.run([caller, endpoint, "count-ranges", str(profile)], check=True, timeout=180)
                print("Direct Table count ranges: same-pin scan controls and current disclosure checks passed.", flush=True)
                return
            if mode in ("abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node"):
                subprocess.run([caller, endpoint, "initialize", str(profile)], check=True, timeout=180)
                if mode in ("relational", "relational-python", "relational-node"):
                    from query.execution.relational_callers_native import exercise
                    def relational_restart():
                        nonlocal authority
                        authority.kill()
                        authority.wait(timeout=15)
                        authority = None
                        authority = start()
                    def relational_policy(allow):
                        subprocess.run([caller, endpoint, "caller-allow" if allow else "caller-deny", str(profile)], check=True, timeout=180)
                    language = mode.removeprefix("relational-") if mode != "relational" else None
                    exercise(*artifacts, root, url, endpoint, json.loads(profile.read_text()), relational_restart, relational_policy, language)
                    assert fault["relational_setup"], "Relational setup never recovered the lost original DDL reply"
                    assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                    assert list((root / "native").rglob("*.tseg"))
                    print(f"Direct relational callers: {fault['requests']} public requests, original retained joins, current denial, node/caller replacement, budget and ordered overflow passed.")
                    return
                if mode in ("board", "board-browser"):
                    from interfaces.board.board_relational import exercise
                    subprocess.run([caller, endpoint, "board-inspector", str(profile)], check=True, timeout=180)
                    def board_restart():
                        nonlocal authority
                        authority.kill()
                        authority.wait(timeout=15)
                        authority = None
                        authority = start()
                    def board_policy(allow):
                        subprocess.run([caller, endpoint, "caller-allow" if allow else "caller-deny", str(profile)], check=True, timeout=180)
                    exercise(*artifacts, root, url, endpoint, json.loads(profile.read_text()), board_restart, board_policy, board_fault, caller, mode == "board-browser")
                    assert board_fault["next"] is None
                    assert len(board_fault["accepted"]) == 3, board_fault
                    assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                    assert list((root / "native").rglob("*.tseg"))
                    print(f"Direct Board: {fault['requests']} public requests; original pin recovery, node/Board replacements, cached/terminal current denial, private origin and explicit cleanup passed.")
                    return
                subprocess.run([caller, endpoint, "installed-authorization", str(profile)], check=True, timeout=180)
                if mode == "abi":
                    from catalog.tables.direct_catalog_abi import exercise
                elif mode == "sdk-python":
                    from sdk.direct_sdk_catalog import exercise
                elif mode == "sdk-node":
                    from sdk.direct_sdk_catalog import exercise_node as exercise
                elif mode == "sdk-ruby":
                    from sdk.direct_sdk_catalog import exercise_ruby as exercise
                elif mode == "sdk-java":
                    from sdk.direct_sdk_catalog import exercise_java as exercise
                elif mode == "sdk-dotnet":
                    from sdk.direct_sdk_catalog import exercise_dotnet as exercise
                elif mode == "sdk-rust":
                    from sdk.direct_sdk_catalog import exercise_rust as exercise
                elif mode == "sdk-beam":
                    from sdk.direct_sdk_catalog import exercise_beam as exercise
                else:
                    from sdk.direct_sdk_catalog import exercise_c as exercise
                def restart():
                    nonlocal authority
                    authority.kill()
                    authority.wait(timeout=15)
                    authority = None
                    authority = start()
                def policy(allow):
                    subprocess.run([caller, endpoint, "installed-allow" if allow else "installed-deny", str(profile)], check=True, timeout=180)
                exercise(*artifacts, root, url, endpoint, json.loads(profile.read_text()), restart, policy)
                assert abi_faults == ({2} if mode in ("sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust") else {2, 12}), abi_faults
                assert retention_faults == {(operation, tag) for operation in ((90000,) if mode in ("sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust") else (90000, 90010)) for tag in ("pin", "release")}, retention_faults
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                assert list((root / "native").rglob("*.tseg"))
                retained = "retained metadata with current access" if mode in ("sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") else "cached/terminal revocation and retained SQL"
                print(f"Direct catalog {mode}: {fault['requests']} public requests, wide bulk staging, exact uncertain receipts, uncertain pin/release replies, caller/node replacements, {retained} after DROP/name reuse passed.")
                return
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
            assert fault["transaction_records_refused"] == {0x54584331, 0x54585731, 0x54585431, 0x54584f31}
            assert fault["transaction_quota_refused"]
            assert fault["changed"]
            assert fault["pin_changed"]
            assert fault["assertion_changed"]
            assert fault["delegated_pin"] and fault["history_pin"]
            segments = list((root / "native").rglob("*.tseg"))
            assert accepted_inspections, "No accepted original operation available for pressure recovery"
            capture_pressure_scan = True
            subprocess.run([caller, endpoint, "pressure-read", str(profile)], check=True, timeout=30)
            capture_pressure_scan = False
            assert len(pressure_scan) == 1
            # Preserve the exact original recovery and immutable scan envelopes
            # inside this private installation before injecting any pressure.
            (root / "pressure-requests.json").write_text(json.dumps(dict(
                inspection=json.loads(accepted_inspections[0][0]),
                expected=accepted_inspections[0][1], scan=json.loads(pressure_scan[0][0]),
                response_bytes=pressure_scan[0][1], baseline_peak_bytes=pressure_scan[0][2])))
            stop(authority)
            authority = None
            settings["storage"] = {"requests": {"request_bytes": 1048576, "data_bytes": 1048576}}
            settings["request_timeout_ms"] = 5000
            config.write_text(json.dumps(settings))
            authority = start()
            try:
                direct_table_maintenance.request_pressure(port, root, lambda: authority, accepted_inspections[0])
                stop(authority)
                authority = None
                # Admit this already verified scan with its measured backing
                # requirement. This fixture limit stays below the shipped cap.
                limit = max(1048576, pressure_scan[0][2])
                settings["storage"]["requests"] = {"request_bytes": limit, "data_bytes": limit}
                config.write_text(json.dumps(settings))
                authority = start()
                direct_table_maintenance.response_pressure(port, root, lambda: authority,
                                                           accepted_inspections[0], pressure_scan[0], limit)
            finally:
                stop(authority)
                authority = None
                settings.pop("storage")
                settings["request_timeout_ms"] = 60000
                config.write_text(json.dumps(settings))
                authority = start()
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
            subprocess.run([caller, endpoint, "prepared-lifetime", str(profile)], check=True, timeout=180)
            subprocess.run([caller, endpoint, "count-ranges", str(profile)], check=True, timeout=180)
            subprocess.run([caller, endpoint, "collations", str(profile)], check=True, timeout=180)
            subprocess.run([caller, endpoint, "projection", str(profile)], check=True, timeout=180)
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
            authorization_start = len(fault["commands"])
            subprocess.run([caller, endpoint, "authorization-lifetime", str(profile)], check=True, timeout=180)
            authorization_commands = fault["commands"][authorization_start:]
            # This fixture alone creates an unrelated process to verify denial.
            # Table reads/writes still dispatch no native actor data commands.
            assert authorization_commands.count("spawn") == 1, authorization_commands
            assert set(authorization_commands) <= {"authorization", "spawn"}, authorization_commands
            print(f"Direct Table HTTP: {fault['requests']} typed calls, 64 KiB point row, {len(segments)} initial .tseg object(s), full CRUD/DDL, typed SQL namespace lifecycle with lost-reply recovery and retained reads after namespace retirement, typed SQL predicate UPDATE/DELETE, finite SQL filter/count and retained joins, authorized metadata completion, database-owned SQL snapshot-cache cleanup, conditional SQL name evidence, exact lost-reply recovery, original-caller read delegation without executor Table grants, retained pins across rewrite/drop/recreation and three restarts, uncertain delegated acquisition/closure, saved direct change-reader checkpoints, paused backfill, paired changes, complete no-op/schema transactions, partial-delivery replay and original schemas through DROP/recreation, current revocation and reserved-control rejection passed.")
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

"""Real local Table HTTP owner, public typed caller, reply fault and disk restart."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import hashlib
import json
import os
import signal
from pathlib import Path
import subprocess
import struct
import sys
import threading
import time
import urllib.request

from harness.services import free_port, wait_ready
from runner.capture import identity, provenance
from runner.paths import ROOT
from storage.tables import direct_table_maintenance


def run(node, caller, mode="tables", *artifacts):
    if mode not in ("log-baseline", "tables", "managed", "queues", "kv", "state-transaction", "mixed-transaction", "queue-transfer", "automatic-queue-transfer", "log-token", "workload-token", "workload-result", "maintenance", "stream-maintenance", "growth", "resource-growth", "dependency-growth", "prepared", "count-ranges", "collations", "projection", "authorization", "dependencies", "resources", "callers", "abi", "sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node"):
        raise ValueError("Unknown direct service proof mode")
    assert len(artifacts) == (2 if mode in ("abi", "board", "board-browser", "relational", "relational-python", "relational-node") else 1 if mode in ("sdk-python", "sdk-node", "sdk-ruby", "sdk-java", "sdk-dotnet", "sdk-rust", "sdk-beam", "sdk-c", "board", "board-browser", "relational", "relational-python", "relational-node") else 1 if mode == "log-baseline" else 0)
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
        if request_memory is not None or mode in ("tables", "state-transaction", "mixed-transaction", "queue-transfer", "automatic-queue-transfer", "log-token", "workload-token", "workload-result"):
            settings["request_metrics"] = True
        if mode in ("log-baseline", "resources", "resource-growth", "queues", "mixed-transaction", "queue-transfer", "automatic-queue-transfer", "workload-token", "workload-result"):
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
        kv_caller = None

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
            forced = False
            try:
                child.wait(timeout=15)
            except subprocess.TimeoutExpired:
                forced = True
                child.kill()
                child.wait(timeout=15)
            return dict(requested_signal="SIGTERM", forced_kill=forced, exit_code=child.returncode)

        fault = {"changed": False, "log_admit": False, "log_publish": False, "assertion_changed": False, "namespace_changed": False, "pin_changed": False, "delegated_pin": False, "delegated_release": False, "history_pin": False, "history_release": False, "relational_setup": False, "transaction_records_refused": set(), "transaction_quota_refused": False, "execute": None, "requests": 0, "commands": []}

        dependency_faults = set()
        stream_faults = set()
        queue_faults = set()
        kv_faults = set()
        state_transaction_faults = set()
        log_token_faults = set()
        workload_token_faults = set()
        workload_result_faults = set()
        log_wait_checks = set()
        resource_faults = set()
        abi_faults = set()
        retention_faults = set()
        history_faults = set()
        accepted_inspections = []
        pressure_scan = []
        capture_pressure_scan = False
        board_fault = {"next": None, "accepted": []}
        managed_fault = {"pages_before_failure": None, "failed": False}
        growth_attempts = root / "growth-attempts" if mode == "growth" else None
        if growth_attempts is not None:
            growth_attempts.mkdir(mode=0o700)
        transaction_attempts = root / "transaction-attempts" if mode in ("state-transaction", "mixed-transaction", "queue-transfer", "automatic-queue-transfer", "log-token", "workload-token", "workload-result") else None
        if transaction_attempts is not None:
            transaction_attempts.mkdir(mode=0o700)
        growth_sequence = 0
        growth_lock = threading.Lock()

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                nonlocal growth_sequence
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                record = envelope.get("action", {}).get("record") if isinstance(envelope.get("action"), dict) else None
                if (mode == "managed" and record and "read" in record
                        and record["read"]["format"] == 0xC4465031
                        and managed_fault["pages_before_failure"] is not None):
                    if managed_fault["pages_before_failure"] == 0:
                        managed_fault.update(pages_before_failure=None, failed=True)
                        data = b'{"err":"AuthorityUnavailable"}'
                        self.send_response(503)
                        self.send_header("Content-Type", "application/json")
                        self.send_header("Content-Length", str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                        return
                    managed_fault["pages_before_failure"] -= 1
                attempt = None
                transaction_action = envelope.get("action", {}).get("transaction") if isinstance(envelope.get("action"), dict) else None
                if mode in ("log-token", "workload-token", "workload-result") and isinstance(envelope.get("action"), dict):
                    transaction_action = envelope["action"]
                if (growth_attempts is not None and self.path == "/table/v1"
                        and isinstance(envelope["action"], dict)
                        and set(envelope["action"]) & {"admit_ddl", "admit_rows", "operation", "pin"}):
                    # Save before forwarding: setup can time out after acceptance,
                    # before growth-write returns the final retained profile.
                    # Private artifacts preserve the original signed request and
                    # any reply; neither an absent reply nor timeout is rejection.
                    with growth_lock:
                        growth_sequence += 1
                        attempt = growth_attempts / f"{growth_sequence:04d}"
                        attempt.with_suffix(".request.json").write_bytes(body)
                elif transaction_attempts is not None and self.path == "/table/v1" and transaction_action:
                    # Preserve every original request before forwarding, including
                    # preparation that fails before the caller saves its final plan.
                    with growth_lock:
                        growth_sequence += 1
                        attempt = transaction_attempts / f"{growth_sequence:04d}"
                        attempt.with_suffix(".request.json").write_bytes(body)
                headers = {"Content-Type": "application/json"}
                for name in ("x-transit-control", "x-transit-wait"):
                    if name in self.headers:
                        headers[name] = self.headers[name]
                log_kind = "queue" if mode == "queues" else "stream"
                log_action = envelope.get("action", {}).get(log_kind) if isinstance(envelope.get("action"), dict) else None
                if mode in ("tables", "queues") and log_action and "wait" in log_action:
                    waiting = log_action["wait"]
                    assert headers.get("x-transit-wait") == f'0:{waiting["milliseconds"]}'
                    original = waiting["claim" if mode == "queues" else "consume"]
                    if int(original["operation"]["operation"]) == (633002 if mode == "queues" else 621007):
                        # A signed wait cannot occupy an ordinary lane, and its
                        # scheduling hint cannot disagree with its signed bound.
                        for invalid in ({"Content-Type": "application/json"},
                                        {"Content-Type": "application/json", "x-transit-wait": "0:2"}):
                            probe = HTTPConnection("127.0.0.1", port, timeout=70)
                            try:
                                probe.request("POST", self.path, body, invalid)
                                rejected = probe.getresponse()
                                assert rejected.status == 400, rejected.status
                                assert json.loads(rejected.read()) == {"err": "InvalidRequest"}
                            finally:
                                probe.close()
                        log_wait_checks.add("admission")
                connection = HTTPConnection("127.0.0.1", port, timeout=70)
                try:
                    connection.request("POST", self.path, body, headers)
                    response = connection.getresponse()
                    data = response.read()
                    if attempt is not None:
                        metrics = response.getheader("x-transit-work")
                        attempt.with_suffix(".response.json").write_text(json.dumps({
                            "status": response.status, "body": data.decode("utf-8"),
                            "metrics": json.loads(metrics) if metrics else None}))
                        if transaction_action and response.status >= 400:
                            print(json.dumps({"transaction_refusal": next(iter(transaction_action)),
                                              "status": response.status,
                                              "memory": {name: json.loads(metrics).get(name) for name in ("owner_memory", "request_memory")} if metrics else None}), flush=True)
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
                        if mode == "workload-result" and response.status == 200:
                            mutation = envelope["action"].get("queue", {}).get("mutate")
                            result_request = envelope["action"].get("workload_result", {})
                            phase = None
                            if mutation and mutation["work"].get("claim", {}).get("operation", {}).get("operation") == 647004:
                                if json.loads(data)["result"]["queue"].get("operation") is not None:
                                    phase = "claim"
                            if result_request:
                                result_phase, value = next(iter(result_request.items()))
                                intent = value["intent"] if result_phase == "open" else value["reference"]["intent"]
                                if intent["binding"].get("queue", {}).get("operation", {}).get("operation") == 647004:
                                    phase = result_phase
                            if phase and phase not in workload_result_faults:
                                parsed = json.loads(data)
                                if phase == "claim":
                                    assert parsed["result"]["queue"]["operation"]["claim"]["rows"] == 3
                                elif phase == "open":
                                    assert parsed["result"]["workload_result"]["opened"]["reference"]["selection"]["claim"]["rows"] == 3
                                else:
                                    assert len(parsed["result"]["workload_result"]["page"]["page"]["claim"]["rows"]) == 2
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                workload_result_faults.add(phase)
                        if mode == "workload-token" and response.status == 200:
                            proposed = envelope["action"].get("client_token", {}).get("bind", {}).get("intent", {}).get("workload")
                            mutation = envelope["action"].get("queue", {}).get("mutate")
                            settlement = envelope["action"].get("client_progress", {}).get("update")
                            phase = None
                            if proposed and proposed["binding"].get("queue", {}).get("operation", {}).get("operation") == 644102:
                                phase = "bind"
                            if mutation and mutation["work"].get("claim", {}).get("operation", {}).get("operation") == 644102:
                                if json.loads(data)["result"]["queue"].get("operation") is not None:
                                    phase = "execute"
                            if settlement and settlement["key"]["token"] == [0x58] * 16 and not settlement["pending"]:
                                phase = "settle"
                            if phase and phase not in workload_token_faults:
                                parsed = json.loads(data)
                                if phase == "bind":
                                    assert parsed["result"]["client_token"]["binding"]["intent"]["workload"] == proposed
                                elif phase == "execute":
                                    assert parsed["result"]["queue"]["operation"]["claim"]["claim"] == mutation["work"]["claim"]
                                else:
                                    assert not parsed["result"]["client_progress"]["state"]["pending"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                workload_token_faults.add(phase)
                        if mode == "log-token" and response.status == 200:
                            proposed = envelope["action"].get("client_token", {}).get("bind", {}).get("intent", {}).get("log")
                            admitted = envelope["action"].get("log_admit")
                            phase = "bind" if proposed else "admit" if admitted else None
                            selected = proposed or admitted
                            if selected and selected["binding"]["identity"]["operation"] == 644002 and phase not in log_token_faults:
                                parsed = json.loads(data)
                                if phase == "bind":
                                    assert parsed["result"]["client_token"]["binding"]["intent"]["log"] == proposed
                                else:
                                    assert parsed["result"]["log_admitted"]["phase"] == "admitted"
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                log_token_faults.add(phase)
                        kv = envelope["action"].get("kv", {})
                        transaction = envelope["action"].get("transaction", {})
                        if mode in ("state-transaction", "mixed-transaction", "queue-transfer") and response.status == 200:
                            mixed = mode == "mixed-transaction"
                            transfer = mode == "queue-transfer"
                            statement = transaction.get("log_statement" if mixed or transfer else "statement", {})
                            settlement = transaction.get("settle", {})
                            request = statement.get("request", {})
                            statement_identity = (request.get("work", {}).get("queue_transfer" if transfer else "append", {}).get("operation")
                                                  if mixed or transfer else request.get("binding", {}).get("identity"))
                            identity = (statement_identity
                                        if statement.get("execute") else settlement.get("operation"))
                            selected = 643006 if transfer else 642016 if mixed else 642012
                            decision = 643101 if transfer else 642101
                            if identity and identity["operation"] in (selected, decision) and identity["operation"] not in state_transaction_faults:
                                parsed = json.loads(data)
                                result = parsed["result"]["transaction"]
                                if identity["operation"] == selected:
                                    if transfer:
                                        proposed = result["log_statement"]["provisional"]["proposed"]["queue_transfer"]
                                        assert proposed["offset"] == 0 and proposed["destination"]["interpretation"]["object"]["object"] == 643020
                                    elif mixed:
                                        assert result["log_statement"]["provisional"]["proposed"]["append"]["rows"] == 1
                                    else:
                                        assert result["statement"]["provisional"]["affected"] == 6
                                else:
                                    assert result["status"]["observation"]["decided"]["outcome"] == "committed"
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                state_transaction_faults.add(identity["operation"])
                        if mode == "kv" and response.status == 200:
                            identity = (kv.get("mutate", {}).get("binding", {}).get("identity")
                                        or kv.get("pin", {}).get("owner"))
                            if identity and identity["operation"] in (641001, 641002) and identity["operation"] not in kv_faults:
                                parsed = json.loads(data)
                                result = parsed["result"]["kv"]
                                assert "operation" in result if identity["operation"] == 641001 else "pin" in result
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                kv_faults.add(identity["operation"])
                                if identity["operation"] == 641001:
                                    assert kv_caller is not None and kv_caller.poll() is None
                                    kv_caller.kill()
                                    assert kv_caller.wait(timeout=15) == -signal.SIGKILL
                                    return
                        log_admit = envelope["action"].get("log_admit")
                        queue = envelope["action"].get("queue", {}).get("mutate")
                        queue_wait = envelope["action"].get("queue", {}).get("wait")
                        if queue_wait:
                            queue = {"work": {"claim": queue_wait["claim"]}}
                        if mode == "queues" and queue and response.status == 200:
                            kind, work = next(iter(queue["work"].items()))
                            selected = work["operation"]["operation"]
                            if (selected in (633001, 633002, 633004, 633008) and selected not in queue_faults
                                    and "operation" in json.loads(data)["result"]["queue"]):
                                parsed = json.loads(data)
                                assert kind in parsed["result"]["queue"]["operation"], parsed
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                queue_faults.add(selected)
                        stream = envelope["action"].get("stream", {}).get("mutate")
                        if mode == "tables" and stream and response.status == 200:
                            kind, work = next(iter(stream["work"].items()))
                            identity = work["commit"]["operation"] if kind == "offset" else work["operation"]
                            selected = identity["operation"]
                            if selected in (621001, 621002, 621005, 621006) and selected not in stream_faults:
                                parsed = json.loads(data)
                                assert kind in parsed["result"]["stream"]["operation"], parsed
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                stream_faults.add(selected)
                        log_operation = envelope["action"].get("log_operation")
                        for selected, tag, result, phase in ((log_admit, "log_admit", "log_admitted", "admitted"), (log_operation, "log_publish", "log_operation", "complete")):
                            if (mode == "tables" and selected and selected["binding"]["identity"]["operation"] == 620001
                                    and (tag == "log_admit" or selected["command"] == "execute") and not fault[tag]):
                                assert response.status == 200, data
                                parsed = json.loads(data)
                                accepted = parsed["result"][result]
                                if tag == "log_publish":
                                    accepted = accepted["operation"]
                                assert accepted["phase"] == phase, accepted
                                assert accepted["binding"] == selected["binding"]
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                fault[tag] = True
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
                        historical = envelope["action"].get("historical_catalog")
                        if mode in ("sdk-python", "sdk-node") and historical and any(tag in historical for tag in ("acquire", "release")):
                            tag = "acquire" if "acquire" in historical else "release"
                            assert response.status == 200, data
                            parsed = json.loads(data)
                            status = parsed["result"]["historical_catalog"]["status"]
                            operation = status["receipt"]["binding"]["intent"]["history"]["operation"]
                            key = (operation, tag)
                            if operation in (92000, 92010) and key not in history_faults:
                                assert status["state"]["phase"] == ("acquiring" if tag == "acquire" else "releasing"), status
                                parsed["context"][0] ^= 1
                                data = json.dumps(parsed).encode()
                                history_faults.add(key)
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
            if mode == "log-baseline":
                from performance.storage.log_runtime import exercise
                def baseline_restart():
                    nonlocal authority
                    stopped = stop(authority)
                    authority = None
                    if stopped['forced_kill'] or stopped['exit_code'] not in (0, -15):
                        raise RuntimeError(f"Baseline owner did not stop under its restart profile: {stopped}")
                    authority = start()
                    return stopped
                exercise(node, caller, root, profile, url, artifacts[0],
                         baseline_restart, lambda: authority)
                return
            proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            endpoint = f"http://127.0.0.1:{proxy.server_port}"
            if mode == "automatic-queue-transfer":
                subprocess.run([caller, endpoint, mode + "-prepare", str(profile)], check=True, timeout=180)
                saved_path = Path(str(profile) + "." + mode)
                saved = saved_path.read_bytes()
                database_seed = root / "queue-transfer.seed"
                database_seed.write_text("1d" * 32)
                database_seed.chmod(0o600)
                settings["table"]["queue_transfers"] = {
                    "principal": 101, "seed_file": str(database_seed), "account": [0x51] * 32,
                    "limits": {"resident_bytes": 16 * 1024 * 1024, "workspace_bytes": 1024 * 1024,
                               "participants": 2, "statements": 1, "savepoints": 1},
                    "budget": {"bytes": 16 * 1024},
                }
                settings["maintenance"] = {"principal": 0, "seed_file": str(seed), "interval_ms": 50, "operation_timeout_ms": 2000}
                config.write_text(json.dumps(settings))
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                deadline = time.monotonic() + 180
                restart_observation = None
                original = None
                observations = []
                while True:
                    assert time.monotonic() < deadline, observations
                    result = subprocess.run([caller, endpoint, mode + "-observe", str(profile)],
                                            timeout=min(30, deadline - time.monotonic()), capture_output=True, text=True)
                    with (root / "automatic-transfer-observe.stderr").open("a") as output:
                        output.write(result.stderr)
                    assert result.returncode == 0, result.stderr[-12000:]
                    observed = json.loads(result.stdout)
                    observations.append(observed)
                    with (root / "automatic-transfer-observations.jsonl").open("a") as output:
                        output.write(json.dumps(observed) + "\n")
                    assert saved_path.read_bytes() == saved
                    if observed["observed"]:
                        receipt = Path(str(saved_path) + ".receipt").read_bytes()
                        if original is None:
                            original = receipt
                        assert receipt == original
                        if restart_observation is None:
                            # Record the phase actually observed; process death
                            # here does not claim an unobserved append boundary.
                            restart_observation = observed
                            authority.kill()
                            authority.wait(timeout=15)
                            authority = start()
                            continue
                        if observed["committed"] and observed["cleanup_complete"] and not observed["pending"]:
                            break
                    time.sleep(.1)
                subprocess.run([caller, endpoint, mode + "-verify", str(profile)], check=True, timeout=180)
                destination_claim = Path(str(saved_path) + ".destination-claim").read_bytes()
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, mode + "-reopen", str(profile)], check=True, timeout=180)
                assert Path(str(saved_path) + ".receipt").read_bytes() == original
                assert Path(str(saved_path) + ".destination-claim").read_bytes() == destination_claim
                assert saved_path.read_bytes() == saved
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(json.dumps(dict(profile="automatic_queue_transfer", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)],
                                      original_receipt_sha256=hashlib.sha256(original).hexdigest(),
                                      destination_claim_sha256=hashlib.sha256(destination_claim).hexdigest(),
                                      limits=settings["table"]["queue_transfers"]["limits"],
                                      maintenance=settings["maintenance"] | {"seed_file": "private"},
                                      restart_observation=restart_observation, observations=observations, passed=True)), flush=True)
                print("Automatic Queue transfer HTTP: explicitly authorized maintenance, one original transaction, source archival and destination payload, SIGKILL/restarts and unchanged original receipts passed.", flush=True)
                return
            if mode == "workload-result":
                saved = None
                positions = None
                for phase in ("prepare", "open", "verify"):
                    subprocess.run([caller, endpoint, "workload-result-" + phase, str(profile)], check=True, timeout=180)
                    current = Path(str(profile) + ".workload-result").read_bytes()
                    if saved is None:
                        saved = current
                    assert current == saved
                    assert workload_result_faults == ({"claim"} if phase == "prepare" else {"claim", "open", "page"})
                    if phase == "open":
                        positions = Path(str(profile) + ".workload-result.positions").read_bytes()
                    if phase != "verify":
                        authority.kill()
                        authority.wait(timeout=15)
                        authority = start()
                    if phase == "open":
                        # The original 1-s leases and configured 10-s clock error
                        # have elapsed before verification. The caller checks the
                        # owner's trusted expired observation, not elapsed wall time.
                        time.sleep(32)
                assert Path(str(profile) + ".workload-result.positions").read_bytes() == positions
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(json.dumps(dict(profile="direct_workload_results", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)], requests=fault["requests"],
                                      lost_replies=sorted(workload_result_faults), replay_prefix_per_partition=257,
                                      original_bindings_sha256=hashlib.sha256(saved).hexdigest(),
                                      positions_sha256=hashlib.sha256(positions).hexdigest(), passed=True)))
                print("Workload results: original payloads, finite consumption and expired claims, saved positions and complete empty results, lost replies and SIGKILL/restarts passed.")
                return
            if mode == "workload-token":
                saved = None
                for phase in ("prepare", "execute", "settle", "verify"):
                    subprocess.run([caller, endpoint, "workload-token-" + phase, str(profile)], check=True, timeout=180)
                    current = Path(str(profile) + ".workload-token").read_bytes()
                    if saved is None:
                        saved = current
                    assert current == saved
                    expected = {"bind"} if phase == "prepare" else {"bind", "execute"} if phase == "execute" else {"bind", "execute", "settle"}
                    assert workload_token_faults == expected
                    if phase != "verify":
                        authority.kill()
                        authority.wait(timeout=15)
                        authority = start()
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(json.dumps(dict(profile="direct_workload_tokens", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)], requests=fault["requests"],
                                      lost_replies=sorted(workload_token_faults), replay_prefix_per_partition=257,
                                      original_bindings_sha256=hashlib.sha256(saved).hexdigest(), passed=True)))
                print("Stream/Queue workload tokens: original saved bindings, three lost replies and SIGKILL/restarts, bounded cold owner recovery and terminal settlement passed.")
                return
            if mode == "log-token":
                saved = None
                for phase in ("prepare", "recover", "verify"):
                    subprocess.run([caller, endpoint, "log-token-" + phase, str(profile)], check=True, timeout=180)
                    current = Path(str(profile) + ".log-token").read_bytes()
                    if saved is None:
                        saved = current
                    assert current == saved
                    assert log_token_faults == ({"bind"} if phase == "prepare" else {"bind", "admit"})
                    if phase != "verify":
                        authority.kill()
                        authority.wait(timeout=15)
                        authority = start()
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(json.dumps(dict(profile="direct_log_declaration_tokens", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)], requests=fault["requests"],
                                      lost_replies=sorted(log_token_faults), passed=True)))
                print("Stream/Queue declaration tokens: original immutable bodies, token and admission recovery, two SIGKILL/restarts, complete partition publication and terminal settlement passed.")
                return
            if mode in ("state-transaction", "mixed-transaction", "queue-transfer"):
                mixed = mode == "mixed-transaction"
                transfer = mode == "queue-transfer"
                lost_statement = 643006 if transfer else 642016 if mixed else 642012
                decision = 643101 if transfer else 642101
                subprocess.run([caller, endpoint, mode + "-prepare", str(profile)], check=True, timeout=180)
                saved_path = Path(str(profile) + "." + mode)
                saved = saved_path.read_bytes()
                assert state_transaction_faults == {lost_statement}
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, mode + "-recover", str(profile)], check=True, timeout=180)
                assert state_transaction_faults == {lost_statement, decision}
                assert saved_path.read_bytes() == saved
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, mode + "-verify", str(profile)], check=True, timeout=180)
                assert saved_path.read_bytes() == saved
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(json.dumps(dict(profile="direct_queue_terminal_transaction" if transfer else "direct_table_kv_log_transaction" if mixed else "direct_table_kv_transaction", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)], requests=fault["requests"],
                                      lost_replies=sorted(state_transaction_faults), passed=True)))
                if transfer:
                    print("Queue transfer HTTP: paired source archive and destination append recovered after two lost replies and SIGKILL/restarts; original identities, payload and FIFO successor passed.")
                else:
                    print(("Table/KV/Stream/Queue" if mixed else "Table/KV") + " transaction HTTP: original private statements and common decision recovered after two lost replies and SIGKILL/restarts, private KV read, public visibility and unchanged saved identities passed.")
                return
            if mode == "kv":
                kv_caller = subprocess.Popen([caller, endpoint, "kv-prepare", str(profile)])
                assert kv_caller.wait(timeout=180) == -signal.SIGKILL
                saved = Path(str(profile) + ".kv").read_bytes()
                records = list(Path(str(profile) + ".kv.recovery").glob("*.rec"))
                assert len(records) == 1
                record = records[0].read_bytes()
                assert record[:4] == b"TCR1" and struct.unpack_from("<Q", record, 68)[0] == 1
                original_size, evidence_size = struct.unpack_from("<II", record, 76)
                assert evidence_size == 0 and original_size == len(saved) and record[116:] == saved
                assert record[84:116] == hashlib.sha256(record[:84] + record[116:]).digest()
                original = json.loads(saved)
                operation = original["mutation"]["binding"]["identity"]
                scope = operation["scope"]
                key = hashlib.sha256(b"transit.kv.mutation.v1\x00" + bytes.fromhex(original["definition"])
                                     + struct.pack("<5Q", scope["realm"], scope["resource"], scope["catalog"], operation["principal"], operation["operation"])).hexdigest()
                assert records[0].name == key + ".rec"
                # The replacement must use the recovery store, not this old
                # fixture's standalone saved-work file.
                Path(str(profile) + ".kv").unlink()
                assert kv_faults == {641001}
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, "kv-recover", str(profile)], check=True, timeout=180)
                pin_saved = Path(str(profile) + ".kv.pin").read_bytes()
                assert kv_faults == {641001, 641002}
                recovered = records[0].read_bytes()
                assert struct.unpack_from("<Q", recovered, 68)[0] == 2
                assert recovered[116:116 + original_size] == saved
                receipt = json.loads(recovered[116 + original_size:])
                assert receipt["binding"] == json.loads(saved)["mutation"]["binding"]
                assert receipt["outcome"]["affected"] == 8
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, "kv-verify", str(profile)], check=True, timeout=180)
                assert records[0].read_bytes() == recovered
                assert Path(str(profile) + ".kv.pin").read_bytes() == pin_saved
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                print(json.dumps(dict(profile="direct_kv_original_recovery", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)],
                                      requests=fault["requests"], lost_replies=sorted(kv_faults),
                                      caller_sigkill_before_reply=True, recovery_store_original_unchanged=True,
                                      passed=True)), flush=True)
                print("Direct KV HTTP: pre-send store refusal, caller SIGKILL before accepted reply, store-only original mutation and receipt recovery, pin recovery after lost reply and node SIGKILL/restarts, retained reads after replacement and DROP, current read denial, rename and explicit pin release passed.", flush=True)
                return
            if mode == "managed":
                subprocess.run([caller, endpoint, "managed-prepare", str(profile)], check=True, timeout=600)
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, "managed-recover", str(profile)], check=True, timeout=600)
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, "managed-verify", str(profile)], check=True, timeout=600)
                managed_fault["pages_before_failure"] = 1
                subprocess.run([caller, endpoint, "managed-prefix", str(profile)], check=True, timeout=180)
                assert managed_fault["failed"], managed_fault
                print("Managed Table: original recovery, atomic output, retained nonempty/empty revisions after replacement and output edits, bounded reads, early close, incomplete prefix and current source/output/control denial passed.", flush=True)
                return
            if mode == "queues":
                subprocess.run([caller, endpoint, "queue-prepare", str(profile)], check=True, timeout=180)
                saved = Path(str(profile) + ".queue").read_bytes()
                assert queue_faults == {633001, 633002, 633004}
                authority.kill()
                authority.wait(timeout=15)
                authority = None
                authority = start()
                subprocess.run([caller, endpoint, "queue-recover", str(profile)], check=True, timeout=180)
                assert Path(str(profile) + ".queue").read_bytes() == saved
                settings["maintenance"] = {"principal": 0, "seed_file": str(seed), "interval_ms": 50, "operation_timeout_ms": 2000}
                settings["storage"] = {"maintenance": {"flush": {"enabled": False}, "archive": {"enabled": False}}}
                config.write_text(json.dumps(settings))
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                deadline = time.monotonic() + 90  # Accepted 60-second leases plus clock bounds and bounded work.
                probes = 0
                def queue_observation():
                    result = subprocess.run([caller, endpoint, "queue-maintenance", str(profile)],
                                            timeout=30, capture_output=True, text=True)
                    with (root / "queue-maintenance.stderr").open("a") as output:
                        output.write(result.stderr)
                    assert result.returncode == 0, result.stderr[-12000:]
                    observed = json.loads(result.stdout)
                    with (root / "queue-maintenance-observations.jsonl").open("a") as output:
                        output.write(json.dumps(observed) + "\n")
                    return observed
                while True:
                    observed = queue_observation()
                    probes += 1
                    if observed["expired"]:
                        break
                    assert time.monotonic() < deadline, observed
                    time.sleep(1)
                assert not list((root / "native").rglob("*.tseg")), "Disabled flushing sealed Queue payloads"
                # Expiry has now recorded the retired definition in the Queue
                # root. Physical relocation must remain possible in this order.
                settings["storage"]["maintenance"]["flush"]["enabled"] = True
                settings["storage"]["maintenance"]["archive"]["enabled"] = True
                config.write_text(json.dumps(settings))
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                deadline = time.monotonic() + 60
                while True:
                    assert queue_observation()["expired"]
                    segments = list((root / "native").rglob("*.tseg"))
                    if segments:
                        break
                    assert time.monotonic() < deadline, "Retired Queue payload sealing did not converge"
                    time.sleep(.1)
                assert len(segments) == 1, segments
                segment = segments[0].read_bytes()
                assert segment[:8] == b"TSEG\x01\0\0\0" and segment[-4:] == b"TSEG"
                assert struct.unpack_from("<Q", segment, 16)[0] == 633000
                assert struct.unpack_from("<I", segment, 32)[0] == 3
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                assert queue_observation()["expired"]
                subprocess.run([caller, endpoint, "queue-recover", str(profile)], check=True, timeout=180)
                assert Path(str(profile) + ".queue").read_bytes() == saved
                subprocess.run([caller, endpoint, "queue-release", str(profile)], check=True, timeout=180)
                release_saved = Path(str(profile) + ".queue.release").read_bytes()
                assert queue_faults == {633001, 633002, 633004, 633008}
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                subprocess.run([caller, endpoint, "queue-release-recover", str(profile)], check=True, timeout=180)
                assert Path(str(profile) + ".queue.release").read_bytes() == release_saved
                subprocess.run([caller, endpoint, "queue-terminal-prepare", str(profile)], check=True, timeout=180)
                def terminal_observation():
                    result = subprocess.run([caller, endpoint, "queue-terminal-observe", str(profile)],
                                            timeout=30, capture_output=True, text=True)
                    assert result.returncode == 0, result.stderr[-12000:]
                    return json.loads(result.stdout)["ready"]
                deadline = time.monotonic() + 30
                while not terminal_observation():
                    assert time.monotonic() < deadline, "Trusted retention age was not observed"
                    time.sleep(.1)
                subprocess.run([caller, endpoint, "queue-terminal-ack", str(profile)], check=True, timeout=180)
                terminal_saved = Path(str(profile) + ".terminal").read_bytes()
                deadline = time.monotonic() + 60
                while not terminal_observation():
                    assert time.monotonic() < deadline, "Terminal Queue retention did not converge"
                    time.sleep(.1)
                authority.kill()
                authority.wait(timeout=15)
                authority = start()
                assert terminal_observation(), "Restart lost terminal expiry or original claim payload"
                assert Path(str(profile) + ".terminal").read_bytes() == terminal_saved
                assert set(fault["commands"]) <= {"authorization"}, fault["commands"]
                assert log_wait_checks == {"admission"}
                print(json.dumps(dict(profile="queue_original_recovery", source=provenance(ROOT),
                                      binaries=[identity(Path(path)) for path in (node, caller)],
                                      requests=fault["requests"], lost_replies=sorted(queue_faults), expiry_probes=probes,
                                      passed=True)), flush=True)
                print("Direct Queue HTTP: FIFO heads, wait admission/timeout, original empty claims, four lost replies including wait acceptance, ACK, automatic retired-lease expiry, retained payloads through tiering, explicit read closure and terminal retention across node SIGKILL/restarts passed.", flush=True)
                return
            if mode in ("maintenance", "stream-maintenance"):
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
                if mode == "stream-maintenance":
                    direct_table_maintenance.exercise_streams(caller, endpoint, profile, root, restart,
                                                             lambda: authority, node)
                    return
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
                if mode in ("sdk-python", "sdk-node"):
                    assert history_faults == {(operation, tag) for operation in ((92000,) if mode == "sdk-node" else (92000, 92010)) for tag in ("acquire", "release")}, history_faults
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
                print(f"Named resources: {fault['requests']} typed catalog calls, 8 withheld stage replies, 4 withheld dependency replies and 11 abrupt node replacements, unchanged saved declarations and dependency bindings, serialized original caller allocation without data grants, actual Station Document initialization and publication, current data revocation, both graph directions, DROP RESTRICT and explicit original-edge cleanup passed.")
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
            assert fault["log_admit"] and fault["log_publish"]
            assert stream_faults == {621001, 621002, 621005, 621006}
            assert log_wait_checks == {"admission"}
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
            if kv_caller is not None and kv_caller.poll() is None:
                kv_caller.kill()
                kv_caller.wait(timeout=15)
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
    # The ordinary direct-service gate includes the Queue schedule with a
    # separate physical directory and clock policy. Focused modes stay focused.
    if len(sys.argv) == 3 or sys.argv[3] == "tables":
        run(sys.argv[1], sys.argv[2], "queues")

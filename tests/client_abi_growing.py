"""The shared raw ABI must retain v3 identities, uncertainty and exact retry."""
import ctypes as c
import hashlib
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

from inspection import System
from storage import free_port, wait_ready


class GrowingSystem(System):
    resident_pages = 1
    def __enter__(self):
        self.store.__enter__()
        try:
            self.root = self.store.root
            self.seed, public = self.key("root")
            self.port = free_port()
            self.url = f"http://127.0.0.1:{self.port}"
            self.config = self.root / "node.json"
            self.config.write_text(json.dumps({
                "profile": "native_v1", "genesis": {"realm": 72, "root_key": public, "max_clock_error_ms": 10000},
                "ursula_url": self.store.url, "bucket": "growing-abi", "journal": "authority",
                "port": self.port, "resident_pages": self.resident_pages, "request_timeout_ms": 5000,
            }))
            initialized = self.start(self.node, self.config, "--initialize")
            assert initialized.wait(timeout=20) == 0
            self.authority = self.start(self.node, self.config)
            wait_ready(self.store.http, self.authority, self.url + "/health")
            return self
        except BaseException:
            self.__exit__(*sys.exc_info())
            raise


def vectors(native):
    fixture = json.loads((Path(__file__).parent / "verification/sdk-operations-v1.json").read_text())
    assert native.lib.transit_client_abi_version() == fixture["abi_version"]
    assert native.lib.transit_client_supports_kind(0) == 0
    assert native.lib.transit_client_supports_kind(0xffffffff) == 0
    seed = bytes.fromhex(fixture["seed_hex"])
    for case in fixture["cases"]:
        assert native.lib.transit_client_supports_kind(case["kind"]) == 1
        document = json.loads(case["canonical"])
        operation = native.prepare(case["kind"], seed, document)
        try:
            exported = native.export(operation)
            frozen = json.loads(exported)
            metadata = c.c_void_p()
            assert native.lib.transit_operation_metadata(operation, c.byref(metadata)) == 0
            info = json.loads(native.take(metadata))
            assert info["identity"] == hashlib.sha256(exported).hexdigest()
            assert info["kind"] == case["tag"] and info["profile"] == "native_v1"
            assert (info["realm"], info["principal"]) == (document["realm"], document["principal"])
            if case["kind"] == 6:
                assert info["command"] == "send" and info["sequence"] == str(document["sequence"])
                assert info["destination"] == document["command"]["send"]["pid"]
            else:
                assert info["sequence"] is info["command"] is info["destination"] is None
            assert frozen["version"] == 1
            signed = frozen["operation"][case["tag"]]
            assert json.dumps(signed[case["body"]], separators=(",", ":")) == case["canonical"]
            assert signed["signature"] == case["signature"]
            assert hashlib.sha256((case["domain"] + case["canonical"]).encode()).hexdigest() == case["sha256"]
            restored = native.restore(exported)
            try:
                assert native.export(restored) == exported
            finally:
                native.lib.transit_operation_destroy(restored)
            # The profile and canonical identity cannot be reinterpreted during
            # restore, and a public ID cannot be narrowed to a legacy slot.
            for invalid_document in (dict(document, version=2), dict(document, principal=2**53)):
                invalid = c.c_void_p()
                raw = json.dumps(invalid_document).encode()
                assert native.lib.transit_operation_prepare(case["kind"], seed, raw, len(raw), c.byref(invalid)) == 1
                assert not invalid.value
            for raw, status in ((b" " + exported, 1), (exported.replace(b'"version":1', b'"version":2', 1), 10)):
                invalid = c.c_void_p()
                assert native.lib.transit_operation_import(raw, len(raw), c.byref(invalid)) == status
                assert not invalid.value
        finally:
            native.lib.transit_operation_destroy(operation)


def run(native, library, node, cli):
    vectors(native)
    with GrowingSystem(node, cli) as system:
        root_seed = bytes.fromhex(system.seed.read_text().strip())
        worker_key, public = system.key("wide-worker")
        worker_seed = bytes.fromhex(worker_key.read_text().strip())
        root_client = native.client(system.url)
        fault = {"drop": True, "invalid_receipt": False, "invalid_read": False, "bodies": [], "paths": []}

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                fault["paths"].append(self.path)
                connection = HTTPConnection("127.0.0.1", system.port, timeout=10)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == "/v1/command":
                        fault["bodies"].append(body)
                        if response.status == 200 and fault["drop"]:
                            fault["drop"] = False
                            self.close_connection = True
                            return
                        if response.status == 200 and fault["invalid_receipt"]:
                            fault["invalid_receipt"] = False
                            data = b'{"position":0}'
                    elif self.path == "/v1/query" and response.status == 200 and fault["invalid_read"]:
                        fault["invalid_read"] = False
                        value = json.loads(data)
                        value["realm"] += 1
                        data = json.dumps(value).encode()
                    self.send_response(response.status)
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f"http://127.0.0.1:{proxy.server_port}"
        client = native.client(url)
        operations = []

        def prepare(kind, seed, document):
            operation = native.prepare(kind, seed, document)
            operations.append(operation)
            return operation

        def root(command):
            system.sequence += 1
            operation = prepare(6, root_seed, {"version": 1, "realm": 72, "principal": 0,
                "sequence": system.sequence, "command": command})
            return native.call(root_client, operation)

        try:
            root({"grant": {"subject": 65536, "public_key": public, "permissions": 255}})
            spawn = prepare(6, worker_seed, {"version": 1, "realm": 72, "principal": 65536,
                "sequence": 1, "command": {"spawn": {}}})
            saved = system.root / "pending.json"
            saved.write_bytes(native.export(spawn))
            saved.chmod(0o600)
            uncertain_status = native.exchange(client, spawn)[0]
            assert uncertain_status == 6
            assert not fault["drop"] and len(fault["bodies"]) == 1
            native.lib.transit_operation_destroy(spawn)
            operations.remove(spawn)

            system.authority.kill()
            system.authority.wait(timeout=10)
            system.store.stop()
            system.store.start()
            system.authority = system.start(node, system.config)
            wait_ready(system.store.http, system.authority, system.url + "/health")
            # Fresh process, no seed or native handles: only persisted retry bytes.
            receipt = json.loads(subprocess.check_output([sys.executable, "-B",
                str(Path(__file__).with_name("client_abi.py")), "--retry", library, url, str(saved)], timeout=15))
            pid = receipt["position"]
            assert pid == 2 and fault["bodies"][0] == fault["bodies"][1]
            assert len(fault["bodies"]) == 2

            query = prepare(7, worker_seed, {"version": 1, "realm": 72, "principal": 65536,
                "kind": {"process": pid}})
            result = native.call(client, query)
            assert result["version"] == 1 and result["principal_sequence"] == 1
            assert result["body"]["process"]["process"]["pid"] == pid
            fault["invalid_read"] = True
            invalid_read_status = native.exchange(client, query)[0]
            assert invalid_read_status == 8
            assert not fault["invalid_read"]

            send = prepare(6, worker_seed, {"version": 1, "realm": 72, "principal": 65536,
                "sequence": 2, "command": {"send": {"pid": pid, "value": "00ff"}}})
            fault["invalid_receipt"] = True
            invalid_receipt_status = native.exchange(client, send)[0]
            assert invalid_receipt_status == 6
            assert not fault["invalid_receipt"]
            assert native.call(client, send)["position"] == 3
            result = native.call(client, query)
            assert result["body"]["process"]["process"]["admitted"] == 1
            assert result["body"]["process"]["input"]["value"] == "00ff"
            assert result["body"]["process"]["input"]["origin"]["external"]["principal"] == 65536
            root({"revoke": 65536})
            revoked_read_status = native.exchange(client, query)[0]
            revoked_retry_status = native.exchange(client, send)[0]
            assert revoked_read_status == revoked_retry_status == 4
            assert set(fault["paths"]) == {"/v1/command", "/v1/query"}
            from sdk_scenarios import check
            check("growing-profile-abi", {
                "protocol_version": result["version"],
                "authenticated_principal": result["body"]["process"]["input"]["origin"]["external"]["principal"],
                "identical_retry": fault["bodies"][0] == fault["bodies"][1],
                "uncertain_status": uncertain_status,
                "invalid_receipt_status": invalid_receipt_status,
                "invalid_read_status": invalid_read_status,
                "admitted_inputs": result["body"]["process"]["process"]["admitted"],
                "revoked_read_status": revoked_read_status,
                "revoked_retry_status": revoked_retry_status,
            })
        finally:
            for operation in operations:
                native.lib.transit_operation_destroy(operation)
            native.lib.transit_client_destroy(client)
            native.lib.transit_client_destroy(root_client)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
    print("Growing C ABI: wide identities, canonical recovery, disk/host restart, lost/invalid replies and revoked retry passed.")

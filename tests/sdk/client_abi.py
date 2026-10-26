"""Exercise the shared C boundary against real authority and disk storage."""
from runner.paths import ROOT
import ctypes as c
from concurrent.futures import ThreadPoolExecutor
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading

from inspection import System


class Native:
    def __init__(self, library):
        self.lib = c.CDLL(library)
        contract = json.loads((ROOT / "packages/zig/transit-client/abi-v1.json").read_text())
        def ctype(name):
            if name == "void":
                return None
            if name == "uint32_t":
                return c.c_uint32
            if name == "size_t":
                return c.c_size_t
            if name.endswith("**"):
                return c.POINTER(c.c_void_p)
            if name == "const uint8_t *":
                return c.c_void_p
            if name.endswith("*"):
                return c.c_void_p
            raise AssertionError(name)
        for function in contract["functions"]:
            fn = getattr(self.lib, function["name"])
            fn.argtypes = [ctype(value) for value in function["parameters"]]
            fn.restype = ctype(function["result"])

        definition = contract["definition"].encode()
        assert self.lib.transit_client_abi_definition_matches(definition, len(definition)) == 1
        for incompatible in (b"", b"previous-v1-definition", definition[:-1]):
            assert self.lib.transit_client_abi_definition_matches(incompatible, len(incompatible)) == 0

    def take(self, buffer):
        if not buffer.value:
            return None
        try:
            return c.string_at(self.lib.transit_buffer_data(buffer), self.lib.transit_buffer_size(buffer))
        finally:
            self.lib.transit_buffer_destroy(buffer)

    def client(self, url, timeout_ms=1000):
        result = c.c_void_p()
        data = url.encode()
        assert self.lib.transit_client_create(1, data, len(data), timeout_ms, c.byref(result)) == 0
        return result

    def prepare(self, kind, seed, request):
        result = c.c_void_p()
        raw = json.dumps(request).encode()
        assert self.lib.transit_operation_prepare(kind, seed, raw, len(raw), c.byref(result)) == 0
        return result

    def export(self, operation):
        result = c.c_void_p()
        assert self.lib.transit_operation_export(operation, c.byref(result)) == 0
        return self.take(result)

    def restore(self, data):
        result = c.c_void_p()
        assert self.lib.transit_operation_import(data, len(data), c.byref(result)) == 0
        return result

    def call(self, client, operation, status=0):
        actual, data = self.exchange(client, operation)
        assert actual == status, (actual, data)
        return data

    def exchange(self, client, operation):
        result = c.c_void_p()
        actual = self.lib.transit_client_call(client, operation, c.byref(result))
        data = self.take(result)
        return actual, json.loads(data) if data else None


def contention(native, node, cli):
    """Independent handles share authority sequencing, never a host mutex."""
    with System(node, cli) as system:
        seed = bytes.fromhex(system.seed.read_text().strip())
        pid = system.command({"spawn": {}})
        receiver = system.command({"spawn": {}})
        clients = [native.client(system.url) for _ in range(2)]
        try:
            def race(values):
                operations = []
                try:
                    for value in values:
                        operations.append(native.prepare(6, seed, {"realm": 72, "principal": 0,
                            "sequence": system.sequence + 1,
                            "command": {"send": {"pid": pid, "value": value.hex()}}}))
                    barrier = threading.Barrier(2)
                    def submit(index):
                        barrier.wait(timeout=5)
                        return native.exchange(clients[index], operations[index])
                    with ThreadPoolExecutor(max_workers=2) as pool:
                        futures = [pool.submit(submit, index) for index in range(2)]
                        results = [future.result(timeout=10) for future in futures]
                    # Reconcile each frozen operation through the other handle.
                    # No participant may recover a conflict by renumbering it.
                    for index, operation in enumerate(operations):
                        assert native.exchange(clients[1-index], operation) == results[index]
                    system.sequence += 1
                    return results
                finally:
                    for operation in operations:
                        native.lib.transit_operation_destroy(operation)

            results = race([b"first", b"second"])
            assert sorted(status for status, _ in results) == [0, 3], results
            winner = next(i for i, (status, _) in enumerate(results) if status == 0)
            assert results[1-winner][1]["err"] == "ConflictingRetry"
            view = system.native_query({"process": pid})["body"]["process"]
            assert view["process"]["admitted"] == 1 and view["process"]["consumed"] == 0
            assert view["input"]["value"] == [b"first", b"second"][winner].hex()
            assert system.native_query({"process": receiver})["body"]["process"]["input"] is None
            duplicate = race([b"duplicate", b"duplicate"])
            assert duplicate[0][0] == 0 and duplicate[0] == duplicate[1]
            after = system.native_query({"process": pid})["body"]["process"]
            from sdk.sdk_scenarios import check
            check("same-principal-handles", {
                "conflicting_winners": sum(status == 0 for status, _ in results),
                "duplicate_receipts_equal": duplicate[0] == duplicate[1],
                "admitted_inputs": after["process"]["admitted"],
                "consumed_inputs": after["process"]["consumed"],
            })

            # Admission, source commitment, destination admission and destination
            # consumption are four separately observable durable boundaries.
            system.command({"own": {"pid": pid, "worker": 0, "expected_generation": 0}})
            current = system.native_query({"process": pid})["body"]["process"]
            system.command({"turn": {"pid": pid, "generation": current["process"]["generation"],
                "input": view["input"]["position"], "expected_revision": current["process"]["revision"],
                "outputs": [{"pid": receiver, "value": b"reply".hex()}, None, None, None]}})
            committed = system.native_query({"process": pid})["body"]["process"]
            before_delivery = system.native_query({"process": receiver})["body"]["process"]
            output = system.inspect("outbox", pid)["outbox"][0]
            system.command({"deliver": output["id"]})
            delivered = system.native_query({"process": receiver})["body"]["process"]
            system.command({"own": {"pid": receiver, "worker": 0, "expected_generation": 0}})
            system.command({"turn": {"pid": receiver, "generation": 1,
                "input": delivered["input"]["position"], "expected_revision": delivered["process"]["revision"]}})
            completed = system.native_query({"process": receiver})["body"]["process"]
            check("admission-commit-reply", {
                "consumed_after_admission": view["process"]["consumed"],
                "consumed_after_commit": committed["process"]["consumed"],
                "reply_admitted_before_delivery": before_delivery["process"]["admitted"],
                "reply_consumed_after_delivery": delivered["process"]["consumed"],
                "reply_consumed_after_handler": completed["process"]["consumed"],
                "reply_value_preserved": delivered["input"]["value"] == b"reply".hex(),
            })
        finally:
            for client in clients:
                native.lib.transit_client_destroy(client)


def retry(library, url, path):
    native = Native(library)
    client = native.client(url)
    operation = native.restore(Path(path).read_bytes())
    try:
        print(json.dumps(native.call(client, operation)))
    finally:
        native.lib.transit_operation_destroy(operation)
        native.lib.transit_client_destroy(client)


def run(library, node, cli, c_proof):
    subprocess.run([c_proof], check=True, timeout=10)
    native = Native(library)
    from sdk.client_abi_growing import run as growing
    growing(native, library, node, cli)
    contention(native, node, cli)
    with System(node, cli) as system:
        seed = bytes.fromhex(system.seed.read_text().strip())
        bodies = []
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                bodies.append(body)
                connection = HTTPConnection("127.0.0.1", system.port, timeout=5)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if len(bodies) == 1:
                        self.close_connection = True
                        return
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
        operation = None
        try:
            request = {"realm": 72, "principal": 0, "sequence": 1, "command": {"spawn": {}}}
            operation = native.prepare(6, seed, request)
            exported = native.export(operation)
            expected_command = system.signed(request["command"], 1) | {"blocks": None}
            assert json.loads(exported)["operation"]["growing_command"] == expected_command
            saved = system.root / "pending.json"
            saved.write_bytes(exported)
            saved.chmod(0o600)
            uncertain, _ = native.exchange(client, operation)  # Commit happened; receipt lost.
            assert uncertain == 6
            native.lib.transit_operation_destroy(operation)
            operation = None
            # A fresh host has no native handles or seed, only exact signed retry
            # material. Current authority still controls receipt disclosure.
            result = json.loads(subprocess.check_output([sys.executable, "-B", str(ROOT / "tests/runner/launch.py"), __file__, "--retry", library, url, str(saved)], timeout=15))
            assert len(bodies) == 2 and bodies[0] == bodies[1]
            assert result["position"] == 1
            from sdk.sdk_scenarios import check
            check("host-loss-retry", {"uncertain_status": uncertain,
                "wire_bytes_equal": bodies[0] == bodies[1], "receipt_position": result["position"]})
            system.sequence = 1
            operation = native.restore(exported)
            assert native.export(operation) == exported
            assert native.call(client, operation) == result
            native.lib.transit_operation_destroy(operation)
            operation = native.prepare(7, seed, {"realm": 72, "principal": 0, "kind": {"process": 1}})
            assert native.call(client, operation)["body"]["process"]["process"]["pid"] == 1
            native.lib.transit_operation_destroy(operation)
            operation = native.prepare(7, seed, {"realm": 72, "principal": 0, "kind": {"capabilities": {}}})
            assert native.call(client, operation)["body"]["capabilities"]["page_entries"] == 8
            worker_seed, public = system.key("reader")
            system.command({"grant": {"subject": 1, "public_key": public, "permissions": 16, "pid": 1}})
            native.lib.transit_operation_destroy(operation)
            operation = None
            operation = native.prepare(7, bytes.fromhex(worker_seed.read_text().strip()), {
                "realm": 72, "principal": 1, "kind": {"process": 1},
            })
            assert native.call(client, operation)["body"]["process"]["process"]["pid"] == 1
            system.command({"grant": {"subject": 1, "public_key": public, "permissions": 0, "pid": 1}})
            denied = native.call(client, operation, status=4)
            assert denied["err"] in ("Forbidden", "AccessDenied")
            invalid = c.c_void_p()
            other_version = exported.replace(b'"version":1', b'"version":99', 1)
            assert native.lib.transit_operation_import(other_version, len(other_version), c.byref(invalid)) == 10
            assert not invalid.value
            noncanonical = b" " + exported
            assert native.lib.transit_operation_import(noncanonical, len(noncanonical), c.byref(invalid)) == 1
            assert not invalid.value
            # Integer narrowing, duplicate JSON fields and unknown tags fail
            # before an operation is created or a network request is made.
            for raw in [b'{"realm":18446744073709551616}', b'{"realm":72,"realm":73}', b'{"command":{"unknown":{}}}']:
                invalid = c.c_void_p()
                assert native.lib.transit_operation_prepare(6, seed, raw, len(raw), c.byref(invalid)) == 1
                assert not invalid.value
            print("C ABI: generated header, canonical signatures, host-loss retry, revocation and malformed-input rejection passed.")
        finally:
            native.lib.transit_operation_destroy(operation)
            native.lib.transit_client_destroy(client)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    if sys.argv[1] == "--retry":
        retry(*sys.argv[2:])
    else:
        run(*sys.argv[1:])

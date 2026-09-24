"""Exercise the shared C boundary against real authority and disk storage."""
import ctypes as c
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
        contract = json.loads((Path(__file__).resolve().parents[1] / "packages/zig/transit-client/abi-v1.json").read_text())
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

    def take(self, buffer):
        if not buffer.value:
            return None
        try:
            return c.string_at(self.lib.transit_buffer_data(buffer), self.lib.transit_buffer_size(buffer))
        finally:
            self.lib.transit_buffer_destroy(buffer)

    def client(self, url):
        result = c.c_void_p()
        data = url.encode()
        assert self.lib.transit_client_create(1, data, len(data), 1000, c.byref(result)) == 0
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
        result = c.c_void_p()
        actual = self.lib.transit_client_call(client, operation, c.byref(result))
        data = self.take(result)
        assert actual == status, (actual, data)
        return json.loads(data) if data else None


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
            operation = native.prepare(1, seed, request)
            exported = native.export(operation)
            assert json.loads(exported)["operation"]["command"] == system.signed(request["command"], 1)
            saved = system.root / "pending.json"
            saved.write_bytes(exported)
            saved.chmod(0o600)
            native.call(client, operation, status=6)  # Commit happened; receipt lost.
            native.lib.transit_operation_destroy(operation)
            operation = None
            # A fresh host has no native handles or seed, only exact signed retry
            # material. Current authority still controls receipt disclosure.
            result = json.loads(subprocess.check_output([sys.executable, "-B", __file__, "--retry", library, url, str(saved)], timeout=15))
            assert len(bodies) == 2 and bodies[0] == bodies[1]
            assert result["position"] == 1
            system.sequence = 1
            operation = native.restore(exported)
            assert native.export(operation) == exported
            assert native.call(client, operation) == result
            native.lib.transit_operation_destroy(operation)
            operation = native.prepare(2, seed, {"realm": 72, "principal": 0, "sequence": 0, "command": {"inspect": 1}})
            assert native.call(client, operation)["process"]["pid"] == 1
            native.lib.transit_operation_destroy(operation)
            operation = native.prepare(3, seed, {"realm": 72, "principal": 0, "kind": "capabilities"})
            assert native.call(client, operation)["capabilities"]["value_bytes"] == 256
            worker_seed, public = system.key("reader")
            system.command({"grant": {"subject": 1, "public_key": public, "permissions": 16, "pid": 1}})
            native.lib.transit_operation_destroy(operation)
            operation = None
            operation = native.prepare(2, bytes.fromhex(worker_seed.read_text().strip()), {
                "realm": 72, "principal": 1, "sequence": 0, "command": {"inspect": 1},
            })
            assert native.call(client, operation)["process"]["pid"] == 1
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
                assert native.lib.transit_operation_prepare(1, seed, raw, len(raw), c.byref(invalid)) == 1
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

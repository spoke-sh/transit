"""Standalone client port: native metadata, profile isolation and seedless retry."""
import hashlib
import json
import select
import subprocess
import sys
from pathlib import Path

from client_abi_growing import GrowingSystem


class Port:
    def __init__(self, executable, config):
        self.child = subprocess.Popen([executable, str(config)], stdin=subprocess.PIPE,
                                      stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)

    def __enter__(self):
        return self

    def __exit__(self, *_):
        self.child.stdin.close()
        try:
            assert self.child.wait(timeout=15) == 0
        finally:
            if self.child.poll() is None:
                self.child.kill()
                self.child.wait(timeout=5)
            self.child.stdout.close()

    def request(self, request, status=0):
        raw = request if isinstance(request, bytes) else json.dumps(request).encode()
        self.child.stdin.write(raw + b"\n")
        assert select.select([self.child.stdout], [], [], 15)[0], "Client port stalled"
        response = json.loads(self.child.stdout.readline(1024 * 1024))
        assert response["status"] == status, response
        return response["value"]


def run(executable, node, cli):
    with GrowingSystem(node, cli) as system:
        config = system.root / "client.json"
        config.write_text(json.dumps({"url": system.url, "timeout_ms": 1000}))
        with Port(executable, config) as port:
            assert port.request({"hello": {}}) == {"host_version": 1, "transit_version": 1}
            caps = port.request({"capabilities": {}})
            assert caps["operation_metadata"] and caps["growing_v3"] and caps["opaque_retry"]
            assert caps["minimum_stack_bytes"] >= 8 * 1024 * 1024
            port.request(b"{", 1)
            port.request({"growing_prepare": 0}, 1)  # No Station surface.

            def prepare(kind, document):
                return port.request({"prepare": {"kind": kind, "seed_file": str(system.seed),
                                                   "document": json.dumps(document)}})

            spawn = prepare(6, {"realm": 72, "principal": 0, "sequence": 1, "command": {"spawn": {}}})
            meta = port.request({"metadata": spawn})
            assert meta["command"] == "spawn" and meta["destination"] is None
            pid = port.request({"call": spawn})["position"]
            frozen = prepare(6, {"realm": 72, "principal": 0, "sequence": 2,
                                 "command": {"send": {"pid": pid, "value": "00ff"}}})
            metadata = port.request({"metadata": frozen})
            assert metadata == {"version": 1, "identity": hashlib.sha256(frozen.encode()).hexdigest(),
                                "kind": "growing_command", "profile": "growing_v3", "realm": 72,
                                "principal": 0, "sequence": "2", "command": "send", "destination": pid}
            receipt = port.request({"call": frozen})
            query = prepare(7, {"realm": 72, "principal": 0, "kind": {"process": pid}})
            info = port.request({"metadata": query})
            assert info["command"] is info["sequence"] is info["destination"] is None
            port.request({"metadata": " " + frozen}, 1)
            port.request({"metadata": frozen.replace('"version":1', '"version":2', 1)}, 10)
            legacy = prepare(1, {"realm": 72, "principal": 0, "sequence": 1,
                                 "command": {"send": {"pid": 1, "value": ""}}})
            assert port.request({"metadata": legacy})["profile"] == "legacy_v2"
            wide = prepare(6, {"realm": 72, "principal": 65536, "sequence": 1,
                               "command": {"send": {"pid": 2**53 - 1, "value": ""}}})
            wide_info = port.request({"metadata": wide})
            assert (wide_info["principal"], wide_info["destination"]) == (65536, 2**53 - 1)
        # A clean process can classify and recover the exact request with no seed.
        system.seed.unlink()
        with Port(executable, config) as port:
            assert port.request({"metadata": frozen}) == metadata
            assert port.request({"call": frozen}) == receipt
            current = port.request({"call": query})
            assert current["body"]["process"]["process"]["pid"] == pid
            assert port.request({"shutdown": {}}) == {"closed": True}
            # The native owner exits after cleanup without waiting for stdin EOF.
            assert port.child.wait(timeout=5) == 0
        print("Client port: standalone metadata, wide identities, malformed input and fresh-host seedless retry passed.")


if __name__ == "__main__":
    run(*sys.argv[1:])

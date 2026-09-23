"""Infrastructure/fault harness; both application callers are independent Zig programs."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
from storage import Fixture, free_port, wait_ready


def run(node, cli, accumulator, byte_log):
    with Fixture() as store:
        children, logs = [], []
        def start():
            log = (store.root / f"node-{len(logs)}.log").open("w+")
            logs.append(log)
            child = subprocess.Popen([str(node), str(config)], stdout=log, stderr=subprocess.STDOUT)
            children.append(child)
            wait_ready(store.http, child, url + "/health")
            return child
        def key(name):
            path = store.root / name
            path.write_text(os.urandom(32).hex())
            path.chmod(0o600)
            public = json.loads(subprocess.check_output([str(cli), "public-key", str(path)], timeout=10))
            return path, public
        root, public = key("root.key")
        port = free_port()
        url = f"http://127.0.0.1:{port}"
        config = store.root / "node.json"
        config.write_text(json.dumps({"genesis": {"realm": 61, "root_key": public}, "ursula_url": store.url,
                                      "bucket": "caller-proof", "journal": "authority", "port": port}))
        sequence = 0
        def command(value):
            nonlocal sequence
            sequence += 1
            request = store.root / "request.json"
            request.write_text(json.dumps({"realm": 61, "principal": 0, "sequence": sequence, "command": value}))
            return json.loads(subprocess.check_output([str(cli), "submit", str(root), str(request), url], timeout=10))["position"]
        dropped = set()
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                request = json.loads(body)["request"]
                connection = HTTPConnection("127.0.0.1", port, timeout=5)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    principal = request["principal"]
                    if response.status == 200 and "turn" in request["command"] and principal not in dropped:
                        dropped.add(principal)
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
        try:
            subprocess.run([str(node), str(config), "--initialize"], check=True, timeout=15)
            authority = start()
            # Workload identifiers and data are caller-defined. The node binary
            # and configuration remain identical for both applications.
            pids = [command({"spawn": {"code": 101, "initial_state": b"0".hex()}}),
                    command({"spawn": {"code": 202, "initial_state": b"seed:".hex()}})]
            configs = []
            for index, (pid, initial, expected) in enumerate(zip(pids, [b"7", b"alpha\0"], [b"7", b"seed:alpha\0"]), 1):
                seed, public = key(f"worker-{index}.key")
                command({"grant": {"subject": index, "public_key": public, "permissions": 88, "pid": pid}})
                command({"own": {"pid": pid, "expected_generation": 0, "worker": index}})
                command({"send": {"pid": pid, "value": initial.hex()}})
                configs.append({"url": f"http://127.0.0.1:{proxy.server_port}", "realm": 61, "principal": index,
                                "pid": pid, "peer": pids[2-index], "generation": 1, "seed_file": str(seed),
                                "expected_state": expected.hex(), "consumed": 1, "lose_ack": True})
            def call(index, phase):
                path = store.root / f"caller-{index}.json"
                path.write_text(json.dumps(configs[index]))
                subprocess.run([str([accumulator, byte_log][index]), str(path), phase], check=True, timeout=20)
            for index in range(2):
                call(index, "commit")
            assert dropped == {1, 2}
            # Atomic turn outputs appear once despite lost acknowledgements.
            command({"deliver": {"pid": pids[1], "output": 1, "courier": 0}})
            command({"deliver": {"pid": pids[0], "output": 2, "courier": 0}})
            authority.kill()
            authority.wait(timeout=10)
            store.stop()
            store.start()
            authority = start()
            for index, expected in enumerate([b"12", b"seed:alpha\x005"]):
                command({"own": {"pid": pids[index], "expected_generation": 1, "worker": index+1}})
                call(index, "stale")
                configs[index].update(generation=2, expected_state=expected.hex(), consumed=2, lose_ack=False)
                call(index, "commit")
                call(index, "verify")
            # No application reducer is present during either restart/recovery.
            authority.kill()
            authority.wait(timeout=10)
            authority = start()
            for index in range(2):
                call(index, "verify")
            print("Two independent Zig callers: opaque state, atomic outputs, lost acknowledgements, stale activation and authority/storage recovery passed.")
        finally:
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            for child in children:
                if child.poll() is None:
                    child.kill()
                child.wait(timeout=10)
            for log in logs:
                log.close()

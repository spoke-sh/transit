"""Two independent Zig editors, a fenced writer and owned disk-backed recovery."""
import argparse
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import sys
import threading
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests"))
from client_abi_growing import GrowingSystem
from cold_storage import ColdStore
from document_contract import encode
from storage import Fixture, wait_ready


def run(*, board=False, browser=False):
    binaries = {name: ROOT / "zig-out/bin" / name for name in (
        "transit-board", "transit-node", "rey-cli", "transit-station-document-worker", "example-station-document")}
    started = time.monotonic()
    with ColdStore() as cold:
        fixture = GrowingSystem(binaries["transit-node"], binaries["rey-cli"])
        fixture.store = Fixture(cold.config())
        fixture.resident_pages = 64
        with fixture as system:
            env = system.store.env | {"LOG_LEVEL": "warn"}
            def write(name, value):
                path = system.root / name
                path.write_text(json.dumps(value))
                path.chmod(0o600)
                return path

            def invoke(argv, *, error=None, timeout=900):
                result = subprocess.run(list(map(str, argv)), env=env, capture_output=True, timeout=timeout)
                if error:
                    assert result.returncode and error.encode() in result.stderr, (result.returncode, result.stderr[-1500:])
                    return None
                if result.returncode:
                    raise RuntimeError(result.stderr.decode()[-4000:])
                return json.loads(result.stdout)

            def query(kind):
                return invoke([binaries["rey-cli"], "query", system.seed,
                    write("query.json", {"realm": 72, "principal": 0, "kind": kind}), system.url])

            def command(body):
                sequence = query({"capabilities": {}})["principal_sequence"] + 1
                path = write(f"command-{sequence}.json", {"realm": 72, "principal": 0, "sequence": sequence, "command": body})
                for attempt in range(3):
                    try:
                        return invoke([binaries["rey-cli"], "submit", system.seed, path, system.url])["position"]
                    except RuntimeError:
                        if attempt == 2:
                            raise

            records = {}
            for principal, role in enumerate(("writer", "left", "right"), 1):
                seed, public = system.key(role)
                pid = command({"spawn": {}})
                resource = command({"create_resource": {"writer": pid, "owned": False}})
                command({"grant": {"subject": principal, "public_key": public, "permissions": 4 | 8 | 16 | 64, "pid": pid}})
                for subject in (0, principal):
                    command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
                command({"associate": {"pid": pid, "name": b"state".hex(), "resource": resource}})
                directory = system.root / role
                directory.mkdir(mode=0o700)
                records[role] = {"pid": pid, "resource": resource, "principal": principal,
                    "seed_file": str(seed), "generation": 1, "activation_directory": str(directory)}
            writer = records["writer"]
            for role in ("left", "right"):
                command({"associate": {"pid": writer["pid"], "name": ("request-"+role).encode().hex(),
                    "resource": records[role]["resource"], "required": False}})
                command({"associate": {"pid": records[role]["pid"], "name": b"document".hex(),
                    "resource": writer["resource"], "required": False}})
                command({"grant_resource": {"resource": records[role]["resource"], "subject": writer["principal"], "permissions": 3}})
                command({"grant_resource": {"resource": writer["resource"], "subject": records[role]["principal"], "permissions": 3}})
            policies = [{"caller": records[role]["pid"], "resource": records[role]["resource"],
                "replica": replica, "revision": 1} for replica, role in enumerate(("left", "right"), 1)]

            def own(role):
                record = records[role]
                record["generation"] = query({"process": record["pid"]})["body"]["process"]["process"]["generation"]
                command({"own": {"pid": record["pid"], "expected_generation": record["generation"], "worker": record["principal"]}})
                record["generation"] += 1

            def deliver():
                after = None
                while True:
                    position = query({"capabilities": {}})["position"]
                    page = query({"outputs": {"after": after, "position": position}})["body"]["outputs"]
                    for entry in page["entries"]:
                        if entry and entry["phase"] == "pending":
                            assert entry["destination"] in [r["pid"] for r in records.values()]
                            command({"deliver": entry["id"]})
                    after = page["next"]
                    if after is None:
                        return

            # Only the writer uses this proxy. Faults inspect framing/metadata;
            # no change bytes or keys are emitted in the evidence report.
            crash = threading.Event()
            release = threading.Event()
            fault = {"armed": False, "crashed": False, "accepted": None, "receipt": None, "retried": False,
                "turns": 0, "max_mutations": 0, "errors": []}
            class Proxy(BaseHTTPRequestHandler):
                def log_message(self, *_):
                    pass
                def do_POST(self):
                    body = self.rfile.read(int(self.headers["Content-Length"]))
                    connection = HTTPConnection("127.0.0.1", system.port, timeout=35)
                    try:
                        connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                        response = connection.getresponse()
                        data = response.read()
                        if self.path == "/v1/command" and response.status == 200:
                            operation = json.loads(body)["request"]["command"]
                            turn = operation.get("turn", operation.get("turn_with_versions", {}).get("turn", {}))
                            mutations = [item for item in turn.get("mutations", []) if item]
                            values = [(bytes.fromhex(item["key"]), bytes.fromhex(item["value"]))
                                for item in mutations if item["value"]]
                            assert all(len(key) <= 32 and len(value) <= 256 for key, value in values)
                            if turn:
                                fault["turns"] += 1
                                fault["max_mutations"] = max(fault["max_mutations"], len(mutations))
                            if body == fault["accepted"]:
                                assert data == fault["receipt"], "Signed acceptance retry changed its receipt"
                                fault["retried"] = True
                            elif fault["accepted"] is None and any(v.startswith(b"SDJ1") and v[12] == 3 for _, v in values):
                                assert len([o for o in turn["outputs"] if o]) == 1
                                fault["accepted"], fault["receipt"] = body, data
                                data = b'{"position":0}'
                            if fault["armed"] and not fault["crashed"] and any(
                                v.startswith(b"SPR1") and v[4] == 1 and int.from_bytes(k[11:19], "big") > 1
                                and int.from_bytes(v[16:20], "little") == 1 for k, v in values):
                                fault["crashed"] = True
                                crash.set()
                                if not release.wait(30):
                                    raise TimeoutError("Worker crash boundary was not released")
                        self.send_response(response.status)
                        self.send_header("Content-Length", str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                    except (BrokenPipeError, ConnectionResetError):
                        if not fault["crashed"]:
                            fault["errors"].append("unexpected disconnected writer")
                    except BaseException as error:
                        fault["errors"].append(type(error).__name__)
                        raise
                    finally:
                        connection.close()
            proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            proxy_url = f"http://127.0.0.1:{proxy.server_port}"

            def worker_config(mode="run", **extra):
                own("writer")
                return write("writer.json", {**{k: v for k, v in writer.items() if k != "resource"},
                    "url": proxy_url, "realm": 72, "document": 17, "mode": mode, "policies": policies, **extra})

            def worker(mode="run", **extra):
                result = invoke([binaries["transit-station-document-worker"], worker_config(mode, **extra)])
                assert result["phase"] == "complete", result
                return result

            common = {"document": "17", "epoch": "1", "type_revision": 1}
            def dot(counter, replica=1):
                return {"counter": str(counter), "replica": str(replica)}
            def assign(text, observed=()):
                return {"assign": {"field": "title", "observed": list(observed), "value": {"string": text}}}
            seed = {**common, "replica": "1", "first": "1", "operations": [assign("Notes"),
                {"assign": {"field": "body", "value": {"text": {}}}},
                {"insert": {"object": dot(2), "value": {"character": "A"}}}]}
            left = {**common, "replica": "1", "previous": "3", "first": "4", "operations": [assign("Left", [dot(1)]),
                {"insert": {"object": dot(2), "after": dot(3), "value": {"character": "a"}}}]}
            right = {**common, "replica": "2", "first": "4", "operations": [assign("Right", [dot(1)]),
                {"insert": {"object": dot(2), "after": dot(3), "value": {"character": "🙂"}}}]}
            resolve = {**common, "replica": "1", "previous": "5", "first": "6", "operations": [assign("Resolved", [dot(4), dot(4, 2)])]}
            def caller(role, mode, namespace=1, change=seed, *, error=None):
                record = records[role]
                if mode in ("publish", "receive"):
                    own(role)
                config = {**record, "url": system.url, "realm": 72, "writer": writer["pid"], "resource": writer["resource"],
                    "document": 17, "replica": 1 if role == "left" else 2, "namespace": namespace,
                    "change": encode(change).hex(), "mode": mode}
                return invoke([binaries["example-station-document"], write(role+".json", config)], error=error)

            def submit(role, namespace, change):
                assert caller(role, "publish", namespace, change)["phase"] == "called"
                deliver()
                worker()
                deliver()
                return caller(role, "receive", namespace, change)

            inspection = None
            try:
                assert worker("create")["revision"] == "0"
                if board or browser:
                    from document_board import DocumentBoard
                    inspection = DocumentBoard(system, writer, command, query, write, binaries, browser)
                    assert inspection.request("/api/v1/capabilities")["documents"]
                invoke([binaries["transit-station-document-worker"], system.root / "writer.json"], error="FreshOwnershipRequired")
                assert submit("left", 1, seed)["phase"] == "accepted"
                assert fault["retried"], "Acceptance uncertainty did not retain exact signed bytes"
                print("Document example: initial structured/text change and exact acceptance retry passed", flush=True)
                # Both edits are prepared against revision 1. Left stays disconnected
                # while right publishes and receives its independent result first.
                assert submit("right", 1, right)["revision"] == "2"
                assert caller("left", "publish", 2, left)["phase"] == "called"
                deliver()
                fault["armed"] = True
                path = worker_config()
                child = system.start(binaries["transit-station-document-worker"], path, env=env)
                deadline = time.monotonic() + 120
                while not crash.wait(.05):
                    assert child.poll() is None, "Writer exited before candidate crash boundary"
                    if time.monotonic() > deadline:
                        raise TimeoutError("Candidate crash boundary")
                child.kill()
                assert child.wait(timeout=10) == -9
                release.set()
                system.authority.kill()
                system.authority.wait(timeout=10)
                system.store.stop()
                system.store.start()
                system.authority = system.start(binaries["transit-node"], system.config)
                wait_ready(system.store.http, system.authority, system.url + "/health")
                # Revocation blocks a reconstructed candidate without permanently
                # poisoning the mailbox. Fresh ownership plus restored policy resumes.
                command({"grant_resource": {"resource": records["left"]["resource"], "subject": writer["principal"], "permissions": 0}})
                invoke([binaries["transit-station-document-worker"], worker_config()], error="AccessDenied")
                command({"grant_resource": {"resource": records["left"]["resource"], "subject": writer["principal"], "permissions": 3}})
                assert worker()["revision"] == "3"
                deliver()
                assert caller("left", "receive", 2, left)["phase"] == "accepted"
                view = caller("right", "inspect", change=right)
                assert (view["title_status"], view["alternatives"], view["text"]) == ("conflict", 2, "A🙂a"), view
                if inspection: inspection.prove()
                assert submit("left", 3, left)["phase"] == "duplicate"
                assert submit("left", 4, resolve)["revision"] == "4"
                assert caller("right", "inspect", change=right)["title_status"] == "scalar"
                print("Document example: disconnected/reordered edits, duplicate, conflict resolution and worker/store recovery passed", flush=True)
                worker("window", merge_window=2)
                assert worker("checkpoint", job=90)["epoch"] == "2"
                rejected = submit("right", 2, right)
                assert rejected["phase"] == "rejected" and rejected["reason"] == "resynchronize", rejected
                sync = caller("right", "resynchronize", change=right)
                assert sync["epoch"] == 2 and sync["floor"] == 4 and sync["previous_counter"] == 5, sync
                if inspection: inspection.inspect(5, 4)
                worker("retire")
                retired = submit("right", 3, right)
                assert retired["phase"] == "rejected" and retired["reason"] == "retired", retired
                caller("right", "inspect", change=right, error="DocumentRetired")
                if inspection: inspection.inspect(5, 4, retired=True)
                assert not fault["errors"], fault["errors"]
                assert fault["max_mutations"] == 4
                print("Document example evidence:", json.dumps({"profile": "local", "seconds": round(time.monotonic()-started, 2),
                    "killed_workers": 1, "node_store_restarts": 1, "exact_acceptance_retry": fault["retried"],
                    "writer_turn_attempts": fault["turns"], "max_mutations": fault["max_mutations"],
                    "hot_bytes": 8*1024*1024, "cold_objects": cold.data_objects(), "cold_bytes": cold.file_bytes()}, sort_keys=True), flush=True)
            finally:
                if inspection: inspection.close()
                release.set()
                proxy.shutdown()
                proxy.server_close()
                thread.join(timeout=5)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=("local", "compose", "reference"), default="local")
    parser.add_argument("--board", action="store_true")
    parser.add_argument("--browser", action="store_true")
    args = parser.parse_args()
    if args.profile == "local":
        if hasattr(os, "sched_getaffinity"):
            os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
        run(board=args.board, browser=args.browser)
    else:
        if args.board or args.browser: parser.error("Board qualification uses the local profile")
        from placed import run as run_placed
        run_placed(args.profile)

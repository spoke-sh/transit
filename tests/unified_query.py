"""Actual v2 requester/source daemons, frozen signed upload and disk recovery."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import argparse
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

import pyarrow as pa

from storage import Fixture, free_port, wait_ready
from cold_storage import ColdStore
from unified_abi import Native, Port, Failure, upload, verify


def run(node, host, proof, port_host, library, kinds=("kv", "table", "document"), sdks=()):
    node, host, proof, port_host, library = (str(Path(path).resolve()) for path in (node, host, proof, port_host, library))
    for kind in kinds:
        started = time.monotonic()
        with ColdStore() as cold, Fixture(cold.config()) as fixture:
            root = fixture.root
            from sdk_unified import install
            factories = install(root / 'installed', sdks) if sdks else []
            public = json.loads(subprocess.check_output([proof, "public"], timeout=10))
            port = free_port()
            url = f"http://127.0.0.1:{port}"
            node_config = root / "node.json"
            resident_pages = 64 if kind == "document" else 8
            node_config.write_text(json.dumps({"profile": "growing_v3", "genesis": {"realm": 46, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "unified-query", "journal": "authority", "port": port, "resident_pages": resident_pages, "request_timeout_ms": 10000}))
            processes, logs = [], []
            native, port_client = None, None
            callers = []
            fault = {"lost": None, "retry": False, "stage": threading.Event(), "resume": threading.Event()}

            class Proxy(BaseHTTPRequestHandler):
                def log_message(self, *_): pass
                def do_POST(self):
                    body = self.rfile.read(int(self.headers["Content-Length"]))
                    message = json.loads(body)
                    connection = HTTPConnection("127.0.0.1", port, timeout=15)
                    try:
                        connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                        response = connection.getresponse()
                        data = response.read()
                        if self.path == "/v3/command" and response.status == 200:
                            request = message["request"]
                            command = request["command"]
                            if request["principal"] == 1234 and "send" in command:
                                payload = bytes.fromhex(command["send"]["value"])[13:]
                                if payload.startswith(b"UQP2"):
                                    if fault["lost"] is None:
                                        fault["lost"] = body, data
                                        data = b'{"position":0}'
                                    elif body == fault["lost"][0]:
                                        assert data == fault["lost"][1]
                                        fault["retry"] = True
                            turn = command.get("turn", command.get("turn_with_versions", {}).get("turn", {}))
                            if request["principal"] == 65536 and not fault["stage"].is_set() and any(item and bytes.fromhex(item["key"]).startswith(b"\x00Us") for item in turn.get("mutations", [])):
                                fault["stage"].set()
                                fault["resume"].wait(timeout=60)
                        self.send_response(response.status)
                        self.send_header("Content-Length", str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                    except (BrokenPipeError, ConnectionResetError, ConnectionRefusedError): pass
                    finally: connection.close()

            proxy = ThreadingHTTPServer(("127.0.0.1", 0), Proxy)
            proxy.daemon_threads = True
            thread = threading.Thread(target=proxy.serve_forever, daemon=True)
            thread.start()
            proxy_url = f"http://127.0.0.1:{proxy.server_port}"

            def start(name, command):
                log = (root / f"{name}.log").open("w+")
                logs.append(log)
                process = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT, env=fixture.env)
                processes.append(process)
                return process

            def invoke(mode, *args, error=None, timeout=180, direct=False):
                result = subprocess.run([proof, url if direct else proxy_url, mode, str(root), *args], capture_output=True, text=True, timeout=timeout, env=fixture.env)
                if error:
                    assert result.returncode and error in result.stderr, (mode, result.stdout, result.stderr)
                else:
                    assert result.returncode == 0, (mode, result.stdout, result.stderr)
                return json.loads(result.stdout) if result.returncode == 0 and result.stdout.strip() else None

            try:
                subprocess.run([node, str(node_config), "--initialize"], check=True, capture_output=True, timeout=30, env=fixture.env)
                authority = start("node", [node, str(node_config)])
                wait_ready(fixture.http, authority, url + "/health")
                connection = invoke("provision", kind, timeout=1800, direct=True)
                print(f"Unified {kind}: provisioned in {time.monotonic() - started:.2f}s", flush=True)
                for name in ("source", "requester", "courier"):
                    path = root / f"{name}.json"
                    config = json.loads(path.read_text())
                    config["url"] = proxy_url
                    path.write_text(json.dumps(config))
                requester = start("requester", [host, str(root / "requester.json")])
                source = start("source", [host, str(root / "source.json")])
                courier = start("courier", [host, str(root / "courier.json")])
                native = Native(library, proxy_url, connection)
                port_client = Port(port_host, root, proxy_url, connection)
                for factory in factories: callers.extend(factory(proxy_url, connection, root, kind))
                uploader = callers[0] if callers else native
                try:
                    upload(uploader, root)
                    raise AssertionError('lost upload response was reported as success')
                except Failure as failure:
                    assert failure.status == 6 and failure.detail['err'] == 'InvalidAuthorityResponse', failure
                invoke("resume")
                assert fault["retry"], "uncertain upload did not retry identical signed bytes"
                status = upload(uploader, root)
                assert status["phase"] in ("admitted", "complete"), status
                print(f"Unified {kind}: frozen upload retry and admission passed", flush=True)
                until = time.monotonic() + 120
                while not fault["stage"].wait(timeout=0.2):
                    status = invoke("status", timeout=15)
                    assert status["phase"] == "admitted", status
                    assert source.poll() is None and requester.poll() is None, "query worker exited"
                    assert time.monotonic() < until, "source never staged a segment"
                source.kill(); source.wait(timeout=10)
                fault["resume"].set()
                same = subprocess.run([host, str(root / "source.json")], capture_output=True, timeout=15, env=fixture.env)
                assert same.returncode and b"FreshOwnershipRequired" in same.stderr, same.stderr
                requester.kill(); requester.wait(timeout=10)
                courier.kill(); courier.wait(timeout=10)
                authority.kill(); authority.wait(timeout=10)
                fixture.stop()
                fixture.start()
                print(f"Unified {kind}: restarted source, requester, node and disk store after segment staging", flush=True)
                authority = start("node-recovered", [node, str(node_config)])
                wait_ready(fixture.http, authority, url + "/health")
                for role in ("source", "requester"):
                    generation = invoke("fence" if role == "source" else "fence-requester", direct=True)["generation"]
                    path = root / f"{role}.json"
                    config = json.loads(path.read_text()); config["generation"] = generation
                    path.write_text(json.dumps(config))
                source = start("source-recovered", [host, str(root / "source.json")])
                requester = start("requester-recovered", [host, str(root / "requester.json")])
                courier = start("courier-recovered", [host, str(root / "courier.json")])
                until = time.monotonic() + 900
                while True:
                    status = invoke("status", timeout=15)
                    if status and status["phase"] == "complete": break
                    assert status and status["phase"] == "admitted", status
                    assert time.monotonic() < until, status
                    assert source.poll() is None and requester.poll() is None, "query worker exited"
                    time.sleep(0.2)
                print(f"Unified {kind}: complete manifest after {time.monotonic() - started:.2f}s", flush=True)
                first = invoke("page")
                assert not first["complete"] and first["rows"] > 0
                saved = (root / "cursor.json").read_bytes()
                invoke("revoke", direct=True)
                invoke("page", error="AccessDenied")
                for owner in (native, port_client, *callers):
                    try:
                        owner.call({'page': dict(namespace='1', cursor=saved.decode())})
                        raise AssertionError('revoked result read succeeded')
                    except Failure as failure:
                        assert failure.status == 4, failure
                assert (root / "cursor.json").read_bytes() == saved
                invoke("restore", direct=True)
                final = first
                while not final["complete"]: final = invoke("page")
                actual = []
                total = 0
                for ordinal in range(final["ordinal"] + 1):
                    encoded = (root / f"result-{ordinal}.arrow").read_bytes()
                    total += len(encoded)
                    with pa.ipc.open_stream(encoded) as reader:
                        actual += reader.read_all().to_pylist()
                # Document v1's accepted scalar bound is 96 bytes; KV/Table
                # deliberately exercise their wider scalar envelope as well.
                padding = 64 if kind == "document" else 128
                expected = [{"value": {"state": 3, "kind": 5, "value": f"東京🙂/{'x'*padding}/{index:02}", "alternatives": []}} for index in range(12 if kind == "document" else 41)]
                if kind == "document":
                    for index, row in enumerate(expected):
                        row['counter'] = dict(state=3, kind=2, value=index+2, alternatives=[])
                        row['replica'] = dict(state=3, kind=2, value=1, alternatives=[])
                assert actual == expected, actual[:2]
                assert total > 8192
                assert kind == "document" or len(actual) > 32
                manifest = final["manifest"]
                assert manifest["job"]["correlation"] == status["correlation"]
                assert manifest["checkpoint"]["progress"]["basis"]["kind"] == kind
                assert manifest["checkpoint"]["bytes"] == total
                verify(native, port_client, root, final['ordinal']+1)
                for owner in callers: verify(owner, owner, root, final['ordinal']+1)
                versions = invoke("versions", direct=True)
                assert versions["next"] is None
                assert all(version["released_at"] is not None for version in versions["entries"] if version)
                assert cold.data_objects() > 0
                print(f"Unified {kind}: {len(actual)} rows / {final['ordinal'] + 1} segments / {total} bytes / {resident_pages} resident authority pages / 8 MiB hot store / {cold.data_objects()} cold objects / {cold.file_bytes()} cold bytes / installed SDKs={','.join(sdks) or 'none'}; frozen upload retry, worker/node/store recovery, prefix revocation and released source pin passed in {time.monotonic() - started:.2f}s", flush=True)
            except BaseException:
                for log in logs:
                    log.flush(); log.seek(0)
                    print(f"{log.name}:\n{log.read()[-5000:]}", file=sys.stderr)
                raise
            finally:
                fault["resume"].set()
                cleanup_errors = []
                for owner in (*callers, port_client, native):
                    if owner is not None:
                        try: owner.close()
                        except BaseException as error: cleanup_errors.append(error)
                for process in processes:
                    if process.poll() is None: process.kill()
                    process.wait(timeout=10)
                proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)
                for log in logs: log.close()
                if cleanup_errors: raise BaseExceptionGroup('query caller cleanup failed', cleanup_errors)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    for name in ('node', 'host', 'proof', 'port_host', 'library'): parser.add_argument(name)
    parser.add_argument('kinds', nargs='*', choices=('kv', 'table', 'document'))
    parser.add_argument('--sdk', action='append', choices=('python', 'node', 'ruby', 'rust'))
    args = parser.parse_args()
    run(args.node, args.host, args.proof, args.port_host, args.library,
        kinds=args.kinds or ('kv', 'table', 'document'), sdks=args.sdk or ())

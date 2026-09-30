"""Run actual Station callers; inject failures only at the transport/runtime."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import hashlib
from pathlib import Path
import struct
import sys
import threading
import time

import pyarrow as pa

from arrow import field, simple_rows
from inspection import System
from storage import wait_ready


def frame(payload, kind=1, correlation=0):
    return (b"STN1" + bytes([kind]) + struct.pack("<Q", correlation) + payload).hex()


def run(node, cli, worker, courier):
    # Capturing the current query format stages durable catalog pages. Use the
    # paged SDK fixture's request budget, independent of inspection deadlines.
    with System(node, cli, clock_error_ms=10000, request_timeout_ms=5000) as s:
        def value(resource, key):
            revision = s.native_query({'resource': resource})['body']['resource']['revision']
            entry = s.native_query({'entries': {'resource': resource, 'revision': revision, 'key': key.hex()}})['body']['entries']['page']['entries'][0]
            return bytes.fromhex(entry['value']) if entry else None
        def create(principal, role, destination=None):
            pid = s.command({"create": {"required": [b"data".hex(), None, None, None]}})
            resource = s.command({"create_resource": {"writer": pid}})
            seed, public = s.key(role)
            s.command({"grant": {"subject": principal, "public_key": public, "permissions": 88, "pid": pid}})
            for subject in (0, principal):
                s.command({"grant_resource": {"resource": resource, "subject": subject, "permissions": 7}})
            s.command({"associate": {"pid": pid, "name": b"data".hex(), "resource": resource}})
            s.command({"send": {"pid": pid, "value": frame(b"init")}})
            s.command({"initialize": {"pid": pid, "expected_generation": 1}})
            s.command({"own": {"pid": pid, "worker": principal, "expected_generation": 2}})
            config = {"url": s.url, "realm": 72, "principal": principal, "pid": pid,
                      "generation": 3, "seed_file": str(seed), "role": role, "destination": destination}
            return pid, resource, config
        ledger, ledger_resource, ledger_config = create(1, "ledger")
        requester, requester_resource, requester_config = create(2, "requester", ledger)
        ledger_config["destination"] = requester
        def total():
            key = b"\x00r" + (1).to_bytes(4, "little") + ((1 << 63) + 1).to_bytes(8, "big")
            row = value(ledger_resource, key)
            return 0 if row is None else int.from_bytes(row[2:], "little", signed=True)
        serial = 0
        def launch(config, once=True):
            nonlocal serial
            serial += 1
            path = s.root / f"worker-{serial}.json"
            path.write_text(json.dumps(config))
            return s.start(worker, *( ["--once", path] if once else [path]))
        def once(config, success=True):
            child = launch(config)
            assert (child.wait(timeout=20) == 0) == success
        once(ledger_config)
        once(requester_config)
        assert total() == 0
        assert value(ledger_resource, b"\x00station") == b"station.genserver.v1"

        delivery_seed, public = s.key("courier")
        s.command({"grant": {"subject": 3, "public_key": public, "permissions": 132}})
        delivery_config = s.root / "courier.json"
        delivery_config.write_text(json.dumps({"url": s.url, "realm": 72, "principal": 3,
                                               "seed_file": str(delivery_seed), "interval_ms": 10}))
        delivery_daemon = s.start(courier, delivery_config)
        def await_input(pid):
            for _ in range(200):
                if s.native_query({"process": pid})["body"]["process"]["input"] is not None:
                    return
                time.sleep(.025)
            raise AssertionError(("no delivered input", pid))

        control = {"mode": "drop", "bodies": [], "changed_basis": 0}
        committed, release = threading.Event(), threading.Event()
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                envelope = json.loads(body)
                command = envelope.get("request", {}).get("command", {})
                is_turn = ("turn" in command or "turn_with_versions" in command) and envelope["request"]["principal"] == 1
                query = envelope.get("query", {})
                if query.get('kind', {}).get('entries', {}).get('view') and not control['changed_basis']:
                    # Advance authority policy after capture without replacing
                    # the view's resource root or revoking its current rights.
                    s.command({'grant_resource': {'resource': ledger_resource, 'subject': 0, 'permissions': 7}})
                    control['changed_basis'] += 1
                if is_turn:
                    control["bodies"].append(body)
                connection = HTTPConnection("127.0.0.1", s.port, timeout=5)
                try:
                    connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                    response = connection.getresponse()
                    data = response.read()
                    if is_turn and response.status == 200 and control["mode"] != "pass":
                        mode, control["mode"] = control["mode"], "pass"
                        committed.set()
                        if mode == "hold":
                            release.wait(timeout=20)
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
        proxied = {**ledger_config, "url": f"http://127.0.0.1:{proxy.server_port}"}
        requester_config["url"] = proxied["url"]
        try:
            s.command({"send": {"pid": requester, "value": frame(b"7")}})
            once(requester_config)
            await_input(ledger)
            once(proxied)
            assert len(control["bodies"]) == 2 and control["bodies"][0] == control["bodies"][1]
            await_input(requester)
            once(requester_config)
            assert total() == 7 and value(requester_resource, b"answer") == b"7"

            # Crash after the authority accepted a reply-producing turn, before
            # its worker received a receipt. Then lose the authority and storage.
            committed.clear()
            control["mode"] = "hold"
            s.command({"send": {"pid": requester, "value": frame(b"5")}})
            once(requester_config)
            await_input(ledger)
            old = launch(proxied)
            assert committed.wait(timeout=15)
            old.kill()
            old.wait(timeout=10)
            release.set()
            s.authority.kill()
            s.authority.wait(timeout=10)
            s.store.stop()
            s.store.start()
            s.authority = s.start(s.node, s.config)
            wait_ready(s.store.http, s.authority, s.url + "/health")
            s.command({"own": {"pid": ledger, "worker": 1, "expected_generation": 3}})
            current = {**ledger_config, "generation": 4}
            once(ledger_config, success=False)
            await_input(requester)
            once(requester_config)
            assert total() == 12 and value(requester_resource, b"answer") == b"12"
            s.command({"send": {"pid": requester, "value": frame(b"-2")}})
            once(requester_config)
            await_input(ledger)
            once(current)
            await_input(requester)
            once(requester_config)
            assert total() == 10 and value(requester_resource, b"answer") == b"10"

            # Send permission alone cannot disclose Table data.
            s.command({"send": {"pid": requester, "value": frame(b"query")}})
            once(requester_config)
            await_input(ledger)
            once(current)
            await_input(requester)
            once(requester_config)
            assert value(requester_resource, b"answer") == b"station.query.error.QueryDenied"
            s.command({"send": {"pid": ledger, "value": frame(b"allow-query")}})
            once(current)

            def pump_until(predicate, limit=160):
                for _ in range(limit):
                    if predicate(): return
                    progressed = False
                    for config in (current, requester_config):
                        if s.native_query({'process': config['pid']})['body']['process']['input'] is not None:
                            once(config)
                            progressed = True
                    if not progressed: time.sleep(.025)
                raise AssertionError('Station query did not reach its recorded completion')
            query_input = s.command({"send": {"pid": requester, "value": frame(b"query")}})
            once(requester_config)
            await_input(ledger)
            # Capture a finite snapshot; no Arrow fragment is sent in this turn.
            once(current)
            await_input(ledger)
            s.command({"own": {"pid": ledger, "worker": 1, "expected_generation": 4}})
            current["generation"] = 5
            once(current)  # a new host publishes only previously captured bytes
            pump_until(lambda: s.native_query({'process': requester})['body']['process']['input'] is not None)
            once(requester_config)  # consume one fragment, then replace its host
            s.command({"own": {"pid": requester, "worker": 2, "expected_generation": 3}})
            requester_config["generation"] = 4
            pump_until(lambda: value(requester_resource, b'last-query') is not None)
            def query_key(tag, identity, ordinal=0, fragment=0):
                return b'\0Q' + tag.encode() + struct.pack('>QQH', identity, ordinal, fragment)
            manifest = value(requester_resource, query_key('c', query_input))
            assert len(manifest) == 241 and manifest[:4] == b'GQM1'
            assert manifest[40] == 2  # Table source kind.
            assert int.from_bytes(manifest[41:49], 'little') == ledger_resource
            assert manifest[89:121] == hashlib.sha256(b'transit.fuze.schema.v1\0\2\2\1id\6\1amount').digest()
            result_id = int.from_bytes(manifest[4:12], 'little')
            segments, size, rows = struct.unpack_from('<QQQ', manifest, 153)
            assert segments == 1 and rows == 1
            data = b''.join(value(requester_resource, query_key('d', query_input, 0, index))
                            for index in range((size + 220) // 221))
            assert len(data) == size
            segment = value(requester_resource, query_key('v', query_input))
            assert hashlib.sha256(data).digest() == segment[-32:]
            with pa.ipc.open_stream(data) as reader:
                table = reader.read_all()
            assert simple_rows(table) == [{'id': 1, 'amount': 10}]
            assert table.schema == pa.schema([field('id', pa.int64()), field('amount', pa.int64())])
            pump_until(lambda: value(ledger_resource, query_key('j', result_id))[57] == 4)

            # Stop delivery long enough to order revocation ahead of continuation.
            # Captured bytes remain retained but may no longer be disclosed.
            s.command({"send": {"pid": requester, "value": frame(b"query")}})
            once(requester_config)
            await_input(ledger)
            delivery_daemon.terminate()
            delivery_daemon.wait(timeout=10)
            once(current)
            s.command({"send": {"pid": ledger, "value": frame(b"deny-query")}})
            once(current)
            delivery_daemon = s.start(courier, delivery_config)
            await_input(ledger)
            once(current)
            await_input(requester)
            once(requester_config)
            assert value(requester_resource, b"answer") == b"station.query.denied.v1"

            bad_input = s.command({"send": {"pid": ledger, "value": frame(b"invalid")}})
            once(current, success=False)
            process = s.inspect("process", ledger)["processes"][0]
            assert process["failure"] is not None
            page = s.inspect("mailbox", ledger)
            while not any(item and item["position"] == bad_input for item in page["events"]):
                assert not page["complete"], "failed input disappeared from the mailbox"
                page = s.inspect("mailbox", ledger, cut=page["cut"], after=page["next"])
            assert total() == 10
            # Lifecycle control stays available after a recorded handler block.
            s.command({"terminate": ledger})
            assert s.inspect("process", ledger)["processes"][0]["lifecycle"] == "terminated"
            assert control["changed_basis"] == 1, "No captured view crossed the policy change"
            print("Station: two-table turns, call/reply, exact retries, captured views across policy changes, worker/store recovery, authorized captured Arrow replies, fencing and blocked-handler control passed.")
        finally:
            release.set()
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)


if __name__ == "__main__":
    run(*sys.argv[1:5])
    from station_services import run as services
    services(*sys.argv[1:])
    from station_lifetime import run as lifetime
    lifetime(*sys.argv[1:4])

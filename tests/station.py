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

from station_ledger import AUDIT, audit_total, query_key, query_result
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
            config = {"url": s.url, "realm": 72, "principal": principal, "pid": pid,
                      "generation": 3, "seed_file": str(seed), "role": role, "destination": destination}
            return pid, resource, config
        ledger, ledger_resource, ledger_config = create(1, "ledger")
        requester, requester_resource, requester_config = create(2, "requester", ledger)
        ledger_config.update(destination=requester, peer_resource=requester_resource)
        requester_config['source_resource'] = ledger_resource
        for resource, subject, config in ((ledger_resource, 2, requester_config), (requester_resource, 1, ledger_config)):
            s.command({'grant_resource': dict(resource=resource, subject=subject, permissions=3)})
            s.command({'associate': dict(pid=config['pid'], name=b'query-peer'.hex(), resource=resource, required=False)})
            s.command({'initialize': dict(pid=config['pid'], expected_generation=2)})
            s.command({'own': dict(pid=config['pid'], worker=subject, expected_generation=3)})
            config['generation'] = 4
        def total():
            return audit_total(s.native_query, ledger_resource)
        serial = 0
        def launch(config, once=True):
            nonlocal serial
            serial += 1
            path = s.root / f"worker-{serial}.json"
            path.write_text(json.dumps(config))
            return s.start(worker, *( ["--once", path] if once else [path]))
        def once(config, success=True):
            child = launch(config)
            assert (child.wait(timeout=30) == 0) == success, Path(s.logs[-1].name).read_text()[-3000:]
        def pump_until(predicate, configs, seconds=60):
            deadline = time.monotonic() + seconds
            while not predicate():
                assert time.monotonic() < deadline, 'Station domain work did not complete'
                progressed = False
                for config in configs:
                    if s.native_query({'process': config['pid']})['body']['process']['input'] is not None:
                        once(config)
                        progressed = True
                if not progressed: time.sleep(.025)
        once(ledger_config)
        once(requester_config)
        assert total() == 0
        s.command({'send': {'pid': ledger, 'value': frame(b'prepare-table')}})
        once(ledger_config)
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
                turn = command.get('turn', command.get('turn_with_versions', {}).get('turn', {}))
                is_turn = bool(turn) and envelope['request']['principal'] == 1 and any(
                    item and bytes.fromhex(item['key']).startswith(AUDIT) for item in turn.get('mutations', []))
                if is_turn:
                    writes = [item for item in turn['mutations'] if item]
                    assert len(writes) == 4 and any(item['value'] is None for item in writes), writes
                    assert any(item and bytes.fromhex(item['value'])[4] == 3 for item in turn['outputs']), 'Terminal publication lost its call reply'
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
            writer = launch(proxied, once=False)
            pump_until(lambda: value(requester_resource, b'answer') == b'7', [requester_config])
            writer.terminate(); writer.wait(timeout=10)
            assert len(control['bodies']) == 2 and control['bodies'][0] == control['bodies'][1]
            assert total() == 7

            # The held turn publishes the typed Table head, exact outcome, audit
            # and reply together; queue admission alone cannot satisfy this fault.
            committed.clear()
            control['mode'] = 'hold'
            s.command({'send': {'pid': requester, 'value': frame(b'5')}})
            once(requester_config)
            old = launch(proxied, once=False)
            assert committed.wait(timeout=60)
            old.kill(); old.wait(timeout=10)
            release.set()
            s.authority.kill(); s.authority.wait(timeout=10)
            s.store.stop(); s.store.start()
            s.authority = s.start(s.node, s.config)
            wait_ready(s.store.http, s.authority, s.url + '/health')
            s.command({'own': {'pid': ledger, 'worker': 1, 'expected_generation': 4}})
            current = {**ledger_config, 'generation': 5}
            once(ledger_config, success=False)
            pump_until(lambda: value(requester_resource, b'answer') == b'12', [requester_config])
            assert total() == 12
            s.command({'send': {'pid': requester, 'value': frame(b'-2')}})
            pump_until(lambda: value(requester_resource, b'answer') == b'10', [current, requester_config])
            assert total() == 10

            def upload_query():
                namespace = s.command({'send': {'pid': requester, 'value': frame(b'query')}})
                def queued():
                    incoming = s.native_query({'process': ledger})['body']['process']['input']
                    return incoming is not None and bytes.fromhex(incoming['value'])[13:17] == b'SPF1'
                pump_until(queued, [requester_config])
                return namespace
            # Drain leftover application self-wakes before sending a query. A
            # pending query call itself is captured only by the explicit step.
            def drain_ledger():
                idle_since = time.monotonic()
                deadline = idle_since + 60
                while time.monotonic() - idle_since < .2:
                    assert time.monotonic() < deadline
                    if s.native_query({'process': ledger})['body']['process']['input'] is not None:
                        once(current)
                        idle_since = time.monotonic()
                    else: time.sleep(.02)
            def phase(namespace):
                state = value(requester_resource, query_key('u', namespace))
                return state[76] if state else None
            drain_ledger()
            denied = upload_query()
            once(current)
            pump_until(lambda: phase(denied) == 6, [current, requester_config])
            assert value(requester_resource, b'answer') == b'station.query.error.QueryDenied'
            s.command({'send': {'pid': ledger, 'value': frame(b'allow-query')}})
            drain_ledger()

            namespace = upload_query()
            once(current)  # retain the actual schema-bound cut, before result staging
            s.command({'own': {'pid': ledger, 'worker': 1, 'expected_generation': 5}})
            current['generation'] = 6
            s.command({'own': {'pid': requester, 'worker': 2, 'expected_generation': 4}})
            requester_config['generation'] = 5
            pump_until(lambda: phase(namespace) == 4, [current, requester_config])
            assert value(requester_resource, b'last-query') == str(namespace).encode()
            result = query_result(value, requester, requester_resource, ledger, ledger_resource, namespace, [{'id': 1, 'amount': 10}])
            assert value(ledger_resource, query_key('j', result))[125] == 3
            drain_ledger()

            # Revoke policy between retained capture and the next self-input.
            namespace = upload_query()
            delivery_daemon.terminate(); delivery_daemon.wait(timeout=10)
            once(current)
            s.command({'send': {'pid': ledger, 'value': frame(b'deny-query')}})
            once(current)
            delivery_daemon = s.start(courier, delivery_config)
            pump_until(lambda: phase(namespace) == 6, [current, requester_config])
            assert value(requester_resource, b'answer') == b'station.query.error.QueryDenied'
            drain_ledger()

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
            print("Station: typed Table/audit/reply publication, call/reply, exact retries, captured views across policy changes, worker/store recovery, authorized captured Arrow replies, fencing and blocked-handler control passed.")
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
    lifetime(*sys.argv[1:5])

"""Actual v1 requester/source daemons, frozen signed upload and disk recovery."""
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


def run(node, host, proof, port_host, library, kinds=("kv", "table", "document"), sdks=(), shell=None, board=None, browser=False, lifecycle=False, example=None, console=None, console_tls=False, compound=False, counts=False):
    if compound and counts:
        raise ValueError('compound and value-count recovery use separate fixture profiles')
    if compound and any((board, browser, lifecycle, example, console, console_tls)):
        raise ValueError('compound recovery selects installed SDKs and the SQL shell; other profiles have separate schedules')
    node, host, proof, port_host, library = (str(Path(path).resolve()) for path in (node, host, proof, port_host, library))
    for kind in kinds:
        started = time.monotonic()
        with ColdStore() as cold, Fixture(cold.config()) as fixture:
            root = fixture.root
            fixture.env.update(LOG_FORMAT="json", LOG_LEVEL="info")
            from sdk_unified import install
            factories = install(root / 'installed', sdks) if sdks else []
            public = json.loads(subprocess.check_output([proof, "public"], timeout=10))
            port = free_port()
            url = f"http://127.0.0.1:{port}"
            node_config = root / "node.json"
            resident_pages = 64 if kind == "document" else 8
            node_config.write_text(json.dumps({"profile": "native_v1", "genesis": {"realm": 46, "root_key": public, "max_clock_error_ms": 10000}, "ursula_url": fixture.url, "bucket": "unified-query", "journal": "authority", "port": port, "resident_pages": resident_pages, "request_timeout_ms": 10000}))
            processes, logs = [], []
            native, port_client = None, None
            callers = []
            fault = {"lost": None, "retry": False, "stage": threading.Event(), "resume": threading.Event(),
                     "read_timeout": threading.Event(), "timed_out": threading.Event(), "console_sends": 0,
                     "console_delay": threading.Event(), "console_waiting": threading.Event(),
                     "seeding": True, "seed_phase": 0, "seed_request": None, "seed_receipt": None}

            class Proxy(BaseHTTPRequestHandler):
                def log_message(self, *_): pass
                def do_POST(self):
                    body = self.rfile.read(int(self.headers["Content-Length"]))
                    message = json.loads(body)
                    request = message.get("request", {})
                    command = request.get("command", {})
                    seed_turn = (fault['seeding'] and self.path == '/v1/command'
                                 and request.get('principal') == 65536
                                 and ('turn' in command or 'turn_with_versions' in command))
                    if seed_turn and fault['seed_phase'] == 0:
                        # Refuse the first prepared seed turn before forwarding.
                        # The next two attempts must keep these exact bytes.
                        fault['seed_request'] = body
                        fault['seed_phase'] = 1
                        data = b'{"err":"AuthorityUnavailable"}'
                        self.send_response(503)
                        self.send_header("Content-Length", str(len(data)))
                        self.end_headers()
                        self.wfile.write(data)
                        print(f"Unified {kind}: seed turn unavailable before submission", flush=True)
                        return
                    if seed_turn and fault['seed_phase'] in (1, 2):
                        assert body == fault['seed_request'], 'seed retry changed its signed request'
                    if self.path == '/v1/query' and message['query']['principal'] == 1234 and fault['console_delay'].is_set() and not fault['console_waiting'].is_set():
                        fault['console_waiting'].set()
                        time.sleep(2)
                    if self.path == '/v1/query' and message['query']['principal'] == 65537 and fault['read_timeout'].is_set() and not fault['timed_out'].is_set():
                        fault['timed_out'].set()
                        time.sleep(6)
                    connection = HTTPConnection("127.0.0.1", port, timeout=15)
                    try:
                        connection.request("POST", self.path, body, {"Content-Type": "application/json"})
                        response = connection.getresponse()
                        data = response.read()
                        status = response.status
                        if self.path == "/v1/command" and response.status == 200:
                            request = message["request"]
                            command = request["command"]
                            if request["principal"] == 1234 and "send" in command:
                                fault['console_sends'] += 1
                                payload = bytes.fromhex(command["send"]["value"])[13:]
                                if payload.startswith(b"UQP1"):
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
                        if hook := fault.get('count_hook'):
                            data = hook(self.path, message, body, response.status, data)
                        if hook := fault.get('console_hook'):
                            data = hook(self.path, message, data)
                        if seed_turn and status == 200:
                            if fault['seed_phase'] == 1:
                                # The mutation committed; hide its reply behind
                                # the same temporary error as an unknown outcome.
                                fault['seed_receipt'] = data
                                fault['seed_phase'] = 2
                                status, data = 503, b'{"err":"AuthorityUnavailable"}'
                            elif fault['seed_phase'] == 2:
                                assert data == fault['seed_receipt'], 'seed retry changed its committed receipt'
                                fault['seed_phase'] = 3
                        self.send_response(status)
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

            def restart(label='recovered', before_workers=None, after_stop=None):
                nonlocal source, requester, courier, authority
                for process in (source, requester, courier, authority):
                    if process.poll() is None: process.kill()
                    process.wait(timeout=10)
                if after_stop: after_stop()
                fixture.stop(); fixture.start()
                authority = start('node-' + label, [node, str(node_config)])
                wait_ready(fixture.http, authority, url + '/health')
                if before_workers: before_workers()
                for role in ('source', 'requester'):
                    generation = invoke('fence' if role == 'source' else 'fence-requester', direct=True)['generation']
                    path = root / (role + '.json')
                    config = json.loads(path.read_text()); config['generation'] = generation
                    path.write_text(json.dumps(config))
                source = start('source-' + label, [host, str(root / 'source.json')])
                requester = start('requester-' + label, [host, str(root / 'requester.json')])
                courier = start('courier-' + label, [host, str(root / 'courier.json')])

            try:
                subprocess.run([node, str(node_config), "--initialize"], check=True, capture_output=True, timeout=30, env=fixture.env)
                authority = start("node", [node, str(node_config)])
                wait_ready(fixture.http, authority, url + "/health")
                connection = invoke("provision-compound" if compound else "provision", kind, timeout=1800)
                assert fault['seed_phase'] == 3, 'seed unavailable/lost-reply schedule did not finish'
                fault['seeding'] = False
                print(f"Unified {kind}: seed retry preserved signed bytes and the original committed receipt", flush=True)
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
                inspectors = (native, port_client, *(caller for caller in callers if caller.inspection))
                scope = json.loads((root / 'shell.json').read_text())['workspace']
                inspection_requests = [{'inspect': {'scope': scope, 'sql': sql}} for sql in (
                    'DESCRIBE items;', 'SHOW TABLES;', 'EXPLAIN SELECT count(*) FROM items;',
                    "EXPLAIN SELECT value FROM items WHERE value = 'redacted-literal' LIMIT 18446744073709551615;",
                    'EXPLAIN SELECT value FROM items WHERE value IS TYPE_ERROR LIMIT 0;',
                    'EXPLAIN SELECT count(*) FROM items AS chosen;',
                    'EXPLAIN SELECT chosen.value FROM items AS chosen WHERE chosen.value IS TYPE_ERROR LIMIT 0;',
                    'EXPLAIN SELECT count(*) AS total FROM items AS chosen;',
                    'EXPLAIN SELECT count(chosen.value) AS present FROM items AS chosen;',
                    'EXPLAIN SELECT count(chosen.amount) FROM (SELECT value AS amount FROM items LIMIT 0) AS chosen;',
                    'EXPLAIN SELECT chosen.value AS "Result", chosen.value AS copy FROM items AS chosen WHERE chosen.value IS TYPE_ERROR LIMIT 0;')]
                program_inspectors = (native, port_client, *(caller for caller in callers if caller.predicate_programs))
                program_requests = [{'inspect': {'scope': scope, 'sql': sql}} for sql in (
                    "EXPLAIN SELECT value FROM items WHERE NOT (value IS NULL OR value = 'redacted-literal') AND value IS VALUE;",
                    'EXPLAIN SELECT value FROM items WHERE ' + 'NOT '*63 + 'value IS NULL;')]
                program_predicates = [
                    {'program': [{'atom': {'state': {'column': 'value', 'value': 'null'}}},
                        {'atom': {'compare': {'column': 'value', 'op': 'eq', 'type': {'utf8': {}}}}},
                        {'disjunction': {}}, {'negate': {}},
                        {'atom': {'state': {'column': 'value', 'value': 'value'}}}, {'conjunction': {}}]},
                    {'program': [{'atom': {'state': {'column': 'value', 'value': 'null'}}}] + [{'negate': {}}]*63},
                ]
                sends = fault['console_sends']
                for action in inspection_requests:
                    expected = None
                    for owner in inspectors:
                        value = owner.call(action)['inspection']
                        assert value['resource'] == connection['resource'] and value['name'] == 'items'
                        assert value['source_kind'] == kind and len(value['contract']) == len(value['schema']) == 32
                        assert int(value['policy_revision']) > 0
                        assert 'redacted-literal' not in json.dumps(value)
                        if expected is None: expected = value['details']
                        assert value['details'] == expected, (value['details'], expected)
                        if 'tables' in expected: assert expected['tables'] == (['items'] if kind == 'table' else [])
                        if 'explanation' in expected:
                            plan = expected['explanation']
                            if plan['aggregate'] == 'count_values':
                                assert plan['projection'] == ['value']
                                assert plan['columns'] == [{'name': 'present' if 'AS present' in action['inspect']['sql'] else 'count', 'type': {'uint64': {}}, 'nullable': False, 'optional': False}]
                                assert plan['operators'] == (['scan', 'limit', 'count_values'] if 'LIMIT 0' in action['inspect']['sql'] else ['scan', 'count_values'])
                            elif plan['aggregate'] == 'count':
                                assert plan['columns'] == [{'name': 'total' if 'AS total' in action['inspect']['sql'] else 'count', 'type': {'uint64': {}}, 'nullable': False, 'optional': False}]
                            elif 'state' in plan['predicate']:
                                assert plan['limit'] == '0' and plan['predicate'] == {'state': {'column': 'value', 'value': 'type_error'}}
                                assert plan['operators'] == ['scan', 'filter', 'limit', 'project']
                                if 'AS "Result"' in action['inspect']['sql']:
                                    assert plan['projection'] == ['value', 'value']
                                    assert plan['columns'] == [{'name': name, 'type': {'utf8': {}}, 'nullable': True, 'optional': kind != 'table'} for name in ('Result', 'copy')]
                            else: assert plan['limit'] == str(2**64-1) and plan['operators'] == ['scan', 'filter', 'limit', 'project'], plan
                for action, predicate in zip(program_requests, program_predicates, strict=True):
                    expected = None
                    for owner in program_inspectors:
                        value = owner.call(action)['inspection']
                        assert value['resource'] == connection['resource'] and value['name'] == 'items'
                        assert value['source_kind'] == kind and 'redacted-literal' not in json.dumps(value)
                        plan = value['details']['explanation']
                        assert plan['predicate'] == predicate and plan['operators'] == ['scan', 'filter', 'project']
                        assert plan['columns'] == [{'name': 'value', 'type': {'utf8': {}}, 'nullable': True, 'optional': kind != 'table'}] and plan['limit'] is None
                        if expected is None: expected = value
                        assert value == expected
                print(f"Unified {kind}: Boolean inspection including 64 instructions agrees across {len(program_inspectors)} enabled native/port/SDK callers", flush=True)
                assert sends == fault['console_sends'], 'inspection submitted query work'
                print(f"Unified {kind}: SQL inspection agrees across {len(inspectors)} enabled native/port/SDK callers", flush=True)
                if compound:
                    action = {'next': dict(namespace='1', bundle=(root/'bundle.bin').read_bytes().hex())}
                    prepared = native.call(action)['prepared']
                    assert prepared is not None
                    for owner in (port_client, *callers):
                        assert owner.call(action)['prepared'] == prepared, 'compound preparation changed signed identity'
                    assert sends == fault['console_sends'], 'preparation submitted query work'
                    print(f"Unified {kind}: compound bundle and original prepared identity agree across {2+len(callers)} callers", flush=True)
                from unified_parameters import compile_requests, rejected as compilation_rejected
                compilers = (native, port_client, *(caller for caller in callers if caller.compilation))
                compilation_requests = compile_requests(compilers, scope, kind, root, fault, capability_owners=(native, port_client))
                print(f"Unified {kind}: parameter compilation agrees across {len(compilers)} native/port/SDK callers with literal SQL and frozen bundle bytes; no dispatch", flush=True)
                uploader = callers[0] if callers else native
                try:
                    upload(uploader, root)
                    raise AssertionError('lost upload response was reported as success')
                except Failure as failure:
                    assert failure.status == 6 and failure.detail['err'] == 'InvalidAuthorityResponse', failure
                    diagnostic = failure.detail['diagnostic']
                    assert diagnostic['outcome'] == 'unknown' and diagnostic['evidence'] == 'saved_intent', diagnostic
                    assert [a['kind'] for a in diagnostic['actions'] if a] == ['inspect_status', 'resume_exact'], diagnostic
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
                restart()
                print(f"Unified {kind}: restarted source, requester, node and disk store after segment staging", flush=True)
                until = time.monotonic() + 900
                while True:
                    status = invoke("status", timeout=15)
                    if status and status["phase"] == "complete": break
                    assert status and status["phase"] == "admitted", status
                    assert time.monotonic() < until, status
                    assert source.poll() is None and requester.poll() is None, "query worker exited"
                    time.sleep(0.2)
                print(f"Unified {kind}: complete manifest after {time.monotonic() - started:.2f}s", flush=True)
                fault['read_timeout'].set()
                assert fault['timed_out'].wait(timeout=20), 'requester did not perform a current read'
                time.sleep(6)
                assert requester.poll() is None, 'transient read timeout killed requester'
                assert 'AuthorityTimeout' in (root/'requester-recovered.log').read_text()
                first = invoke("page")
                assert not first["complete"] and first["rows"] > 0
                saved = (root / "cursor.json").read_bytes()
                invoke("revoke", direct=True)
                invoke("page", error="AccessDenied")
                compilation_rejected(compilers, compilation_requests)
                for owner in inspectors:
                    for action in inspection_requests + (program_requests if owner in program_inspectors else []):
                        try:
                            owner.call(action)
                            raise AssertionError('revoked SQL inspection succeeded')
                        except Failure as failure:
                            assert failure.status == 4, failure
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
                        row['optional'] = dict(state=0, kind=0, value=None, alternatives=[])
                if compound:
                    # Independent oracle: the compound program excludes exactly
                    # the last two input values, without renumbering Document IDs.
                    expected = expected[:-2]
                named_expected = [{('Result' if name == 'value' else name): cell for name, cell in row.items()} for row in expected]
                assert actual == named_expected, actual[:2]
                assert total > 8192
                assert kind == "document" or len(actual) > 32
                manifest = final["manifest"]
                assert manifest["job"]["correlation"] == status["correlation"]
                assert manifest["checkpoint"]["cut"]["kind"] == kind
                assert manifest["checkpoint"]["bytes"] == total
                verify(native, port_client, root, final['ordinal']+1)
                for owner in callers: verify(owner, owner, root, final['ordinal']+1)
                if counts:
                    from unified_counts import check
                    check(native, port_client, callers, root, invoke, restart, fault, kind)
                if shell:
                    from unified_shell import check
                    shell_config = json.loads((root / 'shell.json').read_text())
                    shell_config['url'] = proxy_url
                    (root / 'shell.json').write_text(json.dumps(shell_config))
                    check(shell, root, kind, invoke, expected, fault, compound=compound, counts=counts)
                if board:
                    from unified_board import check
                    check(board, root, kind, invoke, expected, fixture, start, browser=browser)
                if console:
                    from console import check
                    console_config = json.loads((root / 'shell.json').read_text())
                    console_config['url'] = proxy_url
                    check(console, root, kind, invoke, expected, fault, console_config, tls=console_tls)
                if lifecycle:
                    from unified_failures import check as failure_check
                    failure_check(native, port_client, callers, root, invoke, restart, fault, kind)
                    from unified_parameters import uncertain_commands
                    uncertain_commands((native, port_client, *callers), native, fault)
                    from unified_lifecycle import check
                    check(native, root, invoke, fault, kind)
                if example:
                    from unified_example import check
                    check(example, root, native, fault, kind)
                for role in ('source', 'requester', 'courier'):
                    records = []
                    for line in (root / (role+'-recovered.log')).read_text().splitlines():
                        try: record = json.loads(line)
                        except json.JSONDecodeError: continue
                        if record.get('service_name') == 'transit-query-host': records.append(record)
                    assert any(r.get('event', {}).get('name') == 'service.ready' for r in records), role
                    if role != 'courier':
                        assert any(r.get('event', {}).get('name') == 'query.worker.step' and
                                   r['event'].get('protocol_outcome') == 'receipt' for r in records), role
                    serialized = json.dumps(records, ensure_ascii=False)
                    assert '東京' not in serialized and 'UQP1' not in serialized
                    for seed in ('08', '09', '0a', '0b'): assert seed*32 not in serialized
                after = None
                position = None
                while True:
                    versions = invoke("versions", *([json.dumps(after), str(position)] if after else []), direct=True)
                    assert all(version["released_at"] is not None for version in versions["entries"] if version)
                    if versions['next'] is None:
                        break
                    assert versions['next'] != after, 'read-version pagination did not advance'
                    after = versions['next']
                    position = versions['position']
                invoke('retire-source', direct=True)
                compilation_rejected(compilers, compilation_requests, retired=True)
                # Native/port expose the mapped client error; typed SDKs retain
                # the more specific authority rejection in their public code.
                retired_errors = ('QuerySourceUnavailable', 'ResourceUnavailable', 'Rejected', 'AccessDenied', 'StateResourceExpired')
                for owner in inspectors:
                    for action in inspection_requests + (program_requests if owner in program_inspectors else []):
                        try:
                            owner.call(action)
                            raise AssertionError('retired source disclosed SQL metadata')
                        except Failure as failure:
                            assert failure.detail['err'] in retired_errors, failure
                for owner in (native, port_client, *callers):
                    try:
                        owner.call({'page': {'namespace': '1', 'cursor': None}})
                        raise AssertionError('retired source disclosed a completed result')
                    except Failure as failure:
                        assert failure.detail['err'] in retired_errors, failure
                assert cold.data_objects() > 0
                print(f"Unified {kind}: {len(actual)} rows / {final['ordinal'] + 1} segments / {total} bytes / {resident_pages} resident authority pages / 8 MiB hot store / {cold.data_objects()} cold objects / {cold.file_bytes()} cold bytes / predicate={'compound' if compound else 'atom'} / installed SDKs={','.join(sdks) or 'none'}; frozen upload retry, worker/node/store recovery, prefix revocation and released source pin passed in {time.monotonic() - started:.2f}s", flush=True)
            except BaseException:
                for log in logs:
                    log.flush(); log.seek(0)
                    print(f"{log.name}:\n{log.read()[-5000:]}", file=sys.stderr)
                raise
            finally:
                fault["resume"].set()
                if release := fault.get('count_release'): release.set()
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
    parser.add_argument('--sdk', action='append', choices=('python', 'node', 'ruby', 'rust', 'c', 'cpp', 'java', 'dotnet', 'erlang', 'elixir'))
    parser.add_argument('--shell')
    parser.add_argument('--compound', action='store_true')
    parser.add_argument('--console')
    parser.add_argument('--console-tls', action='store_true')
    parser.add_argument('--board')
    parser.add_argument('--browser', action='store_true')
    parser.add_argument('--lifecycle', action='store_true')
    parser.add_argument('--counts', action='store_true')
    parser.add_argument('--expiry', action='store_true')
    parser.add_argument('--example')
    args = parser.parse_args()
    if args.compound and args.expiry:
        parser.error('--compound and --expiry select separate schedules')
    if args.expiry:
        from unified_expiry import run as expiry
        expiry(args.node, args.host, args.proof, args.library, args.kinds or ('kv', 'table', 'document'))
        raise SystemExit(0)
    run(args.node, args.host, args.proof, args.port_host, args.library,
        kinds=args.kinds or ('kv', 'table', 'document'), sdks=args.sdk or (), shell=args.shell,
        board=args.board, browser=args.browser, lifecycle=args.lifecycle, example=args.example, console=args.console, console_tls=args.console_tls, compound=args.compound, counts=args.counts)

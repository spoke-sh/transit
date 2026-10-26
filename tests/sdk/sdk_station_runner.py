"""Shared real-authority schedule for installed public Station runners."""
from runner.paths import ROOT
from dataclasses import dataclass
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import select
import shutil
import struct
import subprocess
import tempfile
import threading
import time
from typing import Callable


@dataclass
class Consumer:
    environment: dict[str, str]
    command: Callable[[str, Path], list]
    cli: Callable[[Path, str], list]
    invalid_handler: str
    extra_failures: tuple[str, ...] = ()
    arrow_adapter: bool = True


def run(node, cli, raw_library, install, label, *, decode_block_repetitions=1, failures_only=False):
    from cold_storage import ColdStore
    # Retained framework/application history needs cold storage. The fixture
    # keeps provider hot memory at 8 MiB rather than raising hot-only capacity.
    with ColdStore() as cold:
        _run(node, cli, raw_library, install, label, cold,
             decode_block_repetitions=decode_block_repetitions, failures_only=failures_only)


def _run(node, cli, raw_library, install, label, cold, *, decode_block_repetitions=1, failures_only=False):
    if not 1 <= decode_block_repetitions <= 1024:
        raise ValueError('decode-block repetitions must be in 1..1024')
    from sdk.client_abi_growing import GrowingSystem
    from sdk.client_abi import Native
    from station import frame
    from sdk.sdk_scenarios import check
    root = ROOT
    fixture = GrowingSystem(node, cli, storage_config=cold.config())
    fixture.resident_pages = 64
    with tempfile.TemporaryDirectory(prefix='transit-station-consumer-') as temporary, fixture as system:
        target = Path(temporary)
        consumer = install(target)
        env = consumer.environment
        codec_fixture = target / 'codecs.json'
        shutil.copyfile(root / 'tests/sdk/sdk-codecs-v1.json', codec_fixture)
        table_fixture = target / 'table-codecs.json'
        shutil.copyfile(root / 'tests/sdk/sdk-table-work-v1.json', table_fixture)
        http_fixture = target / 'http-codecs.json'
        shutil.copyfile(root / 'packages/zig/transit-station-http/src/admission-fixtures.json', http_fixture)
        http_release_fixture = target / 'http-release-codecs.json'
        shutil.copyfile(root / 'packages/zig/transit-station-http/src/release-fixtures.json', http_release_fixture)
        native = Native(raw_library)
        admin = native.client(system.url)
        private = bytes.fromhex(system.seed.read_text().strip())
        sequence, principal = 0, 65536
        def command(body):
            nonlocal sequence
            sequence += 1
            op = native.prepare(6, private, {'realm': 72, 'principal': 0, 'sequence': sequence, 'command': body})
            try:
                deadline = time.monotonic() + 30
                while True:
                    status, response = native.exchange(admin, op)
                    if status == 0:
                        return response['position']
                    assert status in (6, 7) and time.monotonic() < deadline, (status, response)
                    # An ambiguous acknowledgement retains this exact signed
                    # operation; fixture recovery never allocates a new sequence.
                    time.sleep(.05)
            finally: native.lib.transit_operation_destroy(op)
        def read(kind):
            op = native.prepare(7, private, {'realm': 72, 'principal': 0, 'kind': kind})
            try:
                deadline = time.monotonic() + 30
                while True:
                    status, response = native.exchange(admin, op)
                    if status == 0:
                        return response
                    assert status in (6, 7) and time.monotonic() < deadline, (status, response)
                    time.sleep(.05)
            finally: native.lib.transit_operation_destroy(op)
        fault = {'drop': False, 'delay': False, 'poison': False, 'commands': [], 'poisoned': False,
                 'unavailable_reply': False, 'unavailable_replies': 0,
                 'unavailable_process': None, 'unavailable_reads': 0}
        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_): pass
            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                conn = HTTPConnection('127.0.0.1', system.port, timeout=30)
                try:
                    if self.path == '/v1/command':
                        # Retain attempts even if the upstream response arrives
                        # after the host's deadline.
                        fault['commands'].append(body)
                    # BaseHTTPRequestHandler normalizes leading double slashes in self.path.
                    # Preserve the original target so faults cannot hide malformed SDK URLs.
                    target = self.raw_requestline.split()[1].decode('ascii')
                    conn.request('POST', target, body, {'Content-Type': 'application/json'})
                    result = conn.getresponse()
                    data = result.read()
                    status = result.status
                    if self.path == '/v1/command':
                        mutation = json.loads(body)['request']['command']
                        if ('turn' in mutation or 'turn_with_versions' in mutation) and result.status == 200:
                            if fault['delay']:
                                fault['delay_marker'].touch()
                                time.sleep(0.7)
                            if fault['drop']:
                                fault['drop'] = False
                                self.close_connection = True
                                return
                            if fault['unavailable_reply']:
                                fault['unavailable_reply'] = False
                                fault['unavailable_replies'] += 1
                                status, data = 503, b'{"err":"AuthorityUnavailable"}'
                    elif self.path == '/v1/query':
                        query = json.loads(body)['query']['kind']
                        if (status == 200 and fault['unavailable_process'] is not None and
                                query.get('process') == fault['unavailable_process']):
                            fault['unavailable_process'] = None
                            fault['unavailable_reads'] += 1
                            status, data = 503, b'{"err":"AuthorityUnavailable"}'
                        elif (fault['poison'] and not fault['poisoned'] and
                              'entries' in query and query['entries'].get('key') == b'total'.hex()):
                            parsed = json.loads(data)
                            parsed['realm'] += 1
                            data = json.dumps(parsed).encode()
                            fault['poisoned'] = True
                    self.send_response(status)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                finally: conn.close()
        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        children, worker_configs = [], {}
        recovered_events, repeated_reads = 0, 0
        def provision(role='service', finite=False, lifetime_ms=240000):
            nonlocal principal
            principal += 1
            now = time.time_ns() // 1_000_000
            pid = command({'spawn': {'work_before_ms': now+lifetime_ms, 'settle_before_ms': now+lifetime_ms+30000} if finite else {}})
            seed, public = system.key(f'public-{principal}')
            command({'grant': {'subject': principal, 'public_key': public, 'permissions': 88, 'pid': pid}})
            resource = command({'create_resource': {'writer': pid}})
            for subject in (0, principal): command({'grant_resource': {'resource': resource, 'subject': subject, 'permissions': 7}})
            command({'associate': {'pid': pid, 'name': b'data'.hex(), 'resource': resource}})
            command({'own': {'pid': pid, 'worker': principal, 'expected_generation': 1}})
            output = target / f'output-{pid}'
            output.mkdir()
            cfg = {'url': url, 'realm': 72, 'principal': principal, 'pid': pid, 'generation': 2,
                'seed_file': str(seed), 'profile': 'native_v1', 'peer': pid, 'role': role, 'resource': resource,
                'pending': str(target / f'pending-{pid}'), 'output': str(output), 'fixtures': str(codec_fixture), 'http_fixtures': str(http_fixture), 'http_release_fixtures': str(http_release_fixture),
                'table_fixtures': str(table_fixture),
                'query_results': role in ('table', 'query'), 'work_before_ms': now+lifetime_ms if finite else None,
                'settle_before_ms': now+lifetime_ms+30000 if finite else None}
            return cfg
        def config_file(cfg):
            path = target / f"config-{cfg['pid']}.json"
            path.write_text(json.dumps(cfg))
            return path
        def invoke(mode, cfg):
            return subprocess.check_output(consumer.command(mode, config_file(cfg)), env=env, cwd=target, timeout=90, text=True)
        def worker(cfg):
            child = subprocess.Popen(consumer.command('worker', config_file(cfg)), stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=env, cwd=target, text=True)
            children.append(child)
            worker_configs[child.pid] = cfg
            return child
        def one(child, action='one', deadline=None):
            remaining = 180 if deadline is None else deadline - time.monotonic()
            assert remaining > 0, 'Public runner recovery deadline'
            child.stdin.write(action + '\n'); child.stdin.flush()
            assert select.select([child.stdout], [], [], remaining)[0], 'Public runner timed out'
            value = child.stdout.readline()
            assert value, f'Worker failed with {child.poll()}'
            return json.loads(value)
        def expect_one(child, *events):
            nonlocal recovered_events, repeated_reads
            deadline = time.monotonic() + 180
            observed = one(child, deadline=deadline)
            for _ in range(8):
                if observed['event'] in events:
                    return
                transient = observed.get('code') in ('AuthorityTimeout', 'AuthorityUnavailable', 'HttpCapacity')
                if observed['event'] == 'ReadUnavailable' and transient:
                    observed = one(child, deadline=deadline)
                    repeated_reads += 1
                    continue
                assert (observed['event'] == 'NeedsRecovery' and
                        observed['phase'] in ('dispatch', 'observe_confirmation') and
                        transient), {
                            'expected': events, 'observed': observed}
                saved = Path(worker_configs[child.pid]['pending'])
                frozen = saved.read_bytes()
                signed = json.loads(frozen)['operation']['growing_command']
                request = signed['request']
                def attempts():
                    matching = []
                    for body in fault['commands']:
                        candidate = json.loads(body)['request']
                        if all(candidate[key] == request[key] for key in ('realm', 'principal', 'sequence')):
                            matching.append(body)
                    return matching
                original = attempts()
                # Frozen operations own an optional block body. The transport
                # omits that field only when the saved envelope has no body;
                # populated bodies must still match the attempted bytes.
                expected_wire = signed.copy()
                if expected_wire['blocks'] is None:
                    del expected_wire['blocks']
                assert original and json.loads(original[0]) == expected_wire
                # A paused runner cannot silently advance or replace accepted
                # work. Reconcile the saved operation through the host API.
                assert one(child, deadline=deadline) == observed
                assert saved.read_bytes() == frozen
                observed = one(child, 'reconcile', deadline)
                assert all(body == original[0] for body in attempts()), 'Recovery changed signed bytes'
                recovered_events += 1
            assert observed['event'] in events, {'recovery_budget_exhausted': observed}
        def close(child):
            child.stdin.write('close\n'); child.stdin.flush()
            assert json.loads(child.stdout.readline()) == {'closed': True}
            child.stdin.close()
            assert child.wait(timeout=15) == 0
            child.stdout.close()
            children.remove(child)
        def send(cfg, payload): return command({'send': {'pid': cfg['pid'], 'value': frame(payload)}})
        def own(cfg):
            command({'own': {'pid': cfg['pid'], 'worker': cfg['principal'], 'expected_generation': cfg['generation']}})
            cfg['generation'] += 1
        after = None
        def deliver():
            nonlocal after
            position = read({'capabilities': {}})['position']
            batch = read({'outputs': {'after': after, 'position': position}})['body']['outputs']
            for value in batch['entries']:
                if value:
                    if value['phase'] == 'pending': command({'deliver': value['id']})
                    after = value['id']
        def process(cfg): return read({'process': cfg['pid']})['body']['process']['process']
        def state_value(cfg, key):
            revision = read({'resource': cfg['resource']})['body']['resource']['revision']
            page = read({'entries': {'resource': cfg['resource'], 'revision': revision,
                                     'key': key.hex()}})['body']['entries']['page']['entries']
            return next((bytes.fromhex(entry['value']) for entry in page
                         if entry and bytes.fromhex(entry['key']) == key), None)
        def queued_command(cfg, payload):
            # Handler input.position is the admission's global log position;
            # process.admitted/consumed are mailbox ordinals, not identities.
            return send(cfg, payload)
        table_steps = 0
        def drain_table(cfg, child, expected):
            nonlocal table_steps
            # Current authorization adds work to every native fixture read/turn.
            # This finite observer budget is calibrated by the recorded Ruby and
            # Erlang schedules, not a latency promise or resident/backlog limit.
            # Every callback still has four writes; the turn ceiling is unchanged.
            started = time.monotonic()
            budget_seconds = 1200
            for turns in range(4096):
                meta = state_value(cfg, b'table.queue')
                assert meta and len(meta) == 21 and meta[:4] == b'TQM\x01'
                if meta[4:] == bytes(16) + b'\1': break
                elapsed = time.monotonic() - started
                if turns % 50 == 0:
                    print(json.dumps(dict(profile='sdk_table_queue', language=label,
                        phase='draining', seconds=round(elapsed, 3), turns=turns,
                        budget_seconds=budget_seconds)), flush=True)
                assert elapsed < budget_seconds, (
                    label, 'Queued Table work did not complete',
                    dict(seconds=elapsed, turns=turns, budget_seconds=budget_seconds))
                deliver()
                expect_one(child, 'Committed', 'Idle')
                table_steps += 1
            else: raise AssertionError('Queued Table turn budget exhausted')
            drained_seconds = time.monotonic() - started
            outcomes = []
            for operation, state, matched, changed, rejection in expected:
                raw = state_value(cfg, f'table.done.{operation:016x}'.encode())
                assert raw and len(raw) == 38 and raw[:4] == b'TQO\x01', (operation, raw)
                actual, admitted, completed, m, c, r = struct.unpack('<BQQQQB', raw[4:])
                assert (actual, m, c, r) == (state, matched, changed, rejection), (operation, raw.hex())
                assert 0 < admitted <= completed < read({'process': cfg['pid']})['position']
                assert state_value(cfg, f'table.work.{operation:016x}'.encode()) is None
                outcomes.append((admitted, completed))
            assert all(left[1] <= right[0] for left, right in zip(outcomes, outcomes[1:])), outcomes
            print(json.dumps(dict(profile='sdk_table_queue', language=label,
                phase='verified', drain_seconds=round(drained_seconds, 3),
                total_seconds=round(time.monotonic() - started, 3), turns=turns,
                outcomes=len(outcomes), budget_seconds=budget_seconds)), flush=True)
        def negative_queries():
            # The raw sender uses ordinary authorized native turns, exercising
            # typed SDK ingress independently of the native capture unit tests.
            source = command({'spawn': {}})
            source_state = read({'process': source})['body']['process']['process']
            command({'own': {'pid': source, 'worker': 0, 'expected_generation': source_state['generation']}})
            def emit(requester, correlation, result, reason):
                view = read({'process': source})['body']['process']
                command({'turn': {'pid': source, 'generation': view['process']['generation'],
                    'input': view['input']['position'], 'expected_revision': view['process']['revision'],
                    'outputs': [{'pid': requester['pid'], 'value': frame(b'GQE1' + struct.pack('<QB', result, reason), 9, correlation)}, None, None, None]}})
                deliver()
            observed_reasons, closed_after_replacement = [], []
            for reason in range(1, 6):
                requester = provision('query'); requester['peer'] = source
                child = worker(requester)
                correlation = send(requester, b'TSQ\x01\x04')
                expect_one(child, 'Committed'); deliver()
                admitted = read({'process': source})['body']['process']['input']['position']
                emit(requester, correlation, admitted, reason)
                if reason == 1:
                    fault['unavailable_reply'] = True
                    fault['unavailable_process'] = requester['pid']
                expect_one(child, 'Committed')
                # Callback writes commit with the native terminal wait evidence.
                assert state_value(requester, b'total') == b'TSU\x01' + struct.pack('<Q', 1)
                assert state_value(requester, b'observed') == b'TSU\x01' + struct.pack('<Q', reason)
                assert state_value(requester, b'\0Qh' + struct.pack('>QQH', correlation, 0, 0)) == b'GQE1' + struct.pack('<QB', admitted, reason)
                assert process(requester)['failure'] is None
                close(child)
                own(requester)
                child = worker(requester)
                # A replacement sees the closed wait; a later source output may
                # not invoke another callback or overwrite the first outcome.
                command({'send': {'pid': source, 'value': frame(b'duplicate')}})
                emit(requester, correlation, admitted, 5 if reason != 5 else 3)
                expect_one(child, 'Committed')
                assert state_value(requester, b'total') == b'TSU\x01' + struct.pack('<Q', 1)
                assert state_value(requester, b'observed') == b'TSU\x01' + struct.pack('<Q', reason)
                assert process(requester)['failure'] is None and process(requester)['consumed'] == 3
                observed_reasons.append(int.from_bytes(state_value(requester, b'observed')[4:], 'little'))
                closed_after_replacement.append(process(requester)['consumed'])
                close(child)
            assert fault['unavailable_replies'] == 1 and fault['unavailable_reads'] == 1 and recovered_events >= 1
            check('typed-query-failures', {'reason_codes': observed_reasons,
                'consumed_after_replacement': closed_after_replacement,
                'lost_receipts': fault['unavailable_replies'], 'unavailable_reads': fault['unavailable_reads'],
                'exact_recovery': recovered_events >= 1})
            print(f'{label} Station: five authenticated typed query failures, exact lost-receipt recovery and duplicate suppression after replacement passed.')
        try:
            negative_queries()
            if os.environ.get('TRANSIT_TEST_QUERY_FAILURES_ONLY') == '1': return
            gated = provision(finite=True)
            invoke('codecs', gated)
            send(gated, b'TSC\x01\x01' + (2**53+1).to_bytes(8, 'little'))
            gates = json.loads(invoke('gates', gated))
            assert gates['gates'] == ['commit', 'open', 'permit']
            assert process(gated)['consumed'] == 1
            for mode in ('decode-stop', *('decode-block',) * decode_block_repetitions,
                         'handler-stop', 'handler-block', consumer.invalid_handler, *consumer.extra_failures):
                cfg = provision()
                send(cfg, b'TSC\x02\x02' if mode.startswith('decode-') else b'TSC\x01\x01' + (1).to_bytes(8, 'little'))
                invoke(mode, cfg)
                state = process(cfg)
                assert state['consumed'] == 0 and (state['failure'] is not None) == mode.endswith('-block')
                assert read({'resource': cfg['resource']})['body']['resource']['entries'] == 0
            if failures_only:
                print(f'{label} Station lifetime: {decode_block_repetitions} fresh decode-block cases, '
                      'codec/handler failures, retained native mappings and bounded image reuse passed.')
                return
            async_cfg = provision()
            send(async_cfg, b'TSC\x01\x01' + (5).to_bytes(8, 'little'))
            fault['delay_marker'] = Path(async_cfg['output'], 'accepted')
            fault['delay'] = True
            assert json.loads(invoke('async', async_cfg))['committed']
            fault['delay'] = False
            assert process(async_cfg)['consumed'] == 1
            # Unknown accepted commit survives abrupt host loss and exact raw recovery.
            source, requester = provision(), provision('requester')
            requester['peer'] = source['pid']
            send(source, b'TSC\x01\x01' + (2**64-1).to_bytes(8, 'little'))
            service = worker(source)
            fault['drop'] = True
            expect_one(service, 'NeedsRecovery')
            accepted = fault['commands'][-1]
            service.kill(); service.wait(timeout=10); children.remove(service)
            system.authority.kill(); system.authority.wait(timeout=10)
            system.store.stop(); system.store.start()
            system.authority = system.start(node, system.config)
            from harness.services import wait_ready
            wait_ready(system.store.http, system.authority, system.url + '/health')
            seed_path = Path(source['seed_file'])
            saved_seed = seed_path.read_bytes(); seed_path.unlink()
            invoke('recover', source)
            exact_commit_retry = fault['commands'][-1] == accepted
            assert exact_commit_retry and process(source)['consumed'] == 1
            seed_path.write_bytes(saved_seed)
            own(source)
            send(requester, b'TSC\x01\x03')
            caller = worker(requester)
            expect_one(caller, 'Committed')
            waiting = read({'process': requester['pid']})['body']['process']
            close(caller)
            own(requester)
            deliver()
            # Run the installed documented CLI, rather than a test-only handler.
            subprocess.run(consumer.cli(config_file(source), 'service'), env=env, cwd=target, check=True, timeout=60, stdout=subprocess.DEVNULL)
            deliver()
            subprocess.run(consumer.cli(config_file(requester), 'requester'), env=env, cwd=target, check=True, timeout=60, stdout=subprocess.DEVNULL)
            assert process(requester)['consumed'] == 2
            revision = read({'resource': requester['resource']})['body']['resource']['revision']
            entries = read({'entries': {'resource': requester['resource'], 'revision': revision, 'key': b'observed'.hex()}})['body']['entries']['page']['entries']
            observed = next(entry for entry in entries if entry)
            assert bytes.fromhex(observed['value']) == b'TSU\x01' + (2**64-1).to_bytes(8, 'little')
            check('durable-continuation', {
                'observed_wide_integer': str(int.from_bytes(bytes.fromhex(observed['value'])[4:], 'little')),
                'source_admitted': waiting['process']['admitted'] == 1,
                'source_turn_completed_before_reply': waiting['process']['consumed'] == 1 and waiting['input'] is None,
            })
            old = dict(source)
            own(source)
            invoke('stale', old)
            # A caught failed read must still abort the whole private turn.
            send(source, b'TSC\x01\x01' + (0).to_bytes(8, 'little'))
            fault['poison'] = True
            invoke('poison', source)
            assert fault['poisoned'] and process(source)['consumed'] == 2
            fault['poison'] = False
            command({'revoke': source['principal']})
            invoke('denied', source)
            # Bounded Table pages, retained point reads and multi-segment IPC.
            # This case proves the installed runner reports permanent expiry,
            # not a two-second provisioning SLA. Establish the entire finite
            # activation before its work cutoff, including this fixture's 10s
            # admitted clock uncertainty. The later check waits past the exact
            # recorded cutoff; no accepted deadline is renewed or rewritten.
            expired = provision(finite=True, lifetime_ms=30000)
            table, query_cfg = provision('table'), provision('query')
            table['peer'], query_cfg['peer'] = query_cfg['pid'], table['pid']
            service, caller = worker(table), worker(query_cfg)
            assert one(service, 'ready') == {'ready': True}
            initialization = queued_command(table, b'TSQ\x01\x01')
            # Deterministically exercise the same uncertain outcome observed
            # under storage latency, after this queue turn has been accepted.
            before_recovery = recovered_events
            before_reply_faults, before_read_faults = fault['unavailable_replies'], fault['unavailable_reads']
            before_reads = repeated_reads
            fault['unavailable_process'] = table['pid']
            fault['unavailable_reply'] = True
            expect_one(service, 'Committed')
            assert fault['unavailable_replies'] == before_reply_faults + 1 and recovered_events > before_recovery
            assert fault['unavailable_reads'] == before_read_faults + 1 and repeated_reads > before_reads
            assert process(table)['consumed'] == 1
            assert state_value(table, f'table.done.{initialization:016x}'.encode()) is None
            expected_table = [(initialization, 0, 0, 0, 0)]
            for index in range(41):
                key = -(2**63) if index == 0 else index
                value = None if index % 5 == 0 else 2**63-1 if index == 1 else 2**53+1
                payload = b'TSQ\x01\x02' + key.to_bytes(8, 'little', signed=True)
                payload += b'\0' if value is None else b'\1' + value.to_bytes(8, 'little', signed=True)
                operation = queued_command(table, payload)
                expect_one(service, 'Committed')
                expected_table.append((operation, 1, 1, 1, 0))
            # A duplicate is a terminal domain rejection; later accepted work
            # remains queued and must continue after it.
            duplicate = queued_command(table, b'TSQ\x01\x02' + struct.pack('<qBq', 1, 1, 2))
            expect_one(service, 'Committed')
            expected_table.append((duplicate, 2, 0, 0, 1))
            inserted = queued_command(table, b'TSQ\x01\x02' + struct.pack('<qBq', 99, 1, 9))
            expect_one(service, 'Committed')
            expected_table.append((inserted, 1, 1, 1, 0))
            deleted = queued_command(table, b'TSQ\x01\x08' + struct.pack('<q', 99))
            expect_one(service, 'Committed')
            expected_table.append((deleted, 1, 1, 1, 0))
            send(query_cfg, b'TSQ\x01\x04')
            expect_one(caller, 'Committed')
            for _ in range(30):
                deliver()
                expect_one(service, 'Committed', 'Idle')
                expect_one(caller, 'Committed', 'Idle')
                if state_value(query_cfg, b'not-ready') is not None: break
            else: raise AssertionError('Busy Table did not reply NotReady')
            assert not Path(query_cfg['output'], 'manifest.json').exists()
            assert state_value(table, f'table.done.{deleted:016x}'.encode()) is None
            # Replace the host with accepted work still in durable FIFO state.
            close(service)
            own(table)
            service = worker(table)
            drain_table(table, service, expected_table)
            send(table, b'TSQ\x01\x03')
            expect_one(service, 'Committed')
            updated = queued_command(table, b'TSQ\x01\x07' + struct.pack('<qBq', -(2**63), 1, 17))
            expect_one(service, 'Committed')
            drain_table(table, service, [(updated, 1, 1, 1, 0)])
            print(f'{label} Table queue: {len(expected_table)+1} terminal outcomes, FIFO after rejection/host replacement, explicit busy reply, insert/update/delete/defaults, {table_steps} drain turns.', flush=True)
            send(table, b'TSQ\x01\x01')
            expect_one(service, 'Committed')
            send(query_cfg, b'TSQ\x01\x04')
            expect_one(caller, 'Committed')
            close(caller)
            own(query_cfg)
            caller = worker(query_cfg)
            manifest_file = Path(query_cfg['output']) / 'manifest.json'
            # Six logical IPC streams can each occupy 65,535 bytes. Capture
            # stages three 221-byte fragments per turn; receipt processes one
            # fragment per input. Add bounded sealing/publication/credit work.
            # The previous 150-round fixture covered only two scalar columns.
            fragments = (65535 + 220) // 221
            query_round_limit = 6 * (fragments + (fragments + 2) // 3 + 8) + 16
            query_started = time.monotonic()
            query_budget_seconds = 600
            query_times = dict(delivery=0.0, service=0.0, caller=0.0)
            for query_round in range(query_round_limit):
                elapsed = time.monotonic() - query_started
                if query_round % 25 == 0 or elapsed >= query_budget_seconds:
                    print(json.dumps(dict(profile='sdk_public_query', language=label,
                        phase='receiving', seconds=round(elapsed, 3), rounds=query_round,
                        budget_seconds=query_budget_seconds,
                        stage_seconds={key: round(value, 3) for key, value in query_times.items()})), flush=True)
                assert elapsed < query_budget_seconds, (
                    label, 'Public query exceeded fixture deadline',
                    dict(seconds=elapsed, rounds=query_round, stage_seconds=query_times))
                stage_start = time.monotonic()
                deliver()
                delivered = time.monotonic()
                expect_one(service, 'Committed', 'Idle')
                serviced = time.monotonic()
                expect_one(caller, 'Committed', 'Idle')
                received = time.monotonic()
                query_times['delivery'] += delivered - stage_start
                query_times['service'] += serviced - delivered
                query_times['caller'] += received - serviced
                if manifest_file.exists(): break
            else: raise AssertionError('Public query did not complete')
            print(json.dumps(dict(profile='sdk_public_query', language=label,
                phase='received', seconds=round(time.monotonic()-query_started, 3),
                rounds=query_round+1, budget_seconds=query_budget_seconds,
                stage_seconds={key: round(value, 3) for key, value in query_times.items()})), flush=True)
            close(service); close(caller)
            manifest = json.loads(manifest_file.read_bytes())
            assert (manifest['rows'], manifest['segments'], manifest['source'], manifest['destination'], manifest['resource']) == (41, 6, table['pid'], query_cfg['pid'], table['resource'])
            # Independent consumer after all foreign handles have been destroyed.
            import pyarrow as pa
            segments = [Path(query_cfg['output'], f'{i}.arrow').read_bytes() for i in range(6)]
            from query.arrow.fuze_logical_arrow import arrow_cell, read_stream
            from query.files.fuze_file_query import descriptor
            types = [{'int64': {}}, {'int64': {}}, {'utf8': {}},
                     {'list': {'type': {'int64': {}}, 'nullable': False}}]
            fields = [dict(name=name, type=typ, nullable=index == 1, optional=False)
                      for index, (name, typ) in enumerate(zip(('id', 'value', 'label', 'tags'), types))]
            rows = 0
            for ipc in segments:
                physical, batches = read_stream(ipc)
                assert physical.metadata[b'transit.logical_schema'] == descriptor({'structure': fields}).hex().encode()
                for batch in batches:
                    for index in range(batch.num_rows):
                        key = -(2**63) if rows == 0 else rows
                        value = 17 if rows == 0 else None if rows % 5 == 0 else 2**63-1 if rows == 1 else 2**53+1
                        expected = (b'\3' + struct.pack('<q', key),
                                    b'\1' if value is None else b'\3' + struct.pack('<q', value),
                                    b'\3\7\0\0\0example',
                                    b'\3\2\0\0\0' + b'\3' + struct.pack('<q', 1) + b'\3' + struct.pack('<q', 2))
                        assert tuple(arrow_cell(batch.column(n), index, typ) for n, typ in enumerate(types)) == expected
                        rows += 1
            assert rows == 41
            assert sum(map(len, segments)) == manifest['bytes']
            print(f'{label} logical query: {rows} rows, {len(segments)} streams, {manifest["bytes"]} IPC bytes, {query_round+1} publication/receipt rounds.', flush=True)
            own(query_cfg)
            send(query_cfg, b'TSQ\x01\x04')
            reader_child = subprocess.Popen(consumer.command('revoked-result', config_file(query_cfg)), stdout=subprocess.PIPE, env=env, cwd=target, text=True)
            children.append(reader_child)
            deadline = time.monotonic() + 45
            while not Path(query_cfg['output'], 'ready').exists():
                assert reader_child.poll() is None and time.monotonic() < deadline, 'Reader was not ready'
                time.sleep(0.02)
            command({'grant_resource': {'resource': query_cfg['resource'], 'subject': query_cfg['principal'], 'permissions': 0}})
            Path(query_cfg['output'], 'continue').touch()
            denied = json.loads(reader_child.communicate(timeout=30)[0])
            assert denied == {'denied': True}
            assert reader_child.returncode == 0
            children.remove(reader_child)
            query_cfg['arrow_site'] = str(Path(pa.__file__).parent.parent)
            if consumer.arrow_adapter:
                invoke('arrow', query_cfg)
            # Expiry remains retirement, distinct from stale activation or access.
            while time.time_ns() // 1_000_000 <= expired['settle_before_ms'] + 10000:
                time.sleep(0.05)
            command({'expire': expired['pid']})
            invoke('expired', expired)
            check('public-runner-lifecycle', {
                'gated_purposes': gates['gates'], 'handler_calls_after_recovery': gates['handled'],
                'mutation_dispatches': gates['dispatches'], 'exact_commit_retry': exact_commit_retry,
                'restarted_reply_value': str(int.from_bytes(bytes.fromhex(observed['value'])[4:], 'little')),
                'query_rows': manifest['rows'], 'query_segments': manifest['segments'],
                'owned_ipc_after_close': not children, 'revoked_result_denied': denied['denied'],
            })
            assert cold.data_objects() > 0, 'Retained history did not reach cold storage'
            print(f'{label} storage: 8 MiB hot cache, {fixture.resident_pages} authority pages, {cold.data_objects()} cold objects.', flush=True)
            print(f'{label} Station: clean artifacts/examples, full-width codecs, gated mutations, callback failures, scope safety, stop/join, codec policy, poisoned reads, fencing/expiry, exact disk/host recovery, retained Tables and six owned IPC segments passed.')
            print(f'{label} Station recovery: {recovered_events} transient outcomes reconciled with unchanged signed attempts.')
            print(f'{label} Station reads: {repeated_reads} unavailable observations repeated within the same progress budget.')
        finally:
            for child in children:
                child.kill(); child.wait(timeout=10)
            native.lib.transit_client_destroy(admin)
            proxy.shutdown(); proxy.server_close(); thread.join(timeout=5)

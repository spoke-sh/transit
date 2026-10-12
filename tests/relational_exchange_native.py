"""Disk-backed source exchanges into the actual maintained result owner."""
from http.client import HTTPConnection
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import subprocess
import sys
import threading
import time

from cold_storage import ColdStore
from relational import evaluate
from storage import Fixture, free_port, wait_ready


def run(node, proof, pressure=None):
    node, proof = map(lambda path: str(Path(path).resolve()), (node, proof))
    with ColdStore() as cold, Fixture(cold.config()) as fixture:
        root = fixture.root
        secondary = root / 'secondary'
        secondary.mkdir()
        port = free_port()
        direct = f'http://127.0.0.1:{port}'
        config = root / 'node.json'
        public = json.loads(subprocess.check_output([proof, 'public'], timeout=10))
        config.write_text(json.dumps(dict(profile='native_v1', genesis=dict(
            realm=46, root_key=public, max_clock_error_ms=10000),
            ursula_url=fixture.url, bucket='relational-exchanges', journal='authority',
            port=port, resident_pages=8, request_timeout_ms=10000)))
        fault = dict(armed=None, records={}, replays=set(), read=None, read_faults=[])
        metrics = dict(turns=0, max_mutations=0, max_value_bytes=0, accepted=0)
        failures = []

        class Proxy(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                body = self.rfile.read(int(self.headers['Content-Length']))
                connection = HTTPConnection('127.0.0.1', port, timeout=15)
                try:
                    connection.request('POST', self.path, body, {'Content-Type': 'application/json'})
                    response = connection.getresponse()
                    data = response.read()
                    if self.path == '/v1/query' and response.status == 200 and fault['read']:
                        selected_read = fault['read']
                        if selected_read in ('truncated', 'unavailable'):
                            if selected_read == 'truncated':
                                fault['read'] = None
                            if not fault['read_faults'] or fault['read_faults'][-1] != selected_read:
                                fault['read_faults'].append(selected_read)
                            data = data[:-7] if selected_read == 'truncated' else b'{"err":"AuthorityUnavailable"}'
                            if selected_read == 'unavailable':
                                self.send_response(503)
                                self.send_header('Content-Length', str(len(data)))
                                self.end_headers()
                                self.wfile.write(data)
                                return
                        elif selected_read == 'segment':
                            value = json.loads(data)

                            def corrupt(item):
                                if isinstance(item, dict):
                                    for key, child in item.items():
                                        if key == 'value' and isinstance(child, str) and child.startswith(b'FXS1'.hex()):
                                            raw = bytearray.fromhex(child)
                                            raw[-1] ^= 1
                                            item[key] = raw.hex()
                                            return True
                                        if corrupt(child):
                                            return True
                                elif isinstance(item, list):
                                    return any(corrupt(child) for child in item)
                                return False

                            if corrupt(value):
                                fault['read'] = None
                                fault['read_faults'].append(selected_read)
                                data = json.dumps(value, separators=(',', ':')).encode()
                    if self.path == '/v1/command' and response.status == 200:
                        command = json.loads(body)['request']['command']
                        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn'))
                        acceptance = False
                        if turn:
                            mutations = [entry for entry in turn['mutations'] if entry]
                            metrics['turns'] += 1
                            metrics['max_mutations'] = max(metrics['max_mutations'], len(mutations))
                            for entry in mutations:
                                value = bytes.fromhex(entry['value']) if entry['value'] else b''
                                metrics['max_value_bytes'] = max(metrics['max_value_bytes'], len(value))
                                acceptance |= value.startswith(b'RXA1')
                            metrics['accepted'] += acceptance
                        for label, (original, receipt) in fault['records'].items():
                            if body == original:
                                assert data == receipt, 'Exact exchange turn retry changed its receipt'
                                fault['replays'].add(label)
                        selected = fault['armed']
                        handoff_command = {'handoff_quiesced': 'suspend', 'handoff_fenced': 'resume', 'handoff_activated': 'rotate_worker'}.get(selected)
                        if (turn and (selected == 'producer' or (selected == 'acceptance' and acceptance))) or (handoff_command and handoff_command in command):
                            fault['records'][selected] = body, data
                            fault['armed'] = None
                            data = b'{"position":0}'
                    self.send_response(response.status)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                except BaseException as error:
                    failures.append(repr(error))
                    raise
                finally:
                    connection.close()

        proxy = ThreadingHTTPServer(('127.0.0.1', 0), Proxy)
        thread = threading.Thread(target=proxy.serve_forever, daemon=True)
        thread.start()
        url = f'http://127.0.0.1:{proxy.server_port}'
        authority = None
        log = (root / 'node.log').open('w+')
        started = time.monotonic()
        try:
            subprocess.run([node, str(config), '--initialize'], stdout=log, stderr=subprocess.STDOUT, check=True, timeout=30)

            def start():
                process = subprocess.Popen([node, str(config)], stdout=log, stderr=subprocess.STDOUT)
                wait_ready(fixture.http, process, direct + '/health')
                return process

            def restart():
                nonlocal authority
                authority.kill()
                authority.wait(timeout=10)
                authority = None
                fixture.stop()
                fixture.start()
                authority = start()

            def call(mode, *args, directory=root, fail=False, expected_error='InvalidAuthorityResponse'):
                result = subprocess.run([proof, url, mode, str(directory), *map(str, args)], capture_output=True, text=True, timeout=300)
                if fail:
                    assert result.returncode and expected_error in result.stderr, result.stderr
                    return None
                if result.returncode:
                    raise RuntimeError(f'{mode}: {result.stderr[-12000:]}')
                return json.loads(result.stdout)

            def execute(operation, sql, object_id='-', directory=root):
                call('compile', operation, object_id, sql, directory=directory)
                for _ in range(1000):
                    result = call('next', directory=directory)
                    if result['state'] == 'terminal':
                        assert result['outcome'] == 'applied' or (result['outcome'] == 'delegated' and result['table_outcome'] == 'applied'), result
                        return result
                    call('pump', directory=directory)
                raise AssertionError('Table setup exceeded bounded work')

            authority = start()
            for directory, worker in ((root, 65536), (secondary, 65538)):
                call('provision', worker, directory=directory)
                call('initialize', directory=directory)
                call('pump', directory=directory)
            execute(1, 'CREATE TABLE rel_left (k BIGINT, v BIGINT)', 1)
            execute(2, 'INSERT INTO rel_left VALUES (7,10),(7,20),(9,30),(NULL,40)')
            execute(1, 'CREATE TABLE rel_right (k BIGINT, v BIGINT)', 1, secondary)
            execute(2, 'INSERT INTO rel_right VALUES (7,1),(7,2),(7,3),(NULL,4)', directory=secondary)
            sql = 'SELECT l.k, COUNT(*) AS rows, COUNT(r.v) AS present, SUM(r.v) AS total FROM rel_left l LEFT JOIN rel_right r ON l.k = r.k GROUP BY l.k'
            expected = evaluate(dict(join='left', left=[[1, 7, 10], [2, 7, 20], [3, 9, 30], [4, None, 40]],
                right=[[1, 7, 1], [2, 7, 2], [3, 7, 3], [4, None, 4]], group_by=['l.key'], outputs=[
                    ['k', 'column', 'l.key'], ['rows', 'count_all'], ['present', 'count', 'r.value'], ['total', 'sum', 'r.value']]))
            assert expected['error'] is None
            expected = {tuple(row['identity']): row['values'] for row in expected['rows']}
            if pressure:
                call('captured-plan', sql, secondary)
                call('captured-enqueue')
                for _ in range(1000):
                    call('captured-pump', 1)
                    captured = call('captured-status')
                    if captured['state'] == 'capturing' and captured['checkpoint']:
                        break
                else:
                    raise AssertionError('Captured query did not retain an operator checkpoint')
                pressure('captured', call, restart, direct)
                call('captured-pump')
                assert call('captured-status')['state'] == 'complete'
                captured_rows = call('captured-result')
                assert captured_rows['complete'], captured_rows
                actual_rows = [[None if 'null' in cell['cell'] else int(next(iter(cell['cell']['value']['atom'].values())))
                                for cell in row] for row in captured_rows['rows']]
                assert actual_rows == list(expected.values()), (actual_rows, expected)
                call('captured-retire')
                call('captured-clean')
                assert call('captured-status')['released']
            results = []
            for partitions, workers, batch in ((1, 1, 1), (7, 3, 4)):
                begin = time.monotonic()
                before = metrics['turns']
                fault['records'].clear()
                fault['replays'].clear()
                call('maintained-plan', sql, secondary)
                call('maintained-exchange-enqueue')
                call('maintained-pump')
                assert call('maintained-status')['state'] == 'admitted'
                metadata = call('exchange-setup', partitions, workers, batch)
                for worker in range(workers):
                    call('exchange-pump', worker)
                call('exchange-pump', 'r')
                # A producer dies after an accepted private staging proposal.
                call('exchange-tick', 0)
                fault['armed'] = 'producer'
                call('exchange-pump', 0, 1, fail=True)
                assert list(root.glob('exchange-worker-*.json'))
                restart()
                call('exchange-handoff', 0, 'begin', fail=True, expected_error='PendingOperation')
                call('exchange-rotate', 0)
                assert 'producer' in fault['replays']
                # Retain one acknowledged segment and one eligible unacknowledged
                # segment before movement. The checkpoint includes their bytes,
                # cursor, eligibility, ack ledger and original pending notice.
                for segment in range(2):
                    for _ in range(100):
                        if call('exchange-status')['workers'][0]['outstanding']:
                            break
                        call('exchange-tick', 0)
                        call('exchange-pump', 0)
                    else:
                        raise AssertionError('Producer did not retain an eligible segment')
                    if segment == 0:
                        call('exchange-pump', 'r')
                        call('exchange-pump', 0)
                # More than the node's eight resident entry pages. These are
                # explicit application checkpoint records, not fabricated
                # exchange rows or a claim about exchange-state amplification.
                call('exchange-checkpoint-growth', 0)
                call('exchange-pump', 0)
                assert call('exchange-handoff', 0, 'begin')['phase'] == 'planned'
                phases = ['planned']
                checkpoint_path = root / f"handoff-{metadata['workers'][0]['process']['pid']}.json"
                for phase in ('quiesced', 'checkpointed', 'fenced', 'restored', 'activated', 'retired'):
                    # Both the manager and authority/storage disappear at every
                    # recorded boundary. One-shot proof workers are already dead.
                    restart()
                    if phase == 'restored':
                        original = checkpoint_path.read_bytes()
                        fault['read'] = 'unavailable'
                        call('exchange-handoff', 0, 'step', fail=True, expected_error='AuthorityUnavailable')
                        fault['read'] = None
                        assert checkpoint_path.read_bytes() == original
                        assert call('exchange-handoff', 0, 'status')['phase'] == 'fenced'
                        checkpoint_path.unlink()
                        call('exchange-handoff', 0, 'step', fail=True, expected_error='FileNotFound')
                        checkpoint_path.write_bytes(original)
                        corrupt = json.loads(original)
                        corrupt['checkpoint']['state']['digest'][0] ^= 1
                        checkpoint_path.write_text(json.dumps(corrupt, separators=(',', ':')))
                        call('exchange-handoff', 0, 'step', fail=True, expected_error='InvalidWorkerCheckpoint')
                        checkpoint_path.write_bytes(original)
                        call('exchange-deny', 0)
                        call('exchange-handoff', 0, 'step', fail=True, expected_error='AccessDenied')
                        assert call('exchange-handoff', 0, 'status')['phase'] == 'fenced'
                        call('exchange-allow', 0)
                    if phase in ('quiesced', 'fenced', 'activated'):
                        fault['armed'] = 'handoff_' + phase
                        call('exchange-handoff', 0, 'step', fail=True)
                        assert list(root.glob('handoff-pending-*.json'))
                        restart()
                    assert call('exchange-handoff', 0, 'step')['phase'] == phase
                    if phase in ('quiesced', 'fenced', 'activated'):
                        assert 'handoff_' + phase in fault['replays']
                    phases.append(phase)
                transferred = call('exchange-handoff', 0, 'status')
                assert transferred['checkpoint']['state']['entries'] >= 257
                before_fault = call('exchange-status')['head']
                call('exchange-deny', 'r')
                call('exchange-pump', 'r', fail=True, expected_error='AccessDenied')
                call('exchange-allow', 'r')
                assert call('exchange-status')['head'] == before_fault
                fault['read'] = 'truncated'
                call('exchange-pump', 'r', fail=True, expected_error='InvalidAuthorityResponse')
                assert call('exchange-status')['head'] == before_fault
                fault['read'] = 'segment'
                accepted_before = metrics['accepted']
                call('exchange-pump', 'r', fail=True, expected_error='InvalidPublicationDigest')
                assert fault['read'] is None and metrics['accepted'] == accepted_before
                if pressure and partitions == 1:
                    pressure('exchange', call, restart, direct)
                # The second fault is exactly acceptance, before consumption.
                fault['armed'] = 'acceptance'
                recovered = False
                for attempt in range(1000):
                    for worker in reversed(range(workers)):
                        call('exchange-tick', worker)
                        call('exchange-pump', worker)
                    try:
                        call('exchange-pump', 'r')
                    except RuntimeError as error:
                        assert not recovered and 'InvalidAuthorityResponse' in str(error), str(error)
                        assert 'acceptance' in fault['records'] and fault['armed'] is None
                        restart()
                        call('exchange-rotate', 'r')
                        assert 'acceptance' in fault['replays']
                        recovered = True
                        call('exchange-pump', 'r')
                    for worker in range(workers):
                        call('exchange-pump', worker)
                    status = call('exchange-status')
                    if status['head']['completed'] == 2 * partitions:
                        break
                else:
                    raise AssertionError('Exchange exceeded finite work budget')
                assert recovered and status['head']['inflight_segments'] == 0
                assert all(not worker['outstanding'] for worker in status['workers']), status
                assert all(worker['cursor']['channel'] == 2 * partitions for worker in status['workers']), status
                call('exchange-attach', 'r')
                for _ in range(100):
                    call('exchange-pump', 'r', 100)
                    maintained = call('maintained-status')
                    if maintained['state'] == 'idle':
                        break
                else:
                    raise AssertionError('Exchanged maintained result did not complete')
                snapshot = call('maintained-result', 1)
                assert snapshot['complete'] and snapshot['manifest']['revision'] == 1
                actual = {}
                for row in snapshot['events']:
                    group = row['identity']['group']
                    key = tuple(group['values'][:group['len']])
                    values = [None if 'null' in cell['cell'] else int(next(iter(cell['cell']['value']['atom'].values()))) for cell in row['values']]
                    assert key not in actual
                    actual[key] = values
                assert actual == expected, (actual, expected)
                results.append(dict(partitions=partitions, workers=workers, batch=batch, exchange=metadata['id'],
                    turns=metrics['turns'] - before, seconds=round(time.monotonic() - begin, 3),
                    retained_exchange_bytes=status['head']['retained_bytes'], operator_bytes=maintained['state_bytes'],
                    rounds=attempt + 1, completed=status['head']['completed'], oracle=True,
                    producer_loss=True, acceptance_loss=True, node_store_restart=True, stale_worker_rejected=True,
                    handoff_phases=phases, checkpoint_entries=transferred['checkpoint']['state']['entries'],
                    corrupt_checkpoint_rejected=True, missing_checkpoint_rejected=True, denied_restore_blocked=True,
                    unavailable_restore_blocked=True, truncated_read_rejected=True, corrupt_segment_rejected=True,
                    receiver_denial_preserved_head=True,
                    old_credential_rejected=True))
                print(json.dumps(dict(profile='relational-exchange-layout', **results[-1])), flush=True)
            # The final negative placement loses its source's native lifetime
            # after checkpoint/fence. A retained hash cannot revive that source
            # or authorize restoration. No later query needs this fixture source.
            call('maintained-plan', sql, secondary)
            call('maintained-exchange-enqueue')
            call('maintained-pump')
            expired_metadata = call('exchange-setup', 1, 1, 1)
            call('exchange-pump', 0)
            call('exchange-pump', 'r')
            call('exchange-handoff', 0, 'begin')
            for phase in ('quiesced', 'checkpointed', 'fenced'):
                assert call('exchange-handoff', 0, 'step')['phase'] == phase
            expired_path = root / f"handoff-{expired_metadata['workers'][0]['process']['pid']}.json"
            fenced = expired_path.read_bytes()
            call('exchange-expire-source', 'r')
            call('exchange-handoff', 0, 'step', fail=True, expected_error='StateResourceExpired')
            assert expired_path.read_bytes() == fenced
            assert call('exchange-handoff', 0, 'status')['phase'] == 'fenced'
            assert not json.loads((root / 'exchange-native.json').read_text())['workers'][0]['fresh_key']
            call('maintained-retire')
            call('maintained-clean')
            assert call('maintained-status')['state'] == 'retired'
            assert not failures, failures
            assert metrics['max_mutations'] <= 4 and metrics['max_value_bytes'] <= 256
            assert cold.data_objects() > 0
            print(json.dumps(dict(profile='relational-exchange-native', seconds=round(time.monotonic() - started, 3),
                layouts=results, metrics=metrics, cold_objects=cold.data_objects(), cold_bytes=cold.file_bytes(),
                replays=sorted(fault['replays']), read_faults=fault['read_faults'],
                source_owner_expiry_blocks_restore=True, own_resource_retirement_after_expiry=True)), flush=True)
        except BaseException:
            log.flush()
            log.seek(0)
            print(log.read()[-12000:], file=sys.stderr)
            raise
        finally:
            if authority is not None:
                authority.kill()
                authority.wait(timeout=10)
            proxy.shutdown()
            proxy.server_close()
            thread.join(timeout=5)
            log.close()


if __name__ == '__main__':
    run(*sys.argv[1:])

"""Real local node recovery after a durable write loses its sync outcome."""
from http.client import HTTPConnection, HTTPException
import base64
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import urllib.request

from harness.services import free_port, wait_ready
from interfaces.http.serving import Key, compact
from interfaces.installation.server_application_faults import native


def atomic_turn(root, key, inject, retry, child, restart):
    """One accepted turn retains its input, state, captured blocks and intents."""
    sequence = retry('/v1/query', native(key, 42, 0, {'identity': {}}))['principal_sequence']

    def query(kind, path='/v1/query'):
        return retry(path, native(key, 42, 0, kind))

    def command(value, body=None):
        nonlocal sequence
        sequence += 1
        request = native(key, 42, 0, value, sequence)
        if body is not None:
            request['blocks'] = base64.b64encode(body).decode()
        return retry('/v1/command', request)['position']

    def spawn():
        return command({'spawn': dict(allow_collection=False, code=1,
                                      work_before_ms=None, settle_before_ms=None)})

    source, destination = spawn(), spawn()
    resource = command({'create_resource': dict(writer=source, owned=True,
                                                deadline_ms=None, history_ms=None)})
    command({'grant_resource': dict(resource=resource, subject=0, permissions=7)})
    command({'associate': dict(pid=source, name=b'state'.hex(), expected_revision=0,
                               resource=resource, required=True)})
    command({'own': dict(pid=source, expected_generation=1, worker=0)})
    state_key, block_key = b'state'.hex(), b'capture'.hex()
    output, effect = b'output-once'.hex(), b'effect-intent-once'.hex()
    bodies = (b'original captured block', b'new current block')
    first = None
    for index, body in enumerate(bodies):
        input_id = command({'send': dict(pid=source, value=f'input-{index}'.encode().hex())})
        process = query({'process': source})['body']['process']['process']
        revision = query({'resource': resource})['body']['resource']['revision']
        view = command({'open_view': dict(pid=source, generation=process['generation'],
                        input=input_id, expected_revision=process['revision'],
                        resource=resource, revision=revision,
                        deadline_ms=int(time.time() * 1000) + 30000)})
        spec = dict(bytes=len(body), digest=list(hashlib.sha256(
            b'transit.immutable.block.v1\0' + body).digest()))
        turn = dict(pid=source, generation=process['generation'], input=input_id,
                    expected_revision=process['revision'], permit=None,
                    views=[view] + [None]*3, current_views=[None]*4, write_view=view,
                    mutations=[dict(key=state_key, value=f'value-{index}'.encode().hex())] + [None]*3,
                    blocks=[dict(key=block_key, value=spec)] + [None]*15,
                    outputs=[dict(pid=destination, value=output) if index else None] + [None]*3,
                    effect=effect if index else None, failed=False, authorization=None)
        if index == 0:
            first = command({'turn': turn}, body)
            continue
        sequence += 1
        pending = native(key, 42, 0, {'turn_with_versions': dict(turn=turn,
                         reads=[None]*4, retain=[view] + [None]*3, release=[None]*4)}, sequence)
        pending['blocks'] = base64.b64encode(body).decode()
        saved = compact(pending)
        (root / 'pending-turn.json').write_bytes(saved)
        until = inject(pending, '/native/wal/', 1)
        receipt = retry('/v1/command', pending, until=until)
        assert child.poll() is None, 'atomic turn replaced the process instead of its owner'
        version = dict(pid=source, input=input_id, index=0)

    def verify():
        assert compact(pending) == saved
        assert retry('/v1/command', pending) == receipt
        current = query({'process': source})['body']['process']
        assert current['process']['consumed'] == 2 and current['input'] is None, current
        assert current['process']['revision'] == receipt['position'], current
        assert query({'identity': {}})['principal_sequence'] == sequence
        for retained in (False, True):
            if retained:
                kind = {'version_entries': dict(id=version, generation=2, key=state_key, after=None)}
                expected_revision, expected_value, expected_body = first, b'value-0', bodies[0]
                block_source = {'version': dict(id=version, generation=2)}
            else:
                kind = {'entries': dict(view=None, resource=resource, revision=receipt['position'],
                                        key=state_key, after=None)}
                expected_revision, expected_value, expected_body = receipt['position'], b'value-1', bodies[1]
                block_source = {'resource': dict(id=resource, revision=receipt['position'])}
            entries = query(kind)['body'][next(iter(kind))]
            assert entries['resource']['revision'] == expected_revision, entries
            if retained:
                assert entries['version'] == dict(id=version, resource=resource, revision=first,
                                                  created_at=receipt['position'], released_at=None), entries
            values = [item for item in entries['page']['entries'] if item is not None]
            assert values == [dict(key=state_key, value=expected_value.hex(), revision=expected_revision)], values
            blocks = query({'block_entries': dict(source=block_source, keys=[block_key] + [None]*7,
                                                   after=None)}, '/v1/blocks')
            assert base64.b64decode(blocks['blocks']) == expected_body, blocks
            block_result = blocks['response']['body']['block_entries']
            assert block_result['resource']['revision'] == expected_revision
            expected_spec = dict(bytes=len(expected_body), digest=list(hashlib.sha256(
                b'transit.immutable.block.v1\0' + expected_body).digest()))
            assert [item for item in block_result['entries'] if item is not None] == [
                dict(key=block_key, value=expected_spec, revision=expected_revision)], block_result
        outputs = [item for item in query({'outputs': dict(after=None, position=None)})['body']['outputs']['entries'] if item is not None]
        assert len(outputs) == 1 and outputs[0]['turn'] == receipt['position'], outputs
        assert (outputs[0]['destination'], outputs[0]['value'], outputs[0]['phase']) == (destination, output, 'pending'), outputs
        effects = [item for item in query({'effects': dict(pid=source, after=None, position=None)})['body']['effects']['entries'] if item is not None]
        assert len(effects) == 1 and effects[0]['id'] == receipt['position'], effects
        assert (effects[0]['payload'], effects[0]['phase'], effects[0]['attempt']) == (effect, 'pending', None), effects
        assert query({'process': destination})['body']['process']['process']['admitted'] == 0

    verify()
    restart()
    verify()


def run(node):
    # Physical disk is deliberate: tmpfs is not a durable-owner qualification.
    root = Path(tempfile.mkdtemp(prefix='transit-owner-recovery-', dir='/var/tmp'))
    key = Key(root, 'owner', 9)
    port = free_port()
    config = root / 'node.json'
    config.write_text(json.dumps(dict(
        profile='native_v1', genesis=dict(realm=42, root_key=key.public, max_clock_error_ms=10000),
        local_directory=str(root / 'native'), port=port, resident_pages=1,
        request_timeout_ms=2000)))
    http = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    child = None
    log_path = root / 'node.log'

    def exchange(path, request, timeout=4):
        connection = HTTPConnection('127.0.0.1', port, timeout=timeout)
        try:
            connection.request('POST', path, compact(request), {'Content-Type': 'application/json'})
            response = connection.getresponse()
            return response.status, json.loads(response.read())
        finally:
            connection.close()

    def retry(path, request, *, until=None):
        until = time.monotonic() + 15 if until is None else until
        while True:
            assert child.poll() is None, 'owner exited before recovery'
            remaining = until - time.monotonic()
            assert remaining > 0, 'original request did not resolve'
            try:
                status, value = exchange(path, request, timeout=min(4, remaining))
                if status == 200:
                    return value
                assert status in (409, 503), (status, value)
            except (OSError, HTTPException):
                pass
            assert time.monotonic() < until, 'original request did not resolve'
            time.sleep(.025)

    def inject(request, selection, expected):
        # Fault delivery and original-outcome recovery share the existing budget.
        # A request can time out before reaching the selected durability barrier;
        # that is not evidence that the injected fault occurred.
        until = time.monotonic() + 15
        saved = compact(request)
        staging = root / 'arm.next'
        staging.write_text(selection)
        staging.replace(root / 'arm')
        while True:
            assert compact(request) == saved, 'fault retry changed the original request'
            remaining = until - time.monotonic()
            assert remaining > 0, 'selected fault was not observed within the recovery budget'
            marker = root / 'fired'
            observed = marker.read_text() if marker.exists() else ''
            if not (root / 'arm').exists():
                # The hook removes its arm before publishing the counter. Wait
                # for that bounded publication even if the fourth fault has
                # already stopped the owner after exhausting its reopen budget.
                if observed == str(expected):
                    return until
                time.sleep(.025)
                continue
            assert child.poll() is None, 'owner exited before the selected fault'
            try:
                status, result = exchange('/v1/command', request, timeout=min(4, remaining))
                assert status == 503, (status, result)
            except (OSError, HTTPException):
                pass
            time.sleep(.025)

    with log_path.open('w') as log:
        def start(*args):
            nonlocal child
            child = subprocess.Popen([node, str(config), *args], stdout=log,
                                     stderr=subprocess.STDOUT, env={**os.environ,
                                     'TRANSIT_TEST_OWNER_FAULT': str(root), 'LOG_FORMAT': 'json'})
            wait_ready(http, child, f'http://127.0.0.1:{port}/health')

        try:
            start('--bootstrap')
            process = child.pid
            receipts = []
            pending = None
            for sequence, selection in enumerate((
                    '/native/wal/', '/native/native-allocations/queue/',
                    '/native/wal/', '/native/wal/')):
                pending = native(key, 42, 0, {'create_principal': dict(
                    subject=65536 + sequence, public_key=key.public,
                    permissions=1, pid=None)}, sequence + 1)
                (root / 'pending.json').write_bytes(compact(pending))
                until = inject(pending, selection, sequence + 1)
                if sequence == 3:
                    assert child.wait(timeout=15) != 0, 'reopen budget did not stop the owner'
                    child = None
                    assert 'LocalWalReopenBudget' in log_path.read_text()
                    break
                receipt = retry('/v1/command', pending, until=until)
                assert child.pid == process, 'test replaced the node instead of reopening its owner'
                assert retry('/v1/command', pending) == receipt, 'exact retry changed its receipt'
                receipts.append(receipt)
                state = retry('/v1/query', native(key, 42, 0, {'identity': {}}))
                assert state['principal_sequence'] == sequence + 1, state
            # An exhausted process preserves its history and pending request.
            start()
            last = retry('/v1/command', pending)
            assert retry('/v1/command', pending) == last
            state = retry('/v1/query', native(key, 42, 0, {'identity': {}}))
            assert state['principal_sequence'] == 4, state
            for sequence, receipt in enumerate(receipts):
                request = native(key, 42, 0, {'create_principal': dict(
                    subject=65536 + sequence, public_key=key.public,
                    permissions=1, pid=None)}, sequence + 1)
                assert retry('/v1/command', request) == receipt

            def restart():
                child.kill()
                child.wait(timeout=10)
                start()

            atomic_turn(root, key, inject, retry, child, restart)
        except BaseException:
            print(f'Retained local owner failure: {root}', file=sys.stderr)
            print(log_path.read_text()[-6000:], file=sys.stderr)
            raise
        finally:
            if child is not None:
                child.kill()
                child.wait(timeout=10)
    import shutil
    shutil.rmtree(root)
    print('Local owner recovery: original receipts, native allocation queue, bounded reopen and restart; '
          'atomic input/KV/block/output/effect acceptance with retained original blocks after owner '
          'replacement and process restart passed.')


if __name__ == '__main__':
    run(str(Path(sys.argv[1]).resolve()))

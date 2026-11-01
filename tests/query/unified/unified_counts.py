"""Partial COUNT accumulators through real signed callers and disk replacement."""
import hashlib
import json
import struct
import threading
import time

import pyarrow as pa

from query.unified.unified_abi import Failure, authorize_capture


def check(native, port, callers, root, invoke, restart, fault, kind):
    owners = (native, port, *callers)
    uploader = callers[0] if callers else port
    reached, release = threading.Event(), threading.Event()
    fault['count_release'] = release
    gate = dict(armed=False, attempt=None, checkpoint=None, timeout=False)
    lost = dict(armed=True, attempt=None, receipt=None, retries=0)
    lock = threading.Lock()

    def hook(path, message, body, status, data):
        if path != '/v1/command' or status != 200: return data
        request = message['request']
        command = request['command']
        if request['principal'] == 1234 and 'send' in command:
            payload = bytes.fromhex(command['send']['value'])[13:]
            with lock:
                if lost['armed'] and payload.startswith(b'UQP1'):
                    lost.update(armed=False, attempt=body, receipt=data)
                    return b'{"position":0}'
                if body == lost['attempt']:
                    assert data == lost['receipt'], 'original COUNT upload receipt changed'
                    lost['retries'] += 1
        if request['principal'] == 65536:
            turn = command.get('turn', command.get('turn_with_versions', {}).get('turn', {}))
            with lock:
                if gate['armed']:
                    for item in turn.get('mutations', []):
                        if not item or not bytes.fromhex(item['key']).startswith(b'\0Uc') or item['value'] is None: continue
                        checkpoint = bytes.fromhex(item['value'])
                        assert checkpoint[:4] == b'UQC1'
                        # UQC1: magic, source kind, resource and its typed position.
                        # FQS1: magic, binding/plan digests, six u64 counters,
                        # optional sum (tag + i128), finish tag.
                        progress_offset = 4 + 1 + 8 + (32 if kind == 'table' else 8)
                        assert checkpoint[progress_offset:progress_offset + 4] == b'FQS1'
                        pages, scanned, selected, counted, segments, rows = struct.unpack_from('<6Q', checkpoint, progress_offset + 68)
                        if selected and checkpoint[progress_offset + 133] == 0:
                            assert pages and 0 < selected < 10 and counted == selected and segments == rows == 0
                            gate.update(armed=False, attempt=body, checkpoint=checkpoint,
                                        counters=(pages, scanned, selected, counted, segments, rows))
                            reached.set()
                            break
                held = body == gate['attempt']
            if held and not release.wait(timeout=60): gate['timeout'] = True
        return data

    fault['count_hook'] = hook

    def compile(sql):
        invoke('compile-count', sql, direct=True)
        return (root / 'count-bundle.bin').read_bytes().hex()

    def observe(owner, prepared):
        (root / 'pending.json').write_text(prepared)
        try:
            receipt = owner.call({'submit': prepared})['receipt']
        except Failure as failure:
            assert failure.status == 6 and failure.detail['err'] == 'InvalidAuthorityResponse', failure
            assert lost['attempt'] is not None
            # A fresh Zig caller loads exactly the persisted original command.
            invoke('resume')
            assert lost['retries'] > 0
            return
        deadline = time.monotonic() + 60
        while True:
            result = owner.call({'observe': receipt['position']})['observation']
            if 'committed' in result: return
            assert 'pending' in result and time.monotonic() < deadline, result
            time.sleep(.02)

    def upload(namespace, bundle):
        accepted = authorize_capture(native, root, namespace, bundle)
        for _ in range(132):
            prepared = uploader.call({'next': dict(namespace=namespace, bundle=accepted)})['prepared']
            if prepared is None: return
            observe(uploader, prepared)
        raise AssertionError('COUNT upload exceeded the existing finite command budget')

    def wait(namespace, phase, cleanup=False):
        deadline = time.monotonic() + (900 if phase == 'complete' else 180)
        while True:
            status = native.call({'status': namespace})['status']
            if status and status['phase'] == phase:
                if not cleanup: return status
                snapshot = invoke('job', namespace, direct=True)
                if snapshot['job']['cleanup'] == 0: return snapshot
            assert time.monotonic() < deadline, status
            time.sleep(.1)

    def arm():
        release.clear(); reached.clear()
        gate.update(armed=True, attempt=None, checkpoint=None, timeout=False)

    def partial(namespace):
        assert reached.wait(timeout=120), 'COUNT did not commit a partial accumulator'
        snapshot = invoke('job', namespace, direct=True)
        assert snapshot['job']['phase'] == 'capturing'
        progress = snapshot['checkpoint']['progress']
        counters = progress['counters']
        assert (progress['pages'], counters['scanned'], counters['selected'], counters['value_count'], progress['segments'], progress['rows']) == gate['counters']
        assert progress['finished'] is None and counters['sum'] is None
        try:
            native.call({'page': dict(namespace=namespace)})
            raise AssertionError('partial COUNT exposed a result')
        except Failure as failure:
            assert failure.detail['err'] == 'IncompleteResult', failure
        return snapshot

    def result(namespace, selected, counted):
        wait(namespace, 'complete')
        expected_ipc = None
        for owner in owners:
            page = owner.call({'page': dict(namespace=namespace)})['page']
            assert page['ordinal'] == '0' and page['next'] is None
            manifest = page['manifest']
            assert manifest['segments'] == '1' and manifest['selected'] == str(selected) and manifest['value_count'] == str(counted), manifest
            ipc = bytes.fromhex(page['ipc'])
            if expected_ipc is None: expected_ipc = ipc
            assert ipc == expected_ipc
            with pa.ipc.open_stream(ipc) as reader:
                assert reader.schema.names == ['present']
                assert reader.schema.field(0).type.field('value').type == pa.uint64()
                assert reader.read_all().to_pylist() == [{'present': dict(state=3, kind=2, value=counted, alternatives=[])}]
        return expected_ipc

    try:
        bundle = compile('SELECT COUNT(chosen.amount) AS present FROM (SELECT value AS amount FROM items LIMIT 10) AS chosen')
        arm()
        upload('100', bundle)
        before = partial('100')
        partial_attempt = hashlib.sha256(gate['attempt']).hexdigest()

        def persisted():
            recovered = invoke('job', '100', direct=True)
            assert recovered == before, 'disk replacement changed accepted COUNT progress or identity'

        restart('count-recovered', before_workers=persisted, after_stop=release.set)
        ipc = result('100', 10, 10)
        assert lost['retries'] and not gate['timeout']
        print(f'Unified {kind} COUNT: partial {before["checkpoint"]["progress"]["counters"]["value_count"]}/10, exact saved upload, worker/node/store replacement and {len(owners)} result/manifest consumers passed.', flush=True)

        invoke('revoke', direct=True)
        for owner in owners:
            try:
                owner.call({'page': dict(namespace='100')})
                raise AssertionError('revoked caller read a completed COUNT')
            except Failure as failure:
                assert failure.status == 4, failure
        invoke('restore', direct=True)
        assert bytes.fromhex(native.call({'page': dict(namespace='100')})['page']['ipc']) == ipc

        for namespace, phase in (('101', 'denied'), ('102', 'cancelled')):
            arm()
            upload(namespace, bundle)
            saved = partial(namespace)
            if phase == 'denied':
                invoke('request-read-revoke', direct=True)
            else:
                observe(native, native.call({'prepare': {'cancel': namespace}})['prepared'])
            release.set()
            closed = wait(namespace, phase, cleanup=True)
            assert closed['job']['phase'] in ({'cancelled', 'denied'} if phase == 'cancelled' else {phase})
            assert closed['checkpoint'] == saved['checkpoint'], 'closing COUNT reset or advanced its partial progress'
            if phase == 'denied': invoke('request-read-restore', direct=True)
            for owner in owners:
                try:
                    owner.call({'page': dict(namespace=namespace)})
                    raise AssertionError('closed COUNT exposed a result')
                except Failure as failure:
                    assert failure.detail['err'] == 'IncompleteResult', failure
            assert not gate['timeout']

        empty = compile('SELECT COUNT(chosen.amount) AS present FROM (SELECT value AS amount FROM items LIMIT 0) AS chosen')
        upload('103', empty)
        result('103', 0, 0)
        if kind == 'document':
            missing = compile('SELECT COUNT(chosen.absent) AS present FROM (SELECT optional AS absent FROM items LIMIT 10) AS chosen')
            upload('104', missing)
            result('104', 10, 0)
        evidence = dict(kind=kind, partial_progress=before['checkpoint']['progress'],
                        attempt_sha256=partial_attempt,
                        upload_retries=lost['retries'], consumers=len(owners))
        (root / 'count-evidence.json').write_text(json.dumps(evidence, indent=2) + '\n')
        print(f'Unified {kind} COUNT: current denial, cancellation after partial progress, no partial result, zero LIMIT and selected/value manifest counters passed.', flush=True)
    finally:
        release.set()
        fault.pop('count_hook', None)

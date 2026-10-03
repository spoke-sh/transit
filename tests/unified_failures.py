"""Original source failure evidence through lost receipts, SDKs and disk restart."""
import struct
import threading
import time


def check(native, port, callers, root, invoke, restart, fault, kind):
    owners = (native, port, *callers)
    namespace = '55001'
    bundle = bytearray((root / 'bundle.bin').read_bytes())
    assert bundle[:4] == b'UQB1'
    # The frozen source/plan is unchanged. Admit a one-byte result budget.
    struct.pack_into('<QQQ', bundle, 8, 1000, 100, 1)
    lost = dict(attempt=None, receipt=None, retries=0)
    lock = threading.Lock()

    def hook(path, message, body, status, data):
        if path != '/v1/command' or status != 200: return data
        request = message['request']
        if request['principal'] != 65536: return data
        command = request['command']
        turn = command.get('turn', command.get('turn_with_versions', {}).get('turn', {}))
        with lock:
            if body == lost['attempt']:
                assert data == lost['receipt'], 'failure retry changed its receipt'
                lost['retries'] += 1
            elif lost['attempt'] is None:
                for mutation in turn.get('mutations', []):
                    if not mutation or mutation['value'] is None: continue
                    value = bytes.fromhex(mutation['value'])
                    if value[:4] == b'UQJ1' and value[125] == 6:
                        assert len(value) == 167 and value[142:147] == b'\1UQF1'
                        lost.update(attempt=body, receipt=data)
                        return b'{"position":0}'
        return data

    def observe(prepared):
        receipt = native.call({'submit': prepared})['receipt']
        until = time.monotonic() + 90
        while True:
            value = native.call({'observe': receipt['position']})['observation']
            if 'committed' in value: return
            assert 'pending' in value and time.monotonic() < until, value
            time.sleep(.02)

    def parity(expected):
        for owner in owners:
            status = owner.call({'status': namespace})['status']
            assert status['phase'] in ('rejected', 'retired'), status
            assert status['failure'] == expected, (type(owner), status, expected)

    previous_hook = fault.get('count_hook')
    fault['count_hook'] = hook
    try:
        for _ in range(140):
            prepared = native.call({'next': dict(namespace=namespace, bundle=bundle.hex())})['prepared']
            if prepared is None: break
            observe(prepared)
        else: raise AssertionError('failure upload exceeded its bounded steps')
        until = time.monotonic() + 120
        while True:
            status = native.call({'status': namespace})['status']
            if status['phase'] == 'rejected' and lost['retries']: break
            assert time.monotonic() < until, (status, lost['retries'])
            time.sleep(.05)
        failure = status['failure']
        assert failure['code'] == 'budget_exceeded' and failure['stage'] == 'execution', failure
        assert failure['dimension'] == 'result_bytes' and failure['limit'] == '1' and int(failure['observed']) > 1, failure
        job = invoke('job', namespace, direct=True)['job']
        assert job['phase'] == 'failed' and job['failure']['code'] == failure['code'], job
        assert str(job['failure']['observed']) == failure['observed'], job
        parity(failure)
        restart(label='query-failure')
        parity(failure)
        assert invoke('job', namespace, direct=True)['job']['failure'] == job['failure']
        # Retiring/collecting request bytes must retain the original failure.
        observe(native.call({'prepare': {'retire': namespace}})['prepared'])
        parity(failure)
        print(f'Unified {kind} failure: result-byte witness, identical lost-receipt retry, source/requester/node/disk restart and retirement agree across {len(owners)} callers.', flush=True)
    finally:
        if previous_hook is None: fault.pop('count_hook', None)
        else: fault['count_hook'] = previous_hook

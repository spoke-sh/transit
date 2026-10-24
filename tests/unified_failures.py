"""Original source failure evidence through lost receipts, SDKs and disk restart."""
import struct
import json
import threading
import time
from unified_abi import authorize_capture


def check(native, port, callers, root, invoke, restart, fault, kind):
    owners = (native, port, *callers)
    namespace = '55001'
    bundle = bytearray((root / 'bundle-description.bin').read_bytes())
    assert bundle[:4] == b'UQB1'
    # The frozen source/plan is unchanged. Admit a one-byte result budget.
    struct.pack_into('<QQQ', bundle, 40, 1000, 100, 1)
    # This is new work: seal the changed budget before fingerprint/upload.
    # Never mutate or re-sign the accepted bundle used by earlier schedules.
    bundle = bytes.fromhex(authorize_capture(native, root, namespace, bundle.hex()))
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
                    if value[:4] != b'UQJ1': continue
                    # Four route identities, retention tag/worker, optional
                    # native version index, then the 72-byte SPF1 reference.
                    assert value[36] in (1, 2)
                    phase_offset = 45 + (1 if value[36] == 1 else 0) + 72
                    failure_offset = phase_offset + 17
                    if value[phase_offset] == 6:
                        assert len(value) == failure_offset + 1 + 112
                        assert value[failure_offset:failure_offset+5] == b'\1UQF1'
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

    def parity(expected, diagnostic):
        for owner in owners:
            try:
                status = owner.call({'status': namespace})['status']
            except Exception as error:
                child = getattr(owner, 'child', None)
                raise AssertionError(('status diagnostic caller', type(owner).__name__, child.args[:2] if child else None)) from error
            assert status['phase'] in ('denied', 'rejected', 'retired'), status
            assert status['failure'] == expected, (type(owner), status, expected)
            expected_diagnostic = dict(diagnostic, outcome='rejected' if status['phase'] == 'denied' else status['phase'])
            assert status['diagnostic'] == expected_diagnostic, (type(owner), status, expected_diagnostic)

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
        diagnostic = status['diagnostic']
        assert diagnostic['code'] == 'query.budget_exceeded' and diagnostic['identity']['id'] == namespace, diagnostic
        assert diagnostic['stage'] == 'execute' and diagnostic['evidence'] == 'domain_status', diagnostic
        facts = {fact['field']: fact['value'] for fact in diagnostic['facts'] if fact}
        assert facts['budget'] == {'text': 'result_bytes'} and facts['limit'] == {'unsigned': '1'}, facts
        assert facts['required'] == {'unsigned': failure['observed']} and facts['completion'] == {'boolean': False}, facts
        assert [action['kind'] for action in diagnostic['actions'] if action] == ['inspect_status', 'correct_input'], diagnostic
        job = invoke('job', namespace, direct=True)['job']
        assert job['phase'] == 'failed' and job['failure']['code'] == failure['code'], job
        assert str(job['failure']['observed']) == failure['observed'], job
        parity(failure, diagnostic)
        restart(label='query-failure')
        parity(failure, diagnostic)
        assert invoke('job', namespace, direct=True)['job']['failure'] == job['failure']
        # Retiring/collecting request bytes must retain the original failure.
        observe(native.call({'prepare': {'retire': namespace}})['prepared'])
        parity(failure, diagnostic)
        print(f'Unified {kind} failure: result-byte witness, identical lost-receipt retry, source/requester/node/disk restart and retirement agree across {len(owners)} callers.', flush=True)
        if kind == 'kv':
            # Alter source data through its real owner while workers are stopped.
            # The diagnostic must come from this exact failed captured page.
            restart(label='runtime-invalid', before_workers=lambda: invoke('invalidate-kv', direct=True))
            scope = {key: value for key, value in json.loads((root / 'shell.json').read_text())['workspace'].items() if key != 'executor'}
            compiled = native.call({'compile': {'scope': scope, 'sql': "SELECT * FROM items WHERE key IS NULL AND value='';", 'parameters': None}})['compiled']
            namespace = '55002'
            lost.update(attempt=None, receipt=None, retries=0)
            for _ in range(140):
                prepared = native.call({'next': dict(namespace=namespace, bundle=compiled['bundle'])})['prepared']
                if prepared is None: break
                observe(prepared)
            else: raise AssertionError('runtime failure upload exceeded bounded steps')
            until = time.monotonic() + 120
            while True:
                status = native.call({'status': namespace})['status']
                if status['phase'] == 'rejected' and lost['retries']: break
                assert time.monotonic() < until, (status, lost['retries'])
                time.sleep(.05)
            failure, diagnostic = status['failure'], status['diagnostic']
            assert failure['code'] == 'cell_type_error', failure
            facts = {fact['field']: fact for fact in diagnostic['facts'] if fact}
            for field, expected in {'source_row': {'unsigned': '1'}, 'column': {'text': 'value'},
                    'expression': {'unsigned': '1'}, 'source_key': {'text': '6b0000000000000000'},
                    'native_cause': {'text': 'invalid_utf8'}, 'actual_count': {'unsigned': '1'}}.items():
                assert facts[field]['value'] == expected and facts[field]['availability'] == 'provided', (field, facts)
            assert len(facts['source_basis']['value']['digest']) == 32, facts
            job = invoke('job', namespace, direct=True)['job']
            assert job['failure']['runtime'] is not None, job
            parity(failure, diagnostic)
            restart(label='runtime-repaired', before_workers=lambda: invoke('repair-kv', direct=True))
            parity(failure, diagnostic)
            assert invoke('job', namespace, direct=True)['job']['failure'] == job['failure']
            observe(native.call({'prepare': {'retire': namespace}})['prepared'])
            parity(failure, diagnostic)
            print(f'Unified {kind} runtime: original row/column/instruction/key/binding/decoder witness survives lost receipt, exact retry, repaired live data, disk restart and retirement across {len(owners)} callers.', flush=True)
        # Prepare the final submission before a real source policy change.
        # Submit those exact saved bytes afterwards, bypassing no owner check.
        namespace = '55003'
        requested = bytes.fromhex(authorize_capture(native, root, namespace))
        for _ in range(140):
            prepared = native.call({'next': dict(namespace=namespace, bundle=requested.hex())})['prepared']
            assert prepared is not None
            status = native.call({'status': namespace})['status']
            if status and status['phase'] == 'sealed': break
            observe(prepared)
        else: raise AssertionError('policy denial upload exceeded bounded steps')
        restart(label='policy-lowered', before_workers=lambda: invoke('lower-policy', direct=True))
        observe(prepared)
        until = time.monotonic() + 120
        while True:
            status = native.call({'status': namespace})['status']
            if status['phase'] == 'denied': break
            assert time.monotonic() < until, status
            time.sleep(.05)
        failure, diagnostic = status['failure'], status['diagnostic']
        assert failure['code'] == 'policy_denied' and failure['stage'] == 'admission', failure
        assert diagnostic['category'] == 'limit', diagnostic
        facts = {fact['field']: fact['value'] for fact in diagnostic['facts'] if fact}
        assert facts['native_cause'] == {'text': 'policy_budget'} and facts['budget'] == {'text': 'pages'}, facts
        assert facts['limit'] == {'unsigned': '999'} and facts['required'] == {'unsigned': '1000'}, facts
        parity(failure, diagnostic)
        restart(label='policy-budget')
        parity(failure, diagnostic)
        observe(native.call({'prepare': {'retire': namespace}})['prepared'])
        parity(failure, diagnostic)
        restart(label='policy-restored', before_workers=lambda: invoke('restore-policy', direct=True))
        parity(failure, diagnostic)
        print(f'Unified {kind} policy: admitted request retains source admission denial and exact allowed/requested budgets through disk restart and retirement across {len(owners)} callers.', flush=True)
    finally:
        if previous_hook is None: fault.pop('count_hook', None)
        else: fault['count_hook'] = previous_hook

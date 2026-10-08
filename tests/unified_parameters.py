"""Shared native/port/installed SDK parameters in the signed recovery schedule."""
import copy
import json
from pathlib import Path

from unified_abi import Failure

ROOT = Path(__file__).resolve().parents[1]


def compile_requests(owners, scope, kind, root, fault, *, capability_owners=()):
    fixtures = json.loads((ROOT / 'packages/zig/transit-query/src/fixtures/sql-compilation-v1.json').read_text())
    sends = fault['console_sends']
    for owner in capability_owners:
        caps = owner.call({'sql_capabilities': {}})['sql_capabilities']
        assert caps['parameters'] and caps['version'] == 1 and caps['statement_bytes'] == 4096
    requests = []
    for fixture in fixtures['cases']:
        if fixture['name'] not in ('utf8', 'ordinary', 'empty'):
            continue
        request = copy.deepcopy(fixture['request'])
        request['scope'] = scope
        requests.append({'compile': request})
        expected = None
        for owner in owners:
            compiled = owner.call({'compile': request})['compiled']
            literal = owner.call({'compile': {'scope': scope, 'sql': fixture['literal_sql']}})['compiled']
            assert compiled == literal, (fixture['name'], compiled, literal)
            if expected is None:
                expected = compiled['bundle']
            assert compiled['bundle'] == expected
            if 'source' in compiled:
                assert compiled['source'] == scope['source']
                assert compiled['limits'] == scope['limits']

    # Use the new public operation's output in the existing exact-upload,
    # lost-receipt and node/store/worker recovery schedule. A separately built
    # literal SQL fixture is the expected byte identity; installed SDKs also
    # construct typed plans independently when they open this source.
    projection = 'value AS "Result"' + (', counter, replica, optional' if kind == 'document' else '')
    request = {'scope': scope, 'sql': f'SELECT {projection} FROM items WHERE value <> $1',
               'parameters': [{'utf8': 'x' * 512}]}
    if json.loads((root / 'client.json').read_bytes()).get('compound', False):
        padding, last = (64, '10') if kind == 'document' else (128, '39')
        request['sql'] += ' AND NOT (value >= $2 OR value IS NULL)'
        request['parameters'].append({'utf8': f"東京🙂/{'x'*padding}/{last}"})
    requests.append({'compile': request})
    original = (root / 'bundle.bin').read_bytes()
    for owner in owners:
        compiled = owner.call({'compile': request})['compiled']
        assert bytes.fromhex(compiled['bundle']) == original
    (root / 'bundle.bin').write_bytes(bytes.fromhex(compiled['bundle']))
    (root / 'parameter-compilation.json').write_text(json.dumps(request))
    wrong_types = ({'signed': '-9223372036854775808'}, {'unsigned': '18446744073709551615'},
                   {'float_bits': '0000000000000080'}, {'boolean': False}, {'binary': '00ff80'})
    invalid_bindings = [([], 'ParameterCountMismatch'), (None, 'UnboundParameters')]
    invalid_bindings.extend(([value, *request['parameters'][1:]], 'TypeMismatch') for value in wrong_types)
    for parameters, error in invalid_bindings:
        invalid = {**request, 'parameters': parameters}
        original_diagnostic = None
        for owner in owners:
            try:
                owner.call({'compile': invalid})
                raise AssertionError('invalid parameter request compiled')
            except Failure as failure:
                assert failure.detail['err'] == error, failure
                diagnostic = failure.detail['diagnostic']
                assert diagnostic is not None and not failure.detail.get('diagnostic_invalid', False), failure
                assert diagnostic['outcome'] == 'not_submitted' and diagnostic['evidence'] == 'local_before_dispatch', diagnostic
                assert diagnostic['cause'] == error and diagnostic['code'].startswith('sql.'), diagnostic
                assert 'resume_exact' not in [a['kind'] for a in diagnostic['actions'] if a], diagnostic
                if original_diagnostic is None: original_diagnostic = diagnostic
                assert diagnostic == original_diagnostic, (type(owner), diagnostic, original_diagnostic)
    assert fault['console_sends'] == sends, 'compilation submitted query work'
    return requests


def rejected(owners, requests, *, retired=False):
    for owner in owners:
        for request in requests:
            try:
                owner.call(request)
                raise AssertionError('unavailable source returned a compiled bundle')
            except Failure as failure:
                if retired:
                    assert failure.detail['err'] in ('QuerySourceUnavailable', 'ResourceUnavailable', 'Rejected', 'AccessDenied', 'StateResourceExpired'), failure
                else:
                    assert failure.status == 4, failure


def uncertain_commands(owners, native, fault):
    """Every SDK keeps diagnostic + exact command after a committed lost reply."""
    import time
    previous = fault.get('count_hook')
    attempt = {}

    def hook(path, message, body, status, data):
        if path != '/v1/command' or status != 200 or message['request']['principal'] != 1234:
            return data
        if not attempt:
            attempt.update(body=body, receipt=data, retried=False)
            return b'{"position":0}'
        assert body == attempt['body'], 'uncertain caller invented another signed command'
        assert data == attempt['receipt'], 'exact retry changed its native receipt'
        attempt['retried'] = True
        return data

    fault['count_hook'] = hook
    try:
        for index, owner in enumerate(owners):
            namespace = str(57000 + index)
            prepared = native.call({'prepare': {'cancel': namespace}})['prepared']
            attempt.clear()
            try:
                owner.call({'submit': prepared})
                raise AssertionError('lost reply was reported as success')
            except Failure as failure:
                diagnostic = failure.detail['diagnostic']
                assert failure.status == 6 and not failure.detail.get('diagnostic_invalid', False), failure
                assert diagnostic['code'] == 'query.send_unknown' and diagnostic['outcome'] == 'unknown', diagnostic
                assert diagnostic['identity']['sequence'] == str(json.loads(attempt['body'])['request']['sequence']), diagnostic
                assert [a['kind'] for a in diagnostic['actions'] if a] == ['inspect_status', 'resume_exact'], diagnostic
            receipt = owner.call({'submit': prepared})['receipt']
            assert attempt['retried']
            until = time.monotonic() + 60
            while True:
                observation = native.call({'observe': receipt['position']})['observation']
                if 'pending' not in observation: break
                assert time.monotonic() < until, observation
                time.sleep(.02)
            assert 'rejected' in observation, observation
            assert native.call({'status': namespace})['status'] is None
        print(f'Unified diagnostic recovery: unknown send and exact retry survive across {len(owners)} callers; rejected cancel input creates no query outcome.', flush=True)
    finally:
        if previous is None: fault.pop('count_hook', None)
        else: fault['count_hook'] = previous

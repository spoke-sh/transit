"""Shared native/port parameter requests in the signed recovery schedule."""
import copy
import json
from pathlib import Path

from unified_abi import Failure

ROOT = Path(__file__).resolve().parents[1]


def compile_requests(owners, scope, kind, root, fault):
    fixtures = json.loads((ROOT / 'packages/zig/transit-query/src/fixtures/sql-compilation-v1.json').read_text())
    sends = fault['console_sends']
    requests = []
    for fixture in fixtures['cases']:
        if fixture['name'] not in ('utf8', 'ordinary', 'empty'):
            continue
        request = copy.deepcopy(fixture['request'])
        request['scope'] = scope
        requests.append({'compile': request})
        expected = None
        for owner in owners:
            caps = owner.call({'sql_capabilities': {}})['sql_capabilities']
            assert caps['parameters'] and caps['version'] == 1 and caps['statement_bytes'] == 4096
            compiled = owner.call({'compile': request})['compiled']
            literal = owner.call({'compile': {'scope': scope, 'sql': fixture['literal_sql']}})['compiled']
            assert compiled == literal, (fixture['name'], compiled, literal)
            if expected is None:
                expected = compiled
            assert compiled == expected
            assert compiled['source'] == scope['source']
            assert compiled['limits'] == scope['limits']

    # Use the new public operation's output in the existing exact-upload,
    # lost-receipt and node/store/worker recovery schedule. A separately built
    # Zig typed-plan fixture is the expected byte identity.
    projection = 'value AS "Result"' + (', counter, replica, optional' if kind == 'document' else '')
    request = {'scope': scope, 'sql': f'SELECT {projection} FROM items WHERE value <> $1',
               'parameters': [{'utf8': 'x' * 512}]}
    requests.append({'compile': request})
    original = (root / 'bundle.bin').read_bytes()
    for owner in owners:
        compiled = owner.call({'compile': request})['compiled']
        assert bytes.fromhex(compiled['bundle']) == original
    (root / 'bundle.bin').write_bytes(bytes.fromhex(compiled['bundle']))
    (root / 'parameter-compilation.json').write_text(json.dumps(request))
    for parameters, error in (([], 'ParameterCountMismatch'), ([{'binary': '00'}], 'TypeMismatch'),
                              (None, 'UnsupportedConstruct')):
        invalid = {**request, 'parameters': parameters}
        for owner in owners:
            try:
                owner.call({'compile': invalid})
                raise AssertionError('invalid parameter request compiled')
            except Failure as failure:
                assert failure.detail['err'] == error, failure
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

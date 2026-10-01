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
    wrong_types = ({'int64': '-9223372036854775808'}, {'uint64': '18446744073709551615'},
                   {'float_bits': '0000000000000080'}, {'boolean': False}, {'binary': '00ff80'})
    invalid_bindings = [([], 'ParameterCountMismatch'), (None, 'UnsupportedConstruct')]
    invalid_bindings.extend(([value], 'TypeMismatch') for value in wrong_types)
    for parameters, error in invalid_bindings:
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

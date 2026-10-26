"""SDK boundary fault injection: optional detail cannot erase exact recovery."""
import ctypes
import json
from pathlib import Path
from types import SimpleNamespace
import sys
from transit_client._native import Library
from transit_client.errors import UncertainOperation

api = ctypes.CDLL(sys.argv[1])
api.transit_diagnostic_validate.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
api.transit_diagnostic_validate.restype = ctypes.c_uint32
fixture = json.loads(Path('packages/zig/transit-protocol/src/fixtures/diagnostic-v1.json').read_text())
fixture.update(code='query.send_unknown', category='unavailable', stage='submit',
               outcome='unknown', evidence='saved_intent', message='Retain the exact command.')
fixture['identity'] = dict(domain='transport', id='1', realm='1', resource=None, sequence='1')
fixture['facts'] = [None] * 16
fixture['actions'] = [dict(kind='resume_exact', target=fixture['identity']), None, None, None]


def failure(raw):
    owner = object.__new__(Library)
    owner.lib = SimpleNamespace(submit=lambda output: 6)
    owner.take = lambda buffer: raw
    owner.validate_diagnostic = api.transit_diagnostic_validate
    try:
        owner.call_bytes('submit', recovery=b'exact signed command')
        raise AssertionError('failed send reported success')
    except UncertainOperation as error:
        assert error.status == 6 and error.recovery == b'exact signed command'
        return error

valid = failure(json.dumps(dict(err='ProcessExpired', diagnostic=fixture)).encode())
assert valid.diagnostic == fixture and not valid.diagnostic_invalid
fixture['message'] = 'Changed input object'
assert valid.diagnostic['message'] == 'Retain the exact command.'
assert 'Retain the exact command' not in str(valid)
for detail in ({}, {**fixture, 'definition': 'foreign'}, {**fixture, 'actions': [dict(kind='correct_input', target=None), None, None, None]}, {'message': '\udcff'}):
    rejected = failure(json.dumps(dict(err='ProcessExpired', diagnostic=detail)).encode())
    assert rejected.diagnostic is None and rejected.diagnostic_invalid
    assert rejected.code == 'ProcessExpired'
invalid = failure(b'not-json')
assert invalid.diagnostic is None and invalid.diagnostic_invalid and invalid.code is None
print('Python error boundary: owned detail, malformed JSON/UTF-8, foreign definitions and unsafe recovery actions retain primary uncertainty and exact recovery.')

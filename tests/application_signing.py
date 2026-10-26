"""Independent native signing bytes: standard Station envelope and v1 contract definition."""
import hashlib
import json
from pathlib import Path
import struct
import sys

PATH = Path(__file__).resolve().parents[1] / 'packages/zig/transit-station-app/src/fixtures/native-signing-v1.json'


def key(application, tag, principal, operation):
    return (b'\x00A' + struct.pack('>Q', application) + tag.encode() + struct.pack('>QQ', principal, operation)).hex()


def digest(domain, value):
    return list(hashlib.sha256(domain + json.dumps(value, separators=(',', ':')).encode()).digest())


def fixture():
    maximum = (1 << 64) - 1
    scope = {'realm': 49, 'application': 9, 'pid': 17, 'resource': 19, 'namespace': '23'}
    payload = b'STN1\x01' + b'\x00' * 8 + b'AP1i\x04' + struct.pack('<Q', maximum)
    request = {'version': 1, 'definition': '693b9c35bed85a9c5cbbcae180e785b616fabc0ed4a3ca37069fda3aae4233f8', 'realm': 49, 'principal': 65537, 'sequence': 8,
               'command': {'send': {'pid': 17, 'value': payload.hex(), 'role': None}}}
    keys = [key(9, 'c', 0, 0), key(9, 'p', 65537, 0), key(9, 'h', 0, 0),
            key(9, 'o', 65537, maximum), key(9, 'x', 65537, maximum), key(9, 'e', 65537, 83), key(9, 'f', 65537, 83),
            (b'\x00P' + struct.pack('>IQ', 7, 23) + b'r' + struct.pack('>QI', maximum - 1, 0)).hex()]
    query = {'version': 1, 'definition': '693b9c35bed85a9c5cbbcae180e785b616fabc0ed4a3ca37069fda3aae4233f8', 'realm': 49, 'principal': 65537,
             'kind': {'read_entries': {'resource': 19, 'revision': None, 'view': None, 'keys': keys}}}
    return {'version': 1, 'command': {'scope': scope, 'principal': 65537, 'sequence': '8',
             'command': {'publish': str(maximum)}, 'digest': digest(b'transit.request.v1\x00', request)},
            'read': {'scope': scope, 'principal': 65537, 'selection': {'state': {
                'operation': str(maximum), 'record': str(maximum - 1), 'input': 83}},
                'digest': digest(b'transit.query.v1\x00', query)}}


if __name__ == '__main__':
    expected = json.dumps(fixture(), indent=2) + '\n'
    if sys.argv[1:] == ['--write']:
        PATH.write_text(expected)
    else:
        assert not sys.argv[1:]
        assert PATH.read_text() == expected, 'application native signing fixture drift'
        print('Application signing digests match independent Station/native v1 bytes.')

"""Independent AP1 binary fixtures; layout examples do not claim body validity."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'packages/zig/transit-station-app/src/fixtures/publication-v1.json'


def fixture():
    maximum = (1 << 64) - 1
    spec = {'format': 0x41505031, 'length': 17, 'digest': list(range(32))}
    proposal = {'operation': str(maximum), 'record': str(maximum - 1),
                'expected': str(maximum - 2), 'expected_digest': list(range(32, 64)),
                'revision': str(maximum - 1), 'spec': spec}
    proposal_bytes = (struct.pack('<QQQ', maximum, maximum - 1, maximum - 2)
                      + bytes(range(32, 64)) + struct.pack('<QII', maximum - 1, spec['format'], 17)
                      + bytes(spec['digest']))
    receipt = {'proposal': proposal, 'phase': 'applied', 'input': 57, 'owns_record': True, 'conflict_basis': {'none': {}}}
    head = {'revision': proposal['revision'], 'record': proposal['record'], 'spec': spec,
            'principal': 44, 'operation': proposal['operation'], 'input': 57}
    head_bytes = (struct.pack('<QQII', maximum - 1, maximum - 1, spec['format'], 17)
                 + bytes(spec['digest']) + struct.pack('<QQQ', 44, maximum, 57))
    commands = [
        ({'initialize': {}}, b'\x00'),
        ({'policy': {'principal': 44, 'expected': '0', 'next': {'revision': '1', 'publish': True}}}, b'\x01' + struct.pack('<QQQ?', 44, 0, 1, True)),
        ({'begin': proposal}, b'\x02' + proposal_bytes),
        ({'part': {'operation': str(maximum), 'ordinal': 2, 'second': True, 'bytes': '000102'}}, b'\x03' + struct.pack('<QI?B', maximum, 2, True, 3) + b'\x00\x01\x02'),
        ({'publish': str(maximum)}, b'\x04' + struct.pack('<Q', maximum)),
        ({'abandon': str(maximum)}, b'\x05' + struct.pack('<Q', maximum)),
        ({'collect': str(maximum)}, b'\x06' + struct.pack('<Q', maximum)),
    ]
    frame = b'STN1\x01' + bytes(8) + b'AP1i\x04' + struct.pack('<Q', maximum)
    payload = hashlib.sha256(b'transit.application.input.v1\0' + frame).digest()
    cause, code = b'ApplicationDenied', b'publication.denied'
    disposition = dict(reason='ApplicationDenied', input=59, operation=str(maximum), payload=list(payload),
                       cause=cause.hex(), code=code.hex(), category='access', stage='admission')
    disposition_bytes = (b'AP1e\x03' + struct.pack('<QQ', 59, maximum) + payload
                         + bytes([len(cause)]) + cause + bytes([len(code)]) + code + b'\x04\x06')
    witness = dict(policy=dict(principal=44, expected='0', actual='2', present=True, publish=False))
    witness_bytes = b'AP1f\x01' + struct.pack('<QQQ??', 44, 0, 2, True, False)
    return {'version': 1, 'proposal': proposal, 'proposal_hex': (b'AP1r' + proposal_bytes).hex(),
            'receipt': receipt, 'receipt_hex': (b'AP1o' + proposal_bytes + b'\x02' + struct.pack('<Q', 57) + b'\x01\x00').hex(),
            'head': head, 'head_hex': (b'AP1h' + head_bytes).hex(),
            'disposition': disposition, 'disposition_hex': disposition_bytes.hex(),
            'witness': witness, 'witness_hex': witness_bytes.hex(),
            'commands': [{'command': command, 'hex': (b'AP1i' + encoded).hex()} for command, encoded in commands],
            'key_hex': (b'\x00A' + struct.pack('>Q', 9) + b'o' + struct.pack('>QQ', 44, maximum)).hex()}


if __name__ == '__main__':
    expected = json.dumps(fixture(), indent=2) + '\n'
    if sys.argv[1:] == ['--write']:
        PATH.write_text(expected)
    else:
        assert not sys.argv[1:]
        assert PATH.read_text() == expected, 'application record fixtures drifted'
        print('Application AP1 layout fixtures match independent integer/byte encoding.')

"""Independent AP1 binary fixtures; layout examples do not claim body validity."""
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
    receipt = {'proposal': proposal, 'phase': 'applied', 'input': 57, 'owns_record': True}
    head = {'revision': proposal['revision'], 'record': proposal['record'], 'spec': spec,
            'principal': 44, 'operation': proposal['operation'], 'input': 57}
    head_bytes = (struct.pack('<QQII', maximum - 1, maximum - 1, spec['format'], 17)
                 + bytes(spec['digest']) + struct.pack('<QQQ', 44, maximum, 57))
    return {'version': 1, 'proposal': proposal, 'proposal_hex': (b'AP1r' + proposal_bytes).hex(),
            'receipt': receipt, 'receipt_hex': (b'AP1o' + proposal_bytes + b'\x02' + struct.pack('<Q', 57) + b'\x01').hex(),
            'head': head, 'head_hex': (b'AP1h' + head_bytes).hex(),
            'key_hex': (b'\x00A' + struct.pack('>Q', 9) + b'o' + struct.pack('>QQ', 44, maximum)).hex()}


if __name__ == '__main__':
    expected = json.dumps(fixture(), indent=2) + '\n'
    if sys.argv[1:] == ['--write']:
        PATH.write_text(expected)
    else:
        assert not sys.argv[1:]
        assert PATH.read_text() == expected, 'application record fixtures drifted'
        print('Application AP1 layout fixtures match independent integer/byte encoding.')

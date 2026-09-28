"""Independent finite draft budget records and ordinary native commands."""
import json
from pathlib import Path
import struct
import sys

path = Path(__file__).resolve().parents[1] / 'packages/zig/transit-query/src/fixtures/draft-v1.json'
maximum = (1 << 64) - 1
payload = struct.pack('<QB', maximum - 1, 8) + bytes(range(32)) + struct.pack('<QQQ', 100, 30, 65536)
record = b'UQD1' + struct.pack('<Q', maximum) + payload + bytes([2, 0]) + struct.pack('<8Q', maximum, 1, 0, 0, 0, 0, 0, 0)
value = dict(version=1, record_hex=record.hex(), key_hex=(b'\0UD' + struct.pack('>QQ', maximum, 0)).hex(),
             open_hex=(b'UQD1' + payload).hex(), close_hex=(b'UQH1' + struct.pack('<Q', maximum)).hex(),
             submit_hex=(b'UQE1' + struct.pack('<QQ', maximum, maximum)).hex())
text = json.dumps(value, indent=2) + '\n'
if '--write' in sys.argv:
    path.write_text(text)
else:
    assert path.read_text() == text, 'draft fixture drift; run with --write'
    print('Query draft: independent command/key/record fixtures passed.')

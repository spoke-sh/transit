#!/usr/bin/env python3
"""Independent general Table catalog metadata and hashed-name bucket bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-catalog/src/fixtures/table-metadata.json'


def fixture():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    contract = bytes.fromhex(definition)
    maximum = 2**64 - 1
    scope = struct.pack('<QQQ', 1, 7, maximum)
    name = b'people'
    schema = struct.pack('<QII', 7, 0x54534301, 120) + bytes([17]) * 32
    record = b'TCM1' + contract + scope + struct.pack('<QQB', maximum, 3, len(name)) + name
    record += schema + bytes([34]) * 32 + struct.pack('<QQQ', 17, maximum, 5)
    assert len(record) == 187
    digest = hashlib.sha256(b'transit.catalog.name.v1\0' + name).digest()
    binding = b'\0C' + struct.pack('>Q', maximum) + b'N' + digest + struct.pack('>Q', maximum)
    manifest = b'TCB1' + contract + scope + struct.pack('<Q', maximum)
    assert len(binding) == 51 and len(manifest) == 68
    return {
        'definition': definition,
        'record_hex': record.hex(),
        'name_digest_hex': digest.hex(),
        'name_key_hex': binding.hex(),
        'manifest_hex': manifest.hex(),
        'inline_key_hex': (b'\0P' + struct.pack('>IQBQI', 9, maximum, ord('i'), 3, 0)).hex(),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    encoded = json.dumps(fixture(), indent=2) + '\n'
    if args.record:
        FIXTURE.write_text(encoded)
    elif not FIXTURE.is_file() or FIXTURE.read_text() != encoded:
        raise SystemExit('General Table metadata fixtures drifted; review the current format before --record.')
    print('Table catalog: independent metadata, manifest, hashed-name and namespace bytes passed.')


if __name__ == '__main__':
    main()

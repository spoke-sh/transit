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
    binding = b'\0C' + struct.pack('>Q', maximum) + b'N' + digest[:13] + struct.pack('>Q', maximum)
    manifest = b'TCB1' + contract + scope + struct.pack('<Q', maximum)
    assert len(binding) == 32 and len(manifest) == 68
    def control(tag, body):
        return (b'TCA1' + tag + contract + body).hex()
    reference = struct.pack('<QII', 3, 0x54434d01, len(record)) + bytes([51]) * 32
    configuration = control(b'C', scope + struct.pack('<QQIQI', 3, 17, 4096, 8192, 2))
    policy = control(b'P', scope + struct.pack('<QQ', 17, 9) + bytes([1, 0, 1, 1, 0, 0, 1, 0]))
    obj = control(b'O', scope + struct.pack('<QB', maximum, 2) + reference + struct.pack('<QQQQ', 4, 0, 0, 0) + bytes(32))
    operation = control(b'R', scope + struct.pack('<QQQQ', 17, maximum, maximum, maximum) + bytes([68]) * 32 + bytes([3, 3, 0]) + reference + bytes(32) + struct.pack('<QQB', 5, 7, 0))
    restricted = control(b'R', scope + struct.pack('<QQQQ', 17, maximum, maximum, maximum) + bytes([68]) * 32 + bytes([4, 5, 4]) + bytes(48) + bytes(32) + struct.pack('<QQBQQB', 5, 7, 1, maximum, 4, 2))
    dependency = control(b'B', scope + struct.pack('<QQQB', maximum, 15, 4, 1))
    commitment = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x54434d01, len(record))).digest()
    for index, offset in enumerate(range(0, len(record), 256)):
        chunk = record[offset:offset + 256]
        commitment = hashlib.sha256(b'\1' + commitment + struct.pack('<IH', index, len(chunk)) + chunk).digest()
    actual_reference = struct.pack('<QII', 3, 0x54434d01, len(record)) + commitment
    command_header = b'TCQ1' + contract + scope + struct.pack('<QQQQ', 3, 17, maximum, maximum) + actual_reference + b'\3'
    assert len(command_header) == 141
    renamed = '人々'.encode()
    rename_command = command_header + bytes([len(renamed)]) + renamed
    upload_digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x54435101, len(rename_command))).digest()
    for index, offset in enumerate(range(0, len(rename_command), 256)):
        chunk = rename_command[offset:offset + 256]
        upload_digest = hashlib.sha256(b'\1' + upload_digest + struct.pack('<IH', index, len(chunk)) + chunk).digest()
    upload = b'TCU1' + command_header + struct.pack('<QII', maximum, 0x54435101, len(rename_command)) + upload_digest
    upload += struct.pack('<BIQ', 2, len(rename_command), 5) + bytes(32) + b'\0'
    assert len(upload) == 239
    intent = b'TCI1' + contract + struct.pack('<QHII', maximum, len(record), 0, len(rename_command)) + record + rename_command
    assert len(intent) == 54 + len(record) + len(rename_command)
    assert len(bytes.fromhex(configuration)) == 93
    assert len(bytes.fromhex(policy)) == 85
    assert len(bytes.fromhex(obj)) == 182
    assert len(bytes.fromhex(operation)) == 225
    assert len(bytes.fromhex(restricted)) == 242
    return {
        'definition': definition,
        'record_hex': record.hex(),
        'name_digest_hex': digest.hex(),
        'name_key_hex': binding.hex(),
        'manifest_hex': manifest.hex(),
        'command_header_hex': command_header.hex(),
        'rename_command_hex': rename_command.hex(),
        'upload_status_hex': upload.hex(),
        'rename_intent_hex': intent.hex(),
        'inline_key_hex': (b'\0P' + struct.pack('>IQBQI', 9, maximum, ord('i'), 3, 0)).hex(),
        'controls': {'configuration': configuration, 'policy': policy, 'object': obj, 'operation': operation, 'restricted': restricted, 'dependency': dependency},
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

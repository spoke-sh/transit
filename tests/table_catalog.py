#!/usr/bin/env python3
"""Independent general Table catalog metadata and hashed-name bucket bytes."""
import argparse
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / 'packages/zig/transit-catalog/src/fixtures/table-metadata.json'
QUERY_FIXTURE = ROOT / 'packages/zig/transit-query/src/fixtures/table-source.json'


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
    catalog = fixture()
    # A query declaration commits the complete accepted metadata record while
    # carrying only its logical row descriptor for planning. Keep this encoding
    # independent of both the Zig encoder and the Table schema oracle.
    contract = bytes.fromhex(catalog['definition'])
    types = b'transit.fuze.types.v1.2026-09-30'
    logical = b'FTY1' + bytes([len(types)]) + types
    logical += b'\x16\x02\x02id\0\x0a\x07payload\x01\x19\x05\x01\x17\x01\x09'
    metadata = bytes.fromhex(catalog['record_hex'])
    digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x54434d01, len(metadata))).digest()
    digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', 0, len(metadata)) + metadata).digest()
    declaration = b'TQS1' + contract + struct.pack('<QQQQQQII', 1, 7, 2**64-1, 3, 2**64-1, 3, 0x54434d01, len(metadata)) + digest
    declaration += struct.pack('<H', len(logical)) + logical
    assert len(declaration) == 126 + len(logical)
    query = {'wire_hex': declaration.hex(), 'fingerprint_hex': hashlib.sha256(b'transit.table.query.declaration.v1\0' + declaration).hexdigest()}
    policies = []
    for tag, body in ((1, bytes.fromhex(query['fingerprint_hex'])), (2, struct.pack('<QQQQQ', 1, 7, 2**64-1, 3, 17))):
        policy = b'UQA1' + contract + struct.pack('<QQQ', 9, 8, 1) + bytes([tag]) + body + b'\1' + struct.pack('<QQQ', 100, 200, 1048576)
        assert len(policy) == (118 if tag == 1 else 126)
        policies.append(dict(wire_hex=policy.hex(), target=tag))
    for path, value in ((FIXTURE, catalog), (QUERY_FIXTURE, query), (QUERY_FIXTURE.with_name('query-policy.json'), policies)):
        encoded = json.dumps(value, indent=2) + '\n'
        if args.record:
            path.write_text(encoded)
        elif not path.is_file() or path.read_text() != encoded:
            raise SystemExit(f'General Table fixtures drifted: {path}; review the current format before --record.')
    print('Table catalog: independent metadata, manifest, hashed-name, namespace and query-source bytes passed.')


if __name__ == '__main__':
    main()

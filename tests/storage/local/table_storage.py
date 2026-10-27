#!/usr/bin/env python3
"""Independent typed Table storage keys, envelopes and native-definition binding."""
from runner.paths import ROOT
import argparse
import hashlib
import json
from pathlib import Path
import struct

FIXTURE = ROOT / 'packages/zig/transit-station/src/fixtures/table-storage.json'
INDEX_FIXTURE = FIXTURE.with_name('immutable-index.json')


def fixtures():
    definition = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    contract = bytes.fromhex(definition)
    schema = struct.pack('<QII', 7, 0x54534301, 120) + bytes([17]) * 32
    minimum = b'R' + struct.pack('>QQI', 2, 30, 0)
    index = struct.pack('<QII', 9, 0x53495801, 180) + bytes([34]) * 32
    head = b'STH1' + contract + struct.pack('<QQQ', 7, 9, 4) + schema + b'\1'
    head += index + bytes([0, len(minimum)]) + minimum + struct.pack('<Q', 3)
    head += struct.pack('<QQQB', 3, 10, 0, 0)
    assert len(head) == 213
    payload = b'typed page'
    chain = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', 0x54534301, len(payload))).digest()
    digest = hashlib.sha256(b'\1' + chain + struct.pack('<IH', 0, len(payload)) + payload).digest()
    status = b'STW1' + contract + struct.pack('<QQQQ', 7, 9, 1, 21) + bytes([51]) * 32
    status += struct.pack('<QQQQQQQBBB', 12, 15, 1, 2, 5, 1, 1, 2, 0, 1)
    status += bytes(95)  # mandatory empty execution witness
    assert len(status) == 254
    rejected = status[:100] + struct.pack('<QQQQQQQBBB', 12, 15, 1, 2, 5, 0, 0, 3, 1, 2)
    rejected += b'\1' + struct.pack('>QQI', 2, 21, 4) + struct.pack('<QBB', 0, 1, 0) + b'5' + bytes(63)
    assert len(rejected) == 254
    progress = b'STG1' + contract + bytes([51]) * 32 + struct.pack('<Q', 8) + b'\1'
    progress += index + bytes([0, len(minimum)]) + minimum + struct.pack('<Q', 3)
    progress += b'\1' + struct.pack('>QQI', 2, 30, 1) + struct.pack('<IQQ', 0, 2, 1)
    assert len(progress) == 197
    cleanup = b'STX1' + contract + bytes([51]) * 32 + struct.pack('<QQQB', 2, 600, 199, 2)
    assert len(cleanup) == 93
    return {
        'native_definition': definition,
        'manifest_hex': (b'STM1' + contract + struct.pack('<I', 65536)).hex(),
        'block_hex': (b'SBR1' + struct.pack('<II', 0x54534301, len(payload)) + digest + payload).hex(),
        'creation_receipt_hex': (b'STC1' + contract + bytes([119]) * 32 + struct.pack('<QQ', 12, 15)).hex(),
        'creation_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('c'), 0, 0)).hex(),
        'head_hex': head.hex(),
        'head_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('h'), 0, 0)).hex(),
        'history_hex': (b'STJ1' + struct.pack('<Q', 27) + head).hex(),
        'history_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('j'), 4, 0)).hex(),
        'page_key_hex': (b'\0P' + struct.pack('>IQBQI', 8, 9, ord('c'), 7, 0)).hex(),
        'write_key_hex': (b'\0W' + struct.pack('>QQQ', 9, 1, 21)).hex(),
        'write_status_hex': status.hex(),
        'write_rejection_hex': rejected.hex(),
        'statement_progress_hex': progress.hex(),
        'statement_progress_key_hex': (b'\0G' + struct.pack('>QQQ', 9, 1, 21)).hex(),
        'cleanup_hex': cleanup.hex(),
        'cleanup_key_hex': (b'\0X' + struct.pack('>QQQ', 9, 1, 21)).hex(),
    }


def index_fixtures():
    def encode(level, entries):
        body = bytearray([level, len(entries)])
        previous = b''
        for entry in entries:
            key = bytes.fromhex(entry['key'])
            prefix = 0
            while prefix < min(len(previous), len(key)) and previous[prefix] == key[prefix]:
                prefix += 1
            body += bytes([prefix, len(key) - prefix]) + key[prefix:]
            previous = key
            if level == 0:
                value = bytes.fromhex(entry['value'])
                body += struct.pack('<H', len(value)) + value
            else:
                body += struct.pack('<QII', entry['id'], 0x53495801, entry['length'])
                body += bytes.fromhex(entry['digest']) + struct.pack('<Q', entry['count'])
        packed = bytearray()
        for at in range(0, len(body), 8):
            block = body[at:at + 8]
            packed.append(sum(1 << i for i, byte in enumerate(block) if byte))
            packed.extend(byte for byte in block if byte)
        use_packed = len(packed) < len(body)
        return (b'SIX1' + struct.pack('<BH', use_packed, len(body)) +
                (packed if use_packed else body)).hex()
    cases = []
    for name, origin, operation in [('three-small', 1, 1500), ('three-wide', 65537, 2**53 + 1),
                                     ('three-maximum', 2**64 - 1, 2**64 - 1)]:
        entries = []
        for i in range(3):
            identity = struct.pack('>QQI', origin, operation, i)
            selector = hashlib.sha256(bytes([i])).digest()[:16]
            blob = struct.pack('<QII', 1200 + i, 0x54525701, 150)
            blob += hashlib.sha256(b'row' + bytes([i])).digest()
            entries += [dict(key=(b'K' + selector + identity).hex(), value=''),
                        dict(key=(b'R' + identity).hex(), value=blob.hex())]
        cases.append(dict(name=name, level=0, entries=sorted(entries, key=lambda entry: entry['key'])))
    cases.append(dict(name='raw-leaf', level=0, entries=[dict(key='7a', value=(bytes([255])*256).hex())]))
    cases.append(dict(name='maximum-leaf', level=0, entries=[dict(
        key=(bytes([i+1])*128).hex(), value=(bytes([255-i])*256).hex()) for i in range(8)]))
    cases.append(dict(name='branch', level=31, entries=[dict(key=(b'prefix' + bytes([i])).hex(),
        id=2**64-8+i, length=3000+i, digest=hashlib.sha256(bytes([i])).hexdigest(), count=2**53+i)
        for i in range(8)]))
    for case in cases:
        case['encoded'] = encode(case['level'], case['entries'])
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record', action='store_true')
    args = parser.parse_args()
    encoded = json.dumps(fixtures(), indent=2) + '\n'
    index = json.dumps(index_fixtures(), indent=2) + '\n'
    for path, content in ((FIXTURE, encoded), (INDEX_FIXTURE, index)):
        if args.record:
            path.write_text(content)
        elif not path.is_file() or path.read_text() != content:
            raise SystemExit(f'{path.name} drifted; review the current format before --record.')
    print('Typed Table storage: independent head, creation, page, manifest, receipt, statement progress, namespace and packed index bytes passed.')


if __name__ == '__main__':
    main()

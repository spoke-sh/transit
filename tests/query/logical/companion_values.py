#!/usr/bin/env python3
"""Independent canonical range/multirange/dense-vector value fixtures.

This generator uses Python integers, Decimal and struct, never Transit codecs.
The consuming Zig tests must execute the generated cases through actual logical
and Table value boundaries; checking this file alone proves only fixture drift.
"""
import argparse
from decimal import Decimal
import hashlib
import json
import struct

from runner.paths import ROOT

DEFINITION = b'transit.fuze.types.v1.2026-11-01.companions'
FIXTURE = ROOT / 'packages/zig/transit-fuze/src/fixtures/companion-values.json'


def fixtures():
    cases = []

    def add(name, descriptor, logical_type, payload, logical_value, error=None):
        encoded_type = b'FTY1' + bytes([len(DEFINITION)]) + DEFINITION + descriptor
        value = b'FVL1' + struct.pack('<H', len(encoded_type)) + encoded_type + b'\0\3' + payload
        cases.append(dict(name=name, field=dict(name='value', type=logical_type, nullable=False, optional=False),
                          cell=dict(value=logical_value), type_hex=encoded_type.hex(),
                          fingerprint=hashlib.sha256(encoded_type).hexdigest(), value_hex=value.hex(), error=error))

    def range_value(kind, lower, upper, lower_inclusive=True, upper_inclusive=False, empty=False):
        atom = dict(int64='signed', decimal='decimal', date='date_days', timestamp='timestamp_micros')[kind]
        def bound(value, inclusive):
            return None if value is None else dict(value={atom: str(value)}, inclusive=inclusive)
        flags = int(empty) | (2 if lower is not None else 0) | (4 if upper is not None else 0)
        flags |= 8 if lower is not None and lower_inclusive else 0
        flags |= 16 if upper is not None and upper_inclusive else 0
        width = dict(int64=8, decimal=16, date=4, timestamp=8)[kind]
        payload = bytes([flags]) + b''.join(value.to_bytes(width, 'little', signed=True) for value in (lower, upper) if value is not None)
        return payload, dict(is_empty=empty, lower=bound(lower, lower_inclusive), upper=bound(upper, upper_inclusive))

    domains = [
        ('int64', b'\1', {'int64': {}}, -(2**63), 2**63-1),
        ('date', b'\x11', {'date': {}}, -(2**31), 2**31-1),
        ('decimal', b'\x10\x08\x02', {'decimal': dict(precision=8, scale=2)}, int(Decimal('-1.23')*100), int(Decimal('4.56')*100)),
        ('timestamp', b'\x13\0', {'timestamp': 'civil'}, -1000001, 1000001),
        ('timestamp', b'\x13\1', {'timestamp': 'utc'}, -1000001, 1000001),
    ]
    for kind, subtype, logical_type, lower, upper in domains:
        for suffix, low, high, empty in [('bounded', lower, upper, False), ('unbounded', None, None, False), ('empty', None, None, True)]:
            payload, logical_value = range_value(kind, low, high, empty=empty)
            add(f'range/{kind}/{subtype.hex()}/{suffix}', b'\x1c'+subtype, {'range': logical_type}, payload, {'range': logical_value})
        if kind in ('decimal', 'timestamp'):
            payload, logical_value = range_value(kind, lower, upper, False, True)
            add(f'range/{kind}/{subtype.hex()}/continuous', b'\x1c'+subtype, {'range': logical_type}, payload, {'range': logical_value})
    for name, bounds, error in [
        ('separated', [(1, 3), (5, 9)], None),
        ('empty', [], None),
        ('overlap', [(1, 6), (5, 9)], 'NonCanonicalMultiRange'),
        ('adjacent', [(1, 5), (5, 9)], 'NonCanonicalMultiRange'),
        ('reversed', [(5, 9), (1, 3)], 'NonCanonicalMultiRange'),
    ]:
        runs = [range_value('int64', lower, upper) for lower, upper in bounds]
        add('multirange/'+name, b'\x1d\1', {'multirange': {'int64': {}}},
            struct.pack('<I', len(runs))+b''.join(raw for raw, _ in runs), {'multirange': [value for _, value in runs]}, error)
    for name, lower, upper, inclusive, error in [
        ('closed', 1, 3, True, 'NonCanonicalRange'),
        ('overflow', None, 2**63-1, True, 'RangeBoundOverflow'),
        ('reversed', 8, 2, False, 'NonCanonicalRange'),
    ]:
        payload, value = range_value('int64', lower, upper, upper_inclusive=inclusive)
        add('range/int64/'+name, b'\x1c\1', {'range': {'int64': {}}}, payload, {'range': value}, error)
    vectors = [
        ('float32', 1, 3, struct.pack('<3f', -0.0, 1.25, -2.5), None),
        ('float16', 2, 3, struct.pack('<3e', -0.0, 1.25, -2.5), None),
        ('bfloat16', 3, 3, struct.pack('<3H', 0x8000, 0x3fa0, 0xc020), None),
        ('int8', 4, 3, struct.pack('<3b', -128, 0, 127), None),
        ('binary', 5, 16, bytes([0xaa, 0x55]), None),
        ('float32', 1, 1, struct.pack('<I', 0x7f800000), 'InvalidVectorValue'),
        ('float16', 2, 1, struct.pack('<H', 0x7e00), 'InvalidVectorValue'),
        ('bfloat16', 3, 1, struct.pack('<H', 0xff80), 'InvalidVectorValue'),
    ]
    for element, tag, dimensions, payload, error in vectors:
        add(f'vector/{element}/{error or "finite"}', b'\x1e'+struct.pack('<IB', dimensions, tag),
            {'vector': dict(dimensions=dimensions, element=element)}, payload, {'vector': payload.hex()}, error)
    return dict(definition=DEFINITION.decode(), oracle='Python stdlib struct, integers and Decimal; independent fixed tags and range flags', cases=cases)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    document = fixtures()
    encoded = json.dumps(document, indent=2) + '\n'
    if args.write:
        FIXTURE.write_text(encoded)
    elif FIXTURE.read_text() != encoded:
        raise SystemExit('Companion value fixtures drifted; regenerate deliberately with --write')
    print(f'Companion values: {len(document["cases"])} independent canonical and refusal cases checked')


if __name__ == '__main__':
    main()

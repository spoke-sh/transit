#!/usr/bin/env python3
"""Independent CSV/JSONL framing and frozen-schema result fixtures.

Expected schemas are explicit oracle inputs. Python's csv/json/Decimal decode
records; no Transit inference implementation is imported or reproduced.
"""
from runner.paths import ROOT
import csv
from decimal import Decimal
import io
import json
from pathlib import Path
import struct
import argparse
from query.logical.fuze_types import DEFINITION, TAGS
OUTPUT = ROOT / 'packages/zig/transit-fuze/src/fixtures/sources.json'
MISSING = object()


def type_node(kind):
    if isinstance(kind, str):
        return bytes([TAGS[kind]])
    tag, child = kind
    if tag == 'decimal':
        return bytes([TAGS[tag], *child])
    if tag == 'list':
        return bytes([TAGS[tag], 1]) + type_node(child)
    if tag == 'structure':
        data = bytes([TAGS[tag], len(child)])
        for name, field_type, flags in child:
            text = name.encode()
            data += bytes([len(text)]) + text + bytes([flags]) + type_node(field_type)
        return data
    raise ValueError(kind)


def value_cell(value, kind):
    if value is MISSING:
        return b'\0'
    if value is None:
        return b'\1'
    if isinstance(kind, str):
        if kind.startswith('int') or kind.startswith('uint'):
            signed = kind.startswith('int')
            width = int(kind[3:] if signed else kind[4:])
            raw = int(value).to_bytes(width // 8, 'little', signed=signed)
        elif kind == 'boolean':
            raw = bytes([value is True or value == 'true'])
        elif kind == 'utf8':
            text = value.encode()
            raw = struct.pack('<I', len(text)) + text
        elif kind == 'json':
            text = json.dumps(value, separators=(',', ':'), ensure_ascii=False).encode()
            raw = struct.pack('<I', len(text)) + text
        else:
            raise ValueError(kind)
    else:
        tag, child = kind
        if tag == 'structure':
            raw = b''.join(value_cell(value.get(name, MISSING), typ) for name, typ, flags in child)
        elif tag == 'list':
            raw = struct.pack('<I', len(value)) + b''.join(value_cell(item, child) for item in value)
        elif tag == 'decimal':
            from decimal import localcontext
            with localcontext() as ctx:
                ctx.prec = 100
                raw = int(Decimal(value) * 10**child[1]).to_bytes(16, 'little', signed=True)
        else:
            raise ValueError(kind)
    return b'\3' + raw


def case(name, format, inputs, fields):
    logical = ('structure', fields)
    descriptor = b'FTY1' + bytes([len(DEFINITION)]) + DEFINITION + type_node(logical)
    rows = []
    for content in inputs:
        if format == 'csv':
            reader = csv.DictReader(io.StringIO(content, newline=''), strict=True)
        else:
            reader = (json.loads(line, parse_float=Decimal) for line in content.splitlines())
        for row in reader:
            rows.append((b'FVL1' + struct.pack('<H', len(descriptor)) + descriptor + b'\0' + value_cell(row, logical)).hex())
    return dict(name=name, format=format, inputs=inputs, schema_hex=descriptor.hex(), rows_hex=rows)


def fixtures():
    return {'cases': [
        case('csv/quoted-newlines-and-identifiers', 'csv', ['id,text\r\n001,"hello\r\nworld"\r\n002,"quote ""and"" comma,"\r\n'], [('id', 'utf8', 0), ('text', 'utf8', 0)]),
        case('csv/name-alignment-and-wide-integers', 'csv', ['id,n\n1,9007199254740993\n', 'n,id\n18446744073709551615,2\n'], [('id', 'int64', 0), ('n', 'int128', 0)]),
        case('json/sparse-fields-and-null', 'jsonl', ['{"id":1,"x":null}\n{"id":2}\n{"id":3,"x":"hello🙂"}\n'], [('id', 'int64', 0), ('x', 'utf8', 3)]),
        case('json/decimal-and-array', 'jsonl', ['{"amount":1.25,"items":[1,null,2]}\n{"items":[3],"amount":2.50}\n'], [('amount', ('decimal', (3, 2)), 0), ('items', ('list', 'int64'), 0)]),
        case('json/nested-sparse-object', 'jsonl', ['{"x":{"a":1}}\n{"x":{"b":true}}\n'], [('x', ('structure', [('a', 'int64', 2), ('b', 'boolean', 2)]), 0)]),
        case('json/heterogeneous-lossless-raw', 'jsonl', ['{"x":9007199254740993}\n{"x":"001"}\n'], [('x', 'json', 0)]),
    ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    text = json.dumps(fixtures(), indent=2, ensure_ascii=False) + '\n'
    if args.write:
        OUTPUT.write_text(text)
    elif OUTPUT.read_text() != text:
        raise SystemExit('Fuze source fixtures drifted; regenerate deliberately with --write')
    print(f'Fuze sources: {len(fixtures()["cases"])} independent CSV/JSONL result fixtures checked')


if __name__ == '__main__':
    main()

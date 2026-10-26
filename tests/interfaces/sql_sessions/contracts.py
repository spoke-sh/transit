"""Independent logical SQL carriage fixtures and reflected description drift check."""
from runner.paths import ROOT
import argparse
import json
from pathlib import Path
import sys

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--write', action='store_true')
parser.add_argument('--schema', action='store_true')
args = parser.parse_args()
if args.schema:
    value = json.load(sys.stdin)
    assert value['routes'] == dict(method='POST', data='/v1/sql/session', control='/v1/sql/control')
    path = ROOT / 'contracts/sql-session-v1.schema.json'
else:
    definition = b'transit.fuze.types.v1.2026-09-30'
    fields = [(b'wide', 0, 14), (b'absent', 2, 1), (b'nullable', 1, 5)]
    schema = b'FTY1' + bytes([len(definition)]) + definition + bytes([22, len(fields)])
    for name, flags, tag in fields:
        schema += bytes([len(name)]) + name + bytes([flags, tag])
    value = dict(schema=schema.hex(), cells=[(b'\x03' + (2**128 - 1).to_bytes(16, 'little')).hex(), '00', '01'])
    path = ROOT / 'packages/zig/transit-sql-protocol/src/fixtures/logical.json'
encoded = json.dumps(value, indent=2, ensure_ascii=False) + '\n'
if args.write:
    path.write_text(encoded)
else:
    assert json.loads(path.read_text()) == value, f'{path}: contract drift'
print('SQL session contract checked.', file=sys.stderr)

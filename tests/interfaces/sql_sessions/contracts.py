"""Independent logical SQL carriage fixtures and reflected description drift check."""
from runner.paths import ROOT
import argparse
import copy
import json
from pathlib import Path
import sys
from interfaces.sql_sessions.result_frame import CONTENT_TYPE, Decoder, encode_fixture

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
    current = json.loads((ROOT / 'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    observation = dict(metadata=dict(kind='probe', consistency='session', namespace=None, definitions=[], configuration_revision=None, session_settings=None, source=None))
    batch = dict(cursor=[6]*32, batch=0, schema=value['schema'], observation=observation, rows=[value['cells']], complete=True, completion=dict(rows=1))
    binary = encode_fixture(current, [2]*16, batch)
    assert Decoder().response(binary, CONTENT_TYPE, current)['result']['batch'] == batch
    for offset in (0, 4, 92, 96, 108, 140, 172, 176, 180, 184, len(binary)-1):
        mutant = bytearray(binary)
        mutant[offset] ^= 255
        try: Decoder().response(bytes(mutant), CONTENT_TYPE, current)
        except (AssertionError, ValueError, KeyError): pass
        else: raise AssertionError(('binary oracle accepted mutant', offset))
    binary_path = path.with_name('result-frame.hex')
    if args.write: binary_path.write_text(binary.hex() + '\n')
    else: assert binary_path.read_text() == binary.hex() + '\n', 'binary result fixture drift'
    native = json.loads((ROOT / 'packages/zig/transit-protocol/src/fixtures/stream-queue-v1.json').read_text())
    assert native['read']['request']['target']['definition'] == current
    intent = dict(bytes=4096, sha256=[71]*32)
    claim_position = copy.deepcopy(native['queue_cursor'])
    claim_position['next'] = native['claim']['rows']
    for kind, receipt, position, count in (
        ('append', native['append'], native['append']['append']['rows'], 4),
        ('consume', native['read'], native['read_cursor'], 1),
        ('claim', native['claim'], claim_position, 2),
    ):
        projected = dict(data=dict(workload=dict(intent=intent, schema=[73]*32,
            projection=[79]*32, selection={kind:receipt})))
        terminal = dict(rows=count, workload=dict(intent=copy.deepcopy(intent), position={kind:position}))
        selected = dict(cursor=[8]*32, batch=0, schema=value['schema'], observation=projected,
            rows=[value['cells']]*count, complete=True, completion=terminal)
        frame = encode_fixture(current, [2]*16, selected)
        assert Decoder().response(frame, CONTENT_TYPE, current)['result']['batch'] == selected
        fixture_path = path.with_name('workload-' + kind + '-frame.hex')
        if args.write: fixture_path.write_text(frame.hex() + '\n')
        else: assert fixture_path.read_text() == frame.hex() + '\n', 'workload result fixture drift'
        for change in ('missing', 'foreign_body', 'count'):
            invalid = copy.deepcopy(selected)
            if change == 'missing': del invalid['completion']['workload']
            elif change == 'foreign_body': invalid['completion']['workload']['intent']['sha256'][0] ^= 1
            else: invalid['completion']['rows'] = count + 10
            try: Decoder().response(encode_fixture(current, [2]*16, invalid), CONTENT_TYPE, current)
            except (AssertionError, ValueError, KeyError): pass
            else: raise AssertionError(('workload oracle accepted mutant', kind, change))
encoded = json.dumps(value, indent=2, ensure_ascii=False) + '\n'
if args.write:
    path.write_text(encoded)
else:
    assert json.loads(path.read_text()) == value, f'{path}: contract drift'
print('SQL session contract checked.', file=sys.stderr)

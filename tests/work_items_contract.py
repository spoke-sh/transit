"""Independent WI1 commands and domain cursor layout, before browser binding."""
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT/'examples/work-items/fixtures/commands-v1.json'


def fixture():
    cursor = b'AP1c'+struct.pack('<BBQQIQQ', 1, 1, 44, 2**64-1, 2, 33, 2)
    definition = bytes.fromhex(json.loads((ROOT/'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])
    return dict(version=1,
        catalog_initialize=(b'WI1i\x07'+definition+struct.pack('<QQQQQQQQ',49,70,1,1,3,1,1000,33)).hex(),
        put=(b'WI1i\x02'+struct.pack('<Qqq', 2**64-1, -(2**63), 20)).hex(),
        cursor=cursor.hex(),
        step=(b'WI1i\x04'+struct.pack('<QQHB', 2**32-1, 2**64-1, 1, len(cursor))+cursor).hex())


if __name__ == '__main__':
    if sys.argv[1:] == ['--write']:
        PATH.parent.mkdir(parents=True, exist_ok=True)
        PATH.write_text(json.dumps(fixture(), indent=2)+'\n')
    else:
        assert json.loads(PATH.read_text()) == fixture(), 'WI1 fixture drift'
        print('Work-item commands: independent fixed wire and full-width cursor fixtures passed.')

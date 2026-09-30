"""Independent canonical request fixtures; shared Table storage, current definition."""
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT/'packages/zig/transit-query/src/fixtures/table-mutation-v1.json'


def generate():
    definition = json.loads((ROOT/'contracts/transit-v1.schema.json').read_text())['x-transit']['definition']
    variants = [
        ('int64', 'INSERT INTO items (id,value) VALUES(-9223372036854775808,NULL),(-1,9223372036854775807),(9223372036854775807,-9223372036854775808)', 1,
         [(-2**63, None), (-1, struct.pack('<q',2**63-1)), (2**63-1, struct.pack('<q',-2**63))]),
        ('utf8', "INSERT INTO items (value,id) VALUES('é東京🙂',1),('',2)", 1, [(1,'é東京🙂'.encode()), (2,b'')]),
        ('binary', "INSERT INTO items (id,value) VALUES(1,'\\x00ff80'::bytea)", 1, [(1,b'\0\xff\x80')]),
        ('boolean', 'UPDATE items SET value=TRUE WHERE id=-9223372036854775808', 2, [(-2**63,b'\1')]),
        ('int64', 'DELETE FROM items WHERE id=9223372036854775807', 3, [(2**63-1,None)]),
    ]
    cases = []
    for kind,sql,tag,rows in variants:
        descriptor = b'TBL1'+bytes([['int64','boolean','utf8','binary'].index(kind)+1])+b'\2id\5value'
        encoded = (b'TMR1'+bytes.fromhex(definition)+struct.pack('<QQQI',46,2,7,9)
                   +bytes([len(descriptor)])+descriptor+bytes([tag,len(rows)]))
        for key,raw in rows:
            encoded += struct.pack('<q',key)
            if tag != 3:
                cell = b'\1\0' if raw is None else b'\1\1'+raw
                encoded += bytes([len(cell)])+cell
        cases.append(dict(kind=kind,sql=sql,wire_hex=encoded.hex()))
    return json.dumps(dict(version=1,definition=definition,realm=46,writer=2,resource=7,table=9,cases=cases),ensure_ascii=False,indent=2)+'\n'


if __name__ == '__main__':
    expected = generate()
    if sys.argv[1:] == ['--write']:
        FIXTURE.write_text(expected)
    else:
        assert not sys.argv[1:]
        assert FIXTURE.read_text() == expected, 'Regenerate the reviewed Table mutation request fixtures'
        print('Table mutation request: five independent definition-bound layouts and four Table value types passed.')

"""Independent canonical request fixtures; shared Table storage, current definition."""
import hashlib
import json
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT/'packages/zig/transit-query/src/fixtures/table-mutation-v1.json'
RECORDS = FIXTURE.with_name('table-mutation-records-v1.json')
WRITER = FIXTURE.with_name('table-mutation-writer-v1.json')
COMBINED = FIXTURE.with_name('table-query-writer-v1.json')


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


def records(requests):
    data = bytes.fromhex(json.loads(requests)['cases'][0]['wire_hex'])
    format_id = 0x31524d54
    chain = hashlib.sha256(b'transit.station.publication.v1\0'+struct.pack('<II',format_id,len(data))).digest()
    for ordinal,offset in enumerate(range(0,len(data),256)):
        chunk = data[offset:offset+256]
        chain = hashlib.sha256(b'\1'+chain+struct.pack('<IH',ordinal,len(chunk))+chunk).digest()
    reference = b'SPF1'+struct.pack('<QIQQII',7,4,99,1,format_id,len(data))+chain
    descriptor = b'TBL1\1\2id\5value'
    declaration = hashlib.sha256(b'transit.query.source.v1\0UQS1'+struct.pack('<QBI',7,2,9)+bytes([len(descriptor)])+descriptor).digest()
    policy = b'TML1'+struct.pack('<QIQ',10,9,4)+declaration+b'\7'
    statuses = []
    for phase,count,reason,input_id in [(1,0,0,0),(2,0,0,0),(3,3,0,123),(4,0,1,124),(5,0,0,125)]:
        value = b'TMS1'+reference+struct.pack('<QI',10,9)+declaration+struct.pack('<QBBBQ',4,phase,count,reason,input_id)
        value += struct.pack('<Bq', 2 if reason == 1 else 0, -1 if reason == 1 else 0)
        value += bytes(44)  # Mandatory absent-witness flag and canonical slot.
        statuses.append(dict(phase=phase,affected=count,reason=reason,input=input_id,wire_hex=value.hex()))
    for kind in range(1, 9):
        reason = 4 if kind <= 5 else 2
        # Non-applicable fields remain zero; expected policy revision is four.
        revision = 5 if kind in (2, 3, 4, 5) else 0
        permissions = 2 if kind in (3, 4, 5) else 0
        actual = hashlib.sha256(b'changed declaration').digest() if kind in (4, 7, 8) else bytes(32)
        witness = struct.pack('<BQB', kind, revision, permissions) + actual + bytes([1 if kind == 5 else 0])
        value = (b'TMS1' + reference + struct.pack('<QI', 10, 9) + declaration
                 + struct.pack('<QBBBQ', 4, 4, 0, reason, 126) + bytes(9) + b'\1' + witness)
        assert len(value) == 192
        statuses.append(dict(phase=4, affected=0, reason=reason, input=126, wire_hex=value.hex()))
    commands = [b'TMB1'+reference+struct.pack('<IQ',9,4),
                b'TMP1'+reference+struct.pack('<IB',0,0)+data[:128],
                b'TMP1'+reference+struct.pack('<IB',0,1)+data[128:256],
                *[tag+reference for tag in [b'TMZ1',b'TMX1',b'TMK1']], b'TME1'+struct.pack('<QQ',99,4)+data]
    # This request is shorter than one chunk. The second half is still nonempty.
    assert 128 < len(data) <= 256
    return json.dumps(dict(version=1,declaration=declaration.hex(),reference=reference.hex(),policy=policy.hex(),statuses=statuses,commands=[value.hex() for value in commands]),indent=2)+'\n'


def writer_records(encoded_records):
    values = json.loads(encoded_records)
    schema = b'TBL1\1\2id\5value'
    configuration = b'TMW1'+struct.pack('<QQQI',7,17,10,9)+bytes([len(schema)])+schema+b'\7'
    initialize = b'TMI1'+struct.pack('<Q',7)+hashlib.sha256(b'transit.table.mutation.writer.v1\0'+configuration).digest()
    policy = b'TMG1'+struct.pack('<QQ',7,3)+bytes.fromhex(values['policy'])
    frame = b'STN1\1'+bytes(8)+b'TMX1'+bytes.fromhex(values['reference'])
    payload = hashlib.sha256(b'transit.table.mutation.input.v1\0'+frame).digest()
    dispositions = [dict(reason=reason,wire_hex=(b'TME1'+struct.pack('<QQ',10,123)+payload+bytes([reason])).hex()) for reason in range(1,13)]
    return json.dumps(dict(version=1,configuration=configuration.hex(),initialize=initialize.hex(),policy_change=policy.hex(),frame=frame.hex(),dispositions=dispositions),indent=2)+'\n'


def combined_records(encoded_writer, encoded_records):
    writer = bytes.fromhex(json.loads(encoded_writer)['configuration'])
    declaration = bytes.fromhex(json.loads(encoded_records)['declaration'])
    configuration = b'TQC1'+bytes([len(writer)])+writer+struct.pack('<QQBQQQ',9,8,1,1000,100,1048576)
    identity = struct.pack('<Q',7)+hashlib.sha256(b'transit.table.query.writer.v1\0'+configuration).digest()
    definition = bytes.fromhex(json.loads((ROOT/'contracts/transit-v1.schema.json').read_text())['x-transit']['definition'])
    policy = b'UQA1'+definition+struct.pack('<QQQ',9,8,2)+b'\1'+declaration+b'\0'+struct.pack('<QQQ',1000,100,1048576)
    return json.dumps(dict(version=1,configuration=configuration.hex(),initialize=(b'TQI1'+identity).hex(),continuation=(b'TQR1'+identity).hex(),staged=(b'TQW1\1'+configuration).hex(),ready=(b'TQW1\2'+configuration).hex(),policy_change=(b'TQG1'+struct.pack('<QQ',7,1)+policy).hex()),indent=2)+'\n'


if __name__ == '__main__':
    expected = generate()
    expected_records = records(expected)
    expected_writer = writer_records(expected_records)
    expected_combined = combined_records(expected_writer, expected_records)
    if sys.argv[1:] == ['--write']:
        FIXTURE.write_text(expected)
        RECORDS.write_text(expected_records)
        WRITER.write_text(expected_writer)
        COMBINED.write_text(expected_combined)
    else:
        assert not sys.argv[1:]
        assert FIXTURE.read_text() == expected, 'Regenerate the reviewed Table mutation request fixtures'
        assert RECORDS.read_text() == expected_records, 'Regenerate the reviewed Table mutation record fixtures'
        assert WRITER.read_text() == expected_writer, 'Regenerate the reviewed Table writer fixtures'
        assert COMBINED.read_text() == expected_combined, 'Regenerate the reviewed combined Table writer fixtures'
        print('Table mutations: requests, policies, statuses, commands, writer dispositions and combined query/writer initialization agree with independent bytes.')

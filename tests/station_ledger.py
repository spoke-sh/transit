"""Independent inspection of the example's audit and typed query publications."""
import hashlib
import struct
import sys
from pathlib import Path

import pyarrow as pa

from fuze_file_query import cell_bytes, descriptor
from fuze_logical_arrow import arrow_cell

AUDIT = b'\0ledger.audit/'


def provision(system, configurations):
    """Use the launcher's explicit role/bootstrap implementation in proofs."""
    sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'launchers'))
    from authorization import Changes, station
    receipts = {}
    def command(name, body):
        if name not in receipts:
            receipts[name] = (body, system.command(body))
        assert receipts[name][0] == body
        return receipts[name][1]
    workers = {config['role']: dict(principal=config['principal'], pid=config['pid'], resource=resource,
        public_key=system.invoke('public-key', config['seed_file'])) for resource, config in configurations}
    changes = Changes(system.root / 'authorization', command, system.native_query)
    authority = station(changes, 72, workers)
    for _, config in configurations:
        config['authorization'] = authority
    if 'requester' in workers:
        next(config for _, config in configurations if config['role'] == 'ledger')['peer_principal'] = workers['requester']['principal']
    return changes


def audit_total(query, resource):
    return audit_state(query, resource)[0]


def audit_state(query, resource):
    revision = query({'resource': resource})['body']['resource']['revision']
    after, total, count = AUDIT.hex(), 0, 0
    while True:
        page = query({'entries': dict(resource=resource, revision=revision, after=after)})['body']['entries']['page']
        for entry in page['entries']:
            if entry is None:
                return total, count
            key = bytes.fromhex(entry['key'])
            if not key.startswith(AUDIT):
                return total, count
            assert len(key) == len(AUDIT) + 8
            delta, recorded = struct.unpack('<qq', bytes.fromhex(entry['value']))
            total += delta
            count += 1
            assert recorded == total, 'Audit and application computation diverged'
        if page['next'] is None:
            return total, count
        after = page['next']


def query_key(tag, first, second=0):
    return b'\0U' + tag.encode() + struct.pack('>QQ', first, second)


def read_publication(value, reference, publisher):
    assert len(reference) == 72 and reference[:4] == b'SPF1'
    resource, domain, namespace, record, fmt, length = struct.unpack_from('<QIQQII', reference, 4)
    def key(tag, index=0):
        return b'\0P' + struct.pack('>IQ', domain, namespace) + tag + struct.pack('>QI', record, index)
    head = value(resource, key(b'r'))
    assert len(head) == 104 and head[:5] == b'SPR1\2'
    assert struct.unpack_from('<II', head, 8) == (fmt, length)
    assert head[24:56] == head[56:88] == reference[40:72]
    assert struct.unpack_from('<Q', head, 88)[0] == publisher
    chunks = (length + 255) // 256
    assert struct.unpack_from('<I', head, 16)[0] == chunks
    digest = hashlib.sha256(b'transit.station.publication.v1\0' + struct.pack('<II', fmt, length)).digest()
    body = bytearray()
    for index in range(chunks):
        chunk = value(resource, key(b'c', index))
        assert len(chunk) == min(256, length - len(body))
        digest = hashlib.sha256(b'\1' + digest + struct.pack('<IH', index, len(chunk)) + chunk).digest()
        body.extend(chunk)
    assert len(body) == length and digest == reference[40:72]
    return bytes(body)


def query_result(value, requester, requester_resource, owner, resource, namespace, expected):
    status = value(requester_resource, query_key('u', namespace))
    assert status[:4] == b'UQU1' and len(status) == 160 and status[76] == 4 and status[85] == 1
    request = status[4:76]
    reference = status[86:158]
    manifest = read_publication(value, reference, owner)
    assert manifest[:4] == b'UQM1'
    job_length, checkpoint_length = struct.unpack_from('<HH', manifest, 4)
    assert len(manifest) == 8 + job_length + checkpoint_length
    job, checkpoint = manifest[8:8+job_length], manifest[8+job_length:]
    assert job[:4] == b'UQJ1' and job[125] == 3 and job[53:125] == request
    job_id, destination, correlation = struct.unpack_from('<QQQ', job, 4)
    assert destination == requester and correlation == struct.unpack_from('<Q', status, 77)[0]
    assert checkpoint[:5] == b'UQC1\2' and struct.unpack_from('<Q', checkpoint, 5)[0] == resource
    assert checkpoint[53:57] == b'FQS1' and checkpoint[178] != 0
    segments, rows = struct.unpack_from('<QQ', checkpoint, 153)
    assert rows == len(expected) and segments > 0
    chain = hashlib.sha256(b'transit.query.result.v1\0').digest()
    actual, size = [], 0
    schema = {'structure': [dict(name='id', type={'int64': {}}, nullable=False, optional=False),
                            dict(name='amount', type={'int64': {}}, nullable=True, optional=False)]}
    for ordinal in range(segments):
        segment = value(resource, query_key('s', job_id, ordinal))
        assert len(segment) == 125 and segment[:4] == b'UQS1'
        assert struct.unpack_from('<QQ', segment, 4) == (ordinal, len(actual))
        data = read_publication(value, segment[21:93], owner)
        assert hashlib.sha256(data).digest() == segment[93:125]
        with pa.ipc.open_stream(data) as reader:
            table = reader.read_all()
        assert table.schema.names == ['id', 'amount'] and table.num_rows == segment[20]
        assert table.schema.metadata[b'transit.logical_schema'] == descriptor(schema).hex().encode()
        for row in range(table.num_rows):
            record = {}
            for column, field in enumerate(schema['structure']):
                array = table.column(column).combine_chunks()
                cell = {'value': {'atom': {'signed': str(expected[len(actual)][field['name']])}}}
                assert arrow_cell(array, row, field['type']) == cell_bytes(cell, field['type'])
                record[field['name']] = array.field('value')[row].as_py()
            actual.append(record)
        size += len(data)
        chain = hashlib.sha256(chain + segment).digest()
    assert actual == expected
    assert struct.unpack_from('<Q', checkpoint, len(checkpoint)-40)[0] == size
    assert checkpoint[-32:] == chain
    return job_id

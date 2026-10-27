"""Independent TSR1/TCP1 oracle for native result tests, never a runtime client.

The oracle presents canonical cell hex to existing value assertions. Those hex
strings are local test observations; the wire contains aligned binary columns.
"""
import hashlib
import json
import struct
from query.logical.fuze_types import DEFINITION

CONTENT_TYPE = 'application/vnd.transit.sql-result'
ENCODING = 'transit.sql.result.v1.binary-columns'
HOT = (1, 2, 3, 4, 5, 6, 27)


def rounded(n):
    return (n + 63) & ~63


class Reader:
    def __init__(self, data): self.data, self.offset = data, 0
    def take(self, count):
        assert 0 <= count <= len(self.data) - self.offset
        value = self.data[self.offset:self.offset + count]
        self.offset += count
        return value
    def number(self, width): return int.from_bytes(self.take(width), 'little')
    def padded(self, count):
        value = self.take(count)
        assert not any(self.take(rounded(self.offset) - self.offset))
        return value
    def done(self): assert self.offset == len(self.data)


def schema_kinds(schema):
    r = Reader(schema)
    assert r.take(4) == b'FTY1' and r.take(r.number(1)) == DEFINITION
    def kind(depth=0):
        assert depth < 16
        tag = r.number(1)
        assert 1 <= tag <= 27
        children = []
        if tag in (22, 26):
            for _ in range(r.number(1)):
                r.take(r.number(1)).decode()
                assert r.number(1) <= 3
                children.append(kind(depth + 1)[0])
        elif tag in (23, 24, 25):
            if tag == 24: r.number(4)
            if tag == 25: kind(depth + 1)
            assert r.number(1) <= 1
            kind(depth + 1)
        elif tag == 16: r.take(2)
        elif tag == 19: assert r.number(1) <= 1
        return tag, children
    tag, fields = kind()
    assert tag == 22
    r.done()
    return fields


def column_cells(page, kind, rows, definition):
    r = Reader(page)
    assert r.take(4) == b'TCP1' and r.take(32) == bytes.fromhex(definition)
    assert r.number(1) == 0 and r.number(4) == rows
    tags = r.take(rows)
    cells = []
    for tag in tags:
        assert tag <= 4
        if tag == 0: cell = None
        elif tag == 1: cell = b'\x01'
        elif tag == 2: cell = b'\x00'
        elif tag == 3: cell = b'\x02' + r.take(1)
        else:
            count = r.number(2)
            assert 2 <= count <= 255
            cell = bytes([4, count])
            for _ in range(count):
                cell += r.take(16)
                alternative = r.number(1)
                assert alternative <= 2
                if alternative == 0: cell += b'\x01'
                elif alternative == 1: cell += b'\x02' + r.take(1)
                else:
                    value = r.take(r.number(4))
                    assert value[:1] == b'\x03'
                    cell += value
        cells.append(cell)
    if kind in HOT:
        r.padded(0)
        validity = r.padded((rows + 7) // 8)
        assert int.from_bytes(validity, 'little') == sum((tag == 0) << i for i, tag in enumerate(tags))
        if kind in (5, 6, 27):
            offsets = struct.unpack('<' + 'I' * (rows + 1), r.padded((rows + 1) * 4))
            assert offsets[0] == 0 and list(offsets) == sorted(offsets) and offsets[-1] <= 2**31-1
            data = r.padded(offsets[-1])
            values = [data[offsets[i]:offsets[i+1]] for i in range(rows)]
            for i, tag in enumerate(tags):
                if tag: assert not values[i]
            values = [struct.pack('<I', len(value)) + value for value in values]
        elif kind == 4:
            bits = int.from_bytes(r.padded((rows + 7) // 8), 'little')
            assert bits >> rows == 0
            values = [bytes([(bits >> i) & 1]) for i in range(rows)]
            assert all(tag == 0 or values[i] == b'\0' for i, tag in enumerate(tags))
        else:
            data = r.padded(rows * 8)
            values = [data[i*8:i*8+8] for i in range(rows)]
            assert all(tag == 0 or not any(values[i]) for i, tag in enumerate(tags))
        for i, tag in enumerate(tags):
            if tag == 0: cells[i] = b'\x03' + values[i]
    else:
        for i, tag in enumerate(tags):
            if tag == 0:
                cells[i] = r.take(r.number(4))
                assert cells[i][:1] == b'\x03'
    r.done()
    return [cell.hex() for cell in cells]


class Decoder:
    def __init__(self): self.descriptions = {}
    def response(self, data, content_type, definition):
        if content_type == 'application/json':
            value = json.loads(data)
            assert 'batch' not in value.get('result', {}), 'JSON result payload is obsolete'
            return value
        assert content_type == CONTENT_TYPE
        assert 192 <= len(data) <= 4194304 and data[:4] == b'TSR1'
        assert data[4:36] == bytes.fromhex(definition) and not any(data[184:192])
        ordinal, rows, flags, total = struct.unpack_from('<QIIQ', data, 84)
        assert rows <= 32 and flags <= 1 and (flags or total == 0)
        assert rows or flags
        schema_size, observation_size, width = struct.unpack_from('<III', data, 172)
        assert schema_size <= 16384 and observation_size <= 65536 and width <= 256
        assert bool(schema_size) == bool(observation_size) == (ordinal == 0)
        assert bool(width) == bool(rows)
        directory = 192 + schema_size + observation_size
        offset = rounded(directory + width * 8)
        assert offset <= len(data) and not any(data[directory + width*8:offset])
        key = data[52:84]
        commitments = data[108:172]
        if ordinal == 0:
            schema = data[192:192+schema_size]
            observation = data[192+schema_size:directory]
            assert hashlib.sha256(schema).digest() + hashlib.sha256(observation).digest() == commitments
            description = (schema.hex(), json.loads(observation), schema_kinds(schema), commitments)
            if key in self.descriptions: assert self.descriptions[key] == description
            self.descriptions[key] = description
        schema, observation, kinds, expected = self.descriptions[key]
        assert commitments == expected and (rows == 0 or len(kinds) == width)
        columns = []
        for i in range(width):
            start, size = struct.unpack_from('<II', data, directory + i*8)
            assert start == offset and size <= len(data) - offset
            end = offset + size
            offset = rounded(end)
            assert offset <= len(data) and not any(data[end:offset])
            columns.append(column_cells(data[start:end], kinds[i], rows, definition))
        assert offset == len(data)
        cells = [list(row) for row in zip(*columns)]
        assert len(cells) == rows and sum(len(bytes.fromhex(cell)) for row in cells for cell in row) <= 1048576
        return dict(version=1, definition=definition, instance=list(data[36:52]), result=dict(batch=dict(
            cursor=list(key), batch=ordinal, schema=schema, observation=observation, rows=cells,
            complete=bool(flags), completion=dict(rows=total) if flags else None)))


def encode_fixture(definition, instance, batch):
    """Encode independent scalar fixtures for the console's deliberately small peer."""
    schema = bytes.fromhex(batch['schema'])
    kinds = schema_kinds(schema)
    observation = json.dumps(batch['observation'], separators=(',', ':'), ensure_ascii=False).encode()
    rows = batch['rows']
    pages = []
    for i, kind in enumerate(kinds) if rows else ():
        cells = [bytes.fromhex(row[i]) for row in rows]
        tags = bytes({0: 2, 1: 1, 2: 3, 3: 0}[cell[0]] for cell in cells)
        page = bytearray(b'TCP1' + bytes.fromhex(definition) + b'\0' + struct.pack('<I', len(rows)) + tags)
        for cell in cells:
            if cell[0] == 2: page += cell[1:]
        def pad(): page.extend(bytes(rounded(len(page)) - len(page)))
        if kind in HOT:
            pad()
            page += sum((tag == 0) << j for j, tag in enumerate(tags)).to_bytes((len(rows)+7)//8, 'little')
            pad()
            if kind in (5, 6, 27):
                payload = bytearray()
                page += struct.pack('<I', 0)
                for cell in cells:
                    if cell[0] == 3:
                        assert int.from_bytes(cell[1:5], 'little') == len(cell)-5
                        payload += cell[5:]
                    page += struct.pack('<I', len(payload))
                pad(); page += payload
            elif kind == 4:
                page += sum((cell[0] == 3 and cell[1] == 1) << j for j, cell in enumerate(cells)).to_bytes((len(rows)+7)//8, 'little')
            else:
                for cell in cells: page += cell[1:] if cell[0] == 3 else bytes(8)
            pad()
        else:
            for cell in cells:
                if cell[0] == 3: page += struct.pack('<I', len(cell)) + cell
        pages.append(page)
    data = bytearray(192)
    data[:84] = b'TSR1' + bytes.fromhex(definition) + bytes(instance) + bytes(batch['cursor'])
    struct.pack_into('<QIIQ', data, 84, batch['batch'], len(rows), int(batch['complete']), batch['completion']['rows'] if batch['complete'] else 0)
    data[108:172] = hashlib.sha256(schema).digest() + hashlib.sha256(observation).digest()
    if batch['batch'] != 0: schema = observation = b''
    struct.pack_into('<III', data, 172, len(schema), len(observation), len(pages))
    data += schema + observation
    directory = len(data)
    data += bytes(len(pages)*8)
    data += bytes(rounded(len(data)) - len(data))
    for i, page in enumerate(pages):
        struct.pack_into('<II', data, directory+i*8, len(data), len(page))
        data += page
        data += bytes(rounded(len(data)) - len(data))
    return bytes(data)

"""Language-neutral workload and independent completion oracle; no SDK imports."""
import hashlib
import struct

LANGUAGES = ('zig', 'python-sync', 'python-async', 'node')
CASES = ('metadata', 'missing_metadata', 'empty', 'point', 'range', 'full',
         'text_empty', 'text_point', 'text_range', 'text_full',
         'write_1', 'read_after_write_1', 'write_8', 'read_after_write_8')


def text_value(index):
    # Inline, boundary, repeated, non-ASCII and long values; retain raw spelling.
    return ('', 'MiXeD  ', 'twelve bytes', '十三 bytes ☃', "quote's", 'λ雪' * 96)[index % 6]


def digest_text(rows):
    digest = hashlib.sha256()
    for key, value in sorted(rows, key=lambda row: (row[0], row[1].encode('utf8'))):
        raw = value.encode('utf8')
        digest.update(struct.pack('<qQ', key, len(raw)))
        digest.update(raw)
    return digest.hexdigest()


def digest_rows(rows):
    digest = hashlib.sha256()
    for row in sorted(rows):
        digest.update(struct.pack('<qq', *row))
    return digest.hexdigest()


def verify(result, expected):
    if result.get('complete') is not True:
        raise ValueError('Missing terminal completion')
    for field, value in expected.items():
        if result.get(field) != value or type(result[field]) is not type(value):
            raise ValueError('Incorrect independently verified ' + field)
    if type(result.get('elapsed_ns')) is not int or result['elapsed_ns'] < 0:
        raise ValueError('Invalid consumer timing')


def cases(rows):
    values = [(i, 73 + i) for i in range(rows)]
    yield 'metadata', dict(operation='lookup', name='sdk_items'), dict(rows=rows, columns=2)
    yield 'missing_metadata', dict(operation='lookup', name='sdk_missing'), dict(rows=None, columns=None)
    for name, clause, selected in (
        ('empty', 'WHERE id = -1', []),
        ('point', 'WHERE id = 0', values[:1]),
        ('range', 'WHERE id >= 7 AND id < 15', values[7:15]),
        ('full', '', values),
    ):
        yield name, dict(operation='query', name='sdk_items', sql=f'SELECT id, value FROM sdk_items {clause}'), dict(rows=len(selected), digest=digest_rows(selected))
    strings = [(i, text_value(i)) for i in range(rows)]
    for name, clause, selected in (
        ('text_empty', 'WHERE id = -1', []),
        ('text_point', 'WHERE id = 5', strings[5:6]),
        ('text_range', 'WHERE id >= 7 AND id < 15', strings[7:15]),
        ('text_full', '', strings),
    ):
        yield name, dict(operation='query', representation='text', name='sdk_text',
                         sql=f'SELECT id, value FROM sdk_text {clause}'), dict(rows=len(selected), digest=digest_text(selected))



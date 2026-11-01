"""Language-neutral workload and independent completion oracle; no SDK imports."""
import hashlib
import struct

LANGUAGES = ('zig', 'python-sync', 'python-async', 'node')
CASES = ('metadata', 'missing_metadata', 'empty', 'point', 'range', 'full',
         'write_1', 'read_after_write_1', 'write_8', 'read_after_write_8')


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



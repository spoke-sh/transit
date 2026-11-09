"""Independent scalar expectations shared by installed CLI and wire drivers."""
from dataclasses import dataclass
from decimal import Decimal
import struct


@dataclass(frozen=True)
class Case:
    kind: str
    aliases: tuple
    literal: str
    value: object
    pg_oid: int
    mysql_code: int


CASES = (
    Case('int8', ('INT8', 'TINYINT'), '-128', -128, 21, 1),
    Case('int16', ('INT16', 'SMALLINT'), '-32768', -32768, 21, 2),
    Case('int32', ('INT32', 'INT', 'INTEGER'), '-2147483648', -2147483648, 23, 3),
    Case('int64', ('INT64', 'BIGINT'), '-9223372036854775808', -2**63, 20, 8),
    Case('uint8', ('UINT8',), '255', 255, 21, 1),
    Case('uint16', ('UINT16',), '65535', 65535, 23, 2),
    Case('uint32', ('UINT32',), '4294967295', 2**32-1, 20, 3),
    Case('uint64', ('UINT64',), '18446744073709551615', 2**64-1, 1700, 8),
    Case('float32', ('FLOAT32', 'REAL'), '-1.25', -1.25, 700, 4),
    Case('float64', ('FLOAT64', 'DOUBLE', 'DOUBLE PRECISION', 'FLOAT'), '-1.25', -1.25, 701, 5),
    Case('decimal', ('DECIMAL(38,2)', 'NUMERIC(38,2)'), '-123456789012345678901234567890123456.78', Decimal('-123456789012345678901234567890123456.78'), 1700, 246),
    Case('boolean', ('BOOLEAN', 'BOOL'), 'TRUE', True, 16, 1),
    Case('utf8', ('UTF8', 'TEXT', 'VARCHAR', 'CHARACTER VARYING'), "'snow ☃ and 列'", 'snow ☃ and 列', 25, 253),
    Case('binary', ('BINARY', 'BLOB', 'BYTEA'), "X'00ff'", b'\x00\xff', 17, 252),
)

# This is deliberately explicit. Adding a native type or alias requires a
# reviewed disposition, rather than silently narrowing the test to a whitelist.
UNSUPPORTED_ALIASES = ('INT128', 'UINT128', 'DATE', 'TIME', 'TIMESTAMP', 'TIMESTAMPTZ', 'INTERVAL', 'UUID', 'JSON', 'CAPABILITY')
UNSUPPORTED_KINDS = ('int128', 'uint128', 'date', 'time', 'timestamp', 'interval', 'uuid', 'structure', 'list', 'array', 'map', 'tagged_union', 'json', 'range', 'multirange', 'vector', 'capability')


def native_cell(cell, descriptor):
    if 'null' in cell:
        return None
    atom = cell['value']['atom']
    key, value = next(iter(atom.items()))
    if key in ('signed', 'unsigned'):
        return int(value)
    if key == 'decimal':
        scale = descriptor['decimal']['scale']
        digits = str(abs(int(value))).zfill(scale+1)
        return Decimal(('-' if int(value)<0 else '')+(digits[:-scale]+'.'+digits[-scale:] if scale else digits))
    if key == 'float_bits':
        raw = bytes.fromhex(value)
        return struct.unpack('<f' if len(raw)==4 else '<d', raw)[0]
    if key == 'binary':
        return bytes.fromhex(value)
    assert key in ('boolean', 'utf8'), atom
    return value


def native_rows(result):
    fields = result['schema']['type']['structure']
    assert int(result['complete']['rows']) == len(result['rows'])
    return [tuple(native_cell(cell, field['type']) for cell, field in zip(row, fields, strict=True)) for row in result['rows']]


def cli_cell(text, kind, protocol):
    if text == ('\\N' if protocol == 'postgres' else 'NULL'):
        return None
    if kind.startswith(('int', 'uint')):
        return int(text)
    if kind.startswith('float'):
        return float(text)
    if kind == 'decimal':
        return Decimal(text)
    if kind == 'boolean':
        assert text in ('t', 'f', '0', '1'), text
        return text in ('t', '1')
    if kind == 'binary':
        assert text[:2] in ('\\x', '0x', '0X'), text
        return bytes.fromhex(text[2:])
    return text

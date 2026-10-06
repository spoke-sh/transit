"""Owned language-native logical descriptors and cells, separate from ABI JSON."""
from __future__ import annotations
from dataclasses import dataclass
import math
import struct
from typing import Any, Literal, TypeAlias

ScalarKind = Literal['int8', 'int16', 'int32', 'int64', 'int128', 'uint8', 'uint16', 'uint32', 'uint64', 'uint128',
                     'float32', 'float64', 'boolean', 'utf8', 'binary', 'date', 'time', 'interval', 'uuid', 'json']
_SCALARS = frozenset(('int8', 'int16', 'int32', 'int64', 'int128', 'uint8', 'uint16', 'uint32', 'uint64', 'uint128',
                     'float32', 'float64', 'boolean', 'utf8', 'binary', 'date', 'time', 'interval', 'uuid', 'json'))


@dataclass(frozen=True, slots=True)
class ScalarType:
    kind: ScalarKind
    def __post_init__(self) -> None:
        if self.kind not in _SCALARS: raise ValueError('Unknown scalar type')


@dataclass(frozen=True, slots=True)
class DecimalType:
    precision: int
    scale: int


@dataclass(frozen=True, slots=True)
class TimestampType:
    zone: Literal['civil', 'utc']


@dataclass(frozen=True, slots=True)
class Field:
    name: str
    type: Descriptor
    nullable: bool = False
    optional: bool = False


@dataclass(frozen=True, slots=True)
class Element:
    type: Descriptor
    nullable: bool = False


@dataclass(frozen=True, slots=True)
class StructureType:
    fields: tuple[Field, ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'fields', tuple(self.fields))


@dataclass(frozen=True, slots=True)
class UnionType:
    fields: tuple[Field, ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'fields', tuple(self.fields))


@dataclass(frozen=True, slots=True)
class ListType:
    element: Element


@dataclass(frozen=True, slots=True)
class ArrayType:
    element: Element
    length: int


@dataclass(frozen=True, slots=True)
class MapType:
    key: Descriptor
    value: Element


Descriptor: TypeAlias = ScalarType | DecimalType | TimestampType | StructureType | UnionType | ListType | ArrayType | MapType
AtomKind = Literal['signed', 'unsigned', 'decimal', 'float', 'boolean', 'utf8', 'binary', 'date_days', 'time_nanos', 'timestamp_micros', 'interval', 'uuid']


@dataclass(frozen=True, slots=True)
class Interval:
    months: int
    days: int
    nanos: int


@dataclass(frozen=True, slots=True)
class Atom:
    kind: AtomKind
    value: int | float | bool | str | bytes | Interval
    width: Literal[32, 64] | None = None
    def __post_init__(self) -> None:
        if isinstance(self.value, (bytes, bytearray, memoryview)): object.__setattr__(self, 'value', bytes(self.value))


@dataclass(frozen=True, slots=True)
class SequenceValue:
    kind: Literal['structure', 'list', 'array']
    cells: tuple[Cell, ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'cells', tuple(self.cells))


@dataclass(frozen=True, slots=True)
class MapEntry:
    key: Atom
    value: Cell


@dataclass(frozen=True, slots=True)
class MapValue:
    entries: tuple[MapEntry, ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'entries', tuple(self.entries))


@dataclass(frozen=True, slots=True)
class TaggedValue:
    index: int
    value: Cell


@dataclass(frozen=True, slots=True)
class JsonValue:
    json: str


CellValue: TypeAlias = Atom | SequenceValue | MapValue | TaggedValue | JsonValue


@dataclass(frozen=True, slots=True)
class Missing:
    pass


@dataclass(frozen=True, slots=True)
class Null:
    pass


@dataclass(frozen=True, slots=True)
class SourceTypeError:
    actual: ScalarKind | Literal['decimal', 'timestamp', 'structure', 'tagged_union', 'list', 'array', 'map']
    def __post_init__(self) -> None:
        if self.actual not in _SCALARS | {'decimal', 'timestamp', 'structure', 'tagged_union', 'list', 'array', 'map'}: raise ValueError('Unknown source type')


@dataclass(frozen=True, slots=True)
class Present:
    value: CellValue


@dataclass(frozen=True, slots=True)
class Alternative:
    counter: int
    replica: int
    value: Null | SourceTypeError | Present


@dataclass(frozen=True, slots=True)
class Conflict:
    alternatives: tuple[Alternative, ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'alternatives', tuple(self.alternatives))


Cell: TypeAlias = Missing | Null | SourceTypeError | Present | Conflict


class _Budget:
    def __init__(self, maximum: int) -> None:
        self.maximum, self.nodes, self.bytes, self.names = maximum, 0, 0, 0
    def enter(self, depth: int) -> None:
        self.nodes += 1
        if depth >= 16 or self.nodes > self.maximum: raise ValueError('Logical value exceeds its nesting/child bound')
    def data(self, length: int) -> None:
        self.bytes += length
        if self.bytes > 1024 * 1024: raise ValueError('Logical value exceeds its byte bound')
    def name(self, value: object) -> str:
        text = _text(value)
        self.names += len(text.encode())
        if self.names > 4096: raise ValueError('Logical type exceeds its name byte bound')
        return text


def _object(value: object, fields: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != set(fields.split()): raise ValueError('Unexpected logical fields')
    return value


def _variant(value: object) -> tuple[str, Any]:
    if not isinstance(value, dict) or len(value) != 1: raise ValueError('Expected one logical variant')
    kind, payload = next(iter(value.items()))
    if not isinstance(kind, str): raise ValueError('Expected logical tag')
    return kind, payload


def _boolean(value: object) -> bool:
    if type(value) is not bool: raise ValueError('Expected boolean')
    return value


def _integer(value: object, low: int = -(1 << 127), high: int = (1 << 128) - 1) -> int:
    if type(value) is not int or not low <= value <= high: raise ValueError('Expected bounded exact integer')
    return value


def _decimal(value: object) -> int:
    if not isinstance(value, str) or not 1 <= len(value) <= 40: raise ValueError('Invalid logical integer')
    number = _integer(int(value))
    if str(number) != value: raise ValueError('Noncanonical logical integer')
    return number


def _text(value: object) -> str:
    if not isinstance(value, str): raise ValueError('Expected logical text')
    value.encode('utf8')
    return value


def type_wire(value: Descriptor, budget: _Budget | None = None, depth: int = 0) -> dict[str, Any]:
    budget = budget or _Budget(256)
    budget.enter(depth)
    def element(item: Element) -> object: return dict(type=type_wire(item.type, budget, depth + 1), nullable=_boolean(item.nullable))
    if isinstance(value, ScalarType): return {value.kind: {}}
    if isinstance(value, DecimalType): return {'decimal': dict(precision=_integer(value.precision, 1, 38), scale=_integer(value.scale, 0, value.precision))}
    if isinstance(value, TimestampType):
        if value.zone not in ('civil', 'utc'): raise ValueError('Unknown timestamp zone')
        return {'timestamp': value.zone}
    if isinstance(value, (StructureType, UnionType)):
        return {'structure' if isinstance(value, StructureType) else 'tagged_union': [dict(name=budget.name(item.name), type=type_wire(item.type, budget, depth + 1), nullable=_boolean(item.nullable), optional=_boolean(item.optional)) for item in value.fields]}
    if isinstance(value, ListType): return {'list': element(value.element)}
    if isinstance(value, ArrayType): return {'array': dict(element=element(value.element), length=_integer(value.length, 1, 0xffffffff))}
    if isinstance(value, MapType): return {'map': dict(key=type_wire(value.key, budget, depth + 1), value=element(value.value))}
    raise TypeError('Expected logical descriptor')


def type_from_wire(value: object, budget: _Budget | None = None, depth: int = 0) -> Descriptor:
    budget = budget or _Budget(256)
    budget.enter(depth)
    kind, payload = _variant(value)
    def element(value: object) -> Element:
        item = _object(value, 'type nullable')
        return Element(type_from_wire(item['type'], budget, depth + 1), _boolean(item['nullable']))
    if kind in _SCALARS:
        _object(payload, '')
        return ScalarType(kind)  # type: ignore[arg-type]
    if kind == 'decimal':
        item = _object(payload, 'precision scale')
        return DecimalType(_integer(item['precision'], 1, 38), _integer(item['scale'], 0, item['precision']))
    if kind == 'timestamp':
        if payload not in ('civil', 'utc'): raise ValueError('Unknown timestamp zone')
        return TimestampType(payload)
    if kind in ('structure', 'tagged_union'):
        if not isinstance(payload, list): raise ValueError('Expected logical fields')
        fields = []
        for source in payload:
            item = _object(source, 'name type nullable optional')
            fields.append(Field(budget.name(item['name']), type_from_wire(item['type'], budget, depth + 1), _boolean(item['nullable']), _boolean(item['optional'])))
        return StructureType(tuple(fields)) if kind == 'structure' else UnionType(tuple(fields))
    if kind == 'list': return ListType(element(payload))
    if kind == 'array':
        item = _object(payload, 'element length')
        return ArrayType(element(item['element']), _integer(item['length'], 1, 0xffffffff))
    if kind == 'map':
        item = _object(payload, 'key value')
        return MapType(type_from_wire(item['key'], budget, depth + 1), element(item['value']))
    raise ValueError('Unknown logical type')


def atom_wire(value: Atom, budget: _Budget | None = None) -> dict[str, Any]:
    budget = budget or _Budget(65536)
    if not isinstance(value, Atom): raise TypeError('Expected logical atom')
    kind, data = value.kind, value.value
    if kind != 'float' and value.width is not None: raise ValueError('Width belongs only to floats')
    if kind in ('signed', 'unsigned', 'decimal', 'date_days', 'time_nanos', 'timestamp_micros'):
        return {kind: str(_integer(data))}
    if kind == 'interval':
        if not isinstance(data, Interval): raise ValueError('Expected logical interval')
        return {kind: dict(months=str(_integer(data.months)), days=str(_integer(data.days)), nanos=str(_integer(data.nanos)))}
    if kind == 'float':
        if type(data) is not float or not math.isfinite(data) or value.width not in (32, 64): raise ValueError('Expected finite float with explicit width')
        try: bits = struct.pack('<f' if value.width == 32 else '<d', data)
        except OverflowError: raise ValueError('Float exceeds its selected width') from None
        budget.data(len(bits))
        return {'float_bits': bits.hex()}
    if kind == 'boolean': return {kind: _boolean(data)}
    if kind == 'utf8':
        text = _text(data); budget.data(len(text.encode()))
        return {kind: text}
    if kind in ('binary', 'uuid'):
        if not isinstance(data, bytes): raise ValueError('Expected logical bytes')
        if kind == 'uuid' and len(data) != 16: raise ValueError('Expected UUID bytes')
        budget.data(len(data))
        return {kind: data.hex()}
    raise ValueError('Unknown logical atom')


def atom_from_wire(value: object, budget: _Budget | None = None) -> Atom:
    budget = budget or _Budget(65536)
    kind, payload = _variant(value)
    if kind in ('signed', 'unsigned', 'decimal', 'date_days', 'time_nanos', 'timestamp_micros'):
        return Atom(kind, _decimal(payload))  # type: ignore[arg-type]
    if kind == 'interval':
        item = _object(payload, 'months days nanos')
        return Atom('interval', Interval(_decimal(item['months']), _decimal(item['days']), _decimal(item['nanos'])))
    if kind == 'boolean': return Atom('boolean', _boolean(payload))
    if kind == 'utf8':
        text = _text(payload); budget.data(len(text.encode()))
        return Atom('utf8', text)
    if kind in ('binary', 'uuid', 'float_bits'):
        text = _text(payload)
        if len(text) > 2 * 1024 * 1024: raise ValueError('Logical bytes exceed their bound')
        data = bytes.fromhex(text)
        if data.hex() != text: raise ValueError('Noncanonical logical bytes')
        budget.data(len(data))
        if kind == 'float_bits':
            if len(data) not in (4, 8): raise ValueError('Invalid logical float width')
            number = struct.unpack('<f' if len(data) == 4 else '<d', data)[0]
            if not math.isfinite(number): raise ValueError('Nonfinite logical float')
            return Atom('float', number, 32 if len(data) == 4 else 64)
        if kind == 'uuid' and len(data) != 16: raise ValueError('Invalid UUID bytes')
        return Atom(kind, data)  # type: ignore[arg-type]
    raise ValueError('Unknown logical atom')


def _conflict_dot(counter: int, replica: int, previous: tuple[int, int]) -> tuple[int, int]:
    dot = _integer(counter, 1, (1 << 64) - 1), _integer(replica, 1, (1 << 64) - 1)
    if dot <= previous: raise ValueError('Expected increasing positive conflict dots')
    return dot


def cell_wire(value: Cell, budget: _Budget | None = None, depth: int = 0) -> dict[str, Any]:
    budget = budget or _Budget(65536)
    budget.enter(depth)
    if isinstance(value, Missing): return {'missing': {}}
    if isinstance(value, Null): return {'null': {}}
    if isinstance(value, SourceTypeError): return {'type_error': value.actual}
    if isinstance(value, Conflict):
        if not 2 <= len(value.alternatives) <= 8: raise ValueError('Expected two to eight conflict alternatives')
        alternatives = []
        previous = (0, 0)
        for alternative in value.alternatives:
            previous = _conflict_dot(alternative.counter, alternative.replica, previous)
            if not isinstance(alternative.value, (Null, SourceTypeError, Present)): raise ValueError('Invalid conflict alternative')
            alternatives.append(dict(counter=str(alternative.counter), replica=str(alternative.replica), value=cell_wire(alternative.value, budget, depth)))
        return {'conflict': alternatives}
    if not isinstance(value, Present): raise TypeError('Expected logical cell')
    item = value.value
    if isinstance(item, Atom): data: object = {'atom': atom_wire(item, budget)}
    elif isinstance(item, SequenceValue):
        if item.kind not in ('structure', 'list', 'array'): raise ValueError('Unknown logical sequence')
        data = {item.kind: [cell_wire(child, budget, depth + 1) for child in item.cells]}
    elif isinstance(item, MapValue):
        entries = []
        for entry in item.entries:
            budget.enter(depth + 1)
            entries.append(dict(key=atom_wire(entry.key, budget), value=cell_wire(entry.value, budget, depth + 1)))
        data = {'map': entries}
    elif isinstance(item, TaggedValue): data = {'tagged_union': dict(index=_integer(item.index, 0, 255), value=cell_wire(item.value, budget, depth + 1))}
    elif isinstance(item, JsonValue):
        text = _text(item.json); budget.data(len(text.encode()))
        data = {'json': text}
    else: raise TypeError('Expected typed logical value')
    return {'value': data}


def cell_from_wire(value: object, budget: _Budget | None = None, depth: int = 0) -> Cell:
    budget = budget or _Budget(65536)
    budget.enter(depth)
    kind, payload = _variant(value)
    if kind in ('missing', 'null'):
        _object(payload, '')
        return Missing() if kind == 'missing' else Null()
    if kind == 'type_error': return SourceTypeError(_text(payload))  # type: ignore[arg-type]
    if kind == 'conflict':
        if not isinstance(payload, list) or not 2 <= len(payload) <= 8: raise ValueError('Expected two to eight conflict alternatives')
        alternatives = []
        previous = (0, 0)
        for source in payload:
            item = _object(source, 'counter replica value')
            previous = _conflict_dot(_decimal(item['counter']), _decimal(item['replica']), previous)
            cell = cell_from_wire(item['value'], budget, depth)
            if isinstance(cell, (Missing, Conflict)): raise ValueError('Invalid conflict alternative')
            alternatives.append(Alternative(*previous, cell))
        return Conflict(tuple(alternatives))
    if kind != 'value': raise ValueError('Unknown logical cell state')
    kind, payload = _variant(payload)
    if kind == 'atom': return Present(atom_from_wire(payload, budget))
    if kind in ('structure', 'list', 'array'):
        if not isinstance(payload, list): raise ValueError('Expected sequence cells')
        return Present(SequenceValue(kind, tuple(cell_from_wire(child, budget, depth + 1) for child in payload)))  # type: ignore[arg-type]
    if kind == 'map':
        if not isinstance(payload, list): raise ValueError('Expected map entries')
        entries = []
        for source in payload:
            item = _object(source, 'key value')
            budget.enter(depth + 1)
            entries.append(MapEntry(atom_from_wire(item['key'], budget), cell_from_wire(item['value'], budget, depth + 1)))
        return Present(MapValue(tuple(entries)))
    if kind == 'tagged_union':
        item = _object(payload, 'index value')
        return Present(TaggedValue(_integer(item['index'], 0, 255), cell_from_wire(item['value'], budget, depth + 1)))
    if kind == 'json':
        text = _text(payload); budget.data(len(text.encode()))
        return Present(JsonValue(text))
    raise ValueError('Unknown logical value')

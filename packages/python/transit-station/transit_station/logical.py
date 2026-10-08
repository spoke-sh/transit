"""Owned logical documents. Shared Zig validates types, values and operations.

Documents use the public logical JSON contract, including string integers and
float bits. These local values do not grant query/storage/transport admission.
"""
from __future__ import annotations
from builtins import bytes as Bytes
from dataclasses import dataclass
from pathlib import Path
from types import TracebackType
from typing import Any, Literal
from transit_client._native import Library, encode
from transit_client._worker import Worker
from transit_client.types import owned_bytes


from .logical_values import (
    ScalarType as ScalarType,
    DecimalType as DecimalType,
    TimestampType as TimestampType,
    Field as Field,
    Element as Element,
    StructureType as StructureType,
    UnionType as UnionType,
    ListType as ListType,
    ArrayType as ArrayType,
    MapType as MapType,
    Interval as Interval,
    Atom as Atom,
    SequenceValue as SequenceValue,
    MapEntry as MapEntry,
    MapValue as MapValue,
    TaggedValue as TaggedValue,
    JsonValue as JsonValue,
    Missing as Missing,
    Null as Null,
    SourceTypeError as SourceTypeError,
    Present as Present,
    Alternative as Alternative,
    Conflict as Conflict,
    Descriptor as Descriptor,
    CellValue as CellValue,
    Cell as Cell,
    ScalarKind as ScalarKind,
    AtomKind as AtomKind,
)

Rounding = Literal['reject', 'toward_zero', 'nearest_even']


@dataclass(frozen=True, slots=True, init=False)
class Type:
    json: str
    bytes: bytes
    fingerprint: Bytes
    equality: bool
    ordering: bool

    @staticmethod
    def _owned(value: dict[str, Any]) -> Type:
        result = object.__new__(Type)
        for name in ('json', 'bytes', 'fingerprint', 'equality', 'ordering'):
            data = value[name]
            object.__setattr__(result, name, bytes.fromhex(data) if name in ('bytes', 'fingerprint') else data)
        return result


@dataclass(frozen=True, slots=True, init=False)
class Value:
    json: str
    bytes: bytes

    @staticmethod
    def _owned(value: dict[str, Any]) -> Value:
        result = object.__new__(Value)
        object.__setattr__(result, 'json', value['json'])
        object.__setattr__(result, 'bytes', bytes.fromhex(value['bytes']))
        return result


class Codec:
    """Local synchronous codec with a bounded native worker; no credentials/I/O.

    All returned documents/bytes survive close. Do not overlap calls on one
    instance. Use a separate instance in each concurrently executing host task.
    """
    def __init__(self, *, native_directory: Path | None = None) -> None:
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        self._closed = False

    def _call(self, action: object) -> dict[str, Any]:
        if self._closed: raise RuntimeError('Logical codec is closed')
        data = owned_bytes(encode(action), 256 * 1024)
        def call() -> dict[str, Any]:
            result: dict[str, Any] = self._api.call('station_logical_codec', data, len(data))
            return result
        return self._worker.call(call)

    def type_json(self, document: str) -> Type:
        return Type._owned(self._call({'type_json': document})['type'])

    def type_bytes(self, data: bytes) -> Type:
        return Type._owned(self._call({'type_bytes': owned_bytes(data, 16384).hex()})['type'])

    def value_json(self, document: str) -> Value:
        return Value._owned(self._call({'value_json': document})['value'])

    def value_bytes(self, data: bytes) -> Value:
        return Value._owned(self._call({'value_bytes': owned_bytes(data, 96 * 1024).hex()})['value'])

    def bind(self, datatype: Type, literal: str) -> Value:
        return Value._owned(self._call({'bind': {'type_json': datatype.json, 'literal': literal}})['value'])

    def cast(self, value: Value, target: Type, *, rounding: Rounding = 'reject') -> Value:
        return Value._owned(self._call({'cast': {'value_json': value.json, 'type_json': target.json, 'rounding': rounding}})['value'])

    def equal(self, left: Value, right: Value) -> bool:
        result: bool = self._call({'equal': {'left_json': left.json, 'right_json': right.json}})['equal']
        return result

    def order(self, left: Value, right: Value) -> Literal['lt', 'eq', 'gt']:
        result: Literal['lt', 'eq', 'gt'] = self._call({'order': {'left_json': left.json, 'right_json': right.json}})['order']
        return result

    def hash(self, value: Value) -> bytes:
        return bytes.fromhex(self._call({'hash': value.json})['hash'])

    def arrow(self, value: Value) -> bytes:
        """Owned one-column IPC stream, preserving all five cell states."""
        return bytes.fromhex(self._call({'arrow': value.json})['arrow']['ipc'])

    def close(self) -> None:
        if not self._closed:
            self._closed = True
            self._worker.close(lambda: None)

    def __enter__(self) -> Codec: return self
    def __exit__(self, kind: type[BaseException] | None, error: BaseException | None,
                 traceback: TracebackType | None) -> None: self.close()

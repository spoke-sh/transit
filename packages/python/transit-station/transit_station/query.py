"""Bounded query plans and scoped readers; copied IPC owns no resource lifetime."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
import importlib
from typing import Any
from transit_client import ProcessRef, ResourceRef
from transit_client.types import integer
from transit_client.errors import UnsupportedCapability
from .models import Basis
from .turn import Cell, CellType, ReadVersion, Turn, U64_MAX, _cell


class Projection(Enum):
    BOTH = 'both'
    KEY = 'key'
    VALUE = 'value'


class Aggregate(Enum):
    ROWS = 'rows'
    COUNT = 'count'
    SUM = 'sum'
    COUNT_VALUES = 'count_values'


class Comparison(Enum):
    EQ = 'eq'
    NE = 'ne'
    LT = 'lt'
    LE = 'le'
    GT = 'gt'
    GE = 'ge'


@dataclass(frozen=True, slots=True)
class Predicate:
    column: int
    comparison: Comparison | None = None
    value: Cell = field(default=None, repr=False)
    def __post_init__(self) -> None:
        integer(self.column, 'column', minimum=0, maximum=1)
        if self.comparison is not None and not isinstance(self.comparison, Comparison):
            raise TypeError('Expected Comparison')

    def _wire(self, limit: int) -> object:
        if self.comparison is None:
            if self.value is not None:
                raise ValueError('Null predicate cannot carry a comparison value')
            return {'is_null': self.column}
        value = self.value
        kind = CellType.BOOLEAN if type(value) is bool else CellType.INT64 if type(value) is int else CellType.UTF8 if isinstance(value, str) else CellType.BINARY
        return {'compare': {'column': self.column, 'op': self.comparison.value, 'value': _cell(value, kind, limit)}}


@dataclass(frozen=True, slots=True)
class QueryPlan:
    projection: Projection = Projection.BOTH
    limit: int | None = None
    aggregate: Aggregate = Aggregate.ROWS
    predicate: Predicate | None = None
    def __post_init__(self) -> None:
        if not isinstance(self.projection, Projection) or not isinstance(self.aggregate, Aggregate):
            raise TypeError('Select typed query projection and aggregate')
        if self.limit is not None:
            integer(self.limit, 'query limit', minimum=0, maximum=U64_MAX)
        if self.predicate is not None and not isinstance(self.predicate, Predicate):
            raise TypeError('Expected Predicate')

    def _wire(self, cell_limit: int) -> object:
        return {'projection': self.projection.value, 'aggregate': self.aggregate.value,
                'limit': None if self.limit is None else str(self.limit),
                'predicate': {'all': {}} if self.predicate is None else self.predicate._wire(cell_limit)}


@dataclass(frozen=True, slots=True)
class QueryJob:
    result: int
    correlation: int
    source: ReadVersion


@dataclass(frozen=True, slots=True)
class ResultManifest:
    result: int
    source: ProcessRef
    destination: ProcessRef
    correlation: int
    table: int
    policy_revision: int
    basis: Basis
    source_contract: bytes
    plan: bytes
    segments: int
    byte_count: int
    rows: int
    chain: bytes
    schema: bytes


@dataclass(frozen=True, slots=True)
class IpcSegment:
    manifest: ResultManifest
    ordinal: int
    rows: int
    digest: bytes
    ipc: bytes = field(repr=False)

    def to_pyarrow(self) -> Any:
        """Optional PyArrow 23 adapter; each segment is an independent IPC stream."""
        try:
            arrow = importlib.import_module('pyarrow')
        except ImportError:
            raise UnsupportedCapability('Install transit-station[arrow] to decode with PyArrow') from None
        if arrow.__version__ != '23.0.0':
            raise UnsupportedCapability('This adapter is qualified with PyArrow 23.0.0')
        with arrow.ipc.open_stream(self.ipc) as reader:
            table = reader.read_all()
        if table.num_rows != self.rows:
            raise ValueError('IPC row count differs from its verified segment')
        return table


class ResultReader:
    def __init__(self, turn: Turn, correlation: int) -> None:
        self._turn = turn
        self.correlation = integer(correlation, 'correlation', maximum=U64_MAX)

    @property
    def manifest(self) -> ResultManifest:
        value = self._turn._apply({'query_completed': str(self.correlation)})['manifest']
        realm = self._turn.process.realm
        basis = value['basis']
        return ResultManifest(value['result'], ProcessRef(realm, value['source']), ProcessRef(realm, value['destination']),
                              int(value['correlation']), value['table'], int(value['policy_revision']),
                              Basis(ResourceRef(realm, basis['resource']), basis['revision'], bytes(basis['schema'])), bytes(basis['contract']),
                              bytes(value['plan']), int(value['segments']), int(value['bytes']), int(value['rows']),
                              bytes(value['chain']), bytes(value['schema']))

    def segment(self, ordinal: int) -> IpcSegment:
        integer(ordinal, 'ordinal', minimum=0, maximum=U64_MAX)
        complete = self.manifest
        value = self._turn._apply({'query_segment': {'correlation': str(self.correlation), 'ordinal': str(ordinal)}})['segment']
        return IpcSegment(complete, int(value['ordinal']), value['rows'], bytes(value['digest']), bytes.fromhex(value['ipc']))

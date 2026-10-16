"""Bounded query plans and scoped readers; copied IPC owns no resource lifetime."""
from __future__ import annotations
from dataclasses import dataclass, field
import importlib
import json
from enum import Enum
from typing import Any
from transit_client import ProcessRef, ResourceRef
from transit_client.types import integer
from transit_client.errors import UnsupportedCapability
from transit_client._native import encode
from .unified import Plan, Aggregate as Aggregate, Comparison as Comparison
from .models import Origin
from .table import TableBasis
from .turn import ReadVersion, Turn, U64_MAX


class QueryFailureReason(str, Enum):
    RESULT_TOO_LARGE = 'result_too_large'
    WORKSPACE_EXCEEDED = 'workspace_exceeded'
    OVERFLOW = 'overflow'
    CANCELLED = 'cancelled'
    DENIED = 'denied'


@dataclass(frozen=True, slots=True)
class QueryFailure:
    position: int
    origin: Origin
    correlation: int
    result: int
    reason: QueryFailureReason


@dataclass(frozen=True, slots=True, init=False)
class QueryPlan:
    _data: bytes = field(repr=False)
    def __init__(self, plan: Plan) -> None:
        if not isinstance(plan, Plan): raise TypeError('Expected a general query plan')
        object.__setattr__(self, '_data', encode(plan._wire()))
    def _wire(self) -> object: return json.loads(self._data)


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
    basis: TableBasis
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
                              int(value['correlation']), int(value['table']), int(value['policy_revision']),
                              TableBasis(ResourceRef(realm, basis['resource']), basis['revision'], int(value['table']), bytes(basis['head'])),
                              bytes(value['plan']), int(value['segments']), int(value['bytes']), int(value['rows']),
                              bytes(value['chain']), bytes(value['schema']))

    def segment(self, ordinal: int) -> IpcSegment:
        integer(ordinal, 'ordinal', minimum=0, maximum=U64_MAX)
        complete = self.manifest
        value = self._turn._apply({'query_segment': {'correlation': str(self.correlation), 'ordinal': str(ordinal)}})['segment']
        return IpcSegment(complete, int(value['ordinal']), value['rows'], bytes(value['digest']), bytes.fromhex(value['ipc']))

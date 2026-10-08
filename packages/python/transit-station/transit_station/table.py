"""Application-owned typed Tables; each step prepares one private native turn."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
import json
from typing import Any, TYPE_CHECKING
from transit_client import ResourceRef
from transit_client._native import encode
from transit_client.errors import HandlerError, IncompatibleNative
from transit_client.types import integer, owned_bytes
from . import catalog_values as v
from . import logical_values as logical
from .catalog_values import Schema as Schema, TableLimits as TableLimits, Mutation as Mutation
TableSchema = Schema

if TYPE_CHECKING:
    from .turn import Turn, ReadVersion


def _saved(data: bytes, tag: str) -> dict[str, Any]:
    raw = owned_bytes(data, v.LIMITS['handler_action_bytes'])
    try:
        value = json.loads(raw)
        if encode(value) != raw: raise ValueError('Noncanonical saved Table intent')
        owned_bytes(encode({'table': {tag: value}}), v.LIMITS['handler_action_bytes'])
        if not isinstance(value, dict): raise ValueError('Expected saved Table intent')
    except (ValueError, RecursionError, UnicodeError):
        raise IncompatibleNative('Invalid saved Table intent') from None
    return value


def _same_resource(turn: Turn, value: dict[str, Any]) -> None:
    if turn.resource != ResourceRef(value['realm'], value['resource']):
        raise HandlerError('Table intent belongs to another realm or resource')


def _apply(turn: Turn, tag: str, value: object, expected: str) -> Any:
    result = v._object(turn._apply({'table': {tag: value}}), 'table')
    return v._object(result['table'], expected)[expected]


@dataclass(frozen=True, slots=True)
class RowIdentity:
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        object.__setattr__(self, 'data', owned_bytes(self.data, 20))
        if len(self.data) != 20: raise ValueError('Expected a 20-byte row identity')


@dataclass(frozen=True, slots=True)
class Row:
    identity: RowIdentity
    cells: tuple[logical.Cell, ...] = field(repr=False)


@dataclass(frozen=True, slots=True)
class TableBasis:
    resource: ResourceRef
    revision: int
    object_id: int
    head: bytes


@dataclass(frozen=True, slots=True)
class TablePage:
    rows: tuple[Row, ...]
    next: str | None


@dataclass(frozen=True, slots=True)
class TableCreation:
    state: str
    admitted_input: int
    completed_input: int | None


class TableMutationState(str, Enum):
    BUILDING = 'building'
    APPLIED = 'applied'
    REJECTED = 'rejected'
    CANCELLED = 'cancelled'


class TableRejection(str, Enum):
    NONE = 'none'
    ROW_EXISTS = 'row_exists'
    ROW_IDENTITY_EXISTS = 'row_identity_exists'
    NULL_NOT_ALLOWED = 'null_not_allowed'
    MISSING_REQUIRED_FIELD = 'missing_required_field'
    CHARACTER_LIMIT_EXCEEDED = 'character_limit_exceeded'
    OVERFLOW = 'overflow'
    INEXACT = 'inexact'


@dataclass(frozen=True, slots=True)
class TableWitness:
    source: str
    row: RowIdentity | None
    column: int
    text: str
    truncated: bool


@dataclass(frozen=True, slots=True)
class TableMutationStatus:
    reference: TableMutationReference
    state: TableMutationState
    route: str
    admitted_input: int
    completed_input: int | None
    counts: v.Counts | None
    rejection: TableRejection
    witness: TableWitness | None


def _status(value: object) -> TableMutationStatus:
    item = v._object(value, 'reference state route admitted_input completed_input counts rejection witness')
    state = TableMutationState(item['state'])
    rejection = TableRejection(item['rejection'])
    if item['route'] not in ('point', 'statement', 'alter'): raise IncompatibleNative('Unknown Table mutation route')
    admitted = integer(item['admitted_input'], 'admitted input')
    completed = None if item['completed_input'] is None else integer(item['completed_input'], 'completed input')
    if (completed is None) != (state is TableMutationState.BUILDING) or (completed is not None and completed < admitted):
        raise IncompatibleNative('Invalid Table mutation completion')
    if (rejection is not TableRejection.NONE) != (state is TableMutationState.REJECTED):
        raise IncompatibleNative('Invalid Table mutation rejection')
    if (item['counts'] is not None) != (state is TableMutationState.APPLIED):
        raise IncompatibleNative('Counts require an applied Table mutation')
    counts = None
    if item['counts'] is not None:
        c = v._object(item['counts'], 'matched changed')
        counts = v.Counts(v._decimal(c['matched'], 0), v._decimal(c['changed'], 0))
    witness = None
    if item['witness'] is not None:
        w = v._object(item['witness'], 'source row column text truncated')
        if w['source'] not in ('input', 'stored', 'withheld'): raise IncompatibleNative('Invalid witness source')
        witness = TableWitness(w['source'], None if w['row'] is None else RowIdentity(v._hex(w['row'], 20, True)),
                               v._decimal(w['column'], 0), v._text(w['text'], 256), v._boolean(w['truncated']))
    return TableMutationStatus(TableMutationReference.load(encode(item['reference'])), state, item['route'], admitted,
                               completed, counts, rejection, witness)


@dataclass(frozen=True, slots=True, init=False)
class TableMutationReference:
    _data: bytes = field(repr=False)
    @classmethod
    def load(cls, data: bytes) -> TableMutationReference:
        value = v._object(_saved(data, 'status'), 'definition realm resource object principal operation digest')
        v._definition(value['definition'])
        ResourceRef(value['realm'], value['resource'])
        integer(value['principal'], 'principal', minimum=0)
        v._decimal(value['object']); v._decimal(value['operation']); v._digest(value['digest'])
        result = object.__new__(cls)
        object.__setattr__(result, '_data', bytes(data))
        return result
    def save(self) -> bytes: return self._data
    def _read(self, turn: Turn, tag: str) -> TableMutationStatus | None:
        value = _saved(self._data, 'status')
        _same_resource(turn, value)
        result = _apply(turn, tag, value, 'mutation')
        if result is None: return None
        parsed = _status(result)
        if json.loads(parsed.reference.save()) != value: raise IncompatibleNative('Foreign Table mutation outcome')
        return parsed
    def status(self, turn: Turn) -> TableMutationStatus | None: return self._read(turn, 'status')
    def cancel(self, turn: Turn) -> TableMutationStatus:
        result = self._read(turn, 'cancel')
        if result is None: raise IncompatibleNative('Missing cancelled Table mutation')
        return result


@dataclass(frozen=True, slots=True, init=False)
class TableMutation:
    """Persist save() as accepted work; step() neither commits nor schedules work."""
    _data: bytes = field(repr=False)
    @classmethod
    def prepare(cls, resource: ResourceRef, principal: int, operation: int,
                schema: TableSchema, mutation: Mutation) -> TableMutation:
        if not isinstance(resource, ResourceRef) or not isinstance(schema, TableSchema):
            raise TypeError('Expected a resource and typed Table schema')
        value = dict(realm=resource.realm, resource=resource.resource, principal=integer(principal, 'principal', minimum=0),
                     operation=str(v._wide(operation)), schema=schema._wire(), mutation=v._mutation(mutation, v.LIMITS['handler_action_bytes']))
        return cls.load(encode(value))
    @classmethod
    def load(cls, data: bytes) -> TableMutation:
        value = v._object(_saved(data, 'mutate'), 'realm resource principal operation schema mutation')
        ResourceRef(value['realm'], value['resource'])
        integer(value['principal'], 'principal', minimum=0); v._decimal(value['operation'])
        v._schema(value['schema'])
        v._mutation_value(value['mutation'])
        result = object.__new__(cls)
        object.__setattr__(result, '_data', bytes(data))
        return result
    def save(self) -> bytes: return self._data
    @property
    def schema(self) -> TableSchema: return v._schema(_saved(self._data, 'mutate')['schema'])
    @property
    def operation(self) -> int: return v._decimal(_saved(self._data, 'mutate')['operation'])
    def step(self, turn: Turn) -> TableMutationStatus:
        value = _saved(self._data, 'mutate')
        _same_resource(turn, value)
        result = _status(_apply(turn, 'mutate', value, 'mutation'))
        reference = json.loads(result.reference.save())
        if any(reference[key] != value[key] for key in ('realm', 'resource', 'principal', 'operation')) or reference['object'] != value['schema']['object']:
            raise IncompatibleNative('Foreign Table mutation outcome')
        return result


def _row(value: object) -> Row:
    item = v._object(value, 'identity cells')
    if not isinstance(item['cells'], list) or not 1 <= len(item['cells']) <= 128: raise IncompatibleNative('Invalid row width')
    return Row(RowIdentity(v._hex(item['identity'], 20, True)), tuple(logical.cell_from_wire(c) for c in item['cells']))


class Table:
    def __init__(self, turn: Turn, object_id: int, version: ReadVersion | None = None) -> None:
        self._turn, self._version = turn, version
        self._object = v._wide(object_id)
        value = v._object(_apply(turn, 'schema', self._source(), 'schema'), 'schema basis')
        self.schema = v._schema(value['schema'])
        basis = v._object(value['basis'], 'resource revision object head')
        self.basis = TableBasis(ResourceRef(turn.process.realm, basis['resource']), integer(basis['revision'], 'revision'),
                                v._decimal(basis['object']), v._hex(basis['head'], 32, True))
        if self.basis.object_id != object_id or self.schema.object_id != object_id:
            raise IncompatibleNative('Foreign Table definition')
    @staticmethod
    def create(turn: Turn, schema: TableSchema, limits: TableLimits) -> TableCreation:
        if not isinstance(schema, TableSchema) or not isinstance(limits, TableLimits): raise TypeError('Expected Table schema and limits')
        value = v._object(_apply(turn, 'create', dict(realm=turn.resource.realm, resource=turn.resource.resource,
                          schema=schema._wire(), limits=limits._wire()), 'created'), 'state admitted_input completed_input')
        if value['state'] not in ('building', 'applied'): raise IncompatibleNative('Invalid Table creation state')
        admitted = integer(value['admitted_input'], 'admitted input')
        completed = integer(value['completed_input'], 'completed input', minimum=0)
        if (completed == 0) != (value['state'] == 'building') or (completed != 0 and completed < admitted):
            raise IncompatibleNative('Invalid Table creation completion')
        return TableCreation(value['state'], admitted, completed or None)
    def _source(self) -> object:
        return dict(object=str(self._object), version=None if self._version is None else self._version._wire())
    def _check(self, value: object) -> None:
        definition = v._object(value, 'schema basis'); basis = v._object(definition['basis'], 'resource revision object head')
        if (basis['resource'], basis['revision'], v._decimal(basis['object']), v._hex(basis['head'], 32, True)) != (
                self.basis.resource.resource, self.basis.revision, self.basis.object_id, self.basis.head):
            raise IncompatibleNative('Table read changed its captured basis')
    def _get(self, tag: str, request: object) -> Row | None:
        value = v._object(_apply(self._turn, tag, request, 'row'), 'definition row')
        self._check(value['definition'])
        return None if value['row'] is None else _row(value['row'])
    def get(self, identity: RowIdentity) -> Row | None:
        if not isinstance(identity, RowIdentity): raise TypeError('Expected a row identity')
        return self._get('get', dict(source=self._source(), identity=identity.data.hex()))
    def get_key(self, key: tuple[logical.Cell, ...]) -> Row | None:
        if not isinstance(key, tuple) or not 1 <= len(key) <= 128: raise TypeError('Expected a nonempty primary-key tuple')
        return self._get('get_key', dict(source=self._source(), key=[logical.cell_wire(cell) for cell in key]))
    def page(self, cursor: str | None = None, limit: int = 8) -> TablePage:
        if cursor is not None: v._text(cursor, 2048)
        value = v._object(_apply(self._turn, 'page', dict(source=self._source(), cursor=cursor,
                          limit=integer(limit, 'page rows', maximum=8)), 'page'), 'definition rows next')
        self._check(value['definition'])
        if not isinstance(value['rows'], list) or len(value['rows']) > limit: raise IncompatibleNative('Oversized Table page')
        return TablePage(tuple(_row(row) for row in value['rows']), None if value['next'] is None else v._text(value['next'], 2048))
    def prepare(self, principal: int, operation: int, mutation: Mutation) -> TableMutation:
        self._turn._check()
        if self._version is not None: raise HandlerError('Retained Tables are read-only')
        return TableMutation.prepare(self.basis.resource, principal, operation, self.schema, mutation)

"""Owned general Table values; storage semantics belong to the shared Zig owner."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
import copy
import json
from pathlib import Path
from typing import Any, TypeAlias, TypeVar
from transit_client import ProcessRef, ResourceRef
from transit_client._native import encode
from transit_client.types import integer, owned_bytes
from . import logical_values as logical

# Read the generated definition and bounds; never default saved artifacts to them.
_contract = json.loads(Path(__file__).with_name('station-abi.json').read_bytes())
DEFINITION: str = _contract['definition']
LIMITS: dict[str, int] = _contract['limits']
del _contract
E = TypeVar('E', bound=Enum)
W = TypeVar('W')


class _WireBudget:
    """Charge a fragment before converting the next owned logical value."""
    def __init__(self, limit: int): self.remaining = limit
    def take(self, value: W) -> W:
        self.remaining -= len(encode(value))
        if self.remaining < 0: raise ValueError('Table wire budget exceeded')
        return value


def _wide(value: object, name: str = 'identity', minimum: int = 1) -> int:
    return integer(value, name, minimum=minimum, maximum=(1 << 64) - 1)


def _text(value: object, limit: int) -> str:
    if not isinstance(value, str) or not value: raise ValueError('Expected nonempty text')
    owned_bytes(value.encode(), limit)
    return value


def _name(value: object) -> str:
    result = _text(value, 255)
    if '\0' in result: raise ValueError('NUL in catalog name')
    return result


def _boolean(value: object) -> bool:
    if type(value) is not bool: raise ValueError('Expected boolean')
    return value


def _definition(value: object) -> str:
    if value != DEFINITION: raise ValueError('Foreign or missing catalog definition')
    return DEFINITION


def _hex(value: object, limit: int, exact: bool = False) -> bytes:
    text = _text(value, limit * 2)
    result = owned_bytes(bytes.fromhex(text), limit)
    if result.hex() != text or (exact and len(result) != limit): raise ValueError('Expected canonical hexadecimal bytes')
    return result


def _digest(value: object) -> str: return _hex(value, 32, True).hex()


def _object(value: object, fields: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != set(fields.split()): raise ValueError('Unexpected catalog response fields')
    return value


def _variant(value: object) -> tuple[str, Any]:
    if not isinstance(value, dict) or len(value) != 1: raise ValueError('Expected one catalog variant')
    kind, payload = next(iter(value.items()))
    if not isinstance(kind, str): raise ValueError('Expected variant tag')
    return kind, payload


def _decimal(value: object, minimum: int = 1) -> int:
    if not isinstance(value, str) or not 1 <= len(value) <= 20 or not value.isascii() or not value.isdigit(): raise ValueError('Expected canonical decimal string')
    result = _wide(int(value), minimum=minimum)
    if str(result) != value: raise ValueError('Expected canonical decimal string')
    return result


@dataclass(frozen=True, slots=True)
class Scope:
    resource: ResourceRef
    catalog: int
    def __post_init__(self) -> None:
        if not isinstance(self.resource, ResourceRef): raise TypeError('Expected resource reference')
        _wide(self.catalog)
    def _wire(self) -> dict[str, object]:
        return dict(realm=self.resource.realm, resource=self.resource.resource, catalog=str(self.catalog))


@dataclass(frozen=True, slots=True)
class Connection:
    owner: ProcessRef
    scope: Scope
    def __post_init__(self) -> None:
        if not isinstance(self.owner, ProcessRef) or not isinstance(self.scope, Scope): raise TypeError('Expected catalog connection')
        if self.owner.realm != self.scope.resource.realm: raise ValueError('Catalog connection must use one realm')
    def _wire(self, principal: int) -> object:
        return dict(scope=self.scope._wire(), owner=self.owner.pid, principal=integer(principal, 'principal', minimum=0))


@dataclass(frozen=True, slots=True)
class TableLimits:
    record_bytes: int
    staging_bytes: int
    staging_records: int
    def __post_init__(self) -> None:
        integer(self.record_bytes, 'record bytes', maximum=0xffffffff)
        _wide(self.staging_bytes, 'staging bytes')
        integer(self.staging_records, 'staging records', maximum=0xffffffff)
        if self.staging_bytes < self.record_bytes: raise ValueError('Staging quota cannot be smaller than one record')
    def _wire(self) -> object:
        return dict(record_bytes=self.record_bytes, staging_bytes=str(self.staging_bytes), staging_records=self.staging_records)


@dataclass(frozen=True, slots=True)
class Configuration:
    scope: Scope
    owner: ProcessRef
    administrator: int
    table_limits: TableLimits
    def __post_init__(self) -> None:
        Connection(self.owner, self.scope)
        integer(self.administrator, 'administrator')
        if not isinstance(self.table_limits, TableLimits): raise TypeError('Specify deployment Table limits')
    def _wire(self) -> object:
        return dict(scope=self.scope._wire(), owner=self.owner.pid, administrator=self.administrator, table_limits=self.table_limits._wire())


@dataclass(frozen=True, slots=True)
class Rights:
    inspect: bool
    create: bool
    read: bool
    insert: bool
    update: bool
    delete: bool
    alter: bool
    drop: bool
    def __post_init__(self) -> None:
        for value in self._wire().values(): _boolean(value)
    def _wire(self) -> dict[str, bool]:
        return {name: getattr(self, name) for name in ('inspect', 'create', 'read', 'insert', 'update', 'delete', 'alter', 'drop')}


@dataclass(frozen=True, slots=True)
class Policy:
    scope: Scope
    principal: int
    revision: int
    rights: Rights
    def __post_init__(self) -> None:
        if not isinstance(self.scope, Scope) or not isinstance(self.rights, Rights): raise TypeError('Expected scoped rights')
        integer(self.principal, 'principal', minimum=0); _wide(self.revision)
    def _wire(self) -> object:
        return dict(scope=self.scope._wire(), principal=self.principal, revision=str(self.revision), **self.rights._wire())


@dataclass(frozen=True, slots=True)
class PolicyChange:
    expected_revision: int
    policy: Policy
    def __post_init__(self) -> None:
        _wide(self.expected_revision, minimum=0)
        if not isinstance(self.policy, Policy): raise TypeError('Expected policy')
        if self.policy.revision != self.expected_revision + 1: raise ValueError('Policy revision must be the expected successor')
    def _wire(self) -> object:
        return dict(expected_revision=str(self.expected_revision), policy=self.policy._wire())


@dataclass(frozen=True, slots=True)
class Column:
    id: int
    name: str
    type: logical.Descriptor
    nullable: bool = True
    default: logical.Cell | None = None
    max_characters: int | None = None
    def _wire(self) -> dict[str, Any]:
        return dict(id=str(_wide(self.id)), **_column(self.name, self.type, self.nullable, self.default, self.max_characters))


def _column(name: str, datatype: logical.Descriptor, nullable: bool, default: logical.Cell | None, max_characters: int | None) -> dict[str, Any]:
    return dict(name=_name(name), type=logical.type_wire(datatype), nullable=_boolean(nullable), default=None if default is None else logical.cell_wire(default),
                max_characters=None if max_characters is None else integer(max_characters, 'characters', maximum=0xffffffff))


@dataclass(frozen=True, slots=True)
class Schema:
    object_id: int
    revision: int
    next_column: int
    columns: tuple[Column, ...]
    primary_key: tuple[int, ...] = ()
    def __post_init__(self) -> None:
        _wide(self.object_id); _wide(self.revision); _wide(self.next_column)
        object.__setattr__(self, 'columns', tuple(self.columns)); object.__setattr__(self, 'primary_key', tuple(self.primary_key))
        if not 1 <= len(self.columns) <= 128 or len(self.primary_key) > len(self.columns): raise ValueError('Invalid Table column count')
        owned_bytes(encode(self._wire()), 2 * 1024 * 1024)
    def _wire(self) -> object:
        budget = _WireBudget(2 * 1024 * 1024)
        return dict(definition=DEFINITION, object=str(self.object_id), revision=str(self.revision), next_column=str(self.next_column),
                    columns=[budget.take(item._wire()) for item in self.columns], primary_key=[str(_wide(item)) for item in self.primary_key])


@dataclass(frozen=True, slots=True)
class Identity:
    operation: int
    namespace: int
    def __post_init__(self) -> None: _wide(self.operation); _wide(self.namespace)
    def _wire(self) -> object: return dict(operation=str(self.operation), namespace=str(self.namespace))


@dataclass(frozen=True, slots=True)
class Basis:
    object_id: int
    revision: int
    schema_fingerprint: str
    def __post_init__(self) -> None: _wide(self.object_id); _wide(self.revision); _digest(self.schema_fingerprint)
    def _wire(self) -> object: return dict(object=str(self.object_id), revision=str(self.revision), schema_fingerprint=self.schema_fingerprint)


@dataclass(frozen=True, slots=True)
class Metadata:
    scope: Scope
    object_id: int
    revision: int
    name: str
    schema_fingerprint: str
    principal: int
    operation: int
    admitted_input: int
    def __post_init__(self) -> None:
        if not isinstance(self.scope, Scope): raise TypeError('Expected scope')
        _wide(self.object_id); _wide(self.revision); _name(self.name); _digest(self.schema_fingerprint)
        integer(self.principal, 'principal', minimum=0); _wide(self.operation); integer(self.admitted_input, 'admitted input')
    @property
    def basis(self) -> Basis: return Basis(self.object_id, self.revision, self.schema_fingerprint)


@dataclass(frozen=True, slots=True)
class Head:
    revision: int
    rows: int
    pending: int
    def __post_init__(self) -> None: _wide(self.revision); _wide(self.rows, minimum=0); _wide(self.pending, minimum=0)


@dataclass(frozen=True, slots=True)
class Entry:
    metadata: Metadata
    head: Head


@dataclass(frozen=True, slots=True)
class Definition(Entry):
    schema: Schema


@dataclass(frozen=True, slots=True)
class HistoricalDefinition:
    metadata: Metadata
    schema: Schema


@dataclass(frozen=True, slots=True)
class Cursor:
    definition: str
    scope: Scope
    resource_revision: int
    after_object: int
    def __post_init__(self) -> None:
        _definition(self.definition)
        if not isinstance(self.scope, Scope): raise TypeError('Expected scope')
        integer(self.resource_revision, 'resource revision', minimum=0); _wide(self.after_object)
    def _wire(self) -> object:
        return dict(definition=self.definition, scope=self.scope._wire(), resource_revision=self.resource_revision, after_object=str(self.after_object))


@dataclass(frozen=True, slots=True)
class Page:
    resource_revision: int
    entries: tuple[Entry, ...]
    next: Cursor | None
    def __post_init__(self) -> None:
        integer(self.resource_revision, 'resource revision', minimum=0)
        object.__setattr__(self, 'entries', tuple(self.entries))
        if len(self.entries) > 8: raise ValueError('Expected at most eight entries')
        for entry in self.entries:
            if not isinstance(entry, Entry) or not isinstance(entry.metadata, Metadata) or not isinstance(entry.head, Head): raise TypeError('Expected catalog entries')
        for a, b in zip(self.entries, self.entries[1:]):
            if a.metadata.scope != b.metadata.scope or a.metadata.object_id >= b.metadata.object_id: raise ValueError('Expected ordered entries in one scope')
        if self.next is not None:
            if not isinstance(self.next, Cursor) or self.next.resource_revision != self.resource_revision: raise ValueError('Invalid continuation')
            if self.entries:
                last = self.entries[-1].metadata
                if last.scope != self.next.scope or last.object_id > self.next.after_object: raise ValueError('Continuation precedes its last entry')


@dataclass(frozen=True, slots=True)
class Reference:
    definition: str
    digest: str
    def __post_init__(self) -> None: _definition(self.definition); _digest(self.digest)
    def _wire(self) -> object: return dict(definition=self.definition, digest=self.digest)


@dataclass(frozen=True, slots=True)
class SavedIntent:
    definition: str
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        _definition(self.definition)
        object.__setattr__(self, 'data', owned_bytes(self.data, LIMITS['catalog_intent_bytes']))
        if not self.data: raise ValueError('Empty saved intent')
    def _wire(self) -> object: return dict(definition=self.definition, bytes=self.data.hex())


@dataclass(frozen=True, slots=True)
class Prepared:
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        object.__setattr__(self, 'data', owned_bytes(self.data, LIMITS['catalog_prepared_bytes']))
        _text(self.data.decode(), LIMITS['catalog_prepared_bytes'])


class Kind(str, Enum):
    CREATE = 'create'
    ALTER = 'alter'
    RENAME = 'rename'
    DROP = 'drop'
    INSERT = 'insert'
    UPDATE = 'update'
    DELETE = 'delete'


@dataclass(frozen=True, slots=True)
class Intent:
    reference: Reference
    scope: Scope
    owner: ProcessRef
    principal: int
    identity: Identity
    object_id: int
    kind: Kind


@dataclass(frozen=True, slots=True)
class Compiled:
    intent: Intent
    saved: SavedIntent


class Phase(str, Enum):
    PREPARING = 'preparing'
    DELEGATED = 'delegated'
    BUILDING = 'building'
    APPLIED = 'applied'
    UNCHANGED = 'unchanged'
    REJECTED = 'rejected'
    CANCELLED = 'cancelled'


@dataclass(frozen=True, slots=True)
class Counts:
    matched: int
    changed: int
    def __post_init__(self) -> None:
        _wide(self.matched, minimum=0); _wide(self.changed, minimum=0)
        if self.changed > self.matched: raise ValueError('Changed count exceeds matched count')


@dataclass(frozen=True, slots=True)
class Outcome:
    kind: Kind
    operation: int
    object_id: int
    actual_object: int | None
    phase: Phase
    terminal: bool
    counts: Counts | None
    admitted_input: int
    completed_input: int | None
    diagnostic: dict[str, Any] = field(repr=False)


class UploadPhase(str, Enum):
    UPLOADING = 'uploading'
    SEALED = 'sealed'
    READY = 'ready'
    CANCELLED = 'cancelled'


@dataclass(frozen=True, slots=True)
class Upload:
    phase: UploadPhase
    received: int
    total: int


@dataclass(frozen=True, slots=True)
class State:
    outcome: Outcome | None
    upload: Upload | None


class DispositionOutcome(str, Enum):
    INITIALIZED = 'initialized'
    POLICY_APPLIED = 'policy_applied'
    DEPENDENCY_APPLIED = 'dependency_applied'
    INVALID_COMMAND = 'invalid_command'
    BLOCKED = 'blocked'
    DENIED = 'denied'
    IDENTITY_CONFLICT = 'identity_conflict'
    STALE_POLICY = 'stale_policy'


@dataclass(frozen=True, slots=True)
class Disposition:
    input: int
    outcome: DispositionOutcome
    diagnostic: dict[str, Any] = field(repr=False)


class Observation(str, Enum):
    PENDING = 'pending'
    PROCESSED = 'processed'


class NextKind(str, Enum):
    SEND = 'send'
    RUNNING = 'running'
    UPLOAD_CANCELLED = 'upload_cancelled'
    TERMINAL = 'terminal'


@dataclass(frozen=True, slots=True)
class Next:
    kind: NextKind
    prepared: Prepared | None = None
    outcome: Outcome | None = None


@dataclass(frozen=True, slots=True)
class Progress:
    observation: Observation
    disposition: Disposition | None = None
    outcome: Outcome | None = None
    upload: Upload | None = None


class Default(Enum):
    VALUE = 'default'


@dataclass(frozen=True, slots=True)
class Assignment:
    column: int
    value: logical.Cell | Default


class BooleanOperator(str, Enum):
    ALL = 'all'
    NEGATE = 'negate'
    CONJUNCTION = 'conjunction'
    DISJUNCTION = 'disjunction'


class CellState(str, Enum):
    MISSING = 'missing'
    NULL = 'null'
    TYPE_ERROR = 'type_error'
    VALUE = 'value'
    CONFLICT = 'conflict'


class CompareOperator(str, Enum):
    EQ = 'eq'
    NE = 'ne'
    LT = 'lt'
    LE = 'le'
    GT = 'gt'
    GE = 'ge'


@dataclass(frozen=True, slots=True)
class StatePredicate:
    column: int
    state: CellState


@dataclass(frozen=True, slots=True)
class Comparison:
    column: int
    op: CompareOperator
    value: logical.Atom


Predicate: TypeAlias = BooleanOperator | StatePredicate | Comparison


@dataclass(frozen=True, slots=True)
class Insert:
    rows: tuple[tuple[Assignment, ...], ...]
    def __post_init__(self) -> None: object.__setattr__(self, 'rows', tuple(tuple(row) for row in self.rows))


@dataclass(frozen=True, slots=True)
class Update:
    assignments: tuple[Assignment, ...]
    predicate: tuple[Predicate, ...] | None = None
    def __post_init__(self) -> None:
        object.__setattr__(self, 'assignments', tuple(self.assignments))
        if self.predicate is not None: object.__setattr__(self, 'predicate', tuple(self.predicate))


@dataclass(frozen=True, slots=True)
class Delete:
    predicate: tuple[Predicate, ...] | None = None
    def __post_init__(self) -> None:
        if self.predicate is not None: object.__setattr__(self, 'predicate', tuple(self.predicate))


Mutation: TypeAlias = Insert | Update | Delete


@dataclass(frozen=True, slots=True)
class AddColumn:
    name: str
    type: logical.Descriptor
    nullable: bool = True
    default: logical.Cell | None = None
    max_characters: int | None = None


@dataclass(frozen=True, slots=True)
class DropColumn:
    column: int


@dataclass(frozen=True, slots=True)
class RenameColumn:
    column: int
    name: str


@dataclass(frozen=True, slots=True)
class SetDefault:
    column: int
    value: logical.Cell | None


@dataclass(frozen=True, slots=True)
class SetNullable:
    column: int
    nullable: bool


@dataclass(frozen=True, slots=True)
class SetType:
    column: int
    type: logical.Descriptor
    max_characters: int | None = None


Change: TypeAlias = AddColumn | DropColumn | RenameColumn | SetDefault | SetNullable | SetType


@dataclass(frozen=True, slots=True)
class Create:
    schema: Schema
    if_not_exists: bool = False


@dataclass(frozen=True, slots=True)
class Alter:
    basis: Basis
    change: Change


@dataclass(frozen=True, slots=True)
class Rename:
    basis: Basis
    name: str


@dataclass(frozen=True, slots=True)
class Drop:
    basis: Basis | None = None
    if_exists: bool = False


@dataclass(frozen=True, slots=True)
class Mutate:
    basis: Basis
    mutation: Mutation


Operation: TypeAlias = Create | Alter | Rename | Drop | Mutate


class Control(str, Enum):
    CANCEL_OPERATION = 'cancel_operation'
    CLEANUP_OPERATION = 'cleanup_operation'
    CANCEL_UPLOAD = 'cancel_upload'
    COLLECT_UPLOAD = 'collect_upload'


class DependencyKind(str, Enum):
    QUERY_SOURCE = 'query_source'
    WRITER = 'writer'
    WATCH = 'watch'
    MAINTAINED_RELATION = 'maintained_relation'
    HISTORY = 'history'


@dataclass(frozen=True, slots=True)
class Dependency:
    scope: Scope
    object_id: int
    identity: int
    owner: ProcessRef
    kind: DependencyKind
    def _wire(self, present: bool) -> object:
        Connection(self.owner, self.scope)
        return dict(scope=self.scope._wire(), object=str(_wide(self.object_id)), identity=str(_wide(self.identity)), owner=self.owner.pid, kind=_enum(self.kind, DependencyKind), present=_boolean(present))


@dataclass(frozen=True, slots=True)
class Capabilities:
    version: int
    definition: str
    max_columns: int
    max_rows: int
    max_sql_bytes: int
    max_intent_bytes: int
    max_action_bytes: int
    max_prepared_bytes: int
    resident_intents: int


@dataclass(frozen=True, slots=True)
class Description:
    configuration: Configuration
    policy: Policy
    resource_revision: int


def _enum(value: E, kind: type[E]) -> str:
    if not isinstance(value, kind): raise TypeError('Expected typed catalog variant')
    result: str = value.value
    return result


def _scope(value: object) -> Scope:
    v = _object(value, 'realm resource catalog')
    return Scope(ResourceRef(v['realm'], v['resource']), _decimal(v['catalog']))


def _schema(value: object) -> Schema:
    v = _object(value, 'definition object revision next_column columns primary_key')
    _definition(v['definition'])
    if not isinstance(v['columns'], list) or not 1 <= len(v['columns']) <= 128 or not isinstance(v['primary_key'], list): raise ValueError('Invalid columns')
    columns = []
    for item in v['columns']:
        c = _object(item, 'id name type nullable default max_characters')
        columns.append(Column(_decimal(c['id']), _name(c['name']), logical.type_from_wire(c['type']), _boolean(c['nullable']), None if c['default'] is None else logical.cell_from_wire(c['default']), c['max_characters']))
    return Schema(_decimal(v['object']), _decimal(v['revision']), _decimal(v['next_column']), tuple(columns), tuple(_decimal(k) for k in v['primary_key']))


def _metadata(value: object) -> Metadata:
    v = _object(value, 'scope object revision name schema_fingerprint principal operation admitted_input')
    return Metadata(_scope(v['scope']), _decimal(v['object']), _decimal(v['revision']), _name(v['name']), _digest(v['schema_fingerprint']), v['principal'], _decimal(v['operation']), v['admitted_input'])


def _head(value: object) -> Head:
    v = _object(value, 'revision rows pending')
    return Head(_decimal(v['revision']), _decimal(v['rows'], 0), _decimal(v['pending'], 0))


def _resolved(value: object, scope: Scope, name: str) -> Definition | None:
    if value is None: return None
    v = _object(value, 'metadata head schema')
    result = Definition(_metadata(v['metadata']), _head(v['head']), _schema(v['schema']))
    if result.metadata.scope != scope or result.metadata.name != name or result.metadata.object_id != result.schema.object_id: raise ValueError('Foreign Table definition')
    return result


def _historical(value: object, scope: Scope, object_id: int, revision: int) -> HistoricalDefinition | None:
    if value is None: return None
    v = _object(value, 'metadata schema')
    result = HistoricalDefinition(_metadata(v['metadata']), _schema(v['schema']))
    if result.metadata.scope != scope or result.metadata.object_id != object_id or result.metadata.revision != revision or result.schema.object_id != object_id:
        raise ValueError('Foreign historical definition')
    return result


def _page(value: object, scope: Scope, previous: Cursor | None) -> Page:
    v = _object(value, 'resource_revision entries next')
    if not isinstance(v['entries'], list) or len(v['entries']) != 8: raise ValueError('Expected eight optional entry slots')
    entries = []
    ended = False
    for item in v['entries']:
        if item is None: ended = True
        else:
            e = _object(item, 'metadata head'); entry = Entry(_metadata(e['metadata']), _head(e['head']))
            if ended or entry.metadata.scope != scope: raise ValueError('Page has a hole or foreign scope')
            entries.append(entry)
    cursor = None
    if v['next'] is not None:
        c = _object(v['next'], 'definition scope resource_revision after_object')
        cursor = Cursor(c['definition'], _scope(c['scope']), c['resource_revision'], _decimal(c['after_object']))
        if cursor.scope != scope: raise ValueError('Foreign continuation scope')
    page = Page(v['resource_revision'], tuple(entries), cursor)
    if previous is not None and (page.resource_revision != previous.resource_revision or
        (entries and entries[0].metadata.object_id <= previous.after_object) or (cursor is not None and cursor.after_object <= previous.after_object)):
        raise ValueError('Response does not continue the requested page')
    return page


def _intent(value: object, connection: Connection, principal: int) -> Intent:
    v = _object(value, 'reference scope owner principal operation namespace object kind')
    r = _object(v['reference'], 'definition digest'); scope = _scope(v['scope'])
    result = Intent(Reference(r['definition'], r['digest']), scope, ProcessRef(scope.resource.realm, v['owner']), integer(v['principal'], 'principal', minimum=0),
                    Identity(_decimal(v['operation']), _decimal(v['namespace'])), _decimal(v['object'], 0), Kind(v['kind']))
    if result.scope != connection.scope or result.owner != connection.owner or result.principal != principal: raise ValueError('Foreign intent connection')
    return result


def _compiled(value: object, connection: Connection, principal: int, ids: Identity, kind: Kind | None = None, object_id: int | None = None) -> Compiled:
    v = _object(value, 'intent saved'); s = _object(v['saved'], 'definition bytes')
    result = Compiled(_intent(v['intent'], connection, principal), SavedIntent(s['definition'], _hex(s['bytes'], LIMITS['catalog_intent_bytes'])))
    if result.intent.identity != ids or (kind is not None and result.intent.kind != kind) or (object_id is not None and result.intent.object_id != object_id): raise ValueError('Compiled intent does not match its request')
    return result


def _diagnostic(value: object) -> dict[str, Any]:
    if not isinstance(value, dict): raise ValueError('Missing catalog diagnostic')
    # The native exported validator checks this before the decoder runs.
    return copy.deepcopy(value)


def _outcome(value: object) -> Outcome | None:
    if value is None: return None
    v = _object(value, 'kind operation object actual_object phase terminal counts admitted_input completed_input diagnostic')
    phase, kind, terminal = Phase(v['phase']), Kind(v['kind']), _boolean(v['terminal'])
    if terminal != (phase in (Phase.APPLIED, Phase.UNCHANGED, Phase.REJECTED, Phase.CANCELLED)): raise ValueError('Inconsistent terminal state')
    counts = None
    if v['counts'] is not None:
        c = _object(v['counts'], 'matched changed'); counts = Counts(_decimal(c['matched'], 0), _decimal(c['changed'], 0))
    if (counts is not None) != (phase == Phase.APPLIED and kind in (Kind.INSERT, Kind.UPDATE, Kind.DELETE)): raise ValueError('Inconsistent mutation counts')
    return Outcome(kind, _decimal(v['operation']), _decimal(v['object'], 0), None if v['actual_object'] is None else _decimal(v['actual_object'], 0), phase, terminal, counts,
                   integer(v['admitted_input'], 'admitted input'), None if v['completed_input'] is None else integer(v['completed_input'], 'completed input'), _diagnostic(v['diagnostic']))


def _upload(value: object) -> Upload | None:
    if value is None: return None
    v = _object(value, 'phase received total')
    total = integer(v['total'], 'upload total', maximum=LIMITS['catalog_intent_bytes'])
    return Upload(UploadPhase(v['phase']), integer(v['received'], 'received', minimum=0, maximum=total), total)


def _state(value: object) -> State:
    v = _object(value, 'outcome upload')
    return State(_outcome(v['outcome']), _upload(v['upload']))


def _disposition(value: object) -> Disposition | None:
    if value is None: return None
    v = _object(value, 'input outcome diagnostic')
    return Disposition(integer(v['input'], 'input'), DispositionOutcome(v['outcome']), _diagnostic(v['diagnostic']))


def _next(value: object) -> Next:
    kind, payload = _variant(value); tag = NextKind(kind)
    if tag == NextKind.SEND: return Next(tag, prepared=_prepared(payload))
    if tag == NextKind.TERMINAL:
        result = _outcome(payload)
        if result is None or not result.terminal: raise ValueError('Missing terminal outcome')
        return Next(tag, outcome=result)
    _object(payload, '')
    return Next(tag)


def _progress(value: object) -> Progress:
    kind, payload = _variant(value)
    if kind == 'pending':
        _object(payload, '')
        return Progress(Observation.PENDING)
    if kind != 'processed': raise ValueError('Unknown progress variant')
    v = _object(payload, 'disposition outcome upload')
    return Progress(Observation.PROCESSED, _disposition(v['disposition']), _outcome(v['outcome']), _upload(v['upload']))


def _prepared(value: object) -> Prepared: return Prepared(_text(value, LIMITS['catalog_prepared_bytes']).encode())


def _capabilities(value: object) -> Capabilities:
    fields = 'version definition max_columns max_rows max_sql_bytes max_intent_bytes max_action_bytes max_prepared_bytes resident_intents'
    v = _object(value, fields)
    _definition(v['definition'])
    checked: dict[str, Any] = {key: v[key] if key == 'definition' else integer(v[key], key) for key in fields.split()}
    return Capabilities(**checked)


def _description(value: object, connection: Connection, principal: int) -> Description:
    v = _object(value, 'configuration policy resource_revision'); c = _object(v['configuration'], 'scope owner administrator table_limits')
    limits = _object(c['table_limits'], 'record_bytes staging_bytes staging_records'); scope = _scope(c['scope'])
    config = Configuration(scope, ProcessRef(scope.resource.realm, c['owner']), c['administrator'], TableLimits(limits['record_bytes'], _decimal(limits['staging_bytes']), limits['staging_records']))
    p = _object(v['policy'], 'scope principal revision inspect create read insert update delete alter drop')
    rights = Rights(**{key: p[key] for key in ('inspect', 'create', 'read', 'insert', 'update', 'delete', 'alter', 'drop')})
    policy = Policy(_scope(p['scope']), p['principal'], _decimal(p['revision']), rights)
    if config.scope != connection.scope or config.owner != connection.owner or policy.scope != connection.scope or policy.principal != principal: raise ValueError('Foreign catalog description')
    return Description(config, policy, integer(v['resource_revision'], 'resource revision', minimum=0))


def _assignments(values: tuple[Assignment, ...], budget: _WireBudget) -> object:
    if len(values) > 128: raise ValueError('Too many Table assignments')
    return [budget.take(dict(column=str(_wide(item.column)), value={'default': {}} if item.value is Default.VALUE else {'cell': logical.cell_wire(item.value)})) for item in values]


def _predicate(value: Predicate) -> object:
    if isinstance(value, BooleanOperator): return {'atom': {'all': {}}} if value is BooleanOperator.ALL else {value.value: {}}
    if isinstance(value, StatePredicate): return {'atom': {'state': dict(column=str(_wide(value.column)), value=_enum(value.state, CellState))}}
    if isinstance(value, Comparison): return {'atom': {'compare': dict(column=str(_wide(value.column)), op=_enum(value.op, CompareOperator), value=logical.atom_wire(value.value))}}
    raise TypeError('Expected typed predicate')


def _mutation(value: Mutation) -> object:
    budget = _WireBudget(LIMITS['catalog_action_bytes'])
    predicates = None
    if isinstance(value, Insert):
        if not 1 <= len(value.rows) <= 1024: raise ValueError('Invalid insert row count')
        action: object = {'insert': [_assignments(row, budget) for row in value.rows]}
    elif isinstance(value, (Update, Delete)):
        action = {'update': _assignments(value.assignments, budget)} if isinstance(value, Update) else {'delete': {}}
        if value.predicate is not None:
            if len(value.predicate) > 64: raise ValueError('Too many predicate instructions')
            predicates = [budget.take(_predicate(item)) for item in value.predicate]
    else: raise TypeError('Expected typed mutation')
    return dict(action=action, predicate=predicates)


def _change(value: Change) -> object:
    if isinstance(value, AddColumn): return {'add': _column(value.name, value.type, value.nullable, value.default, value.max_characters)}
    column = str(_wide(value.column))
    if isinstance(value, DropColumn): return {'drop': column}
    if isinstance(value, RenameColumn): return {'rename': dict(column=column, name=_name(value.name))}
    if isinstance(value, SetDefault): return {'default': dict(column=column, value=None if value.value is None else logical.cell_wire(value.value))}
    if isinstance(value, SetNullable): return {'nullable': dict(column=column, value=_boolean(value.nullable))}
    if isinstance(value, SetType): return {'type': dict(column=column, type=logical.type_wire(value.type), max_characters=None if value.max_characters is None else integer(value.max_characters, 'characters', maximum=0xffffffff))}
    raise TypeError('Expected typed schema change')


def _operation(value: Operation) -> tuple[Kind, int, object]:
    if isinstance(value, Create): return Kind.CREATE, value.schema.object_id, {'create': dict(schema=value.schema._wire(), if_not_exists=_boolean(value.if_not_exists))}
    if isinstance(value, Drop): return Kind.DROP, value.basis.object_id if value.basis else 0, {'drop': dict(basis=None if value.basis is None else value.basis._wire(), if_exists=_boolean(value.if_exists))}
    if isinstance(value, Rename): return Kind.RENAME, value.basis.object_id, {'rename': dict(basis=value.basis._wire(), name=_name(value.name))}
    if isinstance(value, Alter): return Kind.ALTER, value.basis.object_id, {'alter': dict(basis=value.basis._wire(), change=_change(value.change))}
    if isinstance(value, Mutate):
        kind = Kind.INSERT if isinstance(value.mutation, Insert) else Kind.UPDATE if isinstance(value.mutation, Update) else Kind.DELETE
        return kind, value.basis.object_id, {'mutate': dict(basis=value.basis._wire(), mutation=_mutation(value.mutation))}
    raise TypeError('Expected typed catalog operation')

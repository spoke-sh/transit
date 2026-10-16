"""Typed v1 query callers; shared Zig owns admission, execution and verification."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass, field
from enum import Enum
import importlib
from pathlib import Path
from types import TracebackType
from typing import Any

from transit_client import ProcessRef, ResourceRef
from transit_client._native import Library, encode, seed
from transit_client._worker import Worker, owned_await
from transit_client.errors import IncompatibleNative, UnsupportedCapability, native_error
from transit_client.types import integer, owned_bytes
from .document import DocumentReference
from .turn import ReadVersion
from . import logical_values as logical
from .logical_values import Descriptor as Type, Atom as Scalar, Cell as Cell
from .catalog_values import Metadata, Schema

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


U64_MAX = (1 << 64)-1


def _wide(value: int, name: str, minimum: int = 0) -> int:
    return integer(value, name, minimum=minimum, maximum=U64_MAX)


class DecoderType(Enum):
    INT64 = 'int64'
    UINT64 = 'uint64'
    FLOAT64 = 'float64'
    BOOLEAN = 'boolean'
    UTF8 = 'utf8'
    BINARY = 'binary'


class State(Enum):
    MISSING = 'missing'
    NULL = 'null'
    TYPE_ERROR = 'type_error'
    VALUE = 'value'
    CONFLICT = 'conflict'


def _scalar_wire(value: Scalar) -> object:
    result = logical.atom_wire(value)
    if 'utf8' in result: owned_bytes(result['utf8'].encode('utf-8'), 4096)
    if 'binary' in result and len(result['binary']) > 8192: raise ValueError('Query literal exceeds its 4096-byte bound')
    return result


def _name(value: str) -> str:
    owned_bytes(value.encode('utf-8'), 255)
    if not value or '\0' in value: raise ValueError('Expected a nonempty UTF-8 query name without NUL')
    return value


@dataclass(frozen=True, slots=True)
class Column:
    name: str
    type: Type
    nullable: bool = False
    optional: bool = False
    def _wire(self) -> object:
        return dict(name=_name(self.name), type=logical.type_wire(self.type), nullable=self.nullable, optional=self.optional)


def _column(value: dict[str, Any]) -> Column:
    return Column(_name(value['name']), logical.type_from_wire(value['type']), value['nullable'], value['optional'])


@dataclass(frozen=True, slots=True)
class DecoderColumn:
    name: str
    type: DecoderType
    def _wire(self) -> object:
        owned_bytes(self.name.encode('utf-8'), 32)
        return dict(name=self.name, type=self.type.value)


@dataclass(frozen=True, slots=True)
class Decoder:
    type: DecoderType
    version: int = 1
    def _wire(self) -> object: return {'type': self.type.value, 'version': integer(self.version, 'decoder version', maximum=255)}


@dataclass(frozen=True, slots=True)
class KVSource:
    resource: ResourceRef
    prefix: bytes
    key: Decoder
    value: Decoder
    def _wire(self) -> object:
        return {'version': 1, 'resource': self.resource.resource, 'source': {'kv': {
            'prefix': owned_bytes(self.prefix, 32).hex(), 'key': self.key._wire(), 'value': self.value._wire()}}}


@dataclass(frozen=True, slots=True)
class TableSource:
    owner: ProcessRef
    metadata: Metadata
    schema: Schema
    def __post_init__(self) -> None:
        if not isinstance(self.owner, ProcessRef) or not isinstance(self.metadata, Metadata) or not isinstance(self.schema, Schema):
            raise TypeError('Expected a catalog Table definition and owner')
        if self.owner.realm != self.resource.realm or self.schema.object_id != self.metadata.object_id:
            raise ValueError('Table source requires one catalog identity and realm')
    @property
    def resource(self) -> ResourceRef: return self.metadata.scope.resource
    def _wire(self) -> object:
        m = self.metadata
        row_type = logical.StructureType(tuple(logical.Field(c.name, c.type, c.nullable, False) for c in self.schema.columns))
        return {'version': 1, 'resource': self.resource.resource, 'source': {'table': {
            'scope': m.scope._wire(), 'owner': self.owner.pid, 'object': str(m.object_id),
            'metadata': {'id': str(m.revision), 'spec': {'format': 0x54434d01, 'length': m.commitment.bytes,
                'digest': list(bytes.fromhex(m.commitment.digest))}}, 'row_type': logical.type_wire(row_type)}}}


class ProjectionMode(Enum):
    SCALAR = 'scalar'
    TEXT = 'text'
    ELEMENT_COUNTER = 'element_counter'
    ELEMENT_REPLICA = 'element_replica'


@dataclass(frozen=True, slots=True)
class Projection:
    column: DecoderColumn
    path: tuple[str, ...] = ()
    relative: bool = False
    mode: ProjectionMode = ProjectionMode.SCALAR
    text_bytes: int = 4096
    text_steps: int = 4096
    def _wire(self) -> object:
        return {'column': self.column._wire(), 'path': self.path, 'relative': self.relative,
            'mode': self.mode.value, 'text_bytes': integer(self.text_bytes, 'text bytes', maximum=4096),
            'text_steps': integer(self.text_steps, 'text steps', maximum=16384)}


@dataclass(frozen=True, slots=True)
class DocumentSource:
    reference: DocumentReference
    projections: tuple[Projection, ...]
    expand: tuple[str, ...] | None = None
    @property
    def resource(self) -> ResourceRef: return self.reference.resource
    def _wire(self) -> object:
        ref = self.reference
        return {'version': 1, 'resource': self.resource.resource, 'source': {'document': {
            'reference': {'resource': self.resource.resource, 'document': str(ref.document), 'epoch': str(ref.epoch),
                'type_revision': ref.type_revision, 'revision': str(ref.revision)}, 'change_format': 1,
            'expand': self.expand, 'projections': [value._wire() for value in self.projections]}}}


type Source = KVSource | TableSource | DocumentSource


@dataclass(frozen=True, slots=True)
class IsState:
    column: int
    state: State
    def _wire(self) -> object:
        return {'state': {'column': integer(self.column, 'column', minimum=0, maximum=127), 'value': self.state.value}}


@dataclass(frozen=True, slots=True)
class Compare:
    column: int
    comparison: Comparison
    value: Scalar
    def _wire(self) -> object:
        return {'compare': {'column': integer(self.column, 'column', minimum=0, maximum=127),
            'op': self.comparison.value, 'value': _scalar_wire(self.value)}}


class PredicateOperator(Enum):
    NEGATE = 'negate'
    CONJUNCTION = 'conjunction'
    DISJUNCTION = 'disjunction'


@dataclass(frozen=True, slots=True)
class PredicateAtom:
    predicate: IsState | Compare | None = None
    def _wire(self) -> object:
        if self.predicate is not None and not isinstance(self.predicate, (IsState, Compare)):
            raise TypeError('Expected a non-program predicate atom')
        return {'atom': {'all': {}} if self.predicate is None else self.predicate._wire()}


@dataclass(frozen=True, slots=True)
class PredicateProgram:
    """Immutable postfix instructions; shared Zig validates shape and types."""
    instructions: tuple[PredicateAtom | PredicateOperator, ...]
    def _wire(self) -> object:
        if not isinstance(self.instructions, tuple) or not 1 <= len(self.instructions) <= 64:
            raise TypeError('Expected one to 64 immutable predicate instructions')
        if any(not isinstance(v, (PredicateAtom, PredicateOperator)) for v in self.instructions):
            raise TypeError('Expected a predicate atom or operator')
        return {'program': [{v.value: {}} if isinstance(v, PredicateOperator) else v._wire() for v in self.instructions]}


@dataclass(frozen=True, slots=True)
class Plan:
    projection: tuple[int, ...]
    predicate: IsState | Compare | PredicateProgram | None = None
    limit: int | None = None
    aggregate: Aggregate = Aggregate.ROWS
    output_names: tuple[str | None, ...] | None = None
    def _wire(self) -> object:
        if not isinstance(self.aggregate, Aggregate): raise TypeError('Expected a query aggregate')
        if self.predicate is not None and not isinstance(self.predicate, (IsState, Compare, PredicateProgram)):
            raise TypeError('Expected a query predicate')
        if not isinstance(self.projection, tuple) or not 1 <= len(self.projection) <= 128:
            raise TypeError('Expected one to 128 immutable projection indices')
        if self.output_names is not None and (not isinstance(self.output_names, tuple) or len(self.output_names) != len(self.projection)):
            raise TypeError('Output names must match the projection width')
        if self.output_names is not None:
            for name in self.output_names:
                if name is not None: _name(name)
        return {'version': 1, 'projection': [integer(v, 'column', minimum=0, maximum=127) for v in self.projection],
            'output_names': self.output_names,
            'predicate': {'all': {}} if self.predicate is None else self.predicate._wire(),
            'limit': None if self.limit is None else str(_wide(self.limit, 'limit')), 'aggregate': self.aggregate.value}


@dataclass(frozen=True, slots=True)
class Budgets:
    pages: int
    segments: int
    result_bytes: int
    def _wire(self) -> object:
        return {name: str(_wide(getattr(self, name), name, 1)) for name in ('pages', 'segments', 'result_bytes')}


def _codec(action: object, directory: Path | None) -> dict[str, Any]:
    api = Library('station', Path(__file__).with_name('station-abi.json'), directory)
    worker = Worker(api.contract['minimum_stack_bytes'])
    try:
        data = encode(action)
        def call() -> dict[str, Any]:
            result: dict[str, Any] = api.call('station_unified_query_codec', data, len(data))
            return result
        return worker.call(call)
    finally:
        worker.close(lambda: None)


def decode_arrow(columns: tuple[Column, ...], ipc: bytes, rows: int, *,
                 native_directory: Path | None = None) -> tuple[tuple[Cell, ...], ...]:
    """Decode one owned segment through Zig; this does not establish permission."""
    value = _codec({'inspect_arrow': {'columns': [column._wire() for column in columns],
        'rows': integer(rows, 'rows', minimum=0, maximum=8), 'ipc': owned_bytes(ipc, 65536).hex()}}, native_directory)
    return tuple(tuple(logical.cell_from_wire(cell) for cell in row) for row in value['rows'])


@dataclass(frozen=True, slots=True)
class Bundle:
    """Validated canonical bytes; preparing this value does not admit work."""
    data: bytes = field(repr=False)
    def __post_init__(self) -> None: object.__setattr__(self, 'data', owned_bytes(self.data, 25255))
    @classmethod
    def prepare(cls, source: Source, plan: Plan, budgets: Budgets, *, native_directory: Path | None = None) -> Bundle:
        result = _codec({'prepare': {'source': source._wire(), 'plan': plan._wire(), 'limits': budgets._wire()}}, native_directory)
        return cls(bytes.fromhex(result['prepared']['bytes']))


@dataclass(frozen=True, slots=True)
class Connection:
    source: ProcessRef
    resource: ResourceRef
    requester: ProcessRef
    requests: ResourceRef
    role: int | None = None
    def __post_init__(self) -> None:
        if len({self.source.realm, self.resource.realm, self.requester.realm, self.requests.realm}) != 1:
            raise ValueError('Query connection must use one realm')
        if self.role is not None: integer(self.role, 'selected role', minimum=0)
    def _wire(self, principal: int) -> object:
        return {'realm': self.source.realm, 'principal': integer(principal, 'principal'), 'source': self.source.pid,
            'resource': self.resource.resource, 'requester': self.requester.pid, 'requests': self.requests.resource, 'role': self.role}


@dataclass(frozen=True, slots=True)
class Prepared:
    """Persist before submit; import the same bytes after transport or host loss."""
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        object.__setattr__(self, 'data', owned_bytes(self.data, 8192))
        self.data.decode('utf-8', errors='strict')


@dataclass(frozen=True, slots=True)
class Cursor:
    data: str = field(repr=False)
    def __post_init__(self) -> None: owned_bytes(self.data.encode(), 4096)


class Phase(Enum):
    UPLOADING = 'uploading'
    SEALED = 'sealed'
    ADMITTED = 'admitted'
    COMPLETE = 'complete'
    CANCELLED = 'cancelled'
    DENIED = 'denied'
    REJECTED = 'rejected'
    RETIRED = 'retired'


@dataclass(frozen=True, slots=True)
class Failure:
    code: str
    stage: str
    dimension: str
    limit: int
    observed: int


def _failure(value: dict[str, Any] | None) -> Failure | None:
    if value is None: return None
    return Failure(value['code'], value['stage'], value['dimension'], _wide(int(value['limit']), 'limit'), _wide(int(value['observed']), 'observed'))


@dataclass(frozen=True, slots=True)
class Status:
    phase: Phase
    correlation: int
    reference: bytes
    manifest: bytes | None
    collected: bool
    failure: Failure | None
    diagnostic: dict[str, Any] | None


class Observed(Enum):
    PENDING = 'pending'
    COMMITTED = 'committed'
    REJECTED = 'rejected'


@dataclass(frozen=True, slots=True)
class Observation:
    state: Observed
    reason: str | None = None


@dataclass(frozen=True, slots=True)
class Description:
    resource_revision: int
    policy_revision: int
    limits: Budgets
    active: int | None
    bundle_bytes: int
    segment_bytes: int
    batch_rows: int


@dataclass(frozen=True, slots=True)
class InspectedState:
    column: str
    state: State


@dataclass(frozen=True, slots=True)
class InspectedComparison:
    column: str
    comparison: Comparison
    type: Type


@dataclass(frozen=True, slots=True)
class InspectedAtom:
    predicate: InspectedState | InspectedComparison | None


@dataclass(frozen=True, slots=True)
class InspectedProgram:
    instructions: tuple[InspectedAtom | PredicateOperator, ...]


def _inspected_atom(value: dict[str, Any]) -> InspectedState | InspectedComparison | None:
    if not isinstance(value, dict) or len(value) != 1:
        raise IncompatibleNative('Invalid inspected atom')
    if 'all' in value and value['all'] == {}: return None
    if 'state' in value:
        v = value['state']
        return InspectedState(v['column'], State(v['value']))
    if 'compare' in value:
        v = value['compare']
        return InspectedComparison(v['column'], Comparison(v['op']), logical.type_from_wire(v['type']))
    raise IncompatibleNative('Invalid inspected atom')


def _inspected_predicate(value: dict[str, Any]) -> InspectedState | InspectedComparison | InspectedProgram | None:
    if not isinstance(value, dict) or len(value) != 1:
        raise IncompatibleNative('Invalid inspected predicate')
    if 'program' not in value: return _inspected_atom(value)
    program = value['program']
    if not isinstance(program, list) or not 1 <= len(program) <= 64:
        raise IncompatibleNative('Invalid inspected program size')
    instructions: list[InspectedAtom | PredicateOperator] = []
    depth = 0
    for instruction in program:
        if not isinstance(instruction, dict) or len(instruction) != 1:
            raise IncompatibleNative('Invalid inspected instruction')
        if 'atom' in instruction:
            instructions.append(InspectedAtom(_inspected_atom(instruction['atom'])))
            depth += 1
        else:
            name, payload = next(iter(instruction.items()))
            try: operator = PredicateOperator(name)
            except ValueError as error: raise IncompatibleNative('Invalid inspected operator') from error
            needed = 1 if operator is PredicateOperator.NEGATE else 2
            if payload != {} or depth < needed:
                raise IncompatibleNative('Invalid inspected program shape')
            depth -= needed - 1
            instructions.append(operator)
    if depth != 1: raise IncompatibleNative('Invalid inspected program shape')
    return InspectedProgram(tuple(instructions))


@dataclass(frozen=True, slots=True)
class SourceDescription:
    columns: tuple[Column, ...]


@dataclass(frozen=True, slots=True)
class TableListing:
    names: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class Explanation:
    operators: tuple[str, ...]
    predicate: InspectedState | InspectedComparison | InspectedProgram | None
    projection: tuple[str, ...]
    limit: int | None
    aggregate: Aggregate
    columns: tuple[Column, ...]
    budgets: Budgets


@dataclass(frozen=True, slots=True)
class Inspection:
    """Current configured-source metadata, never a captured query result."""
    name: str
    resource: ResourceRef
    source_kind: str
    source_digest: bytes
    schema_digest: bytes
    resource_revision: int
    policy_revision: int
    details: SourceDescription | TableListing | Explanation


def _inspection(value: dict[str, Any], resource: ResourceRef) -> Inspection:
    if value['version'] != 1 or value['scope'] != 'configured_source' or value['resource'] != resource.resource:
        raise IncompatibleNative('Invalid SQL inspection scope')
    if value['source_kind'] not in ('kv', 'table', 'document'):
        raise IncompatibleNative('Invalid SQL inspection source')
    details = value['details']
    result: SourceDescription | TableListing | Explanation
    if len(details) != 1: raise IncompatibleNative('Invalid SQL inspection variant')
    if 'description' in details:
        result = SourceDescription(tuple(_column(v) for v in details['description']['columns']))
    elif 'tables' in details:
        result = TableListing(tuple(details['tables']))
    elif 'explanation' in details:
        plan = details['explanation']
        inspected = _inspected_predicate(plan['predicate'])
        operators = tuple(plan['operators'])
        if not 2 <= len(operators) <= 4 or any(op not in ('scan', 'filter', 'limit', 'project', 'count', 'sum', 'count_values') for op in operators):
            raise IncompatibleNative('Invalid inspected operators')
        limits = plan['budgets']
        result = Explanation(operators, inspected, tuple(plan['projection']),
            None if plan['limit'] is None else _wide(int(plan['limit']), 'limit'), Aggregate(plan['aggregate']),
            tuple(_column(v) for v in plan['columns']),
            Budgets(*(int(limits[name]) for name in ('pages', 'segments', 'result_bytes'))))
    else: raise IncompatibleNative('Invalid SQL inspection variant')
    source_digest, schema_digest = bytes(value['contract']), bytes(value['schema'])
    if len(source_digest) != 32 or len(schema_digest) != 32: raise IncompatibleNative('Invalid inspection commitment')
    return Inspection(value['name'], resource, value['source_kind'], source_digest, schema_digest,
        integer(value['resource_revision'], 'revision', minimum=0), _wide(int(value['policy_revision']), 'policy revision', 1), result)


def _inspection_request(source: Source, name: str, sql: str, budgets: Budgets) -> object:
    _name(name)
    owned_bytes(sql.encode(), 4096)
    return {'inspect': {'scope': {'source': source._wire(), 'name': name, 'limits': budgets._wire()}, 'sql': sql}}


def _compilation_request(source: Source, name: str, sql: str, budgets: Budgets,
                         parameters: tuple[Scalar, ...] | None) -> object:
    _name(name)
    owned_bytes(sql.encode(), 4096)
    if parameters is not None and (not isinstance(parameters, tuple) or len(parameters) > 65):
        raise ValueError('Expected at most 65 logical parameter atoms in a tuple')
    values = None if parameters is None else [_scalar_wire(value) for value in parameters]
    return {'compile': {'scope': {'source': source._wire(), 'name': name, 'limits': budgets._wire()},
                        'sql': sql, 'parameters': values}}


@dataclass(frozen=True, slots=True)
class Manifest:
    job: int
    source: ReadVersion
    requester: ProcessRef
    correlation: int
    policy_revision: int
    request: bytes
    source_kind: str
    resource: ResourceRef
    revision: int
    source_digest: bytes
    schema_digest: bytes
    source_head: bytes
    plan_digest: bytes
    pages: int
    scanned: int
    selected: int
    value_count: int
    segments: int
    rows: int
    byte_count: int
    sum: int | None
    finished: str
    chain: bytes


@dataclass(frozen=True, slots=True)
class Page:
    manifest: Manifest
    columns: tuple[Column, ...]
    ordinal: int
    rows: int
    ipc: bytes = field(repr=False)
    next: Cursor | None
    def decode(self, *, native_directory: Path | None = None) -> tuple[tuple[Cell, ...], ...]:
        return decode_arrow(self.columns, self.ipc, self.rows, native_directory=native_directory)
    def to_pyarrow(self) -> Any:
        try: arrow = importlib.import_module('pyarrow')
        except ImportError: raise UnsupportedCapability('Install transit-station[arrow]') from None
        if arrow.__version__ != '23.0.0': raise UnsupportedCapability('Arrow adapter requires qualified PyArrow 23.0.0')
        with arrow.ipc.open_stream(self.ipc) as reader: result = reader.read_all()
        if result.num_rows != self.rows: raise IncompatibleNative('Arrow row coverage changed')
        return result


def _page(v: dict[str, Any], realm: int) -> Page:
    data, basis = v['manifest'], v['manifest']['basis']
    original = data['source']
    manifest = Manifest(integer(data['job'], 'job'), ReadVersion(original['pid'], original['input'], original['index']),
        ProcessRef(realm, data['requester']), _wide(int(data['correlation']), 'correlation'), _wide(int(data['policy_revision']), 'policy revision'),
        owned_bytes(bytes.fromhex(data['request']), 72), basis['cut']['kind'], ResourceRef(realm, basis['cut']['resource']), integer(basis['cut']['revision'], 'revision', minimum=0),
        bytes(basis['contract']), bytes(basis['schema']), bytes(basis['cut']['head']), bytes(data['plan']),
        _wide(int(data['pages']), 'pages'), _wide(int(data['scanned']), 'scanned'), _wide(int(data['selected']), 'selected'), _wide(int(data['value_count']), 'value count'),
        _wide(int(data['segments']), 'segments'), _wide(int(data['rows']), 'rows'), _wide(int(data['bytes']), 'bytes'),
        None if data['sum'] is None else integer(int(data['sum']), 'sum', minimum=-(1 << 63), maximum=(1 << 63)-1), data['finished'], bytes(data['chain']))
    if any(len(v) != 32 for v in (manifest.source_digest, manifest.schema_digest, manifest.source_head, manifest.plan_digest, manifest.chain)):
        raise IncompatibleNative('Invalid manifest commitment')
    return Page(manifest, tuple(_column(item) for item in v['columns']),
        _wide(int(v['ordinal']), 'ordinal'), integer(v['rows'], 'rows', minimum=0, maximum=8),
        owned_bytes(bytes.fromhex(v['ipc']), 65536), None if v['next'] is None else Cursor(v['next']))


class Client:
    """One owned native worker; close joins in-flight work. No activation needed."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        self.connection = connection
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        self._handle = c.c_void_p()
        def create() -> None:
            endpoint, key = url.encode(), seed(seed_file)
            try:
                config = encode({'connection': connection._wire(principal), 'timeout_ms': integer(timeout_ms, 'timeout', maximum=60000)})
                status = self._api.lib.station_unified_query_create(1, endpoint, len(endpoint), key, config, len(config), c.byref(self._handle))
                if status: raise native_error(status, phase='open_query')
            finally: c.memset(key, 0, 32)
        try:
            self._worker.call(create)
            caps = self._call({'capabilities': {}})['capabilities']
            if caps['version'] != 1 or not all(caps[name] for name in ('kv', 'table', 'document')):
                raise UnsupportedCapability('Native query client lacks v1 source capabilities')
        except BaseException:
            self.close()
            raise

    def _invoke(self, action: object, recovery: bytes = b'') -> dict[str, Any]:
        data = encode(action)
        result: dict[str, Any] = self._api.call('station_unified_query_call', self._handle, data, len(data), recovery=recovery)
        return result

    def _call(self, action: object, recovery: bytes = b'') -> dict[str, Any]:
        return self._worker.call(lambda: self._invoke(action, recovery))

    def describe(self, source: Source) -> Description:
        if source.resource != self.connection.resource: raise ValueError('Source differs from the connection')
        v = self._call({'describe': source._wire()})['description']
        budgets, caps = v['limits'], v['capabilities']
        return Description(integer(v['resource_revision'], 'revision', minimum=0), _wide(int(v['policy_revision']), 'policy revision'),
            Budgets(*(int(budgets[name]) for name in ('pages', 'segments', 'result_bytes'))),
            None if v['active'] is None else _wide(int(v['active']), 'active'), caps['bundle_bytes'], caps['segment_bytes'], caps['batch_rows'])

    def inspect_sql(self, source: Source, name: str, sql: str, budgets: Budgets) -> Inspection:
        """DESCRIBE, SHOW TABLES or EXPLAIN under current source access; no query admission."""
        if source.resource != self.connection.resource: raise ValueError('Source differs from the connection')
        return _inspection(self._call(_inspection_request(source, name, sql, budgets))['inspection'], source.resource)

    def authorize_bundle(self, bundle: Bundle) -> Bundle:
        """Seal a newly constructed bundle once, before saving its bytes or fingerprint.

        Saved or accepted bundles already carry their original proof. Recover them
        unchanged; this method rejects an already authorized Table bundle.
        """
        if not isinstance(bundle, Bundle): raise TypeError('Expected query bundle')
        return Bundle(bytes.fromhex(self._call({'authorize': bundle.data.hex()})['authorized']))

    def prepare_next(self, namespace: int, bundle: Bundle) -> Prepared | None:
        value = self._call({'next': {'namespace': str(_wide(namespace, 'namespace', 1)), 'bundle': bundle.data.hex()}})['prepared']
        return None if value is None else Prepared(value.encode())

    def compile_sql(self, source: Source, name: str, sql: str, budgets: Budgets,
                    parameters: tuple[Scalar, ...] | None = None) -> Bundle:
        """Own a finite bundle under current source access; no upload or admission."""
        if source.resource != self.connection.resource: raise ValueError('Source differs from the connection')
        result = self._call(_compilation_request(source, name, sql, budgets, parameters))
        return Bundle(bytes.fromhex(result['compiled']['bundle']))

    def _control(self, name: str, namespace: int) -> Prepared:
        value = self._call({'prepare': {name: str(_wide(namespace, 'namespace', 1))}})['prepared']
        if value is None: raise IncompatibleNative('Missing prepared command')
        return Prepared(value.encode())

    def prepare_cancel(self, namespace: int) -> Prepared: return self._control('cancel', namespace)
    def prepare_retire(self, namespace: int) -> Prepared: return self._control('retire', namespace)
    def prepare_collect(self, namespace: int) -> Prepared: return self._control('collect', namespace)

    def submit(self, prepared: Prepared) -> int:
        """Return the admitted input position; observe it before preparing again."""
        return integer(self._call({'submit': prepared.data.decode()}, prepared.data)['receipt']['position'], 'position')

    def observe(self, position: int) -> Observation:
        value = self._call({'observe': integer(position, 'position')})['observation']
        if len(value) != 1: raise IncompatibleNative('Invalid observation')
        name = next(iter(value))
        return Observation(Observed(name), bytes.fromhex(value[name]).decode() if name == 'rejected' else None)

    def status(self, namespace: int) -> Status | None:
        value = self._call({'status': str(_wide(namespace, 'namespace', 1))})['status']
        if value is None: return None
        return Status(Phase(value['phase']), _wide(int(value['correlation']), 'correlation'), owned_bytes(bytes.fromhex(value['reference']), 72),
            None if value['manifest'] is None else owned_bytes(bytes.fromhex(value['manifest']), 72), value['collected'], _failure(value['failure']), value['diagnostic'])

    def page(self, namespace: int, cursor: Cursor | None = None) -> Page:
        return _page(self._call({'page': {'namespace': str(_wide(namespace, 'namespace', 1)),
            'cursor': None if cursor is None else cursor.data}})['page'], self.connection.source.realm)

    def _destroy(self) -> None:
        self._api.lib.station_unified_query_destroy(self._handle)
        self._handle = c.c_void_p()

    def close(self) -> None: self._worker.close(self._destroy)

    def __enter__(self) -> Client: return self
    def __exit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: self.close()


class AsyncClient:
    """One bounded worker. Cancelling an await leaves its native operation owned."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        # Construction performs only local allocation/key loading/capability
        # negotiation; all authority calls run on the owned worker below.
        self._owner = Client(url, principal, seed_file, connection, timeout_ms=timeout_ms, native_directory=native_directory)
        self.connection = connection

    async def _call(self, action: object, recovery: bytes = b'') -> dict[str, Any]:
        return await owned_await(self._owner._worker.submit(lambda: self._owner._invoke(action, recovery)))

    async def describe(self, source: Source) -> Description:
        if source.resource != self.connection.resource: raise ValueError('Source differs from the connection')
        v = (await self._call({'describe': source._wire()}))['description']
        budgets, caps = v['limits'], v['capabilities']
        return Description(integer(v['resource_revision'], 'revision', minimum=0), _wide(int(v['policy_revision']), 'policy revision'),
            Budgets(*(int(budgets[name]) for name in ('pages', 'segments', 'result_bytes'))),
            None if v['active'] is None else _wide(int(v['active']), 'active'), caps['bundle_bytes'], caps['segment_bytes'], caps['batch_rows'])

    async def inspect_sql(self, source: Source, name: str, sql: str, budgets: Budgets) -> Inspection:
        if source.resource != self.connection.resource: raise ValueError('Source differs from the connection')
        return _inspection((await self._call(_inspection_request(source, name, sql, budgets)))['inspection'], source.resource)

    async def authorize_bundle(self, bundle: Bundle) -> Bundle:
        """Seal new work before persistence; never reseal a recovered bundle."""
        if not isinstance(bundle, Bundle): raise TypeError('Expected query bundle')
        result = await self._call({'authorize': bundle.data.hex()})
        return Bundle(bytes.fromhex(result['authorized']))

    async def prepare_next(self, namespace: int, bundle: Bundle) -> Prepared | None:
        value = (await self._call({'next': {'namespace': str(_wide(namespace, 'namespace', 1)), 'bundle': bundle.data.hex()}}))['prepared']
        return None if value is None else Prepared(value.encode())

    async def compile_sql(self, source: Source, name: str, sql: str, budgets: Budgets,
                          parameters: tuple[Scalar, ...] | None = None) -> Bundle:
        """Cancellation of the await leaves the native read owned by this worker."""
        if source.resource != self.connection.resource: raise ValueError('Source differs from the connection')
        result = await self._call(_compilation_request(source, name, sql, budgets, parameters))
        return Bundle(bytes.fromhex(result['compiled']['bundle']))

    async def _control(self, name: str, namespace: int) -> Prepared:
        value = (await self._call({'prepare': {name: str(_wide(namespace, 'namespace', 1))}}))['prepared']
        if value is None: raise IncompatibleNative('Missing prepared command')
        return Prepared(value.encode())

    async def prepare_cancel(self, namespace: int) -> Prepared: return await self._control('cancel', namespace)
    async def prepare_retire(self, namespace: int) -> Prepared: return await self._control('retire', namespace)
    async def prepare_collect(self, namespace: int) -> Prepared: return await self._control('collect', namespace)

    async def submit(self, prepared: Prepared) -> int:
        return integer((await self._call({'submit': prepared.data.decode()}, prepared.data))['receipt']['position'], 'position')

    async def observe(self, position: int) -> Observation:
        value = (await self._call({'observe': integer(position, 'position')}))['observation']
        if len(value) != 1: raise IncompatibleNative('Invalid observation')
        name = next(iter(value))
        return Observation(Observed(name), bytes.fromhex(value[name]).decode() if name == 'rejected' else None)

    async def status(self, namespace: int) -> Status | None:
        value = (await self._call({'status': str(_wide(namespace, 'namespace', 1))}))['status']
        if value is None: return None
        return Status(Phase(value['phase']), _wide(int(value['correlation']), 'correlation'), owned_bytes(bytes.fromhex(value['reference']), 72),
            None if value['manifest'] is None else owned_bytes(bytes.fromhex(value['manifest']), 72), value['collected'], _failure(value['failure']), value['diagnostic'])

    async def page(self, namespace: int, cursor: Cursor | None = None) -> Page:
        return _page((await self._call({'page': {'namespace': str(_wide(namespace, 'namespace', 1)),
            'cursor': None if cursor is None else cursor.data}}))['page'], self.connection.source.realm)

    async def close(self) -> None: await self._owner._worker.aclose(self._owner._destroy)
    async def __aenter__(self) -> AsyncClient: return self
    async def __aexit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: await self.close()

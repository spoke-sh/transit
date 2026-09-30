"""Typed catalog callers; Zig owns compilation, authority, signatures and recovery."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from types import TracebackType
from typing import Any, Callable, TypeVar

from transit_client import ProcessRef, ResourceRef
from transit_client._native import Library, encode, seed
from transit_client._worker import Worker, owned_await
from transit_client.errors import IncompatibleNative, UncertainOperation, UnsupportedCapability, native_error
from transit_client.types import integer, owned_bytes
from .turn import CellType

T = TypeVar('T')
_MAX_U64 = (1 << 64) - 1


def _wide(value: object, name: str, minimum: int = 1) -> int:
    return integer(value, name, minimum=minimum, maximum=_MAX_U64)


def _text(value: object, limit: int) -> str:
    if not isinstance(value, str) or not value: raise ValueError('Expected nonempty text')
    owned_bytes(value.encode(), limit)
    return value


def _boolean(value: object) -> bool:
    if type(value) is not bool: raise ValueError('Expected boolean')
    return value


@dataclass(frozen=True, slots=True)
class Scope:
    resource: ResourceRef
    catalog: int
    def __post_init__(self) -> None:
        if not isinstance(self.resource, ResourceRef): raise TypeError('Expected resource reference')
        _wide(self.catalog, 'catalog')
    def _wire(self) -> dict[str, object]:
        return dict(realm=self.resource.realm, resource=self.resource.resource, catalog=str(self.catalog))


@dataclass(frozen=True, slots=True)
class Connection:
    owner: ProcessRef
    scope: Scope
    def __post_init__(self) -> None:
        if self.owner.realm != self.scope.resource.realm: raise ValueError('Catalog connection must use one realm')
    def _wire(self, principal: int) -> object:
        return dict(scope=self.scope._wire(), owner=self.owner.pid, principal=integer(principal, 'principal', minimum=0))


@dataclass(frozen=True, slots=True)
class Configuration:
    scope: Scope
    owner: ProcessRef
    administrator: int
    def __post_init__(self) -> None:
        Connection(self.owner, self.scope)
        integer(self.administrator, 'administrator')
    def _wire(self) -> object:
        return dict(scope=self.scope._wire(), owner=self.owner.pid, administrator=self.administrator)


@dataclass(frozen=True, slots=True)
class Schema:
    names: tuple[str, str]
    value_type: CellType
    def __post_init__(self) -> None:
        if len(self.names) != 2 or not isinstance(self.value_type, CellType): raise ValueError('Expected two-column Table schema')
        object.__setattr__(self, 'names', (_text(self.names[0], 16), _text(self.names[1], 16)))
    def _wire(self) -> object: return dict(names=list(self.names), value_type=self.value_type.value)


@dataclass(frozen=True, slots=True)
class CreateTable:
    scope: Scope
    operation: int
    object_id: int
    table: int
    name: str
    schema: Schema
    def __post_init__(self) -> None:
        if not isinstance(self.scope, Scope) or not isinstance(self.schema, Schema): raise TypeError('Expected catalog scope and schema')
        _wide(self.operation, 'operation'); _wide(self.object_id, 'object')
        integer(self.table, 'table', maximum=(1 << 32) - 1)
        _text(self.name, 16)
    def _wire(self) -> object:
        return dict(scope=self.scope._wire(), operation=str(self.operation), object=str(self.object_id), table=self.table, name=self.name, schema=self.schema._wire())


@dataclass(frozen=True, slots=True)
class Compiled:
    request: CreateTable
    canonical: bytes = field(repr=False)
    def __post_init__(self) -> None:
        if not isinstance(self.request, CreateTable): raise TypeError('Expected creation request')
        object.__setattr__(self, 'canonical', owned_bytes(self.canonical, 256))
        if not self.canonical: raise ValueError('Empty canonical creation request')


@dataclass(frozen=True, slots=True)
class Policy:
    scope: Scope
    principal: int
    revision: int
    inspect: bool
    create: bool
    def __post_init__(self) -> None:
        if not isinstance(self.scope, Scope): raise TypeError('Expected catalog scope')
        integer(self.principal, 'principal', minimum=0)
        _wide(self.revision, 'policy revision')
        _boolean(self.inspect); _boolean(self.create)
    def _wire(self) -> object:
        return dict(scope=self.scope._wire(), principal=self.principal, revision=str(self.revision), inspect=self.inspect, create=self.create)


@dataclass(frozen=True, slots=True)
class PolicyChange:
    expected_revision: int
    policy: Policy
    def __post_init__(self) -> None:
        _wide(self.expected_revision, 'expected revision', 0)
        if not isinstance(self.policy, Policy): raise TypeError('Expected catalog policy')
    def _wire(self) -> object: return dict(expected_revision=str(self.expected_revision), policy=self.policy._wire())


@dataclass(frozen=True, slots=True)
class Prepared:
    """Opaque owned signed bytes; persist unchanged before attempting submission."""
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        object.__setattr__(self, 'data', owned_bytes(self.data, 8192))
        if not self.data: raise ValueError('Empty saved catalog command')
        self.data.decode('utf-8', errors='strict')


class Observation(Enum):
    PENDING = 'pending'
    PROCESSED = 'processed'


class Outcome(Enum):
    APPLIED = 'applied'
    NAME_CONFLICT = 'name_conflict'
    OBJECT_CONFLICT = 'object_conflict'
    TABLE_CONFLICT = 'table_conflict'


class Origin(Enum):
    EXTERNAL = 'external'
    PROCESS = 'process'
    EFFECT = 'effect'


class DispositionOutcome(Enum):
    INITIALIZED = 'initialized'
    POLICY_APPLIED = 'policy_applied'
    INVALID_COMMAND = 'invalid_command'
    DENIED = 'denied'
    IDENTITY_CONFLICT = 'identity_conflict'
    STALE_POLICY = 'stale_policy'


@dataclass(frozen=True, slots=True)
class Capabilities:
    version: int
    definition: str
    initialize: bool
    create_table: bool
    conditional_policy: bool
    current_metadata: bool
    max_saved_bytes: int
    table_columns: int


@dataclass(frozen=True, slots=True)
class Description:
    configuration: Configuration
    policy: Policy
    resource_revision: int


@dataclass(frozen=True, slots=True)
class Receipt:
    request: CreateTable
    principal: int
    input: int
    outcome: Outcome


@dataclass(frozen=True, slots=True)
class Disposition:
    scope: Scope
    origin: Origin
    principal: int
    input: int
    payload: bytes
    outcome: DispositionOutcome


def _object(value: object, fields: str) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != set(fields.split()): raise ValueError('Unexpected catalog response fields')
    return value


def _decimal(value: object, minimum: int = 1) -> int:
    if not isinstance(value, str) or not 1 <= len(value) <= 20 or not value.isascii() or not value.isdigit(): raise ValueError('Expected canonical decimal string')
    result = _wide(int(value), 'catalog integer', minimum)
    if str(result) != value: raise ValueError('Expected canonical decimal string')
    return result


def _scope(value: object) -> Scope:
    v = _object(value, 'realm resource catalog')
    return Scope(ResourceRef(v['realm'], v['resource']), _decimal(v['catalog']))


def _configuration(value: object) -> Configuration:
    v = _object(value, 'scope owner administrator'); scope = _scope(v['scope'])
    return Configuration(scope, ProcessRef(scope.resource.realm, v['owner']), v['administrator'])


def _policy(value: object) -> Policy:
    v = _object(value, 'scope principal revision inspect create')
    return Policy(_scope(v['scope']), v['principal'], _decimal(v['revision']), v['inspect'], v['create'])


def _request(value: object) -> CreateTable:
    v = _object(value, 'scope operation object table name schema')
    s = _object(v['schema'], 'names value_type')
    if not isinstance(s['names'], list) or len(s['names']) != 2: raise ValueError('Expected two column names')
    schema = Schema((s['names'][0], s['names'][1]), CellType(s['value_type']))
    return CreateTable(_scope(v['scope']), _decimal(v['operation']), _decimal(v['object']), v['table'], v['name'], schema)


def _hex(value: object, limit: int, exact: bool = False) -> bytes:
    text = _text(value, limit * 2)
    result = owned_bytes(bytes.fromhex(text), limit)
    if result.hex() != text or (exact and len(result) != limit): raise ValueError('Expected canonical hexadecimal bytes')
    return result


def _compiled(value: object) -> Compiled:
    v = _object(value, 'request canonical')
    return Compiled(_request(v['request']), _hex(v['canonical'], 256))


def _description(value: object) -> Description:
    v = _object(value, 'configuration policy resource_revision')
    return Description(_configuration(v['configuration']), _policy(v['policy']), integer(v['resource_revision'], 'resource revision', minimum=0))


def _receipt(value: object) -> Receipt | None:
    if value is None: return None
    v = _object(value, 'request principal input outcome')
    return Receipt(_request(v['request']), integer(v['principal'], 'principal', minimum=0), integer(v['input'], 'input'), Outcome(v['outcome']))


def _disposition(value: object) -> Disposition | None:
    if value is None: return None
    v = _object(value, 'scope origin principal input payload outcome')
    return Disposition(_scope(v['scope']), Origin(v['origin']), integer(v['principal'], 'principal', minimum=0), integer(v['input'], 'input'), _hex(v['payload'], 32, True), DispositionOutcome(v['outcome']))


def _prepared(value: object) -> Prepared: return Prepared(_text(value, 8192).encode())


def _capabilities(value: object) -> Capabilities:
    v = _object(value, 'version definition initialize create_table conditional_policy current_metadata max_saved_bytes table_columns')
    definition = _hex(v['definition'], 32, True).hex()
    return Capabilities(integer(v['version'], 'version', maximum=255), definition, _boolean(v['initialize']), _boolean(v['create_table']), _boolean(v['conditional_policy']), _boolean(v['current_metadata']), integer(v['max_saved_bytes'], 'saved bytes', maximum=65535), integer(v['table_columns'], 'columns', maximum=255))


def _decode(decoder: Callable[[Any], T], value: object, recovery: bytes = b'') -> T:
    try: return decoder(value)
    except (ValueError, TypeError, KeyError, AttributeError, OverflowError):
        if recovery: raise UncertainOperation(recovery=recovery, phase='catalog_response') from None
        raise IncompatibleNative('Invalid catalog response from native implementation') from None
    except MemoryError:
        if recovery: raise UncertainOperation(recovery=recovery, phase='catalog_response') from None
        raise


def _compile(sql: str, operation: int, object_id: int, table: int) -> object:
    return {'compile': dict(sql=_text(sql, 4096), operation=str(_wide(operation, 'operation')), object=str(_wide(object_id, 'object')), table=integer(table, 'table', maximum=(1 << 32) - 1))}


def _input(kind: str, prepared: Prepared, position: int) -> object:
    return {kind: dict(prepared=prepared.data.decode(), input=integer(position, 'input'))}


class Client:
    """One owned worker with bounded admission; no implicit retries or provisioning."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        self._connection = connection
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._handle = c.c_void_p()
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        def create() -> None:
            endpoint = _text(url, 2048).encode()
            config = encode(dict(connection=connection._wire(principal), timeout_ms=integer(timeout_ms, 'timeout', maximum=60000)))
            key = seed(seed_file)
            try:
                status = self._api.lib.station_catalog_create(1, endpoint, len(endpoint), key, config, len(config), c.byref(self._handle))
                if status: raise native_error(status, phase='open_catalog')
            finally: c.memset(key, 0, 32)
        try:
            self._worker.call(create)
            caps = self.capabilities()
            if caps.version != 1 or caps.definition != self._api.contract['definition'] or caps.table_columns != 2 or caps.max_saved_bytes != 8192 or not all((caps.initialize, caps.create_table, caps.conditional_policy, caps.current_metadata)):
                raise UnsupportedCapability('Native catalog client lacks the named Table profile')
        except BaseException:
            self.close()
            raise

    @property
    def connection(self) -> Connection: return self._connection

    def _invoke(self, action: object, field_name: str, decoder: Callable[[Any], T], recovery: bytes) -> T:
        data = encode(action)
        try:
            result = self._api.call('station_catalog_call', self._handle, data, len(data), recovery=recovery)
        except (ValueError, TypeError):
            if recovery: raise UncertainOperation(recovery=recovery, phase='catalog_response') from None
            raise IncompatibleNative('Malformed catalog response') from None
        except MemoryError:
            if recovery: raise UncertainOperation(recovery=recovery, phase='catalog_response') from None
            raise
        return _decode(lambda v: decoder(_object(v, field_name)[field_name]), result, recovery)

    def _call(self, action: object, field_name: str, decoder: Callable[[Any], T], recovery: bytes = b'') -> T:
        return self._worker.call(lambda: self._invoke(action, field_name, decoder, recovery))

    def capabilities(self) -> Capabilities: return self._call({'capabilities': {}}, 'capabilities', _capabilities)
    def describe(self) -> Description: return self._call({'describe': {}}, 'description', _description)
    def compile_sql(self, sql: str, operation: int, object_id: int, table: int) -> Compiled:
        return self._call(_compile(sql, operation, object_id, table), 'compiled', _compiled)
    def prepare_initialize(self, configuration: Configuration) -> Prepared:
        return self._call({'prepare_initialize': configuration._wire()}, 'prepared', _prepared)
    def prepare_create(self, request: CreateTable) -> Prepared:
        return self._call({'prepare_create': request._wire()}, 'prepared', _prepared)
    def prepare_policy(self, change: PolicyChange) -> Prepared:
        return self._call({'prepare_policy': change._wire()}, 'prepared', _prepared)
    def submit(self, prepared: Prepared) -> int:
        return self._call({'submit': prepared.data.decode()}, 'receipt', lambda v: integer(_object(v, 'position')['position'], 'position'), prepared.data)
    def observe(self, prepared: Prepared, position: int) -> Observation:
        return self._call(_input('observe', prepared, position), 'observation', Observation)
    def input_disposition(self, prepared: Prepared, position: int) -> Disposition | None:
        return self._call(_input('input_disposition', prepared, position), 'disposition', _disposition)
    def status(self, request: CreateTable) -> Receipt | None:
        return self._call({'status': request._wire()}, 'status', _receipt)
    def _destroy(self) -> None:
        self._api.lib.station_catalog_destroy(self._handle)
        self._handle = c.c_void_p()
    def close(self) -> None: self._worker.close(self._destroy)
    def __enter__(self) -> Client: return self
    def __exit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: self.close()


class AsyncClient:
    """Await cancellation does not cancel native work; close joins its owner."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        self._owner = Client(url, principal, seed_file, connection, timeout_ms=timeout_ms, native_directory=native_directory)
    @property
    def connection(self) -> Connection: return self._owner.connection
    async def _call(self, action: object, field_name: str, decoder: Callable[[Any], T], recovery: bytes = b'') -> T:
        return await owned_await(self._owner._worker.submit(lambda: self._owner._invoke(action, field_name, decoder, recovery)))
    async def capabilities(self) -> Capabilities: return await self._call({'capabilities': {}}, 'capabilities', _capabilities)
    async def describe(self) -> Description: return await self._call({'describe': {}}, 'description', _description)
    async def compile_sql(self, sql: str, operation: int, object_id: int, table: int) -> Compiled:
        return await self._call(_compile(sql, operation, object_id, table), 'compiled', _compiled)
    async def prepare_initialize(self, configuration: Configuration) -> Prepared:
        return await self._call({'prepare_initialize': configuration._wire()}, 'prepared', _prepared)
    async def prepare_create(self, request: CreateTable) -> Prepared:
        return await self._call({'prepare_create': request._wire()}, 'prepared', _prepared)
    async def prepare_policy(self, change: PolicyChange) -> Prepared:
        return await self._call({'prepare_policy': change._wire()}, 'prepared', _prepared)
    async def submit(self, prepared: Prepared) -> int:
        return await self._call({'submit': prepared.data.decode()}, 'receipt', lambda v: integer(_object(v, 'position')['position'], 'position'), prepared.data)
    async def observe(self, prepared: Prepared, position: int) -> Observation:
        return await self._call(_input('observe', prepared, position), 'observation', Observation)
    async def input_disposition(self, prepared: Prepared, position: int) -> Disposition | None:
        return await self._call(_input('input_disposition', prepared, position), 'disposition', _disposition)
    async def status(self, request: CreateTable) -> Receipt | None:
        return await self._call({'status': request._wire()}, 'status', _receipt)
    async def close(self) -> None: await self._owner._worker.aclose(self._owner._destroy)
    async def __aenter__(self) -> AsyncClient: return self
    async def __aexit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: await self.close()

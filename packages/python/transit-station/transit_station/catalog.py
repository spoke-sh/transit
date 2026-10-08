"""Typed general Tables; Zig owns compilation, authority, signatures and recovery."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass
from pathlib import Path
from types import TracebackType
from typing import Any, Callable, Generic, TypeVar
from transit_client._native import Library, encode, seed
from transit_client._worker import Worker, owned_await
from transit_client.errors import IncompatibleNative, UncertainOperation, UnsupportedCapability, native_error
from transit_client.types import integer, owned_bytes
from . import catalog_values as v
from .catalog_values import (
    Scope as Scope,
    Connection as Connection,
    TableLimits as TableLimits,
    Configuration as Configuration,
    Rights as Rights,
    Policy as Policy,
    PolicyChange as PolicyChange,
    Column as Column,
    Schema as Schema,
    Identity as Identity,
    Basis as Basis,
    Metadata as Metadata,
    MetadataCommitment as MetadataCommitment,
    Head as Head,
    Entry as Entry,
    Definition as Definition,
    HistoricalDefinition as HistoricalDefinition,
    Cursor as Cursor,
    Page as Page,
    Reference as Reference,
    SavedIntent as SavedIntent,
    Prepared as Prepared,
    Kind as Kind,
    Intent as Intent,
    Compiled as Compiled,
    Phase as Phase,
    Counts as Counts,
    Outcome as Outcome,
    UploadPhase as UploadPhase,
    Upload as Upload,
    State as State,
    DispositionOutcome as DispositionOutcome,
    Disposition as Disposition,
    Observation as Observation,
    NextKind as NextKind,
    Next as Next,
    Progress as Progress,
    Default as Default,
    Assignment as Assignment,
    BooleanOperator as BooleanOperator,
    CellState as CellState,
    CompareOperator as CompareOperator,
    StatePredicate as StatePredicate,
    Comparison as Comparison,
    Insert as Insert,
    Update as Update,
    Delete as Delete,
    AddColumn as AddColumn,
    DropColumn as DropColumn,
    RenameColumn as RenameColumn,
    SetDefault as SetDefault,
    SetNullable as SetNullable,
    SetType as SetType,
    Create as Create,
    Alter as Alter,
    Rename as Rename,
    Drop as Drop,
    Mutate as Mutate,
    Control as Control,
    DependencyKind as DependencyKind,
    Dependency as Dependency,
    Capabilities as Capabilities,
    Description as Description,
    Predicate as Predicate,
    Mutation as Mutation,
    Change as Change,
    Operation as Operation,
)

T = TypeVar('T')


@dataclass(frozen=True)
class _Request(Generic[T]):
    data: bytes
    field: str
    decode: Callable[[Any], T]
    recovery: bytes = b''


def _request(action: object, field: str, decoder: Callable[[Any], T], recovery: bytes = b'') -> _Request[T]:
    # Freeze all arguments before queued/async work can outlive its caller.
    return _Request(owned_bytes(encode(action), v.LIMITS['catalog_action_bytes']), field, decoder, recovery)


def _empty(value: object) -> None:
    v._object(value, '')


def _input(prepared: Prepared, position: int) -> dict[str, object]:
    if not isinstance(prepared, Prepared): raise TypeError('Expected exact prepared command')
    return dict(prepared=prepared.data.decode(), input=integer(position, 'input'))


class _Queries:
    def __init__(self, connection: Connection, principal: int) -> None:
        self.connection, self.principal = connection, principal

    def capabilities(self) -> _Request[Capabilities]:
        return _request({'capabilities': {}}, 'capabilities', v._capabilities)

    def describe(self) -> _Request[Description]:
        return _request({'describe': {}}, 'description', lambda value: v._description(value, self.connection, self.principal))

    def lookup(self, name: str) -> _Request[Definition | None]:
        return _request({'lookup': v._name(name)}, 'definition', lambda value: v._resolved(value, self.connection.scope, name))

    def definition(self, object_id: int, revision: int) -> _Request[HistoricalDefinition | None]:
        return _request({'definition': dict(object=str(v._wide(object_id)), revision=str(v._wide(revision)))}, 'historical',
                        lambda value: v._historical(value, self.connection.scope, object_id, revision))

    def list(self, cursor: Cursor | None = None) -> _Request[Page]:
        if cursor is not None and (not isinstance(cursor, Cursor) or cursor.scope != self.connection.scope): raise ValueError('Foreign catalog cursor')
        return _request({'list': None if cursor is None else cursor._wire()}, 'page', lambda value: v._page(value, self.connection.scope, cursor))

    def compile_sql(self, sql: str, identity: Identity, create_object: int | None = None) -> _Request[Compiled]:
        if not isinstance(identity, Identity): raise TypeError('Expected operation identity')
        return _request({'compile': dict(sql=v._text(sql, 4096), identity=identity._wire(), create_object=None if create_object is None else str(v._wide(create_object)))}, 'compiled',
                        lambda value: v._compiled(value, self.connection, self.principal, identity, None if create_object is None else Kind.CREATE, create_object))

    def prepare(self, name: str, identity: Identity, action: Operation) -> _Request[Compiled]:
        if not isinstance(identity, Identity): raise TypeError('Expected operation identity')
        kind, object_id, operation = v._operation(action)
        return _request({'prepare': dict(definition=v.DEFINITION, identity=identity._wire(), name=v._name(name), action=operation)}, 'compiled',
                        lambda value: v._compiled(value, self.connection, self.principal, identity, kind, object_id))

    def load(self, saved: SavedIntent) -> _Request[Intent]:
        if not isinstance(saved, SavedIntent): raise TypeError('Expected saved Table intent')
        return _request({'load': saved._wire()}, 'loaded', lambda value: v._intent(value, self.connection, self.principal))

    def forget(self, intent: Reference) -> _Request[None]:
        return _request({'forget': intent._wire()}, 'forgotten', _empty)

    def next(self, intent: Reference) -> _Request[Next]:
        return _request({'next': intent._wire()}, 'next', v._next)

    def status(self, intent: Reference) -> _Request[State]:
        return _request({'status': intent._wire()}, 'state', v._state)

    def prepare_resume(self, intent: Reference) -> _Request[Prepared]:
        return _request({'prepare_resume': intent._wire()}, 'prepared', v._prepared)

    def prepare_control(self, intent: Reference, control: Control) -> _Request[Prepared]:
        return _request({'prepare_control': dict(intent=intent._wire(), control=v._enum(control, Control))}, 'prepared', v._prepared)

    def prepare_initialize(self, configuration: Configuration) -> _Request[Prepared]:
        return _request({'prepare_initialize': configuration._wire()}, 'prepared', v._prepared)

    def prepare_policy(self, change: PolicyChange) -> _Request[Prepared]:
        return _request({'prepare_policy': change._wire()}, 'prepared', v._prepared)

    def prepare_dependency(self, dependency: Dependency, present: bool) -> _Request[Prepared]:
        return _request({'prepare_dependency': dependency._wire(present)}, 'prepared', v._prepared)

    def submit(self, prepared: Prepared) -> _Request[int]:
        if not isinstance(prepared, Prepared): raise TypeError('Expected exact prepared command')
        return _request({'submit': prepared.data.decode()}, 'receipt', lambda value: integer(v._object(value, 'position')['position'], 'position'), prepared.data)

    def observe(self, prepared: Prepared, position: int, *, wait: bool = False) -> _Request[Observation]:
        return _request({'wait_observe' if v._boolean(wait) else 'observe': _input(prepared, position)}, 'observation', Observation)

    def input_disposition(self, prepared: Prepared, position: int) -> _Request[Disposition | None]:
        return _request({'input_disposition': _input(prepared, position)}, 'disposition', v._disposition)

    def progress(self, intent: Reference, prepared: Prepared, position: int, *, wait: bool = False) -> _Request[Progress]:
        return _request({'wait_progress' if v._boolean(wait) else 'progress': dict(intent=intent._wire(), **_input(prepared, position))}, 'progress', v._progress)


class Client:
    """One owned worker and one intent; persist intent and every exact step before send."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        if not isinstance(connection, Connection): raise TypeError('Expected catalog connection')
        self._queries = _Queries(connection, integer(principal, 'principal', minimum=0))
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._handle = c.c_void_p()
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        def create() -> None:
            endpoint = v._text(url, 2048).encode()
            config = encode(dict(connection=connection._wire(principal), timeout_ms=integer(timeout_ms, 'timeout', maximum=60000)))
            key = seed(seed_file)
            try:
                status = self._api.lib.station_catalog_create(1, endpoint, len(endpoint), key, config, len(config), c.byref(self._handle))
                if status: raise native_error(status, phase='open_catalog')
            finally: c.memset(key, 0, 32)
        try:
            self._worker.call(create)
            caps = self.capabilities()
            if (caps.version != 1 or caps.definition != v.DEFINITION or caps.max_columns != 128 or caps.max_rows != 1024 or
                caps.max_sql_bytes != 4096 or caps.max_intent_bytes != v.LIMITS['catalog_intent_bytes'] or
                caps.max_action_bytes != v.LIMITS['catalog_action_bytes'] or caps.max_prepared_bytes != v.LIMITS['catalog_prepared_bytes'] or caps.resident_intents != 1):
                raise UnsupportedCapability('Native catalog client lacks the general Table profile')
        except BaseException:
            self.close()
            raise

    @property
    def connection(self) -> Connection: return self._queries.connection

    def _diagnostics(self, value: object) -> None:
        # Validate success-path evidence using the same owner as error envelopes.
        if isinstance(value, dict):
            for key, child in value.items():
                if key == 'diagnostic':
                    data = encode(child)
                    if not isinstance(child, dict) or len(data) > 32768 or self._api.validate_diagnostic(data, len(data)) != 1: raise ValueError('Invalid Table diagnostic')
                elif isinstance(child, dict): self._diagnostics(child)

    def _invoke(self, request: _Request[T]) -> T:
        try:
            value = self._api.call('station_catalog_call', self._handle, request.data, len(request.data), recovery=request.recovery)
            self._diagnostics(value)
            return request.decode(v._object(value, request.field)[request.field])
        except (ValueError, TypeError, KeyError, AttributeError, OverflowError, RecursionError):
            if request.recovery: raise UncertainOperation(recovery=request.recovery, phase='catalog_response') from None
            raise IncompatibleNative('Invalid catalog response from native implementation') from None
        except MemoryError:
            if request.recovery: raise UncertainOperation(recovery=request.recovery, phase='catalog_response') from None
            raise

    def _call(self, request: _Request[T]) -> T:
        return self._worker.call(lambda: self._invoke(request))

    def capabilities(self) -> Capabilities:
        return self._call(self._queries.capabilities())

    def describe(self) -> Description:
        return self._call(self._queries.describe())

    def lookup(self, name: str) -> Definition | None:
        return self._call(self._queries.lookup(name))

    def definition(self, object_id: int, revision: int) -> HistoricalDefinition | None:
        return self._call(self._queries.definition(object_id, revision))

    def list(self, cursor: Cursor | None=None) -> Page:
        return self._call(self._queries.list(cursor))

    def compile_sql(self, sql: str, identity: Identity, create_object: int | None=None) -> Compiled:
        return self._call(self._queries.compile_sql(sql, identity, create_object))

    def prepare(self, name: str, identity: Identity, action: Operation) -> Compiled:
        return self._call(self._queries.prepare(name, identity, action))

    def load(self, saved: SavedIntent) -> Intent:
        return self._call(self._queries.load(saved))

    def forget(self, intent: Reference) -> None:
        return self._call(self._queries.forget(intent))

    def next(self, intent: Reference) -> Next:
        return self._call(self._queries.next(intent))

    def status(self, intent: Reference) -> State:
        return self._call(self._queries.status(intent))

    def prepare_resume(self, intent: Reference) -> Prepared:
        return self._call(self._queries.prepare_resume(intent))

    def prepare_control(self, intent: Reference, control: Control) -> Prepared:
        return self._call(self._queries.prepare_control(intent, control))

    def prepare_initialize(self, configuration: Configuration) -> Prepared:
        return self._call(self._queries.prepare_initialize(configuration))

    def prepare_policy(self, change: PolicyChange) -> Prepared:
        return self._call(self._queries.prepare_policy(change))

    def prepare_dependency(self, dependency: Dependency, present: bool) -> Prepared:
        return self._call(self._queries.prepare_dependency(dependency, present))

    def submit(self, prepared: Prepared) -> int:
        return self._call(self._queries.submit(prepared))

    def observe(self, prepared: Prepared, position: int, *, wait: bool=False) -> Observation:
        return self._call(self._queries.observe(prepared, position, wait=wait))

    def input_disposition(self, prepared: Prepared, position: int) -> Disposition | None:
        return self._call(self._queries.input_disposition(prepared, position))

    def progress(self, intent: Reference, prepared: Prepared, position: int, *, wait: bool=False) -> Progress:
        return self._call(self._queries.progress(intent, prepared, position, wait=wait))

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
    async def _call(self, request: _Request[T]) -> T:
        return await owned_await(self._owner._worker.submit(lambda: self._owner._invoke(request)))

    async def capabilities(self) -> Capabilities:
        return await self._call(self._owner._queries.capabilities())

    async def describe(self) -> Description:
        return await self._call(self._owner._queries.describe())

    async def lookup(self, name: str) -> Definition | None:
        return await self._call(self._owner._queries.lookup(name))

    async def definition(self, object_id: int, revision: int) -> HistoricalDefinition | None:
        return await self._call(self._owner._queries.definition(object_id, revision))

    async def list(self, cursor: Cursor | None=None) -> Page:
        return await self._call(self._owner._queries.list(cursor))

    async def compile_sql(self, sql: str, identity: Identity, create_object: int | None=None) -> Compiled:
        return await self._call(self._owner._queries.compile_sql(sql, identity, create_object))

    async def prepare(self, name: str, identity: Identity, action: Operation) -> Compiled:
        return await self._call(self._owner._queries.prepare(name, identity, action))

    async def load(self, saved: SavedIntent) -> Intent:
        return await self._call(self._owner._queries.load(saved))

    async def forget(self, intent: Reference) -> None:
        return await self._call(self._owner._queries.forget(intent))

    async def next(self, intent: Reference) -> Next:
        return await self._call(self._owner._queries.next(intent))

    async def status(self, intent: Reference) -> State:
        return await self._call(self._owner._queries.status(intent))

    async def prepare_resume(self, intent: Reference) -> Prepared:
        return await self._call(self._owner._queries.prepare_resume(intent))

    async def prepare_control(self, intent: Reference, control: Control) -> Prepared:
        return await self._call(self._owner._queries.prepare_control(intent, control))

    async def prepare_initialize(self, configuration: Configuration) -> Prepared:
        return await self._call(self._owner._queries.prepare_initialize(configuration))

    async def prepare_policy(self, change: PolicyChange) -> Prepared:
        return await self._call(self._owner._queries.prepare_policy(change))

    async def prepare_dependency(self, dependency: Dependency, present: bool) -> Prepared:
        return await self._call(self._owner._queries.prepare_dependency(dependency, present))

    async def submit(self, prepared: Prepared) -> int:
        return await self._call(self._owner._queries.submit(prepared))

    async def observe(self, prepared: Prepared, position: int, *, wait: bool=False) -> Observation:
        return await self._call(self._owner._queries.observe(prepared, position, wait=wait))

    async def input_disposition(self, prepared: Prepared, position: int) -> Disposition | None:
        return await self._call(self._owner._queries.input_disposition(prepared, position))

    async def progress(self, intent: Reference, prepared: Prepared, position: int, *, wait: bool=False) -> Progress:
        return await self._call(self._owner._queries.progress(intent, prepared, position, wait=wait))

    async def close(self) -> None: await self._owner._worker.aclose(self._owner._destroy)
    async def __aenter__(self) -> AsyncClient: return self
    async def __aexit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: await self.close()

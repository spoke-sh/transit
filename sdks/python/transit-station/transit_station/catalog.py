"""Direct Table lifecycle; Zig owns acceptance, current authority and execution."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass
from pathlib import Path
from types import TracebackType
from typing import Any, Callable, Generic, TypeAlias, TypeVar, cast
from transit_client._native import Library, encode, seed
from transit_client._worker import Worker, owned_await
from transit_client.errors import IncompatibleNative, UncertainOperation, UnsupportedCapability, native_error
from transit_client.types import integer, owned_bytes
from . import catalog_values as v
from .catalog_values import (
    HistoryOperation as HistoryOperation,
    HistoryDirectory as HistoryDirectory,
    HistoryCommonCut as HistoryCommonCut,
    HistoryBudget as HistoryBudget,
    HistorySelection as HistorySelection,
    HistoryKey as HistoryKey,
    HistorySelectionStep as HistorySelectionStep,
    HistoryIntent as HistoryIntent,
    HistoryAcquisition as HistoryAcquisition,
    HistoryControl as HistoryControl,
    HistoricalSnapshot as HistoricalSnapshot,
    HistoryBasis as HistoryBasis,
    HistoryStatus as HistoryStatus,
    HistoryNamespace as HistoryNamespace,
    HistoryEntry as HistoryEntry,
    HistoryCursor as HistoryCursor,
    HistoryPage as HistoryPage,
    HistorySource as HistorySource,
    Scope as Scope, Connection as Connection, TableLimits as TableLimits,
    Configuration as Configuration, AuthorityProfile as AuthorityProfile, Subject as Subject,
    CheckLiteral as CheckLiteral, CheckColumns as CheckColumns, CheckNull as CheckNull,
    CheckConstraint as CheckConstraint, ForeignKeyConstraint as ForeignKeyConstraint, TableIntegrity as TableIntegrity,
    Column as Column, Encoding as Encoding, Collation as Collation, Schema as Schema,
    ColumnSemantics as ColumnSemantics, TimezoneRules as TimezoneRules, SpatialSemantics as SpatialSemantics,
    Identity as Identity, Basis as Basis, Metadata as Metadata, ObjectIdentity as ObjectIdentity,
    Interpretation as Interpretation, StoredDefinition as StoredDefinition, Position as Position,
    Content as Content, Namespace as Namespace, Entry as Entry, Cursor as Cursor, Page as Page,
    Reference as Reference, SavedIntent as SavedIntent, Kind as Kind, Intent as Intent,
    Compiled as Compiled, Commit as Commit, Observation as Observation, Preview as Preview,
    CurrentBasis as CurrentBasis, Default as Default, Assignment as Assignment,
    BooleanOperator as BooleanOperator, CellState as CellState, CompareOperator as CompareOperator,
    StatePredicate as StatePredicate, Comparison as Comparison, Insert as Insert, Update as Update,
    Delete as Delete, AddColumn as AddColumn, DropColumn as DropColumn, RenameColumn as RenameColumn,
    SetDefault as SetDefault, SetNullable as SetNullable, SetType as SetType, SetPhysical as SetPhysical,
    SetIntegrity as SetIntegrity,
    Create as Create, Alter as Alter, Rename as Rename, Drop as Drop, Mutate as Mutate,
    Capabilities as Capabilities, Description as Description, Predicate as Predicate,
    Mutation as Mutation, Change as Change, Operation as Operation,
    SnapshotOwner as SnapshotOwner, SnapshotAcquisition as SnapshotAcquisition, Snapshot as Snapshot,
    ReadAuthority as ReadAuthority, SnapshotStatus as SnapshotStatus, SnapshotMetadata as SnapshotMetadata,
)

T = TypeVar('T')
Recovery: TypeAlias = SavedIntent | Reference | SnapshotAcquisition | Snapshot | HistorySelectionStep | HistoryAcquisition | HistoryControl


class Uncertain(UncertainOperation):
    """The original typed work remains available after any uncertain mutation."""
    def __init__(self, original: Recovery, cause: UncertainOperation) -> None:
        self.original = original
        super().__init__(recovery=original.save().encode(), code=cause.code, phase=cause.phase,
                         diagnostic=cause.diagnostic, diagnostic_invalid=cause.diagnostic_invalid)


@dataclass(frozen=True)
class _Request(Generic[T]):
    data: bytes
    fields: tuple[str, ...]
    decode: Callable[[Any], T]
    recovery: Recovery | None = None


def _request(action: object, fields: str, decoder: Callable[[Any], T], recovery: Recovery | None = None) -> _Request[T]:
    return _Request(owned_bytes(encode(action), v.LIMITS['catalog_action_bytes']), tuple(fields.split()), decoder, recovery)


def _empty(value: object) -> None: v._object(value, '')


class _Queries:
    def __init__(self, connection: Connection, principal: int) -> None:
        self.connection, self.principal = connection, principal

    def capabilities(self) -> _Request[Capabilities]:
        return _request({'catalog': {'capabilities': {}}}, 'catalog capabilities', v._capabilities)

    def describe(self) -> _Request[Description]:
        return _request({'catalog': {'describe': {}}}, 'catalog description', lambda value: v._description(value, self.connection, self.principal))

    def namespace(self, identity: int) -> _Request[Namespace | None]:
        integer(identity, 'namespace')
        def decode(value: object) -> Namespace | None:
            if value is None: return None
            result = v._namespace(value)
            if result.id != identity or result.scope != self.connection.scope: raise ValueError('Foreign namespace')
            return result
        return _request({'catalog': {'namespace': identity}}, 'catalog namespace', decode)

    def namespaces(self, cursor: Cursor | None = None) -> _Request[Page[Namespace]]:
        after = None if cursor is None else cursor._check(self.connection, self.principal, {'namespaces': {}})
        return _request({'catalog': {'namespaces': after}}, 'catalog namespaces',
                        lambda value: cast(Page[Namespace], v._page(value, self.connection, self.principal, None, cursor)))

    def tables(self, namespace: int = 1, cursor: Cursor | None = None) -> _Request[Page[Entry]]:
        integer(namespace, 'namespace')
        after = None if cursor is None else cursor._check(self.connection, self.principal, {'tables': namespace})
        return _request({'catalog': {'tables': dict(namespace=namespace, cursor=after)}}, 'catalog tables',
                        lambda value: cast(Page[Entry], v._page(value, self.connection, self.principal, namespace, cursor)))

    def lookup(self, name: str, namespace: int = 1) -> _Request[Metadata | None]:
        v._name(name); integer(namespace, 'namespace')
        def decode(value: object) -> Metadata | None:
            if value is None: return None
            result = v._metadata(value)
            if (result.basis.connection != self.connection or result.basis.principal != self.principal or
                result.basis.namespace != namespace or result.basis.name != name): raise ValueError('Changed requested Table')
            return result
        return _request({'lookup': dict(namespace=namespace, name=name)}, 'metadata', decode)

    def compile_sql(self, sql: str, identity: Identity, create_object: int | None = None, *, dialect: str = 'transit', ingestion: str = 'point') -> _Request[Compiled]:
        if not isinstance(identity, Identity): raise TypeError('Expected operation identity')
        return _request({'compile': dict(sql=v._text(sql, 4096), namespace=identity.namespace, operation=str(identity.operation),
                                        create_object=None if create_object is None else str(v._wide(create_object)),
                                        dialect=v._one_of(dialect, ('transit', 'mysql')), ingestion=v._one_of(ingestion, ('point', 'bulk')))}, 'compiled',
                        lambda value: v._compiled(value, self.connection, self.principal, identity))

    def prepare(self, name: str, identity: Identity, action: Operation) -> _Request[Compiled]:
        if not isinstance(identity, Identity): raise TypeError('Expected operation identity')
        return _request({'prepare': dict(definition=v.DEFINITION, namespace=identity.namespace, operation=str(identity.operation), name=v._name(name), action=v._operation(action))}, 'compiled',
                        lambda value: v._compiled(value, self.connection, self.principal, identity))

    def load(self, saved: SavedIntent) -> _Request[Intent]:
        return _request({'load': saved._wire()}, 'loaded', lambda value: v._summary(value, saved, self.connection, self.principal))

    def forget(self, intent: Intent) -> _Request[None]:
        return _request({'forget': intent._id()}, 'forgotten', _empty)

    def preview(self, intent: Intent) -> _Request[Preview]:
        return _request({'preview': intent._id()}, 'preview', lambda value: v._preview(value, intent))

    def stage(self, intent: Intent) -> _Request[Reference]:
        def decode(value: object) -> Reference:
            result = Reference.restore(encode(value).decode())
            tag, reference = v._variant(result._wire())
            if (tag != intent.kind or result._binding() != intent._binding() or
                reference['connection'] != self.connection._wire(self.principal) or reference['namespace'] != intent.namespace): raise ValueError('Changed staged work')
            return result
        return _request({'stage': intent._id()}, 'staged', decode, intent.saved)

    def _reference(self, original: Reference) -> object:
        _, value = v._variant(original._wire())
        if value['connection'] != self.connection._wire(self.principal): raise ValueError('Foreign recovery connection')
        return original._wire()

    def admit(self, original: Reference) -> _Request[Observation]:
        return _request({'admit': self._reference(original)}, 'observation', lambda value: v._observation(value, original), original)

    def inspect(self, original: Reference) -> _Request[Observation]:
        return _request({'operation': dict(reference=self._reference(original), command='inspect', steps=1)}, 'observation', lambda value: v._observation(value, original))

    def execute(self, original: Reference, steps: int) -> _Request[Observation]:
        return _request({'operation': dict(reference=self._reference(original), command='execute', steps=integer(steps, 'steps', maximum=65535))},
                        'observation', lambda value: v._observation(value, original), original)

    def cancel(self, original: Reference) -> _Request[Observation]:
        return _request({'operation': dict(reference=self._reference(original), command='cancel', steps=1)}, 'observation', lambda value: v._observation(value, original), original)

    def prepare_history_selection(self, operation: int) -> HistorySelection:
        return HistorySelection.restore(encode(dict(definition=v.DEFINITION, owner=dict(scope=self.connection.scope._wire(), principal=self.principal, operation=str(v._wide(operation))), branch=str(self.connection.branch), directory=None)).decode())

    def prepare_history_key(self, account: bytes, token: bytes) -> HistoryKey:
        account = owned_bytes(account, 32); token = owned_bytes(token, 16)
        if len(account) != 32 or len(token) != 16: raise ValueError('Expected 32-byte account and 16-byte token')
        return HistoryKey.restore(encode(dict(definition=v.DEFINITION, connection=self.connection._wire(self.principal), account=account.hex(), token=token.hex())).decode())

    def prepare_history_step(self, selection: HistorySelection, namespace: int, name: str) -> HistorySelectionStep:
        return HistorySelectionStep.restore(encode(dict(selection=selection._wire(), namespace=integer(namespace, 'namespace'), name=v._name(name))).decode())

    def _history_selection(self, selection: HistorySelection) -> None:
        owner = selection.owner
        if owner.scope != self.connection.scope or owner.principal != self.principal or selection.branch != self.connection.branch: raise ValueError('Foreign history selection')

    def select_history(self, original: HistorySelectionStep) -> _Request[HistorySelection]:
        self._history_selection(original.selection)
        def decode(value: object) -> HistorySelection:
            result = HistorySelection.restore(encode(value).decode())
            if result.owner != original.selection.owner or result.branch != original.selection.branch or result.directory is None: raise ValueError('Changed history selection owner')
            return result
        return _request({'history': {'select': original._wire()}}, 'history selection', decode, original)

    def prepare_history_acquisition(self, selection: HistorySelection, key: HistoryKey, namespace: int = 1, budget: HistoryBudget = HistoryBudget()) -> HistoryAcquisition:
        self._history_selection(selection)
        if selection.directory is None: raise ValueError('Expected a selected history directory')
        return HistoryAcquisition.restore(encode(dict(key=key._check(self.connection, self.principal), intent=dict(definition=v.DEFINITION, connection=self.connection._wire(self.principal), namespace=integer(namespace, 'namespace'), operation=str(selection.owner.operation), selection=selection.directory._wire(), common=None), budget=budget._wire())).decode())

    def prepare_common_history_acquisition(self, key: HistoryKey, operation: int, namespace: int, selection: HistoryDirectory, transaction: HistoryKey, cut: HistoryCommonCut, budget: HistoryBudget = HistoryBudget()) -> HistoryAcquisition:
        return HistoryAcquisition.restore(encode(dict(key=key._check(self.connection, self.principal), intent=dict(definition=v.DEFINITION, connection=self.connection._wire(self.principal), namespace=integer(namespace, 'namespace'), operation=str(v._wide(operation)), selection=selection._wire(), common=dict(key=transaction._check(self.connection, self.principal), cut=cut._wire())), budget=budget._wire())).decode())

    def acquire_history(self, original: HistoryAcquisition) -> _Request[HistoryStatus]:
        original.key._check(self.connection, self.principal)
        def decode(value: object) -> HistoryStatus:
            result = v._history_status(value, original.key, original)
            if result is None: raise ValueError('Missing history admission')
            return result
        return _request({'history': {'acquire': original._wire()}}, 'history status', decode, original)

    def inspect_history(self, key: HistoryKey) -> _Request[HistoryStatus | None]:
        return _request({'history': {'inspect': key._check(self.connection, self.principal)}}, 'history status', lambda value: v._history_status(value, key))

    def prepare_history_control(self, key: HistoryKey, command: str) -> HistoryControl:
        return HistoryControl.restore(encode({command: key._check(self.connection, self.principal)}).decode())

    def resume_history_control(self, original: HistoryControl) -> _Request[HistoryStatus | None]:
        original.key._check(self.connection, self.principal)
        return _request({'history': original._wire()}, 'history status', lambda value: v._history_status(value, original.key), original)

    def _history_control(self, command: str, key: HistoryKey) -> _Request[HistoryStatus | None]:
        return self.resume_history_control(HistoryControl.restore(encode({command: key._wire()}).decode()))

    def advance_history(self, key: HistoryKey) -> _Request[HistoryStatus | None]: return self._history_control('advance', key)
    def abandon_history(self, key: HistoryKey) -> _Request[HistoryStatus | None]: return self._history_control('abandon', key)
    def release_history(self, key: HistoryKey) -> _Request[HistoryStatus | None]: return self._history_control('release', key)

    def historical_lookup(self, snapshot: HistoricalSnapshot, namespace: int, name: str) -> _Request[int | None]:
        return _request({'history': {'lookup': dict(selector=snapshot.selector, namespace=integer(namespace, 'namespace'), name=v._name(name))}}, 'history object', lambda value: None if value is None else v._decimal(value))

    def historical_namespace(self, snapshot: HistoricalSnapshot, name: str) -> _Request[HistoryNamespace | None]:
        def decode(value: object) -> HistoryNamespace | None:
            if value is None: return None
            result = v._history_namespace(value)
            if result.name != name or result.scope != self.connection.scope: raise ValueError('Changed historical namespace')
            return result
        return _request({'history': {'namespace': dict(selector=snapshot.selector, name=v._name(name))}}, 'history namespace', decode)

    def historical_tables(self, snapshot: HistoricalSnapshot, namespace: int, cursor: HistoryCursor | None = None) -> _Request[HistoryPage]:
        integer(namespace, 'namespace')
        return _request({'history': {'list': dict(selector=snapshot.selector, namespace=namespace, after=None if cursor is None else cursor._check(snapshot, namespace))}}, 'history listing', lambda value: v._history_page(value, snapshot, self.connection.scope, namespace, cursor))

    def historical_source(self, snapshot: HistoricalSnapshot, object_id: int) -> _Request[HistorySource]:
        return _request({'history': {'source': dict(selector=snapshot.selector, object=str(v._wide(object_id)))}}, 'history source', lambda value: v._history_source(value, snapshot, object_id))

    def prepare_snapshot(self, basis: Basis, position: Position, operation: int) -> SnapshotAcquisition:
        if basis.connection != self.connection or basis.principal != self.principal: raise ValueError('Foreign Table basis')
        return SnapshotAcquisition.restore(encode(dict(owner=dict(definition=v.DEFINITION, connection=self.connection._wire(self.principal),
                                                                 object=basis.interpretation.interpretation.object._wire(), operation=str(v._wide(operation))),
                                                       expected=position._wire())).decode())

    def acquire_snapshot(self, acquisition: SnapshotAcquisition) -> _Request[Snapshot]:
        acquisition.owner._check(self.connection, self.principal)
        def decode(value: object) -> Snapshot:
            result = Snapshot.restore(encode(value).decode())
            if result.owner._wire() != acquisition.owner._wire(): raise ValueError('Changed snapshot acquisition')
            return result
        return _request({'retention': {'acquire': acquisition._wire()}}, 'retention acquired', decode, acquisition)

    def snapshot_status(self, owner: SnapshotOwner) -> _Request[SnapshotStatus]:
        owner._check(self.connection, self.principal)
        return _request({'retention': {'status': owner._wire()}}, 'retention status', lambda value: v._snapshot_status(value, owner))

    def snapshot_metadata(self, original: Snapshot) -> _Request[SnapshotMetadata]:
        original.owner._check(self.connection, self.principal)
        return _request({'retention': {'metadata': original._wire()}}, 'retention metadata', lambda value: v._snapshot_metadata(value, original))

    def release_snapshot(self, original: Snapshot) -> _Request[None]:
        original.owner._check(self.connection, self.principal)
        def decode(value: object) -> None:
            if value != original._wire(): raise ValueError('Changed snapshot release')
        return _request({'retention': {'release': original._wire()}}, 'retention released', decode, original)


class Client:
    """One owned worker and one local intent; no implicit retries or settlement."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None, service_url: str | None = None) -> None:
        if not isinstance(connection, Connection): raise TypeError('Expected catalog connection')
        self._queries = _Queries(connection, integer(principal, 'principal', minimum=0))
        endpoint = v._text(url, 2048).encode()
        config = encode(dict(definition=v.DEFINITION, connection=connection._wire(principal), timeout_ms=integer(timeout_ms, 'timeout', maximum=60000),
                             service_url=None if service_url is None else v._text(service_url, 2048)))
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._handle = c.c_void_p()
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        def create() -> None:
            key = seed(seed_file)
            try:
                status = self._api.lib.station_catalog_create(1, endpoint, len(endpoint), key, config, len(config), c.byref(self._handle))
                if status: raise native_error(status, phase='open_catalog')
            finally: c.memset(key, 0, 32)
        try:
            self._worker.call(create)
            caps = self.capabilities()
            if (caps.version != 1 or caps.definition != v.DEFINITION or caps.max_columns != 128 or caps.max_rows != 1024 or caps.max_sql_bytes != 4096 or
                caps.max_intent_bytes != v.LIMITS['catalog_intent_bytes'] or caps.max_action_bytes != v.LIMITS['catalog_action_bytes'] or
                caps.metadata_page_entries != 8 or caps.resident_intents != 1): raise UnsupportedCapability('Native catalog lacks the direct Table profile')
        except BaseException:
            self.close()
            raise

    @property
    def connection(self) -> Connection: return self._queries.connection

    def _invoke(self, request: _Request[T]) -> T:
        try:
            value = self._api.call('station_catalog_call', self._handle, request.data, len(request.data),
                                   recovery=b'' if request.recovery is None else request.recovery.save().encode())
            for field in request.fields: value = v._object(value, field)[field]
            return request.decode(value)
        except UncertainOperation as cause:
            if request.recovery is not None: raise Uncertain(request.recovery, cause) from cause
            raise
        except (ValueError, TypeError, KeyError, AttributeError, OverflowError, RecursionError, MemoryError) as cause:
            if request.recovery is not None:
                raise Uncertain(request.recovery, UncertainOperation(recovery=b'', phase='catalog_response')) from cause
            raise IncompatibleNative('Invalid direct catalog response') from cause

    def _call(self, request: _Request[T]) -> T:
        return self._worker.call(lambda: self._invoke(request))

    def prepare_history_control(self, key: HistoryKey, command: str) -> HistoryControl:
        return self._queries.prepare_history_control(key, command)

    def prepare_history_selection(self, operation: int) -> HistorySelection:
        return self._queries.prepare_history_selection(operation)

    def prepare_history_key(self, account: bytes, token: bytes) -> HistoryKey:
        return self._queries.prepare_history_key(account, token)

    def prepare_history_step(self, selection: HistorySelection, namespace: int, name: str) -> HistorySelectionStep:
        return self._queries.prepare_history_step(selection, namespace, name)

    def prepare_history_acquisition(self, selection: HistorySelection, key: HistoryKey, namespace: int = 1, budget: HistoryBudget = HistoryBudget()) -> HistoryAcquisition:
        return self._queries.prepare_history_acquisition(selection, key, namespace, budget)

    def prepare_common_history_acquisition(self, key: HistoryKey, operation: int, namespace: int, selection: HistoryDirectory, transaction: HistoryKey, cut: HistoryCommonCut, budget: HistoryBudget = HistoryBudget()) -> HistoryAcquisition:
        return self._queries.prepare_common_history_acquisition(key, operation, namespace, selection, transaction, cut, budget)

    def select_history(self, original: HistorySelectionStep) -> HistorySelection:
        return self._call(self._queries.select_history(original))

    def acquire_history(self, original: HistoryAcquisition) -> HistoryStatus:
        return self._call(self._queries.acquire_history(original))

    def inspect_history(self, key: HistoryKey) -> HistoryStatus | None:
        return self._call(self._queries.inspect_history(key))

    def advance_history(self, key: HistoryKey) -> HistoryStatus | None:
        return self._call(self._queries.advance_history(key))

    def abandon_history(self, key: HistoryKey) -> HistoryStatus | None:
        return self._call(self._queries.abandon_history(key))

    def release_history(self, key: HistoryKey) -> HistoryStatus | None:
        return self._call(self._queries.release_history(key))

    def resume_history_control(self, original: HistoryControl) -> HistoryStatus | None:
        return self._call(self._queries.resume_history_control(original))

    def historical_lookup(self, snapshot: HistoricalSnapshot, namespace: int, name: str) -> int | None:
        return self._call(self._queries.historical_lookup(snapshot, namespace, name))

    def historical_namespace(self, snapshot: HistoricalSnapshot, name: str) -> HistoryNamespace | None:
        return self._call(self._queries.historical_namespace(snapshot, name))

    def historical_tables(self, snapshot: HistoricalSnapshot, namespace: int, cursor: HistoryCursor | None = None) -> HistoryPage:
        return self._call(self._queries.historical_tables(snapshot, namespace, cursor))

    def historical_source(self, snapshot: HistoricalSnapshot, object_id: int) -> HistorySource:
        return self._call(self._queries.historical_source(snapshot, object_id))

    def prepare_snapshot(self, basis: Basis, position: Position, operation: int) -> SnapshotAcquisition:
        return self._queries.prepare_snapshot(basis, position, operation)

    def capabilities(self) -> Capabilities:
        return self._call(self._queries.capabilities())

    def describe(self) -> Description:
        return self._call(self._queries.describe())

    def namespace(self, identity: int) -> Namespace | None:
        return self._call(self._queries.namespace(identity))

    def namespaces(self, cursor: Cursor | None = None) -> Page[Namespace]:
        return self._call(self._queries.namespaces(cursor))

    def tables(self, namespace: int = 1, cursor: Cursor | None = None) -> Page[Entry]:
        return self._call(self._queries.tables(namespace, cursor))

    def lookup(self, name: str, namespace: int = 1) -> Metadata | None:
        return self._call(self._queries.lookup(name, namespace))

    def compile_sql(self, sql: str, identity: Identity, create_object: int | None = None, *, dialect: str = 'transit', ingestion: str = 'point') -> Compiled:
        return self._call(self._queries.compile_sql(sql, identity, create_object, dialect=dialect, ingestion=ingestion))

    def prepare(self, name: str, identity: Identity, action: Operation) -> Compiled:
        return self._call(self._queries.prepare(name, identity, action))

    def load(self, saved: SavedIntent) -> Intent:
        return self._call(self._queries.load(saved))

    def forget(self, intent: Intent) -> None:
        return self._call(self._queries.forget(intent))

    def preview(self, intent: Intent) -> Preview:
        return self._call(self._queries.preview(intent))

    def stage(self, intent: Intent) -> Reference:
        return self._call(self._queries.stage(intent))

    def admit(self, original: Reference) -> Observation:
        return self._call(self._queries.admit(original))

    def inspect(self, original: Reference) -> Observation:
        return self._call(self._queries.inspect(original))

    def execute(self, original: Reference, steps: int) -> Observation:
        return self._call(self._queries.execute(original, steps))

    def cancel(self, original: Reference) -> Observation:
        return self._call(self._queries.cancel(original))

    def acquire_snapshot(self, acquisition: SnapshotAcquisition) -> Snapshot:
        return self._call(self._queries.acquire_snapshot(acquisition))

    def snapshot_status(self, owner: SnapshotOwner) -> SnapshotStatus:
        return self._call(self._queries.snapshot_status(owner))

    def snapshot_metadata(self, original: Snapshot) -> SnapshotMetadata:
        return self._call(self._queries.snapshot_metadata(original))

    def release_snapshot(self, original: Snapshot) -> None:
        return self._call(self._queries.release_snapshot(original))

    def _destroy(self) -> None:
        self._api.lib.station_catalog_destroy(self._handle)
        self._handle = c.c_void_p()
    def close(self) -> None: self._worker.close(self._destroy)
    def __enter__(self) -> Client: return self
    def __exit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: self.close()


class AsyncClient:
    """Await cancellation leaves native work owned; closing joins its worker."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None, service_url: str | None = None) -> None:
        self._owner = Client(url, principal, seed_file, connection, timeout_ms=timeout_ms, native_directory=native_directory, service_url=service_url)
    @property
    def connection(self) -> Connection: return self._owner.connection
    async def _call(self, request: _Request[T]) -> T:
        return await owned_await(self._owner._worker.submit(lambda: self._owner._invoke(request)))
    def prepare_history_control(self, key: HistoryKey, command: str) -> HistoryControl:
        return self._owner._queries.prepare_history_control(key, command)

    def prepare_history_selection(self, operation: int) -> HistorySelection:
        return self._owner._queries.prepare_history_selection(operation)

    def prepare_history_key(self, account: bytes, token: bytes) -> HistoryKey:
        return self._owner._queries.prepare_history_key(account, token)

    def prepare_history_step(self, selection: HistorySelection, namespace: int, name: str) -> HistorySelectionStep:
        return self._owner._queries.prepare_history_step(selection, namespace, name)

    def prepare_history_acquisition(self, selection: HistorySelection, key: HistoryKey, namespace: int = 1, budget: HistoryBudget = HistoryBudget()) -> HistoryAcquisition:
        return self._owner._queries.prepare_history_acquisition(selection, key, namespace, budget)

    def prepare_common_history_acquisition(self, key: HistoryKey, operation: int, namespace: int, selection: HistoryDirectory, transaction: HistoryKey, cut: HistoryCommonCut, budget: HistoryBudget = HistoryBudget()) -> HistoryAcquisition:
        return self._owner._queries.prepare_common_history_acquisition(key, operation, namespace, selection, transaction, cut, budget)

    async def select_history(self, original: HistorySelectionStep) -> HistorySelection:
        return await self._call(self._owner._queries.select_history(original))

    async def acquire_history(self, original: HistoryAcquisition) -> HistoryStatus:
        return await self._call(self._owner._queries.acquire_history(original))

    async def inspect_history(self, key: HistoryKey) -> HistoryStatus | None:
        return await self._call(self._owner._queries.inspect_history(key))

    async def advance_history(self, key: HistoryKey) -> HistoryStatus | None:
        return await self._call(self._owner._queries.advance_history(key))

    async def abandon_history(self, key: HistoryKey) -> HistoryStatus | None:
        return await self._call(self._owner._queries.abandon_history(key))

    async def release_history(self, key: HistoryKey) -> HistoryStatus | None:
        return await self._call(self._owner._queries.release_history(key))

    async def resume_history_control(self, original: HistoryControl) -> HistoryStatus | None:
        return await self._call(self._owner._queries.resume_history_control(original))

    async def historical_lookup(self, snapshot: HistoricalSnapshot, namespace: int, name: str) -> int | None:
        return await self._call(self._owner._queries.historical_lookup(snapshot, namespace, name))

    async def historical_namespace(self, snapshot: HistoricalSnapshot, name: str) -> HistoryNamespace | None:
        return await self._call(self._owner._queries.historical_namespace(snapshot, name))

    async def historical_tables(self, snapshot: HistoricalSnapshot, namespace: int, cursor: HistoryCursor | None = None) -> HistoryPage:
        return await self._call(self._owner._queries.historical_tables(snapshot, namespace, cursor))

    async def historical_source(self, snapshot: HistoricalSnapshot, object_id: int) -> HistorySource:
        return await self._call(self._owner._queries.historical_source(snapshot, object_id))

    def prepare_snapshot(self, basis: Basis, position: Position, operation: int) -> SnapshotAcquisition:
        return self._owner.prepare_snapshot(basis, position, operation)
    async def capabilities(self) -> Capabilities:
        return await self._call(self._owner._queries.capabilities())

    async def describe(self) -> Description:
        return await self._call(self._owner._queries.describe())

    async def namespace(self, identity: int) -> Namespace | None:
        return await self._call(self._owner._queries.namespace(identity))

    async def namespaces(self, cursor: Cursor | None = None) -> Page[Namespace]:
        return await self._call(self._owner._queries.namespaces(cursor))

    async def tables(self, namespace: int = 1, cursor: Cursor | None = None) -> Page[Entry]:
        return await self._call(self._owner._queries.tables(namespace, cursor))

    async def lookup(self, name: str, namespace: int = 1) -> Metadata | None:
        return await self._call(self._owner._queries.lookup(name, namespace))

    async def compile_sql(self, sql: str, identity: Identity, create_object: int | None = None, *, dialect: str = 'transit', ingestion: str = 'point') -> Compiled:
        return await self._call(self._owner._queries.compile_sql(sql, identity, create_object, dialect=dialect, ingestion=ingestion))

    async def prepare(self, name: str, identity: Identity, action: Operation) -> Compiled:
        return await self._call(self._owner._queries.prepare(name, identity, action))

    async def load(self, saved: SavedIntent) -> Intent:
        return await self._call(self._owner._queries.load(saved))

    async def forget(self, intent: Intent) -> None:
        return await self._call(self._owner._queries.forget(intent))

    async def preview(self, intent: Intent) -> Preview:
        return await self._call(self._owner._queries.preview(intent))

    async def stage(self, intent: Intent) -> Reference:
        return await self._call(self._owner._queries.stage(intent))

    async def admit(self, original: Reference) -> Observation:
        return await self._call(self._owner._queries.admit(original))

    async def inspect(self, original: Reference) -> Observation:
        return await self._call(self._owner._queries.inspect(original))

    async def execute(self, original: Reference, steps: int) -> Observation:
        return await self._call(self._owner._queries.execute(original, steps))

    async def cancel(self, original: Reference) -> Observation:
        return await self._call(self._owner._queries.cancel(original))

    async def acquire_snapshot(self, acquisition: SnapshotAcquisition) -> Snapshot:
        return await self._call(self._owner._queries.acquire_snapshot(acquisition))

    async def snapshot_status(self, owner: SnapshotOwner) -> SnapshotStatus:
        return await self._call(self._owner._queries.snapshot_status(owner))

    async def snapshot_metadata(self, original: Snapshot) -> SnapshotMetadata:
        return await self._call(self._owner._queries.snapshot_metadata(original))

    async def release_snapshot(self, original: Snapshot) -> None:
        return await self._call(self._owner._queries.release_snapshot(original))

    async def close(self) -> None: await self._owner._worker.aclose(self._owner._destroy)
    async def __aenter__(self) -> AsyncClient: return self
    async def __aexit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: await self.close()

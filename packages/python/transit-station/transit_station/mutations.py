"""Typed mutation callers; shared Zig owns policy, staging, signing and recovery."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass, field
from enum import Enum, IntFlag
from pathlib import Path
from types import TracebackType
from typing import Any

from transit_client import ProcessRef, ResourceRef
from transit_client._native import Library, encode, seed
from transit_client._worker import Worker, owned_await
from transit_client.errors import IncompatibleNative, UnsupportedCapability, native_error
from transit_client.types import integer, owned_bytes
from .turn import CellType


@dataclass(frozen=True, slots=True)
class Connection:
    writer: ProcessRef
    resource: ResourceRef
    table: int
    def __post_init__(self) -> None:
        if self.writer.realm != self.resource.realm: raise ValueError('Mutation connection must use one realm')
        integer(self.table, 'table', maximum=(1 << 32)-1)
    def _wire(self, principal: int) -> object:
        return dict(realm=self.writer.realm, principal=integer(principal, 'principal'), writer=self.writer.pid,
                    resource=self.resource.resource, table=self.table)


@dataclass(frozen=True, slots=True)
class Reference:
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        object.__setattr__(self, 'data', owned_bytes(self.data, 72))
        if len(self.data) != 72: raise ValueError('Mutation reference requires 72 bytes')


@dataclass(frozen=True, slots=True)
class Compiled:
    """Persist both fields unchanged before preparing upload commands."""
    request: bytes = field(repr=False)
    reference: Reference
    def __post_init__(self) -> None:
        object.__setattr__(self, 'request', owned_bytes(self.request, 799))
        if not self.request or not isinstance(self.reference, Reference): raise ValueError('Invalid compiled mutation')
    def _wire(self) -> object: return dict(request=self.request.hex(), reference=self.reference.data.hex())


@dataclass(frozen=True, slots=True)
class Prepared:
    """Opaque exact recovery bytes; never parse, re-encode or replace after timeout."""
    data: bytes = field(repr=False)
    def __post_init__(self) -> None:
        object.__setattr__(self, 'data', owned_bytes(self.data, 8192))
        if not self.data: raise ValueError('Empty saved mutation command')
        self.data.decode('utf-8', errors='strict')


class Permissions(IntFlag):
    INSERT = 1
    UPDATE = 2
    DELETE = 4


class Phase(Enum):
    UPLOADING = 'uploading'
    SEALED = 'sealed'
    APPLIED = 'applied'
    REJECTED = 'rejected'
    CANCELLED = 'cancelled'


class Reason(Enum):
    NONE = 'none'
    ROW_EXISTS = 'row_exists'
    SOURCE_CHANGED = 'source_changed'
    INVALID_REQUEST = 'invalid_request'
    DENIED = 'denied'
    BUDGET = 'budget'


class Observation(Enum):
    PENDING = 'pending'
    PROCESSED = 'processed'


class Rejection(Enum):
    INVALID_COMMAND = 'invalid_command'
    DENIED = 'denied'
    IDENTITY_CONFLICT = 'identity_conflict'
    BUSY = 'busy'
    NOT_FOUND = 'not_found'
    NOT_ACTIVE = 'not_active'
    UPLOAD_CLOSED = 'upload_closed'
    NOT_SEALED = 'not_sealed'
    INVALID_PART = 'invalid_part'
    INCOMPLETE_UPLOAD = 'incomplete_upload'
    SOURCE_CHANGED = 'source_changed'
    STALE_POLICY = 'stale_policy'


@dataclass(frozen=True, slots=True)
class Description:
    resource: ResourceRef
    table: int
    names: tuple[str, str]
    value_type: CellType
    resource_revision: int
    policy_revision: int
    declaration: bytes
    permissions: Permissions
    active: int | None


@dataclass(frozen=True, slots=True)
class Status:
    reference: Reference
    principal: int
    table: int
    declaration: bytes
    policy_revision: int
    phase: Phase
    affected_rows: int
    reason: Reason
    input: int


def _wide(value: int, name: str) -> int:
    return integer(value, name, maximum=(1 << 64)-1)


def _digest(value: str) -> bytes:
    result = owned_bytes(bytes.fromhex(value), 32)
    if len(result) != 32: raise IncompatibleNative('Invalid mutation declaration digest')
    return result


def _description(value: dict[str, Any], realm: int) -> Description:
    names = value['names']
    if len(names) != 2 or any(not isinstance(name, str) for name in names):
        raise IncompatibleNative('Invalid Table column names')
    return Description(ResourceRef(realm, value['resource']), integer(value['table'], 'table', maximum=(1 << 32)-1),
                       (names[0], names[1]), CellType(value['value_type']), integer(value['resource_revision'], 'revision', minimum=0),
                       integer(int(value['policy_revision']), 'policy revision'), _digest(value['declaration']),
                       Permissions(integer(value['permissions'], 'permissions', minimum=0, maximum=7)),
                       None if value['active'] is None else _wide(int(value['active']), 'namespace'))


def _status(value: dict[str, Any] | None) -> Status | None:
    if value is None: return None
    return Status(Reference(bytes.fromhex(value['reference'])), integer(value['principal'], 'principal'),
                  integer(value['table'], 'table', maximum=(1 << 32)-1), _digest(value['declaration']),
                  integer(int(value['policy_revision']), 'policy revision'), Phase(value['phase']),
                  integer(value['affected_rows'], 'affected rows', minimum=0, maximum=3), Reason(value['reason']),
                  integer(value['input'], 'input', minimum=0))


def _compiled(value: dict[str, Any]) -> Compiled:
    return Compiled(bytes.fromhex(value['request']), Reference(bytes.fromhex(value['reference'])))


def _prepared(value: str | None) -> Prepared | None:
    return None if value is None else Prepared(value.encode())


def _compile(name: str, sql: str, namespace: int) -> object:
    if not isinstance(name, str) or not isinstance(sql, str): raise TypeError('Expected SQL and Table name strings')
    owned_bytes(name.encode(), 16)
    owned_bytes(sql.encode(), 4096)
    return {'compile':dict(name=name, sql=sql, namespace=str(_wide(namespace, 'namespace')))}


def _control(kind: str, reference: Reference) -> object:
    return {'prepare':{kind:reference.data.hex()}}


def _input(kind: str, prepared: Prepared, position: int) -> object:
    return {kind:dict(prepared=prepared.data.decode(), input=integer(position, 'position'))}


class Client:
    """One bounded native worker; no activation, implicit retry or upload loop."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        self._connection = connection
        self._api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        self._handle = c.c_void_p()
        def create() -> None:
            endpoint, key = url.encode(), seed(seed_file)
            try:
                config = encode(dict(connection=connection._wire(principal),timeout_ms=integer(timeout_ms, 'timeout', maximum=60000)))
                status = self._api.lib.station_table_mutation_create(1,endpoint,len(endpoint),key,config,len(config),c.byref(self._handle))
                if status: raise native_error(status, phase='open_mutation')
            finally: c.memset(key, 0, 32)
        try:
            self._worker.call(create)
            caps = self._call({'capabilities':{}})['capabilities']
            if caps['version'] != 1 or caps['max_rows'] != 3 or caps['max_request_bytes'] != 799 or caps['max_saved_bytes'] != 8192 or not all(caps[name] for name in ('insert','update_primary_key','delete_primary_key')):
                raise UnsupportedCapability('Native mutation client lacks the bounded Table profile')
        except BaseException:
            self.close()
            raise

    @property
    def connection(self) -> Connection: return self._connection

    def _invoke(self, action: object, recovery: bytes = b'') -> dict[str, Any]:
        data = encode(action)
        result: dict[str, Any] = self._api.call('station_table_mutation_call',self._handle,data,len(data),recovery=recovery)
        return result

    def _call(self, action: object, recovery: bytes = b'') -> dict[str, Any]:
        return self._worker.call(lambda: self._invoke(action,recovery))

    def describe(self) -> Description:
        return _description(self._call({'describe':{}})['description'],self.connection.writer.realm)

    def compile_sql(self, name: str, sql: str, namespace: int) -> Compiled:
        return _compiled(self._call(_compile(name,sql,namespace))['compiled'])

    def prepare_next(self, compiled: Compiled) -> Prepared | None:
        return _prepared(self._call({'next':compiled._wire()})['prepared'])

    def _control(self, kind: str, reference: Reference) -> Prepared:
        result = _prepared(self._call(_control(kind,reference))['prepared'])
        if result is None: raise IncompatibleNative('Missing prepared mutation control')
        return result

    def prepare_apply(self, reference: Reference) -> Prepared: return self._control('apply',reference)
    def prepare_cancel(self, reference: Reference) -> Prepared: return self._control('cancel',reference)

    def submit(self, prepared: Prepared) -> int:
        return integer(self._call({'submit':prepared.data.decode()},prepared.data)['receipt']['position'], 'position')

    def observe(self, prepared: Prepared, position: int) -> Observation:
        return Observation(self._call(_input('observe',prepared,position))['observation'])

    def rejection(self, prepared: Prepared, position: int) -> Rejection | None:
        value = self._call(_input('rejection',prepared,position))['rejection']
        return None if value is None else Rejection(value)

    def status(self, reference: Reference) -> Status | None:
        return _status(self._call({'status':reference.data.hex()})['status'])

    def _destroy(self) -> None:
        self._api.lib.station_table_mutation_destroy(self._handle)
        self._handle = c.c_void_p()

    def close(self) -> None: self._worker.close(self._destroy)
    def __enter__(self) -> Client: return self
    def __exit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: self.close()


class AsyncClient:
    """Cancellation of an await leaves its native operation owned until completion."""
    def __init__(self, url: str, principal: int, seed_file: Path, connection: Connection, *,
                 timeout_ms: int = 5000, native_directory: Path | None = None) -> None:
        self._owner = Client(url,principal,seed_file,connection,timeout_ms=timeout_ms,native_directory=native_directory)
        self._connection = connection

    @property
    def connection(self) -> Connection: return self._connection

    async def _call(self, action: object, recovery: bytes = b'') -> dict[str, Any]:
        return await owned_await(self._owner._worker.submit(lambda: self._owner._invoke(action,recovery)))

    async def describe(self) -> Description:
        return _description((await self._call({'describe':{}}))['description'],self.connection.writer.realm)

    async def compile_sql(self, name: str, sql: str, namespace: int) -> Compiled:
        return _compiled((await self._call(_compile(name,sql,namespace)))['compiled'])

    async def prepare_next(self, compiled: Compiled) -> Prepared | None:
        return _prepared((await self._call({'next':compiled._wire()}))['prepared'])

    async def _control(self, kind: str, reference: Reference) -> Prepared:
        result = _prepared((await self._call(_control(kind,reference)))['prepared'])
        if result is None: raise IncompatibleNative('Missing prepared mutation control')
        return result

    async def prepare_apply(self, reference: Reference) -> Prepared: return await self._control('apply',reference)
    async def prepare_cancel(self, reference: Reference) -> Prepared: return await self._control('cancel',reference)

    async def submit(self, prepared: Prepared) -> int:
        return integer((await self._call({'submit':prepared.data.decode()},prepared.data))['receipt']['position'], 'position')

    async def observe(self, prepared: Prepared, position: int) -> Observation:
        return Observation((await self._call(_input('observe',prepared,position)))['observation'])

    async def rejection(self, prepared: Prepared, position: int) -> Rejection | None:
        value = (await self._call(_input('rejection',prepared,position)))['rejection']
        return None if value is None else Rejection(value)

    async def status(self, reference: Reference) -> Status | None:
        return _status((await self._call({'status':reference.data.hex()}))['status'])

    async def close(self) -> None: await self._owner._worker.aclose(self._owner._destroy)
    async def __aenter__(self) -> AsyncClient: return self
    async def __aexit__(self, kind: type[BaseException] | None, value: BaseException | None, traceback: TracebackType | None) -> None: await self.close()

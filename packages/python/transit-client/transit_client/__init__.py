"""Typed raw Transit clients. Import starts no worker, credential read or I/O."""
from __future__ import annotations
import ctypes as c
from dataclasses import dataclass
from pathlib import Path
import threading
from typing import Self, Generic, TypeVar
from . import errors as errors
from .errors import Closed, IncompatibleNative, TransitError, UncertainOperation, UnsupportedCapability, native_error
from .types import (AdmissionReceipt as AdmissionReceipt, ClientConfig as ClientConfig,
                    Capabilities as Capabilities,
                    Credential as Credential, MutationReceipt as MutationReceipt,
                    OperationIdentity as OperationIdentity, ProcessRef as ProcessRef,
                    ResourceRef as ResourceRef, integer, owned_bytes, VALUE_BYTES, MAX_BODY)
from ._native import Library, encode, seed
from ._worker import Worker, owned_await


@dataclass(frozen=True, slots=True)
class SendInfo:
    identity: OperationIdentity
    peer: ProcessRef
    principal: int
    sequence: int


@dataclass(frozen=True, slots=True)
class MutationInfo:
    identity: OperationIdentity
    realm: int
    principal: int
    sequence: int
    command: str


I = TypeVar('I', SendInfo, MutationInfo)


class _Pending(Generic[I]):
    """Owned opaque retry material, reusable on another matching client."""
    def __init__(self, info: I, frozen: bytes) -> None:
        self.info: I = info
        self._frozen: bytes | None = bytes(frozen)
        self._lock = threading.Lock()

    @property
    def identity(self) -> OperationIdentity:
        return self.info.identity

    def export(self) -> bytes:
        with self._lock:
            if self._frozen is None:
                raise Closed('Pending send is closed')
            return bytes(self._frozen)

    def close(self) -> None:
        with self._lock:
            self._frozen = None

    def __enter__(self) -> Self:
        self.export()
        return self

    def __exit__(self, *_: object) -> None:
        self.close()

    def __repr__(self) -> str:
        return f'{type(self).__name__}(identity={self.identity.sha256})'


class PendingSend(_Pending[SendInfo]):
    """A native-classified send; dispatch returns admission only."""


class PendingMutation(_Pending[MutationInfo]):
    """An exact recovered growing command; its receipt confirms this command only."""


class Client:
    def __init__(self, config: ClientConfig) -> None:
        if not isinstance(config, ClientConfig):
            raise TypeError('Expected ClientConfig')
        self.config = config
        self._api = Library('client', Path(__file__).with_name('client-abi.json'), config.native_directory)
        if not self._api.lib.transit_client_supports_kind(6):
            raise UnsupportedCapability('The native client does not support growing sends')
        self._worker = Worker(self._api.contract['minimum_stack_bytes'])
        self._handle = c.c_void_p()
        self._last_receipt: AdmissionReceipt | None = None
        self._last_mutation_receipt: MutationReceipt | None = None
        try:
            self._worker.call(self._open)
        except BaseException:
            self._worker.close(lambda: None)
            raise

    @classmethod
    def open(cls, config: ClientConfig) -> Self:
        return cls(config)

    def _open(self) -> None:
        url = self.config.url.encode()
        status = self._api.lib.transit_client_create(1, url, len(url), self.config.timeout_ms, c.byref(self._handle))
        if status:
            raise native_error(status, phase='open')

    def _import(self, frozen: bytes) -> c.c_void_p:
        operation = c.c_void_p()
        status = self._api.lib.transit_operation_import(frozen, len(frozen), c.byref(operation))
        if status:
            raise native_error(status, phase='recover_send')
        return operation

    def _capabilities(self, credential: Credential) -> Capabilities:
        document = encode({'realm': credential.realm, 'principal': credential.principal,
                           'kind': {'capabilities': {}}})
        operation, private = c.c_void_p(), seed(credential.seed_file)
        try:
            status = self._api.lib.transit_operation_prepare(7, private, document, len(document), c.byref(operation))
            if status:
                raise native_error(status, phase='capabilities')
            response = self._api.call('transit_client_call', self._handle, operation)
            caps = response['body']['capabilities']
            if response['version'] != 3 or caps['version'] != 3 or caps['profile'] != 'growing_v1':
                raise UnsupportedCapability('Authority does not advertise the explicit growing profile')
            return Capabilities(response['realm'], response['position'], response['principal_sequence'],
                                caps['page_entries'], caps['mutation_budget'], caps['output_budget'],
                                caps['retained_read_versions'], caps['station'])
        finally:
            c.memset(private, 0, 32)
            self._api.lib.transit_operation_destroy(operation)

    def capabilities(self, credential: Credential) -> Capabilities:
        if not isinstance(credential, Credential):
            raise TypeError('Expected Credential')
        return self._worker.call(lambda: self._capabilities(credential))

    def _pending(self, operation: c.c_void_p, frozen: bytes) -> PendingSend:
        info = self._api.call('transit_operation_metadata', operation)
        if (info['version'], info['kind'], info['profile'], info['command']) != (1, 'growing_command', 'growing_v3', 'send'):
            raise UnsupportedCapability('Recovery material is not a supported growing send')
        metadata = SendInfo(OperationIdentity(info['identity']), ProcessRef(info['realm'], info['destination']),
                            integer(info['principal'], 'principal', minimum=0), integer(int(info['sequence']), 'sequence'))
        return PendingSend(metadata, frozen)

    def _prepare(self, peer: ProcessRef, payload: bytes, credential: Credential, sequence: int) -> PendingSend:
        if peer.realm != credential.realm:
            raise ValueError('Destination and credential must share a realm')
        document = encode({'realm': credential.realm, 'principal': credential.principal, 'sequence': sequence,
                           'command': {'send': {'pid': peer.pid, 'value': payload.hex()}}})
        operation, private = c.c_void_p(), seed(credential.seed_file)
        try:
            status = self._api.lib.transit_operation_prepare(6, private, document, len(document), c.byref(operation))
            if status:
                raise native_error(status, phase='prepare_send')
            frozen = self._api.call_bytes('transit_operation_export', operation)
            if frozen is None:
                raise IncompatibleNative('Native export returned no operation')
            return self._pending(operation, frozen)
        finally:
            c.memset(private, 0, 32)
            self._api.lib.transit_operation_destroy(operation)

    def prepare_send(self, peer: ProcessRef, data: bytes, *, credential: Credential, sequence: int) -> PendingSend:
        if not isinstance(peer, ProcessRef) or not isinstance(credential, Credential):
            raise TypeError('Expected ProcessRef and Credential')
        payload = owned_bytes(data, VALUE_BYTES)
        integer(sequence, 'sequence')
        return self._worker.call(lambda: self._prepare(peer, payload, credential, sequence))

    def _recover(self, frozen: bytes) -> PendingSend:
        operation = self._import(frozen)
        try:
            return self._pending(operation, frozen)
        finally:
            self._api.lib.transit_operation_destroy(operation)

    def recover_send(self, frozen: bytes) -> PendingSend:
        owned = owned_bytes(frozen, MAX_BODY)
        return self._worker.call(lambda: self._recover(owned))

    def _mutation(self, operation: c.c_void_p, frozen: bytes) -> PendingMutation:
        info = self._api.call('transit_operation_metadata', operation)
        if (info['version'], info['kind'], info['profile']) != (1, 'growing_command', 'growing_v3'):
            raise UnsupportedCapability('Recovery material is not a supported growing mutation')
        return PendingMutation(MutationInfo(OperationIdentity(info['identity']), info['realm'], info['principal'],
                                            int(info['sequence']), info['command']), frozen)

    def _recover_mutation(self, frozen: bytes) -> PendingMutation:
        operation = self._import(frozen)
        try:
            return self._mutation(operation, frozen)
        finally:
            self._api.lib.transit_operation_destroy(operation)

    def recover_mutation(self, frozen: bytes) -> PendingMutation:
        owned = owned_bytes(frozen, MAX_BODY)
        return self._worker.call(lambda: self._recover_mutation(owned))

    def _dispatch_mutation(self, frozen: bytes) -> MutationReceipt:
        operation = self._import(frozen)
        try:
            self._mutation(operation, frozen)
            self._last_mutation_receipt = None
            try:
                result = self._api.call('transit_client_call', self._handle, operation, recovery=frozen)
                receipt = MutationReceipt(result['position'])
            except TransitError:
                raise
            except Exception as error:
                raise UncertainOperation(recovery=frozen, code=type(error).__name__) from None
            self._last_mutation_receipt = receipt
            return receipt
        finally:
            self._api.lib.transit_operation_destroy(operation)

    def dispatch_mutation(self, pending: PendingMutation) -> MutationReceipt:
        if not isinstance(pending, PendingMutation):
            raise TypeError('Expected PendingMutation')
        frozen = pending.export()
        return self._worker.call(lambda: self._dispatch_mutation(frozen))

    def _dispatch(self, frozen: bytes) -> AdmissionReceipt:
        operation = self._import(frozen)
        try:
            self._pending(operation, frozen)  # Native classification, including recovered operations.
            self._last_receipt = None
            try:
                result = self._api.call('transit_client_call', self._handle, operation, recovery=frozen)
                receipt = AdmissionReceipt(result['position'])
            except TransitError:
                raise
            except Exception as error:
                raise UncertainOperation(recovery=frozen, code=type(error).__name__) from None
            self._last_receipt = receipt
            return receipt
        finally:
            self._api.lib.transit_operation_destroy(operation)

    def dispatch(self, pending: PendingSend) -> AdmissionReceipt:
        if not isinstance(pending, PendingSend):
            raise TypeError('Expected PendingSend')
        frozen = pending.export()
        return self._worker.call(lambda: self._dispatch(frozen))

    @property
    def last_receipt(self) -> AdmissionReceipt | None:
        """Last observed admission, retained even when an outer await was cancelled."""
        return self._last_receipt

    @property
    def last_mutation_receipt(self) -> MutationReceipt | None:
        return self._last_mutation_receipt

    def _destroy(self) -> None:
        self._api.lib.transit_client_destroy(self._handle)
        self._handle = c.c_void_p()

    def close(self) -> None:
        self._worker.close(self._destroy)

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *_: object) -> None:
        self.close()


class AsyncClient:
    def __init__(self, client: Client) -> None:
        self._client = client

    @classmethod
    async def open(cls, config: ClientConfig) -> Self:
        # Opening only allocates local handles; no network or credential read.
        return cls(Client.open(config))

    async def prepare_send(self, peer: ProcessRef, data: bytes, *, credential: Credential, sequence: int) -> PendingSend:
        if not isinstance(peer, ProcessRef) or not isinstance(credential, Credential):
            raise TypeError('Expected ProcessRef and Credential')
        owned = owned_bytes(data, VALUE_BYTES)
        integer(sequence, 'sequence')
        return await owned_await(self._client._worker.submit(lambda: self._client._prepare(peer, owned, credential, sequence)))

    async def capabilities(self, credential: Credential) -> Capabilities:
        if not isinstance(credential, Credential):
            raise TypeError('Expected Credential')
        return await owned_await(self._client._worker.submit(lambda: self._client._capabilities(credential)))

    async def recover_send(self, frozen: bytes) -> PendingSend:
        owned = owned_bytes(frozen, MAX_BODY)
        return await owned_await(self._client._worker.submit(lambda: self._client._recover(owned)))

    async def recover_mutation(self, frozen: bytes) -> PendingMutation:
        owned = owned_bytes(frozen, MAX_BODY)
        return await owned_await(self._client._worker.submit(lambda: self._client._recover_mutation(owned)))

    async def dispatch_mutation(self, pending: PendingMutation) -> MutationReceipt:
        if not isinstance(pending, PendingMutation):
            raise TypeError('Expected PendingMutation')
        frozen = pending.export()
        return await owned_await(self._client._worker.submit(lambda: self._client._dispatch_mutation(frozen)))

    async def dispatch(self, pending: PendingSend) -> AdmissionReceipt:
        if not isinstance(pending, PendingSend):
            raise TypeError('Expected PendingSend')
        frozen = pending.export()
        return await owned_await(self._client._worker.submit(lambda: self._client._dispatch(frozen)))

    @property
    def last_receipt(self) -> AdmissionReceipt | None:
        return self._client.last_receipt

    @property
    def last_mutation_receipt(self) -> MutationReceipt | None:
        return self._client.last_mutation_receipt

    async def aclose(self) -> None:
        await self._client._worker.aclose(self._client._destroy)

    async def __aenter__(self) -> Self:
        return self

    async def __aexit__(self, *_: object) -> None:
        await self.aclose()

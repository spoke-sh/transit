"""Typed RPC values; Zig owns construction, publication and capture validation."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Any, Awaitable, Callable, Generic, TypeVar
from transit_client import ResourceRef
from transit_client._native import Library, encode
from transit_client._worker import Worker
from transit_client.errors import Closed, UnsupportedCapability, IncompatibleNative
from transit_client.types import integer, owned_bytes
from .models import Codec

U64_MAX = (1 << 64) - 1
T = TypeVar('T')


class GrpcShape(Enum):
    UNARY = 'unary'
    SERVER_STREAMING = 'server_streaming'
    CLIENT_STREAMING = 'client_streaming'
    BIDI = 'bidi'


@dataclass(frozen=True, slots=True)
class GrpcMethod:
    path: str
    shape: GrpcShape
    descriptor_digest: bytes

    def _wire(self) -> object:
        if not isinstance(self.path, str) or not isinstance(self.shape, GrpcShape):
            raise TypeError('Expected an RPC method and shape')
        digest = owned_bytes(self.descriptor_digest, 32)
        if len(digest) != 32: raise ValueError('Expected a 32-byte descriptor digest')
        return {'path': self.path, 'shape': self.shape.value, 'descriptor_digest': digest.hex()}


@dataclass(frozen=True, slots=True)
class GrpcSecretRef:
    binding: str
    version: int


@dataclass(frozen=True, slots=True)
class GrpcMetadata:
    name: str
    value: bytes | GrpcSecretRef = field(repr=False)


@dataclass(frozen=True, slots=True)
class GrpcRequest:
    method: GrpcMethod
    metadata: tuple[GrpcMetadata, ...] = field(default=(), repr=False)

    def _wire(self) -> object:
        if not isinstance(self.method, GrpcMethod) or not isinstance(self.metadata, tuple) or len(self.metadata) > 64:
            raise TypeError('Expected an RPC method and at most 64 ordered metadata fields')
        entries: list[object] = []
        for item in self.metadata:
            if not isinstance(item, GrpcMetadata) or not isinstance(item.name, str):
                raise TypeError('Expected GrpcMetadata')
            value: object
            if isinstance(item.value, GrpcSecretRef):
                if not isinstance(item.value.binding, str): raise TypeError('Expected a secret binding')
                value = {'secret': {'binding': item.value.binding,
                    'version': str(integer(item.value.version, 'secret version', maximum=U64_MAX))}}
            else:
                value = {'literal': owned_bytes(item.value, 8192).hex()}
            entries.append({'name': item.name, 'value': value})
        return {'method': self.method._wire(), 'metadata': entries}


def _codec(action: object, native_directory: Path | None, *, capability: str = 'grpc_requests') -> dict[str, Any]:
    api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
    worker = Worker(api.contract['minimum_stack_bytes'])
    try:
        data = encode(action)
        def call() -> dict[str, Any]:
            if not api.call('station_growing_capabilities').get(capability):
                raise UnsupportedCapability('Native Station lacks ' + capability)
            value: dict[str, Any] = api.call('station_grpc_codec', data, len(data))
            return value
        return worker.call(call)
    finally:
        worker.close(lambda: None)


def grpc_method(descriptor: bytes, path: str, *, native_directory: Path | None = None) -> GrpcMethod:
    """Resolve a local pinned descriptor; no reflection, authority or credentials."""
    if not isinstance(path, str): raise TypeError('Expected an RPC method path')
    result = _codec({'descriptor': {'bytes': owned_bytes(descriptor, 65536).hex(), 'method': path}},
                    native_directory, capability='grpc_descriptors')['descriptor']['method']
    return GrpcMethod(result['path'], GrpcShape(result['shape']), bytes.fromhex(result['descriptor_digest']))


@dataclass(frozen=True, slots=True)
class PreparedGrpcRequest:
    resource: ResourceRef
    namespace: int
    reference: bytes = field(repr=False)
    metadata: bytes = field(repr=False)
    batch: bytes = field(repr=False)

    def _wire(self) -> object:
        return {'reference': owned_bytes(self.reference, 145).hex(),
                'metadata': owned_bytes(self.metadata, 8192).hex(),
                'batch': owned_bytes(self.batch, 65544).hex()}


def prepare_grpc(resource: ResourceRef, namespace: int, request: GrpcRequest, messages: tuple[bytes, ...], *,
                 endpoint_revision: int, reconcile_before_ms: int, max_attempts: int = 1,
                 native_directory: Path | None = None) -> PreparedGrpcRequest:
    if not isinstance(resource, ResourceRef) or not isinstance(request, GrpcRequest):
        raise TypeError('Expected ResourceRef and GrpcRequest')
    if not isinstance(messages, tuple) or len(messages) > 64:
        raise TypeError('Expected at most 64 immutable original protobuf messages')
    namespace = integer(namespace, 'namespace', maximum=U64_MAX)
    result = _codec({'prepare': {'resource': resource.resource, 'namespace': str(namespace),
        'request': request._wire(), 'messages': [owned_bytes(message, 16384).hex() for message in messages],
        'endpoint_revision': str(integer(endpoint_revision, 'endpoint revision', maximum=U64_MAX)),
        'reconcile_before_ms': integer(reconcile_before_ms, 'reconciliation deadline'),
        'max_attempts': integer(max_attempts, 'attempts', maximum=(1 << 32) - 1)}}, native_directory)['prepared']
    return PreparedGrpcRequest(resource, namespace, bytes.fromhex(result['reference']),
                               bytes.fromhex(result['metadata']), bytes.fromhex(result['batch']))


class GrpcPhase(Enum):
    OBSERVED = 'observed'
    CLOSED_UNKNOWN = 'closed_unknown'
    NOT_DISPATCHED = 'not_dispatched'


class GrpcRejection(Enum):
    DENIED = 'denied'
    INVALID_REQUEST = 'invalid_request'
    BUSY = 'busy'


@dataclass(frozen=True, slots=True)
class GrpcOutcome:
    phase: GrpcPhase
    resource: ResourceRef
    exchange: int
    effect: int
    attempt: int
    status: int | None
    reference: bytes | None = field(repr=False)
    diagnostic: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class GrpcRejected:
    reason: GrpcRejection
    diagnostic: dict[str, Any] = field(repr=False)


@dataclass(frozen=True, slots=True)
class GrpcReleased:
    resource: ResourceRef
    exchange: int


def decode_grpc_reply(realm: int, data: bytes, *, native_directory: Path | None = None) -> GrpcOutcome | GrpcRejected | GrpcReleased:
    integer(realm, 'realm')
    data = owned_bytes(data, 73)
    value = _codec({'outcome': data.hex()}, native_directory,
                   capability='grpc_release' if data[:4] == b'GRK1' else 'grpc_requests')
    if 'rejected' in value:
        return GrpcRejected(GrpcRejection(value['rejected']['reason']), value['rejected']['diagnostic'])
    if 'released' in value:
        return GrpcReleased(ResourceRef(realm, value['released']['resource']), int(value['released']['exchange']))
    result = value['outcome']
    return GrpcOutcome(GrpcPhase(result['phase']), ResourceRef(realm, result['resource']),
                       int(result['exchange']), result['effect'], result['attempt'], result['status'],
                       None if result['reference'] is None else bytes.fromhex(result['reference']), result['diagnostic'])


class GrpcReplyCodec(Generic[T]):
    """Opt-in union of an application codec and shared RPC outcome records."""
    version = 1

    def __init__(self, application: Codec[T], realm: int, *, native_directory: Path | None = None) -> None:
        self.application = application
        self.realm = integer(realm, 'realm')
        self.native_directory = native_directory
        self.type_id = 'transit.grpc.reply+' + application.type_id
        self.max_encoded_bytes = max(73, application.max_encoded_bytes)

    def encode(self, value: T | GrpcOutcome | GrpcRejected | GrpcReleased) -> bytes:
        if isinstance(value, (GrpcOutcome, GrpcRejected, GrpcReleased)):
            raise ValueError('RPC outcome records are receive-only')
        return self.application.encode(value)

    def decode(self, data: bytes) -> T | GrpcOutcome | GrpcRejected | GrpcReleased:
        if data[:4] in (b'GRR1', b'GRF1', b'GRK1'):
            return decode_grpc_reply(self.realm, data, native_directory=self.native_directory)
        return self.application.decode(data)


class GrpcReplayPolicy(Enum):
    CAPTURED = 'captured'
    REQUIRE_UNREDACTED = 'require_unredacted'


class GrpcPartKind(Enum):
    REQUEST_METADATA = 'request_metadata'
    REQUEST_BATCH = 'request_batch'
    ENDPOINT_POLICY = 'endpoint_policy'
    INITIAL_METADATA = 'initial_metadata'
    RESPONSE_MESSAGE = 'response_message'
    RESPONSE_BODY = 'response_body'
    HALF_CLOSE = 'half_close'
    TRAILERS = 'trailers'
    TIMING = 'timing'
    OMISSION = 'omission'
    COMPLETION = 'completion'


@dataclass(frozen=True, slots=True)
class GrpcPart:
    kind: GrpcPartKind
    data: bytes = field(repr=False)
    complete: bool


def _part(value: dict[str, Any] | None, complete: bool) -> GrpcPart | None:
    if value is None:
        if not complete:
            raise IncompatibleNative('RPC reader ended without verified completion')
        return None
    if type(value['complete']) is not bool:
        raise IncompatibleNative('Invalid RPC completion flag')
    return GrpcPart(GrpcPartKind(value['kind']), owned_bytes(bytes.fromhex(value['bytes']), 256), value['complete'])


class GrpcReader:
    def __init__(self, identity: int, call: Callable[[object], dict[str, Any]]) -> None:
        self._identity, self._call, self._closed = identity, call, False
        self._complete = False

    @property
    def complete(self) -> bool: return self._complete

    def read(self) -> GrpcPart | None:
        if self._closed: raise Closed('RPC reader is closed')
        part = _part(self._call({'next': self._identity})['part'], self.complete)
        if part is not None: self._complete = part.complete
        return part

    def close(self) -> None:
        if not self._closed:
            self._call({'close': self._identity})
            self._closed = True

    def __enter__(self) -> GrpcReader: return self
    def __exit__(self, *_: object) -> None: self.close()


class AsyncGrpcReader:
    def __init__(self, identity: int, call: Callable[[object], Awaitable[dict[str, Any]]]) -> None:
        self._identity, self._call, self._closed = identity, call, False
        self._complete = False

    @property
    def complete(self) -> bool: return self._complete

    async def read(self) -> GrpcPart | None:
        if self._closed: raise Closed('RPC reader is closed')
        part = _part((await self._call({'next': self._identity}))['part'], self.complete)
        if part is not None: self._complete = part.complete
        return part

    async def aclose(self) -> None:
        if not self._closed:
            await self._call({'close': self._identity})
            self._closed = True

    async def __aenter__(self) -> AsyncGrpcReader: return self
    async def __aexit__(self, *_: object) -> None: await self.aclose()

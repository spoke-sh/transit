"""Typed HTTP values; Zig owns construction, publication and capture validation."""
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


class HttpMethod(Enum):
    GET = 'GET'
    HEAD = 'HEAD'
    POST = 'POST'
    PUT = 'PUT'
    PATCH = 'PATCH'
    DELETE = 'DELETE'
    OPTIONS = 'OPTIONS'


@dataclass(frozen=True, slots=True)
class Literal:
    value: str = field(repr=False)


@dataclass(frozen=True, slots=True)
class Variable:
    name: str
    value: str = field(repr=False)


@dataclass(frozen=True, slots=True)
class SecretRef:
    binding: str
    version: int


type HttpPiece = Literal | Variable | SecretRef


def _pieces(values: tuple[HttpPiece, ...]) -> list[object]:
    if not isinstance(values, tuple) or len(values) > 128:
        raise ValueError('Expected at most 128 immutable HTTP pieces')
    result: list[object] = []
    for piece in values:
        if isinstance(piece, Literal) and isinstance(piece.value, str):
            result.append({'literal': piece.value})
        elif isinstance(piece, Variable) and isinstance(piece.name, str) and isinstance(piece.value, str):
            result.append({'variable': {'name': piece.name, 'value': piece.value}})
        elif isinstance(piece, SecretRef) and isinstance(piece.binding, str):
            result.append({'secret': {'binding': piece.binding, 'version': str(integer(piece.version, 'secret version', maximum=U64_MAX))}})
        else:
            raise TypeError('Expected a typed HTTP literal, variable or secret reference')
    return result


@dataclass(frozen=True, slots=True)
class HttpHeader:
    name: str
    value: tuple[HttpPiece, ...] = field(repr=False)


@dataclass(frozen=True, slots=True)
class HttpRequest:
    method: HttpMethod
    target: tuple[HttpPiece, ...] = field(repr=False)
    headers: tuple[HttpHeader, ...] = field(default=(), repr=False)

    def _wire(self) -> object:
        if not isinstance(self.method, HttpMethod) or not isinstance(self.headers, tuple) or len(self.headers) > 64:
            raise ValueError('Expected an HTTP method and at most 64 ordered headers')
        headers: list[object] = []
        for header in self.headers:
            if not isinstance(header, HttpHeader) or not isinstance(header.name, str):
                raise TypeError('Expected HttpHeader')
            headers.append({'name': header.name, 'value': _pieces(header.value)})
        return {'method': self.method.value, 'target': _pieces(self.target), 'headers': headers}


def _codec(action: object, native_directory: Path | None) -> dict[str, Any]:
    api = Library('station', Path(__file__).with_name('station-abi.json'), native_directory)
    worker = Worker(api.contract['minimum_stack_bytes'])
    try:
        data = encode(action)
        def call() -> dict[str, Any]:
            if not api.call('station_growing_capabilities').get('http_requests'):
                raise UnsupportedCapability('Native Station lacks HTTP request support')
            value: dict[str, Any] = api.call('station_http_codec', data, len(data))
            return value
        return worker.call(call)
    finally:
        worker.close(lambda: None)


@dataclass(frozen=True, slots=True)
class PreparedHttpRequest:
    resource: ResourceRef
    namespace: int
    reference: bytes = field(repr=False)
    metadata: bytes = field(repr=False)
    body: bytes = field(repr=False)

    def _wire(self) -> object:
        return {'reference': owned_bytes(self.reference, 112).hex(),
                'metadata': owned_bytes(self.metadata, 8192).hex(),
                'body': owned_bytes(self.body, 65536).hex()}


def prepare_http(resource: ResourceRef, namespace: int, request: HttpRequest, body: bytes = b'', *,
                 endpoint_revision: int, reconcile_before_ms: int, max_attempts: int = 1,
                 native_directory: Path | None = None) -> PreparedHttpRequest:
    if not isinstance(resource, ResourceRef) or not isinstance(request, HttpRequest):
        raise TypeError('Expected ResourceRef and HttpRequest')
    namespace = integer(namespace, 'namespace', maximum=U64_MAX)
    body = owned_bytes(body, 65536)
    result = _codec({'prepare': {'resource': resource.resource, 'namespace': str(namespace),
        'request': request._wire(), 'body': body.hex(),
        'endpoint_revision': str(integer(endpoint_revision, 'endpoint revision', maximum=U64_MAX)),
        'reconcile_before_ms': integer(reconcile_before_ms, 'reconciliation deadline'),
        'max_attempts': integer(max_attempts, 'attempts', maximum=(1 << 32) - 1)}}, native_directory)['prepared']
    return PreparedHttpRequest(resource, namespace, bytes.fromhex(result['reference']),
                               bytes.fromhex(result['metadata']), body)


class HttpPhase(Enum):
    OBSERVED = 'observed'
    CLOSED_UNKNOWN = 'closed_unknown'
    NOT_DISPATCHED = 'not_dispatched'


class HttpRejection(Enum):
    DENIED = 'denied'
    INVALID_REQUEST = 'invalid_request'
    BUSY = 'busy'


@dataclass(frozen=True, slots=True)
class HttpOutcome:
    phase: HttpPhase
    resource: ResourceRef
    exchange: int
    effect: int
    attempt: int
    status: int | None
    reference: bytes | None = field(repr=False)


@dataclass(frozen=True, slots=True)
class HttpRejected:
    reason: HttpRejection


def decode_http_reply(realm: int, data: bytes, *, native_directory: Path | None = None) -> HttpOutcome | HttpRejected:
    integer(realm, 'realm')
    value = _codec({'outcome': owned_bytes(data, 71).hex()}, native_directory)
    if 'rejected' in value:
        return HttpRejected(HttpRejection(value['rejected']))
    result = value['outcome']
    return HttpOutcome(HttpPhase(result['phase']), ResourceRef(realm, result['resource']),
                       int(result['exchange']), result['effect'], result['attempt'], result['status'],
                       None if result['reference'] is None else bytes.fromhex(result['reference']))


class HttpReplyCodec(Generic[T]):
    """Opt-in union of an application codec and shared HTTP outcome records."""
    version = 1

    def __init__(self, application: Codec[T], realm: int, *, native_directory: Path | None = None) -> None:
        self.application = application
        self.realm = integer(realm, 'realm')
        self.native_directory = native_directory
        self.type_id = 'transit.http.reply+' + application.type_id
        self.max_encoded_bytes = max(71, application.max_encoded_bytes)

    def encode(self, value: T | HttpOutcome | HttpRejected) -> bytes:
        if isinstance(value, (HttpOutcome, HttpRejected)):
            raise ValueError('HTTP outcome records are receive-only')
        return self.application.encode(value)

    def decode(self, data: bytes) -> T | HttpOutcome | HttpRejected:
        if data[:4] in (b'HTR1', b'HTF1'):
            return decode_http_reply(self.realm, data, native_directory=self.native_directory)
        return self.application.decode(data)


class HttpReplayPolicy(Enum):
    CAPTURED = 'captured'
    REQUIRE_UNREDACTED = 'require_unredacted'


class HttpPartKind(Enum):
    REQUEST_TEMPLATE = 'request_template'
    REQUEST_HEAD = 'request_head'
    REQUEST_BODY = 'request_body'
    RESPONSE_HEAD = 'response_head'
    RESPONSE_BODY = 'response_body'
    RESPONSE_TRAILERS = 'response_trailers'
    TIMING = 'timing'
    OMISSION = 'omission'
    COMPLETION = 'completion'


@dataclass(frozen=True, slots=True)
class HttpPart:
    kind: HttpPartKind
    data: bytes = field(repr=False)
    complete: bool


def _part(value: dict[str, Any] | None, complete: bool) -> HttpPart | None:
    if value is None:
        if not complete:
            raise IncompatibleNative('HTTP reader ended without verified completion')
        return None
    if type(value['complete']) is not bool:
        raise IncompatibleNative('Invalid HTTP completion flag')
    return HttpPart(HttpPartKind(value['kind']), owned_bytes(bytes.fromhex(value['bytes']), 256), value['complete'])


class HttpReader:
    def __init__(self, identity: int, call: Callable[[object], dict[str, Any]]) -> None:
        self._identity, self._call, self._closed = identity, call, False
        self._complete = False

    @property
    def complete(self) -> bool: return self._complete

    def read(self) -> HttpPart | None:
        if self._closed: raise Closed('HTTP reader is closed')
        part = _part(self._call({'next': self._identity})['part'], self.complete)
        if part is not None: self._complete = part.complete
        return part

    def close(self) -> None:
        if not self._closed:
            self._call({'close': self._identity})
            self._closed = True

    def __enter__(self) -> HttpReader: return self
    def __exit__(self, *_: object) -> None: self.close()


class AsyncHttpReader:
    def __init__(self, identity: int, call: Callable[[object], Awaitable[dict[str, Any]]]) -> None:
        self._identity, self._call, self._closed = identity, call, False
        self._complete = False

    @property
    def complete(self) -> bool: return self._complete

    async def read(self) -> HttpPart | None:
        if self._closed: raise Closed('HTTP reader is closed')
        part = _part((await self._call({'next': self._identity}))['part'], self.complete)
        if part is not None: self._complete = part.complete
        return part

    async def aclose(self) -> None:
        if not self._closed:
            await self._call({'close': self._identity})
            self._closed = True

    async def __aenter__(self) -> AsyncHttpReader: return self
    async def __aexit__(self, *_: object) -> None: await self.aclose()

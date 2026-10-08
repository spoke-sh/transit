"""Scoped, synchronous handler operations backed by the growing native turn."""
from __future__ import annotations
from dataclasses import dataclass
import threading
from typing import Any, TypeVar, TYPE_CHECKING, Protocol
from transit_client import ProcessRef, ResourceRef
from transit_client.types import integer, owned_bytes, MAX_BODY
from transit_client.errors import Busy, Closed, HandlerError, MissingValue, TurnExpired, UnsupportedCapability
from ._growing import Growing
from .table import Table, TableSchema, TableLimits, TableCreation
from .models import Codec, Found, Key, KVEntry, Page, Reply, WaitPolicy, encoded, decoded
if TYPE_CHECKING:
    from .query import QueryJob, QueryPlan, ResultReader
    from .http import PreparedHttpRequest, HttpOutcome, HttpFollowupReason
    from .grpc import PreparedGrpcRequest, GrpcOutcome
    from .document import DocumentOwner

T = TypeVar('T')
U64_MAX = (1 << 64) - 1


class StopSignal(Protocol):
    def is_set(self) -> bool: ...


def _cursor(value: str | None) -> str | None:
    if value is not None:
        if not isinstance(value, str):
            raise TypeError('Cursor must be opaque text or None')
        if len(value) > MAX_BODY or len(value.encode()) > MAX_BODY:
            raise ValueError('Cursor exceeds the native request bound')
    return value


class U64:
    @staticmethod
    def checked_add(left: int, right: int) -> int:
        integer(left, 'left', minimum=0, maximum=U64_MAX)
        integer(right, 'right', minimum=0, maximum=U64_MAX)
        return integer(left + right, 'sum', minimum=0, maximum=U64_MAX)


@dataclass(frozen=True, slots=True)
class Budgets:
    mutations: int
    outputs: int
    views: int
    retained_reads: int
    retains: int
    releases: int


@dataclass(frozen=True, slots=True)
class ReadVersion:
    pid: int
    input: int
    index: int
    def __post_init__(self) -> None:
        integer(self.pid, 'pid')
        integer(self.input, 'input')
        integer(self.index, 'index', minimum=0, maximum=255)
    def _wire(self) -> dict[str, int]:
        return {'pid': self.pid, 'input': self.input, 'index': self.index}


class State:
    def __init__(self, turn: Turn, version: ReadVersion | None = None) -> None:
        self._turn, self._version = turn, version

    def _key(self, key: Key[T]) -> str:
        self._turn._check()
        if not isinstance(key, Key):
            raise TypeError('Expected a typed Key')
        return owned_bytes(key.name, self._turn._native.caps['key_bytes']).hex()

    def find(self, key: Key[T]) -> Found[T] | None:
        name = self._key(key)
        action = {'get': name} if self._version is None else {'version_get': {'id': self._version._wire(), 'key': name}}
        value = self._turn._apply(action)['value']
        return None if value is None else Found(decoded(key.codec, bytes.fromhex(value), self._turn._native.caps['value_bytes']))

    def require(self, key: Key[T]) -> T:
        found = self.find(key)
        if found is None:
            raise MissingValue('Required associated-state value is absent')
        return found.value

    def put(self, key: Key[T], value: T) -> None:
        name = self._key(key)
        if self._version is not None:
            raise HandlerError('Retained sources are read-only')
        data = encoded(key.codec, value, self._turn._native.caps['value_bytes'])
        self._turn._apply({'put': {'key': name, 'value': data.hex()}})

    def delete(self, key: Key[T]) -> None:
        name = self._key(key)
        if self._version is not None:
            raise HandlerError('Retained sources are read-only')
        self._turn._apply({'delete': name})

    def page(self, cursor: str | None = None) -> Page[KVEntry]:
        cursor = _cursor(cursor)
        action = {'page': cursor} if self._version is None else {'version_page': {'id': self._version._wire(), 'cursor': cursor}}
        page = self._turn._apply(action)['page']
        entries = tuple(KVEntry(bytes.fromhex(entry['key']), bytes.fromhex(entry['value']), entry['revision'])
                        for entry in page['entries'] if entry is not None)
        return Page(entries, page['next'])


class Source:
    def __init__(self, turn: Turn, identity: ReadVersion) -> None:
        self._turn, self.identity = turn, identity
        self.state = State(turn, identity)

    def table(self, object_id: int) -> Table:
        self._turn._check()
        return Table(self._turn, object_id, self.identity)


class Turn:
    def __init__(self, native: Growing, event: dict[str, Any], process: ProcessRef, stop: StopSignal) -> None:
        self._native, self._event, self.process, self._stop = native, event, process, stop
        self._scope: int = event['scope']
        self._thread, self._active, self._lock = threading.get_ident(), True, threading.Lock()
        self.state = State(self)
        self.resource = ResourceRef(process.realm, event['resource'])
        self.resource_revision: int = event['resource_revision']

    def _check(self) -> None:
        if not self._active:
            raise TurnExpired('Turn scope has ended')
        if threading.get_ident() != self._thread:
            raise Busy('Turn operations belong to their handler worker')
        if self._stop.is_set():
            raise Closed('Local stop requested; no implicit acknowledgement')

    def _apply(self, action: object) -> Any:
        self._check()
        if not self._lock.acquire(False):
            raise Busy('One operation per turn')
        try:
            return self._native.apply(self._scope, action)
        finally:
            self._lock.release()

    def _end(self) -> None:
        self._active = False

    @property
    def budgets(self) -> Budgets:
        return Budgets(**self._apply({'budgets': {}})['budgets'])

    def _peer(self, peer: ProcessRef) -> int:
        self._check()
        if not isinstance(peer, ProcessRef) or peer.realm != self.process.realm:
            raise ValueError('Destination must be a ProcessRef in this realm')
        return peer.pid

    def cast(self, peer: ProcessRef, value: T, *, codec: Codec[T]) -> None:
        pid = self._peer(peer)
        data = encoded(codec, value, self._native.caps['message_bytes'])
        self._apply({'cast': {'pid': pid, 'value': data.hex()}})

    def call(self, peer: ProcessRef, value: T, *, codec: Codec[T], wait: WaitPolicy) -> int:
        pid = self._peer(peer)
        if not isinstance(wait, WaitPolicy):
            raise TypeError('Select an explicit WaitPolicy')
        data = encoded(codec, value, self._native.caps['message_bytes'])
        result = self._apply({'call': {'pid': pid, 'value': data.hex(), 'deadline_ms': wait.deadline_ms, 'observer': wait.observer}})
        return int(result['correlation'])

    def reply(self, value: T, *, codec: Codec[T]) -> None:
        self._check()
        data = encoded(codec, value, self._native.caps['message_bytes'])
        self._apply({'reply': data.hex()})

    def require_reply(self, reply: Reply[T], *, peer: ProcessRef, correlation: int) -> None:
        self._peer(peer)
        integer(correlation, 'correlation', maximum=U64_MAX)
        incoming = self._event['input']
        origin = incoming['origin'].get('process')
        if (not isinstance(reply, Reply) or incoming['kind'] != 'reply' or origin is None
                or origin['pid'] != peer.pid or int(incoming['correlation']) != correlation
                or reply.position != incoming['position'] or reply.correlation != correlation):
            raise HandlerError('Reply does not match the current authenticated input, peer and saved correlation')

    def cancel_call(self, correlation: int) -> bool:
        value: bool = self._apply({'cancel': str(integer(correlation, 'correlation', maximum=U64_MAX))})['cancelled']
        return value

    def document(self, identity: int) -> DocumentOwner:
        from .document import DocumentOwner
        self._check()
        return DocumentOwner(self, identity)

    def _http_request(self, request: PreparedHttpRequest) -> None:
        from .http import PreparedHttpRequest
        self._check()
        if not isinstance(request, PreparedHttpRequest) or request.resource != self.resource:
            raise ValueError('HTTP publication must use the current associated resource')
        if not self._native.caps.get('http_requests'):
            raise UnsupportedCapability('Native Station lacks HTTP request support')

    def stage_http(self, request: PreparedHttpRequest) -> bool:
        """Advance one upload step; true permits a call in this turn."""
        self._http_request(request)
        staged: bool = self._apply({'http_stage': request._wire()})['staged']
        return staged

    def call_http(self, peer: ProcessRef, request: PreparedHttpRequest) -> int:
        """Call with two committed immutable records; return durable correlation."""
        pid = self._peer(peer)
        self._http_request(request)
        result = self._apply({'http_call': {'pid': pid, 'reference': owned_bytes(request.reference, 112).hex()}})
        return int(result['correlation'])

    def release_http(self, peer: ProcessRef, resource: ResourceRef, exchange: int) -> int:
        """Request durable hold disposal; authenticate the correlated HttpReleased reply."""
        pid = self._peer(peer)
        if not isinstance(resource, ResourceRef) or resource.realm != self.resource.realm:
            raise ValueError('HTTP capture must belong to the current realm')
        if not self._native.caps.get('http_release'):
            raise UnsupportedCapability('Native Station lacks durable HTTP release support')
        result = self._apply({'http_release': {'pid': pid, 'resource': resource.resource,
            'exchange': str(integer(exchange, 'exchange', maximum=U64_MAX))}})
        return int(result['correlation'])

    def followup_http(self, peer: ProcessRef, parent: HttpOutcome, reason: HttpFollowupReason,
                      request: PreparedHttpRequest) -> int:
        """Explicitly request a linked attempt; current service policy decides admission."""
        from .http import HttpOutcome, HttpFollowupReason
        pid = self._peer(peer)
        self._http_request(request)
        if not isinstance(parent, HttpOutcome) or not isinstance(parent.resource, ResourceRef) or parent.resource.realm != self.resource.realm:
            raise ValueError('HTTP parent must belong to the current realm')
        if not isinstance(reason, HttpFollowupReason):
            raise TypeError('Expected HttpFollowupReason')
        if not self._native.caps.get('http_followup'):
            raise UnsupportedCapability('Native Station lacks HTTP followup support')
        result = self._apply({'http_followup': {'pid': pid, 'resource': parent.resource.resource,
            'parent': str(integer(parent.exchange, 'parent exchange', maximum=U64_MAX)),
            'reason': reason.value, 'reference': owned_bytes(request.reference, 112).hex()}})
        return int(result['correlation'])

    def _grpc_request(self, request: PreparedGrpcRequest) -> None:
        from .grpc import PreparedGrpcRequest
        self._check()
        if not isinstance(request, PreparedGrpcRequest) or request.resource != self.resource:
            raise ValueError('RPC publication must use the current associated resource')
        if not self._native.caps.get('grpc_requests'):
            raise UnsupportedCapability('Native Station lacks RPC request support')

    def stage_grpc(self, request: PreparedGrpcRequest) -> bool:
        """Advance one upload step; true permits a call in this turn."""
        self._grpc_request(request)
        staged: bool = self._apply({'grpc_stage': request._wire()})['staged']
        return staged

    def call_grpc(self, peer: ProcessRef, request: PreparedGrpcRequest) -> int:
        """Call with two committed immutable records; return durable correlation."""
        pid = self._peer(peer)
        self._grpc_request(request)
        result = self._apply({'grpc_call': {'pid': pid, 'reference': owned_bytes(request.reference, 145).hex()}})
        return int(result['correlation'])

    def release_grpc(self, peer: ProcessRef, resource: ResourceRef, exchange: int) -> int:
        """Request durable hold disposal; authenticate the correlated GrpcReleased reply."""
        pid = self._peer(peer)
        if not isinstance(resource, ResourceRef) or resource.realm != self.resource.realm:
            raise ValueError('RPC capture must belong to the current realm')
        if not self._native.caps.get('grpc_release'):
            raise UnsupportedCapability('Native Station lacks durable RPC release support')
        result = self._apply({'grpc_release': {'pid': pid, 'resource': resource.resource,
            'exchange': str(integer(exchange, 'exchange', maximum=U64_MAX))}})
        return int(result['correlation'])

    def retry_grpc(self, peer: ProcessRef, parent: GrpcOutcome,
                      request: PreparedGrpcRequest) -> int:
        """Explicitly request a linked attempt; current service policy decides admission."""
        from .grpc import GrpcOutcome
        pid = self._peer(peer)
        self._grpc_request(request)
        if not isinstance(parent, GrpcOutcome) or not isinstance(parent.resource, ResourceRef) or parent.resource.realm != self.resource.realm:
            raise ValueError('RPC parent must belong to the current realm')
        if not self._native.caps.get('grpc_followup'):
            raise UnsupportedCapability('Native Station lacks RPC followup support')
        result = self._apply({'grpc_followup': {'pid': pid, 'resource': parent.resource.resource,
            'parent': str(integer(parent.exchange, 'parent exchange', maximum=U64_MAX)),
            'reference': owned_bytes(request.reference, 145).hex()}})
        return int(result['correlation'])

    def table(self, object_id: int) -> Table:
        self._check()
        return Table(self, object_id)

    def create_table(self, schema: TableSchema, limits: TableLimits) -> TableCreation:
        return Table.create(self, schema, limits)

    def retain(self) -> ReadVersion:
        return ReadVersion(**self._apply({'retain': {}})['version'])

    def open_version(self, identity: ReadVersion) -> Source:
        self._check()
        if not isinstance(identity, ReadVersion):
            raise TypeError('Expected ReadVersion')
        return Source(self, identity)

    def release(self, identity: ReadVersion) -> None:
        if not isinstance(identity, ReadVersion):
            raise TypeError('Expected ReadVersion')
        self._apply({'release': identity._wire()})

    def allow_query(self, peer: ProcessRef, object_id: int, *, expected_revision: int, allow: bool) -> None:
        pid = self._peer(peer)
        integer(object_id, 'Table object', maximum=U64_MAX)
        integer(expected_revision, 'policy revision', minimum=0, maximum=U64_MAX)
        if type(allow) is not bool: raise TypeError('allow must be boolean')
        self._apply({'query_policy': {'peer': pid, 'table': str(object_id), 'expected_revision': str(expected_revision), 'allow': allow}})

    def start_query(self, object_id: int, plan: QueryPlan) -> QueryJob:
        from .query import QueryJob, QueryPlan
        self._check()
        if not isinstance(plan, QueryPlan): raise TypeError('Expected QueryPlan')
        integer(object_id, 'Table object', maximum=U64_MAX)
        result = self._apply({'query_start': {'id': str(object_id), 'plan': plan._wire()}})['query']
        return QueryJob(result['result'], int(result['correlation']), ReadVersion(**result['source']))

    def close_query(self, result: int, *, reason: str = 'cancelled') -> None:
        integer(result, 'query result')
        if reason not in ('cancelled', 'denied'):
            raise ValueError('Select cancelled or denied closure')
        self._apply({'query_close': {'result': result, 'reason': reason}})

    def result(self, correlation: int) -> ResultReader:
        from .query import ResultReader
        self._check()
        return ResultReader(self, correlation)

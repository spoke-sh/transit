"""Public Station values. A host task, field or reference is not durable state."""
from __future__ import annotations
from dataclasses import dataclass, field
from enum import Enum
from pathlib import Path
from typing import Generic, Protocol, TypeVar
from transit_client import Credential, MutationReceipt, OperationIdentity, ProcessRef, ResourceRef
from transit_client.types import ClientConfig, integer, owned_bytes, VALUE_BYTES
from transit_client.errors import CodecError

T = TypeVar('T')
M = TypeVar('M')


class Codec(Protocol[T]):
    @property
    def type_id(self) -> str: ...
    @property
    def version(self) -> int: ...
    @property
    def max_encoded_bytes(self) -> int: ...
    def encode(self, value: T) -> bytes: ...
    def decode(self, data: bytes) -> T: ...


def encoded(codec: Codec[T], value: T, limit: int) -> bytes:
    try:
        integer(codec.version, 'codec version')
        integer(codec.max_encoded_bytes, 'codec byte bound', maximum=limit)
        if not isinstance(codec.type_id, str) or not codec.type_id:
            raise ValueError('Missing codec type ID')
        return owned_bytes(codec.encode(value), codec.max_encoded_bytes)
    except Exception as error:
        raise CodecError('Application encoding failed', code=type(error).__name__) from None


def decoded(codec: Codec[T], data: bytes, limit: int) -> T:
    try:
        integer(codec.version, 'codec version')
        integer(codec.max_encoded_bytes, 'codec byte bound', maximum=limit)
        if not isinstance(codec.type_id, str) or not codec.type_id:
            raise ValueError('Missing codec type ID')
        return codec.decode(owned_bytes(data, codec.max_encoded_bytes))
    except Exception as error:
        raise CodecError('Application decoding failed', code=type(error).__name__) from None


@dataclass(frozen=True, slots=True)
class Key(Generic[T]):
    name: bytes
    codec: Codec[T] = field(repr=False)
    def __post_init__(self) -> None:
        # The native key bound is checked again when used against a handle.
        if not isinstance(self.name, bytes) or not self.name or self.name[0] == 0:
            raise ValueError('Application keys must be nonempty bytes and cannot begin with zero')


@dataclass(frozen=True, slots=True)
class Found(Generic[T]):
    value: T = field(repr=False)


@dataclass(frozen=True, slots=True)
class Basis:
    resource: ResourceRef
    revision: int
    schema: bytes


@dataclass(frozen=True, slots=True)
class Page(Generic[T]):
    entries: tuple[T, ...]
    next: str | None = field(repr=False)
    basis: Basis | None = None


@dataclass(frozen=True, slots=True)
class KVEntry:
    key: bytes
    value: bytes = field(repr=False)
    revision: int


@dataclass(frozen=True, slots=True)
class Activation:
    process: ProcessRef
    principal: int
    generation: int
    seed_file: Path = field(repr=False)
    def __post_init__(self) -> None:
        if not isinstance(self.process, ProcessRef):
            raise TypeError('Expected ProcessRef')
        integer(self.principal, 'principal')
        integer(self.generation, 'generation')
        object.__setattr__(self, 'seed_file', Path(self.seed_file))

    @property
    def credential(self) -> Credential:
        return Credential(self.process.realm, self.principal, self.seed_file)


@dataclass(frozen=True, slots=True)
class ServiceConfig:
    url: str
    profile: str
    activation: Activation
    association: str = 'data'
    timeout_ms: int = 5000
    query_results: bool = False
    native_directory: Path | None = field(default=None, repr=False)
    def __post_init__(self) -> None:
        if not isinstance(self.activation, Activation):
            raise TypeError('Expected Activation')
        ClientConfig(self.url, self.profile, self.timeout_ms, self.native_directory)
        if not isinstance(self.association, str) or not self.association:
            raise ValueError('Association must be nonempty text')
        if len(self.association) > VALUE_BYTES or len(self.association.encode()) > VALUE_BYTES:
            raise ValueError('Association exceeds the native value bound')
        if type(self.query_results) is not bool:
            raise TypeError('query_results must be boolean')
        if self.native_directory is not None:
            object.__setattr__(self, 'native_directory', Path(self.native_directory))


class FailurePolicy(Enum):
    STOP = 'stop'
    BLOCK_INPUT = 'block_input'


@dataclass(frozen=True, slots=True)
class WaitPolicy:
    deadline_ms: int | None
    observer: int | None
    def __post_init__(self) -> None:
        if (self.deadline_ms is None) != (self.observer is None):
            raise ValueError('A timed wait requires both a deadline and observer')
        if self.deadline_ms is not None:
            integer(self.deadline_ms, 'deadline_ms')
            integer(self.observer, 'observer')

    @classmethod
    def untimed(cls) -> WaitPolicy:
        return cls(None, None)

    @classmethod
    def until(cls, deadline_ms: int, observer: int) -> WaitPolicy:
        return cls(deadline_ms, observer)


@dataclass(frozen=True, slots=True)
class Origin:
    kind: str
    principal: int | None = None
    process: ProcessRef | None = None
    turn: int | None = None
    output: int | None = None
    effect: int | None = None
    attempt: int | None = None
    executor: int | None = None
    policy_revision: int | None = None


@dataclass(frozen=True, slots=True)
class Cast(Generic[M]):
    value: M = field(repr=False)
    position: int
    origin: Origin


@dataclass(frozen=True, slots=True)
class Call(Generic[M]):
    value: M = field(repr=False)
    position: int
    origin: Origin
    correlation: int


@dataclass(frozen=True, slots=True)
class Reply(Generic[M]):
    value: M = field(repr=False)
    position: int
    origin: Origin
    correlation: int


type Incoming[M] = Cast[M] | Call[M] | Reply[M]


@dataclass(frozen=True, slots=True)
class Control:
    kind: str
    position: int
    origin: Origin
    correlation: int


@dataclass(frozen=True, slots=True)
class FrozenMutation:
    identity: OperationIdentity
    purpose: str
    input_position: int
    _bytes: bytes = field(repr=False)
    def export(self) -> bytes:
        return self._bytes


class RecoveryStore(Protocol):
    def before_dispatch(self, mutation: FrozenMutation) -> None: ...
    def confirmed(self, identity: OperationIdentity, receipt: MutationReceipt) -> None: ...


@dataclass(frozen=True, slots=True)
class Recovery:
    store: RecoveryStore | None = field(repr=False)
    @classmethod
    def persist_before_dispatch(cls, store: RecoveryStore) -> Recovery:
        if not callable(getattr(store, 'before_dispatch', None)) or not callable(getattr(store, 'confirmed', None)):
            raise TypeError('Recovery store must implement both persistence hooks')
        return cls(store)
    @classmethod
    def fence_on_restart(cls) -> Recovery:
        return cls(None)


@dataclass(frozen=True, slots=True)
class Committed:
    input_position: int
    receipt: MutationReceipt


@dataclass(frozen=True, slots=True)
class Blocked:
    input_position: int | None
    receipt: MutationReceipt | None


@dataclass(frozen=True, slots=True)
class NeedsRecovery:
    mutation: FrozenMutation
    phase: str
    error: Exception = field(repr=False)
    receipt: MutationReceipt | None = None


@dataclass(frozen=True, slots=True)
class Idle:
    pass


@dataclass(frozen=True, slots=True)
class Progress:
    pass


@dataclass(frozen=True, slots=True)
class Stopped:
    pass


type RunnerEvent = Committed | Blocked | NeedsRecovery | Idle | Progress | Stopped

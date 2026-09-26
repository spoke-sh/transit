"""Version-one example formats specified by examples/station-sdk/README.md."""
from dataclasses import dataclass
from typing import Generic, TypeVar, cast
from transit_station import Codec


def bounded(value: int, low: int, high: int) -> int:
    if type(value) is not int or not low <= value <= high:
        raise ValueError('Integer outside the application format')
    return value


@dataclass(frozen=True, slots=True)
class Add:
    value: int
    def __post_init__(self) -> None: bounded(self.value, 0, 2**64 - 1)


@dataclass(frozen=True, slots=True)
class Read: pass


@dataclass(frozen=True, slots=True)
class Start: pass


@dataclass(frozen=True, slots=True)
class Total:
    value: int
    def __post_init__(self) -> None: bounded(self.value, 0, 2**64 - 1)


type CounterMessage = Add | Read | Start | Total


class CounterCodec:
    type_id = 'transit.examples.counter'
    version = 1
    max_encoded_bytes = 13
    def encode(self, value: CounterMessage) -> bytes:
        tag = {Add: 1, Read: 2, Start: 3, Total: 4}.get(type(value))
        if tag is None: raise ValueError('Unsupported counter message')
        data = b'TSC\x01' + bytes([tag])
        if isinstance(value, (Add, Total)):
            data += bounded(value.value, 0, 2**64-1).to_bytes(8, 'little')
        return data
    def decode(self, data: bytes) -> CounterMessage:
        if type(data) is not bytes or len(data) < 5 or data[:4] != b'TSC\x01':
            raise ValueError('Unsupported counter format')
        tag = data[4]
        if tag in (1, 4) and len(data) == 13:
            value = int.from_bytes(data[5:], 'little')
            return Add(value) if tag == 1 else Total(value)
        if tag == 2 and len(data) == 5: return Read()
        if tag == 3 and len(data) == 5: return Start()
        raise ValueError('Invalid counter message')


class U64Codec:
    type_id = 'transit.examples.u64'
    version = 1
    max_encoded_bytes = 12
    def encode(self, value: int) -> bytes:
        return b'TSU\x01' + bounded(value, 0, 2**64-1).to_bytes(8, 'little')
    def decode(self, data: bytes) -> int:
        if type(data) is not bytes or len(data) != 12 or data[:4] != b'TSU\x01':
            raise ValueError('Invalid u64 value')
        return int.from_bytes(data[4:], 'little')


@dataclass(frozen=True, slots=True)
class Initialize: pass


@dataclass(frozen=True, slots=True)
class Insert:
    key: int
    value: int | None
    def __post_init__(self) -> None:
        bounded(self.key, -(2**63), 2**63-1)
        if self.value is not None: bounded(self.value, -(2**63), 2**63-1)


@dataclass(frozen=True, slots=True)
class Rows: pass


type QueryMessage = Initialize | Insert | Rows | Start


class QueryCodec:
    type_id = 'transit.examples.query'
    version = 1
    max_encoded_bytes = 22
    def encode(self, value: QueryMessage) -> bytes:
        tag = {Initialize: 1, Insert: 2, Rows: 3, Start: 4}.get(type(value))
        if tag is None: raise ValueError('Unsupported query message')
        data = b'TSQ\x01' + bytes([tag])
        if isinstance(value, Insert):
            data += bounded(value.key, -(2**63), 2**63-1).to_bytes(8, 'little', signed=True)
            data += b'\0' if value.value is None else b'\1' + bounded(value.value, -(2**63), 2**63-1).to_bytes(8, 'little', signed=True)
        return data
    def decode(self, data: bytes) -> QueryMessage:
        if type(data) is not bytes or len(data) < 5 or data[:4] != b'TSQ\x01':
            raise ValueError('Unsupported query format')
        tag = data[4]
        if len(data) == 5 and tag in (1, 3, 4):
            return Initialize() if tag == 1 else Rows() if tag == 3 else Start()
        if tag == 2 and len(data) in (14, 22):
            key = int.from_bytes(data[5:13], 'little', signed=True)
            if data[13] == 0 and len(data) == 14: return Insert(key, None)
            if data[13] == 1 and len(data) == 22: return Insert(key, int.from_bytes(data[14:], 'little', signed=True))
        raise ValueError('Invalid query message')


T = TypeVar('T')
W = TypeVar('W')


class Selected(Generic[T, W]):
    def __init__(self, base: Codec[W], variants: tuple[type[object], ...]) -> None:
        self.base, self.variants = base, variants
        self.type_id, self.version, self.max_encoded_bytes = base.type_id, base.version, base.max_encoded_bytes
    def encode(self, value: T) -> bytes:
        if type(value) not in self.variants: raise ValueError('Message not accepted by this role')
        return self.base.encode(cast(W, value))
    def decode(self, data: bytes) -> T:
        value = self.base.decode(data)
        if type(value) not in self.variants: raise ValueError('Message not accepted by this role')
        return cast(T, value)


counter = CounterCodec()
u64 = U64Codec()
query = QueryCodec()
counter_codec: Codec[Add | Read] = Selected(counter, (Add, Read))
requester_codec: Codec[Start | Total] = Selected(counter, (Start, Total))
total_codec: Codec[Total] = Selected(counter, (Total,))
query_service_codec: Codec[Initialize | Insert | Rows] = Selected(query, (Initialize, Insert, Rows))
query_requester_codec: Codec[Start] = Selected(query, (Start,))

"""Bounded application records for a durable FIFO; no native framework codecs."""
from dataclasses import dataclass
from transit_station import Key
from .codecs import Initialize, Insert, Update, Delete, query, bounded

MAX_INPUT = 2**53 - 1
INITIAL = 2**64 - 1
REJECTIONS = ('none', 'row_exists', 'row_identity_exists', 'null_not_allowed',
              'missing_required_field', 'character_limit_exceeded', 'overflow', 'inexact')


@dataclass(frozen=True, slots=True)
class Queue:
    head: int = 0
    tail: int = 0
    ready: bool = False


@dataclass(frozen=True, slots=True)
class Work:
    next: int
    command: Initialize | Insert | Update | Delete


@dataclass(frozen=True, slots=True)
class Outcome:
    # 0 creation applied; 1 DML applied; 2 rejected; 3 cancelled.
    state: int
    admitted: int
    completed: int
    matched: int = 0
    changed: int = 0
    rejection: int = 0


class QueueCodec:
    type_id = 'transit.examples.table.queue'
    version = 1
    max_encoded_bytes = 21
    def encode(self, value: Queue) -> bytes:
        bounded(value.head, 0, INITIAL); bounded(value.tail, 0, MAX_INPUT)
        if (value.head == 0) != (value.tail == 0) or (value.head != INITIAL and value.head > value.tail):
            raise ValueError('Invalid Table queue endpoints')
        if type(value.ready) is not bool or (value.head == INITIAL and value.ready): raise ValueError('Invalid Table queue state')
        return b'TQM\x01' + value.head.to_bytes(8, 'little') + value.tail.to_bytes(8, 'little') + bytes([value.ready])
    def decode(self, data: bytes) -> Queue:
        if type(data) is not bytes or len(data) != 21 or data[:4] != b'TQM\x01' or data[20] > 1: raise ValueError('Invalid Table queue')
        value = Queue(int.from_bytes(data[4:12], 'little'), int.from_bytes(data[12:20], 'little'), bool(data[20]))
        if self.encode(value) != data: raise ValueError('Noncanonical Table queue')
        return value


class WorkCodec:
    type_id = 'transit.examples.table.work'
    version = 1
    max_encoded_bytes = 34
    def encode(self, value: Work) -> bytes:
        bounded(value.next, 0, MAX_INPUT)
        if not isinstance(value.command, (Initialize, Insert, Update, Delete)): raise ValueError('Invalid queued command')
        return b'TQW\x01' + value.next.to_bytes(8, 'little') + query.encode(value.command)
    def decode(self, data: bytes) -> Work:
        if type(data) is not bytes or len(data) not in (17, 25, 26, 34) or data[:4] != b'TQW\x01': raise ValueError('Invalid Table work')
        command = query.decode(data[12:])
        if not isinstance(command, (Initialize, Insert, Update, Delete)): raise ValueError('Invalid queued command')
        value = Work(int.from_bytes(data[4:12], 'little'), command)
        if self.encode(value) != data: raise ValueError('Noncanonical Table work')
        return value


class OutcomeCodec:
    type_id = 'transit.examples.table.outcome'
    version = 1
    max_encoded_bytes = 38
    def encode(self, value: Outcome) -> bytes:
        bounded(value.state, 0, 3); bounded(value.admitted, 1, MAX_INPUT); bounded(value.completed, value.admitted, MAX_INPUT)
        bounded(value.matched, 0, INITIAL); bounded(value.changed, 0, value.matched); bounded(value.rejection, 0, len(REJECTIONS)-1)
        if (value.state != 1 and (value.matched or value.changed)) or (value.state == 2) != (value.rejection != 0): raise ValueError('Invalid Table outcome')
        return b'TQO\x01' + bytes([value.state]) + b''.join(v.to_bytes(8, 'little') for v in (value.admitted, value.completed, value.matched, value.changed)) + bytes([value.rejection])
    def decode(self, data: bytes) -> Outcome:
        if type(data) is not bytes or len(data) != 38 or data[:4] != b'TQO\x01': raise ValueError('Invalid Table outcome')
        fields = [int.from_bytes(data[i:i+8], 'little') for i in (5, 13, 21, 29)]
        value = Outcome(data[4], fields[0], fields[1], fields[2], fields[3], data[37])
        if self.encode(value) != data: raise ValueError('Noncanonical Table outcome')
        return value


queue_codec = QueueCodec()
work_codec = WorkCodec()
outcome_codec = OutcomeCodec()
QUEUE = Key(b'table.queue', queue_codec)


def work_key(identity: int) -> Key[Work]:
    bounded(identity, 1, INITIAL)
    return Key(f'table.work.{identity:016x}'.encode('ascii'), work_codec)


def outcome_key(identity: int) -> Key[Outcome]:
    bounded(identity, 1, INITIAL)
    return Key(f'table.done.{identity:016x}'.encode('ascii'), outcome_codec)

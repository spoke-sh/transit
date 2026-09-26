"""A Table service and requester consuming original bounded IPC segments."""
from collections.abc import Callable
from transit_client import ProcessRef
from transit_client.errors import HandlerError
from transit_station import (Turn, Incoming, Cast, Call, Key, WaitPolicy, TableSchema, Row,
    QueryPlan, IpcSegment, ResultReader)
from .codecs import (Initialize, Insert, Rows, Start, u64, query_service_codec)

TABLE = TableSchema.int64(1)
REQUEST = Key(b'request', u64)
OBSERVED = Key(b'observed', u64)


class TableService:
    def __init__(self, requester: ProcessRef) -> None:
        self.requester = requester
    def initialize(self, turn: Turn) -> None:
        turn.create_table(TABLE)
        turn.allow_query(self.requester, TABLE, expected_revision=0, allow=True)
    def handle(self, turn: Turn, incoming: Incoming[Initialize | Insert | Rows]) -> None:
        value = incoming.value
        if isinstance(incoming, Cast) and isinstance(value, Initialize):
            pass
        elif isinstance(incoming, Cast) and isinstance(value, Insert):
            turn.table(TABLE).insert(Row(value.key, value.value))
        elif isinstance(incoming, Call) and isinstance(value, Rows):
            turn.start_query(TABLE, QueryPlan(limit=2**64-1))
        else:
            raise HandlerError('Unexpected Table message')


class QueryRequester:
    def __init__(self, source: ProcessRef, consume: Callable[[IpcSegment], None]) -> None:
        self.source, self.consume = source, consume
    def initialize(self, turn: Turn) -> None:
        pass
    def handle(self, turn: Turn, incoming: Incoming[Start]) -> None:
        if not isinstance(incoming, Cast) or not isinstance(incoming.value, Start):
            raise HandlerError('Expected query start')
        if turn.state.find(REQUEST) is not None:
            raise HandlerError('Query already started')
        correlation = turn.call(self.source, Rows(), codec=query_service_codec, wait=WaitPolicy.untimed())
        turn.state.put(REQUEST, correlation)
    def handle_result(self, turn: Turn, reader: ResultReader) -> None:
        complete = reader.manifest
        if complete.correlation != turn.state.require(REQUEST) or complete.source != self.source:
            raise HandlerError('Result does not match the saved request')
        # Each callback receives owned bytes. External callback effects need their
        # own idempotency policy: this private turn has not committed yet.
        for ordinal in range(complete.segments):
            self.consume(reader.segment(ordinal))
        turn.state.put(OBSERVED, complete.rows)

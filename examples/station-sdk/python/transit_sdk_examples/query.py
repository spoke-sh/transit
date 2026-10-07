"""A Table service and requester consuming original bounded IPC segments."""
from collections.abc import Callable
from transit_client import ProcessRef
from transit_client.errors import HandlerError
from transit_station import (Turn, Incoming, Cast, Call, Key, WaitPolicy, TableSchema,
    QueryPlan, IpcSegment, ResultReader)
from transit_station import Reply, TableMutation, TableCreation, TableMutationStatus
from transit_station import catalog_values as catalog, logical_values as logical
from transit_station.unified import Plan
from .codecs import (Initialize, Insert, Rows, Start, Advance, NotReady, Update, Delete, u64,
    query_service_codec, query_reply_codec)
from .table_work import (Queue, Work, Outcome, INITIAL, MAX_INPUT, REJECTIONS,
    QUEUE, work_key, outcome_key)

TABLE = TableSchema(1, 1, 5, (
    catalog.Column(1, 'id', logical.ScalarType('int64'), nullable=False),
    catalog.Column(2, 'value', logical.ScalarType('int64')),
    catalog.Column(3, 'label', logical.ScalarType('utf8'), nullable=False,
                   default=logical.Present(logical.Atom('utf8', 'example'))),
    catalog.Column(4, 'tags', logical.ListType(logical.Element(logical.ScalarType('int64'))), nullable=False,
                   default=logical.Present(logical.SequenceValue('list', (
                       logical.Present(logical.Atom('signed', 1)), logical.Present(logical.Atom('signed', 2))))))),
    (1,))
LIMITS = catalog.TableLimits(65536, 8388608, 1024)
REQUEST = Key(b'request', u64)
OBSERVED = Key(b'observed', u64)
NOT_READY = Key(b'not-ready', u64)


class TableService:
    def __init__(self, requester: ProcessRef) -> None:
        self.requester = requester
    def initialize(self, turn: Turn) -> None:
        pass
    def _queue(self, turn: Turn) -> Queue:
        found = turn.state.find(QUEUE)
        return found.value if found is not None else Queue()
    def _wake(self, turn: Turn) -> None:
        turn.cast(turn.process, Advance(), codec=query_service_codec)
    def _enqueue(self, turn: Turn, position: int, command: Initialize | Insert | Update | Delete) -> None:
        if not 1 <= position <= MAX_INPUT: raise HandlerError('Invalid original input')
        queue = self._queue(turn)
        key = work_key(position)
        if turn.state.find(key) is not None or turn.state.find(outcome_key(position)) is not None:
            raise HandlerError('Table input identity reused')
        if queue.tail:
            if position <= queue.tail: raise HandlerError('Table queue order changed')
            tail = turn.state.require(work_key(queue.tail))
            if tail.next: raise HandlerError('Invalid Table queue tail')
            turn.state.put(work_key(queue.tail), Work(position, tail.command))
            head = queue.head
        elif not queue.ready and not isinstance(command, Initialize):
            # The fixed application schema has its own initial queue entry.
            # Original mutation identities always remain admitted input positions.
            turn.state.put(work_key(INITIAL), Work(position, Initialize()))
            head = INITIAL
        else:
            head = position
        turn.state.put(key, Work(0, command))
        turn.state.put(QUEUE, Queue(head, position, queue.ready))
        if not queue.head: self._wake(turn)
    def _drive(self, turn: Turn) -> None:
        queue = self._queue(turn)
        if not queue.head: return
        work = turn.state.require(work_key(queue.head))
        if (work.next == 0) != (queue.head == queue.tail): raise HandlerError('Invalid Table queue link')
        if work.next and queue.head != INITIAL and work.next <= queue.head: raise HandlerError('Invalid Table queue order')
        status: TableCreation | TableMutationStatus
        if isinstance(work.command, Initialize):
            status = turn.create_table(TABLE, LIMITS)
        else:
            if not queue.ready or queue.head == INITIAL: raise HandlerError('Table queue is not initialized')
            spec: catalog.Mutation
            predicate = (catalog.Comparison(1, catalog.CompareOperator.EQ, logical.Atom('signed', work.command.key)),)
            if isinstance(work.command, Delete):
                spec = catalog.Delete(predicate)
            else:
                value = logical.Null() if work.command.value is None else logical.Present(logical.Atom('signed', work.command.value))
                if isinstance(work.command, Insert):
                    spec = catalog.Insert(((catalog.Assignment(1, logical.Present(logical.Atom('signed', work.command.key))), catalog.Assignment(2, value)),))
                else:
                    spec = catalog.Update((catalog.Assignment(2, value),), predicate)
            # The application format fixes TABLE's original schema. This same
            # input position and command are used in every continuation/restart.
            status = TableMutation.prepare(turn.resource, 0, queue.head, TABLE, spec).step(turn)
        if status.state == 'building':
            self._wake(turn)
            return
        initialize = isinstance(status, TableCreation)
        needed = 3 + int(initialize and not queue.ready)
        if turn.budgets.mutations < needed:
            # The applied receipt remains durable. A later step observes that
            # same receipt and finishes queue bookkeeping without a new write.
            self._wake(turn)
            return
        if status.completed_input is None: raise HandlerError('Missing Table completion')
        if isinstance(status, TableCreation):
            if status.state != 'applied': raise HandlerError('Table initialization failed')
            outcome = Outcome(0, status.admitted_input, status.completed_input)
            if not queue.ready: turn.allow_query(self.requester, TABLE.object_id, expected_revision=0, allow=True)
        else:
            code = {'applied': 1, 'rejected': 2, 'cancelled': 3}[status.state]
            counts = status.counts
            outcome = Outcome(code, status.admitted_input, status.completed_input,
                              counts.matched if counts else 0, counts.changed if counts else 0,
                              REJECTIONS.index(status.rejection))
        turn.state.put(outcome_key(queue.head), outcome)
        turn.state.delete(work_key(queue.head))
        turn.state.put(QUEUE, Queue(work.next, queue.tail if work.next else 0, queue.ready or initialize))
        if work.next: self._wake(turn)
    def handle(self, turn: Turn, incoming: Incoming[Initialize | Insert | Rows | Advance | Update | Delete]) -> None:
        value = incoming.value
        if isinstance(incoming, Cast) and isinstance(value, (Initialize, Insert, Update, Delete)):
            self._enqueue(turn, incoming.position, value)
        elif isinstance(incoming, Cast) and isinstance(value, Advance):
            if incoming.origin.kind != 'process' or incoming.origin.process != turn.process:
                raise HandlerError('Table continuation requires its recorded self output')
            self._drive(turn)
        elif isinstance(incoming, Call) and isinstance(value, Rows):
            queue = self._queue(turn)
            if not queue.ready or queue.head:
                turn.reply(NotReady(), codec=query_reply_codec)
            else:
                turn.start_query(TABLE.object_id, QueryPlan(Plan((0, 1, 2, 3), limit=2**64-1)))
        else:
            raise HandlerError('Unexpected Table message')


class QueryRequester:
    def __init__(self, source: ProcessRef, consume: Callable[[IpcSegment], None]) -> None:
        self.source, self.consume = source, consume
    def initialize(self, turn: Turn) -> None:
        pass
    def handle(self, turn: Turn, incoming: Incoming[Start | NotReady]) -> None:
        if isinstance(incoming, Reply) and isinstance(incoming.value, NotReady):
            if incoming.correlation != turn.state.require(REQUEST): raise HandlerError('Unexpected query reply')
            turn.require_reply(incoming, peer=self.source, correlation=incoming.correlation)
            turn.state.put(NOT_READY, incoming.correlation)
            return
        if not isinstance(incoming, Cast) or not isinstance(incoming.value, Start):
            raise HandlerError('Expected query start')
        previous = turn.state.find(REQUEST)
        if previous is not None and turn.state.find(NOT_READY) != previous:
            raise HandlerError('Query already started')
        correlation = turn.call(self.source, Rows(), codec=query_service_codec, wait=WaitPolicy.untimed())
        turn.state.put(REQUEST, correlation)
        if turn.state.find(NOT_READY) is not None: turn.state.delete(NOT_READY)
    def handle_result(self, turn: Turn, reader: ResultReader) -> None:
        complete = reader.manifest
        if complete.correlation != turn.state.require(REQUEST) or complete.source != self.source:
            raise HandlerError('Result does not match the saved request')
        # Each callback receives owned bytes. External callback effects need their
        # own idempotency policy: this private turn has not committed yet.
        for ordinal in range(complete.segments):
            self.consume(reader.segment(ordinal))
        turn.state.put(OBSERVED, complete.rows)

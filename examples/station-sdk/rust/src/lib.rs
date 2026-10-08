pub mod codecs;
pub mod table_work;
use codecs::*;
use std::sync::LazyLock;
use transit_client::{
    Correlation, Counter as ProtocolCounter, Error, ErrorKind, ProcessRef, Result,
};
use transit_station_sdk::{
    Aggregate, Handler, Incoming, IpcSegment, Key, Origin, QueryPlan, ResultComplete,
    TableCreationState, TableLimits, TableMutation, TableMutationState, TableSchema, Turn,
    WaitPolicy,
};

pub static TOTAL: LazyLock<Key<u64>> = LazyLock::new(|| Key::new(b"total", U64Codec).unwrap());
pub static REQUEST: LazyLock<Key<u64>> = LazyLock::new(|| Key::new(b"request", U64Codec).unwrap());
pub static OBSERVED: LazyLock<Key<u64>> =
    LazyLock::new(|| Key::new(b"observed", U64Codec).unwrap());
use table_work::{INITIAL, MAX_INPUT, METADATA, Outcome, Queue, Work, outcome_key, work_key};
use transit_station_sdk::{
    catalog as c,
    logical::{Atom, Cell, CellValue, Descriptor, Element, ScalarType},
    unified,
};
pub fn signed(value: i64) -> Cell {
    Cell::Value(CellValue::Atom(Atom::Signed(value.into())))
}
pub static TABLE: LazyLock<TableSchema> = LazyLock::new(|| {
    let int64 = Descriptor::Scalar(ScalarType::Int64);
    let mut id = c::Column::new(1, "id".into(), int64.clone());
    id.nullable = false;
    let value = c::Column::new(2, "value".into(), int64.clone());
    let mut label = c::Column::new(3, "label".into(), Descriptor::Scalar(ScalarType::Utf8));
    label.nullable = false;
    label.default = Some(Cell::Value(CellValue::Atom(Atom::Utf8("example".into()))));
    let mut tags = c::Column::new(
        4,
        "tags".into(),
        Descriptor::List(Element::new(int64, false)),
    );
    tags.nullable = false;
    tags.default = Some(Cell::Value(CellValue::List(vec![signed(1), signed(2)])));
    TableSchema {
        object: 1,
        revision: 1,
        next_column: 5,
        columns: vec![id, value, label, tags],
        primary_key: vec![1],
    }
});
pub const TABLE_LIMITS: TableLimits = TableLimits {
    record_bytes: 65536,
    staging_bytes: 8388608,
    staging_records: 1024,
};
pub static NOT_READY: LazyLock<Key<u64>> =
    LazyLock::new(|| Key::new(b"not-ready", U64Codec).unwrap());
fn unexpected() -> Error {
    Error::new(ErrorKind::Handler, "unexpected-example-message")
}
pub struct Counter;
impl Handler<CounterMessage> for Counter {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        turn.state().put(&TOTAL, &0)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<CounterMessage>) -> Result<()> {
        match input {
            Incoming::Cast {
                value: CounterMessage::Add(value),
                ..
            } => {
                let total = turn
                    .state()
                    .require(&TOTAL)?
                    .checked_add(value)
                    .ok_or_else(unexpected)?;
                turn.state().put(&TOTAL, &total)
            }
            Incoming::Call {
                value: CounterMessage::Read,
                ..
            } => {
                let total = turn.state().require(&TOTAL)?;
                turn.reply(&Total(total), &TotalCodec)
            }
            _ => Err(unexpected()),
        }
    }
}
pub struct Requester {
    pub counter: ProcessRef,
}
impl Handler<RequesterMessage> for Requester {
    fn initialize(&mut self, _turn: &mut Turn<'_>) -> Result<()> {
        Ok(())
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<RequesterMessage>) -> Result<()> {
        match input {
            Incoming::Cast {
                value: RequesterMessage::Start,
                ..
            } => {
                if turn.state().find(&REQUEST)?.is_some() {
                    return Err(Error::new(ErrorKind::Handler, "already-started"));
                }
                let correlation = turn.call(
                    self.counter,
                    &CounterMessage::Read,
                    &CounterCodec,
                    WaitPolicy::Untimed,
                )?;
                turn.state().put(&REQUEST, &correlation.get())
            }
            Incoming::Reply(reply) => {
                let RequesterMessage::Total(total) = reply.value else {
                    return Err(unexpected());
                };
                let saved = Correlation::new(turn.state().require(&REQUEST)?)?;
                turn.require_reply(&reply, self.counter, saved)?;
                turn.state().put(&OBSERVED, &total)
            }
            _ => Err(unexpected()),
        }
    }
}
pub struct TableService {
    pub requester: ProcessRef,
}
impl TableService {
    fn queue(turn: &mut Turn<'_>) -> Result<Queue> {
        Ok(turn
            .state()
            .find(&METADATA)?
            .map(|found| found.value)
            .unwrap_or_default())
    }
    fn wake(turn: &mut Turn<'_>) -> Result<()> {
        turn.cast(turn.process(), &QueryMessage::Advance, &QueryCodec)
    }
    fn enqueue(turn: &mut Turn<'_>, identity: u64, command: QueryMessage) -> Result<()> {
        if identity == 0 || identity > MAX_INPUT {
            return Err(unexpected());
        }
        let queue = Self::queue(turn)?;
        let key = work_key(identity)?;
        if turn.state().find(&key)?.is_some()
            || turn.state().find(&outcome_key(identity)?)?.is_some()
        {
            return Err(unexpected());
        }
        let mut head = identity;
        if queue.tail != 0 {
            if identity <= queue.tail {
                return Err(unexpected());
            }
            let tail = turn.state().require(&work_key(queue.tail)?)?;
            if tail.next != 0 {
                return Err(unexpected());
            }
            turn.state().put(
                &work_key(queue.tail)?,
                &Work {
                    next: identity,
                    command: tail.command,
                },
            )?;
            head = queue.head;
        } else if !queue.ready && command != QueryMessage::Initialize {
            turn.state().put(
                &work_key(INITIAL)?,
                &Work {
                    next: identity,
                    command: QueryMessage::Initialize,
                },
            )?;
            head = INITIAL;
        }
        turn.state().put(&key, &Work { next: 0, command })?;
        turn.state().put(
            &METADATA,
            &Queue {
                head,
                tail: identity,
                ready: queue.ready,
            },
        )?;
        if queue.head == 0 {
            Self::wake(turn)?;
        }
        Ok(())
    }
    fn step(turn: &mut Turn<'_>, queue: Queue, command: QueryMessage) -> Result<Option<Outcome>> {
        if command == QueryMessage::Initialize {
            let status = turn.create_table(&TABLE, &TABLE_LIMITS)?;
            if status.state == TableCreationState::Building {
                return Ok(None);
            }
            return Ok(Some(Outcome {
                state: 0,
                admitted: status.admitted_input.get(),
                completed: status.completed_input.ok_or_else(unexpected)?.get(),
                ..Outcome::default()
            }));
        }
        if !queue.ready || queue.head == INITIAL {
            return Err(unexpected());
        }
        let key = match command {
            QueryMessage::Insert { key, .. }
            | QueryMessage::Update { key, .. }
            | QueryMessage::Delete { key } => key,
            _ => return Err(unexpected()),
        };
        let predicate = Some(vec![c::Predicate::Compare {
            column: 1,
            op: c::CompareOperator::Eq,
            value: Atom::Signed(key.into()),
        }]);
        let assignment = |column, cell| c::Assignment {
            column,
            value: c::AssignmentValue::Cell(cell),
        };
        let mutation = match command {
            QueryMessage::Insert { value, .. } => c::Mutation::Insert {
                rows: vec![vec![
                    assignment(1, signed(key)),
                    assignment(2, value.map_or(Cell::Null, signed)),
                ]],
            },
            QueryMessage::Update { value, .. } => c::Mutation::Update {
                assignments: vec![assignment(2, value.map_or(Cell::Null, signed))],
                predicate,
            },
            QueryMessage::Delete { .. } => c::Mutation::Delete { predicate },
            _ => return Err(unexpected()),
        };
        let status = TableMutation::prepare(
            turn.resource(),
            ProtocolCounter::new(0)?,
            queue.head,
            &TABLE,
            &mutation,
        )?
        .step(turn)?;
        let state = match status.state {
            TableMutationState::Building => return Ok(None),
            TableMutationState::Applied => 1,
            TableMutationState::Rejected => 2,
            TableMutationState::Cancelled => 3,
        };
        Ok(Some(Outcome {
            state,
            admitted: status.admitted_input.get(),
            completed: status.completed_input.ok_or_else(unexpected)?.get(),
            matched: status.counts.as_ref().map_or(0, |c| c.matched),
            changed: status.counts.as_ref().map_or(0, |c| c.changed),
            rejection: status.rejection as u8,
        }))
    }
    fn drive(&self, turn: &mut Turn<'_>) -> Result<()> {
        let queue = Self::queue(turn)?;
        if queue.head == 0 {
            return Ok(());
        }
        let work = turn.state().require(&work_key(queue.head)?)?;
        if (work.next == 0) != (queue.head == queue.tail)
            || (work.next != 0 && queue.head != INITIAL && work.next <= queue.head)
        {
            return Err(unexpected());
        }
        let outcome = Self::step(turn, queue, work.command)?;
        let initialize = work.command == QueryMessage::Initialize;
        let Some(outcome) = outcome else {
            return Self::wake(turn);
        };
        if turn.budgets()?.mutations < 3 + usize::from(initialize && !queue.ready) {
            return Self::wake(turn);
        }
        if initialize && !queue.ready {
            turn.allow_query(self.requester, TABLE.object, 0, true)?;
        }
        turn.state().put(&outcome_key(queue.head)?, &outcome)?;
        turn.state().delete(&work_key(queue.head)?)?;
        turn.state().put(
            &METADATA,
            &Queue {
                head: work.next,
                tail: if work.next == 0 { 0 } else { queue.tail },
                ready: queue.ready || initialize,
            },
        )?;
        if work.next != 0 {
            Self::wake(turn)?;
        }
        Ok(())
    }
}
impl Handler<QueryMessage> for TableService {
    fn initialize(&mut self, _turn: &mut Turn<'_>) -> Result<()> {
        Ok(())
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<QueryMessage>) -> Result<()> {
        match input {
            Incoming::Cast {
                value:
                    command @ (QueryMessage::Initialize
                    | QueryMessage::Insert { .. }
                    | QueryMessage::Update { .. }
                    | QueryMessage::Delete { .. }),
                position,
                ..
            } => Self::enqueue(turn, position.get(), command),
            Incoming::Cast {
                value: QueryMessage::Advance,
                origin: Origin::Process { process, .. },
                ..
            } if process == turn.process() => self.drive(turn),
            Incoming::Call {
                value: QueryMessage::Rows,
                ..
            } => {
                let queue = Self::queue(turn)?;
                if !queue.ready || queue.head != 0 {
                    return turn.reply(&QueryStart::NotReady, &QueryStartCodec);
                }
                turn.start_query(
                    TABLE.object,
                    &QueryPlan::new(&unified::Plan {
                        projection: vec![0, 1, 2, 3],
                        output_names: None,
                        predicate: unified::Predicate::All,
                        limit: Some(u64::MAX),
                        aggregate: Aggregate::Rows,
                    })?,
                )
                .map(|_| ())
            }
            _ => Err(unexpected()),
        }
    }
}
pub struct QueryRequester<F> {
    pub source: ProcessRef,
    pub consume: F,
}
impl<F: FnMut(IpcSegment) -> Result<()> + Send + 'static> Handler<QueryStart>
    for QueryRequester<F>
{
    fn initialize(&mut self, _turn: &mut Turn<'_>) -> Result<()> {
        Ok(())
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<QueryStart>) -> Result<()> {
        match input {
            Incoming::Reply(reply) if reply.value == QueryStart::NotReady => {
                let saved = Correlation::new(turn.state().require(&REQUEST)?)?;
                turn.require_reply(&reply, self.source, saved)?;
                return turn.state().put(&NOT_READY, &reply.correlation.get());
            }
            Incoming::Cast {
                value: QueryStart::Start,
                ..
            } => {}
            _ => return Err(unexpected()),
        }
        let previous = turn.state().find(&REQUEST)?.map(|found| found.value);
        let not_ready = turn.state().find(&NOT_READY)?.map(|found| found.value);
        if previous.is_some() && previous != not_ready {
            return Err(unexpected());
        }
        let correlation = turn.call(
            self.source,
            &QueryMessage::Rows,
            &QueryCodec,
            WaitPolicy::Untimed,
        )?;
        turn.state().put(&REQUEST, &correlation.get())?;
        if not_ready.is_some() {
            turn.state().delete(&NOT_READY)?;
        }
        Ok(())
    }
    fn handle_result(&mut self, turn: &mut Turn<'_>, complete: ResultComplete) -> Result<()> {
        let expected = turn.state().require(&REQUEST)?;
        let manifest = {
            let mut reader = turn.result(complete.correlation)?;
            let manifest = reader.manifest()?;
            if manifest.correlation.get() != expected || manifest.source != self.source {
                return Err(unexpected());
            }
            // Callback effects need their own idempotency policy: this turn is private.
            for ordinal in 0..manifest.segments {
                (self.consume)(reader.segment(ordinal)?)?;
            }
            manifest
        };
        turn.state().put(&OBSERVED, &manifest.rows)
    }
}

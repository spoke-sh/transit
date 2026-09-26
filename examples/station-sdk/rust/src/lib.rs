pub mod codecs;
use codecs::*;
use std::sync::LazyLock;
use transit_client::{
    Correlation, Counter as ProtocolCounter, Error, ErrorKind, ProcessRef, Result,
};
use transit_station_sdk::{
    Handler, Incoming, IpcSegment, Key, QueryPlan, ResultComplete, Row, TableSchema, Turn,
    WaitPolicy,
};

pub static TOTAL: LazyLock<Key<u64>> = LazyLock::new(|| Key::new(b"total", U64Codec).unwrap());
pub static REQUEST: LazyLock<Key<u64>> = LazyLock::new(|| Key::new(b"request", U64Codec).unwrap());
pub static OBSERVED: LazyLock<Key<u64>> =
    LazyLock::new(|| Key::new(b"observed", U64Codec).unwrap());
pub static TABLE: LazyLock<TableSchema<i64>> = LazyLock::new(|| TableSchema::int64(1).unwrap());
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
impl Handler<QueryMessage> for TableService {
    fn initialize(&mut self, turn: &mut Turn<'_>) -> Result<()> {
        turn.create_table(&TABLE)?;
        turn.allow_query(self.requester, &TABLE, ProtocolCounter::new(0)?, true)
    }
    fn handle(&mut self, turn: &mut Turn<'_>, input: Incoming<QueryMessage>) -> Result<()> {
        match input {
            Incoming::Cast {
                value: QueryMessage::Initialize,
                ..
            } => Ok(()),
            Incoming::Cast {
                value: QueryMessage::Insert { key, value },
                ..
            } => turn.table(&TABLE)?.insert(&Row { key, value }),
            Incoming::Call {
                value: QueryMessage::Rows,
                ..
            } => turn
                .start_query(
                    &TABLE,
                    &QueryPlan {
                        limit: Some(u64::MAX),
                        ..QueryPlan::default()
                    },
                )
                .map(|_| ()),
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
        if !matches!(
            input,
            Incoming::Cast {
                value: QueryStart,
                ..
            }
        ) {
            return Err(unexpected());
        }
        if turn.state().find(&REQUEST)?.is_some() {
            return Err(Error::new(ErrorKind::Handler, "query-already-started"));
        }
        let correlation = turn.call(
            self.source,
            &QueryMessage::Rows,
            &QueryCodec,
            WaitPolicy::Untimed,
        )?;
        turn.state().put(&REQUEST, &correlation.get())
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

//! Bounded application FIFO records, independent of native Table storage.
use crate::codecs::{QueryCodec, QueryMessage};
use std::sync::LazyLock;
use transit_client::{Error, ErrorKind, Result};
use transit_station_sdk::{Codec, Key};

pub const MAX_INPUT: u64 = (1 << 53) - 1;
pub const INITIAL: u64 = u64::MAX;
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Queue {
    pub head: u64,
    pub tail: u64,
    pub ready: bool,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Work {
    pub next: u64,
    pub command: QueryMessage,
}
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct Outcome {
    pub state: u8,
    pub admitted: u64,
    pub completed: u64,
    pub matched: u64,
    pub changed: u64,
    pub rejection: u8,
}
fn invalid() -> Error {
    Error::new(ErrorKind::Codec, "example-table-record")
}
fn prefix(bytes: &[u8], tag: u8, lengths: &[usize]) -> Result<()> {
    if !lengths.contains(&bytes.len()) || bytes[..4] != [b'T', b'Q', tag, 1] {
        return Err(invalid());
    }
    Ok(())
}
fn get(bytes: &[u8], offset: usize) -> u64 {
    u64::from_le_bytes(bytes[offset..offset + 8].try_into().unwrap())
}
#[derive(Clone, Copy)]
pub struct QueueCodec;
impl Codec<Queue> for QueueCodec {
    fn type_id(&self) -> &str {
        "transit.examples.table.queue"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        21
    }
    fn encode(&self, value: &Queue) -> Result<Vec<u8>> {
        if value.tail > MAX_INPUT
            || (value.head == 0) != (value.tail == 0)
            || (value.head != INITIAL && value.head > value.tail)
            || (value.head == INITIAL && value.ready)
        {
            return Err(invalid());
        }
        let mut bytes = b"TQM\x01".to_vec();
        bytes.extend_from_slice(&value.head.to_le_bytes());
        bytes.extend_from_slice(&value.tail.to_le_bytes());
        bytes.push(u8::from(value.ready));
        Ok(bytes)
    }
    fn decode(&self, bytes: &[u8]) -> Result<Queue> {
        prefix(bytes, b'M', &[21])?;
        if bytes[20] > 1 {
            return Err(invalid());
        }
        let value = Queue {
            head: get(bytes, 4),
            tail: get(bytes, 12),
            ready: bytes[20] == 1,
        };
        self.encode(&value)?;
        Ok(value)
    }
}
#[derive(Clone, Copy)]
pub struct WorkCodec;
impl Codec<Work> for WorkCodec {
    fn type_id(&self) -> &str {
        "transit.examples.table.work"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        34
    }
    fn encode(&self, value: &Work) -> Result<Vec<u8>> {
        if value.next > MAX_INPUT
            || !matches!(
                value.command,
                QueryMessage::Initialize
                    | QueryMessage::Insert { .. }
                    | QueryMessage::Update { .. }
                    | QueryMessage::Delete { .. }
            )
        {
            return Err(invalid());
        }
        let mut bytes = b"TQW\x01".to_vec();
        bytes.extend_from_slice(&value.next.to_le_bytes());
        bytes.extend(QueryCodec.encode(&value.command)?);
        Ok(bytes)
    }
    fn decode(&self, bytes: &[u8]) -> Result<Work> {
        prefix(bytes, b'W', &[17, 25, 26, 34])?;
        let value = Work {
            next: get(bytes, 4),
            command: QueryCodec.decode(&bytes[12..])?,
        };
        self.encode(&value)?;
        Ok(value)
    }
}
#[derive(Clone, Copy)]
pub struct OutcomeCodec;
impl Codec<Outcome> for OutcomeCodec {
    fn type_id(&self) -> &str {
        "transit.examples.table.outcome"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        38
    }
    fn encode(&self, value: &Outcome) -> Result<Vec<u8>> {
        if value.state > 3
            || value.admitted == 0
            || value.completed < value.admitted
            || value.completed > MAX_INPUT
            || value.changed > value.matched
            || value.rejection > 7
            || (value.state != 1 && (value.matched != 0 || value.changed != 0))
            || (value.state == 2) != (value.rejection != 0)
        {
            return Err(invalid());
        }
        let mut bytes = b"TQO\x01".to_vec();
        bytes.push(value.state);
        for number in [
            value.admitted,
            value.completed,
            value.matched,
            value.changed,
        ] {
            bytes.extend_from_slice(&number.to_le_bytes());
        }
        bytes.push(value.rejection);
        Ok(bytes)
    }
    fn decode(&self, bytes: &[u8]) -> Result<Outcome> {
        prefix(bytes, b'O', &[38])?;
        let value = Outcome {
            state: bytes[4],
            admitted: get(bytes, 5),
            completed: get(bytes, 13),
            matched: get(bytes, 21),
            changed: get(bytes, 29),
            rejection: bytes[37],
        };
        self.encode(&value)?;
        Ok(value)
    }
}
pub static METADATA: LazyLock<Key<Queue>> =
    LazyLock::new(|| Key::new(b"table.queue", QueueCodec).unwrap());
pub fn work_key(identity: u64) -> Result<Key<Work>> {
    if identity == 0 {
        return Err(invalid());
    }
    Key::new(format!("table.work.{identity:016x}").as_bytes(), WorkCodec)
}
pub fn outcome_key(identity: u64) -> Result<Key<Outcome>> {
    if identity == 0 {
        return Err(invalid());
    }
    Key::new(
        format!("table.done.{identity:016x}").as_bytes(),
        OutcomeCodec,
    )
}

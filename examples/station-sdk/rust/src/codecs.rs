use transit_client::{Error, ErrorKind, Result};
use transit_station_sdk::Codec;

fn invalid() -> Error {
    Error::new(ErrorKind::Codec, "example-format")
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CounterValue {
    Add(u64),
    Read,
    Start,
    Total(u64),
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CounterMessage {
    Add(u64),
    Read,
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum RequesterMessage {
    Start,
    Total(u64),
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Total(pub u64);
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum QueryValue {
    Initialize,
    Insert { key: i64, value: Option<i64> },
    Rows,
    Start,
    Advance,
    NotReady,
    Update { key: i64, value: Option<i64> },
    Delete { key: i64 },
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum QueryMessage {
    Initialize,
    Insert { key: i64, value: Option<i64> },
    Rows,
    Advance,
    Update { key: i64, value: Option<i64> },
    Delete { key: i64 },
}
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum QueryStart {
    Start,
    NotReady,
}

#[derive(Clone, Copy)]
pub struct CounterFormat;
impl Codec<CounterValue> for CounterFormat {
    fn type_id(&self) -> &str {
        "transit.examples.counter"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        13
    }
    fn encode(&self, value: &CounterValue) -> Result<Vec<u8>> {
        let mut bytes = b"TSC\x01".to_vec();
        bytes.push(match value {
            CounterValue::Add(_) => 1,
            CounterValue::Read => 2,
            CounterValue::Start => 3,
            CounterValue::Total(_) => 4,
        });
        if let CounterValue::Add(value) | CounterValue::Total(value) = value {
            bytes.extend_from_slice(&value.to_le_bytes());
        }
        Ok(bytes)
    }
    fn decode(&self, bytes: &[u8]) -> Result<CounterValue> {
        if bytes.len() < 5 || !bytes.starts_with(b"TSC\x01") {
            return Err(invalid());
        }
        match (bytes[4], bytes.len()) {
            (1, 13) => Ok(CounterValue::Add(u64::from_le_bytes(
                bytes[5..].try_into().unwrap(),
            ))),
            (2, 5) => Ok(CounterValue::Read),
            (3, 5) => Ok(CounterValue::Start),
            (4, 13) => Ok(CounterValue::Total(u64::from_le_bytes(
                bytes[5..].try_into().unwrap(),
            ))),
            _ => Err(invalid()),
        }
    }
}
#[derive(Clone, Copy)]
pub struct U64Codec;
impl Codec<u64> for U64Codec {
    fn type_id(&self) -> &str {
        "transit.examples.u64"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        12
    }
    fn encode(&self, value: &u64) -> Result<Vec<u8>> {
        let mut bytes = b"TSU\x01".to_vec();
        bytes.extend_from_slice(&value.to_le_bytes());
        Ok(bytes)
    }
    fn decode(&self, bytes: &[u8]) -> Result<u64> {
        if bytes.len() != 12 || !bytes.starts_with(b"TSU\x01") {
            return Err(invalid());
        }
        Ok(u64::from_le_bytes(bytes[4..].try_into().unwrap()))
    }
}
#[derive(Clone, Copy)]
pub struct QueryFormat;
impl Codec<QueryValue> for QueryFormat {
    fn type_id(&self) -> &str {
        "transit.examples.query"
    }
    fn version(&self) -> u32 {
        1
    }
    fn max_encoded_bytes(&self) -> usize {
        22
    }
    fn encode(&self, value: &QueryValue) -> Result<Vec<u8>> {
        let mut bytes = b"TSQ\x01".to_vec();
        bytes.push(match value {
            QueryValue::Initialize => 1,
            QueryValue::Insert { .. } => 2,
            QueryValue::Rows => 3,
            QueryValue::Start => 4,
            QueryValue::Advance => 5,
            QueryValue::NotReady => 6,
            QueryValue::Update { .. } => 7,
            QueryValue::Delete { .. } => 8,
        });
        if let QueryValue::Insert { key, value } | QueryValue::Update { key, value } = value {
            bytes.extend_from_slice(&key.to_le_bytes());
            bytes.push(u8::from(value.is_some()));
            if let Some(value) = value {
                bytes.extend_from_slice(&value.to_le_bytes());
            }
        }
        if let QueryValue::Delete { key } = value {
            bytes.extend_from_slice(&key.to_le_bytes());
        }
        Ok(bytes)
    }
    fn decode(&self, bytes: &[u8]) -> Result<QueryValue> {
        if bytes.len() < 5 || !bytes.starts_with(b"TSQ\x01") {
            return Err(invalid());
        }
        match (bytes[4], bytes.len()) {
            (1, 5) => Ok(QueryValue::Initialize),
            (3, 5) => Ok(QueryValue::Rows),
            (4, 5) => Ok(QueryValue::Start),
            (5, 5) => Ok(QueryValue::Advance),
            (6, 5) => Ok(QueryValue::NotReady),
            (8, 13) => Ok(QueryValue::Delete {
                key: i64::from_le_bytes(bytes[5..13].try_into().unwrap()),
            }),
            (2 | 7, 14 | 22)
                if (bytes[13] == 0 && bytes.len() == 14)
                    || (bytes[13] == 1 && bytes.len() == 22) =>
            {
                let key = i64::from_le_bytes(bytes[5..13].try_into().unwrap());
                let value = if bytes[13] == 0 {
                    None
                } else {
                    Some(i64::from_le_bytes(bytes[14..].try_into().unwrap()))
                };
                Ok(if bytes[4] == 2 {
                    QueryValue::Insert { key, value }
                } else {
                    QueryValue::Update { key, value }
                })
            }
            _ => Err(invalid()),
        }
    }
}
macro_rules! selected {
    ($name:ident,$type:ty,$base:ident,$encode:expr,$decode:expr) => {
        #[derive(Clone, Copy)]
        pub struct $name;
        impl Codec<$type> for $name {
            fn type_id(&self) -> &str {
                $base.type_id()
            }
            fn version(&self) -> u32 {
                $base.version()
            }
            fn max_encoded_bytes(&self) -> usize {
                $base.max_encoded_bytes()
            }
            fn encode(&self, value: &$type) -> Result<Vec<u8>> {
                $base.encode(&($encode)(*value))
            }
            fn decode(&self, bytes: &[u8]) -> Result<$type> {
                ($decode)($base.decode(bytes)?)
            }
        }
    };
}
selected!(
    CounterCodec,
    CounterMessage,
    CounterFormat,
    |value| match value {
        CounterMessage::Add(value) => CounterValue::Add(value),
        CounterMessage::Read => CounterValue::Read,
    },
    |value| match value {
        CounterValue::Add(value) => Ok(CounterMessage::Add(value)),
        CounterValue::Read => Ok(CounterMessage::Read),
        _ => Err(invalid()),
    }
);
selected!(
    RequesterCodec,
    RequesterMessage,
    CounterFormat,
    |value| match value {
        RequesterMessage::Start => CounterValue::Start,
        RequesterMessage::Total(value) => CounterValue::Total(value),
    },
    |value| match value {
        CounterValue::Start => Ok(RequesterMessage::Start),
        CounterValue::Total(value) => Ok(RequesterMessage::Total(value)),
        _ => Err(invalid()),
    }
);
selected!(
    TotalCodec,
    Total,
    CounterFormat,
    |value: Total| CounterValue::Total(value.0),
    |value| match value {
        CounterValue::Total(value) => Ok(Total(value)),
        _ => Err(invalid()),
    }
);
selected!(
    QueryCodec,
    QueryMessage,
    QueryFormat,
    |value| match value {
        QueryMessage::Initialize => QueryValue::Initialize,
        QueryMessage::Insert { key, value } => QueryValue::Insert { key, value },
        QueryMessage::Rows => QueryValue::Rows,
        QueryMessage::Advance => QueryValue::Advance,
        QueryMessage::Update { key, value } => QueryValue::Update { key, value },
        QueryMessage::Delete { key } => QueryValue::Delete { key },
    },
    |value| match value {
        QueryValue::Initialize => Ok(QueryMessage::Initialize),
        QueryValue::Insert { key, value } => Ok(QueryMessage::Insert { key, value }),
        QueryValue::Rows => Ok(QueryMessage::Rows),
        QueryValue::Advance => Ok(QueryMessage::Advance),
        QueryValue::Update { key, value } => Ok(QueryMessage::Update { key, value }),
        QueryValue::Delete { key } => Ok(QueryMessage::Delete { key }),
        _ => Err(invalid()),
    }
);
selected!(
    QueryStartCodec,
    QueryStart,
    QueryFormat,
    |value| match value {
        QueryStart::Start => QueryValue::Start,
        QueryStart::NotReady => QueryValue::NotReady,
    },
    |value| match value {
        QueryValue::Start => Ok(QueryStart::Start),
        QueryValue::NotReady => Ok(QueryStart::NotReady),
        _ => Err(invalid()),
    }
);

//! Typed Station composition over shared native protocol/framework semantics.
#[rustfmt::skip]
mod abi;
mod bridge;
mod query;
mod runner;
mod table;
mod turn;
mod types;
pub use bridge::encode_cast;
pub use query::{
    Aggregate, Column, Comparison, IpcSegment, Predicate, Projection, QueryCloseReason, QueryJob,
    QueryPlan, ResultComplete, ResultManifest, ResultReader,
};
pub use runner::{CloseError, Handler, Runner, Shutdown};
pub use table::{Cell, CellType, Row, Table, TableSchema, TableValue};
pub use transit_client::{Correlation, Counter};
pub use turn::{Source, State, Turn};
pub use types::*;

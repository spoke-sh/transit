//! Typed Station composition over shared native protocol/framework semantics.
#[rustfmt::skip]
mod abi;
mod bridge;
pub mod catalog;
mod document;
mod grpc;
mod http;
pub mod mutations;
mod query;
mod runner;
mod table;
mod turn;
mod types;
pub mod unified;
pub use bridge::encode_cast;
pub use grpc::{
    GrpcMessage, GrpcMetadata, GrpcMetadataValue, GrpcMethod, GrpcOutcome, GrpcPart, GrpcPartKind,
    GrpcPhase, GrpcReader, GrpcRejected, GrpcRejection, GrpcReleased, GrpcReplayPolicy, GrpcReply,
    GrpcReplyCodec, GrpcRequest, GrpcRequestOptions, GrpcShape, PreparedGrpcRequest,
    decode_grpc_reply, grpc_method, prepare_grpc,
};
pub use http::{
    HttpFollowupReason, HttpHeader, HttpMessage, HttpMethod, HttpOutcome, HttpPart, HttpPartKind,
    HttpPhase, HttpPiece, HttpReader, HttpRejected, HttpRejection, HttpReleased, HttpReplayPolicy,
    HttpReply, HttpReplyCodec, HttpRequest, HttpRequestOptions, PreparedHttpRequest,
    decode_http_reply, prepare_http,
};
pub use query::{
    Aggregate, Column, Comparison, IpcSegment, Predicate, Projection, QueryCloseReason, QueryJob,
    QueryPlan, ResultComplete, ResultManifest, ResultReader,
};
pub use runner::{CloseError, Handler, Runner, Shutdown};
pub use table::{Cell, CellType, Row, Table, TableSchema, TableValue};
pub use transit_client::{Correlation, Counter};
pub use turn::{Source, State, Turn};
pub use types::*;

pub use document::{
    DocumentAssignment, DocumentChange, DocumentDescription, DocumentDot, DocumentField,
    DocumentItem, DocumentLimits, DocumentOperation, DocumentOwner, DocumentPage, DocumentPath,
    DocumentPhase, DocumentProgress, DocumentReader, DocumentReference, DocumentResynchronization,
    DocumentStatus, DocumentValue, PreparedDocumentChange, decode_document, prepare_document,
};

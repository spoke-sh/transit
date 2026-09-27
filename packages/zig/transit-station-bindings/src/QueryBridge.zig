//! Shared owned query bridge; the ABI only owns native handles.
const b = @import("transit_query").Bridge;
pub const q = b.q;
pub const Command = b.Command;
pub const Action = b.Action;
pub const Description = b.Description;
pub const Status = b.Status;
pub const Manifest = b.Manifest;
pub const Page = b.Page;
pub const Result = b.Result;
pub const prepared = b.prepared;
pub const apply = b.apply;

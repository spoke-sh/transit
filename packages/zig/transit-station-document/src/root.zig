//! Station Document semantics. Immutable candidates are not durable acceptance.
pub const station = @import("transit_station");
pub const Model = @import("Model.zig");
pub const Change = Model.Change;
pub const Dot = Model.Dot;
pub const Scalar = Model.Scalar;
pub const Operation = Model.Operation;
pub const Client = @import("Client.zig");
pub const Checkpoint = @import("Checkpoint.zig");
pub const Service = @import("Service.zig");
pub const Request = @import("Request.zig");
pub const Remote = @import("Remote.zig");
pub const Caller = @import("Caller.zig");
pub const Document = @import("Document.zig");
pub const codec = @import("codec.zig");
test {
    _ = Client;
    _ = Checkpoint;
    _ = Service;
    _ = Service.records;
    _ = Document;
    _ = Model;
    _ = codec;
    _ = @import("merge_test.zig");
    _ = @import("service_test.zig");
    _ = @import("remote_test.zig");
}

pub const JsonValues = @import("JsonValues.zig");

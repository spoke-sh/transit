//! Station Document semantics. Immutable candidates are not durable acceptance.
pub const station = @import("transit_station");
pub const Model = @import("Model.zig");
pub const Change = Model.Change;
pub const Dot = Model.Dot;
pub const Scalar = Model.Scalar;
pub const Operation = Model.Operation;
pub const Checkpoint = @import("Checkpoint.zig");
pub const Service = @import("Service.zig");
pub const Document = @import("Document.zig");
pub const codec = @import("codec.zig");
test {
    _ = Checkpoint;
    _ = Service;
    _ = Service.records;
    _ = Document;
    _ = Model;
    _ = codec;
    _ = @import("merge_test.zig");
    _ = @import("service_test.zig");
}

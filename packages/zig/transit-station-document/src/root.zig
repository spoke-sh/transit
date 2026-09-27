//! Station Document semantics. Immutable candidates are not durable acceptance.
pub const station = @import("transit_station");
pub const Model = @import("Model.zig");
pub const Change = Model.Change;
pub const Dot = Model.Dot;
pub const Scalar = Model.Scalar;
pub const Operation = Model.Operation;
pub const Document = @import("Document.zig");
pub const codec = @import("codec.zig");
test {
    _ = Document;
    _ = Model;
    _ = codec;
    _ = @import("merge_test.zig");
}

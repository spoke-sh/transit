//! Deterministic Document changes and candidate evaluation, independent of
//! execution, persistence and authorization. A candidate is not acceptance.
pub const Model = @import("Model.zig");
pub const Bytes = @import("Bytes.zig").Bytes;
pub const Change = Model.Change;
pub const Dot = Model.Dot;
pub const Scalar = Model.Scalar;
pub const Operation = Model.Operation;
pub const codec = @import("codec.zig");
pub const Document = @import("Document.zig").Document;
test {
    _ = Model;
    _ = codec;
    _ = @import("merge_test.zig");
}

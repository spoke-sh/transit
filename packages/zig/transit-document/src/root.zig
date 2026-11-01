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
pub const SuccinctTree = @import("SuccinctTree.zig").SuccinctTree;
pub const SpanText = @import("SpanText.zig").SpanText;
pub const VersionedMerge = @import("VersionedMerge.zig");
test {
    _ = @import("logical_tree_test.zig");
    _ = Model;
    _ = codec;
    _ = @import("SuccinctTree.zig");
    _ = @import("SpanText.zig");
    _ = VersionedMerge;
    _ = @import("merge_test.zig");
    _ = @import("succinct_tree_test.zig");
    _ = @import("span_text_test.zig");
    _ = @import("versioned_merge_test.zig");
}
pub const LogicalChange = @import("LogicalChange.zig");
pub const CausalTree = @import("CausalTree.zig").CausalTree;
pub const CausalTreeChunkBytes = @import("CausalTree.zig").chunk_bytes;

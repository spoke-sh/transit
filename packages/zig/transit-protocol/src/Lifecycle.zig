//! Generic process controls. Behavior initialization and restart policy live above Transit.
const p = @import("root.zig");
pub const max_required = 4;
pub const Control = struct {
    phase: enum { initializing, ready, suspended } = .initializing,
    required: [max_required]?p.Value = @splat(null),
    resume_before_ms: ?u64 = null,
};
pub const Fence = struct { pid: u64, expected_generation: u64 };

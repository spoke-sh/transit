//! Bounded memory ownership and accounting, without clocks, I/O or domain policy.
pub const AllocationProbe = @import("AllocationProbe.zig");
test {
    _ = AllocationProbe;
}

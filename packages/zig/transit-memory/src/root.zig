//! Bounded memory ownership and accounting, without clocks, I/O or domain policy.
pub const AllocationProbe = @import("AllocationProbe.zig");
pub const Quota = @import("Quota.zig");
pub const Budget = @import("Budget.zig");
pub const Workspace = @import("Workspace.zig");
pub const Pool = @import("Pool.zig");
pub const Slab = @import("Slab.zig");
test {
    _ = AllocationProbe;
    _ = Quota;
    _ = Budget;
    _ = Workspace;
    _ = Pool;
    _ = Slab;
}

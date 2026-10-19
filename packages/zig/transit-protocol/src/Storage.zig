//! Shared runtime storage budgets. These bound private work and physical
//! allocation admission; they never authorize retention or logical expiry.
const p = @import("root.zig");
pub const max_candidate_bytes = 8 * 1024 * 1024;
pub const Limits = struct {
    bytes: u64 = 8 * 1024 * 1024 * 1024,
    control_bytes: u64 = 64 * 1024 * 1024,
    candidate_bytes: u32 = max_candidate_bytes,
    pub fn validate(self: Limits) !void {
        if (self.bytes == 0 or self.bytes > p.max_counter or self.control_bytes < 1024 * 1024 or self.control_bytes > p.max_counter or self.candidate_bytes == 0 or self.candidate_bytes > max_candidate_bytes) return error.InvalidStorageBudget;
    }
};
pub const Maintenance = struct { collection_every_records: u64 = 1024, compact: bool = false };
pub const Settings = struct { limits: Limits = .{}, maintenance: Maintenance = .{} };

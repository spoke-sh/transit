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
pub const Flush = struct {
    enabled: bool = false,
    rows: u16 = 256,
    work_rows: u16 = 32,
    bytes: u64 = 256 * 1024,
    age_ms: u32 = 5000,
    pub fn validate(self: Flush) !void {
        if (self.rows == 0 or self.rows > 1024 or self.work_rows == 0 or self.work_rows > 1024 or self.bytes == 0 or self.bytes > p.max_counter or
            self.age_ms == 0 or self.age_ms > 60000) return error.InvalidStorageBudget;
    }
};
pub const Archive = struct {
    enabled: bool = false,
    work_frames: u8 = 4,
    pub fn validate(self: Archive) !void {
        if (self.work_frames == 0 or self.work_frames > 8) return error.InvalidStorageBudget;
    }
};
pub const Maintenance = struct {
    collection_every_records: u64 = 1024,
    compact: bool = false,
    compaction_rows: u16 = 32,
    resident_bytes: u32 = 128 * 1024 * 1024,
    archive: Archive = .{},
    flush: Flush = .{},
    pub fn validate(self: Maintenance) !void {
        try self.flush.validate();
        try self.archive.validate();
        if (self.collection_every_records == 0 or self.collection_every_records > p.max_counter or
            self.compaction_rows == 0 or self.compaction_rows > 1024 or
            self.resident_bytes < 32 * 1024 * 1024 or self.resident_bytes > 512 * 1024 * 1024) return error.InvalidStorageBudget;
    }
};
pub const Settings = struct { limits: Limits = .{}, maintenance: Maintenance = .{} };

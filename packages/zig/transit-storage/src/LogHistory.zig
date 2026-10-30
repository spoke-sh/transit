//! Bounded physical log archival over the shared immutable TWAL codec. Candidates
//! remain private until the partition publishes coverage. A logical expiry and
//! dependency proof is separately required to remove any archived prefix.
const std = @import("std");
const d = @import("transit_protocol").DataLifecycle;
const Log = @import("TransitLog.zig");
const Archive = @import("TableArchive.zig");
const TreeStore = @import("TreeStore.zig");
const pages = TreeStore.pages;
pub const Limits = Archive.Limits;
pub const Coverage = struct {
    from: u64,
    through: u64,
    directory: ?pages.Reference,
    pub const empty: Coverage = .{ .from = 0, .through = 0, .directory = null };
    pub fn validate(self: Coverage, next_lsn: u64) !void {
        if (self.from > self.through or self.through >= next_lsn or (self.from == self.through) != (self.directory == null)) return error.InvalidLogArchive;
    }
};
pub const Candidate = struct { coverage: Coverage, frames: u8, bytes: u64, complete: bool };

/// Caller begins an index work budget. Each input frame and its encoded copy is
/// bounded independently of historical cardinality; no publication occurs here.
pub fn stage(allocator: std.mem.Allocator, index: *TreeStore, log: Log.Log, partition: u64, coverage: Coverage, cut: d.Position, limits: Limits) !Candidate {
    try cut.validate();
    try limits.validate();
    if (partition == 0 or cut.partition != partition or cut.next_lsn == 0 or coverage.from > coverage.through or (coverage.from == coverage.through) != (coverage.directory == null)) return error.InvalidLogArchive;
    const tree: pages.Tree(TreeStore) = .{ .store = index };
    var result: Candidate = .{ .coverage = coverage, .frames = 0, .bytes = 0, .complete = coverage.through >= cut.next_lsn };
    while (!result.complete and result.frames < limits.frames) {
        const lsn = result.coverage.through;
        var batch = try log.read(allocator, partition, lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1 or batch.frames[0].header.partition_id != partition or batch.frames[0].header.lsn != lsn) return error.LogHistoryUnavailable;
        const bytes = Log.alignedFrameSize(batch.frames[0].payload.len);
        if (bytes > limits.encoded_bytes - result.bytes) break;
        const value = try Archive.stage(allocator, index.store, batch.frames[0]);
        result.coverage.directory = try tree.put(result.coverage.directory, try Archive.key(lsn), value);
        result.coverage.through += 1;
        result.frames += 1;
        result.bytes += bytes;
        result.complete = result.coverage.through >= cut.next_lsn;
    }
    return result;
}

pub fn read(allocator: std.mem.Allocator, index: *TreeStore, coverage: Coverage, partition: u64, lsn: u64) !Log.Log.OwnedBatch {
    if (lsn < coverage.from or lsn >= coverage.through) return error.LogHistoryUnavailable;
    const tree: pages.Tree(TreeStore) = .{ .store = index };
    const value = try tree.get(coverage.directory, try Archive.key(lsn)) orelse return error.LogHistoryUnavailable;
    return Archive.readReference(allocator, index.store, value, partition, lsn);
}

/// Validate one already-staged publication step without writing objects. No
/// candidate can claim an unbounded jump or replace a previously retained cut.
pub fn verifyExtension(allocator: std.mem.Allocator, index: *TreeStore, before: Coverage, after: Coverage, partition: u64, previous_lsn: u64) !void {
    try before.validate(previous_lsn);
    try after.validate(try std.math.add(u64, previous_lsn, 1));
    if (after.from != before.from or after.through <= before.through or after.through > previous_lsn or after.through - before.through > Archive.max_frames) return error.InvalidLogArchive;
    var lsn = before.through;
    while (lsn < after.through) : (lsn += 1) {
        var archived = try read(allocator, index, after, partition, lsn);
        defer archived.deinit();
    }
}

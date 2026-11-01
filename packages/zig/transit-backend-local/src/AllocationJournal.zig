//! One bounded inventory append is a durability boundary. A maintenance
//! deadline can stop before or after it; interrupting its WAL publication would
//! unnecessarily force replacement of the shared foreground storage owner.
const std = @import("std");
const storage = @import("transit_storage");

pub fn append(comptime record_bytes: usize, io: std.Io, queue: *storage.LocalWal.LocalWal, position: u64, payloads: []const []const u8) !void {
    if (payloads.len == 0 or payloads.len > storage.TransitObjectStore.max_put_batch) return error.InvalidAllocationHistory;
    for (payloads) |payload| if (payload.len != record_bytes) return error.InvalidAllocationHistory;
    try io.checkCancel();
    const previous = io.swapCancelProtection(.blocked);
    defer _ = io.swapCancelProtection(previous);
    // Keep genuine write/sync failures and uncertain publication unchanged.
    // Protection ends before marker/object publication and the next work unit.
    _ = try queue.appendFrames(0, position, 1, 1, .manifest_checkpoint, payloads);
}

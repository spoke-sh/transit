//! Checkpoint/trim for backend-owned work ledgers. Callers supply a consumed
//! prefix; authority history has a separate signed retention decision.
const std = @import("std");
const a = @import("root.zig");
pub fn run(journal: a.Journal, floor: u64) !void {
    if (floor == 0) return;
    var metadata = try journal.send(.{ .head = .{ .stream = journal.stream } });
    defer metadata.deinit();
    try metadata.head.requireSuccess();
    const range = try metadata.head.metadata();
    const tail = range.record_next orelse return error.MissingRecordCoordinate;
    const first = range.record_first orelse return error.MissingRecordCoordinate;
    if (first >= floor) return;
    if (floor >= tail) return error.InvalidLedgerFloor;
    var record = try journal.send(.{ .read = .{ .stream = journal.stream, .options = .{ .position = .{ .record = tail - 1 }, .max_records = 1 } } });
    defer record.deinit();
    try record.head.requireSuccess();
    const read = try record.head.metadata();
    if (read.record_start != tail - 1 or read.record_next != tail or record.body.len > a.max_record_bytes) return error.InvalidLedgerFloor;
    try a.validateObject(journal.client.http.allocator, record.body);
    var saved = try journal.send(.{ .publish_snapshot = .{ .stream = journal.stream, .at = .{ .record = tail }, .body = record.body, .content_type = "application/json" } });
    defer saved.deinit();
    try saved.head.requireSuccess();
    var latest = try journal.send(.{ .read_snapshot = .{ .stream = journal.stream } });
    defer latest.deinit();
    if (latest.head.status != .temporary_redirect) return error.InvalidSnapshotResponse;
    const offset = (try latest.head.metadata()).snapshot_offset orelse return error.MissingSnapshotOffset;
    var verified = try journal.send(.{ .read_snapshot = .{ .stream = journal.stream, .offset = offset } });
    defer verified.deinit();
    try verified.head.requireSuccess();
    // A competing newer checkpoint may be valid, but this bounded attempt has
    // not verified its fields. Retry from the current ledger instead of guessing.
    if (!std.mem.eql(u8, verified.body, record.body)) return error.Conflict;
    var trimmed = try journal.send(.{ .advance_retention = .{ .stream = journal.stream, .at = .{ .record = floor } } });
    defer trimmed.deinit();
    try trimmed.head.requireSuccess();
}

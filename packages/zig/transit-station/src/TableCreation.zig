//! Resumable application-owned Table initialization. This does not publish a
//! catalog name, grant access or commit the handler's private native proposal.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Pub = @import("Publication.zig");
const Pages = @import("TablePages.zig");
const Head = @import("TableHead.zig");

pub const Result = struct { state: enum { building, applied }, admitted_input: u64, completed_input: u64 };
pub fn key(object: u64) p.Value {
    return Pages.key(object, 'c', 0);
}
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(p.Growth.current_definition)) catch unreachable;
    return bytes;
}
const Record = struct {
    intent: [32]u8,
    admitted: u64,
    completed: u64 = 0,
    fn encode(self: Record) !p.Value {
        var bytes: [84]u8 = undefined;
        bytes[0..4].* = "STC1".*;
        bytes[4..36].* = definition();
        bytes[36..68].* = self.intent;
        std.mem.writeInt(u64, bytes[68..76], self.admitted, .little);
        std.mem.writeInt(u64, bytes[76..84], self.completed, .little);
        return p.Value.init(&bytes);
    }
    fn decode(value: p.Value) !Record {
        try value.validate();
        if (value.len != 84 or !std.mem.eql(u8, value.data[0..4], "STC1")) return error.InvalidTableCreation;
        if (!std.mem.eql(u8, value.data[4..36], &definition())) return error.IncompatibleTableStorage;
        const decoded: Record = .{ .intent = value.data[36..68].*, .admitted = std.mem.readInt(u64, value.data[68..76], .little), .completed = std.mem.readInt(u64, value.data[76..84], .little) };
        if (decoded.admitted == 0 or decoded.admitted > p.max_counter or decoded.completed > p.max_counter or (decoded.completed != 0 and decoded.completed < decoded.admitted)) return error.InvalidTableCreation;
        return decoded;
    }
    fn result(self: Record) Result {
        return .{ .state = if (self.completed == 0) .building else .applied, .admitted_input = self.admitted, .completed_input = self.completed };
    }
};

/// The caller durably schedules another step when building and responds only
/// with the final head/receipt commit. Reuse the exact schema, object and quotas
/// after interruption; a changed program cannot reinterpret accepted creation.
/// The original receipt survives subsequent writes, ALTER and retirement.
pub fn step(allocator: std.mem.Allocator, turn: *Turn, schema: f.TableSchema.Schema, limits: Pub.Limits) !Result {
    const before = turn.decision;
    errdefer turn.decision = before;
    try schema.validate();
    try limits.validate();
    if (schema.revision != 1) return error.InvalidTableCreation;
    var buffer: [f.TableSchema.max_bytes]u8 = undefined;
    const encoded = try schema.encode(&buffer);
    if (encoded.len > limits.record_bytes) return error.PublicationTooLarge;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.station.table.creation.v1\x00");
    hash.update(&definition());
    var binding: [24]u8 = undefined;
    std.mem.writeInt(u64, binding[0..8], turn.view.resource, .little);
    std.mem.writeInt(u32, binding[8..12], limits.record_bytes, .little);
    std.mem.writeInt(u64, binding[12..20], limits.staging_bytes, .little);
    std.mem.writeInt(u32, binding[20..24], limits.staging_records, .little);
    hash.update(&binding);
    hash.update(encoded);
    const intent = hash.finalResult();
    var record: Record = if (try turn.read(key(schema.object))) |value| blk: {
        const saved = try Record.decode(value);
        if (!std.mem.eql(u8, &saved.intent, &intent)) return error.TableCreationConflict;
        break :blk saved;
    } else {
        // Never adopt a namespace created by a different owner/profile.
        if (try turn.read(Pages.key(schema.object, 'd', 0)) != null or try turn.read(Head.key(schema.object)) != null) return error.TableExists;
        _ = try Pages.create(turn, schema.object, limits);
        const accepted: Record = .{ .intent = intent, .admitted = turn.delivery.input.position };
        try turn.write(key(schema.object), try accepted.encode());
        return accepted.result();
    };
    if (record.completed != 0) return record.result();
    if (try turn.read(Head.key(schema.object)) != null) return error.TableExists;
    const pages = try Pages.create(turn, schema.object, limits);
    const ref: Pages.Reference = .{ .id = 1, .spec = try Pub.Digest.of(Pages.schema_format, encoded) };
    if (try pages.stage(turn, ref, encoded) != .ready) return record.result();
    // Large publication readers require a committed descriptor. The next step
    // verifies the published schema before exposing the Table head.
    if (encoded.len > Pages.inline_bytes and !std.meta.eql(before, turn.decision)) return record.result();
    const head: Head = .{ .resource = turn.view.resource, .object = schema.object, .revision = 1, .schema = ref, .next_record = 2 };
    try head.create(allocator, turn);
    record.completed = turn.delivery.input.position;
    try turn.write(key(schema.object), try record.encode());
    return record.result();
}

test "application creation receipt matches independent bytes and rejects incompatible records" {
    const t = std.testing;
    const Fixture = struct { creation_receipt_hex: []const u8, creation_key_hex: []const u8 };
    const fixture = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-storage.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    const record: Record = .{ .intent = @splat(119), .admitted = 12, .completed = 15 };
    const encoded = try record.encode();
    var bytes: [256]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.value.creation_receipt_hex), encoded.slice());
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&bytes, fixture.value.creation_key_hex), key(9).slice());
    try t.expectEqualDeep(record, try Record.decode(encoded));
    for ([_]usize{ 0, 4, 35, 67, 83, 85 }) |length| {
        var changed = encoded;
        changed.len = @intCast(length);
        @memset(changed.data[length..], 0);
        try t.expectError(error.InvalidTableCreation, Record.decode(changed));
    }
    var changed = encoded;
    changed.data[4] ^= 1;
    try t.expectError(error.IncompatibleTableStorage, Record.decode(changed));
    for ([_]Record{ .{ .intent = record.intent, .admitted = 0 }, .{ .intent = record.intent, .admitted = 12, .completed = 11 }, .{ .intent = record.intent, .admitted = 12, .completed = p.max_counter + 1 } }) |invalid| {
        try t.expectError(error.InvalidTableCreation, Record.decode(try invalid.encode()));
    }
}

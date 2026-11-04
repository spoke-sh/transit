//! Bounded transport descriptors for explicit Stream assignments and traversed
//! progress. Decoding checks shape, never authority, cursor MACs or live pins.
const std = @import("std");
const p = @import("root.zig");

/// Largest interval descriptor, including both optional request bounds.
pub const max_bytes = 357;
pub const group_bytes = 152;

pub const Group = struct {
    definition: p.Growth.Definition,
    group: p.StreamQueue.GroupProgress,

    pub fn validate(self: Group) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.group.validate();
    }
};

pub const Progress = struct {
    definition: p.Growth.Definition,
    receipt: p.StreamRead.Receipt,
    progress: p.StreamRead.Progress,

    pub fn validate(self: Progress) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.receipt.validate();
        if (self.receipt.request.group == null) return error.InvalidStreamProgress;
        try self.progress.requireReceipt(self.receipt);
    }
    pub fn settlement(self: Progress, operation: p.DataLifecycle.Operation) !@FieldType(p.LogWorkload.StreamRequest, "offset") {
        try self.validate();
        const coverage = try self.progress.coverage();
        const result: @FieldType(p.LogWorkload.StreamRequest, "offset") = .{
            .commit = .{ .operation = operation, .group = self.receipt.request.group.?, .coverage = coverage, .expected_next = coverage.from, .next = coverage.until },
            .progress = self.progress,
        };
        try result.validate();
        return result;
    }
};

fn writeTarget(writer: *std.Io.Writer, target: p.StreamQueue.Partition) !void {
    const object = target.interpretation.object;
    inline for (.{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, target.interpretation.revision }) |value| try writer.writeInt(u64, value, .little);
    try writer.writeAll(&target.interpretation.digest);
    try writer.writeInt(u32, target.partition, .little);
}
fn readTarget(reader: *std.Io.Reader) !p.StreamQueue.Partition {
    const scope: p.DataLifecycle.Scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) };
    const object: p.DataLifecycle.Object = .{ .scope = scope, .branch = try reader.takeInt(u64, .little), .object = try reader.takeInt(u64, .little) };
    return .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = object, .revision = try reader.takeInt(u64, .little), .digest = (try reader.takeArray(32)).* }, .partition = try reader.takeInt(u32, .little) };
}
fn writeGroup(writer: *std.Io.Writer, group: p.StreamQueue.Group) !void {
    inline for (.{ group.id, group.generation, group.principal }) |value| try writer.writeInt(u64, value, .little);
}
fn readGroup(reader: *std.Io.Reader) !p.StreamQueue.Group {
    return .{ .id = try reader.takeInt(u64, .little), .generation = try reader.takeInt(u64, .little), .principal = try reader.takeInt(u64, .little) };
}
fn boolean(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidStreamHandle,
    };
}
fn writeCursor(writer: *std.Io.Writer, cursor: p.StreamRead.Cursor) !void {
    try writer.writeInt(u64, cursor.coverage.through, .little);
    try writer.writeInt(u64, cursor.coverage.rows, .little);
    try writer.writeByte(@intFromBool(cursor.coverage.complete));
    try writer.writeAll(&cursor.authentication);
}
fn readCursor(reader: *std.Io.Reader, receipt: p.StreamRead.Receipt) !p.StreamRead.Cursor {
    var coverage = try receipt.initialCoverage();
    coverage.through = try reader.takeInt(u64, .little);
    coverage.rows = try reader.takeInt(u64, .little);
    coverage.complete = try boolean(reader);
    return .{ .read = receipt.handle(), .coverage = coverage, .authentication = (try reader.takeArray(32)).* };
}

/// Fixed, little-endian transport. Repeated fields are omitted only after native
/// shape validation proves they equal the receipt. No cursor MAC is rewritten.
pub fn encode(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    comptime std.debug.assert(@TypeOf(value) == Group or @TypeOf(value) == Progress);
    try value.validate();
    var buffer: [max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    try writer.writeAll(if (@TypeOf(value) == Group) "SGH1" else "SPH1");
    try writer.writeAll(&p.Growth.definition_bytes);
    if (@TypeOf(value) == Group) {
        try writeTarget(&writer, value.group.target);
        try writeGroup(&writer, value.group.group);
        try writer.writeInt(u64, value.group.next, .little);
    } else {
        const receipt = value.receipt;
        try writeTarget(&writer, receipt.request.target);
        try writeGroup(&writer, receipt.request.group.?);
        try writer.writeInt(u64, receipt.request.operation.operation, .little);
        try writer.writeInt(u64, receipt.request.from, .little);
        try writer.writeByte(@intFromBool(receipt.request.until != null));
        if (receipt.request.until) |until| try writer.writeInt(u64, until, .little);
        try writer.writeByte(@intFromBool(receipt.request.timestamp != null));
        if (receipt.request.timestamp) |range| {
            try writer.writeInt(i64, range.from_us, .little);
            try writer.writeInt(i64, range.until_us, .little);
        }
        inline for (.{ receipt.cut.accepted.partition, receipt.cut.accepted.next_lsn, receipt.cut.retained_from, receipt.cut.next, receipt.source.bytes }) |number| try writer.writeInt(u64, number, .little);
        try writer.writeAll(&receipt.source.sha256);
        try writer.writeByte(@intFromBool(value.progress == .interval));
        if (value.progress == .interval) try writeCursor(&writer, value.progress.interval.first);
        try writeCursor(&writer, value.progress.end());
    }
    return allocator.dupe(u8, writer.buffered());
}

/// Every decoded field is owned by value. The definition is required before
/// construction; malformed tags, truncation and trailing bytes refuse.
pub fn decode(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    comptime std.debug.assert(T == Group or T == Progress);
    _ = allocator;
    if (bytes.len < 36 or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..4], if (T == Group) "SGH1" else "SPH1")) return error.InvalidStreamHandle;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    return decodeBody(T, bytes[36..]) catch |err| switch (err) {
        error.EndOfStream => error.InvalidStreamHandle,
        else => err,
    };
}
fn decodeBody(comptime T: type, bytes: []const u8) !T {
    var reader: std.Io.Reader = .fixed(bytes);
    const target = try readTarget(&reader);
    const group = try readGroup(&reader);
    const result: T = if (T == Group) .{ .definition = p.Growth.current_definition, .group = .{ .target = target, .group = group, .next = try reader.takeInt(u64, .little) } } else blk: {
        const operation: p.DataLifecycle.Operation = .{ .scope = target.interpretation.object.scope, .principal = group.principal, .operation = try reader.takeInt(u64, .little) };
        const from = try reader.takeInt(u64, .little);
        const until: ?u64 = if (try boolean(&reader)) try reader.takeInt(u64, .little) else null;
        const timestamp: ?p.StreamRead.TimestampRange = if (try boolean(&reader)) .{ .from_us = try reader.takeInt(i64, .little), .until_us = try reader.takeInt(i64, .little) } else null;
        const position: p.DataLifecycle.Position = .{ .partition = try reader.takeInt(u64, .little), .next_lsn = try reader.takeInt(u64, .little) };
        const cut: p.StreamQueue.Cut = .{ .target = target, .accepted = position, .retained_from = try reader.takeInt(u64, .little), .next = try reader.takeInt(u64, .little) };
        const receipt: p.StreamRead.Receipt = .{
            .request = .{ .target = target, .operation = operation, .group = group, .from = from, .until = until, .timestamp = timestamp },
            .cut = cut,
            .until = until orelse cut.next,
            .source = .{ .bytes = try reader.takeInt(u64, .little), .sha256 = (try reader.takeArray(32)).* },
            .accepted = .{ .partition = position.partition, .next_lsn = std.math.add(u64, position.next_lsn, 1) catch return error.InvalidStreamRead },
        };
        const interval = try boolean(&reader);
        const first = try readCursor(&reader, receipt);
        const progress: p.StreamRead.Progress = if (interval) .{ .interval = .{ .first = first, .last = try readCursor(&reader, receipt) } } else .{ .exhausted = first };
        break :blk .{ .definition = p.Growth.current_definition, .receipt = receipt, .progress = progress };
    };
    if (reader.bufferedLen() != 0) return error.InvalidStreamHandle;
    try result.validate();
    return result;
}

test "Stream handles preserve independent assignment and interval fixtures without granting authority" {
    const t = std.testing;
    const fixture = try p.Json.parseFromSlice(p.StreamQueue.SchemaTypes, t.allocator, @embedFile("fixtures/stream-queue-v1.json"));
    defer fixture.deinit();
    const group = fixture.value.group_handle;
    const progress = fixture.value.progress_handle;
    try t.expectEqualDeep(fixture.value.group_progress, group.group);
    try t.expectEqualDeep(fixture.value.read, progress.receipt);
    inline for (.{ group, progress }) |value| {
        const bytes = try encode(t.allocator, value);
        defer t.allocator.free(bytes);
        try t.expectEqualDeep(value, try decode(@TypeOf(value), t.allocator, bytes));
        const golden = try std.json.parseFromSlice([]const u8, t.allocator, @embedFile(if (@TypeOf(value) == Group) "fixtures/stream-handle-group.json" else "fixtures/stream-handle-progress.json"), .{});
        defer golden.deinit();
        var decoded: [max_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&decoded, golden.value), bytes);
        for (0..bytes.len) |length| try t.expectError(error.InvalidStreamHandle, decode(@TypeOf(value), t.allocator, bytes[0..length]));
        bytes[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, decode(@TypeOf(value), t.allocator, bytes));
        bytes[4] ^= 1;
        try t.expectError(error.InvalidStreamHandle, decode(@TypeOf(value), t.allocator, "{\"definition\":\"0\"}"));
    }
    var maximum = progress;
    maximum.receipt.request.until = maximum.receipt.until;
    maximum.receipt.request.timestamp = .{ .from_us = std.math.minInt(i64), .until_us = std.math.maxInt(i64) };
    const largest = try encode(t.allocator, maximum);
    defer t.allocator.free(largest);
    try t.expectEqual(max_bytes, largest.len);
    try t.expectEqualDeep(maximum, try decode(Progress, t.allocator, largest));
    largest[160] = 2;
    try t.expectError(error.InvalidStreamHandle, decode(Progress, t.allocator, largest));
    const group_encoded = try encode(t.allocator, group);
    defer t.allocator.free(group_encoded);
    try t.expectEqual(group_bytes, group_encoded.len);
    var extended: [group_bytes + 1]u8 = @splat(0);
    @memcpy(extended[0..group_bytes], group_encoded);
    try t.expectError(error.InvalidStreamHandle, decode(Group, t.allocator, &extended));
    const coverage = try progress.progress.coverage();
    const operation: p.DataLifecycle.Operation = .{ .scope = progress.receipt.request.operation.scope, .principal = progress.receipt.request.operation.principal, .operation = 99 };
    const settlement = try progress.settlement(operation);
    try t.expectEqual(coverage.from, settlement.commit.expected_next);
    try t.expectEqual(coverage.until, settlement.commit.next);
    var forged = progress;
    forged.progress.interval.first.read.owner.operation += 1;
    try t.expectError(error.InvalidStreamProgress, forged.validate());
    forged = progress;
    forged.receipt.request.group = null;
    try t.expectError(error.InvalidStreamProgress, forged.validate());
    forged = progress;
    forged.progress.interval.last.authentication[0] ^= 1;
    // A nonzero forged MAC passes shape validation; only the native read owner
    // may authenticate it. The installed SQL proof must reject settlement.
    try forged.validate();
}

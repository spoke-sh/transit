//! Binary result framing. Columns borrow their HTTP body; the initial descriptor
//! owns logical meaning. Framing is independent of source pages and completion.
const std = @import("std");
const api = @import("root.zig");
const r = api.results;
const Self = @This();
pub const content_type = "application/vnd.transit.sql-result";
pub const alignment = 64;
pub const header_bytes = 192;
pub const max_description_bytes = 64 * 1024;
pub const max_completion_bytes = 16 * 1024;
pub const max_columns = (r.Types.Limits{}).nodes;
pub const Description = struct { schema: []const u8, observation: r.Observation.Value };
instance: api.Instance,
cursor: api.Id,
ordinal: u64,
rows: u32,
schema: [32]u8,
observation: [32]u8,
description: ?Description,
columns: []const []const u8,
completion: ?r.Completion,

fn rounded(value: usize) !usize {
    return (try std.math.add(usize, value, alignment - 1)) & ~@as(usize, alignment - 1);
}
fn put(bytes: []u8, comptime T: type, offset: usize, value: T) void {
    std.mem.writeInt(T, bytes[offset..][0..@sizeOf(T)], value, .little);
}
fn get(bytes: []const u8, comptime T: type, offset: usize) T {
    return std.mem.readInt(T, bytes[offset..][0..@sizeOf(T)], .little);
}
fn shape(self: Self) !void {
    if (self.rows > api.max_rows or self.columns.len > max_columns or
        (self.rows == 0 and (self.completion == null or self.columns.len != 0)) or
        (self.rows != 0 and self.columns.len == 0) or
        ((self.ordinal == 0) != (self.description != null))) return error.InvalidResultFrame;
    if (self.completion) |completion| {
        try completion.validateShape();
        if (completion.rows < self.rows) return error.InvalidResultFrame;
    }
    if (self.description) |description| {
        if (description.schema.len == 0 or description.schema.len > r.Types.max_encoding_bytes) return error.InvalidResultFrame;
    }
}

const Layout = struct { schema: []const u8, metadata_size: usize, completion_size: usize, directory: usize, size: usize };
fn layout(self: Self) !Layout {
    try self.shape();
    var buffer: [256]u8 = undefined;
    var counter: std.Io.Writer.Discarding = .init(&buffer);
    var json: std.json.Stringify = .{ .writer = &counter.writer };
    if (self.description) |description| try api.Json.write(description.observation, &json);
    const metadata_size = std.math.cast(usize, counter.fullCount()) orelse return error.InvalidResultFrame;
    if (metadata_size > max_description_bytes) return error.InvalidResultFrame;
    var completion_buffer: [256]u8 = undefined;
    var completion_counter: std.Io.Writer.Discarding = .init(&completion_buffer);
    var completion_json: std.json.Stringify = .{ .writer = &completion_counter.writer };
    if (self.completion) |completion| if (completion.workload) |workload| try api.Json.write(workload, &completion_json);
    const completion_size = std.math.cast(usize, completion_counter.fullCount()) orelse return error.InvalidResultFrame;
    if (completion_size > max_completion_bytes) return error.InvalidResultFrame;
    const schema_bytes = if (self.description) |description| description.schema else &.{};
    const directory = header_bytes + schema_bytes.len + metadata_size + completion_size;
    var size = try rounded(directory + self.columns.len * 8);
    for (self.columns) |column| size = try rounded(try std.math.add(usize, size, column.len));
    if (size > api.max_message_bytes) return error.SqlMessageTooLarge;
    return .{ .schema = schema_bytes, .metadata_size = metadata_size, .completion_size = completion_size, .directory = directory, .size = size };
}
pub fn encodedSize(self: Self) !usize {
    return (try self.layout()).size;
}
/// One exact-sized owned allocation. Metadata writes directly into its final
/// frame range; the caller frees the result through this allocator.
pub fn encode(allocator: std.mem.Allocator, self: Self) ![]align(alignment) u8 {
    const plan = try self.layout();
    const output = try allocator.alignedAlloc(u8, .fromByteUnits(alignment), plan.size);
    errdefer allocator.free(output);
    return writeInto(output, self, plan);
}
/// No allocation. Output borrows destination until its owner reuses it. Inputs
/// must not alias destination. Insufficient capacity leaves destination intact.
pub fn encodeInto(destination: []align(alignment) u8, self: Self) ![]align(alignment) u8 {
    return writeInto(destination, self, try self.layout());
}
fn writeInto(destination: []align(alignment) u8, self: Self, plan: Layout) ![]align(alignment) u8 {
    if (destination.len < plan.size) return error.ResultBufferTooSmall;
    const output = destination[0..plan.size];
    const schema_bytes = plan.schema;
    const directory = plan.directory;
    @memset(output[0..header_bytes], 0);
    @memcpy(output[0..4], "TSR1");
    @memcpy(output[4..36], &api.native.definition_bytes);
    @memcpy(output[36..52], &self.instance);
    @memcpy(output[52..84], &self.cursor);
    put(output, u64, 84, self.ordinal);
    put(output, u32, 92, self.rows);
    put(output, u32, 96, @intFromBool(self.completion != null));
    put(output, u64, 100, if (self.completion) |completion| completion.rows else 0);
    @memcpy(output[108..140], &self.schema);
    @memcpy(output[140..172], &self.observation);
    put(output, u32, 172, @intCast(schema_bytes.len));
    put(output, u32, 176, @intCast(plan.metadata_size));
    put(output, u32, 180, @intCast(self.columns.len));
    put(output, u32, 184, @intCast(plan.completion_size));
    @memcpy(output[header_bytes..][0..schema_bytes.len], schema_bytes);
    if (self.description) |description| {
        var writer: std.Io.Writer = .fixed(output[header_bytes + schema_bytes.len ..][0..plan.metadata_size]);
        var json: std.json.Stringify = .{ .writer = &writer };
        try api.Json.write(description.observation, &json);
        std.debug.assert(writer.buffered().len == plan.metadata_size);
    }
    if (self.completion) |completion| if (completion.workload) |workload| {
        var writer: std.Io.Writer = .fixed(output[directory - plan.completion_size .. directory]);
        var json: std.json.Stringify = .{ .writer = &writer };
        try api.Json.write(workload, &json);
        std.debug.assert(writer.buffered().len == plan.completion_size);
    };
    var offset = try rounded(directory + self.columns.len * 8);
    @memset(output[directory + self.columns.len * 8 .. offset], 0);
    for (self.columns, 0..) |column, i| {
        put(output, u32, directory + i * 8, @intCast(offset));
        put(output, u32, directory + i * 8 + 4, @intCast(column.len));
        @memcpy(output[offset..][0..column.len], column);
        const end = offset + column.len;
        offset = try rounded(end);
        @memset(output[end..offset], 0);
    }
    return output;
}

/// Input remains owned by the caller and must outlive the frame. This parser
/// allocates only the column directory and observation/completion metadata. Column
/// admission/type validation belongs to the shared physical codec and reader.
pub fn parseBorrowed(arena: std.mem.Allocator, bytes: []align(alignment) const u8) !Self {
    const count = try columnCount(bytes);
    const columns = try arena.alloc([]const u8, count);
    return parseInto(arena, columns, bytes);
}
fn columnCount(bytes: []align(alignment) const u8) !usize {
    if (bytes.len < header_bytes or bytes.len > api.max_message_bytes or !std.mem.eql(u8, bytes[0..4], "TSR1")) return error.InvalidResultFrame;
    if (!std.mem.eql(u8, bytes[4..36], &api.native.definition_bytes)) return error.IncompatibleSqlDefinition;
    const count: usize = get(bytes, u32, 180);
    if (count > max_columns) return error.InvalidResultFrame;
    return count;
}
/// Columns borrow caller-owned directory and immutable frame bytes. Only the
/// observation and completion use metadata storage; it must outlive the frame view.
pub fn parseInto(metadata_arena: std.mem.Allocator, directory_storage: [][]const u8, bytes: []align(alignment) const u8) !Self {
    const count = try columnCount(bytes);
    if (!std.mem.allEqual(u8, bytes[188..header_bytes], 0)) return error.InvalidResultFrame;
    const flags = get(bytes, u32, 96);
    const terminal = get(bytes, u64, 100);
    if (flags > 1 or (flags == 0 and terminal != 0)) return error.InvalidResultFrame;
    const schema_size: usize = get(bytes, u32, 172);
    const metadata_size: usize = get(bytes, u32, 176);
    const completion_size: usize = get(bytes, u32, 184);
    if (schema_size > r.Types.max_encoding_bytes or metadata_size > max_description_bytes or completion_size > max_completion_bytes or count > max_columns or
        (flags == 0 and completion_size != 0) or
        ((schema_size == 0) != (metadata_size == 0))) return error.InvalidResultFrame;
    const directory = header_bytes + schema_size + metadata_size + completion_size;
    const start = try rounded(directory + count * 8);
    if (start > bytes.len or !std.mem.allEqual(u8, bytes[directory + count * 8 .. start], 0)) return error.InvalidResultFrame;
    if (directory_storage.len < count) return error.ResultDirectoryTooSmall;
    const columns = directory_storage[0..count];
    var offset = start;
    for (columns, 0..) |*column, i| {
        const declared: usize = get(bytes, u32, directory + i * 8);
        const length: usize = get(bytes, u32, directory + i * 8 + 4);
        if (declared != offset or length > bytes.len - offset) return error.InvalidResultFrame;
        const end = offset + length;
        const next = try rounded(end);
        if (next > bytes.len or !std.mem.allEqual(u8, bytes[end..next], 0)) return error.InvalidResultFrame;
        column.* = bytes[offset..end];
        offset = next;
    }
    if (offset != bytes.len) return error.InvalidResultFrame;
    const description: ?Description = if (schema_size == 0) null else blk: {
        const metadata = bytes[header_bytes + schema_size ..][0..metadata_size];
        try api.fuze.Types.Json.preflight(metadata, .{ .bytes = max_description_bytes, .depth = 16, .tokens = 16384, .fields = 256 });
        const tree = try std.json.parseFromSlice(std.json.Value, metadata_arena, metadata, .{});
        defer tree.deinit();
        try api.Json.validateShape(r.Observation.Value, tree.value);
        const observation = try std.json.parseFromSliceLeaky(r.Observation.Value, metadata_arena, metadata, .{ .allocate = .alloc_always });
        try r.Observation.validate(observation);
        break :blk .{ .schema = bytes[header_bytes..][0..schema_size], .observation = observation };
    };
    const workload: ?r.Workload.Completion = if (completion_size == 0) null else blk: {
        const metadata = bytes[directory - completion_size .. directory];
        try api.fuze.Types.Json.preflight(metadata, .{ .bytes = max_completion_bytes, .depth = 16, .tokens = 16384, .fields = 256 });
        const tree = try std.json.parseFromSlice(std.json.Value, metadata_arena, metadata, .{});
        defer tree.deinit();
        try api.Json.validateShape(r.Workload.Completion, tree.value);
        const value = try std.json.parseFromSliceLeaky(r.Workload.Completion, metadata_arena, metadata, .{ .allocate = .alloc_always });
        try value.validateShape();
        break :blk value;
    };
    const frame: Self = .{
        .instance = bytes[36..52].*,
        .cursor = bytes[52..84].*,
        .ordinal = get(bytes, u64, 84),
        .rows = get(bytes, u32, 92),
        .schema = bytes[108..140].*,
        .observation = bytes[140..172].*,
        .description = description,
        .columns = columns,
        .completion = if (flags == 1) .{ .rows = terminal, .workload = workload } else null,
    };
    try frame.shape();
    return frame;
}

test "binary frames borrow aligned columns and carry the descriptor only at ordinal zero" {
    const t = std.testing;
    const observation: r.Observation.Value = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } };
    var frame: Self = .{ .instance = @splat(1), .cursor = @splat(2), .ordinal = 0, .rows = 1, .schema = @splat(3), .observation = @splat(4), .description = .{ .schema = "binary\x00schema", .observation = observation }, .columns = &.{"\x00\xff\x10"}, .completion = null };
    for (0..3) |ordinal| {
        frame.ordinal = ordinal;
        if (ordinal != 0) frame.description = null;
        if (ordinal == 2) frame.completion = .{ .rows = 3 };
        const bytes = try encode(t.allocator, frame);
        defer t.allocator.free(bytes);
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        const decoded = try parseBorrowed(arena.allocator(), bytes);
        try t.expectEqualDeep(frame, decoded);
        try t.expect(std.mem.isAligned(@intFromPtr(decoded.columns[0].ptr), alignment));
        try t.expect(@intFromPtr(decoded.columns[0].ptr) >= @intFromPtr(bytes.ptr));
        try t.expect(@intFromPtr(decoded.columns[0].ptr) < @intFromPtr(bytes.ptr) + bytes.len);
    }
}

test "binary framing rejects foreign definitions truncation overlaps padding and false terminals" {
    const t = std.testing;
    const frame: Self = .{ .instance = @splat(1), .cursor = @splat(2), .ordinal = 1, .rows = 1, .schema = @splat(3), .observation = @splat(4), .description = null, .columns = &.{ "abc", "def" }, .completion = .{ .rows = 2 } };
    const bytes = try encode(t.allocator, frame);
    defer t.allocator.free(bytes);
    for (0..bytes.len) |length| {
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        try t.expectError(error.InvalidResultFrame, parseBorrowed(arena.allocator(), bytes[0..length]));
    }
    for ([_]usize{ 4, 92, 96, 172, 176, 180, 184, 192, 200, bytes.len - 1 }) |offset| {
        const prior = bytes[offset];
        bytes[offset] = 255;
        defer bytes[offset] = prior;
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        if (parseBorrowed(arena.allocator(), bytes)) |_| return error.MutationEscaped else |_| {}
    }
    put(bytes, u64, 100, 0);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    try t.expectError(error.InvalidResultFrame, parseBorrowed(arena.allocator(), bytes));
}

test "caller-owned framing and directory reuse preserve bytes without backing allocation" {
    const t = std.testing;
    const memory = @import("transit_memory");
    var probe: memory.AllocationProbe = .{ .parent = t.allocator };
    var metadata = try memory.Workspace.init(probe.allocator(), 128 * 1024);
    defer metadata.deinit();
    var lease = try metadata.acquire();
    defer lease.release(false) catch unreachable;
    var bytes: [8192]u8 align(alignment) = undefined;
    var columns: [max_columns][]const u8 = undefined;
    const observation: r.Observation.Value = .{ .metadata = .{ .kind = .probe, .consistency = .session, .namespace = null, .definitions = &.{}, .configuration_revision = null, .session_settings = null } };
    var frame: Self = .{ .instance = @splat(1), .cursor = @splat(2), .ordinal = 0, .rows = 1, .schema = @splat(3), .observation = @splat(4), .description = .{ .schema = "binary\x00schema", .observation = observation }, .columns = &.{ "\x00\xff\x10", "retained" }, .completion = null };
    const expected = try encode(t.allocator, frame);
    defer t.allocator.free(expected);
    const required = try frame.encodedSize();
    probe.begin(true);
    for (0..1000) |iteration| {
        try lease.reset();
        frame.ordinal = iteration % 3;
        frame.description = if (frame.ordinal == 0) .{ .schema = "binary\x00schema", .observation = observation } else null;
        frame.completion = if (frame.ordinal == 2) .{ .rows = 3 } else null;
        @memset(&bytes, 0xaa);
        const encoded = try encodeInto(&bytes, frame);
        if (frame.ordinal == 0) {
            try t.expectEqual(required, encoded.len);
            try t.expectEqualSlices(u8, expected, encoded);
        }
        const parsed = try parseInto(try lease.allocator(), &columns, encoded);
        try t.expectEqualDeep(frame, parsed);
        try t.expect(@intFromPtr(parsed.columns[1].ptr) > @intFromPtr(encoded.ptr));
        try t.expectEqual(@as(u8, 0xaa), bytes[encoded.len]);
        try t.expectError(error.ResultDirectoryTooSmall, parseInto(try lease.allocator(), columns[0..1], encoded));
    }
    @memset(&bytes, 0xaa);
    try t.expectError(error.ResultBufferTooSmall, encodeInto(bytes[0..header_bytes], frame));
    try t.expect(std.mem.allEqual(u8, &bytes, 0xaa));
    try probe.verify();
    try t.expectEqual(metadata.buffer.len, probe.live_bytes);
}

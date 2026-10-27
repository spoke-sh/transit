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
    if (self.completion) |completion| if (completion.rows < self.rows) return error.InvalidResultFrame;
    if (self.description) |description| {
        if (description.schema.len == 0 or description.schema.len > r.Types.max_encoding_bytes) return error.InvalidResultFrame;
    }
}

/// One exact-sized aligned allocation; column bytes are already encoded by the
/// owning codec. Repeating ordinal zero repeats the same initial description.
pub fn encode(allocator: std.mem.Allocator, self: Self) ![]align(alignment) u8 {
    try self.shape();
    const metadata = if (self.description) |description| try api.Json.valueAlloc(allocator, description.observation) else null;
    defer if (metadata) |bytes| allocator.free(bytes);
    if (metadata) |bytes| if (bytes.len > max_description_bytes) return error.InvalidResultFrame;
    const schema_bytes = if (self.description) |description| description.schema else &.{};
    const metadata_bytes = metadata orelse &.{};
    const directory = header_bytes + schema_bytes.len + metadata_bytes.len;
    var size = try rounded(directory + self.columns.len * 8);
    for (self.columns) |column| size = try rounded(try std.math.add(usize, size, column.len));
    if (size > api.max_message_bytes) return error.SqlMessageTooLarge;
    const output = try allocator.alignedAlloc(u8, .fromByteUnits(alignment), size);
    errdefer allocator.free(output);
    @memset(output, 0);
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
    put(output, u32, 176, @intCast(metadata_bytes.len));
    put(output, u32, 180, @intCast(self.columns.len));
    @memcpy(output[header_bytes..][0..schema_bytes.len], schema_bytes);
    @memcpy(output[header_bytes + schema_bytes.len ..][0..metadata_bytes.len], metadata_bytes);
    var offset = try rounded(directory + self.columns.len * 8);
    for (self.columns, 0..) |column, i| {
        put(output, u32, directory + i * 8, @intCast(offset));
        put(output, u32, directory + i * 8 + 4, @intCast(column.len));
        @memcpy(output[offset..][0..column.len], column);
        offset = try rounded(offset + column.len);
    }
    return output;
}

/// Input remains owned by the caller and must outlive the frame. This parser
/// allocates only the column directory and initial observation metadata. Column
/// admission/type validation belongs to the shared physical codec and reader.
pub fn parseBorrowed(arena: std.mem.Allocator, bytes: []align(alignment) const u8) !Self {
    if (bytes.len < header_bytes or bytes.len > api.max_message_bytes or !std.mem.eql(u8, bytes[0..4], "TSR1")) return error.InvalidResultFrame;
    if (!std.mem.eql(u8, bytes[4..36], &api.native.definition_bytes)) return error.IncompatibleSqlDefinition;
    if (!std.mem.allEqual(u8, bytes[184..header_bytes], 0)) return error.InvalidResultFrame;
    const flags = get(bytes, u32, 96);
    const terminal = get(bytes, u64, 100);
    if (flags > 1 or (flags == 0 and terminal != 0)) return error.InvalidResultFrame;
    const schema_size: usize = get(bytes, u32, 172);
    const metadata_size: usize = get(bytes, u32, 176);
    const count: usize = get(bytes, u32, 180);
    if (schema_size > r.Types.max_encoding_bytes or metadata_size > max_description_bytes or count > max_columns or
        ((schema_size == 0) != (metadata_size == 0))) return error.InvalidResultFrame;
    const directory = header_bytes + schema_size + metadata_size;
    const start = try rounded(directory + count * 8);
    if (start > bytes.len or !std.mem.allEqual(u8, bytes[directory + count * 8 .. start], 0)) return error.InvalidResultFrame;
    const columns = try arena.alloc([]const u8, count);
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
        const metadata = bytes[header_bytes + schema_size .. directory];
        try api.fuze.Types.Json.preflight(metadata, .{ .bytes = max_description_bytes, .depth = 16, .tokens = 16384, .fields = 256 });
        const tree = try std.json.parseFromSlice(std.json.Value, arena, metadata, .{});
        defer tree.deinit();
        try api.Json.validateShape(r.Observation.Value, tree.value);
        const observation = try std.json.parseFromSliceLeaky(r.Observation.Value, arena, metadata, .{ .allocate = .alloc_always });
        break :blk .{ .schema = bytes[header_bytes..][0..schema_size], .observation = observation };
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
        .completion = if (flags == 1) .{ .rows = terminal } else null,
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

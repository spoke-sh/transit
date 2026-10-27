//! Canonical source-row repartitioning. Physical workers never alter a bound
//! query, stable row identity, logical partition or ordered SUM evaluation.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const native = @import("transit_protocol").Growth;
const table = @import("TableSchema.zig");
const values = @import("RelationalValues.zig");
pub const max_rows = 4;
pub const fixed_bytes = 4 + 32 + 32 + 8 + 1 + 8 * 4 + 2 + max_rows * (20 + table.max_columns * 9);
pub const max_bytes = fixed_bytes + max_rows * values.max_text_bytes;

pub fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}

/// Logical partition count is an admitted u64, not a resident array bound.
/// All sources in one join use the same count and canonical key encoding.
pub fn route(plan: r.Plan, source: u8, partitions: u64, row: e.Row) !u64 {
    try plan.validate();
    try validateRow(plan, source, row);
    if (partitions == 0) return error.InvalidRelationalExchange;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.relational.partition.v1\x00");
    if (plan.join) |join| {
        hash.update(&.{1});
        const column = if (source == 0) join.left else join.right;
        try values.hashInto(&hash, row.values[try plan.sources[source].schema.index(column.id)], try plan.resolveColumn(column));
    } else if (grouped(plan)) {
        hash.update(&.{2});
        hash.update(&.{@intCast(plan.group_by.len)});
        for (plan.group_by) |column| try values.hashInto(&hash, row.values[try plan.sources[source].schema.index(column.id)], try plan.resolveColumn(column));
    } else {
        hash.update(&.{3});
        var bytes: [20]u8 = undefined;
        identityBytes(row.identity, &bytes);
        hash.update(&bytes);
    }
    const digest = hash.finalResult();
    return std.mem.readInt(u64, digest[0..8], .little) % partitions;
}
fn grouped(plan: r.Plan) bool {
    if (plan.group_by.len != 0) return true;
    for (plan.outputs) |output| if (output.expression != .column) return true;
    return false;
}
pub fn identityBytes(value: r.RowIdentity, bytes: *[20]u8) void {
    std.mem.writeInt(u64, bytes[0..8], value.origin, .big);
    std.mem.writeInt(u64, bytes[8..16], value.operation, .big);
    std.mem.writeInt(u32, bytes[16..20], value.ordinal, .big);
}
pub fn validateRow(plan: r.Plan, source: u8, row: e.Row) !void {
    if (source >= plan.sources.len) return error.InvalidRelationalExchange;
    try row.identity.validate();
    _ = try values.payloadLength(&row.values);
    const columns = plan.sources[source].schema.columns;
    for (columns, 0..) |column, i| {
        if (column.type == .int64 or column.type == .utf8) {
            try values.validate(row.values[i], column);
        } else if (row.values[i] != null) return error.InvalidRelationalSourceRow;
    }
    for (row.values[columns.len..]) |value| if (value != null) return error.InvalidRelationalSourceRow;
}
pub const Segment = struct {
    exchange: u64,
    source: u8,
    partitions: u64,
    partition: u64,
    /// Recorded physical-plan epoch. It is evidence, not an independent
    /// execution authority or dedup key; the native PID generation fences work.
    epoch: u64,
    sequence: u64,
    terminal: bool,
    len: u8 = 0,
    rows: [max_rows]e.Row = undefined,

    pub fn deinit(self: *Segment) void {
        for (self.rows[0..self.len]) |*row| row.deinit();
        self.* = undefined;
    }

    pub fn encode(self: Segment, bound: r.Bound, output: []u8) ![]const u8 {
        var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
        try self.writeTo(bound, &writer);
        return writer.buffered();
    }
    pub fn encodeAlloc(self: Segment, allocator: std.mem.Allocator, bound: r.Bound) ![]u8 {
        return values.encodeOwned(allocator, self, bound, max_bytes);
    }
    pub fn writeTo(self: Segment, bound: r.Bound, writer: *std.Io.Writer) !void {
        try bound.validate();
        if (self.exchange == 0 or self.epoch == 0 or self.partitions == 0 or self.partition >= self.partitions or
            self.source >= bound.plan.sources.len or self.sequence == std.math.maxInt(u64) or self.len > max_rows or
            (self.len == 0 and !self.terminal)) return error.InvalidRelationalExchange;
        try writer.writeAll("FXS1");
        try writer.writeAll(&definition());
        try writer.writeAll(&try bound.fingerprint());
        try writer.writeInt(u64, self.exchange, .little);
        try writer.writeByte(self.source);
        inline for (.{ "partitions", "partition", "epoch", "sequence" }) |field| try writer.writeInt(u64, @field(self, field), .little);
        try writer.writeByte(@intFromBool(self.terminal));
        try writer.writeByte(self.len);
        var previous: ?r.RowIdentity = null;
        for (self.rows[0..self.len]) |row| {
            if (try route(bound.plan, self.source, self.partitions, row) != self.partition) return error.InvalidRelationalRouting;
            if (previous) |id| if (e.identityOrder(id, row.identity) != .lt) return error.InvalidRelationalSourceOrder;
            previous = row.identity;
            var id: [20]u8 = undefined;
            identityBytes(row.identity, &id);
            try writer.writeAll(&id);
            for (row.values[0..bound.plan.sources[self.source].schema.columns.len]) |value| try values.write(writer, value);
        }
    }
    pub fn decode(allocator: std.mem.Allocator, bound: r.Bound, bytes: []const u8) !Segment {
        try bound.validate();
        if (bytes.len > max_bytes) return error.InvalidRelationalExchange;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "FXS1")) return error.InvalidRelationalExchange;
        if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
        if (!std.mem.eql(u8, try reader.take(32), &try bound.fingerprint())) return error.RelationalSourceChanged;
        var result: Segment = .{ .exchange = try reader.takeInt(u64, .little), .source = try reader.takeByte(), .partitions = try reader.takeInt(u64, .little), .partition = try reader.takeInt(u64, .little), .epoch = try reader.takeInt(u64, .little), .sequence = try reader.takeInt(u64, .little), .terminal = false };
        const terminal = try reader.takeByte();
        if (terminal > 1) return error.InvalidRelationalExchange;
        result.terminal = terminal == 1;
        result.len = try reader.takeByte();
        if (result.len > max_rows or result.source >= bound.plan.sources.len) return error.InvalidRelationalExchange;
        for (result.rows[0..result.len]) |*row| {
            row.* = .{ .identity = .{ .origin = try reader.takeInt(u64, .big), .operation = try reader.takeInt(u64, .big), .ordinal = try reader.takeInt(u32, .big) } };
            for (row.values[0..bound.plan.sources[result.source].schema.columns.len]) |*value| value.* = try values.read(&reader);
        }
        if (reader.bufferedLen() != 0) return error.InvalidRelationalExchange;
        values.checkEncoding(bytes, result, bound) catch |err| return switch (err) {
            error.WriteFailed, error.InvalidRelationalEncoding => error.InvalidRelationalExchange,
            else => err,
        };
        errdefer result.deinit();
        for (result.rows[0..result.len]) |*row| row.* = try row.clone(allocator);
        return result;
    }
};

test {
    _ = @import("relational_exchange_test.zig");
}

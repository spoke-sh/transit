//! Canonical owned mutation request. Publication transports bytes; it does not
//! authorize the caller, select rows or commit a private Table proposal.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const f = q.fuze;
const Table = q.station.Table;
const Self = @This();
pub const max_bytes = 4 + 32 + 8 * 3 + 4 + 1 + 39 + 2 + f.TableMutation.max_rows * (8 + 1 + f.model.max_cell_bytes + 2);
pub const format: u32 = 0x31524d54; // TMR1
realm: u64,
writer: u64,
resource: u64,
table: u32,
plan: f.TableMutation.Plan,

pub fn target(self: Self) Table {
    return .{ .resource = self.resource, .id = self.table, .schema = self.plan.schema };
}
pub fn validate(self: Self) !void {
    inline for (.{ "realm", "writer", "resource" }) |field| {
        const value = @field(self, field);
        if (value == 0 or value > p.max_counter) return error.InvalidTableMutationRequest;
    }
    if (self.table == 0) return error.InvalidTableMutationRequest;
    try self.plan.validate();
}
pub fn fromSql(realm: u64, writer: u64, table: Table, name: f.model.Name, text: []const u8) !Self {
    const result: Self = .{ .realm = realm, .writer = writer, .resource = table.resource, .table = table.id, .plan = try f.TableMutation.compile(text, .{ .name = name, .schema = table.schema }) };
    try result.validate();
    return result;
}
fn definition() [32]u8 {
    var result: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, @tagName(p.Growth.current_definition)) catch unreachable;
    return result;
}
fn writeRow(writer: *std.Io.Writer, table: Table, row: f.model.Row) !void {
    try writer.writeInt(i64, row.key, .little);
    const value = try table.encodeCell(row.value);
    try writer.writeByte(@intCast(value.len));
    try writer.writeAll(value.slice());
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(output);
    try writer.writeAll("TMR1");
    try writer.writeAll(&definition());
    inline for (.{ "realm", "writer", "resource" }) |field| try writer.writeInt(u64, @field(self, field), .little);
    try writer.writeInt(u32, self.table, .little);
    const descriptor = try Table.encodeSchema(self.plan.schema);
    try writer.writeByte(@intCast(descriptor.len));
    try writer.writeAll(descriptor.slice());
    switch (self.plan.operation) {
        .insert => |rows| {
            var count: u8 = 0;
            for (rows) |slot| if (slot != null) {
                count += 1;
            };
            try writer.writeAll(&.{ 1, count });
            for (rows[0..count]) |slot| try writeRow(&writer, self.target(), slot.?);
        },
        .update => |row| {
            try writer.writeAll(&.{ 2, 1 });
            try writeRow(&writer, self.target(), row);
        },
        .delete => |key| {
            try writer.writeAll(&.{ 3, 1 });
            try writer.writeInt(i64, key, .little);
        },
    }
    return writer.buffered();
}
fn readRow(reader: *std.Io.Reader, table: Table) !f.model.Row {
    const key = try reader.takeInt(i64, .little);
    const len = try reader.takeByte();
    return .{ .key = key, .value = try table.decodeCell(try p.Value.init(try reader.take(len))) };
}
/// All decoded names and cells are copied into the result. No input bytes borrow.
pub fn decode(bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.InvalidTableMutationRequest;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "TMR1")) return error.InvalidTableMutationRequest;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    var result: Self = .{
        .realm = try reader.takeInt(u64, .little),
        .writer = try reader.takeInt(u64, .little),
        .resource = try reader.takeInt(u64, .little),
        .table = try reader.takeInt(u32, .little),
        .plan = .{ .schema = undefined, .operation = .{ .delete = 0 } },
    };
    const descriptor_len = try reader.takeByte();
    result.plan.schema = try Table.decodeSchema(try p.Value.init(try reader.take(descriptor_len)));
    const operation = try reader.takeByte();
    const count = try reader.takeByte();
    result.plan.operation = switch (operation) {
        1 => blk: {
            if (count == 0 or count > f.TableMutation.max_rows) return error.InvalidTableMutationRequest;
            var rows: [f.TableMutation.max_rows]?f.model.Row = @splat(null);
            for (rows[0..count]) |*row| row.* = try readRow(&reader, result.target());
            break :blk .{ .insert = rows };
        },
        2 => blk: {
            if (count != 1) return error.InvalidTableMutationRequest;
            break :blk .{ .update = try readRow(&reader, result.target()) };
        },
        3 => blk: {
            if (count != 1) return error.InvalidTableMutationRequest;
            break :blk .{ .delete = try reader.takeInt(i64, .little) };
        },
        else => return error.InvalidTableMutationRequest,
    };
    if (reader.bufferedLen() != 0) return error.InvalidTableMutationRequest;
    try result.validate();
    return result;
}
pub fn reference(self: Self, namespace: u64) !q.station.PublicationReference {
    var bytes: [max_bytes]u8 = undefined;
    const ref: q.station.PublicationReference = .{ .domain = .table_mutation, .resource = self.resource, .namespace = namespace, .record = 1, .spec = try q.station.Publication.Digest.of(format, try self.encode(&bytes)) };
    try checkReference(ref);
    return ref;
}
pub fn checkReference(ref: q.station.PublicationReference) !void {
    try ref.validate();
    if (ref.domain != .table_mutation or ref.record != 1 or ref.spec.format != format or ref.spec.length == 0 or ref.spec.length > max_bytes) return error.InvalidTableMutationRequest;
}

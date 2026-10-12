//! Exact resumable operator state. The host publishes this record together with
//! its group root, consumed input and output coverage; bytes alone grant nothing.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const Index = @import("RelationalIndex.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const max_bytes = 8192;
pub const Phase = enum(u8) { input = 1, empty_right = 2, output = 3, complete = 4, failed = 5 };
binding: [32]u8,
root: ?Index.Reference,
phase: Phase = .input,
left: ?e.Row = null,
after_left: ?r.RowIdentity = null,
after_right: ?r.RowIdentity = null,
matched: bool = false,
right_covered: bool = false,
group_count: u64 = 0,
after_group: ?e.Key = null,
work: u64 = 0,
result_rows: u64 = 0,
result_bytes: u64 = 0,
failure: ?e.Failure = null,

pub fn grouped(plan: r.Plan) bool {
    if (plan.group_by.len != 0) return true;
    for (plan.outputs) |output| if (output.expression != .column) return true;
    return false;
}
pub fn validate(self: Self, bound: r.Bound) !void {
    try bound.validate();
    if (!std.mem.eql(u8, &self.binding, &try bound.fingerprint())) return error.RelationalSourceChanged;
    const plan = bound.plan;
    if (self.work > plan.budgets.work_steps or self.result_rows > plan.budgets.output_rows or self.result_bytes > plan.budgets.result_bytes) return error.InvalidRelationalCheckpoint;
    if (self.root) |root| {
        try Index.validateReference(root);
        if (root.entries != self.group_count) return error.InvalidRelationalCheckpoint;
    } else if (self.group_count != 0) return error.InvalidRelationalCheckpoint;
    for ([_]?r.RowIdentity{ self.after_left, self.after_right }) |id| if (id) |value| try value.validate();
    if (plan.join == null and (self.left != null or self.after_right != null or self.matched or self.right_covered or self.phase == .empty_right)) return error.InvalidRelationalCheckpoint;
    if (self.left) |row| {
        try row.identity.validate();
        if (self.after_left == null or !std.meta.eql(row.identity, self.after_left.?) or (self.phase != .input and self.phase != .failed)) return error.InvalidRelationalCheckpoint;
        const schema = plan.sources[0].schema;
        for (row.values, 0..) |value, i| {
            if (i >= schema.columns.len or schema.columns[i].type != .int64) {
                if (value != null) return error.InvalidRelationalCheckpoint;
            } else if (!schema.columns[i].nullable and value == null) return error.InvalidRelationalCheckpoint;
        }
    }
    if (self.after_group) |key| {
        try checkKey(key, plan);
        if (!grouped(plan) or (self.phase != .output and self.phase != .complete and self.phase != .failed)) return error.InvalidRelationalCheckpoint;
    }
    if (!grouped(plan)) {
        if (self.root != null or self.group_count != 0 or self.after_group != null or self.phase == .output) return error.InvalidRelationalCheckpoint;
    } else {
        if (self.result_rows > self.group_count or ((self.phase == .input or self.phase == .empty_right) and self.result_rows != 0)) return error.InvalidRelationalCheckpoint;
        if (self.phase == .complete and self.result_rows != self.group_count) return error.InvalidRelationalCheckpoint;
        if (self.phase != .failed and ((self.after_group == null) != (self.result_rows == 0))) return error.InvalidRelationalCheckpoint;
    }
    if (self.failure) |failure| {
        if (self.phase != .failed or failure.output >= plan.outputs.len or plan.outputs[failure.output].expression == .column) return error.InvalidRelationalCheckpoint;
        try failure.pair.left.validate();
        if (failure.pair.right) |right| {
            if (plan.join == null) return error.InvalidRelationalCheckpoint;
            try right.validate();
        }
        try checkKey(failure.group, plan);
    }
    var fields: [r.max_outputs]@import("Types.zig").Field = undefined;
    var schema_bytes: [@import("Types.zig").max_encoding_bytes]u8 = undefined;
    const size = (try (try plan.outputSchema(&fields)).encode(&schema_bytes)).len;
    if (self.result_bytes < size) return error.InvalidRelationalCheckpoint;
    const minimum = std.math.mul(u64, self.result_rows, plan.outputs.len * 5) catch return error.InvalidRelationalCheckpoint;
    const maximum = std.math.mul(u64, self.result_rows, plan.outputs.len * 13) catch return error.InvalidRelationalCheckpoint;
    if (self.result_bytes - size < minimum or self.result_bytes - size > maximum) return error.InvalidRelationalCheckpoint;
}
fn checkKey(key: e.Key, plan: r.Plan) !void {
    if (key.len != plan.group_by.len) return error.InvalidRelationalCheckpoint;
    for (key.values[key.len..]) |value| if (value != null) return error.InvalidRelationalCheckpoint;
}
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn encode(self: Self, bound: r.Bound, output: []u8) ![]const u8 {
    try self.validate(bound);
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FRC1");
    try writer.writeAll(&definition());
    try writer.writeAll(&self.binding);
    try Index.writeReference(&writer, self.root);
    try writer.writeByte(@backingInt(self.phase));
    try writeId(&writer, self.after_left);
    try writeId(&writer, self.after_right);
    try writer.writeByte(@intFromBool(self.left != null));
    if (self.left) |row| {
        try writer.writeAll(&try row.identity.encode());
        for (row.values[0..bound.plan.sources[0].schema.columns.len]) |value| try Index.writeOptional(&writer, value);
    }
    try writer.writeByte(@intFromBool(self.matched));
    try writer.writeByte(@intFromBool(self.right_covered));
    inline for (.{ "group_count", "work", "result_rows", "result_bytes" }) |field| try writer.writeInt(u64, @field(self, field), .little);
    try writer.writeByte(@intFromBool(self.after_group != null));
    if (self.after_group) |key| try writeKey(&writer, key);
    try writer.writeByte(@intFromBool(self.failure != null));
    if (self.failure) |failure| {
        try writer.writeAll(&try failure.pair.left.encode());
        try writeId(&writer, failure.pair.right);
        try writer.writeByte(failure.output);
        try writeKey(&writer, failure.group);
    }
    return writer.buffered();
}
pub fn decode(bound: r.Bound, bytes: []const u8) !Self {
    try bound.validate();
    if (bytes.len > max_bytes) return error.InvalidRelationalCheckpoint;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FRC1")) return error.InvalidRelationalCheckpoint;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    var self: Self = .{ .binding = (try reader.takeArray(32)).*, .root = try Index.readReference(&reader) };
    self.phase = std.enums.fromInt(Phase, try reader.takeByte()) orelse return error.InvalidRelationalCheckpoint;
    self.after_left = try readId(&reader);
    self.after_right = try readId(&reader);
    if (try boolean(&reader)) {
        var row: e.Row = .{ .identity = try r.RowIdentity.decode(try reader.takeArray(20)) };
        for (row.values[0..bound.plan.sources[0].schema.columns.len]) |*value| value.* = try Index.readOptional(&reader);
        self.left = row;
    }
    self.matched = try boolean(&reader);
    self.right_covered = try boolean(&reader);
    inline for (.{ "group_count", "work", "result_rows", "result_bytes" }) |field| @field(self, field) = try reader.takeInt(u64, .little);
    if (try boolean(&reader)) self.after_group = try readKey(&reader, bound.plan);
    if (try boolean(&reader)) self.failure = .{ .pair = .{ .left = try r.RowIdentity.decode(try reader.takeArray(20)), .right = try readId(&reader) }, .output = try reader.takeByte(), .group = try readKey(&reader, bound.plan) };
    if (reader.bufferedLen() != 0) return error.InvalidRelationalCheckpoint;
    try self.validate(bound);
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try self.encode(bound, &canonical))) return error.InvalidRelationalCheckpoint;
    return self;
}
fn boolean(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidRelationalCheckpoint,
    };
}
fn writeId(writer: *std.Io.Writer, id: ?r.RowIdentity) !void {
    try writer.writeByte(@intFromBool(id != null));
    if (id) |value| try writer.writeAll(&try value.encode());
}
fn readId(reader: *std.Io.Reader) !?r.RowIdentity {
    return if (try boolean(reader)) try r.RowIdentity.decode(try reader.takeArray(20)) else null;
}
fn writeKey(writer: *std.Io.Writer, key: e.Key) !void {
    for (key.values[0..key.len]) |value| try Index.writeOptional(writer, value);
}
fn readKey(reader: *std.Io.Reader, plan: r.Plan) !e.Key {
    var key: e.Key = .{ .len = @intCast(plan.group_by.len) };
    for (key.values[0..key.len]) |*value| value.* = try Index.readOptional(reader);
    return key;
}

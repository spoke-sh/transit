//! One current native command codec. Every field is owned and bounded; missing
//! or foreign definitions and trailing bytes reject before a ledger transition.
const std = @import("std");
const g = @import("root.zig");
const p = g.catalog.protocol;
const Self = @This();
pub const Qualified = struct { operation: u64, generation: u64 };
pub const Record = struct { operation: u64, generation: u64, record: u64 };
pub const Part = struct {
    offset: u32,
    length: u8,
    bytes: [g.Upload.part_bytes]u8,
    pub fn init(offset: u32, bytes: []const u8) !Part {
        if (bytes.len == 0 or bytes.len > g.Upload.part_bytes or offset % g.Upload.part_bytes != 0) return error.InvalidGatewayPart;
        var result: Part = .{ .offset = offset, .length = @intCast(bytes.len), .bytes = @splat(0) };
        @memcpy(result.bytes[0..bytes.len], bytes);
        return result;
    }
    pub fn validate(self: Part) !void {
        if (self.length == 0 or self.length > self.bytes.len or self.offset % self.bytes.len != 0) return error.InvalidGatewayPart;
        for (self.bytes[self.length..]) |byte| if (byte != 0) return error.InvalidGatewayPart;
    }
};
pub const Command = union(enum(u8)) {
    initialize: void = 1,
    begin: struct { nonce: [16]u8, binding: g.Ledger.Binding, fingerprint: [32]u8 = @splat(0) } = 2,
    begin_intent: struct { operation: u64, spec: g.station.Publication.Spec } = 3,
    intent_part: struct { operation: u64, part: Part } = 4,
    seal_intent: u64 = 5,
    admit_intent: Qualified = 6,
    activate: u64 = 7,
    dispatch: Qualified = 8,
    reconcile: u64 = 13,
    cancel: u64 = 14,
    cancel_unsent: Qualified = 17,
    capacity: struct { operations: u64, bytes: u64, pending: u32 } = 18,
    reserve: struct { operation: u64, bytes: u64 } = 19,
    complete: struct { target: Qualified, outcome: g.Terminal } = 20,
    session_cancel: u64 = 21,
    session_resume: u64 = 22,
    external_begin: g.SessionOperations.Begin = 23,
    external_ready: struct { operation: u64, generation: u64, length: u32, digest: [32]u8 } = 24,
    external_complete: struct { operation: u64, generation: u64, summary: @FieldType(g.SessionOperations.External, "summary") } = 25,
    captured: g.CapturedLedger.Command = 26,
    pub fn validate(self: Command) !void {
        switch (self) {
            .intent_part => |value| try value.part.validate(),
            .begin_intent => |value| try value.spec.validate(),
            .complete => |value| try value.outcome.validate(),
            else => {},
        }
    }
    pub fn encode(self: Command) !p.Value {
        try self.validate();
        var buffer: [g.station.Frame.max_payload]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try writer.writeAll("GSQ1");
        try writer.writeAll(&p.Growth.definition_bytes);
        try write(&writer, self);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Command {
        try value.validate();
        if (value.len > g.station.Frame.max_payload) return error.InvalidGatewayCommand;
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "GSQ1")) return error.InvalidGatewayCommand;
        if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        const result = try read(&reader, Command);
        if (reader.bufferedLen() != 0) return error.InvalidGatewayCommand;
        try result.validate();
        return result;
    }
};
fn write(out: *std.Io.Writer, value: anytype) anyerror!void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .void => {},
        .int => try out.writeInt(T, value, .little),
        .@"enum" => |info| try out.writeInt(info.tag_type, @backingInt(value), .little),
        .array => for (value) |item| try write(out, item),
        .optional => {
            try out.writeByte(@intFromBool(value != null));
            if (value) |item| try write(out, item);
        },
        .@"struct" => |info| inline for (info.field_names) |name| try write(out, @field(value, name)),
        .@"union" => {
            try out.writeByte(@backingInt(std.meta.activeTag(value)));
            switch (value) {
                inline else => |item| try write(out, item),
            }
        },
        else => @compileError("native gateway controls require bounded owned fields"),
    }
}
fn read(input: *std.Io.Reader, comptime T: type) anyerror!T {
    return switch (@typeInfo(T)) {
        .void => {},
        .int => try input.takeInt(T, .little),
        .@"enum" => |info| std.enums.fromInt(T, try input.takeInt(info.tag_type, .little)) orelse error.InvalidGatewayCommand,
        .array => |info| blk: {
            var result: T = undefined;
            for (&result) |*item| item.* = try read(input, info.child);
            break :blk result;
        },
        .optional => |info| switch (try input.takeByte()) {
            0 => null,
            1 => try read(input, info.child),
            else => error.InvalidGatewayCommand,
        },
        .@"struct" => |info| blk: {
            var result: T = undefined;
            inline for (info.field_names) |name| @field(result, name) = try read(input, @FieldType(T, name));
            break :blk result;
        },
        .@"union" => |info| blk: {
            const tag = try read(input, info.tag_type.?);
            inline for (info.field_names) |name| if (tag == @field(info.tag_type.?, name)) break :blk @unionInit(T, name, try read(input, @FieldType(T, name)));
            return error.InvalidGatewayCommand;
        },
        else => @compileError("native gateway controls require bounded owned fields"),
    };
}
pub const Disposition = struct {
    pub const magic = "GSD1";
    input: u64,
    principal: u64,
    payload: [32]u8,
    cause_length: u8,
    cause: [64]u8,
    pub fn init(turn: *g.station.Turn, failure: anyerror) !Disposition {
        const name = @errorName(failure);
        if (name.len > 64) return error.UnrepresentableGatewayFailure;
        var value: Disposition = .{ .input = turn.delivery.input.position, .principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0, .payload = try g.catalog.Model.fingerprint(turn.delivery.input.value), .cause_length = @intCast(name.len), .cause = @splat(0) };
        @memcpy(value.cause[0..name.len], name);
        try value.validate();
        return value;
    }
    pub fn validate(self: Disposition) !void {
        if (self.input == 0 or self.input > p.max_counter or self.principal > p.max_counter or self.cause_length == 0 or self.cause_length > 64) return error.InvalidGatewayDisposition;
        for (self.cause[0..self.cause_length]) |byte| if (!std.ascii.isAlphanumeric(byte)) return error.InvalidGatewayDisposition;
        for (self.cause[self.cause_length..]) |byte| if (byte != 0) return error.InvalidGatewayDisposition;
    }
};
test "native gateway commands require exact definition, lengths, optional flags and owned parts" {
    const t = std.testing;
    var bytes: [128]u8 = @splat(13);
    const command: Command = .{ .intent_part = .{ .operation = 99, .part = try Part.init(128, &bytes) } };
    var encoded = try command.encode();
    @memset(&bytes, 0);
    try t.expectEqual(@as(u16, 178), encoded.len);
    try t.expectEqualDeep(command, try Command.decode(encoded));
    for (0..encoded.len) |end| {
        if (Command.decode(try p.Value.init(encoded.slice()[0..end]))) |_| return error.ExpectedTruncationFailure else |_| {}
    }
    encoded.data[4] ^= 1;
    try t.expectError(error.IncompatibleDefinition, Command.decode(encoded));
    encoded.data[4] ^= 1;
    encoded.len += 1;
    try t.expectError(error.InvalidGatewayCommand, Command.decode(encoded));
    const complete: Command = .{ .complete = .{ .target = .{ .operation = 7, .generation = 2 }, .outcome = .{ .kind = .dml, .identity = @splat(1), .resource = 9, .principal = 11, .operation = 7, .object = 1, .partition = 20, .next_lsn = 21, .resulting_revision = 1, .state = .applied, .matched = std.math.maxInt(u64), .changed = std.math.maxInt(u64) - 1 } } };
    try t.expectEqualDeep(complete, try Command.decode(try complete.encode()));
}

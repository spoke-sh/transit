//! Owned host values around the shared Document model. No CRDT logic lives here.
const std = @import("std");
pub const document = @import("transit_station_document");
const m = document.Model;
const a = @import("Actions.zig");
const base = @import("Abi.zig");
const p = document.station.protocol;
pub const maximum_json_bytes = 32768;
pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidDocumentInteger;
    for (text) |b| if (!std.ascii.isDigit(b)) return error.InvalidDocumentInteger;
    return std.fmt.parseInt(u64, text, 10);
}
fn signed(text: []const u8) !i64 {
    const negative = std.mem.startsWith(u8, text, "-");
    const magnitude = try unsigned(if (negative) text[1..] else text);
    if (negative and magnitude == 0) return error.InvalidDocumentInteger;
    return std.fmt.parseInt(i64, text, 10);
}
pub fn unhex(alloc: std.mem.Allocator, text: []const u8, limit: usize) ![]const u8 {
    if (text.len % 2 != 0 or text.len / 2 > limit) return error.DocumentEncodingCapacity;
    const bytes = try alloc.alloc(u8, text.len / 2);
    return std.fmt.hexToBytes(bytes, text);
}
pub const Dot = struct {
    counter: []const u8 = "0",
    replica: []const u8 = "0",
    pub fn native(self: Dot) !m.Dot {
        return .{ .counter = try unsigned(self.counter), .replica = try unsigned(self.replica) };
    }
    pub fn fromNative(alloc: std.mem.Allocator, value: m.Dot) !Dot {
        return .{ .counter = try a.decimal(alloc, value.counter), .replica = try a.decimal(alloc, value.replica) };
    }
};
pub const Scalar = union(enum) {
    null_value,
    boolean: bool,
    signed: []const u8,
    unsigned: []const u8,
    float_bits: []const u8,
    string: []const u8,
    binary: []const u8,
    map,
    list,
    text,
    character: []const u8,
    pub fn native(self: Scalar, alloc: std.mem.Allocator) !m.Scalar {
        const result: m.Scalar = switch (self) {
            .null_value => .null_value,
            .boolean => |v| .{ .boolean = v },
            .signed => |v| .{ .signed = try signed(v) },
            .unsigned => |v| .{ .unsigned = try unsigned(v) },
            .float_bits => |v| blk: {
                if (v.len != 16) return error.InvalidDocumentScalar;
                const bytes = try unhex(alloc, v, 8);
                break :blk .{ .float = @bitCast(std.mem.readInt(u64, bytes[0..8], .little)) };
            },
            .string => |v| .{ .string = try m.Bytes.init(v) },
            .binary => |v| .{ .binary = try m.Bytes.init(try unhex(alloc, v, 96)) },
            .map => .map,
            .list => .list,
            .text => .text,
            .character => |v| blk: {
                const view = try std.unicode.Utf8View.init(v);
                var iterator = view.iterator();
                const cp = iterator.nextCodepoint() orelse return error.InvalidDocumentUnicode;
                if (iterator.nextCodepoint() != null) return error.InvalidDocumentUnicode;
                break :blk .{ .character = cp };
            },
        };
        try result.validate();
        return result;
    }
    pub fn fromNative(alloc: std.mem.Allocator, value: m.Scalar) !Scalar {
        return switch (value) {
            .null_value => .null_value,
            .boolean => |v| .{ .boolean = v },
            .signed => |v| .{ .signed = try a.decimal(alloc, v) },
            .unsigned => |v| .{ .unsigned = try a.decimal(alloc, v) },
            .float => |v| blk: {
                var bytes: [8]u8 = undefined;
                std.mem.writeInt(u64, &bytes, @bitCast(v), .little);
                break :blk .{ .float_bits = try a.hex(alloc, &bytes) };
            },
            .string => |v| .{ .string = try alloc.dupe(u8, v.slice()) },
            .binary => |v| .{ .binary = try a.hex(alloc, v.slice()) },
            .map => .map,
            .list => .list,
            .text => .text,
            .character => |v| blk: {
                var bytes: [4]u8 = undefined;
                const len = try std.unicode.utf8Encode(@intCast(v), &bytes);
                break :blk .{ .character = try alloc.dupe(u8, bytes[0..len]) };
            },
        };
    }
};
pub const Operation = union(enum) {
    assign: struct { object: Dot = .{}, field: []const u8, observed: []const Dot = &.{}, value: Scalar },
    remove: struct { object: Dot = .{}, field: []const u8, observed: []const Dot },
    insert: struct { object: Dot, after: Dot = .{}, value: Scalar },
    set_element: struct { object: Dot, element: Dot, observed: []const Dot, value: Scalar },
    delete_element: struct { object: Dot, element: Dot },
    pub fn native(self: Operation, alloc: std.mem.Allocator) !m.Operation {
        switch (self) {
            inline else => |value, tag| {
                var payload: @FieldType(m.Operation, @tagName(tag)) = undefined;
                payload.object = try value.object.native();
                if (@hasField(@TypeOf(payload), "field")) payload.field = try m.Name.init(value.field);
                if (@hasField(@TypeOf(payload), "element")) payload.element = try value.element.native();
                if (@hasField(@TypeOf(payload), "after")) payload.after = try value.after.native();
                if (@hasField(@TypeOf(payload), "observed")) {
                    if (value.observed.len > m.max_conflicts) return error.DocumentConflictCapacity;
                    payload.observed = .{ .len = @intCast(value.observed.len) };
                    for (value.observed, 0..) |dot, i| payload.observed.dots[i] = try dot.native();
                }
                if (@hasField(@TypeOf(payload), "value")) payload.value = try value.value.native(alloc);
                return @unionInit(m.Operation, @tagName(tag), payload);
            },
        }
    }
    pub fn fromNative(alloc: std.mem.Allocator, operation: m.Operation) !Operation {
        switch (operation) {
            inline else => |value, tag| {
                var payload: @FieldType(Operation, @tagName(tag)) = undefined;
                payload.object = try Dot.fromNative(alloc, value.object);
                if (@hasField(@TypeOf(payload), "field")) payload.field = try alloc.dupe(u8, value.field.slice());
                if (@hasField(@TypeOf(payload), "element")) payload.element = try Dot.fromNative(alloc, value.element);
                if (@hasField(@TypeOf(payload), "after")) payload.after = try Dot.fromNative(alloc, value.after);
                if (@hasField(@TypeOf(payload), "observed")) {
                    const observed = try alloc.alloc(Dot, value.observed.len);
                    for (observed, value.observed.slice()) |*out, dot| out.* = try Dot.fromNative(alloc, dot);
                    payload.observed = observed;
                }
                if (@hasField(@TypeOf(payload), "value")) payload.value = try Scalar.fromNative(alloc, value.value);
                return @unionInit(Operation, @tagName(tag), payload);
            },
        }
    }
};
pub const Change = struct {
    document: []const u8,
    epoch: []const u8,
    type_revision: u32 = 1,
    replica: []const u8,
    previous: []const u8 = "0",
    first: []const u8,
    operations: []const Operation,
    pub fn native(self: Change, alloc: std.mem.Allocator) !m.Change {
        if (self.operations.len == 0 or self.operations.len > m.max_operations) return error.InvalidDocumentChange;
        var out: m.Change = .{ .document = try unsigned(self.document), .epoch = try unsigned(self.epoch), .type_revision = self.type_revision, .replica = try unsigned(self.replica), .previous = try unsigned(self.previous), .first = try unsigned(self.first), .len = @intCast(self.operations.len) };
        for (self.operations, 0..) |op, i| out.operations[i] = try op.native(alloc);
        try out.validate();
        return out;
    }
    pub fn fromNative(alloc: std.mem.Allocator, value: m.Change) !Change {
        try value.validate();
        const ops = try alloc.alloc(Operation, value.len);
        for (ops, value.operations[0..value.len]) |*out, op| out.* = try Operation.fromNative(alloc, op);
        return .{ .document = try a.decimal(alloc, value.document), .epoch = try a.decimal(alloc, value.epoch), .type_revision = value.type_revision, .replica = try a.decimal(alloc, value.replica), .previous = try a.decimal(alloc, value.previous), .first = try a.decimal(alloc, value.first), .operations = ops };
    }
};
pub const Reference = struct {
    resource: u64,
    document: []const u8,
    epoch: []const u8,
    type_revision: u32,
    revision: []const u8,
    pub fn native(self: Reference) !document.Client.Reference {
        const out: document.Client.Reference = .{ .resource = self.resource, .document = try unsigned(self.document), .epoch = try unsigned(self.epoch), .type_revision = self.type_revision, .revision = try unsigned(self.revision) };
        _ = try out.encode();
        return out;
    }
    pub fn fromNative(alloc: std.mem.Allocator, value: document.Client.Reference) !Reference {
        return .{ .resource = value.resource, .document = try a.decimal(alloc, value.document), .epoch = try a.decimal(alloc, value.epoch), .type_revision = value.type_revision, .revision = try a.decimal(alloc, value.revision) };
    }
};
pub const Action = union(enum) { prepare: Change, decode: []const u8, reference: Reference, inspect_reference: p.Value };
pub const Result = union(enum) { prepared: struct { bytes: []const u8, spec: document.station.Publication.Spec }, change: Change, reference: p.Value, inspected_reference: Reference };
pub fn apply(alloc: std.mem.Allocator, action: Action) !Result {
    switch (action) {
        .prepare => |input| {
            var bytes: [m.max_change_bytes]u8 = undefined;
            const encoded = try document.codec.encode(try input.native(alloc), &bytes);
            return .{ .prepared = .{ .bytes = try a.hex(alloc, encoded), .spec = try document.station.Publication.Digest.of(document.Service.change_format, encoded) } };
        },
        .decode => |bytes| return .{ .change = try Change.fromNative(alloc, try document.codec.decode(try unhex(alloc, bytes, m.max_change_bytes))) },
        .reference => |input| return .{ .reference = try (try input.native()).encode() },
        .inspect_reference => |bytes| return .{ .inspected_reference = try Reference.fromNative(alloc, try document.Client.Reference.decode(bytes)) },
    }
}
pub fn codec(json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > maximum_json_bytes) return .invalid_argument;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const action = std.json.parseFromSlice(Action, alloc, json[0..len], .{}) catch |err| return base.failure(err, out);
    const result = apply(alloc, action.value) catch |err| return base.failure(err, out);
    base.output(result, out) catch |err| return base.status(err);
    return .ok;
}
test "Document host codec preserves owned full-width and Unicode values through shared Zig" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const change: Change = .{ .document = "18446744073709551615", .epoch = "1", .replica = "18446744073709551615", .first = "1", .operations = &.{
        .{ .assign = .{ .field = "value", .value = .{ .signed = "-9223372036854775808" } } },
        .{ .assign = .{ .field = "body", .value = .text } },
        .{ .insert = .{ .object = .{ .counter = "2", .replica = "18446744073709551615" }, .value = .{ .character = "🙂" } } },
        .{ .assign = .{ .field = "binary", .value = .{ .binary = "00ff" } } },
    } };
    const prepared = (try apply(alloc, .{ .prepare = change })).prepared;
    const restored = (try apply(alloc, .{ .decode = prepared.bytes })).change;
    try t.expectEqualStrings(change.document, restored.document);
    try t.expectEqualStrings("-9223372036854775808", restored.operations[0].assign.value.signed);
    try t.expectEqualStrings("🙂", restored.operations[2].insert.value.character);
    try t.expectEqualStrings("00ff", restored.operations[3].assign.value.binary);
    try t.expectEqualStrings(prepared.bytes, (try apply(alloc, .{ .prepare = restored })).prepared.bytes);
    const negative_zero: Scalar = .{ .float_bits = "0000000000000080" };
    try t.expectEqualStrings(negative_zero.float_bits, (try Scalar.fromNative(alloc, try negative_zero.native(alloc))).float_bits);
    try t.expectError(error.InvalidDocumentScalar, (Scalar{ .float_bits = "000000000000f07f" }).native(alloc));
    try t.expectError(error.InvalidDocumentInteger, unsigned("01"));
    try t.expectError(error.InvalidDocumentInteger, signed("-0"));
    try t.expectError(error.InvalidDocumentUnicode, (Scalar{ .character = "é" }).native(alloc));
    try t.expectError(error.InvalidDocumentUnicode, (Scalar{ .character = "" }).native(alloc));
}

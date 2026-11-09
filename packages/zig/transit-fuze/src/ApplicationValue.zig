//! Values shared by the ordered evaluator and its native host. Protected bytes
//! never enter this representation: references name transient, purpose-bound
//! reservations and confer no authority to redeem them.
const std = @import("std");
const p = @import("transit_protocol");
const a = @import("ApplicationProgram.zig");
pub const Kind = a.Types.Kind;
pub const Reference = struct { id: [32]u8 };
pub const Field = struct { name: []const u8, value: Value };
pub const Value = union(enum) {
    null,
    boolean: bool,
    integer: i64,
    text: []const u8,
    binary: []const u8,
    uuid: [16]u8,
    /// UTC microseconds since epoch, matching the SQL timestamp representation.
    timestamp: i64,
    /// Signed microseconds. Arithmetic and native seconds conversion are checked.
    duration: i64,
    json: []const u8,
    record: []const Field,
    secret: struct { reference: Reference, revision: []const u8 },
    protected_json: Reference,
    capability: Reference,
    failure: struct { code: []const u8, effect_outcome: []const u8 },
    /// A protected scalar projection, such as JSON_VALUE(token.body, '$.error').
    /// Its logical kind remains visible to binding; its bytes stay in the host.
    sealed: struct { kind: Kind, reference: Reference },

    /// Binary values always use lowercase hex strings, including valid UTF-8
    /// and empty bytes. The host JSON shape remains a string in every case.
    pub fn jsonStringify(self: Value, out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.beginObject();
        switch (self) {
            inline else => |item, tag| {
                try out.objectField(@tagName(tag));
                switch (tag) {
                    .binary => try out.write(Hex{ .bytes = item }),
                    .secret => try p.Json.write(Secret{ .reference = item.reference, .revision = .{ .bytes = item.revision } }, out),
                    else => try p.Json.write(item, out),
                }
            },
        }
        try out.endObject();
    }
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Value {
        return jsonParseFromValue(allocator, try std.json.innerParse(std.json.Value, allocator, source, options), options);
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, node: std.json.Value, options: std.json.ParseOptions) std.json.ParseFromValueError!Value {
        p.Json.validateShape(Value, node) catch return error.UnexpectedToken;
        const info = @typeInfo(Value).@"union";
        inline for (info.field_names, info.field_types) |name, T| {
            if (node.object.get(name)) |item| {
                if (T == void) return .null;
                if (comptime std.mem.eql(u8, name, "binary")) return .{ .binary = (try Hex.jsonParseFromValue(allocator, item, options)).bytes };
                if (comptime std.mem.eql(u8, name, "secret")) {
                    const secret = try std.json.innerParseFromValue(Secret, allocator, item, options);
                    return .{ .secret = .{ .reference = secret.reference, .revision = secret.revision.bytes } };
                }
                return @unionInit(Value, name, try std.json.innerParseFromValue(T, allocator, item, options));
            }
        }
        return error.UnknownField;
    }

    pub fn kind(self: Value) Kind {
        return switch (self) {
            .sealed => |value| value.kind,
            inline else => |_, tag| @field(Kind, @tagName(tag)),
        };
    }
    pub fn protected(self: Value) bool {
        return self == .secret or self == .protected_json or self == .sealed;
    }
    pub fn public(self: Value) anyerror!void {
        return self.publicDepth(0);
    }
    fn publicDepth(self: Value, depth: usize) anyerror!void {
        if (depth > a.max_depth) return error.ProgramTooDeep;
        if (self.protected() or self == .capability or self == .failure) return error.ProtectedProgramValue;
        if (self == .record) {
            if (self.record.len > a.max_arguments + 1) return error.ProgramTooComplex;
            for (self.record) |entry| try entry.value.publicDepth(depth + 1);
        }
    }
    pub fn field(self: Value, name: []const u8) !Value {
        if (self == .null) return .null;
        if (self == .secret and std.mem.eql(u8, name, "revision")) return .{ .binary = self.secret.revision };
        if (self == .failure and std.mem.eql(u8, name, "effect_outcome")) return .{ .text = self.failure.effect_outcome };
        if (self != .record) return error.ProgramTypeMismatch;
        for (self.record) |entry| if (std.mem.eql(u8, entry.name, name)) return entry.value;
        return error.UnknownProgramField;
    }
    /// The host independently validates a reference's scope, original owner,
    /// purpose, expiry and live transient reservation before any redemption.
    pub fn validate(self: Value, expected: a.Types.Value) !void {
        var bytes: usize = 0;
        try self.validateDepth(expected, 0, &bytes);
    }
    fn validateDepth(self: Value, expected: a.Types.Value, depth: usize, bytes: *usize) anyerror!void {
        if (depth > a.max_depth) return error.ProgramTooDeep;
        if (self == .null) {
            if (expected.kind != .null and !expected.nullable) return error.ProgramNullabilityMismatch;
            return;
        }
        if (self.kind() != expected.kind or self.protected() != expected.protected) return error.ProgramTypeMismatch;
        switch (self) {
            .text, .json => |text| {
                if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidSqlEncoding;
                bytes.* = try std.math.add(usize, bytes.*, text.len);
                if (bytes.* > 1024 * 1024) return error.ProgramTooComplex;
                if (self == .json) try validateJson(text);
            },
            .binary => |value| bytes.* = try std.math.add(usize, bytes.*, value.len),
            .record => |fields| {
                if (fields.len != expected.fields.len or fields.len > a.max_arguments + 1) return error.ProgramTypeMismatch;
                for (fields, expected.fields) |entry, wanted| {
                    if (!std.mem.eql(u8, entry.name, wanted.name)) return error.ProgramTypeMismatch;
                    try entry.value.validateDepth(wanted.value, depth + 1, bytes);
                }
            },
            .secret => |value| {
                try reference(value.reference);
                if (value.revision.len == 0 or value.revision.len > 2048) return error.ProgramTypeMismatch;
                bytes.* = try std.math.add(usize, bytes.*, value.revision.len);
            },
            .protected_json, .capability => |value| try reference(value),
            .sealed => |value| {
                switch (value.kind) {
                    .boolean, .integer, .text, .binary, .uuid, .timestamp, .duration, .json => {},
                    else => return error.ProgramTypeMismatch,
                }
                try reference(value.reference);
            },
            .failure => |failure| {
                if (failure.code.len == 0 or failure.code.len > 255 or failure.effect_outcome.len == 0 or failure.effect_outcome.len > 63) return error.ProgramTypeMismatch;
                bytes.* += failure.code.len + failure.effect_outcome.len;
            },
            else => {},
        }
        if (bytes.* > 1024 * 1024) return error.ProgramTooComplex;
    }
    fn reference(value: Reference) !void {
        if (std.mem.allEqual(u8, &value.id, 0)) return error.ProtectedProgramValue;
    }
    fn validateJson(bytes: []const u8) !void {
        var scratch: [4096]u8 = undefined;
        var fixed = std.heap.FixedBufferAllocator.init(&scratch);
        var scanner = std.json.Scanner.initCompleteInput(fixed.allocator(), bytes);
        defer scanner.deinit();
        var depth: usize = 0;
        while (true) switch (try scanner.next()) {
            .end_of_document => return,
            .object_begin, .array_begin => {
                depth += 1;
                if (depth > a.max_depth) return error.ProgramTooDeep;
            },
            .object_end, .array_end => depth -= 1,
            else => {},
        };
    }
};

const Secret = struct { reference: Reference, revision: Hex };
const Hex = struct {
    bytes: []const u8,
    pub fn jsonStringify(self: Hex, out: *std.json.Stringify) std.Io.Writer.Error!void {
        if (self.bytes.len > 1024 * 1024) return error.WriteFailed;
        try out.print("\"{x}\"", .{self.bytes});
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, node: std.json.Value, _: std.json.ParseOptions) std.json.ParseFromValueError!Hex {
        if (node != .string) return error.UnexpectedToken;
        const text = node.string;
        if (text.len > 2 * 1024 * 1024) return error.LengthMismatch;
        if (text.len % 2 != 0) return error.InvalidCharacter;
        for (text) |byte| if (!(byte >= '0' and byte <= '9') and !(byte >= 'a' and byte <= 'f')) return error.InvalidCharacter;
        const bytes = try allocator.alloc(u8, text.len / 2);
        errdefer allocator.free(bytes);
        _ = std.fmt.hexToBytes(bytes, text) catch return error.InvalidCharacter;
        return .{ .bytes = bytes };
    }
};

test "application binary values have one owned encoding for every byte and nested revision" {
    const t = std.testing;
    var bytes: [256]u8 = undefined;
    for (&bytes, 0..) |*byte, index| byte.* = @intCast(index);
    const nested: Value = .{ .record = &.{
        .{ .name = "digest", .value = .{ .binary = &bytes } },
        .{ .name = "credential", .value = .{ .secret = .{ .reference = .{ .id = @splat(1) }, .revision = &bytes } } },
    } };
    const encoded = try p.Json.valueAlloc(t.allocator, nested);
    const parsed = try p.Json.parseFromSliceOwned(Value, t.allocator, encoded);
    t.allocator.free(encoded);
    defer parsed.deinit();
    @memset(&bytes, 0);
    for ((try parsed.value.field("digest")).binary, 0..) |byte, index| try t.expectEqual(@as(u8, @intCast(index)), byte);
    for ((try parsed.value.field("credential")).secret.revision, 0..) |byte, index| try t.expectEqual(@as(u8, @intCast(index)), byte);
    for ([_][]const u8{ "", "ASCII", "\xc3\xa9" }, [_][]const u8{ "{\"binary\":\"\"}", "{\"binary\":\"4153434949\"}", "{\"binary\":\"c3a9\"}" }) |input, expected| {
        const wire = try p.Json.valueAlloc(t.allocator, Value{ .binary = input });
        defer t.allocator.free(wire);
        try t.expectEqualStrings(expected, wire);
        const decoded = try p.Json.parseFromSliceOwned(Value, t.allocator, wire);
        defer decoded.deinit();
        try t.expectEqualSlices(u8, input, decoded.value.binary);
    }
    for ([_][]const u8{ "{\"binary\":[]}", "{\"binary\":[0,255]}", "{\"binary\":null}", "{\"integer\":\"1\"}", "{\"uuid\":\"0123456789012345\"}" }) |invalid| try t.expectError(error.InvalidJsonShape, p.Json.parseFromSliceOwned(Value, t.allocator, invalid));
    for ([_][]const u8{ "{\"binary\":\"f\"}", "{\"binary\":\"FF\"}", "{\"binary\":\"gg\"}" }) |invalid| try t.expectError(error.InvalidCharacter, p.Json.parseFromSliceOwned(Value, t.allocator, invalid));
}

test "application values retain protected handles without admitting ordinary persistence" {
    const t = std.testing;
    const value: Value = .{ .secret = .{ .reference = .{ .id = @splat(1) }, .revision = "revision" } };
    try value.validate(.{ .kind = .secret, .protected = true });
    try t.expectError(error.ProtectedProgramValue, value.public());
    try (try value.field("revision")).public();
    const projected: Value = .{ .sealed = .{ .kind = .text, .reference = .{ .id = @splat(2) } } };
    try projected.validate(.{ .kind = .text, .protected = true });
    try t.expectError(error.ProtectedProgramValue, projected.public());
    try t.expectError(error.ProgramTypeMismatch, (Value{ .text = "credential" }).validate(.{ .kind = .text, .protected = true }));
    try t.expectError(error.ProgramTypeMismatch, projected.validate(.{ .kind = .text }));
    try t.expectError(error.ProtectedProgramValue, (Value{ .capability = .{ .id = @splat(4) } }).public());
    try t.expectEqual(@as(Value, .null), try (@as(Value, .null)).field("missing"));
}

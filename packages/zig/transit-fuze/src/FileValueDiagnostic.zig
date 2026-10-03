//! Owned first conversion failure. No allocation or borrowed row/schema memory.
const std = @import("std");
const types = @import("Types.zig");
const Self = @This();
pub const Origin = enum { inferred, specified, raw };
pub const Actual = enum { missing, null_value, boolean, string, number, array, object };
pub const Path = struct {
    bytes: [256]u8 = @splat(0),
    len: u16 = 0,
    truncated: bool = false,
    pub fn slice(self: *const Path) []const u8 {
        return self.bytes[0..self.len];
    }
    fn append(self: *Path, bytes: []const u8) void {
        if (self.truncated) return;
        if (bytes.len > self.bytes.len - self.len) {
            self.truncated = true;
            return;
        }
        @memcpy(self.bytes[self.len..][0..bytes.len], bytes);
        self.len += @intCast(bytes.len);
    }
    /// JSON Pointer escaping keeps '.', '/', '~' and numeric field names
    /// unambiguous. Array indices are zero-based, as in JSON Pointer.
    pub fn field(self: Path, name: []const u8) Path {
        var next = self;
        next.append("/");
        var at: usize = 0;
        while (at < name.len) {
            const width = std.unicode.utf8ByteSequenceLength(name[at]) catch 1;
            const end = @min(at + width, name.len);
            next.append(switch (name[at]) {
                '~' => "~0",
                '/' => "~1",
                else => name[at..end],
            });
            at = end;
        }
        return next;
    }
    pub fn index(self: Path, ordinal: usize) Path {
        var bytes: [20]u8 = undefined;
        return self.field(std.fmt.bufPrint(&bytes, "{d}", .{ordinal}) catch unreachable);
    }
};
path: Path,
expected: [64]u8 = @splat(0),
expected_len: u8 = 0,
actual: Actual,
preview: [128]u8 = @splat(0),
preview_len: u8 = 0,
preview_truncated: bool = false,
has_preview: bool = false,
expected_count: ?u64 = null,
actual_count: ?u64 = null,
map_key: bool = false,
nullable: ?bool = null,
optional: ?bool = null,
origin: ?Origin = null,
sampling_records: u64 = 0,
sampling_bytes: u64 = 0,
sampling_complete: bool = false,

pub fn expectedType(self: *const Self) []const u8 {
    return self.expected[0..self.expected_len];
}
pub fn scalar(self: *const Self) []const u8 {
    return self.preview[0..self.preview_len];
}
pub fn init(path: Path, expected: ?types.Type, actual: ?std.json.Value) Self {
    var result: Self = .{ .path = path, .actual = if (actual) |value| switch (value) {
        .null => .null_value,
        .bool => .boolean,
        .string => .string,
        .number_string, .integer, .float => .number,
        .array => .array,
        .object => .object,
    } else .missing };
    var out: std.Io.Writer = .fixed(&result.expected);
    if (expected) |kind| switch (kind) {
        .decimal => |decimal| out.print("decimal({d},{d})", .{ decimal.precision, decimal.scale }) catch unreachable,
        .timestamp => |zone| out.print("timestamp({s})", .{@tagName(zone)}) catch unreachable,
        .array => |array| {
            out.print("array({d})", .{array.length}) catch unreachable;
            result.expected_count = array.length;
        },
        else => out.writeAll(@tagName(kind)) catch unreachable,
    } else out.writeAll("declared field") catch unreachable;
    result.expected_len = @intCast(out.end);
    if (actual) |value| switch (value) {
        .string, .number_string => |bytes| result.capture(bytes),
        .bool => |boolean| result.capture(if (boolean) "true" else "false"),
        .null => result.capture("null"),
        .array => |array| result.actual_count = array.items.len,
        .object => |object| result.actual_count = object.count(),
        inline .integer, .float => |number| {
            var bytes: [64]u8 = undefined;
            result.capture(std.fmt.bufPrint(&bytes, if (@TypeOf(number) == i64) "{d}" else "{e}", .{number}) catch unreachable);
        },
    };
    return result;
}
fn capture(self: *Self, bytes: []const u8) void {
    self.has_preview = true;
    self.preview_len = @intCast(@min(bytes.len, self.preview.len));
    if (std.unicode.utf8ValidateSlice(bytes)) while (!std.unicode.utf8ValidateSlice(bytes[0..self.preview_len])) {
        self.preview_len -= 1;
    };
    @memcpy(self.preview[0..self.preview_len], bytes[0..self.preview_len]);
    self.preview_truncated = bytes.len > self.preview_len;
}

/// Each recursive conversion gets its own path; unwinding preserves the first
/// leaf failure, not the enclosing object. Tolerated cells do not publish errors.
pub const Context = struct {
    failure: *?Self,
    path: Path,
    map_key: bool = false,
    pub fn child(self: Context, name: []const u8) Context {
        return .{ .failure = self.failure, .path = self.path.field(name) };
    }
    pub fn index(self: Context, ordinal: usize) Context {
        return .{ .failure = self.failure, .path = self.path.index(ordinal) };
    }
    pub fn capture(self: Context, expected: ?types.Type, actual: ?std.json.Value) void {
        if (self.failure.* != null) return;
        self.failure.* = Self.init(self.path, expected, actual);
        self.failure.*.?.map_key = self.map_key;
    }
    pub fn validate(self: Context, cell: types.Values.Cell, field: types.Field, actual: ?std.json.Value) !void {
        cell.validate(field, .{}) catch |err| {
            self.capture(field.type, actual);
            self.failure.*.?.nullable = field.nullable;
            self.failure.*.?.optional = field.optional;
            return err;
        };
    }
};

test "file conversion evidence owns bounded paths, exact decimal type and scalar bytes" {
    const t = std.testing;
    var text = "1.234".*;
    var witness = init((Path{}).field("price/quoted~").index(2), .{ .decimal = .{ .precision = 4, .scale = 2 } }, .{ .number_string = &text });
    @memset(&text, '0');
    try t.expectEqualStrings("/price~1quoted~0/2", witness.path.slice());
    try t.expectEqualStrings("decimal(4,2)", witness.expectedType());
    try t.expectEqualStrings("1.234", witness.scalar());
    var long = (Path{}).field(&@as([254]u8, @splat('x')));
    long = long.field("東京");
    try t.expect(long.truncated);
    try t.expect(std.unicode.utf8ValidateSlice(long.slice()));
    witness = init(.{}, .utf8, .{ .string = &@as([129]u8, @splat('x')) });
    try t.expect(witness.preview_truncated);
}

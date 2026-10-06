//! Owned bounded application bytes. JSON uses lowercase hex, independent of any
//! application's serialization. No borrowed parser storage survives a response.
const std = @import("std");
const Value = @This();
pub const max_bytes = 256;
len: u16 = 0,
data: [max_bytes]u8 = @splat(0),

pub fn init(bytes: []const u8) !Value {
    if (bytes.len > max_bytes) return error.ValueTooLarge;
    var value: Value = .{};
    value.len = @intCast(bytes.len);
    @memcpy(value.data[0..bytes.len], bytes);
    return value;
}
pub fn slice(self: *const Value) []const u8 {
    return self.data[0..self.len];
}
pub fn validate(self: Value) !void {
    if (self.len > max_bytes) return error.InvalidValue;
    if (!std.mem.allEqual(u8, self.data[self.len..], 0)) return error.InvalidValue;
}
pub fn eql(a: Value, b: Value) bool {
    return a.len == b.len and std.mem.eql(u8, &a.data, &b.data);
}
/// Decimal-text convenience for sample applications. Transit never calls this.
pub fn integer(value: i64) Value {
    var buffer: [32]u8 = undefined;
    return init(std.fmt.bufPrint(&buffer, "{d}", .{value}) catch unreachable) catch unreachable;
}
pub fn asInteger(self: Value) !i64 {
    if (self.len == 0) return 0; // Sample counter starts from empty state.
    return std.fmt.parseInt(i64, self.slice(), 10);
}
pub fn jsonStringify(self: Value, out: anytype) !void {
    self.validate() catch return error.WriteFailed;
    var hex: [max_bytes * 2]u8 = undefined;
    const alphabet = "0123456789abcdef";
    for (self.slice(), 0..) |byte, i| {
        hex[2 * i] = alphabet[byte >> 4];
        hex[2 * i + 1] = alphabet[byte & 15];
    }
    try out.write(hex[0 .. self.len * 2]);
}
pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Value {
    return fromText(try std.json.innerParse([]const u8, allocator, source, options));
}
pub fn jsonParseFromValue(_: std.mem.Allocator, value: std.json.Value, _: std.json.ParseOptions) !Value {
    return switch (value) {
        .string => |text| fromText(text),
        else => error.UnexpectedToken,
    };
}
fn fromText(text: []const u8) !Value {
    if (text.len > max_bytes * 2 or text.len % 2 != 0) return error.InvalidCharacter;
    for (text) |c| if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return error.InvalidCharacter;
    var result: Value = .{};
    result.len = @intCast(text.len / 2);
    _ = std.fmt.hexToBytes(result.data[0..result.len], text) catch return error.InvalidCharacter;
    return result;
}

test "opaque bytes own parser data and enforce canonical bounded encoding" {
    const t = std.testing;
    const value = try Value.init(&.{ 0, 255, 34, 10 });
    const encoded = try std.json.Stringify.valueAlloc(t.allocator, value, .{});
    defer t.allocator.free(encoded);
    try t.expectEqualStrings("\"00ff220a\"", encoded);
    var parsed = try std.json.parseFromSlice(Value, t.allocator, encoded, .{});
    const owned = parsed.value;
    parsed.deinit();
    try t.expect(value.eql(owned));
    const tree = try std.json.parseFromSlice(std.json.Value, t.allocator, encoded, .{});
    defer tree.deinit();
    const from_value = try std.json.parseFromValue(Value, t.allocator, tree.value, .{});
    defer from_value.deinit();
    try t.expect(value.eql(from_value.value));
    try t.expectError(error.InvalidCharacter, std.json.parseFromValue(Value, t.allocator, .{ .string = "FF" }, .{}));
    try t.expectError(error.UnexpectedToken, std.json.parseFromValue(Value, t.allocator, .{ .integer = 1 }, .{}));
    try t.expectError(error.InvalidCharacter, std.json.parseFromSlice(Value, t.allocator, "\"FF\"", .{}));
    try t.expectError(error.InvalidCharacter, std.json.parseFromSlice(Value, t.allocator, "\"0\"", .{}));
    try t.expectError(error.ValueTooLarge, Value.init(&(@as([max_bytes + 1]u8, @splat(1)))));
}

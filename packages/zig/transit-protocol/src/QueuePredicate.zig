//! Owned bounded Queue selection plan. Fuze owns typed interpretation;
//! protocol values and persisted claim receipts never borrow parser storage.
const std = @import("std");
const QueuePredicate = @This();
pub const max_bytes = 2048;
len: u16 = 0,
data: [max_bytes]u8 = @splat(0),

pub fn init(bytes: []const u8) !QueuePredicate {
    if (bytes.len > max_bytes) return error.QueuePredicateTooLarge;
    var value: QueuePredicate = .{};
    value.len = @intCast(bytes.len);
    @memcpy(value.data[0..bytes.len], bytes);
    return value;
}
pub fn slice(self: *const QueuePredicate) []const u8 {
    return self.data[0..self.len];
}
pub fn validate(self: QueuePredicate) !void {
    if (self.len > max_bytes) return error.InvalidQueuePredicate;
    if (!std.mem.allEqual(u8, self.data[self.len..], 0)) return error.InvalidQueuePredicate;
}
pub fn eql(a: QueuePredicate, b: QueuePredicate) bool {
    return a.len == b.len and std.mem.eql(u8, &a.data, &b.data);
}
pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
    try out.write(.{ .type = "string", .pattern = "^(?:[0-9a-f]{2})*$", .maxLength = max_bytes * 2 });
}
pub fn jsonStringify(self: QueuePredicate, out: anytype) !void {
    self.validate() catch return error.WriteFailed;
    var hex: [max_bytes * 2]u8 = undefined;
    const alphabet = "0123456789abcdef";
    for (self.slice(), 0..) |byte, i| {
        hex[2 * i] = alphabet[byte >> 4];
        hex[2 * i + 1] = alphabet[byte & 15];
    }
    try out.write(hex[0 .. self.len * 2]);
}
pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !QueuePredicate {
    return fromText(try std.json.innerParse([]const u8, allocator, source, options));
}
pub fn jsonParseFromValue(_: std.mem.Allocator, value: std.json.Value, _: std.json.ParseOptions) !QueuePredicate {
    return switch (value) {
        .string => |text| fromText(text),
        else => error.UnexpectedToken,
    };
}
fn fromText(text: []const u8) !QueuePredicate {
    if (text.len > max_bytes * 2 or text.len % 2 != 0) return error.InvalidCharacter;
    for (text) |c| if (!(c >= '0' and c <= '9') and !(c >= 'a' and c <= 'f')) return error.InvalidCharacter;
    var result: QueuePredicate = .{};
    result.len = @intCast(text.len / 2);
    _ = std.fmt.hexToBytes(result.data[0..result.len], text) catch return error.InvalidCharacter;
    return result;
}

test "queue predicate bytes own parser data and enforce canonical bounded encoding" {
    const t = std.testing;
    const value = try QueuePredicate.init(&.{ 0, 255, 34, 10 });
    const encoded = try std.json.Stringify.valueAlloc(t.allocator, value, .{});
    defer t.allocator.free(encoded);
    try t.expectEqualStrings("\"00ff220a\"", encoded);
    var parsed = try std.json.parseFromSlice(QueuePredicate, t.allocator, encoded, .{});
    const owned = parsed.value;
    parsed.deinit();
    try t.expect(value.eql(owned));
    const tree = try std.json.parseFromSlice(std.json.Value, t.allocator, encoded, .{});
    defer tree.deinit();
    const from_value = try std.json.parseFromValue(QueuePredicate, t.allocator, tree.value, .{});
    defer from_value.deinit();
    try t.expect(value.eql(from_value.value));
    try t.expectError(error.InvalidCharacter, std.json.parseFromValue(QueuePredicate, t.allocator, .{ .string = "FF" }, .{}));
    try t.expectError(error.UnexpectedToken, std.json.parseFromValue(QueuePredicate, t.allocator, .{ .integer = 1 }, .{}));
    try t.expectError(error.InvalidCharacter, std.json.parseFromSlice(QueuePredicate, t.allocator, "\"FF\"", .{}));
    try t.expectError(error.InvalidCharacter, std.json.parseFromSlice(QueuePredicate, t.allocator, "\"0\"", .{}));
    try t.expectError(error.QueuePredicateTooLarge, QueuePredicate.init(&(@as([max_bytes + 1]u8, @splat(1)))));
}

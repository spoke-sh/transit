//! Lossless JSON parsing with pre-allocation syntax-shape limits. The caller
//! supplies its allocator/buffer budget; every number remains a JSON lexeme.
const std = @import("std");
pub const Limits = struct { bytes: usize = 65536, depth: usize = 16, tokens: usize = 4096, fields: usize = 256 };
pub fn parse(allocator: std.mem.Allocator, bytes: []const u8, limits: Limits) !std.json.Parsed(std.json.Value) {
    try preflight(bytes, limits);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{
        .allocate = .alloc_always,
        .parse_numbers = false,
        .max_value_len = limits.bytes,
        .duplicate_field_behavior = .@"error",
    });
    errdefer parsed.deinit();
    try checkFields(parsed.value, limits.fields);
    return parsed;
}
pub fn validate(bytes: []const u8) !void {
    var scratch: [1024 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    var parsed = try parse(fixed.allocator(), bytes, .{});
    defer parsed.deinit();
}
pub fn preflight(bytes: []const u8, limits: Limits) !void {
    if (bytes.len > limits.bytes) return error.JsonByteBudgetExceeded;
    if (!std.unicode.utf8ValidateSlice(bytes)) return error.InvalidUtf8;
    var depth: usize = 0;
    var tokens: usize = 1;
    var quoted = false;
    var escaped = false;
    for (bytes) |byte| {
        if (quoted) {
            if (escaped) {
                escaped = false;
                continue;
            }
            if (byte == '\\') escaped = true else if (byte == '"') quoted = false;
            continue;
        }
        switch (byte) {
            '"' => {
                quoted = true;
                tokens += 1;
            },
            '[', '{' => {
                depth += 1;
                tokens += 1;
                if (depth > limits.depth) return error.JsonDepthExceeded;
            },
            ']', '}' => {
                if (depth == 0) return error.InvalidJson;
                depth -= 1;
            },
            ',', ':' => tokens += 1,
            else => {},
        }
        if (tokens > limits.tokens) return error.JsonTokenBudgetExceeded;
    }
    if (quoted or depth != 0) return error.InvalidJson;
}
fn checkFields(value: std.json.Value, max_fields: usize) anyerror!void {
    switch (value) {
        .object => |object| {
            if (object.count() > max_fields) return error.JsonFieldBudgetExceeded;
            for (object.values()) |child| try checkFields(child, max_fields);
        },
        .array => |array| for (array.items) |child| try checkFields(child, max_fields),
        else => {},
    }
}
test "JSON preserves numeric lexemes and rejects escaped duplicate keys before use" {
    var parsed = try parse(std.testing.allocator, "{\"wide\":9007199254740993,\"fraction\":0.123456789012345678901234567890123456789}", .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("9007199254740993", parsed.value.object.get("wide").?.number_string);
    try std.testing.expectError(error.DuplicateField, parse(std.testing.allocator, "{\"a\":1,\"\\u0061\":2}", .{}));
    try std.testing.expectError(error.JsonDepthExceeded, parse(std.testing.allocator, "[[[]]]", .{ .depth = 2 }));
    try std.testing.expectError(error.JsonFieldBudgetExceeded, parse(std.testing.allocator, "{\"a\":1,\"b\":2}", .{ .fields = 1 }));
}

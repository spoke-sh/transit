//! Lossless JSON parsing with pre-allocation syntax-shape limits. The caller
//! supplies its allocator/buffer budget; every number remains a JSON lexeme.
const std = @import("std");
pub const Diagnostic = @import("JsonDiagnostic.zig");
pub const BudgetDiagnostic = @import("BudgetDiagnostic.zig");
pub const Limits = struct { bytes: usize = 65536, depth: usize = 16, tokens: usize = 4096, fields: usize = 256 };
pub fn parse(allocator: std.mem.Allocator, bytes: []const u8, limits: Limits) !std.json.Parsed(std.json.Value) {
    return parseDiagnostic(allocator, bytes, limits, null);
}
pub fn parseDiagnostic(allocator: std.mem.Allocator, bytes: []const u8, limits: Limits, diagnostic: ?*?BudgetDiagnostic) !std.json.Parsed(std.json.Value) {
    return parseContext(allocator, bytes, limits, diagnostic, null);
}
pub fn parseContext(allocator: std.mem.Allocator, bytes: []const u8, limits: Limits, diagnostic: ?*?BudgetDiagnostic, failure: ?*?Diagnostic) !std.json.Parsed(std.json.Value) {
    try preflightContext(bytes, limits, diagnostic, failure);
    var reader = Diagnostic.Reader.init(allocator, bytes, failure);
    defer reader.deinit();
    const options: std.json.ParseOptions = .{ .allocate = .alloc_always, .parse_numbers = false, .max_value_len = limits.bytes, .duplicate_field_behavior = .@"error" };
    var parsed = if (failure != null) try reader.parse(allocator, options) else try std.json.parseFromSlice(std.json.Value, allocator, bytes, options);
    errdefer parsed.deinit();
    try checkFields(parsed.value, limits.fields, diagnostic, failure, .{});
    return parsed;
}

pub fn validate(bytes: []const u8) !void {
    var scratch: [1024 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&scratch);
    var parsed = try parse(fixed.allocator(), bytes, .{});
    defer parsed.deinit();
}
pub fn preflight(bytes: []const u8, limits: Limits) !void {
    return preflightDiagnostic(bytes, limits, null);
}
pub fn preflightDiagnostic(bytes: []const u8, limits: Limits, diagnostic: ?*?BudgetDiagnostic) !void {
    return preflightContext(bytes, limits, diagnostic, null);
}
pub fn preflightContext(bytes: []const u8, limits: Limits, diagnostic: ?*?BudgetDiagnostic, failure: ?*?Diagnostic) !void {
    if (bytes.len > limits.bytes) {
        BudgetDiagnostic.save(diagnostic, .{ .dimension = .json_bytes, .required = bytes.len, .limit = limits.bytes });
        Diagnostic.remember(failure, .{ .kind = .budget });
        return error.JsonByteBudgetExceeded;
    }
    if (Diagnostic.invalidUtf8Offset(bytes)) |at| {
        Diagnostic.remember(failure, .{ .kind = .encoding, .offset = at });
        return error.InvalidUtf8;
    }
    var depth: usize = 0;
    var tokens: usize = 1;
    var quoted = false;
    var escaped = false;
    for (bytes, 0..) |byte, offset| {
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
                if (depth > limits.depth) {
                    BudgetDiagnostic.save(diagnostic, .{ .dimension = .json_depth, .required = depth, .limit = limits.depth, .minimum = true });
                    Diagnostic.remember(failure, .{ .kind = .budget, .offset = offset });
                    return error.JsonDepthExceeded;
                }
            },
            ']', '}' => {
                if (depth == 0) {
                    Diagnostic.remember(failure, .{ .kind = .syntax, .offset = offset });
                    return error.InvalidJson;
                }
                depth -= 1;
            },
            ',', ':' => tokens += 1,
            else => {},
        }
        if (tokens > limits.tokens) {
            BudgetDiagnostic.save(diagnostic, .{ .dimension = .json_tokens, .required = tokens, .limit = limits.tokens, .minimum = true });
            Diagnostic.remember(failure, .{ .kind = .budget, .offset = offset });
            return error.JsonTokenBudgetExceeded;
        }
    }
    if (quoted or depth != 0) {
        Diagnostic.remember(failure, .{ .kind = .syntax, .offset = bytes.len });
        return error.InvalidJson;
    }
}
fn checkFields(value: std.json.Value, max_fields: usize, diagnostic: ?*?BudgetDiagnostic, failure: ?*?Diagnostic, path: Diagnostic.Path) anyerror!void {
    switch (value) {
        .object => |object| {
            if (object.count() > max_fields) {
                BudgetDiagnostic.save(diagnostic, .{ .dimension = .json_fields, .required = object.count(), .limit = max_fields });
                Diagnostic.remember(failure, .{ .kind = .fields, .path = path });
                return error.JsonFieldBudgetExceeded;
            }
            for (object.keys(), object.values()) |key, child| try checkFields(child, max_fields, diagnostic, failure, path.field(key));
        },
        .array => |array| for (array.items, 0..) |child, index| try checkFields(child, max_fields, diagnostic, failure, path.index(index)),
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

test "JSON token evidence preserves original duplicate positions and nested decoded paths" {
    const t = std.testing;
    const bytes = "{\"雪\":[{\"a/b~\":1,\"a\\u002fb~\":{\"child\":2}}]}";
    var failure: ?Diagnostic = null;
    try t.expectError(error.DuplicateField, parseContext(t.allocator, bytes, .{}, null, &failure));
    try t.expectEqual(.duplicate, failure.?.kind);
    try t.expectEqualStrings("/雪/0/a~1b~0", failure.?.path.?.slice());
    try t.expectEqual(std.mem.indexOf(u8, bytes, "\"a\\u002f"), failure.?.offset);
    try t.expectEqual(std.mem.indexOf(u8, bytes, "\"a/b~\""), failure.?.earlier);
    failure = null;
    try t.expectError(error.SyntaxError, parseContext(t.allocator, "{\"x\":[1,truX]}", .{}, null, &failure));
    try t.expectEqualStrings("/x/1", failure.?.path.?.slice());
    try t.expectEqual(@as(?usize, 11), failure.?.offset);
    failure = null;
    try t.expectError(error.InvalidUtf8, parseContext(t.allocator, "{\"x\":\"a\xff\"}", .{}, null, &failure));
    try t.expectEqual(.encoding, failure.?.kind);
    try t.expectEqual(@as(?usize, 7), failure.?.offset);
    failure = null;
    try t.expectError(error.JsonFieldBudgetExceeded, parseContext(t.allocator, "{\"x\":{\"a\":1,\"b\":2}}", .{ .fields = 1 }, null, &failure));
    try t.expectEqualStrings("/x", failure.?.path.?.slice());
    try t.expectEqual(null, failure.?.offset);
}

test "JSON observing token source agrees with the original parser and leaves OOM unclassified" {
    const t = std.testing;
    for ([_][]const u8{ "null", "true", "-0.123e-10", "[]", "{}", "{\"a\":[],\"b\":{},\"c\":[false,{\"d\":2}]}", "{\"a\":1,\"a\":2}", "{\"a\":1,\"a\":truX}", "[1,,2]", "[true]x", "{\"x\":\"\\ud800\"}" }) |bytes| {
        var failure: ?Diagnostic = null;
        var original = parse(t.allocator, bytes, .{}) catch |err| {
            try t.expectError(err, parseContext(t.allocator, bytes, .{}, null, &failure));
            continue;
        };
        defer original.deinit();
        var observed = try parseContext(t.allocator, bytes, .{}, null, &failure);
        defer observed.deinit();
        const before = try std.json.Stringify.valueAlloc(t.allocator, original.value, .{});
        defer t.allocator.free(before);
        const after = try std.json.Stringify.valueAlloc(t.allocator, observed.value, .{});
        defer t.allocator.free(after);
        try t.expectEqualStrings(before, after);
        try t.expectEqual(null, failure);
    }
    var no_resize = t.FailingAllocator.init(t.allocator, .{ .resize_fail_index = 0 });
    try t.checkAllAllocationFailures(no_resize.allocator(), struct {
        fn run(allocator: std.mem.Allocator) !void {
            var failure: ?Diagnostic = null;
            var parsed = parseContext(allocator, "{\"a\":[{}, {\"b\":123}]}", .{}, null, &failure) catch |err| {
                try t.expectEqual(null, failure);
                return err;
            };
            parsed.deinit();
        }
    }.run, .{});
}

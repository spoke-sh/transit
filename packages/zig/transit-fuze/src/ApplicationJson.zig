//! Bounded JSON helpers for ordered programs. Hosts use the same strict parser
//! for public and protected bodies; this module grants no declassification.
const std = @import("std");
const a = @import("ApplicationProgram.zig");
const Json = @import("BoundedJson.zig");
const V = @import("ApplicationValue.zig").Value;
pub const max_bytes = 65536;

fn parse(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(std.json.Value) {
    return Json.parse(allocator, bytes, .{ .bytes = max_bytes }) catch |err| return switch (err) {
        error.OutOfMemory => err,
        error.JsonByteBudgetExceeded, error.JsonDepthExceeded, error.JsonTokenBudgetExceeded, error.JsonFieldBudgetExceeded => error.ProgramTooComplex,
        else => error.InvalidProgramJson,
    };
}

pub fn validatePath(path: []const u8) !void {
    if (path.len < 3 or path.len > 256 or !std.mem.startsWith(u8, path, "$.")) return error.ProgramArgumentMismatch;
    var parts = std.mem.splitScalar(u8, path[2..], '.');
    var count: usize = 0;
    while (parts.next()) |part| {
        count += 1;
        if (count > 16 or part.len == 0 or part.len > 63 or (!std.ascii.isAlphabetic(part[0]) and part[0] != '_')) return error.ProgramArgumentMismatch;
        for (part) |ch| if (!std.ascii.isAlphanumeric(ch) and ch != '_') return error.ProgramArgumentMismatch;
    }
}

pub const Projection = enum { text, integer, string };
/// Output borrows only the supplied allocator, never a parser arena. Numeric
/// projection accepts exact decimal integer tokens, with no float conversion.
pub fn project(output: std.mem.Allocator, bytes: []const u8, path: []const u8, kind: Projection) !V {
    try validatePath(path);
    var parsed = try parse(output, bytes);
    defer parsed.deinit();
    var selected = parsed.value;
    var parts = std.mem.splitScalar(u8, path[2..], '.');
    while (parts.next()) |part| {
        if (selected == .null) return .null;
        if (selected != .object) return error.ProgramTypeMismatch;
        selected = selected.object.get(part) orelse return .null;
    }
    if (selected == .null) return .null;
    if (kind == .integer) {
        if (selected != .number_string) return error.ProgramTypeMismatch;
        const text = selected.number_string;
        const digits = if (std.mem.startsWith(u8, text, "-")) text[1..] else text;
        if (digits.len == 0) return error.ProgramTypeMismatch;
        for (digits) |ch| if (!std.ascii.isDigit(ch)) return error.ProgramTypeMismatch;
        return .{ .integer = try std.fmt.parseInt(i64, text, 10) };
    }
    const text = switch (selected) {
        .string => |value| value,
        .number_string => |value| if (kind == .text) value else return error.ProgramTypeMismatch,
        .bool => |value| if (kind == .text) (if (value) "true" else "false") else return error.ProgramTypeMismatch,
        else => return error.ProgramTypeMismatch,
    };
    return .{ .text = try output.dupe(u8, text) };
}

/// Keys are unique UTF-8 strings. JSON inputs are validated before insertion;
/// protected/native handles and arbitrary record coercions cannot enter JSON.
pub fn object(output: std.mem.Allocator, args: []const V) !V {
    return objectBounded(output, args) catch |err| return if (err == error.WriteFailed) error.ProgramTooComplex else err;
}
fn objectBounded(output: std.mem.Allocator, args: []const V) !V {
    if (args.len > a.max_arguments or args.len % 2 != 0) return error.ProgramArgumentMismatch;
    for (args) |arg| try arg.public();
    const buffer = try output.alloc(u8, max_bytes);
    defer output.free(buffer);
    var writer: std.Io.Writer = .fixed(buffer);
    var json: std.json.Stringify = .{ .writer = &writer };
    try json.beginObject();
    var i: usize = 0;
    while (i < args.len) : (i += 2) {
        if (args[i] != .text or !std.unicode.utf8ValidateSlice(args[i].text)) return error.ProgramTypeMismatch;
        var previous: usize = 0;
        while (previous < i) : (previous += 2) if (std.mem.eql(u8, args[previous].text, args[i].text)) return error.DuplicateProgramField;
        try json.objectField(args[i].text);
        switch (args[i + 1]) {
            .null => try json.write(null),
            .boolean => |value| try json.write(value),
            .integer => |value| try json.write(value),
            .text => |value| {
                if (!std.unicode.utf8ValidateSlice(value)) return error.InvalidSqlEncoding;
                try json.write(value);
            },
            .json => |value| {
                var parsed = try parse(output, value);
                defer parsed.deinit();
                try json.write(parsed.value);
            },
            else => return error.ProgramTypeMismatch,
        }
    }
    try json.endObject();
    // Count/depth limits apply to the composed object too, not just each child.
    var validated = try parse(output, writer.buffered());
    defer validated.deinit();
    return .{ .json = try output.dupe(u8, writer.buffered()) };
}

fn component(writer: *std.Io.Writer, text: []const u8) !void {
    const alphabet = "0123456789ABCDEF";
    for (text) |ch| {
        if (std.ascii.isAlphanumeric(ch) or std.mem.indexOfScalar(u8, "-._~", ch) != null) {
            try writer.writeByte(ch);
        } else try writer.writeAll(&.{ '%', alphabet[ch >> 4], alphabet[ch & 15] });
    }
}

/// A pure HTTPS URL constructor. Sending/redirecting still needs the host's
/// declared authority. No credentials, fragments, existing query or controls
/// are accepted in the base. NULL members are omitted, containers refuse.
pub fn url(output: std.mem.Allocator, base: []const u8, parameters: []const u8) !V {
    return urlBounded(output, base, parameters) catch |err| return if (err == error.WriteFailed) error.ProgramTooComplex else err;
}
fn urlBounded(output: std.mem.Allocator, base: []const u8, parameters: []const u8) !V {
    if (base.len == 0 or base.len > 8192 or !std.unicode.utf8ValidateSlice(base)) return error.ProgramArgumentMismatch;
    for (base) |ch| if (ch <= 0x20 or ch == 0x7f or ch == '\\') return error.ProgramArgumentMismatch;
    const uri = std.Uri.parse(base) catch return error.ProgramArgumentMismatch;
    if (!std.mem.eql(u8, uri.scheme, "https") or uri.host == null or uri.host.?.isEmpty() or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null) return error.ProgramArgumentMismatch;
    var parsed = try parse(output, parameters);
    defer parsed.deinit();
    if (parsed.value != .object) return error.ProgramTypeMismatch;
    const buffer = try output.alloc(u8, max_bytes);
    defer output.free(buffer);
    var writer: std.Io.Writer = .fixed(buffer);
    try writer.writeAll(base);
    var entries = parsed.value.object.iterator();
    var first = true;
    while (entries.next()) |entry| {
        const value = entry.value_ptr.*;
        const text = switch (value) {
            .null => continue,
            .string, .number_string => |text| text,
            .bool => |boolean| if (boolean) "true" else "false",
            else => return error.ProgramTypeMismatch,
        };
        try writer.writeByte(if (first) '?' else '&');
        first = false;
        try component(&writer, entry.key_ptr.*);
        try writer.writeByte('=');
        try component(&writer, text);
    }
    return .{ .text = try output.dupe(u8, writer.buffered()) };
}

test "application JSON projection preserves integers and rejects ambiguous or non-scalar input" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try t.expectEqual(@as(i64, 9007199254740993), (try project(allocator, "{\"id\":9007199254740993}", "$.id", .integer)).integer);
    try t.expectEqual(.null, try project(allocator, "{\"nested\":{\"id\":null}}", "$.nested.id", .integer));
    try t.expectEqual(.null, try project(allocator, "{}", "$.id", .integer));
    for ([_][]const u8{ "{\"id\":1.0}", "{\"id\":1e3}", "{\"id\":\"1\"}", "{\"id\":true}", "{\"id\":[]}" }) |body| try t.expectError(error.ProgramTypeMismatch, project(allocator, body, "$.id", .integer));
    try t.expectError(error.Overflow, project(allocator, "{\"id\":9223372036854775808}", "$.id", .integer));
    try t.expectError(error.InvalidProgramJson, project(allocator, "{\"id\":1,\"id\":2}", "$.id", .integer));
    try t.expectError(error.ProgramArgumentMismatch, project(allocator, "{}", "$['id']", .integer));
    try t.expectError(error.ProgramTypeMismatch, project(allocator, "{\"token\":true}", "$.token", .string));
    try t.expectEqualStrings("false", (try project(allocator, "{\"nested\":{\"value\":false}}", "$.nested.value", .text)).text);
}

test "application JSON objects and URLs bound ordinary values and encode each query component" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value = try object(allocator, &.{ .{ .text = "client_id" }, .{ .text = "a+ /&?é" }, .{ .text = "id" }, .{ .integer = 9007199254740993 }, .{ .text = "empty" }, .null });
    try t.expectEqualStrings("https://example.test/authorize?client_id=a%2B%20%2F%26%3F%C3%A9&id=9007199254740993", (try url(allocator, "https://example.test/authorize", value.json)).text);
    try t.expectEqualStrings("https://example.test/", (try url(allocator, "https://example.test/", "{}")).text);
    try t.expectError(error.DuplicateProgramField, object(allocator, &.{ .{ .text = "x" }, .null, .{ .text = "x" }, .null }));
    try t.expectError(error.ProtectedProgramValue, object(allocator, &.{ .{ .text = "x" }, .{ .capability = .{ .id = @splat(1) } } }));
    for ([_][]const u8{ "http://example.test/", "https://user@example.test/", "https://example.test/?x=1", "https://example.test/#part", "https://example.test/\r\n" }) |base| try t.expectError(error.ProgramArgumentMismatch, url(allocator, base, "{}"));
    try t.expectError(error.ProgramTypeMismatch, url(allocator, "https://example.test/", "{\"x\":{}}"));
    try t.expectError(error.InvalidProgramJson, url(allocator, "https://example.test/", "{\"x\":1,\"x\":2}"));
    const huge = try allocator.alloc(u8, max_bytes);
    @memset(huge, 'x');
    try t.expectError(error.ProgramTooComplex, object(allocator, &.{ .{ .text = "x" }, .{ .text = huge } }));
}

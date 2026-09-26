const std = @import("std");
const t = std.testing;
const http = @import("root.zig");
test "request rendering preserves duplicate headers and escapes variables without resolving capture secrets" {
    const request: http.Request = .{ .method = .GET, .target = &.{ .{ .literal = "/search?q=" }, .{ .variable = .{ .name = "query", .value = "a&b\r\n" } } }, .headers = &.{ .{ .name = "X-Tag", .value = &.{.{ .literal = "one" }} }, .{ .name = "X-Tag", .value = &.{.{ .literal = "two" }} }, .{ .name = "Authorization", .value = &.{ .{ .literal = "Bearer " }, .{ .secret = .{ .binding = "api", .version = 7 } } } } } };
    var buffer: [http.Request.maximum_head_bytes]u8 = undefined;
    const captured = try request.render("example.test", 443, &buffer, null, false);
    try t.expect(std.mem.indexOf(u8, captured, "/search?q=a%26b%0D%0A") != null);
    try t.expect(std.mem.indexOf(u8, captured, "X-Tag: one\r\nX-Tag: two") != null);
    try t.expect(std.mem.indexOf(u8, captured, "{{secrets.api@7}}") != null);
    const template = try request.render("example.test", 443, &buffer, null, true);
    try t.expect(std.mem.indexOf(u8, template, "{{vars.query}}") != null);
    var provenance: std.Io.Writer = .fixed(&buffer);
    try request.provenance(&provenance);
    const parsed = try std.json.parseFromSlice(http.Request, t.allocator, provenance.buffered(), .{});
    defer parsed.deinit();
    try t.expectEqualStrings("a&b\r\n", parsed.value.target[1].variable.value);
    try t.expectEqual(@as(u64, 7), parsed.value.headers[2].value[1].secret.version);
}
test "reject header injection, ambient routing fields and unsafe request target" {
    var buffer: [http.Request.maximum_head_bytes]u8 = undefined;
    var request: http.Request = .{ .method = .POST, .target = &.{.{ .literal = "/" }}, .headers = &.{.{ .name = "X-Test", .value = &.{.{ .variable = .{ .name = "x", .value = "safe\r\nHost: stolen" } }} }} };
    try t.expectError(error.InvalidHttpHeader, request.render("example.test", 443, &buffer, null, false));
    request.headers = &.{.{ .name = "Transfer-Encoding", .value = &.{.{ .literal = "chunked" }} }};
    try t.expectError(error.ReservedHttpHeader, request.render("example.test", 443, &buffer, null, false));
    request.headers = &.{};
    request.target = &.{.{ .literal = "//other.test/" }};
    try t.expectError(error.InvalidHttpTarget, request.render("example.test", 443, &buffer, null, false));
}
test "response framing rejects ambiguous lengths and unqualified decompression" {
    try t.expectError(error.InvalidHttpFraming, http.validateResponse("HTTP/1.1 xyz Invalid\r\n\r\n"));
    _ = try http.validateResponse("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nX-A: one\r\nX-A: two\r\n\r\n");
    try t.expectError(error.InvalidHttpFraming, http.validateResponse("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"));
    try t.expectError(error.InvalidHttpFraming, http.validateResponse("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n"));
    try t.expectError(error.UnsupportedHttpEncoding, http.validateResponse("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n\r\n"));
    try t.expectError(error.InvalidHttpHeader, http.validateResponse("HTTP/1.1 200 OK\r\nBad Header: x\r\n\r\n"));
}

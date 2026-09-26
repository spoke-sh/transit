const std = @import("std");
const t = std.testing;
const http = @import("root.zig");
test "shared HTTP fixtures fix Unicode escaping and terminal record encodings" {
    const Value = http.exchange.p.Value;
    const Fixture = struct { version: u32, timing: Value, omission: Value, completion: Value, request: http.Request, rendered: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures.json"), .{});
    defer parsed.deinit();
    const fixture = parsed.value;
    try t.expectEqual(@as(u32, 1), fixture.version);
    inline for (.{ .{ http.Timing, "timing" }, .{ http.Omission, "omission" }, .{ http.Completion, "completion" } }) |item| {
        const wire = @field(fixture, item[1]);
        const value = try http.exchange.codec.decode(item[0], wire);
        try t.expect((try http.exchange.codec.encode(value)).eql(wire));
        var bad = wire;
        bad.data[3] = '9';
        try t.expectError(error.InvalidExchangeRecord, http.exchange.codec.decode(item[0], bad));
        bad = wire;
        bad.len -= 1;
        bad.data[bad.len] = 0;
        try t.expectError(error.InvalidExchangeRecord, http.exchange.codec.decode(item[0], bad));
    }
    try t.expectEqual(@as(u64, 513), (try http.exchange.codec.decode(http.Completion, fixture.completion)).response_bytes);
    var buffer: [http.Request.maximum_head_bytes]u8 = undefined;
    try t.expectEqualStrings(fixture.rendered, try fixture.request.render("example.test", 443, &buffer, null, false));
}
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
    request.target = &.{ .{ .literal = "/" }, .{ .literal = "/other.test/" } };
    try t.expectError(error.InvalidHttpTarget, request.render("example.test", 443, &buffer, null, false));
}
fn replayFixture(validator: *http.Replay.Validator, omit: bool) !void {
    try validator.push(.request_template, "{}");
    try validator.push(.request_head, "POST / HTTP/1.1\r\nContent-Length: 4\r\n\r\n");
    try validator.push(.request_body, "body");
    const heads = "HTTP/1.1 103 Early Hints\r\n\r\nHTTP/1.1 200 OK\r\nContent-Length: 513\r\nX-Private: {{omitted}}\r\n\r\n";
    // Exercise splits inside status/header delimiters, including every byte.
    for (heads) |byte| try validator.push(.response_head, &.{byte});
    var body: [513]u8 = @splat(0);
    body[256] = 255;
    try validator.push(.response_body, body[0..256]);
    try validator.push(.response_body, body[256..]);
    try validator.push(.response_trailers, "Digest: preserved\r\n\r\n");
    try validator.push(.timing, (try http.exchange.codec.encode(http.Timing{ .started_ms = 7, .elapsed_ns = 19 })).slice());
    try validator.push(.omission, (try http.exchange.codec.encode(http.Omission{ .response_headers = @intFromBool(omit), .request_secrets = 0 })).slice());
    try validator.push(.completion, (try http.exchange.codec.encode(http.Completion{ .status = 200, .request_bytes = 4, .response_bytes = 513, .heads = 2, .framing = .length })).slice());
}
test "HTTP replay checks complete ordered protocol coverage and explicit redaction gaps" {
    var v: http.Replay.Validator = .{ .terminal_status = 200 };
    try replayFixture(&v, true);
    try t.expectEqual(@as(u64, 513), (try v.finish()).response_bytes);
    var exact: http.Replay.Validator = .{ .terminal_status = 200, .policy = .require_unredacted };
    try replayFixture(&exact, true);
    try t.expectError(error.HttpReplayGap, exact.finish());
    v = .{ .terminal_status = 201 };
    try replayFixture(&v, true);
    try t.expectError(error.HttpReplayGap, v.finish());
    v = .{ .terminal_status = 200 };
    try t.expectError(error.HttpReplayGap, v.push(.response_body, "prefix"));
    try t.expectError(error.HttpReplayGap, v.finish());
    v = .{ .terminal_status = 200 };
    try v.push(.request_template, "{}");
    try t.expectError(error.HttpReplayGap, v.push(.response_body, "prefix"));
    v = .{ .terminal_status = 200 };
    try v.push(.request_template, "{}");
    try v.push(.request_head, "POST / HTTP/1.1\r\nContent-Length: 4\r\n\r\n");
    try v.push(.request_body, "cut");
    try t.expectError(error.HttpReplayGap, v.push(.response_head, "HTTP/1.1 200 OK\r\n\r\n"));
}
test "explicit followup policies preserve destination credentials and permitted method changes" {
    const parent: http.Policy.Prepared = .{ .endpoint_revision = 7, .host = "example.test", .address = "127.0.0.1", .port = 443, .tls = true, .timeout_ms = 1000, .request_bytes = 64, .response_bytes = 64, .response_headers = &.{"location"}, .trust_digest = @splat(1), .request = .{ .method = .POST, .target = &.{.{ .literal = "/operation" }}, .body_bytes = 4, .headers = &.{.{ .name = "Idempotency-Key", .value = &.{.{ .literal = "stable" }} }} }, .retry_policy = .{ .id = 1, .revision = 1, .key_header = "Idempotency-Key" }, .redirect_policy = .{ .id = 2, .revision = 1 }, .reconcile_policy = .{ .id = 3, .revision = 1, .method = .GET, .target = "/status/stable" }, .cancel_policy = .{ .id = 4, .revision = 1, .method = .DELETE, .target = "/operations/stable" } };
    _ = try http.Policy.followup(t.allocator, .retry, parent, parent, null, null);
    var next = parent;
    next.address = "169.254.169.254";
    try t.expectError(error.HttpFollowupChanged, http.Policy.followup(t.allocator, .retry, parent, next, null, null));
    next = parent;
    next.request.target = &.{.{ .literal = "/redirected" }};
    _ = try http.Policy.followup(t.allocator, .redirect, parent, next, 307, "/redirected");
    try t.expectError(error.UnsupportedHttpRedirect, http.Policy.followup(t.allocator, .redirect, parent, next, 302, "/redirected"));
    try t.expectError(error.HttpRedirectScope, http.Policy.followup(t.allocator, .redirect, parent, next, 307, "https://other.test/redirected"));
    try t.expectError(error.HttpRedirectScope, http.Policy.followup(t.allocator, .redirect, parent, next, 307, "//other.test/redirected"));
    try t.expectError(error.HttpRedirectChanged, http.Policy.followup(t.allocator, .redirect, parent, next, 307, "/unapproved"));
    next.host = "other.test";
    try t.expectError(error.HttpFollowupChanged, http.Policy.followup(t.allocator, .redirect, parent, next, 307, "/redirected"));
    next = parent;
    next.request.method = .GET;
    next.request.target = &.{.{ .literal = "/status/stable" }};
    next.request.body_bytes = 0;
    _ = try http.Policy.followup(t.allocator, .reconcile, parent, next, null, null);
    next.request.method = .POST;
    try t.expectError(error.HttpFollowupChanged, http.Policy.followup(t.allocator, .reconcile, parent, next, null, null));
    next.request.method = .DELETE;
    next.request.target = &.{.{ .literal = "/operations/stable" }};
    _ = try http.Policy.followup(t.allocator, .cancel, parent, next, null, null);
    next.cancel_policy.?.revision += 1;
    try t.expectError(error.HttpFollowupChanged, http.Policy.followup(t.allocator, .cancel, parent, next, null, null));
}
test "response framing rejects ambiguous lengths and unqualified decompression" {
    try t.expectError(error.InvalidHttpFraming, http.validateResponse("HTTP/1.1 xyz Invalid\r\n\r\n"));
    _ = try http.validateResponse("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nX-A: one\r\nX-A: two\r\n\r\n");
    try t.expectError(error.InvalidHttpFraming, http.validateResponse("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nTransfer-Encoding: chunked\r\n\r\n"));
    try t.expectError(error.InvalidHttpFraming, http.validateResponse("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nContent-Length: 0\r\n\r\n"));
    try t.expectError(error.UnsupportedHttpEncoding, http.validateResponse("HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\n\r\n"));
    try t.expectError(error.InvalidHttpHeader, http.validateResponse("HTTP/1.1 200 OK\r\nBad Header: x\r\n\r\n"));
}
test "trailer capture enforces the same finite field count as response heads" {
    var input: [1024]u8 = undefined;
    var output: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&input);
    for (0..65) |_| try writer.writeAll("X: v\r\n");
    try writer.writeAll("\r\n");
    try t.expectError(error.HttpHeadersOversize, http.Transport.captureHeaders(.{ .host = "example.test", .address = "127.0.0.1", .port = 443, .tls = true }, writer.buffered(), true, &output));
}

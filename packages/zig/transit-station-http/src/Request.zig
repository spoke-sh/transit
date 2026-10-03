//! Pure request construction. Secret resolution is supplied by the executor;
//! capture renders references instead, and never invokes that resolver.
const std = @import("std");
const http = @import("root.zig");
const Self = @This();
const Rejection = http.Service.Rejection;
const Scalar = http.exchange.AdmissionRejection.Scalar;
fn fail(context: ?*?Rejection, check: http.exchange.AdmissionRejection.Check, field: []const u8, expected: Scalar, actual: Scalar, cause: anyerror) anyerror {
    if (context) |slot| if (slot.* == null) {
        slot.* = Rejection.detail(.invalid_request, check, field, expected, actual, cause);
    };
    return cause;
}
pub const Secret = struct { binding: []const u8, version: u64 };
pub const Piece = union(enum) { literal: []const u8, variable: struct { name: []const u8, value: []const u8 }, secret: Secret };
pub const Header = struct { name: []const u8, value: []const Piece };
pub const Resolver = struct { context: *anyopaque, resolve: *const fn (*anyopaque, Secret) anyerror![]const u8 };
method: std.http.Method,
target: []const Piece,
headers: []const Header = &.{},
body_bytes: u64 = 0,
pub const maximum_head_bytes = 8192;
pub const maximum_headers = 64;
pub const maximum_pieces = 128;

/// Records literal pieces, ordinary binding bytes and credential references.
/// Runtime callers must retain this alongside the rendered non-secret head.
pub fn provenance(self: Self, writer: *std.Io.Writer) !void {
    try std.json.Stringify.value(self, .{ .emit_null_optional_fields = false }, writer);
}

fn identifier(bytes: []const u8) !void {
    if (bytes.len == 0 or bytes.len > 128) return error.InvalidHttpBinding;
    for (bytes) |b| if (!std.ascii.isAlphanumeric(b) and b != '_' and b != '-' and b != '.') return error.InvalidHttpBinding;
}
fn reserved(name: []const u8) bool {
    for ([_][]const u8{ "host", "content-length", "transfer-encoding", "connection", "proxy-authorization", "proxy-connection", "upgrade", "expect", "accept-encoding", "trailer", "te" }) |field| if (std.ascii.eqlIgnoreCase(name, field)) return true;
    return false;
}
fn parts(out: *std.Io.Writer, pieces: []const Piece, target: bool, resolver: ?Resolver, template: bool, context: ?*?Rejection, prefix: []const u8) !void {
    if (pieces.len > maximum_pieces) return fail(context, .maximum, prefix, .{ .unsigned = maximum_pieces }, .{ .unsigned = pieces.len }, error.HttpRequestTooLarge);
    for (pieces, 0..) |piece, index| {
        var path_bytes: [80]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_bytes, "{s}[{d}]", .{ prefix, index });
        switch (piece) {
            .literal => |bytes| {
                if (target) for (bytes) |b| {
                    if (b <= 32 or b >= 127 or b == '#' or b == '\\') return fail(context, .decode, path, .{ .text = "ASCII origin-form target bytes" }, .{ .text = bytes }, error.InvalidHttpTarget);
                };
                try out.writeAll(bytes);
            },
            .variable => |v| {
                identifier(v.name) catch |err| return fail(context, .decode, path, .{ .text = "valid variable name" }, .{ .text = v.name }, err);
                if (template) try out.print("{{{{vars.{s}}}}}", .{v.name}) else if (target) {
                    for (v.value) |b| {
                        if (std.ascii.isAlphanumeric(b) or std.mem.indexOfScalar(u8, "-._~", b) != null) try out.writeByte(b) else try out.print("%{X:0>2}", .{b});
                    }
                } else try out.writeAll(v.value);
            },
            .secret => |s| {
                identifier(s.binding) catch |err| return fail(context, .decode, path, .{ .text = "valid credential reference" }, .redacted, err);
                if (s.version == 0 or target) return fail(context, .policy, path, .{ .text = "versioned header credential" }, .redacted, error.InvalidHttpSecret);
                if (resolver) |r| {
                    const value = try r.resolve(r.context, s);
                    try http.validateHeader("value", value);
                    try out.writeAll(value);
                } else try out.print("{{{{secrets.{s}@{d}}}}}", .{ s.binding, s.version });
            },
        }
    }
}
/// Produces exact request-head bytes, except that capture deliberately records
/// credential references. Template mode preserves ordinary variable names too.
pub fn render(self: Self, host: []const u8, port: u16, buffer: []u8, resolver: ?Resolver, template: bool) ![]const u8 {
    return self.renderDiagnostic(host, port, buffer, resolver, template, null);
}
pub fn renderDiagnostic(self: Self, host: []const u8, port: u16, buffer: []u8, resolver: ?Resolver, template: bool, context: ?*?Rejection) ![]const u8 {
    if (buffer.len > maximum_head_bytes) return fail(context, .maximum, "request.head.buffer_bytes", .{ .unsigned = maximum_head_bytes }, .{ .unsigned = buffer.len }, error.HttpRequestTooLarge);
    if (self.headers.len > maximum_headers) return fail(context, .maximum, "request.headers", .{ .unsigned = maximum_headers }, .{ .unsigned = self.headers.len }, error.HttpRequestTooLarge);
    if (port == 0) return fail(context, .different, "endpoint.port", .{ .unsigned = 0 }, .{ .unsigned = 0 }, error.HttpRequestTooLarge);
    switch (self.method) {
        .GET, .HEAD, .POST, .PUT, .PATCH, .DELETE, .OPTIONS => {},
        else => return fail(context, .policy, "request.method", .{ .text = "GET HEAD POST PUT PATCH DELETE OPTIONS" }, .{ .text = @tagName(self.method) }, error.UnsupportedHttpMethod),
    }
    if (host.len == 0 or host.len > 253) return fail(context, .decode, "endpoint.host.bytes", .{ .text = "1..253 bytes" }, .{ .unsigned = host.len }, error.InvalidHttpAuthority);
    for (host) |b| if (!std.ascii.isAlphanumeric(b) and b != '-' and b != '.') return fail(context, .decode, "endpoint.host", .{ .text = "ASCII DNS host name" }, .redacted, error.InvalidHttpAuthority);
    if (self.target.len == 0 or self.target[0] != .literal or self.target[0].literal.len == 0 or self.target[0].literal[0] != '/') return fail(context, .decode, "request.target", .{ .text = "nonempty literal starting with /" }, .unrecorded, error.InvalidHttpTarget);
    if (std.mem.startsWith(u8, self.target[0].literal, "//")) return fail(context, .policy, "request.target[0]", .{ .text = "origin-form path; no // authority" }, .{ .text = self.target[0].literal }, error.InvalidHttpTarget);
    var out: std.Io.Writer = .fixed(buffer);
    out.print("{s} ", .{@tagName(self.method)}) catch |err| return fail(context, .maximum, "request.head.bytes", .{ .unsigned = buffer.len }, .unrecorded, err);
    parts(&out, self.target, true, null, template, context, "request.target") catch |err| return fail(context, .maximum, "request.head.bytes", .{ .unsigned = buffer.len }, .unrecorded, err);
    if (std.mem.startsWith(u8, out.buffered()[@tagName(self.method).len + 1 ..], "//")) return fail(context, .policy, "request.target", .{ .text = "origin-form path; no // authority" }, .unrecorded, error.InvalidHttpTarget);
    out.print(" HTTP/1.1\r\nHost: {s}:{d}\r\nConnection: close\r\nAccept-Encoding: identity\r\nContent-Length: {d}\r\n", .{ host, port, self.body_bytes }) catch |err| return fail(context, .maximum, "request.head.bytes", .{ .unsigned = buffer.len }, .unrecorded, err);
    var value_buffer: [maximum_head_bytes]u8 = undefined;
    defer std.crypto.secureZero(u8, &value_buffer);
    for (self.headers, 0..) |header, index| {
        var path_bytes: [64]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_bytes, "request.headers[{d}]", .{index});
        if (reserved(header.name)) return fail(context, .policy, path, .{ .text = "application header" }, .{ .text = header.name }, error.ReservedHttpHeader);
        var value: std.Io.Writer = .fixed(&value_buffer);
        parts(&value, header.value, false, resolver, template, context, path) catch |err| return fail(context, .decode, path, .unrecorded, .redacted, err);
        http.validateHeader(header.name, value.buffered()) catch |err| return fail(context, .decode, path, .{ .text = "valid HTTP header name/value" }, .redacted, err);
        out.print("{s}: {s}\r\n", .{ header.name, value.buffered() }) catch |err| return fail(context, .maximum, path, .{ .unsigned = buffer.len }, .unrecorded, err);
    }
    out.writeAll("\r\n") catch |err| return fail(context, .maximum, "request.head.bytes", .{ .unsigned = buffer.len }, .unrecorded, err);
    return out.buffered();
}

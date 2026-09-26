//! Pure request construction. Secret resolution is supplied by the executor;
//! capture renders references instead, and never invokes that resolver.
const std = @import("std");
const http = @import("root.zig");
const Self = @This();
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
fn parts(out: *std.Io.Writer, pieces: []const Piece, target: bool, resolver: ?Resolver, template: bool) !void {
    if (pieces.len > maximum_pieces) return error.HttpRequestTooLarge;
    for (pieces) |piece| switch (piece) {
        .literal => |bytes| {
            if (target) for (bytes) |b| {
                if (b <= 32 or b >= 127 or b == '#' or b == '\\') return error.InvalidHttpTarget;
            };
            try out.writeAll(bytes);
        },
        .variable => |v| {
            try identifier(v.name);
            if (template) try out.print("{{{{vars.{s}}}}}", .{v.name}) else if (target) {
                for (v.value) |b| {
                    if (std.ascii.isAlphanumeric(b) or std.mem.indexOfScalar(u8, "-._~", b) != null) try out.writeByte(b) else try out.print("%{X:0>2}", .{b});
                }
            } else try out.writeAll(v.value);
        },
        .secret => |s| {
            try identifier(s.binding);
            if (s.version == 0 or target) return error.InvalidHttpSecret;
            if (resolver) |r| {
                const value = try r.resolve(r.context, s);
                try http.validateHeader("value", value);
                try out.writeAll(value);
            } else try out.print("{{{{secrets.{s}@{d}}}}}", .{ s.binding, s.version });
        },
    };
}
/// Produces exact request-head bytes, except that capture deliberately records
/// credential references. Template mode preserves ordinary variable names too.
pub fn render(self: Self, host: []const u8, port: u16, buffer: []u8, resolver: ?Resolver, template: bool) ![]const u8 {
    if (buffer.len > maximum_head_bytes or self.headers.len > maximum_headers or port == 0) return error.HttpRequestTooLarge;
    switch (self.method) {
        .GET, .HEAD, .POST, .PUT, .PATCH, .DELETE, .OPTIONS => {},
        else => return error.UnsupportedHttpMethod,
    }
    if (host.len == 0 or host.len > 253) return error.InvalidHttpAuthority;
    for (host) |b| if (!std.ascii.isAlphanumeric(b) and b != '-' and b != '.') return error.InvalidHttpAuthority;
    if (self.target.len == 0 or self.target[0] != .literal or self.target[0].literal.len == 0 or self.target[0].literal[0] != '/') return error.InvalidHttpTarget;
    if (std.mem.startsWith(u8, self.target[0].literal, "//")) return error.InvalidHttpTarget;
    var out: std.Io.Writer = .fixed(buffer);
    try out.print("{s} ", .{@tagName(self.method)});
    try parts(&out, self.target, true, null, template);
    try out.print(" HTTP/1.1\r\nHost: {s}:{d}\r\nConnection: close\r\nAccept-Encoding: identity\r\nContent-Length: {d}\r\n", .{ host, port, self.body_bytes });
    var value_buffer: [maximum_head_bytes]u8 = undefined;
    for (self.headers) |header| {
        if (reserved(header.name)) return error.ReservedHttpHeader;
        var value: std.Io.Writer = .fixed(&value_buffer);
        try parts(&value, header.value, false, resolver, template);
        try http.validateHeader(header.name, value.buffered());
        try out.print("{s}: {s}\r\n", .{ header.name, value.buffered() });
    }
    try out.writeAll("\r\n");
    return out.buffered();
}

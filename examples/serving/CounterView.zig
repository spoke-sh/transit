//! Application static assets, outside Board's inspection/value boundary.
const std = @import("std");
const hosting = @import("transit_serving_http");
const http = @import("transit_http_server");
const assets = @import("assets");
const Self = @This();
host: *hosting.Context,
pub fn isControl(self: *Self, request: *std.http.Server.Request) bool {
    return self.host.isControl(request);
}
pub fn connectionError(self: *Self, err: anyerror, started: bool) void {
    self.host.connectionError(err, started);
}
pub fn handle(self: *Self, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    if (request.head.method != .GET or std.mem.eql(u8, request.head.target, "/health") or std.mem.startsWith(u8, request.head.target, "/reactive/"))
        return self.host.handle(io, allocator, request);
    self.host.validateRequest(request) catch return http.respond(request, .forbidden, "{}");
    const asset = if (std.mem.eql(u8, request.head.target, "/")) assets.Asset{ .bytes = assets.index, .mime = "text/html; charset=utf-8" } else assets.get(request.head.target) orelse return http.respond(request, .not_found, "{}");
    try request.respond(asset.bytes, .{ .keep_alive = false, .extra_headers = &.{
        .{ .name = "content-type", .value = asset.mime },
        .{ .name = "cache-control", .value = "no-store" },
        .{ .name = "x-content-type-options", .value = "nosniff" },
        .{ .name = "content-security-policy", .value = "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'" },
        .{ .name = "referrer-policy", .value = "no-referrer" },
    } });
}

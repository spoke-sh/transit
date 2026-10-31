//! Entry-point composition only; browser semantics belong to transit-browser.
const std = @import("std");
const browser = @import("transit_browser");
const http = @import("transit_http_server");
pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const args = try init.minimal.args.toSlice(a);
    if (args.len != 2) return error.ExpectedBrowserConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], a, .limited(1024 * 1024));
    const config = try std.json.parseFromSliceLeaky(browser.Gateway.Config, a, bytes, .{});
    const encoded = try std.Io.Dir.cwd().readFileAlloc(init.io, config.secret_file, a, .limited(128));
    defer std.crypto.secureZero(u8, encoded);
    const text = std.mem.trim(u8, encoded, "\r\n");
    if (!browser.Security.validToken(text)) return error.InvalidBrowserSecret;
    var secret: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&secret, text);
    defer std.crypto.secureZero(u8, &secret);
    var gateway = try browser.Gateway.init(config, secret);
    defer std.crypto.secureZero(u8, &gateway.secret);
    for (config.providers) |provider| _ = try browser.Provider.endpoints(a, provider, config.development);
    var listener = try (try std.Io.net.IpAddress.parseIp4(config.address, config.port)).listen(init.io, .{ .reuse_address = true });
    defer listener.deinit(init.io);
    try http.serve(init.io, init.gpa, &listener, .{ .connections = 12, .requests = 4, .control_requests = 2, .wait_requests = 2, .header_timeout_ms = 1000, .request_timeout_ms = 60000 }, &gateway);
}

/// Read and validate the public listener before the supervisor reports ready.
/// Secrets are read only by the browser role; this address carries no credentials.
pub fn healthAddress(a: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(1024 * 1024));
    const config = try std.json.parseFromSliceLeaky(browser.Gateway.Config, a, bytes, .{});
    _ = try browser.Gateway.init(config, @splat(0));
    for (config.providers) |provider| _ = try browser.Provider.endpoints(a, provider, config.development);
    return std.fmt.allocPrint(a, "http://{s}:{d}/health", .{ if (std.mem.eql(u8, config.address, "0.0.0.0")) "127.0.0.1" else config.address, config.port });
}

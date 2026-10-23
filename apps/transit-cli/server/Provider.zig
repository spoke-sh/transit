//! Loopback service addressing and bounded readiness observations.
const std = @import("std");
const http = @import("transit_http_server");
pub fn url(allocator: std.mem.Allocator, port: u16) ![]const u8 {
    return std.fmt.allocPrint(allocator, "http://127.0.0.1:{d}", .{port});
}
const Fetch = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    address: []const u8,
    method: std.http.Method = .GET,
    headers: []const std.http.Header = &.{},
    status: std.http.Status = .service_unavailable,
    fn run(self: *Fetch) anyerror!void {
        var client: std.http.Client = .{ .io = self.io, .allocator = self.allocator };
        defer client.deinit();
        var output: [8192]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&output);
        self.status = (try client.fetch(.{ .location = .{ .url = self.address }, .method = self.method, .payload = if (self.method == .PUT) "" else null, .extra_headers = self.headers, .keep_alive = false, .redirect_behavior = .not_allowed, .response_writer = &writer })).status;
    }
};
pub fn health(init: std.process.Init, address: []const u8) bool {
    var fetch: Fetch = .{ .io = init.io, .allocator = init.gpa, .address = address };
    http.deadline(init.io, 1000, Fetch.run, .{&fetch}) catch return false;
    return fetch.status == .ok;
}

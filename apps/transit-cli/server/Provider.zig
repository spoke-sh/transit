//! Selected local provider bootstrap only. No provider authority enters Transit.
const std = @import("std");
const http = @import("transit_http_server");
const Config = @import("Config.zig");
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
pub fn bucket(init: std.process.Init, port: u16, secret: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const seconds: std.time.epoch.EpochSeconds = .{ .secs = @intCast(@divFloor(std.Io.Clock.real.now(init.io).toMilliseconds(), 1000)) };
    const day = seconds.getEpochDay().calculateYearDay();
    const month = day.calculateMonthDay();
    const time = seconds.getDaySeconds();
    const date = try std.fmt.allocPrint(allocator, "{d:0>4}{d:0>2}{d:0>2}", .{ day.year, month.month.numeric(), month.day_index + 1 });
    const timestamp = try std.fmt.allocPrint(allocator, "{s}T{d:0>2}{d:0>2}{d:0>2}Z", .{ date, time.getHoursIntoDay(), time.getMinutesIntoHour(), time.getSecondsIntoMinute() });
    const host = try std.fmt.allocPrint(allocator, "127.0.0.1:{d}", .{port});
    const payload = hexHash("");
    const names = "host;x-amz-content-sha256;x-amz-date";
    const canonical = try std.fmt.allocPrint(allocator, "PUT\n/transit\n\nhost:{s}\nx-amz-content-sha256:{s}\nx-amz-date:{s}\n\n{s}\n{s}", .{ host, payload, timestamp, names, payload });
    const scope = try std.fmt.allocPrint(allocator, "{s}/us-east-1/s3/aws4_request", .{date});
    const to_sign = try std.fmt.allocPrint(allocator, "AWS4-HMAC-SHA256\n{s}\n{s}\n{s}", .{ timestamp, scope, hexHash(canonical) });
    var key: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &key);
    std.crypto.auth.hmac.sha2.HmacSha256.create(&key, date, try std.fmt.allocPrint(allocator, "AWS4{s}", .{secret}));
    for ([_][]const u8{ "us-east-1", "s3", "aws4_request" }) |value| std.crypto.auth.hmac.sha2.HmacSha256.create(&key, value, &key);
    var signature: [32]u8 = undefined;
    std.crypto.auth.hmac.sha2.HmacSha256.create(&signature, to_sign, &key);
    const authorization = try std.fmt.allocPrint(allocator, "AWS4-HMAC-SHA256 Credential=transit/{s}, SignedHeaders={s}, Signature={s}", .{ scope, names, std.fmt.bytesToHex(signature, .lower) });
    var fetch: Fetch = .{ .io = init.io, .allocator = allocator, .address = try std.fmt.allocPrint(allocator, "http://{s}/transit", .{host}), .method = .PUT, .headers = &.{ .{ .name = "authorization", .value = authorization }, .{ .name = "x-amz-date", .value = timestamp }, .{ .name = "x-amz-content-sha256", .value = &payload } } };
    try http.deadline(init.io, 5000, Fetch.run, .{&fetch});
    if (fetch.status != .ok) return error.ColdBucketCreationFailed;
}
fn hexHash(bytes: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
pub fn configuration(allocator: std.mem.Allocator, config: Config, secret: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator,
        \\[server]
        \\listen = "127.0.0.1:{d}"
        \\admin_listen = "127.0.0.1:0"
        \\[runtime]
        \\core_count = 2
        \\node_memory_abort_cap_size = "512MiB"
        \\live_read_max_waiters_per_core = 64
        \\[raft]
        \\node_id = 1
        \\group_count = 1
        \\max_uncommitted_size_per_group = "8MiB"
        \\[raft.wal]
        \\backend = "disk"
        \\path = "{s}/wal"
        \\min_available_size = "64MiB"
        \\resume_available_size = "128MiB"
        \\[storage.cold]
        \\backend = "s3"
        \\root = "pages"
        \\flush_interval = "100ms"
        \\flush_size = "256KiB"
        \\flush_pressure_hot_size = "256KiB"
        \\max_hot_size_per_group = "8MiB"
        \\[storage.cold.cache]
        \\max_size = "8MiB"
        \\block_size = "256KiB"
        \\readahead_blocks = 0
        \\[storage.cold.s3]
        \\bucket = "transit"
        \\region = "us-east-1"
        \\endpoint = "http://127.0.0.1:{d}"
        \\access_key_id = "transit"
        \\secret_access_key = "{s}"
        \\server_side_encryption = "none"
        \\[storage.snapshot]
        \\backend = "s3"
        \\drive_interval = "1s"
        \\[governance.cold_health]
        \\hot_size_high = "6MiB"
        \\hot_size_low = "4MiB"
        \\
    , .{ config.ports.store, config.installation, config.ports.cold, secret });
}

//! Adversarial sandbox executable, never a Transit handler or production image.
const std = @import("std");
const Check = struct {
    label: []const u8,
    url: []const u8,
    method: std.http.Method = .GET,
    host: ?[]const u8 = null,
};
const Config = struct { authority: []const u8, checks: []const Check };
const Response = struct { status: std.http.Status, authority_not_found: bool };

fn request(client: *std.http.Client, check: Check) anyerror!Response {
    var buffer: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    const response = try client.fetch(.{
        .location = .{ .url = check.url },
        .method = check.method,
        .payload = if (check.method == .POST) "{}" else null,
        .headers = .{
            .host = if (check.host) |host| .{ .override = host } else .default,
            .content_type = .{ .override = "application/json" },
        },
        .redirect_behavior = .not_allowed,
        .keep_alive = false,
        .response_writer = &writer,
    });
    return .{ .status = response.status, .authority_not_found = std.mem.eql(u8, writer.buffered(), "{\"err\":\"NotFound\"}") };
}
fn timeout(io: std.Io) anyerror!void {
    try io.sleep(.fromSeconds(5), .awake);
}
fn bounded(client: *std.http.Client, check: Check) !Response {
    const Result = union(enum) { response: anyerror!Response, timeout: anyerror!void };
    var values: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(client.io, &values);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{client.io});
    try select.concurrent(.response, request, .{ client, check });
    return switch (try select.await()) {
        .response => |r| r,
        .timeout => error.ProbeTimeout,
    };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedPublicProbeConfig;
    var parsed = try std.json.parseFromSlice(Config, init.gpa, args[1], .{});
    defer parsed.deinit();
    const config = parsed.value;
    var client: std.http.Client = .{ .allocator = init.gpa, .io = init.io };
    defer client.deinit();
    // Template golden Actors have no egress policy. Wait for the actual test
    // Actor's allow-list and use a positive control before counting denials.
    while (true) {
        const response = bounded(&client, .{ .label = "authority", .url = config.authority }) catch {
            try init.io.sleep(.fromSeconds(1), .awake);
            continue;
        };
        if (response.status == .ok) break;
        try init.io.sleep(.fromSeconds(1), .awake);
    }
    for ([_][]const u8{
        "/var/run/secrets/kubernetes.io/serviceaccount/token",
        "/root/.kube/config",
        "/secrets/seed",
        "/config/node.json",
    }) |path| {
        if (std.Io.Dir.cwd().openFile(init.io, path, .{})) |file| {
            file.close(init.io);
            return error.CredentialOrControlMountExposed;
        } else |err| switch (err) {
            error.FileNotFound, error.AccessDenied => {},
            else => return err,
        }
    }
    var buffer: [2048]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (config.checks) |check| {
        const response = try bounded(&client, check);
        // Host-spoofed traffic may be routed to the permitted authority, whose
        // fixed NotFound response also proves the raw target was not reached.
        const denied = response.status == .forbidden or
            (check.host != null and response.status == .not_found and response.authority_not_found);
        try output.interface.print("probe {s}: status={d} denied={}\n", .{ check.label, @backingInt(response.status), denied });
        try output.interface.flush();
        if (!denied) return error.EgressBypass;
    }
    try output.interface.writeAll("ISOLATION_PROOF_PASSED\n");
    try output.interface.flush();
    // Keep the Actor inspectable until the harness explicitly suspends it.
    while (true) try init.io.sleep(.fromSeconds(60), .awake);
}

//! Trusted synthetic executor, not an HTTP connector or a handler. One fresh
//! dispatch authorizes at most one local send. Recovery never resends an attempt.
const std = @import("std");
const transit = wire.protocol;
const wire = @import("transit_client");
const Config = struct {
    authority: []const u8,
    endpoint: []const u8,
    seed_file: []const u8,
    realm: u64,
    principal: u8,
    pid: u64,
    effect: u64,
};
fn fetch(client: *std.http.Client, endpoint: []const u8, payload: []const u8) anyerror!i64 {
    var buffer: [128]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    const response = try client.fetch(.{
        .location = .{ .url = endpoint },
        .method = .POST,
        .payload = payload,
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .redirect_behavior = .not_allowed,
        .keep_alive = false,
        .response_writer = &writer,
    });
    if (response.status != .ok) return error.UnknownRemoteOutcome;
    return std.fmt.parseInt(i64, writer.buffered(), 10);
}
fn timeout(io: std.Io) anyerror!void {
    try io.sleep(.fromSeconds(5), .awake);
}
fn boundedFetch(client: *std.http.Client, endpoint: []const u8, payload: []const u8) !i64 {
    const Result = union(enum) { response: anyerror!i64, timeout: anyerror!void };
    var values: [2]Result = undefined;
    var select: std.Io.Select(Result) = .init(client.io, &values);
    defer select.cancelDiscard();
    try select.concurrent(.timeout, timeout, .{client.io});
    try select.concurrent(.response, fetch, .{ client, endpoint, payload });
    return switch (try select.await()) {
        .response => |value| value,
        .timeout => error.UnknownRemoteOutcome,
    };
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfig;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(bytes);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, bytes, .{});
    defer parsed.deinit();
    const c = parsed.value;
    // This fixture's only destination is a harness-owned loopback service.
    if (!std.mem.startsWith(u8, c.endpoint, "http://127.0.0.1:")) return error.InvalidSyntheticEndpoint;
    const key = try wire.readKey(init.gpa, init.io, c.seed_file);
    var client = wire.Client.init(init.gpa, init.io, c.authority);
    defer client.deinit();
    const view = try client.view(.{ .realm = c.realm, .principal = c.principal, .sequence = 0, .command = .{ .inspect = c.pid } }, key);
    const effect = for (view.effects) |slot| {
        if (slot) |effect| if (effect.id == c.effect) break effect;
    } else return error.UnknownEffect;
    if (effect.phase != .pending) return error.AttemptAlreadyAuthorized;
    const attempt = (try client.submit(try transit.sign(.{
        .realm = c.realm,
        .principal = c.principal,
        .sequence = view.principal_sequence + 1,
        .command = .{ .dispatch = .{ .pid = c.pid, .effect = c.effect, .max_observations = 1 } },
    }, key))).position;
    var buffer: [256]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print("authorized {d}\n", .{attempt});
    try stdout.interface.flush();
    // Harness pause point AFTER durable authorization, BEFORE network I/O.
    var input_buffer: [1]u8 = undefined;
    var stdin = std.Io.File.stdin().readerStreaming(init.io, &input_buffer);
    if (try stdin.interface.takeByte() != '\n') return error.InvalidRelease;
    var http: std.http.Client = .{ .allocator = init.gpa, .io = init.io };
    defer http.deinit();
    const payload = try std.json.Stringify.valueAlloc(init.gpa, .{ .effect = c.effect, .attempt = attempt, .value = effect.payload }, .{});
    defer init.gpa.free(payload);
    const result = boundedFetch(&http, c.endpoint, payload) catch null;
    // No retry of the external operation, including an unknown response. A
    // rejection here cannot undo a request the external system already accepted.
    _ = try client.submit(try transit.sign(.{
        .realm = c.realm,
        .principal = c.principal,
        .sequence = view.principal_sequence + 2,
        .command = .{ .observe = .{ .pid = c.pid, .effect = c.effect, .attempt = attempt, .result = result } },
    }, key));
}

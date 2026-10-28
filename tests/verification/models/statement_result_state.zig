//! Private semantic trace adapter. Calls the real Progress owner; it does not
//! implement fetch deduplication, authorization, service I/O or SQL evaluation.
const std = @import("std");
const r = @import("transit_sql_client").results;
const Input = struct {
    kind: enum { receive, deliver, finish, fail, cancel, release },
    rows: u64,
    identity: u8,
};
const identity: r.Identity = .{ .result = @splat(1), .schema = @splat(2), .observation = @splat(3) };
fn act(state: *r.Progress, event: Input) !void {
    var incoming = identity;
    switch (event.identity) {
        0 => {},
        1 => incoming.result[0] ^= 1,
        2 => incoming.schema[0] ^= 1,
        3 => incoming.observation[0] ^= 1,
        else => return error.UnmappedIdentity,
    }
    switch (event.kind) {
        .receive => try state.receive(incoming, event.rows),
        .deliver => try state.deliver(event.rows),
        .finish => try state.finish(incoming, .{ .rows = event.rows }),
        .fail => state.fail(false),
        .cancel => state.fail(true),
        .release => state.release(),
    }
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedTracePath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(32 * 1024 * 1024));
    defer init.gpa.free(bytes);
    const traces = try std.json.parseFromSlice([]const []const Input, init.gpa, bytes, .{});
    defer traces.deinit();
    if (traces.value.len > 8192) return error.TooManyTraces;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (traces.value) |events| {
        if (events.len > 128) return error.TraceTooLong;
        var state: r.Progress = .{ .identity = identity };
        var last_error: []const u8 = "none";
        for (events) |event| {
            last_error = "none";
            act(&state, event) catch |err| switch (err) {
                error.ResultIdentityChanged, error.InvalidResultTransition, error.InvalidResultCount => last_error = @errorName(err),
                else => return err,
            };
            if (!std.meta.eql(state.identity, identity)) return error.ResultAttributionMutated;
        }
        const completion = state.completion();
        try std.json.Stringify.value(.{ .state = .{
            .received = state.received,
            .delivered = state.delivered,
            .outcome = @tagName(state.outcome),
            .consumption = state.consumption,
            .released = state.released,
            .terminal = if (completion) |value| @as(i128, value.rows) else -1,
            .evidence = completion != null,
        }, .@"error" = last_error }, .{}, &output.interface);
        try output.interface.writeByte('\n');
    }
    try output.interface.flush();
}

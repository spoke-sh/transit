//! Ctrl-C uses the same recorded native cancellation as the explicit command.
const std = @import("std");
const Console = @import("Console.zig").Console;
const u = @import("Unified.zig");
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");

pub fn interrupt(console: *Console) !void {
    Signals.beginCancellation();
    defer Signals.endCancellation();
    // A cancelled output task is joined before arriving here. Discard its
    // buffered remainder so a later query cannot flush interrupted result bytes.
    console.out.end = 0;
    // Interactive.sql has already stopped local evaluation and attempted to
    // close its leased snapshot. A failed close is bounded by lease expiry.
    if (console.interactive) return report(console, "Query cancelled.\n", .{});
    const session = console.session;
    const id = console.active_query orelse return report(console, "Query cancelled before submission.\n", .{});
    if (session.complete) return report(console, "Query {d} already completed.\n", .{id});
    report(console, "Cancelling query {d}...\n", .{id}) catch {};
    // Reconcile only the original frozen operation, never finish its upload or
    // replace an uncertain principal sequence with a newly prepared operation.
    try u.settle(console.init, session, console.client);
    var status = try console.client.status(id);
    if (status) |current| switch (current.phase) {
        .uploading, .sealed, .admitted => {
            if (console.recovery == null) return error.ConsoleRecoveryRequired;
            session.pending = try console.client.prepare(.{ .cancel = id });
            session.length = 0;
            try u.settle(console.init, session, console.client);
            status = (try console.client.status(id)) orelse return error.QueryUploadNotFound;
        },
        else => {},
    };
    if (status) |current| switch (current.phase) {
        .cancelled => {
            // The requester releases its active upload slot through bounded
            // collection. Wait for it so the next SELECT can actually start.
            const deadline = std.Io.Clock.boot.now(console.init.io).toMilliseconds() + 30000;
            while (!status.?.collected) {
                if (Signals.interrupted()) return error.ConsoleInterrupted;
                if (std.Io.Clock.boot.now(console.init.io).toMilliseconds() >= deadline) return error.QueryWaitTimedOut;
                try console.init.io.sleep(.fromMilliseconds(20), .awake);
                status = (try console.client.status(id)) orelse return error.QueryUploadNotFound;
                if (status.?.phase != .cancelled) return error.InvalidAuthorityResponse;
            }
        },
        .complete, .denied, .rejected, .retired => {},
        else => return error.UnresolvedSubmission,
    };
    // Only observed closure (or no admitted upload) releases local recovery.
    // A failed/uncertain cancellation retains the exact intent for .cancel.
    session.clear();
    try session.checkpoint();
    if (status) |current| switch (current.phase) {
        .cancelled => try report(console, "Query {d} cancelled.\n", .{id}),
        .complete => try report(console, "Query {d} already completed; result display interrupted.\n", .{id}),
        else => try report(console, "Query {d} is {s}; result display interrupted.\n", .{ id, @tagName(current.phase) }),
    } else try report(console, "Query {d} cancelled before submission.\n", .{id});
}

fn report(console: *Console, comptime format: []const u8, args: anytype) !void {
    var message: [256]u8 = undefined;
    const text = try std.fmt.bufPrint(&message, format, args);
    var buffer: [256]u8 = undefined;
    var stderr = std.Io.File.stderr().writerStreaming(console.init.io, &buffer);
    try Output.write(console.init, &stderr.interface, text);
}

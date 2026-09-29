//! Automatic finite SQL execution over the same native session and recovery.
const std = @import("std");
const q = @import("transit_query");
const u = @import("Unified.zig");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");

pub fn sql(console: *Console, statement: []const u8) !void {
    const session = console.session;
    if (console.recovery == null) return error.ConsoleRecoveryRequired;
    if (session.pending != null or session.input != null) return error.UnresolvedSubmission;
    if (session.namespace) |existing| if (!session.complete) {
        if (try console.client.status(existing)) |status| switch (status.phase) {
            .cancelled, .denied, .rejected, .retired => {},
            else => return error.UnresolvedSubmission,
        } else if (session.length != 0) return error.UnresolvedSubmission;
    };
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    // Compile before changing identity; invalid SQL cannot start durable work.
    _ = try q.Workspace.apply(arena.allocator(), console.client, console.config, .{ .compile = .{ .sql = statement } });
    var id: u64 = 0;
    for (0..8) |_| {
        var random: [8]u8 = undefined;
        try console.init.io.randomSecure(&random);
        id = std.mem.readInt(u64, &random, .little) & q.protocol.max_counter;
        if (id != 0 and try console.client.status(id) == null) break;
        id = 0;
    }
    if (id == 0) return error.QueryIdentityUnavailable;
    session.clear();
    session.namespace = id;
    try session.checkpoint();
    const deadline = now(console) + 300000;
    var discard_buffer: [4096]u8 = undefined;
    var discard: std.Io.Writer.Discarding = .init(&discard_buffer);
    try u.command(console.init, session, console.client, console.config, statement, arena.allocator(), &discard.writer);
    try finish(console, deadline);
}
pub fn recover(console: *Console, selected: ?u64) !void {
    const session = console.session;
    if (selected) |id| {
        if (id == 0 or id > q.protocol.max_counter) return error.InvalidQueryIdentity;
        if (session.namespace != id) {
            if (session.pending != null or session.input != null or (session.namespace != null and !session.complete)) return error.UnresolvedSubmission;
            _ = (try console.client.status(id)) orelse return error.QueryUploadNotFound;
            session.clear();
            session.namespace = id;
        }
    }
    if (session.namespace == null) return error.NoQuery;
    // An explicit resume starts presentation at the beginning. No result rows
    // are saved locally, so a disconnected output stream cannot be reconstructed.
    session.cursor = null;
    session.complete = false;
    try session.checkpoint();
    try reconcile(console);
    try finish(console, now(console) + 300000);
}
pub fn reconcile(console: *Console) !void {
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    var scratch: [4096]u8 = undefined;
    var discard: std.Io.Writer.Discarding = .init(&scratch);
    if (console.session.pending != null or console.session.input != null or console.session.length != 0) {
        try u.command(console.init, console.session, console.client, console.config, if (console.session.pending != null) ".retry" else ".advance", arena.allocator(), &discard.writer);
    }
}
pub fn finish(console: *Console, deadline: i64) !void {
    const session = console.session;
    const id = session.namespace orelse return error.NamespaceRequired;
    while (true) {
        try check(console, deadline);
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        if (session.pending != null) return error.UnresolvedSubmission;
        if (session.input != null) {
            var scratch: [4096]u8 = undefined;
            var discard: std.Io.Writer.Discarding = .init(&scratch);
            try u.command(console.init, session, console.client, console.config, ".advance", arena.allocator(), &discard.writer);
        }
        const status = (try console.client.status(id)) orelse return error.QueryUploadNotFound;
        switch (status.phase) {
            .complete => break,
            .uploading, .sealed, .admitted => {},
            .denied => return error.QueryDenied,
            .cancelled => return error.QueryCancelled,
            .retired => return error.QueryRetired,
            .rejected => return error.QueryRejected,
        }
        try console.init.io.sleep(.fromMilliseconds(50), .awake);
    }
    const bytes = try console.init.gpa.alloc(u8, 1048576);
    defer {
        std.crypto.secureZero(u8, bytes);
        console.init.gpa.free(bytes);
    }
    var rows: u64 = 0;
    while (!session.complete) {
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        const allocator = arena.allocator();
        const cursor = if (session.cursor) |value| try std.json.Stringify.valueAlloc(allocator, value, .{}) else null;
        const page = (try q.Workspace.apply(allocator, console.client, console.config, .{ .page = .{ .namespace = try q.document.JsonValues.decimal(allocator, id), .cursor = cursor } })).page;
        var buffered: std.Io.Writer = .fixed(bytes);
        try @import("Results.zig").write(allocator, &buffered, page, session.format == .json);
        rows += page.cells.len;
        if (page.evidence.next == null and session.format == .table) try buffered.print("{d} {s}\n", .{ rows, if (rows == 1) "row" else "rows" });
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try Output.write(console.init, console.out, buffered.buffered());
        session.cursor = if (page.evidence.next) |next| (try std.json.parseFromSlice(q.UnifiedResult.Cursor, allocator, next, .{})).value else null;
        session.complete = page.evidence.next == null;
        try session.checkpoint();
    }
}
fn now(console: *Console) i64 {
    return std.Io.Clock.boot.now(console.init.io).toMilliseconds();
}
fn check(console: *Console, deadline: i64) !void {
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    if (now(console) >= deadline) return error.QueryWaitTimedOut;
}

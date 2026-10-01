//! Automatic finite SQL execution over the same native session and recovery.
const std = @import("std");
const q = @import("transit_query");
const u = @import("Unified.zig");
const Console = @import("Console.zig").Console;
const Signals = @import("Signals.zig");
const Output = @import("Output.zig");
const Timing = @import("Timing.zig");

pub fn sql(console: *Console, statement: []const u8) !void {
    var timing = Timing.start(console.init, console.preferences.timing);
    defer timing.report();
    const session = console.session;
    if (console.recovery == null) return error.ConsoleRecoveryRequired;
    if (session.pending != null or session.input != null) return error.UnresolvedSubmission;
    if (session.namespace) |existing| if (!session.complete) {
        if (try console.client.status(existing)) |status| switch (status.phase) {
            .cancelled, .denied, .rejected, .retired => {},
            else => return error.UnresolvedSubmission,
        } else if (session.length != 0) return error.UnresolvedSubmission;
    };
    console.query_running = true;
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
    defer arena.deinit();
    // Compile before changing identity; invalid SQL cannot start durable work.
    timing.enter(.compile);
    _ = q.Workspace.apply(arena.allocator(), console.client, console.config, .{ .compile = .{ .sql = statement } }) catch |err| return console.sqlFailure(statement, err);
    if (Signals.interrupted()) return error.ConsoleInterrupted;
    timing.enter(.prepare);
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
    console.active_query = id;
    timing.enter(.persist);
    try session.checkpoint();
    timing.enter(.submit);
    const deadline = now(console) + 300000;
    var discard_buffer: [4096]u8 = undefined;
    var discard: std.Io.Writer.Discarding = .init(&discard_buffer);
    try u.command(console.init, session, console.client, console.config, statement, arena.allocator(), &discard.writer);
    try finish(console, deadline, &timing);
}
pub fn recover(console: *Console, selected: ?u64) !void {
    var timing = Timing.start(console.init, console.preferences.timing);
    defer timing.report();
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
    console.query_running = true;
    console.active_query = session.namespace;
    // An explicit resume starts presentation at the beginning. No result rows
    // are saved locally, so a disconnected output stream cannot be reconstructed.
    session.cursor = null;
    session.complete = false;
    try session.checkpoint();
    timing.enter(.submit);
    try reconcile(console);
    try finish(console, now(console) + 300000, &timing);
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
pub fn finish(console: *Console, deadline: i64, timing: *Timing) !void {
    timing.enter(.wait);
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
    const m = q.fuze.Unified;
    const workspace = try console.init.gpa.alloc(u8, m.Arrow.working_bytes);
    defer console.init.gpa.free(workspace);
    const arrow = try console.init.gpa.alloc(u8, m.Arrow.segment_bytes);
    defer console.init.gpa.free(arrow);
    while (!session.complete) {
        timing.enter(.fetch);
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        var arena: std.heap.ArenaAllocator = .init(console.init.gpa);
        defer arena.deinit();
        const allocator = arena.allocator();
        // Decode once through the verified native page reader. Its access and
        // ordered coverage checks precede disclosure; the batch stays at its
        // final address while conflict cells borrow its fixed alternatives.
        const batch = try allocator.create(m.Inspect.Batch);
        const page = try console.client.page(id, session.cursor, allocator, workspace, arrow, batch);
        const definition = try console.config.source.native(allocator);
        if (!std.mem.eql(u8, &page.manifest.checkpoint.progress.basis.contract, &try definition.fingerprint())) return error.QueryIdentityMismatch;
        timing.enter(.render);
        var buffered: std.Io.Writer = .fixed(bytes);
        try @import("Results.zig").write(allocator, &buffered, page, batch, if (session.cursor) |cursor| cursor.ordinal else 0, session.format == .json);
        rows += batch.count;
        if (page.next == null and session.format == .table) try buffered.print("{d} {s}\n", .{ rows, if (rows == 1) "row" else "rows" });
        if (Signals.interrupted()) return error.ConsoleInterrupted;
        try Output.write(console.init, console.out, buffered.buffered());
        timing.enter(.persist);
        session.cursor = page.next;
        session.complete = page.next == null;
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

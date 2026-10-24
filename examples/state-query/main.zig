//! Non-trading finite SQL caller. The recovery file preserves intent and exact
//! signed bytes across OS restarts; public Transit history remains authority.
const std = @import("std");
const q = @import("transit_query");
const Config = struct {
    url: []const u8,
    seed_file: []const u8,
    connection: q.UnifiedClient.Connection,
    workspace: q.Workspace.Config,
    namespace: u64,
    sql: []const u8,
    recovery_file: []const u8,
    mode: enum { upload, read } = .upload,
};
const Recovery = struct { identity: [32]u8, bundle: []const u8, pending: ?q.UnifiedClient.Prepared = null };
fn save(init: std.process.Init, path: []const u8, value: Recovery) !void {
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, path, .{ .replace = true, .permissions = .fromMode(0o600) });
    defer atomic.deinit(init.io);
    var buffer: [4096]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &writer.interface);
    try writer.interface.flush();
    try atomic.file.sync(init.io);
    try atomic.replace(init.io);
}
fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &writer.interface);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.arena.allocator(), .limited(32768));
    const config = (try std.json.parseFromSlice(Config, init.arena.allocator(), bytes, .{})).value;
    if (config.namespace == 0 or config.sql.len > q.fuze.Sql.max_statement_bytes) return error.InvalidConfiguration;
    var wire = q.wire.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = 10000;
    var client: q.UnifiedClient = .{ .wire = &wire, .connection = config.connection, .key = try q.wire.readKey(init.gpa, init.io, config.seed_file) };
    client.tables = try q.Workspace.directTables(init.arena.allocator(), &client, config.workspace);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&client));
    if (config.mode == .read) {
        var cursor: ?[]const u8 = null;
        defer if (cursor) |value| init.gpa.free(value);
        while (true) {
            var arena = std.heap.ArenaAllocator.init(init.gpa);
            defer arena.deinit();
            const page = (try q.Workspace.apply(arena.allocator(), &client, config.workspace, .{ .page = .{ .namespace = try q.document.JsonValues.decimal(arena.allocator(), config.namespace), .cursor = cursor } })).page;
            // No row survives the page arena. Output completion follows verified
            // coverage, never an empty batch or local EOF.
            try print(init, .{ .ordinal = page.evidence.ordinal, .manifest = page.evidence.manifest, .columns = page.evidence.columns, .cells = page.cells, .complete_coverage = page.evidence.next == null });
            const next_cursor = if (page.evidence.next) |next| try init.gpa.dupe(u8, next) else null;
            if (cursor) |old| init.gpa.free(old);
            cursor = next_cursor;
            if (cursor == null) return;
        }
    }
    const identity_bytes = try std.json.Stringify.valueAlloc(init.arena.allocator(), .{ config.connection, config.workspace, config.namespace, config.sql }, .{});
    var identity: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(identity_bytes, &identity, .{});
    const saved = std.Io.Dir.cwd().readFileAlloc(init.io, config.recovery_file, init.arena.allocator(), .limited(65536)) catch |err| switch (err) {
        error.FileNotFound => null,
        else => return err,
    };
    var recovery: Recovery = if (saved) |data| (try std.json.parseFromSlice(Recovery, init.arena.allocator(), data, .{})).value else fresh: {
        if (try client.status(config.namespace) != null) return error.MissingOriginalIntent;
        var compiled = (try q.Workspace.apply(init.arena.allocator(), &client, config.workspace, .{ .compile = .{ .sql = config.sql } })).compiled;
        if (compiled.source.source == .table) compiled = (try q.Workspace.apply(init.arena.allocator(), &client, config.workspace, .{ .capture = .{ .bundle = compiled.bundle, .operation = try q.document.JsonValues.decimal(init.arena.allocator(), config.namespace) } })).compiled;
        const value: Recovery = .{ .identity = identity, .bundle = compiled.bundle };
        try save(init, config.recovery_file, value);
        break :fresh value;
    };
    if (!std.mem.eql(u8, &identity, &recovery.identity)) return error.RecoveryConfigurationChanged;
    // Validate the frozen source and budgets against current authority without
    // substituting a newly compiled plan. A changed credential cannot use an old
    // pending command; callers must preserve this principal's sequence ownership.
    _ = try q.Workspace.apply(init.arena.allocator(), &client, config.workspace, .{ .next = .{ .namespace = try q.document.JsonValues.decimal(init.arena.allocator(), config.namespace), .bundle = recovery.bundle } });
    for (0..132) |_| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        if (recovery.pending == null) {
            const bundle = try q.Bundle.decode(arena.allocator(), try q.Values.unhex(arena.allocator(), recovery.bundle, q.Bundle.max_bytes));
            recovery.pending = try client.prepareNext(config.namespace, bundle);
            try save(init, config.recovery_file, recovery);
        }
        const pending = recovery.pending orelse return print(init, .{ .status = try client.status(config.namespace) });
        const receipt = try client.submit(pending);
        const deadline = std.Io.Clock.boot.now(init.io).toMilliseconds() + 60000;
        while (true) switch (try client.observe(receipt.position)) {
            .committed => break,
            .rejected => return error.QueryCommandRejected,
            .pending => {
                if (std.Io.Clock.boot.now(init.io).toMilliseconds() >= deadline) return error.QueryCommandPending;
                try init.io.sleep(.fromMilliseconds(20), .awake);
            },
        };
        recovery.pending = null;
        try save(init, config.recovery_file, recovery);
    }
    return error.UploadStepBudgetExceeded;
}

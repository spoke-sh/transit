//! Optional source recovery is composed above the SQL database runtime.
const std = @import("std");
const g = @import("root.zig");
pub fn attach(runtime: *g.DatabaseRuntime, directory: std.Io.Dir, sources: []const g.Configuration.Source) !void {
    try runtime.attachReadCache(directory, .{ .context = @ptrCast(sources.ptr), .len = sources.len, .resolve = resolve });
}
fn resolve(context: *const anyopaque, index: usize, allocator: std.mem.Allocator, io: std.Io, transport: *g.wire.Client) !?g.catalog.DirectTableClient {
    const sources: [*]const g.Configuration.Source = @ptrCast(@alignCast(context));
    const source = sources[index];
    if (source.workspace.source.source != .table) return null;
    const key = try g.wire.readKey(allocator, io, source.key_file);
    var caller: g.query.UnifiedClient = .{ .wire = transport, .connection = source.connection, .key = key };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var client = (try g.query.Workspace.directTables(arena.allocator(), &caller, source.workspace)) orelse return null;
    client.allocator = allocator;
    return client;
}

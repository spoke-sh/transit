//! Authorized settings-name completion; hints never execute or prepare reloads.
const std = @import("std");
const q = @import("root.zig");
const A = q.Assistance;
pub fn complete(allocator: std.mem.Allocator, client: q.SettingsClient, request: A.Request) !?A.Response {
    const span = try q.fuze.SqlInput.active(request.sql, request.cursor, request.mode == .console);
    var result = (try completeStatement(allocator, client, .{ .sql = request.sql[span.start..span.end], .cursor = request.cursor - span.start, .generation = request.generation, .mode = request.mode })) orelse return null;
    if (result.range) |*range| {
        range.start += span.start;
        range.end += span.start;
    }
    return result;
}
fn completeStatement(allocator: std.mem.Allocator, client: q.SettingsClient, request: A.Request) !?A.Response {
    try q.fuze.Sql.validateText(request.sql);
    if (request.cursor > request.sql.len) return error.InvalidSqlCursor;
    const text = request.sql[0..request.cursor];
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidSqlCursor;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    var parser = try q.fuze.SqlTyped.init(arena.allocator(), text, null);
    const show = parser.word("SHOW");
    const set = parser.word("SET");
    const reset = parser.word("RESET");
    if (!show and !set and !reset) return null;
    try parser.advance();
    const start = parser.lexer.start;
    const prefix = text[start..];
    for (prefix) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '_' and byte != '.') return null;
    if (!show and (std.ascii.startsWithIgnoreCase(prefix, "ROLE") or std.ascii.startsWithIgnoreCase(prefix, "LOCAL"))) return null;
    // Enumerate only public rows under the caller's current inspection grant.
    var items: [A.max_items]A.Item = undefined;
    var count: usize = 0;
    var limited = false;
    errdefer for (items[0..count]) |item| allocator.free(item.text);
    if (show) for ([_][]const u8{ "ALL", "DATABASES", "SCHEMAS", "TABLES" }) |word| try add(allocator, &items, &count, &limited, prefix, word, "Authorized settings or catalog listing");
    if (reset) try add(allocator, &items, &count, &limited, prefix, "ALL", "Restore captured session defaults");
    var generation: ?u64 = null;
    var policy: u64 = 0;
    var cursor: ?q.settings.Contract.Cursor = null;
    for (0..128) |_| {
        const response = try client.read(.{ .settings = .{ .cursor = cursor } });
        defer response.deinit();
        const page = response.value.result.settings;
        if (generation) |prior| if (page.generation != prior) return error.ConfigurationSnapshotChanged;
        generation = page.generation;
        if (generation != null and policy != 0 and policy != response.value.policy_revision) return error.ConfigurationSnapshotChanged;
        policy = response.value.policy_revision;
        for (page.rows) |row| {
            if (!show and !row.session_mutable) continue;
            try add(allocator, &items, &count, &limited, prefix, row.name, "Registered setting; authorization is checked at execution");
        }
        cursor = page.next;
        if (cursor == null) break;
    }
    if (cursor != null) limited = true;
    const revision = try std.fmt.allocPrint(allocator, "{d}", .{policy});
    errdefer allocator.free(revision);
    var end: usize = request.cursor;
    while (end < request.sql.len and (std.ascii.isAlphanumeric(request.sql[end]) or request.sql[end] == '_' or request.sql[end] == '.')) : (end += 1) {}
    return .{ .generation = request.generation, .coverage = if (limited) .limited else .complete, .status = .ready, .profile = .configuration_v1, .resource = client.binding.object.id, .contract = q.settings.Contract.Binding.identity(client.binding.installation), .resource_revision = generation.?, .policy_revision = revision, .range = .{ .start = @intCast(start), .end = @intCast(end), .quoted = false }, .items = try allocator.dupe(A.Item, items[0..count]) };
}
fn add(allocator: std.mem.Allocator, items: *[A.max_items]A.Item, count: *usize, limited: *bool, prefix: []const u8, name: []const u8, detail: []const u8) !void {
    if (!std.ascii.startsWithIgnoreCase(name, prefix)) return;
    try A.offer(allocator, items, count, limited, prefix, name, .keyword, detail);
}

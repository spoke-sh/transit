//! Shared application schema and data migration client over the native SQL session.
const std = @import("std");
const root = @import("root.zig");
const api = root.protocol;
const Client = root.Client;
const Response = root.Response;
pub const Migration = api.Migration;

pub const ParsedFilename = struct {
    version_id: []const u8,
    name: []const u8,
};

pub fn parseFilename(basename: []const u8) !ParsedFilename {
    if (!std.mem.endsWith(u8, basename, ".sql")) return error.InvalidMigrationFilename;
    const stem = basename[0 .. basename.len - 4];
    if (stem.len == 0) return error.InvalidMigrationFilename;
    const sep = std.mem.indexOfAny(u8, stem, "-_");
    const version_id = if (sep) |idx| stem[0..idx] else stem;
    const name = if (sep) |idx| stem[idx + 1 ..] else stem;
    if (version_id.len == 0 or version_id.len > Migration.max_version_id_bytes) return error.InvalidMigrationVersion;
    if (name.len == 0 or name.len > Migration.max_name_bytes) return error.InvalidMigrationVersion;
    for (version_id) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != '_') return error.InvalidMigrationVersion;
    }
    return .{ .version_id = version_id, .name = name };
}

pub fn loadSourceFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !Migration.SourceFile {
    if (path.len == 0 or path.len > Migration.max_path_bytes) return error.InvalidMigrationVersion;
    const basename = std.fs.path.basename(path);
    const parsed = try parseFilename(basename);
    // The reader needs one byte beyond the inclusive source limit to prove EOF.
    const sql = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(api.max_sql_bytes + 1));
    errdefer allocator.free(sql);
    if (sql.len == 0) return error.EmptyMigrationSource;
    _ = try api.fuze.SqlInput.SourceScan.init(sql);
    var sha: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(sql, &sha, .{});
    const version_id = try allocator.dupe(u8, parsed.version_id);
    errdefer allocator.free(version_id);
    const name = try allocator.dupe(u8, parsed.name);
    errdefer allocator.free(name);
    return .{
        .version_id = version_id,
        .name = name,
        .path = try allocator.dupe(u8, path),
        .sql = sql,
        .sha256 = sha,
    };
}

pub fn discoverSources(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir_path: ?[]const u8,
    file_paths: []const []const u8,
) ![]Migration.SourceFile {
    var list: std.ArrayList(Migration.SourceFile) = .empty;
    if (dir_path) |dir_name| {
        var directory = try std.Io.Dir.cwd().openDir(io, dir_name, .{ .iterate = true });
        defer directory.close(io);
        var iterator = directory.iterate();
        while (try iterator.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".sql")) continue;
            if (list.items.len >= Migration.max_sources) return error.TooManyMigrationSources;
            const full_path = try std.fs.path.join(allocator, &.{ dir_name, entry.name });
            try list.append(allocator, try loadSourceFile(allocator, io, full_path));
        }
    }
    for (file_paths) |file_path| {
        if (list.items.len >= Migration.max_sources) return error.TooManyMigrationSources;
        try list.append(allocator, try loadSourceFile(allocator, io, file_path));
    }
    std.mem.sort(Migration.SourceFile, list.items, {}, struct {
        fn lessThan(_: void, a: Migration.SourceFile, b: Migration.SourceFile) bool {
            return std.mem.order(u8, a.version_id, b.version_id) == .lt;
        }
    }.lessThan);
    for (list.items, 0..) |item, index| {
        for (list.items[0..index]) |earlier| {
            if (std.mem.eql(u8, earlier.version_id, item.version_id)) return error.DuplicateMigrationVersion;
        }
    }
    return list.toOwnedSlice(allocator);
}

pub fn toSavedPlan(
    report: Migration.Report,
    sources: []const Migration.SourceFile,
    allow_grants: bool,
) Migration.SavedPlan {
    return .{
        .definition = report.definition,
        .target = report.target,
        .plan_digest = report.plan_digest,
        .allow_grants = allow_grants,
        .sources = sources,
        .versions = report.versions,
    };
}

pub fn encodeSavedPlan(allocator: std.mem.Allocator, saved: Migration.SavedPlan) ![]u8 {
    try saved.validate();
    return api.Json.valueAlloc(allocator, saved);
}

pub fn decodeSavedPlan(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Migration.SavedPlan) {
    if (bytes.len == 0 or bytes.len > api.max_message_bytes) return error.InvalidMigrationPlan;
    const parsed = try std.json.parseFromSlice(Migration.SavedPlan, allocator, bytes, .{
        .allocate = .alloc_always,
        .duplicate_field_behavior = .@"error",
        .ignore_unknown_fields = false,
    });
    errdefer parsed.deinit();
    try parsed.value.validate();
    return parsed;
}

pub fn execute(client: *Client, allocator: std.mem.Allocator, request: Migration.Request) !Response {
    try request.validate();
    const response = try client.callAllocated(.{ .migrate = request }, allocator);
    return response;
}

test "parseFilename splits version_id and descriptive name" {
    const t = std.testing;
    const p1 = try parseFilename("0001-init.sql");
    try t.expectEqualStrings("0001", p1.version_id);
    try t.expectEqualStrings("init", p1.name);

    const p2 = try parseFilename("20261030_add_users.sql");
    try t.expectEqualStrings("20261030", p2.version_id);
    try t.expectEqualStrings("add_users", p2.name);

    try t.expectError(error.InvalidMigrationFilename, parseFilename("0001-init.txt"));
    try t.expectError(error.InvalidMigrationVersion, parseFilename("-init.sql"));
}

test "migration file loading keeps the source budget separate from statement admission" {
    const t = std.testing;
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    const path = try std.fs.path.join(t.allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "0001-source.sql" });
    defer t.allocator.free(path);
    var bytes: [api.max_sql_bytes + 1]u8 = @splat(' ');
    @memcpy(bytes[60000..60009], "SELECT 1;");
    try temporary.dir.writeFile(t.io, .{ .sub_path = "0001-source.sql", .data = bytes[0..api.max_sql_bytes] });
    const Check = struct {
        fn run(allocator: std.mem.Allocator, source_path: []const u8) !void {
            const source = try loadSourceFile(allocator, t.io, source_path);
            defer allocator.free(source.version_id);
            defer allocator.free(source.name);
            defer allocator.free(source.path);
            defer allocator.free(source.sql);
            try source.validate();
            try t.expectEqual(api.max_sql_bytes, source.sql.len);
            try t.expectError(error.StatementTooLarge, api.fuze.Sql.validateText(source.sql));
            var script = try api.fuze.SqlScript.init(source.sql);
            const statement = (try script.next()).?;
            try t.expectEqualStrings("SELECT 1", source.sql[statement.start..statement.end]);
            try t.expectEqual(null, try script.next());
        }
    };
    try t.checkAllAllocationFailures(t.allocator, Check.run, .{path});
    try temporary.dir.writeFile(t.io, .{ .sub_path = "0001-source.sql", .data = &bytes });
    try t.expectError(error.StreamTooLong, loadSourceFile(t.allocator, t.io, path));
    for ([_][]const u8{ "SELECT\x001;", "SELECT\xff1;" }) |invalid| {
        try temporary.dir.writeFile(t.io, .{ .sub_path = "0001-source.sql", .data = invalid });
        try t.expectError(error.InvalidSqlEncoding, loadSourceFile(t.allocator, t.io, path));
    }
}

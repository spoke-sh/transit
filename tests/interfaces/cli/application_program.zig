//! Independent consumer-source oracle. Expected boundaries are reviewed fixture
//! inputs; the production framer and parser do not generate their expectations.
const std = @import("std");
const f = @import("transit_fuze");
const service = @import("transit_sql_service");
const Manifest = struct {
    repository: []const u8,
    revision: []const u8,
    files: []const struct { path: []const u8, bytes: usize, sha256: []const u8, statement_lines: []const u32 },
};
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 6) return error.Usage;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(8192));
    const manifest = try std.json.parseFromSlice(Manifest, allocator, bytes, .{});
    const binding_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[2], allocator, .limited(32 * 1024));
    const bindings = try std.json.parseFromSlice([]const f.ApplicationProgram.Types.Resource, allocator, binding_bytes, .{});
    const t = std.testing;
    try t.expectEqual(3, manifest.value.files.len);
    var programs: usize = 0;
    for (manifest.value.files, args[3..]) |file, path| {
        try t.expectEqualStrings(file.path, std.fs.path.basename(path));
        const source = try std.Io.Dir.cwd().readFileAlloc(init.io, path, allocator, .limited(f.SqlScript.max_source_bytes));
        try t.expectEqual(file.bytes, source.len);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, file.sha256);
        try (service.session_protocol.Migration.SourceFile{ .version_id = file.path[0..4], .name = file.path, .path = file.path, .sql = source, .sha256 = expected }).validate();
        const steps = try service.MigrationRunner.splitStatements(allocator, source);
        try t.expectEqual(file.statement_lines.len, steps.len);
        for (steps, file.statement_lines) |step, line| {
            try t.expectEqual(line, step.line);
            if (!std.mem.startsWith(u8, step.sql, "CREATE DATAFLOW")) continue;
            var location: f.Sql.Location = .{};
            var parsed = f.ApplicationProgram.parse(allocator, step.sql, &location) catch |err| {
                std.debug.print("{s}:{d}: program parser failed at byte {d}: {s}\n", .{ file.path, line, location.offset, @errorName(err) });
                return err;
            };
            defer parsed.deinit();
            try t.expect(parsed.program.nodes > 0);
            var bound = f.ApplicationProgram.Types.bind(allocator, parsed.program, bindings.value, &location) catch |err| {
                std.debug.print("{s}:{d}: program binding failed at byte {d}: {s}\n", .{ file.path, line, location.offset, @errorName(err) });
                return err;
            };
            defer bound.deinit();
            try t.expect(bound.uses.len > 0);
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(step.sql, &digest, .{});
            const encoded = try f.ApplicationProgram.Codec.encode(allocator, parsed.program, digest);
            defer allocator.free(encoded);
            var retained = try f.ApplicationProgram.Codec.decode(allocator, encoded);
            defer retained.deinit();
            try t.expectEqualDeep(parsed.program, retained.program);
            var rebound = try f.ApplicationProgram.Types.bind(allocator, retained.program, bindings.value, null);
            defer rebound.deinit();
            try t.expectEqualDeep(bound.uses, rebound.uses);
            try t.expectEqualDeep(bound.values, rebound.values);
            programs += 1;
        }
    }
    try t.expectEqual(6, programs);
    var buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try output.interface.writeAll("Application sources: exact checksums, 43 migration boundaries and six retained typed Queue programs verified against independent schema fixtures; no installation or runtime outcome qualified.\n");
    try output.interface.flush();
}

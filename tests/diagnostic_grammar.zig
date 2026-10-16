//! Public compiler consumer for reviewed grammar/diagnostic cases. No authority,
//! credentials, command preparation or execution is available to this process.
const std = @import("std");
const q = @import("transit_query");
const a = @import("transit_station_app");
const f = q.fuze;
const Case = struct {
    id: []const u8,
    sql: []const u8,
    profile: enum { query, template, declaration, table_ddl, mutation, application, relational, authorization } = .query,
    value_type: f.Unified.Type = .int64,
    source: []const u8 = "items",
    basis: []const u8 = "CREATE TABLE items (id INT64 PRIMARY KEY, value INT64)",
};
fn compile(allocator: std.mem.Allocator, case: Case, binding: *f.Sql.Binding, location: *f.Sql.Location) !void {
    const columns = [_]f.Unified.Column{
        .{ .name = try f.Unified.Name.init("id"), .type = .int64 },
        .{ .name = try f.Unified.Name.init("value"), .type = case.value_type },
    };
    const source: f.Unified.Sql.Source = .{ .name = try f.Unified.Name.init(case.source), .schema = .{ .columns = &columns } };
    switch (case.profile) {
        .authorization => {
            var value = try f.AuthorizationSql.compile(allocator, case.sql, location);
            defer value.deinit();
        },
        .query => _ = try f.Unified.Sql.planDiagnostic(allocator, case.sql, source, binding),
        .template => {
            var value = try f.Prepared.initDiagnostic(allocator, case.sql, source, binding);
            defer value.deinit();
        },
        .declaration => _ = try f.Declaration.compileDiagnostic(case.sql, binding),
        .relational => {
            var parser = try f.SqlTyped.init(allocator, case.sql, location);
            const explain = try parser.takeWord("EXPLAIN");
            const start = if (explain) parser.lexer.start else 0;
            var syntax = f.RelationalSql.parse(allocator, case.sql[start..], location) catch |err| {
                location.offset += start;
                return err;
            };
            defer syntax.deinit();
            var basis = try f.TableDdl.compile(allocator, case.basis, null, null);
            defer basis.deinit();
            var sources: [2]f.Relational.Source = undefined;
            for (syntax.targets, 0..) |target, i| sources[i] = .{ .alias = target.alias, .realm = 1, .resource = i + 1, .catalog = 1, .owner = i + 1, .schema = try basis.statement.create.bind(i + 1) };
            _ = syntax.bind(sources[0..syntax.targets.len], .interactive, .{ .resident_bytes = 1048576, .spill_bytes = 1048576, .result_bytes = 1048576, .output_rows = 1000, .work_steps = 10000, .source_pins = 2 }, location) catch |err| {
                location.offset += start;
                return err;
            };
        },
        .table_ddl, .mutation => {
            var basis = try f.TableDdl.compile(allocator, case.basis, null, null);
            defer basis.deinit();
            const schema = try basis.statement.create.bind(7);
            if (case.profile == .table_ddl) {
                var value = try f.TableDdl.compile(allocator, case.sql, schema, location);
                defer value.deinit();
            } else {
                var value = try f.TableDml.compile(allocator, case.sql, case.source, schema, location);
                defer value.deinit();
            }
        },
        .application => unreachable,
    }
}
pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 2) return error.Usage;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(4 * 1024 * 1024));
    const cases = try std.json.parseFromSlice([]const Case, allocator, bytes, .{ .ignore_unknown_fields = true });
    var buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    for (cases.value) |case| {
        var arena = std.heap.ArenaAllocator.init(init.gpa);
        defer arena.deinit();
        var diagnostic: ?q.protocol.Diagnostic = null;
        var kind: ?f.SqlDiagnostic.Kind = null;
        if (case.profile == .application) {
            var detail: a.Diagnostic = .{};
            if (a.Sql.parseDiagnostic(arena.allocator(), case.sql, &detail)) |parsed_value| {
                var parsed = parsed_value;
                parsed.deinit();
            } else |err| diagnostic = try detail.structured(err);
        } else {
            var binding: f.Sql.Binding = .{};
            var location: f.Sql.Location = .{};
            compile(arena.allocator(), case, &binding, &location) catch |err| {
                const detail = (switch (case.profile) {
                    .authorization => f.SqlDiagnostic.authorization(case.sql, err, location),
                    .mutation => f.SqlDiagnostic.tableDml(case.sql, err, location),
                    .table_ddl => f.SqlDiagnostic.tableDdl(case.sql, err, location),
                    .relational => f.SqlDiagnostic.tableSelect(case.sql, err, location),
                    .declaration => f.SqlDiagnostic.writeCompiler(case.sql, err, .declaration, binding),
                    else => f.SqlDiagnostic.bound(case.sql, err, false, binding),
                }) orelse {
                    std.debug.print("Unmapped grammar case {s}: {s}\n", .{ case.id, @errorName(err) });
                    return error.UnmappedGrammarDiagnostic;
                };
                kind = detail.kind;
                diagnostic = try detail.structured();
            };
        }
        if (diagnostic) |detail| try detail.validate();
        try std.json.Stringify.value(.{ .id = case.id, .accepted = diagnostic == null, .kind = kind, .diagnostic = diagnostic }, .{}, &output.interface);
        try output.interface.writeByte('\n');
    }
    try output.interface.flush();
}

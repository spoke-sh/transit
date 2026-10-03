//! Public compiler consumer for reviewed grammar/diagnostic cases. No authority,
//! credentials, command preparation or execution is available to this process.
const std = @import("std");
const q = @import("transit_query");
const a = @import("transit_station_app");
const f = q.fuze;
const Case = struct {
    id: []const u8,
    sql: []const u8,
    profile: enum { query, template, declaration, mutation, application } = .query,
    value_type: f.Unified.Type = .int64,
    source: []const u8 = "items",
};
fn compile(allocator: std.mem.Allocator, case: Case, binding: *f.Sql.Binding) !void {
    const columns = [_]f.Unified.Column{
        .{ .name = try f.Unified.Name.init("id"), .type = .int64 },
        .{ .name = try f.Unified.Name.init("value"), .type = case.value_type },
    };
    const source: f.Unified.Sql.Source = .{ .name = try f.Unified.Name.init(case.source), .schema = .{ .columns = &columns } };
    switch (case.profile) {
        .query => _ = try f.Unified.Sql.planDiagnostic(allocator, case.sql, source, binding),
        .template => {
            var value = try f.Prepared.initDiagnostic(allocator, case.sql, source, binding);
            defer value.deinit();
        },
        .declaration => _ = try f.Declaration.compileDiagnostic(case.sql, binding),
        .mutation => _ = try f.TableMutation.compileDiagnostic(case.sql, .{ .name = try f.model.Name.init(case.source), .schema = .{ .names = .{ try f.model.Name.init("id"), try f.model.Name.init("value") }, .value_type = std.meta.stringToEnum(f.model.Type, @tagName(case.value_type)) orelse return error.InvalidFixtureType } }, binding),
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
            compile(arena.allocator(), case, &binding) catch |err| {
                const detail = (switch (case.profile) {
                    .mutation => f.SqlDiagnostic.writeCompiler(case.sql, err, .mutation, binding),
                    .declaration => f.SqlDiagnostic.writeCompiler(case.sql, err, .declaration, binding),
                    else => f.SqlDiagnostic.bound(case.sql, err, false, binding),
                }) orelse return error.UnmappedGrammarDiagnostic;
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

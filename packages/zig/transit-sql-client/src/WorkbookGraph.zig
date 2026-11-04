//! Session-local relation bindings. Names resolve through the Fuze SQL parser;
//! presentation order has no authority over evaluation order.
const std = @import("std");
const f = @import("transit_fuze");
pub const max_cells = 4;
pub const Cell = struct { id: []const u8, name: []const u8, sql: []const u8 };
pub const Binding = struct { cell: []const u8, input: ?[]const u8 };
pub const Issue = struct { cell: []const u8, code: []const u8, path: []const []const u8 = &.{} };
pub const Validation = struct {
    pub const json_schema_sequence_bounds = .{ .bindings = max_cells };
    bindings: []const Binding,
    issue: ?Issue = null,
};
pub const Graph = struct {
    cells: []const Cell,
    inputs: [max_cells]?usize = @splat(null),
    targets: [max_cells][]const u8 = undefined,
    validation: Validation,
    pub fn affects(self: Graph, changed: usize, dependent: usize) bool {
        var at: ?usize = dependent;
        for (0..max_cells) |_| {
            const index = at orelse return false;
            if (index == changed) return true;
            at = self.inputs[index];
        }
        return false;
    }
};
pub fn validId(id: []const u8) bool {
    if (id.len != 32) return false;
    for (id) |char| if (!std.ascii.isDigit(char) and !(char >= 'a' and char <= 'f')) return false;
    return true;
}
fn validName(name: []const u8) bool {
    if (name.len == 0 or name.len > 40 or !(std.ascii.isAlphabetic(name[0]) or name[0] == '_')) return false;
    for (name) |char| if (!std.ascii.isAlphanumeric(char) and char != '_') return false;
    return true;
}
pub fn analyze(allocator: std.mem.Allocator, cells: []const Cell) !Graph {
    if (cells.len == 0 or cells.len > max_cells) return error.InvalidWorkbookSize;
    const bindings = try allocator.alloc(Binding, cells.len);
    for (cells, bindings) |cell, *binding| binding.* = .{ .cell = cell.id, .input = null };
    var graph: Graph = .{ .cells = cells, .validation = .{ .bindings = bindings } };
    var bytes: usize = 0;
    for (cells, 0..) |cell, i| {
        if (!validId(cell.id) or !validName(cell.name)) {
            graph.validation.issue = .{ .cell = cell.id, .code = "InvalidCellIdentity" };
            return graph;
        }
        bytes += cell.sql.len;
        if (cell.sql.len == 0 or bytes > 60000) return error.InvalidWorkbookSize;
        for (cells[0..i]) |earlier| {
            if (std.mem.eql(u8, earlier.name, cell.name) or std.mem.eql(u8, earlier.id, cell.id)) {
                graph.validation.issue = .{ .cell = cell.id, .code = "DuplicateCell" };
                return graph;
            }
        }
        var parser = f.SqlTyped.init(allocator, cell.sql, null) catch |err| {
            graph.validation.issue = .{ .cell = cell.id, .code = @errorName(err) };
            return graph;
        };
        const syntax = f.TableSelect.syntax(&parser, null) catch |err| {
            graph.validation.issue = .{ .cell = cell.id, .code = @errorName(err) };
            return graph;
        };
        parser.finish() catch |err| {
            graph.validation.issue = .{ .cell = cell.id, .code = @errorName(err) };
            return graph;
        };
        graph.targets[i] = syntax.subject.name;
        const prefix = "workbook.";
        if (std.mem.startsWith(u8, syntax.subject.name, prefix)) {
            const name = syntax.subject.name[prefix.len..];
            const input = for (cells, 0..) |candidate, j| {
                if (std.mem.eql(u8, name, candidate.name)) break j;
            } else {
                graph.validation.issue = .{ .cell = cell.id, .code = "MissingCellInput" };
                return graph;
            };
            graph.inputs[i] = input;
            bindings[i].input = cells[input].id;
        }
    }
    for (cells, 0..) |cell, i| {
        var path: [max_cells + 1][]const u8 = undefined;
        var length: usize = 0;
        var at: ?usize = i;
        while (at) |index| {
            path[length] = cells[index].id;
            length += 1;
            if ((index == i and length > 1) or length > max_cells) {
                graph.validation.issue = .{ .cell = cell.id, .code = "WorkbookCycle", .path = try allocator.dupe([]const u8, path[0..length]) };
                return graph;
            }
            at = graph.inputs[index];
        }
    }
    return graph;
}

test "parser bindings ignore comments and strings; order is not a dependency" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    const cells = [_]Cell{
        .{ .id = "00000000000000000000000000000001", .name = "summary", .sql = "SELECT COUNT(*) AS n FROM \"workbook.filtered\"" },
        .{ .id = "00000000000000000000000000000002", .name = "source", .sql = "SELECT * FROM metrics /* workbook.summary */" },
        .{ .id = "00000000000000000000000000000003", .name = "filtered", .sql = "SELECT id FROM \"workbook.source\" WHERE name = 'workbook.summary'" },
    };
    const graph = try analyze(arena.allocator(), &cells);
    try std.testing.expect(graph.validation.issue == null);
    try std.testing.expectEqual(@as(?usize, 2), graph.inputs[0]);
    try std.testing.expect(graph.affects(1, 0));
    try std.testing.expect(!graph.affects(2, 1));
}
test "cycles and missing input block the graph with the path" {
    var arena: std.heap.ArenaAllocator = .init(std.testing.allocator);
    defer arena.deinit();
    var cells = [_]Cell{
        .{ .id = "00000000000000000000000000000001", .name = "a", .sql = "SELECT * FROM \"workbook.b\"" },
        .{ .id = "00000000000000000000000000000002", .name = "b", .sql = "SELECT * FROM \"workbook.a\"" },
    };
    const cycle = try analyze(arena.allocator(), &cells);
    try std.testing.expectEqualStrings("WorkbookCycle", cycle.validation.issue.?.code);
    try std.testing.expectEqual(@as(usize, 3), cycle.validation.issue.?.path.len);
    cells[1].name = "renamed";
    const missing = try analyze(arena.allocator(), &cells);
    try std.testing.expectEqualStrings("MissingCellInput", missing.validation.issue.?.code);
}

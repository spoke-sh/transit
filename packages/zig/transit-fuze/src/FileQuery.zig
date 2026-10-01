//! Finite plans over a frozen file binding. SQL parsing, literals and cell/aggregate
//! semantics are shared with native Unified plans. All source rows are decoded
//! and verified even when projection/filter/limit would discard their values.
const std = @import("std");
const types = @import("Types.zig");
const source = @import("FileSource.zig");
const finite = @import("Finite.zig");
const values = types.Values;
pub const Plan = struct {
    schema: types.Type,
    source_basis: [32]u8,
    projection: []const u8,
    predicate: union(enum) {
        all,
        state: struct { column: u8, value: types.State },
        compare: struct { column: u8, op: finite.Comparison, value: types.Semantics.Atom },
    } = .all,
    aggregate: finite.Aggregate = .rows,
    limit: ?u64 = null,
    pub fn validate(self: Plan) !void {
        try self.schema.validate(.{});
        if (self.schema != .structure or self.schema.structure.len > 128) return error.InvalidQuerySchema;
        if (self.projection.len == 0 or self.projection.len > 128) return error.InvalidProjection;
        for (self.projection, 0..) |index, i| {
            if (index >= self.schema.structure.len) return error.UnknownColumn;
            for (self.projection[0..i]) |earlier| if (index == earlier) return error.DuplicateProjection;
        }
        if (self.aggregate != .rows and self.projection.len != 1) return error.UnsupportedAggregate;
        if (self.aggregate == .sum and self.schema.structure[self.projection[0]].type != .int64) return error.UnsupportedAggregate;
        switch (self.predicate) {
            .all => {},
            .state => |state| if (state.column >= self.schema.structure.len) return error.UnknownColumn,
            .compare => |comparison| {
                if (comparison.column >= self.schema.structure.len) return error.UnknownColumn;
                try types.Semantics.validate(comparison.value, self.schema.structure[comparison.column].type);
                if (comparison.value == .bytes and comparison.value.bytes.len > types.Query.max_cell_bytes) return error.CellTooLarge;
                if (self.schema.structure[comparison.column].type == .interval) return error.UnsupportedComparison;
            },
        }
    }
    pub fn fingerprint(self: Plan) ![32]u8 {
        try self.validate();
        var bytes: [8192]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("transit.fuze.file-plan.v1\x00");
        try writer.writeAll(&self.source_basis);
        try writer.writeAll(&try self.schema.fingerprint());
        try writer.writeByte(@backingInt(self.aggregate));
        try writer.writeByte(@intCast(self.projection.len));
        try writer.writeAll(self.projection);
        try writer.writeByte(@intFromBool(self.limit != null));
        try writer.writeInt(u64, self.limit orelse 0, .little);
        switch (self.predicate) {
            .all => try writer.writeByte(0),
            .state => |state| try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) }),
            .compare => |comparison| {
                try writer.writeAll(&.{ 2, comparison.column, @backingInt(comparison.op) });
                var value: [6144]u8 = undefined;
                const encoded = try types.Codec.encode(.{ .value = .{ .atom = comparison.value } }, .{ .name = "literal", .type = self.schema.structure[comparison.column].type }, &value);
                try writer.writeInt(u16, @intCast(encoded.len), .little);
                try writer.writeAll(encoded);
            },
        }
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
        return digest;
    }
    pub fn outputSchema(self: Plan, fields: []types.Field) !types.Type {
        try self.validate();
        if (fields.len < self.projection.len) return error.InvalidProjection;
        if (self.aggregate != .rows) {
            fields[0] = .{ .name = @tagName(self.aggregate), .type = if (self.aggregate == .count) .uint64 else .int64, .nullable = self.aggregate == .sum };
            return .{ .structure = fields[0..1] };
        }
        for (self.projection, 0..) |index, i| fields[i] = self.schema.structure[index];
        return .{ .structure = fields[0..self.projection.len] };
    }
    fn matches(self: Plan, cells: []const values.Cell) !bool {
        return switch (self.predicate) {
            .all => true,
            .state => |state| std.meta.activeTag(cells[state.column]) == state.value,
            .compare => |comparison| finite.compare(comparison.op, cells[comparison.column], comparison.value, self.schema.structure[comparison.column].type, struct {
                fn order(expected: types.Type, left: values.Value, right: types.Semantics.Atom) !std.math.Order {
                    if (left != .atom) return error.UnsupportedComparison;
                    return values.atomOrder(left.atom, right, expected);
                }
            }.order),
        };
    }
};
pub const Compiled = struct {
    arena: std.heap.ArenaAllocator,
    descriptor: types.Decoded,
    plan: Plan,
    pub fn deinit(self: *Compiled) void {
        self.arena.deinit();
        self.descriptor.deinit();
        self.* = undefined;
    }
};
pub fn compile(allocator: std.mem.Allocator, text: []const u8, name: []const u8, binding: *const source.Binding) !Compiled {
    try binding.validateMetadata();
    var encoded: [types.max_encoding_bytes]u8 = undefined;
    var descriptor = try types.decode(allocator, try binding.schema.type.encode(&encoded));
    errdefer descriptor.deinit();
    const schema = descriptor.type;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    const ast = try @import("Sql.zig").parse(text);
    var names: [128][]const u8 = undefined;
    for (schema.structure, 0..) |field, i| names[i] = field.name;
    var input: [128]u8 = undefined;
    var projected: [128]u8 = undefined;
    const shape = try @import("SqlLowering.zig").lower(ast, name, names[0..schema.structure.len], &input, &projected);
    var plan: Plan = .{ .schema = schema, .source_basis = binding.digest, .projection = try alloc.dupe(u8, shape.projection), .aggregate = shape.aggregate, .limit = shape.limit };
    plan.predicate = switch (shape.predicate) {
        .all => .all,
        .state => |state| .{ .state = .{ .column = state.column, .value = state.value } },
        .compare => |comparison| blk: {
            const scalar = try @import("UnifiedSql.zig").scalar(alloc, comparison.literal);
            // The same SQL literal typing as native queries: no source-specific
            // implicit cast or reinterpretation of a string as an exact number.
            try scalar.validate(try schema.structure[comparison.column].type.queryType());
            const cell = try values.fromQuery(.{ .value = scalar });
            break :blk .{ .compare = .{ .column = comparison.column, .op = comparison.op, .value = cell.value.atom } };
        },
    };
    try plan.validate();
    return .{ .arena = arena, .descriptor = descriptor, .plan = plan };
}
pub const Execution = struct {
    scan: source.Scan,
    plan: Plan,
    fingerprint: [32]u8,
    scanned: u64 = 0,
    selected: u64 = 0,
    emitted: u64 = 0,
    sum: ?i64 = null,
    complete: bool = false,
    failed: bool = false,
    pub fn init(allocator: std.mem.Allocator, binding: *const source.Binding, sources: []const source.Source, plan: Plan) !Execution {
        try plan.validate();
        if (!std.mem.eql(u8, &plan.source_basis, &binding.digest) or !try plan.schema.eql(binding.schema.type)) return error.SourceChanged;
        const fingerprint = try plan.fingerprint();
        return .{ .scan = try source.Scan.init(allocator, binding, sources), .plan = plan, .fingerprint = fingerprint };
    }
    pub fn deinit(self: *Execution) void {
        self.scan.deinit();
        self.* = undefined;
    }
    pub fn next(self: *Execution) !?source.Row {
        if (self.failed) return error.FailedQuery;
        if (self.complete) return null;
        errdefer self.failed = true;
        if (!std.mem.eql(u8, &try self.plan.fingerprint(), &self.fingerprint)) return error.SourceChanged;
        while (try self.scan.next()) |owned| {
            var row = owned;
            errdefer row.deinit();
            self.scanned = try std.math.add(u64, self.scanned, 1);
            if ((self.plan.limit != null and self.selected == self.plan.limit.?) or !try self.plan.matches(row.cells)) {
                row.deinit();
                continue;
            }
            self.selected = try std.math.add(u64, self.selected, 1);
            if (self.plan.aggregate == .sum) self.sum = try finite.sum(self.sum, row.cells[self.plan.projection[0]], struct {
                fn integer(value: values.Value) !i64 {
                    if (value != .atom or value.atom != .signed) return error.TypeMismatch;
                    return std.math.cast(i64, value.atom.signed) orelse error.Overflow;
                }
            }.integer);
            if (self.plan.aggregate == .rows) {
                const projected = try row.arena.allocator().alloc(values.Cell, self.plan.projection.len);
                for (self.plan.projection, projected) |index, *cell| cell.* = row.cells[index];
                row.cells = projected;
                self.emitted = try std.math.add(u64, self.emitted, 1);
                return row;
            }
            row.deinit();
        }
        if (!self.scan.complete) return error.IncompleteSource;
        if (self.plan.aggregate != .rows) {
            var arena: std.heap.ArenaAllocator = .init(self.scan.allocator);
            errdefer arena.deinit();
            const cells = try arena.allocator().alloc(values.Cell, 1);
            cells[0] = if (self.plan.aggregate == .count) .{ .value = .{ .atom = .{ .unsigned = self.selected } } } else if (self.sum) |sum| .{ .value = .{ .atom = .{ .signed = sum } } } else .null;
            self.complete = true;
            self.emitted = 1;
            return .{ .arena = arena, .cells = cells };
        }
        self.complete = true;
        return null;
    }
};

const Memory = struct {
    bytes: []const u8,
    fn read(context: *anyopaque, offset: u64, output: []u8) !usize {
        const self: *Memory = @ptrCast(@alignCast(context));
        const start: usize = @intCast(offset);
        const n = @min(output.len, self.bytes.len - start);
        @memcpy(output[0..n], self.bytes[start..][0..n]);
        return n;
    }
    fn check(_: *anyopaque) !void {}
    fn handle(self: *Memory) source.Source {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.bytes, &digest, .{});
        return .{ .context = self, .read = read, .check = check, .length = self.bytes.len, .digest = digest };
    }
};
test "file SELECT shares projection filter limit count and ordered sum semantics" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id,value\n1,2\n2,3\n3,4\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var selected = try compile(t.allocator, "SELECT value FROM input WHERE id >= 2 LIMIT 1", "input", &binding);
    defer selected.deinit();
    var rows = try Execution.init(t.allocator, &binding, &sources, selected.plan);
    defer rows.deinit();
    var row = (try rows.next()).?;
    defer row.deinit();
    try t.expectEqual(@as(i128, 3), row.cells[0].value.atom.signed);
    try t.expect((try rows.next()) == null);
    try t.expect(rows.complete);
    try t.expectEqual(@as(u64, 3), rows.scanned);
    for ([_]struct { sql: []const u8, expected: i128 }{
        .{ .sql = "SELECT COUNT(*) FROM input", .expected = 3 },
        .{ .sql = "SELECT SUM(value) FROM input", .expected = 9 },
        .{ .sql = "SELECT SUM(chosen.value) FROM (SELECT value FROM input WHERE id >= 2 LIMIT 1) AS chosen", .expected = 3 },
    }) |fixture| {
        var compiled = try compile(t.allocator, fixture.sql, "input", &binding);
        defer compiled.deinit();
        var execution = try Execution.init(t.allocator, &binding, &sources, compiled.plan);
        defer execution.deinit();
        var result = (try execution.next()).?;
        defer result.deinit();
        const atom = result.cells[0].value.atom;
        try t.expectEqual(fixture.expected, if (atom == .unsigned) @as(i128, @intCast(atom.unsigned)) else atom.signed);
        try t.expect(execution.complete);
        try t.expect((try execution.next()) == null);
    }
}
test "file projections and limits never hide a source conversion failure" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id,value\n1,2\n2,outlier\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .sample_records = 1 }, &.{});
    defer binding.deinit();
    var compiled = try compile(t.allocator, "SELECT id FROM input LIMIT 1", "input", &binding);
    defer compiled.deinit();
    var execution = try Execution.init(t.allocator, &binding, &sources, compiled.plan);
    defer execution.deinit();
    var first = (try execution.next()).?;
    first.deinit();
    try t.expectError(error.InvalidLiteral, execution.next());
    try t.expect(!execution.complete);
    try t.expectError(error.FailedQuery, execution.next());
}
test "typed file plans compare all integer bits while SQL keeps exact literal admission" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "n\n340282366920938463463374607431768211455\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    const plan: Plan = .{ .schema = binding.schema.type, .source_basis = binding.digest, .projection = &.{0}, .predicate = .{ .compare = .{ .column = 0, .op = .eq, .value = .{ .unsigned = std.math.maxInt(u128) } } } };
    var execution = try Execution.init(t.allocator, &binding, &sources, plan);
    defer execution.deinit();
    var row = (try execution.next()).?;
    defer row.deinit();
    try t.expectEqual(std.math.maxInt(u128), row.cells[0].value.atom.unsigned);
    try t.expect((try execution.next()) == null);
    try t.expectError(error.UnsupportedQueryType, compile(t.allocator, "SELECT n FROM input WHERE n = 1", "input", &binding));
    try t.expectError(error.UnsupportedAggregate, compile(t.allocator, "SELECT SUM(n) FROM input", "input", &binding));
}
fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var memory: Memory = .{ .bytes = "id,text\n1,hello\n2,world\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var compiled = try compile(allocator, "SELECT id FROM input WHERE text = 'hello'", "input", &binding);
    defer compiled.deinit();
    var execution = try Execution.init(allocator, &binding, &sources, compiled.plan);
    defer execution.deinit();
    var count: usize = 0;
    while (try execution.next()) |owned| {
        var row = owned;
        defer row.deinit();
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), count);
}
test "file plan and result allocation failures release owned schema literals and rows" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationSchedule, .{});
}

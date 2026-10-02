//! Finite plans over a frozen file binding. SQL parsing, literals and cell/aggregate
//! semantics are shared with native Unified plans. All source rows are decoded
//! and verified even when projection/filter/limit would discard their values.
const std = @import("std");
const types = @import("Types.zig");
const source = @import("FileSource.zig");
const finite = @import("Finite.zig");
const values = types.Values;
const machine = @import("PredicateMachine.zig");
const lowering = @import("SqlLowering.zig");

/// Instructions and variable-width atoms borrow immutable caller storage.
/// Compiled file plans own both through their arena.
pub const Program = struct {
    pub const max_instructions = machine.max_instructions;
    pub const Instruction = machine.Instruction(Plan.Atom);
    instructions: []const Instruction,

    pub fn validate(self: Program, schema: types.Type) !void {
        try machine.validateShape(self.instructions);
        for (self.instructions) |instruction| {
            if (instruction == .atom) try instruction.atom.validate(schema);
        }
    }
    pub fn truth(self: Program, schema: types.Type, cells: []const values.Cell) !finite.Truth {
        return machine.truth(self.instructions, PredicateRow{ .schema = schema, .cells = cells });
    }
};
const PredicateRow = struct { schema: types.Type, cells: []const values.Cell };
pub const Plan = struct {
    schema: types.Type,
    source_basis: [32]u8,
    projection: []const u8,
    /// Empty retains defaults; otherwise one optional borrowed name per output.
    /// Names and their vector must remain immutable through execution.
    output_names: []const ?[]const u8 = &.{},
    predicate: union(enum) {
        all,
        state: @FieldType(Atom, "state"),
        compare: @FieldType(Atom, "compare"),
        program: Program,
    } = .all,
    aggregate: finite.Aggregate = .rows,
    limit: ?u64 = null,
    pub const Atom = union(enum) {
        all,
        state: struct { column: u8, value: types.State },
        compare: struct { column: u8, op: finite.Comparison, value: types.Semantics.Atom },

        pub fn validateShape(self: Atom) !void {
            switch (self) {
                .all => {},
                .state => |state| if (state.column >= 128) return error.UnknownColumn,
                .compare => |comparison| {
                    if (comparison.column >= 128) return error.UnknownColumn;
                    if (comparison.value == .bytes and comparison.value.bytes.len > types.Query.max_cell_bytes) return error.CellTooLarge;
                },
            }
        }
        pub fn validate(self: Atom, schema: types.Type) !void {
            try self.validateShape();
            if (schema != .structure) return error.InvalidQuerySchema;
            switch (self) {
                .all => {},
                .state => |state| if (state.column >= schema.structure.len) return error.UnknownColumn,
                .compare => |comparison| {
                    if (comparison.column >= schema.structure.len) return error.UnknownColumn;
                    const expected = schema.structure[comparison.column].type;
                    try types.Semantics.validate(comparison.value, expected);
                    if (expected == .interval) return error.UnsupportedComparison;
                },
            }
        }
        pub fn truth(self: Atom, row: PredicateRow) !finite.Truth {
            return switch (self) {
                .all => .true_value,
                .state => |state| if (state.column < row.cells.len) finite.Truth.fromBool(std.meta.activeTag(row.cells[state.column]) == state.value) else error.UnknownColumn,
                .compare => |comparison| blk: {
                    if (row.schema != .structure) return error.InvalidQuerySchema;
                    if (comparison.column >= row.cells.len or comparison.column >= row.schema.structure.len) return error.UnknownColumn;
                    break :blk try finite.compareTruth(comparison.op, row.cells[comparison.column], comparison.value, row.schema.structure[comparison.column].type, struct {
                        fn order(expected: types.Type, left: values.Value, right: types.Semantics.Atom) !std.math.Order {
                            if (left != .atom) return error.UnsupportedComparison;
                            return values.atomOrder(left.atom, right, expected);
                        }
                    }.order);
                },
            };
        }
        fn write(self: Atom, schema: types.Type, writer: *std.Io.Writer) !void {
            switch (self) {
                .all => try writer.writeByte(0),
                .state => |state| try writer.writeAll(&.{ 1, state.column, @backingInt(state.value) }),
                .compare => |comparison| {
                    try writer.writeAll(&.{ 2, comparison.column, @backingInt(comparison.op) });
                    var value: [6144]u8 = undefined;
                    const encoded = try types.Codec.encode(.{ .value = .{ .atom = comparison.value } }, .{ .name = "literal", .type = schema.structure[comparison.column].type }, &value);
                    try writer.writeInt(u16, @intCast(encoded.len), .little);
                    try writer.writeAll(encoded);
                },
            }
        }
    };
    pub fn validate(self: Plan) !void {
        try self.schema.validate(.{});
        try self.validateShape();
    }
    // Compiler-owned schemas have already passed Type.clone's validation and
    // remain immutable during lowering. Public plans still validate both parts.
    fn validateShape(self: Plan) !void {
        if (self.schema != .structure or self.schema.structure.len > 128) return error.InvalidQuerySchema;
        if (self.projection.len == 0 or self.projection.len > 128) return error.InvalidProjection;
        if (self.output_names.len != 0 and self.output_names.len != self.projection.len) return error.InvalidOutputNames;
        const renamed = self.hasOutputNames();
        for (self.projection, 0..) |index, i| {
            if (index >= self.schema.structure.len) return error.UnknownColumn;
            if (!renamed) for (self.projection[0..i]) |earlier| {
                if (index == earlier) return error.DuplicateProjection;
            };
        }
        if (self.aggregate != .rows and self.projection.len != 1) return error.UnsupportedAggregate;
        if (self.aggregate == .sum and self.schema.structure[self.projection[0]].type != .int64) return error.UnsupportedAggregate;
        // The 128-field descriptor workspace belongs only to renamed outputs;
        // keep its stack probing/initialization out of ordinary validation.
        if (renamed) try @call(.never_inline, validateOutput, .{&self});
        switch (self.predicate) {
            .program => |program| try program.validate(self.schema),
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).validate(self.schema),
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
            .program => |program| {
                try writer.writeAll(&.{ 3, @intCast(program.instructions.len) });
                for (program.instructions) |instruction| switch (instruction) {
                    .atom => |atom| {
                        try writer.writeByte(0);
                        try atom.write(self.schema, &writer);
                    },
                    .negate => try writer.writeByte(1),
                    .conjunction => try writer.writeByte(2),
                    .disjunction => try writer.writeByte(3),
                };
            },
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).write(self.schema, &writer),
        }
        // Preserve existing unnamed-plan identities. Named plans commit every
        // optional name, including its position, within the same byte budget.
        if (self.hasOutputNames()) {
            try writer.writeAll("output_names\x00");
            for (self.output_names) |name| {
                try writer.writeByte(@intFromBool(name != null));
                if (name) |value| {
                    try writer.writeByte(@intCast(value.len));
                    try writer.writeAll(value);
                }
            }
        }
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &digest, .{});
        return digest;
    }
    pub fn outputSchema(self: Plan, fields: []types.Field) !types.Type {
        try self.validate();
        if (fields.len < self.projection.len) return error.InvalidProjection;
        for (0..self.projection.len) |i| fields[i] = self.outputField(i);
        return .{ .structure = fields[0..self.projection.len] };
    }
    fn hasOutputNames(self: Plan) bool {
        for (self.output_names) |name| if (name != null) return true;
        return false;
    }
    fn outputField(self: Plan, index: usize) types.Field {
        var field = if (self.aggregate == .rows) self.schema.structure[self.projection[index]] else types.Field{
            .name = if (self.aggregate == .count_values) "count" else @tagName(self.aggregate),
            .type = if (self.aggregate == .sum) .int64 else .uint64,
            .nullable = self.aggregate == .sum,
        };
        if (self.output_names.len != 0) if (self.output_names[index]) |name| {
            field.name = name;
        };
        return field;
    }
    fn validateOutput(self: *const Plan) !void {
        var fields: [128]types.Field = undefined;
        for (0..self.projection.len) |i| fields[i] = self.outputField(i);
        // Repeated recursive inputs must still fit the descriptor budget.
        try (types.Type{ .structure = fields[0..self.projection.len] }).validate(.{});
    }
    fn matches(self: Plan, cells: []const values.Cell) !bool {
        const truth = switch (self.predicate) {
            .program => |program| try program.truth(self.schema, cells),
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).truth(.{ .schema = self.schema, .cells = cells }),
        };
        return truth.selects();
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
    return compileDiagnostic(allocator, text, name, binding, null);
}
pub fn compileDiagnostic(allocator: std.mem.Allocator, text: []const u8, name: []const u8, binding: *const source.Binding, diagnostic: ?*@import("Sql.zig").Binding) !Compiled {
    if (diagnostic) |detail| detail.* = .{};
    try binding.validateMetadata();
    var descriptor = try binding.schema.type.clone(allocator);
    errdefer descriptor.deinit();
    const schema = descriptor.type;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    const alloc = arena.allocator();
    var ast: @import("Sql.zig").Ast = undefined;
    var location: @import("Sql.zig").Location = .{};
    try @import("Sql.zig").parseInto(text, &ast, if (diagnostic != null) &location else null);
    var names: [128][]const u8 = undefined;
    for (schema.structure, 0..) |field, i| names[i] = field.name;
    var input: [128]u8 = undefined;
    var projected: [128]u8 = undefined;
    const shape = try lowering.lowerDiagnostic(&ast, name, names[0..schema.structure.len], &input, &projected, diagnostic);
    var output_names: [@import("Unified.zig").max_columns]?[]const u8 = undefined;
    if (shape.input) |*inner| {
        try (Plan{ .schema = schema, .source_basis = binding.digest, .projection = inner.columns, .output_names = namesView(inner.names, &output_names, inner.columns.len) }).validateShape();
    }
    var plan: Plan = .{ .schema = schema, .source_basis = binding.digest, .projection = try alloc.dupe(u8, shape.projection), .aggregate = shape.aggregate, .limit = shape.limit };
    const borrowed_names = namesView(shape.output_names, &output_names, shape.projection.len);
    if (borrowed_names.len != 0) {
        const owned = try alloc.alloc(?[]const u8, borrowed_names.len);
        for (borrowed_names, owned) |borrowed, *item| item.* = if (borrowed) |value| try alloc.dupe(u8, value) else null;
        plan.output_names = owned;
    }
    plan.predicate = switch (shape.predicate) {
        .program => |program| blk: {
            try program.validate();
            const instructions = try alloc.alloc(Program.Instruction, program.count);
            const qualifier = ast.source_alias orelse ast.source;
            for (program.instructions[0..program.count], instructions) |instruction, *output| {
                output.* = switch (instruction) {
                    .atom => |atom| .{ .atom = try lowerAtom(alloc, try lowering.lowerAtomDiagnostic(try program.expand(atom), qualifier.slice(), names[0..schema.structure.len], diagnostic), schema, diagnostic) },
                    .negate => .negate,
                    .conjunction => .conjunction,
                    .disjunction => .disjunction,
                };
            }
            break :blk .{ .program = .{ .instructions = instructions } };
        },
        inline else => |value, tag| blk: {
            const atom = try lowerAtom(alloc, @unionInit(lowering.Atom, @tagName(tag), value), schema, diagnostic);
            break :blk switch (atom) {
                inline else => |item, kind| @unionInit(@FieldType(Plan, "predicate"), @tagName(kind), item),
            };
        },
    };
    try plan.validateShape();
    return .{ .arena = arena, .descriptor = descriptor, .plan = plan };
}
fn lowerAtom(allocator: std.mem.Allocator, atom: lowering.Atom, schema: types.Type, diagnostic: ?*@import("Sql.zig").Binding) !Plan.Atom {
    return switch (atom) {
        .all => .all,
        .state => |state| .{ .state = .{ .column = state.column, .value = state.value } },
        .compare => |comparison| blk: {
            const scalar = try @import("UnifiedSql.zig").scalar(allocator, comparison.literal);
            // Native and file SQL have identical literal admission; no implicit
            // cast or reinterpretation of a string as an exact number.
            scalar.validate(try schema.structure[comparison.column].type.queryType()) catch |err| {
                if (diagnostic) |detail| {
                    detail.expected = @tagName(schema.structure[comparison.column].type);
                    detail.actual = @tagName(scalar);
                    @import("Sql.zig").Binding.supplied(detail, scalar);
                }
                return err;
            };
            const cell = try values.fromQuery(.{ .value = scalar });
            break :blk .{ .compare = .{ .column = comparison.column, .op = comparison.op, .value = cell.value.atom } };
        },
    };
}
fn namesView(names: lowering.OutputNames, output: *[@import("Unified.zig").max_columns]?[]const u8, width: usize) []const ?[]const u8 {
    if (names == .none) return &.{};
    for (output[0..width], 0..) |*item, i| item.* = if (names.get(i)) |value| value.slice() else null;
    return output[0..width];
}
pub const Execution = struct {
    scan: source.Scan,
    plan: Plan,
    fingerprint: [32]u8,
    scanned: u64 = 0,
    selected: u64 = 0,
    value_count: u64 = 0,
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
            if (self.plan.aggregate == .count_values) self.value_count = try finite.countValue(self.value_count, row.cells[self.plan.projection[0]]);
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
            cells[0] = switch (self.plan.aggregate) {
                .count => .{ .value = .{ .atom = .{ .unsigned = self.selected } } },
                .count_values => .{ .value = .{ .atom = .{ .unsigned = self.value_count } } },
                .sum => if (self.sum) |sum| .{ .value = .{ .atom = .{ .signed = sum } } } else .null,
                .rows => unreachable,
            };
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
    var compiled = try compile(t.allocator, "SELECT id FROM input WHERE id = 1 OR id = 2 LIMIT 1", "input", &binding);
    defer compiled.deinit();
    var execution = try Execution.init(t.allocator, &binding, &sources, compiled.plan);
    defer execution.deinit();
    var first = (try execution.next()).?;
    first.deinit();
    try t.expectError(error.InvalidLiteral, execution.next());
    try t.expect(!execution.complete);
    try t.expectError(error.FailedQuery, execution.next());
}

test "file compilation and public plans retain schema validation boundaries" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id,value\n1,2\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    const original = binding.schema.type;
    var compiled = try compile(t.allocator, "SELECT SUM(value) FROM input", "input", &binding);
    defer compiled.deinit();
    for ([_]struct { schema: types.Type, failure: anyerror }{
        .{ .schema = .{ .structure = &.{ .{ .name = "id", .type = .int64 }, .{ .name = "id", .type = .int64 } } }, .failure = error.DuplicateField },
        .{ .schema = .{ .structure = &.{.{ .name = "id", .type = .{ .decimal = .{ .precision = 0, .scale = 0 } } }} }, .failure = error.InvalidDecimal },
    }) |fixture| {
        binding.schema.type = fixture.schema;
        try t.expectError(fixture.failure, compile(t.allocator, "SELECT * FROM input", "input", &binding));
        const borrowed: Plan = .{ .schema = fixture.schema, .source_basis = binding.digest, .projection = &.{0} };
        try t.expectError(fixture.failure, borrowed.validate());
        // A compiled plan owns its already validated descriptor independently.
        try compiled.plan.validate();
    }
    binding.schema.type = original;
    binding.digest[0] ^= 1;
    try t.expectError(error.SourceChanged, compile(t.allocator, "SELECT * FROM input", "input", &binding));
}
test "typed file plans compare all integer bits while SQL keeps exact literal admission" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "n\n340282366920938463463374607431768211455\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    const plan: Plan = .{ .schema = binding.schema.type, .source_basis = binding.digest, .projection = &.{0}, .predicate = .{ .program = .{ .instructions = &.{ .{ .atom = .{ .compare = .{ .column = 0, .op = .ne, .value = .{ .unsigned = std.math.maxInt(u128) } } } }, .negate } } } };
    var execution = try Execution.init(t.allocator, &binding, &sources, plan);
    defer execution.deinit();
    var row = (try execution.next()).?;
    defer row.deinit();
    try t.expectEqual(std.math.maxInt(u128), row.cells[0].value.atom.unsigned);
    try t.expect((try execution.next()) == null);
    try t.expectError(error.UnsupportedQueryType, compile(t.allocator, "SELECT n FROM input WHERE n = 1", "input", &binding));
    try t.expectError(error.UnsupportedAggregate, compile(t.allocator, "SELECT SUM(n) FROM input", "input", &binding));
}
test "file output aliases own names and agree with native column scope" {
    const t = std.testing;
    const unified = @import("Unified.zig");
    var memory: Memory = .{ .bytes = "id,value\n1,2\n2,3\n3,4\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    const native_columns = [_]unified.Column{
        .{ .name = try unified.Name.init("id"), .type = .int64 },
        .{ .name = try unified.Name.init("value"), .type = .int64 },
    };
    const native_source: unified.Sql.Source = .{ .name = try unified.Name.init("input"), .schema = .{ .columns = &native_columns } };
    for ([_]struct { sql: []const u8, names: []const []const u8, columns: []const u8 }{
        .{ .sql = "SELECT value AS first, value AS second FROM input", .names = &.{ "first", "second" }, .columns = &.{ 1, 1 } },
        .{ .sql = "SELECT id, value AS \"Value\" FROM input", .names = &.{ "id", "Value" }, .columns = &.{ 0, 1 } },
        .{ .sql = "SELECT COUNT(*) AS rows FROM input", .names = &.{"rows"}, .columns = &.{0} },
        .{ .sql = "SELECT SUM(value) AS total FROM input", .names = &.{"total"}, .columns = &.{1} },
        .{ .sql = "SELECT SUM(chosen.renamed) AS total FROM (SELECT src.value AS renamed FROM input AS src WHERE src.id > 1 LIMIT 1) AS chosen", .names = &.{"total"}, .columns = &.{1} },
        .{ .sql = "SELECT SUM(chosen.second) FROM (SELECT value AS first, value AS second FROM input LIMIT 1) AS chosen", .names = &.{"sum"}, .columns = &.{1} },
    }) |fixture| {
        const text = try t.allocator.dupe(u8, fixture.sql);
        defer t.allocator.free(text);
        var compiled = try compile(t.allocator, text, "input", &binding);
        defer compiled.deinit();
        // Reusing compiler stack storage must not change an earlier result.
        var subsequent = try compile(t.allocator, "SELECT value AS replaced FROM input", "input", &binding);
        subsequent.deinit();
        var native_arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer native_arena.deinit();
        const native = try unified.Sql.plan(native_arena.allocator(), text, native_source);
        @memset(text, 'x'); // Neither plan may borrow output names from SQL text.
        var fields: [128]types.Field = undefined;
        const output = try compiled.plan.outputSchema(&fields);
        var native_fields: [unified.max_columns]unified.Column = undefined;
        const native_output = try native.outputSchema(native_source.schema, &native_fields);
        try t.expectEqualSlices(u8, fixture.columns, compiled.plan.projection);
        try t.expectEqualSlices(u8, native.projection, compiled.plan.projection);
        for (fixture.names, output.structure, native_output.columns) |name, field, native_field| {
            try t.expectEqualStrings(name, field.name);
            try t.expectEqualStrings(name, native_field.name.slice());
            try t.expectEqual(native_field.type, try field.type.queryType());
        }
        var execution = try Execution.init(t.allocator, &binding, &sources, compiled.plan);
        defer execution.deinit();
        while (try execution.next()) |owned| {
            var row = owned;
            defer row.deinit();
            try t.expectEqual(fixture.columns.len, row.cells.len);
        }
        try t.expect(execution.complete);
    }
    for ([_][]const u8{
        "SELECT value AS id, id FROM input",
        "SELECT value AS same, id AS same FROM input",
        "SELECT value AS renamed FROM input WHERE renamed > 1",
        "SELECT SUM(chosen.value) FROM (SELECT value AS renamed FROM input) AS chosen",
        "SELECT SUM(chosen.id) FROM (SELECT value AS renamed FROM input) AS chosen",
        "SELECT COUNT(*) FROM (SELECT id AS same, value AS same FROM input) AS chosen",
    }) |text| {
        if (compile(t.allocator, text, "input", &binding)) |accepted| {
            var unexpected = accepted;
            unexpected.deinit();
            return error.UnexpectedFileAcceptance;
        } else |_| {}
        var arena: std.heap.ArenaAllocator = .init(t.allocator);
        defer arena.deinit();
        if (unified.Sql.plan(arena.allocator(), text, native_source)) |_| return error.UnexpectedNativeAcceptance else |_| {}
    }
}
test "typed file output names bind identity and enforce output descriptor budgets" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id\n1\n2\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var name = "first".*;
    const names = [_]?[]const u8{&name};
    var plan: Plan = .{ .schema = binding.schema.type, .source_basis = binding.digest, .projection = &.{0} };
    const unnamed = try plan.fingerprint();
    plan.output_names = &.{null};
    try t.expectEqual(unnamed, try plan.fingerprint());
    plan.output_names = &names;
    try t.expect(!std.mem.eql(u8, &unnamed, &try plan.fingerprint()));
    var execution = try Execution.init(t.allocator, &binding, &sources, plan);
    defer execution.deinit();
    var row = (try execution.next()).?;
    row.deinit();
    name[0] = 'F';
    try t.expectError(error.SourceChanged, execution.next());
    try t.expect(!execution.complete);
    try t.expectError(error.FailedQuery, execution.next());
    plan.output_names = &.{ "a", "b" };
    try t.expectError(error.InvalidOutputNames, plan.validate());
    plan.output_names = &.{""};
    try t.expectError(error.InvalidFieldName, plan.validate());
    plan.output_names = &.{"a\x00b"};
    try t.expectError(error.InvalidFieldName, plan.validate());
    plan.output_names = &.{"\xff"};
    try t.expectError(error.InvalidFieldName, plan.validate());
    const child: types.Type = .int64;
    const schema: types.Type = .{ .structure = &.{.{ .name = "list", .type = .{ .list = .{ .type = &child } } }} };
    var repeated_names: [128]?[]const u8 = undefined;
    var storage: [128][3]u8 = undefined;
    for (&repeated_names, &storage, 0..) |*item, *bytes, i| item.* = try std.fmt.bufPrint(bytes, "{d}", .{i});
    const projection: [128]u8 = @splat(0);
    plan = .{ .schema = schema, .source_basis = @splat(0), .projection = &projection, .output_names = &repeated_names };
    try t.expectError(error.TypeBudgetExceeded, plan.validate());
}
fn allocationSchedule(allocator: std.mem.Allocator) !void {
    var memory: Memory = .{ .bytes = "id,text\n1,hello\n2,world\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var compiled = try compile(allocator, "SELECT id AS first, id AS second FROM input WHERE NOT (text <> 'hello' OR id < 1)", "input", &binding);
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

test "file compound SQL owns literals and preserves binding after input text is overwritten" {
    const t = std.testing;
    var memory: Memory = .{ .bytes = "id,text\n1,hello\n2,world\n" };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var text = "SELECT id FROM input WHERE NOT (text <> 'hello' OR id < 1)".*;
    var compiled = try compile(t.allocator, &text, "input", &binding);
    defer compiled.deinit();
    @memset(&text, 'x');
    const literal = compiled.plan.predicate.program.instructions[0].atom.compare.value.bytes;
    try t.expectEqualStrings("hello", literal);
    var execution = try Execution.init(t.allocator, &binding, &sources, compiled.plan);
    defer execution.deinit();
    var first = (try execution.next()).?;
    first.deinit();
    // Typed plans borrow immutable program/literal storage. Mutating a valid
    // literal after execution starts must fail before another row is disclosed.
    @constCast(literal)[0] = 'H';
    try t.expectError(error.SourceChanged, execution.next());
    try t.expect(!execution.complete);
    try t.expectError(error.FailedQuery, execution.next());
}

test "file compound filtering never hides a late changed source digest" {
    const t = std.testing;
    var bytes = "id\n1\n2\n".*;
    var memory: Memory = .{ .bytes = &bytes };
    const sources = [_]source.Source{memory.handle()};
    var binding = try source.discover(t.allocator, &sources, .{ .format = .csv, .mode = .full }, &.{});
    defer binding.deinit();
    var compiled = try compile(t.allocator, "SELECT id FROM input WHERE id < 0 AND NOT (id IS NULL) LIMIT 0", "input", &binding);
    defer compiled.deinit();
    bytes[bytes.len - 2] = '3';
    var execution = try Execution.init(t.allocator, &binding, &sources, compiled.plan);
    defer execution.deinit();
    try t.expectError(error.SourceChanged, execution.next());
    try t.expect(!execution.complete);
    try t.expectError(error.FailedQuery, execution.next());
}

test {
    _ = @import("file_predicate_test.zig");
}

//! Source-independent finite logical plans and pull execution. A scan owns
//! its current row; storage, capture, authorization and disclosure stay outside.
const std = @import("std");
const types = @import("Types.zig");
const values = types.Values;
const finite = @import("Finite.zig");
const machine = @import("PredicateMachine.zig");
const PredicateRow = @import("LogicalPredicate.zig").Row;

pub const Row = struct {
    arena: std.heap.ArenaAllocator,
    cells: []const values.Cell,
    pub fn deinit(self: *Row) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
pub const Program = @import("LogicalPredicate.zig").Program;
pub const Plan = struct {
    schema: types.Type,
    source_basis: [32]u8,
    collations: @import("QueryCollations.zig") = .{},
    projection: []const u8,
    /// Empty retains defaults; otherwise one optional borrowed name per output.
    /// Names and their vector must remain immutable through execution.
    output_names: []const ?[]const u8 = &.{},
    predicate: union(enum) {
        all,
        state: @FieldType(Atom, "state"),
        compare: @FieldType(Atom, "compare"),
        null_compare: @FieldType(Atom, "null_compare"),
        program: Program,
    } = .all,
    aggregate: finite.Aggregate = .rows,
    limit: ?u64 = null,
    pub const Atom = @import("LogicalPredicate.zig").Atom;
    pub fn validate(self: Plan) !void {
        try self.schema.validate(.{});
        try self.validateShape();
    }
    // Compiler-owned schemas have already passed Type.clone's validation and
    // remain immutable during lowering. Public plans still validate both parts.
    pub fn validateShape(self: Plan) !void {
        if (self.schema != .structure or self.schema.structure.len > 128) return error.InvalidQuerySchema;
        try self.collations.validate(self.schema);
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
            .program => |program| try program.validateCollations(self.schema, self.collations),
            inline else => |value, tag| try @as(Atom, @unionInit(Atom, @tagName(tag), value)).validateCollations(self.schema, self.collations),
        }
    }
    pub fn fingerprint(self: Plan) ![32]u8 {
        return self.fingerprintInner() catch |err| switch (err) {
            error.WriteFailed => error.PlanTooLarge,
            else => err,
        };
    }
    fn fingerprintInner(self: Plan) ![32]u8 {
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
        // Named plans commit every optional name and its output position;
        // all plans subsequently commit their input comparison semantics.
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
        try writer.writeAll("collations\x00");
        try self.collations.write(self.schema, &writer);
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
    pub const PredicateFailure = struct { column: u8, instruction: u8 };
    pub fn matches(self: Plan, cells: []const values.Cell, failed: *?PredicateFailure) !bool {
        failed.* = null;
        const row: PredicateRow = .{ .schema = self.schema, .cells = cells, .collations = self.collations };
        const truth = switch (self.predicate) {
            .program => |program| result: {
                var instruction: ?u8 = null;
                break :result machine.truthDiagnostic(program.instructions, row, &instruction) catch |err| {
                    if (instruction) |index| if (atomColumn(program.instructions[index].atom)) |column| {
                        failed.* = .{ .column = column, .instruction = index };
                    };
                    return err;
                };
            },
            inline else => |value, tag| result: {
                const atom: Atom = @unionInit(Atom, @tagName(tag), value);
                break :result atom.truth(row) catch |err| {
                    if (atomColumn(atom)) |column| failed.* = .{ .column = column, .instruction = 0 };
                    return err;
                };
            },
        };
        return truth.selects();
    }
    fn atomColumn(atom: Atom) ?u8 {
        return switch (atom) {
            .all => null,
            .state => |item| item.column,
            .compare => |item| item.column,
            .null_compare => |item| item.column,
        };
    }
};
/// First operator failure, copied before the row and schema owners are released.
/// It describes the frozen execution, never a later read of the source.
pub const Failure = struct {
    operation: enum { predicate, count, sum },
    row: u64,
    column: [128]u8 = @splat(0),
    column_len: u8,
    column_truncated: bool,
    expected: [64]u8,
    expected_len: u8,
    state: types.State,
    instruction: ?u8,
    binding: [32]u8,
    plan: [32]u8,
    pub fn columnName(self: *const Failure) []const u8 {
        return self.column[0..self.column_len];
    }
    pub fn expectedType(self: *const Failure) []const u8 {
        return self.expected[0..self.expected_len];
    }
};
/// Shared ordered row operators for pull execution and resumable bounded steps.
/// A caller validates the immutable plan and row schema before entering. Failed
/// counters are provisional and must never be committed as successful progress.
pub const Counters = struct {
    scanned: u64 = 0,
    selected: u64 = 0,
    value_count: u64 = 0,
    sum: ?i64 = null,
    pub const FailureSite = struct { operation: @FieldType(Failure, "operation"), column: u8, instruction: ?u8 = null };
    pub fn observe(self: *Counters, plan: Plan, cells: []const values.Cell, failure: *?FailureSite) !bool {
        failure.* = null;
        if (cells.len != plan.schema.structure.len) return error.InvalidColumnCount;
        self.scanned = try std.math.add(u64, self.scanned, 1);
        if (plan.limit) |limit| if (self.selected == limit) return false;
        var predicate_failure: ?Plan.PredicateFailure = null;
        if (!(plan.matches(cells, &predicate_failure) catch |err| {
            if (predicate_failure) |site| failure.* = .{ .operation = .predicate, .column = site.column, .instruction = site.instruction };
            return err;
        })) return false;
        return self.contribute(plan, cells, failure);
    }
    /// Consume one selected, validated row after predicate failure arbitration.
    /// The caller has advanced scanned exactly once at the original frontier.
    pub fn contribute(self: *Counters, plan: Plan, cells: []const values.Cell, failure: *?FailureSite) !bool {
        self.selected = try std.math.add(u64, self.selected, 1);
        if (plan.aggregate == .count_values) self.value_count = finite.countValue(self.value_count, cells[plan.projection[0]]) catch |err| {
            failure.* = .{ .operation = .count, .column = plan.projection[0] };
            return err;
        };
        if (plan.aggregate == .sum) self.sum = finite.sum(self.sum, cells[plan.projection[0]], struct {
            fn integer(value: values.Value) !i64 {
                if (value != .atom or value.atom != .signed) return error.TypeMismatch;
                return std.math.cast(i64, value.atom.signed) orelse error.Overflow;
            }
        }.integer) catch |err| {
            failure.* = .{ .operation = .sum, .column = plan.projection[0] };
            return err;
        };
        return true;
    }
    pub fn result(self: Counters, aggregate: finite.Aggregate) !values.Cell {
        return switch (aggregate) {
            .count => .{ .value = .{ .atom = .{ .unsigned = self.selected } } },
            .count_values => .{ .value = .{ .atom = .{ .unsigned = self.value_count } } },
            .sum => if (self.sum) |sum| .{ .value = .{ .atom = .{ .signed = sum } } } else .null,
            .rows => error.UnsupportedAggregate,
        };
    }
};
pub const Verification = enum { full_source, selected_prefix };
pub fn Execution(comptime Scan: type, comptime verification: Verification) type {
    return struct {
        const Self = @This();
        scan: Scan,
        plan: Plan,
        fingerprint: [32]u8,
        scanned: u64 = 0,
        selected: u64 = 0,
        value_count: u64 = 0,
        emitted: u64 = 0,
        sum: ?i64 = null,
        complete: bool = false,
        failed: bool = false,
        failure: ?Failure = null,
        /// Takes ownership of scan only on success. The source owner must establish
        /// the schema and source-basis binding before entering this executor.
        pub fn init(scan: Scan, plan: Plan) !Self {
            return .{ .scan = scan, .plan = plan, .fingerprint = try plan.fingerprint() };
        }
        pub fn deinit(self: *Self) void {
            self.scan.deinit();
            self.* = undefined;
        }
        pub fn next(self: *Self) !?Row {
            if (self.failed) return error.FailedQuery;
            if (self.complete) return null;
            errdefer self.failed = true;
            if (!std.mem.eql(u8, &try self.plan.fingerprint(), &self.fingerprint)) return error.SourceChanged;
            while (if (verification == .selected_prefix and self.atLimit()) null else try self.scan.next()) |owned| {
                var row = owned;
                errdefer row.deinit();
                if (!try self.observe(row.cells)) {
                    row.deinit();
                    continue;
                }
                if (self.plan.aggregate == .rows) {
                    const projected = try row.arena.allocator().alloc(values.Cell, self.plan.projection.len);
                    for (self.plan.projection, projected) |index, *cell| cell.* = row.cells[index];
                    row.cells = projected;
                    self.emitted = try std.math.add(u64, self.emitted, 1);
                    return row;
                }
                row.deinit();
            }
            if (!self.scan.complete and !(verification == .selected_prefix and self.atLimit())) return error.IncompleteSource;
            if (self.plan.aggregate != .rows) {
                var arena: std.heap.ArenaAllocator = .init(self.scan.allocator);
                errdefer arena.deinit();
                const cells = try arena.allocator().alloc(values.Cell, 1);
                cells[0] = try self.counters().result(self.plan.aggregate);
                self.complete = true;
                self.emitted = 1;
                return .{ .arena = arena, .cells = cells };
            }
            self.complete = true;
            return null;
        }
        fn atLimit(self: *const Self) bool {
            return if (self.plan.limit) |limit| self.selected == limit else false;
        }
        fn counters(self: *const Self) Counters {
            return .{ .scanned = self.scanned, .selected = self.selected, .value_count = self.value_count, .sum = self.sum };
        }
        fn observe(self: *Self, cells: []const values.Cell) !bool {
            var progress = self.counters();
            defer {
                self.scanned = progress.scanned;
                self.selected = progress.selected;
                self.value_count = progress.value_count;
                self.sum = progress.sum;
            }
            var failure: ?Counters.FailureSite = null;
            return progress.observe(self.plan, cells, &failure) catch |err| {
                // Capture the same one-based row before the deferred copy.
                self.scanned = progress.scanned;
                if (failure) |site| self.capture(site.operation, cells, site.column, site.instruction);
                return err;
            };
        }
        fn capture(self: *Self, operation: @FieldType(Failure, "operation"), cells: []const values.Cell, column: u8, instruction: ?u8) void {
            if (self.failure != null or column >= self.plan.schema.structure.len or column >= cells.len) return;
            const field = self.plan.schema.structure[column];
            const typed = @import("FileValueDiagnostic.zig").init(.{}, field.type, null);
            var detail: Failure = .{
                .operation = operation,
                .row = self.scanned,
                .column_len = @intCast(@min(field.name.len, 128)),
                .column_truncated = field.name.len > 128,
                .expected = typed.expected,
                .expected_len = typed.expected_len,
                .state = std.meta.activeTag(cells[column]),
                .instruction = instruction,
                .binding = self.plan.source_basis,
                .plan = self.fingerprint,
            };
            @memcpy(detail.column[0..detail.column_len], field.name[0..detail.column_len]);
            self.failure = detail;
        }
    };
}

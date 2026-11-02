//! Dedicated append syntax over the shared typed VALUES binder. Preparation
//! performs no catalog lookup, partition routing, upload or durable admission.
const std = @import("std");
const f = @import("root.zig");
const p = @import("transit_protocol");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Atom = f.Types.Values.Atom;
const Field = f.WorkloadProjection.Field;

pub const Kind = enum { stream, queue };
pub const Target = struct { kind: Kind, source: Reference };
fn header(parser: *Parser) !Target {
    const kind: Kind = if (try parser.takeWord("PRODUCE")) .stream else if (try parser.takeWord("ENQUEUE")) .queue else return error.UnsupportedStatement;
    try parser.requireWord("INTO");
    return .{ .kind = kind, .source = try Reference.unqualified(parser, .source) };
}
pub fn target(allocator: std.mem.Allocator, text: []const u8, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Target {
    var parser = try Parser.initDialect(allocator, text, location, true, dialect);
    return header(&parser);
}

const Operand = struct {
    value: union(enum) { literal: Atom, parameter: f.Sql.Parameter },
    fn parse(parser: *Parser, kind: f.Types.Type, parameters: *std.ArrayList(f.TableDmlPrepared.Parameter)) !Operand {
        if (try parser.parameter()) |site| {
            // Partition, producer ID/epoch/sequence, and visibility are the
            // only metadata sites. Repeated indices still share one type.
            if (parameters.items.len == 5) return error.InvalidLogAppendOperand;
            try parameters.append(parser.allocator, .{ .site = site, .type = kind });
            return .{ .value = .{ .parameter = site } };
        }
        const literal = try parser.literal(kind);
        var failure: ?Parser.Literal.Span = null;
        const cell = literal.bind(parser.allocator, kind, &failure) catch |err| {
            if (parser.location) |location| location.* = .{ .offset = (failure orelse literal.span).start };
            return err;
        };
        if (cell != .value or cell.value != .atom) return error.InvalidLogAppendOperand;
        try f.LogicalPrepared.validate(cell.value.atom, kind);
        return .{ .value = .{ .literal = cell.value.atom } };
    }
    fn bind(self: Operand, values: []const ?Atom) !Atom {
        return switch (self.value) {
            .literal => |value| value,
            .parameter => |site| if (site.index == 0 or site.index > values.len) error.ParameterCountMismatch else values[site.index - 1] orelse error.NullWorkloadParameter,
        };
    }
    fn number(self: Operand, values: []const ?Atom) !u64 {
        return std.math.cast(u64, (try self.bind(values)).unsigned) orelse error.InvalidLogAppendOperand;
    }
};
const Producer = struct { id: Operand, epoch: Operand, sequence: Operand };
const Returning = struct { field: Field, name: []const u8 };

fn returned(parser: *Parser, source: []const u8, schema: f.TableSchema.Schema) !Returning {
    const reference = try Reference.parse(parser);
    const field: Field = if (reference.qualifier == null and std.mem.eql(u8, reference.name, "_partition")) .partition else if (reference.qualifier == null and std.mem.eql(u8, reference.name, "_offset")) .offset else .{ .column = schema.columns[try reference.resolve(source, schema.columns, parser.location)].id };
    return .{ .field = field, .name = if (try parser.takeWord("AS")) try parser.name() else reference.name };
}
fn descriptor(schema: f.TableSchema.Schema, item: Returning) !f.Types.Field {
    return switch (item.field) {
        .column => |id| blk: {
            const column = schema.columns[try schema.index(id)];
            break :blk .{ .name = item.name, .type = column.type, .nullable = column.nullable };
        },
        .partition, .offset => .{ .name = item.name, .type = .uint64 },
        else => error.InvalidLogAppendOperand,
    };
}

pub const Prepared = struct {
    template: f.TableDmlPrepared,
    target: Target,
    partition: ?Operand,
    producer: ?Producer,
    visible: ?Operand,
    return_fields: []const Field,
    return_indices: []const u8,
    return_names: []const ?[]const u8,
    output: ?f.Types.Decoded,

    pub fn init(allocator: std.mem.Allocator, text: []const u8, schema: f.TableSchema.Schema, dialect: f.Sql.Dialect, location: ?*f.Sql.Location) !Prepared {
        try schema.validate();
        var arena: std.heap.ArenaAllocator = .init(allocator);
        defer arena.deinit();
        const a = arena.allocator();
        var parser = try Parser.initDialect(a, try a.dupe(u8, text), location, true, dialect);
        const selected = try header(&parser);
        const syntax: f.TableDml.Syntax = .{
            .subject = .{ .kind = .insert, .name = selected.source.name, .span = selected.source.span },
            .subject_span = selected.source.span,
            .action = .{ .insert = try f.TableDml.insertValues(&parser, schema) },
        };
        var parameters: std.ArrayList(f.TableDmlPrepared.Parameter) = .empty;
        const partition = if (try parser.takeWord("PARTITION")) try Operand.parse(&parser, .uint64, &parameters) else null;
        const producer: ?Producer = if (try parser.takeWord("PRODUCER")) value: {
            try parser.requireWord("ID");
            const id = try Operand.parse(&parser, .uuid, &parameters);
            try parser.requireWord("EPOCH");
            const epoch = try Operand.parse(&parser, .uint64, &parameters);
            try parser.requireWord("SEQUENCE");
            break :value .{ .id = id, .epoch = epoch, .sequence = try Operand.parse(&parser, .uint64, &parameters) };
        } else null;
        const visible = if (try parser.takeWord("WITH")) value: {
            if (selected.kind != .queue) return error.UnsupportedLogAppendOption;
            try parser.require(.left);
            try parser.requireWord("VISIBLE_AT");
            try parser.require(.eq);
            const operand = try Operand.parse(&parser, .{ .timestamp = .utc }, &parameters);
            try parser.require(.right);
            break :value operand;
        } else null;
        var returning: std.ArrayList(Returning) = .empty;
        if (try parser.takeWord("RETURNING")) {
            if (try parser.take(.star)) {
                for (schema.columns) |column| try returning.append(a, .{ .field = .{ .column = column.id }, .name = try a.dupe(u8, column.name) });
            } else while (true) {
                if (returning.items.len == f.TableSchema.max_columns) return error.InvalidProjection;
                try returning.append(a, try returned(&parser, selected.source.name, schema));
                if (!try parser.take(.comma)) break;
            }
        }
        try parser.finish();
        var fields: std.ArrayList(Field) = .empty;
        const indices = try a.alloc(u8, returning.items.len);
        const names = try a.alloc(?[]const u8, returning.items.len);
        var output_fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        for (returning.items, indices, names, 0..) |item, *index, *name, i| {
            for (returning.items[0..i]) |earlier| {
                if (std.mem.eql(u8, earlier.name, item.name)) return error.InvalidOutputNames;
                // FQP1's input layout has distinct names even when SQL aliases
                // distinguish application columns from metadata in the output.
                if (!std.meta.eql(earlier.field, item.field) and
                    std.mem.eql(u8, fieldName(schema, earlier.field), fieldName(schema, item.field)))
                    return error.DuplicateColumn;
            }
            index.* = for (fields.items, 0..) |field, j| {
                if (std.meta.eql(field, item.field)) break @intCast(j);
            } else value: {
                try fields.append(a, item.field);
                break :value @intCast(fields.items.len - 1);
            };
            name.* = item.name;
            output_fields[i] = try descriptor(schema, item);
        }
        var output: ?f.Types.Decoded = if (returning.items.len == 0) null else try (f.Types.Type{ .structure = output_fields[0..returning.items.len] }).clone(allocator);
        errdefer if (output) |*value| value.deinit();
        const template = try f.TableDmlPrepared.adoptSyntax(allocator, &arena, selected.source.name, schema, syntax, parameters.items, location);
        return .{ .template = template, .target = selected, .partition = partition, .producer = producer, .visible = visible, .return_fields = fields.items, .return_indices = indices, .return_names = names, .output = output };
    }
    pub fn deinit(self: *Prepared) void {
        if (self.output) |*output| output.deinit();
        self.template.deinit();
        self.* = undefined;
    }
    pub fn parameterTypes(self: *const Prepared) []const f.Types.Type {
        return self.template.parameterTypes();
    }
    pub fn bind(self: *const Prepared, allocator: std.mem.Allocator, values: []const ?Atom, location: ?*f.Sql.Location) !Bound {
        var rows = try self.template.bind(allocator, self.template.name, self.template.schema.schema, values, location);
        errdefer rows.deinit();
        const partition: ?u32 = if (self.partition) |operand| std.math.cast(u32, try operand.number(values)) orelse return error.InvalidLogPartitioning else null;
        const producer: ?p.StreamQueue.Producer = if (self.producer) |input| .{ .id = (try input.id.bind(values)).uuid, .epoch = try input.epoch.number(values), .sequence = try input.sequence.number(values) } else null;
        if (producer) |value| try value.validate();
        const visible_ms: u64 = if (self.visible) |operand| value: {
            const micros = (try operand.bind(values)).timestamp;
            if (micros < 0 or @mod(micros, 1000) != 0) return error.InvalidLogVisibilityTime;
            break :value std.math.cast(u64, @divExact(micros, 1000)) orelse return error.InvalidLogVisibilityTime;
        } else 0;
        return .{ .rows = rows, .partition = partition, .producer = producer, .visible_ms = visible_ms };
    }
    /// Encode only after the owning adapter has chosen the exact native work.
    /// Returned fields borrow Prepared; bytes borrow the caller's output buffer.
    pub fn projection(self: *const Prepared, allocator: std.mem.Allocator, source: f.WorkloadProjection.Source, output: []u8) !?struct { fields: []const Field, bytes: []const u8 } {
        if (self.output == null) return null;
        if (!std.mem.eql(u8, &try self.template.schema.schema.fingerprint(), &try source.schema.fingerprint())) return error.TableSchemaChanged;
        switch (source.binding) {
            .stream => |binding| if (self.target.kind != .stream or binding.kind != .append) return error.InvalidWorkloadProjection,
            .queue => |binding| if (self.target.kind != .queue or binding.kind != .enqueue) return error.InvalidWorkloadProjection,
        }
        const layout = try f.WorkloadProjection.layout(source, self.return_fields);
        const plan: f.LogicalQuery.Plan = .{ .schema = layout.typeOf(), .source_basis = try f.WorkloadProjection.basis(allocator, source, self.return_fields), .projection = self.return_indices, .output_names = self.return_names, .collations = layout.collations };
        return .{ .fields = self.return_fields, .bytes = try f.WorkloadProjection.encode(source, self.return_fields, plan, allocator, output) };
    }
};
fn fieldName(schema: f.TableSchema.Schema, field: Field) []const u8 {
    return switch (field) {
        .column => |id| schema.columns[schema.index(id) catch unreachable].name,
        .partition => "_partition",
        .offset => "_offset",
        else => unreachable,
    };
}
pub const Bound = struct {
    rows: f.TableDml.Owned,
    partition: ?u32,
    producer: ?p.StreamQueue.Producer,
    visible_ms: u64,
    pub fn deinit(self: *Bound) void {
        self.rows.deinit();
        self.* = undefined;
    }
};

const test_columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 9, .name = "body", .type = .utf8, .nullable = true, .collation = .ascii_ci },
};
const test_schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 10, .columns = &test_columns, .primary_key = &.{} };

fn appendOwned(allocator: std.mem.Allocator) !void {
    var prepared = try Prepared.init(allocator, "PRODUCE INTO events (id, body) VALUES ($1, $2) PARTITION $3 PRODUCER ID $4 EPOCH $5 SEQUENCE $6 RETURNING events.id AS first_id, events.id AS again_id, _offset, _partition", test_schema, .transit, null);
    var live = true;
    defer if (live) prepared.deinit();
    try std.testing.expectEqual(@as(usize, 6), prepared.parameterTypes().len);
    try std.testing.expectEqual(f.Types.Type.uuid, prepared.parameterTypes()[3]);
    try std.testing.expectEqual(@as(usize, 3), prepared.return_fields.len);
    try std.testing.expectEqualSlices(u8, &.{ 0, 0, 1, 2 }, prepared.return_indices);
    var body = "original".*;
    var bound = try prepared.bind(allocator, &.{ .{ .signed = 42 }, .{ .bytes = &body }, .{ .unsigned = 3 }, .{ .uuid = @splat(17) }, .{ .unsigned = 1 }, .{ .unsigned = 2 } }, null);
    defer bound.deinit();
    try std.testing.expectEqual(@as(?u32, 3), bound.partition);
    try std.testing.expectEqual(@as(u64, 2), bound.producer.?.sequence);
    const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const source: f.WorkloadProjection.Source = .{ .binding = .{ .stream = .{
        .definition = p.Growth.current_definition,
        .operation = .{ .scope = scope, .principal = 1, .operation = 19 },
        .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(5) }, .partition = 3 },
        .kind = .append,
        .intent = @splat(6),
    } }, .schema = test_schema };
    var bytes: [f.LogicalPlanCodec.max_bytes]u8 = undefined;
    var incompatible = source;
    incompatible.binding.stream.kind = .consume;
    try std.testing.expectError(error.InvalidWorkloadProjection, prepared.projection(allocator, incompatible, &bytes));
    incompatible = source;
    incompatible.schema.revision += 1;
    try std.testing.expectError(error.TableSchemaChanged, prepared.projection(allocator, incompatible, &bytes));
    const encoded = (try prepared.projection(allocator, source, &bytes)).?;
    var restored = try f.WorkloadProjection.restore(allocator, source, encoded.fields, encoded.bytes);
    defer restored.deinit();
    var projector = try f.WorkloadProjection.Projector.init(allocator, source, encoded.fields, restored.plan);
    const row = (try projector.row(bound.rows.plan.action.insert[0], .{ .offset = 23 })).?;
    try std.testing.expectEqual(@as(i128, 42), row[0].value.atom.signed);
    try std.testing.expectEqual(@as(i128, 42), row[1].value.atom.signed);
    try std.testing.expectEqual(@as(u128, 23), row[2].value.atom.unsigned);
    try std.testing.expectEqual(@as(u128, 3), row[3].value.atom.unsigned);
    try std.testing.expectEqualStrings("again_id", restored.plan.output_names[1].?);
    prepared.deinit();
    live = false;
    @memset(&body, 0);
    try std.testing.expectEqualStrings("original", bound.rows.plan.action.insert[0][1].value.atom.bytes);
}

test "log append SQL owns typed row metadata parameters and frozen RETURNING" {
    try appendOwned(std.testing.allocator);
    try std.testing.checkAllAllocationFailures(std.testing.allocator, appendOwned, .{});
}

test "log append SQL bounds metadata and keeps dialect and statement boundaries" {
    const t = std.testing;
    var queue = try Prepared.init(t.allocator, "ENQUEUE INTO `tasks` (`id`) VALUES (?) WITH (visible_at = TIMESTAMP '1970-01-01T00:00:01.000Z') RETURNING *", test_schema, .mysql, null);
    defer queue.deinit();
    var bound = try queue.bind(t.allocator, &.{.{ .signed = 7 }}, null);
    defer bound.deinit();
    try t.expectEqual(Kind.queue, queue.target.kind);
    try t.expectEqual(@as(u64, 1000), bound.visible_ms);
    try t.expectEqual(@as(?u32, null), bound.partition);
    try t.expectEqual(@as(usize, 2), queue.output.?.type.structure.len);
    try t.expectEqual(f.Types.Values.Cell.null, bound.rows.plan.action.insert[0][1]);
    for ([_][]const u8{
        "INSERT INTO events (id) VALUES (1)",
        "PRODUCE INTO events (id) VALUES (1); DROP STREAM events",
        "PRODUCE INTO events (id) VALUES (1) WITH (visible_at = TIMESTAMP '1970-01-01T00:00:01Z')",
        "ENQUEUE INTO tasks (id) VALUES (1) WITH (unknown = 1)",
        "PRODUCE INTO events (id) VALUES (1) RETURNING COUNT(*)",
        "PRODUCE INTO events (id) VALUES (1) RETURNING id LIMIT 1",
    }) |sql| {
        if (Prepared.init(t.allocator, sql, test_schema, .transit, null)) |value| {
            var unexpected = value;
            unexpected.deinit();
            return error.ExpectedLogAppendRefusal;
        } else |_| {}
    }
    try t.expectError(error.ParameterTypeConflict, Prepared.init(t.allocator, "PRODUCE INTO events (id) VALUES ($1) PARTITION $1", test_schema, .transit, null));
    try t.expectError(error.ParameterGap, Prepared.init(t.allocator, "PRODUCE INTO events (id) VALUES ($1) PARTITION $3", test_schema, .transit, null));
    var partition = try Prepared.init(t.allocator, "PRODUCE INTO events (id) VALUES ($1) PARTITION $2", test_schema, .transit, null);
    defer partition.deinit();
    try t.expectError(error.NullWorkloadParameter, partition.bind(t.allocator, &.{ .{ .signed = 1 }, null }, null));
    try t.expectError(error.InvalidLogPartitioning, partition.bind(t.allocator, &.{ .{ .signed = 1 }, .{ .unsigned = @as(u64, std.math.maxInt(u32)) + 1 } }, null));
    var fractional = try Prepared.init(t.allocator, "ENQUEUE INTO tasks (id) VALUES (1) WITH (visible_at = TIMESTAMP '1970-01-01T00:00:00.000001Z')", test_schema, .transit, null);
    defer fractional.deinit();
    try t.expectError(error.InvalidLogVisibilityTime, fractional.bind(t.allocator, &.{}, null));
}

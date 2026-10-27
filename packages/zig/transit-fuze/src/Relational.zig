//! Pure finite relational admission and identity. Borrowed descriptors remain
//! immutable while used. This module acquires no source and executes no query.
const std = @import("std");
const table = @import("TableSchema.zig");
const types = @import("Types.zig");
pub const RowIdentity = @import("TableRow.zig").Identity;

pub const definition = "transit.fuze.relational.v1.2026-10-26";
pub const max_sources = 2;
pub const max_outputs = 128;
pub const max_groups = 128;
pub const max_instructions = 64;
pub const max_plan_bytes = 8192;

pub const Source = struct {
    alias: []const u8,
    realm: u64,
    resource: u64,
    catalog: u64,
    owner: u64,
    schema: table.Schema,
};
/// A column uses its stable schema identity, never its current ordinal/name.
pub const Column = struct {
    source: u8,
    id: table.ColumnId,
    pub fn eql(a: Column, b: Column) bool {
        return a.source == b.source and a.id == b.id;
    }
};
pub const Join = struct {
    kind: enum(u8) { inner, left },
    left: Column,
    right: Column,
};
pub const Expression = union(enum(u8)) {
    column: Column,
    count_all,
    count: Column,
    sum: Column,
};
pub const Output = struct { name: []const u8, expression: Expression };
pub const Comparison = enum(u8) { equal, not_equal, less, less_equal, greater, greater_equal };
pub const Instruction = union(enum(u8)) {
    compare: struct { column: Column, op: Comparison, value: @import("RelationalValues.zig").Literal },
    is_null: Column,
    is_not_null: Column,
    negate,
    conjunction,
    disjunction,
};
pub const Predicate = struct {
    /// Empty means true; otherwise an eager postfix program with one result.
    instructions: []const Instruction = &.{},
};
pub const Lifetime = enum(u8) { interactive, captured, maintained };
pub const Budgets = struct {
    resident_bytes: u64,
    spill_bytes: u64,
    result_bytes: u64,
    output_rows: u64,
    work_steps: u64,
    source_pins: u8,
};

pub const Plan = struct {
    sources: []const Source,
    join: ?Join = null,
    source_filters: [max_sources]Predicate = .{ .{}, .{} },
    /// Evaluated after the join, including null extension, before aggregation.
    filter: Predicate = .{},
    group_by: []const Column = &.{},
    outputs: []const Output,
    lifetime: Lifetime,
    budgets: Budgets,

    pub fn validate(self: Plan) !void {
        if (self.sources.len == 0 or self.sources.len > max_sources) return error.InvalidRelationalSources;
        if ((self.sources.len == 2) != (self.join != null)) return error.InvalidRelationalJoin;
        if (self.outputs.len == 0 or self.outputs.len > max_outputs) return error.InvalidRelationalOutputs;
        if (self.group_by.len > max_groups) return error.InvalidRelationalGroups;
        var resources: u8 = 0;
        for (self.sources, 0..) |source, i| {
            try name(source.alias);
            if (source.realm == 0 or source.resource == 0 or source.catalog == 0 or source.owner == 0) return error.InvalidRelationalSourceIdentity;
            try source.schema.validate();
            if (source.realm != self.sources[0].realm) return error.CrossRealmRelationalQuery;
            var seen_resource = false;
            for (self.sources[0..i]) |earlier| {
                if (std.mem.eql(u8, source.alias, earlier.alias)) return error.DuplicateRelationalAlias;
                if (source.resource == earlier.resource) {
                    seen_resource = true;
                    if (source.owner != earlier.owner) return error.RelationalSourceChanged;
                }
                if (source.resource == earlier.resource and source.catalog == earlier.catalog and source.schema.object == earlier.schema.object) {
                    if (!std.mem.eql(u8, &try source.schema.fingerprint(), &try earlier.schema.fingerprint())) return error.RelationalSourceChanged;
                }
            }
            if (!seen_resource) resources += 1;
        }
        for (self.source_filters[0..self.sources.len], 0..) |predicate, i| try self.validatePredicate(predicate, @intCast(i));
        for (self.source_filters[self.sources.len..]) |predicate| {
            if (predicate.instructions.len != 0) return error.InvalidRelationalSources;
        }
        if (self.join) |join| {
            if (join.left.source != 0 or join.right.source != 1) return error.InvalidRelationalJoin;
            const left = try self.resolveColumn(join.left);
            const right = try self.resolveColumn(join.right);
            if (std.meta.activeTag(left.type) != std.meta.activeTag(right.type) or left.collation != right.collation) return error.InvalidRelationalJoin;
        }
        try self.validatePredicate(self.filter, null);
        for (self.group_by, 0..) |column, i| {
            _ = try self.resolveColumn(column);
            for (self.group_by[0..i]) |earlier| if (column.eql(earlier)) return error.DuplicateRelationalGroup;
        }
        var aggregate = false;
        for (self.outputs) |output| if (output.expression != .column) {
            aggregate = true;
        };
        var output_name_bytes: usize = 0;
        for (self.outputs, 0..) |output, i| {
            try name(output.name);
            output_name_bytes += output.name.len;
            for (self.outputs[0..i]) |earlier| if (std.mem.eql(u8, output.name, earlier.name)) return error.DuplicateRelationalOutput;
            switch (output.expression) {
                .count_all => {},
                .column => |column| {
                    _ = try self.resolveColumn(column);
                    if (aggregate or self.group_by.len != 0) {
                        var grouped = false;
                        for (self.group_by) |key| if (key.eql(column)) {
                            grouped = true;
                        };
                        if (!grouped) return error.UngroupedRelationalColumn;
                    }
                },
                .count => |column| _ = try self.resolveColumn(column),
                .sum => |column| if ((try self.resolveColumn(column)).type != .int64) return error.UnsupportedRelationalType,
            }
        }
        const type_limits: types.Limits = .{};
        if (output_name_bytes > type_limits.name_bytes) return error.InvalidRelationalOutputs;
        const budgets = self.budgets;
        if (budgets.resident_bytes == 0 or budgets.result_bytes == 0 or budgets.work_steps == 0 or
            budgets.source_pins < resources or budgets.source_pins > max_sources) return error.InvalidRelationalBudgets;
        var scratch: [256]u8 = undefined;
        var size: std.Io.Writer.Discarding = .init(&scratch);
        try self.write(&size.writer);
        if (size.fullCount() > max_plan_bytes) return error.RelationalPlanTooLarge;
    }

    /// Checks the selected operator capability, independently of Table storage.
    pub fn resolveColumn(self: Plan, reference: Column) !table.Column {
        if (reference.source >= self.sources.len) return error.UnknownRelationalSource;
        const schema = self.sources[reference.source].schema;
        const result = schema.columns[try schema.index(reference.id)];
        if (result.type != .int64 and result.type != .utf8) return error.UnsupportedRelationalType;
        return result;
    }

    fn validatePredicate(self: Plan, predicate: Predicate, source: ?u8) !void {
        if (predicate.instructions.len > max_instructions) return error.InvalidRelationalPredicate;
        var depth: usize = 0;
        for (predicate.instructions) |instruction| {
            const reference: ?Column = switch (instruction) {
                .compare => |item| item.column,
                .is_null, .is_not_null => |item| item,
                else => null,
            };
            if (reference) |column| {
                const descriptor = try self.resolveColumn(column);
                if (instruction == .compare) try @import("RelationalValues.zig").validate(instruction.compare.value, descriptor);
                if (source) |index| if (column.source != index) return error.InvalidRelationalFilterScope;
                depth += 1;
            } else switch (instruction) {
                .negate => if (depth == 0) return error.InvalidRelationalPredicate,
                .conjunction, .disjunction => {
                    if (depth < 2) return error.InvalidRelationalPredicate;
                    depth -= 1;
                },
                else => unreachable,
            }
        }
        if (predicate.instructions.len != 0 and depth != 1) return error.InvalidRelationalPredicate;
    }

    /// Names, schema defaults/keys, routing, filters, budgets and lifetime all
    /// participate. Snapshot cuts belong to Bound, not this prepared identity.
    pub fn fingerprint(self: Plan) ![32]u8 {
        var bytes: [max_plan_bytes]u8 = undefined;
        return digest(try self.encodePrepared(&bytes));
    }

    /// Canonical identity preimage. Full schemas travel in RelationalCodec;
    /// these bytes bind their fingerprints without duplicating descriptors.
    pub fn encodePrepared(self: Plan, output: []u8) ![]const u8 {
        try self.validate();
        var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_plan_bytes)]);
        try self.write(&writer);
        return writer.buffered();
    }

    pub fn outputSchema(self: Plan, fields: []types.Field) !types.Type {
        try self.validate();
        if (fields.len < self.outputs.len) return error.RelationalOutputBufferTooSmall;
        for (self.outputs, 0..) |output, i| {
            const nullable = switch (output.expression) {
                .column => |reference| (try self.resolveColumn(reference)).nullable or
                    (reference.source == 1 and self.join != null and self.join.?.kind == .left),
                .sum => true,
                .count_all, .count => false,
            };
            fields[i] = .{
                .name = output.name,
                .type = switch (output.expression) {
                    .column => |reference| (try self.resolveColumn(reference)).type,
                    .sum => .int64,
                    .count_all, .count => .uint64,
                },
                .nullable = nullable,
            };
        }
        const result: types.Type = .{ .structure = fields[0..self.outputs.len] };
        try result.validate(.{});
        return result;
    }

    fn write(self: Plan, writer: *std.Io.Writer) !void {
        try writer.writeAll(definition ++ "\x00prepared\x00");
        try writer.writeByte(@intCast(self.sources.len));
        for (self.sources) |source| {
            try text(writer, source.alias);
            for ([_]u64{ source.realm, source.resource, source.catalog, source.owner }) |value| try writer.writeInt(u64, value, .little);
            try writer.writeAll(&try source.schema.fingerprint());
        }
        try writer.writeByte(if (self.join) |join| 1 + @backingInt(join.kind) else 0);
        if (self.join) |join| {
            try writeColumn(writer, join.left);
            try writeColumn(writer, join.right);
        }
        for (self.source_filters[0..self.sources.len]) |predicate| try writePredicate(writer, predicate);
        try writePredicate(writer, self.filter);
        try writer.writeByte(@intCast(self.group_by.len));
        for (self.group_by) |column| try writeColumn(writer, column);
        try writer.writeByte(@intCast(self.outputs.len));
        for (self.outputs) |output| {
            try text(writer, output.name);
            try writer.writeByte(@backingInt(std.meta.activeTag(output.expression)));
            switch (output.expression) {
                .count_all => {},
                inline else => |column| try writeColumn(writer, column),
            }
        }
        try writer.writeByte(@backingInt(self.lifetime));
        inline for (.{ "resident_bytes", "spill_bytes", "result_bytes", "output_rows", "work_steps" }) |field| {
            try writer.writeInt(u64, @field(self.budgets, field), .little);
        }
        try writer.writeByte(self.budgets.source_pins);
    }
};

/// Resolve normalized names against supplied schemas only. No lookup, name
/// folding, authorization or discovery of additional Tables is performed.
pub fn resolve(sources: []const Source, qualifier: ?[]const u8, column_name: []const u8) !Column {
    if (sources.len == 0 or sources.len > max_sources) return error.InvalidRelationalSources;
    try name(column_name);
    if (qualifier) |alias| try name(alias);
    var result: ?Column = null;
    var found_source = qualifier == null;
    for (sources, 0..) |source, i| {
        try name(source.alias);
        try source.schema.validate();
        for (sources[0..i]) |earlier| if (std.mem.eql(u8, source.alias, earlier.alias)) return error.DuplicateRelationalAlias;
        if (qualifier) |alias| if (!std.mem.eql(u8, alias, source.alias)) continue;
        found_source = true;
        for (source.schema.columns) |column| if (std.mem.eql(u8, column.name, column_name)) {
            if (result != null) return error.AmbiguousRelationalColumn;
            result = .{ .source = @intCast(i), .id = column.id };
        };
    }
    if (!found_source) return error.UnknownRelationalSource;
    return result orelse error.UnknownColumn;
}

/// Adapter-supplied evidence, in source/alias order. Finite lifetimes commit the
/// captured native resource root. The maintained lifetime commits the complete
/// required Table heads at its recorded native coordinate, resolved through
/// complete Table history. Neither evidence kind supplies authority or a lease.
pub const Cut = struct {
    /// Native KV resource revisions and direct Table partition frontiers are
    /// distinct atomic domains. This field is mandatory in persisted vectors.
    domain: union(enum) { native_resource, table_partition: struct { branch: u64, object: u64, partition: u64 } },
    resource: u64,
    revision: u64,
    commitment: [32]u8,
    schema: [32]u8,
};
pub const Bound = struct {
    plan: Plan,
    cuts: []const Cut,

    pub fn validate(self: Bound) !void {
        try self.plan.validate();
        if (self.cuts.len != self.plan.sources.len) return error.IncompleteRelationalBasis;
        var domains: usize = 0;
        for (self.cuts, self.plan.sources, 0..) |cut, source, i| {
            if (cut.resource != source.resource or
                !std.mem.eql(u8, &cut.schema, &try source.schema.fingerprint())) return error.RelationalSourceChanged;
            if (std.mem.allEqual(u8, &cut.commitment, 0)) return error.InvalidRelationalCut;
            if (cut.domain == .table_partition) {
                const target = cut.domain.table_partition;
                if (target.branch != 1 or target.object != source.schema.object or target.partition == 0 or cut.revision == 0) return error.InvalidRelationalCut;
            }
            var shared = false;
            for (self.cuts[0..i]) |earlier| if (cut.resource == earlier.resource) {
                if (std.meta.activeTag(cut.domain) != std.meta.activeTag(earlier.domain)) return error.InconsistentRelationalCut;
                if (cut.domain == .table_partition) {
                    const a = cut.domain.table_partition;
                    const b = earlier.domain.table_partition;
                    if ((a.partition == b.partition) != (a.branch == b.branch and a.object == b.object)) return error.InconsistentRelationalCut;
                    if (a.partition != b.partition) continue;
                }
                if (cut.revision != earlier.revision or !std.mem.eql(u8, &cut.commitment, &earlier.commitment)) return error.InconsistentRelationalCut;
                shared = true;
            };
            if (!shared) domains += 1;
        }
        if (domains > self.plan.budgets.source_pins) return error.InvalidRelationalBudgets;
    }

    pub fn fingerprint(self: Bound) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update(definition ++ "\x00bound\x00");
        hash.update(&try self.plan.fingerprint());
        for (self.cuts) |cut| {
            hash.update(&.{if (cut.domain == .native_resource) 0 else 1});
            if (cut.domain == .table_partition) {
                const target = cut.domain.table_partition;
                inline for (.{ target.branch, target.object, target.partition }) |id| {
                    var value: [8]u8 = undefined;
                    std.mem.writeInt(u64, &value, id, .little);
                    hash.update(&value);
                }
            }
            var coordinates: [16]u8 = undefined;
            std.mem.writeInt(u64, coordinates[0..8], cut.resource, .little);
            std.mem.writeInt(u64, coordinates[8..16], cut.revision, .little);
            hash.update(&coordinates);
            hash.update(&cut.commitment);
            hash.update(&cut.schema);
        }
        return hash.finalResult();
    }
};

/// These distinct rules prevent NULL equality for joins leaking into grouping.
pub fn joinMatches(left: @import("RelationalValues.zig").Value, right: @import("RelationalValues.zig").Value, descriptor: table.Column) !bool {
    return left != null and right != null and try groupOrder(left, right, descriptor) == .eq;
}
pub fn groupOrder(left: @import("RelationalValues.zig").Value, right: @import("RelationalValues.zig").Value, descriptor: table.Column) !std.math.Order {
    return @import("RelationalValues.zig").order(left, right, descriptor);
}
/// One aggregate's provisional state. Caller supplies canonical contributors;
/// discard a failed candidate. Group storage and publication are host concerns.
pub const AggregateState = struct {
    rows: u64 = 0,
    values: u64 = 0,
    sum: ?i64 = null,
    pub fn observe(self: *AggregateState, kind: enum { count_all, count, sum }, value: ?i64) !void {
        var next = self.*;
        next.rows = try std.math.add(u64, next.rows, 1);
        if (value != null) next.values = try std.math.add(u64, next.values, 1);
        if (kind == .sum) if (value) |integer| {
            next.sum = try std.math.add(i64, next.sum orelse 0, integer);
        };
        self.* = next;
    }
};

fn name(value: []const u8) !void {
    if (value.len == 0 or value.len > 255 or !std.unicode.utf8ValidateSlice(value) or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidRelationalName;
}
fn text(writer: *std.Io.Writer, value: []const u8) !void {
    try writer.writeByte(@intCast(value.len));
    try writer.writeAll(value);
}
fn writeColumn(writer: *std.Io.Writer, column: Column) !void {
    try writer.writeByte(column.source);
    try writer.writeInt(u64, column.id, .little);
}
fn writePredicate(writer: *std.Io.Writer, predicate: Predicate) !void {
    try writer.writeByte(@intCast(predicate.instructions.len));
    for (predicate.instructions) |instruction| {
        try writer.writeByte(@backingInt(std.meta.activeTag(instruction)));
        switch (instruction) {
            .compare => |item| {
                try writeColumn(writer, item.column);
                try writer.writeByte(@backingInt(item.op));
                try @import("RelationalValues.zig").write(writer, item.value);
            },
            .is_null, .is_not_null => |column| try writeColumn(writer, column),
            else => {},
        }
    }
}
fn digest(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}

test {
    _ = @import("relational_test.zig");
}

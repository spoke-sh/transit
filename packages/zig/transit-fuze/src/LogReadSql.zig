//! Shared typed text operands and row layouts for workload SQL preparation.
//! These helpers acquire no input and grant no workload authority.
const std = @import("std");
const f = @import("root.zig");
const Parser = f.SqlTyped;
const Reference = @import("SqlReference.zig");
const Field = f.WorkloadProjection.Field;
const Atom = f.Types.Values.Atom;

pub const Operand = union(enum) {
    literal: struct { bytes: []const u8, offset: usize },
    parameter: f.Sql.Parameter,
    pub fn parse(parser: *Parser, parameters: *std.ArrayList(f.LogicalPrepared.Parameter), comptime invalid: anyerror) !Operand {
        if (try parser.parameter()) |site| {
            try parameters.append(parser.allocator, .{ .site = site, .type = .utf8 });
            return .{ .parameter = site };
        }
        const literal = try parser.literal(.utf8);
        var failure: ?Parser.Literal.Span = null;
        const cell = literal.bind(parser.allocator, .utf8, &failure) catch |err| {
            if (parser.location) |location| location.* = .{ .offset = (failure orelse literal.span).start };
            return err;
        };
        if (cell != .value or cell.value != .atom or cell.value.atom != .bytes) {
            if (parser.location) |location| location.* = .{ .offset = literal.span.start };
            return invalid;
        }
        return .{ .literal = .{ .bytes = cell.value.atom.bytes, .offset = literal.span.start } };
    }
    pub fn bind(self: Operand, values: []const ?Atom) ![]const u8 {
        return switch (self) {
            .literal => |value| value.bytes,
            .parameter => |site| (values[site.index - 1] orelse return error.NullWorkloadParameter).bytes,
        };
    }
    pub fn at(self: Operand, diagnostic: ?*f.Sql.Binding) void {
        const detail = diagnostic orelse return;
        switch (self) {
            .literal => |value| detail.location = .{ .offset = value.offset },
            .parameter => |site| {
                detail.location = .{ .offset = site.offset };
                detail.parameter = site.index;
                detail.parameter_sites[0] = site.offset;
                detail.expected = "utf8";
            },
        }
    }
};
pub fn field(schema: f.TableSchema.Schema, qualifier: []const u8, reference: Reference, location: ?*f.Sql.Location) !Field {
    if (reference.qualifier == null) {
        if (std.mem.eql(u8, reference.name, "_partition")) return .partition;
        if (std.mem.eql(u8, reference.name, "_offset")) return .offset;
    }
    return .{ .column = schema.columns[try reference.resolve(qualifier, schema.columns, location)].id };
}
pub fn add(fields: *std.ArrayList(Field), allocator: std.mem.Allocator, value: Field) !void {
    for (fields.items) |existing| if (std.meta.eql(existing, value)) return;
    if (fields.items.len == f.TableSchema.max_columns) return error.InvalidProjection;
    try fields.append(allocator, value);
}
pub fn waitDuration(value: []const u8) !u32 {
    return duration(u32, value, error.InvalidLogWait);
}
pub fn leaseDuration(value: []const u8) !u64 {
    return duration(u64, value, error.InvalidLogLeaseDuration);
}
fn duration(comptime Int: type, value: []const u8, comptime invalid: anyerror) !Int {
    var end: usize = 0;
    while (end < value.len and std.ascii.isDigit(value[end])) : (end += 1) {}
    const multiplier = f.PerfectHash.ComptimeMap(u64, true, .{ .{ "ms", 1 }, .{ "s", 1000 }, .{ "m", 60000 } }).get(value[end..]) orelse return invalid;
    const number = std.fmt.parseInt(u64, value[0..end], 10) catch return invalid;
    if (number == 0) return invalid;
    return std.math.cast(Int, std.math.mul(u64, number, multiplier) catch return invalid) orelse invalid;
}

pub const Profile = enum { stream, queue };
fn resolve(schema: f.TableSchema.Schema, qualifier: []const u8, reference: Reference, location: ?*f.Sql.Location, profile: Profile) !Field {
    if (profile == .queue and reference.qualifier == null) {
        if (std.mem.eql(u8, reference.name, "_lease_epoch")) return .lease_epoch;
        if (std.mem.eql(u8, reference.name, "_attempt")) return .attempt;
        if (std.mem.eql(u8, reference.name, "_receipt_handle")) return .receipt_handle;
    }
    return field(schema, qualifier, reference, location);
}

/// Allocate into the caller's syntax arena. Expand application stars before
/// adding predicate-only inputs. Acquisition
/// predicates cannot depend on lease metadata produced by that acquisition.
pub fn input(allocator: std.mem.Allocator, schema: f.TableSchema.Schema, syntax: *f.TableSelect.Syntax, location: ?*f.Sql.Location, profile: Profile) ![]const Field {
    var fields: std.ArrayList(Field) = .empty;
    if (syntax.selection.star) {
        syntax.selection.star = false;
        syntax.selection.count = schema.columns.len;
        for (schema.columns, 0..) |column, i| {
            try add(&fields, allocator, .{ .column = column.id });
            syntax.selection.items[i] = .{ .column = .{
                .name = try allocator.dupe(u8, column.name),
                .span = syntax.subject.span,
                .qualifier = syntax.qualifier,
            }, .alias = null };
        }
    } else for (syntax.selection.items[0..syntax.selection.count]) |item| try add(&fields, allocator, try resolve(schema, syntax.qualifier, item.column, location, profile));
    if (syntax.predicate) |predicate| for (predicate.instructions) |instruction| {
        if (instruction == .atom) switch (instruction.atom) {
            inline else => |atom| {
                const selected = try resolve(schema, syntax.qualifier, atom.column, location, profile);
                if (selected == .lease_epoch or selected == .attempt or selected == .receipt_handle) return error.InvalidLogClaimPredicate;
                try add(&fields, allocator, selected);
            },
        };
    };
    return fields.items;
}

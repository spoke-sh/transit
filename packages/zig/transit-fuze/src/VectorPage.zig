//! Validated source-page adapters; codecs stay outside the pure column kernels.
const std = @import("std");
const t = @import("Types.zig");
const q = @import("LogicalQuery.zig");
const m = @import("Unified.zig");
const finite = @import("Finite.zig");
const k = @import("VectorKernel.zig");
pub const Outcome = k.Outcome;
const Atom = k.Atom;
const Instruction = k.Instruction;
const Program = k.Program;
const View = k.View;
const scalar = k.scalar;

/// A validation page remains its original boundary. Borrowing its rows avoids
/// copying variable values or reserving a large compute arena for eight lanes.
pub fn logicalPage(plan: q.Plan, rows: []const @import("LogicalArrow.zig").Row, output: []Outcome, sites: []u8) void {
    std.debug.assert(rows.len == output.len and rows.len <= 8);
    switch (plan.predicate) {
        .all => @memset(output, .{ .truth = .true_value }),
        .program => logicalProgram(plan, rows, output, sites),
        inline else => |value, tag| {
            const atom = Atom.bind(@unionInit(q.Plan.Atom, @tagName(tag), value), plan.schema);
            atom.run(atom, .{ .logical = .{ .rows = rows, .column = atom.column } }, 0, output);
            @memset(sites, 0);
        },
    }
}
fn logicalProgram(plan: q.Plan, rows: []const @import("LogicalArrow.zig").Row, output: []Outcome, sites: []u8) void {
    var instructions: [q.Program.max_instructions]Instruction = undefined;
    const bound = Program.bind(plan, &instructions);
    var columns: [128]View = undefined;
    for (columns[0..plan.schema.structure.len], 0..) |*column, i| column.* = .{ .logical = .{ .rows = rows, .column = @intCast(i) } };
    var scratch: [8 * q.Program.max_instructions]finite.Truth = undefined;
    var temporary: [8]Outcome = undefined;
    bound.evaluate(columns[0..plan.schema.structure.len], 0, output, sites, &scratch, &temporary);
}
pub fn logicalSite(plan: q.Plan, instruction: u8) q.Plan.PredicateFailure {
    const column = switch (plan.predicate) {
        .program => |program| switch (program.instructions[instruction].atom) {
            .compare => |v| v.column,
            .state => |v| v.column,
            .all => unreachable,
        },
        .compare => |v| v.column,
        .state => |v| v.column,
        .all => unreachable,
    };
    return .{ .column = column, .instruction = instruction };
}
fn nativeAtom(atom: m.Plan.Atom) q.Plan.Atom {
    return switch (atom) {
        .all => .all,
        .state => |v| .{ .state = .{ .column = v.column, .value = @fromBackingInt(@intCast(@backingInt(v.value))) } },
        .compare => |v| .{ .compare = .{ .column = v.column, .op = v.op, .value = scalar(v.value) } },
    };
}
fn bindNative(atom: m.Plan.Atom, schema: m.Schema) Atom {
    return Atom.bindType(nativeAtom(atom), if (atom == .compare) t.Type.fromQuery(schema.columns[atom.compare.column].type) else .int64);
}
pub fn unifiedPage(bound: *const m.Plan.Bound, rows: []const m.Row, output: []Outcome, sites: []u8) void {
    std.debug.assert(rows.len == output.len and rows.len <= m.max_rows);
    switch (bound.plan.predicate) {
        .all => @memset(output, .{ .truth = .true_value }),
        .program => nativeProgram(bound, rows, output, sites),
        inline else => |value, tag| {
            const atom = bindNative(@unionInit(m.Plan.Atom, @tagName(tag), value), bound.schema);
            atom.run(atom, .{ .unified = .{ .rows = rows, .column = atom.column } }, 0, output);
            @memset(sites, 0);
        },
    }
}
fn nativeProgram(bound: *const m.Plan.Bound, rows: []const m.Row, output: []Outcome, sites: []u8) void {
    const program = &bound.plan.predicate.program;
    var instructions: [q.Program.max_instructions]Instruction = undefined;
    var depth: usize = 0;
    var maximum: usize = 0;
    for (program.instructions[0..program.count], instructions[0..program.count]) |in, *out| switch (in) {
        .atom => |atom| {
            out.* = .{ .atom = bindNative(atom, bound.schema) };
            depth += 1;
            maximum = @max(maximum, depth);
        },
        .negate => out.* = .negate,
        .conjunction, .disjunction => |_, tag| {
            out.* = if (tag == .conjunction) .conjunction else .disjunction;
            depth -= 1;
        },
    };
    const compiled: Program = .{ .instructions = instructions[0..program.count], .depth = maximum };
    var columns: [m.max_columns]View = undefined;
    for (columns[0..bound.schema.columns.len], 0..) |*column, i| column.* = .{ .unified = .{ .rows = rows, .column = @intCast(i) } };
    var scratch: [m.max_rows * q.Program.max_instructions]finite.Truth = undefined;
    var temporary: [m.max_rows]Outcome = undefined;
    compiled.evaluate(columns[0..bound.schema.columns.len], 0, output, sites, &scratch, &temporary);
}
pub fn nativeSite(plan: *const m.Plan, instruction: u8) q.Plan.PredicateFailure {
    const column = switch (plan.predicate) {
        .program => |*program| switch (program.instructions[instruction].atom) {
            .compare => |v| v.column,
            .state => |v| v.column,
            .all => unreachable,
        },
        .compare => |v| v.column,
        .state => |v| v.column,
        .all => unreachable,
    };
    return .{ .column = column, .instruction = instruction };
}

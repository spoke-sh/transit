//! Bound column operators. Inputs borrow validated source/physical buffers;
//! outcomes retain lane order and never publish progress or acquire authority.
const std = @import("std");
const t = @import("Types.zig");
const q = @import("LogicalQuery.zig");
const finite = @import("Finite.zig");
const m = @import("Unified.zig");
pub const cpu = @import("VectorCpu.zig");
pub const Outcome = union(enum) { truth: finite.Truth, type_error, conflict };
pub const Detail = union(enum) { none, type_error: t.Kind, conflict: []const t.Values.Alternative };
pub const Storage = union(enum) { words: []u64, values: []t.Values.Value, states_only };
pub const Column = struct {
    type: t.Type,
    data: Storage,
    states: []t.State,
    details: []Detail,
    pub fn view(self: Column, len: usize) View {
        return .{ .flat = .{ .type = self.type, .data = switch (self.data) {
            .words => |v| .{ .words = v },
            .values => |v| .{ .values = v },
            .states_only => .states_only,
        }, .states = self.states[0..len], .details = self.details[0..len] } };
    }
    pub fn rowBytes(kind: t.Type, retain: bool) usize {
        return @sizeOf(t.State) + @sizeOf(Detail) + if (!retain) @as(usize, 0) else if (hot(kind)) @as(usize, 8) else @sizeOf(t.Values.Value);
    }
    pub fn init(a: std.mem.Allocator, kind: t.Type, capacity: usize, retain: bool) !Column {
        return .{ .type = kind, .data = if (!retain) .states_only else if (hot(kind)) .{ .words = try a.alloc(u64, capacity) } else .{ .values = try a.alloc(t.Values.Value, capacity) }, .states = try a.alloc(t.State, capacity), .details = try a.alloc(Detail, capacity) };
    }
    pub fn append(self: Column, a: std.mem.Allocator, i: usize, cell: t.Values.Cell) !void {
        if (self.data == .states_only) {
            self.states[i] = std.meta.activeTag(cell);
            self.details[i] = .none;
            return;
        }
        const owned = if (self.data == .words and cell != .conflict) cell else try t.Values.cloneValidated(a, cell);
        self.states[i] = std.meta.activeTag(owned);
        self.details[i] = switch (owned) {
            .conflict => |alternatives| .{ .conflict = alternatives },
            .type_error => |kind| .{ .type_error = kind },
            else => .none,
        };
        switch (self.data) {
            .words => |words| words[i] = if (owned != .value) 0 else switch (self.type) {
                .int64 => @bitCast(@as(i64, @intCast(owned.value.atom.signed))),
                .uint64 => @intCast(owned.value.atom.unsigned),
                .float64 => @bitCast(owned.value.atom.float),
                .boolean => @intFromBool(owned.value.atom.boolean),
                else => unreachable,
            },
            .values => |values| values[i] = if (owned == .value) owned.value else .{ .atom = .{ .signed = 0 } },
            .states_only => unreachable,
        }
    }
};
pub fn hot(kind: t.Type) bool {
    return switch (kind) {
        .int64, .uint64, .float64, .boolean => true,
        else => false,
    };
}
pub const View = union(enum) {
    flat: struct { type: t.Type, data: union(enum) { words: []const u64, values: []const t.Values.Value, states_only }, states: []const t.State, details: []const Detail },
    constant: struct { value: t.Values.Cell, len: usize },
    logical: struct { rows: []const @import("LogicalArrow.zig").Row, column: u8 },
    unified: struct { rows: []const m.Row, column: u8 },
    pub fn len(self: View) usize {
        return switch (self) {
            .flat => |v| v.states.len,
            .constant => |v| v.len,
            .logical => |v| v.rows.len,
            .unified => |v| v.rows.len,
        };
    }
    pub fn state(self: View, i: usize) t.State {
        return switch (self) {
            .flat => |v| v.states[i],
            .constant => |v| std.meta.activeTag(v.value),
            .logical => |v| std.meta.activeTag(v.rows[i].cells[v.column]),
            .unified => |v| @fromBackingInt(@intCast(@backingInt(std.meta.activeTag(v.rows[i].cells[v.column])))),
        };
    }
    pub fn atom(self: View, i: usize) t.Values.Atom {
        std.debug.assert(self.state(i) == .value);
        return switch (self) {
            .flat => |v| switch (v.data) {
                .states_only => unreachable,
                .values => |values| values[i].atom,
                .words => |words| switch (v.type) {
                    .int64 => .{ .signed = @as(i64, @bitCast(words[i])) },
                    .uint64 => .{ .unsigned = words[i] },
                    .float64 => .{ .float = @bitCast(words[i]) },
                    .boolean => .{ .boolean = words[i] != 0 },
                    else => unreachable,
                },
            },
            .constant => |v| v.value.value.atom,
            .logical => |v| v.rows[i].cells[v.column].value.atom,
            .unified => |v| scalar(v.rows[i].cells[v.column].value),
        };
    }
    pub fn cell(self: View, i: usize) t.Values.Cell {
        return switch (self) {
            .constant => |v| v.value,
            .logical => |v| v.rows[i].cells[v.column],
            .unified => unreachable, // Predicate view only; native cells keep their own owner.
            .flat => |v| switch (v.states[i]) {
                .missing => .missing,
                .null => .null,
                .type_error => .{ .type_error = v.details[i].type_error },
                .conflict => .{ .conflict = v.details[i].conflict },
                .value => .{ .value = switch (v.data) {
                    .values => |values| values[i],
                    .words => .{ .atom = self.atom(i) },
                    .states_only => unreachable,
                } },
            },
        };
    }
};
pub fn scalar(value: m.Scalar) t.Values.Atom {
    return switch (value) {
        .int64 => |v| .{ .signed = v },
        .uint64 => |v| .{ .unsigned = v },
        .float64 => |v| .{ .float = v },
        .boolean => |v| .{ .boolean = v },
        .utf8, .binary => |v| .{ .bytes = v },
    };
}
pub const Atom = struct {
    column: u8,
    literal: t.Values.Atom = .{ .signed = 0 },
    kind: t.Type = .int64,
    state: t.State = .value,
    uses_values: bool = false,
    implementation: cpu.Implementation = .portable,
    run: *const fn (Atom, View, usize, []Outcome) void,
    pub fn bind(atom: q.Plan.Atom, schema: t.Type) Atom {
        return bindType(atom, if (atom == .compare) schema.structure[atom.compare.column].type else .int64);
    }
    pub fn bindType(atom: q.Plan.Atom, kind: t.Type) Atom {
        return switch (atom) {
            .all => .{ .column = 0, .run = all },
            .state => |v| .{ .column = v.column, .state = v.value, .run = states },
            .compare => |v| .{ .column = v.column, .literal = v.value, .kind = kind, .uses_values = true, .run = switch (v.op) {
                inline else => |op| switch (kind) {
                    .int64 => &Compare(i64, op).run,
                    .uint64 => &Compare(u64, op).run,
                    .float64 => &Compare(f64, op).run,
                    .boolean => &Compare(u8, op).run,
                    else => &Compare(void, op).run,
                },
            } },
        };
    }
    pub fn all(_: Atom, _: View, _: usize, output: []Outcome) void {
        @memset(output, .{ .truth = .true_value });
    }
    pub fn states(self: Atom, column: View, start: usize, output: []Outcome) void {
        for (output, start..) |*out, i| out.* = .{ .truth = finite.Truth.fromBool(column.state(i) == self.state) };
    }
};

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
fn number(comptime T: type, atom: t.Values.Atom) T {
    return switch (T) {
        i64 => @intCast(atom.signed),
        u64 => @intCast(atom.unsigned),
        f64 => atom.float,
        u8 => @intFromBool(atom.boolean),
        else => unreachable,
    };
}
fn Compare(comptime T: type, comptime op: finite.Comparison) type {
    return struct {
        fn run(self: Atom, column: View, start: usize, output: []Outcome) void {
            const literal = if (T != void) number(T, self.literal) else {};
            if (T != void and column == .flat and column.flat.data == .words) {
                const words = column.flat.data.words[start..][0..output.len];
                const states = column.flat.states[start..][0..output.len];
                if (self.implementation == .avx2 and output.len >= 16) {
                    // Reuse the result buffer for byte masks. Expand backwards
                    // so a tagged outcome never overwrites an unread mask.
                    const masks = std.mem.sliceAsBytes(output)[0..output.len];
                    cpu.compare(words, if (T == u8) @as(u64, literal) else @bitCast(literal), if (T == i64) 0 else if (T == f64) 2 else 1, @backingInt(op), masks);
                    var remaining = output.len;
                    while (remaining != 0) {
                        remaining -= 1;
                        const selected = masks[remaining] != 0;
                        output[remaining] = stateOutcome(states[remaining], selected);
                    }
                    return;
                }
                for (output, words, states) |*out, word, state| {
                    const value: T = if (T == u8) @intCast(word) else @bitCast(word);
                    out.* = stateOutcome(state, relation(op, value, literal));
                }
                return;
            }
            for (output, start..) |*out, i| {
                out.* = switch (column.state(i)) {
                    .null, .missing => .{ .truth = .unknown },
                    .type_error => .type_error,
                    .conflict => .conflict,
                    .value => value: {
                        const order = if (T == void) t.Values.atomOrder(column.atom(i), self.literal, self.kind) catch unreachable else std.math.order(number(T, column.atom(i)), literal);
                        break :value .{ .truth = finite.Truth.fromBool(switch (op) {
                            .eq => order == .eq,
                            .ne => order != .eq,
                            .lt => order == .lt,
                            .le => order != .gt,
                            .gt => order == .gt,
                            .ge => order != .lt,
                        }) };
                    },
                };
            }
        }
    };
}
fn relation(comptime op: finite.Comparison, value: anytype, literal: @TypeOf(value)) bool {
    return switch (op) {
        .eq => value == literal,
        .ne => value != literal,
        .lt => value < literal,
        .le => value <= literal,
        .gt => value > literal,
        .ge => value >= literal,
    };
}
fn stateOutcome(state: t.State, selected: bool) Outcome {
    return switch (state) {
        .null, .missing => .{ .truth = .unknown },
        .type_error => .type_error,
        .conflict => .conflict,
        .value => .{ .truth = finite.Truth.fromBool(selected) },
    };
}
pub const Instruction = union(enum) { atom: Atom, negate, conjunction, disjunction };
pub const Program = struct {
    instructions: []const Instruction,
    depth: usize,
    /// Admission has validated the immutable logical plan. Destination remains
    /// owned by the caller and must outlive every evaluation.
    pub fn bind(plan: q.Plan, destination: []Instruction) Program {
        if (plan.predicate != .program) {
            const atom: q.Plan.Atom = switch (plan.predicate) {
                .program => unreachable,
                inline else => |v, tag| @unionInit(q.Plan.Atom, @tagName(tag), v),
            };
            destination[0] = .{ .atom = Atom.bind(atom, plan.schema) };
            return .{ .instructions = destination[0..1], .depth = 1 };
        }
        var depth: usize = 0;
        var maximum: usize = 0;
        for (plan.predicate.program.instructions, destination[0..plan.predicate.program.instructions.len]) |instruction, *out| switch (instruction) {
            .atom => |atom| {
                out.* = .{ .atom = Atom.bind(atom, plan.schema) };
                depth += 1;
                maximum = @max(maximum, depth);
            },
            .negate => out.* = .negate,
            .conjunction, .disjunction => |_, tag| {
                out.* = if (tag == .conjunction) .conjunction else .disjunction;
                depth -= 1;
            },
        };
        return .{ .instructions = destination[0..plan.predicate.program.instructions.len], .depth = maximum };
    }
    /// Eager instruction-major evaluation. Each lane retains its first error;
    /// only the source-ordered consumer chooses which failure is observable.
    pub fn evaluate(self: Program, columns: []const View, start: usize, output: []Outcome, sites: []u8, scratch: []finite.Truth, temporary: []Outcome) void {
        const n = output.len;
        std.debug.assert(sites.len >= n and temporary.len >= n and scratch.len >= n * self.depth);
        @memset(output, .{ .truth = .unknown });
        var depth: usize = 0;
        for (self.instructions, 0..) |instruction, index| switch (instruction) {
            .atom => |atom| {
                atom.run(atom, columns[atom.column], start, temporary[0..n]);
                for (temporary[0..n], output, 0..) |value, *out, row| {
                    scratch[depth * n + row] = if (value == .truth) value.truth else .unknown;
                    if (value != .truth and out.* == .truth) {
                        out.* = value;
                        sites[row] = @intCast(index);
                    }
                }
                depth += 1;
            },
            .negate => for (scratch[(depth - 1) * n .. depth * n]) |*truth| {
                truth.* = truth.negate();
            },
            .conjunction, .disjunction => |_, tag| {
                depth -= 1;
                for (scratch[(depth - 1) * n .. depth * n], scratch[depth * n .. (depth + 1) * n]) |*left, right| left.* = if (tag == .conjunction) left.conjunction(right) else left.disjunction(right);
            },
        };
        for (output, scratch[0..n]) |*out, truth| if (out.* == .truth) {
            out.* = .{ .truth = truth };
        };
    }
};

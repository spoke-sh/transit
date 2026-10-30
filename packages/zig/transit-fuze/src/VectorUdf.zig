//! Deterministic, resource-bounded scalar and table User-Defined Functions
//! (`SqlMacro` compile-time/plan-inlined macros and sandboxed in-engine
//! vectorized `WasmVectorSandbox` kernels) executing directly over `Fuze`
//! column batches without round-tripping through `128 KiB` `Station` actor
//! mailboxes (`D5`, `P3`).
const std = @import("std");
const Types = @import("Types.zig");
const v = Types.Values;
const OperatorTraits = @import("OperatorTraits.zig");

pub const definition = "transit.fuze.vector-udf.v1.2026-10-30";
pub const max_udf_params: usize = 8;
pub const max_wasm_instructions: usize = 256;
pub const default_max_fuel_per_row: u32 = 256;
pub const default_max_memory_bytes: usize = 64 * 1024;

pub const UdfRuntime = enum(u8) {
    sql_macro = 1,
    wasm_vector_v1 = 2,
};

pub const UdfKind = enum(u8) {
    scalar = 1,
    table = 2,
};

pub const OnTrapPolicy = enum(u8) {
    emit_type_error_cell = 1,
    abort_statement = 2,
};

pub const AmbientImportKind = enum(u8) {
    none = 0,
    wasi_preview1 = 1,
    system_clock = 2,
    entropy_random = 3,
    network_socket = 4,
    filesystem_io = 5,
    station_actor_send = 6,
};

/// Algebraic expression tree for hygiene-checked SQL scalar macros.
pub const MacroExpr = union(enum) {
    param: u8,
    literal_int64: i64,
    literal_utf8: []const u8,
    add_checked: struct { left: *const MacroExpr, right: *const MacroExpr },
    sub_checked: struct { left: *const MacroExpr, right: *const MacroExpr },
    mul_checked: struct { left: *const MacroExpr, right: *const MacroExpr },
    div_checked: struct { left: *const MacroExpr, right: *const MacroExpr },
    coalesce: struct { primary: *const MacroExpr, fallback: *const MacroExpr },
    clamp_int64: struct { value: *const MacroExpr, min_val: i64, max_val: i64 },

    pub fn validate(self: MacroExpr, param_count: u8) !void {
        switch (self) {
            .param => |idx| if (idx >= param_count) return error.InvalidMacroParameterIndex,
            .literal_int64, .literal_utf8 => {},
            .add_checked => |b| {
                try b.left.validate(param_count);
                try b.right.validate(param_count);
            },
            .sub_checked => |b| {
                try b.left.validate(param_count);
                try b.right.validate(param_count);
            },
            .mul_checked => |b| {
                try b.left.validate(param_count);
                try b.right.validate(param_count);
            },
            .div_checked => |b| {
                try b.left.validate(param_count);
                try b.right.validate(param_count);
            },
            .coalesce => |c| {
                try c.primary.validate(param_count);
                try c.fallback.validate(param_count);
            },
            .clamp_int64 => |cl| {
                if (cl.min_val > cl.max_val) return error.InvalidMacroClampBounds;
                try cl.value.validate(param_count);
            },
        }
    }

    pub fn evaluateRow(self: MacroExpr, args: []const v.Cell) v.Cell {
        switch (self) {
            .param => |idx| return if (idx < args.len) args[idx] else .{ .missing = {} },
            .literal_int64 => |n| return .{ .value = .{ .atom = .{ .signed = n } } },
            .literal_utf8 => |s| return .{ .value = .{ .atom = .{ .bytes = s } } },
            .coalesce => |c| {
                const p = c.primary.evaluateRow(args);
                return switch (p) {
                    .null => c.fallback.evaluateRow(args),
                    else => p,
                };
            },
            .clamp_int64 => |cl| {
                const inner = cl.value.evaluateRow(args);
                return switch (inner) {
                    .null, .missing, .type_error, .conflict => inner,
                    .value => |val| switch (val) {
                        .atom => |atom| switch (atom) {
                            .signed => |s_val| blk: {
                                const n = std.math.cast(i64, s_val) orelse break :blk .{ .type_error = .int64 };
                                break :blk .{ .value = .{ .atom = .{ .signed = @min(@max(n, cl.min_val), cl.max_val) } } };
                            },
                            else => .{ .type_error = .unknown },
                        },
                        else => .{ .type_error = .unknown },
                    },
                };
            },
            .add_checked, .sub_checked, .mul_checked, .div_checked => {
                const lhs_ptr = switch (self) {
                    .add_checked => |b| b.left,
                    .sub_checked => |b| b.left,
                    .mul_checked => |b| b.left,
                    .div_checked => |b| b.left,
                    else => unreachable,
                };
                const rhs_ptr = switch (self) {
                    .add_checked => |b| b.right,
                    .sub_checked => |b| b.right,
                    .mul_checked => |b| b.right,
                    .div_checked => |b| b.right,
                    else => unreachable,
                };
                const l_cell = lhs_ptr.evaluateRow(args);
                const r_cell = rhs_ptr.evaluateRow(args);
                // Ordered 5-state propagation: conflict/type_error/missing dominate null
                inline for ([_]v.Cell{ l_cell, r_cell }) |side| {
                    switch (side) {
                        .conflict, .type_error, .missing => return side,
                        else => {},
                    }
                }
                if (l_cell == .null or r_cell == .null) return .{ .null = {} };
                if (l_cell.value != .atom or r_cell.value != .atom) return .{ .type_error = .unknown };
                const lv: i64 = switch (l_cell.value.atom) {
                    .signed => |s_val| std.math.cast(i64, s_val) orelse return .{ .type_error = .int64 },
                    else => return .{ .type_error = .unknown },
                };
                const rv: i64 = switch (r_cell.value.atom) {
                    .signed => |s_val| std.math.cast(i64, s_val) orelse return .{ .type_error = .int64 },
                    else => return .{ .type_error = .unknown },
                };
                const res: i64 = switch (self) {
                    .add_checked => std.math.add(i64, lv, rv) catch
                        return .{ .type_error = .int64 },
                    .sub_checked => std.math.sub(i64, lv, rv) catch
                        return .{ .type_error = .int64 },
                    .mul_checked => std.math.mul(i64, lv, rv) catch
                        return .{ .type_error = .int64 },
                    .div_checked => blk: {
                        if (rv == 0) return .{ .type_error = .int64 };
                        break :blk std.math.divTrunc(i64, lv, rv) catch
                            return .{ .type_error = .int64 };
                    },
                    else => unreachable,
                };
                return .{ .value = .{ .atom = .{ .signed = res } } };
            },
        }
    }
};

/// Deterministic stack-machine Wasm instruction subset for in-engine vectorized UDF execution.
pub const WasmInstr = union(enum) {
    local_get: u8,
    i64_const: i64,
    i64_add_checked,
    i64_sub_checked,
    i64_mul_checked,
    i64_div_s_checked,
    i64_abs_checked,
    memory_grow_bytes: usize,
    branch_back_if_positive: usize,
    trap_explicit,
};

pub const WasmVectorModule = struct {
    param_count: u8,
    ambient_imports: []const AmbientImportKind = &.{},
    initial_memory_bytes: usize = 4096,
    instructions: []const WasmInstr,

    pub fn validate(self: WasmVectorModule, max_memory_bytes: usize) !void {
        for (self.ambient_imports) |imp| {
            if (imp != .none) return error.AmbientUdfImportRejected;
        }
        if (self.param_count > max_udf_params) return error.TooManyUdfParameters;
        if (self.instructions.len == 0 or self.instructions.len > max_wasm_instructions) {
            return error.InvalidWasmInstructionCount;
        }
        if (self.initial_memory_bytes > max_memory_bytes) {
            return error.UdfMemoryLimitExceeded;
        }
        for (self.instructions, 0..) |ins, pc| {
            switch (ins) {
                .local_get => |idx| if (idx >= self.param_count) return error.InvalidWasmLocalIndex,
                .branch_back_if_positive => |target_pc| if (target_pc > pc) return error.InvalidWasmBranchTarget,
                else => {},
            }
        }
    }
};

pub const FunctionDescriptor = struct {
    function_id: u64,
    name: []const u8,
    definition_id: u64,
    kind: UdfKind = .scalar,
    runtime: UdfRuntime,
    param_count: u8,
    deterministic: bool = true,
    on_trap: OnTrapPolicy = .emit_type_error_cell,
    max_fuel_per_row: u32 = default_max_fuel_per_row,
    max_memory_bytes: usize = default_max_memory_bytes,
    macro_body: ?MacroExpr = null,
    wasm_module: ?WasmVectorModule = null,

    pub fn validate(self: FunctionDescriptor) !void {
        if (self.function_id == 0 or self.definition_id == 0) return error.InvalidUdfIdentity;
        if (self.name.len == 0 or self.name.len > 63) return error.InvalidUdfName;
        if (!self.deterministic) return error.NonDeterministicUdfRejected;
        if (self.param_count > max_udf_params) return error.TooManyUdfParameters;
        if (self.max_fuel_per_row == 0) return error.InvalidUdfFuelBudget;
        if (self.max_memory_bytes == 0) return error.InvalidUdfMemoryBudget;
        switch (self.runtime) {
            .sql_macro => {
                const body = self.macro_body orelse return error.MissingSqlMacroBody;
                try body.validate(self.param_count);
            },
            .wasm_vector_v1 => {
                const wasm = self.wasm_module orelse return error.MissingWasmUdfModule;
                if (wasm.param_count != self.param_count) return error.UdfParameterArityMismatch;
                try wasm.validate(self.max_memory_bytes);
            },
        }
    }

    pub fn operatorEffects(self: FunctionDescriptor) OperatorTraits.EffectSet {
        _ = self;
        return OperatorTraits.EffectSet.read_only;
    }
};

pub const BatchExecutionStats = struct {
    rows_processed: usize = 0,
    total_fuel_consumed: u64 = 0,
    peak_memory_bytes: usize = 0,
    trap_row_count: usize = 0,
    actor_mailbox_hops: usize = 0,
};

/// Execute a validated scalar UDF across a batch of rows (`row_args[row_idx][param_idx]`)
/// directly inside the `Fuze` morsel pipeline with zero `Station` actor mailbox hops.
pub fn evaluateScalarBatch(
    desc: FunctionDescriptor,
    row_args: []const []const v.Cell,
    out_cells: []v.Cell,
) !BatchExecutionStats {
    try desc.validate();
    if (out_cells.len < row_args.len) return error.OutputBufferTooSmall;

    var stats: BatchExecutionStats = .{
        .rows_processed = row_args.len,
        .actor_mailbox_hops = 0,
    };

    switch (desc.runtime) {
        .sql_macro => {
            const macro = desc.macro_body.?;
            for (row_args, 0..) |args, row_i| {
                if (args.len != desc.param_count) return error.UdfArgumentArityMismatch;
                out_cells[row_i] = macro.evaluateRow(args);
                stats.total_fuel_consumed += 1;
            }
            return stats;
        },
        .wasm_vector_v1 => {
            const wasm = desc.wasm_module.?;
            stats.peak_memory_bytes = wasm.initial_memory_bytes;

            for (row_args, 0..) |args, row_i| {
                if (args.len != desc.param_count) return error.UdfArgumentArityMismatch;

                // Propagate non-value 5-state cells in deterministic precedence order
                var propagate: ?v.Cell = null;
                for (args) |c| {
                    switch (c) {
                        .conflict, .type_error, .missing => {
                            propagate = c;
                            break;
                        },
                        .null => if (propagate == null) {
                            propagate = c;
                        },
                        .value => {},
                    }
                }
                if (propagate) |p| {
                    out_cells[row_i] = p;
                    continue;
                }

                var locals: [max_udf_params]i64 = @splat(0);
                var domain_invalid = false;
                for (args, 0..) |c, p_i| {
                    if (c.value != .atom) {
                        domain_invalid = true;
                        break;
                    }
                    switch (c.value.atom) {
                        .signed => |s_val| {
                            locals[p_i] = std.math.cast(i64, s_val) orelse {
                                domain_invalid = true;
                                break;
                            };
                        },
                        else => {
                            domain_invalid = true;
                            break;
                        },
                    }
                }
                if (domain_invalid) {
                    out_cells[row_i] = .{ .type_error = .unknown };
                    stats.trap_row_count += 1;
                    continue;
                }

                var stack: [32]i64 = @splat(0);
                var sp: usize = 0;
                var pc: usize = 0;
                var row_fuel: u32 = 0;
                var row_mem: usize = wasm.initial_memory_bytes;
                var trapped: ?Types.Kind = null;

                while (pc < wasm.instructions.len) {
                    if (row_fuel >= desc.max_fuel_per_row) {
                        stats.trap_row_count += 1;
                        if (desc.on_trap == .abort_statement) return error.UdfFuelExhausted;
                        trapped = .int64;
                        break;
                    }
                    row_fuel += 1;
                    stats.total_fuel_consumed += 1;

                    const ins = wasm.instructions[pc];
                    pc += 1;

                    switch (ins) {
                        .local_get => |idx| {
                            if (sp >= stack.len) {
                                trapped = .int64;
                                break;
                            }
                            stack[sp] = locals[idx];
                            sp += 1;
                        },
                        .i64_const => |val| {
                            if (sp >= stack.len) {
                                trapped = .int64;
                                break;
                            }
                            stack[sp] = val;
                            sp += 1;
                        },
                        .i64_add_checked => {
                            if (sp < 2) {
                                trapped = .int64;
                                break;
                            }
                            const b = stack[sp - 1];
                            const a = stack[sp - 2];
                            sp -= 1;
                            stack[sp - 1] = std.math.add(i64, a, b) catch {
                                trapped = .int64;
                                break;
                            };
                        },
                        .i64_sub_checked => {
                            if (sp < 2) {
                                trapped = .int64;
                                break;
                            }
                            const b = stack[sp - 1];
                            const a = stack[sp - 2];
                            sp -= 1;
                            stack[sp - 1] = std.math.sub(i64, a, b) catch {
                                trapped = .int64;
                                break;
                            };
                        },
                        .i64_mul_checked => {
                            if (sp < 2) {
                                trapped = .int64;
                                break;
                            }
                            const b = stack[sp - 1];
                            const a = stack[sp - 2];
                            sp -= 1;
                            stack[sp - 1] = std.math.mul(i64, a, b) catch {
                                trapped = .int64;
                                break;
                            };
                        },
                        .i64_div_s_checked => {
                            if (sp < 2) {
                                trapped = .int64;
                                break;
                            }
                            const b = stack[sp - 1];
                            const a = stack[sp - 2];
                            sp -= 1;
                            if (b == 0) {
                                trapped = .int64;
                                break;
                            }
                            stack[sp - 1] = std.math.divTrunc(i64, a, b) catch {
                                trapped = .int64;
                                break;
                            };
                        },
                        .i64_abs_checked => {
                            if (sp < 1) {
                                trapped = .int64;
                                break;
                            }
                            const a = stack[sp - 1];
                            if (a == std.math.minInt(i64)) {
                                trapped = .int64;
                                break;
                            }
                            stack[sp - 1] = if (a < 0) -a else a;
                        },
                        .memory_grow_bytes => |delta| {
                            const next_mem = std.math.add(usize, row_mem, delta) catch {
                                if (desc.on_trap == .abort_statement) return error.UdfMemoryLimitExceeded;
                                trapped = .int64;
                                break;
                            };
                            if (next_mem > desc.max_memory_bytes) {
                                stats.trap_row_count += 1;
                                if (desc.on_trap == .abort_statement) return error.UdfMemoryLimitExceeded;
                                trapped = .int64;
                                break;
                            }
                            row_mem = next_mem;
                            if (row_mem > stats.peak_memory_bytes) stats.peak_memory_bytes = row_mem;
                        },
                        .branch_back_if_positive => |target_pc| {
                            if (sp < 1) {
                                trapped = .int64;
                                break;
                            }
                            const cond = stack[sp - 1];
                            sp -= 1;
                            if (cond > 0) {
                                pc = target_pc;
                            }
                        },
                        .trap_explicit => {
                            trapped = .int64;
                            break;
                        },
                    }
                }

                if (trapped) |observed_kind| {
                    stats.trap_row_count += 1;
                    if (desc.on_trap == .abort_statement) return error.UdfExecutionTrapped;
                    out_cells[row_i] = .{ .type_error = observed_kind };
                } else if (sp == 0) {
                    out_cells[row_i] = .{ .null = {} };
                } else {
                    out_cells[row_i] = .{ .value = .{ .atom = .{ .signed = stack[sp - 1] } } };
                }
            }
            return stats;
        },
    }
}

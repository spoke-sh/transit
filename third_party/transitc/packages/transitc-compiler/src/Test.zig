//! Pure test products. SQL carries database semantics; expectations are runner controls.
const std = @import("std");
const f = @import("transit_sql_frontend");
const p = @import("transit_protocol");
pub const max_cases = 128;
pub const max_actions = 1024;
pub const max_rows = 10000;
pub const max_result_bytes = 16 * 1024 * 1024;
pub const max_observations = 1000;
pub const Rows = struct { schema: f.Types.Type, values: []const []const u8 };
pub const Expectation = union(enum) {
    complete,
    rows: Rows,
    command: struct { matched: u64, changed: u64 },
    refusal: enum { duplicate_key, check_violation },
    workflow: struct { name: []const u8, completed: u64, refused: u64, observations: u64 },
};
pub const Action = struct { step: ?usize = null, expectation: Expectation, location: p.Diagnostic.Location };
pub const Case = struct {
    name: []const u8,
    identity: [32]u8,
    location: p.Diagnostic.Location,
    sql: []const u8,
    sql_digest: [32]u8,
    steps: []const @import("Compiler.zig").Step,
    actions: []const Action,
};

/// Both compiler expectations and runtime observations use the shared exact
/// value encoding, including duplicate counts and all cell-state distinctions.
pub fn rowBytes(cells: []const f.Types.Values.Cell, schema: f.Types.Type, output: []u8) ![]const u8 {
    return f.Types.Codec.encodeBound(.{ .value = .{ .structure = cells } }, .{ .name = "row", .type = schema }, output);
}

pub fn bindRows(output: std.mem.Allocator, scratch: std.mem.Allocator, text: []const u8, schema: f.Types.Type) !Rows {
    if (schema != .structure or schema.structure.len > f.TableSchema.max_columns) return error.InvalidTestSchema;
    const retained = try schema.clone(output);
    if (text.len == 0) return .{ .schema = retained.type, .values = &.{} };
    var parser = try f.SqlTyped.init(scratch, text, null);
    var values: std.ArrayList([]const u8) = .empty;
    var cells: [f.TableSchema.max_columns]f.Types.Values.Cell = undefined;
    const encoded = try scratch.alloc(u8, f.Types.Codec.max_bytes);
    var bytes: usize = 0;
    while (true) {
        if (values.items.len == max_rows) return error.TestRowLimit;
        try parser.require(.left);
        for (schema.structure, 0..) |field, i| {
            if (i != 0) try parser.require(.comma);
            cells[i] = try parser.value(field.type);
            try cells[i].validate(field, .{});
        }
        try parser.require(.right);
        const row = try rowBytes(cells[0..schema.structure.len], schema, encoded);
        if (row.len > max_result_bytes - bytes) return error.TestResultLimit;
        bytes += row.len;
        try values.append(output, try output.dupe(u8, row));
        if (!try parser.take(.comma)) break;
    }
    try parser.finish();
    return .{ .schema = retained.type, .values = try values.toOwnedSlice(output) };
}

pub const Failure = enum { rows, counts, expected_refusal, refusal_reason, workflow_counts, workflow_progress };
pub const Detail = struct {
    expected_primary: u64 = 0,
    expected_secondary: u64 = 0,
    observed_primary: u64 = 0,
    observed_secondary: u64 = 0,
    observations: u64 = 0,
    schema_mismatch: bool = false,
    expected_reason: [32]u8 = @splat(0),
    expected_reason_len: u8 = 0,
    observed_reason: [32]u8 = @splat(0),
    observed_reason_len: u8 = 0,
    pub fn setExpectedReason(self: *Detail, text: []const u8) void {
        const n: u8 = @intCast(@min(text.len, self.expected_reason.len));
        @memcpy(self.expected_reason[0..n], text[0..n]);
        self.expected_reason_len = n;
    }
    pub fn setObservedReason(self: *Detail, text: []const u8) void {
        const n: u8 = @intCast(@min(text.len, self.observed_reason.len));
        @memcpy(self.observed_reason[0..n], text[0..n]);
        self.observed_reason_len = n;
    }
    pub fn expectedReason(self: *const Detail) []const u8 {
        return self.expected_reason[0..self.expected_reason_len];
    }
    pub fn observedReason(self: *const Detail) []const u8 {
        return self.observed_reason[0..self.observed_reason_len];
    }
};

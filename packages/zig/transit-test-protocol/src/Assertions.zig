//! Neutral SQL test expectations shared by compiler clients and native hosts.
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
/// Both compiler expectations and runtime observations use the shared exact
/// value encoding, including duplicate counts and all cell-state distinctions.
pub fn rowBytes(cells: []const f.Types.Values.Cell, schema: f.Types.Type, output: []u8) ![]const u8 {
    return f.Types.Codec.encodeBound(.{ .value = .{ .structure = cells } }, .{ .name = "row", .type = schema }, output);
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

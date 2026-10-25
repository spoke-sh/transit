//! A Table observation identifies an interpretation and accepted data frontier.
//! It is neither a retention handle nor authority. Result readers construct it
//! only after verifying their original retained source evidence.
const std = @import("std");
const q = @import("root.zig");
const Self = @This();

/// Full-width positions cross language boundaries as canonical decimal text.
pub const Counter = struct {
    value: u64 = 0,
    pub fn jsonStringify(self: Counter, out: *std.json.Stringify) !void {
        var bytes: [20]u8 = undefined;
        try out.write(std.fmt.bufPrint(&bytes, "{d}", .{self.value}) catch unreachable);
    }
    pub fn jsonParse(allocator: std.mem.Allocator, input: anytype, options: std.json.ParseOptions) !Counter {
        const text = try std.json.innerParse([]const u8, allocator, input, options);
        return .{ .value = q.Values.unsigned(text) catch return error.InvalidNumber };
    }
    pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.write(.{ .type = "string", .pattern = "^(0|[1-9][0-9]*)$", .maxLength = 20, .@"x-transit-encoding" = "unsigned-decimal-u64" });
    }
};
resource: u64,
partition: Counter,
accepted: Counter,
contract: [32]u8,
schema: [32]u8,

pub fn validate(self: Self) !void {
    try q.UnifiedRecords.identity(self.resource);
    if (self.partition.value == 0 or self.accepted.value == 0 or std.mem.allEqual(u8, &self.contract, 0) or std.mem.allEqual(u8, &self.schema, 0)) return error.InvalidQuerySource;
}
pub fn current(source: q.TableSource, definition: q.catalog.DirectTableProtocol.Definition) !Self {
    try source.validate();
    if (!std.meta.eql(source.interpretation, definition.interpretation) or source.namespace != definition.namespace or definition.changed_lsn > definition.position.next_lsn) return error.SourceChanged;
    const result: Self = .{ .resource = source.scope.resource, .partition = .{ .value = definition.position.partition }, .accepted = .{ .value = definition.position.next_lsn }, .contract = try source.fingerprint(), .schema = try source.row_type.fingerprint() };
    try result.validate();
    return result;
}
pub fn captured(basis: q.TableSource.Basis) !Self {
    _ = try basis.record();
    const result: Self = .{ .resource = basis.retained.snapshot.object.scope.resource, .partition = .{ .value = basis.retained.accepted.partition }, .accepted = .{ .value = basis.retained.accepted.next_lsn }, .contract = basis.declaration, .schema = basis.schema };
    try result.validate();
    return result;
}
pub fn sameSource(self: Self, other: Self) bool {
    self.validate() catch return false;
    other.validate() catch return false;
    return self.resource == other.resource and self.partition.value == other.partition.value and std.mem.eql(u8, &self.contract, &other.contract) and std.mem.eql(u8, &self.schema, &other.schema);
}
/// A verified later result may cover an earlier watch observation. Compare only
/// within one exact interpretation and partition, never across native revisions.
pub fn covers(self: Self, observed: Self, changed_lsn: u64) bool {
    return self.sameSource(observed) and changed_lsn <= observed.accepted.value and self.accepted.value >= changed_lsn;
}

test "Table positions preserve full-width counters and reject unrelated source coverage" {
    const t = std.testing;
    const original: Self = .{ .resource = 7, .partition = .{ .value = std.math.maxInt(u64) }, .accepted = .{ .value = std.math.maxInt(u64) }, .contract = @splat(1), .schema = @splat(2) };
    const bytes = try q.protocol.Json.valueAlloc(t.allocator, original);
    defer t.allocator.free(bytes);
    try t.expect(std.mem.indexOf(u8, bytes, "\"partition\":\"18446744073709551615\"") != null);
    const parsed = try q.protocol.Json.parseFromSlice(Self, t.allocator, bytes);
    defer parsed.deinit();
    try t.expectEqualDeep(original, parsed.value);
    try t.expect(original.covers(parsed.value, std.math.maxInt(u64)));
    var older = original;
    older.accepted.value -= 1;
    try t.expect(!older.covers(original, original.accepted.value));
    try t.expect(older.covers(original, older.accepted.value));
    var foreign = original;
    foreign.partition.value -= 1;
    try t.expect(!original.covers(foreign, 1));
    foreign = original;
    foreign.contract[0] ^= 1;
    try t.expect(!original.covers(foreign, 1));
    try t.expectError(error.UnexpectedToken, q.protocol.Json.parseFromSlice(Counter, t.allocator, "18446744073709551615"));
    try t.expectError(error.InvalidNumber, q.protocol.Json.parseFromSlice(Counter, t.allocator, "\"01\""));
}

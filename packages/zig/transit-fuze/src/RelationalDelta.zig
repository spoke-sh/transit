//! Canonical paired changes between complete maintained results. A record is
//! staged evidence; only its owning complete revision admits the transaction.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const Output = @import("RelationalOutput.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const max_bytes = 4 + 32 + 1 + 32 + 32 + 8 + 4 + 2 * Output.max_bytes;
ordinal: u64,
before: ?Output = null,
after: ?Output = null,
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn identityOrder(a: @FieldType(e.Output, "identity"), b: @FieldType(e.Output, "identity")) !std.math.Order {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return error.InvalidRelationalDelta;
    return switch (a) {
        .group => |key| if (key.len > r.max_groups or b.group.len > r.max_groups) error.InvalidRelationalDelta else key.order(b.group),
        .pair => |pair| blk: {
            const left = e.identityOrder(pair.left, b.pair.left);
            if (left != .eq) break :blk left;
            if (pair.right) |right| break :blk if (b.pair.right) |other| e.identityOrder(right, other) else .gt;
            break :blk if (b.pair.right != null) .lt else .eq;
        },
    };
}
pub fn sameValues(a: e.Output, b: e.Output) bool {
    if (a.len != b.len or a.len > a.cells.len) return false;
    for (a.cells[0..a.len], b.cells[0..b.len]) |left, right| if (!std.meta.eql(left, right)) return false;
    return true;
}
pub fn encode(self: Self, previous: ?r.Bound, next: r.Bound, output: []u8) ![]const u8 {
    try next.validate();
    if (next.plan.lifetime != .maintained or (self.before == null and self.after == null)) return error.InvalidRelationalDelta;
    if (previous) |old| {
        try old.validate();
        if (!std.mem.eql(u8, &try old.plan.fingerprint(), &try next.plan.fingerprint())) return error.RelationalSourceChanged;
    } else if (self.before != null) return error.InvalidRelationalDelta;
    if (self.ordinal >= next.plan.budgets.output_rows and self.ordinal - next.plan.budgets.output_rows >= next.plan.budgets.output_rows) return error.RelationalResultBudget;
    // Validate each typed row before inspecting bounded arrays or identities.
    var before_buffer: [Output.max_bytes]u8 = undefined;
    var after_buffer: [Output.max_bytes]u8 = undefined;
    const before_bytes: []const u8 = if (self.before) |row| try row.encode(previous.?, &before_buffer) else "";
    const after_bytes: []const u8 = if (self.after) |row| try row.encode(next, &after_buffer) else "";
    if (self.before) |before| if (self.after) |after| {
        if (try identityOrder(before.row.identity, after.row.identity) != .eq or sameValues(before.row, after.row)) return error.InvalidRelationalDelta;
    };
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll("FRD1");
    try writer.writeAll(&definition());
    try writer.writeByte(@intFromBool(previous != null));
    try writer.writeAll(&if (previous) |old| try old.fingerprint() else @as([32]u8, @splat(0)));
    try writer.writeAll(&try next.fingerprint());
    try writer.writeInt(u64, self.ordinal, .little);
    try writer.writeInt(u16, @intCast(before_bytes.len), .little);
    try writer.writeAll(before_bytes);
    try writer.writeInt(u16, @intCast(after_bytes.len), .little);
    try writer.writeAll(after_bytes);
    return writer.buffered();
}
pub fn decode(previous: ?r.Bound, next: r.Bound, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.InvalidRelationalDelta;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FRD1")) return error.InvalidRelationalDelta;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    if (try reader.takeByte() != @intFromBool(previous != null)) return error.InvalidRelationalDelta;
    if (!std.mem.eql(u8, try reader.take(32), &if (previous) |old| try old.fingerprint() else @as([32]u8, @splat(0)))) return error.RelationalSourceChanged;
    if (!std.mem.eql(u8, try reader.take(32), &try next.fingerprint())) return error.RelationalSourceChanged;
    var result: Self = .{ .ordinal = try reader.takeInt(u64, .little) };
    const before = try reader.take(try reader.takeInt(u16, .little));
    if (before.len != 0) result.before = try Output.decode(previous orelse return error.InvalidRelationalDelta, before);
    const after = try reader.take(try reader.takeInt(u16, .little));
    if (after.len != 0) result.after = try Output.decode(next, after);
    if (reader.bufferedLen() != 0) return error.InvalidRelationalDelta;
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try result.encode(previous, next, &canonical))) return error.InvalidRelationalDelta;
    return result;
}
test {
    _ = @import("relational_delta_test.zig");
}

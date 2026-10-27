//! Canonical paired changes between complete maintained results. A record is
//! staged evidence; only its owning complete revision admits the transaction.
const std = @import("std");
const r = @import("Relational.zig");
const e = @import("RelationalExecution.zig");
const Output = @import("RelationalOutput.zig");
const values = @import("RelationalValues.zig");
const native = @import("transit_protocol").Growth;
const Self = @This();
pub const fixed_bytes = 4 + 32 + 1 + 32 + 32 + 8 + 8 + 2 * Output.fixed_bytes;
pub const max_bytes = fixed_bytes + 4 * values.max_text_bytes;
ordinal: u64,
before: ?Output = null,
after: ?Output = null,
pub fn deinit(self: *Self) void {
    if (self.before) |*row| row.deinit();
    if (self.after) |*row| row.deinit();
    self.* = undefined;
}
fn definition() [32]u8 {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(native.current_definition)) catch unreachable;
    return bytes;
}
pub fn identityOrder(a: @FieldType(e.Output, "identity"), b: @FieldType(e.Output, "identity"), plan: r.Plan) !std.math.Order {
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return error.InvalidRelationalDelta;
    return switch (a) {
        .group => |key| if (key.len > r.max_groups or b.group.len > r.max_groups) error.InvalidRelationalDelta else key.order(b.group, plan),
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
    for (a.cells[0..a.len], b.cells[0..b.len]) |left, right| {
        if (std.meta.activeTag(left) != std.meta.activeTag(right)) return false;
        if (left == .null) continue;
        if (left != .value or left.value != .atom or right.value != .atom) return false;
        const la = left.value.atom;
        const ra = right.value.atom;
        if (std.meta.activeTag(la) != std.meta.activeTag(ra)) return false;
        if (la == .bytes) {
            if (!std.mem.eql(u8, la.bytes, ra.bytes)) return false;
        } else if (!std.meta.eql(la, ra)) return false;
    }
    return true;
}
pub fn encode(self: Self, previous: ?r.Bound, next: r.Bound, output: []u8) ![]const u8 {
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try self.writeTo(.{ .previous = previous, .next = next }, &writer);
    return writer.buffered();
}
const Bounds = struct { previous: ?r.Bound, next: r.Bound };
pub fn encodeAlloc(self: Self, allocator: std.mem.Allocator, previous: ?r.Bound, next: r.Bound) ![]u8 {
    return values.encodeOwned(allocator, self, Bounds{ .previous = previous, .next = next }, max_bytes);
}
pub fn writeTo(self: Self, bounds: Bounds, writer: *std.Io.Writer) !void {
    const previous = bounds.previous;
    const next = bounds.next;
    try next.validate();
    if (next.plan.lifetime != .maintained or (self.before == null and self.after == null)) return error.InvalidRelationalDelta;
    if (previous) |old| {
        try old.validate();
        if (!std.mem.eql(u8, &try old.plan.fingerprint(), &try next.plan.fingerprint())) return error.RelationalSourceChanged;
    } else if (self.before != null) return error.InvalidRelationalDelta;
    if (self.ordinal >= next.plan.budgets.output_rows and self.ordinal - next.plan.budgets.output_rows >= next.plan.budgets.output_rows) return error.RelationalResultBudget;
    // Validate each typed row before inspecting bounded arrays or identities.
    const before_length = if (self.before) |row| try encodedLength(row, previous.?) else 0;
    const after_length = if (self.after) |row| try encodedLength(row, next) else 0;
    if (self.before) |before| if (self.after) |after| {
        if (try identityOrder(before.row.identity, after.row.identity, next.plan) != .eq or sameValues(before.row, after.row)) return error.InvalidRelationalDelta;
    };
    try writer.writeAll("FRD1");
    try writer.writeAll(&definition());
    try writer.writeByte(@intFromBool(previous != null));
    try writer.writeAll(&if (previous) |old| try old.fingerprint() else @as([32]u8, @splat(0)));
    try writer.writeAll(&try next.fingerprint());
    try writer.writeInt(u64, self.ordinal, .little);
    try writer.writeInt(u32, before_length, .little);
    if (self.before) |row| try row.writeTo(previous.?, writer);
    try writer.writeInt(u32, after_length, .little);
    if (self.after) |row| try row.writeTo(next, writer);
}
fn encodedLength(row: Output, bound: r.Bound) !u32 {
    var scratch: [256]u8 = undefined;
    var writer: std.Io.Writer.Discarding = .init(&scratch);
    try row.writeTo(bound, &writer.writer);
    if (writer.fullCount() > Output.max_bytes) return error.InvalidRelationalOutput;
    return @intCast(writer.fullCount());
}
pub fn decode(allocator: std.mem.Allocator, previous: ?r.Bound, next: r.Bound, bytes: []const u8) !Self {
    if (bytes.len > max_bytes) return error.InvalidRelationalDelta;
    var reader: std.Io.Reader = .fixed(bytes);
    if (!std.mem.eql(u8, try reader.take(4), "FRD1")) return error.InvalidRelationalDelta;
    if (!std.mem.eql(u8, try reader.take(32), &definition())) return error.IncompatibleDefinition;
    if (try reader.takeByte() != @intFromBool(previous != null)) return error.InvalidRelationalDelta;
    if (!std.mem.eql(u8, try reader.take(32), &if (previous) |old| try old.fingerprint() else @as([32]u8, @splat(0)))) return error.RelationalSourceChanged;
    if (!std.mem.eql(u8, try reader.take(32), &try next.fingerprint())) return error.RelationalSourceChanged;
    var result: Self = .{ .ordinal = try reader.takeInt(u64, .little) };
    errdefer result.deinit();
    const before = try reader.take(try reader.takeInt(u32, .little));
    if (before.len != 0) result.before = try Output.decode(allocator, previous orelse return error.InvalidRelationalDelta, before);
    const after = try reader.take(try reader.takeInt(u32, .little));
    if (after.len != 0) result.after = try Output.decode(allocator, next, after);
    if (reader.bufferedLen() != 0) return error.InvalidRelationalDelta;
    values.checkEncoding(bytes, result, Bounds{ .previous = previous, .next = next }) catch |err| return switch (err) {
        error.WriteFailed, error.InvalidRelationalEncoding => error.InvalidRelationalDelta,
        else => err,
    };
    return result;
}
test {
    _ = @import("relational_delta_test.zig");
}

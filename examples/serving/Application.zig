//! Non-trading Table application. The serving framework never decodes its values.
const std = @import("std");
const serving = @import("transit_serving");
const s = serving.station;
const p = s.protocol;
const Self = @This();
ingress: u64,
initializer: u64,
pub const progress_key = p.Value.init("data-progress") catch unreachable;
pub fn interface(self: *Self) s.GrowingGenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
fn initialize(_: ?*anyopaque, turn: *s.GrowingTurn) !void {
    _ = try s.Table.create(turn, 1, .{ .names = .{ try .init("id"), try .init("count") }, .value_type = .int64 });
    try turn.put(progress_key, p.Value.integer(0));
}
fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (frame.kind == .cast and turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.initializer and frame.payload.len == 0) return;
    if (try s.Frame.source(turn.delivery.input) != self.ingress) return error.UnexpectedServingIngress;
    if (frame.kind == .cancel) return; // Ordered cancellation cannot undo a committed update.
    if (frame.kind != .call) return error.UnsupportedServingInvocation;
    const invocation = try serving.Codec.decode(serving.Model.Invocation, 'i', frame.payload);
    if (invocation.codec != 1 or invocation.payload.len != 16) return turn.reply(try p.Value.init("InvalidCounterCommand"));
    const row_id = std.mem.readInt(i64, invocation.payload.data[0..8], .little);
    const delta = std.mem.readInt(i64, invocation.payload.data[8..16], .little);
    const table = try s.Table.open(turn, 1);
    const previous = try table.get(turn, row_id);
    const next = std.math.add(i64, if (previous) |row| row.value.int64 else 0, delta) catch return turn.reply(try p.Value.init("CounterOverflow"));
    try table.upsert(turn, .{ .key = row_id, .value = .{ .int64 = next } });
    const progress = try (try turn.read(progress_key)).?.asInteger();
    try turn.put(progress_key, p.Value.integer(try std.math.add(i64, progress, 1)));
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(i64, &bytes, next, .little);
    try turn.reply(try p.Value.init(&bytes));
}

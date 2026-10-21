//! Native GenServer adapter for the deterministic account ledger. Rejected
//! inputs have bounded attributed dispositions; state read failures never do.
const std = @import("std");
const g = @import("root.zig");
const s = g.station;
const c = g.catalog;
const p = c.protocol;
const Self = @This();
allocator: std.mem.Allocator,
ledger: g.Ledger,
pub fn interface(self: *Self) s.GenServer.Handler {
    return .{ .context = self, .initialize = initialize, .handle = handle };
}
pub fn guard(self: *Self) s.GenServer.InputGuard {
    return .{ .context = self, .reject = reject };
}
fn initialized(self: *Self, turn: *s.Turn) !bool {
    const config = self.ledger.configuration;
    if (turn.delivery.realm != config.realm or turn.delivery.pid != config.owner or turn.delivery.principal != config.worker or turn.view.resource != config.resource) return error.GatewayOwnerChanged;
    if (try turn.read(g.LedgerRecords.key('h', 0, 0)) == null) return false;
    _ = try self.ledger.head(turn);
    return true;
}
fn initializer(self: *Self, turn: *s.Turn, command: g.Control.Command) bool {
    return command == .initialize and turn.delivery.input.origin == .external and turn.delivery.input.origin.external.principal == self.ledger.configuration.control;
}
fn initialize(raw: ?*anyopaque, turn: *s.Turn) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast) return error.UninitializedGateway;
    const command = try g.Control.Command.decode(frame.payload);
    if (!self.initializer(turn, command)) return error.UninitializedGateway;
    try self.ledger.initialize(turn, command.initialize);
}
fn failure(self: *Self, turn: *s.Turn, cause: anyerror) !bool {
    _ = self;
    const disposition = try g.Control.Disposition.init(turn, cause);
    const encoded = try g.LedgerRecords.encode(disposition);
    const key = g.LedgerRecords.key('i', disposition.input, 0);
    if (try turn.read(key)) |existing| {
        if (!existing.eql(encoded)) return error.GatewayDispositionConflict;
    } else try turn.write(key, encoded);
    return true;
}
fn reject(raw: ?*anyopaque, turn: *s.Turn) !bool {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    const ready = try self.initialized(turn);
    const frame = s.Frame.decode(turn.delivery.input.value) catch |err| return if (ready) self.failure(turn, err) else error.UninitializedGateway;
    if (frame.kind != .cast) return if (ready) self.failure(turn, error.UnsupportedGatewayFrame) else error.UninitializedGateway;
    const command = g.Control.Command.decode(frame.payload) catch |err| return if (ready) self.failure(turn, err) else error.UninitializedGateway;
    if (!ready and !self.initializer(turn, command)) return error.UninitializedGateway;
    return false;
}
fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) !void {
    const self: *Self = @ptrCast(@alignCast(raw.?));
    if (frame.kind != .cast or !try self.initialized(turn)) return error.UninitializedGateway;
    const before = turn.decision;
    self.apply(turn, try g.Control.Command.decode(frame.payload)) catch |err| {
        turn.decision = before;
        // A failed source observation is retried by GenServer without committing
        // any application rejection. Allocation/cancellation are also transient.
        if (turn.read_error != null or err == error.OutOfMemory or err == error.Cancelled) return err;
        _ = try self.failure(turn, err);
    };
}
pub fn apply(self: *Self, turn: *s.Turn, command: g.Control.Command) !void {
    try command.validate();
    const ledger = self.ledger;
    switch (command) {
        .captured => |value| try g.CapturedLedger.apply(ledger, turn, value),
        .external_begin => |value| {
            _ = try g.SessionOperations.begin(ledger, turn, value);
        },
        .external_ready => |value| try g.SessionOperations.ready(ledger, turn, value.operation, value.generation, value.length, value.digest),
        .external_complete => |value| try g.SessionOperations.complete(ledger, turn, value.operation, value.generation, value.summary),
        .initialize => |sequence| try ledger.initialize(turn, sequence),
        .begin => |value| {
            _ = try ledger.begin(turn, value.nonce, value.binding, value.fingerprint);
        },
        .begin_intent => |value| try ledger.beginIntent(turn, value.operation, value.spec),
        .intent_part => |value| try ledger.intentPart(turn, value.operation, value.part.offset, value.part.bytes[0..value.part.length]),
        .seal_intent => |id| try ledger.sealIntent(turn, id),
        .admit_intent => |value| try ledger.admitIntent(self.allocator, turn, value.operation, value.generation),
        .activate => |generation| {
            _ = try ledger.activate(turn, generation);
        },
        .begin_step => |value| {
            _ = try ledger.beginStep(turn, value.target.operation, value.target.generation, value.spec);
        },
        .step_part => |value| try ledger.stepPart(turn, value.target.operation, value.target.generation, value.target.record, value.part.offset, value.part.bytes[0..value.part.length]),
        .publish_step => |value| try ledger.publishStep(self.allocator, turn, value.operation, value.generation, value.record),
        .receipt => |value| try ledger.recordReceipt(turn, value.target.operation, value.target.generation, value.target.record, .{ .position = value.input }),
        .processed => |value| try ledger.recordProcessed(self.allocator, turn, value.target.operation, value.target.generation, value.target.record, value.disposition),
        .reconcile => |id| try ledger.request(turn, id, .reconcile),
        .cancel => |id| try ledger.request(turn, id, .cancel),
        .session_cancel => |id| try ledger.sessionRequest(turn, id, .cancel),
        .session_resume => |id| try ledger.sessionRequest(turn, id, .reconcile),
        .abandon_step => |value| try ledger.abandonStep(turn, value.operation, value.generation, value.record),
        .collect_step => |value| try ledger.collectAbandonedStep(turn, value.operation, value.generation, value.record),
        .cancel_unsent => |value| try ledger.cancelUnsent(turn, value.operation, value.generation),
        .capacity => |value| try ledger.increaseCapacity(turn, value.operations, value.bytes, value.pending),
        .reserve => |value| try ledger.reserveRecovery(turn, value.operation, value.bytes),
        .complete => |value| try ledger.complete(turn, value.target.operation, value.target.generation, value.outcome),
    }
}
test "native behavior records attributed rejection without committing partial application writes" {
    const t = std.testing;
    const Store = @import("store_test.zig");
    var store: Store = .{};
    defer store.deinit();
    var behavior: Self = .{ .allocator = t.allocator, .ledger = .{ .configuration = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .reader = 11, .account = @splat(7), .bindings = &.{.{ .resource = 8, .catalog = 1, .owner = 9 }}, .intent_bytes = 4096, .operation_quota = 100, .byte_quota = 1024 * 1024 } } };
    var turn = try store.capture();
    const init_frame: s.Frame = .{ .kind = .cast, .payload = try (g.Control.Command{ .initialize = 0 }).encode() };
    turn.delivery.input.value = try init_frame.encode();
    try initialize(&behavior, &turn);
    try handle(&behavior, &turn, init_frame);
    try store.commit(turn);
    store.origin = 99;
    turn = try store.capture();
    const forbidden: s.Frame = .{ .kind = .cast, .payload = try (g.Control.Command{ .activate = 1 }).encode() };
    turn.delivery.input.value = try forbidden.encode();
    try t.expect(!try reject(&behavior, &turn));
    try handle(&behavior, &turn, forbidden);
    const disposition = try g.LedgerRecords.decode(g.Control.Disposition, (try turn.read(g.LedgerRecords.key('i', turn.delivery.input.position, 0))).?);
    try t.expectEqualStrings("GatewayDenied", disposition.cause[0..disposition.cause_length]);
    try t.expectEqual(@as(u64, 99), disposition.principal);
    try t.expectEqualSlices(u8, &try c.Model.fingerprint(turn.delivery.input.value), &disposition.payload);
    try store.commit(turn);
    turn = try store.capture();
    turn.delivery.input.value = try p.Value.init("broken frame");
    try t.expect(try reject(&behavior, &turn));
    try store.commit(turn);
    store.denied = true;
    turn = try store.capture();
    try t.expectError(error.AccessDenied, reject(&behavior, &turn));
    for (turn.decision.mutations) |slot| try t.expect(slot == null);
}

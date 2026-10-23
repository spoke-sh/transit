//! Bounded SQL recovery over a committed control reference and the direct Table
//! owner. Native generation fences the ledger; the original binding fences data.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const r = g.LedgerRecords;
const Self = @This();
allocator: std.mem.Allocator,
client: *g.Client,
table_key: p.Ed25519.KeyPair,
generation: u64,
admission_after: u64 = 0,
pub const Dispatch = struct { operation: u64, reference: g.IntentReference.Reference };
pub const Action = union(enum) { idle, blocked: u64, control: g.Control.Command, dispatch: Dispatch };
pub fn deinit(_: *Self) void {}

pub fn fence(self: *Self) !void {
    const config = self.client.ledger.configuration;
    if (self.client.principal != config.coordinator or self.generation == 0) return error.GatewayIdentityConflict;
    const state = try self.client.reader().query(.{ .process = config.owner });
    if (state.body != .process) return error.InvalidAuthorityResponse;
    const process = state.body.process.process;
    if (process.generation != self.generation or process.owner != config.worker) return error.StaleGatewayCoordinator;
    if (process.lifecycle != .running or process.failure != null or !p.Growth.processReady(process)) return error.GatewayOwnerUnavailable;
}
pub fn table(self: *Self, item: r.Operation) c.DirectTableClient {
    const config = self.client.ledger.configuration;
    return .{ .allocator = self.allocator, .authority = self.client.transport, .service = self.client.transport, .connection = .{ .scope = .{ .realm = config.realm, .resource = item.resource, .catalog = item.catalog }, .branch = 1, .audience = item.owner, .principal = config.table_principal, .role = item.selectedRole() }, .key = self.table_key };
}
fn target(self: *Self, id: u64) g.Control.Qualified {
    return .{ .operation = id, .generation = self.generation };
}
/// Observation never admits data work. Published dispatch eligibility survives
/// replacement, a lost reply and credential rotation; it never resolves names.
pub fn next(self: *Self) !Action {
    try self.fence();
    const ledger = self.client.ledger;
    var source = try self.client.source();
    const head = try ledger.head(&source);
    if (try ledger.indexed(&source, .admission, self.admission_after)) |item| {
        self.admission_after = item.id;
        if (item.cancel != 0) return .{ .control = .{ .cancel_unsent = self.target(item.id) } };
        if (item.phase == .uploading and (try ledger.publication(item.id).inspect(&source, 1)).state == .published) return .{ .control = .{ .admit_intent = self.target(item.id) } };
    } else self.admission_after = 0;
    if (head.active == 0) return if (try ledger.indexed(&source, .ready, 0) != null) .{ .control = .{ .activate = self.generation } } else .idle;
    const item = try ledger.operation(&source, head.active);
    if (item.phase != .active) return error.InvalidGatewayInventory;
    if (item.published == 0) return .{ .control = if (item.cancel != 0) .{ .cancel_unsent = self.target(item.id) } else .{ .dispatch = self.target(item.id) } };
    const reference = try ledger.readReference(self.allocator, &source, item);
    const observed = try reference.operation(self.table(item), .inspect, 1);
    defer observed.deinit();
    if (try g.Terminal.fromReference(reference, observed.value.result)) |terminal| return .{ .control = .{ .complete = .{ .target = self.target(item.id), .outcome = terminal } } };
    if (item.blocked != 0) return .{ .blocked = item.id };
    return .{ .dispatch = .{ .operation = item.id, .reference = reference } };
}
/// Recheck committed eligibility immediately before the attempt. Each call is
/// an explicit admission or execution of already frozen work. Unavailability
/// leaves that eligibility intact; no successor intent or Table ID is allocated.
pub fn dispatch(self: *Self, action: Dispatch) !?g.Control.Command {
    try self.fence();
    var source = try self.client.source();
    const ledger = self.client.ledger;
    const item = try ledger.operation(&source, action.operation);
    if ((try ledger.head(&source)).active != item.id or item.phase != .active or item.published != 1) return error.GatewayOperationInactive;
    const reference = try ledger.readReference(self.allocator, &source, item);
    try reference.requireSame(action.reference);
    const caller = self.table(item);
    const observed = try reference.operation(caller, .inspect, 1);
    defer observed.deinit();
    if (try g.Terminal.fromReference(reference, observed.value.result)) |terminal| return .{ .complete = .{ .target = self.target(item.id), .outcome = terminal } };
    const absent = switch (observed.value.result) {
        .ddl => |value| value == .not_observed,
        .rows => |value| value == .not_observed,
        .name_assertion => |value| value == .not_observed,
        else => return error.InvalidGatewayTerminal,
    };
    const response = if (absent and !(reference == .name_assertion and item.cancel != 0)) try reference.admit(caller) else try reference.operation(caller, if (item.cancel != 0) .cancel else .execute, 8);
    defer response.deinit();
    if (try g.Terminal.fromReference(reference, response.value.result)) |terminal| return .{ .complete = .{ .target = self.target(item.id), .outcome = terminal } };
    return null;
}

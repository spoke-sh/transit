//! A data-owner ledger above Station. Domain code owns transform semantics;
//! completed step receipts and data mutations share one ordinary private turn.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const c = root.Records;
const Wide = root.Model.Wide;
const Turn = root.station.Turn;
const Self = @This();
pub const Configuration = struct { application: u64, realm: u64, administrator: u64, initial_epoch: Wide, initial_contract: [32]u8 };
pub const Policy = struct { revision: Wide, migrate: bool };
pub const Head = struct { epoch: Wide, contract: [32]u8, active: Wide = .{} };
pub const Proposal = struct { plan: Wide, expected: Wide, next: Wide, transform: u16, source: [32]u8, target: [32]u8 };
pub const Plan = struct { proposal: Proposal, digest: [32]u8, principal: u64, input: u64 };
pub const Phase = enum(u8) { active = 1, applied = 2, abandoned = 3 };
pub const Progress = struct { next: Wide = .{ .value = 1 }, phase: Phase = .active, cursor: p.Value = .{}, input: u64 = 0 };
pub const Step = struct { plan: Wide, ordinal: Wide, operation: u16, arguments: p.Value = .{} };
pub const Receipt = struct { plan: Wide, ordinal: Wide, digest: [32]u8, input: u64, progress: Progress };
pub const Transition = union(enum) { advance: p.Value, activate: void };
configuration: Configuration,

pub fn key(application: u64, tag: u8, plan_id: u64, ordinal: u64) p.Value {
    var value = c.key(application, tag, plan_id, ordinal);
    value.data[1] = 'M';
    return value;
}
fn address(self: Self, tag: u8, plan_id: u64, ordinal: u64) p.Value {
    return key(self.configuration.application, tag, plan_id, ordinal);
}
fn who(turn: *const Turn) !u64 {
    if (turn.delivery.input.origin != .external) return error.MigrationDenied;
    return turn.delivery.input.origin.external.principal;
}
fn configurationValid(self: Self, turn: *const Turn) !void {
    const value = self.configuration;
    inline for (.{ value.application, value.realm, value.administrator }) |id| if (id == 0 or id > p.max_counter) return error.InvalidMigrationConfiguration;
    if (value.realm != turn.delivery.realm or value.initial_epoch.value == 0) return error.InvalidMigrationConfiguration;
}
pub fn initialize(self: Self, turn: *Turn) !void {
    try self.configurationValid(turn);
    if (try who(turn) != self.configuration.administrator) return error.MigrationDenied;
    const before = turn.decision;
    errdefer turn.decision = before;
    const encoded = try c.encode('C', self.configuration);
    if (try turn.read(self.address('C', 0, 0))) |value| {
        if (!value.eql(encoded)) return error.MigrationConfigurationChanged;
        return;
    }
    if (try turn.read(self.address('H', 0, 0)) != null) return error.MigrationConfigurationChanged;
    try turn.write(self.address('C', 0, 0), encoded);
    try turn.write(self.address('H', 0, 0), try c.encode('H', Head{ .epoch = self.configuration.initial_epoch, .contract = self.configuration.initial_contract }));
}
fn check(self: Self, turn: *Turn) !void {
    try self.configurationValid(turn);
    const value = (try turn.read(self.address('C', 0, 0))) orelse return error.MigrationNotInitialized;
    if (!value.eql(try c.encode('C', self.configuration))) return error.MigrationConfigurationChanged;
}
pub fn policy(self: Self, reader: anytype, principal: u64) !?Policy {
    return if (try reader.read(self.address('P', principal, 0))) |value| try c.decode(Policy, 'P', value) else null;
}
pub fn setPolicy(self: Self, turn: *Turn, principal: u64, expected: Wide, next: Policy) !void {
    try self.check(turn);
    if (try who(turn) != self.configuration.administrator) return error.MigrationDenied;
    if (principal == 0 or principal > p.max_counter or next.revision.value != try std.math.add(u64, expected.value, 1)) return error.InvalidMigrationPolicy;
    const previous = try self.policy(turn, principal);
    if ((if (previous) |value| value.revision.value else 0) != expected.value) return error.MigrationPolicyConflict;
    try turn.write(self.address('P', principal, 0), try c.encode('P', next));
}
fn authorize(self: Self, turn: *Turn) !u64 {
    try self.check(turn);
    const principal = try who(turn);
    if (!(try self.policy(turn, principal) orelse return error.MigrationDenied).migrate) return error.MigrationDenied;
    return principal;
}
pub fn head(self: Self, reader: anytype) !Head {
    return c.decode(Head, 'H', (try reader.read(self.address('H', 0, 0))) orelse return error.MigrationNotInitialized);
}
pub fn plan(self: Self, reader: anytype, id: Wide) !?Plan {
    return if (try reader.read(self.address('A', id.value, 0))) |value| try c.decode(Plan, 'A', value) else null;
}
pub fn progress(self: Self, reader: anytype, id: Wide) !Progress {
    return c.decode(Progress, 'G', (try reader.read(self.address('G', id.value, 0))) orelse return error.MigrationPlanAbsent);
}
pub fn receipt(self: Self, reader: anytype, step: Step) !?Receipt {
    return if (try reader.read(self.address('S', step.plan.value, step.ordinal.value))) |value| try c.decode(Receipt, 'S', value) else null;
}
fn hash(comptime domain: []const u8, bytes: p.Value) [32]u8 {
    var value = std.crypto.hash.sha2.Sha256.init(.{});
    value.update(domain);
    value.update(bytes.slice());
    return value.finalResult();
}
pub fn proposalDigest(self: Self, proposal: Proposal) ![32]u8 {
    if (proposal.plan.value == 0 or proposal.expected.value == 0 or proposal.next.value != try std.math.add(u64, proposal.expected.value, 1) or proposal.transform == 0) return error.InvalidMigrationProposal;
    return hash("transit.application.migration.plan.v1\x00", try c.encode('D', .{ .application = self.configuration.application, .proposal = proposal }));
}
pub fn stepDigest(self: Self, proposal: Plan, step: Step) ![32]u8 {
    try step.arguments.validate();
    if (step.plan.value != proposal.proposal.plan.value or step.ordinal.value == 0 or step.operation == 0 or step.arguments.len > 128) return error.InvalidMigrationStep;
    return hash("transit.application.migration.step.v1\x00", try c.encode('D', .{ .application = self.configuration.application, .proposal = proposal.digest, .step = step }));
}
/// The domain owner validates supported transforms and source/target declarations
/// before calling begin. No domain callback or external effect runs here.
pub fn begin(self: Self, turn: *Turn, proposal: Proposal) !Progress {
    const principal = try self.authorize(turn);
    const digest = try self.proposalDigest(proposal);
    if (try self.plan(turn, proposal.plan)) |previous| {
        if (previous.principal != principal or !std.mem.eql(u8, &digest, &previous.digest)) return error.MigrationPlanConflict;
        return self.progress(turn, proposal.plan);
    }
    var current = try self.head(turn);
    if (current.active.value != 0) return error.MigrationBusy;
    if (current.epoch.value != proposal.expected.value or !std.mem.eql(u8, &current.contract, &proposal.source)) return error.MigrationSourceChanged;
    const before = turn.decision;
    errdefer turn.decision = before;
    current.active = proposal.plan;
    try turn.write(self.address('A', proposal.plan.value, 0), try c.encode('A', Plan{ .proposal = proposal, .digest = digest, .principal = principal, .input = turn.delivery.input.position }));
    try turn.write(self.address('G', proposal.plan.value, 0), try c.encode('G', Progress{ .input = turn.delivery.input.position }));
    try turn.write(self.address('H', 0, 0), try c.encode('H', current));
    return .{ .input = turn.delivery.input.position };
}
/// Domain apply(turn, plan, progress, step) returns a bounded cursor or activation.
/// It may write at most two domain records, or one for an activation. Errors roll
/// back the complete decision, including tentative domain mutations.
pub fn apply(self: Self, turn: *Turn, step: Step, domain: anytype) !Receipt {
    const principal = try self.authorize(turn);
    const selected = (try self.plan(turn, step.plan)) orelse return error.MigrationPlanAbsent;
    if (selected.principal != principal) return error.MigrationDenied;
    const digest = try self.stepDigest(selected, step);
    if (try self.receipt(turn, step)) |previous| {
        if (!std.mem.eql(u8, &previous.digest, &digest)) return error.MigrationStepConflict;
        return previous;
    }
    var current = try self.head(turn);
    var state = try self.progress(turn, step.plan);
    if (current.active.value != step.plan.value or state.phase != .active) return error.MigrationNotActive;
    if (state.next.value != step.ordinal.value) return error.MigrationStepConflict;
    if (current.epoch.value != selected.proposal.expected.value or !std.mem.eql(u8, &current.contract, &selected.proposal.source)) return error.MigrationSourceChanged;
    const before = turn.decision;
    errdefer turn.decision = before;
    const transition = try domain.apply(turn, selected, state, step);
    state.next.value = try std.math.add(u64, state.next.value, 1);
    state.input = turn.delivery.input.position;
    switch (transition) {
        .advance => |cursor| {
            try cursor.validate();
            if (cursor.len > 128) return error.MigrationCursorTooLarge;
            state.cursor = cursor;
        },
        .activate => {
            state.phase = .applied;
            current = .{ .epoch = selected.proposal.next, .contract = selected.proposal.target };
            try turn.write(self.address('H', 0, 0), try c.encode('H', current));
        },
    }
    const result: Receipt = .{ .plan = step.plan, .ordinal = step.ordinal, .digest = digest, .input = turn.delivery.input.position, .progress = state };
    try turn.write(self.address('G', step.plan.value, 0), try c.encode('G', state));
    try turn.write(self.address('S', step.plan.value, step.ordinal.value), try c.encode('S', result));
    return result;
}
pub fn abandon(self: Self, turn: *Turn, id: Wide) !Progress {
    const principal = try self.authorize(turn);
    const selected = (try self.plan(turn, id)) orelse return error.MigrationPlanAbsent;
    if (selected.principal != principal) return error.MigrationDenied;
    var state = try self.progress(turn, id);
    if (state.phase == .abandoned) return state;
    if (state.phase == .applied) return error.MigrationAlreadyApplied;
    var current = try self.head(turn);
    if (current.active.value != id.value) return error.MigrationNotActive;
    const before = turn.decision;
    errdefer turn.decision = before;
    state.phase = .abandoned;
    state.input = turn.delivery.input.position;
    current.active = .{};
    try turn.write(self.address('G', id.value, 0), try c.encode('G', state));
    try turn.write(self.address('H', 0, 0), try c.encode('H', current));
    return state;
}

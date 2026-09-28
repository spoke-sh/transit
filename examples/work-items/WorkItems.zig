//! Application-owned status semantics and one bounded Table evolution.
const std = @import("std");
pub const app = @import("transit_station_app");
pub const query = @import("transit_query");
const s = app.station;
const p = app.protocol;
const M = app.Migration;
const Wide = app.Model.Wide;
const Self = @This();
pub const Configuration = struct { application: u64, realm: u64, administrator: u64, writer: u64, resource: u64 };
configuration: Configuration,
pub const Command = union(enum(u8)) {
    initialize: void = 0,
    policy: struct { principal: u64, expected: Wide, next: M.Policy } = 1,
    put: struct { epoch: Wide, id: i64, state: i64 } = 2,
    begin: M.Proposal = 3,
    step: M.Step = 4,
    abandon: Wide = 5,
    release_writes: struct { epoch: Wide, contract: [32]u8 } = 6,
    pub fn encode(self: Command) !p.Value {
        var value = try app.Records.encode('i', self);
        value.data[0..3].* = "WI1".*;
        if (value.len > s.Frame.max_payload) return error.MessageTooLarge;
        return value;
    }
    pub fn decode(value: p.Value) !Command {
        try value.validate();
        if (value.len < 5 or !std.mem.eql(u8, value.data[0..4], "WI1i")) return error.InvalidWorkItemCommand;
        var encoded = value;
        encoded.data[0..3].* = "AP1".*;
        return app.Records.decode(Command, 'i', encoded) catch error.InvalidWorkItemCommand;
    }
};
pub const Cursor = struct {
    phase: enum(u8) { copy = 0, verify = 1, ready = 2 } = .copy,
    has_after: bool = false,
    after: i64 = 0,
    copied: u64 = 0,
    verified: u64 = 0,
    pub fn encode(self: Cursor) !p.Value {
        return app.Records.encode('c', self);
    }
    pub fn decode(value: p.Value) !Cursor {
        return if (value.len == 0) .{} else app.Records.decode(Cursor, 'c', value);
    }
};
const Active = struct { table: u32, writes: bool };
const active_table = p.Value.init("work-items.active-table") catch unreachable;
pub fn source(self: Self, table: u32) !query.SourceDefinition {
    return .{ .resource = self.configuration.resource, .source = .{ .table = .{ .id = table, .schema = .{ .names = .{ try .init("id"), try .init(if (table == 1) "status" else "state") }, .value_type = .int64 } } } };
}
pub fn ledger(self: Self) !M {
    return .{ .configuration = .{ .application = self.configuration.application, .realm = self.configuration.realm, .administrator = self.configuration.administrator, .initial_epoch = .{ .value = 1 }, .initial_contract = try (try self.source(1)).fingerprint() } };
}
pub fn proposal(self: Self, id: u32) !M.Proposal {
    if (id < 2) return error.InvalidWorkItemPlan;
    return .{ .plan = .{ .value = id }, .expected = .{ .value = 1 }, .next = .{ .value = 2 }, .transform = 1, .source = try (try self.source(1)).fingerprint(), .target = try (try self.source(id)).fingerprint() };
}
pub fn initialize(self: Self, turn: *s.GrowingTurn) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (turn.view.resource != self.configuration.resource) return error.WorkItemScopeChanged;
    try (try self.ledger()).initialize(turn);
    const definition = try self.source(1);
    if (try turn.read(s.Table.descriptorKey(1)) == null) _ = try s.Table.create(turn, 1, definition.source.table.schema);
}
pub fn selected(self: Self, turn: anytype) !u32 {
    const head = try (try self.ledger()).head(turn);
    if (head.epoch.value == 1) return 1;
    const state = try app.Records.decode(Active, 'a', (try turn.read(active_table)) orelse return error.WorkItemStateMissing);
    if (state.table < 2) return error.WorkItemStateMissing;
    return state.table;
}
pub fn execute(self: Self, turn: *s.GrowingTurn, command: Command) !void {
    if (turn.view.resource != self.configuration.resource or turn.delivery.input.origin != .external) return error.WorkItemDenied;
    const owner = try self.ledger();
    const before = turn.decision;
    errdefer turn.decision = before;
    switch (command) {
        .initialize => try self.initialize(turn),
        .policy => |value| try owner.setPolicy(turn, value.principal, value.expected, value.next),
        .put => |value| {
            if (turn.delivery.input.origin.external.principal != self.configuration.writer) return error.WorkItemDenied;
            const head = try owner.head(turn);
            if (head.active.value != 0) return error.WorkItemMigrationPaused;
            if (head.epoch.value != value.epoch.value) return error.WorkItemEpochChanged;
            if (head.epoch.value != 1 and !(try app.Records.decode(Active, 'a', (try turn.read(active_table)) orelse return error.WorkItemStateMissing)).writes) return error.WorkItemPublicationPaused;
            if (value.state != (if (head.epoch.value == 1) @as(i64, 0) else 10) and value.state != (if (head.epoch.value == 1) @as(i64, 1) else 20)) return error.InvalidWorkItemState;
            const table = try s.Table.open(turn, try self.selected(turn));
            try table.upsert(turn, .{ .key = value.id, .value = .{ .int64 = value.state } });
        },
        .begin => |value| {
            if (value.plan.value < 2 or value.plan.value > std.math.maxInt(u32) or !std.meta.eql(value, try self.proposal(@intCast(value.plan.value)))) return error.InvalidWorkItemPlan;
            const exists = try owner.plan(turn, value.plan) != null;
            _ = try owner.begin(turn, value);
            if (!exists) _ = try s.Table.create(turn, @intCast(value.plan.value), (try self.source(@intCast(value.plan.value))).source.table.schema);
        },
        .step => |value| _ = try owner.apply(turn, value, self),
        .abandon => |value| _ = try owner.abandon(turn, value),
        .release_writes => |value| {
            if (turn.delivery.input.origin.external.principal != self.configuration.administrator) return error.WorkItemDenied;
            const head = try owner.head(turn);
            if (head.epoch.value != value.epoch.value or head.epoch.value != 2 or head.active.value != 0 or !std.mem.eql(u8, &head.contract, &value.contract)) return error.WorkItemEpochChanged;
            var state = try app.Records.decode(Active, 'a', (try turn.read(active_table)) orelse return error.WorkItemStateMissing);
            if (state.writes) return;
            state.writes = true;
            try turn.write(active_table, try app.Records.encode('a', state));
        },
    }
}
fn pageAfter(table: s.Table, turn: *s.GrowingTurn, cursor: Cursor) !s.Table.Page {
    // The domain write pause, not a reused snapshot token, stabilizes contents.
    return table.page(turn, if (cursor.has_after) .{ .source = .{ .view = turn.view.id }, .resource = table.resource, .revision = turn.view.revision, .table = table.id, .schema = try table.schema.fingerprint(), .after = cursor.after } else null);
}
pub fn apply(self: Self, turn: *s.GrowingTurn, plan: M.Plan, progress: M.Progress, step: M.Step) !M.Transition {
    if (!step.arguments.eql(progress.cursor)) return error.WorkItemCursorChanged;
    var cursor = try Cursor.decode(progress.cursor);
    const target: u32 = @intCast(plan.proposal.plan.value);
    if (step.operation == 2) {
        if (cursor.phase != .ready or cursor.copied != cursor.verified) return error.WorkItemVerificationIncomplete;
        try turn.write(active_table, try app.Records.encode('a', Active{ .table = target, .writes = false }));
        return .{ .activate = {} };
    }
    if (step.operation != 1 or cursor.phase == .ready) return error.InvalidWorkItemStep;
    const from = try s.Table.open(turn, 1);
    const to = try s.Table.open(turn, target);
    const page = try pageAfter(if (cursor.phase == .copy) from else to, turn, cursor);
    const count = @min(2, page.len);
    for (page.rows[0..count]) |row| {
        if (cursor.phase == .copy) {
            const translated = try translate(row.value);
            try to.insert(turn, .{ .key = row.key, .value = .{ .int64 = translated } });
            cursor.copied = try std.math.add(u64, cursor.copied, 1);
        } else {
            const original = (try from.get(turn, row.key)) orelse return error.WorkItemVerificationFailed;
            if (row.value != .int64 or row.value.int64 != try translate(original.value)) return error.WorkItemVerificationFailed;
            cursor.verified = try std.math.add(u64, cursor.verified, 1);
        }
        cursor.has_after = true;
        cursor.after = row.key;
    }
    if (page.len <= 2 and page.next == null) {
        cursor.phase = if (cursor.phase == .copy) .verify else .ready;
        cursor.has_after = false;
        cursor.after = 0;
        if (cursor.phase == .ready and cursor.copied != cursor.verified) return error.WorkItemVerificationFailed;
    }
    _ = self;
    return .{ .advance = try cursor.encode() };
}
fn translate(value: query.fuze.model.Cell) !i64 {
    if (value != .int64) return error.InvalidWorkItemState;
    return switch (value.int64) {
        0 => 10,
        1 => 20,
        else => error.InvalidWorkItemState,
    };
}
pub fn dispositionKey(application: u64, principal: u64, input: u64) p.Value {
    var key = app.Records.key(application, 'e', principal, input);
    key.data[1] = 'W';
    return key;
}
pub const Behavior = struct {
    owner: Self,
    capture: ?query.UnifiedBehavior.Source = null,
    pub fn interface(self: *@This()) s.GrowingGenServer.Handler {
        return .{ .context = self, .initialize = init, .handle = handle };
    }
    pub fn guard(self: *@This()) s.GrowingGenServer.InputGuard {
        return .{ .context = self, .reject = reject };
    }
    fn get(raw: ?*anyopaque) *@This() {
        return @ptrCast(@alignCast(raw.?));
    }
    fn init(raw: ?*anyopaque, turn: *s.GrowingTurn) !void {
        try get(raw).owner.initialize(turn);
    }
    fn disposition(self: *@This(), turn: *s.GrowingTurn, reason: []const u8) !void {
        const principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
        try turn.write(dispositionKey(self.owner.configuration.application, principal, turn.delivery.input.position), try p.Value.init(reason));
    }
    fn reject(raw: ?*anyopaque, turn: *s.GrowingTurn) anyerror!bool {
        const self = get(raw);
        const frame = s.Frame.decode(turn.delivery.input.value) catch {
            try self.disposition(turn, "InvalidWorkItemFrame");
            return true;
        };
        if (self.capture != null and !std.mem.startsWith(u8, frame.payload.slice(), "WI1i")) {
            // Public send permission does not authorize arbitrary query control
            // on this data owner. Internal calls still use the shared peer and
            // correlation checks; external ingress admits only scoped policy.
            if (turn.delivery.input.origin == .external and
                (frame.kind != .cast or turn.delivery.input.origin.external.principal != self.owner.configuration.administrator or !std.mem.startsWith(u8, frame.payload.slice(), "UQA2")))
            {
                try self.disposition(turn, "WorkItemDenied");
                return true;
            }
            if (try turn.read(app.Migration.key(self.owner.configuration.application, 'C', 0, 0)) == null) {
                try self.disposition(turn, "WorkItemInitializationRequired");
                return true;
            }
            return false;
        }
        if (frame.kind != .cast or turn.delivery.input.origin != .external) {
            try self.disposition(turn, "WorkItemDenied");
            return true;
        }
        _ = Command.decode(frame.payload) catch {
            try self.disposition(turn, "InvalidWorkItemCommand");
            return true;
        };
        return false;
    }
    fn handle(raw: ?*anyopaque, turn: *s.GrowingTurn, frame: s.Frame) anyerror!void {
        const self = get(raw);
        if (self.capture) |*capture| {
            if (!std.mem.startsWith(u8, frame.payload.slice(), "WI1i")) {
                const handler = capture.interface();
                if (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "UQA2")) {
                    if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.owner.configuration.administrator) return self.disposition(turn, "WorkItemDenied");
                    const policy = query.UnifiedRecords.Policy.decode(frame.payload) catch return self.disposition(turn, "InvalidWorkItemQueryPolicy");
                    if (policy.peer != capture.peer) return self.disposition(turn, "InvalidWorkItemQueryPolicy");
                    const definition = try self.owner.source(try self.owner.selected(turn));
                    if (!std.mem.eql(u8, &policy.declaration, &try query.Bundle.declaration(definition))) return self.disposition(turn, "WorkItemEpochChanged");
                    if (try turn.read(query.UnifiedRecords.key('v', 0, 0)) == null) {
                        try handler.initialize.?(handler.context, turn);
                    } else {
                        try handler.handle(handler.context, turn, .{ .kind = .cast, .payload = try query.UnifiedRequest.Command.encode(.initialize) });
                    }
                    query.UnifiedCapture.setPolicy(turn, policy) catch |err| {
                        if (err == error.StaleQueryPolicy) return self.disposition(turn, "StaleQueryPolicy");
                        return err;
                    };
                    return;
                }
                return handler.handle(handler.context, turn, frame);
            }
        }
        const before = turn.decision;
        self.owner.execute(turn, try Command.decode(frame.payload)) catch |err| {
            turn.decision = before;
            if (turn.read_error != null or !requestError(err)) return err;
            try self.disposition(turn, @errorName(err));
        };
    }
};
fn requestError(err: anyerror) bool {
    return switch (err) {
        error.WorkItemDenied, error.WorkItemMigrationPaused, error.WorkItemPublicationPaused, error.WorkItemEpochChanged, error.InvalidWorkItemState, error.InvalidWorkItemPlan, error.InvalidWorkItemStep, error.WorkItemCursorChanged, error.WorkItemVerificationIncomplete, error.MigrationDenied, error.MigrationPolicyConflict, error.InvalidMigrationPolicy, error.MigrationPlanConflict, error.MigrationBusy, error.MigrationSourceChanged, error.MigrationPlanAbsent, error.MigrationStepConflict, error.MigrationNotActive, error.MigrationAlreadyApplied, error.InvalidMigrationStep, error.InvalidMigrationProposal, error.TableExists => true,
        // Corrupt data, read failures and transform failures leave the input
        // unresolved. They must never become a fabricated successful step.
        else => false,
    };
}
test {
    _ = @import("work_items_test.zig");
}

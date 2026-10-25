//! Application-owned status semantics and one bounded Table evolution.
const std = @import("std");
pub const app = @import("transit_station_app");
pub const query = @import("transit_query");
const s = app.station;
const p = app.protocol;
const M = app.Migration;
const Wide = app.Model.Wide;
const c = query.catalog;
pub const Table = @import("WorkTable.zig");
pub const Data = Table.Data;
const Self = @This();
pub const Configuration = struct { application: u64, realm: u64, administrator: u64, writer: u64, resource: u64, owner: u64 };
pub const Failure = @import("WorkItemFailure.zig");
allocator: std.mem.Allocator,
configuration: Configuration,
failure: ?*Failure.Context = null,
transport: ?Data.Transport = null,
fn remember(self: Self, witness: Failure.Witness) void {
    if (self.failure) |failure| failure.domain = witness;
}
fn rememberEpoch(self: Self, expected: Wide, head: M.Head, expected_contract: ?[32]u8) void {
    self.remember(.{ .epoch = .{ .expected = expected, .actual = head.epoch, .active = head.active, .actual_contract = head.contract, .expected_contract = expected_contract orelse @splat(0), .contract_known = expected_contract != null } });
}
pub const Command = union(enum(u8)) {
    initialize: void = 0,
    policy: struct { principal: u64, expected: Wide, next: M.Policy } = 1,
    put: struct { epoch: Wide, id: i64, state: i64 } = 2,
    begin: M.Proposal = 3,
    step: M.Step = 4,
    abandon: Wide = 5,
    release_writes: struct { epoch: Wide, contract: [32]u8 } = 6,
    catalog_initialize: Data.Binding = 7,
    prepare_table: u32 = 8,
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
        const command = app.Records.decode(Command, 'i', encoded) catch return error.InvalidWorkItemCommand;
        if (command == .catalog_initialize) command.catalog_initialize.validate() catch return error.InvalidWorkItemCommand;
        return command;
    }
};
pub const Cursor = struct {
    phase: enum(u8) { copy = 0, verify = 1, ready = 2 } = .copy,
    has_after: bool = false,
    after: Table.Identity = .{ .origin = 0, .operation = 0, .ordinal = 0 },
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
const data_binding = p.Value.init("work-items.data-binding") catch unreachable;
pub fn data(self: Self, reader: anytype) !Data.Binding {
    const stored = try app.Records.decode(Data.Binding, 'd', (try reader.read(data_binding)) orelse return error.WorkItemInitializationRequired);
    try stored.validate();
    if (stored.scope.realm != self.configuration.realm) return error.CatalogScopeChanged;
    return stored;
}
pub fn client(self: Self, reader: anytype) !Data.Client {
    return (self.transport orelse return error.WorkItemDataUnavailable).bind(try self.data(reader));
}
pub const Source = struct {
    owned: query.TableSource.Owned,
    definition: query.SourceDefinition,
    pub fn deinit(self: *@This()) void {
        self.owned.deinit();
        self.* = undefined;
    }
};
pub fn source(self: Self, reader: anytype, principal: u64, table: u32) !Source {
    const binding = try self.data(reader);
    const direct = try self.client(reader);
    var definition = try Table.definition(direct, binding, table);
    defer definition.deinit();
    _ = reader.requireAuthorization(try definition.authority.guard(try reader.authorizationSubject(principal))) catch |err| return if (err == error.AccessDenied) error.CatalogDenied else err;
    const owned = try query.TableSource.from(self.allocator, direct.connection, definition.value);
    return .{ .owned = owned, .definition = .{ .resource = binding.scope.resource, .source = .{ .table = owned.source } } };
}
/// The application contract binds its owner, resource, layout and state encoding.
/// Query declarations separately bind actually published catalog metadata.
pub fn contract(self: Self, table: u32) ![32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.work_items.contract.v1\x00");
    var ids: [32]u8 = undefined;
    std.mem.writeInt(u64, ids[0..8], self.configuration.application, .little);
    std.mem.writeInt(u64, ids[8..16], self.configuration.realm, .little);
    std.mem.writeInt(u64, ids[16..24], self.configuration.resource, .little);
    std.mem.writeInt(u64, ids[24..32], self.configuration.owner, .little);
    hash.update(&ids);
    hash.update(&try Table.schema(table).fingerprint());
    hash.update(&.{if (table == 1) 1 else 2});
    return hash.finalResult();
}
pub fn ledger(self: Self) !M {
    return .{ .configuration = .{ .application = self.configuration.application, .realm = self.configuration.realm, .administrator = self.configuration.administrator, .initial_epoch = .{ .value = 1 }, .initial_contract = try self.contract(1) }, .failure = if (self.failure) |failure| &failure.ledger else null };
}
pub fn proposal(self: Self, id: u32) !M.Proposal {
    if (id < 2) return error.InvalidWorkItemPlan;
    return .{ .plan = .{ .value = id }, .expected = .{ .value = 1 }, .next = .{ .value = 2 }, .transform = 1, .source = try self.contract(1), .target = try self.contract(id) };
}
pub fn initialize(self: Self, turn: *s.Turn) !void {
    try self.scope(turn);
    try (try self.ledger()).initialize(turn);
}
fn scope(self: Self, turn: *s.Turn) !void {
    if (turn.view.resource != self.configuration.resource or turn.delivery.pid != self.configuration.owner or turn.delivery.realm != self.configuration.realm) return error.WorkItemScopeChanged;
}
fn create(self: Self, turn: *s.Turn, table: u32, continuing: bool) !void {
    if (table == 0) return error.InvalidWorkItemPlan;
    const binding = try self.data(turn);
    const direct = try self.client(turn);
    const address = Create.keyFor(table);
    var pending = if (try turn.read(address)) |value| try app.Records.decode(Create, 't', value) else blk: {
        if (continuing) return error.InvalidWorkItemWork;
        const value: Create = .{ .input = turn.delivery.input.position, .table = table };
        try turn.write(address, try app.Records.encode('t', value));
        break :blk value;
    };
    if (pending.table != table) return error.InvalidWorkItemWork;
    if (pending.ready) return;
    // Only an already committed application declaration can freeze Table work.
    var committed = turn.committed();
    if (try committed.read(address) != null) {
        try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = pending.input, .principal = self.configuration.administrator } });
        if (try Data.inspect(self.allocator, &committed, self.configuration.application, self.configuration.owner, pending.input) == null) {
            const described = try direct.call(.describe);
            defer described.deinit();
            const namespace = try direct.call(.{ .namespace = binding.namespace });
            defer namespace.deinit();
            const registered = namespace.value.result.namespace orelse return error.WorkItemInitializationRequired;
            var prerequisite = try c.TableAuthority.guard(try turn.authorizationSubject(self.configuration.administrator), described.value.result.description.authority, registered, null, .create_table);
            prerequisite.selectable = binding.owner_role;
            prerequisite.requirements[2] = .{ .object = .{ .kind = .process, .id = self.configuration.owner }, .privileges = p.permission(.send) };
            _ = try turn.requireAuthorization(prerequisite);
            var intent = try Table.creation(self.allocator, direct, binding, table, pending.input, prerequisite);
            defer intent.deinit();
            try Data.prepare(self.allocator, turn, .{ .application = self.configuration.application, .resource = self.configuration.resource, .worker = self.configuration.owner, .input = pending.input, .table = table, .purpose = .create, .source_row = null, .reference = try direct.stage(&intent, binding.namespace) });
        } else switch (try Data.advance(self.allocator, turn, direct, self.configuration.application, pending.input, table, .create)) {
            .pending => {},
            .committed => {
                pending.ready = true;
                try turn.write(address, try app.Records.encode('t', pending));
                return;
            },
            .rejected, .cancelled => return error.WorkItemInitializationRequired,
        }
    }
    var bytes: [8]u8 = undefined;
    bytes[0..4].* = "WI1t".*;
    std.mem.writeInt(u32, bytes[4..8], table, .little);
    try turn.cast(turn.delivery.pid, try p.Value.init(&bytes));
}
const Create = struct {
    input: u64,
    table: u32,
    ready: bool = false,
    fn keyFor(table: u32) p.Value {
        var bytes: [8]u8 = undefined;
        bytes[0..4].* = "\x00WIC".*;
        std.mem.writeInt(u32, bytes[4..], table, .big);
        return p.Value.init(&bytes) catch unreachable;
    }
};
pub const TableBasis = struct {
    interpretation: p.DataLifecycle.Definition,
    position: p.DataLifecycle.Position,
    rows: u64,
    pub fn from(value: c.DirectTableProtocol.Definition) TableBasis {
        return .{ .interpretation = value.interpretation.interpretation, .position = value.position, .rows = value.row_count };
    }
    pub fn require(self: TableBasis, value: c.DirectTableProtocol.Definition) !void {
        if (!std.meta.eql(self.interpretation, value.interpretation.interpretation)) return error.WorkItemEpochChanged;
        if (self.rows != value.row_count or !self.position.unchangedAt(value.position, value.changed_lsn)) return error.WorkItemSourceChanged;
    }
};
pub const MigrationBasis = struct {
    definition: [32]u8,
    source: TableBasis,
    target: TableBasis,
    fn keyFor(plan: u64) p.Value {
        var bytes: [12]u8 = undefined;
        bytes[0..4].* = "\x00WIB".*;
        std.mem.writeInt(u64, bytes[4..], plan, .big);
        return p.Value.init(&bytes) catch unreachable;
    }
    fn read(reader: anytype, plan: u64) !MigrationBasis {
        const value = try app.Records.decode(MigrationBasis, 'b', (try reader.read(keyFor(plan))) orelse return error.WorkItemStateMissing);
        if (!std.mem.eql(u8, &value.definition, &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        return value;
    }
};
/// The independent source and target bases verified by migration progress.
/// This metadata does not retain rows or assert a cross-Table atomic snapshot.
pub fn migrationBasis(self: Self, reader: anytype, plan: Wide) !?MigrationBasis {
    if (try (try self.ledger()).plan(reader, plan) == null) return null;
    return try MigrationBasis.read(reader, plan.value);
}
fn tableGuard(self: Self, turn: *s.Turn, authority: c.DirectReadAuthority, principal: u64, privileges: u64) !p.Authorization.Guard {
    var required = try authority.guard(try turn.authorizationSubject(principal));
    required.requirements[2].?.privileges |= privileges;
    required.requirements[3] = .{ .object = .{ .kind = .process, .id = self.configuration.owner }, .privileges = p.permission(.send) };
    _ = turn.requireAuthorization(required) catch |err| return if (err == error.AccessDenied) error.CatalogDenied else err;
    return required;
}
pub fn selected(self: Self, turn: anytype) !u32 {
    const head = try (try self.ledger()).head(turn);
    if (head.epoch.value == 1) return 1;
    const state = try app.Records.decode(Active, 'a', (try turn.read(active_table)) orelse return error.WorkItemStateMissing);
    if (state.table < 2) return error.WorkItemStateMissing;
    return state.table;
}
pub fn execute(self: Self, turn: *s.Turn, command: Command) !void {
    try self.scope(turn);
    if (turn.delivery.input.origin != .external) return error.WorkItemDenied;
    switch (command) {
        .initialize, .catalog_initialize, .prepare_table => if (turn.delivery.input.origin.external.principal != self.configuration.administrator) return error.WorkItemDenied,
        else => {},
    }
    const owner = try self.ledger();
    const before = turn.decision;
    errdefer turn.decision = before;
    switch (command) {
        .initialize => try self.initialize(turn),
        .catalog_initialize => |binding| {
            _ = try owner.head(turn);
            try binding.validate();
            if (binding.scope.realm != self.configuration.realm) return error.CatalogScopeChanged;
            const encoded = try app.Records.encode('d', binding);
            if (try turn.read(data_binding)) |existing| {
                if (!existing.eql(encoded)) return error.CatalogConfigurationChanged;
            } else {
                const direct = try (self.transport orelse return error.WorkItemDataUnavailable).bind(binding);
                const namespace = try direct.call(.{ .namespace = binding.namespace });
                defer namespace.deinit();
                if (namespace.value.result.namespace == null) return error.WorkItemInitializationRequired;
                try turn.write(data_binding, encoded);
            }
        },
        .prepare_table => |table| try self.create(turn, table, false),
        .policy => |value| try owner.setPolicy(turn, value.principal, value.expected, value.next),
        .put => |value| {
            if (turn.delivery.input.origin.external.principal != self.configuration.writer) return error.WorkItemDenied;
            const head = try owner.head(turn);
            if (head.active.value != 0) {
                self.rememberEpoch(value.epoch, head, null);
                return error.WorkItemMigrationPaused;
            }
            if (head.epoch.value != value.epoch.value) {
                self.rememberEpoch(value.epoch, head, null);
                return error.WorkItemEpochChanged;
            }
            if (head.epoch.value != 1 and !(try app.Records.decode(Active, 'a', (try turn.read(active_table)) orelse return error.WorkItemStateMissing)).writes) {
                self.rememberEpoch(value.epoch, head, null);
                return error.WorkItemPublicationPaused;
            }
            if (value.state != (if (head.epoch.value == 1) @as(i64, 0) else 10) and value.state != (if (head.epoch.value == 1) @as(i64, 1) else 20)) {
                self.remember(.{ .state = .{ .epoch = head.epoch, .key = value.id, .value = value.state } });
                return error.InvalidWorkItemState;
            }
            const table = try self.selected(turn);
            const prepared = try app.Records.decode(Create, 't', (try turn.read(Create.keyFor(table))) orelse return error.WorkItemInitializationRequired);
            if (!prepared.ready) return error.WorkItemInitializationRequired;
            const pending: Put = .{ .input = turn.delivery.input.position, .principal = turn.delivery.input.origin.external.principal, .table = table, .key = value.id, .state = value.state };
            try turn.write(Put.keyFor(pending.input), try app.Records.encode('w', pending));
            try turn.cast(turn.delivery.pid, put_continue);
        },
        .begin => |value| {
            if (value.plan.value < 2 or value.plan.value > std.math.maxInt(u32) or !std.meta.eql(value, try self.proposal(@intCast(value.plan.value)))) return error.InvalidWorkItemPlan;
            _ = try owner.authorize(turn);
            const exists = try owner.plan(turn, value.plan) != null;
            if (!exists) {
                if (try firstPut(turn) != null) return error.WorkItemWritesPending;
                const binding = try self.data(turn);
                const direct = try self.client(turn);
                var source_table = try Table.definition(direct, binding, 1);
                defer source_table.deinit();
                var target = try Table.definition(direct, binding, @intCast(value.plan.value));
                defer target.deinit();
                const principal = turn.delivery.input.origin.external.principal;
                _ = try self.tableGuard(turn, source_table.authority, principal, 0);
                _ = try self.tableGuard(turn, target.authority, principal, c.TableAuthority.insert);
                if (target.value.row_count != 0) {
                    self.remember(.{ .target = @intCast(value.plan.value) });
                    return error.TableExists;
                }
                try turn.write(MigrationBasis.keyFor(value.plan.value), try app.Records.encode('b', MigrationBasis{ .definition = p.Growth.definition_bytes, .source = .from(source_table.value), .target = .from(target.value) }));
            }
            _ = try owner.begin(turn, value);
        },
        .step => |value| try self.migrate(turn, value, false),
        .abandon => |value| _ = try owner.abandon(turn, value),
        .release_writes => |value| {
            if (turn.delivery.input.origin.external.principal != self.configuration.administrator) return error.WorkItemDenied;
            const head = try owner.head(turn);
            if (head.epoch.value != value.epoch.value or head.epoch.value != 2 or head.active.value != 0 or !std.mem.eql(u8, &head.contract, &value.contract)) {
                self.rememberEpoch(value.epoch, head, value.contract);
                return error.WorkItemEpochChanged;
            }
            var state = try app.Records.decode(Active, 'a', (try turn.read(active_table)) orelse return error.WorkItemStateMissing);
            if (state.writes) return;
            state.writes = true;
            try turn.write(active_table, try app.Records.encode('a', state));
        },
    }
}
fn validateStep(self: Self, progress: M.Progress, step: M.Step) !Cursor {
    if (!step.arguments.eql(progress.cursor)) {
        self.remember(Failure.cursor(progress.cursor, step.arguments));
        return error.WorkItemCursorChanged;
    }
    const cursor = try Cursor.decode(progress.cursor);
    if (step.operation == 2) {
        if (cursor.phase != .ready or cursor.copied != cursor.verified) {
            self.remember(.{ .verification = .{ .phase = cursor.phase, .copied = cursor.copied, .verified = cursor.verified } });
            return error.WorkItemVerificationIncomplete;
        }
    } else if (step.operation != 1 or cursor.phase == .ready) {
        self.remember(.{ .verification = .{ .phase = cursor.phase, .copied = cursor.copied, .verified = cursor.verified } });
        return error.InvalidWorkItemStep;
    }
    return cursor;
}
fn migrate(self: Self, turn: *s.Turn, step: M.Step, continuing: bool) !void {
    const owner = try self.ledger();
    if (!continuing) {
        // Reject application syntax/cursors before freezing a valid new step.
        // The shared ledger owns every authority, ordinal and digest rejection.
        const principal = turn.delivery.input.origin.external.principal;
        if (try owner.policy(turn, principal)) |policy| if (policy.migrate) {
            if (try owner.plan(turn, step.plan)) |plan| if (plan.principal == principal) {
                const progress = try owner.progress(turn, step.plan);
                const head = try owner.head(turn);
                if (head.active.value == step.plan.value and progress.phase == .active and progress.next.value == step.ordinal.value and try owner.pending(turn, step) == null and try owner.receipt(turn, step) == null) _ = try self.validateStep(progress, step);
            };
        };
    }
    const result = if (continuing) try owner.continueStage(turn, step, self) else try owner.stage(turn, step, self);
    if (result == null) try turn.cast(turn.delivery.pid, try (Command{ .step = step }).encode());
}
pub fn stage(self: Self, turn: *s.Turn, plan: M.Plan, progress: M.Progress, pending: M.Pending) !?M.Transition {
    var cursor = try self.validateStep(progress, pending.step);
    const target: u32 = @intCast(plan.proposal.plan.value);
    try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = pending.input, .principal = plan.principal } });
    const binding = try self.data(turn);
    const direct = try self.client(turn);
    var cuts = try MigrationBasis.read(turn, target);
    var committed = turn.committed();
    // Recover already eligible work before reading its now-changed target.
    // Native progress loss must not invalidate this operation's own acceptance.
    if (cursor.phase == .copy) if (try Data.inspect(self.allocator, &committed, self.configuration.application, self.configuration.owner, pending.input)) |record| {
        if (!std.meta.eql(record.reference.binding.expected_definition, @as(?p.DataLifecycle.Definition, cuts.target.interpretation)) or
            !std.meta.eql(record.reference.binding.expected_data, @as(?p.DataLifecycle.Position, cuts.target.position))) return error.InvalidWorkItemWork;
        switch (try Data.advance(self.allocator, turn, direct, self.configuration.application, pending.input, target, .copy)) {
            .pending => return null,
            .committed => |evidence| {
                if (evidence.outcome.matched != 1 or evidence.outcome.affected != 1 or evidence.outcome.live_rows != try std.math.add(u64, cuts.target.rows, 1)) return error.WorkItemVerificationFailed;
                const after = record.source_row orelse return error.InvalidWorkItemWork;
                if (cursor.has_after and std.mem.order(u8, &try cursor.after.encode(), &try after.encode()) != .lt) return error.InvalidWorkItemWork;
                cursor.copied = try std.math.add(u64, cursor.copied, 1);
                if (cursor.copied > cuts.source.rows) return error.WorkItemVerificationFailed;
                cursor.has_after = true;
                cursor.after = after;
                cuts.target.position = evidence.outcome.position;
                cuts.target.rows = evidence.outcome.live_rows;
                try turn.write(MigrationBasis.keyFor(target), try app.Records.encode('b', cuts));
                return .{ .advance = try cursor.encode() };
            },
            .rejected, .cancelled => return error.WorkItemVerificationFailed,
        }
    };
    var source_table = try Table.definition(direct, binding, 1);
    defer source_table.deinit();
    var target_table = try Table.definition(direct, binding, target);
    defer target_table.deinit();
    try cuts.source.require(source_table.value);
    try cuts.target.require(target_table.value);
    _ = try self.tableGuard(turn, source_table.authority, plan.principal, 0);
    _ = try self.tableGuard(turn, target_table.authority, plan.principal, c.TableAuthority.insert);
    if (pending.step.operation == 2) {
        if (cursor.copied != cuts.source.rows or cursor.verified != cuts.target.rows) return error.WorkItemVerificationFailed;
        try turn.write(active_table, try app.Records.encode('a', Active{ .table = target, .writes = false }));
        return .{ .activate = {} };
    }
    const next_row = try Table.next(self.allocator, direct, if (cursor.phase == .copy) source_table.value else target_table.value, if (cursor.phase == .copy) cuts.source.position else cuts.target.position, if (cursor.has_after) cursor.after else null);
    if (next_row) |value| {
        if (cursor.phase == .copy) {
            const proposed: Table.Row = .{ .identity = value.identity, .key = value.key, .state = try translate(value.state) };
            var intent = try Table.mutation(self.allocator, direct, target_table.value, cuts.target.position, pending.input, proposed, true, turn.decision.authorization.?);
            defer intent.deinit();
            try Data.prepare(self.allocator, turn, .{ .application = self.configuration.application, .resource = self.configuration.resource, .worker = self.configuration.owner, .input = pending.input, .table = target, .purpose = .copy, .source_row = value.identity, .reference = try direct.stage(&intent, binding.namespace) });
            return null;
        }
        const original = (try Table.get(self.allocator, direct, source_table.value, cuts.source.position, value.key)) orelse return error.WorkItemVerificationFailed;
        if (value.state != try translate(original.state)) return error.WorkItemVerificationFailed;
        cursor.verified = try std.math.add(u64, cursor.verified, 1);
        cursor.has_after = true;
        cursor.after = value.identity;
    } else {
        if (cursor.phase == .copy and cursor.copied != cuts.source.rows) return error.WorkItemVerificationFailed;
        cursor.phase = if (cursor.phase == .copy) .verify else .ready;
        cursor.has_after = false;
        cursor.after = .{ .origin = 0, .operation = 0, .ordinal = 0 };
        if (cursor.phase == .ready and (cursor.copied != cursor.verified or cursor.verified != cuts.target.rows)) return error.WorkItemVerificationFailed;
    }
    return .{ .advance = try cursor.encode() };
}
fn translate(value: i64) !i64 {
    return switch (value) {
        0 => 10,
        1 => 20,
        else => error.WorkItemSourceInvalid,
    };
}
const put_continue = p.Value.init("WI1p") catch unreachable;
const put_prefix = "\x00work-items.put/";
const Put = struct {
    input: u64,
    principal: u64,
    table: u32,
    key: i64,
    state: i64,
    fn keyFor(input: u64) p.Value {
        var bytes: [put_prefix.len + 8]u8 = undefined;
        @memcpy(bytes[0..put_prefix.len], put_prefix);
        std.mem.writeInt(u64, bytes[put_prefix.len..], input, .big);
        return p.Value.init(&bytes) catch unreachable;
    }
};
fn firstPut(turn: *s.Turn) !?Put {
    var reader = turn.committed();
    const page = try reader.page(try p.Value.init(put_prefix));
    const entry = page.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, entry.key.slice(), put_prefix)) return null;
    const pending = try app.Records.decode(Put, 'w', entry.value);
    if (!entry.key.eql(Put.keyFor(pending.input))) return error.InvalidWorkItemWork;
    return pending;
}
fn put(self: Self, turn: *s.Turn) !void {
    const pending = (try firstPut(turn)) orelse return;
    if (pending.principal != self.configuration.writer) return error.WorkItemDenied;
    try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = pending.input, .principal = pending.principal } });
    const binding = try self.data(turn);
    const direct = try self.client(turn);
    var committed = turn.committed();
    if (try Data.inspect(self.allocator, &committed, self.configuration.application, self.configuration.owner, pending.input) == null) {
        var selected_table = try Table.definition(direct, binding, pending.table);
        defer selected_table.deinit();
        _ = try self.tableGuard(turn, selected_table.authority, pending.principal, 0);
        const previous = try Table.get(self.allocator, direct, selected_table.value, selected_table.value.position, pending.key);
        const prerequisite = try self.tableGuard(turn, selected_table.authority, pending.principal, if (previous == null) c.TableAuthority.insert else c.TableAuthority.update);
        const identity = if (previous) |value| value.identity else try c.DirectTableProtocol.Rows.insertIdentity(.{ .scope = direct.connection.scope, .principal = direct.connection.principal, .operation = pending.input }, 0);
        var intent = try Table.mutation(self.allocator, direct, selected_table.value, selected_table.value.position, pending.input, .{ .identity = identity, .key = pending.key, .state = pending.state }, previous == null, prerequisite);
        defer intent.deinit();
        try Data.prepare(self.allocator, turn, .{ .application = self.configuration.application, .resource = self.configuration.resource, .worker = self.configuration.owner, .input = pending.input, .table = pending.table, .purpose = .put, .source_row = null, .reference = try direct.stage(&intent, binding.namespace) });
    } else switch (try Data.advance(self.allocator, turn, direct, self.configuration.application, pending.input, pending.table, .put)) {
        .pending => {},
        .committed => |evidence| {
            if (evidence.outcome.matched != 1) return error.WorkItemVerificationFailed;
            try turn.write(Put.keyFor(pending.input), null);
        },
        .rejected, .cancelled => return error.WorkItemVerificationFailed,
    }
    try turn.cast(turn.delivery.pid, put_continue);
}
/// Inspect domain completion only after observing that the original native input
/// was consumed and checking its separate rejected-input disposition.
pub fn completed(self: Self, reader: anytype, command: Command, input: u64) !bool {
    return switch (command) {
        .put => !try putPending(reader, input),
        .prepare_table => |table| value: {
            const prepared = try app.Records.decode(Create, 't', (try reader.read(Create.keyFor(table))) orelse break :value false);
            if (!prepared.ready) break :value false;
            var definition = self.source(reader, self.configuration.administrator, table) catch |err| {
                if (err == error.WorkItemInitializationRequired) break :value false;
                return err;
            };
            defer definition.deinit();
            break :value true;
        },
        .step => |step| value: {
            const owner = try self.ledger();
            if (try owner.receipt(reader, step) != null) break :value true;
            if ((try owner.progress(reader, step.plan)).phase != .active) return error.MigrationNotActive;
            const plan = (try owner.plan(reader, step.plan)) orelse return error.MigrationPlanAbsent;
            const policy = (try owner.policy(reader, plan.principal)) orelse return error.MigrationDenied;
            if (!policy.migrate) return error.MigrationDenied;
            break :value false;
        },
        else => true,
    };
}
pub fn putPending(reader: anytype, input: u64) !bool {
    return try reader.read(Put.keyFor(input)) != null;
}
pub fn dispositionKey(application: u64, principal: u64, input: u64) p.Value {
    var key = app.Records.key(application, 'e', principal, input);
    key.data[1] = 'W';
    return key;
}
pub fn witnessKey(application: u64, principal: u64, input: u64) p.Value {
    var key = dispositionKey(application, principal, input);
    key.data[10] = 'f';
    return key;
}
pub const Behavior = struct {
    owner: Self,
    capture: ?query.UnifiedBehavior.Source = null,
    pub fn interface(self: *@This()) s.GenServer.Handler {
        return .{ .context = self, .initialize = init, .handle = handle };
    }
    pub fn guard(self: *@This()) s.GenServer.InputGuard {
        return .{ .context = self, .reject = reject };
    }
    fn get(raw: ?*anyopaque) *@This() {
        return @ptrCast(@alignCast(raw.?));
    }
    fn init(raw: ?*anyopaque, turn: *s.Turn) !void {
        try get(raw).owner.initialize(turn);
    }
    fn disposition(self: *@This(), turn: *s.Turn, reason: []const u8) !void {
        return self.dispositionContext(turn, reason, null, .{});
    }
    fn dispositionContext(self: *@This(), turn: *s.Turn, reason: []const u8, command: ?Command, context: Failure.Context) !void {
        const principal = if (turn.delivery.input.origin == .external) turn.delivery.input.origin.external.principal else 0;
        const plan: Wide = if (command) |cmd| switch (cmd) {
            .begin => |proposal_value| proposal_value.plan,
            .step => |step| step.plan,
            .abandon => |id| id,
            else => .{},
        } else .{};
        const ordinal: Wide = if (command) |cmd| if (cmd == .step) cmd.step.ordinal else .{} else .{};
        const operation: u16 = if (command) |cmd| if (cmd == .step) cmd.step.operation else 0 else 0;
        const record = try app.MigrationFailure.capture(turn, reason, plan, ordinal, operation);
        try turn.write(dispositionKey(self.owner.configuration.application, principal, turn.delivery.input.position), try app.Records.encode('e', record));
        const witness: Failure.Witness = context.domain orelse .{ .ledger = context.ledger };
        try turn.write(witnessKey(self.owner.configuration.application, principal, turn.delivery.input.position), try app.Records.encode('f', witness));
    }
    fn reject(raw: ?*anyopaque, turn: *s.Turn) anyerror!bool {
        const self = get(raw);
        const frame = s.Frame.decode(turn.delivery.input.value) catch {
            try self.disposition(turn, "InvalidWorkItemFrame");
            return true;
        };
        if (frame.kind == .cast and turn.delivery.input.origin == .process and turn.delivery.input.origin.process.pid == turn.delivery.pid and
            (frame.payload.eql(put_continue) or (frame.payload.len == 8 and std.mem.eql(u8, frame.payload.data[0..4], "WI1t")) or (std.mem.startsWith(u8, frame.payload.slice(), "WI1i") and (Command.decode(frame.payload) catch return error.InvalidWorkItemCommand) == .step))) return false;
        if (self.capture != null and !std.mem.startsWith(u8, frame.payload.slice(), "WI1i")) {
            // Public send permission does not authorize arbitrary query control
            // on this data owner. Internal calls still use the shared peer and
            // correlation checks; external ingress admits only scoped policy.
            if (turn.delivery.input.origin == .external and
                (frame.kind != .cast or turn.delivery.input.origin.external.principal != self.owner.configuration.administrator or !std.mem.startsWith(u8, frame.payload.slice(), "UQA1")))
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
    fn handle(raw: ?*anyopaque, turn: *s.Turn, frame: s.Frame) anyerror!void {
        const self = get(raw);
        try self.dispatch(turn, frame);
    }
    fn dispatch(self: *Behavior, turn: *s.Turn, frame: s.Frame) anyerror!void {
        if (frame.kind == .cast and turn.delivery.input.origin == .process and turn.delivery.input.origin.process.pid == turn.delivery.pid) {
            const before = turn.decision;
            errdefer turn.decision = before;
            try self.owner.scope(turn);
            if (frame.payload.eql(put_continue)) return self.owner.put(turn);
            if (frame.payload.len == 8 and std.mem.eql(u8, frame.payload.data[0..4], "WI1t")) return self.owner.create(turn, std.mem.readInt(u32, frame.payload.data[4..8], .little), true);
            if (std.mem.startsWith(u8, frame.payload.slice(), "WI1i")) {
                const command = try Command.decode(frame.payload);
                if (command != .step) return error.WorkItemDenied;
                self.owner.migrate(turn, command.step, true) catch |err| {
                    if (turn.read_error != null or (err != error.MigrationDenied and err != error.MigrationNotActive)) return err;
                    // The retained step remains pending/abandoned. A later exact
                    // external step can resume after current policy restoration.
                    turn.decision = before;
                };
                return;
            }
        }
        if (self.capture) |*capture| {
            if (!std.mem.startsWith(u8, frame.payload.slice(), "WI1i")) {
                const direct = try self.owner.client(turn);
                if (direct.connection.principal != capture.resources.principal or direct.connection.scope.realm != capture.resources.realm) return error.WorkItemScopeChanged;
                // Capture authenticates the executor's login and uses the
                // original caller's retained delegation. The role selected
                // for application mutations does not authorize query reads.
                var executor = direct.connection;
                executor.role = null;
                capture.tables = .{ .allocator = self.owner.allocator, .authority = capture.resources.wire, .service = capture.resources.wire, .connection = executor, .key = capture.resources.key };
                const handler = capture.interface();
                if (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "UQA1")) {
                    if (turn.delivery.input.origin != .external or turn.delivery.input.origin.external.principal != self.owner.configuration.administrator) return self.disposition(turn, "WorkItemDenied");
                    const policy = query.UnifiedRecords.Policy.decode(frame.payload) catch return self.disposition(turn, "InvalidWorkItemQueryPolicy");
                    if (policy.peer != capture.peer) return self.disposition(turn, "InvalidWorkItemQueryPolicy");
                    var table_source = try self.owner.source(turn, self.owner.configuration.administrator, try self.owner.selected(turn));
                    defer table_source.deinit();
                    const expected = table_source.definition.source.table;
                    if (policy.target != .catalog or !std.meta.eql(policy.target.catalog.scope, expected.scope) or policy.target.catalog.owner != expected.owner) return self.disposition(turn, "WorkItemEpochChanged");
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
        const command = try Command.decode(frame.payload);
        var context: Failure.Context = .{};
        var owner_value = self.owner;
        owner_value.failure = &context;
        owner_value.execute(turn, command) catch |err| {
            turn.decision = before;
            if (turn.read_error != null or !requestError(err)) return err;
            try self.dispositionContext(turn, @errorName(err), command, context);
        };
    }
};
fn requestError(err: anyerror) bool {
    // The finite domain map excludes infrastructure, corruption and transform
    // failures. Those leave the input unresolved and preserve its original work.
    return Failure.classification(@errorName(err)) != null;
}

test {
    _ = @import("work_items_test.zig");
}

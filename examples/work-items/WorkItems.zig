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
const Self = @This();
pub const Configuration = struct { application: u64, realm: u64, administrator: u64, writer: u64, resource: u64, owner: u64 };
pub const Failure = @import("WorkItemFailure.zig");
allocator: std.mem.Allocator,
configuration: Configuration,
failure: ?*Failure.Context = null,
registration: ?*?p.Authorization.Action = null,
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
    catalog_initialize: c.TableAuthority.Profile = 7,
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
        return app.Records.decode(Command, 'i', encoded) catch error.InvalidWorkItemCommand;
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
/// Installation allocates native identities before catalog authorization exists.
/// The administrator explicitly initializes the catalog with registered objects;
/// subsequent activations read that retained configuration without reprovisioning.
pub fn catalogConfiguration(self: Self, authority: c.TableAuthority.Profile) c.TableCatalogRecords.Configuration {
    return .{ .scope = .{ .realm = self.configuration.realm, .resource = self.configuration.resource, .catalog = 1 }, .owner = self.configuration.owner, .administrator = self.configuration.administrator, .database_name = c.TableAuthority.Name.init("work_items") catch unreachable, .authority = authority, .table_limits = Table.limits };
}
pub fn catalog(self: Self, reader: anytype) !c.TableCatalog {
    const stored = try c.Records.decode(c.TableCatalogRecords.Configuration, 'C', (try reader.read(c.Records.key(1, 'c', 0, 0))) orelse return error.WorkItemInitializationRequired);
    try stored.validate();
    if (!std.meta.eql(stored, self.catalogConfiguration(stored.authority))) return error.CatalogConfigurationChanged;
    return .{ .configuration = stored, .registration = self.registration };
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
    const catalog_value = try self.catalog(reader);
    var definition = (try catalog_value.lookup(self.allocator, reader, principal, try Table.name(table))) orelse return error.WorkItemInitializationRequired;
    defer definition.deinit();
    if (!std.mem.eql(u8, &try definition.schema.schema.fingerprint(), &try Table.schema(table).fingerprint())) return error.WorkItemEpochChanged;
    _ = try catalog_value.authorizeObject(reader, principal, definition.metadata.object, .read);
    const owned = try query.TableSource.from(self.allocator, catalog_value.configuration, definition);
    return .{ .owned = owned, .definition = .{ .resource = self.configuration.resource, .source = .{ .table = owned.source } } };
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
    const request: c.TableDdlRequest = .{ .principal = self.configuration.administrator, .operation = table, .object = table, .expected_revision = 0, .name = try Table.name(table), .action = .{ .create = .{ .schema = Table.schema(table) } } };
    const catalog_value = try self.catalog(turn);
    const outcome = if (continuing) try catalog_value.continueDdl(self.allocator, turn, request) else try catalog_value.step(self.allocator, turn, request);
    if (outcome.terminal()) {
        if (outcome.operation.state != .applied) return error.WorkItemInitializationRequired;
    } else {
        var bytes: [8]u8 = undefined;
        bytes[0..4].* = "WI1t".*;
        std.mem.writeInt(u32, bytes[4..8], table, .little);
        try turn.cast(turn.delivery.pid, try p.Value.init(&bytes));
    }
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
        .catalog_initialize => |authority| {
            _ = try owner.head(turn);
            try (c.TableCatalog{ .configuration = self.catalogConfiguration(authority) }).initialize(turn);
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
            _ = s.TableHead.load(turn, table) catch |err| return if (err == error.TableNotFound) error.WorkItemInitializationRequired else err;
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
                const target = s.TableHead.load(turn, value.plan.value) catch |err| return if (err == error.TableNotFound) error.WorkItemInitializationRequired else err;
                if (target.rows != 0 or target.pending != 0 or target.retired) {
                    self.remember(.{ .target = @intCast(value.plan.value) });
                    return error.TableExists;
                }
                var stored = try target.readSchema(self.allocator, turn);
                defer stored.deinit();
                if (!std.mem.eql(u8, &try stored.schema.fingerprint(), &try Table.schema(@intCast(value.plan.value)).fingerprint())) return error.InvalidWorkItemPlan;
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
    const tables = try self.catalog(turn);
    _ = try tables.authorizeObject(turn, plan.principal, 1, .read);
    _ = try tables.authorizeObject(turn, plan.principal, target, .read);
    _ = try tables.authorizeObject(turn, plan.principal, target, .insert);
    if (pending.step.operation == 2) {
        try turn.write(active_table, try app.Records.encode('a', Active{ .table = target, .writes = false }));
        return .{ .activate = {} };
    }
    const next_row = try Table.next(self.allocator, turn, if (cursor.phase == .copy) 1 else target, if (cursor.has_after) cursor.after else null);
    if (next_row) |row| {
        if (cursor.phase == .copy) {
            const value: Table.Row = .{ .identity = .{ .origin = plan.principal + 1, .operation = pending.input, .ordinal = 0 }, .key = row.key, .state = try translate(row.state) };
            const result = try Table.write(self.allocator, turn, target, plan.principal, pending.input, value, true, pending.digest, 2);
            if (result.state == .building) return null;
            if (result.state != .applied or result.matched != 1) return error.WorkItemVerificationFailed;
            cursor.copied = try std.math.add(u64, cursor.copied, 1);
        } else {
            const original = (try Table.get(self.allocator, turn, 1, row.key)) orelse return error.WorkItemVerificationFailed;
            if (row.state != try translate(original.state)) return error.WorkItemVerificationFailed;
            cursor.verified = try std.math.add(u64, cursor.verified, 1);
        }
        cursor.has_after = true;
        cursor.after = row.identity;
    } else {
        cursor.phase = if (cursor.phase == .copy) .verify else .ready;
        cursor.has_after = false;
        cursor.after = .{ .origin = 0, .operation = 0, .ordinal = 0 };
        if (cursor.phase == .ready and cursor.copied != cursor.verified) return error.WorkItemVerificationFailed;
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
    prepared: bool = false,
    insert: bool = false,
    identity: Table.Identity = .{ .origin = 0, .operation = 0, .ordinal = 0 },
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
    var pending = (try firstPut(turn)) orelse return;
    if (pending.principal != self.configuration.writer) return error.WorkItemDenied;
    try turn.bindAuthorizationSubject(.{ .accepted = .{ .pid = self.configuration.owner, .input = pending.input, .principal = pending.principal } });
    const tables = try self.catalog(turn);
    _ = try tables.authorizeObject(turn, pending.principal, pending.table, .read);
    if (!pending.prepared) {
        const previous = try Table.get(self.allocator, turn, pending.table, pending.key);
        pending.identity = if (previous) |value| value.identity else .{ .origin = pending.principal + 1, .operation = pending.input, .ordinal = 0 };
        pending.insert = previous == null;
        pending.prepared = true;
        _ = try tables.authorizeObject(turn, pending.principal, pending.table, if (pending.insert) .insert else .update);
        try turn.write(Put.keyFor(pending.input), try app.Records.encode('w', pending));
    } else {
        _ = try tables.authorizeObject(turn, pending.principal, pending.table, if (pending.insert) .insert else .update);
        const result = try Table.write(self.allocator, turn, pending.table, pending.principal, pending.input, .{ .identity = pending.identity, .key = pending.key, .state = pending.state }, pending.insert, try self.contract(pending.table), 1);
        if (result.state != .building) {
            if (result.state != .applied or result.matched != 1) return error.WorkItemVerificationFailed;
            try turn.write(Put.keyFor(pending.input), null);
        }
    }
    try turn.cast(turn.delivery.pid, put_continue);
}
/// Inspect domain completion only after observing that the original native input
/// was consumed and checking its separate rejected-input disposition.
pub fn completed(self: Self, reader: anytype, command: Command, input: u64) !bool {
    return switch (command) {
        .put => !try putPending(reader, input),
        .prepare_table => |table| value: {
            const head = s.TableHead.load(reader, table) catch |err| {
                if (err == error.TableNotFound) break :value false;
                return err;
            };
            if (head.retired) return error.WorkItemInitializationRequired;
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
    registration: ?p.Authorization.Action = null,
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
        self.registration = null;
        self.owner.registration = &self.registration;
        self.dispatch(turn, frame) catch |err| {
            // Registration precedes catalog publication. Leave the original
            // input unresolved while the host completes the native handshake.
            if (err == error.CatalogRegistrationRequired) turn.read_error = err;
            return err;
        };
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

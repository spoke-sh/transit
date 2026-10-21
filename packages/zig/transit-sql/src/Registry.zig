//! Bounded logical sessions. Registry locks protect identities/admission only;
//! each session has one native-client borrower, independent of its HTTP sockets.
const std = @import("std");
const g = @import("root.zig");
const api = g.session_protocol;
const f = g.fuze;
const Self = @This();
allocator: std.mem.Allocator,
io: std.Io,
configuration: *const g.Configuration,
runtimes: []const *g.AccountRuntime,
instance: api.Instance,
mutex: std.Io.Mutex = .init,
slots: []Slot,
challenges: [16]?Challenge = @splat(null),
authenticating: std.atomic.Value(u16) = .init(0),
recovery_index: usize = 0,
recovery_after: [g.Limits.max_accounts]u64 = @splat(0),
pub const Peer = struct { uid: ?u32 = null, loopback: bool = false, tls: bool = false };
const Challenge = struct { id: api.Id, account: usize, database: []const u8, source: ?[]const u8, credential: g.Configuration.Credential, scram: g.Authentication.Scram, started: std.Io.Timestamp };
const Statement = struct { id: api.Id, prepared: *g.Session.Prepared };
const Cursor = struct {
    id: api.Id,
    prepared: *g.Session.Prepared,
    owned: bool,
    read: ?*g.Session.Read,
    arena: std.heap.ArenaAllocator,
    batch_arena: std.heap.ArenaAllocator,
    batch: api.Batch = undefined,
};
pub const Slot = struct {
    present: bool = false,
    native: bool = true,
    opening: bool = false,
    id: api.Id = @splat(0),
    account: usize = 0,
    mutex: std.Io.Mutex = .init,
    cancellation: std.atomic.Value(bool) = .init(false),
    active: std.atomic.Value(bool) = .init(false),
    memory: g.query.QueryMemory = undefined,
    host: ?*g.Session = null,
    last: std.Io.Timestamp = .{ .nanoseconds = 0 },
    // Protected by Registry.mutex. Independent controls borrow immutable
    // identity, and keep this slot from expiring or being reused until joined.
    controls: u16 = 0,
    statements: [api.max_prepared]?Statement = @splat(null),
    cursor: ?Cursor = null,
    fn clearCursor(self: *Slot) void {
        const cursor = if (self.cursor) |*value| value else return;
        if (cursor.read) |read| self.host.?.closeRead(read);
        if (cursor.owned) self.host.?.destroy(cursor.prepared);
        cursor.batch_arena.deinit();
        cursor.arena.deinit();
        self.cursor = null;
    }
    fn clear(self: *Slot) void {
        self.clearCursor();
        for (&self.statements) |*entry| if (entry.*) |value| {
            self.host.?.destroy(value.prepared);
            entry.* = null;
        };
        if (self.host) |host| host.deinit();
        self.host = null;
        std.debug.assert(self.memory.used == 0);
        std.crypto.secureZero(u8, &self.id);
    }
};
pub fn init(allocator: std.mem.Allocator, io: std.Io, configuration: *const g.Configuration, runtimes: []const *g.AccountRuntime, instance: api.Instance) !Self {
    const slots = try allocator.alloc(Slot, configuration.limits.connections);
    for (slots) |*slot| slot.* = .{};
    return .{ .allocator = allocator, .io = io, .configuration = configuration, .runtimes = runtimes, .instance = instance, .slots = slots };
}
/// The supervisor joins every listener/borrower before releasing the registry.
pub fn deinit(self: *Self) void {
    for (self.slots) |*slot| if (slot.present) slot.clear();
    for (&self.challenges) |*challenge| if (challenge.*) |*value| value.scram.deinit();
    self.allocator.free(self.slots);
}
pub fn acquireAuthentication(self: *Self) bool {
    var count = self.authenticating.load(.monotonic);
    while (count < self.configuration.limits.authentications) count = self.authenticating.cmpxchgWeak(count, count + 1, .acquire, .monotonic) orelse return true;
    return false;
}
pub fn releaseAuthentication(self: *Self) void {
    std.debug.assert(self.authenticating.fetchSub(1, .release) > 0);
}
fn locate(self: *Self, id: api.Id) !*Slot {
    for (self.slots) |*slot| if (slot.present and !slot.opening and slot.native and std.crypto.timing_safe.eql(api.Id, slot.id, id)) return slot;
    return error.SqlSessionExpired;
}
/// Returns a locked slot, including for a wire connection. All adapters consume
/// the same total/per-account admission budget and the same AccountRuntime.
pub fn create(self: *Self, account: usize, credential: g.Configuration.Credential, database: []const u8, dialect: f.Sql.Dialect, native: bool) !*Slot {
    self.sweep();
    try self.mutex.lock(self.io);
    var count: usize = 0;
    var free: ?*Slot = null;
    for (self.slots) |*slot| {
        if (slot.present and slot.account == account) count += 1;
        if (!slot.present and slot.controls == 0 and free == null and slot.mutex.tryLock()) free = slot;
    }
    if (count >= self.configuration.limits.connections_per_account or free == null) {
        if (free) |slot| slot.mutex.unlock(self.io);
        self.mutex.unlock(self.io);
        return error.GatewayConnectionCapacity;
    }
    const slot = free.?;
    slot.present = true;
    slot.opening = true;
    slot.native = native;
    slot.account = account;
    self.mutex.unlock(self.io);
    errdefer {
        self.mutex.lockUncancelable(self.io);
        slot.present = false;
        self.mutex.unlock(self.io);
        slot.mutex.unlock(self.io);
    }
    try self.io.randomSecure(&slot.id);
    slot.memory = .{ .parent = self.allocator, .limit = self.configuration.limits.session_bytes };
    slot.cancellation.store(false, .release);
    slot.active.store(false, .release);
    slot.host = try g.Session.init(slot.memory.allocator(), self.io, self.configuration, account, self.runtimes[account], credential, database, dialect, &slot.cancellation, &slot.active);
    slot.host.?.native_profile = native;
    slot.last = std.Io.Clock.awake.now(self.io);
    self.mutex.lockUncancelable(self.io);
    slot.opening = false;
    self.mutex.unlock(self.io);
    return slot;
}
/// Caller holds the slot lock. Remove the published identity before cleanup so
/// control requests cannot race a freed Session or credential.
pub fn remove(self: *Self, slot: *Slot) void {
    self.mutex.lockUncancelable(self.io);
    slot.present = false;
    self.mutex.unlock(self.io);
    slot.clear();
}
pub fn sweep(self: *Self) void {
    const now = std.Io.Clock.awake.now(self.io);
    self.mutex.lockUncancelable(self.io);
    for (&self.challenges) |*entry| if (entry.*) |*challenge| if (challenge.started.durationTo(now).toMilliseconds() >= self.configuration.limits.handshake_ms) {
        challenge.scram.deinit();
        entry.* = null;
        self.releaseAuthentication();
    };
    self.mutex.unlock(self.io);
    for (self.slots) |*slot| {
        self.mutex.lockUncancelable(self.io);
        const expired = slot.present and !slot.opening and slot.native and slot.controls == 0 and
            slot.last.durationTo(now).toMilliseconds() >= self.configuration.limits.idle_ms and slot.mutex.tryLock();
        if (expired) slot.present = false;
        self.mutex.unlock(self.io);
        if (!expired) continue;
        defer slot.mutex.unlock(self.io);
        slot.clear();
    }
}
fn response(self: *Self, allocator: std.mem.Allocator, result: @FieldType(api.Response, "result")) ![]u8 {
    const bytes = try api.Json.valueAlloc(allocator, api.Response{ .version = 1, .definition = api.native.current_definition, .instance = self.instance, .result = result });
    errdefer allocator.free(bytes);
    if (bytes.len > api.max_message_bytes) return error.SqlMessageTooLarge;
    return bytes;
}
pub fn failure(self: *Self, allocator: std.mem.Allocator, err: anyerror) ![]u8 {
    return self.response(allocator, .{ .err = .{ .code = @errorName(err), .sqlstate = switch (err) {
        error.AuthenticationFailed, error.InvalidAuthentication => "28000".*,
        error.GatewayDenied, error.GatewayDatabaseDenied, error.GatewayCatalogDenied, error.CatalogDenied, error.AccessDenied, error.QueryDenied, error.GatewayCredentialChanged => "42501".*,
        error.GatewayConnectionCapacity, error.SqlSessionBusy, error.OutOfMemory => "53000".*,
        error.GatewayDeadline, error.GatewayWaitCancelled => "57014".*,
        else => "HY000".*,
    }, .message = "SQL request failed; inspect the error code and original operation before retrying", .retry = .never } });
}
/// Encodes while the borrower lock remains held. The returned bytes belong to
/// the request allocator and never borrow a result freed by another connection.
pub fn request(self: *Self, allocator: std.mem.Allocator, input: api.Request, peer: Peer) ![]u8 {
    try input.validate();
    if (input.action == .hello) return self.response(allocator, .{ .hello = .{ .encoding = api.encoding, .session_lease_ms = self.configuration.limits.idle_ms, .maximum_message = api.max_message_bytes, .maximum_batch = api.max_batch_bytes, .maximum_rows = api.max_rows, .capabilities = &.{ "catalog_reads", "table_ddl", "table_dml", "logical_types", "typed_parameters", "finite_relational", "source_bindings", "captured_queries", "settings", "configuration_reload", "operation_recovery" } } });
    if (!std.mem.eql(u8, &input.instance.?, &self.instance)) return error.SqlInstanceChanged;
    if (input.action == .open) return self.open(allocator, input.action.open, peer);
    if (input.action == .authenticate) return self.authenticate(allocator, input.action.authenticate);
    if (input.action == .cancel or input.action == .status or input.action == .operations or input.action == .@"resume") return self.control(allocator, input);
    try self.mutex.lock(self.io);
    const slot = self.locate(input.session.?) catch |err| {
        self.mutex.unlock(self.io);
        return err;
    };
    if (!slot.mutex.tryLock()) {
        self.mutex.unlock(self.io);
        return error.SqlSessionBusy;
    }
    if (slot.controls == 0 and slot.last.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.configuration.limits.idle_ms) {
        slot.present = false;
        self.mutex.unlock(self.io);
        slot.clear();
        slot.mutex.unlock(self.io);
        return error.SqlSessionExpired;
    }
    slot.last = std.Io.Clock.awake.now(self.io);
    self.mutex.unlock(self.io);
    defer slot.mutex.unlock(self.io);
    defer {
        self.mutex.lockUncancelable(self.io);
        slot.last = std.Io.Clock.awake.now(self.io);
        self.mutex.unlock(self.io);
    }
    const host = slot.host.?;
    errdefer slot.clearCursor();
    if (input.action == .close) {
        try host.begin();
        host.end();
        self.remove(slot);
        return self.response(allocator, .closed);
    }
    try host.begin();
    defer host.end();
    host.sql_diagnostic = null;
    host.execution_diagnostic = null;
    const result = self.action(allocator, slot, input.action) catch |err| {
        slot.clearCursor();
        const info = host.diagnostic(err);
        const diagnostic = if (host.sql_diagnostic) |value| try value.structured() else host.execution_diagnostic;
        const state = if (host.sql_diagnostic) |value| switch (value.kind) {
            .syntax => "42601".*,
            .unsupported, .grammar_only, .interface => "0A000".*,
            .binding => "22023".*,
            .limit => "54000".*,
        } else info.state;
        return self.response(allocator, .{ .err = .{ .code = @errorName(err), .sqlstate = state, .message = info.message, .diagnostic = diagnostic, .retry = if (input.action == .execute and input.action.execute.token != null and diagnostic == null) .control else .never } });
    };
    return self.response(allocator, result);
}
fn opened(self: *Self, allocator: std.mem.Allocator, account: usize, credential: g.Configuration.Credential, database: []const u8, source: ?[]const u8, proof: []const u8) ![]u8 {
    const slot = try self.create(account, credential, database, .transit, true);
    defer slot.mutex.unlock(self.io);
    errdefer self.remove(slot);
    try slot.host.?.selectSource(source);
    return self.response(allocator, .{ .opened = .{ .session = slot.id, .account = self.configuration.accounts[account].ledger.account, .database = slot.host.?.database, .proof = proof } });
}
fn open(self: *Self, allocator: std.mem.Allocator, input: @FieldType(api.Action, "open"), peer: Peer) ![]u8 {
    self.sweep();
    if (!self.acquireAuthentication()) return error.GatewayConnectionCapacity;
    var retained = false;
    defer if (!retained) self.releaseAuthentication();
    const index = self.configuration.account(input.account) catch return error.AuthenticationFailed;
    const account = &self.configuration.accounts[index];
    _ = try account.database(input.database);
    const source = if (input.source) |name| (try account.source(name, input.database)).name else null;
    const credential = try g.Session.loadCredential(allocator, self.io, account);
    switch (input.authentication) {
        .peer => {
            if (account.authentication != .peer or peer.uid == null or account.peer_uid != peer.uid) return error.AuthenticationFailed;
            return self.opened(allocator, index, credential, input.database, source, "");
        },
        .trust => {
            if (account.authentication != .trust or !peer.loopback or peer.uid != null) return error.AuthenticationFailed;
            return self.opened(allocator, index, credential, input.database, source, "");
        },
        .scram => {
            if (account.authentication != .password or !peer.tls or credential.verifier == null) return error.AuthenticationFailed;
            var random: [18]u8 = undefined;
            try self.io.randomSecure(&random);
            const bound = try api.authenticationBinding(allocator, self.instance, account.name, input.database, input.source);
            var scram = try g.Authentication.Scram.initBound(credential.verifier.?, input.first, random, bound);
            errdefer scram.deinit();
            try self.mutex.lock(self.io);
            defer self.mutex.unlock(self.io);
            const now = std.Io.Clock.awake.now(self.io);
            for (self.challenges[0..self.configuration.limits.authentications]) |*entry| {
                if (entry.*) |*old| if (old.started.durationTo(now).toMilliseconds() >= self.configuration.limits.handshake_ms) {
                    old.scram.deinit();
                    entry.* = null;
                    self.releaseAuthentication();
                };
                if (entry.* != null) continue;
                var id: api.Id = undefined;
                try self.io.randomSecure(&id);
                entry.* = .{ .id = id, .account = index, .database = try databaseName(account, input.database), .source = source, .credential = credential, .scram = scram, .started = now };
                retained = true;
                return self.response(allocator, .{ .challenge = .{ .id = id, .message = entry.*.?.scram.challenge() } });
            }
            return error.GatewayConnectionCapacity;
        },
    }
}
fn databaseName(account: *const g.Configuration.Account, name: []const u8) ![]const u8 {
    for (account.databases) |database| if (std.mem.eql(u8, database.name, name)) return database.name;
    return error.GatewayDatabaseDenied;
}
fn authenticate(self: *Self, allocator: std.mem.Allocator, input: @FieldType(api.Action, "authenticate")) ![]u8 {
    try self.mutex.lock(self.io);
    const found = for (&self.challenges) |*entry| {
        if (entry.*) |value| if (std.crypto.timing_safe.eql(api.Id, value.id, input.challenge)) {
            entry.* = null;
            break value;
        };
    } else {
        self.mutex.unlock(self.io);
        return error.AuthenticationFailed;
    };
    self.mutex.unlock(self.io);
    var challenge = found;
    defer self.releaseAuthentication();
    defer challenge.scram.deinit();
    if (challenge.started.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.configuration.limits.handshake_ms) return error.AuthenticationFailed;
    const credential = try g.Session.loadCredential(allocator, self.io, &self.configuration.accounts[challenge.account]);
    if (!std.meta.eql(credential, challenge.credential)) return error.AuthenticationFailed;
    const proof = try challenge.scram.finish(input.final);
    return self.opened(allocator, challenge.account, credential, challenge.database, challenge.source, &proof);
}
fn findStatement(slot: *Slot, id: api.Id) !*Statement {
    for (&slot.statements) |*entry| if (entry.*) |*statement| if (std.mem.eql(u8, &statement.id, &id)) return statement;
    return error.SqlStatementExpired;
}
fn describe(allocator: std.mem.Allocator, host: *g.Session, statement: Statement) !api.Description {
    try host.validate(statement.prepared);
    const parameters = try allocator.alloc([]const u8, statement.prepared.parameters().len);
    for (statement.prepared.parameters(), parameters) |kind, *encoded| encoded.* = try api.Codec.descriptor(allocator, kind);
    return .{ .statement = statement.id, .schema = try api.Codec.schema(allocator, statement.prepared.fields()), .parameters = parameters, .mutation = statement.prepared.mutation() };
}
fn action(self: *Self, allocator: std.mem.Allocator, slot: *Slot, input: api.Action) !@FieldType(api.Response, "result") {
    const host = slot.host.?;
    switch (input) {
        .touch => return .closed,
        .context => {
            const T = @FieldType(@FieldType(api.Response, "result"), "context");
            var sources: std.ArrayList(std.meta.Elem(@FieldType(T, "sources"))) = .empty;
            for (host.account.sources) |*configured| {
                if (!std.mem.eql(u8, configured.database, host.database)) continue;
                const selected = g.SourceSession.init(host, configured) catch |err| switch (err) {
                    error.QueryDenied, error.AccessDenied, error.SqlSourceIdentityMismatch => continue,
                    else => return err,
                };
                defer selected.deinit();
                const description = try selected.client.describe(selected.definition);
                try sources.append(allocator, .{ .name = configured.name, .sql_name = configured.workspace.name, .kind = std.meta.stringToEnum(@FieldType(std.meta.Elem(@FieldType(T, "sources")), "kind"), @tagName(selected.definition.source)).?, .resource = selected.definition.resource, .revision = description.resource_revision, .contract = try selected.definition.fingerprint() });
            }
            return .{ .context = .{ .account = host.account.ledger.account, .database = host.database, .source = host.sourceName(), .sources = sources.items } };
        },
        .close => unreachable,
        .reset => {
            slot.clearCursor();
            for (&slot.statements) |*entry| if (entry.*) |value| {
                host.destroy(value.prepared);
                entry.* = null;
            };
            try host.reset();
            return .closed;
        },
        .prepare => |value| {
            const entry = for (slot.statements[0..@min(api.max_prepared, self.configuration.limits.prepared_statements)]) |*candidate| {
                if (candidate.* == null) break candidate;
            } else return error.SqlPreparedCapacity;
            var id: api.Id = undefined;
            try self.io.randomSecure(&id);
            entry.* = .{ .id = id, .prepared = try host.prepare(value.sql) };
            errdefer {
                host.destroy(entry.*.?.prepared);
                entry.* = null;
            }
            return .{ .described = try describe(allocator, host, entry.*.?) };
        },
        .describe => |id| return .{ .described = try describe(allocator, host, (try findStatement(slot, id)).*) },
        .release => |id| {
            const statement = try findStatement(slot, id);
            if (slot.cursor) |cursor| if (cursor.prepared == statement.prepared) return error.SqlResultActive;
            host.destroy(statement.prepared);
            for (&slot.statements) |*entry| if (entry.*) |value| if (std.mem.eql(u8, &value.id, &id)) {
                entry.* = null;
                break;
            };
            return .closed;
        },
        .execute => |value| return self.execute(allocator, slot, value),
        .result => |value| {
            if (slot.cursor != null) return error.SqlResultActive;
            if (value.kind != .captured or !std.mem.eql(u8, &value.account, &host.account.ledger.account)) return error.GatewayDenied;
            const prepared = try host.allocator.create(g.Session.Prepared);
            var owned = true;
            errdefer if (owned) host.allocator.destroy(prepared);
            prepared.* = .{ .captured = try g.CapturedOperations.prepareResult(host, value.id) };
            errdefer if (owned) prepared.captured.deinit();
            var id: api.Id = undefined;
            try self.io.randomSecure(&id);
            const read = try host.openRead(prepared, &.{});
            slot.cursor = .{ .id = id, .prepared = prepared, .owned = true, .read = read, .arena = .init(slot.memory.allocator()), .batch_arena = .init(slot.memory.allocator()) };
            owned = false;
            return .{ .batch = try self.batch(slot, 0) };
        },
        .fetch => |value| {
            const cursor = if (slot.cursor) |*current| current else return error.SqlResultIncomplete;
            if (!std.mem.eql(u8, &cursor.id, &value.cursor)) return error.SqlResultIncomplete;
            try host.validate(cursor.prepared);
            if (value.batch == cursor.batch.batch) return .{ .batch = cursor.batch };
            if (cursor.batch.complete or value.batch != cursor.batch.batch + 1) return error.InvalidSqlCursor;
            return .{ .batch = try self.batch(slot, value.batch) };
        },
        .close_result => |id| {
            if (slot.cursor) |cursor| {
                if (!std.mem.eql(u8, &cursor.id, &id)) return error.SqlResultIncomplete;
                slot.clearCursor();
            }
            return .closed;
        },
        .assist => |value| {
            if (host.source) |source| {
                const result = (try g.query.Workspace.apply(allocator, &source.client, source.configuration.workspace, .{ .assist = .{ .sql = value.text, .cursor = std.math.cast(u16, value.cursor) orelse return error.InvalidSqlCursor, .generation = 0, .mode = .console } })).assistance;
                const T = @FieldType(@FieldType(api.Response, "result"), "assistance");
                const items = try allocator.alloc(std.meta.Elem(@FieldType(T, "items")), result.items.len);
                for (result.items, items) |item, *out| out.* = .{ .text = item.text, .kind = switch (item.kind) {
                    inline else => |kind| @field(@FieldType(std.meta.Elem(@FieldType(T, "items")), "kind"), @tagName(kind)),
                }, .detail = item.detail };
                return .{ .assistance = .{ .profile = .unified_v1, .resource = result.resource, .contract = result.contract, .resource_revision = result.resource_revision, .policy_revision = result.policy_revision, .range = result.range, .items = items } };
            }
            const result = try g.query.TableAssistance.complete(allocator, &host.table, .{ .sql = value.text, .cursor = std.math.cast(u16, value.cursor) orelse return error.InvalidSqlCursor, .generation = 0, .mode = .console });
            const T = @FieldType(@FieldType(api.Response, "result"), "assistance");
            const items = try allocator.alloc(std.meta.Elem(@FieldType(T, "items")), result.items.len);
            for (result.items, items) |item, *out| out.* = .{ .text = item.text, .kind = switch (item.kind) {
                inline else => |kind| @field(@FieldType(std.meta.Elem(@FieldType(T, "items")), "kind"), @tagName(kind)),
            }, .detail = item.detail };
            return .{ .assistance = .{ .profile = @fromBackingInt(@intCast(@backingInt(result.profile))), .resource = result.resource, .contract = result.contract, .resource_revision = result.resource_revision, .policy_revision = result.policy_revision, .range = result.range, .items = items } };
        },
        else => return error.InvalidSqlAction,
    }
}
fn execute(self: *Self, allocator: std.mem.Allocator, slot: *Slot, input: @FieldType(api.Action, "execute")) !@FieldType(api.Response, "result") {
    const host = slot.host.?;

    if (slot.cursor != null) return error.SqlResultActive;
    const digest = if (input.token != null) try api.fingerprint(allocator, self.instance, host.account.ledger.account, host.database, host.sourceName(), input) else null;
    if (input.token) |token| if (try host.fresh(g.ConfigurationOperations.find, .{ host, token, digest })) |item| return .{ .operation = try operationStatus(host, item) };
    const prepared = if (input.statement) |id| (try findStatement(slot, id)).prepared else try host.prepare(input.sql.?);
    var owned = input.statement == null;
    defer if (owned) host.destroy(prepared);
    var arena: std.heap.ArenaAllocator = .init(slot.memory.allocator());
    var retained = false;
    defer if (!retained) arena.deinit();
    const a = arena.allocator();
    if (input.parameters.len != prepared.parameters().len) return error.WireParameterCountMismatch;
    const values = try a.alloc(?f.Types.Values.Atom, input.parameters.len);
    for (input.parameters, prepared.parameters(), values) |encoded, kind, *value| {
        var decoded = try api.Codec.decodeParameter(a, encoded);
        defer decoded.deinit();
        if (!try decoded.field.type.eql(kind)) return error.SqlParameterTypeMismatch;
        value.* = switch (decoded.cell) {
            .null => null,
            .value => |cell| if (cell == .atom) try f.Types.Values.cloneAtom(a, cell.atom) else return error.SqlParameterTypeMismatch,
            else => return error.SqlParameterTypeMismatch,
        };
    }
    try host.bind(prepared, values);
    if (input.captured and prepared.* == .source) {
        return .{ .operation = try g.CapturedOperations.admit(host, &prepared.source, values, input.token orelse return error.SqlAdmissionTokenRequired, digest.?) };
    }
    if (input.captured and prepared.* == .native and !prepared.mutation()) return error.CapturedSourceRequired;
    if (prepared.* == .settings and prepared.settings.plan.statement == .reload) return .{ .operation = try g.ConfigurationOperations.admit(host, input.token orelse return error.SqlAdmissionTokenRequired, digest.?) };
    if (prepared.mutation()) {
        if (prepared.* == .native) {
            const token = input.token orelse return error.SqlAdmissionTokenRequired;
            const item = try host.runtime.admit(host.allocator, &host.observer, &host.table, &prepared.native, values, token, digest.?, host.deadline, &host.operation);
            return .{ .operation = try host.fresh(g.AccountRuntime.status, .{ host.runtime, host.allocator, &host.observer, &host.table, item.id }) };
        }
        const result = try host.write(prepared, values);
        return .{ .completion = .{ .kind = result.kind, .matched = result.count, .changed = result.changed } };
    }
    var id: api.Id = undefined;
    try self.io.randomSecure(&id);
    // Finish every fallible acquisition before publishing the cursor. Struct
    // result-location semantics may initialize destination fields before a
    // later `try` fails; request cleanup must never see such a partial owner.
    const read = try host.openRead(prepared, values);
    slot.cursor = .{ .id = id, .prepared = prepared, .owned = owned, .read = read, .arena = arena, .batch_arena = .init(slot.memory.allocator()) };
    retained = true;
    owned = false;
    return .{ .batch = try self.batch(slot, 0) };
}
fn batch(self: *Self, slot: *Slot, ordinal: u64) !api.Batch {
    _ = self;
    const cursor = &slot.cursor.?;
    _ = cursor.batch_arena.reset(.free_all);
    const allocator = cursor.batch_arena.allocator();
    const host = slot.host.?;
    try host.validate(cursor.prepared);
    const fields = cursor.prepared.fields();
    const rows = try allocator.alloc([]const []const u8, api.max_rows);
    var count: usize = 0;
    var used: usize = 0;
    var complete = false;
    // Fetch one bounded engine batch. Source ownership remains with the cursor;
    // encoding copies it before the engine can reuse its output buffers.
    const scratch = try host.allocator.alloc(u8, api.max_batch_bytes);
    defer host.allocator.free(scratch);
    const result = try cursor.read.?.nextBatch(@min(api.max_rows, g.ReadBatch.max_rows));
    for (result.rows[0..result.len]) |row| {
        const cells = try allocator.alloc([]const u8, fields.len);
        for (row.?, fields, cells) |cell, field, *encoded| {
            encoded.* = try api.Codec.hex(allocator, try f.Types.Codec.encodeBound(cell, field, scratch));
            used = try std.math.add(usize, used, encoded.*.len / 2);
            if (used > api.max_batch_bytes) return error.SqlBatchTooLarge;
        }
        rows[count] = cells;
        count += 1;
    }
    complete = result.complete;
    cursor.batch = .{ .cursor = cursor.id, .batch = ordinal, .schema = try api.Codec.schema(allocator, fields), .rows = rows[0..count], .complete = complete, .basis = try cursor.read.?.basis(allocator) };
    if (complete) {
        host.closeRead(cursor.read.?);
        cursor.read = null;
    }
    return cursor.batch;
}
/// Controls use a separately owned transport, even while the session's read or
/// admission request is stalled. Authentication is checked afresh before any
/// atomic cancellation or protected operation observation.
fn control(self: *Self, allocator: std.mem.Allocator, input: api.Request) ![]u8 {
    try self.mutex.lock(self.io);
    const slot = self.locate(input.session.?) catch |err| {
        self.mutex.unlock(self.io);
        return err;
    };
    if (slot.controls == 0 and !slot.active.load(.acquire) and
        slot.last.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.configuration.limits.idle_ms)
    {
        self.mutex.unlock(self.io);
        return error.SqlSessionExpired;
    }
    const account = slot.account;
    const credential = if (slot.host) |host| host.credential else {
        self.mutex.unlock(self.io);
        return error.SqlSessionBusy;
    };
    const database = slot.host.?.database;
    const source_name = slot.host.?.sourceName();
    slot.controls += 1;
    self.mutex.unlock(self.io);
    defer {
        self.mutex.lockUncancelable(self.io);
        slot.last = std.Io.Clock.awake.now(self.io);
        slot.controls -= 1;
        self.mutex.unlock(self.io);
    }
    var cancelled: std.atomic.Value(bool) = .init(false);
    var active: std.atomic.Value(bool) = .init(false);
    var memory: g.query.QueryMemory = .{ .parent = self.allocator, .limit = self.configuration.limits.session_bytes };
    const host = try g.Session.init(memory.allocator(), self.io, self.configuration, account, self.runtimes[account], credential, database, .transit, &cancelled, &active);
    defer host.deinit();
    try host.selectSource(source_name);
    try host.begin();
    defer host.end();
    const runtime = host.runtime;
    if (input.action == .operations) {
        const page = try host.fresh(operationPage, .{ host, input.action.operations.after });
        var entries: std.ArrayList(api.Operation) = .empty;
        for (page.entries) |entry| if (entry) |item| {
            host.fresh(selectOperation, .{ host, item }) catch |err| switch (err) {
                error.GatewayDatabaseDenied, error.CatalogDenied, error.GatewayDenied, error.QueryDenied, error.SqlOperationBindingChanged => continue,
                else => return err,
            };
            try entries.append(allocator, try operationStatus(host, item));
        };
        return self.response(allocator, .{ .operations = .{ .entries = entries.items, .next = page.next } });
    }
    const target: api.Target = switch (input.action) {
        .cancel => |value| value,
        .status => |value| value,
        .@"resume" => |value| .{ .operation = value },
        else => unreachable,
    };
    if (target == .query) {
        if (input.action != .cancel) return error.InvalidSqlAction;
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const current = try self.locate(input.session.?);
        // The all-zero query handle explicitly means the current request in
        // this authenticated session, including execution before its first reply.
        const zero = std.mem.allEqual(u8, &target.query, 0);
        if (!current.mutex.tryLock()) {
            if (!zero) return error.SqlSessionBusy;
            current.cancellation.store(true, .release);
        } else {
            defer current.mutex.unlock(self.io);
            if (!zero and (current.cursor == null or !std.mem.eql(u8, &current.cursor.?.id, &target.query))) return error.SqlResultIncomplete;
            // Cleanup can perform native reads; release the registry lock first.
            self.mutex.unlock(self.io);
            current.clearCursor();
            self.mutex.lockUncancelable(self.io);
        }
        return self.response(allocator, .closed);
    }
    const reference: g.SessionOperations.Reference = switch (target) {
        .operation => |value| blk: {
            if (!std.mem.eql(u8, &value.account, &host.account.ledger.account)) return error.GatewayDenied;
            const ref = try host.fresh(operationReference, .{ host, value.id });
            if (!std.mem.eql(u8, @tagName(value.kind), @tagName(ref.kind))) return error.InvalidSqlOperationReference;
            break :blk ref;
        },
        .token => |token| (try host.fresh(g.ConfigurationOperations.find, .{ host, token, @as(?[32]u8, null) })) orelse return error.MissingGatewayOperation,
        .query => unreachable,
    };
    try host.fresh(selectOperation, .{ host, reference });
    if (reference.kind == .configuration) {
        if (input.action == .cancel) return error.ConfigurationCancellationUnsupported;
        return self.response(allocator, .{ .operation = if (input.action == .@"resume") try g.ConfigurationOperations.resumeOperation(host, reference.id) else try g.ConfigurationOperations.status(host, reference.id) });
    }
    if (reference.kind == .captured) {
        return self.response(allocator, .{ .operation = if (input.action == .cancel) try g.CapturedOperations.cancel(host, reference.id) else if (input.action == .@"resume") try g.CapturedOperations.resumeOperation(host, reference.id) else try g.CapturedOperations.status(host, reference.id) });
    }
    _ = try operationStatus(host, reference);
    if (input.action == .cancel) try runtime.control(.{ .session_cancel = reference.id }, host.deadline);
    if (input.action == .@"resume") try runtime.control(.{ .session_resume = reference.id }, host.deadline);
    return self.response(allocator, .{ .operation = try operationStatus(host, reference) });
}
fn selectOperation(host: *g.Session, ref: g.SessionOperations.Reference) !void {
    var reader = try host.observer.source();
    const binding: g.Ledger.Binding = if (ref.kind == .table) blk: {
        const item = try host.runtime.ledger.operation(&reader, ref.id);
        break :blk .{ .resource = item.resource, .catalog = item.catalog, .owner = item.owner, .namespace = item.namespace, .role = item.selectedRole() };
    } else (try g.SessionOperations.external(host.runtime.ledger, &reader, ref.id)).binding();
    const database = for (host.account.databases) |database| {
        if (std.meta.eql(database.binding, binding)) break database.name;
    } else return error.GatewayDatabaseDenied;
    try host.selectDatabase(database);
    if (ref.kind == .captured) try g.CapturedOperations.select(host, ref.id);
}
fn operationReference(host: *g.Session, id: u64) !g.SessionOperations.Reference {
    var source = try host.observer.source();
    return g.SessionOperations.reference(host.runtime.ledger, &source, id);
}
fn operationPage(host: *g.Session, after: u64) !g.SessionOperations.Page {
    var source = try host.observer.source();
    return g.SessionOperations.list(host.runtime.ledger, &source, after, false);
}
fn operationStatus(host: *g.Session, ref: g.SessionOperations.Reference) !api.Operation {
    return switch (ref.kind) {
        .table => try host.fresh(g.AccountRuntime.status, .{ host.runtime, host.allocator, &host.observer, &host.table, ref.id }),
        .configuration => try g.ConfigurationOperations.status(host, ref.id),
        .captured => try g.CapturedOperations.status(host, ref.id),
    };
}
/// One indexed operation per pass, rotating accounts. Retained history is never
/// loaded as a resident queue. This task owns its transport independently of
/// sessions, Table coordination and expiry.
pub fn recover(self: *Self) !void {
    if (self.runtimes.len == 0) return;
    const index = self.recovery_index;
    self.recovery_index = (index + 1) % self.runtimes.len;
    const runtime = self.runtimes[index];
    if (!runtime.ready.load(.acquire)) return;
    var memory: g.query.QueryMemory = .{ .parent = self.allocator, .limit = self.configuration.limits.session_bytes };
    const a = memory.allocator();
    const account = &self.configuration.accounts[index];
    var wire = g.station.client.Client.init(a, self.io, self.configuration.native_url);
    defer wire.deinit();
    wire.timeout_ms = self.configuration.request_timeout_ms;
    var observer: g.Client = .{ .transport = &wire, .ledger = runtime.ledger, .principal = account.ledger.ingress, .key = runtime.ingress.key };
    var source = try observer.source();
    const page = try g.SessionOperations.list(runtime.ledger, &source, self.recovery_after[index], true);
    const reference = page.entries[0] orelse {
        self.recovery_after[index] = 0;
        return;
    };
    self.recovery_after[index] = reference.id;
    const item = try g.SessionOperations.external(runtime.ledger, &source, reference.id);
    const database = for (account.databases) |database| {
        if (std.meta.eql(database.binding, item.binding())) break database.name;
    } else return error.SqlOperationBindingChanged;
    var cancelled: std.atomic.Value(bool) = .init(false);
    var active: std.atomic.Value(bool) = .init(false);
    const host = try g.Session.init(a, self.io, self.configuration, index, runtime, try g.Session.loadCredential(a, self.io, account), database, .transit, &cancelled, &active);
    defer host.deinit();
    try host.begin();
    defer host.end();
    switch (reference.kind) {
        .configuration => _ = try g.ConfigurationOperations.resumeOperation(host, reference.id),
        .captured => {
            try g.CapturedOperations.select(host, reference.id);
            _ = try g.CapturedOperations.resumeOperation(host, reference.id);
        },
        .table => return error.InvalidSqlOperationReference,
    }
}

//! Protocol-neutral SQL session execution over the shared native account runtime.
const std = @import("std");
const g = @import("root.zig");
const q = g.query;
const c = g.catalog;
const f = g.fuze;
const p = c.protocol;
const telemetry = q.wire.observability.telemetry;
const Self = @This();
const Settings = @import("SessionSettings.zig");
const Inspection = @import("SessionInspection.zig");
allocator: std.mem.Allocator,
io: std.Io,
config: *const g.Configuration,
account: *const g.Configuration.Account,
runtime: *g.DatabaseRuntime,
credential: g.Configuration.Credential,
database: []const u8,
dialect: f.Sql.Dialect,
native_profile: bool = false,
recovering: bool = false,
source: ?*g.SourceSession = null,
wire: g.wire.Client,
settings_wire: ?g.wire.Client = null,
diagnostic_source: ObservationSource = .native,
settings_session: q.SettingsSession = .{},
table: c.DirectTableClient,
namespace: u64,
observer: g.Client,
directory: std.Io.Dir,
cancellation: *std.atomic.Value(bool),
active: *std.atomic.Value(bool),
deadline: g.DatabaseRuntime.Deadline,
operation: ?u64 = null,
terminal: ?g.Terminal = null,
detail_buffer: [160]u8 = undefined,
diagnostics: ?*telemetry.Runtime = null,
sql_diagnostic: ?f.SqlDiagnostic = null,
execution_diagnostic: ?q.protocol.Diagnostic = null,
compile_binding: f.Sql.Binding = .{},
fresh_current: bool = false,
fresh_prepared: ?*const Prepared = null,
transaction: g.SessionTransaction.State = .{},
transaction_completion: ?g.results.CommandCompletion = null,
const ObservationSource = enum { native, settings };
pub const Options = struct { capture_settings: bool = true };
pub const read_options: g.direct.DirectRelationalQuery.Options = .{ .consistency = .independent_table_snapshots, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 16 * 1024 * 1024, .output_rows = 10000, .work_steps = 1000000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
pub const Prepared = union(enum) {
    transaction: g.database.TransactionSql.Control,
    native: g.Statement,
    probe: g.Probe,
    settings: Settings.Prepared,
    inspection: Inspection,
    source: g.SourceSession.Prepared,
    captured: g.CapturedOperations.Prepared,
    pub fn parameters(self: *const Prepared) []const f.Types.Type {
        return switch (self.*) {
            .native => |*value| value.parameters(),
            .source => |*value| value.template.parameterTypes(),
            .probe, .settings, .inspection, .captured, .transaction => &.{},
        };
    }
    pub fn fields(self: *const Prepared) []const f.Types.Field {
        return switch (self.*) {
            .native => |*value| value.fields(),
            .source => |*value| value.output.type.structure,
            .captured => |*value| value.output.type.structure,
            .transaction => &.{},
            .probe => |value| value.fields(),
            .inspection => |value| value.output,
            .settings => |value| if (value.output) |output| output.type.structure else &.{},
        };
    }
    pub fn mutation(self: *const Prepared) bool {
        return switch (self.*) {
            .transaction => true,
            .native => |*value| value.kind() != .select,
            .probe => |value| value.kind == .set,
            .inspection, .source, .captured => false,
            .settings => |value| value.plan.statement == .set or value.plan.statement == .reset,
        };
    }
    /// Command dispatch and effect-free admission are distinct: a configuration
    /// reload returns rows, but must never enter a read-only presentation host.
    pub fn readOnly(self: *const Prepared) bool {
        return !self.mutation() and !(self.* == .settings and self.settings.plan.statement == .reload);
    }
    pub fn empty(self: *const Prepared) bool {
        return self.* == .probe and self.probe.kind == .empty;
    }
};

test "read-only admission excludes row-returning configuration effects" {
    const t = std.testing;
    var reload: Prepared = .{ .settings = .{ .plan = (try q.SettingsSql.parse(t.allocator, "SELECT transit_reload_conf()", .transit)).?, .output = null } };
    defer reload.settings.deinit();
    try t.expect(!reload.mutation()); // Ordinary reload still uses row dispatch.
    try t.expect(!reload.readOnly());
    var catalog: Prepared = .{ .settings = .{ .plan = (try q.SettingsSql.parse(t.allocator, "SHOW TABLES", .transit)).?, .output = null } };
    defer catalog.settings.deinit();
    try t.expect(catalog.readOnly());
}
pub const Read = struct {
    host: *Self,
    value: union(enum) { single: g.direct.DirectTableQuery, relational: *g.direct.DirectRelationalQuery, probe: g.Probe, settings: Settings.Read, inspection: Inspection.Read, source: g.SourceSession.Read, captured: g.CapturedOperations.Read },
    prepared: *Prepared,
    builder: g.results.BatchBuilder,
    input: g.ReadBatch = .{},
    input_index: usize = 0,
    started: bool = false,
    disclosure: g.BatchDisclosure = .{},
    pins: [f.Relational.max_sources]?g.ReadCache.Record = @splat(null),
    batch: ?g.direct.DirectTableQuery.Batch = null,
    output: ?f.RelationalExecution.Output = null,
    probe_cells: [3]f.Types.Values.Cell = undefined,
    emitted: bool = false,
    emitted_rows: u64 = 0,
    validated_open: bool = false,
    validated_disclosure: bool = false,
    transaction: ?p.Transaction.Handle = null,
    transaction_context: ?c.DirectTransactionRead.Context = null,
    pub fn dataBasis(self: *Read, allocator: std.mem.Allocator) !?g.results.Observation.Data {
        return switch (self.value) {
            .single => |*query| blk: {
                const scan = &query.execution.scan;
                const source = scan.reader.basis;
                if (source.workspace) |view| break :blk try self.transactionBasis(allocator, &.{view});
                if (source.catalog) |snapshot| break :blk .{ .historical = .{ .snapshot = snapshot, .sources = try allocator.dupe(@FieldType(g.results.Observation.Data, "table"), &.{.{ .object = source.snapshot.object, .interpretation = source.interpretation.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .pin = source.snapshot.handle.content, .commitment = try scan.fingerprint(), .schema = try scan.reader.schema.schema.fingerprint() }}) } };
                break :blk .{ .table = .{ .object = source.snapshot.object, .interpretation = source.interpretation.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .pin = source.snapshot.handle.content, .commitment = try scan.fingerprint(), .schema = try scan.reader.schema.schema.fingerprint() } };
            },
            .relational => |query| blk: {
                if (self.transaction != null) {
                    var views: [f.Relational.max_sources]p.Transaction.ReadView = undefined;
                    const count = query.tables.declarations.len;
                    for (query.tables.scans[0..count], views[0..count]) |scan, *view| view.* = scan.?.reader.basis.workspace orelse return error.InvalidTransactionObservation;
                    break :blk try self.transactionBasis(allocator, views[0..count]);
                }
                if (query.tables.scans[0].?.reader.basis.catalog) |snapshot| {
                    const sources = try allocator.alloc(@FieldType(g.results.Observation.Data, "table"), query.tables.declarations.len);
                    for (query.tables.scans[0..sources.len], sources) |slot, *out| {
                        const scan = slot.?;
                        const source = scan.reader.basis;
                        if (!std.meta.eql(source.catalog, snapshot)) return error.InvalidHistoricalObservation;
                        out.* = .{ .object = source.snapshot.object, .interpretation = source.interpretation.interpretation, .accepted = source.accepted, .changed_lsn = source.changed_lsn, .pin = source.snapshot.handle.content, .commitment = try scan.fingerprint(), .schema = try scan.reader.schema.schema.fingerprint() };
                    }
                    break :blk .{ .historical = .{ .snapshot = snapshot, .sources = sources } };
                }
                break :blk .{ .independent_table_snapshots = try allocator.dupe(f.Relational.Cut, query.execution.bound.cuts) };
            },
            .source => |source| sourceBasis(source.query.basis),
            .captured => |captured| if (captured.basis) |value| sourceBasis(value) else null,
            else => null,
        };
    }
    fn transactionBasis(self: *Read, allocator: std.mem.Allocator, views: []const p.Transaction.ReadView) !g.results.Observation.Data {
        const first = views[0];
        const result: g.results.Observation.Data = .{ .transaction = .{ .handle = self.transaction orelse return error.InvalidTransactionObservation, .cut = first.cut, .revision = first.revision, .last_statement = first.last_statement, .sources = try allocator.dupe(p.Transaction.ReadView, views) } };
        try g.results.Observation.validate(.{ .data = result });
        return result;
    }
    pub fn observation(self: *Read, allocator: std.mem.Allocator) !g.results.Observation.Value {
        if (try self.dataBasis(allocator)) |data| return .{ .data = data };
        if (self.value == .captured or self.value == .source or self.value == .single or self.value == .relational) return error.MissingResultObservation;
        var metadata: g.results.Observation.Metadata = .{ .kind = .probe, .consistency = .session, .namespace = self.host.namespace, .definitions = &.{}, .configuration_revision = null, .session_settings = null };
        switch (self.value) {
            .inspection => |inspection| {
                const prepared = inspection.prepared;
                metadata.kind = prepared.kind;
                metadata.historical = prepared.historical_list;
                metadata.consistency = if (prepared.storage or prepared.node_storage) .independent_observations else .exact_definitions;
                if (prepared.metadata) |binding| {
                    metadata.definitions = try allocator.dupe(p.DataLifecycle.Definition, &.{binding.interpretation.interpretation});
                    metadata.historical = binding.catalog;
                }
                if (prepared.log_metadata) |binding| metadata.definitions = try allocator.dupe(p.DataLifecycle.Definition, &.{binding.definition.stored.declaration.interpretation});
                if (prepared.statement) |statement| {
                    if (statement.plan == .select) {
                        metadata.definitions = try allocator.dupe(p.DataLifecycle.Definition, &.{statement.plan.select.binding.interpretation.interpretation});
                        metadata.historical = statement.plan.select.binding.catalog;
                    } else if (statement.plan == .relational) {
                        metadata.historical = statement.plan.relational.catalog;
                        const definitions = try allocator.alloc(p.DataLifecycle.Definition, statement.plan.relational.bindings.len);
                        for (statement.plan.relational.bindings, definitions) |binding, *definition| definition.* = binding.interpretation.interpretation;
                        metadata.definitions = definitions;
                    }
                }
                if (prepared.source) {
                    const definition = self.host.source.?.definition;
                    var fields: [q.SourceDefinition.max_columns]f.Types.Field = undefined;
                    const schema = try definition.schema(&fields);
                    metadata.source = .{ .resource = definition.resource, .contract = try definition.fingerprint(), .schema = try schema.fingerprint() };
                }
            },
            .settings => |settings| {
                metadata.kind = if (settings.plan.statement == .catalog) .catalog else .settings;
                metadata.consistency = if (settings.plan.statement == .catalog) .independent_observations else .session;
                if (settings.settings) |reader| metadata.configuration_revision = reader.observed_revision;
                const bytes = try p.Json.valueAlloc(allocator, self.host.settings_session);
                defer allocator.free(bytes);
                var digest: [32]u8 = undefined;
                std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
                metadata.session_settings = digest;
            },
            .probe => {},
            else => unreachable,
        }
        return .{ .metadata = metadata };
    }
    fn sourceBasis(value: q.Basis) g.results.Observation.Data {
        return .{ .source = .{ .kind = value.cut.kind, .resource = value.cut.resource, .position = switch (value.cut.position) {
            .native_revision => |revision| .{ .native_revision = revision },
            .table => |commitment| .{ .table = commitment },
        }, .contract = value.contract, .schema = value.schema } };
    }
    pub fn validateDisclosure(self: *Read) !void {
        if (self.validated_disclosure) {
            self.validated_disclosure = false;
            return;
        }
        try self.disclosure.validate(self.host, self.prepared);
    }
    /// A parked wire continuation cannot reuse an earlier admission/disclosure
    /// observation. The retained data cut and buffered cells remain unchanged.
    pub fn resumeWire(self: *Read) void {
        self.validated_open = false;
        self.validated_disclosure = false;
    }
    pub fn nextBatch(self: *Read, requested: u8) !g.ReadBatch {
        // A historical catalog page has distinct protected objects. Keep their
        // union within one native disclosure guard, including namespace rights.
        // This bounds a physical batch, never the complete catalog result.
        const maximum = if (self.value == .inspection and self.value.inspection.prepared.historical_list != null) @min(requested, 8) else requested;
        self.validated_disclosure = false;
        try self.host.deadline.check(self.host.io);
        if (self.validated_open) {
            self.validated_open = false;
        } else {
            try self.host.current();
        }
        try self.builder.reset(maximum, g.results.BatchBuilder.max_bytes);
        self.disclosure = .{ .transaction = self.transaction, .transaction_context = self.transaction_context };
        var complete = false;
        while (self.builder.len < maximum) {
            if (self.input_index == self.input.len) {
                if (self.started and self.input.complete) {
                    complete = true;
                    break;
                }
                try self.host.deadline.check(self.host.io);
                self.input = try self.pull(@min(maximum - self.builder.len, g.direct.DirectTableQuery.Batch.max_rows));
                try self.input.validate(@min(maximum - self.builder.len, g.direct.DirectTableQuery.Batch.max_rows));
                self.input_index = 0;
                self.started = true;
                if (self.input.len == 0) {
                    complete = self.input.complete;
                    break;
                }
            }
            if (!try self.builder.append(self.prepared.fields(), self.input.rows[self.input_index].?)) break;
            if (self.value == .settings) try self.disclosure.append(self.value.settings.subject);
            if (self.value == .inspection) try self.disclosure.append(self.value.inspection.subject);
            self.input_index += 1;
        }
        complete = complete or (self.started and self.input.complete and self.input_index == self.input.len);
        // Source pulls may reset scratch and run for many rows. Authority is
        // current at this disclosure, not merely when the first row was read.
        if (self.value == .settings) {
            if (self.value.settings.settings) |settings| self.disclosure.origins = settings.origins orelse false;
        }
        try self.disclosure.validate(self.host, self.prepared);
        self.validated_disclosure = true;
        self.emitted_rows = try std.math.add(u64, self.emitted_rows, self.builder.len);
        return .{ .rows = self.builder.rows, .len = self.builder.len, .complete = complete };
    }
    fn pull(self: *Read, maximum: u8) !g.ReadBatch {
        if (self.batch) |*batch| batch.deinit();
        self.batch = null;
        if (self.output) |*output| output.deinit();
        self.output = null;
        var result: g.ReadBatch = .{};
        if (self.value == .captured) return self.value.captured.next(maximum);
        if (self.value == .source) return self.value.source.next(maximum);
        if (self.value == .single) {
            self.batch = self.value.single.nextBatch(maximum) catch |err| {
                self.host.execution_diagnostic = q.ApiDiagnostic.attempt("table_select", .read, null, err, .{}, false, null) catch null;
                if (self.host.execution_diagnostic) |*detail| {
                    detail.fact(.emitted_rows, .execution, .{ .unsigned = .init(self.emitted_rows) }) catch {};
                    if (self.value.single.native_rejection) |native| detail.text(.native_cause, .authority, @tagName(native)) catch {};
                }
                return err;
            };
            result.len = self.batch.?.len;
            result.complete = self.batch.?.complete;
            for (self.batch.?.rows[0..result.len], result.rows[0..result.len]) |row, *cells| cells.* = row.?.cells;
            return result;
        }
        const cells: ?[]const f.Types.Values.Cell = switch (self.value) {
            .single, .source, .captured => unreachable,
            .relational => |query| blk: {
                self.output = try query.next() orelse break :blk null;
                break :blk self.output.?.cells[0..self.output.?.len];
            },
            .settings => |*settings| try settings.next(),
            .inspection => |*inspection| try inspection.next(),
            .probe => |probe| blk: {
                if (self.emitted or probe.fields().len == 0) break :blk null;
                self.emitted = true;
                for (self.probe_cells[0..probe.fields().len], 0..) |*cell, i| cell.* = try probe.value(self.host.database, i);
                break :blk self.probe_cells[0..probe.fields().len];
            },
        };
        result.rows[0] = cells;
        result.len = @intFromBool(cells != null);
        result.complete = cells == null or switch (self.value) {
            .inspection => |inspection| inspection.complete(),
            .probe => true,
            else => false,
        };
        return result;
    }
};
pub fn loadCredential(allocator: std.mem.Allocator, io: std.Io, account: *const g.Configuration.Account) !g.Configuration.Credential {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, account.verifier_file, allocator, .limited(4096));
    defer allocator.free(bytes);
    defer std.crypto.secureZero(u8, bytes);
    const parsed = try std.json.parseFromSlice(g.Configuration.Credential, allocator, bytes, .{});
    defer parsed.deinit();
    try parsed.value.validate(account.execution.account);
    if ((account.authentication == .password) != (parsed.value.verifier != null)) return error.InvalidAuthentication;
    if (parsed.value.principal != account.execution.table_principal) return error.InvalidAuthentication;
    return parsed.value;
}
pub fn init(allocator: std.mem.Allocator, io: std.Io, config: *const g.Configuration, index: usize, runtime: *g.DatabaseRuntime, credential: g.Configuration.Credential, database: []const u8, dialect: f.Sql.Dialect, cancellation: *std.atomic.Value(bool), active: *std.atomic.Value(bool)) !*Self {
    return initOptions(allocator, io, config, index, runtime, credential, database, dialect, cancellation, active, .{});
}
pub fn initOptions(allocator: std.mem.Allocator, io: std.Io, config: *const g.Configuration, index: usize, runtime: *g.DatabaseRuntime, credential: g.Configuration.Credential, database: []const u8, dialect: f.Sql.Dialect, cancellation: *std.atomic.Value(bool), active: *std.atomic.Value(bool), options: Options) !*Self {
    if (runtime.read_pins == null) return error.SqlReadRecoveryRequired;
    const account = &config.accounts[index];
    const binding = try account.database(database);
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    var directory = try std.Io.Dir.cwd().openDir(io, config.spill_directory, .{});
    errdefer directory.close(io);
    self.* = .{ .allocator = allocator, .io = io, .config = config, .account = account, .runtime = runtime, .credential = credential, .database = undefined, .dialect = dialect, .wire = g.wire.Client.init(allocator, io, config.native_url), .table = undefined, .namespace = binding.namespace, .observer = undefined, .directory = directory, .cancellation = cancellation, .active = active, .deadline = .{ .start = std.Io.Clock.awake.now(io), .milliseconds = config.limits.command_ms, .cancellation = cancellation } };
    errdefer self.wire.deinit();
    self.wire.local = runtime.background.local;
    // Database names borrow immutable configuration, never a startup frame.
    for (account.databases) |selected| if (std.mem.eql(u8, selected.name, database)) {
        self.database = selected.name;
        break;
    };
    self.wire.timeout_ms = config.request_timeout_ms;
    self.table = .{ .allocator = allocator, .authority = &self.wire, .service = &self.wire, .connection = .{ .scope = .{ .realm = account.execution.realm, .resource = binding.resource, .catalog = binding.catalog }, .branch = 1, .audience = binding.owner, .principal = account.execution.table_principal, .role = binding.role }, .key = runtime.table_key, .lease = runtime.lease() };
    self.observer = .{ .transport = &self.wire, .execution = runtime.execution, .principal = account.execution.table_principal, .key = runtime.table_key, .lease = runtime.lease() };
    try self.current();
    if (config.settings) |configured| {
        self.settings_wire = g.wire.Client.init(allocator, io, configured.url);
        // Configuration has its own publication owner. Its signed native
        // authority reads use the same local database authority when co-hosted.
        if (runtime.background.local) |endpoint| {
            var authority = endpoint;
            authority.routes = &.{"/v1/query"};
            self.settings_wire.?.local = authority;
        }
        self.settings_wire.?.timeout_ms = config.request_timeout_ms;
        errdefer self.settings_wire.?.deinit();
        if (options.capture_settings) {
            self.settings_session = try self.freshOn(.settings, q.SettingsSession.capture, .{try Settings.client(self)});
        }
    }
    return self;
}
pub fn deinit(self: *Self) void {
    self.active.store(false, .release);
    if (self.source) |source| source.deinit();
    self.directory.close(self.io);
    self.wire.deinit();
    if (self.settings_wire) |*wire| wire.deinit();
    const allocator = self.allocator;
    std.crypto.secureZero(u8, std.mem.asBytes(self));
    allocator.destroy(self);
}
pub fn current(self: *Self) !void {
    return self.fresh(Self.currentOnce, .{self});
}
fn currentOnce(self: *Self) !void {
    const credential = try loadCredential(self.allocator, self.io, self.account);
    if (!std.meta.eql(credential, self.credential)) return error.GatewayCredentialChanged;
    const native: g.wire.AuthorizationClient = .{ .transport = &self.wire, .realm = self.account.execution.realm, .principal = self.account.execution.table_principal, .key = self.table.key, .role = self.table.connection.role };
    const identity = (try native.read(.identity)).body.authorization.body.identity;
    try credential.checkIdentity(identity.principal, identity.login_role, identity.credential_epoch);
    self.table.credential_epoch = identity.credential_epoch;
    self.observer.credential_epoch = identity.credential_epoch;
    var ordinary = self.table;
    ordinary.transaction = null;
    _ = try ordinary.require(.{ .namespace = self.namespace, .target = null, .access = .schema });
    // Revocation can also withdraw account readiness. Report the caller's
    // current denial before waiting for that account to recover; readiness is
    // still required before the activation fence and any result disclosure.
    if (!self.runtime.ready.load(.acquire)) return error.GatewayOwnerUnavailable;
    try self.runtime.fence(&self.observer);
    if (self.source) |source| try source.current();
}
/// Exact-current metadata reads may race a concurrent committed catalog turn.
/// Retry only pure preparation/validation, retaining the original statement on
/// validation. An independently idempotent sticky cancellation may also retry
/// against its original operation. Never replay a query iterator or SQL write.
pub fn fresh(self: *Self, comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) !@typeInfo(@typeInfo(@TypeOf(function)).@"fn".return_type.?).error_union.payload {
    return self.freshOn(.native, function, args);
}
fn observationRejection(self: *const Self, source: ObservationSource) ?p.ErrorCode {
    return switch (source) {
        .native => self.wire.last_rejection,
        .settings => if (self.settings_wire) |wire| wire.last_rejection else null,
    };
}
/// The settings reader can also resume a failed page request at its retained
/// cursor. This does not authorize restarting other iterators or mutations.
pub fn freshOn(self: *Self, source: ObservationSource, comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) !@typeInfo(@typeInfo(@TypeOf(function)).@"fn".return_type.?).error_union.payload {
    self.diagnostic_source = source;
    var attempts: u8 = 0;
    const started = std.Io.Clock.awake.now(self.io);
    while (true) {
        try self.deadline.check(self.io);
        return @call(.auto, function, args) catch |err| {
            self.diagnostic_source = source;
            const rejected = self.observationRejection(source);
            const stale = ((err == error.Rejected or err == error.Conflict) and rejected == .StaleStateResource) or err == error.CatalogDefinitionChanged;
            const unavailable = g.wire.Client.unavailable(err) or (err == error.Conflict and rejected == .Conflict) or err == error.GatewayOwnerUnavailable;
            // Recovery and native admission may need more than 64 short polls.
            // Bound those waits by both configured time budgets; retain the
            // conflict-attempt limit for repeatedly changing metadata.
            if ((!stale and !unavailable) or (unavailable and started.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= self.config.request_timeout_ms) or (!unavailable and attempts == 64)) return err;
            if (!unavailable) attempts += 1;
            try self.io.sleep(.fromMilliseconds(if (unavailable) 20 else 1), .awake);
            continue;
        };
    }
}
pub fn begin(self: *Self) !void {
    self.cancellation.store(false, .release);
    self.operation = null;
    self.terminal = null;
    self.transaction_completion = null;
    self.table.transaction = null;
    self.fresh_prepared = null;
    self.deadline.start = std.Io.Clock.awake.now(self.io);
    self.deadline.milliseconds = self.commandMilliseconds();
    self.active.store(true, .release);
    errdefer self.active.store(false, .release);
    // This evidence is scoped to one command. Session creation or a previous
    // request cannot authorize work after credentials or grants change.
    try self.current();
    self.fresh_current = true;
}
pub fn end(self: *Self) void {
    self.fresh_current = false;
    self.fresh_prepared = null;
    self.active.store(false, .release);
}
/// End same-command observation reuse when a wire adapter resumes after parking.
/// This neither resets the command deadline nor changes its accepted identity.
pub fn resumeWire(self: *Self) void {
    self.fresh_current = false;
    self.fresh_prepared = null;
}
pub fn transactionStatus(self: *const Self) g.results.Transaction.SessionState {
    if (!self.transaction.active()) return .idle;
    return if (self.transaction.failed or self.transaction.pending != null) .failed else .active;
}
pub fn reset(self: *Self) !void {
    if (self.transaction.active()) return error.SqlTransactionActive;
    self.fresh_current = false;
    try self.current();
    self.operation = null;
    self.settings_session.reset();
}
pub fn selectSource(self: *Self, name: ?[]const u8) !void {
    if (self.transaction.active()) return error.SqlTransactionActive;
    if (self.source) |source| {
        self.fresh_current = false;
        source.deinit();
    }
    self.source = null;
    if (name) |selected| {
        self.fresh_current = false;
        self.source = try self.fresh(g.SourceSession.init, .{ self, try self.account.source(selected, self.database) });
    }
}
pub fn sourceName(self: *const Self) ?[]const u8 {
    return if (self.source) |source| source.configuration.name else null;
}
pub fn selectDatabase(self: *Self, name: []const u8) !void {
    if (self.transaction.active()) return error.SqlTransactionActive;
    try self.current();
    const binding = try self.account.database(name);
    var candidate = self.table;
    candidate.connection.scope.resource = binding.resource;
    candidate.connection.scope.catalog = binding.catalog;
    candidate.connection.audience = binding.owner;
    candidate.connection.role = binding.role;
    _ = try candidate.require(.{ .namespace = binding.namespace, .target = null, .access = .schema });
    try self.selectSource(null);
    self.table = candidate;
    self.namespace = binding.namespace;
    for (self.account.databases) |selected| if (std.mem.eql(u8, selected.name, name)) {
        self.database = selected.name;
        break;
    };
}
pub fn readOptions(self: *const Self) g.direct.DirectRelationalQuery.Options {
    var result = read_options;
    if (self.table.transaction != null) result.consistency = .transaction;
    return result;
}
pub fn prepare(self: *Self, sql: []const u8) !*Prepared {
    self.sql_diagnostic = null;
    self.compile_binding = .{};
    return self.prepareInner(sql) catch |err| {
        self.sql_diagnostic = f.SqlDiagnostic.bound(sql, err, true, self.compile_binding);
        return err;
    };
}
fn prepareInner(self: *Self, sql: []const u8) !*Prepared {
    if (self.fresh_current) {
        self.fresh_current = false;
    } else {
        try self.current();
    }
    try g.SessionTransaction.reconcile(self);
    const control = try g.database.TransactionSql.parse(sql, self.dialect);
    if (control == null) try g.SessionTransaction.refresh(self);
    const result = try self.allocator.create(Prepared);
    errdefer self.allocator.destroy(result);
    if (control) |value| {
        result.* = .{ .transaction = value };
        try g.SessionTransaction.require(self, result);
        self.fresh_prepared = result;
        return result;
    }
    if (try self.fresh(Inspection.prepare, .{ self, sql })) |inspection| {
        result.* = .{ .inspection = inspection };
        self.fresh_prepared = result;
        return result;
    }
    if (try g.Probe.parse(sql, self.dialect)) |probe| result.* = .{ .probe = probe } else if (try self.freshOn(.settings, Settings.prepare, .{ self, sql })) |settings| result.* = .{ .settings = settings } else if (self.source) |source| result.* = .{ .source = try self.fresh(g.SourceSession.prepare, .{ source, sql }) } else result.* = .{ .native = try self.fresh(g.Statement.prepareDiagnostic, .{ self.allocator, &self.table, self.namespace, sql, self.dialect, if (self.native_profile) g.Statement.Profile.native else g.Statement.Profile.wire, self.readOptions(), &self.compile_binding }) };
    self.fresh_prepared = result;
    return result;
}
pub fn destroy(self: *Self, prepared: *Prepared) void {
    if (self.fresh_prepared == prepared) self.fresh_prepared = null;
    if (prepared.* == .native) prepared.native.deinit();
    if (prepared.* == .source) prepared.source.deinit();
    if (prepared.* == .captured) prepared.captured.deinit();
    if (prepared.* == .settings) prepared.settings.deinit();
    if (prepared.* == .inspection) prepared.inspection.deinit();
    self.allocator.destroy(prepared);
}
pub fn validate(self: *Self, prepared: *Prepared) !void {
    if (self.fresh_prepared == prepared) {
        self.fresh_prepared = null;
        return;
    }
    self.fresh_prepared = null;
    try g.SessionTransaction.require(self, prepared);
    if (prepared.* != .transaction) try g.SessionTransaction.refresh(self);
    try self.deadline.check(self.io);
    try self.current();
    switch (prepared.*) {
        .native => |*statement| {
            if (statement.namespace != self.namespace) return error.CatalogIdentityConflict;
            try self.fresh(g.Statement.validate, .{ statement, &self.table });
            // Revalidating a retained handle checks its definition and rights,
            // not the data frontier observed at preparation. A later execution
            // must observe that frontier before selecting a cached read pin.
            if (statement.plan == .select) statement.plan.select.metadata = null;
        },
        .source => |*statement| try self.fresh(g.SourceSession.validate, .{ self.source orelse return error.UnknownSqlSource, statement }),
        .captured => |*captured| try g.CapturedOperations.validateResult(self, captured),
        .inspection => |*inspection| try self.fresh(Inspection.validate, .{ inspection, self }),
        .settings => |*settings| try self.freshOn(.settings, Settings.authorize, .{ self, &settings.plan }),
        .probe, .transaction => {}, // current() already validates the login and database.
    }
    self.fresh_prepared = prepared;
}
pub fn bind(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !void {
    switch (prepared.*) {
        .native => |*statement| try statement.checkValues(self.allocator, values),
        .source => |*statement| {
            var bound = try self.source.?.bind(statement, values);
            bound.deinit();
        },
        .probe, .settings, .inspection, .captured, .transaction => if (values.len != 0) return error.WireParameterCountMismatch,
    }
}
pub fn openRead(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !*Read {
    // Acquisition persists each original request before dispatch. A failed
    // attempt enters cleanup. ReadCache can retry preparation only after proving
    // the original pin is absent and its exact frontier can no longer be acquired;
    // an accepted/uncertain pin or opened iterator never switches its cut.
    return self.acquireRead(prepared, values);
}

fn acquireRead(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !*Read {
    try g.SessionTransaction.require(self, prepared);
    const is_fresh = self.fresh_prepared == prepared;
    if (is_fresh) {
        self.fresh_prepared = null;
    } else {
        try self.validate(prepared);
    }
    const read = try self.allocator.create(Read);
    errdefer self.allocator.destroy(read);
    read.* = .{ .host = self, .value = undefined, .prepared = prepared, .builder = try .init(self.allocator, self.config.limits.cycle_bytes), .validated_open = true, .transaction = self.transaction.handle, .transaction_context = self.table.transaction };
    errdefer read.builder.deinit();
    errdefer self.releasePins(read);
    switch (prepared.*) {
        .transaction => return error.ExpectedGatewayRead,
        .captured => |*captured| read.value = .{ .captured = try g.CapturedOperations.Read.init(self, captured) },
        .source => |*statement| read.value = .{ .source = try g.SourceSession.Read.init(self.source.?, statement, values) },
        .inspection => |*inspection| read.value = .{ .inspection = .{ .host = self, .prepared = inspection } },
        .settings => |*settings| read.value = .{ .settings = try Settings.Read.init(self, settings) },
        .probe => |probe| read.value = .{ .probe = probe },
        .native => |*statement| {
            if (statement.kind() != .select) return error.ExpectedGatewayRead;
            const count = if (statement.plan == .relational) statement.plan.relational.plan.sources.len else 1;
            var snapshots: [f.Relational.max_sources]c.DirectTableProtocol.Snapshot = undefined;
            for (0..count) |i| {
                const binding = if (statement.plan == .relational) statement.plan.relational.bindings[i] else statement.plan.select.binding;
                if (binding.catalog) |snapshot| {
                    const response = try c.DirectHistory.call(self.table, .{ .source = .{ .snapshot = snapshot, .object = binding.interpretation.interpretation.object.object, .rows = true } });
                    defer response.deinit();
                    const selected = response.value.result.historical_catalog.source;
                    if (!std.meta.eql(selected.binding.declaration, binding.interpretation)) return error.HistoricalIdentityConflict;
                    snapshots[i] = selected.table().snapshot;
                    continue;
                }
                if (self.table.transaction != null) {
                    const response = try self.table.call(.{ .lookup = .{ .namespace = binding.namespace, .name = binding.name.slice() } });
                    defer response.deinit();
                    const metadata = response.value.result.lookup orelse return error.TableNotFound;
                    try binding.check(self.table.connection, metadata);
                    const view = metadata.workspace orelse return error.InvalidTransactionRead;
                    snapshots[i] = .{ .object = metadata.interpretation.interpretation.object, .handle = .{ .owner = view.cut.begin.identity.begin, .content = view.private } };
                    continue;
                }
                var shared: ?usize = null;
                for (read.pins[0..i], 0..) |slot, j| if (slot) |pin| if (std.meta.eql(pin.table, binding)) {
                    shared = j;
                    break;
                };
                if (shared) |j| {
                    snapshots[i] = snapshots[j];
                    continue;
                }
                const known_metadata = if (is_fresh and statement.plan == .select) statement.plan.select.metadata else null;
                read.pins[i] = try self.runtime.read_pins.?.acquireCurrentWithMetadata(self.table, binding, known_metadata);
                snapshots[i] = try read.pins[i].?.snapshot();
            }
            if (statement.plan == .relational) {
                var nonce: [16]u8 = undefined;
                try self.io.randomSecure(&nonce);
                var path: [64]u8 = undefined;
                const name = try std.fmt.bufPrint(&path, "sql-{x}", .{nonce});
                read.value = .{ .relational = try statement.openRelational(self.allocator, self.io, self.directory, name, &self.table, snapshots[0..count], self.readOptions(), self.cancellation) };
            } else read.value = .{ .single = try statement.openSelect(self.allocator, &self.table, values, snapshots[0], .{ .requests = 10000, .rows = 10000, .result_bytes = 16 * 1024 * 1024 }, self.cancellation) };
        },
    }
    return read;
}
pub fn closeRead(self: *Self, read: *Read) void {
    read.builder.deinit();
    if (read.output) |*output| output.deinit();
    read.output = null;
    const rejection = self.wire.last_rejection;
    defer self.wire.last_rejection = rejection;
    if (read.batch) |*batch| batch.deinit();
    switch (read.value) {
        .single => |*query| {
            query.close();
            query.deinit();
        },
        .relational => |query| {
            query.close();
            query.deinit();
        },
        .source => |*source| source.deinit(),
        .captured => |*captured| captured.deinit(),
        .probe, .inspection => {},
        .settings => |*settings| settings.deinit(),
    }
    self.releasePins(read);
    self.allocator.destroy(read);
}
fn releasePins(self: *Self, read: *Read) void {
    // Cleanup has independent network observations. Preserve the failed read's
    // diagnostic even when acquiring/opening it never produced a cursor.
    const rejection = self.wire.last_rejection;
    defer self.wire.last_rejection = rejection;
    for (&read.pins) |*slot| if (slot.*) |record| {
        var client = self.table;
        client.connection = record.table.connection;
        self.runtime.read_pins.?.close(client, record) catch |err| {
            self.runtime.read_cleanup_failure.store(@intFromError(err), .release);
            self.runtime.notify();
        };
        slot.* = null;
    };
}
pub fn write(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !g.results.CommandCompletion {
    const is_fresh = self.fresh_prepared == prepared;
    if (is_fresh) {
        self.fresh_prepared = null;
    } else {
        try self.validate(prepared);
    }
    if (prepared.* == .transaction or self.transaction.handle != null) return g.SessionTransaction.execute(self, prepared, values);
    if (prepared.* == .settings) {
        try Settings.mutate(self, &prepared.settings);
        return .{ .kind = if (prepared.settings.plan.statement == .reset) .reset else .set, .outcome = .applied, .counts = null, .operation = null, .pending_restart = false, .diagnostic = null };
    }
    if (prepared.* == .probe) {
        if (prepared.probe.kind != .set) return error.ExpectedGatewayWrite;
        return .{ .kind = .set, .outcome = .applied, .counts = null, .operation = null, .pending_restart = false, .diagnostic = null };
    }
    const result = try self.runtime.executePrepared(self.allocator, &self.observer, &self.table, &prepared.native, values, self.deadline, &self.operation, is_fresh, true);
    self.terminal = result.terminal;
    switch (result.terminal.state) {
        .applied, .unchanged => {},
        .rejected => return error.GatewayMutationRejected,
        .cancelled => return error.GatewayMutationCancelled,
    }
    try self.current();
    return result.completion;
}
/// A resumed output observes the original outcome, never revalidates the SQL as
/// a new execution. COMMIT and DROP may have ended their original attachment or
/// definition. Reuse the public status owner under current login/scope rights.
pub fn validateWireCompletion(self: *Self, prepared: *Prepared, completion: g.results.CommandCompletion) !void {
    try completion.validate();
    try self.current();
    if (completion.operation) |operation| {
        if (!std.mem.eql(u8, &operation.account, &self.runtime.execution.configuration.account)) return error.InvalidWireCompletion;
        const observed = try self.fresh(g.DatabaseRuntime.status, .{ self.runtime, self.allocator, &self.observer, &self.table, self.namespace, operation.id });
        const verified = try observed.completion();
        if (verified.kind != completion.kind or verified.outcome != completion.outcome or !std.meta.eql(verified.counts, completion.counts) or !std.meta.eql(verified.operation, completion.operation)) return error.InvalidWireCompletion;
    } else switch (prepared.*) {
        .settings => |*settings| try self.freshOn(.settings, Settings.authorize, .{ self, &settings.plan }),
        .probe => {},
        else => return error.InvalidWireCompletion,
    }
}
pub fn diagnostic(self: *Self, err: anyerror) struct { state: [5]u8, message: []const u8, detail: ?[]const u8 } {
    if (self.transaction.handle != null) self.transaction.failed = true;
    const rejected = self.observationRejection(self.diagnostic_source);
    const remote = err == error.Conflict or err == error.Rejected or err == error.AuthorityUnavailable;
    if (self.diagnostics) |diagnostics| diagnostics.event(.{ .name = "sql.request.failed", .level = .warn, .outcome = .failed, .error_type = if (remote and rejected != null) @tagName(rejected.?) else @errorName(err) });
    // Direct HTTP failures retain the verified owner cause separately from
    // their status-class error. Do not apply that cause to unrelated failures.
    const cause = if ((err == error.Conflict or err == error.Rejected) and rejected == .TableDefinitionChanged) error.TableDefinitionChanged else err;
    const info: struct { [5]u8, []const u8 } = if (err == error.AuthorityUnavailable and (rejected == .HttpCapacity or rejected == .StorageQuota)) .{ "53000".*, "Database capacity exhausted; inspect admitted writes before retrying SQL" } else if (err == error.Conflict and rejected == .Conflict) .{ "55000".*, "Current state changed; inspect admitted work before retrying SQL" } else switch (cause) {
        error.CatalogDenied, error.AccessDenied, error.GatewayDatabaseDenied, error.ConfigurationDenied => .{ "42501".*, "Current permission denied" },
        error.GatewayCredentialChanged, error.InvalidAuthentication => .{ "28000".*, "Credential changed or disabled" },
        error.GatewayDeadline, error.GatewayWaitCancelled, error.Cancelled, error.Canceled, error.StatementTimedOut => .{ "57014".*, "Request wait ended; admitted work requires outcome inspection" },
        error.SettingOutOfRange, error.InvalidSettingValue, error.InvalidSettingUnit => .{ "22023".*, "Setting value exceeds its type or administrator ceiling" },
        error.UnknownSetting => .{ "42704".*, "Unknown registered setting" },
        error.SettingNotSessionMutable => .{ "0A000".*, "Setting cannot be changed by this session" },
        error.StandaloneConfigurationOperationRequired => .{ "0A000".*, "Reload requires the complete standalone SELECT transit_reload_conf() statement" },
        error.ConfigurationSortRequiresBoundedLimit => .{ "54000".*, "Ordered configuration history requires LIMIT of at most 256" },
        error.ConfigurationServiceRequired => .{ "0A000".*, "Configuration service binding is required" },
        error.ConfigurationReloadRejected => .{ "22023".*, "Configuration reload rejected; inspect transit_config_reloads()" },
        error.ConfigurationSnapshotChanged => .{ "40001".*, "Configuration changed; discard partial results and repeat the read" },
        error.WireParameterCountMismatch, error.WireParameterTypeMismatch, error.InvalidWireValue => .{ "22023".*, "Parameter type or value rejected" },
        error.NullNotAllowed => .{ "23502".*, "Required value is NULL" },
        error.CheckConstraintViolation => .{ "23514".*, "A CHECK constraint rejected the proposed row" },
        error.InvalidHistoricalSelector => .{ "22023".*, "Expected an exact published historical snapshot selector" },
        error.HistoricalObjectNotSelected => .{ "42P01".*, "Object is absent from the selected historical catalog" },
        error.HistoricalSnapshotReleased => .{ "55000".*, "The selected historical snapshot has been explicitly released" },
        error.UnsupportedHistoricalTransaction, error.UnsupportedHistoricalKind, error.HistoricalReadOnly => .{ "0A000".*, "This statement cannot execute against a historical catalog" },
        error.WireValueOutOfRange, error.DecimalOverflow, error.InexactDecimalRounding => .{ "22003".*, "Value exceeds the declared numeric precision or exact rounding rule" },
        error.DivisionByZero => .{ "22012".*, "Decimal divisor is zero" },
        error.TimestampOverflow => .{ "22008".*, "Timestamp is out of range" },
        error.NonexistentLocalTime, error.AmbiguousLocalTime => .{ "22007".*, "Local time requires an explicit gap or fold resolution" },
        error.InvalidTimeBucket, error.ZeroMagnitudeCosineVector, error.InvalidColumnSemantics, error.MissingColumnSemantics => .{ "22023".*, "Scalar operation requires valid declared semantics and operands" },
        error.ScalarProgramBudget => .{ "54000".*, "Scalar expression exceeds its instruction budget" },
        error.TimezoneCoverageUnavailable, error.UnsupportedScalarFunction => .{ "0A000".*, "Scalar operation is outside the declared execution coverage" },
        error.CatalogIdentityConflict, error.CatalogDefinitionChanged, error.TableDefinitionChanged => .{ "55000".*, "Prepared source changed; prepare again" },
        error.GatewayOwnerUnavailable, error.StaleGatewayCoordinator => .{ "55000".*, "Gateway owner is not ready; inspect admitted writes before retrying SQL" },
        error.SqlReadLeaseCapacity, error.GatewayRecordTooLarge, error.TooManyWireStatements, error.TooManyWirePortals, error.OutOfMemory, error.ResultMemoryBudgetExceeded, error.ResultRowTooLarge, error.SqlBatchTooLarge, error.InvalidResultBudget => .{ "54000".*, "Session capacity exceeded" },
        error.CellTooLarge => .{ "54000".*, "Bound scalar exceeds the 4096-byte limit" },
        error.UnknownWireStatement, error.UnknownWirePortal => .{ "26000".*, "Unknown prepared statement or portal" },
        error.DuplicateWireStatement, error.DuplicateWirePortal => .{ "42P05".*, "Prepared name already exists" },
        error.SqlTransactionActive => .{ "25001".*, "A transaction is already attached; settle it before changing session scope" },
        error.SqlTransactionRequired => .{ "25P01".*, "No transaction is attached to this session" },
        error.SqlTransactionFailed => .{ "25P02".*, "Transaction requires ROLLBACK or ROLLBACK TO SAVEPOINT" },
        error.SqlTransactionPending => .{ "55000".*, "The original transaction command is unresolved; inspect or resume its original token" },
        error.SqlTransactionLimit => .{ "54000".*, "Transaction statement or savepoint limit reached; settle the transaction" },
        error.SqlTransactionClosed => .{ "25000".*, "Transaction is closing or already decided; inspect its original operation" },
        error.TransactionReadChanged => .{ "55000".*, "Transaction workspace changed; discard the old result cursor" },
        error.UnsupportedTransactionStatement, error.UnsupportedTransactionIsolation => .{ "0A000".*, "Operation is outside the selected serializable Table transaction profile" },
        error.ReadOnlyTransaction => .{ "25006".*, "The transaction is read only" },
        error.SqlTransactionRejected => blk: {
            const completion = self.transaction_completion orelse break :blk .{ "XX000".*, "Missing transaction outcome" };
            const evidence = completion.transaction.?.evidence;
            if (evidence == .decided) break :blk g.SessionTransaction.decisionDiagnostic(evidence.decided.decision.outcome);
            if (evidence == .statement) break :blk switch (evidence.statement.refusal.?) {
                .duplicate_key => .{ "23505".*, "Primary key already exists in the transaction workspace" },
                .missing_row => .{ "02000".*, "Required row is absent from the transaction workspace" },
                .invalid_rows => .{ "23000".*, "Row constraints rejected the transaction statement" },
                .check_violation => .{ "23514".*, "A CHECK constraint rejected the transaction statement" },
                .work_limit => .{ "54000".*, "Transaction statement work budget exceeded" },
                .data_changed, .definition_changed => .{ "40001".*, "Transaction source changed" },
            };
            break :blk .{ "55000".*, "The original transaction command was refused; inspect its recorded outcome" };
        },
        error.GatewayMutationRejected => blk: {
            const terminal = self.terminal orelse break :blk .{ "XX000".*, "Missing terminal observation" };
            break :blk switch (terminal.kind) {
                .catalog_assertion => .{ "40001".*, "Conditional Table name changed before acceptance" },
                .namespace_change => switch (terminal.reason) {
                    1 => .{ "42P06".*, "Schema name already exists" },
                    2, 3 => .{ "40001".*, "Schema identity or definition changed" },
                    4 => .{ "2BP01".*, "A registered dependency blocks the schema change" },
                    else => .{ "55000".*, "Schema declaration rejected" },
                },
                .log_declaration => switch (terminal.reason) {
                    1 => .{ "42P07".*, "Stream or Queue name already exists" },
                    2, 3 => .{ "40001".*, "Stream or Queue identity or definition changed" },
                    4 => .{ "2BP01".*, "A registered dependency blocks the declaration change" },
                    else => .{ "55000".*, "Stream or Queue declaration rejected" },
                },
                .dml => switch (terminal.reason) {
                    1, 2 => .{ "40001".*, "Table definition or data changed" },
                    3 => .{ "23505".*, "Primary key already exists" },
                    4 => .{ "02000".*, "Required row no longer exists" },
                    5 => .{ "23000".*, "Row constraints rejected the mutation" },
                    6 => .{ "54000".*, "Statement work budget exceeded" },
                    7 => .{ "23514".*, "A CHECK constraint rejected the mutation" },
                    else => .{ "23000".*, "Table mutation rejected; inspect its recorded outcome" },
                },
                .ddl => switch (terminal.reason) {
                    1 => .{ "42P07".*, "Table name already exists" },
                    2, 3, 4 => .{ "40001".*, "Table identity, definition or data changed" },
                    5 => .{ "2BP01".*, "A registered dependency blocks the change" },
                    6 => .{ "23000".*, "Schema constraints rejected the change" },
                    7 => .{ "0A000".*, "Populated Table change requires an online phased rewrite" },
                    8 => .{ "54000".*, "Schema validation work budget exceeded" },
                    else => .{ "55000".*, "Table declaration rejected" },
                },
            };
        },
        error.GatewayMutationCancelled => .{ "57014".*, "Table operation cancelled" },
        error.UnsupportedGatewayStatement, error.UnsupportedExecutionCycle, error.UnsupportedWireType => .{ "0A000".*, "Operation is outside the selected SQL profile" },
        error.InvalidSqlSyntax, error.ExpectedIdentifier, error.UnexpectedToken => .{ "42601".*, "SQL syntax rejected" },
        error.TableNotFound => .{ "42P01".*, "Table does not exist" },
        error.CatalogNameNotFound => .{ "42P01".*, "Catalog object does not exist" },
        error.CatalogKindMismatch => .{ "42809".*, "Catalog object has a different data kind" },
        error.UnsupportedLogOption, error.UnsupportedLogPrimaryKey, error.UnsupportedLogRepartition, error.UnsupportedLogKeyChange, error.UnsupportedLogTimestampChange => .{ "0A000".*, "Stream or Queue declaration option is unsupported" },
        error.InvalidLogOption, error.DuplicateLogOption, error.InvalidLogPartitioning, error.InvalidLogRetention, error.InvalidLogLimits, error.InvalidLogKeyColumn, error.InvalidStreamPolicy, error.InvalidStreamTimestampColumn, error.InvalidQueuePolicy, error.InvalidQueuePartitionKey, error.InvalidQueueBackoff, error.InvalidQueueDestination => .{ "22023".*, "Invalid Stream or Queue declaration policy or budget" },
        error.SqlTokenConflict => .{ "22023".*, "Client token already identifies different work" },
        error.EmptyWireQuery => .{ "42601".*, "Query is empty" },
        else => .{ "XX000".*, "Request failed; inspect admitted work before retrying SQL" },
    };
    const detail = if (self.transaction.pending) |pending| std.fmt.bufPrint(&self.detail_buffer, "Original transaction command token {x}; inspect this token before repeating SQL", .{pending.token}) catch null else if (self.operation) |id| std.fmt.bufPrint(&self.detail_buffer, "Gateway operation {d}; sending SQL again creates new work", .{id}) catch null else null;
    return .{ .state = info[0], .message = info[1], .detail = detail };
}

test "capacity diagnostics retain operation uncertainty and do not override denial" {
    var host: Self = undefined;
    host.transaction = .{};
    host.transaction_completion = null;
    host.diagnostics = null;
    host.diagnostic_source = .native;
    host.operation = 17;
    host.wire.last_rejection = .HttpCapacity;
    const capacity = host.diagnostic(error.AuthorityUnavailable);
    try std.testing.expectEqualStrings("53000", &capacity.state);
    try std.testing.expect(std.mem.indexOf(u8, capacity.detail.?, "17") != null);
    try std.testing.expectEqualStrings("42501", &host.diagnostic(error.AccessDenied).state);
    try std.testing.expectEqualStrings("23502", &host.diagnostic(error.NullNotAllowed).state);
    try std.testing.expectEqualStrings("22003", &host.diagnostic(error.DecimalOverflow).state);
    try std.testing.expectEqualStrings("22003", &host.diagnostic(error.InexactDecimalRounding).state);
    try std.testing.expectEqualStrings("22012", &host.diagnostic(error.DivisionByZero).state);
    try std.testing.expectEqualStrings("22008", &host.diagnostic(error.TimestampOverflow).state);
    try std.testing.expectEqualStrings("22007", &host.diagnostic(error.AmbiguousLocalTime).state);
    try std.testing.expectEqualStrings("22007", &host.diagnostic(error.NonexistentLocalTime).state);
    try std.testing.expectEqualStrings("22023", &host.diagnostic(error.ZeroMagnitudeCosineVector).state);
    try std.testing.expectEqualStrings("54000", &host.diagnostic(error.ScalarProgramBudget).state);
    try std.testing.expectEqualStrings("0A000", &host.diagnostic(error.TimezoneCoverageUnavailable).state);
    try std.testing.expectEqualStrings("22023", &host.diagnostic(error.InvalidHistoricalSelector).state);
    try std.testing.expectEqualStrings("42P01", &host.diagnostic(error.HistoricalObjectNotSelected).state);
    try std.testing.expectEqualStrings("55000", &host.diagnostic(error.HistoricalSnapshotReleased).state);
    try std.testing.expectEqualStrings("0A000", &host.diagnostic(error.UnsupportedHistoricalTransaction).state);
    try std.testing.expectEqualStrings("54000", &host.diagnostic(error.CellTooLarge).state);
    try std.testing.expectEqualStrings("55000", &host.diagnostic(error.GatewayOwnerUnavailable).state);
    const changed = host.diagnostic(error.TableDefinitionChanged);
    try std.testing.expectEqualStrings("55000", &changed.state);
    try std.testing.expectEqualStrings("Prepared source changed; prepare again", changed.message);
    try std.testing.expect(std.mem.indexOf(u8, changed.detail.?, "17") != null);
    host.wire.last_rejection = .TableDefinitionChanged;
    for ([_]anyerror{ error.Conflict, error.Rejected }) |remote| {
        const response = host.diagnostic(remote);
        try std.testing.expectEqualStrings("55000", &response.state);
        try std.testing.expectEqualStrings("Prepared source changed; prepare again", response.message);
        try std.testing.expect(std.mem.indexOf(u8, response.detail.?, "17") != null);
    }
    try std.testing.expectEqualStrings("54000", &host.diagnostic(error.OutOfMemory).state);
    host.wire.last_rejection = .Conflict;
    const contention = host.diagnostic(error.Conflict);
    try std.testing.expectEqualStrings("55000", &contention.state);
    try std.testing.expect(std.mem.indexOf(u8, contention.detail.?, "17") != null);
    try std.testing.expectEqualStrings("42501", &host.diagnostic(error.AccessDenied).state);
    host.wire.last_rejection = .ConflictingRetry;
    try std.testing.expectEqualStrings("XX000", &host.diagnostic(error.Conflict).state);
    host.wire.last_rejection = .StorageQuota;
    try std.testing.expectEqualStrings("53000", &host.diagnostic(error.AuthorityUnavailable).state);
    try std.testing.expectEqualStrings("54000", &host.diagnostic(error.SqlReadLeaseCapacity).state);
    try std.testing.expectEqualStrings("22023", &host.diagnostic(error.SqlTokenConflict).state);
    host.wire.last_rejection = null;
    try std.testing.expectEqualStrings("XX000", &host.diagnostic(error.AuthorityUnavailable).state);
}

test "pure preparation retries transport loss within its budget but never retries denial" {
    const t = std.testing;
    const Observation = struct {
        attempts: u32 = 0,
        failures: u32 = 2,
        failure: anyerror = error.AuthorityUnavailable,
        fn run(self: *@This()) !u32 {
            self.attempts += 1;
            if (self.attempts <= self.failures) return self.failure;
            return 17;
        }
    };
    var host: Self = undefined;
    host.transaction = .{};
    host.transaction_completion = null;
    host.io = t.io;
    var config: g.Configuration = undefined;
    config.request_timeout_ms = 5000;
    host.config = &config;
    host.wire.last_rejection = null;
    host.deadline = .{ .start = std.Io.Clock.awake.now(t.io), .milliseconds = 5000 };
    var read: Observation = .{};
    try t.expectEqual(@as(u32, 17), try host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 3), read.attempts);
    read = .{ .failure = error.AccessDenied };
    try t.expectError(error.AccessDenied, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 1), read.attempts);
    read = .{ .failure = error.TableDefinitionChanged };
    try t.expectError(error.TableDefinitionChanged, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 1), read.attempts);
    host.wire.last_rejection = .TableDefinitionChanged;
    read = .{ .failure = error.Conflict };
    try t.expectError(error.Conflict, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 1), read.attempts);
    host.wire.last_rejection = null;
    config.request_timeout_ms = 30;
    read = .{ .failures = 100 };
    try t.expectError(error.AuthorityUnavailable, host.fresh(Observation.run, .{&read}));
    try t.expect(read.attempts > 0 and read.attempts < read.failures);
    read = .{ .failures = 100, .failure = error.GatewayOwnerUnavailable };
    try t.expectError(error.GatewayOwnerUnavailable, host.fresh(Observation.run, .{&read}));
    try t.expect(read.attempts > 0 and read.attempts < read.failures);
    read = .{ .failures = 100, .failure = error.CatalogDefinitionChanged };
    try t.expectError(error.CatalogDefinitionChanged, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 65), read.attempts);
    host.deadline.milliseconds = 0;
    read = .{};
    try t.expectError(error.GatewayDeadline, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 0), read.attempts);
}

test "settings observations use their own rejection and retain terminal decisions" {
    const t = std.testing;
    const Observation = struct {
        transport: *g.wire.Client,
        attempts: u32 = 0,
        code: p.ErrorCode = .StaleStateResource,
        failure: anyerror = error.Conflict,
        fn run(self: *@This()) !void {
            self.attempts += 1;
            self.transport.last_rejection = if (self.attempts <= 2) self.code else null;
            if (self.attempts <= 2) return self.failure;
        }
    };
    var config: g.Configuration = undefined;
    config.request_timeout_ms = 5000;
    var host: Self = undefined;
    host.transaction = .{};
    host.transaction_completion = null;
    host.io = t.io;
    host.config = &config;
    host.diagnostics = null;
    host.operation = null;
    host.wire.last_rejection = .TableDefinitionChanged;
    host.settings_wire = g.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer host.settings_wire.?.deinit();
    host.deadline = .{ .start = std.Io.Clock.awake.now(t.io), .milliseconds = 5000 };
    var read: Observation = .{ .transport = &host.settings_wire.? };
    try host.freshOn(.settings, Observation.run, .{&read});
    try t.expectEqual(@as(u32, 3), read.attempts);
    read = .{ .transport = &host.settings_wire.?, .code = .AccessDenied, .failure = error.AccessDenied };
    try t.expectError(error.AccessDenied, host.freshOn(.settings, Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 1), read.attempts);
    try t.expectEqualStrings("42501", &host.diagnostic(error.AccessDenied).state);
    read = .{ .transport = &host.settings_wire.?, .code = .ConfigurationSnapshotChanged, .failure = error.ConfigurationSnapshotChanged };
    try t.expectError(error.ConfigurationSnapshotChanged, host.freshOn(.settings, Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 1), read.attempts);
    try t.expectEqualStrings("40001", &host.diagnostic(error.ConfigurationSnapshotChanged).state);
    host.settings_wire.?.last_rejection = .HttpCapacity;
    try t.expectEqualStrings("53000", &host.diagnostic(error.AuthorityUnavailable).state);
    try t.expectEqualStrings("42501", &host.diagnostic(error.AccessDenied).state);
    host.settings_wire.?.last_rejection = null;
    try t.expectEqualStrings("XX000", &host.diagnostic(error.Conflict).state);
    host.diagnostic_source = .native;
    try t.expectEqualStrings("55000", &host.diagnostic(error.Conflict).state);
}

pub fn commandMilliseconds(self: *const Self) u32 {
    const requested = self.settings_session.timeout();
    return if (requested == 0) self.config.limits.command_ms else @intCast(@min(requested, self.config.limits.command_ms));
}

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
runtime: *g.AccountRuntime,
credential: g.Configuration.Credential,
database: []const u8,
dialect: f.Sql.Dialect,
native_profile: bool = false,
source: ?*g.SourceSession = null,
wire: g.station.client.Client,
settings_wire: ?g.station.client.Client = null,
settings_session: q.SettingsSession = .{},
table: c.TableClient,
observer: g.Client,
directory: std.Io.Dir,
cancellation: *std.atomic.Value(bool),
active: *std.atomic.Value(bool),
deadline: g.AccountRuntime.Deadline,
operation: ?u64 = null,
terminal: ?g.Terminal = null,
detail_buffer: [160]u8 = undefined,
diagnostics: ?*telemetry.Runtime = null,
sql_diagnostic: ?f.SqlDiagnostic = null,
execution_diagnostic: ?q.protocol.Diagnostic = null,
compile_binding: f.Sql.Binding = .{},
pub const read_options: q.RelationalQuery.Options = .{ .consistency = .per_resource_snapshot_vector, .budgets = .{ .resident_bytes = 16 * 1024 * 1024, .spill_bytes = 16 * 1024 * 1024, .result_bytes = 16 * 1024 * 1024, .output_rows = 10000, .work_steps = 1000000, .source_pins = 2 }, .requests = 10000, .spill_work = 10000 };
pub const Prepared = union(enum) {
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
            .probe, .settings, .inspection, .captured => &.{},
        };
    }
    pub fn fields(self: *const Prepared) []const f.Types.Field {
        return switch (self.*) {
            .native => |*value| value.fields(),
            .source => |*value| value.output.type.structure,
            .captured => |*value| value.output.type.structure,
            .probe => |value| value.fields(),
            .inspection => |value| value.output,
            .settings => |value| if (value.output) |output| output.type.structure else &.{},
        };
    }
    pub fn mutation(self: *const Prepared) bool {
        return switch (self.*) {
            .native => |*value| value.kind() != .select,
            .probe => |value| value.kind == .set,
            .inspection, .source, .captured => false,
            .settings => |value| value.plan.statement == .set or value.plan.statement == .reset,
        };
    }
    pub fn empty(self: *const Prepared) bool {
        return self.* == .probe and self.probe.kind == .empty;
    }
};
pub const Read = struct {
    host: *Self,
    value: union(enum) { single: q.TableQuery, relational: *q.RelationalQuery, probe: g.Probe, settings: Settings.Read, inspection: Inspection.Read, source: g.SourceSession.Read, captured: g.CapturedOperations.Read },
    batch: ?q.TableQuery.Batch = null,
    output: f.RelationalExecution.Output = undefined,
    probe_cells: [3]f.Types.Values.Cell = undefined,
    emitted: bool = false,
    emitted_rows: u64 = 0,
    pub fn basis(self: *Read, allocator: std.mem.Allocator) !?g.session_protocol.Basis {
        return switch (self.value) {
            .single => |*query| blk: {
                const scan = &query.execution.scan;
                break :blk .{ .table = .{ .realm = scan.connection.scope.realm, .resource = scan.view.resource, .catalog = scan.connection.scope.catalog, .owner = scan.connection.owner, .object = scan.definition.?.metadata.object, .revision = scan.view.revision, .commitment = try scan.fingerprint(), .schema = try query.compiled.plan.schema.fingerprint() } };
            },
            .relational => |query| .{ .per_resource_snapshot_vector = try allocator.dupe(f.Relational.Cut, query.execution.bound.cuts) },
            .source => |source| sourceBasis(source.query.basis),
            .captured => |captured| if (captured.basis) |value| sourceBasis(value) else null,
            else => null,
        };
    }
    fn sourceBasis(value: q.Basis) g.session_protocol.Basis {
        return .{ .source = .{ .kind = value.cut.kind, .resource = value.cut.resource, .revision = value.cut.revision, .head = value.cut.head, .contract = value.contract, .schema = value.schema } };
    }
    pub fn nextBatch(self: *Read, maximum: u8) !g.ReadBatch {
        if (maximum == 0 or maximum > g.ReadBatch.max_rows) return error.InvalidQueryBudget;
        try self.host.deadline.check(self.host.io);
        try self.host.current();
        if (self.batch) |*batch| batch.deinit();
        self.batch = null;
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
            self.emitted_rows += result.len;
            result.complete = self.batch.?.complete;
            for (self.batch.?.rows[0..result.len], result.rows[0..result.len]) |row, *cells| cells.* = row.?.cells;
            return result;
        }
        const cells: ?[]const f.Types.Values.Cell = switch (self.value) {
            .single, .source, .captured => unreachable,
            .relational => |query| blk: {
                self.output = try query.next() orelse break :blk null;
                break :blk self.output.cells[0..self.output.len];
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
        result.complete = cells == null;
        return result;
    }
};
pub fn loadCredential(allocator: std.mem.Allocator, io: std.Io, account: *const g.Configuration.Account) !g.Configuration.Credential {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, account.verifier_file, allocator, .limited(4096));
    defer allocator.free(bytes);
    defer std.crypto.secureZero(u8, bytes);
    const parsed = try std.json.parseFromSlice(g.Configuration.Credential, allocator, bytes, .{});
    defer parsed.deinit();
    try parsed.value.validate(account.ledger.account);
    if ((account.authentication == .password) != (parsed.value.verifier != null)) return error.InvalidAuthentication;
    if (parsed.value.principal != account.ledger.table_principal) return error.InvalidAuthentication;
    return parsed.value;
}
pub fn init(allocator: std.mem.Allocator, io: std.Io, config: *const g.Configuration, index: usize, runtime: *g.AccountRuntime, credential: g.Configuration.Credential, database: []const u8, dialect: f.Sql.Dialect, cancellation: *std.atomic.Value(bool), active: *std.atomic.Value(bool)) !*Self {
    const account = &config.accounts[index];
    const binding = try account.database(database);
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    var directory = try std.Io.Dir.cwd().openDir(io, config.spill_directory, .{});
    errdefer directory.close(io);
    self.* = .{ .allocator = allocator, .io = io, .config = config, .account = account, .runtime = runtime, .credential = credential, .database = undefined, .dialect = dialect, .wire = g.station.client.Client.init(allocator, io, config.native_url), .table = undefined, .observer = undefined, .directory = directory, .cancellation = cancellation, .active = active, .deadline = .{ .start = std.Io.Clock.awake.now(io), .milliseconds = config.limits.command_ms, .cancellation = cancellation } };
    errdefer self.wire.deinit();
    // Database names borrow immutable configuration, never a startup frame.
    for (account.databases) |selected| if (std.mem.eql(u8, selected.name, database)) {
        self.database = selected.name;
        break;
    };
    self.wire.timeout_ms = config.request_timeout_ms;
    self.table = .{ .transport = &self.wire, .connection = .{ .scope = .{ .realm = account.ledger.realm, .resource = binding.resource, .catalog = binding.catalog }, .owner = binding.owner, .principal = account.ledger.table_principal, .namespace = binding.namespace, .role = binding.role }, .key = runtime.coordinator.table_key, .reader = .{ .wire = &self.wire, .realm = account.ledger.realm, .principal = account.ledger.reader, .key = runtime.coordinator.reader_key } };
    self.observer = .{ .transport = &self.wire, .ledger = runtime.ledger, .principal = account.ledger.ingress, .key = runtime.ingress.key };
    try self.current();
    if (config.settings) |configured| {
        self.settings_wire = g.station.client.Client.init(allocator, io, configured.url);
        self.settings_wire.?.timeout_ms = config.request_timeout_ms;
        errdefer self.settings_wire.?.deinit();
        self.settings_session = try self.fresh(q.SettingsSession.capture, .{try Settings.client(self)});
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
    if (!self.runtime.ready.load(.acquire)) return error.GatewayOwnerUnavailable;
    const credential = try loadCredential(self.allocator, self.io, self.account);
    if (!std.meta.eql(credential, self.credential)) return error.GatewayCredentialChanged;
    const native: g.station.client.AuthorizationClient = .{ .transport = &self.wire, .realm = self.account.ledger.realm, .principal = self.account.ledger.table_principal, .key = self.table.key, .role = self.table.connection.role };
    const identity = (try native.read(.identity)).body.authorization.body.identity;
    try credential.checkIdentity(identity.principal, identity.login_role, identity.credential_epoch);
    _ = try self.fresh(c.TableClient.describeDatabase, .{&self.table});
    const state = try self.observer.reader().query(.{ .process = self.account.ledger.owner });
    if (state.body != .process) return error.InvalidAuthorityResponse;
    const process = state.body.process.process;
    if (process.generation != self.account.generation or process.owner != self.account.ledger.worker) return error.StaleGatewayCoordinator;
    if (process.lifecycle != .running or process.failure != null or !p.Growth.processReady(process)) return error.GatewayOwnerUnavailable;
    if (self.source) |source| try source.current();
}
/// Exact-current metadata reads may race a concurrent committed catalog turn.
/// Retry only pure preparation/validation, retaining the original statement on
/// validation. Never replay a query iterator, write, or signed native request.
pub fn fresh(self: *Self, comptime function: anytype, args: std.meta.ArgsTuple(@TypeOf(function))) !@typeInfo(@typeInfo(@TypeOf(function)).@"fn".return_type.?).error_union.payload {
    var attempts: u8 = 0;
    while (true) {
        try self.deadline.check(self.io);
        return @call(.auto, function, args) catch |err| {
            const stale = ((err == error.Rejected or err == error.Conflict) and self.wire.last_rejection == .StaleStateResource) or err == error.CatalogDefinitionChanged;
            const unavailable = g.station.client.Client.unavailable(err) or self.wire.contended(err) or err == error.GatewayOwnerUnavailable;
            if ((!stale and !unavailable) or attempts == 64) return err;
            attempts += 1;
            try self.io.sleep(.fromMilliseconds(if (unavailable) 20 else 1), .awake);
            continue;
        };
    }
}
pub fn begin(self: *Self) !void {
    self.cancellation.store(false, .release);
    self.operation = null;
    self.terminal = null;
    self.deadline.start = std.Io.Clock.awake.now(self.io);
    self.deadline.milliseconds = self.commandMilliseconds();
    self.active.store(true, .release);
    errdefer self.active.store(false, .release);
    try self.current();
}
pub fn end(self: *Self) void {
    self.active.store(false, .release);
}
pub fn reset(self: *Self) !void {
    try self.current();
    self.operation = null;
    self.settings_session.reset();
}
pub fn selectSource(self: *Self, name: ?[]const u8) !void {
    if (self.source) |source| source.deinit();
    self.source = null;
    if (name) |selected| self.source = try self.fresh(g.SourceSession.init, .{ self, try self.account.source(selected, self.database) });
}
pub fn sourceName(self: *const Self) ?[]const u8 {
    return if (self.source) |source| source.configuration.name else null;
}
pub fn selectDatabase(self: *Self, name: []const u8) !void {
    try self.current();
    const binding = try self.account.database(name);
    var candidate = self.table;
    candidate.connection.scope.resource = binding.resource;
    candidate.connection.scope.catalog = binding.catalog;
    candidate.connection.owner = binding.owner;
    candidate.connection.namespace = binding.namespace;
    candidate.connection.role = binding.role;
    _ = try candidate.describeDatabase();
    try self.selectSource(null);
    self.table = candidate;
    for (self.account.databases) |selected| if (std.mem.eql(u8, selected.name, name)) {
        self.database = selected.name;
        break;
    };
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
    try self.current();
    const result = try self.allocator.create(Prepared);
    errdefer self.allocator.destroy(result);
    if (self.native_profile) {
        if (try self.fresh(Inspection.prepare, .{ self, sql })) |inspection| {
            result.* = .{ .inspection = inspection };
            return result;
        }
    }
    if (try g.Probe.parse(sql, self.dialect)) |probe| result.* = .{ .probe = probe } else if (try Settings.prepare(self, sql)) |settings| result.* = .{ .settings = settings } else if (self.source) |source| result.* = .{ .source = try self.fresh(g.SourceSession.prepare, .{ source, sql }) } else result.* = .{ .native = try self.fresh(g.Statement.prepareDiagnostic, .{ self.allocator, &self.table, sql, self.dialect, if (self.native_profile) g.Statement.Profile.native else g.Statement.Profile.wire, read_options, &self.compile_binding }) };
    return result;
}
pub fn destroy(self: *Self, prepared: *Prepared) void {
    if (prepared.* == .native) prepared.native.deinit();
    if (prepared.* == .source) prepared.source.deinit();
    if (prepared.* == .captured) prepared.captured.deinit();
    if (prepared.* == .settings) prepared.settings.deinit();
    if (prepared.* == .inspection) prepared.inspection.deinit();
    self.allocator.destroy(prepared);
}
pub fn validate(self: *Self, prepared: *Prepared) !void {
    try self.deadline.check(self.io);
    try self.current();
    switch (prepared.*) {
        .native => |*statement| try self.fresh(g.Statement.validate, .{ statement, &self.table }),
        .source => |*statement| try self.fresh(g.SourceSession.validate, .{ self.source orelse return error.UnknownSqlSource, statement }),
        .captured => |*captured| try g.CapturedOperations.validateResult(self, captured),
        .inspection => |*inspection| try self.fresh(Inspection.validate, .{ inspection, self }),
        .settings => |*settings| try self.fresh(Settings.authorize, .{ self, &settings.plan }),
        .probe => {}, // current() already validates the login and database.
    }
}
pub fn bind(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !void {
    switch (prepared.*) {
        .native => |*statement| try statement.checkValues(self.allocator, values),
        .source => |*statement| {
            var bound = try self.source.?.bind(statement, values);
            bound.deinit();
        },
        .probe, .settings, .inspection, .captured => if (values.len != 0) return error.WireParameterCountMismatch,
    }
}
pub fn openRead(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !*Read {
    try self.validate(prepared);
    const read = try self.allocator.create(Read);
    errdefer self.allocator.destroy(read);
    read.* = .{ .host = self, .value = undefined };
    switch (prepared.*) {
        .captured => |*captured| read.value = .{ .captured = try g.CapturedOperations.Read.init(self, captured) },
        .source => |*statement| read.value = .{ .source = try g.SourceSession.Read.init(self.source.?, statement, values) },
        .inspection => |*inspection| read.value = .{ .inspection = .{ .host = self, .prepared = inspection } },
        .settings => |*settings| read.value = .{ .settings = try Settings.Read.init(self, settings) },
        .probe => |probe| read.value = .{ .probe = probe },
        .native => |*statement| {
            var nonces: [f.Relational.max_sources][16]u8 = undefined;
            try self.io.randomSecure(std.mem.asBytes(&nonces));
            if (statement.plan == .relational) {
                var path: [64]u8 = undefined;
                const name = try std.fmt.bufPrint(&path, "sql-{x}", .{nonces[0]});
                read.value = .{ .relational = try statement.openRelational(self.allocator, self.io, self.directory, name, &self.table, nonces, read_options, self.cancellation) };
            } else read.value = .{ .single = try statement.openSelect(self.allocator, &self.table, values, nonces[0], .{ .requests = 10000, .rows = 10000, .result_bytes = 16 * 1024 * 1024 }, self.cancellation) };
        },
    }
    return read;
}
pub fn closeRead(self: *Self, read: *Read) void {
    const rejection = self.wire.last_rejection;
    defer self.wire.last_rejection = rejection;
    if (read.batch) |*batch| batch.deinit();
    switch (read.value) {
        .single => |*query| {
            query.close() catch {};
            query.deinit();
        },
        .relational => |query| {
            query.close() catch {};
            query.deinit();
        },
        .source => |*source| source.deinit(),
        .captured => |*captured| captured.deinit(),
        .probe, .inspection => {},
        .settings => |*settings| settings.deinit(),
    }
    self.allocator.destroy(read);
}
pub fn write(self: *Self, prepared: *Prepared, values: []const ?f.Types.Values.Atom) !struct { kind: g.Completion, count: u64, changed: u64 } {
    try self.validate(prepared);
    if (prepared.* == .settings) {
        try Settings.mutate(self, &prepared.settings);
        return .{ .kind = .set, .count = 0, .changed = 0 };
    }
    if (prepared.* == .probe) {
        if (prepared.probe.kind != .set) return error.ExpectedGatewayWrite;
        return .{ .kind = .set, .count = 0, .changed = 0 };
    }
    const terminal = try self.runtime.execute(self.allocator, &self.observer, &self.table, &prepared.native, values, self.deadline, &self.operation);
    self.terminal = terminal;
    switch (terminal.state) {
        .applied, .unchanged => {},
        .rejected => return error.GatewayMutationRejected,
        .cancelled, .upload_cancelled => return error.GatewayMutationCancelled,
    }
    try self.validate(prepared);
    return .{ .kind = switch (prepared.native.kind()) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
        .create => .create_table,
        .alter => .alter_table,
        .drop => .drop_table,
        .select => return error.ExpectedGatewayWrite,
    }, .count = terminal.matched, .changed = terminal.changed };
}
pub fn diagnostic(self: *Self, err: anyerror) struct { state: [5]u8, message: []const u8, detail: ?[]const u8 } {
    if (self.diagnostics) |diagnostics| diagnostics.event(.{ .name = "sql.request.failed", .level = .warn, .outcome = .failed, .error_type = if (self.wire.last_rejection) |rejection| @tagName(rejection) else @errorName(err) });
    const info: struct { [5]u8, []const u8 } = if (err == error.AuthorityUnavailable and self.wire.last_rejection == .HttpCapacity) .{ "53000".*, "Native request capacity exhausted; inspect admitted writes before retrying SQL" } else switch (err) {
        error.CatalogDenied, error.AccessDenied, error.GatewayDatabaseDenied => .{ "42501".*, "Current permission denied" },
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
        error.WireValueOutOfRange => .{ "22003".*, "Value is out of range" },
        error.CatalogIdentityConflict, error.CatalogDefinitionChanged => .{ "55000".*, "Prepared source changed; prepare again" },
        error.GatewayOwnerUnavailable, error.StaleGatewayCoordinator => .{ "55000".*, "Gateway owner is not ready; inspect admitted writes before retrying SQL" },
        error.TooManyWireStatements, error.TooManyWirePortals, error.OutOfMemory => .{ "54000".*, "Session capacity exceeded" },
        error.CellTooLarge => .{ "54000".*, "Bound scalar exceeds the 4096-byte limit" },
        error.UnknownWireStatement, error.UnknownWirePortal => .{ "26000".*, "Unknown prepared statement or portal" },
        error.DuplicateWireStatement, error.DuplicateWirePortal => .{ "42P05".*, "Prepared name already exists" },
        error.GatewayMutationRejected => blk: {
            const terminal = self.terminal orelse break :blk .{ "XX000".*, "Missing terminal observation" };
            break :blk switch (terminal.kind) {
                .dml => switch (terminal.reason) {
                    1, 2 => .{ "23505".*, "Row identity already exists" },
                    3, 4 => .{ "23502".*, "Required value is missing or NULL" },
                    5 => .{ "22001".*, "Character limit exceeded" },
                    6, 7 => .{ "22003".*, "Value is out of range or inexact" },
                    else => .{ "23000".*, "Table mutation rejected; inspect its recorded outcome" },
                },
                .ddl => switch (terminal.reason) {
                    1 => .{ "42P07".*, "Table name already exists" },
                    3 => .{ "42P01".*, "Table does not exist" },
                    else => .{ "55000".*, "Table identity or schema changed" },
                },
                .upload => .{ "XX000".*, "Unexpected upload rejection" },
            };
        },
        error.GatewayMutationCancelled => .{ "57014".*, "Table operation cancelled" },
        error.UnsupportedGatewayStatement, error.UnsupportedExecutionCycle, error.UnsupportedWireType => .{ "0A000".*, "Operation is outside the selected SQL profile" },
        error.InvalidSqlSyntax, error.ExpectedIdentifier, error.UnexpectedToken => .{ "42601".*, "SQL syntax rejected" },
        error.TableNotFound => .{ "42P01".*, "Table does not exist" },
        error.EmptyWireQuery => .{ "42601".*, "Query is empty" },
        else => .{ "XX000".*, "Request failed; inspect admitted work before retrying SQL" },
    };
    const detail = if (self.operation) |id| std.fmt.bufPrint(&self.detail_buffer, "Gateway operation {d}; sending SQL again creates new work", .{id}) catch null else null;
    return .{ .state = info[0], .message = info[1], .detail = detail };
}

test "capacity diagnostics retain operation uncertainty and do not override denial" {
    var host: Self = undefined;
    host.diagnostics = null;
    host.operation = 17;
    host.wire.last_rejection = .HttpCapacity;
    const capacity = host.diagnostic(error.AuthorityUnavailable);
    try std.testing.expectEqualStrings("53000", &capacity.state);
    try std.testing.expect(std.mem.indexOf(u8, capacity.detail.?, "17") != null);
    try std.testing.expectEqualStrings("42501", &host.diagnostic(error.AccessDenied).state);
    try std.testing.expectEqualStrings("23502", &host.diagnostic(error.NullNotAllowed).state);
    try std.testing.expectEqualStrings("54000", &host.diagnostic(error.CellTooLarge).state);
    try std.testing.expectEqualStrings("55000", &host.diagnostic(error.GatewayOwnerUnavailable).state);
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
    host.io = t.io;
    host.wire.last_rejection = null;
    host.deadline = .{ .start = std.Io.Clock.awake.now(t.io), .milliseconds = 5000 };
    var read: Observation = .{};
    try t.expectEqual(@as(u32, 17), try host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 3), read.attempts);
    read = .{ .failure = error.AccessDenied };
    try t.expectError(error.AccessDenied, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 1), read.attempts);
    read = .{ .failures = 100 };
    try t.expectError(error.AuthorityUnavailable, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 65), read.attempts);
    host.deadline.milliseconds = 0;
    read = .{};
    try t.expectError(error.GatewayDeadline, host.fresh(Observation.run, .{&read}));
    try t.expectEqual(@as(u32, 0), read.attempts);
}

pub fn commandMilliseconds(self: *const Self) u32 {
    const requested = self.settings_session.timeout();
    return if (requested == 0) self.config.limits.command_ms else @intCast(@min(requested, self.config.limits.command_ms));
}

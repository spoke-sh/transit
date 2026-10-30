//! Shared request coordination inside one exclusive local data owner. A catalog
//! writer excludes row admission; independent Tables take shared directory access
//! and separate bounded lock stripes. These locks contain no durable identities.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Service = @import("LocalTableService.zig");
const w = c.DirectTableProtocol;
pub const Protocol = w;
const Self = @This();
const stripe_count = 64;
pub const request_owners = 10;
const ResidentSlot = struct { mutex: std.Io.Mutex = .init, value: ?*Service.Resident = null };
pub const Config = struct {
    catalog: c.DirectCatalog.Configuration,
    registrar: struct { principal: u64, seed_file: []const u8, role: ?u64 = null },
    statement_scan_rows: u64 = 1_000_000,
    statement_scan_bytes: u64 = 64 * 1024 * 1024,
    client_token_quota: u64 = 1_000_000,
    transaction_limits: c.protocol.Transaction.Limits = c.DirectTransaction.default_limits,
    transaction_account_limits: c.DirectClientToken.TransactionReservations = .defaults,
};

configuration: c.DirectCatalog.Configuration,
registrar: @FieldType(Service, "registrar"),
options: c.DirectCatalog.Options,
recovery: c.DirectCatalog.RecoveryState,
recovery_mutex: std.Io.Mutex = .init,
directory: std.Io.RwLock = .init,
tables: [stripe_count]std.Io.Mutex = @splat(.init),
/// Disposable prefix per lock stripe. Name-only lookups borrow a stripe for
/// their hint too; the resolved object/partition must still match at open.
/// Collision causes full recovery, never a limit on durable Table population.
table_recovery: [stripe_count]?c.storage.TablePartition.RecoveryState = @splat(null),
residents: [request_owners]ResidentSlot = @splat(.{}),
control_residents: [2]ResidentSlot = @splat(.{}),
/// Retained caches and owner work have a separate aggregate bound from parsed
/// requests/responses. Data exhaustion cannot consume the control reserve.
resident_memory: @import("DirectRequestMemory.zig") = .{},

/// The embedding owner joins every request before closing retained workspaces.
pub fn deinit(self: *Self) void {
    for (&self.residents) |*slot| if (slot.value) |resident| resident.destroy();
    for (&self.control_residents) |*slot| if (slot.value) |resident| resident.destroy();
    std.debug.assert(self.resident_memory.data.used.load(.acquire) == 0);
    std.debug.assert(self.resident_memory.control.used.load(.acquire) == 0);
    self.* = undefined;
}

pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config, engine: *backend.DataAuthority.Engine) !Self {
    try config.catalog.validate();
    try config.transaction_limits.validate();
    inline for (@typeInfo(c.DirectClientToken.TransactionReservations).@"struct".field_names) |name| {
        if (@field(config.transaction_account_limits, name) == 0) return error.InvalidTableConfiguration;
    }
    if (config.statement_scan_rows == 0 or config.statement_scan_bytes == 0 or config.client_token_quota == 0) return error.InvalidTableConfiguration;
    if (config.catalog.scope.realm != engine.genesis.realm or config.registrar.principal > c.protocol.max_counter) return error.InvalidTableConfiguration;
    if (config.registrar.role) |role| try c.protocol.Authorization.roleId(role);
    const key = try @import("transit_client").readKey(allocator, io, config.registrar.seed_file);
    const owner = engine.journal.backend;
    var control: backend.DataStore = .{ .backend = owner, .control = true };
    var data: backend.DataStore = .{ .backend = owner };
    const options: c.DirectCatalog.Options = .{ .client_token_quota = config.client_token_quota, .transaction_limits = config.transaction_limits, .transaction_account_limits = config.transaction_account_limits, .table = .{ .statement_scan_rows = config.statement_scan_rows, .statement_scan_bytes = config.statement_scan_bytes } };
    var catalog = try c.DirectCatalog.init(allocator, config.catalog, control.log(), control.objects(), data.log(), data.objects(), options);
    defer catalog.deinit();
    // Validate retained configuration/history before listener readiness. This
    // does not initialize or execute an application's catalog declaration.
    try catalog.recover();
    return .{ .configuration = config.catalog, .registrar = .{ .principal = config.registrar.principal, .key = key, .role = config.registrar.role }, .options = options, .recovery = try catalog.recoveryState() };
}
pub fn warm(self: *Self, engine: *backend.DataAuthority.Engine) !void {
    const owner = engine.journal.backend;
    if (self.residents[0].value == null) {
        self.residents[0].value = try Service.Resident.create(owner.allocator, self.resident_memory.request(owner.allocator, false), owner, self.configuration, self.options, self.recovery);
    }
    if (self.control_residents[0].value == null) {
        self.control_residents[0].value = try Service.Resident.create(owner.allocator, self.resident_memory.request(owner.allocator, true), owner, self.configuration, self.options, self.recovery);
    }
}
fn exclusive(action: w.Action) bool {
    return switch (action) {
        .transaction => true,
        .client_token => |value| value == .bind,
        .client_progress => |value| value == .update,
        .initialize, .admit_ddl, .check_set, .name_assertion, .name_preview => true,
        .namespace_operation => |value| value.command != .inspect,
        .dependency_operation => |value| value.command != .inspect,
        .resource_operation => |value| value.command != .inspect,
        .admit_saved => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => true,
            .insert, .update, .delete => false,
        },
        .operation => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => value.command != .inspect,
            .insert, .update, .delete => false,
        },
        else => false,
    };
}
fn target(action: w.Action) ?u64 {
    return switch (action) {
        .check => |value| if (value.target) |expected| expected.object.object else null,
        inline .observe, .read_current => |value| value.interpretation.object.object,
        inline .storage, .flush => |value| value.object.object,
        .read_authority => |value| value.object,
        .stage => |value| value.intent.work.binding().target.object,
        inline .admit_saved, .commit_saved => |value| value.binding.target.object,
        .preview => |value| value.binding.target.object,
        inline .preview_rows, .preview_statement, .admit_rows, .admit_statement => |value| value.binding.target.object,
        .operation => |value| value.binding.target.object,
        inline .pin, .retain_history, .pin_status => |value| value.object.object,
        inline .scan, .column_scan, .filter_scan, .read_key, .key_range, .history => |value| value.snapshot.object.object,
        inline .snapshot, .history_start, .history_source, .release => |value| value.object.object,
        .history_scan => |value| value.source.object.object,
        else => null,
    };
}
fn stripe(action: w.Action) ?usize {
    if (target(action)) |object| return @intCast(object % stripe_count);
    return switch (action) {
        // A name lookup discloses an observed definition, not a mutation. It
        // already tolerates concurrent row acceptance; this lock serializes
        // only its disposable hint. Catalog changes still require directory's
        // exclusive side, and DirectCatalog verifies identity and current rights.
        .lookup => |value| @intCast(std.hash.Wyhash.hash(value.namespace, value.name) % stripe_count),
        else => null,
    };
}
pub fn execute(self: *Self, io: std.Io, engine: *backend.DataAuthority.Engine, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request) ![]const u8 {
    return self.executeCapacity(io, engine, arena, output_allocator, request, false);
}
pub fn executeCapacity(self: *Self, io: std.Io, engine: *backend.DataAuthority.Engine, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request, control: bool) ![]const u8 {
    return self.executeMeasured(io, engine, arena, output_allocator, request, control, null);
}
pub fn executeMeasured(self: *Self, io: std.Io, engine: *backend.DataAuthority.Engine, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request, control: bool, memory_report: ?*?@import("DirectRequestMemory.zig").Report) ![]const u8 {
    return self.executeResult(.json, io, engine, arena, output_allocator, request, control, memory_report);
}
pub fn executeTyped(self: *Self, io: std.Io, engine: *backend.DataAuthority.Engine, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request, control: bool) !w.Response {
    return self.executeResult(.typed, io, engine, arena, output_allocator, request, control, null);
}
fn executeResult(self: *Self, comptime format: Service.Output, io: std.Io, engine: *backend.DataAuthority.Engine, arena: *std.heap.ArenaAllocator, output_allocator: std.mem.Allocator, request: w.Request, control: bool, memory_report: ?*?@import("DirectRequestMemory.zig").Report) !Service.Result(format) {
    if (control and request.transport().control == null) return error.InvalidRequest;
    const write = exclusive(request.action);
    if (write) try self.directory.lock(io) else try self.directory.lockShared(io);
    defer if (write) self.directory.unlock(io) else self.directory.unlockShared(io);
    const index = if (write) null else stripe(request.action);
    const mutex = if (index) |slot| &self.tables[slot] else null;
    if (mutex) |lock| try lock.lock(io);
    defer if (mutex) |lock| lock.unlock(io);
    try self.recovery_mutex.lock(io);
    var recovered = self.recovery;
    self.recovery_mutex.unlock(io);
    defer {
        self.recovery_mutex.lockUncancelable(io);
        defer self.recovery_mutex.unlock(io);
        if (recovered.root.next_lsn > self.recovery.root.next_lsn) self.recovery = recovered;
    }
    var options = self.options;
    if (index) |slot| options.table_recovery = &self.table_recovery[slot];
    // Storage owners contain no request pointers and can serve any free lane.
    // Their count is bounded independently of the durable Table population.
    const slots: []ResidentSlot = if (control) &self.control_residents else &self.residents;
    const resident = for (slots) |*slot| {
        if (slot.mutex.tryLock()) break slot;
    } else blk: {
        try slots[0].mutex.lock(io);
        break :blk &slots[0];
    };
    defer resident.mutex.unlock(io);
    if (resident.value) |value| value.probe.begin(false) else resident.value = Service.Resident.create(engine.journal.backend.allocator, self.resident_memory.request(engine.journal.backend.allocator, control), engine.journal.backend, self.configuration, options, recovered) catch |err| return if (err == error.TableResidentCapacity) (if (control) error.ControlCapacity else error.StorageQuota) else err;
    errdefer {
        resident.value.?.destroy();
        resident.value = null;
    }
    defer if (memory_report) |report| {
        report.* = @import("DirectRequestMemory.zig").Report.capture(&resident.value.?.probe);
    };
    var service: Service = .{ .engine = engine, .configuration = self.configuration, .registrar = self.registrar, .options = options, .recovery_state = &recovered, .resident = resident.value };
    return service.executeResult(format, arena, output_allocator, request) catch |err| {
        if (err == error.OutOfMemory and resident.value.?.memory.exhausted)
            return if (control) error.ControlCapacity else error.StorageQuota;
        return err;
    };
}

test "projected and filtered Table reads share the retained object's host lock" {
    const snapshot: w.Snapshot = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 97 }, .handle = undefined };
    const projected: w.Action = .{ .column_scan = .{ .snapshot = snapshot, .columns = &.{0}, .after = null, .limits = .{} } };
    const filtered: w.Action = .{ .filter_scan = .{ .snapshot = snapshot, .plan = .{ .base64 = "" }, .fingerprint = @splat(0), .after = null, .limits = .{} } };
    try std.testing.expectEqual(@as(?u64, 97), target(projected));
    try std.testing.expectEqual(@as(?u64, 97), target(filtered));
    try std.testing.expect(!exclusive(projected) and !exclusive(filtered));
}

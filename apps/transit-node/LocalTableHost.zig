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
pub const Config = struct {
    catalog: c.DirectCatalog.Configuration,
    registrar: struct { principal: u64, seed_file: []const u8, role: ?u64 = null },
    statement_scan_rows: u64 = 1_000_000,
    statement_scan_bytes: u64 = 64 * 1024 * 1024,
};

configuration: c.DirectCatalog.Configuration,
registrar: @FieldType(Service, "registrar"),
options: c.DirectCatalog.Options,
recovery: c.DirectCatalog.RecoveryState,
recovery_mutex: std.Io.Mutex = .init,
directory: std.Io.RwLock = .init,
tables: [64]std.Io.Mutex = @splat(.init),

pub fn init(allocator: std.mem.Allocator, io: std.Io, config: Config, engine: *backend.DataAuthority.Engine) !Self {
    try config.catalog.validate();
    if (config.statement_scan_rows == 0 or config.statement_scan_bytes == 0) return error.InvalidTableConfiguration;
    if (config.catalog.scope.realm != engine.genesis.realm or config.registrar.principal > c.protocol.max_counter) return error.InvalidTableConfiguration;
    if (config.registrar.role) |role| try c.protocol.Authorization.roleId(role);
    const key = try @import("transit_client").readKey(allocator, io, config.registrar.seed_file);
    const owner = engine.journal.backend;
    var control: backend.DataStore = .{ .backend = owner, .control = true };
    var data: backend.DataStore = .{ .backend = owner };
    const options: c.DirectCatalog.Options = .{ .table = .{ .statement_scan_rows = config.statement_scan_rows, .statement_scan_bytes = config.statement_scan_bytes } };
    var catalog = try c.DirectCatalog.init(allocator, config.catalog, control.log(), control.objects(), data.log(), data.objects(), options);
    defer catalog.deinit();
    // Validate retained configuration/history before listener readiness. This
    // does not initialize or execute an application's catalog declaration.
    try catalog.recover();
    return .{ .configuration = config.catalog, .registrar = .{ .principal = config.registrar.principal, .key = key, .role = config.registrar.role }, .options = options, .recovery = try catalog.recoveryState() };
}
fn exclusive(action: w.Action) bool {
    return switch (action) {
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
        .read_authority => |value| value.object,
        .stage => |value| value.intent.work.binding().target.object,
        .admit_saved => |value| value.binding.target.object,
        .preview => |value| value.binding.target.object,
        inline .preview_rows, .preview_statement, .admit_rows, .admit_statement => |value| value.binding.target.object,
        .operation => |value| value.binding.target.object,
        inline .pin, .retain_history, .pin_status => |value| value.object.object,
        inline .scan, .read_key, .key_range, .history => |value| value.snapshot.object.object,
        inline .snapshot, .history_start, .history_source, .release => |value| value.object.object,
        .history_scan => |value| value.source.object.object,
        else => null,
    };
}
pub fn execute(self: *Self, io: std.Io, engine: *backend.DataAuthority.Engine, arena: *std.heap.ArenaAllocator, request: w.Request, output: []u8) ![]const u8 {
    const write = exclusive(request.action);
    if (write) try self.directory.lock(io) else try self.directory.lockShared(io);
    defer if (write) self.directory.unlock(io) else self.directory.unlockShared(io);
    const mutex = if (!write) if (target(request.action)) |object| &self.tables[@intCast(object % self.tables.len)] else null else null;
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
    var service: Service = .{ .engine = engine, .configuration = self.configuration, .registrar = self.registrar, .options = self.options, .recovery_state = &recovered };
    return service.execute(arena, request, output);
}

//! Persist exact public operations before submission and receipts before derivation.
const std = @import("std");
const q = @import("transit_query");
const p = q.protocol;
const g = p.Growth;
const Files = @import("Files.zig");
const Config = @import("Config.zig");
pub const caller = 10;
pub const source = 20;
pub const requester = 21;
pub const courier = 22;
pub const maintenance = 23;
pub const installer = 24;
pub const board = 25;
pub const read_permissions = p.State.permission(.inspect) | p.State.permission(.read);
pub const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 128, .result_bytes = 1048576 };
pub const Record = struct {
    version: u8 = 1,
    definition: g.Definition,
    identity: Config.Identity,
    installation: [16]u8,
    root_public: [32]u8,
    position: u64 = 0,
    genesis_observed: bool = false,
    provision: [14]?u64 = @splat(null),
    authorization_steps: [8]?u64 = @splat(null),
    authorization_change: ?u64 = null,
    initialized: [3]bool = .{ false, false, false },
    default_table_complete: bool,
    complete: bool = false,
    registration: ?q.wire.bootstrap.GrowingRegistration = null,
    pending: ?Pending = null,
    installer_receipt: ?u64 = null,
    board_receipts: [3]?u64 = @splat(null),
};
const Pending = struct { signed: g.SignedRequest, effect: enum { provision, initialize, activation, installer, board, authority }, index: u8 };
const Self = @This();
init: std.process.Init,
config: Config,
record: Record,
wire: *q.wire.Client,
root: p.Ed25519.KeyPair,
caller_key: p.Ed25519.KeyPair,
record_path: []const u8,
failed: bool = false,
pub fn path(self: *const Self, name: []const u8) ![]const u8 {
    return std.fs.path.join(self.init.arena.allocator(), &.{ self.config.installation, name });
}
pub fn save(self: *Self) !void {
    Files.json(self.init.io, self.init.gpa, self.record_path, self.record) catch |err| {
        self.failed = true;
        return err;
    };
}
pub fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    const response = try self.wire.query(.{ .realm = self.config.realm, .principal = 0, .kind = kind }, self.root);
    if (response.position < self.record.position) return error.AuthorityRollback;
    if (response.position > self.record.position or !self.record.genesis_observed) {
        self.record.position = response.position;
        self.record.genesis_observed = true;
        try self.save();
    }
    return response;
}
pub fn flush(self: *Self) !void {
    const pending = self.record.pending orelse return;
    const receipt = try self.wire.submit(pending.signed);
    switch (pending.effect) {
        .provision => self.record.provision[pending.index] = receipt.position,
        .initialize => self.record.initialized[pending.index] = true,
        .activation => {},
        .authority => switch (pending.signed.request.command.authorization) {
            .begin => self.record.authorization_change = receipt.position,
            .advance => {},
            .abandon => self.record.authorization_change = null,
            .publish => |id| {
                const observed = try self.query(.{ .authorization = .{ .kind = .{ .change = id } } });
                const outcome = observed.body.authorization.body.change;
                if (outcome.status != .published) return error.UnresolvedProvisioning;
                self.record.authorization_steps[pending.index] = outcome.created_id orelse 0;
                self.record.authorization_change = null;
            },
        },
        .installer => self.record.installer_receipt = receipt.position,
        .board => self.record.board_receipts[pending.index] = receipt.position,
    }
    self.record.position = @max(self.record.position, receipt.position);
    self.record.pending = null;
    try self.save();
}
pub fn submit(self: *Self, principal: u64, command: g.Command, effect: @FieldType(Pending, "effect"), index: u8) !void {
    if (self.record.pending != null) return error.UnresolvedProvisioning;
    const key = if (principal == 0) self.root else self.caller_key;
    const basis = try self.wire.query(.{ .realm = self.config.realm, .principal = principal, .kind = .{ .capabilities = {} } }, key);
    if (basis.position < self.record.position) return error.AuthorityRollback;
    self.record.position = basis.position;
    self.record.pending = .{ .signed = try g.sign(.{ .realm = self.config.realm, .principal = principal, .sequence = try std.math.add(u64, basis.principal_sequence, 1), .command = command }, key), .effect = effect, .index = index };
    try self.save();
    try self.flush();
}
pub fn connection(self: *Self) q.UnifiedClient.Connection {
    return connectionFrom(self.record, self.config.realm);
}
pub fn connectionFrom(record: Record, realm: u64) q.UnifiedClient.Connection {
    const done = record.provision;
    return .{ .realm = realm, .principal = caller, .requester = done[0].?, .requests = done[1].?, .source = done[4].?, .resource = done[5].? };
}
pub fn catalogFor(c: q.UnifiedClient.Connection, record: Record) q.catalog.TableCatalogRecords.Configuration {
    return .{ .scope = .{ .realm = c.realm, .resource = c.resource, .catalog = 1 }, .owner = c.source, .administrator = caller, .database_name = q.catalog.TableAuthority.Name.init("transit") catch unreachable, .authority = .{ .database_domain = record.authorization_steps[3].?, .schema_domain = record.authorization_steps[4].?, .table_domain = record.authorization_steps[5].?, .database = record.authorization_steps[6].?, .initial_schema = 1, .initial_schema_authority = record.authorization_steps[7].? }, .table_limits = .{ .record_bytes = q.fuze.TableRow.max_bytes, .staging_bytes = 2 * q.fuze.TableRow.max_bytes, .staging_records = 2 } };
}
pub fn provision(self: *Self) !void {
    try self.flush();
    for (0..self.record.provision.len) |i| {
        if (self.record.provision[i] != null) continue;
        if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
        if (i == 9) {
            try self.provisionAuthorization();
            self.record.provision[i] = self.record.position;
            try self.save();
            continue;
        }
        const done = self.record.provision;
        const command: g.Command = switch (i) {
            0, 4 => .{ .spawn = .{} },
            1 => .{ .create_resource = .{ .writer = done[0].? } },
            2 => .{ .grant_resource = .{ .resource = done[1].?, .subject = 0, .permissions = p.State.all_permissions } },
            3 => .{ .associate = .{ .pid = done[0].?, .name = try .init("state"), .resource = done[1].? } },
            5 => .{ .create_resource = .{ .writer = done[4].? } },
            6 => .{ .grant_resource = .{ .resource = done[5].?, .subject = 0, .permissions = p.State.all_permissions } },
            7 => .{ .associate = .{ .pid = done[4].?, .name = try .init("state"), .resource = done[5].? } },
            8 => .{ .associate = .{ .pid = done[4].?, .name = try .init("requests"), .resource = done[1].?, .required = false } },
            9 => unreachable,
            10 => .{ .grant = .{ .subject = courier, .public_key = (try q.wire.readKey(self.init.gpa, self.init.io, try self.path("courier.seed"))).public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.delivery) | p.permission(.send) } },
            11 => .{ .grant = .{ .subject = maintenance, .public_key = (try q.wire.readKey(self.init.gpa, self.init.io, try self.path("maintenance.seed"))).public_key.toBytes(), .permissions = p.permission(.admin) | p.permission(.effect) | p.permission(.delivery) } },
            12 => .{ .grant_resource = .{ .resource = done[1].?, .subject = caller, .permissions = read_permissions } },
            13 => .{ .grant_resource = .{ .resource = done[5].?, .subject = caller, .permissions = read_permissions } },
            else => unreachable,
        };
        try self.submit(0, command, .provision, @intCast(i));
    }
    if (self.config.applications != null and self.record.installer_receipt == null) {
        var key = try q.wire.readKey(self.init.gpa, self.init.io, try self.path("installer.seed"));
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        try self.submit(0, .{ .create_principal = .{ .subject = installer, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.admin) } }, .installer, 0);
    }
}
/// Each installation action is recorded once. The pending signed operation and
/// native change record survive loss of any reply; finished grants are not replayed.
fn provisionAuthorization(self: *Self) !void {
    const scope: q.catalog.Model.Scope = .{ .realm = self.config.realm, .resource = self.record.provision[5].?, .catalog = 1 };
    const a = p.Authorization;
    const tables = q.catalog.TableAuthority;
    for (0..self.record.authorization_steps.len) |index| {
        while (self.record.authorization_steps[index] == null) {
            if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
            const done = self.record.authorization_steps;
            const action: a.Action = switch (index) {
                0 => .{ .create_role = .{ .name = try .init("local_owner"), .login = true } },
                1 => .{ .bind_credential = .{ .principal = caller, .role = done[0].?, .public_key = self.caller_key.public_key.toBytes() } },
                2 => .{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = done[0].?, .privileges = p.permission(.inspect) | p.permission(.send) } },
                3, 4, 5 => .{ .register_domain = .{ .registrar = source, .actions = tables.actions(switch (index) {
                    3 => .database,
                    4 => .schema,
                    else => .table,
                }) } },
                6 => .{ .register_object = .{ .domain = done[3].?, .owner = done[0].?, .binding = try tables.binding(scope, .database, 0) } },
                7 => .{ .register_object = .{ .domain = done[4].?, .owner = done[0].?, .schema = tables.reference(done[6].?), .binding = try tables.binding(scope, .schema, 1) } },
                else => unreachable,
            };
            const observation = try self.query(.{ .authorization = .{ .kind = if (self.record.authorization_change) |id| .{ .change = id } else .identity } });
            const policy = observation.body.authorization;
            const command: a.Command = if (self.record.authorization_change) |id| step: {
                const outcome = policy.body.change;
                if (outcome.status == .abandoned) {
                    self.record.authorization_change = null;
                    try self.save();
                    continue;
                }
                if (outcome.status == .published) return error.InvalidInstallationAuthority;
                if (outcome.basis != policy.revision) break :step .{ .abandon = id };
                break :step if (outcome.status == .ready) .{ .publish = id } else .{ .advance = id };
            } else .{ .begin = .{ .expected_revision = policy.revision, .action = action } };
            try self.submit(0, .{ .authorization = command }, .authority, @intCast(index));
        }
    }
}
/// Completed grants are never reissued on restart, including after revocation.
pub fn provisionBoard(self: *Self) !void {
    try self.flush();
    for (self.record.board_receipts, 0..) |receipt, i| {
        if (receipt != null) continue;
        if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
        var key = try q.wire.readKey(self.init.gpa, self.init.io, try self.path("board.seed"));
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        const c = self.connection();
        const command: g.Command = switch (i) {
            0 => .{ .create_principal = .{ .subject = board, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) } },
            1, 2 => .{ .grant_resource = .{ .subject = board, .resource = if (i == 1) c.resource else c.requests, .permissions = read_permissions } },
            else => unreachable,
        };
        try self.submit(0, command, .board, @intCast(i));
    }
}
pub fn activate(self: *Self, registration: q.wire.bootstrap.GrowingRegistration) !void {
    // The child owns the private key. Record its public registration before
    // granting anything, and resolve old frozen operations before calling here.
    self.record.registration = registration;
    try self.save();
    const c = self.connection();
    const resource = if (registration.principal == source) c.resource else c.requests;
    try self.submit(0, .{ .grant = .{ .subject = registration.principal, .public_key = registration.public_key, .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = registration.pid } }, .activation, 0);
    try self.submit(0, .{ .grant_resource = .{ .resource = resource, .subject = registration.principal, .permissions = p.State.all_permissions } }, .activation, 0);
    if (registration.principal == source) try self.submit(0, .{ .grant_resource = .{ .resource = c.requests, .subject = source, .permissions = read_permissions } }, .activation, 0);
    try self.submit(0, .{ .own = .{ .pid = registration.pid, .expected_generation = registration.generation - 1, .worker = registration.principal } }, .activation, 0);
}
pub fn initializeBehaviors(self: *Self) !void {
    const c = self.connection();
    for ([_]u64{ c.source, c.requester, c.source }, 0..) |pid, i| if (!self.record.initialized[i]) {
        const payload = switch (i) {
            0 => try (q.catalog.TableControl.Command{ .initialize = catalogFor(c, self.record) }).encode(),
            1 => try q.UnifiedRequest.Command.encode(.initialize),
            2 => try (q.CatalogQueryOwner.PolicyChange{ .expected_revision = 0, .policy = .{ .peer = c.requester, .requests = c.requests, .revision = 1, .allow = true, .target = .{ .catalog = .{ .scope = catalogFor(c, self.record).scope, .owner = c.source, .principal = c.principal } }, .limits = limits } }).encode(),
            else => unreachable,
        };
        try self.submit(caller, .{ .send = .{ .pid = pid, .value = try (q.station.Frame{ .kind = .cast, .payload = payload }).encode() } }, .initialize, @intCast(i));
    };
}
/// Default data is an explicit recoverable catalog operation, not a host side
/// effect. The completion marker prevents recreating items after an explicit DROP.
pub fn ensureDefaultTable(self: *Self, catalog: *q.catalog.TableClient) !void {
    if (self.record.default_table_complete) return;
    var saved = try @import("../TableRecovery.zig").open(self.init.io, self.init.gpa, try self.path("default-table.json"), catalog);
    defer saved.close();
    errdefer {
        if (saved.failed) self.failed = true;
    }
    var original = try catalog.compile(self.init.gpa, "CREATE TABLE items (id INT64 PRIMARY KEY, value INT64)", .{ .operation = 1, .namespace = 1, .create_object = 1 }, null);
    defer original.deinit();
    if (saved.intent == null) try saved.install(catalog, &original);
    if (!std.mem.eql(u8, original.bytes, saved.intent.?.bytes)) return error.InstallationIdentityMismatch;
    if (saved.record.pending) |pending| {
        if (saved.record.input == null) {
            saved.record.input = (try catalog.submit(pending)).position;
            try saved.save(catalog);
        }
        const progress = try catalog.waitProgress(&saved.intent.?, pending, saved.record.input.?);
        if (progress == .pending) return error.TableWriterNotReady;
        if (progress.processed.disposition != null) return error.InstallationDefaultTableRejected;
        saved.record.pending = null;
        saved.record.input = null;
    }
    switch (try catalog.next(&saved.intent.?)) {
        .send => |pending| {
            saved.record.pending = pending;
            saved.record.input = null;
            try saved.save(catalog);
            saved.record.input = (try catalog.submit(pending)).position;
            try saved.save(catalog);
            return error.TableWriterNotReady;
        },
        .running => return error.TableWriterNotReady,
        .upload_cancelled => return error.InstallationDefaultTableRejected,
        .terminal => |outcome| {
            if (outcome != .ddl or outcome.ddl.operation.state != .applied or outcome.ddl.operation.actual_object != 1) return error.InstallationDefaultTableRejected;
            saved.record.complete = true;
            try saved.save(catalog);
            self.record.default_table_complete = true;
            try self.save();
        },
    }
}
pub fn create(init: std.process.Init, config: Config, identity: Config.Identity) !void {
    const allocator = init.arena.allocator();
    // A sibling private directory is never a live installation. An interrupted
    // assembly contains no accepted native work and is never silently adopted.
    var random: [16]u8 = undefined;
    try init.io.randomSecure(&random);
    const temporary = try std.fmt.allocPrint(allocator, "{s}.creating-{s}", .{ config.installation, std.fmt.bytesToHex(random, .lower) });
    try std.Io.Dir.cwd().access(init.io, std.fs.path.dirname(config.installation).?, .{});
    if (std.Io.Dir.cwd().access(init.io, config.installation, .{})) |_| return error.InstallationExists else |err| if (err != error.FileNotFound) return err;
    try std.Io.Dir.cwd().createDir(init.io, temporary, .fromMode(0o700));
    const directory = try std.Io.Dir.cwd().openDir(init.io, temporary, .{ .iterate = true });
    defer directory.close(init.io);
    for ([_][]const u8{ "wal", "cold", "activations", "provider-home", "certs", "applications", "management-recovery" }) |name| {
        try directory.createDir(init.io, name, .fromMode(0o700));
        if (std.mem.eql(u8, name, "wal") or std.mem.eql(u8, name, "cold")) try Files.write(init.io, try std.fs.path.join(allocator, &.{ temporary, name, "transit-installation" }), &std.fmt.bytesToHex(random, .lower));
    }
    var root_public: [32]u8 = undefined;
    for ([_][]const u8{ "root", "caller", "courier", "maintenance", "cold", "installer", "board" }) |name| {
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        if (std.mem.eql(u8, name, "root")) root_public = (try p.Ed25519.KeyPair.generateDeterministic(seed)).public_key.toBytes();
        const bytes = std.fmt.bytesToHex(seed, .lower);
        try Files.write(init.io, try std.fmt.allocPrint(allocator, "{s}/{s}.seed", .{ temporary, name }), &bytes);
    }
    try Files.json(init.io, init.gpa, try std.fs.path.join(allocator, &.{ temporary, "installation.json" }), Record{ .definition = g.current_definition, .identity = identity, .installation = random, .root_public = root_public, .default_table_complete = false });
    if (std.c.fsync(directory.handle) != 0) return error.InstallationSyncFailed;
    try std.Io.Dir.cwd().renamePreserve(temporary, std.Io.Dir.cwd(), config.installation, init.io);
    const parent = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(config.installation).?, .{ .iterate = true });
    defer parent.close(init.io);
    if (std.c.fsync(parent.handle) != 0) return error.InstallationSyncFailed;
}
pub fn checkStorage(self: *Self) !void {
    for ([_][]const u8{ "wal", "cold" }) |name| {
        const marker = try std.Io.Dir.cwd().readFileAlloc(self.init.io, try std.fmt.allocPrint(self.init.arena.allocator(), "{s}/{s}/transit-installation", .{ self.config.installation, name }), self.init.gpa, .limited(33));
        defer self.init.gpa.free(marker);
        if (!std.mem.eql(u8, marker, &std.fmt.bytesToHex(self.record.installation, .lower))) return error.StorageIdentityMismatch;
    }
}

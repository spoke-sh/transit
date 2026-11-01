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
pub const table_registrar = 26;
pub const read_permissions = p.State.permission(.inspect) | p.State.permission(.read);
pub const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 128, .result_bytes = 1048576 };
pub const Record = struct {
    version: u8 = 1,
    definition: g.Definition,
    identity: Config.Identity,
    installation: [16]u8,
    root_public: [32]u8,
    endpoint: []const u8,
    realm: u64,
    position: u64 = 0,
    genesis_observed: bool = false,
    provision: [14]?u64 = @splat(null),
    authorization_steps: [13]?u64 = @splat(null),
    authorization_change: ?u64 = null,
    initialized: [2]bool = .{ false, false },
    default_table_complete: bool,
    default_table: ?q.catalog.DirectTableIntent.Reference,
    table_registrar_receipt: ?u64,
    complete: bool,
    workers: [2]Worker,
    registration: ?q.wire.bootstrap.GrowingRegistration = null,
    pending: ?Pending = null,
    installer_receipt: ?u64 = null,
    board_receipts: [3]?u64 = @splat(null),
};
pub const Worker = struct {
    public_key: [32]u8,
    enrollment: [3]?u64,
};
const worker_permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish);
const Pending = struct { signed: g.SignedRequest, effect: enum { provision, initialize, activation, worker_enrollment, installer, board, authority, table_registrar }, index: u8 };
const Self = @This();
const Startup = @import("Startup.zig");
startup: ?*Startup = null,
init: std.process.Init,
config: Config,
record: Record,
wire: *q.wire.Client,
root: p.Ed25519.KeyPair,
caller_key: p.Ed25519.KeyPair,
record_path: []const u8,
failed: bool = false,
/// Runtime scheduling fence over independently persisted setup journals.
/// Recovery resolves those journals before any new root writer starts.
root_pending: ?[32]u8 = null,
pub fn reserveRoot(self: *Self, signed: g.SignedRequest) !void {
    if (signed.request.principal != 0) return;
    const digest = try g.digest(signed.request);
    if (self.root_pending) |pending| if (!std.mem.eql(u8, &pending, &digest)) return error.UnresolvedProvisioning;
    self.root_pending = digest;
}
pub fn releaseRoot(self: *Self, signed: g.SignedRequest) !void {
    if (signed.request.principal != 0) return;
    const digest = try g.digest(signed.request);
    if (self.root_pending) |pending| if (!std.mem.eql(u8, &pending, &digest)) return error.UnresolvedProvisioning;
    self.root_pending = null;
}
pub fn ownsRoot(self: *Self, signed: g.SignedRequest) !bool {
    const pending = self.root_pending orelse return true;
    return signed.request.principal == 0 and std.mem.eql(u8, &pending, &try g.digest(signed.request));
}

test "independent setup journals cannot reuse an unresolved root sequence" {
    const t = std.testing;
    var installation: Self = undefined;
    installation.root_pending = null;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const first = try g.sign(.{ .realm = 1, .principal = 0, .sequence = 1, .command = .{ .spawn = .{} } }, key);
    const other = try g.sign(.{ .realm = 1, .principal = 0, .sequence = 1, .command = .{ .create_resource = .{ .writer = 1 } } }, key);
    try installation.reserveRoot(first);
    try installation.reserveRoot(first);
    try t.expect(try installation.ownsRoot(first));
    try t.expect(!try installation.ownsRoot(other));
    try t.expectError(error.UnresolvedProvisioning, installation.reserveRoot(other));
    try t.expectError(error.UnresolvedProvisioning, installation.releaseRoot(other));
    try installation.releaseRoot(first);
    try installation.reserveRoot(other);
    try installation.releaseRoot(other);
}
pub fn path(self: *const Self, name: []const u8) ![]const u8 {
    return std.fs.path.join(self.init.arena.allocator(), &.{ self.config.installation, name });
}
pub fn save(self: *Self) !void {
    Startup.measure(self.startup, .journal_checkpoint, Files.json, .{ self.init.io, self.init.gpa, self.record_path, self.record }) catch |err| {
        self.failed = true;
        return err;
    };
}
pub fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
    const response = try Startup.measure(self.startup, Startup.query(kind), q.wire.Client.query, .{ self.wire, g.Query{ .realm = self.config.realm, .principal = 0, .kind = kind }, self.root });
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
    const receipt = try Startup.measure(self.startup, Startup.submission(pending.signed.request.command), q.wire.Client.submit, .{ self.wire, pending.signed });
    switch (pending.effect) {
        .provision => self.record.provision[pending.index] = receipt.position,
        .initialize => self.record.initialized[pending.index] = true,
        .activation => self.record.workers[pending.index].public_key = pending.signed.request.command.rotate_worker.public_key,
        .worker_enrollment => self.record.workers[pending.index / 3].enrollment[pending.index % 3] = receipt.position,
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
        .table_registrar => self.record.table_registrar_receipt = receipt.position,
    }
    self.record.position = @max(self.record.position, receipt.position);
    self.record.pending = null;
    try self.save();
}
pub fn submit(self: *Self, principal: u64, command: g.Command, effect: @FieldType(Pending, "effect"), index: u8) !void {
    if (self.record.pending != null) return error.UnresolvedProvisioning;
    const key = if (principal == 0) self.root else self.caller_key;
    const basis = try Startup.measure(self.startup, .native_capabilities, q.wire.Client.query, .{ self.wire, g.Query{ .realm = self.config.realm, .principal = principal, .kind = .{ .capabilities = {} } }, key });
    if (basis.position < self.record.position) return error.AuthorityRollback;
    if (command == .rotate_worker and !basis.body.capabilities.worker_rotation) return error.UnsupportedWorkerRotation;
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
pub fn directCatalog(self: *Self) q.catalog.DirectCatalog.Configuration {
    const installed = self.connection();
    const authority = self.record.authorization_steps;
    return .{
        .scope = .{ .realm = installed.realm, .resource = installed.resource, .catalog = 1 },
        .branch = 1,
        .partition = 1,
        .audience = installed.source,
        .authority = .{
            .database_domain = authority[3].?,
            .schema_domain = authority[4].?,
            .table_domain = authority[5].?,
            .stream_domain = authority[10].?,
            .queue_domain = authority[11].?,
            .kv_domain = authority[12].?,
            .database = authority[6].?,
            .initial_schema = 1,
            .initial_schema_authority = authority[7].?,
        },
        .database_name = q.catalog.TableAuthority.Name.init("transit") catch unreachable,
        .initial_schema_name = q.catalog.TableAuthority.Name.init("public") catch unreachable,
    };
}
pub fn provision(self: *Self) !void {
    try self.flush();
    for (0..self.record.provision.len) |i| {
        if (self.record.provision[i] != null) continue;
        if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
        if (i == 9) {
            if (self.record.table_registrar_receipt == null) {
                var key = try q.wire.readKey(self.init.gpa, self.init.io, try self.path("table-registrar.seed"));
                defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
                try self.submit(0, .{ .create_principal = .{ .subject = table_registrar, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) } }, .table_registrar, 0);
            }
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
    try self.provisionWorkers();
    if (self.config.applications != null and self.record.installer_receipt == null) {
        var key = try q.wire.readKey(self.init.gpa, self.init.io, try self.path("installer.seed"));
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        try self.submit(0, .{ .create_principal = .{ .subject = installer, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.admin) } }, .installer, 0);
    }
}

/// Enroll each built-in principal once. Subsequent activation rotates its exact
/// recorded key and ownership generation without restoring any removed grant.
fn provisionWorkers(self: *Self) !void {
    const c = self.connection();
    for ([_]u64{ source, requester }, 0..) |principal, index| {
        const worker = &self.record.workers[index];
        const pid = if (index == 0) c.source else c.requester;
        const resource = if (index == 0) c.resource else c.requests;
        const steps: usize = if (index == 0) 3 else 2;
        for (0..steps) |step| {
            if (worker.enrollment[step] != null) continue;
            if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
            const command: g.Command = switch (step) {
                0 => .{ .create_principal = .{ .subject = principal, .public_key = worker.public_key, .permissions = worker_permissions, .pid = pid } },
                1 => .{ .grant_resource = .{ .resource = resource, .subject = principal, .permissions = p.State.all_permissions } },
                2 => .{ .grant_resource = .{ .resource = c.requests, .subject = principal, .permissions = read_permissions } },
                else => unreachable,
            };
            try self.submit(0, command, .worker_enrollment, @intCast(index * 3 + step));
        }
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
                3, 4, 5 => .{ .register_domain = .{ .registrar = table_registrar, .lifetime_resource = scope.resource, .actions = tables.actions(switch (index) {
                    3 => .database,
                    4 => .schema,
                    else => .table,
                }) } },
                6 => .{ .register_object = .{ .domain = done[3].?, .owner = done[0].?, .binding = try tables.binding(scope, .database, 0) } },
                7 => .{ .register_object = .{ .domain = done[4].?, .owner = done[0].?, .schema = tables.reference(done[6].?), .binding = try tables.binding(scope, .schema, 1) } },
                8 => .{ .register_domain = .{ .registrar = 0, .actions = q.settings.Contract.all_privileges } },
                9 => .{ .register_object = .{ .domain = done[8].?, .owner = done[0].?, .binding = q.settings.Contract.Binding.identity(self.record.installation) } },
                10, 11, 12 => .{ .register_domain = .{ .registrar = table_registrar, .lifetime_resource = scope.resource, .actions = tables.actions(if (index == 10) .stream else if (index == 11) .queue else .kv) } },
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
    const index: u8 = if (registration.principal == source) 0 else if (registration.principal == requester) 1 else return error.InvalidRegistration;
    try self.submit(0, .{ .rotate_worker = .{
        .pid = registration.pid,
        .worker = registration.principal,
        .expected_generation = registration.generation - 1,
        .expected_public_key = self.record.workers[index].public_key,
        .expected_permissions = worker_permissions,
        .public_key = registration.public_key,
    } }, .activation, index);
}
pub fn initializeBehaviors(self: *Self) !void {
    const c = self.connection();
    for ([_]u64{ c.source, c.requester }, 0..) |pid, i| if (!self.record.initialized[i]) {
        const payload = try q.UnifiedRequest.Command.encode(.initialize);
        try self.submit(caller, .{ .send = .{ .pid = pid, .value = try (q.station.Frame{ .kind = .cast, .payload = payload }).encode() } }, .initialize, @intCast(i));
    };
}
pub const DirectoryState = enum { missing, empty, populated };
/// Examine only the installation directory, never infer newness from a missing
/// record inside it. In particular, dangling symlinks are not absent directories.
pub fn directoryState(io: std.Io, path_name: []const u8) !DirectoryState {
    const stat = std.Io.Dir.cwd().statFile(io, path_name, .{ .follow_symlinks = false }) catch |err| {
        if (err == error.FileNotFound) return .missing;
        return err;
    };
    if (stat.kind != .directory) return error.InvalidInstallationDirectory;
    const directory = try std.Io.Dir.cwd().openDir(io, path_name, .{ .iterate = true, .follow_symlinks = false });
    defer directory.close(io);
    var entries = directory.iterate();
    return if (try entries.next(io) == null) .empty else .populated;
}

/// Caller holds the sibling installation lock across selection, creation and
/// recovery. No provider or authority starts before this record is published.
pub fn prepare(init: std.process.Init, config: Config, identity: Config.Identity) !bool {
    const state = try directoryState(init.io, config.installation);
    if (state == .populated) return false;
    if (config.startup.require_existing) return error.ExistingInstallationRequired;
    try create(init, config, identity, state);
    return true;
}

fn create(init: std.process.Init, config: Config, identity: Config.Identity, state: DirectoryState) !void {
    const allocator = init.arena.allocator();
    // A sibling private directory is never a live installation. An interrupted
    // assembly contains no accepted native work and is never silently adopted.
    var random: [16]u8 = undefined;
    try init.io.randomSecure(&random);
    const temporary = try std.fmt.allocPrint(allocator, "{s}.creating-{s}", .{ config.installation, std.fmt.bytesToHex(random, .lower) });
    try std.Io.Dir.cwd().access(init.io, std.fs.path.dirname(config.installation).?, .{});
    try std.Io.Dir.cwd().createDir(init.io, temporary, .fromMode(0o700));
    const directory = try std.Io.Dir.cwd().openDir(init.io, temporary, .{ .iterate = true });
    defer directory.close(init.io);
    for ([_][]const u8{ "data", "activations", "applications", "management-recovery" }) |name| {
        try directory.createDir(init.io, name, .fromMode(0o700));
        if (std.mem.eql(u8, name, "data")) try Files.write(init.io, try std.fs.path.join(allocator, &.{ temporary, name, "transit-installation" }), &std.fmt.bytesToHex(random, .lower));
    }
    var root_public: [32]u8 = undefined;
    for ([_][]const u8{ "root", "caller", "courier", "maintenance", "installer", "board", "table-registrar" }) |name| {
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        if (std.mem.eql(u8, name, "root")) root_public = (try p.Ed25519.KeyPair.generateDeterministic(seed)).public_key.toBytes();
        const bytes = std.fmt.bytesToHex(seed, .lower);
        try Files.write(init.io, try std.fmt.allocPrint(allocator, "{s}/{s}.seed", .{ temporary, name }), &bytes);
    }
    var workers: [2]Worker = undefined;
    for (&workers) |*worker| {
        var seed: [32]u8 = undefined;
        defer std.crypto.secureZero(u8, &seed);
        try init.io.randomSecure(&seed);
        var key = try p.Ed25519.KeyPair.generateDeterministic(seed);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        worker.* = .{ .public_key = key.public_key.toBytes(), .enrollment = @splat(null) };
    }
    try Files.json(init.io, init.gpa, try std.fs.path.join(allocator, &.{ temporary, "installation.json" }), Record{ .definition = g.current_definition, .identity = identity, .installation = random, .root_public = root_public, .endpoint = try @import("Provider.zig").url(allocator, config.ports.gateway), .realm = config.realm, .default_table_complete = false, .default_table = null, .table_registrar_receipt = null, .complete = false, .workers = workers });
    if (std.c.fsync(directory.handle) != 0) return error.InstallationSyncFailed;
    // Remove only an empty directory, never its contents. If anything appeared
    // since classification, rmdir refuses it. Nonreplacing publication also
    // refuses a new destination racing with us. A crash in between leaves only
    // unpublished staging files: no accepted work or active identity exists yet.
    if (state == .empty) try std.Io.Dir.cwd().deleteDir(init.io, config.installation);
    try std.Io.Dir.cwd().renamePreserve(temporary, std.Io.Dir.cwd(), config.installation, init.io);
    const parent = try std.Io.Dir.cwd().openDir(init.io, std.fs.path.dirname(config.installation).?, .{ .iterate = true });
    defer parent.close(init.io);
    if (std.c.fsync(parent.handle) != 0) return error.InstallationSyncFailed;
}
pub fn checkStorage(self: *Self) !void {
    for ([_][]const u8{"data"}) |name| {
        const marker = try std.Io.Dir.cwd().readFileAlloc(self.init.io, try std.fmt.allocPrint(self.init.arena.allocator(), "{s}/{s}/transit-installation", .{ self.config.installation, name }), self.init.gpa, .limited(33));
        defer self.init.gpa.free(marker);
        if (!std.mem.eql(u8, marker, &std.fmt.bytesToHex(self.record.installation, .lower))) return error.StorageIdentityMismatch;
    }
}

pub fn settingsBinding(record: Record, realm: u64) !q.settings.Contract.Binding {
    return .{ .realm = realm, .installation = record.installation, .object = .{ .kind = .domain, .id = record.authorization_steps[9] orelse return error.InvalidInstallationAuthority } };
}

test "startup creates only absent or empty directories and preserves recorded identities" {
    const t = std.testing;
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const directory = try temporary.dir.realPathFileAlloc(t.io, ".", a);
    const init: std.process.Init = .{ .io = t.io, .gpa = a, .arena = &arena, .minimal = undefined, .environ_map = undefined, .preopens = undefined };
    var config: Config = .{
        .version = 1,
        .realm = 1,
        .installation = try std.fs.path.join(a, &.{ directory, "installation" }),
        .ports = .{ .node = 19104, .gateway = 19105 },
        .executables = .{ .node = "unused", .query_host = "unused", .sql_gateway = "unused" },
    };
    const identity = std.mem.zeroes(Config.Identity);
    config.startup.require_existing = true;
    try t.expectError(error.ExistingInstallationRequired, prepare(init, config, identity));
    try t.expectEqual(.missing, try directoryState(t.io, config.installation));
    try temporary.dir.createDir(t.io, "installation", .default_dir);
    try t.expectError(error.ExistingInstallationRequired, prepare(init, config, identity));
    try t.expectEqual(.empty, try directoryState(t.io, config.installation));
    config.startup.require_existing = false;
    try t.expect(try prepare(init, config, identity));
    const record_path = try std.fs.path.join(a, &.{ config.installation, "installation.json" });
    const before = try Files.read(Record, t.io, a, record_path);
    try t.expect(!try prepare(init, config, identity));
    config.startup.require_existing = true;
    try t.expect(!try prepare(init, config, identity));
    const after = try Files.read(Record, t.io, a, record_path);
    try t.expectEqual(before.installation, after.installation);
    try t.expectEqual(before.root_public, after.root_public);
    try t.expect(!after.complete and !after.genesis_observed);
    // Losing the record in a populated installation never makes it new.
    try std.Io.Dir.cwd().deleteFile(t.io, record_path);
    config.startup.require_existing = false;
    try t.expect(!try prepare(init, config, identity));
    try t.expectError(error.FileNotFound, Files.read(Record, t.io, a, record_path));
    config.installation = try std.fs.path.join(a, &.{ directory, "new" });
    try t.expect(try prepare(init, config, identity));
    try t.expectEqual(.populated, try directoryState(t.io, config.installation));
}

test "initialization refuses links files and contents appearing before publication" {
    const t = std.testing;
    var temporary = t.tmpDir(.{});
    defer temporary.cleanup();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const directory = try temporary.dir.realPathFileAlloc(t.io, ".", a);
    const target = try std.fs.path.join(a, &.{ directory, "target" });
    try Files.write(t.io, target, "preserve");
    try t.expectError(error.InvalidInstallationDirectory, directoryState(t.io, target));
    try temporary.dir.symLink(t.io, "absent", "dangling", .{});
    try t.expectError(error.InvalidInstallationDirectory, directoryState(t.io, try std.fs.path.join(a, &.{ directory, "dangling" })));
    try temporary.dir.createDir(t.io, "installation", .default_dir);
    try temporary.dir.symLink(t.io, "installation", "link", .{ .is_directory = true });
    try t.expectError(error.InvalidInstallationDirectory, directoryState(t.io, try std.fs.path.join(a, &.{ directory, "link" })));
    const init: std.process.Init = .{ .io = t.io, .gpa = a, .arena = &arena, .minimal = undefined, .environ_map = undefined, .preopens = undefined };
    const config: Config = .{
        .version = 1,
        .realm = 1,
        .installation = try std.fs.path.join(a, &.{ directory, "installation" }),
        .ports = .{ .node = 19104, .gateway = 19105 },
        .executables = .{ .node = "unused", .query_host = "unused", .sql_gateway = "unused" },
    };
    const state = try directoryState(t.io, config.installation);
    const marker = try std.fs.path.join(a, &.{ config.installation, "unrecognized" });
    try Files.write(t.io, marker, "preserve");
    try t.expectError(error.DirNotEmpty, create(init, config, std.mem.zeroes(Config.Identity), state));
    try t.expectError(error.PathAlreadyExists, create(init, config, std.mem.zeroes(Config.Identity), .missing));
    try t.expectEqualStrings("preserve", try std.Io.Dir.cwd().readFileAlloc(t.io, marker, a, .limited(8)));
}

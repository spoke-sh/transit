//! Local placement composes public native operations. Records never grant authority.
const std = @import("std");
const q = @import("transit_query");
const p = q.protocol;
const g = p.Growth;
const A = q.wire.Application;
const http = @import("transit_http_server");
const Installation = @import("Installation.zig");
const Config = @import("Config.zig");
const Files = @import("Files.zig");
const Process = @import("Process.zig");
const Signals = @import("../Signals.zig");
const Self = @This();
const Candidate = struct { artifact: A.Artifact, configuration: []const u8, revision: [32]u8 };
const Pending = struct { signed: g.SignedRequest, effect: union(enum) { provision: struct { pid: ?u8 = null, resource: ?u8 = null }, activation: u8, fence: u8, inspection: void } };
const record_bytes = 256 * 1024;
const Record = struct {
    version: u32 = 1,
    definition: g.Definition,
    installation: [16]u8,
    declaration: A.Declaration,
    digest: [32]u8,
    installer: g.SignedQuery,
    pids: [A.max_roles]?u64 = @splat(null),
    resources: [A.max_resources]?u64 = @splat(null),
    workers: [A.max_roles]u64 = @splat(0),
    callers: [A.max_callers]u64 = @splat(0),
    public_keys: [A.max_roles][32]u8 = @splat(@splat(0)),
    generations: [A.max_roles]u64 = @splat(0),
    selected: [A.max_roles]?Candidate = @splat(null),
    next: u32 = 0,
    installed: bool = false,
    inspection_next: u8 = 0,
    blocked: ?[]const u8 = null,
    rejected: ?Pending = null,
    receipt_count: u32 = 0,
    pending: ?Pending = null,
    replacement: ?struct { signed: A.Signed, fenced: bool = false } = null,
};
const Worker = struct {
    process: Process = .{},
    phase: enum { pending, registration, activation, ready, failed } = .pending,
    registration: ?q.wire.bootstrap.GrowingRegistration = null,
    buffer: [1024]u8 = undefined,
    length: usize = 0,
    started: ?std.Io.Timestamp = null,
    restarts: u8 = 0,
    error_name: ?[]const u8 = null,
};
const Runtime = struct {
    name: [64]u8 = undefined,
    length: usize = 0,
    role_count: usize = 0,
    workers: [A.max_roles]Worker = @splat(.{}),
    fn label(self: *const Runtime) []const u8 {
        return self.name[0..self.length];
    }
};
init: std.process.Init,
installation: *Installation,
executable: []const u8,
limits: Config.Applications,
apps: []Runtime,
count: usize = 0,
next_app: usize = 0,
mutex: std.Io.Mutex = .init,
listener: std.Io.net.Server,
future: ?std.Io.Future(void) = null,
failed: std.atomic.Value(bool) = .init(false),
host: []const u8,

pub fn create(init: std.process.Init, installation: *Installation, executable: []const u8) !*Self {
    const self = try init.gpa.create(Self);
    errdefer init.gpa.destroy(self);
    const limits = installation.config.applications.?;
    const apps = try init.gpa.alloc(Runtime, limits.max_applications);
    errdefer init.gpa.free(apps);
    for (apps) |*app| app.* = .{};
    var listener = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", limits.port)).listen(init.io, .{ .reuse_address = true });
    errdefer listener.deinit(init.io);
    const host = try std.fmt.allocPrint(init.gpa, "127.0.0.1:{d}", .{limits.port});
    errdefer init.gpa.free(host);
    self.* = .{ .init = init, .installation = installation, .executable = executable, .limits = limits, .apps = apps, .listener = listener, .host = host };
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const directory = try std.Io.Dir.cwd().openDir(init.io, try installation.path("applications"), .{ .iterate = true });
    defer directory.close(init.io);
    var iterator = directory.iterate();
    while (try iterator.next(init.io)) |entry| {
        if (std.mem.startsWith(u8, entry.name, ".creating-")) continue;
        if (entry.kind != .directory) return error.InvalidApplicationCatalog;
        try A.name(entry.name);
        const record = try self.load(arena.allocator(), entry.name);
        try self.add(entry.name, record.declaration.roles.len);
        _ = arena.reset(.retain_capacity);
    }
    const management: A.Management = .{ .url = try std.fmt.allocPrint(arena.allocator(), "http://{s}", .{host}), .realm = installation.config.realm, .installation = installation.record.installation, .principal = Installation.installer, .seed_file = try installation.path("installer.seed"), .recovery_directory = try installation.path("management-recovery") };
    try @import("../Settings.zig").write(init, try installation.path("management.yaml"), management);
    self.future = try std.Io.concurrent(init.io, serve, .{self});
    return self;
}
/// Resolve frozen native operations before built-in roles can consume the root
/// sequence. The latest per-app receipt also closes the checkpoint/floor crash gap.
pub fn recover(self: *Self) !void {
    try self.mutex.lock(self.init.io);
    defer self.mutex.unlock(self.init.io);
    var arena = std.heap.ArenaAllocator.init(self.init.gpa);
    defer arena.deinit();
    for (self.apps[0..self.count]) |*app| {
        const allocator = arena.allocator();
        var record = try self.load(allocator, app.label());
        if (record.receipt_count > 0) {
            const receipt = try Files.read(A.Receipt, self.init.io, allocator, try self.path(allocator, app.label(), try std.fmt.allocPrint(allocator, "receipts/{d}.json", .{record.receipt_count - 1})));
            if (receipt.index != record.receipt_count - 1) return error.InvalidApplicationCatalog;
            self.installation.record.position = @max(self.installation.record.position, receipt.position);
            _ = try self.installation.query(.capabilities);
        }
        if (record.pending != null) {
            try self.installer(record.installer, self.installation.wire);
            try self.flush(allocator, &record);
        }
        _ = arena.reset(.retain_capacity);
    }
}
pub fn destroy(self: *Self) void {
    if (self.future) |*future| future.cancel(self.init.io);
    self.listener.deinit(self.init.io);
    for (self.apps[0..self.count]) |*app| {
        var i = app.role_count;
        while (i > 0) {
            i -= 1;
            app.workers[i].process.stop(self.init.io);
        }
    }
    self.init.gpa.free(self.apps);
    self.init.gpa.free(self.host);
    self.init.gpa.destroy(self);
}
fn serve(self: *Self) void {
    http.serve(self.init.io, self.init.gpa, &self.listener, .{ .connections = 6, .requests = 2, .control_requests = 1, .header_timeout_ms = 500, .request_timeout_ms = 4000 }, self) catch self.failed.store(true, .release);
}
pub fn connectionError(_: *Self, _: anyerror, _: bool) void {}
fn path(self: *Self, allocator: std.mem.Allocator, application: []const u8, tail: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ self.installation.config.installation, "applications", application, tail });
}
fn load(self: *Self, allocator: std.mem.Allocator, application: []const u8) !Record {
    const record = try Files.readBounded(Record, self.init.io, allocator, try self.path(allocator, application, "record.json"), record_bytes);
    if (record.version != 1 or !std.mem.eql(u8, &record.installation, &self.installation.record.installation) or !std.mem.eql(u8, record.declaration.application, application) or !std.mem.eql(u8, &record.digest, &try A.digest(allocator, record.declaration))) return error.InvalidApplicationCatalog;
    try record.declaration.validate();
    return record;
}
// Management admission reserves space for the next frozen native request and
// receipt coordinates. Reject before changing the record or poisoning recovery.
fn admitCheckpoint(allocator: std.mem.Allocator, record: Record) !void {
    const encoded = try p.Json.valueAlloc(allocator, record);
    defer allocator.free(encoded);
    if (encoded.len > record_bytes - 8192) return error.ApplicationCheckpointCapacity;
}
fn save(self: *Self, allocator: std.mem.Allocator, record: Record) !void {
    Files.jsonBounded(self.init.io, allocator, try self.path(allocator, record.declaration.application, "record.json"), record, record_bytes) catch |err| {
        self.failed.store(true, .release);
        return err;
    };
}
fn find(self: *Self, application: []const u8) ?*Runtime {
    for (self.apps[0..self.count]) |*app| if (std.mem.eql(u8, app.label(), application)) return app;
    return null;
}
fn add(self: *Self, application: []const u8, roles: usize) !void {
    if (self.count == self.apps.len) return error.ApplicationCapacity;
    var total = roles;
    for (self.apps[0..self.count]) |app| total += app.role_count;
    if (total > self.limits.max_roles) return error.ApplicationCapacity;
    const app = &self.apps[self.count];
    app.length = application.len;
    @memcpy(app.name[0..application.len], application);
    app.role_count = roles;
    self.count += 1;
}
fn identity(self: *Self, signed: g.SignedQuery, wire: *q.wire.Client) !g.Identity {
    if (signed.query.realm != self.installation.config.realm or signed.query.kind != .identity) return error.AccessDenied;
    const response = try wire.call(g.Response, "/v1/query", signed);
    try g.validateResponse(response, signed.query);
    return response.body.identity;
}
fn installer(self: *Self, signed: g.SignedQuery, wire: *q.wire.Client) !void {
    const current = try self.identity(signed, wire);
    if (current.principal != Installation.installer or current.pid != null or current.permissions & (p.permission(.admin) | p.permission(.inspect)) != (p.permission(.admin) | p.permission(.inspect))) return error.AccessDenied;
}
fn requestFile(self: *Self, allocator: std.mem.Allocator, signed: A.Signed) ![]const u8 {
    return self.path(allocator, signed.request.application(), try std.fmt.allocPrint(allocator, "requests/{d}-{s}.json", .{ signed.request.principal, signed.request.operation }));
}
fn remember(self: *Self, allocator: std.mem.Allocator, signed: A.Signed) !void {
    const destination = try self.requestFile(allocator, signed);
    const previous = Files.read(A.Signed, self.init.io, allocator, destination) catch |err| {
        if (err != error.FileNotFound) return err;
        return Files.json(self.init.io, allocator, destination, signed);
    };
    if (!std.mem.eql(u8, &try A.digest(allocator, previous.request), &try A.digest(allocator, signed.request))) return error.ConflictingApplicationOperation;
}

pub fn handle(self: *Self, io: std.Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    if (!std.mem.eql(u8, (try http.header(request, "host")).?, self.host)) return http.respond(request, .forbidden, "{\"err\":\"InvalidHost\"}");
    var headers = request.iterateHeaders();
    while (headers.next()) |header| if (std.ascii.eqlIgnoreCase(header.name, "origin") or std.ascii.eqlIgnoreCase(header.name, "authorization") or std.ascii.eqlIgnoreCase(header.name, "x-real-ip") or std.ascii.eqlIgnoreCase(header.name, "forwarded") or std.ascii.startsWithIgnoreCase(header.name, "x-forwarded-")) return http.respond(request, .forbidden, "{\"err\":\"InvalidIdentityHeader\"}");
    if (request.head.method == .GET and std.mem.eql(u8, request.head.target, "/health")) return http.respond(request, .ok, "{\"ready\":true}");
    if (request.head.method != .POST or !std.mem.eql(u8, request.head.target, "/applications/v1")) return http.respond(request, .not_found, "{\"err\":\"NotFound\"}");
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const body = request.readerExpectNone(&.{}).allocRemaining(alloc, .limited(A.max_bytes)) catch return http.respond(request, .payload_too_large, "{\"err\":\"ApplicationLimit\"}");
    const signed = (p.Json.parseFromSlice(A.Signed, alloc, body) catch return http.respond(request, .bad_request, "{\"err\":\"InvalidRequest\"}")).value;
    A.verify(alloc, signed) catch return http.respond(request, .forbidden, "{\"err\":\"AccessDenied\"}");
    if (!std.mem.eql(u8, &signed.request.installation, &self.installation.record.installation)) return http.respond(request, .forbidden, "{\"err\":\"AccessDenied\"}");
    var wire = q.wire.Client.init(alloc, io, self.installation.wire.url);
    defer wire.deinit();
    wire.timeout_ms = 1500;
    const current = self.identity(signed.identity, &wire) catch |err| return http.respond(request, if (err == error.AccessDenied) .forbidden else .service_unavailable, if (err == error.AccessDenied) "{\"err\":\"AccessDenied\"}" else "{\"err\":\"AuthorityUnavailable\"}");
    const admin = current.principal == Installation.installer and current.pid == null and current.permissions & p.permission(.admin) != 0;
    if (signed.request.command != .status and !admin) return http.respond(request, .forbidden, "{\"err\":\"AccessDenied\"}");
    try self.mutex.lock(io);
    defer self.mutex.unlock(io);
    const output = self.control(alloc, signed, admin) catch |err| {
        const response_status: std.http.Status = if (err == error.AccessDenied) .forbidden else if (err == error.FileNotFound) .not_found else .conflict;
        return http.respond(request, response_status, try std.json.Stringify.valueAlloc(alloc, .{ .err = @errorName(err) }, .{}));
    };
    // Recheck disclosure after disk/lock work, using the caller's own identity.
    _ = self.identity(signed.identity, &wire) catch |err| return http.respond(request, if (err == error.AccessDenied) .forbidden else .service_unavailable, if (err == error.AccessDenied) "{\"err\":\"AccessDenied\"}" else "{\"err\":\"AuthorityUnavailable\"}");
    try http.respond(request, .ok, output);
}
fn control(self: *Self, allocator: std.mem.Allocator, signed: A.Signed, admin: bool) ![]const u8 {
    const command = signed.request.command;
    const application = signed.request.application();
    if (command == .install) try self.install(allocator, signed);
    const app = self.find(application) orelse return error.FileNotFound;
    var record = try self.load(allocator, application);
    if (!admin) {
        var allowed = false;
        for (record.callers[0..record.declaration.callers.len]) |caller| if (caller == signed.request.principal) {
            allowed = true;
        };
        if (!allowed) return error.AccessDenied;
    }
    if (command == .replace) {
        const previous = Files.read(A.Signed, self.init.io, allocator, try self.requestFile(allocator, signed)) catch |err| value: {
            if (err != error.FileNotFound) return err;
            break :value null;
        };
        if (previous) |found| {
            if (!std.mem.eql(u8, &try A.digest(allocator, found.request), &try A.digest(allocator, signed.request))) return error.ConflictingApplicationOperation;
        } else {
            if (!record.installed or record.pending != null or record.replacement != null) return error.ApplicationBusy;
            const replacement = command.replace;
            const i = A.index(A.Role, record.declaration.roles, replacement.role) orelse return error.UnknownApplicationRole;
            const selected = try candidate(allocator, record, i);
            if (!std.mem.eql(u8, record.declaration.roles[i].contract, replacement.contract) or !std.mem.eql(u8, &selected.revision, &replacement.expected_revision)) return error.IncompatibleApplicationReplacement;
            if (!std.mem.eql(u8, &try Config.digest(self.init, replacement.artifact.path), &replacement.artifact.sha256)) return error.ApplicationArtifactChanged;
            record.replacement = .{ .signed = signed };
            try admitCheckpoint(allocator, record);
            try self.save(allocator, record);
            try self.remember(allocator, signed);
        }
    }
    if (command == .connect) {
        if (!record.installed) return error.ApplicationBusy;
        const i = A.index(A.Caller, record.declaration.callers, command.connect.caller) orelse return error.UnknownApplicationCaller;
        const connection: A.Connection = .{ .application = application, .url = try @import("Provider.zig").url(allocator, self.installation.config.ports.gateway), .realm = self.installation.config.realm, .principal = record.callers[i], .seed_file = try self.path(allocator, application, try std.fmt.allocPrint(allocator, "caller-{d}.seed", .{i})), .roles = try bindings(allocator, record, .roles), .resources = try bindings(allocator, record, .resources), .callers = try bindings(allocator, record, .callers) };
        return p.Json.valueAlloc(allocator, connection);
    }
    return p.Json.valueAlloc(allocator, try self.status(allocator, app, record, if (command == .status) command.status.after else 0));
}
fn install(self: *Self, allocator: std.mem.Allocator, signed: A.Signed) !void {
    const declaration = signed.request.command.install;
    const digest = try A.digest(allocator, declaration);
    if (self.find(declaration.application) != null) {
        const record = try self.load(allocator, declaration.application);
        if (!std.mem.eql(u8, &record.digest, &digest)) return error.ConflictingApplicationDeclaration;
        try self.remember(allocator, signed);
        return;
    }
    var total = declaration.roles.len;
    for (self.apps[0..self.count]) |app| total += app.role_count;
    if (self.count >= self.apps.len or total > self.limits.max_roles) return error.ApplicationCapacity;
    for (declaration.roles) |role| if (!std.mem.eql(u8, &try Config.digest(self.init, role.artifact.path), &role.artifact.sha256)) return error.ApplicationArtifactChanged;
    var nonce: [16]u8 = undefined;
    try self.init.io.randomSecure(&nonce);
    const staging = try std.fmt.allocPrint(allocator, ".creating-{s}", .{std.fmt.bytesToHex(nonce, .lower)});
    const directory_path = try self.path(allocator, staging, "");
    try std.Io.Dir.cwd().createDir(self.init.io, directory_path, .fromMode(0o700));
    const directory = try std.Io.Dir.cwd().openDir(self.init.io, directory_path, .{ .iterate = true });
    defer directory.close(self.init.io);
    for ([_][]const u8{ "requests", "receipts", "activations" }) |child| try directory.createDir(self.init.io, child, .fromMode(0o700));
    var record: Record = .{ .definition = g.current_definition, .installation = self.installation.record.installation, .declaration = declaration, .digest = digest, .installer = signed.identity };
    for (declaration.roles, 0..) |_, i| {
        record.workers[i] = try self.randomPrincipal();
        var seed: [32]u8 = undefined;
        try self.init.io.randomSecure(&seed);
        defer std.crypto.secureZero(u8, &seed);
        record.public_keys[i] = (try p.Ed25519.KeyPair.generateDeterministic(seed)).public_key.toBytes();
    }
    for (declaration.callers, 0..) |_, i| {
        record.callers[i] = try self.randomPrincipal();
        var seed: [32]u8 = undefined;
        try self.init.io.randomSecure(&seed);
        defer std.crypto.secureZero(u8, &seed);
        try Files.write(self.init.io, try self.path(allocator, staging, try std.fmt.allocPrint(allocator, "caller-{d}.seed", .{i})), &std.fmt.bytesToHex(seed, .lower));
    }
    // Check the bounded checkpoint fits before any native operation is possible.
    try admitCheckpoint(allocator, record);
    try Files.jsonBounded(self.init.io, allocator, try self.path(allocator, staging, "record.json"), record, record_bytes);
    try Files.json(self.init.io, allocator, try self.path(allocator, staging, try std.fmt.allocPrint(allocator, "requests/{d}-{s}.json", .{ signed.request.principal, signed.request.operation })), signed);
    if (std.c.fsync(directory.handle) != 0) return error.InstallationSyncFailed;
    try std.Io.Dir.cwd().renamePreserve(directory_path, std.Io.Dir.cwd(), try self.path(allocator, declaration.application, ""), self.init.io);
    const parent = try std.Io.Dir.cwd().openDir(self.init.io, try self.installation.path("applications"), .{ .iterate = true });
    defer parent.close(self.init.io);
    if (std.c.fsync(parent.handle) != 0) {
        self.failed.store(true, .release);
        return error.InstallationSyncFailed;
    }
    try self.add(declaration.application, declaration.roles.len);
}
fn randomPrincipal(self: *Self) !u64 {
    var bytes: [8]u8 = undefined;
    try self.init.io.randomSecure(&bytes);
    return (std.mem.readInt(u64, &bytes, .little) & ((@as(u64, 1) << 52) - 1)) | (@as(u64, 1) << 52);
}
fn bindings(allocator: std.mem.Allocator, record: Record, comptime kind: enum { roles, resources, callers }) ![]A.Binding {
    const values = switch (kind) {
        .roles => record.declaration.roles,
        .resources => record.declaration.resources,
        .callers => record.declaration.callers,
    };
    const result = try allocator.alloc(A.Binding, values.len);
    for (values, 0..) |value, i| result[i] = .{ .name = value.name, .id = switch (kind) {
        .roles => record.pids[i] orelse 0,
        .resources => record.resources[i] orelse 0,
        .callers => record.callers[i],
    } };
    return result;
}
fn candidate(allocator: std.mem.Allocator, record: Record, i: usize) !Candidate {
    if (record.selected[i]) |selected| return selected;
    const role = record.declaration.roles[i];
    return .{ .artifact = role.artifact, .configuration = role.configuration, .revision = try revision(allocator, role.contract, role.artifact, role.configuration) };
}
fn revision(allocator: std.mem.Allocator, contract: []const u8, artifact: A.Artifact, configuration: []const u8) ![32]u8 {
    return A.digest(allocator, .{ .contract = contract, .artifact = artifact, .configuration = configuration });
}
fn status(self: *Self, allocator: std.mem.Allocator, app: *Runtime, record: Record, after: u32) !A.Status {
    if (after > record.receipt_count) return error.InvalidApplicationCursor;
    const roles = try allocator.alloc(A.RoleStatus, app.role_count);
    for (roles, 0..) |*role, i| {
        const runtime = &app.workers[i];
        role.* = .{ .name = record.declaration.roles[i].name, .pid = record.pids[i] orelse 0, .principal = record.workers[i], .generation = record.generations[i], .revision = (try candidate(allocator, record, i)).revision, .state = if (record.blocked != null) .failed else switch (runtime.phase) {
            .ready => if (runtime.registration != null and runtime.registration.?.generation == record.generations[i]) .ready else .starting,
            .failed => .failed,
            .pending => .pending,
            else => .starting,
        }, .error_name = record.blocked orelse runtime.error_name };
    }
    const count = @min(8, record.receipt_count - after);
    const receipts = try allocator.alloc(A.Receipt, count);
    for (receipts, 0..) |*receipt, i| receipt.* = try Files.read(A.Receipt, self.init.io, allocator, try self.path(allocator, app.label(), try std.fmt.allocPrint(allocator, "receipts/{d}.json", .{after + i})));
    return .{ .application = app.label(), .declaration = record.digest, .installed = record.installed, .roles = roles, .resources = try bindings(allocator, record, .resources), .receipts = receipts, .next = if (after + count < record.receipt_count) after + count else null };
}

const Step = struct { command: g.Command, principal: u64 = 0, effect: @FieldType(Pending, "effect") = .{ .provision = .{} } };
fn at(index: u32, ordinal: *u32) bool {
    defer ordinal.* += 1;
    return index == ordinal.*;
}
fn plan(self: *Self, allocator: std.mem.Allocator, record: Record) !?Step {
    const d = record.declaration;
    var n: u32 = 0;
    for (d.roles, 0..) |_, i| if (at(record.next, &n)) return .{ .command = .{ .spawn = .{} }, .effect = .{ .provision = .{ .pid = @intCast(i) } } };
    for (d.resources, 0..) |resource, i| {
        if (at(record.next, &n)) return .{ .command = .{ .create_resource = .{ .writer = record.pids[A.index(A.Role, d.roles, resource.writer).?].? } }, .effect = .{ .provision = .{ .resource = @intCast(i) } } };
        if (at(record.next, &n)) return .{ .command = .{ .grant_resource = .{ .resource = record.resources[i].?, .subject = 0, .permissions = p.State.all_permissions } } };
    }
    for (d.roles, 0..) |_, i| if (at(record.next, &n)) return .{ .command = .{ .create_principal = .{ .subject = record.workers[i], .public_key = record.public_keys[i], .permissions = A.worker_permissions, .pid = record.pids[i].? } } };
    for (d.callers, 0..) |caller, i| if (at(record.next, &n)) {
        var key = try self.callerKey(allocator, d.application, i);
        defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
        return .{ .command = .{ .create_principal = .{ .subject = record.callers[i], .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | (if (caller.send_to != null) p.permission(.send) else @as(u16, 0)), .pid = if (caller.send_to) |target| record.pids[A.index(A.Role, d.roles, target).?].? else null } } };
    };
    for (d.roles, 0..) |role, i| for (role.accesses) |access| {
        const resource = record.resources[A.index(A.Resource, d.resources, access.resource).?].?;
        if (at(record.next, &n)) return .{ .command = .{ .associate = .{ .pid = record.pids[i].?, .name = try p.Value.init(access.name), .resource = resource, .required = access.required } } };
        if (at(record.next, &n)) return .{ .command = .{ .grant_resource = .{ .resource = resource, .subject = record.workers[i], .permissions = access.permissions } } };
    };
    for (d.callers, 0..) |caller, i| for (caller.reads) |read| if (at(record.next, &n)) return .{ .command = .{ .grant_resource = .{ .resource = record.resources[A.index(A.Resource, d.resources, read.resource).?].?, .subject = record.callers[i], .permissions = read.permissions } } };
    for (d.initialize) |initial| if (at(record.next, &n)) return .{ .principal = record.callers[A.index(A.Caller, d.callers, initial.caller).?], .command = .{ .send = .{ .pid = record.pids[A.index(A.Role, d.roles, initial.role).?].?, .value = initial.value } } };
    if (record.next != n) return error.InvalidApplicationCatalog;
    return null;
}
fn callerKey(self: *Self, allocator: std.mem.Allocator, application: []const u8, i: usize) !p.Ed25519.KeyPair {
    return q.wire.readKey(allocator, self.init.io, try self.path(allocator, application, try std.fmt.allocPrint(allocator, "caller-{d}.seed", .{i})));
}
fn submit(self: *Self, allocator: std.mem.Allocator, record: *Record, step: Step) !void {
    if (record.pending != null) return error.UnresolvedProvisioning;
    var key = self.installation.root;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    if (step.principal != 0) {
        const i = std.mem.indexOfScalar(u64, &record.callers, step.principal) orelse return error.InvalidApplicationCatalog;
        key = try self.callerKey(allocator, record.declaration.application, i);
    }
    const basis = try self.installation.wire.query(.{ .realm = self.installation.config.realm, .principal = step.principal, .kind = .capabilities }, key);
    if (basis.position < self.installation.record.position) return error.AuthorityRollback;
    if (!basis.body.capabilities.worker_rotation) return error.UnsupportedWorkerRotation;
    record.pending = .{ .signed = try g.sign(.{ .realm = self.installation.config.realm, .principal = step.principal, .sequence = try std.math.add(u64, basis.principal_sequence, 1), .command = step.command }, key), .effect = step.effect };
    try self.save(allocator, record.*);
    try self.flush(allocator, record);
}
fn flush(self: *Self, allocator: std.mem.Allocator, record: *Record) !void {
    const pending = record.pending orelse return;
    try self.installation.reserveRoot(pending.signed);
    const accepted = try self.installation.wire.submit(pending.signed);
    const receipt: A.Receipt = .{ .index = record.receipt_count, .principal = pending.signed.request.principal, .sequence = pending.signed.request.sequence, .position = accepted.position, .digest = try g.digest(pending.signed.request) };
    const receipt_path = try self.path(allocator, record.declaration.application, try std.fmt.allocPrint(allocator, "receipts/{d}.json", .{receipt.index}));
    const previous = Files.read(A.Receipt, self.init.io, allocator, receipt_path) catch |err| value: {
        if (err != error.FileNotFound) return err;
        break :value null;
    };
    if (previous) |value| {
        if (!std.meta.eql(value, receipt)) return error.InvalidApplicationCatalog;
    } else try Files.json(self.init.io, allocator, receipt_path, receipt);
    switch (pending.effect) {
        .provision => |effect| {
            if (effect.pid) |i| record.pids[i] = accepted.position;
            if (effect.resource) |i| record.resources[i] = accepted.position;
            record.next += 1;
        },
        .inspection => record.inspection_next += 1,
        .activation, .fence => |i| {
            record.public_keys[i] = pending.signed.request.command.rotate_worker.public_key;
            record.generations[i] = pending.signed.request.command.rotate_worker.expected_generation + 1;
            if (pending.effect == .fence) record.replacement.?.fenced = true;
        },
    }
    record.pending = null;
    record.receipt_count = try std.math.add(u32, record.receipt_count, 1);
    try self.save(allocator, record.*);
    self.installation.record.position = @max(self.installation.record.position, accepted.position);
    try self.installation.save();
    try self.installation.releaseRoot(pending.signed);
}
pub fn tick(self: *Self) !void {
    if (self.failed.load(.acquire)) return error.ApplicationManagerFailed;
    try self.mutex.lock(self.init.io);
    defer self.mutex.unlock(self.init.io);
    if (self.count == 0) return;
    var arena = std.heap.ArenaAllocator.init(self.init.gpa);
    defer arena.deinit();
    const allocator = arena.allocator();
    const index = self.next_app % self.count;
    defer self.next_app = (index + 1) % self.count;
    const app = &self.apps[index];
    var record = try self.load(allocator, app.label());
    if (self.installation.root_pending != null) {
        const pending = record.pending orelse return;
        if (!try self.installation.ownsRoot(pending.signed)) return;
    }
    if (record.blocked == null) self.advance(allocator, app, &record) catch |err| {
        if (q.wire.Client.unavailable(err) or (record.pending == null and err == error.Conflict)) return; // Keep the same frozen operation first.
        if (self.installation.failed or self.failed.load(.acquire) or err == error.AuthorityRollback or err == error.NoSpaceLeft or err == error.InstallationSyncFailed) return err;
        if (Signals.interrupted()) return error.ServerStopped;
        record.blocked = @errorName(err);
        // Explicit negative decisions do not leave an uncertain operation. Keep
        // the rejected proposal for inspection, and let unrelated apps progress.
        if (record.pending) |pending| {
            if (self.installation.wire.last_rejection == null) return err;
            if (pending.signed.request.principal == 0) {
                const observed = try self.installation.query(.capabilities);
                if (observed.principal_sequence < pending.signed.request.sequence) {
                    record.rejected = pending;
                    record.pending = null;
                    try self.installation.releaseRoot(pending.signed);
                }
            }
        }
        try self.save(allocator, record);
        for (app.workers[0..app.role_count]) |*worker| {
            worker.process.stop(self.init.io);
            worker.phase = .failed;
            worker.error_name = @errorName(err);
        }
    };
}
fn advance(self: *Self, allocator: std.mem.Allocator, app: *Runtime, record: *Record) !void {
    try self.installer(record.installer, self.installation.wire);
    if (record.pending != null) {
        try self.flush(allocator, record);
        return;
    }
    if (!record.installed) {
        if (try self.plan(allocator, record.*)) |step| {
            try self.submit(allocator, record, step);
            return;
        }
        record.installed = true;
        try self.save(allocator, record.*);
        return;
    }
    if (self.installation.record.board_receipts[0] != null and record.inspection_next < record.declaration.inspection.len) {
        const read = record.declaration.inspection[record.inspection_next];
        const resource = record.resources[A.index(A.Resource, record.declaration.resources, read.resource).?].?;
        try self.submit(allocator, record, .{ .command = .{ .grant_resource = .{ .resource = resource, .subject = Installation.board, .permissions = read.permissions } }, .effect = .inspection });
        return;
    }
    if (record.replacement) |replacement| {
        try self.installer(replacement.signed.identity, self.installation.wire);
        try self.remember(allocator, replacement.signed);
        const target = replacement.signed.request.command.replace;
        const i = A.index(A.Role, record.declaration.roles, target.role).?;
        if (!replacement.fenced) {
            const process = (try self.installation.query(.{ .process = record.pids[i].? })).body.process.process;
            var seed: [32]u8 = undefined;
            try self.init.io.randomSecure(&seed);
            defer std.crypto.secureZero(u8, &seed);
            const key = try p.Ed25519.KeyPair.generateDeterministic(seed);
            try self.submit(allocator, record, .{ .command = .{ .rotate_worker = .{ .pid = record.pids[i].?, .worker = record.workers[i], .expected_generation = process.generation, .expected_public_key = record.public_keys[i], .expected_permissions = A.worker_permissions, .public_key = key.public_key.toBytes() } }, .effect = .{ .fence = @intCast(i) } });
            return;
        }
        self.stopDependents(app, record.*, i);
        record.selected[i] = .{ .artifact = target.artifact, .configuration = target.configuration, .revision = try revision(allocator, target.contract, target.artifact, target.configuration) };
        record.replacement = null;
        try self.save(allocator, record.*);
        return;
    }
    roles: for (record.declaration.roles, 0..) |role, i| {
        const worker = &app.workers[i];
        if (worker.phase == .failed) continue;
        if (worker.phase != .pending and !worker.process.alive()) {
            self.stopDependents(app, record.*, i);
            if (worker.restarts == 3) {
                worker.phase = .failed;
                worker.error_name = "RestartBudgetExhausted";
                return;
            }
            worker.restarts += 1;
            return;
        }
        if (worker.phase == .ready) continue;
        for (role.depends_on) |dependency| if (app.workers[A.index(A.Role, record.declaration.roles, dependency).?].phase != .ready) continue :roles;
        if (worker.phase == .pending) {
            try self.startWorker(allocator, app, record.*, i);
            return;
        }
        if (worker.phase == .registration) {
            const registration = try self.pollRegistration(worker) orelse return;
            if (registration.version != 1 or registration.realm != self.installation.config.realm or registration.principal != record.workers[i] or registration.pid != record.pids[i].? or registration.generation != worker.registration.?.generation) return error.InvalidRegistration;
            worker.registration = registration;
            worker.phase = .activation;
            try self.submit(allocator, record, .{ .command = .{ .rotate_worker = .{ .pid = registration.pid, .worker = registration.principal, .expected_generation = registration.generation - 1, .expected_public_key = record.public_keys[i], .expected_permissions = A.worker_permissions, .public_key = registration.public_key } }, .effect = .{ .activation = @intCast(i) } });
            return;
        }
        if (worker.phase == .activation) {
            const marker = try self.path(allocator, app.label(), try std.fmt.allocPrint(allocator, "activations/{d}-{d}-{d}.activation", .{ self.installation.config.realm, record.pids[i].?, record.generations[i] }));
            std.Io.Dir.cwd().access(self.init.io, marker, .{}) catch |err| {
                if (err != error.FileNotFound) return err;
                if (worker.started.?.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 30000) return error.RoleReadinessTimeout;
                return;
            };
            const process = (try self.installation.query(.{ .process = record.pids[i].? })).body.process.process;
            if (process.owner != record.workers[i] or process.generation != record.generations[i] or process.failure != null or process.lifecycle != .running) return error.ProcessUnavailable;
            worker.phase = .ready;
            return;
        }
    }
}
fn stopDependents(self: *Self, app: *Runtime, record: Record, index: usize) void {
    var affected: [A.max_roles]bool = @splat(false);
    affected[index] = true;
    for (record.declaration.roles, 0..) |role, i| for (role.depends_on) |dependency| if (affected[A.index(A.Role, record.declaration.roles, dependency).?]) {
        affected[i] = true;
    };
    var i = app.role_count;
    while (i > 0) {
        i -= 1;
        if (affected[i]) {
            app.workers[i].process.stop(self.init.io);
            app.workers[i].phase = .pending;
            app.workers[i].registration = null;
            app.workers[i].length = 0;
        }
    }
}
fn startWorker(self: *Self, allocator: std.mem.Allocator, app: *Runtime, record: Record, i: usize) !void {
    const selected = try candidate(allocator, record, i);
    if (!std.mem.eql(u8, &try Config.digest(self.init, selected.artifact.path), &selected.artifact.sha256)) return error.ApplicationArtifactChanged;
    const process = (try self.installation.query(.{ .process = record.pids[i].? })).body.process.process;
    if (process.lifecycle != .running or process.failure != null) return error.ProcessUnavailable;
    const generation = try std.math.add(u64, process.generation, 1);
    const config: A.Bootstrap = .{ .application = app.label(), .role = record.declaration.roles[i].name, .contract = record.declaration.roles[i].contract, .revision = selected.revision, .url = self.installation.wire.url, .realm = self.installation.config.realm, .principal = record.workers[i], .pid = record.pids[i].?, .generation = generation, .activation_directory = try self.path(allocator, app.label(), "activations"), .roles = try bindings(allocator, record, .roles), .resources = try bindings(allocator, record, .resources), .callers = try bindings(allocator, record, .callers), .configuration = selected.configuration };
    try config.validate();
    const path_name = try self.path(allocator, app.label(), try std.fmt.allocPrint(allocator, "{s}.bootstrap.json", .{config.role}));
    try Files.json(self.init.io, allocator, path_name, config);
    const worker = &app.workers[i];
    try worker.process.start(self.init, self.executable, try self.path(allocator, app.label(), try std.fmt.allocPrint(allocator, "{s}.launch.json", .{config.role})), .{ .argv = &.{ selected.artifact.path, "--transit-bootstrap-v1", path_name }, .environment = &self.installation.config.logging.environment() }, true);
    worker.phase = .registration;
    worker.started = std.Io.Clock.awake.now(self.init.io);
    worker.registration = .{ .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = generation, .public_key = @splat(0) };
}
fn pollRegistration(self: *Self, worker: *Worker) !?q.wire.bootstrap.GrowingRegistration {
    if (worker.started.?.durationTo(std.Io.Clock.awake.now(self.init.io)).toMilliseconds() >= 10000) return error.RegistrationTimeout;
    var descriptors: [1]std.c.pollfd = .{.{ .fd = worker.process.stdout_file.?.handle, .events = std.c.POLL.IN, .revents = 0 }};
    for (0..worker.buffer.len) |_| {
        if (std.c.poll(&descriptors, 1, 0) <= 0) return null;
        if (worker.length == worker.buffer.len) return error.InvalidRegistration;
        if (std.c.read(descriptors[0].fd, @ptrCast(&worker.buffer[worker.length]), 1) != 1) return error.InvalidRegistration;
        if (worker.buffer[worker.length] == '\n') {
            const parsed = try std.json.parseFromSlice(struct { growing_bootstrap: q.wire.bootstrap.GrowingRegistration }, self.init.gpa, worker.buffer[0..worker.length], .{});
            defer parsed.deinit();
            try worker.process.drainStdout(self.init.io);
            return parsed.value.growing_bootstrap;
        }
        worker.length += 1;
    }
    return error.InvalidRegistration;
}

test "replacement checkpoint admission reserves recovery space for escaped configuration" {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var record: Record = .{ .definition = g.current_definition, .installation = @splat(1), .declaration = .{ .application = "items", .roles = &.{}, .resources = &.{}, .callers = &.{} }, .digest = @splat(2), .installer = try g.signQuery(.{ .realm = 1, .principal = 24, .kind = .identity }, key) };
    const configuration: [8192]u8 = @splat(0);
    const selected: Candidate = .{ .artifact = .{ .path = "/worker", .sha256 = @splat(3) }, .configuration = &configuration, .revision = @splat(4) };
    record.selected[0] = selected;
    try admitCheckpoint(std.testing.allocator, record);
    for (&record.selected) |*slot| slot.* = selected;
    try std.testing.expectError(error.ApplicationCheckpointCapacity, admitCheckpoint(std.testing.allocator, record));
}

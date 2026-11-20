//! Server-owned Station service processes. Registration describes work; signed
//! public reads and operations remain its authorization and durable authority.
const std = @import("std");
const q = @import("transit_query");
const tx_station = @import("station_transaction_internal");
const p = q.protocol;
const g = p.Growth;
const Controller = q.station.Controller;
const TxController = tx_station.ServiceController;
const Files = @import("Files.zig");
const Process = @import("Process.zig");
const Role = @import("StationRole.zig");
const Installation = @import("Installation.zig");

pub const Service = struct {
    name: []const u8,
    principal: u64,
    seed_file: []const u8,
    mode: Controller.Mode,
    watches: []const Controller.Watch = &.{},
    transactional: []const TxController.Watch = &.{},
    lease_ms: u64 = 30000,
    interval_ms: u32 = 100,
    request_timeout_ms: u32 = 2000,
};

pub const Manifest = struct { version: u8 = 1, definition: g.Definition, realm: u64, services: []const Service };

pub fn txMode(mode: Controller.Mode) TxController.Mode {
    return switch (mode) {
        .observe => .observe,
        .lifecycle => .lifecycle,
    };
}

pub fn validate(services: []const Service, limit: usize) !void {
    if (services.len > limit) return error.StationServiceCapacity;
    for (services, 0..) |service, i| {
        try q.wire.Application.name(service.name);
        if (service.principal == 0 or service.principal > p.max_counter or service.principal == Installation.courier or service.principal == Installation.maintenance or service.principal == Installation.board) return error.InvalidController;
        if (!std.fs.path.isAbsolute(service.seed_file) or service.interval_ms == 0 or service.interval_ms > 60000 or service.request_timeout_ms == 0 or service.request_timeout_ms > 60000 or service.lease_ms == 0) return error.InvalidController;
        if ((service.watches.len > 0) == (service.transactional.len > 0)) return error.InvalidController;
        for (services[0..i]) |old| if (old.principal == service.principal or std.mem.eql(u8, old.name, service.name)) return error.DuplicateStationService;
        if (service.watches.len > 0) {
            if (service.watches.len > 4) return error.InvalidController;
            for (service.watches, 0..) |watch, j| {
                if (watch.pid == 0 or watch.pid > p.max_counter or watch.resource == 0 or watch.resource > p.max_counter) return error.InvalidWatch;
                if (watch.child) |child| if (child == 0 or child > p.max_counter) return error.InvalidWatch;
                if (service.mode == .lifecycle and watch.child == null) return error.InvalidWatch;
                if (service.mode == .lifecycle and watch.child != service.watches[0].child) return error.InvalidWatch;
                for (service.watches[0..j]) |old| if (std.meta.eql(old, watch)) return error.InvalidWatch;
            }
        } else {
            try TxController.validateWatches(service.principal, service.transactional[0].connection.scope.realm, txMode(service.mode), service.transactional);
        }
    }
}

pub fn external(init: std.process.Init, installation: *Installation, executable: []const u8) !?*Group {
    const file = installation.config.station.file orelse {
        if (installation.record.station_manifest != null) return error.MissingStationManifest;
        return null;
    };
    var arena = std.heap.ArenaAllocator.init(init.gpa);
    defer arena.deinit();
    const manifest = try Files.read(Manifest, init.io, arena.allocator(), file);
    if (manifest.version != 1 or manifest.definition != g.current_definition or manifest.realm != installation.config.realm) return error.InvalidStationManifest;
    try validate(manifest.services, installation.config.station.max_services);
    for (manifest.services) |service| {
        if (service.transactional.len > 0 and service.transactional[0].connection.scope.realm != manifest.realm)
            return error.InvalidStationManifest;
    }
    const bytes = try p.Json.valueAlloc(arena.allocator(), manifest);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (installation.record.station_manifest) |accepted| {
        if (!std.mem.eql(u8, &accepted, &digest)) return error.StationManifestChanged;
    } else {
        for (manifest.services) |service| try checkAccess(init, installation, service);
        // Freeze scope before starting any sequencer. A crash after this save
        // requires this same manifest and the already provisioned identities.
        installation.record.station_manifest = digest;
        try installation.save();
    }
    return Group.create(init, installation, executable, "station", manifest.services, false);
}

fn checkAccess(init: std.process.Init, installation: *Installation, service: Service) !void {
    if (service.watches.len > 0) {
        var controller: Controller = .{
            .client = installation.wire,
            .realm = installation.config.realm,
            .principal = service.principal,
            .key = try q.wire.readKey(init.gpa, init.io, service.seed_file),
            .mode = service.mode,
            .watches = service.watches,
        };
        defer std.crypto.secureZero(u8, std.mem.asBytes(&controller.key));
        try controller.check();
    } else {
        var data_wire = q.wire.Client.init(init.gpa, init.io, installation.wire.url);
        defer data_wire.deinit();
        data_wire.timeout_ms = service.request_timeout_ms;
        var controller = try TxController.init(
            init.gpa,
            installation.wire,
            &data_wire,
            installation.config.realm,
            service.principal,
            try q.wire.readKey(init.gpa, init.io, service.seed_file),
            txMode(service.mode),
            service.transactional,
            service.lease_ms,
            1,
        );
        defer controller.deinit();
        try controller.check();
    }
}

pub const Group = struct {
    const Slot = struct { process: Process = .{}, config: Role.Config, ready: bool = false, completed_passes: u64 = 0 };
    init: std.process.Init,
    installation: *Installation,
    arena: std.heap.ArenaAllocator,
    scratch: std.heap.ArenaAllocator,
    slots: []Slot,
    checked: ?std.Io.Timestamp = null,
    active: bool = false,

    pub fn create(init: std.process.Init, installation: *Installation, executable: []const u8, namespace: []const u8, services: []const Service, local_workers: bool) !*Group {
        try validate(services, installation.config.station.max_services);
        const self = try init.gpa.create(Group);
        self.* = .{ .init = init, .installation = installation, .arena = .init(init.gpa), .scratch = .init(init.gpa), .slots = &.{} };
        errdefer self.destroy();
        const allocator = self.arena.allocator();
        const encoded = try p.Json.valueAlloc(allocator, services);
        const owned = try std.json.parseFromSliceLeaky([]const Service, allocator, encoded, .{ .allocate = .alloc_always });
        const slots = try allocator.alloc(Slot, owned.len);
        var boot: [16]u8 = undefined;
        try init.io.randomSecure(&boot);
        for (owned, 0..) |service, i| {
            const directory = try std.fs.path.join(allocator, &.{ installation.config.installation, namespace, service.name });
            try std.Io.Dir.cwd().createDirPath(init.io, directory);
            slots[i] = .{ .config = .{
                .url = installation.wire.url,
                .realm = installation.config.realm,
                .principal = service.principal,
                .seed_file = service.seed_file,
                .mode = service.mode,
                .watches = service.watches,
                .transactional = service.transactional,
                .lease_ms = service.lease_ms,
                .interval_ms = service.interval_ms,
                .request_timeout_ms = service.request_timeout_ms,
                .status_file = try std.fs.path.join(allocator, &.{ directory, "status.json" }),
                .boot = boot,
            } };
            self.slots = slots[0 .. i + 1];
            if (local_workers and service.mode == .lifecycle) slots[i].config.local_stop = directory;
            try self.access(&slots[i]);
            const config_path = try std.fs.path.join(allocator, &.{ directory, "config.json" });
            try Files.json(init.io, allocator, config_path, slots[i].config);
            const arguments = try @import("../RuntimeRole.zig").arguments(allocator, executable, null, .station, &.{config_path});
            try slots[i].process.start(init, executable, try std.fs.path.join(allocator, &.{ directory, "launch.json" }), .{ .argv = arguments, .environment = &installation.config.logging.environment() }, false);
        }
        const started = std.Io.Clock.awake.now(init.io);
        while (!try self.check()) {
            if (@import("../Signals.zig").interrupted()) return error.ServerStopped;
            if (started.durationTo(std.Io.Clock.awake.now(init.io)).toMilliseconds() >= 30000) return error.StationReadinessTimeout;
            try init.io.sleep(.fromMilliseconds(100), .awake);
        }
        self.active = true;
        return self;
    }

    pub fn destroy(self: *Group) void {
        for (self.slots) |*slot| slot.process.stop(self.init.io);
        self.scratch.deinit();
        self.arena.deinit();
        self.init.gpa.destroy(self);
    }

    fn access(self: *Group, slot: *const Slot) !void {
        const config = slot.config;
        try checkAccess(self.init, self.installation, .{
            .name = "slot",
            .principal = config.principal,
            .seed_file = config.seed_file,
            .mode = config.mode,
            .watches = config.watches,
            .transactional = config.transactional,
            .lease_ms = config.lease_ms,
            .interval_ms = config.interval_ms,
            .request_timeout_ms = config.request_timeout_ms,
        });
    }

    pub fn check(self: *Group) !bool {
        defer _ = self.scratch.reset(.retain_capacity);
        var ready = true;
        const now = std.Io.Clock.awake.now(self.init.io);
        const authenticate = self.checked == null or self.checked.?.durationTo(now).toMilliseconds() >= 1000;
        for (self.slots) |*slot| {
            if (!slot.process.alive()) return error.StationServiceExited;
            slot.ready = false;
            if (authenticate) try self.access(slot);
            const status = Files.read(Role.Status, self.init.io, self.scratch.allocator(), slot.config.status_file) catch |err| {
                if (err != error.FileNotFound) return err;
                if (self.active) return error.StationServiceUnavailable;
                ready = false;
                continue;
            };
            const age = std.Io.Clock.awake.now(self.init.io).toMilliseconds() - status.observed_ms;
            const grace: i128 = @as(i128, slot.config.interval_ms) + @as(i128, slot.config.request_timeout_ms) * 3 + 5000;
            const fresh = std.mem.eql(u8, &status.boot, &slot.config.boot) and age >= 0 and age <= grace;
            if (self.active and !fresh) return error.StationServiceUnavailable;
            slot.ready = fresh and status.ready;
            slot.completed_passes = status.completed_passes;
            if (!slot.ready) ready = false;
        }
        if (authenticate) self.checked = now;
        return ready;
    }

    pub const Progress = struct { ready: bool, completed_passes: u64 };
    pub fn progress(self: *const Group, index: usize) Progress {
        return .{ .ready = self.slots[index].ready, .completed_passes = self.slots[index].completed_passes };
    }

    /// Only the local worker owner acknowledges a joined stop. Boot and native
    /// or transactional failure identity bind that evidence to this runner and retry.
    pub fn joinStops(self: *Group, context: anytype, join: anytype) !void {
        defer _ = self.scratch.reset(.retain_capacity);
        const allocator = self.scratch.allocator();
        for (self.slots) |slot| {
            const directory = slot.config.local_stop orelse continue;
            const request = Files.read(Role.Stop, self.init.io, allocator, try std.fs.path.join(allocator, &.{ directory, "stop.json" })) catch |err| {
                if (err == error.FileNotFound) continue;
                return err;
            };
            const expected_pid = if (slot.config.watches.len > 0)
                slot.config.watches[0].child.?
            else
                slot.config.transactional[0].child.?.pid;
            if (!std.mem.eql(u8, &request.boot, &slot.config.boot) or request.pid != expected_pid) continue;
            const process = (try self.installation.query(.{ .process = request.pid })).body.process.process;
            if (process.generation != request.generation) continue;
            if (slot.config.watches.len > 0) {
                if (process.failure != request.failure) continue;
            } else if (process.failure != request.failure) {
                var data_wire = q.wire.Client.init(self.init.gpa, self.init.io, self.installation.wire.url);
                defer data_wire.deinit();
                data_wire.timeout_ms = slot.config.request_timeout_ms;
                var inspector = try TxController.init(
                    self.init.gpa,
                    self.installation.wire,
                    &data_wire,
                    slot.config.realm,
                    slot.config.principal,
                    try q.wire.readKey(self.init.gpa, self.init.io, slot.config.seed_file),
                    .lifecycle,
                    slot.config.transactional,
                    slot.config.lease_ms,
                    1,
                );
                defer inspector.deinit();
                const blocked = (try inspector.inspectBlockedFailure(slot.config.transactional[0], request.pid)) orelse continue;
                if (blocked.generation != request.generation or blocked.failure != request.failure) continue;
            }
            try join(context, request.pid);
            _ = try Files.jsonIfChanged(self.init.io, allocator, try std.fs.path.join(allocator, &.{ directory, "stopped.json" }), request);
        }
    }
};

test "Station service registration rejects duplicate sequencers and unscoped lifecycle intent" {
    const service: Service = .{ .name = "observer", .principal = 101, .seed_file = "/private/seed", .mode = .observe, .watches = &.{.{ .pid = 3, .resource = 4 }} };
    try validate(&.{service}, 1);
    try std.testing.expectError(error.DuplicateStationService, validate(&.{ service, service }, 2));
    var lifecycle = service;
    lifecycle.mode = .lifecycle;
    try std.testing.expectError(error.InvalidWatch, validate(&.{lifecycle}, 1));
    try std.testing.expectError(error.StationServiceCapacity, validate(&.{service}, 0));

    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = 2, .catalog = 3 };
    const conn: tx_station.catalog.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 101, .role = null };
    const timers: p.StreamQueue.Partition = .{
        .definition = g.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 8 }, .revision = 1, .digest = @splat(1) },
        .partition = 0,
    };
    const tx_service: Service = .{ .name = "tx-observer", .principal = 101, .seed_file = "/private/seed", .mode = .observe, .transactional = &.{.{ .connection = conn, .timers = timers }} };
    try validate(&.{tx_service}, 1);
    var both = tx_service;
    both.watches = &.{.{ .pid = 3, .resource = 4 }};
    try std.testing.expectError(error.InvalidController, validate(&.{both}, 1));
}

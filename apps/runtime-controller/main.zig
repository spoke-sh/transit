//! One PID's reference reconciler. Backlog scans are authoritative; notifications
//! and provider state cannot create execution rights. --once advances one step.
const std = @import("std");
const transit = @import("transit");
const wire = @import("transit_client");
const substrate = @import("runtime_substrate");
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u8,
    seed_file: []const u8,
    pid: u64,
    worker: u8,
    provider: substrate.Config,
};
const Controller = struct {
    config: Config,
    client: *wire.Client,
    provider: substrate.Adapter,
    key: transit.Ed25519.KeyPair,

    fn send(self: *Controller, view: wire.View, command: transit.Command) !void {
        _ = try self.client.submit(try transit.sign(.{
            .realm = self.config.realm,
            .principal = self.config.principal,
            .sequence = view.principal_sequence + 1,
            .command = command,
        }, self.key));
    }
    fn intent(self: *Controller, view: wire.View, stopped: bool) !void {
        try self.send(view, .{ .runtime_intent = .{
            .pid = self.config.pid,
            .expected_revision = if (view.process.binding) |b| b.revision else 0,
            .instance = self.config.provider.instance,
            .resource = self.provider.resource(),
            .workload = self.provider.workload(),
            .desired = if (stopped) .stopped else .running,
        } });
    }
    fn observe(self: *Controller, view: wire.View, uid: ?[16]u8, stopped: bool) !void {
        const b = view.process.binding.?;
        try self.send(view, .{ .runtime_observe = .{
            .pid = self.config.pid,
            .revision = b.revision,
            .operation = b.operation,
            .incarnation = uid,
            .outcome = if (stopped) .stopped else .ready,
        } });
    }
    fn step(self: *Controller) !enum { idle, intent, created, resumed, observed, activated, suspended } {
        const view = try self.client.view(.{
            .realm = self.config.realm,
            .principal = self.config.principal,
            .sequence = 0,
            .command = .{ .inspect = self.config.pid },
        }, self.key);
        const p = view.process;
        const retired = p.lifecycle != .running;
        const backlog = p.admitted > p.consumed + p.cancelled;
        const b = p.binding orelse {
            if (retired or !backlog) return .idle;
            try self.intent(view, false);
            return .intent;
        };
        if (!std.meta.eql(b.instance, self.config.provider.instance) or
            !std.meta.eql(b.resource, self.provider.resource()) or
            !std.meta.eql(b.workload, self.provider.workload())) return error.BindingMismatch;
        if (b.phase == .pending or b.phase == .unknown) {
            const actor = self.provider.get() catch |err| switch (err) {
                error.ProviderNotFound => {
                    // A bound incarnation disappearing is not permission to
                    // recreate its name and adopt a different provider resource.
                    if (b.incarnation != null) return error.ProviderIncarnationLost;
                    if (retired or b.desired == .stopped) {
                        try self.observe(view, null, true);
                        return .observed;
                    }
                    try self.provider.create();
                    // Deliberately yield after physical create. The next scan
                    // reconciles it; no local receipt is necessary for recovery.
                    return .created;
                },
                else => return err,
            };
            if (b.incarnation) |uid| if (!std.meta.eql(uid, actor.uid)) return error.ProviderIncarnationMismatch;
            if (b.desired == .stopped) {
                if (actor.state == .running) {
                    try self.provider.suspendActor();
                    return .suspended;
                }
                if (actor.state != .suspended and actor.state != .crashed) return .idle;
                try self.observe(view, actor.uid, true);
                return .observed;
            }
            if (retired or actor.state == .running) {
                // Evidence can settle after retirement; it grants no activation.
                if (!retired) try self.provider.policy();
                try self.observe(view, actor.uid, false);
                return .observed;
            }
            if (actor.state == .suspended or actor.state == .crashed) {
                try self.provider.policy();
                try self.provider.resumeActor();
                return .resumed;
            }
            return .idle;
        }
        if (retired) {
            if (b.desired == .stopped or b.phase == .stopped) return .idle;
            try self.intent(view, true);
            return .intent;
        }
        if (!backlog or b.desired == .stopped) return .idle;
        const actor = try self.provider.get();
        if (!std.meta.eql(b.incarnation, @as(?[16]u8, actor.uid))) return error.ProviderIncarnationMismatch;
        if (actor.state != .running or (if (b.activation) |a| !std.meta.eql(actor.worker, @as(?[16]u8, a.worker_incarnation)) else false)) {
            try self.intent(view, false);
            return .intent;
        }
        if (b.activation != null) return .idle;
        const registration = try self.provider.bootstrap(actor);
        if (registration.realm != self.config.realm or registration.pid != self.config.pid) return error.BootstrapMismatch;
        try self.send(view, .{ .activate = .{
            .pid = p.pid,
            .revision = b.revision,
            .expected_generation = p.generation,
            .worker = self.config.worker,
            .public_key = registration.public_key,
            .worker_incarnation = actor.worker orelse return error.ProviderNotReady,
        } });
        return .activated;
    }
};
pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !std.mem.eql(u8, args[2], "--once"))) return error.ExpectedConfigAndOptionalOnce;
    const body = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(body);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, body, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    var controller: Controller = .{
        .config = config,
        .client = &client,
        .provider = .{ .allocator = init.gpa, .io = init.io, .config = config.provider },
        .key = try wire.readKey(init.gpa, init.io, config.seed_file),
    };
    try controller.provider.validate();
    while (true) {
        const result = controller.step() catch |err| {
            if (args.len == 3) return err;
            std.debug.print("runtime reconciliation: {s}\n", .{@errorName(err)});
            try init.io.sleep(.fromSeconds(1), .awake);
            continue;
        };
        var buffer: [128]u8 = undefined;
        var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try writer.interface.print("{s}\n", .{@tagName(result)});
        try writer.interface.flush();
        if (args.len == 3) return;
        try init.io.sleep(.fromSeconds(1), .awake);
    }
}

//! One PID's reference reconciler. Backlog scans are authoritative; notifications
//! and provider state cannot create execution rights. --once advances one step.
const std = @import("std");
const transit = wire.protocol.Growth;
const View = struct { process: transit.Process, principal_sequence: u64 };
const wire = @import("transit_client");
const observations = wire.observability;
const telemetry = observations.telemetry;
const substrate = @import("transit_runtime_substrate");
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    pid: u64,
    worker: u64,
    provider: substrate.Config,
};
const Controller = struct {
    config: Config,
    client: *wire.Client,
    provider: substrate.Adapter,
    key: wire.protocol.Ed25519.KeyPair,
    generation: ?u64 = null,
    binding_revision: ?u64 = null,

    fn send(self: *Controller, view: View, command: transit.Command) !void {
        _ = try self.client.submit(try transit.sign(.{
            .realm = self.config.realm,
            .principal = self.config.principal,
            .sequence = view.principal_sequence + 1,
            .command = command,
        }, self.key));
    }
    fn intent(self: *Controller, view: View, stopped: bool) !void {
        try self.send(view, .{ .runtime_intent = .{
            .pid = self.config.pid,
            .expected_revision = if (view.process.binding) |b| b.revision else 0,
            .instance = self.config.provider.instance,
            .resource = self.provider.resource(),
            .workload = self.provider.workload(),
            .desired = if (stopped) .stopped else .running,
        } });
    }
    fn observe(self: *Controller, view: View, uid: ?[16]u8, stopped: bool) !void {
        const b = view.process.binding.?;
        try self.send(view, .{ .runtime_observe = .{
            .pid = self.config.pid,
            .revision = b.revision,
            .operation = b.operation,
            .incarnation = uid,
            .outcome = if (stopped) .stopped else .ready,
        } });
    }
    fn currentView(self: *Controller) !View {
        const response = try self.client.query(.{ .realm = self.config.realm, .principal = self.config.principal, .kind = .{ .process = self.config.pid } }, self.key);
        return .{ .process = response.body.process.process, .principal_sequence = response.principal_sequence };
    }
    fn step(self: *Controller) !enum { idle, intent, created, reverted, resumed, observed, activated, suspended, switched } {
        const view = try self.currentView();
        const p = view.process;
        self.generation = p.generation;
        self.binding_revision = if (p.binding) |binding| binding.revision else null;
        const stopping = p.lifecycle != .running or p.failure != null or (if (p.control) |control| control.phase != .ready else false);
        const backlog = p.admitted > p.consumed + p.cancelled;
        const b = p.binding orelse {
            if (stopping or !backlog) return .idle;
            try self.intent(view, false);
            return .intent;
        };
        if (!std.meta.eql(b.instance, self.config.provider.instance) or
            !std.meta.eql(b.resource, self.provider.resource()) or
            !std.meta.eql(b.workload, self.provider.workload())) return error.BindingMismatch;
        if (b.upgrade_from) |previous| {
            if (b.desired != .stopped or (b.phase != .pending and b.phase != .unknown)) return error.InvalidBinding;
            switch (try self.provider.reconcileUpgrade(previous, b.incarnation orelse return error.InvalidBinding)) {
                .idle => return .idle,
                .reverted => return .reverted,
                .switched => return .switched,
                .stopped => {
                    try self.observe(view, b.incarnation, true);
                    return .observed;
                },
            }
        }
        if (b.phase == .pending or b.phase == .unknown) {
            const actor = self.provider.get() catch |err| switch (err) {
                error.ProviderNotFound => {
                    // A bound incarnation disappearing is not permission to
                    // recreate its name and adopt a different provider resource.
                    if (b.incarnation != null) return error.ProviderIncarnationLost;
                    if (stopping or b.desired == .stopped) {
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
            if (stopping or actor.state == .running) {
                // Evidence can settle after retirement; it grants no activation.
                if (!stopping) try self.provider.policy();
                try self.observe(view, actor.uid, false);
                return .observed;
            }
            if (actor.state == .crashed) {
                // Substrate requires revert before resuming a crashed Actor.
                // The pending durable intent has already fenced the old owner.
                try self.provider.revertActor();
                return .reverted;
            }
            if (actor.state == .suspended) {
                try self.provider.policy();
                try self.provider.resumeActor();
                return .resumed;
            }
            return .idle;
        }
        if (stopping) {
            if (b.desired == .stopped or b.phase == .stopped) return .idle;
            try self.intent(view, true);
            return .intent;
        }
        if ((!backlog and b.activation != null) or b.desired == .stopped) return .idle;
        const actor = try self.provider.get();
        if (!std.meta.eql(b.incarnation, @as(?[16]u8, actor.uid))) return error.ProviderIncarnationMismatch;
        if (actor.state != .running or (if (b.activation) |a| !std.meta.eql(actor.worker, @as(?[16]u8, a.worker_incarnation)) else false)) {
            try self.intent(view, false);
            return .intent;
        }
        if (b.activation != null) return .idle;
        // A cold boot may reuse a Substrate worker pod. This profile binds
        // activation to a fresh pod UID, so placement must replace that worker
        // before bootstrap logs can identify an eligible activation.
        if (b.last_worker_incarnation) |previous| {
            if (std.meta.eql(actor.worker, @as(?[16]u8, previous))) return error.StaleWorkerIncarnation;
        }
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
    var diagnostics = telemetry.Runtime.init(init.io, "transit-runtime-controller", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped", .level = .info });
    diagnostics.event(.{ .name = "service.starting", .level = .info });
    runMain(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn runMain(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const check = args.len == 3 and std.mem.eql(u8, args[2], "--check");
    if (args.len < 2 or args.len > 3 or (args.len == 3 and !check and !std.mem.eql(u8, args[2], "--once"))) return error.ExpectedConfigAndOptionalMode;
    const body = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(wire.max_body));
    defer init.gpa.free(body);
    var parsed = try std.json.parseFromSlice(Config, init.gpa, body, .{});
    defer parsed.deinit();
    const config = parsed.value;
    var client = wire.Client.init(init.gpa, init.io, config.url);
    defer client.deinit();
    client.observer = diagnostics;
    var controller: Controller = .{
        .config = config,
        .client = &client,
        .provider = .{ .allocator = init.gpa, .io = init.io, .config = config.provider, .observer = diagnostics },
        .key = try wire.readKey(init.gpa, init.io, config.seed_file),
    };
    try controller.provider.validate();
    if (check) {
        const view = try controller.currentView();
        if (view.process.binding) |binding| {
            if (!std.meta.eql(binding.instance, config.provider.instance) or
                !std.meta.eql(binding.resource, controller.provider.resource()) or
                !std.meta.eql(binding.workload, controller.provider.workload())) return error.BindingMismatch;
        }
        return; // Readiness never advances the protocol or provider lifecycle.
    }
    while (true) {
        var observation = observations.begin(diagnostics, .runtime_step, "reconcile", null);
        observation.event.realm = config.realm;
        observation.event.pid = config.pid;
        client.parent_context = observation.span.context;
        controller.provider.parent_context = observation.span.context;
        defer client.parent_context = null;
        defer controller.provider.parent_context = null;
        const result = controller.step() catch |err| {
            observation.fail(err);
            observation.finish();
            if (args.len == 3) return err;
            try init.io.sleep(.fromSeconds(1), .awake);
            continue;
        };
        observation.event.operation = @tagName(result);
        observation.event.generation = controller.generation;
        observation.event.binding_revision = controller.binding_revision;
        observation.event.level = if (result == .idle) .debug else .info;
        observation.event.outcome = if (result == .idle) .idle else .ok;
        observation.finish();
        if (args.len == 3) {
            var buffer: [128]u8 = undefined;
            var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
            try writer.interface.print("{s}\n", .{@tagName(result)});
            try writer.interface.flush();
            return;
        }
        try init.io.sleep(.fromSeconds(1), .awake);
    }
}

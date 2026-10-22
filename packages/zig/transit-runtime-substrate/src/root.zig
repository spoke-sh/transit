//! Adapter to the pinned upstream kubectl-ate transport. It owns no Transit
//! authority. Substrate CLI/TLS and Kubernetes credentials stay with controllers.
const std = @import("std");
const observations = @import("transit_observability");
pub const revision = "d277088bc1d081ef716d81dd7986d05d0a36ad3a";
pub const PreviousWorkload = struct { template: []const u8, template_uid: [16]u8, image: []const u8 };
pub const Config = struct {
    cli: []const u8,
    kubeconfig: []const u8,
    context: []const u8,
    instance: [16]u8,
    atespace: []const u8,
    actor: []const u8,
    template: []const u8,
    template_uid: [16]u8,
    image: []const u8,
    container: []const u8 = "counter",
    egress_policy_file: []const u8,
    authority_host: []const u8,
    previous_workload: ?PreviousWorkload = null,
    endpoint: ?[]const u8 = null,
    token_file: ?[]const u8 = null,
};
pub const Actor = struct {
    uid: [16]u8,
    worker: ?[16]u8,
    state: enum { running, suspended, crashed, other },
    previous_workload: bool = false,
};
pub const Bootstrap = struct { realm: u64, pid: u64, public_key: [32]u8 };
pub const Adapter = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    config: Config,
    observer: ?*observations.telemetry.Runtime = null,
    parent_context: ?observations.telemetry.Context = null,

    pub fn resource(self: Adapter) [32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.substrate.resource.v1\x00");
        hash.update(self.config.atespace);
        hash.update("/");
        hash.update(self.config.actor);
        return hash.finalResult();
    }
    pub fn workload(self: Adapter) [32]u8 {
        return workloadIdentity(self.config.template_uid, self.config.image);
    }
    pub fn workloadIdentity(template_uid: [16]u8, image: []const u8) [32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.substrate.workload.v1\x00");
        hash.update(&template_uid);
        hash.update(image);
        return hash.finalResult();
    }
    pub fn validate(self: Adapter) !void {
        for ([_][]const u8{ self.config.atespace, self.config.actor, self.config.template, self.config.container }) |value| try name(value);
        if (self.config.context.len == 0 or self.config.kubeconfig.len == 0 or self.config.cli.len == 0) return error.MissingProviderTrust;
        if ((self.config.endpoint == null) != (self.config.token_file == null)) return error.MissingProviderTrust;
        if (std.mem.find(u8, self.config.image, "@sha256:") == null) return error.UnpinnedImage;
        const version = try self.call(&.{"--version"});
        defer self.allocator.free(version);
        if (std.mem.find(u8, version, "commit=" ++ revision ++ " ") == null) return error.UnsupportedSubstrate;
        if (self.config.previous_workload) |previous| {
            try name(previous.template);
            if (std.mem.find(u8, version, "version transit-upgrade-v1 commit=") == null) return error.UnsupportedSubstrateUpgrade;
            if (std.mem.eql(u8, previous.template, self.config.template)) return error.TemplateMismatch;
        }
        const body = try self.call(&.{ "get", "actor-template", self.config.template, "-a", self.config.atespace });
        defer self.allocator.free(body);
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, body, .{});
        defer parsed.deinit();
        const meta = try member(parsed.value, "metadata");
        if (!std.meta.eql(try uuid(try string(try member(meta, "uid"))), self.config.template_uid)) return error.TemplateMismatch;
        const containers = try member(parsed.value, "containers");
        if (containers != .array or containers.array.items.len != 1) return error.TemplateMismatch;
        if (!std.mem.eql(u8, try string(try member(containers.array.items[0], "name")), self.config.container)) return error.TemplateMismatch;
        if (!std.mem.eql(u8, try string(try member(containers.array.items[0], "image")), self.config.image)) return error.TemplateMismatch;
        const volumes = try member(parsed.value, "volumes");
        if (volumes != .array or volumes.array.items.len != 1) return error.UnsupportedVolumes;
        const volume = volumes.array.items[0];
        if (volume != .object or volume.object.count() != 2 or
            !std.mem.eql(u8, try string(try member(volume, "name")), "runtime-data") or
            (try member(volume, "durableDir")) != .object) return error.UnsupportedVolumes;
        const mounts = try member(containers.array.items[0], "volumeMounts");
        if (mounts != .array or mounts.array.items.len != 1 or
            !std.mem.eql(u8, try string(try member(mounts.array.items[0], "name")), "runtime-data") or
            !std.mem.eql(u8, try string(try member(mounts.array.items[0], "mountPath")), "/runtime-data")) return error.UnsupportedVolumes;
        const snapshots = try member(parsed.value, "snapshotsConfig");
        if (!std.mem.eql(u8, try string(try member(snapshots, "onPause")), "SNAPSHOT_CONTENT_SCOPE_DATA") or
            !std.mem.eql(u8, try string(try member(snapshots, "onCommit")), "SNAPSHOT_CONTENT_SCOPE_DATA") or
            !std.mem.eql(u8, try string(try member(try member(snapshots, "onResume"), "fromData")), "RESUME_SOURCE_COLD_BOOT")) return error.UnsupportedSnapshotPolicy;
    }

    pub fn get(self: Adapter) !Actor {
        return self.getImpl(false);
    }
    /// Called only for a recorded upgrade. Configuration alone is never
    /// authority to switch templates or to accept an earlier workload.
    pub fn reconcileUpgrade(self: Adapter, previous: [32]u8, uid: [16]u8) !enum { idle, reverted, switched, stopped } {
        const old = self.config.previous_workload orelse return error.MissingUpgradeConfiguration;
        if (!std.meta.eql(previous, workloadIdentity(old.template_uid, old.image))) return error.BindingMismatch;
        const actor = try self.getImpl(true);
        if (!std.meta.eql(actor.uid, uid)) return error.ProviderIncarnationMismatch;
        if (actor.state == .crashed) {
            try self.revertActor();
            return .reverted;
        }
        if (actor.state != .suspended) return .idle;
        if (!actor.previous_workload) return .stopped;
        const hex = std.fmt.bytesToHex(uid, .lower);
        const formatted = try self.allocator.print("{s}-{s}-{s}-{s}-{s}", .{ hex[0..8], hex[8..12], hex[12..16], hex[16..20], hex[20..32] });
        defer self.allocator.free(formatted);
        const body = try self.call(&.{ "update", "actor", self.config.actor, "-a", self.config.atespace, "--expected-uid", formatted, "--expected-template", old.template, "--template", self.config.template });
        self.allocator.free(body);
        // Readback on a later scan is required even after a successful response.
        return .switched;
    }
    fn getImpl(self: Adapter, allow_previous: bool) !Actor {
        const body = try self.call(&.{ "get", "actor", self.config.actor, "-a", self.config.atespace });
        defer self.allocator.free(body);
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, body, .{});
        defer parsed.deinit();
        const value = parsed.value;
        const meta = try member(value, "metadata");
        if (!std.mem.eql(u8, try string(try member(meta, "atespace")), self.config.atespace) or
            !std.mem.eql(u8, try string(try member(meta, "name")), self.config.actor)) return error.ResourceMismatch;
        const template = try member(value, "actorTemplate");
        if (!std.mem.eql(u8, try string(try member(template, "atespace")), self.config.atespace)) return error.TemplateMismatch;
        const template_name = try string(try member(template, "name"));
        const previous = !std.mem.eql(u8, template_name, self.config.template);
        if (previous) {
            if (!allow_previous) return error.TemplateMismatch;
            const old = self.config.previous_workload orelse return error.TemplateMismatch;
            if (!std.mem.eql(u8, template_name, old.template)) return error.TemplateMismatch;
        }
        const status = try member(value, "status");
        const state = try string(try member(status, "state"));
        const running = std.mem.eql(u8, state, "ACTOR_STATE_RUNNING");
        var worker: ?[16]u8 = null;
        if (running) {
            if (previous) return error.ProviderNotStopped;
            const current_template = try uuid(try string(try member(status, "currentActorTemplateUid")));
            if (!std.meta.eql(current_template, self.config.template_uid)) return error.TemplateMismatch;
            worker = try uuid(try string(try member(try member(status, "workerAssignment"), "workerPodUid")));
        }
        return .{
            .uid = try uuid(try string(try member(meta, "uid"))),
            .worker = worker,
            .previous_workload = previous,
            .state = if (running) .running else if (std.mem.eql(u8, state, "ACTOR_STATE_SUSPENDED")) .suspended else if (std.mem.eql(u8, state, "ACTOR_STATE_CRASHED")) .crashed else .other,
        };
    }
    pub fn create(self: Adapter) !void {
        const reference = try self.allocator.print("{s}/{s}", .{ self.config.atespace, self.config.template });
        defer self.allocator.free(reference);
        const body = self.call(&.{ "create", "actor", self.config.actor, "-a", self.config.atespace, "--template", reference }) catch |err| switch (err) {
            error.ProviderAlreadyExists => return, // reconciliation validates it
            else => return err,
        };
        self.allocator.free(body);
    }
    pub fn resumeActor(self: Adapter) !void {
        const body = try self.call(&.{ "resume", "actor", self.config.actor, "-a", self.config.atespace });
        self.allocator.free(body);
    }
    pub fn revertActor(self: Adapter) !void {
        const body = try self.call(&.{ "revert", "actor", self.config.actor, "-a", self.config.atespace });
        self.allocator.free(body);
    }
    pub fn suspendActor(self: Adapter) !void {
        const body = try self.call(&.{ "suspend", "actor", self.config.actor, "-a", self.config.atespace });
        self.allocator.free(body);
    }
    /// The one allowed destination is the private authority hostname. All
    /// remaining egress must be denied by the selected Substrate gateway.
    pub fn policy(self: Adapter) !void {
        const query = &.{ "get", "egress-policy", self.config.actor, "-a", self.config.atespace };
        const body = self.call(query) catch |err| switch (err) {
            error.ProviderNotFound => blk: {
                const created = try self.call(&.{ "create", "egress-policy", self.config.actor, "-a", self.config.atespace, "-f", self.config.egress_policy_file });
                self.allocator.free(created);
                // One bounded readback per scan; provider lag is retried by
                // reconciliation, never through unbounded recursion.
                break :blk try self.call(query);
            },
            else => return err,
        };
        defer self.allocator.free(body);
        var parsed = try std.json.parseFromSlice(std.json.Value, self.allocator, body, .{});
        defer parsed.deinit();
        const rules = try member(parsed.value, "rules");
        if (rules != .array or rules.array.items.len != 1) return error.UnsafeEgressPolicy;
        const rule = rules.array.items[0];
        if (rule != .object or rule.object.count() != 1) return error.UnsafeEgressPolicy;
        const hosts = try member(rule, "hostnames");
        if (hosts != .object or hosts.object.count() != 1) return error.UnsafeEgressPolicy;
        const patterns = try member(hosts, "patterns");
        if (patterns != .array or patterns.array.items.len != 1 or
            !std.mem.eql(u8, try string(patterns.array.items[0]), self.config.authority_host)) return error.UnsafeEgressPolicy;
    }
    pub fn bootstrap(self: Adapter, expected: Actor) !Bootstrap {
        const logs = try self.call(&.{ "logs", "actor", self.config.actor, "-a", self.config.atespace, "-c", self.config.container });
        defer self.allocator.free(logs);
        var lines = std.mem.splitScalar(u8, logs, '\n');
        var found: ?Bootstrap = null;
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var parsed = std.json.parseFromSlice(struct { bootstrap: Bootstrap }, self.allocator, line, .{ .ignore_unknown_fields = true }) catch continue;
            defer parsed.deinit();
            if (found != null) return error.AmbiguousBootstrap;
            found = parsed.value.bootstrap;
        }
        const after = try self.get();
        if (!std.meta.eql(after, expected) or after.state != .running) return error.ProviderChanged;
        return found orelse error.BootstrapUnavailable;
    }

    fn call(self: Adapter, args: []const []const u8) ![]u8 {
        const operation: []const u8 = operation: {
            if (args.len != 0) inline for (.{ "--version", "get", "create", "update", "apply", "suspend", "resume", "revert", "logs" }) |known| {
                if (std.mem.eql(u8, args[0], known)) break :operation known;
            };
            break :operation "other";
        };
        var observation = observations.begin(self.observer, .provider_operation, operation, self.parent_context);
        defer observation.finish();
        return self.callImpl(args) catch |err| {
            observation.fail(err);
            return err;
        };
    }

    fn callImpl(self: Adapter, args: []const []const u8) ![]u8 {
        var argv: [32][]const u8 = undefined;
        const prefix = [_][]const u8{ self.config.cli, "--kubeconfig", self.config.kubeconfig, "--context", self.config.context, "-o", "json" };
        if (prefix.len + args.len > argv.len) return error.TooManyArguments;
        @memcpy(argv[0..prefix.len], &prefix);
        var count = prefix.len;
        if (self.config.endpoint) |endpoint| {
            if (count + 4 + args.len > argv.len) return error.TooManyArguments;
            const direct = [_][]const u8{ "--endpoint", endpoint, "--token-file", self.config.token_file.? };
            @memcpy(argv[count..][0..direct.len], &direct);
            count += direct.len;
        }
        @memcpy(argv[count..][0..args.len], args);
        const timeout: std.Io.Timeout = .{ .duration = .{ .raw = .fromSeconds(30), .clock = .awake } };
        const result = try std.process.run(self.allocator, self.io, .{
            .argv = argv[0 .. count + args.len],
            .stdout_limit = .limited(64 * 1024),
            .stderr_limit = .limited(8 * 1024),
            .timeout = .{ .deadline = timeout.toTimestamp(self.io).? },
        });
        defer self.allocator.free(result.stderr);
        errdefer self.allocator.free(result.stdout);
        // This pinned CLI represents an existing actor with no egress policy as
        // success + empty stdout + this diagnostic (the gateway denies all).
        if (args.len >= 2 and std.mem.eql(u8, args[0], "get") and std.mem.eql(u8, args[1], "egress-policy") and
            result.stdout.len == 0 and std.mem.find(u8, result.stderr, "has no egress policy") != null) return error.ProviderNotFound;
        if (result.term != .exited or result.term.exited != 0) {
            if (std.mem.find(u8, result.stderr, "code = NotFound") != null) return error.ProviderNotFound;
            if (std.mem.find(u8, result.stderr, "code = AlreadyExists") != null) return error.ProviderAlreadyExists;
            return error.ProviderUnavailable;
        }
        return result.stdout;
    }
};
fn member(value: std.json.Value, key: []const u8) !std.json.Value {
    if (value != .object) return error.InvalidProviderResponse;
    return value.object.get(key) orelse error.InvalidProviderResponse;
}
fn string(value: std.json.Value) ![]const u8 {
    if (value != .string) return error.InvalidProviderResponse;
    return value.string;
}
pub fn uuid(value: []const u8) ![16]u8 {
    if (value.len != 36) return error.InvalidProviderIdentity;
    var hex: [32]u8 = undefined;
    var at: usize = 0;
    for (value, 0..) |char, index| {
        if (index == 8 or index == 13 or index == 18 or index == 23) {
            if (char != '-') return error.InvalidProviderIdentity;
        } else {
            hex[at] = char;
            at += 1;
        }
    }
    var bytes: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, &hex) catch return error.InvalidProviderIdentity;
    if (std.mem.allEqual(u8, &bytes, 0)) return error.InvalidProviderIdentity;
    return bytes;
}
fn name(value: []const u8) !void {
    if (value.len == 0 or value.len > 63 or !std.ascii.isAlphanumeric(value[0]) or !std.ascii.isAlphanumeric(value[value.len - 1])) return error.InvalidProviderName;
    for (value) |char| if (!(std.ascii.isDigit(char) or std.ascii.isLower(char) or char == '-')) return error.InvalidProviderName;
}
test "provider identity rejects names, malformed and zero UIDs" {
    const t = std.testing;
    _ = try uuid("11111111-2222-3333-4444-555555555555");
    try t.expectError(error.InvalidProviderIdentity, uuid("11111111x2222-3333-4444-555555555555"));
    try t.expectError(error.InvalidProviderIdentity, uuid("00000000-0000-0000-0000-000000000000"));
    try t.expectError(error.InvalidProviderName, name("--flag"));
    try t.expectError(error.InvalidProviderName, name("A/other"));
}

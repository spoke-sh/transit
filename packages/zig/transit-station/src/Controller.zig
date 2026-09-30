//! Public-client observer/actuator. Dedicated identities keep its trusted clock
//! and lifecycle authority separate from ordinary behavior workers.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const g = p.Growth;
const Supervisor = @import("Supervisor.zig");
const Waiting = @import("Waiting.zig");
const Turn = @import("Turn.zig");
const Controller = @This();
pub const Watch = struct { pid: u64, resource: u64, child: ?u64 = null };
pub const Mode = enum { observe, lifecycle };
client: *wire.Client,
realm: u64,
principal: u64,
key: p.Ed25519.KeyPair,
mode: Mode,
watches: []const Watch,
pending: ?g.SignedRequest = null,
pending_token: ?Token = null,
seen: [128]?Token = @splat(null),
next_seen: usize = 0,
watch_index: usize = 0,
after: ?p.Value = null,
revision: ?u64 = null,
completed_passes: u64 = 0,
const Token = struct { owner: u64, identity: u64, generation: u64, detail: u64, kind: u8 };

fn known(self: *const Controller, token: Token) bool {
    for (self.seen) |slot| if (slot) |old| if (std.meta.eql(old, token)) return true;
    return false;
}
fn prepare(self: *Controller, sequence: u64, command: g.Command, token: Token) !bool {
    self.pending = try g.sign(.{ .realm = self.realm, .principal = self.principal, .sequence = try std.math.add(u64, sequence, 1), .command = command }, self.key);
    self.pending_token = token;
    return true;
}
const View = struct { process: g.Process, principal_sequence: u64, position: u64 };
fn view(self: *Controller, pid: u64) !View {
    const response = try self.client.query(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .process = pid } }, self.key);
    return .{ .process = response.body.process.process, .principal_sequence = response.principal_sequence, .position = response.position };
}
pub fn step(self: *Controller, now_ms: u64) !bool {
    if (self.principal == 0 or self.principal > p.max_counter or self.watches.len == 0 or self.watches.len > 4) return error.InvalidController;
    if (self.pending) |signed| {
        _ = try self.client.submit(signed);
        self.pending = null;
        self.seen[self.next_seen] = self.pending_token;
        self.next_seen = (self.next_seen + 1) % self.seen.len;
        self.pending_token = null;
        return true;
    }
    const watch = self.watches[self.watch_index];
    if (self.revision == null) {
        const metadata = try self.client.query(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .resource = watch.resource } }, self.key);
        if (metadata.body.resource.writer != watch.pid) return error.InvalidWatch;
        self.revision = metadata.body.resource.revision;
    }
    const response = self.client.query(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .entries = .{ .resource = watch.resource, .revision = self.revision, .after = self.after } } }, self.key) catch |err| {
        if (self.client.last_rejection == .StaleStateResource or self.client.last_rejection == .StaleState or self.client.last_rejection == .QueryExpired) {
            self.after = null;
            self.revision = null;
            return false;
        }
        if (self.client.last_rejection == .StateResourceExpired) {
            self.nextWatch();
            return false;
        }
        return err;
    };
    const page = response.body.entries;
    if (page.resource.writer != watch.pid) return error.InvalidWatch;
    for (page.page.entries) |slot| {
        const entry = slot orelse continue;
        if (self.mode == .observe and entry.key.len == 10 and std.mem.eql(u8, entry.key.data[0..2], "\x00w")) {
            const wait = try Turn.Wait.decode(entry.value);
            if (wait.phase != .waiting or wait.observer != self.principal or wait.deadline_ms == null or now_ms < wait.deadline_ms.?) continue;
            const correlation = std.mem.readInt(u64, entry.key.data[2..10], .little);
            const token: Token = .{ .owner = watch.pid, .identity = correlation, .generation = entry.revision, .detail = wait.deadline_ms.?, .kind = 0 };
            if (self.known(token)) continue;
            const current = try self.view(watch.pid);
            if (current.process.lifecycle != .running) continue;
            return self.prepare(current.principal_sequence, .{ .send = .{ .pid = watch.pid, .value = try (try Waiting.observation(correlation, now_ms)).encode() } }, token);
        }
        if (entry.key.len != 11 or !std.mem.eql(u8, entry.key.data[0..2], "\x00c") or entry.key.data[10] != 0) continue;
        const child = try Supervisor.Child.decode(entry.value);
        if (watch.child) |id| if (child.pid != id) continue;
        const current = try self.view(child.pid);
        const process = current.process;
        if (process.pid != child.pid) return error.InvalidAuthorityResponse;
        if (self.mode == .lifecycle) {
            const action = child.action() orelse continue;
            if (process.lifecycle != .running or process.failure == null or process.generation != child.generation or process.failure.? != child.failure) continue;
            if (process.binding) |binding| {
                if (binding.phase == .pending or binding.phase == .unknown or binding.upgrade_from != null) continue;
                if (binding.desired != .stopped) {
                    return self.prepare(current.principal_sequence, .{ .runtime_intent = .{ .pid = child.pid, .expected_revision = binding.revision, .instance = binding.instance, .resource = binding.resource, .workload = binding.workload, .desired = .stopped } }, .{ .owner = watch.pid, .identity = child.pid, .generation = child.generation, .detail = binding.revision, .kind = 254 });
                }
                if (binding.phase != .stopped) continue;
            }
            // Re-observation after controller loss proves an accepted retry
            // by its changed generation; no second administrative retry.
            return self.prepare(current.principal_sequence, action, .{ .owner = watch.pid, .identity = child.pid, .generation = child.generation, .detail = child.failure, .kind = 255 });
        }
        if (child.observer != self.principal or child.phase == .retired) continue;
        var kind: Supervisor.Kind = if (process.lifecycle == .terminated) .terminated else if (process.lifecycle == .expired) .expired else if (process.failure != null) .failed else .activation;
        if (kind == .activation) if (process.control) |control| {
            kind = switch (control.phase) {
                .initializing => .initializing,
                .suspended => .suspended,
                .ready => .activation,
            };
        };
        const failure = process.failure orelse 0;
        const due = child.phase == .retry_wait and now_ms >= child.retry_at_ms;
        if (!due and child.generation == process.generation and child.failure == failure) {
            if ((kind == .activation and child.phase == .watching) or (kind == .failed and (child.phase == .retry_requested or child.phase == .exhausted or child.phase == .retry_wait)) or (kind == .suspended and child.phase == .suspended) or (kind == .initializing and child.phase == .initializing)) continue;
        }
        const token: Token = .{ .owner = watch.pid, .identity = child.pid, .generation = process.generation, .detail = if (due) child.retry_at_ms else failure, .kind = @backingInt(kind) };
        if (self.known(token)) continue;
        const event: Supervisor.Observation = .{ .pid = child.pid, .generation = process.generation, .failure = failure, .cut = current.position, .observed_ms = now_ms, .kind = kind };
        return self.prepare(current.principal_sequence, .{ .send = .{ .pid = watch.pid, .value = try (try event.encode()).encode() } }, token);
    }
    if (page.page.next) |next| {
        self.after = next;
        self.revision = page.resource.revision;
    } else self.nextWatch();
    return false;
}
fn nextWatch(self: *Controller) void {
    self.watch_index = (self.watch_index + 1) % self.watches.len;
    if (self.watch_index == 0) self.completed_passes +%= 1;
    self.after = null;
    self.revision = null;
}

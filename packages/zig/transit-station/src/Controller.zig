//! Public-client observer/actuator. Dedicated identities keep its trusted clock
//! and lifecycle authority separate from ordinary behavior workers.
const std = @import("std");
const wire = @import("transit_client");
const p = wire.protocol;
const Supervisor = @import("Supervisor.zig");
const Waiting = @import("Waiting.zig");
const Turn = @import("Turn.zig");
const Controller = @This();
pub const Watch = struct { pid: u64, resource: u64, child: ?u64 = null };
pub const Mode = enum { observe, lifecycle };
client: *wire.Client,
realm: u64,
principal: u8,
key: p.Ed25519.KeyPair,
mode: Mode,
watches: []const Watch,
pending: ?p.SignedRequest = null,
pending_token: ?Token = null,
seen: [128]?Token = @splat(null),
next_seen: usize = 0,
const Token = struct { owner: u64, identity: u64, generation: u64, detail: u64, kind: u8 };

fn known(self: *const Controller, token: Token) bool {
    for (self.seen) |slot| if (slot) |old| if (std.meta.eql(old, token)) return true;
    return false;
}
fn prepare(self: *Controller, sequence: u64, command: p.Command, token: Token) !bool {
    self.pending = try p.sign(.{ .realm = self.realm, .principal = self.principal, .sequence = try std.math.add(u64, sequence, 1), .command = command }, self.key);
    self.pending_token = token;
    return true;
}
fn view(self: *Controller, pid: u64) !p.View {
    return self.client.view(.{ .realm = self.realm, .principal = self.principal, .sequence = 0, .command = .{ .inspect = pid } }, self.key);
}
pub fn step(self: *Controller, now_ms: u64) !bool {
    if (self.principal == 0 or self.principal >= p.max_principals or self.watches.len == 0 or self.watches.len > 4) return error.InvalidController;
    if (self.pending) |signed| {
        _ = try self.client.submit(signed);
        self.pending = null;
        self.seen[self.next_seen] = self.pending_token;
        self.next_seen = (self.next_seen + 1) % self.seen.len;
        self.pending_token = null;
        return true;
    }
    for (self.watches) |watch| {
        var entries: [p.State.max_entries]?p.State.Entry = @splat(null);
        var page = self.client.state(.{ .realm = self.realm, .principal = self.principal, .kind = .entries, .resource = watch.resource }, self.key) catch |err| {
            if (self.client.last_rejection == .StateResourceExpired) continue;
            return err;
        };
        var len: usize = 0;
        var after: u16 = 0;
        while (true) {
            for (page.entries) |slot| if (slot) |entry| {
                if (len == entries.len) return error.InvalidAuthorityResponse;
                entries[len] = entry;
                len += 1;
            };
            const next = page.next orelse break;
            if (next <= after or next > p.State.max_entries) return error.InvalidAuthorityResponse;
            after = next;
            page = try self.client.state(.{ .realm = self.realm, .principal = self.principal, .kind = .entries, .resource = watch.resource, .after = after, .cut = page.cut }, self.key);
        }
        const resource = page.resources[0] orelse return error.InvalidAuthorityResponse;
        if (resource.writer != watch.pid) return error.InvalidWatch;
        for (entries[0..len]) |slot| {
            const entry = slot.?;
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
                if (process.lifecycle != .running or process.failure == null or process.generation != child.generation or process.failure.?.recorded_at != child.failure) continue;
                if (process.binding) |binding| {
                    if (binding.phase == .pending or binding.phase == .unknown or binding.upgrade_from != null) continue;
                    if (binding.desired != .stopped) {
                        return self.prepare(current.principal_sequence, .{ .runtime_intent = .{ .pid = child.pid, .expected_revision = binding.revision, .instance = binding.instance, .resource = binding.resource, .workload = binding.workload, .desired = .stopped } }, .{ .owner = watch.pid, .identity = child.pid, .generation = child.generation, .detail = binding.revision, .kind = 254 });
                    }
                    if (binding.phase != .stopped) continue;
                }
                // Re-observation after controller loss proves an accepted retry
                // by its changed generation; no second administrative retry.
                return self.prepare(current.principal_sequence, .{ .lifecycle = action }, .{ .owner = watch.pid, .identity = child.pid, .generation = child.generation, .detail = child.failure, .kind = 255 });
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
            const failure = if (process.failure) |f| f.recorded_at else 0;
            const due = child.phase == .retry_wait and now_ms >= child.retry_at_ms;
            if (!due and child.generation == process.generation and child.failure == failure) {
                if ((kind == .activation and child.phase == .watching) or (kind == .failed and (child.phase == .retry_requested or child.phase == .exhausted or child.phase == .retry_wait)) or (kind == .suspended and child.phase == .suspended) or (kind == .initializing and child.phase == .initializing)) continue;
            }
            const token: Token = .{ .owner = watch.pid, .identity = child.pid, .generation = process.generation, .detail = if (due) child.retry_at_ms else failure, .kind = @backingInt(kind) };
            if (self.known(token)) continue;
            const event: Supervisor.Observation = .{ .pid = child.pid, .generation = process.generation, .failure = failure, .cut = current.position, .observed_ms = now_ms, .kind = kind };
            return self.prepare(current.principal_sequence, .{ .send = .{ .pid = watch.pid, .value = try (try event.encode()).encode() } }, token);
        }
    }
    return false;
}

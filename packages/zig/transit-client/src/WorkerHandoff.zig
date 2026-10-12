//! Recorded manual worker replacement under one current native authority.
//! Hosts persist records and exact signed commands; this module owns no I/O.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const g = p.Growth;
pub const Phase = enum { planned, quiesced, checkpointed, fenced, restored, activated, retired };
pub const Plan = struct {
    id: u64,
    realm: u64,
    pid: u64,
    resource: u64,
    worker: u64,
    generation: u64,
    resume_before_ms: u64,
    expected_public_key: [32]u8,
    public_key: [32]u8,
    permissions: u16,
    application: [32]u8,
    old_instance: [32]u8,
    new_instance: [32]u8,
    pub fn validate(self: Plan) !void {
        inline for (.{ "id", "realm", "pid", "resource", "worker" }) |field| {
            if (@field(self, field) == 0 or @field(self, field) > p.max_counter) return error.InvalidWorkerHandoff;
        }
        if (self.generation == 0 or self.generation > std.math.maxInt(u64) - 3 or self.resume_before_ms == 0) return error.InvalidWorkerHandoff;
        if (self.permissions & (p.permission(.inspect) | p.permission(.execute)) != (p.permission(.inspect) | p.permission(.execute))) return error.InvalidWorkerHandoff;
        if (self.permissions & ~p.all_permissions != 0) return error.InvalidWorkerHandoff;
        if (std.mem.eql(u8, &self.expected_public_key, &self.public_key) or std.mem.eql(u8, &self.old_instance, &self.new_instance)) return error.InvalidWorkerHandoff;
    }
};
pub const State = struct {
    resource: u64,
    writer: u64,
    revision: u64,
    entries: u64,
    bytes: u64,
    digest: [32]u8,
};
pub const Checkpoint = struct {
    state: State,
    revision: u64,
    consumed: u64,
    cancelled: u64,
    admitted: u64,
    fn matches(self: Checkpoint, process: g.Process) !void {
        // Inputs and output acknowledgements can arrive while execution is
        // quiesced. They remain in native history; restoration never rolls them
        // back to the checkpoint's earlier mailbox/outbox observation.
        if (process.revision != self.revision or process.consumed != self.consumed or process.cancelled != self.cancelled or process.admitted < self.admitted) return error.WorkerHandoffConflict;
    }
};
pub const Record = struct {
    definition: g.Definition,
    plan: Plan,
    phase: Phase,
    checkpoint: ?Checkpoint,
    retired_instance: ?[32]u8,
    pub const max_bytes = 8192;
    pub fn start(plan: Plan) !Record {
        try plan.validate();
        return .{ .definition = g.current_definition, .plan = plan, .phase = .planned, .checkpoint = null, .retired_instance = null };
    }
    pub fn validate(self: Record) !void {
        if (self.definition != g.current_definition) return error.IncompatibleDefinition;
        try self.plan.validate();
        if ((self.checkpoint != null) != (@backingInt(self.phase) >= @backingInt(Phase.checkpointed))) return error.InvalidWorkerHandoff;
        if (self.checkpoint) |checkpoint| {
            if (checkpoint.state.resource != self.plan.resource or checkpoint.state.writer != self.plan.pid or checkpoint.consumed > checkpoint.admitted or checkpoint.cancelled > checkpoint.admitted - checkpoint.consumed) return error.InvalidWorkerCheckpoint;
        }
        if ((self.phase == .retired) != (self.retired_instance != null)) return error.InvalidWorkerHandoff;
        if (self.retired_instance) |instance| if (!std.mem.eql(u8, &instance, &self.plan.old_instance)) return error.InvalidWorkerHandoff;
    }
    pub fn save(self: Record, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const bytes = try std.json.Stringify.valueAlloc(allocator, self, .{});
        errdefer allocator.free(bytes);
        if (bytes.len > max_bytes) return error.InvalidWorkerHandoff;
        return bytes;
    }
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Record {
        if (bytes.len > max_bytes) return error.InvalidWorkerHandoff;
        const parsed = try std.json.parseFromSlice(Record, allocator, bytes, .{});
        defer parsed.deinit();
        const canonical = try parsed.value.save(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidWorkerHandoff;
        return parsed.value;
    }
    fn expect(self: Record, phase: Phase) !void {
        try self.validate();
        if (self.phase != phase) return error.InvalidWorkerHandoff;
    }
    fn stopped(self: Record, process: g.Process, delta: u64) !void {
        if (process.pid != self.plan.pid or process.owner != null or process.generation != self.plan.generation + delta or process.lifecycle != .running or process.failure != null or process.turn_permit != null or process.binding != null) return error.WorkerHandoffConflict;
        if (self.checkpoint) |checkpoint| try checkpoint.matches(process);
    }
    /// Save/sign the returned command as an exact pending native operation
    /// before dispatch. No observation failure authorizes a new sequence.
    pub fn command(self: Record) !g.Command {
        try self.validate();
        return switch (self.phase) {
            .planned => .{ .@"suspend" = .{ .pid = self.plan.pid, .expected_generation = self.plan.generation, .resume_before_ms = self.plan.resume_before_ms } },
            .checkpointed => .{ .@"resume" = .{ .pid = self.plan.pid, .expected_generation = self.plan.generation + 1 } },
            .restored => .{ .rotate_worker = .{ .pid = self.plan.pid, .worker = self.plan.worker, .expected_generation = self.plan.generation + 2, .expected_public_key = self.plan.expected_public_key, .expected_permissions = self.plan.permissions, .public_key = self.plan.public_key } },
            else => error.InvalidWorkerHandoff,
        };
    }
    pub fn quiesce(self: Record, process: g.Process) !Record {
        try self.expect(.planned);
        try self.stopped(process, 1);
        const control = process.control orelse return error.WorkerHandoffConflict;
        if (control.phase != .suspended or control.resume_before_ms != self.plan.resume_before_ms) return error.WorkerHandoffConflict;
        var next = self;
        next.phase = .quiesced;
        return next;
    }
    pub fn capture(self: Record, process: g.Process, state: State) !Record {
        try self.expect(.quiesced);
        try self.stopped(process, 1);
        const control = process.control orelse return error.WorkerHandoffConflict;
        if (control.phase != .suspended or control.resume_before_ms != self.plan.resume_before_ms or state.resource != self.plan.resource or state.writer != self.plan.pid) return error.WorkerHandoffConflict;
        var next = self;
        next.checkpoint = .{ .state = state, .revision = process.revision, .consumed = process.consumed, .cancelled = process.cancelled, .admitted = process.admitted };
        next.phase = .checkpointed;
        try next.validate();
        return next;
    }
    pub fn fence(self: Record, process: g.Process) !Record {
        try self.expect(.checkpointed);
        try self.stopped(process, 2);
        if (!g.processReady(process)) return error.WorkerHandoffConflict;
        var next = self;
        next.phase = .fenced;
        return next;
    }
    /// The host additionally validates the application binding and every current
    /// dependency under the replacement worker's grants before this transition.
    pub fn restored(self: Record, process: g.Process, state: State, application: [32]u8) !Record {
        try self.expect(.fenced);
        try self.stopped(process, 2);
        if (!g.processReady(process) or !std.meta.eql(self.checkpoint.?.state, state) or !std.mem.eql(u8, &self.plan.application, &application)) return error.InvalidWorkerCheckpoint;
        var next = self;
        next.phase = .restored;
        return next;
    }
    pub fn activate(self: Record, process: g.Process, grant: g.Grant) !Record {
        try self.expect(.restored);
        if (!g.processReady(process) or process.pid != self.plan.pid or process.owner != self.plan.worker or process.generation != self.plan.generation + 3 or process.turn_permit != null or process.binding != null) return error.WorkerHandoffConflict;
        try self.checkpoint.?.matches(process);
        if (grant.subject != self.plan.worker or grant.pid != self.plan.pid or grant.permissions != self.plan.permissions or !std.mem.eql(u8, &grant.public_key, &self.plan.public_key)) return error.WorkerHandoffConflict;
        var next = self;
        next.phase = .activated;
        return next;
    }
    /// Provider shutdown evidence belongs to the host. The exact old instance is
    /// recorded only after activation has irreversibly fenced its credential.
    pub fn retire(self: Record, instance: [32]u8) !Record {
        try self.expect(.activated);
        if (!std.mem.eql(u8, &instance, &self.plan.old_instance)) return error.WorkerHandoffConflict;
        var next = self;
        next.phase = .retired;
        next.retired_instance = instance;
        return next;
    }
};
/// Constant-resident checkpoint of all ordered entries at one exact native
/// resource revision. A lost scan restarts; no partial digest is a checkpoint.
pub fn snapshot(source: anytype, resource: g.Resource, pages: u64) !State {
    if (resource.phase != .active or source.view.resource != resource.id or source.view.revision != resource.revision or pages == 0) return error.InvalidWorkerCheckpoint;
    var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
    hash.update("transit.worker-handoff.state.v1\x00");
    hash.update(@tagName(g.current_definition));
    var scalar: [8]u8 = undefined;
    for ([_]u64{ resource.id, resource.writer, resource.revision, resource.entries }) |value| {
        std.mem.writeInt(u64, &scalar, value, .little);
        hash.update(&scalar);
    }
    var count: u64 = 0;
    var size: u64 = 0;
    var after: ?p.Value = null;
    var read: u64 = 0;
    while (true) {
        if (read == pages) return error.RequestBudgetExceeded;
        read += 1;
        const page = try source.page(after);
        var last = after;
        for (page.entries) |slot| if (slot) |entry| {
            try entry.key.validate();
            try entry.value.validate();
            if (last) |key| if (std.mem.order(u8, key.slice(), entry.key.slice()) != .lt) return error.InvalidWorkerCheckpoint;
            if (entry.revision > resource.revision) return error.InvalidWorkerCheckpoint;
            for ([_]u64{ entry.revision, entry.key.len, entry.value.len }) |value| {
                std.mem.writeInt(u64, &scalar, value, .little);
                hash.update(&scalar);
            }
            hash.update(entry.key.slice());
            hash.update(entry.value.slice());
            count = try std.math.add(u64, count, 1);
            size = try std.math.add(u64, size, @as(u64, entry.key.len) + entry.value.len);
            if (count > resource.entries) return error.InvalidWorkerCheckpoint;
            last = entry.key;
        };
        const next = page.next orelse break;
        if (last == null or !next.eql(last.?)) return error.InvalidWorkerCheckpoint;
        if (after) |previous| if (std.mem.order(u8, previous.slice(), next.slice()) != .lt) return error.InvalidWorkerCheckpoint;
        after = next;
    }
    if (count != resource.entries) return error.InvalidWorkerCheckpoint;
    return .{ .resource = resource.id, .writer = resource.writer, .revision = resource.revision, .entries = count, .bytes = size, .digest = hash.finalResult() };
}

test {
    _ = @import("worker_handoff_test.zig");
}

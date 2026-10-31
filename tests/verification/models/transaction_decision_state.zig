//! Replay TransactionDecision.tla counterexample traces against the production
//! TransactionDecisionLog and TransactionDirectory storage components.
const std = @import("std");
const s = @import("transit_storage");
const p = @import("transit_protocol");
const x = p.Transaction;
const D = s.TransactionDirectory;
const J = s.TransactionDecisionLog;

const Event = enum {
    Init,
    Freeze,
    Prepare,
    Commit,
    Abort,
    Observe,
    LoseReply,
    Recover,
    Fence,
    Policy,
    Availability,
    Conflict,
};

const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
const identity: x.Identity = .{ .begin = .{ .scope = scope, .principal = 0, .operation = 100 }, .branch = 1 };
const content: p.DataLifecycle.Content = .{ .bytes = 100, .sha256 = @splat(5) };

fn participant(object: u64) D.Entry {
    return .{ .participant = .{ .state = .{
        .kind = .table,
        .guard = .{ .source = .{
            .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = object }, .revision = 1, .digest = @splat(1) },
            .accepted = .{ .partition = object + 10, .next_lsn = 5 },
        }, .changed_lsn = 3 },
        .access = .write,
    } } };
}

fn beginRecord(directory: x.Directory) x.Begin {
    return .{
        .definition = p.Growth.current_definition,
        .identity = identity,
        .mode = .serializable,
        .selection = .explicit_objects,
        .objects = directory,
        .catalog = .{ .partition = 1, .next_lsn = 1 },
        .limits = .{ .resident_bytes = 65536, .workspace_bytes = 1048576, .participants = 1000, .statements = 1000, .savepoints = 32 },
    };
}

fn attemptRecord(directory: x.Directory) x.Attempt {
    return .{
        .definition = p.Growth.current_definition,
        .transaction = identity,
        .operation = .{ .scope = scope, .principal = 0, .operation = 101 },
        .cut = content,
        .workspace = content,
        .participants = directory,
        .writes = directory.count,
        .last_statement = 1,
    };
}

fn preparation(object: u64, frozen: x.Attempt) D.Entry {
    const state = participant(object).participant.state;
    return .{ .prepared = .{
        .attempt = frozen,
        .target = participant(object).target(),
        .predecessor = participant(object).participant.guard(),
        .position = .{ .partition = state.guard.source.accepted.partition, .next_lsn = 6 },
        .successor = content,
    } };
}

fn buildBinding(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore) !J.Binding {
    var selected = try D.init(allocator, objects, identity, .participants, 1000, 1, 1024 * 1024);
    defer selected.deinit();
    for (1..3) |object| try selected.put(participant(object));
    const root = try selected.seal();
    return .{ .begin = beginRecord(root), .attempt = attemptRecord(root) };
}

fn buildPreparations(allocator: std.mem.Allocator, objects: s.TransitObjectStore.ObjectStore, frozen: J.Binding, count: usize) !x.Directory {
    var directory = try D.init(allocator, objects, identity, .preparations, 1000, 1, 1024 * 1024);
    defer directory.deinit();
    for (1..count + 1) |object| try directory.put(preparation(object, frozen.attempt));
    return directory.seal();
}

const Access = struct {
    allowed: bool = true,
    owner_epoch: u64 = 1,
    policy_epoch: u64 = 1,
    available: bool = true,
    conflict: bool = false,

    fn acquire(raw: *anyopaque) !J.Guard.Fence {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.allowed) return error.AccessDenied;
        return .{ .writer_epoch = self.owner_epoch, .policy_epoch = self.policy_epoch };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *@This()) J.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
    fn checkParticipant(raw: *anyopaque, _: x.Participant) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.conflict) return error.TransactionConflict;
    }
    fn checkPrepared(raw: *anyopaque, _: x.Prepared) !void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (!self.available) return error.ParticipantUnavailable;
    }
    fn verification(self: *@This()) J.Verification {
        return .{ .context = self, .participant = checkParticipant, .prepared = checkPrepared };
    }
};

fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.TransactionNotFrozen,
        error.InvalidTransactionDecision,
        error.StaleWriterEpoch,
        error.AccessDenied,
        error.ParticipantUnavailable,
        error.TransactionConflict,
        error.LostAcknowledgement,
        error.TransactionRecoveryRequired,
        => @errorName(err),
        else => return err,
    };
}

fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    const frozen = try buildBinding(allocator, objects.objectStore());
    var owner = try J.init(allocator, wal.log(), objects.objectStore(), 4, frozen);
    try owner.recover();

    var access: Access = .{};
    var wal_epoch: u64 = 1;
    var prepared_count: usize = 0;
    var knowledge: []const u8 = "unknown";
    var last_error: []const u8 = "none";
    var first_decision: ?@FieldType(x.Decision, "outcome") = null;

    for (events) |event| {
        last_error = "none";
        switch (event) {
            .Init => {},
            .Freeze => {
                owner.freeze(access.guard()) catch |err| {
                    last_error = try expectedError(err);
                };
            },
            .Prepare => {
                if (prepared_count < 2) prepared_count += 1;
            },
            .Commit => {
                const dir = try buildPreparations(allocator, objects.objectStore(), frozen, prepared_count);
                if (owner.commit(dir, access.verification(), access.guard())) |decided| {
                    if (first_decision) |orig| {
                        if (orig != decided.outcome) return error.DecisionOverwritten;
                    } else first_decision = decided.outcome;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .Abort => {
                if (owner.abort(access.guard())) |decided| {
                    if (first_decision) |orig| {
                        if (orig != decided.outcome) return error.DecisionOverwritten;
                    } else first_decision = decided.outcome;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .Observe => {
                if (owner.observe(access.guard())) |obs| {
                    knowledge = switch (obs) {
                        .unavailable => "unavailable",
                        .denied => "denied",
                        .not_observed => "unknown",
                        .preparing => "preparing",
                        .decided => |d| @tagName(d.outcome),
                    };
                } else |err| {
                    last_error = try expectedError(err);
                    if (err == error.AccessDenied) knowledge = "denied";
                }
            },
            .LoseReply => {
                knowledge = "unknown";
            },
            .Recover => {
                access.owner_epoch = wal_epoch;
                knowledge = "unknown";
                try owner.recover();
            },
            .Fence => {
                wal_epoch = 2;
                try wal.fenceEpochs(4, wal_epoch, 1);
            },
            .Policy => {
                access.allowed = !access.allowed;
            },
            .Availability => {
                access.available = !access.available;
            },
            .Conflict => {
                access.conflict = !access.conflict;
            },
        }
        if (owner.recovery_required) try owner.recover();
    }

    var auditor: Access = .{ .owner_epoch = wal_epoch };
    const durable = try owner.observe(auditor.guard());
    const decision_name: []const u8 = switch (durable) {
        .unavailable => "unavailable",
        .denied => "denied",
        .not_observed => "none",
        .preparing => "preparing",
        .decided => |d| @tagName(d.outcome),
    };
    const tail = try wal.log().tail(4);
    try std.json.Stringify.value(.{
        .decision = decision_name,
        .knowledge = knowledge,
        .last_error = last_error,
        .tail = tail,
    }, .{}, out);
    try out.writeByte('\n');
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedTracePath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(bytes);
    var traces = try std.json.parseFromSlice([]const []const Event, init.gpa, bytes, .{});
    defer traces.deinit();
    if (traces.value.len > 128) return error.TooManyTraces;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (traces.value) |events| {
        if (events.len > 128) return error.TraceTooLong;
        try replay(init.gpa, events, &output.interface);
    }
    try output.interface.flush();
}

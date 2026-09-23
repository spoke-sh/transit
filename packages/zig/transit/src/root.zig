//! Protocol profile v1. No transport, OS clock, scheduling, or application I/O.
const std = @import("std");
pub const Ed25519 = std.crypto.sign.Ed25519;
pub const max_principals = 16;
pub const max_processes = 64;
pub const max_counter = (1 << 53) - 1;
pub const Permission = enum(u4) { admin, spawn, send, execute, inspect, effect };
pub const all_permissions: u16 = 0x3f;
pub fn permission(p: Permission) u16 {
    return @as(u16, 1) << @backingInt(p);
}

pub const Grant = struct {
    subject: u8,
    public_key: [32]u8,
    permissions: u16,
    pid: ?u64 = null,
};
pub const Principal = struct {
    grant: Grant,
    revision: u64,
    sequence: u64 = 0,
    digest: [32]u8 = @splat(0),
    receipt: u64 = 0,
};
pub const Pid = struct { realm: u64, local: u64 };
pub const Process = struct {
    pid: u64,
    code: u32,
    owner: ?u8 = null,
    generation: u64 = 0,
    lifecycle: enum { running, terminated, expired } = .running,
    state: i64 = 0,
    admitted: u64 = 0,
    consumed: u64 = 0,
    // Journal position of the last consumed input; backlog stays in storage.
    input_cursor: u64 = 0,
};
pub const Command = union(enum) {
    grant: Grant,
    revoke: u8,
    spawn: struct { code: u32 = 1, deadline_ms: ?u64 = null },
    own: struct { pid: u64, expected_generation: u64, worker: u8 },
    send: struct { pid: u64, value: i64 },
    turn: struct { pid: u64, generation: u64, input: u64, result: i64 },
    terminate: u64,
    inspect: u64,
};
pub const Request = struct {
    version: u32 = 1,
    realm: u64,
    principal: u8,
    sequence: u64,
    command: Command,
};
pub const SignedRequest = struct { request: Request, signature: [64]u8 };
pub const Record = struct {
    version: u32 = 1,
    position: u64,
    policy_revision: u64,
    request: Request,
};
pub const RetryPolicy = enum { unlimited, last_per_principal };
pub const Genesis = struct {
    version: u32 = 1,
    realm: u64,
    root_key: [32]u8,
    retry_policy: RetryPolicy = .unlimited,
};
pub const Entry = union(enum) { genesis: Genesis, operation: Record };

/// The v1 experiment uses scalar state/input and one compiled workload version.
/// The executable supplies the reviewed reducer; Transit owns its sequencing.
pub const Reducer = *const fn (i64, i64) anyerror!i64;

pub fn digest(request: Request) [32]u8 {
    // The typed encoder is the canonical wire representation: fixed fields/order,
    // integer values, no user-controlled object ordering or float normalization.
    var output: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&output);
    std.json.Stringify.value(request, .{}, &writer) catch unreachable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("rey.transit.request.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}

pub fn sign(request: Request, key: Ed25519.KeyPair) !SignedRequest {
    return .{ .request = request, .signature = (try key.sign(&digest(request), null)).toBytes() };
}

pub const State = struct {
    realm: u64,
    retry_policy: RetryPolicy,
    position: u64 = 1,
    principals: [max_principals]?Principal = @splat(null),
    processes: [max_processes]?Process = @splat(null),

    pub fn init(genesis: Genesis) !State {
        if (genesis.version != 1 or genesis.realm == 0 or genesis.realm > max_counter) return error.InvalidGenesis;
        _ = try Ed25519.PublicKey.fromBytes(genesis.root_key);
        var state: State = .{ .realm = genesis.realm, .retry_policy = genesis.retry_policy };
        state.principals[0] = .{ .grant = .{ .subject = 0, .public_key = genesis.root_key, .permissions = all_permissions }, .revision = 0 };
        return state;
    }

    pub fn principal(self: *const State, id: u8) !Principal {
        if (id >= max_principals) return error.Unauthorized;
        return self.principals[id] orelse error.Unauthorized;
    }

    pub fn process(self: *State, pid: u64) !*Process {
        for (&self.processes) |*slot| if (slot.*) |*p| {
            if (p.pid == pid) return p;
        };
        return error.UnknownProcess;
    }

    pub fn authenticate(self: *const State, signed: SignedRequest) !void {
        const request = signed.request;
        if (request.version != 1 or request.realm != self.realm) return error.WrongProtocolRealm;
        const p = try self.principal(request.principal);
        const public = try Ed25519.PublicKey.fromBytes(p.grant.public_key);
        try Ed25519.Signature.fromBytes(signed.signature).verify(&digest(request), public);
    }

    pub fn authorize(self: *const State, request: Request) !void {
        if (request.version != 1 or request.realm != self.realm) return error.WrongProtocolRealm;
        const p = try self.principal(request.principal);
        const required: Permission = switch (request.command) {
            .grant, .revoke, .own, .terminate => .admin,
            .spawn => .spawn,
            .send => .send,
            .turn => .execute,
            .inspect => .inspect,
        };
        if (p.grant.permissions & permission(required) == 0) return error.Forbidden;
        const pid: ?u64 = switch (request.command) {
            .own => |c| c.pid,
            .send => |c| c.pid,
            .turn => |c| c.pid,
            .terminate, .inspect => |id| id,
            else => null,
        };
        if (p.grant.pid) |scope| if (pid != scope) return error.Forbidden;
    }

    /// Current permission is checked even when disclosing an existing receipt.
    pub fn duplicate(self: *const State, request: Request) !?u64 {
        try self.authorize(request);
        const p = try self.principal(request.principal);
        if (request.sequence == 0 or request.sequence > max_counter) return error.InvalidSequence;
        if (request.sequence < p.sequence) return if (self.retry_policy == .unlimited) error.HistoricalReceiptRequired else error.RetryHorizonExceeded;
        if (request.sequence == p.sequence) {
            if (!std.mem.eql(u8, &p.digest, &digest(request))) return error.ConflictingRetry;
            return p.receipt;
        }
        if (request.sequence != p.sequence + 1) return error.SequenceGap;
        return null;
    }

    /// Validate a transition on a copy. The caller publishes it only after CAS.
    /// `input` must be fetched from the journal by the trusted engine, never from
    /// a worker-supplied envelope. State alone does not hold the mailbox backlog.
    pub fn apply(self: *State, record: Record, input: ?Record, reducer: Reducer) !void {
        if (record.version != 1 or record.position != self.position or self.position >= max_counter) return error.InvalidPosition;
        const req = record.request;
        if (try self.duplicate(req) != null) return error.DuplicateRecord;
        if ((try self.principal(req.principal)).revision != record.policy_revision) return error.StalePolicy;
        switch (req.command) {
            .grant => |g| {
                if (req.principal != 0) return error.Forbidden;
                if (g.subject == 0 or g.subject >= max_principals or g.permissions & ~all_permissions != 0) return error.InvalidGrant;
                _ = try Ed25519.PublicKey.fromBytes(g.public_key);
                var p = self.principals[g.subject] orelse Principal{ .grant = g, .revision = record.position };
                p.grant = g;
                p.revision = record.position;
                self.principals[g.subject] = p;
            },
            .revoke => |subject| {
                if (req.principal != 0) return error.Forbidden;
                if (subject == 0 or subject >= max_principals) return error.InvalidGrant;
                if (self.principals[subject]) |*p| {
                    p.grant.permissions = 0;
                    p.revision = record.position;
                } else return error.UnknownPrincipal;
            },
            .spawn => |c| {
                if (c.code != 1) return error.UnsupportedWorkload;
                // A sampled client clock cannot fence a delayed storage commit.
                // Reject finite wall-time contracts until that gate is proved.
                if (c.deadline_ms != null) return error.UnsupportedDeadline;
                const free = for (&self.processes) |*slot| {
                    if (slot.* == null) break slot;
                } else return error.ProcessCapacity;
                free.* = .{ .pid = record.position, .code = c.code };
            },
            .own => |c| {
                const p = try self.process(c.pid);
                try running(p);
                if (c.expected_generation != p.generation) return error.StaleGeneration;
                const worker = try self.principal(c.worker);
                if (worker.grant.permissions & permission(.execute) == 0) return error.Forbidden;
                if (worker.grant.pid) |scope| if (scope != c.pid) return error.Forbidden;
                p.generation = try std.math.add(u64, p.generation, 1);
                p.owner = c.worker;
            },
            .send => |c| {
                const p = try self.process(c.pid);
                try running(p);
                p.admitted = try std.math.add(u64, p.admitted, 1);
            },
            .turn => |c| {
                const p = try self.process(c.pid);
                try running(p);
                if (c.generation != p.generation or p.owner != req.principal) return error.StaleGeneration;
                const message = input orelse return error.MissingInput;
                if (message.request.command != .send or message.request.command.send.pid != c.pid or
                    c.input != message.position or c.input <= p.input_cursor or c.input >= record.position or p.consumed >= p.admitted) return error.InvalidInput;
                if (c.result != try reducer(p.state, message.request.command.send.value)) return error.InvalidResult;
                p.state = c.result;
                p.consumed += 1;
                p.input_cursor = c.input;
            },
            .terminate => |pid| {
                const p = try self.process(pid);
                try running(p);
                p.lifecycle = .terminated;
                p.owner = null;
            },
            .inspect => |pid| {
                _ = try self.process(pid);
            },
        }
        const caller = &self.principals[req.principal].?;
        caller.sequence = req.sequence;
        caller.digest = digest(req);
        caller.receipt = record.position;
        self.position += 1;
    }
};

fn running(p: *const Process) !void {
    if (p.lifecycle != .running) return error.RetiredProcess;
}

/// Store contract: immutable positions, authoritative tail, conditional append.
/// Read buffers and the state have fixed limits independent of mailbox backlog.
pub fn Engine(comptime Store: type, comptime reducer: Reducer) type {
    return struct {
        const Self = @This();
        store: *Store,
        state: State,

        pub fn open(store: *Store, genesis: Genesis) !Self {
            const first = (try store.read(0)) orelse return error.MissingGenesis;
            if (first != .genesis or !std.meta.eql(first.genesis, genesis)) return error.GenesisMismatch;
            var self: Self = .{ .store = store, .state = try State.init(genesis) };
            try self.refresh();
            return self;
        }

        pub fn bootstrap(store: *Store, genesis: Genesis) !Self {
            _ = try State.init(genesis);
            _ = try store.append(0, .{ .genesis = genesis });
            return open(store, genesis);
        }

        pub fn nextInput(self: *Self, pid: u64, limit: u64) !?Record {
            const p = try self.state.process(pid);
            if (p.admitted == p.consumed) return null;
            var at = p.input_cursor + 1;
            while (at < limit) : (at += 1) {
                const entry = (try self.store.read(at)) orelse return error.IncompleteHistory;
                if (entry == .operation and entry.operation.request.command == .send and entry.operation.request.command.send.pid == pid) return entry.operation;
            }
            return error.MissingInput;
        }

        pub fn refresh(self: *Self) !void {
            const target = try self.store.tail();
            if (target < self.state.position) return error.HistoryRollback;
            while (self.state.position < target) {
                const entry = (try self.store.read(self.state.position)) orelse return error.IncompleteHistory;
                if (entry != .operation) return error.InvalidHistory;
                const r = entry.operation;
                const input = if (r.request.command == .turn) try self.nextInput(r.request.command.turn.pid, r.position) else null;
                var next = self.state;
                try next.apply(r, input, reducer);
                self.state = next;
            }
        }

        pub const Prepared = struct { record: Record, next: State };

        pub fn prepare(self: *Self, signed: SignedRequest) !Prepared {
            try self.refresh();
            try self.state.authenticate(signed);
            const req = signed.request;
            if (try self.state.duplicate(req) != null) return error.AlreadyCommitted;
            const r: Record = .{ .position = self.state.position, .policy_revision = (try self.state.principal(req.principal)).revision, .request = req };
            const input = if (req.command == .turn) try self.nextInput(req.command.turn.pid, r.position) else null;
            var next = self.state;
            try next.apply(r, input, reducer);
            return .{ .record = r, .next = next };
        }

        pub fn commit(self: *Self, prepared: Prepared) !u64 {
            if (!try self.store.append(prepared.record.position, .{ .operation = prepared.record })) return error.Conflict;
            self.state = prepared.next;
            return prepared.record.position;
        }

        pub fn submit(self: *Self, signed: SignedRequest) !u64 {
            try self.refresh();
            try self.state.authenticate(signed);
            const receipt = self.state.duplicate(signed.request) catch |err| switch (err) {
                error.HistoricalReceiptRequired => {
                    var at: u64 = 1;
                    while (at < self.state.position) : (at += 1) {
                        const old = (try self.store.read(at)) orelse return error.IncompleteHistory;
                        if (old != .operation) return error.InvalidHistory;
                        const request = old.operation.request;
                        if (request.principal == signed.request.principal and request.sequence == signed.request.sequence) {
                            if (!std.mem.eql(u8, &digest(request), &digest(signed.request))) return error.ConflictingRetry;
                            return at;
                        }
                    }
                    return error.MissingReceipt;
                },
                else => return err,
            };
            if (receipt) |position| return position;
            return self.commit(try self.prepare(signed));
        }
    };
}

test {
    _ = @import("tests.zig");
}

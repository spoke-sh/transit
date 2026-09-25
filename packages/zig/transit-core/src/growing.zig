//! M10 authority integration in development. Published roots, not resident
//! catalogs, hold protocol state. This module is not yet served by transit-node.
const std = @import("std");
const core = @import("root.zig");
const catalog = @import("catalog.zig");
const pages = @import("pages.zig");
const p = core.protocol;
const g = p.Growth;
pub const Genesis = struct { version: u32 = g.version, realm: u64, root_key: [32]u8, max_clock_error_ms: ?u32 = null };
pub const Head = struct {
    version: u32 = g.version,
    position: u64,
    genesis: [32]u8,
    catalog: catalog.Snapshot,
    time_floor_ms: u64 = 0,
    outputs: u64 = 0,
};
pub const Record = struct { position: u64, previous: ?pages.Reference, next: Head, request: g.Request, time: ?core.Time.Sample };
pub const Entry = union(enum) { genesis: struct { genesis: Genesis, head: Head }, operation: Record };
pub const Principal = struct { grant: g.Grant, revision: u64, epoch: u64, sequence: u64 = 0 };
pub const Receipt = struct { position: u64, digest: [32]u8 };
pub const StoredView = struct { meta: g.View, snapshot: catalog.Snapshot };
pub const ResourceGrant = struct { principal_epoch: u64, permissions: u8 };

fn genesisHash(genesis: Genesis) ![32]u8 {
    if (genesis.version != g.version or genesis.realm == 0 or genesis.realm > p.max_counter) return error.InvalidGenesis;
    _ = try p.Ed25519.PublicKey.fromBytes(genesis.root_key);
    var bytes: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(genesis, .{}, &writer);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.genesis.v3\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
fn address(namespace: catalog.Namespace, id: u64) pages.Key {
    return catalog.key(namespace, id, 0, "") catch unreachable;
}

/// Journal owns conditional append and record coordinates. PageStore owns
/// immutable data/cache lifetime. Both are privileged capabilities, never given
/// to handlers. Prepare stages; commit alone publishes the candidate head.
pub fn Engine(comptime Journal: type, comptime PageStore: type) type {
    return struct {
        const Self = @This();
        const Catalog = catalog.Catalog(PageStore);
        journal: *Journal,
        page_store: *PageStore,
        genesis: Genesis,
        head: Head,
        clock: ?core.Time.Source = null,

        pub fn bootstrap(journal: *Journal, page_store: *PageStore, genesis: Genesis) !Self {
            const fingerprint = try genesisHash(genesis);
            if (try journal.tail() == 0) {
                var candidate = try Catalog.open(page_store, .{});
                try candidate.put(address(.principal, 0), Principal{ .grant = .{ .subject = 0, .public_key = genesis.root_key, .permissions = p.all_permissions }, .revision = 0, .epoch = 0 });
                const head: Head = .{ .position = 1, .genesis = fingerprint, .catalog = candidate.snapshot };
                _ = try journal.append(0, .{ .genesis = .{ .genesis = genesis, .head = head } });
            }
            return open(journal, page_store, genesis);
        }
        pub fn open(journal: *Journal, page_store: *PageStore, genesis: Genesis) !Self {
            var self: Self = .{ .journal = journal, .page_store = page_store, .genesis = genesis, .head = .{ .position = 0, .genesis = try genesisHash(genesis), .catalog = .{} } };
            try self.refresh();
            const root = try self.principal(0);
            if (!std.mem.eql(u8, &root.grant.public_key, &genesis.root_key)) return error.GenesisMismatch;
            return self;
        }
        pub fn refresh(self: *Self) !void {
            const tail = try self.journal.tail();
            if (tail == 0 or tail < self.head.position) return error.InvalidHistory;
            if (tail == self.head.position) return;
            const entry = (try self.journal.read(tail - 1)) orelse return error.IncompleteHistory;
            const next: Head = switch (entry) {
                .genesis => |value| blk: {
                    if (tail != 1 or !std.mem.eql(u8, &try genesisHash(value.genesis), &self.head.genesis)) return error.GenesisMismatch;
                    break :blk value.head;
                },
                .operation => |record| blk: {
                    if (record.position != tail - 1) return error.InvalidPosition;
                    if (record.request.version != g.version or record.request.realm != self.genesis.realm) return error.WrongProtocolRealm;
                    if (record.previous == null) return error.InvalidHistory;
                    if (self.head.position == record.position and !std.meta.eql(self.head.catalog.root, record.previous)) return error.InvalidHistory;
                    break :blk record.next;
                },
            };
            if (next.version != g.version or next.position != tail or next.position > p.max_counter) return error.InvalidPosition;
            if (!std.mem.eql(u8, &next.genesis, &self.head.genesis)) return error.GenesisMismatch;
            try next.catalog.validate();
            if (next.catalog.records == 0) return error.InvalidHistory;
            // A persisted root must include its own publication's sequence and
            // receipt. Detect a wrong/partial root rather than trust a position
            // field that merely claims the proposal became visible.
            if (entry == .operation) {
                const record = entry.operation;
                var proposed = try Catalog.open(self.page_store, next.catalog);
                const caller = (try proposed.get(Principal, address(.principal, record.request.principal))) orelse return error.InvalidHistory;
                const receipt = (try proposed.get(Receipt, try catalog.key(.receipt, record.request.principal, record.request.sequence, ""))) orelse return error.MissingReceipt;
                if (caller.sequence != record.request.sequence or receipt.position != record.position or !std.mem.eql(u8, &receipt.digest, &try g.digest(record.request))) return error.InvalidHistory;
            }
            // The trusted journal's published head is the materialization root.
            // Recovery reads pages on demand; it never stages or runs handlers.
            self.head = next;
        }
        pub fn state(self: *Self) !Catalog {
            return Catalog.open(self.page_store, self.head.catalog);
        }
        pub fn principal(self: *Self, id: u64) !Principal {
            var current = try self.state();
            return (try current.get(Principal, address(.principal, id))) orelse error.Unauthorized;
        }
        pub fn process(self: *Self, pid: u64) !g.Process {
            var current = try self.state();
            return (try current.get(g.Process, address(.process, pid))) orelse error.UnknownProcess;
        }
        fn authenticate(self: *Self, signed: g.SignedRequest) !Principal {
            try g.validate(signed.request);
            if (signed.request.realm != self.genesis.realm) return error.WrongProtocolRealm;
            const principal_value = try self.principal(signed.request.principal);
            const public = try p.Ed25519.PublicKey.fromBytes(principal_value.grant.public_key);
            try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try g.digest(signed.request), public);
            try self.authorize(principal_value, signed.request.command);
            return principal_value;
        }
        fn authorize(self: *Self, principal_value: Principal, command: g.Command) !void {
            _ = self;
            const needed: p.Permission = switch (command) {
                .spawn => .spawn,
                .send => .send,
                .begin_turn, .turn, .open_view, .close_view => .execute,
                .deliver => .delivery,
                .dispatch, .observe, .close_effect => .effect,
                else => .admin,
            };
            if (principal_value.grant.permissions & p.permission(needed) == 0) return error.Forbidden;
            const pid: ?u64 = switch (command) {
                inline .own, .send, .begin_turn, .turn, .associate, .open_view, .close_view, .dispatch, .observe, .close_effect => |c| c.pid,
                .create_resource => |c| c.writer,
                .terminate, .expire => |id| id,
                else => null,
            };
            if (principal_value.grant.pid) |scope| if (pid != scope) return error.Forbidden;
        }
        fn duplicate(self: *Self, request: g.Request, principal_value: Principal) !?u64 {
            if (request.sequence > principal_value.sequence) {
                if (request.sequence != principal_value.sequence + 1) return error.SequenceGap;
                return null;
            }
            var current = try self.state();
            const receipt = (try current.get(Receipt, try catalog.key(.receipt, request.principal, request.sequence, ""))) orelse return error.MissingReceipt;
            if (!std.mem.eql(u8, &receipt.digest, &try g.digest(request))) return error.ConflictingRetry;
            return receipt.position;
        }
        pub const Prepared = struct { record: Record };
        pub fn prepare(self: *Self, signed: g.SignedRequest) !Prepared {
            try self.refresh();
            var principal_value = try self.authenticate(signed);
            if (try self.duplicate(signed.request, principal_value) != null) return error.AlreadyCommitted;
            if (self.head.position >= p.max_counter) return error.InvalidPosition;
            var candidate = try self.state();
            var next = self.head;
            const needs_time = switch (signed.request.command) {
                .grant, .revoke, .terminate, .close_view, .grant_resource, .retire_resource => false,
                .spawn => |c| c.work_before_ms != null,
                else => true,
            };
            const sample = if (needs_time) (if (self.clock) |clock| try clock.sample() else null) else null;
            if (sample) |now| {
                const bound = self.genesis.max_clock_error_ms orelse return error.UnsupportedDeadline;
                if (now.error_ms > bound or now.unix_ms > p.max_counter) return error.UntrustedTime;
                if (now.unix_ms < next.time_floor_ms) return error.ClockRollback;
                next.time_floor_ms = now.unix_ms;
            }
            try self.apply(&candidate, signed.request, sample);
            // Grant changes may target this caller only when the root's own
            // identity is unchanged; administrative root replacement is invalid.
            principal_value.sequence = signed.request.sequence;
            try candidate.put(address(.principal, signed.request.principal), principal_value);
            try candidate.put(try catalog.key(.receipt, signed.request.principal, signed.request.sequence, ""), Receipt{ .position = self.head.position, .digest = try g.digest(signed.request) });
            next.catalog = candidate.snapshot;
            next.position += 1;
            return .{ .record = .{ .position = self.head.position, .previous = self.head.catalog.root, .next = next, .request = signed.request, .time = sample } };
        }
        pub fn commit(self: *Self, prepared: Prepared) !u64 {
            if (!try self.journal.append(prepared.record.position, .{ .operation = prepared.record })) return error.Conflict;
            self.head = prepared.record.next;
            return prepared.record.position;
        }
        pub fn submit(self: *Self, signed: g.SignedRequest) !u64 {
            try self.refresh();
            const principal_value = try self.authenticate(signed);
            if (try self.duplicate(signed.request, principal_value)) |receipt| return receipt;
            return self.commit(try self.prepare(signed));
        }
        fn before(self: *Self, sample: ?core.Time.Sample, deadline: u64) !void {
            _ = self.genesis.max_clock_error_ms orelse return error.UnsupportedDeadline;
            const now = sample orelse return error.ClockUnavailable;
            try now.before(deadline);
        }
        fn executable(self: *Self, process_value: g.Process, sample: ?core.Time.Sample, settlement: bool) !void {
            if (process_value.lifecycle != .running) return error.RetiredProcess;
            if (process_value.failure != null) return error.BlockedProcess;
            if (process_value.work_before_ms) |cutoff| try self.before(sample, if (settlement and process_value.turn_permit != null) process_value.settle_before_ms.? else cutoff);
        }
        fn apply(self: *Self, candidate: *Catalog, request: g.Request, sample: ?core.Time.Sample) !void {
            const position = self.head.position;
            switch (request.command) {
                .grant => |grant| {
                    if (request.principal != 0) return error.Forbidden;
                    if (grant.subject == 0 or grant.permissions & ~p.all_permissions != 0) return error.InvalidGrant;
                    _ = try p.Ed25519.PublicKey.fromBytes(grant.public_key);
                    var subject = (try candidate.get(Principal, address(.principal, grant.subject))) orelse Principal{ .grant = grant, .revision = position, .epoch = 0 };
                    subject.grant = grant;
                    subject.revision = position;
                    subject.epoch = position;
                    try candidate.put(address(.principal, grant.subject), subject);
                },
                .revoke => |id| {
                    if (request.principal != 0 or id == 0) return error.Forbidden;
                    var subject = (try candidate.get(Principal, address(.principal, id))) orelse return error.UnknownPrincipal;
                    subject.grant.permissions = 0;
                    subject.revision = position;
                    subject.epoch = position;
                    try candidate.put(address(.principal, id), subject);
                },
                .spawn => |create| {
                    if ((create.work_before_ms == null) != (create.settle_before_ms == null)) return error.InvalidLifetime;
                    if (create.work_before_ms) |cutoff| {
                        if (create.settle_before_ms.? <= cutoff) return error.InvalidLifetime;
                        try self.before(sample, cutoff);
                    }
                    try candidate.put(address(.process, position), g.Process{ .pid = position, .code = create.code, .work_before_ms = create.work_before_ms, .settle_before_ms = create.settle_before_ms });
                },
                .own => |own| {
                    var process_value = try self.process(own.pid);
                    try self.executable(process_value, sample, true);
                    if (process_value.generation != own.expected_generation) return error.StaleGeneration;
                    const worker = try self.principal(own.worker);
                    if (worker.grant.permissions & p.permission(.execute) == 0) return error.Forbidden;
                    if (worker.grant.pid) |scope| if (scope != own.pid) return error.Forbidden;
                    process_value.generation += 1;
                    process_value.owner = own.worker;
                    try candidate.put(address(.process, own.pid), process_value);
                },
                .send => |send| {
                    var process_value = try self.process(send.pid);
                    try self.executable(process_value, sample, false);
                    process_value.admitted += 1;
                    const input: g.Input = .{ .position = position, .ordinal = process_value.admitted, .value = send.value, .origin = .{ .external = .{ .principal = request.principal, .policy_revision = (try self.principal(request.principal)).revision } } };
                    try candidate.put(try catalog.key(.mailbox, send.pid, input.ordinal, ""), input);
                    try candidate.put(address(.process, send.pid), process_value);
                },
                .terminate => |pid| {
                    var process_value = try self.process(pid);
                    if (process_value.lifecycle != .running) return error.RetiredProcess;
                    process_value.lifecycle = .terminated;
                    process_value.cancelled = process_value.admitted - process_value.consumed;
                    process_value.owner = null;
                    try candidate.put(address(.process, pid), process_value);
                },
                else => return error.UnsupportedGrowthCommand,
            }
        }
    };
}

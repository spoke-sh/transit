//! Native authority over immutable paged catalogs and journal-published policy.
const std = @import("std");
const core = @import("root.zig");
const catalog = @import("catalog.zig");
const pages = @import("pages.zig");
const p = core.protocol;
const g = p.Growth;
const state_ops = @import("growing_state.zig");
const work_ops = @import("growing_work.zig");
const auth_ops = @import("growing_authorization.zig");
pub const Genesis = struct {
    version: u32 = g.version,
    definition: g.Definition = g.current_definition,
    realm: u64,
    root_key: [32]u8,
    authorization_limits: p.Authorization.Limits = .{},
    authorization_change_quota: core.authorization_admin.Quota = .{},
    max_clock_error_ms: ?u32 = null,
    /// Operational bound on required resources checked at one process boundary.
    /// Non-required associations and retained resources have no catalog ceiling.
    required_dependencies: u16 = 16,
    dependency_vertices: u16 = 64,
    /// Explicit realm/application opt-in for protocol journal prefix compaction.
    /// Does not authorize page, receipt, mailbox, view or value deletion.
    allow_history_trim: bool = false,
    /// Finite admission ceiling on the journal position, like the legacy
    /// profile's. Unset (default) means unlimited. Growing catalogs are
    /// unbounded by design, so unlike the legacy reserve there is no fixed
    /// array size to derive a worst-case wind-down budget from; the reserve
    /// below is an explicit configured band instead of a formula. See
    /// docs/reference/state.md.
    admission_ceiling: ?u64 = null,
    /// Extra journal positions beyond `admission_ceiling`, reserved for
    /// control/wind-down work only (see `checkCapacity`). Meaningless when
    /// `admission_ceiling` is null. Zero means no grace band: control work
    /// stops exactly at the ceiling too.
    control_reserve: u64 = 4096,
};
pub const Head = struct {
    version: u32 = g.version,
    definition: g.Definition,
    position: u64,
    genesis: [32]u8,
    catalog: catalog.Snapshot,
    authorization: core.authorization_store.Snapshot,
    authorization_next_id: u64,
    time_floor_ms: u64 = 0,
    outputs: u64 = 0,
    history_floor: u64 = 0,
    last_collection: ?u64 = null,
};
pub const Record = struct { position: u64, previous: ?pages.Reference, next: Head, request: g.Request, time: ?core.Time.Sample };
pub const Entry = union(enum) { genesis: struct { genesis: Genesis, head: Head }, operation: Record };
/// Current derived decision, never a persisted permission record.
pub const Principal = struct { grant: g.Grant, role: u64, enabled: bool, credential_epoch: u64, revision: u64, epoch: u64, sequence: u64 };
pub const Sequence = struct { sequence: u64 };
pub const Receipt = struct { position: u64, digest: [32]u8 };
pub const StoredView = struct { meta: g.View, snapshot: catalog.Snapshot };
pub const StoredReadVersion = struct { meta: g.ReadVersion, snapshot: catalog.Snapshot };
pub const StoredSnapshot = struct {
    meta: g.Snapshot,
    snapshot: catalog.Snapshot,
    principal: u64,
    principal_epoch: u64,
    nonce: [16]u8,
};
pub const RetiredProcess = struct { pid: u64, lifecycle: @FieldType(g.Process, "lifecycle") };
pub const Maintenance = @import("growing_maintenance.zig");

fn genesisHash(genesis: Genesis) ![32]u8 {
    if (genesis.version != g.version or genesis.realm == 0 or genesis.realm > p.max_counter) return error.InvalidGenesis;
    _ = try p.Ed25519.PublicKey.fromBytes(genesis.root_key);
    try genesis.authorization_limits.validate();
    if (genesis.authorization_change_quota.steps == 0 or genesis.authorization_change_quota.changed_records == 0 or genesis.authorization_change_quota.steps > p.max_counter or genesis.authorization_change_quota.changed_records > p.max_counter) return error.InvalidCapacity;
    if (genesis.required_dependencies == 0 or genesis.required_dependencies > 4096) return error.InvalidCapacity;
    if (genesis.dependency_vertices == 0 or genesis.dependency_vertices > state_ops.graph_vertices) return error.InvalidCapacity;
    if (genesis.admission_ceiling) |ceiling| if (ceiling < 2 or ceiling > p.max_admission_ceiling) return error.InvalidCapacity;
    if (genesis.control_reserve > p.max_control_reserve) return error.InvalidCapacity;
    var bytes: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try std.json.Stringify.value(genesis, .{}, &writer);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.genesis.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn address(namespace: catalog.Namespace, id: u64) pages.Key {
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
        record_cache: catalog.RecordCache = .{},
        authorization_cache: catalog.RecordCache = .{},
        clock: ?core.Time.Source = null,
        /// Inject a fresh secure epoch at service startup. Volatile read pins
        /// cannot survive restart or replace retained durable read versions.
        snapshot_epoch: ?[16]u8 = null,
        snapshot_serial: u64 = 0,
        snapshot_time_floor_ms: u64 = 0,
        snapshots: [g.snapshot_capacity]?StoredSnapshot = @splat(null),

        pub fn bootstrap(journal: *Journal, page_store: *PageStore, genesis: Genesis) !Self {
            const fingerprint = try genesisHash(genesis);
            if (try journal.tail() == 0) {
                var candidate = try Catalog.open(page_store, .{});
                try candidate.put(address(.principal, 0), Sequence{ .sequence = 0 });
                const policy_root = try auth_ops.bootstrap(page_store, genesis.root_key);
                const head: Head = .{ .definition = g.current_definition, .position = 1, .genesis = fingerprint, .catalog = candidate.snapshot, .authorization = policy_root, .authorization_next_id = policy_root.next_id };
                _ = try journal.append(0, .{ .genesis = .{ .genesis = genesis, .head = head } });
            }
            return open(journal, page_store, genesis);
        }
        pub fn open(journal: *Journal, page_store: *PageStore, genesis: Genesis) !Self {
            var self: Self = .{ .journal = journal, .page_store = page_store, .genesis = genesis, .head = .{ .definition = g.current_definition, .position = 0, .genesis = try genesisHash(genesis), .catalog = .{}, .authorization = .{ .catalog = .{}, .revision = 0, .next_id = 1 }, .authorization_next_id = 1 } };
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
            if (next.history_floor >= next.position or next.history_floor < self.head.history_floor) return error.InvalidHistory;
            if (!std.mem.eql(u8, &next.genesis, &self.head.genesis)) return error.GenesisMismatch;
            try next.catalog.validate();
            try next.authorization.validate();
            if (next.authorization_next_id < next.authorization.next_id or next.authorization_next_id < self.head.authorization_next_id or next.authorization_next_id >= p.Authorization.public_role) return error.InvalidHistory;
            if (next.authorization.revision >= next.position or next.authorization.revision < self.head.authorization.revision) return error.InvalidHistory;
            if (next.catalog.records == 0 or next.authorization.catalog.records == 0) return error.InvalidHistory;
            // A persisted root must include its own publication's sequence and
            // receipt. Detect a wrong/partial root rather than trust a position
            // field that merely claims the proposal became visible.
            if (entry == .operation) {
                const record = entry.operation;
                var proposed = try Catalog.open(self.page_store, next.catalog);
                const caller = (try proposed.get(Sequence, address(.principal, record.request.principal))) orelse return error.InvalidHistory;
                const receipt = (try proposed.get(Receipt, try catalog.key(.receipt, record.request.principal, record.request.sequence, ""))) orelse return error.MissingReceipt;
                if (caller.sequence != record.request.sequence or receipt.position != record.position or !std.mem.eql(u8, &receipt.digest, &try g.digest(record.request))) return error.InvalidHistory;
            }
            // The trusted journal's published head is the materialization root.
            // Recovery reads pages on demand; it never stages or runs handlers.
            self.head = next;
        }
        pub fn state(self: *Self) !Catalog {
            var result = try Catalog.open(self.page_store, self.head.catalog);
            result.record_cache = &self.record_cache;
            return result;
        }
        pub fn principal(self: *Self, id: u64) !Principal {
            return auth_ops.principal(self, id);
        }
        pub fn authorization(self: *Self) !core.authorization_store.Store(PageStore) {
            var store = try core.authorization_store.Store(PageStore).open(self.page_store, self.head.authorization);
            store.catalog.record_cache = &self.authorization_cache;
            store.next_id = self.head.authorization_next_id;
            return store;
        }
        pub fn process(self: *Self, pid: u64) !g.Process {
            var current = try self.state();
            if (try current.get(g.Process, address(.process, pid))) |value| return value;
            if (try current.get(RetiredProcess, address(.retired_process, pid)) != null) return error.RetiredProcess;
            return error.UnknownProcess;
        }
        pub fn query(self: *Self, signed: g.SignedQuery) !g.Response {
            return @import("growing_read.zig").read(self, signed);
        }
        /// Privileged maintenance must reestablish current realm-wide admin
        /// authority before using the storage adapter. This publishes nothing.
        pub fn authorizeMaintenance(self: *Self, signed: g.SignedRequest) !void {
            if (signed.request.command != .checkpoint) return error.Forbidden;
            try self.refresh();
            _ = try self.authenticate(signed);
        }
        pub fn validateTime(self: *Self, now: core.Time.Sample) !void {
            const bound = self.genesis.max_clock_error_ms orelse return error.UnsupportedDeadline;
            if (now.error_ms > bound or now.unix_ms > p.max_counter) return error.UntrustedTime;
            if (now.unix_ms < self.head.time_floor_ms) return error.ClockRollback;
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
            if (!principal_value.enabled) return error.Forbidden;
            if (command == .authorization) return;
            if (command == .send) _ = try auth_ops.actor(self, principal_value.grant.subject, command.send.role);
            const needed: p.Permission = switch (command) {
                .spawn, .create => .spawn,
                .send => .send,
                .begin_turn, .turn, .turn_with_versions, .open_view, .close_view => .execute,
                .deliver => .delivery,
                .declare_payload, .payload_ready => .publish,
                .dispatch, .observe, .close_effect => .effect,
                else => .admin,
            };
            const pid: ?u64 = switch (command) {
                inline .own, .rotate_worker, .retry, .send, .begin_turn, .turn, .associate, .open_view, .close_view, .dispatch, .observe, .close_effect, .cancel_effect, .runtime_intent, .runtime_observe, .runtime_upgrade, .activate, .declare_payload, .payload_ready, .retire_payload, .payload_deleted, .collect, .initialize, .@"suspend", .@"resume" => |c| c.pid,
                .turn_with_versions => |command_value| command_value.turn.pid,
                .deliver => |id| (try work_ops.output(self, id)).destination,
                .create_resource => |c| c.writer,
                .terminate, .expire, .expire_suspension => |id| id,
                else => null,
            };
            if (principal_value.grant.pid) |scope| if (pid != scope) return error.Forbidden;
            if (!try auth_ops.nativeHas(self, principal_value, pid, needed)) return error.Forbidden;
        }
        fn duplicate(self: *Self, request: g.Request, principal_value: Principal) !?u64 {
            if (request.sequence > principal_value.sequence) {
                if (request.sequence != principal_value.sequence + 1) return error.SequenceGap;
                return null;
            }
            var current = try self.state();
            const receipt = (try current.get(Receipt, try catalog.key(.receipt, request.principal, request.sequence, ""))) orelse return error.MissingReceipt;
            if (!std.mem.eql(u8, &receipt.digest, &try g.digest(request))) return error.ConflictingRetry;
            try state_ops.authorizeReceipt(self, request);
            return receipt.position;
        }
        pub const Prepared = struct { record: Record };
        pub fn prepare(self: *Self, signed: g.SignedRequest) !Prepared {
            try self.refresh();
            const principal_value = try self.authenticate(signed);
            if (try self.duplicate(signed.request, principal_value) != null) return error.AlreadyCommitted;
            return self.prepareCurrent(signed.request);
        }
        /// Closing admission is resource backpressure, never expiry or permission
        /// to discard work. Defaults stay unlimited. Legacy derives its reserve
        /// from fixed catalog array sizes; growing catalogs have none, so the
        /// reserve is `genesis.control_reserve`, an explicit reviewed band
        /// rather than a computed worst case. Commands that only resolve
        /// existing obligations (revocation, retry, termination, expiry,
        /// closing a view/effect/resource, delivery, observation, checkpoint,
        /// reassigning ownership, and a turn that admits no new output/effect)
        /// remain admissible past the ceiling; commands that grow the journal
        /// with new obligations do not, until the reserve is exhausted too.
        fn checkCapacity(self: *Self, command: g.Command) !void {
            const ceiling = self.genesis.admission_ceiling orelse return;
            if (self.head.position < ceiling) return;
            if (self.head.position >= ceiling + self.genesis.control_reserve) return error.ControlCapacity;
            switch (command) {
                .authorization => |value| if (!try auth_ops.controlCommand(self, value)) return error.AdmissionClosed,
                .revoke, .retry, .terminate, .expire, .own, .rotate_worker, .begin_turn, .close_view, .retire_resource, .expire_resource, .reclaim_resource, .deliver, .observe, .close_effect, .cancel_effect, .checkpoint, .payload_ready, .retire_payload, .payload_deleted, .collect => {},
                .grant_resource => |c| if (c.permissions != 0) return error.AdmissionClosed,
                .turn => |t| {
                    if (t.effect != null) return error.AdmissionClosed;
                    for (t.outputs) |o| if (o != null) return error.AdmissionClosed;
                },
                .turn_with_versions => |tv| try self.checkCapacity(.{ .turn = tv.turn }),
                .runtime_intent => |c| if (c.desired != .stopped) return error.AdmissionClosed,
                .runtime_observe => {},
                .@"suspend", .expire_suspension => {},
                else => return error.AdmissionClosed,
            }
        }
        /// Authentication, permission and retry validation must have completed
        /// at this head. Publication CAS rejects every intervening transition.
        fn prepareCurrent(self: *Self, request: g.Request) !Prepared {
            if (self.head.position >= p.max_counter) return error.InvalidPosition;
            try self.checkCapacity(request.command);
            var candidate = try self.state();
            var pending: catalog.Candidate = .{};
            switch (request.command) {
                .send, .open_view, .close_view, .turn, .turn_with_versions, .deliver => candidate.pending = &pending,
                else => {},
            }
            var next = self.head;
            const needs_time = switch (request.command) {
                .authorization, .grant, .create_principal, .revoke, .terminate, .close_view, .grant_resource, .retire_resource, .checkpoint, .runtime_observe, .payload_ready, .retire_payload, .payload_deleted, .collect => false,
                .reclaim_resource => |id| ((try state_ops.resource(self, id)).history_ms orelse 0) > 0,
                .runtime_intent => |c| c.desired == .running,
                .close_effect => |c| c.reason == .deadline,
                .deliver => |id| (try self.process((try work_ops.output(self, id)).source)).lifecycle == .running,
                .cancel_effect => |c| (try self.process(c.pid)).lifecycle == .running,
                .expire => |id| needs: {
                    work_ops.expired(self, try self.process(id), null) catch |err| switch (err) {
                        error.ClockUnavailable => break :needs true,
                        else => return err,
                    };
                    break :needs false;
                },
                .spawn => |c| c.work_before_ms != null,
                .create => |c| c.process.work_before_ms != null,
                else => true,
            };
            const sample = if (needs_time) (if (self.clock) |clock| try clock.sample() else null) else null;
            if (sample) |now| {
                try self.validateTime(now);
                next.time_floor_ms = now.unix_ms;
            }
            // Delivery contributes six keys at most and does not change the
            // caller record. Its final mutation can include both retry records.
            var mutations: [core.pages.mutation_batch]core.pages.Mutation = undefined;
            const count: usize = if (request.command == .deliver)
                try work_ops.prepareDelivery(self, &candidate, request, sample, mutations[0..6])
            else count: {
                try self.apply(&candidate, &next, request, sample);
                break :count 0;
            };
            // Grant changes may target this caller only when the root's own
            // identity is unchanged; administrative root replacement is invalid.
            var principal_value = (try candidate.get(Sequence, address(.principal, request.principal))) orelse return error.InvalidHistory;
            principal_value.sequence = request.sequence;
            mutations[count] = try catalog.putMutation(address(.principal, request.principal), principal_value);
            mutations[count + 1] = try catalog.putMutation(try catalog.key(.receipt, request.principal, request.sequence, ""), Receipt{ .position = self.head.position, .digest = try g.digest(request) });
            try candidate.mutate(mutations[0 .. count + 2]);
            try candidate.flush();
            next.catalog = candidate.snapshot;
            next.position += 1;
            return .{ .record = .{ .position = self.head.position, .previous = self.head.catalog.root, .next = next, .request = request, .time = sample } };
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
            return self.commit(try self.prepareCurrent(signed.request));
        }
        pub fn before(self: *Self, sample: ?core.Time.Sample, deadline: u64) !void {
            _ = self.genesis.max_clock_error_ms orelse return error.UnsupportedDeadline;
            const now = sample orelse return error.ClockUnavailable;
            try now.before(deadline);
        }
        pub fn executable(self: *Self, process_value: g.Process, sample: ?core.Time.Sample, settlement: bool) !void {
            if (process_value.lifecycle != .running) return error.RetiredProcess;
            if (process_value.failure != null) return error.BlockedProcess;
            if (process_value.control) |control| if (control.phase != .ready) return error.InvalidLifecycle;
            try self.admissible(process_value, sample, settlement);
            if (process_value.control != null) try @import("growing_lifecycle.zig").required(self, process_value, sample);
        }
        pub fn provisionable(self: *Self, process_value: g.Process, sample: ?core.Time.Sample) !void {
            if (process_value.lifecycle != .running) return error.RetiredProcess;
            if (process_value.failure != null) return error.BlockedProcess;
            try self.admissible(process_value, sample, false);
        }
        /// A handler failure blocks execution, not the durable mailbox. New
        /// external admission still obeys work lifetime and required state.
        fn admissible(self: *Self, process_value: g.Process, sample: ?core.Time.Sample, settlement: bool) !void {
            if (process_value.lifecycle != .running) return error.RetiredProcess;
            if (process_value.control) |control| if (control.phase == .suspended) try self.before(sample, control.resume_before_ms.?);
            if (process_value.work_before_ms) |cutoff| try self.before(sample, if (settlement and process_value.turn_permit != null) process_value.settle_before_ms.? else cutoff);
            try state_ops.dependencies(self, process_value.pid, sample);
        }
        fn apply(self: *Self, candidate: *Catalog, next: *Head, request: g.Request, sample: ?core.Time.Sample) !void {
            const position = self.head.position;
            switch (request.command) {
                .authorization => try auth_ops.apply(self, candidate, next, request),
                .grant, .create_principal => |grant| {
                    _ = grant;
                    try auth_ops.nativeGrant(self, candidate, next, request);
                },
                .revoke => try auth_ops.nativeRevoke(self, next, request),
                .declare_payload, .payload_ready, .retire_payload, .payload_deleted => try @import("growing_payload.zig").apply(self, candidate, request, sample),
                .spawn => |create| {
                    if ((create.work_before_ms == null) != (create.settle_before_ms == null)) return error.InvalidLifetime;
                    if (create.work_before_ms) |cutoff| {
                        if (create.settle_before_ms.? <= cutoff) return error.InvalidLifetime;
                        try self.before(sample, cutoff);
                    }
                    try candidate.put(address(.process, position), g.Process{ .pid = position, .allow_collection = create.allow_collection, .code = create.code, .work_before_ms = create.work_before_ms, .settle_before_ms = create.settle_before_ms });
                    try auth_ops.object(self, next, .{ .kind = .process, .id = position }, p.all_permissions);
                },
                .own => |own| {
                    var process_value = try self.process(own.pid);
                    if (process_value.binding != null) return error.RuntimeActivationRequired;
                    try self.executable(process_value, sample, true);
                    if (process_value.generation != own.expected_generation) return error.StaleGeneration;
                    const worker = try self.principal(own.worker);
                    if (!try auth_ops.nativeHas(self, worker, own.pid, .execute)) return error.Forbidden;
                    if (worker.grant.pid) |scope| if (scope != own.pid) return error.Forbidden;
                    process_value.generation += 1;
                    process_value.owner = own.worker;
                    try candidate.put(address(.process, own.pid), process_value);
                },
                .rotate_worker => |rotation| {
                    if (request.principal != 0 or rotation.worker == 0) return error.Forbidden;
                    var process_value = try self.process(rotation.pid);
                    if (process_value.binding != null) return error.RuntimeActivationRequired;
                    try self.executable(process_value, sample, true);
                    if (process_value.generation != rotation.expected_generation) return error.StaleGeneration;
                    const worker = try self.principal(rotation.worker);
                    const required = p.permission(.inspect) | p.permission(.execute);
                    if (worker.grant.pid != rotation.pid or worker.grant.permissions != rotation.expected_permissions or
                        worker.grant.permissions & required != required or
                        !std.mem.eql(u8, &worker.grant.public_key, &rotation.expected_public_key) or
                        std.mem.eql(u8, &rotation.expected_public_key, &rotation.public_key)) return error.Forbidden;
                    _ = try p.Ed25519.PublicKey.fromBytes(rotation.public_key);
                    // Preserve both epoch (resource policy) and signed sequence.
                    // A key rotation cannot restore a revoked resource grant.
                    process_value.generation += 1;
                    process_value.owner = rotation.worker;
                    try auth_ops.rotate(self, next, rotation.worker, rotation.public_key);
                    try candidate.put(address(.process, rotation.pid), process_value);
                },
                .send => |send| {
                    var process_value = try self.process(send.pid);
                    try self.admissible(process_value, sample, false);
                    process_value.admitted += 1;
                    const input: g.Input = .{ .position = position, .ordinal = process_value.admitted, .value = send.value, .origin = .{ .external = .{ .principal = request.principal, .policy_revision = (try self.principal(request.principal)).revision } } };
                    const caller = try self.principal(request.principal);
                    const claim: p.Authorization.Claim = .{ .definition = g.current_definition, .realm = request.realm, .principal = request.principal, .credential_epoch = caller.credential_epoch, .role = (try auth_ops.actor(self, request.principal, send.role)).role, .audience = send.pid, .context = try p.Authorization.inputContext(send.value) };
                    try candidate.mutate(&.{
                        try catalog.putMutation(try catalog.key(.mailbox, send.pid, input.ordinal, ""), input),
                        try catalog.putMutation(address(.process, send.pid), process_value),
                        try catalog.putMutation(try catalog.key(.authorization_origin, send.pid, input.position, ""), claim),
                    });
                },
                .retry => |command| {
                    var process_value = try self.process(command.pid);
                    if (process_value.lifecycle != .running) return error.RetiredProcess;
                    if (process_value.generation != command.expected_generation) return error.StaleGeneration;
                    if (process_value.failure == null or process_value.failure != command.failure_input) return error.InvalidFailure;
                    _ = try state_ops.nextInput(self, process_value, command.failure_input);
                    process_value.failure = null;
                    // Validate current work lifetime/dependencies after clearing
                    // only the candidate's block. No accepted input is skipped.
                    try self.executable(process_value, sample, false);
                    try @import("growing_lifecycle.zig").restartBinding(&process_value, position);
                    try @import("growing_lifecycle.zig").fence(&process_value);
                    try candidate.put(address(.process, command.pid), process_value);
                },
                .terminate, .expire => |pid| {
                    var process_value = try self.process(pid);
                    if (process_value.lifecycle != .running) return error.RetiredProcess;
                    if (request.command == .expire) try work_ops.expired(self, process_value, sample);
                    process_value.lifecycle = if (request.command == .expire) .expired else .terminated;
                    process_value.cancelled = process_value.admitted - process_value.consumed;
                    process_value.owner = null;
                    process_value.turn_permit = null;
                    try candidate.put(address(.process, pid), process_value);
                    try state_ops.retireIndexes(candidate, pid);
                },
                .create_resource, .grant_resource, .associate, .open_view, .close_view, .retire_resource, .expire_resource, .reclaim_resource, .begin_turn, .turn, .turn_with_versions => try state_ops.apply(self, candidate, next, request, sample),
                .deliver => unreachable, // Prepared with its retry records above.
                .dispatch, .observe, .close_effect, .cancel_effect => try work_ops.apply(self, candidate, request, sample),
                .runtime_intent, .runtime_observe, .runtime_upgrade, .activate => try @import("growing_runtime.zig").apply(self, candidate, next, request, sample),
                .create, .initialize, .@"suspend", .@"resume", .expire_suspension => {
                    try @import("growing_lifecycle.zig").apply(self, candidate, request, sample);
                    if (request.command == .create) try auth_ops.object(self, next, .{ .kind = .process, .id = position }, p.all_permissions);
                },
                .collect => |command| {
                    try @import("growing_collection.zig").apply(self, candidate, next, command);
                    next.last_collection = position;
                },
                .checkpoint => {
                    if (!self.genesis.allow_history_trim) return error.RetentionNotEnabled;
                    // This publication is itself a complete root checkpoint.
                    // Keep it (or a newer complete head) in the journal so
                    // recovery never guesses a root from provider discovery.
                    next.history_floor = position;
                },
            }
        }
    };
}

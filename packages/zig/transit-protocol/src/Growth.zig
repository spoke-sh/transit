//! Native v1 wire types with bounded operations and paged durable collections.
const std = @import("std");
const p = @import("root.zig");
pub const version = 1;
/// Contract-set fingerprint, independent of the public version label. Replace
/// this identifier on an incompatible pre-1.0 cutover, including changed stored
/// Station/query semantics. Never reuse it to reinterpret accepted history.
/// SHA-256 of transit.native.v1.connector-outcome-diagnostic.2026-10-03.
pub const Definition = enum { ff8b5156ecbea7eba6dd375379442a334bf2eaf7f7b2e2f1eff462a5a554554a };
pub const current_definition: Definition = @fromBackingInt(0);
pub const Id = u64;
pub const request_domain = "transit.request.v1\x00";
pub const query_domain = "transit.query.v1\x00";
pub const page_size = 8;
pub const turn_views = 4;
pub const turn_mutations = 4;
pub const turn_outputs = 4;
pub const key_bytes = 32;
pub const view_lifetime_ms = 60_000;
pub const version_changes = 4;
pub const snapshot_capacity = 64;
pub const snapshots_per_principal = 8;
pub const snapshot_lifetime_ms = 300_000;
pub const Inspection = @import("NativeInspection.zig");
pub const SnapshotRead = @import("SnapshotRead.zig");
pub const SnapshotId = struct { epoch: [16]u8, serial: u64 };
pub const Snapshot = struct {
    id: SnapshotId,
    resource: Resource,
    deadline_ms: u64,
    hard_deadline_ms: u64,
};

/// Durable identity known before the containing input commits. Not a capability.
pub const ReadVersionId = struct { pid: Id, input: Id, index: u8 };
pub const ReadVersion = struct {
    id: ReadVersionId,
    resource: Id,
    revision: u64,
    created_at: Id,
    released_at: ?Id = null,
};
pub const TurnWithVersions = struct {
    turn: Turn,
    reads: [version_changes]?ReadVersionId = @splat(null),
    retain: [version_changes]?Id = @splat(null),
    release: [version_changes]?ReadVersionId = @splat(null),
};

pub const Grant = struct { subject: Id, public_key: [32]u8, permissions: u16, pid: ?Id = null };
pub const Create = struct { allow_collection: bool = false, code: u32 = 1, work_before_ms: ?u64 = null, settle_before_ms: ?u64 = null };
pub const ManagedCreate = struct { process: Create = .{}, required: [p.Lifecycle.max_required]?p.Value = @splat(null) };
pub const Output = struct { pid: Id, value: p.Value };
pub const Mutation = struct { key: p.Value, value: ?p.Value };
pub const Turn = struct {
    pid: Id,
    generation: u64,
    input: Id,
    expected_revision: u64,
    permit: ?Id = null,
    views: [turn_views]?Id = @splat(null),
    write_view: ?Id = null,
    mutations: [turn_mutations]?Mutation = @splat(null),
    outputs: [turn_outputs]?Output = @splat(null),
    effect: ?p.Value = null,
    failed: bool = false,
};
pub const Command = union(enum) {
    grant: Grant,
    revoke: Id,
    spawn: Create,
    own: struct { pid: Id, expected_generation: u64, worker: Id },
    retry: struct { pid: Id, expected_generation: u64, failure_input: Id },
    send: struct { pid: Id, value: p.Value },
    begin_turn: struct { pid: Id, generation: u64, input: Id },
    turn: Turn,
    terminate: Id,
    expire: Id,
    create_resource: struct { writer: Id, owned: bool = true, deadline_ms: ?u64 = null, history_ms: ?u64 = null },
    grant_resource: struct { resource: Id, subject: Id, permissions: u8 },
    associate: struct { pid: Id, name: p.Value, expected_revision: u64 = 0, resource: ?Id, required: bool = true },
    open_view: struct { pid: Id, generation: u64, input: Id, expected_revision: u64, resource: Id, revision: u64, deadline_ms: u64 },
    close_view: struct { pid: Id, view: Id },
    retire_resource: Id,
    expire_resource: Id,
    reclaim_resource: Id,
    deliver: Id,
    dispatch: struct { pid: Id, effect: Id, reconcile_before_ms: ?u64 = null, max_observations: u16 = p.max_effect_observations },
    observe: struct { pid: Id, effect: Id, attempt: Id, result: ?p.Value },
    close_effect: struct { pid: Id, effect: Id, attempt: Id, reason: enum { abandoned, deadline } = .abandoned },
    cancel_effect: struct { pid: Id, effect: Id },
    checkpoint: void,
    // Additive variants preserve existing canonical request bytes and receipts.
    turn_with_versions: TurnWithVersions,
    /// Rotate one PID-scoped worker without renewing its permissions/resource
    /// grants. The expected key/generation fence a racing administrator.
    rotate_worker: struct { pid: Id, worker: Id, expected_generation: u64, expected_public_key: [32]u8, expected_permissions: u16, public_key: [32]u8 },
    /// Never replace an existing principal when provisioning an application.
    create_principal: Grant,
    runtime_intent: p.Runtime.Intent,
    runtime_observe: p.Runtime.Observation,
    runtime_upgrade: p.Runtime.Upgrade,
    activate: struct { pid: Id, revision: u64, expected_generation: u64, worker: Id, public_key: [32]u8, worker_incarnation: [16]u8 },
    create: ManagedCreate,
    initialize: p.Lifecycle.Fence,
    @"suspend": struct { pid: Id, expected_generation: u64, resume_before_ms: u64 },
    @"resume": p.Lifecycle.Fence,
    expire_suspension: Id,
    declare_payload: struct { pid: Id, sha256: [32]u8, bytes: u32, allow_delete: bool = false },
    payload_ready: p.PayloadRef,
    retire_payload: p.PayloadRef,
    payload_deleted: p.PayloadRef,
    collect: Collection,
};
pub const Collection = struct { pid: Id, id: Id, kind: enum { output, effect, payload, resource, process } };
pub const Request = struct { version: u32 = version, definition: Definition = current_definition, realm: Id, principal: Id, sequence: u64, command: Command };
pub const SignedRequest = struct { request: Request, signature: [64]u8 };
pub const Origin = union(enum) {
    external: struct { principal: Id, policy_revision: u64 },
    process: struct { pid: Id, turn: Id, output: Id },
    effect: struct { id: Id, attempt: Id, executor: Id },
};
pub const Input = struct { position: Id, ordinal: u64, value: p.Value, origin: Origin };
pub const Process = struct {
    allow_collection: bool = false,
    pid: Id,
    code: u32,
    owner: ?Id = null,
    generation: u64 = 0,
    revision: u64 = 0,
    lifecycle: enum { running, terminated, expired } = .running,
    failure: ?Id = null,
    admitted: u64 = 0,
    consumed: u64 = 0,
    cancelled: u64 = 0,
    work_before_ms: ?u64 = null,
    settle_before_ms: ?u64 = null,
    turn_permit: ?struct { id: Id, input: Id } = null,
    binding: ?p.Runtime.Binding = null,
    control: ?p.Lifecycle.Control = null,
};
pub const Resource = struct {
    id: Id,
    writer: Id,
    owner: ?Id,
    revision: u64,
    entries: u64 = 0,
    history_ms: ?u64 = null,
    changed_ms: u64 = 0,
    last_turn: ?Id = null,
    deadline_ms: ?u64,
    phase: enum { active, retired, reclaimed } = .active,
    retired_at: ?Id = null,
};
pub fn processReady(process: Process) bool {
    return process.lifecycle == .running and process.failure == null and
        (if (process.control) |control| control.phase == .ready else true);
}
pub const Association = struct { pid: Id, name: p.Value, resource: Id, revision: u64, required: bool };
pub const View = struct {
    id: Id,
    pid: Id,
    principal: Id,
    generation: u64,
    input: Id,
    process_revision: u64,
    resource: Id,
    revision: u64,
    deadline_ms: u64,
    closed_at: ?Id = null,
};
pub const Entry = struct { key: p.Value, value: p.Value, revision: u64 };
pub const EffectObservation = struct { input: Id, policy_revision: u64 };
pub const EffectClosure = struct {
    reason: enum { observed, observation_budget, abandoned, deadline, unattempted_cancel },
    principal: Id,
    policy_revision: u64,
    clock_lower_ms: ?u64 = null,
};
pub const Effect = struct {
    id: Id,
    pid: Id,
    payload: p.Value,
    phase: enum { pending, authorized, unknown, observed, cancelled, closed_unknown } = .pending,
    attempt: ?Id = null,
    executor: ?Id = null,
    authorization_policy: ?u64 = null,
    last_observation: ?EffectObservation = null,
    closure: ?EffectClosure = null,
    result: ?p.Value = null,
    closed_at: ?Id = null,
    reconcile_before_ms: ?u64 = null,
    max_observations: u16 = p.max_effect_observations,
    observations: u16 = 0,
};
pub const Outbox = struct {
    id: Id,
    source: Id,
    turn: Id,
    index: u8,
    destination: Id,
    value: p.Value,
    phase: enum { pending, delivered, denied, expired, retired, cancelled } = .pending,
    resolved_at: ?Id = null,
    courier: ?Id = null,
    policy_revision: ?u64 = null,
};
pub const Payload = struct {
    id: Id,
    pid: Id,
    publisher: Id,
    sha256: [32]u8,
    bytes: u32,
    allow_delete: bool = false,
    phase: enum { creating, ready, retiring, deleted } = .creating,
    retired_at: ?Id = null,
    deleted_at: ?Id = null,
};
pub const Query = struct {
    version: u32 = version,
    definition: Definition = current_definition,
    realm: Id,
    principal: Id,
    kind: union(enum) {
        capabilities: void,
        inspection: Inspection.Query,
        delivery: void,
        process: Id,
        resource: Id,
        view: Id,
        association: struct { pid: Id, name: p.Value },
        processes: struct { after: ?Id = null, position: ?Id = null },
        resources: struct { after: ?Id = null, position: ?Id = null },
        associations: struct { pid: Id, after: ?Id = null, position: ?Id = null },
        entries: struct { view: ?Id = null, resource: ?Id = null, revision: ?u64 = null, key: ?p.Value = null, after: ?p.Value = null },
        outputs: struct { after: ?Id = null, position: ?Id = null },
        effects: struct { pid: Id, after: ?Id = null, position: ?Id = null },
        read_version: ReadVersionId,
        version_entries: struct { id: ReadVersionId, generation: u64, key: ?p.Value = null, after: ?p.Value = null },
        read_versions: struct { pid: Id, after: ?ReadVersionId = null, position: ?Id = null },
        identity: void,
        read_access: Id,
        read_entries: struct { resource: Id, revision: ?u64 = null, view: ?Id = null, keys: [page_size]?p.Value },
        open_snapshot: struct { resource: Id, nonce: [16]u8 },
        snapshot_entries: struct { id: SnapshotId, key: ?p.Value = null, after: ?p.Value = null },
        close_snapshot: SnapshotId,
        snapshot_read: SnapshotRead.Query,
    },
};
pub const Identity = struct { principal: Id, permissions: u16, pid: ?Id, policy_revision: u64 };
pub const SignedQuery = struct { query: Query, signature: [64]u8 };
pub fn Batch(comptime T: type, comptime Cursor: type) type {
    return struct { entries: [page_size]?T = @splat(null), next: ?Cursor = null };
}
pub const Capabilities = struct {
    profile: enum { growing_v1 } = .growing_v1,
    version: u32 = version,
    identity_maximum: u64 = p.max_counter,
    page_entries: u16 = page_size,
    mutation_budget: u16 = turn_mutations,
    view_budget: u16 = turn_views,
    output_budget: u16 = turn_outputs,
    required_resources_per_process: u16,
    dependency_validation_vertices: u16,
    dependency_changes: enum { quiescent_owner_and_borrowers } = .quiescent_owner_and_borrowers,
    association_lookup: bool = false,
    scoped_retry: bool = false,
    retained_read_versions: bool = false,
    resource_read_access: bool = false,
    resource_read_batch: bool = false,
    leased_snapshots: bool = false,
    snapshot_read: bool = false,
    worker_rotation: bool = false,
    version_change_budget: u16 = version_changes,
    // Unsupported lifecycle/provider/cleanup extensions must remain explicit.
    runtime_bindings: bool = false,
    history_reclamation: bool = false,
    retained_history: enum { unlimited, checkpointed } = .unlimited,
    station: bool = false,
    /// Null means unlimited (no configured ceiling). Combine with the
    /// enclosing Response's `position` to compute remaining ordinary and
    /// control-reserve headroom; neither is a physical-capacity guarantee.
    admission_ceiling: ?u64 = null,
    control_reserve: u64 = 0,
};
pub const Response = struct {
    version: u32 = version,
    definition: Definition,
    realm: Id,
    position: Id,
    principal_sequence: u64,
    body: union(enum) {
        capabilities: Capabilities,
        inspection: Inspection.Page,
        delivery: struct { next: ?Id },
        process: struct { process: Process, input: ?Input },
        resource: Resource,
        view: View,
        association: ?Association,
        processes: Batch(Process, Id),
        resources: Batch(Resource, Id),
        associations: Batch(Association, Id),
        entries: struct { view: ?View, resource: Resource, page: Batch(Entry, p.Value) },
        outputs: Batch(Outbox, Id),
        effects: Batch(Effect, Id),
        read_version: ReadVersion,
        version_entries: struct { version: ReadVersion, generation: u64, resource: Resource, page: Batch(Entry, p.Value) },
        read_versions: Batch(ReadVersion, ReadVersionId),
        identity: Identity,
        read_access: Resource,
        read_entries: struct { resource: Resource, view: ?View = null, entries: [page_size]?Entry },
        open_snapshot: Snapshot,
        snapshot_entries: struct { snapshot: Snapshot, page: Batch(Entry, p.Value) },
        close_snapshot: SnapshotId,
        snapshot_read: SnapshotRead.Result,
    },
};

pub fn validateKey(key: p.Value) !void {
    try key.validate();
    if (key.len == 0 or key.len > key_bytes) return error.InvalidStateKey;
}
fn counters(value: anytype) !void {
    const T = @TypeOf(value);
    if (T == p.Value) return value.validate();
    switch (@typeInfo(T)) {
        .int => if (value > p.max_counter) return error.InvalidCounter,
        .optional => if (value) |child| try counters(child),
        .array => for (value) |child| try counters(child),
        .@"struct" => |info| inline for (info.field_names) |name| try counters(@field(value, name)),
        .@"union" => switch (value) {
            inline else => |child| try counters(child),
        },
        else => {},
    }
}
pub fn validate(request: Request) !void {
    if (request.version != version or request.realm == 0) return error.WrongProtocolRealm;
    try counters(request);
    if (request.sequence == 0) return error.InvalidSequence;
    switch (request.command) {
        .create => |c| for (c.required, 0..) |slot, index| if (slot) |name| {
            try validateKey(name);
            for (c.required[0..index]) |previous| if (previous) |other| if (name.eql(other)) return error.InvalidStateKey;
        },
        .associate => |c| try validateKey(c.name),
        .turn => |c| try validateTurn(c),
        .turn_with_versions => |c| {
            try validateTurn(c.turn);
            for (c.reads, 0..) |slot, i| if (slot) |id| {
                if (c.turn.failed) return error.InvalidFailure;
                try validateVersionId(id);
                if (id.pid != c.turn.pid) return error.InvalidReadVersion;
                for (c.reads[0..i]) |previous| if (previous) |other| if (std.meta.eql(id, other)) return error.InvalidReadVersion;
            };
            for (c.retain, 0..) |slot, i| if (slot) |id| {
                if (c.turn.failed) return error.InvalidFailure;
                if (std.mem.indexOfScalar(?Id, &c.turn.views, id) == null) return error.InvalidReadVersion;
                for (c.retain[0..i]) |previous| if (previous == id) return error.InvalidReadVersion;
            };
            for (c.release, 0..) |slot, i| if (slot) |id| {
                if (c.turn.failed) return error.InvalidFailure;
                try validateVersionId(id);
                if (id.pid != c.turn.pid) return error.InvalidReadVersion;
                for (c.release[0..i]) |previous| if (previous) |other| if (std.meta.eql(id, other)) return error.InvalidReadVersion;
            };
        },
        else => {},
    }
}
fn validateTurn(turn: Turn) !void {
    for (turn.mutations, 0..) |slot, i| if (slot) |mutation| {
        try validateKey(mutation.key);
        for (turn.mutations[0..i]) |previous| if (previous) |other| if (other.key.eql(mutation.key)) return error.DuplicateStateKey;
    };
}
pub fn validateVersionId(id: ReadVersionId) !void {
    try counters(id);
    if (id.pid == 0 or id.input == 0 or id.index >= version_changes) return error.InvalidReadVersion;
}
pub fn versionOrder(a: ReadVersionId, b: ReadVersionId) std.math.Order {
    if (a.pid != b.pid) return std.math.order(a.pid, b.pid);
    if (a.input != b.input) return std.math.order(a.input, b.input);
    return std.math.order(a.index, b.index);
}
pub fn validateQuery(query: Query) !void {
    if (query.version != version or query.realm == 0) return error.WrongProtocolRealm;
    try counters(query);
    switch (query.kind) {
        .inspection => |q| try Inspection.validate(q),
        .snapshot_read => |q| try SnapshotRead.validate(q),
        .open_snapshot => |q| if (q.resource == 0) return error.InvalidRead,
        .snapshot_entries => |q| {
            if (q.id.serial == 0 or (q.key != null and q.after != null)) return error.InvalidRead;
            if (q.key) |key| try validateKey(key);
            if (q.after) |key| try validateKey(key);
        },
        .close_snapshot => |id| if (id.serial == 0) return error.InvalidRead,
        .association => |c| try validateKey(c.name),
        .read_entries => |c| {
            if (c.view == 0) return error.InvalidRead;
            if (c.resource == 0 or c.keys[0] == null) return error.InvalidRead;
            var ended = false;
            for (c.keys, 0..) |slot, i| {
                const key = slot orelse {
                    ended = true;
                    continue;
                };
                if (ended) return error.InvalidRead;
                try validateKey(key);
                for (c.keys[0..i]) |previous| if (previous.?.eql(key)) return error.InvalidRead;
            }
        },
        .entries => |c| {
            if ((c.view == null) == (c.resource == null) or (c.resource == null) != (c.revision == null)) return error.InvalidRead;
            if (c.key != null and c.after != null) return error.InvalidRead;
            if (c.key) |key| try validateKey(key);
            if (c.after) |key| try validateKey(key);
        },
        .read_version => |id| try validateVersionId(id),
        .version_entries => |c| {
            try validateVersionId(c.id);
            if (c.key != null and c.after != null) return error.InvalidRead;
            if (c.key) |key| try validateKey(key);
            if (c.after) |key| try validateKey(key);
        },
        .read_versions => |c| if (c.after) |id| {
            try validateVersionId(id);
            if (id.pid != c.pid or c.position == null) return error.InvalidRead;
        },
        inline .processes, .resources, .associations, .outputs, .effects => |c| if (c.after != null and c.position == null) return error.InvalidRead,
        else => {},
    }
}

/// Validate context and coverage before handing a typed response to a caller.
/// Parsing the JSON type alone cannot detect a different realm, variant or cut.
pub fn validateResponse(response: Response, query: Query) !void {
    try validateQuery(query);
    try counters(response);
    if (response.version != version or response.realm != query.realm or response.position == 0 or
        !std.mem.eql(u8, @tagName(response.body), @tagName(query.kind))) return error.InvalidRead;
    switch (query.kind) {
        .delivery => if (response.body.delivery.next == 0) return error.InvalidRead,
        .inspection => try Inspection.validatePage(response.body.inspection, query, response.position),
        .snapshot_read => |q| try SnapshotRead.validateResult(response.body.snapshot_read, q),
        .open_snapshot => |q| {
            const snapshot = response.body.open_snapshot;
            try validateSnapshot(snapshot);
            if (snapshot.resource.id != q.resource) return error.InvalidRead;
        },
        .snapshot_entries => |q| {
            const value = response.body.snapshot_entries;
            try validateSnapshot(value.snapshot);
            if (!std.meta.eql(q.id, value.snapshot.id)) return error.InvalidRead;
            try validateEntries(value.page, q.key, q.after, value.snapshot.resource.revision);
        },
        .close_snapshot => |id| if (!std.meta.eql(id, response.body.close_snapshot)) return error.InvalidRead,
        .identity => {
            const identity = response.body.identity;
            if (identity.principal != query.principal or identity.permissions & ~p.all_permissions != 0 or
                identity.permissions & p.permission(.inspect) == 0 or identity.pid == 0 or identity.policy_revision >= response.position) return error.InvalidRead;
        },
        .capabilities => {
            const caps = response.body.capabilities;
            if (caps.version != version or caps.identity_maximum != p.max_counter or
                caps.page_entries != page_size or caps.mutation_budget != turn_mutations or
                caps.view_budget != turn_views or caps.output_budget != turn_outputs or
                caps.version_change_budget != version_changes or
                caps.required_resources_per_process == 0 or caps.dependency_validation_vertices == 0) return error.InvalidRead;
        },
        .process => |pid| {
            const value = response.body.process;
            if (value.process.pid != pid or value.process.consumed > value.process.admitted or
                value.process.cancelled > value.process.admitted - value.process.consumed) return error.InvalidRead;
            if (value.input) |input| {
                if (!processReady(value.process) or input.ordinal != value.process.consumed + 1 or
                    input.ordinal > value.process.admitted or input.position >= response.position) return error.InvalidRead;
            } else if (processReady(value.process) and value.process.consumed < value.process.admitted) return error.InvalidRead;
        },
        .resource => |id| if (response.body.resource.id != id) return error.InvalidRead,
        .read_access => |id| if (response.body.read_access.id != id or response.body.read_access.phase != .active) return error.InvalidRead,
        .read_entries => |q| {
            const value = response.body.read_entries;
            if (q.view) |id| {
                const view = value.view orelse return error.InvalidRead;
                if (view.id != id or view.resource != q.resource or view.revision != value.resource.revision or view.closed_at != null) return error.InvalidRead;
            } else if (value.view != null) return error.InvalidRead;
            if (value.resource.id != q.resource or value.resource.phase != .active) return error.InvalidRead;
            if (q.revision) |revision| if (value.resource.revision != revision) return error.InvalidRead;
            for (value.entries, q.keys) |slot, key| if (slot) |entry| {
                if (key == null or !entry.key.eql(key.?) or entry.revision == 0 or entry.revision > value.resource.revision) return error.InvalidRead;
                try validateKey(entry.key);
            };
        },
        .view => |id| if (response.body.view.id != id) return error.InvalidRead,
        .read_version => |id| {
            try validateVersion(response.body.read_version, response.position);
            if (!std.meta.eql(id, response.body.read_version.id)) return error.InvalidRead;
        },
        .version_entries => |q| {
            const value = response.body.version_entries;
            try validateVersion(value.version, response.position);
            if (!std.meta.eql(q.id, value.version.id) or value.generation != q.generation or value.version.released_at != null or
                value.version.resource != value.resource.id or value.version.revision != value.resource.revision) return error.InvalidRead;
            try validateEntries(value.page, q.key, q.after, value.resource.revision);
        },
        .read_versions => |q| {
            if (q.position) |cut| if (cut != response.position) return error.InvalidRead;
            const batch = response.body.read_versions;
            var previous = q.after;
            var ended = false;
            for (batch.entries) |slot| {
                const item = slot orelse {
                    ended = true;
                    continue;
                };
                try validateVersion(item, response.position);
                if (ended or item.id.pid != q.pid) return error.InvalidRead;
                if (previous) |id| if (versionOrder(id, item.id) != .lt) return error.InvalidRead;
                previous = item.id;
            }
            if (batch.next) |next| {
                try validateVersionId(next);
                if (next.pid != q.pid or next.input >= response.position) return error.InvalidRead;
                if (q.after) |id| if (versionOrder(id, next) != .lt) return error.InvalidRead;
                if (previous) |id| if (versionOrder(id, next) == .gt) return error.InvalidRead;
            }
        },
        .association => |q| if (response.body.association) |value| {
            if (value.pid != q.pid or !value.name.eql(q.name) or value.resource == 0 or
                value.resource >= response.position or value.revision == 0 or value.revision >= response.position) return error.InvalidRead;
        },
        .entries => |q| {
            const value = response.body.entries;
            if (q.view) |id| {
                const view = value.view orelse return error.InvalidRead;
                if (view.id != id or view.principal != query.principal or view.resource != value.resource.id or
                    view.revision != value.resource.revision) return error.InvalidRead;
            } else if (value.view != null or value.resource.id != q.resource.? or value.resource.revision != q.revision.?) return error.InvalidRead;
            try validateEntries(value.page, q.key, q.after, value.resource.revision);
        },
        inline .processes, .resources, .associations, .outputs, .effects => |q, tag| {
            if (q.position) |cut| if (cut != response.position) return error.InvalidRead;
            const batch = @field(response.body, @tagName(tag));
            var previous = q.after orelse 0;
            var ended = false;
            for (batch.entries) |slot| {
                const entry = slot orelse {
                    ended = true;
                    continue;
                };
                const id = if (tag == .processes) entry.pid else if (tag == .associations) entry.revision else entry.id;
                if (ended or id <= previous) return error.InvalidRead;
                if (tag == .outputs) {
                    if (entry.turn >= response.position) return error.InvalidRead;
                } else if (id >= response.position) return error.InvalidRead;
                if (tag == .associations or tag == .effects) if (entry.pid != q.pid) return error.InvalidRead;
                if (tag == .effects) try validateEffect(entry, response.position);
                previous = id;
            }
            if (batch.next) |next| {
                if (next < previous or next <= (q.after orelse 0)) return error.InvalidRead;
                if (tag != .outputs and next >= response.position) return error.InvalidRead;
            }
        },
    }
}

pub fn validateSnapshot(value: Snapshot) !void {
    if (value.id.serial == 0 or value.resource.id == 0 or value.resource.phase != .active or
        value.deadline_ms == 0 or value.deadline_ms > value.hard_deadline_ms) return error.InvalidRead;
}

test "leased snapshot signing matches independent canonical JSON fixtures" {
    const Fixture = struct { query: Query, digest: []const u8 };
    const parsed = try std.json.parseFromSlice([]Fixture, std.testing.allocator, @embedFile("fixtures/leased-snapshots.json"), .{});
    defer parsed.deinit();
    for (parsed.value) |fixture| {
        const actual = try queryDigest(fixture.query);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, fixture.digest);
        try std.testing.expectEqualSlices(u8, &expected, &actual);
    }
}

test "native responses require the current contract definition even with a v1 label" {
    const t = std.testing;
    const missing = "{\"version\":1,\"realm\":42,\"position\":1,\"principal_sequence\":0,\"body\":{\"identity\":{\"principal\":0,\"permissions\":1,\"pid\":null,\"policy_revision\":0}}}";
    try t.expectError(error.MissingField, std.json.parseFromSlice(Response, t.allocator, missing, .{}));
    const foreign = "{\"version\":1,\"definition\":\"previous-v1-definition\",\"realm\":42,\"position\":1,\"principal_sequence\":0,\"body\":{\"identity\":{\"principal\":0,\"permissions\":1,\"pid\":null,\"policy_revision\":0}}}";
    try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(Response, t.allocator, foreign, .{}));
    const retired = "{\"version\":1,\"definition\":\"2577b1247a78a2f8a3eae59b3b36a286fedf9836759d19325edd9b3318b5bad5\",\"realm\":42,\"position\":1,\"principal_sequence\":0,\"body\":{\"identity\":{\"principal\":0,\"permissions\":1,\"pid\":null,\"policy_revision\":0}}}";
    try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(Response, t.allocator, retired, .{}));
    const incomplete_output_names = "{\"version\":1,\"definition\":\"34f920f3044133818431378d99c1db55f7c714e43c6966acb71197b0a4d69090\",\"realm\":42,\"position\":1,\"principal_sequence\":0,\"body\":{\"identity\":{\"principal\":0,\"permissions\":1,\"pid\":null,\"policy_revision\":0}}}";
    try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(Response, t.allocator, incomplete_output_names, .{}));
    inline for (.{
        // Previous publication input dispositions omitted retained typed witnesses.
        "682928908924c932d9281f8e4fa5ed4adff2c704e39bb4bf11aba4bd2cbeeeda",
        // Previous serving dispositions retained only a bare error name.
        "c750e7034f20d2446bfe44c7ad19a3ca45b415a0a02754523dc280cf74e20d15",
        "8d2c6617b339418cf2d3afa6259009e4b3efc5308e40fe65757ca9385c227803",
        "75a5efed41df165c680b9d13116d10b3c72357e542eca9b96195d6b520714cb1",
        "4f6cb811c01a0e89111f7c5e4ff0425d91a7bd6eeaf0ca77c6d6d66399da4cbc",
        "b83b6c75eae067d04b938425305a4a03c04193b4499e059405fa42ae63b9fec5",
        "8473c39ff9d0cfda98692ce4c568f35ae158785fdfb86b8d04f08ad35fec2152",
        "2a9d723001230edbae890c52dc06dd4b9e153fc3db0f8ff865f2cad73db72f1e",
        "1eeeb5cd033defd5dcbcd0ce764b2fbb6b163eac17109dee4589f37bd5f4a463",
        // Previous application receipts omitted the original conflict basis.
        "695a46c853d1442c3eae1b8079694b2f04b616b1798d25f50fc243325f596ee2",
        // Previous query records and replies omitted the original terminal failure.
        "72b041c9c88b99dc14e6be68318faf397d451f851f9ef2b6d52faf2c4714d6c5",
        // Previous mutation status omitted the rejecting execution witness.
        "e412a074bf01f92cb62c7953051930d81a78cc1a0f45472b7eff17d9931f8633",
        // Pre-integration Boolean and value-count definitions.
        "b2a625681e95d8a208ebe65f4b7b86931b6582bdfcc9f85d66b043447b9473b9",
        "a6e224b47cf74998fe2665313d4337fea789d33d6d389b66b6ee3142860fb6f5",
        // Shared Boolean plans before the typed C/C++ program ABI.
        "23c4c85312d089e41826bb76da6ffa2b6a009fc49bd8655bcb813524f2f401e7",
        // Inline Table admission and captured reads before Boolean integration.
        "8629e1618a4f97ac07d5b4b454249a8d1b18eab9e969a9876345844ef4fa57fe",
        // Boolean plans before inline admission and captured-read selectors.
        "723ca82356804b77dbb20dadb122c37816a16188448d52a680a6ff1a87a0314c",
        // Output names and local writer before Boolean saved-plan programs.
        "1b790ef9b226fa9d5ee27622dd7fbfd51cb56eb764574594c0a792d4170bf0a2",
        // Local combined writer before output-name support.
        "ccd596113a3719c6d38afdffe907f04e90f4703472c91aaaffa7875364b5b31e",
        // Output-name callers before local combined-writer integration.
        "00177e103bcb1a8208abd6958d79c9f3f471caf62d4a0c87957072356fd28214",
        // Integrated plans before the neutral caller layout cutover.
        "67e9b3edcd3502e692285c9a3d093bd6b9a958dc6edde4c7057504067d505ff0",
    }) |definition| {
        const previous = "{\"version\":1,\"definition\":\"" ++ definition ++ "\",\"realm\":42,\"position\":1,\"principal_sequence\":0,\"body\":{\"identity\":{\"principal\":0,\"permissions\":1,\"pid\":null,\"policy_revision\":0}}}";
        try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(Response, t.allocator, previous, .{}));
    }
}

test "leased snapshot responses reject wrong tokens, cuts and malformed coverage" {
    const t = std.testing;
    const id: SnapshotId = .{ .epoch = @splat(7), .serial = 1 };
    const query: Query = .{ .realm = 42, .principal = 2, .kind = .{ .snapshot_entries = .{ .id = id } } };
    const valid: Response = .{ .realm = 42, .position = 20, .definition = current_definition, .principal_sequence = 0, .body = .{ .snapshot_entries = .{ .snapshot = .{ .id = id, .resource = .{ .id = 3, .writer = 2, .owner = null, .revision = 7, .deadline_ms = null }, .deadline_ms = 100, .hard_deadline_ms = 200 }, .page = .{} } } };
    try validateResponse(valid, query);
    var bad = valid;
    bad.body.snapshot_entries.snapshot.id.epoch[0] = 8;
    try t.expectError(error.InvalidRead, validateResponse(bad, query));
    bad = valid;
    bad.body.snapshot_entries.snapshot.deadline_ms = 201;
    try t.expectError(error.InvalidRead, validateResponse(bad, query));
    bad = valid;
    bad.body.snapshot_entries.page.next = try p.Value.init("a");
    try t.expectError(error.InvalidRead, validateResponse(bad, query));
    bad = valid;
    bad.body.snapshot_entries.page.entries[0] = .{ .key = try p.Value.init("a"), .value = .{}, .revision = 8 };
    try t.expectError(error.InvalidRead, validateResponse(bad, query));
}
fn validateVersion(value: ReadVersion, position: Id) !void {
    try validateVersionId(value.id);
    if (value.resource == 0 or value.revision < value.resource or value.revision >= value.created_at or
        value.created_at <= value.id.input or value.created_at >= position) return error.InvalidRead;
    if (value.released_at) |released| if (released <= value.created_at or released >= position) return error.InvalidRead;
}
fn validateEntries(page: Batch(Entry, p.Value), point: ?p.Value, after: ?p.Value, revision: u64) !void {
    var previous = after;
    var ended = false;
    var count: usize = 0;
    for (page.entries) |slot| {
        const entry = slot orelse {
            ended = true;
            continue;
        };
        if (ended) return error.InvalidRead;
        try validateKey(entry.key);
        if (previous) |key| if (std.mem.order(u8, key.slice(), entry.key.slice()) != .lt) return error.InvalidRead;
        if (point) |key| if (!key.eql(entry.key)) return error.InvalidRead;
        if (entry.revision > revision) return error.InvalidRead;
        previous = entry.key;
        count += 1;
    }
    if (point != null and (count > 1 or page.next != null)) return error.InvalidRead;
    if (page.next) |next| {
        try validateKey(next);
        if (count == 0 or !next.eql(previous.?)) return error.InvalidRead;
    }
}

pub fn commandPid(command: Command) ?Id {
    return switch (command) {
        .turn_with_versions => |c| c.turn.pid,
        .terminate, .expire, .expire_suspension => |id| id,
        inline else => |value| switch (@typeInfo(@TypeOf(value))) {
            .@"struct" => if (@hasField(@TypeOf(value), "pid")) value.pid else null,
            else => null,
        },
    };
}
fn hash(domain: []const u8, value: anytype) ![32]u8 {
    var bytes: [p.max_entry_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(value, .{}, &writer) catch return error.RecordTooLarge;
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(domain);
    hasher.update(writer.buffered());
    return hasher.finalResult();
}
pub fn digest(request: Request) ![32]u8 {
    try validate(request);
    return hash(request_domain, request);
}
pub fn queryDigest(query: Query) ![32]u8 {
    try validateQuery(query);
    return hash(query_domain, query);
}
pub fn sign(request: Request, key: p.Ed25519.KeyPair) !SignedRequest {
    return .{ .request = request, .signature = (try key.sign(&try digest(request), null)).toBytes() };
}
pub fn signQuery(query: Query, key: p.Ed25519.KeyPair) !SignedQuery {
    return .{ .query = query, .signature = (try key.sign(&try queryDigest(query), null)).toBytes() };
}

test "growing identities are explicit and cannot reuse legacy signature domains" {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const request: Request = .{ .realm = 1, .principal = 65536, .sequence = 1, .command = .{ .send = .{ .pid = 2, .value = .{} } } };
    const signed = try sign(request, key);
    try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try digest(request), key.public_key);
    var invalid = request;
    invalid.version = 2;
    try std.testing.expectError(error.WrongProtocolRealm, sign(invalid, key));
    invalid = request;
    invalid.principal = p.max_counter + 1;
    try std.testing.expectError(error.InvalidCounter, sign(invalid, key));
    try std.testing.expectError(error.InvalidRead, signQuery(.{ .realm = 1, .principal = 1, .kind = .{ .entries = .{ .view = 3, .key = try p.Value.init("k"), .after = try p.Value.init("k") } } }, key));
}

test "growing blocked process reads disclose metadata without claiming executable input" {
    const query: Query = .{ .realm = 1, .principal = 0, .kind = .{ .process = 1 } };
    var response: Response = .{ .realm = 1, .position = 4, .definition = current_definition, .principal_sequence = 0, .body = .{ .process = .{ .process = .{ .pid = 1, .code = 1, .failure = 2, .admitted = 1 }, .input = null } } };
    try validateResponse(response, query);
    response.body.process.input = .{ .position = 2, .ordinal = 1, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } };
    try std.testing.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.process.process.failure = null;
    try validateResponse(response, query);
    response.body.process.input = null;
    try std.testing.expectError(error.InvalidRead, validateResponse(response, query));
}

test "growing named association response binds the requested PID and exact name" {
    const t = std.testing;
    const name = try p.Value.init("data");
    const query: Query = .{ .realm = 1, .principal = 65536, .kind = .{ .association = .{ .pid = 2, .name = name } } };
    var response: Response = .{ .realm = 1, .position = 5, .definition = current_definition, .principal_sequence = 0, .body = .{ .association = .{ .pid = 2, .name = name, .resource = 3, .revision = 4, .required = true } } };
    try validateResponse(response, query);
    response.body.association.?.pid = 1;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.association.?.pid = 2;
    response.body.association.?.name = try p.Value.init("different");
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.association.?.name = name;
    response.body.association.?.revision = 5;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.association = null;
    try validateResponse(response, query);
}

test "growing responses reject mixed bases, incomplete pages and nonadvancing cursors" {
    const t = std.testing;
    const query: Query = .{ .realm = 1, .principal = 0, .kind = .{ .entries = .{ .resource = 2, .revision = 3 } } };
    var response: Response = .{ .realm = 1, .position = 4, .definition = current_definition, .principal_sequence = 0, .body = .{ .entries = .{
        .view = null,
        .resource = .{ .id = 2, .writer = 1, .owner = null, .revision = 3, .entries = 1, .deadline_ms = null },
        .page = .{ .entries = .{ .{ .key = try p.Value.init("a"), .value = .{}, .revision = 3 }, null, null, null, null, null, null, null } },
    } } };
    try validateResponse(response, query);
    const good = response;
    response.realm = 2;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response = good;
    response.body.entries.resource.revision = 4;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response = good;
    response.body.entries.page.entries[2] = .{ .key = try p.Value.init("b"), .value = .{}, .revision = 3 };
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response = good;
    response.body.entries.page.next = try p.Value.init("b");
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response = .{ .realm = 1, .position = 20, .definition = current_definition, .principal_sequence = 0, .body = .{ .resources = .{ .next = 10 } } };
    const filtered: Query = .{ .realm = 1, .principal = 0, .kind = .{ .resources = .{} } };
    try validateResponse(response, filtered); // Empty filtered pages can advance.
    try t.expectError(error.InvalidRead, validateResponse(response, .{ .realm = 1, .principal = 0, .kind = .{ .resources = .{ .after = 10, .position = 20 } } }));
    response.body = .{ .outputs = .{ .entries = .{ .{ .id = 50, .source = 1, .turn = 10, .index = 0, .destination = 2, .value = .{} }, null, null, null, null, null, null, null }, .next = 50 } };
    try validateResponse(response, .{ .realm = 1, .principal = 0, .kind = .{ .outputs = .{} } }); // Output IDs have their own sequence.
}

test "v1 turn and entries signatures match independent canonical bytes" {
    // Independently computed SHA-256 over the current canonical JSON.
    // Altering Turn or the entries-query defaults breaks retained receipts.
    const request: Request = .{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .turn = .{ .pid = 2, .generation = 3, .input = 4, .expected_revision = 0 } } };
    const query: Query = .{ .realm = 42, .principal = 0, .kind = .{ .entries = .{ .view = 5 } } };
    try std.testing.expectEqualStrings("e7e9e78ac367727caa32da9d76c9b9255bb07484e7cba3ad3af9584d15d5823e", &std.fmt.bytesToHex(try digest(request), .lower));
    try std.testing.expectEqualStrings("a96e6e181c1d13be45a03f890a5bb59e041d80f09fe58758b2584f62e8f0e723", &std.fmt.bytesToHex(try queryDigest(query), .lower));
}

test "retained version proposals and responses reject foreign duplicate and forged bases" {
    const t = std.testing;
    var request: Request = .{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .turn_with_versions = .{ .turn = .{ .pid = 2, .generation = 3, .input = 4, .expected_revision = 0, .views = .{ 5, null, null, null } }, .retain = .{ 5, null, null, null } } } };
    try validate(request);
    request.command.turn_with_versions.turn.failed = true;
    try t.expectError(error.InvalidFailure, validate(request));
    request.command.turn_with_versions.turn.failed = false;
    request.command.turn_with_versions.retain[1] = 5;
    try t.expectError(error.InvalidReadVersion, validate(request));
    request.command.turn_with_versions.retain[1] = 6;
    try t.expectError(error.InvalidReadVersion, validate(request));
    request.command.turn_with_versions.retain[1] = null;
    request.command.turn_with_versions.release[0] = .{ .pid = 3, .input = 1, .index = 0 };
    try t.expectError(error.InvalidReadVersion, validate(request));
    request.command.turn_with_versions.release[0].?.pid = 2;
    request.command.turn_with_versions.release[0].?.index = 4;
    try t.expectError(error.InvalidReadVersion, validate(request));
    request.command.turn_with_versions.release[0].?.index = 0;
    request.command.turn_with_versions.release[1] = request.command.turn_with_versions.release[0];
    try t.expectError(error.InvalidReadVersion, validate(request));
    const id: ReadVersionId = .{ .pid = 2, .input = 4, .index = 0 };
    const query: Query = .{ .realm = 42, .principal = 0, .kind = .{ .version_entries = .{ .id = id, .generation = 3 } } };
    var response: Response = .{ .realm = 42, .position = 7, .definition = current_definition, .principal_sequence = 1, .body = .{ .version_entries = .{
        .version = .{ .id = id, .resource = 3, .revision = 3, .created_at = 6 },
        .generation = 3,
        .resource = .{ .id = 3, .writer = 2, .owner = null, .revision = 3, .deadline_ms = null },
        .page = .{},
    } } };
    try validateResponse(response, query);
    response.body.version_entries.generation = 2;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.version_entries.generation = 3;
    response.body.version_entries.version.id.index = 1;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.version_entries.version.id = id;
    response.body.version_entries.resource.revision = 5;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.version_entries.resource.revision = 3;
    response.body.version_entries.page.next = try p.Value.init("row");
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.version_entries.page.next = null;
    response.body.version_entries.version.created_at = 7;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
}

test "growing identity response is scoped and cannot claim an unobserved policy" {
    const query: Query = .{ .realm = 1, .principal = 65536, .kind = .{ .identity = {} } };
    var response: Response = .{ .realm = 1, .position = 9, .definition = current_definition, .principal_sequence = 0, .body = .{ .identity = .{ .principal = 65536, .permissions = p.permission(.inspect), .pid = null, .policy_revision = 8 } } };
    try validateResponse(response, query);
    response.body.identity.principal = 2;
    try std.testing.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.identity.principal = 65536;
    response.body.identity.policy_revision = 9;
    try std.testing.expectError(error.InvalidRead, validateResponse(response, query));
}

test "bounded multi-key read validation preserves slot identity and absence" {
    const t = std.testing;
    var keys: [page_size]?p.Value = @splat(null);
    keys[0] = try p.Value.init("second");
    keys[1] = try p.Value.init("missing");
    keys[2] = try p.Value.init("first");
    const query: Query = .{ .realm = 1, .principal = 2, .kind = .{ .read_entries = .{ .resource = 3, .keys = keys } } };
    try validateQuery(query);
    var response: Response = .{ .realm = 1, .position = 10, .definition = current_definition, .principal_sequence = 0, .body = .{ .read_entries = .{ .resource = .{ .id = 3, .writer = 4, .owner = null, .revision = 7, .entries = 2, .deadline_ms = null }, .entries = @splat(null) } } };
    response.body.read_entries.entries[0] = .{ .key = keys[0].?, .value = p.Value.integer(2), .revision = 7 };
    response.body.read_entries.entries[2] = .{ .key = keys[2].?, .value = p.Value.integer(1), .revision = 6 };
    try validateResponse(response, query);
    var bad = query;
    bad.kind.read_entries.keys[1] = keys[0];
    try t.expectError(error.InvalidRead, validateQuery(bad));
    bad.kind.read_entries.keys[1] = null;
    try t.expectError(error.InvalidRead, validateQuery(bad));
    bad.kind.read_entries.keys = @splat(null);
    try t.expectError(error.InvalidRead, validateQuery(bad));
    response.body.read_entries.entries[2].?.key = keys[0].?;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
    response.body.read_entries.entries[2].?.key = keys[2].?;
    response.body.read_entries.entries[2].?.revision = 8;
    try t.expectError(error.InvalidRead, validateResponse(response, query));
}

/// Validates recorded native evidence only; this never asserts that a connector
/// performed I/O, that an observation is honest, or that remote work succeeded.
pub fn validateEffect(value: Effect, position: u64) error{InvalidRead}!void {
    if (value.id == 0 or value.pid == 0 or value.pid >= value.id or value.id >= position or position > p.max_counter or
        value.max_observations == 0 or value.max_observations > p.max_effect_observations or value.observations > value.max_observations) return error.InvalidRead;
    const attempted = value.phase != .pending and value.phase != .cancelled;
    if (attempted != (value.attempt != null) or attempted != (value.executor != null) or attempted != (value.authorization_policy != null)) return error.InvalidRead;
    if (value.attempt) |attempt| {
        if (attempt <= value.id or attempt >= position or value.executor.? > p.max_counter or value.authorization_policy.? >= attempt) return error.InvalidRead;
    }
    if ((value.observations != 0) != (value.last_observation != null)) return error.InvalidRead;
    if (value.last_observation) |observation| {
        if (!attempted or observation.input <= value.attempt.? or observation.input >= position or observation.policy_revision >= observation.input) return error.InvalidRead;
    }
    const terminal = value.phase == .observed or value.phase == .closed_unknown or value.phase == .cancelled;
    if (terminal != (value.closed_at != null) or terminal != (value.closure != null) or (value.phase == .observed) != (value.result != null)) return error.InvalidRead;
    if (value.closed_at) |input| {
        if (input <= (value.attempt orelse value.id) or input >= position) return error.InvalidRead;
        const closure = value.closure.?;
        if (closure.principal > p.max_counter or closure.policy_revision >= input) return error.InvalidRead;
        if (value.last_observation) |observation| if (observation.input > input) return error.InvalidRead;
        switch (closure.reason) {
            .observed, .observation_budget => {
                if (value.last_observation == null or value.last_observation.?.input != input or
                    value.last_observation.?.policy_revision != closure.policy_revision or closure.principal != value.executor or closure.clock_lower_ms != null) return error.InvalidRead;
                if (closure.reason == .observed) {
                    if (value.phase != .observed) return error.InvalidRead;
                } else if (value.phase != .closed_unknown or value.observations != value.max_observations) return error.InvalidRead;
            },
            .abandoned => if (value.phase != .closed_unknown or value.observations >= value.max_observations or closure.clock_lower_ms != null) return error.InvalidRead,
            .deadline => if (value.phase != .closed_unknown or value.observations >= value.max_observations or closure.clock_lower_ms == null or value.reconcile_before_ms == null or closure.clock_lower_ms.? < value.reconcile_before_ms.?) return error.InvalidRead,
            .unattempted_cancel => if (value.phase != .cancelled or closure.clock_lower_ms != null) return error.InvalidRead,
        }
    }
    switch (value.phase) {
        .pending, .cancelled => if (value.observations != 0 or value.reconcile_before_ms != null) return error.InvalidRead,
        .authorized => if (value.observations != 0) return error.InvalidRead,
        .unknown => if (value.observations == 0 or value.observations >= value.max_observations) return error.InvalidRead,
        .observed => if (value.observations == 0) return error.InvalidRead,
        .closed_unknown => {},
    }
}

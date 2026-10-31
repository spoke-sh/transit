//! Native v1 wire types with bounded operations and paged durable collections.
const std = @import("std");
const p = @import("root.zig");
pub const version = 1;
/// Contract-set fingerprint, independent of the public version label. Replace
/// this identifier on an incompatible pre-1.0 cutover, including changed stored
/// Station/query semantics. Never reuse it to reinterpret accepted history.
/// SHA-256 of transit.v1.retained-table-branches.installed-worker-rotation.2026-11-01.
pub const Definition = enum {
    @"04cd820c132773e6cd69e1d4174f1dff012f8e0f286a82dc35512327a252c6d6",

    fn spelling(bytes: []const u8) !Definition {
        if (!std.mem.eql(u8, bytes, @tagName(current_definition))) return error.InvalidEnumTag;
        return current_definition;
    }
    // Generic JSON enums accept numeric strings as ordinal tags. A contract
    // fingerprint must match its exact spelling, never enum ordinal zero.
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Definition {
        const token = try source.nextAllocMax(allocator, .alloc_if_needed, options.max_value_len.?);
        defer switch (token) {
            .allocated_string, .allocated_number => |bytes| allocator.free(bytes),
            else => {},
        };
        return switch (token) {
            .string, .allocated_string => |bytes| spelling(bytes),
            else => error.InvalidEnumTag,
        };
    }
    pub fn jsonParseFromValue(_: std.mem.Allocator, value: std.json.Value, _: std.json.ParseOptions) !Definition {
        return switch (value) {
            .string => |bytes| spelling(bytes),
            else => error.InvalidEnumTag,
        };
    }
};
pub const current_definition: Definition = @fromBackingInt(0);
/// Binary artifact fingerprint. There is no implicit definition for persisted bytes.
pub const definition_bytes: [32]u8 = blk: {
    var bytes: [32]u8 = undefined;
    _ = std.fmt.hexToBytes(&bytes, @tagName(current_definition)) catch unreachable;
    break :blk bytes;
};
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
pub const BlockRead = @import("BlockRead.zig");
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
    /// Declared read views whose resource revision must still equal the cut.
    /// Ordinary views remain snapshots; guards add no write authority.
    current_views: [turn_views]?Id = @splat(null),
    write_view: ?Id = null,
    mutations: [turn_mutations]?Mutation = @splat(null),
    blocks: p.Blocks.Mutations = @splat(null),
    outputs: [turn_outputs]?Output = @splat(null),
    effect: ?p.Value = null,
    failed: bool = false,
    /// Current original-subject requirements, independent of executor fencing.
    authorization: ?p.Authorization.Guard = null,
};
pub const Command = union(enum) {
    authorization: p.Authorization.Command,
    grant: Grant,
    revoke: Id,
    spawn: Create,
    own: struct { pid: Id, expected_generation: u64, worker: Id },
    retry: struct { pid: Id, expected_generation: u64, failure_input: Id },
    send: struct { pid: Id, value: p.Value, role: ?Id = null },
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
    /// Fence immutable candidates before a physical root collection.
    storage_fence: void,
    /// Relocate one bounded portion of current state without logical changes.
    storage_compact: void,
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
pub const SignedRequest = struct {
    request: Request,
    signature: [64]u8,
    pub fn jsonStringify(self: @This(), out: *std.json.Stringify) std.Io.Writer.Error!void {
        try @import("SignedEnvelope.zig").write(self, out);
    }
    pub const json_schema_type = @import("SignedEnvelope.zig").Wire(@This(), "request");
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        return @import("SignedEnvelope.zig").parse(@This(), "request", allocator, source, options);
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !@This() {
        return @import("SignedEnvelope.zig").fromValue(@This(), "request", allocator, value, options);
    }
};
/// Transport owns large bytes separately from the signed logical request and
/// authority record. A historical receipt needs no new physical publication.
pub const CommandEnvelope = struct {
    request: Request,
    signature: [64]u8,
    blocks: ?p.Blocks.Body = null,
    pub fn init(value: SignedRequest) @This() {
        return .{ .request = value.request, .signature = value.signature };
    }
    pub fn signed(self: *const @This()) SignedRequest {
        return .{ .request = self.request, .signature = self.signature };
    }
    pub fn jsonStringify(self: @This(), out: *std.json.Stringify) std.Io.Writer.Error!void {
        try @import("SignedEnvelope.zig").write(self, out);
    }
    pub const json_schema_type = @import("SignedEnvelope.zig").Wire(@This(), "request");
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        return @import("SignedEnvelope.zig").parse(@This(), "request", allocator, source, options);
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !@This() {
        return @import("SignedEnvelope.zig").fromValue(@This(), "request", allocator, value, options);
    }
};
pub fn blockMutations(command: Command) p.Blocks.Mutations {
    return switch (command) {
        .turn => |turn| turn.blocks,
        .turn_with_versions => |extended| extended.turn.blocks,
        else => @splat(null),
    };
}
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
    block_entries: u64 = 0,
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
        authorization: p.Authorization.Query,
        capabilities: void,
        storage: void,
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
        block_entries: BlockRead.Query,
    },
};
pub const Identity = struct { principal: Id, permissions: u16, pid: ?Id, policy_revision: u64 };
pub const SignedQuery = struct {
    query: Query,
    signature: [64]u8,
    pub fn jsonStringify(self: @This(), out: *std.json.Stringify) std.Io.Writer.Error!void {
        try @import("SignedEnvelope.zig").write(self, out);
    }
    pub const json_schema_type = @import("SignedEnvelope.zig").Wire(@This(), "query");
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        return @import("SignedEnvelope.zig").parse(@This(), "query", allocator, source, options);
    }
    pub fn jsonParseFromValue(allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) !@This() {
        return @import("SignedEnvelope.zig").fromValue(@This(), "query", allocator, value, options);
    }
};
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
    immutable_blocks: bool = false,
    block_record_budget: u16 = p.Blocks.max_records,
    block_byte_budget: u32 = p.Blocks.max_batch_bytes,
    leased_snapshots: bool = false,
    snapshot_read: bool = false,
    worker_rotation: bool = false,
    declarative_authorization: bool = false,
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
        authorization: p.Authorization.Result,
        capabilities: Capabilities,
        storage: p.Storage.Observation,
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
        block_entries: BlockRead.Result,
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
    _ = try p.Blocks.validate(turn.blocks);
    if (turn.failed and turn.blocks[0] != null) return error.InvalidFailure;
    if (turn.authorization) |guard| try guard.validate();
    for (turn.current_views, 0..) |slot, i| if (slot) |id| {
        if (id == 0 or std.mem.indexOfScalar(?Id, &turn.views, id) == null) return error.InvalidStateView;
        for (turn.current_views[0..i]) |previous| if (previous == id) return error.InvalidStateView;
    };
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
        .authorization => |q| try p.Authorization.validateQuery(q),
        .inspection => |q| try Inspection.validate(q),
        .snapshot_read => |q| try SnapshotRead.validate(q),
        .block_entries => |q| try BlockRead.validate(q),
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
        .authorization => |q| try p.Authorization.validateResult(response.body.authorization, q, query.realm, query.principal),
        .storage => try response.body.storage.validate(),
        .delivery => if (response.body.delivery.next == 0) return error.InvalidRead,
        .inspection => try Inspection.validatePage(response.body.inspection, query, response.position),
        .snapshot_read => |q| try SnapshotRead.validateResult(response.body.snapshot_read, q),
        .block_entries => |q| try BlockRead.validateResult(response.body.block_entries, q),
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
                caps.version_change_budget != version_changes or caps.block_record_budget != p.Blocks.max_records or caps.block_byte_budget != p.Blocks.max_batch_bytes or
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

test "contract definitions reject numeric enum aliases in both JSON decoders" {
    const t = std.testing;
    for ([_][]const u8{ "0", "\"0\"", "\"0000000000000000000000000000000000000000000000000000000000000000\"", "\"previous-v1-definition\"", "\"4327831d2a07273573f6c7d707c5bb1456581509ab3dc175820f940392819f3d\"", "\"53974aff8eb79a045fdec030d2817d9df3c98c2fa755f437d503bb73edc5446b\"", "\"d90afcbeedc1b0e10af843565045bbffad8067809da44ced09266a887bf2e248\"", "\"f6e7696ff8788e92814cd877a989121f7d2a5089c445b5155de22eff01f270d2\"", "\"8d33a5642dfcc05496cfe1b6558cdc07246ec5f17790750a5f28cfe9c81b3a8f\"", "\"f4155ebec2d3eae38ccb8894ab250a29138ef35d84792d83b4a9150e44a5b6fb\"", "\"901eb98b9b23d159d20c3216ca2c160c0cf303c8b3f751d8ace5c91562904fa8\"", "\"dec0151b4f9d664f75113d65fd43b3ba9a47f07ffb28fdda7e4b91b3d369bb60\"", "\"e8677230beea38e3f824c3413009a123a2386f7c6c7a1cfcaa7efe51e8486c78\"", "\"9454a601d54b923917307ccca9c9c70235378f011aa17a8073013eb0ddfa2c56\"", "\"e90c811e59e082a12accb35d8b7d4e4217ed1db5e023c340944b773f1cdd5e2a\"", "\"554fe1fda3e411cf8699db84285f655ae459494c04192fb6dfa66b29b00c12fa\"", "\"c7e556954e7f6e9cf79a65abf9d082372ea626174ca7a6b4422ae25083dffc8b\"", "\"312fcb8d609365bc55ffa7ddbe0242493e843256539f96889a51a2fba0f2b9c0\"", "\"1dbbcfbb8c493a1e1a1ef340811178dfb7068830b58f9412d97881d61ab75a9f\"", "\"67f02f8b95384ab69ae024f8dd8bc403aa7b358024fd345b4e28e538e392a15e\"", "\"c7446846aac6473237f91be61e004180fd8386136217c4cd09160b382e34cccd\"", "null", "false", "[]", "{}" }) |bytes| {
        try t.expectError(error.InvalidEnumTag, std.json.parseFromSlice(Definition, t.allocator, bytes, .{}));
        const value = try std.json.parseFromSlice(std.json.Value, t.allocator, bytes, .{});
        defer value.deinit();
        try t.expectError(error.InvalidEnumTag, std.json.parseFromValue(Definition, t.allocator, value.value, .{}));
    }
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, current_definition, .{});
    defer t.allocator.free(bytes);
    const typed = try std.json.parseFromSlice(Definition, t.allocator, bytes, .{});
    defer typed.deinit();
    try t.expectEqual(current_definition, typed.value);
    const value = try std.json.parseFromSlice(std.json.Value, t.allocator, bytes, .{});
    defer value.deinit();
    const decoded = try std.json.parseFromValue(Definition, t.allocator, value.value, .{});
    defer decoded.deinit();
    try t.expectEqual(current_definition, decoded.value);
}

test "signed wire envelopes require definitions and preserve strict JSON shapes" {
    const t = std.testing;
    inline for (.{
        .{ SignedRequest, "request", SignedRequest{ .request = .{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .send = .{ .pid = 3, .value = try .init("x") } } }, .signature = @splat(0) } },
        .{ SignedRequest, "request", SignedRequest{ .request = .{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .runtime_intent = .{ .pid = 3, .expected_revision = 0, .instance = @splat(1), .resource = @splat(2), .workload = @splat(3) } } }, .signature = @splat(0) } },
        .{ SignedQuery, "query", SignedQuery{ .query = .{ .realm = 42, .principal = 0, .kind = .{ .open_snapshot = .{ .resource = 7, .nonce = @splat(105) } } }, .signature = @splat(0) } },
    }) |case| {
        const T = case[0];
        // Real native senders and saved-work owners use ordinary std.json.
        // UTF-8-compatible byte arrays must still survive the strict decoder.
        const bytes = try std.json.Stringify.valueAlloc(t.allocator, case[2], .{});
        defer t.allocator.free(bytes);
        const parsed = try std.json.parseFromSlice(T, t.allocator, bytes, .{});
        defer parsed.deinit();
        try t.expectEqualDeep(case[2], parsed.value);
        const wrapped = try std.json.Stringify.valueAlloc(t.allocator, .{ .saved = case[2] }, .{});
        defer t.allocator.free(wrapped);
        const recovered = try std.json.parseFromSlice(struct { saved: T }, t.allocator, wrapped, .{});
        defer recovered.deinit();
        try t.expectEqualDeep(case[2], recovered.value.saved);
        var tree = try std.json.parseFromSlice(std.json.Value, t.allocator, bytes, .{});
        defer tree.deinit();
        const arena = tree.arena.allocator();
        const body = tree.value.object.getPtr(case[1]).?;
        const definition = body.object.get("definition").?;
        try t.expect(body.object.swapRemove("definition"));
        try t.expectError(error.MissingField, std.json.parseFromValue(T, t.allocator, tree.value, .{}));
        const missing = try std.json.Stringify.valueAlloc(t.allocator, tree.value, .{});
        defer t.allocator.free(missing);
        try t.expectError(error.MissingField, std.json.parseFromSlice(T, t.allocator, missing, .{}));
        try t.expectError(error.MissingField, p.Json.parseFromSlice(T, t.allocator, missing));
        const saved = try std.fmt.allocPrint(t.allocator, "{{\"signed\":{s}}}", .{missing});
        defer t.allocator.free(saved);
        try t.expectError(error.MissingField, std.json.parseFromSlice(struct { signed: T }, t.allocator, saved, .{}));
        for ([_][]const u8{ "0", "previous-v1-definition", "a28555784e076674c14c347f2302940983d53af7c9253813b7c5f37b1dccfbd6" }) |foreign| {
            try body.object.put(arena, "definition", .{ .string = foreign });
            try t.expectError(error.UnexpectedToken, std.json.parseFromValue(T, t.allocator, tree.value, .{}));
        }
        try body.object.put(arena, "definition", definition);
        const signature = tree.value.object.get("signature").?;
        try body.object.put(arena, "unknown", .{ .bool = true });
        try t.expectError(error.UnknownField, std.json.parseFromValue(T, t.allocator, tree.value, .{}));
        try t.expect(body.object.swapRemove("unknown"));
        try tree.value.object.put(arena, "signature", .{ .string = &@as([64]u8, @splat(105)) });
        try t.expectError(error.UnexpectedToken, std.json.parseFromValue(T, t.allocator, tree.value, .{}));
        if (T == SignedQuery) {
            try tree.value.object.put(arena, "signature", signature);
            const snapshot = body.object.getPtr("kind").?.object.getPtr("open_snapshot").?;
            try snapshot.object.put(arena, "nonce", .{ .string = "iiiiiiiiiiiiiiii" });
            try t.expectError(error.UnexpectedToken, std.json.parseFromValue(T, t.allocator, tree.value, .{}));
        }
    }
    // This is unsigned authoring input, not a saved or received signed request.
    const authored = try std.json.parseFromSlice(Query, t.allocator, "{\"realm\":42,\"principal\":0,\"kind\":{\"identity\":{}}}", .{});
    defer authored.deinit();
    try t.expectEqual(current_definition, authored.value.definition);
}

test "signed schema reflection requires the same explicit definition as decoding" {
    const t = std.testing;
    inline for (.{ .{ SignedRequest, "request" }, .{ SignedQuery, "query" } }) |case| {
        inline for (.{ false, true }) |recursive| {
            var output: std.Io.Writer.Allocating = .init(t.allocator);
            defer output.deinit();
            var out: std.json.Stringify = .{ .writer = &output.writer };
            if (recursive) try p.Schema.writeRecursive(case[0], &out, .{ .safe_integers = true }) else try p.Schema.write(case[0], &out, .{ .safe_integers = true });
            const schema = try std.json.parseFromSlice(std.json.Value, t.allocator, output.written(), .{});
            defer schema.deinit();
            const root = if (recursive) schema.value.object.get("$defs").?.object.get("T0").? else schema.value;
            const body = root.object.get("properties").?.object.get(case[1]).?.object;
            var found = false;
            for (body.get("required").?.array.items) |name| {
                if (std.mem.eql(u8, "definition", name.string)) found = true;
            }
            try t.expect(found);
            try t.expect(body.get("x-transit-defaults").?.object.get("definition") == null);
        }
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
        // Before tagged catalog assertions and SQL unchanged outcomes.
        "b08ae0e187823f4f869791e8b1cab5d42dbe8a54db6652855eca8562cf6404b9",
        // Before prepared finite requests and current-capture selection.
        "1d30f28e62da251490d698d6ccd67d4baeeb128fca3478f6518b6aa131f9bf20",
        // Before direct Table watches and explicit retained result positions.
        "38fb0433e2dbce32b39167abb988460d09b813d8f2de519e78fbb8ca732b40e8",
        // Before mandatory direct-Table bootstrap and dedicated registration.
        "c0fdedd9d2abcfd2c2ab0d0bfccf9bb9bd67c3c8eb29f8e9dc0a10e9a4ee42ba",
        // Before mandatory Table operation roots and matched/changed outcomes.
        "361f2e32d404b9fd77db6e4ca004472e8c58c44d7786f49daf622008a3012d4a",
        "b801d844954d7d395d6af53ac922cc07f39dd158f77d9c45ce62c6624178e47e",
        "a6ca7686cc7bdd39ff47373f000221d6e0ccf91ed1ac2cf4c56e0f60fb250f92",
        "04fb672449029157eed66ce316d0d55d0b12bbbeddb07c3f337fb9f7b95ab036",
        "b4c2e47f8dac6fff59724ee96a6e95af0134c065b9895eb5303c4a1155f09b04",
        "ca3da62f10ff4dbe279871b62429d49d235b7f821c23cf0dee497b02c683485b",
        "03cfbcd3ac01907b74674fd0877c0a718d76974e1ea320fa1f9dc7ab15ccd488",
        "25f5ba20fd4d8dc23f8be8713b2b8468dc23a65b0aa58bb99f983face981d9c7",
        // Before mandatory ordered Table roots and source/interval-bound key ranges.
        "7eb140320f47f8c8c3dd96ee6f74a43e6daaf68c4ec4c3639e8b0fbc900aca8f",
        // Before exact Table declarations, schema-independent names and retirement.
        "9ecf03c83a3bd5e82dc87da5756ba71a1a2ed3d7ab1e8a9dbbb2033f6f87d66c",
        "228a44d0a7345601f87f99d680751ca3ece4a59aaab980b80bba2dfb2a0d1830",
        // Fixed two-column Tables, before general schema/lifecycle and ABI cutover.
        "57343ef043d4dc7f9612a7ca3309e9218dd527c0f3826a519ff0d29b761b4a82",
        // Before retained sources carried exact native publication authority.
        "64510390ce1d02e9e93fc04bf00554ca4625ae8b895134fc8cb04e3f5143a96c",
        // Before mandatory neutral encoding/collation fields and native SDK layouts.
        "d5cad2104285ea53f190c0c090bb3ab40db2f6555970d251bfa5361b2ffaf964",
        // Before mandatory scoped read delegations and executor authentication.
        "f2f9eecaf384f4ef6dde55ad0af62bf368ff17e76cfe0877665d1070a8460982",
        // Before durable Table branch directory and retention ownership.
        "d819613421eddad994752d367fa40948abe9914ffc0f10ee13b18c2b875d3e8e",
        // Before lossless column codecs and mandatory physical page definitions.
        "dbeaf8ee99483d030ed06e8779be25af19f74d7c794591e180c8906a55b456dd",
        // Before mandatory binary storage definitions and keyless row identity.
        "a836b4860f5817b78c936b1ff8ee2e13c973b7e9f73dfc5003a0820ef8194262",
        "9438134d5552df1afc0043aab73220112135bc05c260525d7598f6ba694cc31b",
        // Before mandatory local WAL metadata and exact data lifecycle bindings.
        "4621694a96edf0779fc0f8213802a43d2f4b179421f00f868a06cb23c50b567a",
        // Pre-compact immutable page definition.
        "9d3f4b28d873a0f082bca76aca29ae36f7d4afe9b337484a161323819cd67db9",
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
        "ff8b5156ecbea7eba6dd375379442a334bf2eaf7f7b2e2f1eff462a5a554554a",
        "2751c5ead29471b9675530a20cd0e364368ba79dee3ec6f00f8806d0accb94e7",
        "692358a0bda42413cb14638010c0adea7edaa238aff1275e9557fcb38a37e741",
        "4dab48676c92875019edb9a3c8e3e6e9071ebfe22000fe513c5efe66b16734f6",
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
        // Coupled native credential/permission records before declarative roles.
        "138bd4043de660b50db60d909ab7e29c3d1ab64b1b0658a8a8e000fd15d72365",
        // Role graph before authenticated service claims and publication guards.
        "9019f430927fc05d487fc716b7a33d870909e0c00a8808799d085b09658aa246",
        "3e49cab638f15a788cc7a47a378b1956f80ed47e5366d64134cb22f3cd332b51",
        // Application Table continuations before native original-subject guards.
        "dbabceb7ec736d0ab8c2874fb404249f45eea6ad9666a183a7e0a4125f6c4986",
        // SQL account records before retained schema/role and private reader identity.
        "d70f7dc070a57a2da55ff74f938297ae6c48404d2b648aa3fdd7b214c481939b",
        // Serving reads before bound current original-subject proofs.
        "84cad99694b96f29d0b8bff1529036006166000d56bc5889b19f6760ef0a6373",
        // Mediation recovery before retained signer and exact send receipts.
        "3f918c9828cf632c52018e094e23cf4384d2c2fe288009aeea4c9aef1b696bb3",
        // Original-subject queries before recoverable administration semantics.
        "3dccf1d571d3e126c9b2d0c4f5f7fe474b3b69ec93bfbcd169808ccb2e9b990a",
        "ac0e81dfaadf725c78718db69d4f29fddf460007918b8e8ea12d518179c0b67d",
        "38d50a6745f3bafd7e25f1e8300af4fd054818a0a7b90426786b1294fd06b727",
        "f5aa69446cb85fcbc2e5d0e3f56f2af91b86d99c481d8bdc53c033c4a95d84a9",
        // Local configuration before retained opt-in SQL enrollment.
        "e8b8b051371208d375f870a3f294b843b3f9ae4928874da3491cc77ebf0341bc",
        // TLS-only SQL records before explicit local trust and owner bootstrap.
        "1f58b18465617d0a60a1ca4139d0ecf5c0dde7c4ed64d503d21267c21545ab10",
        // Before retained direct Table change-reader checkpoints.
        "819b12b133443f6c0a269c818da0698cb222ac4cad1d7010da3ac602000a0f55",
        // Before role-bound single-executable local installation identities.
        "654ca199c506604af21873605129e34e18c1c349a42643ece06ed0da9dca7a93",
        // Before SQL namespace references and namespace terminal/completion kinds.
        "f444c2a15245cf6a5852c727ebf3922f214a7fb8d3e078ea2d92b6b1eb668463",
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
    var encoder: std.json.Stringify = .{ .writer = &writer };
    p.Json.write(value, &encoder) catch return error.RecordTooLarge;
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
    const Fixture = struct { turn: struct { sha256: []const u8 }, entries: struct { sha256: []const u8 } };
    const fixture = try std.json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixtures/authorization-v1.json"), .{ .ignore_unknown_fields = true });
    defer fixture.deinit();
    try std.testing.expectEqualStrings(fixture.value.turn.sha256, &std.fmt.bytesToHex(try digest(request), .lower));
    try std.testing.expectEqualStrings(fixture.value.entries.sha256, &std.fmt.bytesToHex(try queryDigest(query), .lower));
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

test "complete bulk descriptor and metadata budgets fit the bounded canonical request" {
    var turn: Turn = .{ .pid = p.max_counter, .generation = p.max_counter, .input = p.max_counter, .expected_revision = p.max_counter };
    for (&turn.mutations, 0..) |*slot, i| {
        var key: [key_bytes]u8 = @splat(255);
        key[0] = @intCast(i);
        slot.* = .{ .key = try .init(&key), .value = try .init(&@as([p.Value.max_bytes]u8, @splat(255))) };
    }
    for (&turn.blocks, 0..) |*slot, i| {
        var key: [key_bytes]u8 = @splat(255);
        key[0] = @intCast(i);
        slot.* = .{ .key = try .init(&key), .value = .{ .bytes = 0, .digest = @splat(255) } };
    }
    for (&turn.outputs) |*slot| slot.* = .{ .pid = p.max_counter, .value = try .init(&@as([p.Value.max_bytes]u8, @splat(255))) };
    const request: Request = .{ .realm = p.max_counter, .principal = p.max_counter, .sequence = p.max_counter, .command = .{ .turn = turn } };
    const bytes = try p.Json.valueAlloc(std.testing.allocator, request);
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len <= p.max_entry_bytes);
    _ = try digest(request);
    // An ASCII-compatible fixed array remains an array in canonical signing,
    // just as in the generated wire schema and an independent implementation.
    const query: Query = .{ .realm = 1, .principal = 0, .kind = .{ .open_snapshot = .{ .resource = 1, .nonce = "abcdefghijklmnop".* } } };
    const canonical = try p.Json.valueAlloc(std.testing.allocator, query);
    defer std.testing.allocator.free(canonical);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(query_domain);
    hasher.update(canonical);
    try std.testing.expectEqualDeep(hasher.finalResult(), try queryDigest(query));
}

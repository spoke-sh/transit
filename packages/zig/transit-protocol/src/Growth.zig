//! M10 growing-profile wire types. Kept separate from the supported v2 profile;
//! declaring a contract does not advertise service support or migrate history.
const std = @import("std");
const p = @import("root.zig");
pub const version = 3;
pub const Id = u64;
pub const request_domain = "transit.request.v3\x00";
pub const query_domain = "transit.query.v3\x00";
pub const page_size = 8;
pub const turn_views = 4;
pub const turn_mutations = 4;
pub const turn_outputs = 4;
pub const key_bytes = 32;
pub const view_lifetime_ms = 60_000;

pub const Grant = struct { subject: Id, public_key: [32]u8, permissions: u16, pid: ?Id = null };
pub const Create = struct { code: u32 = 1, work_before_ms: ?u64 = null, settle_before_ms: ?u64 = null };
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
    send: struct { pid: Id, value: p.Value },
    begin_turn: struct { pid: Id, generation: u64, input: Id },
    turn: Turn,
    terminate: Id,
    expire: Id,
    create_resource: struct { writer: Id, owned: bool = true, deadline_ms: ?u64 = null },
    grant_resource: struct { resource: Id, subject: Id, permissions: u8 },
    associate: struct { pid: Id, name: p.Value, expected_revision: u64 = 0, resource: ?Id, required: bool = true },
    open_view: struct { pid: Id, generation: u64, input: Id, expected_revision: u64, resource: Id, revision: u64, deadline_ms: u64 },
    close_view: struct { pid: Id, view: Id },
    retire_resource: Id,
    expire_resource: Id,
    deliver: Id,
    dispatch: struct { pid: Id, effect: Id, reconcile_before_ms: ?u64 = null, max_observations: u16 = p.max_effect_observations },
    observe: struct { pid: Id, effect: Id, attempt: Id, result: ?p.Value },
    close_effect: struct { pid: Id, effect: Id, attempt: Id, reason: enum { abandoned, deadline } = .abandoned },
};
pub const Request = struct { version: u32 = version, realm: Id, principal: Id, sequence: u64, command: Command };
pub const SignedRequest = struct { request: Request, signature: [64]u8 };
pub const Origin = union(enum) {
    external: struct { principal: Id, policy_revision: u64 },
    process: struct { pid: Id, turn: Id, output: Id },
    effect: struct { id: Id, attempt: Id, executor: Id },
};
pub const Input = struct { position: Id, ordinal: u64, value: p.Value, origin: Origin };
pub const Process = struct {
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
};
pub const Resource = struct {
    id: Id,
    writer: Id,
    owner: ?Id,
    revision: u64,
    entries: u64 = 0,
    deadline_ms: ?u64,
    phase: enum { active, retired } = .active,
    retired_at: ?Id = null,
};
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
pub const Effect = struct {
    id: Id,
    pid: Id,
    payload: p.Value,
    phase: enum { pending, authorized, unknown, observed, cancelled, closed_unknown } = .pending,
    attempt: ?Id = null,
    executor: ?Id = null,
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
pub const Query = struct {
    version: u32 = version,
    realm: Id,
    principal: Id,
    kind: union(enum) {
        capabilities: void,
        process: Id,
        resource: Id,
        view: Id,
        processes: struct { after: ?Id = null, position: ?Id = null },
        resources: struct { after: ?Id = null, position: ?Id = null },
        associations: struct { pid: Id, after: ?Id = null, position: ?Id = null },
        entries: struct { view: ?Id = null, resource: ?Id = null, revision: ?u64 = null, key: ?p.Value = null, after: ?p.Value = null },
        outputs: struct { after: ?Id = null, position: ?Id = null },
        effects: struct { pid: Id, after: ?Id = null, position: ?Id = null },
    },
};
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
    // Unsupported lifecycle/provider/cleanup extensions must remain explicit.
    runtime_bindings: bool = false,
    history_reclamation: bool = false,
    station: bool = false,
};
pub const Response = struct {
    version: u32 = version,
    realm: Id,
    position: Id,
    principal_sequence: u64,
    body: union(enum) {
        capabilities: Capabilities,
        process: struct { process: Process, input: ?Input },
        resource: Resource,
        view: View,
        processes: Batch(Process, Id),
        resources: Batch(Resource, Id),
        associations: Batch(Association, Id),
        entries: struct { view: ?View, resource: Resource, page: Batch(Entry, p.Value) },
        outputs: Batch(Outbox, Id),
        effects: Batch(Effect, Id),
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
        .associate => |c| try validateKey(c.name),
        .turn => |c| {
            for (c.mutations, 0..) |slot, i| if (slot) |mutation| {
                try validateKey(mutation.key);
                for (c.mutations[0..i]) |previous| if (previous) |other| if (other.key.eql(mutation.key)) return error.DuplicateStateKey;
            };
        },
        else => {},
    }
}
pub fn validateQuery(query: Query) !void {
    if (query.version != version or query.realm == 0) return error.WrongProtocolRealm;
    try counters(query);
    switch (query.kind) {
        .entries => |c| {
            if ((c.view == null) == (c.resource == null) or (c.resource == null) != (c.revision == null)) return error.InvalidRead;
            if (c.key != null and c.after != null) return error.InvalidRead;
            if (c.key) |key| try validateKey(key);
            if (c.after) |key| try validateKey(key);
        },
        inline .processes, .resources, .associations, .outputs, .effects => |c| if (c.after != null and c.position == null) return error.InvalidRead,
        else => {},
    }
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
    const legacy = p.digest(.{ .realm = 1, .principal = 1, .sequence = 1, .command = .{ .send = .{ .pid = 2, .value = .{} } } });
    try std.testing.expect(!std.mem.eql(u8, &legacy, &try digest(request)));
    try std.testing.expectError(error.InvalidRead, signQuery(.{ .realm = 1, .principal = 1, .kind = .{ .entries = .{ .view = 3, .key = try p.Value.init("k"), .after = try p.Value.init("k") } } }, key));
}

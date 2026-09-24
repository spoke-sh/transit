//! State-resource profile v1. Values are opaque; all returned bytes are owned.
const std = @import("std");
const p = @import("root.zig");
pub const version = 1;
pub const max_resources = 4;
pub const max_entries = 32;
pub const max_associations = 64;
pub const max_views = 4;
pub const max_mutations = 4;
pub const max_key_bytes = 32;
pub const page_size = 8;
pub const max_view_ms = 60_000;
pub const Permission = enum(u3) { inspect, read, write };
pub const all_permissions: u8 = 7;
pub fn permission(value: Permission) u8 {
    return @as(u8, 1) << @backingInt(value);
}
pub const Resource = struct {
    id: u64,
    writer: u64,
    owner: ?u64,
    revision: u64,
    deadline_ms: ?u64,
    /// Null retains history indefinitely; zero opts into immediate safe trim.
    /// Positive durations are minimum history ages, not entry TTLs.
    history_ms: ?u32,
    changed_ms: u64 = 0,
    phase: enum { active, retired, reclaimed } = .active,
    retired_at: ?u64 = null,
    last_turn: ?u64 = null,
};
pub const Association = struct {
    pid: u64,
    name: p.Value,
    resource: u64,
    revision: u64,
    required: bool,
};
pub const Entry = struct { key: p.Value, value: p.Value, revision: u64 };
pub const Mutation = struct { key: p.Value, value: ?p.Value };
pub const View = struct {
    id: u64,
    pid: u64,
    principal: u8,
    generation: u64,
    input: u64,
    process_revision: u64,
    resource: u64,
    revision: u64,
    deadline_ms: u64,
};
pub const Create = struct {
    writer: u64,
    /// PID-owned by the writer, or independently owned when false.
    owned: bool = true,
    deadline_ms: ?u64 = null,
    history_ms: ?u32 = null,
};
pub const Associate = struct {
    pid: u64,
    name: p.Value,
    expected_revision: u64 = 0,
    /// Null conditionally removes an association; names are not global aliases.
    resource: ?u64,
    required: bool = true,
};
pub const Open = struct {
    pid: u64,
    generation: u64,
    input: u64,
    expected_revision: u64,
    resource: u64,
    revision: u64,
    deadline_ms: u64,
};
pub const Turn = struct {
    turn: p.Turn,
    /// Each view fixes one resource revision and belongs to this activation/input.
    views: [max_views]?u64 = @splat(null),
    /// One writable resource, identified by an included view; null is read-only.
    write_view: ?u64 = null,
    mutations: [max_mutations]?Mutation = @splat(null),
};
pub const Command = union(enum) {
    create: Create,
    grant: struct { resource: u64, subject: u8, permissions: u8 },
    associate: Associate,
    open: Open,
    close: struct { pid: u64, view: u64 },
    turn: Turn,
    retire: u64,
    expire: u64,
    reclaim: u64,
};
pub const Query = struct {
    version: u32 = version,
    realm: u64,
    principal: u8,
    kind: enum { capabilities, resources, associations, entries, view },
    pid: ?u64 = null,
    resource: ?u64 = null,
    view: ?u64 = null,
    key: ?p.Value = null,
    cut: ?p.Inspection.Cut = null,
    after: u16 = 0,
};
pub const SignedQuery = struct { query: Query, signature: [64]u8 };
pub const Capabilities = struct {
    resources: u16 = max_resources,
    keys_per_resource: u16 = max_entries,
    associations: u16 = max_associations,
    active_views: u16 = max_views,
    mutations_per_turn: u16 = max_mutations,
    key_bytes: u16 = max_key_bytes,
    value_bytes: u16 = p.Value.max_bytes,
    page_entries: u16 = page_size,
    view_ms: u32 = max_view_ms,
};
pub const Page = struct {
    version: u32 = version,
    realm: u64,
    principal_sequence: u64,
    reader: @FieldType(p.Inspection.Page, "reader"),
    kind: @FieldType(Query, "kind"),
    cut: p.Inspection.Cut,
    capabilities: ?Capabilities = null,
    next: ?u16 = null,
    resources: [page_size]?Resource = @splat(null),
    associations: [page_size]?Association = @splat(null),
    entries: [page_size]?Entry = @splat(null),
    view: ?View = null,
};
pub fn key(value: p.Value) !void {
    try value.validate();
    if (value.slice().len == 0 or value.slice().len > max_key_bytes) return error.InvalidStateKey;
}
pub fn validate(command: Command) !void {
    switch (command) {
        .associate => |c| try key(c.name),
        .turn => |c| {
            try p.validate(.{ .realm = 1, .principal = 0, .sequence = 1, .command = .{ .turn = c.turn } });
            for (c.mutations) |slot| if (slot) |mutation| {
                try key(mutation.key);
                if (mutation.value) |value| try value.validate();
            };
        },
        else => {},
    }
}
pub fn validateQuery(q: Query) !void {
    if (q.version != version or q.realm == 0 or q.realm > p.max_counter or q.principal >= p.max_principals) return error.InvalidRead;
    if (q.key) |value| try key(value);
    switch (q.kind) {
        .capabilities => if (q.pid != null or q.resource != null or q.view != null or q.key != null or q.after != 0 or q.cut != null) return error.InvalidRead,
        .resources => if (q.pid != null or q.view != null or q.key != null) return error.InvalidRead,
        .associations => if (q.pid == null or q.resource != null or q.view != null or q.key != null) return error.InvalidRead,
        .entries => if (q.pid != null or q.resource == null or q.view != null) return error.InvalidRead,
        .view => if (q.pid == null or q.view == null or q.resource != null) return error.InvalidRead,
    }
    if (q.after != 0 and q.cut == null) return error.InvalidRead;
    if (q.key != null and q.after != 0) return error.InvalidRead;
    for ([_]?u64{ q.pid, q.resource, q.view }) |id| if (id) |value| if (value == 0 or value > p.max_counter) return error.InvalidRead;
    if (q.cut) |cut| if (cut.position > p.max_counter or cut.policy_revision > p.max_counter or cut.retained_from > cut.position) return error.InvalidRead;
}
pub fn digest(q: Query) [32]u8 {
    var bytes: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(q, .{}, &writer) catch unreachable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("rey.transit.state.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn sign(q: Query, pair: p.Ed25519.KeyPair) !SignedQuery {
    try validateQuery(q);
    return .{ .query = q, .signature = (try pair.sign(&digest(q), null)).toBytes() };
}

test "state read fixture has canonical bytes and an independent domain hash" {
    const Fixture = struct { canonical: []const u8, sha256: []const u8 };
    var fixture = try std.json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixtures/state-v1.json"), .{});
    defer fixture.deinit();
    var parsed = try std.json.parseFromSlice(Query, std.testing.allocator, fixture.value.canonical, .{});
    defer parsed.deinit();
    const bytes = try std.json.Stringify.valueAlloc(std.testing.allocator, parsed.value, .{});
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings(fixture.value.canonical, bytes);
    try std.testing.expectEqualStrings(fixture.value.sha256, &std.fmt.bytesToHex(digest(parsed.value), .lower));
    const pair = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const signed = try sign(parsed.value, pair);
    try p.Ed25519.Signature.fromBytes(signed.signature).verify(&digest(parsed.value), pair.public_key);
    var changed = parsed.value;
    changed.principal = 1;
    try std.testing.expectError(error.SignatureVerificationFailed, p.Ed25519.Signature.fromBytes(signed.signature).verify(&digest(changed), pair.public_key));
}

test "bounded state turn fits the journal record with ordinary outputs" {
    const value = try p.Value.init(&@as([p.Value.max_bytes]u8, @splat(255)));
    const name = try p.Value.init(&@as([max_key_bytes]u8, @splat(255)));
    const command: Command = .{ .turn = .{
        .turn = .{ .pid = p.max_counter, .generation = p.max_counter, .input = p.max_counter, .expected_revision = p.max_counter, .result = value, .effect = value, .permit = p.max_counter, .outputs = @splat(.{ .pid = p.max_counter, .value = value }) },
        .views = @splat(p.max_counter),
        .write_view = p.max_counter,
        .mutations = @splat(.{ .key = name, .value = value }),
    } };
    const bytes = try std.json.Stringify.valueAlloc(std.testing.allocator, command, .{});
    defer std.testing.allocator.free(bytes);
    // Reserve room for the signed command's request/record/time/admission wrapper.
    try std.testing.expect(bytes.len + 1024 < p.max_entry_bytes);
}

test "keys and read shape reject malformed or ambiguous access" {
    try std.testing.expectError(error.InvalidStateKey, key(.{}));
    try std.testing.expectError(error.InvalidStateKey, key(try p.Value.init(&@as([max_key_bytes + 1]u8, @splat(1)))));
    try std.testing.expectError(error.InvalidRead, validateQuery(.{ .realm = 1, .principal = 0, .kind = .view, .pid = 1 }));
    try std.testing.expectError(error.InvalidRead, validateQuery(.{ .realm = 1, .principal = 0, .kind = .entries, .resource = 1, .after = 1 }));
}

test "state profile rejects mutation arrays beyond one bounded resource batch" {
    try std.testing.expectError(error.UnexpectedToken, std.json.parseFromSlice(Turn, std.testing.allocator,
        \\{"turn":{"pid":1,"generation":1,"input":2,"result":""},"write_view":[3,4]}
    , .{}));
    try std.testing.expectError(error.UnknownField, std.json.parseFromSlice(Turn, std.testing.allocator,
        \\{"turn":{"pid":1,"generation":1,"input":2,"result":""},"write_resources":[3,4]}
    , .{}));
}

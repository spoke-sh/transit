//! Read-only, domain-separated inspection v1. All response values own their bytes.
const std = @import("std");
const p = @import("root.zig");
pub const page_size = 16;
pub const scan_limit = 128;
pub const Resource = enum { processes, process, mailbox, outbox, effects, payloads, history };
pub const Cut = struct { position: u64, policy_revision: u64, retained_from: u64 };
pub const Query = struct {
    version: u32 = 1,
    realm: u64,
    principal: u8,
    resource: Resource,
    pid: ?u64 = null,
    /// Exclusive authority tail. Continuations expire on any authority change.
    cut: ?Cut = null,
    /// Array slot for catalogs; journal position for history/mailbox.
    after: u64 = 0,
};
pub const SignedQuery = struct { query: Query, signature: [64]u8 };
pub const Event = struct {
    position: u64,
    pid: u64,
    kind: std.meta.Tag(p.Command),
    lifecycle_action: ?std.meta.Tag(p.Lifecycle.Command) = null,
    policy_revision: u64,
    input: ?u64 = null,
    effect: ?u64 = null,
    output: ?u64 = null,
    value: ?p.Value = null,
    failed: bool = false,
    generation: ?u64 = null,
    mailbox_status: ?enum { pending, consumed, cancelled } = null,
    /// An admission is distinct from an attempted delivery or observation.
    admitted: bool = false,
    /// Only authority clock samples are event time; most operations have none.
    unix_ms: ?u64 = null,
    clock_error_ms: ?u32 = null,
};
pub const Page = struct {
    version: u32 = 1,
    realm: u64,
    resource: Resource,
    pid: ?u64,
    cut: Cut,
    last_collection: ?u64 = null,
    reader: struct { principal: u8, permissions: u16, pid: ?u64 },
    next: ?u64 = null,
    /// Completion of this query at the cut, not a claim of complete history.
    complete: bool = true,
    history: enum { retained, prefix_reclaimed },
    scanned: u16 = 0,
    processes: [page_size]?p.ProcessView = @splat(null),
    events: [page_size]?Event = @splat(null),
    outbox: [page_size]?p.Outbox = @splat(null),
    effects: [page_size]?p.Effect = @splat(null),
    payloads: [page_size]?p.Payload = @splat(null),
};
pub fn validate(q: Query) !void {
    if (q.version != 1 or q.realm == 0 or q.realm > p.max_counter or q.principal >= p.max_principals or q.after > p.max_counter) return error.InvalidRead;
    if ((q.resource == .processes) != (q.pid == null)) return error.InvalidRead;
    if (q.pid) |pid| if (pid == 0 or pid > p.max_counter) return error.InvalidRead;
    if (q.after != 0 and q.cut == null) return error.InvalidRead;
    if (q.cut) |cut| if (cut.position > p.max_counter or cut.policy_revision > p.max_counter or cut.retained_from > cut.position) return error.InvalidRead;
}
pub fn digest(query: Query) [32]u8 {
    var bytes: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    std.json.Stringify.value(query, .{}, &writer) catch unreachable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("rey.transit.inspection.v1\x00");
    hash.update(writer.buffered());
    return hash.finalResult();
}
pub fn sign(query: Query, key: p.Ed25519.KeyPair) !SignedQuery {
    try validate(query);
    return .{ .query = query, .signature = (try key.sign(&digest(query), null)).toBytes() };
}

test "shared inspection canonical bytes, domain hash and signature" {
    const Fixture = struct { seed_hex: []const u8, canonical: []const u8, sha256: []const u8, signature: [64]u8 };
    var fixture = try std.json.parseFromSlice(Fixture, std.testing.allocator, @embedFile("fixtures/inspection-v1.json"), .{});
    defer fixture.deinit();
    var query = try std.json.parseFromSlice(Query, std.testing.allocator, fixture.value.canonical, .{});
    defer query.deinit();
    const canonical = try std.json.Stringify.valueAlloc(std.testing.allocator, query.value, .{});
    defer std.testing.allocator.free(canonical);
    try std.testing.expectEqualStrings(fixture.value.canonical, canonical);
    try std.testing.expectEqualStrings(fixture.value.sha256, &std.fmt.bytesToHex(digest(query.value), .lower));
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, fixture.value.seed_hex);
    const key = try p.Ed25519.KeyPair.generateDeterministic(seed);
    try std.testing.expectEqual(fixture.value.signature, (try sign(query.value, key)).signature);
}

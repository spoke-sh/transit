//! Observation evidence is separate from permissions and resource retention.
const std = @import("std");
const r = @import("root.zig");
const d = r.protocol.DataLifecycle;
const Self = @This();
pub const Data = union(enum) {
    source: struct { kind: r.fuze.Unified.SourceKind, resource: u64, position: union(enum) { native_revision: u64, table: [32]u8 }, contract: [32]u8, schema: [32]u8 },
    table: struct { object: d.Object, interpretation: d.Definition, accepted: d.Position, changed_lsn: u64, pin: d.Content, commitment: [32]u8, schema: [32]u8 },
    independent_table_snapshots: []const r.fuze.Relational.Cut,
};
pub const Metadata = struct {
    kind: enum { catalog, settings, plan, probe },
    /// Catalog pagination can observe different revisions. Only an owner-supplied
    /// revision is reported; metadata never pretends to be a data snapshot.
    consistency: enum { exact_definitions, independent_observations, session },
    namespace: ?u64,
    definitions: []const d.Definition,
    configuration_revision: ?u64,
    session_settings: ?[32]u8,
};
pub const Value = union(enum) { data: Data, metadata: Metadata };
pub fn fingerprint(allocator: std.mem.Allocator, value: Value) ![32]u8 {
    const bytes = try r.protocol.Json.valueAlloc(allocator, value);
    defer allocator.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}

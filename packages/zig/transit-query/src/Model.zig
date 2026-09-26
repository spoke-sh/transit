const q = @import("root.zig");
const p = q.protocol;
const f = q.fuze;
/// One registered Table and one requester per query principal. Configuration
/// does not grant authority: every operation uses current signed Transit reads.
pub const Connection = struct {
    realm: u64,
    principal: u64,
    source: u64,
    resource: u64,
    table: u32,
    name: []const u8,
    requester: u64,
    requests: u64,
};
pub const Source = struct {
    version: u8 = 1,
    connection: Connection,
    resource_revision: u64,
    descriptor_revision: u64,
    schema: f.model.Schema,
    policy_revision: u64,
    sequence: u64,
    active: ?u64,
};
pub const Prepared = struct {
    version: u8 = 1,
    source: Source,
    plan: f.Stream.Plan,
    signed: p.Growth.SignedRequest,
};
pub const Phase = enum { submitted, busy, rejected, admitted, capturing, delivering, complete, cancelled, denied, expired, failed };
pub const Status = struct {
    version: u8 = 1,
    correlation: u64,
    phase: Phase,
    result: ?u64 = null,
    received_segments: u64 = 0,
    received_rows: u64 = 0,
    manifest: ?q.station.GrowingQuery.Manifest = null,
};
/// Integers use decimal strings, binary uses hex. Never coerce int64 into a
/// JavaScript number. Null remains distinct from empty string and false.
pub const Cell = union(enum) { null, int64: []const u8, boolean: bool, utf8: []const u8, binary: []const u8 };
pub const Column = struct { name: []const u8, type: f.model.Type, nullable: bool };
pub const Page = struct {
    version: u8 = 1,
    manifest: q.station.GrowingQuery.Manifest,
    ordinal: u64,
    columns: [2]?Column = @splat(null),
    rows: [f.model.max_rows]?[2]?Cell = @splat(null),
    count: u8,
    next: ?u64,
};

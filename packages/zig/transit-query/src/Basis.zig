//! Captured source identity. The immutable request supplies contract and schema;
//! a compact checkpoint retains the cut and the exact Table head commitment.
const std = @import("std");
const q = @import("root.zig");
const Self = @This();
pub const Cut = struct {
    kind: q.fuze.Unified.SourceKind,
    resource: u64,
    revision: u64,
    head: [32]u8 = @splat(0),
    pub fn validate(self: Cut) !void {
        try q.UnifiedRecords.identity(self.resource);
        if (self.revision > q.protocol.max_counter or (self.kind != .table and !std.mem.allEqual(u8, &self.head, 0))) return error.SourceChanged;
    }
};
cut: Cut,
contract: [32]u8,
schema: [32]u8,
pub fn from(source: q.SourceDefinition, cut: Cut) !Self {
    try cut.validate();
    if (cut.resource != source.resource or cut.kind != std.meta.activeTag(source.source)) return error.SourceChanged;
    var fields: [q.SourceDefinition.max_columns]q.fuze.Types.Field = undefined;
    return .{ .cut = cut, .contract = try source.fingerprint(), .schema = try (try source.schema(&fields)).fingerprint() };
}
pub fn fingerprint(self: Self) ![32]u8 {
    try self.cut.validate();
    var bytes: [17]u8 = undefined;
    bytes[0] = @backingInt(self.cut.kind);
    std.mem.writeInt(u64, bytes[1..9], self.cut.resource, .little);
    std.mem.writeInt(u64, bytes[9..17], self.cut.revision, .little);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.query.capture.v1\x00");
    digest.update(&bytes);
    digest.update(&self.contract);
    digest.update(&self.schema);
    digest.update(&self.cut.head);
    return digest.finalResult();
}
pub fn tableHead(head: q.station.TableHead) ![32]u8 {
    if (head.retired) return error.SourceChanged;
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.query.table-head.v1\x00");
    digest.update((try head.encode()).slice());
    return digest.finalResult();
}

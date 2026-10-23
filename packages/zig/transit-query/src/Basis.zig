//! Native revisions and direct Table cuts are distinct positions. A Table
//! commitment names complete durable source evidence, never a native version.
const std = @import("std");
const q = @import("root.zig");
const Self = @This();
pub const Cut = struct {
    kind: q.fuze.Unified.SourceKind,
    resource: u64,
    position: union(enum) { native_revision: u64, table: [32]u8 },
    pub fn native(kind: q.fuze.Unified.SourceKind, resource: u64, revision: u64) !Cut {
        const result: Cut = .{ .kind = kind, .resource = resource, .position = .{ .native_revision = revision } };
        try result.validate();
        return result;
    }
    pub fn validate(self: Cut) !void {
        try q.UnifiedRecords.identity(self.resource);
        switch (self.position) {
            .native_revision => |revision| if (self.kind == .table or revision > q.protocol.max_counter) return error.SourceChanged,
            .table => |commitment| if (self.kind != .table or std.mem.allEqual(u8, &commitment, 0)) return error.SourceChanged,
        }
    }
    pub fn nativeRevision(self: Cut) !u64 {
        try self.validate();
        return switch (self.position) {
            .native_revision => |revision| revision,
            .table => error.TableBasisRequired,
        };
    }
    pub fn write(self: Cut, writer: *std.Io.Writer) !void {
        try self.validate();
        try writer.writeByte(@backingInt(self.kind));
        try writer.writeInt(u64, self.resource, .little);
        switch (self.position) {
            .native_revision => |revision| try writer.writeInt(u64, revision, .little),
            .table => |commitment| try writer.writeAll(&commitment),
        }
    }
    pub fn read(reader: *std.Io.Reader) !Cut {
        const kind = std.enums.fromInt(q.fuze.Unified.SourceKind, try reader.takeByte()) orelse return error.InvalidQueryRecord;
        const resource = try reader.takeInt(u64, .little);
        const result: Cut = .{ .kind = kind, .resource = resource, .position = if (kind == .table) .{ .table = (try reader.takeArray(32)).* } else .{ .native_revision = try reader.takeInt(u64, .little) } };
        try result.validate();
        return result;
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
    var bytes: [41]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try self.cut.write(&writer);
    var digest = std.crypto.hash.sha2.Sha256.init(.{});
    digest.update("transit.query.capture.v1\x00");
    digest.update(&q.protocol.Growth.definition_bytes);
    digest.update(writer.buffered());
    digest.update(&self.contract);
    digest.update(&self.schema);
    return digest.finalResult();
}

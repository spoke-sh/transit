//! Exact object-bound DDL intent. SQL compilation and native authentication are
//! separate; names never retarget a saved object or schema revision.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const m = c.TableCatalogRecords;
const Meta = c.TableMetadata;
const Self = @This();
principal: u64,
operation: u64,
object: u64,
expected_revision: u64,
name: Meta.Name,
action: union(m.Kind) {
    create: struct { schema: f.TableSchema.Schema, if_not_exists: bool = false },
    alter: struct { schema: f.TableSchema.Schema, change: f.TableEvolution.Change },
    rename: Meta.Name,
    drop: struct { if_exists: bool = false },
},
pub fn right(self: Self) m.Right {
    return switch (self.action) {
        .create => .create,
        .alter, .rename => .alter,
        .drop => .drop,
    };
}
pub fn digest(self: Self, scope: m.Scope) ![32]u8 {
    try scope.validate();
    try self.name.validate();
    if (self.principal > c.protocol.max_counter or self.operation == 0) return error.InvalidCatalogIdentity;
    switch (self.action) {
        .create => |value| {
            try value.schema.validate();
            if (self.object == 0 or self.expected_revision != 0 or value.schema.object != self.object or value.schema.revision != 1) return error.InvalidCatalogDefinition;
        },
        .alter => |value| {
            try value.schema.validate();
            if (self.object == 0 or self.expected_revision == 0 or value.schema.object != self.object) return error.InvalidCatalogDefinition;
        },
        .rename => |name| {
            try name.validate();
            if (self.object == 0 or self.expected_revision == 0) return error.InvalidCatalogDefinition;
        },
        .drop => |value| if ((self.object == 0) != (self.expected_revision == 0) or (self.object == 0 and !value.if_exists)) return error.InvalidCatalogDefinition,
    }
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.ddl.v1\x00");
    hash.update(&Meta.definition());
    var ids: [64]u8 = undefined;
    var out: std.Io.Writer = .fixed(&ids);
    try Meta.scopeWrite(&out, scope);
    try out.writeInt(u64, self.principal, .little);
    try out.writeInt(u64, self.operation, .little);
    try out.writeInt(u64, self.object, .little);
    try out.writeInt(u64, self.expected_revision, .little);
    try out.writeByte(@backingInt(self.action));
    try out.writeByte(self.name.len);
    hash.update(out.buffered());
    hash.update(self.name.slice());
    switch (self.action) {
        .create => |value| {
            hash.update(&.{@intFromBool(value.if_not_exists)});
            hash.update(&try value.schema.fingerprint());
        },
        .alter => |value| {
            var columns: [f.TableSchema.max_columns]f.TableSchema.Column = undefined;
            const next = try f.TableEvolution.apply(value.schema, value.change, &columns);
            hash.update(&try value.schema.fingerprint());
            hash.update(&try next.after.fingerprint());
        },
        .rename => |name| {
            hash.update(&.{name.len});
            hash.update(name.slice());
        },
        .drop => |value| hash.update(&.{@intFromBool(value.if_exists)}),
    }
    return hash.finalResult();
}
pub fn tableAlter(self: Self, scope: m.Scope) !c.station.TableAlter.Request {
    const value = switch (self.action) {
        .alter => |value| value,
        else => return error.InvalidCatalogDefinition,
    };
    return .{ .resource = scope.resource, .principal = self.principal, .operation = self.operation, .schema = value.schema, .change = value.change };
}

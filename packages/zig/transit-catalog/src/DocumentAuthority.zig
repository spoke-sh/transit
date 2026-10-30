//! Direct Document privileges in the native authorization graph.
//! Distinguishes metadata inspection, retained revision reads, causal/versioned
//! mutations, finite merge-window checkpoint publication, and DDL administration.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const a = c.TableAuthority;

pub const inspect: u64 = 1;
pub const read: u64 = 2;
pub const mutate: u64 = 4;
pub const checkpoint: u64 = 8;
pub const all_privileges: u64 = inspect | read | mutate | checkpoint;
pub const Access = enum { create, inspect, read, mutate, checkpoint, administer };

pub fn requirements(
    profile: a.Profile,
    subject: p.Authorization.Subject,
    schema: a.Schema,
    object: ?a.Table,
    access: Access,
) !p.Authorization.Guard {
    if (access == .create) return a.guard(subject, profile, schema, null, .create_table);
    if (access == .administer) return a.guard(subject, profile, schema, object, .alter);
    var result = try a.guard(subject, profile, schema, null, .schema);
    const target = object orelse return error.InvalidCatalogIdentity;
    if (target.id == 0 or target.schema != schema.id) return error.InvalidCatalogIdentity;
    try c.Model.nativeId(target.authorization);
    result.requirements[2] = .{
        .object = a.reference(target.authorization),
        .privileges = switch (access) {
            .inspect => inspect,
            .read => read,
            .mutate => mutate,
            .checkpoint => read | checkpoint,
            .create, .administer => unreachable,
        },
    };
    try result.validate();
    return result;
}

pub fn binding(scope: c.Model.Scope, id: u64) ![32]u8 {
    try scope.validate();
    if (id == 0) return error.InvalidCatalogIdentity;
    var bytes: [32]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try c.TableMetadata.scopeWrite(&writer, scope);
    try writer.writeInt(u64, id, .little);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.document.authorization.binding.v1\x00");
    hash.update(&c.TableMetadata.definition());
    hash.update(writer.buffered());
    return hash.finalResult();
}

test "document privileges distinguish inspection read mutation checkpoint and administration" {
    const t = std.testing;
    const profile: a.Profile = .{
        .database_domain = 1,
        .schema_domain = 2,
        .table_domain = 3,
        .stream_domain = 31,
        .queue_domain = 32,
        .database = 4,
        .initial_schema = 1,
        .initial_schema_authority = 5,
    };
    const schema: a.Schema = .{
        .scope = .{ .realm = 1, .resource = 7, .catalog = 9 },
        .id = 1,
        .authorization = 5,
        .name = try .init("public"),
        .revision = 1,
    };
    const object: a.Table = .{ .id = 42, .schema = 1, .authorization = 109 };
    const subject: p.Authorization.Subject = .{
        .accepted = .{ .pid = 3, .input = 1, .principal = 17 },
    };
    for ([_]struct { access: Access, expected: u64 }{
        .{ .access = .inspect, .expected = inspect },
        .{ .access = .read, .expected = read },
        .{ .access = .mutate, .expected = mutate },
        .{ .access = .checkpoint, .expected = read | checkpoint },
    }) |case| {
        const guard = try requirements(profile, subject, schema, object, case.access);
        try t.expectEqual(@as(u64, a.connect), guard.requirements[0].?.privileges);
        try t.expectEqual(@as(u64, a.usage), guard.requirements[1].?.privileges);
        try t.expectEqual(case.expected, guard.requirements[2].?.privileges);
        try t.expectEqual(p.Authorization.ObjectRef{ .kind = .domain, .id = 109 }, guard.requirements[2].?.object);
    }
    const create = try requirements(profile, subject, schema, null, .create);
    try t.expectEqual(@as(u64, a.usage | a.create), create.requirements[1].?.privileges);
    try t.expect(create.requirements[2] == null);
    try t.expectEqual(.ownership, (try requirements(profile, subject, schema, object, .administer)).requirements[2].?.access);

    const doc_binding = try binding(schema.scope, 42);
    const stream_binding = try a.binding(schema.scope, .stream, 42);
    try t.expect(!std.mem.eql(u8, &doc_binding, &stream_binding));
    try t.expectError(error.InvalidCatalogIdentity, binding(schema.scope, 0));
}

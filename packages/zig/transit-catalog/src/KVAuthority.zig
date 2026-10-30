//! Direct KV rights use the existing native policy graph. A definition, old
//! receipt, retained cut or application association never supplies these rights.
const c = @import("root.zig");
const p = c.protocol;
const a = c.TableAuthority;

pub const inspect: u64 = 1;
pub const read: u64 = 2;
pub const write: u64 = 4;
pub const all_privileges: u64 = inspect | read | write;
pub const Access = enum { create, inspect, read, write, administer };

pub fn requirements(profile: a.Profile, subject: p.Authorization.Subject, schema: a.Schema, object: ?a.Table, access: Access) !p.Authorization.Guard {
    if (access == .create) return a.guard(subject, profile, schema, null, .create_table);
    if (access == .administer) return a.guard(subject, profile, schema, object, .alter);
    var result = try a.guard(subject, profile, schema, null, .schema);
    const target = object orelse return error.InvalidCatalogIdentity;
    if (target.id == 0 or target.schema != schema.id) return error.InvalidCatalogIdentity;
    try c.Model.nativeId(target.authorization);
    result.requirements[2] = .{ .object = a.reference(target.authorization), .privileges = switch (access) {
        .inspect => inspect,
        .read => read,
        .write => write,
        .create, .administer => unreachable,
    } };
    try result.validate();
    return result;
}

test "KV privileges separate metadata reads writes and ownership in the existing policy graph" {
    const std = @import("std");
    const t = std.testing;
    const profile = c.testing.Authority.profile;
    const schema: a.Schema = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .id = 1, .authorization = profile.initial_schema_authority, .name = try .init("public"), .revision = 1 };
    const object: a.Table = .{ .id = 42, .schema = 1, .authorization = 99 };
    const subject: p.Authorization.Subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 17 } };
    for ([_]struct { access: Access, mask: u64 }{
        .{ .access = .inspect, .mask = inspect }, .{ .access = .read, .mask = read }, .{ .access = .write, .mask = write },
    }) |case| {
        const guard = try requirements(profile, subject, schema, object, case.access);
        try t.expectEqual(a.connect, guard.requirements[0].?.privileges);
        try t.expectEqual(a.usage, guard.requirements[1].?.privileges);
        try t.expectEqual(case.mask, guard.requirements[2].?.privileges);
        try t.expectEqual(a.reference(object.authorization), guard.requirements[2].?.object);
    }
    const create = try requirements(profile, subject, schema, null, .create);
    try t.expectEqual(a.usage | a.create, create.requirements[1].?.privileges);
    try t.expect(create.requirements[2] == null);
    try t.expectEqual(.ownership, (try requirements(profile, subject, schema, object, .administer)).requirements[2].?.access);
    const kv_binding = try a.binding(schema.scope, .kv, object.id);
    for ([_]a.Kind{ .table, .stream, .queue }) |kind| try t.expect(!std.mem.eql(u8, &kv_binding, &try a.binding(schema.scope, kind, object.id)));
    var invalid = profile;
    invalid.kv_domain = invalid.table_domain;
    try t.expectError(error.InvalidCatalogConfiguration, invalid.validate());
}

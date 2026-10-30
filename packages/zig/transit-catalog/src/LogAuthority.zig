//! Stream/Queue privileges in the existing native authorization graph. Domains
//! and registered objects are provisioned by its registrar, never by this helper.
const c = @import("root.zig");
const p = c.protocol;
const a = c.TableAuthority;
pub const inspect: u64 = 1;
pub const read: u64 = 2;
pub const append: u64 = 4;
pub const acquire: u64 = 8;
pub const settle: u64 = 16;
pub const all_privileges: u64 = inspect | read | append | acquire | settle;
pub const Access = enum { create, inspect, read, append, acquire, settle, administer };

/// CREATE uses schema CREATE; administration uses native object ownership.
/// Reading or settling never inherits authority from a lease/group identity.
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
        .append => append,
        .acquire => read | acquire,
        .settle => settle,
        .create, .administer => unreachable,
    } };
    try result.validate();
    return result;
}

test "log privileges distinguish metadata payload selection settlement and administration" {
    const std = @import("std");
    const t = std.testing;
    const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .stream_domain = 31, .queue_domain = 32, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
    const schema: a.Schema = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .id = 1, .authorization = 5, .name = try .init("public"), .revision = 1 };
    const object: a.Table = .{ .id = 42, .schema = 1, .authorization = 99 };
    const subject: p.Authorization.Subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 17 } };
    for ([_]struct { access: Access, expected: u64 }{
        .{ .access = .inspect, .expected = inspect }, .{ .access = .read, .expected = read },
        .{ .access = .append, .expected = append },   .{ .access = .acquire, .expected = read | acquire },
        .{ .access = .settle, .expected = settle },
    }) |case| {
        const guard = try requirements(profile, subject, schema, object, case.access);
        try t.expectEqual(@as(u64, a.connect), guard.requirements[0].?.privileges);
        try t.expectEqual(@as(u64, a.usage), guard.requirements[1].?.privileges);
        try t.expectEqual(case.expected, guard.requirements[2].?.privileges);
        try t.expectEqual(p.Authorization.ObjectRef{ .kind = .domain, .id = 99 }, guard.requirements[2].?.object);
    }
    const create = try requirements(profile, subject, schema, null, .create);
    try t.expectEqual(@as(u64, a.usage | a.create), create.requirements[1].?.privileges);
    try t.expect(create.requirements[2] == null);
    try t.expectEqual(.ownership, (try requirements(profile, subject, schema, object, .administer)).requirements[2].?.access);
    const stream = try a.binding(schema.scope, .stream, 42);
    const queue = try a.binding(schema.scope, .queue, 42);
    try t.expect(!std.mem.eql(u8, &stream, &queue));
    var invalid = profile;
    invalid.queue_domain = invalid.table_domain;
    try t.expectError(error.InvalidCatalogConfiguration, invalid.validate());
}

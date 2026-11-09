//! Connector permissions use the existing native graph, independently of Stream
//! append authority and the executor named in a declaration.
const c = @import("root.zig");
const a = c.TableAuthority;
const p = c.protocol;
pub const inspect: u64 = 1;
pub const use: u64 = 2;
pub const Access = enum { inspect, use, create, administer };
pub fn actions(kind: c.SourceDeclaration.Kind) u64 {
    return if (kind == .source) inspect else inspect | use;
}
pub fn requirements(profile: a.Profile, subject: p.Authorization.Subject, schema: a.Schema, target: ?a.Table, kind: c.SourceDeclaration.Kind, access: Access) !p.Authorization.Guard {
    if (access == .create) return a.guard(subject, profile, schema, null, .create_table);
    if (access == .administer) return a.guard(subject, profile, schema, target, .alter);
    if (access == .use and kind == .source) return error.CatalogKindMismatch;
    const object = target orelse return error.InvalidCatalogIdentity;
    if (object.id == 0 or object.schema != schema.id) return error.InvalidCatalogIdentity;
    try c.Model.nativeId(object.authorization);
    var required = try a.guard(subject, profile, schema, null, .schema);
    required.requirements[2] = .{ .object = a.reference(object.authorization), .privileges = if (access == .use) use else inspect };
    try required.validate();
    return required;
}

test "SOURCE authority separates binding use inspection and administration" {
    const std = @import("std");
    const t = std.testing;
    const profile = @import("TestAuthority.zig").profile;
    const schema: a.Schema = .{ .scope = .{ .realm = 1, .resource = 7, .catalog = 9 }, .id = 1, .authorization = 5, .name = try .init("public"), .revision = 1 };
    const object: a.Table = .{ .id = 42, .schema = 1, .authorization = 99 };
    const subject: p.Authorization.Subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 17 } };
    try t.expectEqual(inspect, (try requirements(profile, subject, schema, object, .connection, .inspect)).requirements[2].?.privileges);
    try t.expectEqual(use, (try requirements(profile, subject, schema, object, .connection, .use)).requirements[2].?.privileges);
    try t.expectEqual(.ownership, (try requirements(profile, subject, schema, object, .source, .administer)).requirements[2].?.access);
    try t.expectError(error.CatalogKindMismatch, requirements(profile, subject, schema, object, .source, .use));
    try t.expectEqual(use, (try requirements(profile, subject, schema, object, .sink, .use)).requirements[2].?.privileges);
    const source = try a.binding(schema.scope, .source, object.id);
    for ([_]a.Kind{ .connection, .table, .stream, .queue, .kv, .sink }) |kind| try t.expect(!std.mem.eql(u8, &source, &try a.binding(schema.scope, kind, object.id)));
    var invalid = profile;
    invalid.connection_domain = invalid.source_domain;
    try t.expectError(error.InvalidCatalogConfiguration, invalid.validate());
    invalid = profile;
    invalid.sink_domain = invalid.connection_domain;
    try t.expectError(error.InvalidCatalogConfiguration, invalid.validate());
}

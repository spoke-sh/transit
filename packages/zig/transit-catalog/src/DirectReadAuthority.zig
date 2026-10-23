//! Exact native policy objects used by a direct Table read. These references
//! carry no permission; a result publisher rechecks them under its bound caller.
const std = @import("std");
const c = @import("root.zig");
const a = c.protocol.Authorization;
const Self = @This();
database: u64,
schema: u64,
table: u64,

pub fn validate(self: Self) !void {
    inline for (.{ "database", "schema", "table" }) |field| try c.Model.nativeId(@field(self, field));
    if (self.database == self.schema or self.database == self.table or self.schema == self.table) return error.InvalidCatalogConfiguration;
}
/// The enclosing worker/result reader supplies an independently bound subject.
/// Execution proofs retain their original credential epoch; current result reads
/// have their own disclosure proof. Neither is inferred from these object IDs.
pub fn guard(self: Self, subject: a.Subject) !a.Guard {
    try self.validate();
    var result: a.Guard = .{ .subject = subject, .requirements = @splat(null) };
    result.requirements[0] = .{ .object = c.TableAuthority.reference(self.database), .privileges = c.TableAuthority.connect };
    result.requirements[1] = .{ .object = c.TableAuthority.reference(self.schema), .privileges = c.TableAuthority.usage };
    result.requirements[2] = .{ .object = c.TableAuthority.reference(self.table), .privileges = c.TableAuthority.select };
    try result.validate();
    return result;
}

test "direct read authority guards the same database namespace and Table at publication" {
    const t = std.testing;
    const authority: Self = .{ .database = 11, .schema = 12, .table = 13 };
    const subject: a.Subject = .{ .accepted = .{ .pid = 3, .input = 5, .principal = 7 } };
    const required = try authority.guard(subject);
    try t.expectEqualDeep(subject, required.subject);
    try t.expectEqual(@as(u64, 11), required.requirements[0].?.object.id);
    try t.expectEqual(@as(u64, 12), required.requirements[1].?.object.id);
    try t.expectEqual(@as(u64, 13), required.requirements[2].?.object.id);
    try t.expect(required.requirements[3] == null and required.selectable == null);
    for (required.requirements[0..3]) |requirement| {
        try t.expectEqual(.domain, requirement.?.object.kind);
        try t.expectEqual(.all, requirement.?.access);
        try t.expectEqual(@as(u64, 1), requirement.?.privileges);
    }
    try t.expectError(error.InvalidCatalogConfiguration, (Self{ .database = 11, .schema = 12, .table = 11 }).guard(subject));
}

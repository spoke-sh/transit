//! Pure schema command and canonical identity. Storage and authorization
//! belong to the caller-selected owner.
const c = @import("root.zig");
const p = c.protocol;
const a = c.TableAuthority;
const r = c.Records;
const Self = @This();

scope: c.Model.Scope,
principal: u64,
operation: u64,
schema: u64,
expected_revision: u64,
action: union(enum(u8)) { create: struct { name: a.Name, owner: u64 } = 1, rename: a.Name = 2, drop: void = 3 },
pub fn validate(self: Self) !void {
    try self.scope.validate();
    try c.Model.nativeId(self.operation);
    try c.Model.nativeId(self.schema);
    if (self.principal > p.max_counter or self.expected_revision > p.max_counter or (self.action == .create) != (self.expected_revision == 0)) return error.InvalidSchemaCommand;
    switch (self.action) {
        .create => |value| {
            try value.name.validate();
            try p.Authorization.roleId(value.owner);
        },
        .rename => |name| try name.validate(),
        .drop => {},
    }
}
pub fn digest(self: Self) ![32]u8 {
    return c.Model.fingerprint(try r.encode('H', self));
}

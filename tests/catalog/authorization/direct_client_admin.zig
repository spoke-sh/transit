//! Shared signed administration for installed direct caller fixtures.
const c = @import("transit_catalog");
const wire = c.client;
const p = c.protocol;
const g = p.Growth;
pub const Admin = struct {
    client: *wire.Client,
    pub fn query(self: *@This(), kind: @FieldType(p.Authorization.Query, "kind")) !g.Response {
        return self.client.query(.{ .realm = 42, .principal = 0, .kind = .{ .authorization = .{ .kind = kind } } }, try key(17));
    }
    pub fn submit(self: *@This(), command: g.Command) !u64 {
        const identity = try self.query(.identity);
        return (try self.client.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = identity.principal_sequence + 1, .command = command }, try key(17)))).position;
    }
    pub fn change(self: *@This(), action: p.Authorization.Action) !?u64 {
        const revision = (try self.query(.identity)).body.authorization.revision;
        const id = try self.submit(.{ .authorization = .{ .begin = .{ .expected_revision = revision, .action = action } } });
        for (0..256) |_| {
            const found = (try self.query(.{ .change = id })).body.authorization.body.change;
            switch (found.status) {
                .preparing => _ = try self.submit(.{ .authorization = .{ .advance = id } }),
                .ready => _ = try self.submit(.{ .authorization = .{ .publish = id } }),
                .published => return found.created_id,
                .abandoned => return error.UnexpectedAbandonedChange,
            }
        }
        return error.AuthorizationStepBudget;
    }
};
fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}

//! Signed current-authority reads and recoverable opaque object registration.
//! A registration step only prepares bytes. The owner explicitly submits it.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const g = p.Growth;
const a = p.Authorization;
pub fn WithTransport(comptime Transport: type) type {
    return struct {
        const Self = @This();
        transport: *Transport,
        realm: u64,
        principal: u64,
        key: p.Ed25519.KeyPair,
        role: ?u64 = null,

        pub fn read(self: Self, kind: @FieldType(a.Query, "kind")) !g.Response {
            return self.transport.query(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .authorization = .{ .role = self.role, .kind = kind } } }, self.key);
        }
        /// Bind a service request to the caller's current credential epoch.
        /// The service independently verifies this proof through native authority.
        pub fn proof(self: Self, audience: u64, context: [32]u8) !a.Subject {
            const observation = try self.read(.identity);
            const identity = observation.body.authorization.body.identity;
            return .{ .signed = try a.Proof.sign(.{ .definition = g.current_definition, .realm = self.realm, .principal = self.principal, .credential_epoch = identity.credential_epoch, .role = self.role, .audience = audience, .context = context }, self.key) };
        }
        pub fn authenticate(self: Self, subject: a.Subject) !a.Verified {
            return (try self.read(.{ .authenticate = subject })).body.authorization.body.authenticate;
        }
        pub fn check(self: Self, guard: a.Guard) !a.Verified {
            return (try self.read(.{ .check = guard })).body.authorization.body.check;
        }
        pub fn binding(self: Self, domain: u64, identity: [32]u8) !?a.Object {
            return (try self.read(.{ .binding = .{ .domain = domain, .key = identity } })).body.authorization.body.binding;
        }
        pub const Registration = union(enum) { ready: a.Object, submit: g.SignedRequest };
        /// The binding's retained native change record is the recovery ledger.
        /// A single observation supplies both phase and principal sequence.
        /// An in-flight identical next step therefore has identical signed bytes;
        /// a stale-basis begin cannot be accepted after a policy change.
        pub fn registration(self: Self, action: @FieldType(a.Action, "register_object")) !Registration {
            return self.registrationChecked(action, null);
        }
        /// A domain registrar carries the revision from its original caller's
        /// current-rights check. Do not replace it with a later observed basis.
        pub fn registrationAt(self: Self, action: @FieldType(a.Action, "register_object"), authorization_revision: u64) !Registration {
            return self.registrationChecked(action, authorization_revision);
        }
        fn registrationChecked(self: Self, action: @FieldType(a.Action, "register_object"), authorization_revision: ?u64) !Registration {
            const identity = action.binding orelse return error.InvalidAuthorizationObject;
            const observation = try self.read(.{ .registration = .{ .domain = action.domain, .key = identity } });
            const authority = observation.body.authorization;
            if (authorization_revision) |expected| if (expected != authority.revision) return error.StaleAuthorizationRevision;
            const command: a.Command = if (authority.body.registration) |existing| step: {
                if (!std.meta.eql(existing.action, a.Action{ .register_object = action })) return error.InvalidAuthorizationObject;
                switch (existing.outcome.status) {
                    .published => {
                        const object = (try self.binding(action.domain, identity)) orelse return error.InvalidAuthorizationObject;
                        if (object.reference.id != existing.outcome.created_id) return error.InvalidAuthorizationObject;
                        return .{ .ready = object };
                    },
                    .abandoned => {},
                    .preparing, .ready => {
                        if (existing.outcome.basis != authority.revision) break :step .{ .abandon = existing.outcome.id };
                        break :step if (existing.outcome.status == .ready) .{ .publish = existing.outcome.id } else .{ .advance = existing.outcome.id };
                    },
                }
                break :step .{ .begin = .{ .expected_revision = authority.revision, .role = self.role, .action = .{ .register_object = action } } };
            } else .{ .begin = .{ .expected_revision = authority.revision, .role = self.role, .action = .{ .register_object = action } } };
            const signed = try g.sign(.{ .realm = self.realm, .principal = self.principal, .sequence = try std.math.add(u64, observation.principal_sequence, 1), .command = .{ .authorization = command } }, self.key);
            return .{ .submit = signed };
        }
    };
}
pub const Client = WithTransport(wire.Client);

test "registration preparation preserves exact identity across lost replies and never submits implicitly" {
    const t = std.testing;
    const Fake = struct {
        response: g.Response,
        queries: usize = 0,
        pub fn query(self: *@This(), query_value: g.Query, key: p.Ed25519.KeyPair) !g.Response {
            _ = try g.signQuery(query_value, key);
            self.queries += 1;
            return self.response;
        }
    };
    var transport: Fake = .{ .response = .{ .definition = g.current_definition, .realm = 42, .position = 11, .principal_sequence = 3, .body = .{ .authorization = .{ .revision = 7, .role = 0, .body = .{ .registration = null } } } } };
    const client: WithTransport(Fake) = .{ .transport = &transport, .realm = 42, .principal = 0, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7)) };
    const action: @FieldType(a.Action, "register_object") = .{ .domain = 2, .owner = 3, .binding = @splat(5) };
    const first = (try client.registration(action)).submit;
    const retry = (try client.registration(action)).submit;
    try t.expect(std.meta.eql(first, retry));
    try t.expectEqual(@as(u64, 4), first.request.sequence);
    try t.expectEqual(@as(u64, 7), first.request.command.authorization.begin.expected_revision);
    try t.expectError(error.StaleAuthorizationRevision, client.registrationAt(action, 6));
    try t.expectEqualDeep(first, (try client.registrationAt(action, 7)).submit);
    transport.response.principal_sequence = 4;
    transport.response.body.authorization.body = .{ .registration = .{ .action = .{ .register_object = action }, .outcome = .{ .id = 11, .principal = 0, .role = 0, .basis = 7, .revision = 11, .status = .preparing, .created_id = 13, .changed_records = 1, .steps = 0 } } };
    const next = (try client.registration(action)).submit;
    try t.expectEqual(@as(u64, 11), next.request.command.authorization.advance);
    try t.expectEqual(@as(u64, 5), next.request.sequence);
    try t.expect(std.meta.eql(next, (try client.registration(action)).submit));
    transport.response.body.authorization.body.registration.?.outcome.status = .ready;
    transport.response.principal_sequence = 5;
    const publication = (try client.registration(action)).submit;
    try t.expectEqual(@as(u64, 11), publication.request.command.authorization.publish);
    transport.response.body.authorization.revision = 12;
    const abandoned = (try client.registration(action)).submit;
    try t.expectEqual(@as(u64, 11), abandoned.request.command.authorization.abandon);
    var foreign = action;
    foreign.owner += 1;
    try t.expectError(error.InvalidAuthorizationObject, client.registration(foreign));
    try t.expectEqual(@as(usize, 9), transport.queries);
}

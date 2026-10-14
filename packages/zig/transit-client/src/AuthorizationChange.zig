//! An explicit, recoverable administration lifecycle. Hosts save each returned
//! record before submitting its pending bytes. Reads never submit or re-sign an
//! uncertain request. The native operation ledger owns progress and outcome.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const g = p.Growth;
const a = p.Authorization;
pub const Envelope = struct {
    signed: g.SignedRequest,
    public_key: [32]u8,
    fn validate(self: Envelope) !void {
        try g.validate(self.signed.request);
        try p.Ed25519.Signature.fromBytes(self.signed.signature).verify(&try g.digest(self.signed.request), try p.Ed25519.PublicKey.fromBytes(self.public_key));
    }
};
pub const Record = struct {
    definition: g.Definition,
    begin: Envelope,
    change: ?u64,
    pending: ?Envelope,
    pub const max_bytes = 32 * 1024;
    pub fn validate(self: Record) !void {
        if (self.definition != g.current_definition) return error.IncompatibleDefinition;
        try self.begin.validate();
        const original = self.begin.signed.request;
        if (original.command != .authorization or original.command.authorization != .begin) return error.InvalidAuthorizationChange;
        if (self.change) |id| {
            if (id == 0 or id > p.max_counter) return error.InvalidAuthorizationChange;
        } else if (self.pending == null or !std.meta.eql(self.pending.?, self.begin)) return error.InvalidAuthorizationChange;
        if (self.pending) |pending| {
            try pending.validate();
            const request = pending.signed.request;
            if (request.realm != original.realm or request.principal != original.principal or request.command != .authorization) return error.InvalidAuthorizationChange;
            if (self.change) |id| {
                if (request.sequence <= original.sequence) return error.InvalidAuthorizationChange;
                switch (request.command.authorization) {
                    .begin => return error.InvalidAuthorizationChange,
                    .advance, .publish, .abandon => |target| if (target != id) return error.InvalidAuthorizationChange,
                }
            }
        }
    }
    pub fn save(self: Record, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const bytes = try p.Json.valueAlloc(allocator, self);
        errdefer allocator.free(bytes);
        if (bytes.len > max_bytes) return error.InvalidAuthorizationChange;
        return bytes;
    }
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Record {
        if (bytes.len > max_bytes) return error.InvalidAuthorizationChange;
        const parsed = try p.Json.parseFromSlice(Record, allocator, bytes);
        defer parsed.deinit();
        try parsed.value.validate();
        return parsed.value;
    }
    /// Only a validated submit receipt consumes a pending request. A timeout or
    /// rejected observation leaves the exact original bytes available to retry.
    pub fn received(self: Record, receipt: p.Receipt) !Record {
        try self.validate();
        if (self.pending == null or receipt.position == 0 or receipt.position > p.max_counter) return error.InvalidAuthorizationChange;
        var next = self;
        if (next.change == null) next.change = receipt.position else if (receipt.position <= next.change.?) return error.InvalidAuthorizationChange;
        next.pending = null;
        return next;
    }
};

pub fn WithTransport(comptime Transport: type) type {
    return struct {
        const Self = @This();
        authority: @import("AuthorizationClient.zig").WithTransport(Transport),
        pub const Prepared = struct { preview: a.Preview, record: Record };
        pub const Next = union(enum) { pending: Record, terminal: a.Outcome };

        pub fn prepare(self: Self, revision: u64, action: a.Action) !Prepared {
            const observation = try self.authority.read(.{ .preview = .{ .expected_revision = revision, .action = action } });
            const envelope = try self.sign(observation, .{ .begin = .{ .expected_revision = revision, .role = self.authority.role, .action = action } });
            return .{ .preview = observation.body.authorization.body.preview, .record = .{ .definition = g.current_definition, .begin = envelope, .change = null, .pending = envelope } };
        }
        fn sign(self: Self, observation: g.Response, command: a.Command) !Envelope {
            return .{ .public_key = self.authority.key.public_key.toBytes(), .signed = try g.sign(.{ .realm = self.authority.realm, .principal = self.authority.principal, .sequence = try std.math.add(u64, observation.principal_sequence, 1), .command = .{ .authorization = command } }, self.authority.key) };
        }
        fn validate(self: Self, record: Record) !void {
            try record.validate();
            const request = record.begin.signed.request;
            if (request.realm != self.authority.realm or request.principal != self.authority.principal) return error.InvalidAuthorizationChange;
        }
        fn recoveryAuthority(self: Self) @TypeOf(self.authority) {
            var authority = self.authority;
            authority.role = null;
            return authority;
        }
        /// A current credential can discover the receipt of an old exact
        /// request after rotation. Absence leaves its uncertainty untouched.
        pub fn recoverPending(self: Self, record: Record) !?Record {
            try self.validate(record);
            const pending = record.pending orelse return error.AuthorizationChangeNotPending;
            const observation = try self.recoveryAuthority().read(.{ .receipt = pending.signed.request });
            const receipt = observation.body.authorization.body.receipt orelse return null;
            return try record.received(receipt);
        }
        pub fn observe(self: Self, record: Record) !g.Response {
            try self.validate(record);
            const observation = try self.recoveryAuthority().read(.{ .operation = record.change orelse return error.AuthorizationChangeNotAdmitted });
            const operation = observation.body.authorization.body.operation;
            const original = record.begin.signed.request.command.authorization.begin;
            if (operation.outcome.principal != self.authority.principal or operation.outcome.basis != original.expected_revision or !std.meta.eql(operation.action, original.action)) return error.InvalidAuthorizationChange;
            if (original.role) |role| if (operation.outcome.role != role) return error.InvalidAuthorizationChange;
            return observation;
        }
        pub fn next(self: Self, record: Record) !Next {
            try self.validate(record);
            if (record.pending != null) return .{ .pending = record };
            const observation = try self.observe(record);
            const outcome = observation.body.authorization.body.operation.outcome;
            if (outcome.status == .published or outcome.status == .abandoned) return .{ .terminal = outcome };
            if (outcome.basis != observation.body.authorization.revision) return error.StaleAuthorizationRevision;
            var next_record = record;
            next_record.pending = try self.sign(observation, if (outcome.status == .ready) .{ .publish = outcome.id } else .{ .advance = outcome.id });
            return .{ .pending = next_record };
        }
        pub fn abandon(self: Self, record: Record) !Record {
            try self.validate(record);
            // An uncertain request must first be resolved using its exact bytes.
            if (record.pending != null) return error.AuthorizationChangePending;
            const observation = try self.observe(record);
            const outcome = observation.body.authorization.body.operation.outcome;
            if (outcome.status == .published or outcome.status == .abandoned) return error.InvalidAuthorizationChange;
            var next_record = record;
            next_record.pending = try self.sign(observation, .{ .abandon = outcome.id });
            return next_record;
        }
        pub fn submit(self: Self, record: Record) !p.Receipt {
            try self.validate(record);
            return self.authority.transport.submit((record.pending orelse return error.AuthorizationChangeNotPending).signed);
        }
    };
}
pub const Client = WithTransport(wire.Client);

test "saved authorization steps preserve identity through uncertain submits and reject tampering" {
    const t = std.testing;
    const Fake = struct {
        response: g.Response,
        submitted: ?g.SignedRequest = null,
        fail: bool = true,
        pub fn query(self: *@This(), query_value: g.Query, key: p.Ed25519.KeyPair) !g.Response {
            _ = try g.signQuery(query_value, key);
            return self.response;
        }
        pub fn submit(self: *@This(), signed: g.SignedRequest) !p.Receipt {
            if (self.submitted) |prior| try t.expect(std.meta.eql(prior, signed));
            self.submitted = signed;
            if (self.fail) return error.AuthorityTimeout;
            return .{ .position = 12 };
        }
    };
    var fake: Fake = .{ .response = .{ .definition = g.current_definition, .realm = 42, .position = 12, .principal_sequence = 4, .body = .{ .authorization = .{ .revision = 7, .role = 0, .body = .{ .preview = .{ .complete = true, .changed_records = 1, .steps = 1, .pages = 2, .reads = 4 } } } } } };
    const client: WithTransport(Fake) = .{ .authority = .{ .transport = &fake, .realm = 42, .principal = 0, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7)) } };
    const action: a.Action = .{ .create_role = .{ .name = try p.Value.init("reader") } };
    const prepared = try client.prepare(7, action);
    const bytes = try prepared.record.save(t.allocator);
    defer t.allocator.free(bytes);
    const restored = try Record.restore(t.allocator, bytes);
    try t.expect(std.meta.eql(prepared.record, restored));
    try t.expectError(error.AuthorityTimeout, client.submit(restored));
    try t.expect(std.meta.eql(restored, (try client.next(restored)).pending));
    fake.fail = false;
    const admitted = try restored.received(try client.submit(restored));
    try t.expectEqual(@as(?u64, 12), admitted.change);
    fake.response.body.authorization.body = .{ .receipt = null };
    try t.expect(try client.recoverPending(restored) == null);
    fake.response.body.authorization.body = .{ .receipt = .{ .position = 12 } };
    try t.expect(std.meta.eql(admitted, (try client.recoverPending(restored)).?));
    fake.response.principal_sequence = 5;
    fake.response.body.authorization.body = .{ .operation = .{ .action = action, .outcome = .{ .id = 12, .principal = 0, .role = 0, .basis = 7, .revision = 12, .status = .ready, .created_id = 15, .changed_records = 1, .steps = 1 } } };
    const publish = (try client.next(admitted)).pending;
    try t.expectEqual(@as(u64, 12), publish.pending.?.signed.request.command.authorization.publish);
    try t.expectEqual(@as(u64, 6), publish.pending.?.signed.request.sequence);
    try t.expectError(error.AuthorizationChangePending, client.abandon(publish));
    fake.response.body.authorization.revision = 13;
    try t.expectError(error.StaleAuthorizationRevision, client.next(admitted));
    try t.expectEqual(@as(u64, 12), (try client.abandon(admitted)).pending.?.signed.request.command.authorization.abandon);
    fake.response.body.authorization.body.operation.action.create_role.name = try p.Value.init("different");
    try t.expectError(error.InvalidAuthorizationChange, client.observe(admitted));
    var corrupt = restored;
    corrupt.begin.signed.request.sequence += 1;
    try t.expectError(error.SignatureVerificationFailed, corrupt.validate());
}

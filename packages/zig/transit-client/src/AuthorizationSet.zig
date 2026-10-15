//! Explicit, scoped grant reconciliation. Each native change publishes separately;
//! the signed document and exact pending envelope survive interrupted application.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const a = p.Authorization;
const Change = wire.AuthorizationChange;
pub const max_intents = 32;
pub const max_bytes = 128 * 1024;
pub const Membership = struct { member: u64, role: u64 };
pub const Defaults = struct { creator: u64, schema: a.ObjectRef, domain: u64 };
pub const Scope = struct {
    pub const json_schema_sequence_bounds = .{ .objects = max_intents, .memberships = max_intents, .defaults = max_intents };
    objects: []const a.ObjectRef = &.{},
    memberships: []const Membership = &.{},
    defaults: []const Defaults = &.{},
    pub fn validate(self: Scope) !void {
        if (self.objects.len + self.memberships.len + self.defaults.len > max_intents) return error.InvalidAuthorizationSet;
        for (self.objects, 0..) |object, i| {
            try object.validate();
            for (self.objects[0..i]) |prior| if (std.meta.eql(object, prior)) return error.InvalidAuthorizationSet;
        }
        for (self.memberships, 0..) |edge, i| {
            try a.roleId(edge.member);
            try a.roleId(edge.role);
            if (edge.member == edge.role) return error.InvalidAuthorizationSet;
            for (self.memberships[0..i]) |prior| if (std.meta.eql(edge, prior)) return error.InvalidAuthorizationSet;
        }
        for (self.defaults, 0..) |target, i| {
            try a.roleId(target.creator);
            try target.schema.validate();
            if (target.domain == 0 or target.domain >= a.public_role) return error.InvalidAuthorizationSet;
            for (self.defaults[0..i]) |prior| if (std.meta.eql(target, prior)) return error.InvalidAuthorizationSet;
        }
    }
    fn permits(self: Scope, intent: Intent) bool {
        switch (intent) {
            inline .grant, .revoke => |value| for (self.objects) |object| {
                if (std.meta.eql(object, value.object)) return true;
            },
            inline .membership, .revoke_membership => |value| for (self.memberships) |edge| {
                if (edge.member == value.member and edge.role == value.role) return true;
            },
            inline .default_grant, .revoke_default => |value| for (self.defaults) |target| {
                if (target.creator == value.creator and target.domain == value.domain and std.meta.eql(target.schema, value.schema)) return true;
            },
        }
        return false;
    }
};
/// Omitted objects/edges remain untouched. Revocation is always explicit and
/// retains the native grantor, option and RESTRICT/CASCADE rules.
pub const Intent = union(enum) {
    grant: @FieldType(a.Action, "grant"),
    revoke: @FieldType(a.Action, "revoke_privileges"),
    membership: @FieldType(a.Action, "membership"),
    revoke_membership: @FieldType(a.Action, "revoke_role"),
    default_grant: @FieldType(a.Action, "default_grant"),
    revoke_default: @FieldType(a.Action, "revoke_defaults"),
    pub fn action(self: Intent) a.Action {
        return switch (self) {
            .revoke => |value| .{ .revoke_privileges = value },
            .revoke_membership => |value| .{ .revoke_role = value },
            .revoke_default => |value| .{ .revoke_defaults = value },
            inline else => |value, tag| @unionInit(a.Action, @tagName(tag), value),
        };
    }
    fn overlaps(self: Intent, other: Intent) bool {
        return switch (self) {
            inline .grant, .revoke => |left| switch (other) {
                inline .grant, .revoke => |right| left.grantee == right.grantee and std.meta.eql(left.object, right.object),
                else => false,
            },
            inline .membership, .revoke_membership => |left| switch (other) {
                inline .membership, .revoke_membership => |right| left.member == right.member and left.role == right.role,
                else => false,
            },
            inline .default_grant, .revoke_default => |left| switch (other) {
                inline .default_grant, .revoke_default => |right| left.creator == right.creator and left.domain == right.domain and left.grantee == right.grantee and std.meta.eql(left.schema, right.schema),
                else => false,
            },
        };
    }
};
pub const Document = struct {
    pub const json_schema_sequence_bounds = .{ .intents = max_intents };
    definition: p.Growth.Definition,
    realm: u64,
    base_revision: u64,
    managed_scope: Scope,
    intents: []const Intent,
    pub fn validate(self: Document) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.realm == 0 or self.realm > p.max_counter or self.intents.len == 0 or self.intents.len > max_intents) return error.InvalidAuthorizationSet;
        try a.revision(self.base_revision);
        try self.managed_scope.validate();
        for (self.intents, 0..) |intent, i| {
            if (!self.managed_scope.permits(intent)) return error.AuthorizationSetScope;
            try a.validateQuery(.{ .kind = .{ .preview = .{ .expected_revision = self.base_revision, .action = intent.action() } } });
            for (self.intents[0..i]) |prior| if (intent.overlaps(prior)) return error.InvalidAuthorizationSet;
        }
    }
};
pub const Seal = struct {
    document: Document,
    principal: u64,
    role: u64,
    public_key: [32]u8,
    signature: [64]u8,
    fn digest(self: Seal, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try p.Json.valueAlloc(allocator, .{ .document = self.document, .principal = self.principal, .role = self.role, .public_key = self.public_key });
        defer allocator.free(bytes);
        if (bytes.len > max_bytes) return error.InvalidAuthorizationSet;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.authorization.changeset.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    fn validate(self: Seal, allocator: std.mem.Allocator) !void {
        try self.document.validate();
        if (self.principal > p.max_counter) return error.InvalidAuthorizationSet;
        try a.roleId(self.role);
        try p.Ed25519.Signature.fromBytes(self.signature).verify(&try self.digest(allocator), try p.Ed25519.PublicKey.fromBytes(self.public_key));
    }
};
pub const Completion = struct { record: Change.Record, outcome: a.Outcome };
pub const Record = struct {
    pub const json_schema_sequence_bounds = .{ .completed = max_intents };
    seal: Seal,
    completed: []const Completion = &.{},
    current: ?Change.Record,
    pub fn validate(self: Record, allocator: std.mem.Allocator) !void {
        try self.seal.validate(allocator);
        const document = self.seal.document;
        if (self.completed.len > document.intents.len or (self.completed.len == document.intents.len and self.current != null)) return error.InvalidAuthorizationSet;
        var revision = document.base_revision;
        for (self.completed, 0..) |done, i| {
            try self.validateChange(done.record, i, revision);
            const outcome = done.outcome;
            if (done.record.pending != null or done.record.change != outcome.id or outcome.status != .published or outcome.principal != self.seal.principal or outcome.role != self.seal.role or outcome.basis != revision or outcome.revision <= revision) return error.InvalidAuthorizationSet;
            revision = outcome.revision;
        }
        if (self.current) |current| try self.validateChange(current, self.completed.len, revision) else if (self.completed.len == 0) return error.InvalidAuthorizationSet;
    }
    fn validateChange(self: Record, record: Change.Record, index: usize, revision: u64) !void {
        try record.validate();
        const request = record.begin.signed.request;
        const begin = request.command.authorization.begin;
        if (request.realm != self.seal.document.realm or request.principal != self.seal.principal or begin.role != self.seal.role or begin.expected_revision != revision or !std.meta.eql(begin.action, self.seal.document.intents[index].action())) return error.InvalidAuthorizationSet;
        if (index == 0 and !std.mem.eql(u8, &record.begin.public_key, &self.seal.public_key)) return error.InvalidAuthorizationSet;
    }
    pub fn save(self: Record, allocator: std.mem.Allocator) ![]u8 {
        try self.validate(allocator);
        const bytes = try p.Json.valueAlloc(allocator, self);
        errdefer allocator.free(bytes);
        if (bytes.len > max_bytes) return error.InvalidAuthorizationSet;
        return bytes;
    }
    /// All slices belong to the supplied arena, which must outlive this record.
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Record {
        if (bytes.len > max_bytes) return error.InvalidAuthorizationSet;
        const checked = try p.Json.parseFromSlice(Record, allocator, bytes);
        defer checked.deinit();
        try checked.value.validate(allocator);
        return std.json.parseFromSliceLeaky(Record, allocator, bytes, .{ .allocate = .alloc_always });
    }
    pub fn received(self: Record, receipt: p.Receipt) !Record {
        var result = self;
        result.current = try (self.current orelse return error.AuthorizationChangeNotPending).received(receipt);
        return result;
    }
};
pub const Summary = struct { completed: u8, total: u8, status: enum { pending, published, abandoned }, revision: u64 };
pub fn WithTransport(comptime Transport: type) type {
    return struct {
        const Self = @This();
        client: Change.WithTransport(Transport),
        allocator: std.mem.Allocator,
        pub const Next = union(enum) { record: Record, terminal: Summary };
        fn check(self: Self, record: Record) !void {
            try record.validate(self.allocator);
            if (record.seal.document.realm != self.client.authority.realm or record.seal.principal != self.client.authority.principal) return error.InvalidAuthorizationSet;
        }
        fn selected(self: Self, role: u64) Change.WithTransport(Transport) {
            var client = self.client;
            client.authority.role = role;
            return client;
        }
        pub fn prepare(self: Self, document: Document) !struct { preview: a.Preview, record: Record } {
            try document.validate();
            if (document.realm != self.client.authority.realm) return error.InvalidAuthorizationSet;
            const identity = (try self.client.authority.read(.identity)).body.authorization;
            if (identity.revision != document.base_revision) return error.StaleAuthorizationRevision;
            var seal: Seal = .{ .document = document, .principal = self.client.authority.principal, .role = identity.role, .public_key = self.client.authority.key.public_key.toBytes(), .signature = undefined };
            seal.signature = (try self.client.authority.key.sign(&try seal.digest(self.allocator), null)).toBytes();
            const first = try self.selected(seal.role).prepare(document.base_revision, document.intents[0].action());
            return .{ .preview = first.preview, .record = .{ .seal = seal, .current = first.record } };
        }
        fn completed(self: Self, record: Record) !void {
            // A saved local status never proves publication or permits skipping
            // an intent. Verify each retained outcome against the native ledger.
            for (record.completed) |done| {
                const observed = (try self.client.observe(done.record)).body.authorization.body.operation.outcome;
                if (!std.meta.eql(done.outcome, observed)) return error.InvalidAuthorizationSet;
            }
        }
        pub fn observe(self: Self, record: Record) !Summary {
            try self.check(record);
            try self.completed(record);
            const count = record.completed.len;
            var result: Summary = .{ .completed = @intCast(count), .total = @intCast(record.seal.document.intents.len), .status = if (count == record.seal.document.intents.len) .published else .pending, .revision = if (count == 0) record.seal.document.base_revision else record.completed[count - 1].outcome.revision };
            if (record.current) |current| if (current.change != null) {
                const outcome = (try self.client.observe(current)).body.authorization.body.operation.outcome;
                if (outcome.status == .abandoned) result.status = .abandoned;
                if (outcome.status == .published) {
                    result.completed += 1;
                    result.revision = outcome.revision;
                    if (result.completed == result.total) result.status = .published;
                }
            };
            return result;
        }
        pub fn next(self: Self, record: Record) !Next {
            try self.check(record);
            if (record.current) |current| {
                const step = try self.selected(record.seal.role).next(current);
                if (step == .pending) {
                    var result = record;
                    result.current = step.pending;
                    return .{ .record = result };
                }
                if (step.terminal.status == .abandoned) return .{ .terminal = try self.observe(record) };
                const values = try self.allocator.alloc(Completion, record.completed.len + 1);
                @memcpy(values[0..record.completed.len], record.completed);
                values[record.completed.len] = .{ .record = current, .outcome = step.terminal };
                // Checkpoint the completed step before preparing another. A
                // later stale-basis rejection cannot conceal earlier success.
                return .{ .record = .{ .seal = record.seal, .completed = values, .current = null } };
            }
            try self.completed(record);
            if (record.completed.len == record.seal.document.intents.len) return .{ .terminal = try self.observe(record) };
            const revision = record.completed[record.completed.len - 1].outcome.revision;
            const prepared = try self.selected(record.seal.role).prepare(revision, record.seal.document.intents[record.completed.len].action());
            var result = record;
            result.current = prepared.record;
            return .{ .record = result };
        }
        pub fn recoverPending(self: Self, record: Record) !?Record {
            try self.check(record);
            const current = record.current orelse return error.AuthorizationChangeNotPending;
            if (try self.client.recoverPending(current)) |recovered| {
                var result = record;
                result.current = recovered;
                return result;
            }
            return null;
        }
        pub fn abandon(self: Self, record: Record) !Record {
            try self.check(record);
            var result = record;
            result.current = try self.client.abandon(record.current orelse return error.AuthorizationChangeNotAdmitted);
            return result;
        }
        pub fn submit(self: Self, record: Record) !p.Receipt {
            return self.client.authority.transport.submit(try self.submission(record));
        }
        pub fn submission(self: Self, record: Record) !p.Growth.SignedRequest {
            try self.check(record);
            try self.completed(record);
            const current = record.current orelse return error.AuthorizationChangeNotPending;
            return (current.pending orelse return error.AuthorizationChangeNotPending).signed;
        }
    };
}
pub const Action = union(enum) {
    prepare: Document,
    restore: []const u8,
    next: []const u8,
    submit: []const u8,
    observe: []const u8,
    received: struct { record: []const u8, receipt: p.Receipt },
    recover_pending: []const u8,
    abandon: []const u8,
};
pub const Result = union(enum) {
    prepared: struct { preview: a.Preview, record: []const u8 },
    record: []const u8,
    next: union(enum) { record: []const u8, terminal: Summary },
    receipt: p.Receipt,
    observation: Summary,
    recovered: ?[]const u8,
};

test "changesets require explicit scopes and reject overlapping grant intent" {
    const t = std.testing;
    const object: a.ObjectRef = .{ .kind = .domain, .id = 12 };
    var intents = [_]Intent{.{ .grant = .{ .object = object, .grantee = 4, .privileges = 1 } }};
    var document: Document = .{ .definition = p.Growth.current_definition, .realm = 1, .base_revision = 3, .managed_scope = .{ .objects = &.{object} }, .intents = &intents };
    try document.validate();
    document.managed_scope = .{};
    try t.expectError(error.AuthorizationSetScope, document.validate());
    document.managed_scope = .{ .objects = &.{object} };
    document.intents = &.{ intents[0], .{ .revoke = .{ .object = object, .grantee = 4, .privileges = 2 } } };
    try t.expectError(error.InvalidAuthorizationSet, document.validate());
    document.intents = &intents;
    intents[0] = .{ .revoke = .{ .object = object, .grantee = 4, .privileges = 1, .grant_option_only = true, .behavior = .cascade } };
    try document.validate();
    try t.expectEqual(true, intents[0].action().revoke_privileges.grant_option_only);
    try t.expectEqual(.cascade, intents[0].action().revoke_privileges.behavior);
    document.intents = &.{};
    try t.expectError(error.InvalidAuthorizationSet, document.validate());
}

test "sealed changesets preserve selected role, scope and all unsent intents" {
    const t = std.testing;
    const object: a.ObjectRef = .{ .kind = .domain, .id = 12 };
    var intents = [_]Intent{
        .{ .grant = .{ .object = object, .grantee = 4, .privileges = 1 } },
        .{ .revoke = .{ .object = object, .grantee = 5, .privileges = 2 } },
    };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var seal: Seal = .{ .document = .{ .definition = p.Growth.current_definition, .realm = 1, .base_revision = 3, .managed_scope = .{ .objects = &.{object} }, .intents = &intents }, .principal = 2, .role = 4, .public_key = key.public_key.toBytes(), .signature = undefined };
    seal.signature = (try key.sign(&try seal.digest(alloc), null)).toBytes();
    const begin: Change.Envelope = .{ .public_key = key.public_key.toBytes(), .signed = try p.Growth.sign(.{ .realm = 1, .principal = 2, .sequence = 1, .command = .{ .authorization = .{ .begin = .{ .expected_revision = 3, .role = 4, .action = intents[0].action() } } } }, key) };
    const record: Record = .{ .seal = seal, .current = .{ .definition = p.Growth.current_definition, .begin = begin, .change = null, .pending = begin } };
    const bytes = try record.save(alloc);
    const restored = try Record.restore(alloc, bytes);
    try t.expectEqualStrings(bytes, try restored.save(alloc));
    intents[1].revoke.privileges = 4;
    try t.expectError(error.SignatureVerificationFailed, record.validate(alloc));
    // Restored slices own their data, independent from the source document.
    try restored.validate(alloc);
    var forged = restored;
    forged.seal.role = 5;
    try t.expectError(error.SignatureVerificationFailed, forged.validate(alloc));
    forged = restored;
    forged.current.?.begin.signed.request.command.authorization.begin.role = 5;
    try t.expectError(error.SignatureVerificationFailed, forged.validate(alloc));
    forged = restored;
    forged.current = null;
    try t.expectError(error.InvalidAuthorizationSet, forged.validate(alloc));
}

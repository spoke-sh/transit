//! Database-owned immutable client-token bindings. A binding selects saved
//! work; its catalog position is not the data operation's completion position.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;

pub const Key = struct {
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    account: [32]u8,
    token: [16]u8,

    pub fn scope(self: Key) c.DirectRecord.Scope {
        return .{ .definition = self.definition, .connection = self.connection, .account = self.account };
    }

    pub fn validate(self: Key) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        if (std.mem.allEqual(u8, &self.account, 0)) return error.InvalidClientToken;
    }
    /// Roles, credentials, target names and proposed operations cannot create
    /// another identity for the same principal/account/token in this catalog.
    pub fn digest(self: Key) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.client-token.v1\x00");
        var bytes: [8]u8 = undefined;
        inline for (.{ self.connection.scope.realm, self.connection.scope.resource, self.connection.scope.catalog, self.connection.principal }) |value| {
            std.mem.writeInt(u64, &bytes, value, .little);
            hash.update(&bytes);
        }
        hash.update(&self.account);
        hash.update(&self.token);
        return hash.finalResult();
    }
    pub fn requireSame(self: Key, other: Key) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
};

/// Optional request fence against a specific Catalog recovery revision. The
/// local host holds shared Catalog access through execution/disclosure; replacing
/// this record requires exclusive access, so stale requests cannot cross it.
pub const Lease = struct {
    key: Key,
    revision: p.DataLifecycle.Position,
    pub fn validate(self: Lease, connection: c.DirectTableProtocol.Connection) !void {
        try self.key.validate();
        try self.revision.validate();
        if (!std.meta.eql(self.key.connection.scope, connection.scope) or self.key.connection.principal != connection.principal or self.key.connection.audience != connection.audience) return error.InvalidClientToken;
    }
};

pub const Limits = struct {
    operations: u64 = 1_000_000,
    bytes: u64 = 4 * 1024 * 1024 * 1024,
    pending: u64 = 1024,
    pub fn validate(self: Limits) !void {
        if (self.operations == 0 or self.bytes == 0 or self.pending == 0) return error.InvalidClientToken;
    }
};
pub const Budget = struct {
    limits: Limits = .{},
    bytes: u64 = 4608,
    pub fn validate(self: Budget) !void {
        try self.limits.validate();
        if (self.bytes < 512 or self.bytes > self.limits.bytes) return error.InvalidClientToken;
    }
};
/// Sum of admitted transaction ceilings, independent of transient residency.
/// This is retained with the account's token usage and includes every role.
pub const TransactionReservations = struct {
    count: u64,
    resident_bytes: u64,
    workspace_bytes: u64,
    participants: u64,
    statements: u64,
    savepoints: u64,

    pub const empty: TransactionReservations = .{ .count = 0, .resident_bytes = 0, .workspace_bytes = 0, .participants = 0, .statements = 0, .savepoints = 0 };
    pub const defaults: TransactionReservations = .{ .count = 128, .resident_bytes = 64 * 1024 * 1024, .workspace_bytes = 4 * 1024 * 1024 * 1024, .participants = 400_000, .statements = 400_000, .savepoints = 4096 };

    fn transition(self: TransactionReservations, begin: p.Transaction.Begin, add: bool) !TransactionReservations {
        var next = self;
        inline for (@typeInfo(TransactionReservations).@"struct".field_names) |name| {
            const amount = if (comptime std.mem.eql(u8, name, "count")) 1 else @field(begin.limits, name);
            @field(next, name) = if (add) try std.math.add(u64, @field(next, name), amount) else try std.math.sub(u64, @field(next, name), amount);
        }
        return next;
    }
    pub fn requireWithin(self: TransactionReservations, limits: TransactionReservations) !void {
        inline for (@typeInfo(TransactionReservations).@"struct".field_names) |name| {
            if (@field(self, name) > @field(limits, name)) return error.TransactionAccountCapacity;
        }
    }
};

/// Counters share the primary token's account scope, including all login roles.
/// Settlement releases pending capacity; accepted identities and byte charges
/// remain retained. Quota pressure never expires accepted work.
pub const Usage = struct {
    limits: Limits,
    operations: u64 = 0,
    bytes: u64 = 0,
    pending: u64 = 0,
    /// Mandatory on disk: old usage must never silently acquire zero charges.
    transactions: TransactionReservations,
    pub fn initial(limits: Limits) Usage {
        return .{ .limits = limits, .transactions = .empty };
    }
    pub fn transition(self: Usage, before: ?Progress, after: Progress) !Usage {
        var next = self;
        const budget = after.receipt.binding.budget;
        if (!std.meta.eql(self.limits, budget.limits)) return error.ClientBudgetConflict;
        if (before) |prior| {
            if (prior.pending and !after.pending) {
                next.pending = try std.math.sub(u64, next.pending, 1);
                if (after.receipt.binding.intent == .transaction)
                    next.transactions = try next.transactions.transition(after.receipt.binding.intent.transaction.begin, false);
            }
        } else {
            next.operations = try std.math.add(u64, next.operations, 1);
            next.bytes = try std.math.add(u64, next.bytes, budget.bytes);
            next.pending = try std.math.add(u64, next.pending, 1);
            if (after.receipt.binding.intent == .transaction)
                next.transactions = try next.transactions.transition(after.receipt.binding.intent.transaction.begin, true);
        }
        if (next.operations > next.limits.operations or next.bytes > next.limits.bytes or next.pending > next.limits.pending) return error.ClientTokenCapacity;
        return next;
    }
};
pub fn usageKey(key: Key) !c.storage.TreeStore.pages.Key {
    var account = key;
    account.token = @splat(0);
    return c.storage.TreeStore.pages.Key.init(&try account.digest());
}

pub const Binding = struct {
    key: Key,
    /// Caller-defined commitment to the complete original request, including
    /// parameters and selected database. The catalog does not interpret SQL.
    fingerprint: [32]u8,
    intent: c.DirectIntent.Reference,
    budget: Budget = .{},

    pub fn validate(self: Binding) !void {
        try self.key.validate();
        try self.intent.validate();
        try self.budget.validate();
        if (self.intent == .history and !std.mem.eql(u8, &self.fingerprint, &try self.intent.history.digest())) return error.ClientTokenConflict;
        if (self.intent == .branch and !std.mem.eql(u8, &self.fingerprint, &try self.intent.branch.digest())) return error.ClientTokenConflict;
        if (self.intent == .workload and self.budget.bytes < try self.intent.workload.reservationBytes()) return error.ClientTokenBudget;
        if (self.intent == .transaction_call and self.budget.bytes < c.DirectTransactionCall.reservation_bytes) return error.ClientTokenBudget;
        if (self.intent == .transaction and self.intent.transaction.purpose == .queue_transfer and
            !std.meta.eql(self.key.scope(), self.intent.transaction.purpose.queue_transfer.scope)) return error.DataIdentityConflict;
        if (!std.meta.eql(self.key.connection, self.intent.connection()) or
            std.mem.allEqual(u8, &self.fingerprint, 0)) return error.InvalidClientToken;
        if (self.intent == .external and !std.mem.eql(u8, &self.key.account, &self.intent.external.record.scope.account)) return error.InvalidClientToken;
        if (self.intent == .log and !std.mem.eql(u8, &self.key.account, &self.intent.log.record.scope.account)) return error.InvalidClientToken;
        if (self.intent == .workload and !std.mem.eql(u8, &self.key.account, &self.intent.workload.record.scope.account)) return error.InvalidClientToken;
    }
    /// Racing preparations of the same request may propose different operation
    /// IDs or cuts. Only the originally accepted reference may be dispatched.
    pub fn retry(self: Binding, proposed: Binding) !void {
        try self.validate();
        try proposed.validate();
        try self.key.requireSame(proposed.key);
        if (!std.mem.eql(u8, &self.fingerprint, &proposed.fingerprint)) return error.ClientTokenConflict;
    }
};

pub const Receipt = struct {
    binding: Binding,
    position: p.DataLifecycle.Position,
    /// Catalog-reserved transaction decision partition, never a commit LSN.
    /// Mandatory even when null so older receipts cannot gain a default owner.
    coordination: ?u64,
    pub fn validate(self: Receipt) !void {
        try self.binding.validate();
        try self.position.validate();
        if (self.position.next_lsn < 2) return error.InvalidClientToken;
        if ((self.binding.intent == .transaction) != (self.coordination != null)) return error.InvalidClientToken;
        if (self.coordination) |partition| {
            if (partition <= self.position.partition or partition == std.math.maxInt(u64)) return error.InvalidClientToken;
        }
    }
};

/// Recovery bookkeeping is distinct from an operation's authoritative outcome.
/// The original receipt never changes. A settled entry cannot become pending.
pub const Progress = struct {
    receipt: Receipt,
    revision: p.DataLifecycle.Position,
    pending: bool,
    cancel: bool,
    record: ?c.DirectRecord.Reference,
    pub fn initial(receipt: Receipt) Progress {
        return .{ .receipt = receipt, .revision = receipt.position, .pending = true, .cancel = false, .record = null };
    }
    pub fn validate(self: Progress) !void {
        try self.receipt.validate();
        try self.revision.validate();
        if (self.revision.partition != self.receipt.position.partition or self.revision.next_lsn < self.receipt.position.next_lsn) return error.InvalidClientToken;
        if (self.record) |value| {
            try value.validate();
            if (!std.meta.eql(value.scope, self.receipt.binding.key.scope())) return error.DataIdentityConflict;
        }
    }
    pub fn id(self: Progress) u64 {
        return self.receipt.position.next_lsn;
    }
};
pub const Update = struct {
    key: Key,
    expected: p.DataLifecycle.Position,
    pending: bool,
    cancel: bool,
    record: ?c.DirectRecord.Reference,
    pub fn validate(self: Update) !void {
        try self.key.validate();
        try self.expected.validate();
        if (self.expected.next_lsn < 2) return error.InvalidClientToken;
        if (self.record) |value| {
            try value.validate();
            if (!std.meta.eql(value.scope, self.key.scope())) return error.DataIdentityConflict;
        }
    }
};
pub const Selection = struct {
    scope: c.DirectRecord.Scope,
    after: ?u64,
    pending: bool,
};
pub const Page = struct { entries: [8]?Progress = @splat(null), next: ?u64 = null };
pub const ProgressRequest = union(enum) {
    inspect: Key,
    operation: struct { scope: c.DirectRecord.Scope, id: u64 },
    list: Selection,
    update: Update,
    pub fn scope(self: ProgressRequest) c.DirectRecord.Scope {
        return switch (self) {
            .inspect => |value| value.scope(),
            .update => |value| value.key.scope(),
            inline .operation, .list => |value| value.scope,
        };
    }
    pub fn validate(self: ProgressRequest) !void {
        try self.scope().validate();
        switch (self) {
            .inspect => |value| try value.validate(),
            .update => |value| try value.validate(),
            .operation => |value| if (value.id < 2) return error.InvalidClientToken,
            .list => {},
        }
    }
};
pub const ProgressResult = union(enum) { state: ?Progress, page: Page };

pub fn accountPrefix(scope: c.DirectRecord.Scope) ![24]u8 {
    try scope.validate();
    var buffer: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(scope, &encoder);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(writer.buffered(), &hash, .{});
    return hash[0..24].*;
}
pub fn accountKey(scope: c.DirectRecord.Scope, id: u64) !c.storage.TreeStore.pages.Key {
    var bytes: [32]u8 = undefined;
    bytes[0..24].* = try accountPrefix(scope);
    std.mem.writeInt(u64, bytes[24..32], id, .big);
    return c.storage.TreeStore.pages.Key.init(&bytes);
}

pub fn inspect(client: c.DirectTableClient, key: Key) !?Progress {
    const response = try client.call(.{ .client_progress = .{ .inspect = key } });
    defer response.deinit();
    return response.value.result.client_progress.state;
}
pub fn operation(client: c.DirectTableClient, account: [32]u8, id: u64) !?Progress {
    const response = try client.call(.{ .client_progress = .{ .operation = .{ .scope = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = account }, .id = id } } });
    defer response.deinit();
    return response.value.result.client_progress.state;
}
pub fn list(client: c.DirectTableClient, account: [32]u8, after: ?u64, pending: bool) !Page {
    const response = try client.call(.{ .client_progress = .{ .list = .{ .scope = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = account }, .after = after, .pending = pending } } });
    defer response.deinit();
    return response.value.result.client_progress.page;
}
pub fn update(client: c.DirectTableClient, value: Update) !Progress {
    const response = try client.call(.{ .client_progress = .{ .update = value } });
    defer response.deinit();
    return response.value.result.client_progress.state orelse error.InvalidTableResponse;
}
pub const Request = union(enum) {
    lookup: Key,
    bind: Binding,
    pub fn key(self: Request) Key {
        return switch (self) {
            .lookup => |value| value,
            .bind => |value| value.key,
        };
    }
    pub fn validate(self: Request) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
    }
};

/// A lookup is observation only. No automatic retry or data admission occurs.
pub fn lookup(client: c.DirectTableClient, key: Key) !?Receipt {
    const response = try client.call(.{ .client_token = .{ .lookup = key } });
    defer response.deinit();
    return response.value.result.client_token;
}
/// Save the key before calling. A missing reply requires lookup or the same
/// binding attempt; dispatch only the reference in the returned receipt.
pub fn bind(client: c.DirectTableClient, binding: Binding) !Receipt {
    const response = try client.call(.{ .client_token = .{ .bind = binding } });
    defer response.deinit();
    return response.value.result.client_token orelse error.InvalidTableResponse;
}

test "direct client token signing and key identity match independent fixtures" {
    const t = std.testing;
    const w = c.DirectTableProtocol;
    const Fixture = struct { request: w.Request, public_key: [32]u8, key_digest: [32]u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-client-token-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    const binding = fixture.request.action.client_token.bind;
    try t.expectEqualDeep(fixture.key_digest, try binding.key.digest());
    try t.expectEqual(std.math.maxInt(u64), binding.intent.table.binding.identity.operation);
    var changed_key = binding.key;
    changed_key.connection.role = 12;
    try t.expectEqualDeep(fixture.key_digest, try changed_key.digest());
    try t.expectError(error.DataIdentityConflict, binding.key.requireSame(changed_key));
    var changed = fixture.request;
    changed.action.client_token.bind.fingerprint[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    try t.expect(fixture.request.transport().mutation);
    changed.action = .{ .client_token = .{ .lookup = binding.key } };
    try t.expect(!changed.transport().mutation);

    const response: w.Response = .{ .definition = p.Growth.current_definition, .context = fixture.request.proof.claim.context, .policy_revision = 1, .subject = .{ .principal = 4, .login_role = 4, .role = 4, .credential_epoch = 1, .audience = 5, .context = fixture.request.proof.claim.context }, .result = .{ .client_token = .{ .binding = binding, .coordination = null, .position = .{ .partition = 1, .next_lsn = 2 } } } };
    try c.DirectTableClient.validateResponse(t.allocator, fixture.request, response);
    var damaged = response;
    damaged.result.client_token = null;
    try t.expectError(error.InvalidTableResponse, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
    damaged = response;
    damaged.result.client_token.?.binding.key.account[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
    damaged = response;
    damaged.result.client_token.?.binding.fingerprint[0] ^= 1;
    try t.expectError(error.ClientTokenConflict, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
    damaged = response;
    damaged.result.client_token.?.position.next_lsn = 0;
    try t.expectError(error.InvalidClientToken, c.DirectTableClient.validateResponse(t.allocator, fixture.request, damaged));
}

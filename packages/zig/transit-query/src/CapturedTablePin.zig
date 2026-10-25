//! A direct Table pin owned by durable computation state. Admission/closure are
//! native decisions; direct acquisition/release follow their committed records.
//! Worker replacement does not close a live pin or replace the original grant.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const Turn = q.station.Turn;
const Grant = c.DirectReadDelegation;
const Handle = c.storage.TablePartition.SnapshotHandle;

/// The job is the admitting input's identity; source distinguishes independently
/// captured inputs. These are durable keys, not a resident collection bound.
pub const Slot = struct {
    job: u64,
    source: u32,
    fn validate(self: Slot) !void {
        try q.UnifiedRecords.identity(self.job);
    }
    fn key(self: Slot, part: u8) p.Value {
        var bytes: [16]u8 = undefined;
        bytes[0..3].* = "\x00QP".*;
        std.mem.writeInt(u64, bytes[3..11], self.job, .big);
        std.mem.writeInt(u32, bytes[11..15], self.source, .big);
        bytes[15] = part;
        return p.Value.init(&bytes) catch unreachable;
    }
};
pub const Phase = enum(u8) { acquiring = 1, closing = 2, closed = 3 };
pub const Retained = struct {
    handle: Handle,
    accepted: p.DataLifecycle.Position,
    authority: c.DirectReadAuthority,
    declaration_bytes: u64,
    schema: [32]u8,
    changed_lsn: u64,
    rows: u64,
    fn basis(self: Retained, record: Record) !c.DirectTableReader.Basis {
        const result: c.DirectTableReader.Basis = .{
            .snapshot = try record.snapshot(self.handle),
            .interpretation = .{ .interpretation = record.grant.binding.interpretation, .content = .{ .bytes = self.declaration_bytes, .sha256 = record.grant.binding.interpretation.digest }, .schema_fingerprint = self.schema, .retired = false },
            .accepted = self.accepted,
            .changed_lsn = self.changed_lsn,
            .row_count = self.rows,
            .authority = self.authority,
        };
        try result.interpretation.validate();
        try result.authority.validate();
        try record.grant.requireSource(result.interpretation.interpretation, result.accepted);
        if (result.changed_lsn > result.accepted.next_lsn) return error.InvalidQueryRecord;
        return result;
    }
};
pub const Record = struct {
    phase: Phase,
    resource: u64,
    worker: u64,
    slot: Slot,
    grant: Grant,
    pub const encoded_bytes = 33 + Grant.encoded_bytes;
    fn encode(self: Record, allocator: std.mem.Allocator) ![encoded_bytes]u8 {
        try q.UnifiedRecords.identity(self.resource);
        try q.UnifiedRecords.identity(self.worker);
        try self.slot.validate();
        var bytes: [encoded_bytes]u8 = undefined;
        bytes[0..4].* = "QTP1".*;
        bytes[4] = @backingInt(self.phase);
        std.mem.writeInt(u64, bytes[5..13], self.resource, .little);
        std.mem.writeInt(u64, bytes[13..21], self.worker, .little);
        std.mem.writeInt(u64, bytes[21..29], self.slot.job, .little);
        std.mem.writeInt(u32, bytes[29..33], self.slot.source, .little);
        bytes[33..].* = try self.grant.encode(allocator);
        return bytes;
    }
    fn decode(allocator: std.mem.Allocator, bytes: *const [encoded_bytes]u8) !Record {
        if (!std.mem.eql(u8, bytes[0..4], "QTP1")) return error.InvalidQueryRecord;
        const result: Record = .{
            .phase = std.enums.fromInt(Phase, bytes[4]) orelse return error.InvalidQueryRecord,
            .resource = std.mem.readInt(u64, bytes[5..13], .little),
            .worker = std.mem.readInt(u64, bytes[13..21], .little),
            .slot = .{ .job = std.mem.readInt(u64, bytes[21..29], .little), .source = std.mem.readInt(u32, bytes[29..33], .little) },
            .grant = try Grant.decode(allocator, bytes[33..]),
        };
        _ = try result.encode(allocator);
        return result;
    }
    fn check(self: Record, turn: *const Turn, slot: Slot) !void {
        if (!std.meta.eql(self.slot, slot) or self.resource != turn.view.resource or self.worker != turn.delivery.pid or
            self.grant.binding.connection.scope.realm != turn.delivery.realm or self.grant.binding.executor != turn.delivery.principal) return error.QueryDenied;
    }
    pub fn snapshot(self: Record, retained: Handle) !c.DirectTableProtocol.Snapshot {
        try retained.content.validate();
        if (!std.meta.eql(retained.owner, self.grant.binding.owner)) return error.SourceChanged;
        return .{ .object = self.grant.binding.interpretation.object, .handle = retained };
    }
};

fn read(allocator: std.mem.Allocator, reader: anytype, slot: Slot) !?Record {
    try slot.validate();
    const first = try reader.read(slot.key(0));
    const second = try reader.read(slot.key(1));
    if (first == null and second == null) return null;
    if (first == null or second == null or first.?.len != p.Value.max_bytes or second.?.len != Record.encoded_bytes - p.Value.max_bytes) return error.InvalidQueryRecord;
    var bytes: [Record.encoded_bytes]u8 = undefined;
    @memcpy(bytes[0..p.Value.max_bytes], first.?.slice());
    @memcpy(bytes[p.Value.max_bytes..], second.?.slice());
    const result = try Record.decode(allocator, &bytes);
    if (!std.meta.eql(result.slot, slot)) return error.InvalidQueryRecord;
    const claimed = (try reader.read(try ownerKey(result.grant))) orelse return error.InvalidQueryRecord;
    if (!claimed.eql(try ownerClaim(result))) return error.QueryNamespaceInUse;
    return result;
}
fn ownerKey(grant: Grant) !p.Value {
    var bytes: [40]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    inline for (.{ "realm", "resource", "catalog" }) |field| try writer.writeInt(u64, @field(grant.binding.owner.scope, field), .little);
    try writer.writeInt(u64, grant.binding.owner.principal, .little);
    try writer.writeInt(u64, grant.binding.owner.operation, .little);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.query.pin-owner.v1\x00");
    hash.update(&bytes);
    const digest = hash.finalResult();
    var address: [32]u8 = undefined;
    address[0..3].* = "\x00QO".*;
    address[3..].* = digest[0..29].*;
    return p.Value.init(&address);
}
fn ownerClaim(record: Record) !p.Value {
    var bytes: [68]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    inline for (.{ "realm", "resource", "catalog" }) |field| try writer.writeInt(u64, @field(record.grant.binding.owner.scope, field), .little);
    try writer.writeInt(u64, record.grant.binding.owner.principal, .little);
    try writer.writeInt(u64, record.grant.binding.owner.operation, .little);
    try writer.writeInt(u64, record.resource, .little);
    try writer.writeInt(u64, record.worker, .little);
    try writer.writeInt(u64, record.slot.job, .little);
    try writer.writeInt(u32, record.slot.source, .little);
    return p.Value.init(writer.buffered());
}
/// Inspection is read-only. An acquiring record may already own a remote pin
/// whose reply or native handle publication was lost; absence is not failure.
pub fn inspect(allocator: std.mem.Allocator, turn: *Turn, slot: Slot) !?Record {
    var current = turn.committed();
    const result = (try read(allocator, &current, slot)) orelse return null;
    try result.check(turn, slot);
    return result;
}
fn require(allocator: std.mem.Allocator, turn: *Turn, slot: Slot) !Record {
    return (try inspect(allocator, turn, slot)) orelse return error.QueryNotFound;
}
/// Three metadata mutations: the two grant fragments and a permanent pin-owner
/// claim. Commit with the admitted job's transition to acquisition eligibility.
/// This performs no remote work. A private record cannot acquire; another job
/// cannot reuse a grant and later release this job's live pin.
pub fn prepare(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, grant: Grant) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    const record: Record = .{ .phase = .acquiring, .resource = turn.view.resource, .worker = turn.delivery.pid, .slot = slot, .grant = grant };
    try record.check(turn, slot);
    const bytes = try record.encode(allocator);
    if (try read(allocator, turn, slot)) |existing| {
        if (!std.meta.eql(existing, record)) return error.QueryNamespaceInUse;
        return;
    }
    if (slot.job > turn.delivery.input.position or try turn.read(slot.key(2)) != null) return error.InvalidQueryRecord;
    const owner_key = try ownerKey(grant);
    if (try turn.read(owner_key) != null) return error.QueryNamespaceInUse;
    try turn.write(owner_key, try ownerClaim(record));
    try turn.write(slot.key(0), try p.Value.init(bytes[0..p.Value.max_bytes]));
    try turn.write(slot.key(1), try p.Value.init(bytes[p.Value.max_bytes..]));
}
fn evidence(turn: *Turn, record: Record) !?Retained {
    var current = turn.committed();
    return readEvidence(&current, record);
}
fn readEvidence(reader: anytype, record: Record) !?Retained {
    const value = (try reader.read(record.slot.key(2))) orelse return null;
    if (value.len != 172 or !std.mem.eql(u8, value.data[0..4], "QTH1")) return error.InvalidQueryRecord;
    if (!std.mem.eql(u8, value.data[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const result: Retained = .{
        .handle = .{ .owner = record.grant.binding.owner, .content = .{ .bytes = std.mem.readInt(u64, value.data[36..44], .little), .sha256 = value.data[44..76].* } },
        .authority = .{ .database = std.mem.readInt(u64, value.data[76..84], .little), .schema = std.mem.readInt(u64, value.data[84..92], .little), .table = std.mem.readInt(u64, value.data[92..100], .little) },
        .declaration_bytes = std.mem.readInt(u64, value.data[100..108], .little),
        .schema = value.data[108..140].*,
        .changed_lsn = std.mem.readInt(u64, value.data[140..148], .little),
        .rows = std.mem.readInt(u64, value.data[148..156], .little),
        .accepted = .{ .partition = std.mem.readInt(u64, value.data[156..164], .little), .next_lsn = std.mem.readInt(u64, value.data[164..172], .little) },
    };
    _ = try result.basis(record);
    return result;
}
/// Read immutable source evidence after traversal/closure without reopening the
/// remote pin. The caller separately checks current disclosure authorization.
pub fn source(allocator: std.mem.Allocator, reader: anytype, slot: Slot, worker: u64) !c.DirectTableReader.Basis {
    const record = (try observe(allocator, reader, slot, worker)) orelse return error.QueryNotFound;
    const retained = (try readEvidence(reader, record)) orelse return error.IncompleteSource;
    return retained.basis(record);
}
/// Public native readers can inspect cleanup independently of result status.
/// This performs no direct action; the reader supplies current resource access.
pub fn observe(allocator: std.mem.Allocator, reader: anytype, slot: Slot, worker: u64) !?Record {
    const record = (try read(allocator, reader, slot)) orelse return null;
    if (record.resource != reader.view.resource or record.worker != worker) return error.QueryIdentityMismatch;
    return record;
}
fn saveHandle(turn: *Turn, record: Record, value: Retained) !void {
    _ = try value.basis(record);
    var bytes: [172]u8 = undefined;
    bytes[0..4].* = "QTH1".*;
    bytes[4..36].* = p.Growth.definition_bytes;
    std.mem.writeInt(u64, bytes[36..44], value.handle.content.bytes, .little);
    bytes[44..76].* = value.handle.content.sha256;
    std.mem.writeInt(u64, bytes[76..84], value.authority.database, .little);
    std.mem.writeInt(u64, bytes[84..92], value.authority.schema, .little);
    std.mem.writeInt(u64, bytes[92..100], value.authority.table, .little);
    std.mem.writeInt(u64, bytes[100..108], value.declaration_bytes, .little);
    bytes[108..140].* = value.schema;
    std.mem.writeInt(u64, bytes[140..148], value.changed_lsn, .little);
    std.mem.writeInt(u64, bytes[148..156], value.rows, .little);
    std.mem.writeInt(u64, bytes[156..164], value.accepted.partition, .little);
    std.mem.writeInt(u64, bytes[164..172], value.accepted.next_lsn, .little);
    const encoded = try p.Value.init(&bytes);
    if (try turn.read(record.slot.key(2))) |existing| {
        if (!existing.eql(encoded)) return error.SourceChanged;
    } else try turn.write(record.slot.key(2), encoded);
}
fn phase(allocator: std.mem.Allocator, turn: *Turn, original: Record, next: Phase) !void {
    var changed = original;
    changed.phase = next;
    const bytes = try changed.encode(allocator);
    // The phase is entirely in the first fragment. The immutable second half
    // remains present, including after closure, for exact retry/inspection.
    try turn.write(changed.slot.key(0), try p.Value.init(bytes[0..p.Value.max_bytes]));
}
/// Commit this one-mutation decision with or after the job's transition away
/// from reading its input. It can also close an uncertain acquisition. No
/// release occurs until a later turn observes this committed decision.
pub fn beginClose(allocator: std.mem.Allocator, turn: *Turn, slot: Slot) !void {
    const record = (try read(allocator, turn, slot)) orelse return error.QueryNotFound;
    try record.check(turn, slot);
    if (record.phase == .acquiring) try phase(allocator, turn, record, .closing);
}

/// Translate only a checked direct-service rejection. An unavailable or
/// malformed reply preserves uncertainty and the original acquisition intent.
pub fn readFailure(client: c.DirectTableClient, err: anyerror) anyerror {
    if (err == error.AccessDenied) return error.CatalogDenied;
    if (err == error.Conflict or err == error.Rejected) {
        if (client.authority.last_rejection == .StaleAuthorizationCredential) return error.QueryDenied;
        return switch (client.service.last_rejection orelse return err) {
            .Conflict => error.SourceChanged,
            .QueryExpired => error.SourceChanged,
            .HistoryReclaimed => error.TableHistoryGap,
            .StaleAuthorizationCredential => error.QueryDenied,
            else => err,
        };
    }
    return err;
}
const Remote = struct {
    client: c.DirectTableClient,
    fn delegated(self: Remote, grant: Grant) !c.DirectTableClient {
        const connection = self.client.connection;
        const original = grant.binding.connection;
        if (self.client.delegation != null or self.client.closure != null or self.client.borrow != null or connection.principal != grant.binding.executor or connection.role != null or
            !std.meta.eql(connection.scope, original.scope) or connection.branch != original.branch or connection.audience != original.audience) return error.QueryDenied;
        var result = self.client;
        result.connection = original;
        result.delegation = grant;
        return result;
    }
    fn pin(self: Remote, grant: Grant) !Retained {
        const client = try self.delegated(grant);
        const acquisition: c.DirectTableProtocol.Acquisition = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner, .expected = grant.binding.expected, .selection = grant.binding.selection };
        const response = client.call(if (grant.binding.retention == .history) .{ .retain_history = acquisition } else .{ .pin = acquisition }) catch |err| return readFailure(client, err);
        defer response.deinit();
        const found = client.call(.{ .snapshot = .{ .object = grant.binding.interpretation.object, .handle = response.value.result.pin } }) catch |err| return readFailure(client, err);
        defer found.deinit();
        const value = found.value.result.snapshot;
        return .{ .handle = response.value.result.pin, .accepted = value.accepted, .authority = value.authority, .declaration_bytes = value.interpretation.content.bytes, .schema = value.interpretation.schema_fingerprint, .changed_lsn = value.changed_lsn, .rows = value.row_count };
    }
    fn close(self: Remote, grant: Grant, known: ?Handle) !void {
        const client = try self.delegated(grant);
        try client.closeOriginalPin(grant.binding.interpretation.object, grant.binding.owner, grant.binding.expected, known);
    }
    fn closeAuthorized(self: Remote, grant: Grant, authorization: Grant.Closure, known: ?Handle) !void {
        var client = try self.delegated(grant);
        client.closure = authorization;
        try client.closeOriginalPin(grant.binding.interpretation.object, grant.binding.owner, grant.binding.expected, known);
    }
};

/// Bind a configured executor route to an immutable original grant. Callers
/// separately establish committed retention before using this route for work.
pub fn delegatedClient(client: c.DirectTableClient, grant: Grant) !c.DirectTableClient {
    return (Remote{ .client = client }).delegated(grant);
}
/// Borrowed exchange routes never inherit the coordinator's cleanup capability.
pub fn borrowedClient(client: c.DirectTableClient, grant: Grant, borrow: Grant.Borrow) !c.DirectTableClient {
    const connection = client.connection;
    const original = grant.binding.connection;
    if (client.delegation != null or client.closure != null or client.borrow != null or connection.principal != borrow.binding.executor or connection.role != null or
        !std.meta.eql(connection.scope, original.scope) or connection.branch != original.branch or connection.audience != original.audience) return error.QueryDenied;
    var result = client;
    result.connection = original;
    result.delegation = grant;
    result.borrow = borrow;
    return result;
}
/// The configured executor's own key authenticates the original caller's saved
/// grant. Acquisition only follows committed admission and preserves its cut.
pub fn acquire(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, client: c.DirectTableClient) !c.DirectTableReader.Basis {
    return acquireWith(allocator, turn, slot, Remote{ .client = client });
}
fn acquireWith(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, remote: anytype) !c.DirectTableReader.Basis {
    const record = try require(allocator, turn, slot);
    if (record.phase != .acquiring or (try read(allocator, turn, slot)).?.phase != .acquiring) return error.QueryClosed;
    const known = try evidence(turn, record);
    const retained = try remote.pin(record.grant);
    if (known) |old| if (!std.meta.eql(old, retained)) return error.SourceChanged;
    try saveHandle(turn, record, retained);
    return retained.basis(record);
}
pub fn readClient(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, client: c.DirectTableClient) !c.DirectTableClient {
    const record = try require(allocator, turn, slot);
    if (record.phase != .acquiring) return error.QueryClosed;
    return (Remote{ .client = client }).delegated(record.grant);
}
/// A pure status read obtains native source requirements without creating a
/// pin. Admission can then commit under the query worker's own audience proof.
pub fn authorizeAdmission(turn: *Turn, grant: Grant, client: c.DirectTableClient) !void {
    const delegated = try (Remote{ .client = client }).delegated(grant);
    const response = delegated.call(.{ .pin_status = .{ .object = grant.binding.interpretation.object, .owner = grant.binding.owner } }) catch |err| return readFailure(delegated, err);
    defer response.deinit();
    try authorizeSource(turn, grant, response.value.result.pin_state.authority);
}
pub fn authorizeSource(turn: *Turn, grant: Grant, authority: c.DirectReadAuthority) !void {
    const subject = try turn.authorizationSubject(grant.binding.connection.principal);
    if (subject != .signed) return error.QueryDenied;
    const original = grant.proof.claim;
    const current = subject.signed.claim;
    if (current.definition != original.definition or current.realm != original.realm or current.principal != original.principal or
        current.credential_epoch != original.credential_epoch or current.role != original.role) return error.QueryDenied;
    _ = try turn.requireAuthorization(try authority.guard(subject));
}
/// Fence a later native progress/result commit with the exact policy objects
/// observed at direct capture. The enclosing bundle binds this execution proof
/// to its worker and immutable request before calling here.
pub fn authorizeExecution(allocator: std.mem.Allocator, turn: *Turn, slot: Slot) !void {
    const record = try require(allocator, turn, slot);
    const retained = (try evidence(turn, record)) orelse return error.IncompleteSource;
    try authorizeSource(turn, record.grant, retained.authority);
}
/// Reconcile only a committed closing decision. Failure leaves cleanup pending;
/// publishing closed state is a separate native commit, safe to retry after loss.
pub fn settle(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, client: c.DirectTableClient) !void {
    const record = try require(allocator, turn, slot);
    if (record.phase == .closed) return;
    if (record.phase != .closing) return error.QueryActive;
    var current = turn.committed();
    if (try current.read(slot.key(3))) |value| {
        const authorization = try Grant.Closure.decode(value.slice());
        const known = try evidence(turn, record);
        try (Remote{ .client = client }).closeAuthorized(record.grant, authorization, if (known) |retained| retained.handle else null);
        return phase(allocator, turn, record, .closed);
    }
    return settleWith(allocator, turn, slot, Remote{ .client = client });
}
/// Record fresh closure permission separately from the original read grant.
/// A later native turn performs release with these committed bytes. Rejection
/// or a lost response leaves both the original request and this intent intact.
pub fn authorizeCleanup(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, client: c.DirectTableClient, authorization: Grant.Closure) !void {
    const record = try require(allocator, turn, slot);
    if (record.phase == .closed) return;
    if (record.phase != .closing) return error.QueryActive;
    const bytes = try authorization.encode();
    if (try turn.read(slot.key(3))) |previous| {
        const existing = try Grant.Closure.decode(previous.slice());
        if (std.meta.eql(existing, authorization)) return;
        if (authorization.credential_epoch <= existing.credential_epoch) return error.QueryDenied;
    }
    var delegated = try (Remote{ .client = client }).delegated(record.grant);
    delegated.closure = authorization;
    const status = delegated.call(.{ .pin_status = .{ .object = record.grant.binding.interpretation.object, .owner = record.grant.binding.owner } }) catch |err| return readFailure(delegated, err);
    defer status.deinit();
    try turn.write(slot.key(3), try p.Value.init(&bytes));
}
fn settleWith(allocator: std.mem.Allocator, turn: *Turn, slot: Slot, remote: anytype) !void {
    const record = try require(allocator, turn, slot);
    if (record.phase == .closed) return;
    if (record.phase != .closing) return error.QueryActive;
    const known = try evidence(turn, record);
    try remote.close(record.grant, if (known) |value| value.handle else null);
    try phase(allocator, turn, record, .closed);
}

test "captured Table pins require committed admission and closure across lost replies and worker replacement" {
    const t = std.testing;
    const Store = @import("source_store_test.zig");
    const Fixture = struct {
        const Mock = struct {
            expected: Grant,
            retained: ?Handle = null,
            released: bool = false,
            calls: usize = 0,
            denied: bool = false,
            lose_reply: bool = false,
            fn pin(self: *@This(), grant: Grant) !Retained {
                self.calls += 1;
                try t.expectEqualDeep(self.expected, grant);
                if (self.denied) return error.AccessDenied;
                if (self.released) return error.TableSnapshotReleased;
                if (self.retained == null) self.retained = .{ .owner = grant.binding.owner, .content = .{ .bytes = 80, .sha256 = @splat(3) } };
                if (self.lose_reply) return error.ReadFailed;
                return .{ .handle = self.retained.?, .accepted = grant.binding.expected, .authority = .{ .database = 11, .schema = 12, .table = 13 }, .declaration_bytes = 128, .schema = @splat(41), .changed_lsn = 4, .rows = 2 };
            }
            fn close(self: *@This(), grant: Grant, known: ?Handle) !void {
                self.calls += 1;
                try t.expectEqualDeep(self.expected, grant);
                if (self.denied) return error.AccessDenied;
                if (known) |value| try t.expectEqualDeep(self.retained.?, value);
                self.released = true;
                if (self.lose_reply) return error.ReadFailed;
            }
        };
        fn createGrant() !Grant {
            const binding: Grant.Binding = .{
                .definition = p.Growth.current_definition,
                .connection = .{ .scope = .{ .realm = 1, .resource = 9, .catalog = 1 }, .branch = 1, .audience = 20, .principal = 21, .role = 21 },
                .executor = 2,
                .interpretation = .{ .object = .{ .scope = .{ .realm = 1, .resource = 9, .catalog = 1 }, .branch = 1, .object = 30 }, .revision = 1, .digest = @splat(1) },
                .expected = .{ .partition = 31, .next_lsn = 5 },
                .owner = .{ .scope = .{ .realm = 1, .resource = 9, .catalog = 1 }, .principal = 21, .operation = 32 },
                .retention = .snapshot,
                .purpose = @splat(2),
            };
            return .{ .binding = binding, .proof = try p.Authorization.Proof.sign(.{
                .definition = p.Growth.current_definition,
                .realm = 1,
                .principal = 21,
                .role = 21,
                .credential_epoch = 1,
                .audience = 20,
                .context = try binding.context(t.allocator),
            }, try c.testing.Authority.key(21)) };
        }
    };
    for ([_]bool{ false, true }) |publish_handle| {
        var store: Store = .{};
        defer store.deinit();
        const grant = try Fixture.createGrant();
        const slot: Slot = .{ .job = store.input, .source = 0 };
        var remote: Fixture.Mock = .{ .expected = grant };
        var turn = try store.capture();
        try prepare(t.allocator, &turn, slot, grant);
        try t.expect((try inspect(t.allocator, &turn, slot)) == null);
        try t.expectError(error.QueryNotFound, acquireWith(t.allocator, &turn, slot, &remote));
        try t.expectEqual(@as(usize, 0), remote.calls);
        // Preparation has room for its already admitted job's eligibility transition.
        try turn.write(q.UnifiedRecords.key('j', slot.job, 0), try p.Value.init("job"));
        try store.commit(turn);
        turn = try store.capture();
        var wire = q.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:0");
        defer wire.deinit();
        const wrong_executor: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &wire, .service = &wire, .connection = grant.binding.connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9)) };
        try t.expectError(error.QueryDenied, acquire(t.allocator, &turn, slot, wrong_executor));
        try t.expectError(error.QueryNamespaceInUse, prepare(t.allocator, &turn, .{ .job = turn.delivery.input.position, .source = 0 }, grant));
        var changed = grant;
        changed.proof.signature[0] ^= 1;
        try t.expectError(error.QueryNamespaceInUse, prepare(t.allocator, &turn, slot, changed));
        remote.lose_reply = true;
        try t.expectError(error.ReadFailed, acquireWith(t.allocator, &turn, slot, &remote));
        try t.expect(remote.retained != null);
        for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
        remote.lose_reply = false;
        var restart = try store.clone();
        defer restart.deinit();
        turn = try restart.capture();
        turn.delivery.generation = 2;
        turn.view.generation = 2;
        turn.decision.views[0] = turn.view;
        const first = try acquireWith(t.allocator, &turn, slot, &remote);
        // Lose the native handle commit after successful direct acquisition.
        turn = try restart.capture();
        try t.expectEqualDeep(first, try acquireWith(t.allocator, &turn, slot, &remote));
        if (publish_handle) try restart.commit(turn);
        if (publish_handle) {
            try restart.setRights(.{ .principal = 21 });
            var claim = grant.proof.claim;
            claim.audience = restart.pid;
            claim.context = @splat(34);
            const execution: p.Authorization.Subject = .{ .signed = try p.Authorization.Proof.sign(claim, try c.testing.Authority.key(21)) };
            turn = try restart.capture();
            try turn.bindAuthorizationSubject(execution);
            try authorizeExecution(t.allocator, &turn, slot);
            try t.expectEqualDeep(try (c.DirectReadAuthority{ .database = 11, .schema = 12, .table = 13 }).guard(execution), turn.decision.authorization.?);
            // A current denial prevents publishing buffered computation state.
            try restart.grantObject(21, 13, 0);
            turn = try restart.capture();
            try turn.bindAuthorizationSubject(execution);
            try t.expectError(error.AccessDenied, authorizeExecution(t.allocator, &turn, slot));
            try t.expect(turn.decision.authorization == null);
            try restart.grantObject(21, 13, c.TableAuthority.select);
            // A new credential epoch cannot renew the original execution.
            claim.credential_epoch += 1;
            turn = try restart.capture();
            try turn.bindAuthorizationSubject(.{ .signed = try p.Authorization.Proof.sign(claim, try c.testing.Authority.key(21)) });
            try t.expectError(error.QueryDenied, authorizeExecution(t.allocator, &turn, slot));
        }
        turn = try restart.capture();
        try beginClose(t.allocator, &turn, slot);
        try t.expectError(error.QueryClosed, acquireWith(t.allocator, &turn, slot, &remote));
        try t.expectError(error.QueryActive, settleWith(t.allocator, &turn, slot, &remote));
        try t.expect(!remote.released);
        try restart.commit(turn);
        turn = try restart.capture();
        try t.expectError(error.QueryDenied, settle(t.allocator, &turn, slot, wrong_executor));
        remote.denied = true;
        try t.expectError(error.AccessDenied, settleWith(t.allocator, &turn, slot, &remote));
        try t.expectEqual(.closing, (try inspect(t.allocator, &turn, slot)).?.phase);
        for (turn.decision.mutations) |mutation| try t.expect(mutation == null);
        remote.denied = false;
        remote.lose_reply = true;
        try t.expectError(error.ReadFailed, settleWith(t.allocator, &turn, slot, &remote));
        try t.expect(remote.released);
        remote.lose_reply = false;
        try settleWith(t.allocator, &turn, slot, &remote);
        // Lose the native closed-state commit too; exact closure repeats safely.
        turn = try restart.capture();
        try settleWith(t.allocator, &turn, slot, &remote);
        try restart.commit(turn);
        turn = try restart.capture();
        const calls = remote.calls;
        try settleWith(t.allocator, &turn, slot, &remote);
        try t.expectEqual(calls, remote.calls);
        try t.expectError(error.QueryClosed, acquireWith(t.allocator, &turn, slot, &remote));
        try t.expectError(error.QueryNamespaceInUse, prepare(t.allocator, &turn, slot, grant));
        try t.expectEqual(.closed, (try inspect(t.allocator, &turn, slot)).?.phase);
        turn.delivery.principal += 1;
        try t.expectError(error.QueryDenied, inspect(t.allocator, &turn, slot));
        turn.delivery.principal -= 1;
        _ = restart.state.remove(slot.key(1));
        try t.expectError(error.InvalidQueryRecord, inspect(t.allocator, &turn, slot));
    }
}

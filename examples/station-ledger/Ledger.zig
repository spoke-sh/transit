//! Application computation over a typed Table. A paged pending queue preserves
//! original input/call identity; the final Table head, audit and reply commit
//! together. Immutable audit entries are application KV, not another Table head.
const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const p = s.protocol;
const f = q.fuze;
const Authorization = @import("Authorization.zig");
pub const schema: f.TableSchema.Schema = .{ .object = 1, .revision = 1, .next_column = 3, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "amount", .type = .int64 },
}, .primary_key = &.{1} };
pub const name = q.catalog.TableMetadata.Name.init("ledger") catch unreachable;
pub const continuation = p.Value.init("ledger.drive") catch unreachable;
pub const create_continuation = p.Value.init("ledger.create") catch unreachable;
const pending_prefix = "\x00ledger.pending/";
const proof_prefix = "\x00ledger.subject/";
pub const audit_prefix = "\x00ledger.audit/";
pub fn catalog(realm: u64, resource: u64, owner: u64, profile: q.catalog.TableAuthority.Profile) q.catalog.TableCatalog {
    return .{ .configuration = .{ .scope = .{ .realm = realm, .resource = resource, .catalog = 1 }, .owner = owner, .administrator = 0, .database_name = q.catalog.TableAuthority.Name.init("ledger") catch unreachable, .authority = profile, .table_limits = .{ .record_bytes = 4096, .staging_bytes = 32768, .staging_records = 8 } } };
}
pub fn create(allocator: std.mem.Allocator, turn: *s.Turn, continuing: bool, profile: q.catalog.TableAuthority.Profile, registration: *?p.Authorization.Action) !void {
    var owner = catalog(turn.delivery.realm, turn.view.resource, turn.delivery.pid, profile);
    owner.registration = registration;
    const request = createRequest();
    const outcome = if (continuing) try owner.continueDdl(allocator, turn, request) else try owner.step(allocator, turn, request);
    if (outcome.terminal()) {
        if (outcome.operation.state != .applied) return error.LedgerInitializationFailed;
    } else try turn.cast(turn.delivery.pid, create_continuation);
}
fn createRequest() q.catalog.TableDdlRequest {
    return .{ .principal = 0, .operation = 1, .object = 1, .expected_revision = 0, .name = name, .action = .{ .create = .{ .schema = schema } } };
}
fn keyFor(prefix: []const u8, input: u64) p.Value {
    var bytes: [32]u8 = undefined;
    @memcpy(bytes[0..prefix.len], prefix);
    std.mem.writeInt(u64, bytes[prefix.len..][0..8], input, .big);
    return p.Value.init(bytes[0 .. prefix.len + 8]) catch unreachable;
}
const Pending = struct {
    input: u64,
    origin: u64,
    correlation: u64,
    delta: i64,
    prepared: ?struct { identity: f.TableRow.Identity, total: i64, insert: bool } = null,
    fn context(self: Pending) [36]u8 {
        var bytes: [36]u8 = undefined;
        bytes[0..4].* = "LDA1".*;
        std.mem.writeInt(u64, bytes[4..12], self.input, .little);
        std.mem.writeInt(u64, bytes[12..20], self.origin, .little);
        std.mem.writeInt(u64, bytes[20..28], self.correlation, .little);
        std.mem.writeInt(i64, bytes[28..36], self.delta, .little);
        return bytes;
    }
    fn encode(self: Pending) !p.Value {
        if (self.input == 0 or self.input > p.max_counter or self.origin > p.max_counter or (self.origin == 0) != (self.correlation == 0)) return error.InvalidLedgerWork;
        var bytes: [128]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("LDW1");
        try out.writeAll(&q.catalog.TableMetadata.definition());
        inline for (.{ "input", "origin", "correlation" }) |field| try out.writeInt(u64, @field(self, field), .little);
        try out.writeInt(i64, self.delta, .little);
        try out.writeByte(@intFromBool(self.prepared != null));
        if (self.prepared) |value| {
            try out.writeAll(&try value.identity.encode());
            try out.writeInt(i64, value.total, .little);
            try out.writeByte(@intFromBool(value.insert));
        }
        return p.Value.init(out.buffered());
    }
    fn decode(value: p.Value) !Pending {
        var in: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try in.take(4), "LDW1")) return error.InvalidLedgerWork;
        if (!std.mem.eql(u8, try in.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
        var result: Pending = .{ .input = try in.takeInt(u64, .little), .origin = try in.takeInt(u64, .little), .correlation = try in.takeInt(u64, .little), .delta = try in.takeInt(i64, .little) };
        switch (try in.takeByte()) {
            0 => {},
            1 => result.prepared = .{ .identity = try f.TableRow.Identity.decode(try in.takeArray(20)), .total = try in.takeInt(i64, .little), .insert = switch (try in.takeByte()) {
                0 => false,
                1 => true,
                else => return error.InvalidLedgerWork,
            } },
            else => return error.InvalidLedgerWork,
        }
        if (in.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidLedgerWork;
        return result;
    }
};
fn wake(turn: *s.Turn) !void {
    try turn.cast(turn.delivery.pid, continuation);
}
pub fn enqueue(turn: *s.Turn, frame: s.Frame, authority: Authorization) !void {
    const pending: Pending = .{ .input = turn.delivery.input.position, .origin = if (frame.kind == .call) try s.Frame.source(turn.delivery.input) else 0, .correlation = if (frame.kind == .call) frame.correlation else 0, .delta = try frame.payload.asInteger() };
    const key = keyFor(pending_prefix, pending.input);
    if (try turn.read(key) != null) return error.LedgerWorkAlreadyExists;
    const proof = try authority.prepare(turn, &pending.context());
    try authority.bind(turn, proof, &pending.context());
    _ = try catalog(turn.delivery.realm, turn.view.resource, turn.delivery.pid, authority.profile).authorize(turn, authority.client.principal, .inspect);
    try turn.write(key, try pending.encode());
    try turn.write(keyFor(proof_prefix, pending.input), try Authorization.encode(proof));
    try wake(turn);
}
fn first(turn: *s.Turn) !?Pending {
    var committed = turn.committed();
    const page = try committed.page(try p.Value.init(pending_prefix));
    const entry = page.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, entry.key.slice(), pending_prefix)) return null;
    const pending = try Pending.decode(entry.value);
    if (!entry.key.eql(keyFor(pending_prefix, pending.input))) return error.InvalidLedgerWork;
    return pending;
}
pub fn drive(allocator: std.mem.Allocator, turn: *s.Turn, authority: Authorization) !void {
    if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.AccessDenied;
    var pending = (try first(turn)) orelse return;
    const proof = try Authorization.decode((try turn.read(keyFor(proof_prefix, pending.input))) orelse return error.InvalidLedgerWork);
    try authority.bind(turn, proof, &pending.context());
    const owner = catalog(turn.delivery.realm, turn.view.resource, turn.delivery.pid, authority.profile);
    var definition = (try owner.lookup(allocator, turn, authority.client.principal, name)) orelse return wake(turn);
    defer definition.deinit();
    _ = try owner.authorizeObject(turn, authority.client.principal, 1, .read);
    if (pending.prepared == null) {
        const head = try s.TableHead.load(turn, 1);
        var stored = try head.readSchema(allocator, turn);
        defer stored.deinit();
        if (head.retired or head.pending != 0 or !std.mem.eql(u8, &try stored.schema.fingerprint(), &try schema.fingerprint())) return error.LedgerSchemaChanged;
        var reader: s.TablePages.Reader(*s.Turn) = .{ .pages = .{ .resource = turn.view.resource, .object = 1 }, .source = turn };
        const data: s.TableData = .{ .schema = schema, .index = head.index };
        const id = try data.findKey(allocator, &reader, &.{.{ .value = .{ .atom = .{ .signed = 1 } } }});
        var total: i64 = 0;
        if (id) |identity| {
            var row = (try data.get(allocator, &reader, identity)) orelse return error.InvalidTableIndex;
            defer row.deinit();
            const cell = row.row().cells[1];
            if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidLedgerValue;
            total = std.math.cast(i64, cell.value.atom.signed) orelse return error.InvalidLedgerValue;
        }
        pending.prepared = .{ .identity = id orelse .{ .origin = authority.client.principal + 1, .operation = pending.input, .ordinal = 0 }, .total = try std.math.add(i64, total, pending.delta), .insert = id == null };
        try turn.write(keyFor(pending_prefix, pending.input), try pending.encode());
        return wake(turn);
    }
    const prepared = pending.prepared.?;
    _ = try owner.authorizeObject(turn, authority.client.principal, 1, if (prepared.insert) .insert else .update);
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = prepared.total } } } };
    const row: f.TableRow.Row = .{ .identity = prepared.identity, .cells = &cells };
    var intent: [16]u8 = undefined;
    std.mem.writeInt(u64, intent[0..8], pending.input, .little);
    std.mem.writeInt(i64, intent[8..16], pending.delta, .little);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&intent, &digest, .{});
    const status = try s.TableWrite.stepWithReserve(allocator, turn, .{ .resource = turn.view.resource, .principal = authority.client.principal, .operation = pending.input, .schema = schema, .change = if (prepared.insert) .{ .insert = row } else .{ .update = row }, .owner_binding = digest }, 2);
    if (status.state == .building) return wake(turn);
    if (status.state != .applied or status.matched != 1) return error.LedgerMutationRejected;
    var audit: [16]u8 = undefined;
    std.mem.writeInt(i64, audit[0..8], pending.delta, .little);
    std.mem.writeInt(i64, audit[8..16], prepared.total, .little);
    try turn.write(keyFor(audit_prefix, pending.input), try p.Value.init(&audit));
    try turn.write(keyFor(pending_prefix, pending.input), null);
    // Retain the original proof beside the immutable audit. Removing the queue
    // entry does not erase attribution or consume an extra terminal mutation.
    if (pending.origin != 0) try turn.send(pending.origin, .{ .kind = .reply, .correlation = pending.correlation, .payload = p.Value.integer(prepared.total) });
    try wake(turn);
}

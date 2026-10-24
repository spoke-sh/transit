//! Application computation over a typed Table. A paged pending queue preserves
//! original input/call identity. A committed dispatch precedes direct Table
//! admission; its confirmed receipt precedes the atomic native audit and reply.
const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const p = s.protocol;
const f = q.fuze;
const Authorization = @import("Authorization.zig");
const Data = @import("Data.zig");
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
pub fn schemaAt(binding: Data.Binding) f.TableSchema.Schema {
    var value = schema;
    value.object = binding.object;
    return value;
}
const creation_key = p.Value.init("\x00ledger.creation") catch unreachable;
pub fn create(allocator: std.mem.Allocator, turn: *s.Turn, continuing: bool, authority: Authorization, binding: Data.Binding) !void {
    if (continuing) {
        if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.AccessDenied;
    } else switch (turn.delivery.input.origin) {
        .external => |origin| if (origin.principal != 0) return error.AccessDenied,
        else => return error.AccessDenied,
    }
    var creator = authority.client;
    creator.role = binding.owner_role;
    const client = try binding.client(allocator, creator);
    if (binding.executor != turn.delivery.principal) return error.InvalidLedgerDataBinding;
    const saved = try turn.read(creation_key);
    if (saved == null) {
        if (continuing) return error.InvalidLedgerWork;
        const initialized = try client.call(.initialize);
        defer initialized.deinit();
        const input = turn.delivery.input.position;
        var required: p.Authorization.Guard = .{ .subject = try turn.authorizationSubject(0), .requirements = @splat(null) };
        required.requirements[0] = .{ .object = .{ .kind = .realm, .id = 0 }, .privileges = p.permission(.admin) };
        var intent = try Data.creation(allocator, client, binding, schemaAt(binding), input, required);
        defer intent.deinit();
        const reference = try Data.stage(client, &intent, binding.namespace);
        try Data.prepare(allocator, turn, .{ .resource = turn.view.resource, .worker = turn.delivery.pid, .input = input, .purpose = .create, .reference = reference });
        try turn.write(creation_key, p.Value.integer(@intCast(input)));
    } else {
        const input = std.math.cast(u64, try saved.?.asInteger()) orelse return error.InvalidLedgerWork;
        switch (try Data.advance(allocator, turn, client, input, .create)) {
            .pending => {},
            .committed => return,
            .rejected, .cancelled => return error.LedgerInitializationFailed,
        }
    }
    try turn.cast(turn.delivery.pid, create_continuation);
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
pub fn enqueue(allocator: std.mem.Allocator, turn: *s.Turn, frame: s.Frame, authority: Authorization) !void {
    const pending: Pending = .{ .input = turn.delivery.input.position, .origin = if (frame.kind == .call) try s.Frame.source(turn.delivery.input) else 0, .correlation = if (frame.kind == .call) frame.correlation else 0, .delta = try frame.payload.asInteger() };
    const key = keyFor(pending_prefix, pending.input);
    if (try turn.read(key) != null) return error.LedgerWorkAlreadyExists;
    const proof = try authority.prepare(turn, &pending.context());
    try authority.bind(turn, proof, &pending.context());
    // Queue admission checks CONNECT; pending creation may still be running.
    // The eventual mutation checks SELECT and its exact write privilege.
    const client = try authority.data.client(allocator, authority.client);
    const described = try client.call(.describe);
    defer described.deinit();
    _ = try turn.requireAuthorization(try q.catalog.TableAuthority.guard(try turn.authorizationSubject(authority.client.principal), described.value.result.description.authority, null, null, .database));
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
pub fn drive(allocator: std.mem.Allocator, turn: *s.Turn, authority: Authorization, binding: Data.Binding) !void {
    if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.AccessDenied;
    var pending = (try first(turn)) orelse return;
    const proof = try Authorization.decode((try turn.read(keyFor(proof_prefix, pending.input))) orelse return error.InvalidLedgerWork);
    try authority.bind(turn, proof, &pending.context());
    const client = try binding.client(allocator, authority.client);
    if (pending.prepared == null) {
        var metadata = Data.definition(client, binding, schemaAt(binding)) catch |err| return if (err == error.LedgerInitializationRequired) wake(turn) else err;
        defer metadata.deinit();
        const existing = try Data.get(allocator, client, metadata.value, schemaAt(binding));
        pending.prepared = .{
            .identity = if (existing) |row| row.identity else try q.catalog.DirectTableProtocol.Rows.insertIdentity(.{ .scope = binding.scope, .principal = client.connection.principal, .operation = pending.input }, 0),
            .total = try std.math.add(i64, if (existing) |row| row.amount else 0, pending.delta),
            .insert = existing == null,
        };
        const prepared = pending.prepared.?;
        var required = try metadata.authority.guard(try turn.authorizationSubject(authority.client.principal));
        required.requirements[2].?.privileges |= if (prepared.insert) q.catalog.TableAuthority.insert else q.catalog.TableAuthority.update;
        var intent = try Data.mutation(allocator, client, metadata.value, schemaAt(binding), pending.input, .{ .identity = prepared.identity, .amount = prepared.total }, prepared.insert, required);
        defer intent.deinit();
        const reference = try Data.stage(client, &intent, binding.namespace);
        try Data.prepare(allocator, turn, .{ .resource = turn.view.resource, .worker = turn.delivery.pid, .input = pending.input, .purpose = .delta, .reference = reference });
        try turn.write(keyFor(pending_prefix, pending.input), try pending.encode());
        return wake(turn);
    }
    const prepared = pending.prepared.?;
    const record = (try Data.inspect(allocator, turn, turn.delivery.pid, pending.input)) orelse return error.InvalidLedgerWork;
    _ = try turn.requireAuthorization(record.reference.binding.prerequisite.?);
    switch (try Data.advance(allocator, turn, client, pending.input, .delta)) {
        .pending => return wake(turn),
        .committed => |evidence| if (evidence.outcome.matched != 1) return error.LedgerMutationRejected,
        .rejected, .cancelled => return error.LedgerMutationRejected,
    }
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

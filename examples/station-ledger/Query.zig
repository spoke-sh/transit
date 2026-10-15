//! Finite query composition for this application. Freeze actual catalog metadata
//! before uploading; every bounded continuation reconstructs the same bundle.
const std = @import("std");
const q = @import("transit_query");
const s = q.station;
const p = q.protocol;
const Ledger = @import("Ledger.zig");
const Authorization = @import("Authorization.zig");
pub const limits: q.Bundle.Limits = .{ .pages = 32, .segments = 8, .result_bytes = 65536 };
pub const continuation = p.Value.init("ledger.query") catch unreachable;
const prefix = "\x00ledger.query/";
fn proofKey(input: u64) p.Value {
    var bytes: [24]u8 = undefined;
    bytes[0..16].* = "\x00ledger.query-a/".*;
    std.mem.writeInt(u64, bytes[16..24], input, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn keyFor(input: u64) p.Value {
    var bytes: [prefix.len + 8]u8 = undefined;
    @memcpy(bytes[0..prefix.len], prefix);
    std.mem.writeInt(u64, bytes[prefix.len..], input, .big);
    return p.Value.init(&bytes) catch unreachable;
}
fn first(turn: *s.Turn) !?p.Growth.Entry {
    var committed = turn.committed();
    const page = try committed.page(try p.Value.init(prefix));
    const entry = page.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, entry.key.slice(), prefix)) return null;
    if (entry.key.len != prefix.len + 8) return error.InvalidLedgerQuery;
    return entry;
}
fn wake(turn: *s.Turn) !void {
    try turn.cast(turn.delivery.pid, continuation);
}
pub fn enqueue(allocator: std.mem.Allocator, turn: *s.Turn, resources: s.client.ResourceReader, resource: u64, owner: u64, authority: Authorization) !void {
    if (try q.UnifiedUpload.active(turn) != null or try first(turn) != null) {
        try turn.put(try p.Value.init("answer"), try p.Value.init("query.v1.busy"));
        return;
    }
    const catalog = Ledger.catalog(turn.delivery.realm, resource, owner, authority.profile);
    var client: q.catalog.TableClient = .{ .transport = authority.client.transport, .connection = .{ .scope = catalog.configuration.scope, .owner = owner, .principal = authority.client.principal, .role = authority.client.role }, .key = authority.client.key, .reader = resources };
    // Metadata inspection is performed by this requester, within its own PID
    // scope. The later execution proof has the ledger as its separate audience.
    var inspector = authority.client;
    inspector.role = null;
    client.authority = .{ .client = inspector, .subject = try authority.client.proof(turn.delivery.pid, try q.catalog.TableAuthority.binding(catalog.configuration.scope, .database, 0)) };
    var definition = (try client.lookup(allocator, Ledger.name)) orelse return error.LedgerInitializationFailed;
    defer definition.deinit();
    var source = try q.TableSource.from(allocator, catalog.configuration, definition);
    defer source.deinit();
    var bytes: [256]u8 = undefined;
    try turn.write(keyFor(turn.delivery.input.position), try p.Value.init(try source.source.encode(&bytes)));
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const description = try q.Bundle.fromSql(arena.allocator(), .{ .resource = resource, .source = .{ .table = source.source } }, "ledger", "SELECT id, amount FROM ledger", limits);
    const bundle = try description.authorize(authority.client, owner, turn.delivery.pid, turn.view.resource);
    try turn.write(proofKey(turn.delivery.input.position), try Authorization.encode(bundle.authorization.?));
    try wake(turn);
}
pub fn drive(allocator: std.mem.Allocator, turn: *s.Turn, owner: u64, observer: ?u64) !void {
    if (try s.Frame.source(turn.delivery.input) != turn.delivery.pid) return error.AccessDenied;
    const pending = (try first(turn)) orelse return;
    const namespace = std.mem.readInt(u64, pending.key.slice()[prefix.len..][0..8], .big);
    if (namespace == 0 or namespace > p.max_counter) return error.InvalidLedgerQuery;
    var source = try q.TableSource.decode(allocator, pending.value.slice());
    defer source.deinit();
    if (source.source.owner != owner or source.source.scope.realm != turn.delivery.realm or source.source.object != 1) return error.InvalidLedgerQuery;
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var bundle = try q.Bundle.fromSql(arena.allocator(), .{ .resource = source.source.scope.resource, .source = .{ .table = source.source } }, "ledger", "SELECT id, amount FROM ledger", limits);
    bundle.authorization = try Authorization.decode((try turn.read(proofKey(namespace))) orelse return error.InvalidLedgerQuery);
    _ = try bundle.subject(owner, turn.delivery.pid, turn.view.resource);
    const reference = try bundle.reference(turn.view.resource, namespace);
    const status = (try q.UnifiedUpload.status(turn, namespace)) orelse {
        try q.UnifiedUpload.begin(turn, reference);
        return wake(turn);
    };
    if (!std.meta.eql(status.reference, reference)) return error.InvalidLedgerQuery;
    switch (status.phase) {
        .uploading => {
            const publication = reference.publication();
            const descriptor = try publication.inspect(turn, reference.record);
            if (descriptor.written == reference.spec.chunks()) {
                try q.UnifiedUpload.seal(turn, namespace);
            } else {
                var bytes: [q.Bundle.max_bytes]u8 = undefined;
                const encoded = try bundle.encode(&bytes);
                const offset = descriptor.written * s.Publication.chunk_bytes;
                _ = try publication.append(turn, reference.record, descriptor.written, encoded[offset .. offset + try reference.spec.size(descriptor.written)]);
            }
            try wake(turn);
        },
        .sealed => {
            _ = try q.UnifiedUpload.submitWithObserver(turn, namespace, owner, observer);
            try turn.write(pending.key, null);
        },
        else => return error.InvalidLedgerQuery,
    }
}
/// The ordinary Waiting preprocessing has already authenticated the source and
/// correlation. The shared upload owns outcome decoding; the app saves its ID.
pub fn reply(turn: *s.Turn, frame: s.Frame, owner: u64) !bool {
    const index = (try turn.read(q.UnifiedRecords.key('i', frame.correlation, 0))) orelse return false;
    const namespace = try q.UnifiedRecords.readIdentity(index);
    try q.UnifiedUpload.reply(turn, frame, owner);
    const status = (try q.UnifiedUpload.status(turn, namespace)) orelse return error.InvalidLedgerQuery;
    if (status.phase == .complete) {
        try turn.put(try p.Value.init("last-query"), p.Value.integer(@intCast(namespace)));
    } else if (status.failure) |failure| {
        var bytes: [128]u8 = undefined;
        try turn.put(try p.Value.init("answer"), try p.Value.init(try std.fmt.bufPrint(&bytes, "station.query.error.{s}", .{if (failure.denied()) "QueryDenied" else @tagName(failure.code)})));
    } else try turn.put(try p.Value.init("answer"), try p.Value.init("query.v1.cancelled"));
    return true;
}

//! Signed ledger control/read client. One serialized caller owns each principal.
//! Transport attempts, processed inputs and domain outcomes remain separate.
const std = @import("std");
const g = @import("root.zig");
const wire = g.station.client;
const p = wire.protocol;
const native = p.Growth;
const Self = @This();
transport: *wire.Client,
ledger: g.Ledger,
principal: u64,
key: p.Ed25519.KeyPair,
pub const Prepared = struct {
    version: u8,
    definition: native.Definition,
    realm: u64,
    resource: u64,
    owner: u64,
    configuration: [32]u8,
    signed: native.SignedRequest,
    pub const max_saved_bytes = 4096;
    pub fn command(self: Prepared) !g.Control.Command {
        if (self.version != 1 or self.definition != native.current_definition) return error.IncompatibleDefinition;
        try native.validate(self.signed.request);
        const request = self.signed.request;
        if (self.realm == 0 or self.realm > p.max_counter or self.resource == 0 or self.resource > p.max_counter or self.owner == 0 or self.owner > p.max_counter or request.realm != self.realm or request.command != .send or request.command.send.pid != self.owner) return error.InvalidGatewayPrepared;
        const frame = try g.station.Frame.decode(request.command.send.value);
        if (frame.kind != .cast) return error.InvalidGatewayPrepared;
        return g.Control.Command.decode(frame.payload);
    }
    pub fn save(self: Prepared, allocator: std.mem.Allocator) ![]u8 {
        _ = try self.command();
        return std.json.Stringify.valueAlloc(allocator, self, .{});
    }
    pub fn restore(allocator: std.mem.Allocator, bytes: []const u8) !Prepared {
        if (bytes.len == 0 or bytes.len > max_saved_bytes) return error.InvalidGatewayPrepared;
        const parsed = try std.json.parseFromSlice(Prepared, allocator, bytes, .{});
        defer parsed.deinit();
        _ = try parsed.value.command();
        const canonical = try parsed.value.save(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical)) return error.InvalidGatewayPrepared;
        return parsed.value;
    }
};
pub fn reader(self: *Self) wire.ResourceReader {
    return .{ .wire = self.transport, .realm = self.ledger.configuration.realm, .principal = self.principal, .key = self.key };
}
pub fn source(self: *Self) !wire.ResourceReader.Reader {
    return self.reader().open(self.ledger.configuration.resource);
}
/// Bounded scratch at an already observed revision; no retained permission or
/// snapshot. Used for finite publication reads, with fresh native disclosure
/// checks still owned by their caller.
pub fn cachedSource(self: *Self, revision: u64) !wire.ResourceReader.Cached(wire.ResourceReader.Batches) {
    const batches = try self.reader().batches();
    return batches.cached(try batches.read(self.ledger.configuration.resource, revision, &.{g.LedgerRecords.key('h', 0, 0)}));
}
fn role(self: *Self, command: g.Control.Command) !void {
    const config = self.ledger.configuration;
    const expected = switch (command) {
        .initialize, .reconcile, .cancel, .capacity, .reserve => config.control,
        .begin, .begin_intent, .intent_part, .seal_intent, .session_cancel, .session_resume, .external_begin, .external_ready, .external_complete, .captured => config.ingress,
        else => config.coordinator,
    };
    if (self.principal != expected) return error.GatewayDenied;
}
pub fn prepare(self: *Self, command: g.Control.Command) !Prepared {
    try self.role(command);
    const config = self.ledger.configuration;
    const payload = try command.encode();
    const sequence = (try self.reader().query(.capabilities)).principal_sequence;
    const result: Prepared = .{ .version = 1, .definition = native.current_definition, .realm = config.realm, .resource = config.resource, .owner = config.owner, .configuration = try config.digest(), .signed = try native.sign(.{ .realm = config.realm, .principal = self.principal, .sequence = try std.math.add(u64, sequence, 1), .command = .{ .send = .{ .pid = config.owner, .value = try (g.station.Frame{ .kind = .cast, .payload = payload }).encode() } } }, self.key) };
    _ = try result.command();
    return result;
}
pub fn validate(self: *Self, prepared: Prepared) !void {
    const command = try prepared.command();
    try self.role(command);
    const config = self.ledger.configuration;
    if (prepared.realm != config.realm or prepared.resource != config.resource or prepared.owner != config.owner or prepared.signed.request.principal != self.principal or !std.mem.eql(u8, &prepared.configuration, &try config.digest())) return error.GatewayIdentityConflict;
    try p.Ed25519.Signature.fromBytes(prepared.signed.signature).verify(&try native.digest(prepared.signed.request), self.key.public_key);
}
pub fn submit(self: *Self, prepared: Prepared) !p.Receipt {
    try self.validate(prepared);
    return self.transport.submit(prepared.signed);
}
pub const Progress = union(enum) { pending, processed: ?g.Control.Disposition };
/// Observes one accepted native input. It neither retries sends nor allocates a
/// successor sequence. A processed result alone is not a SQL terminal outcome.
pub fn progress(self: *Self, prepared: Prepared, receipt: p.Receipt) !Progress {
    try self.validate(prepared);
    if (receipt.position == 0 or receipt.position > p.max_counter) return error.InvalidGatewayReceipt;
    const response = try self.reader().query(.{ .process = prepared.owner });
    if (response.body != .process or receipt.position > response.position) return error.InvalidAuthorityResponse;
    const state = response.body.process;
    if (state.process.lifecycle != .running or state.process.failure != null or !native.processReady(state.process)) return error.GatewayOwnerUnavailable;
    if (state.input) |input| {
        if (input.position == receipt.position and (input.origin != .external or input.origin.external.principal != self.principal or !input.value.eql(prepared.signed.request.command.send.value))) return error.GatewayIdentityConflict;
        if (input.position <= receipt.position) return .pending;
    }
    var current = try self.source();
    const encoded = (try current.read(g.LedgerRecords.key('i', receipt.position, 0))) orelse return .{ .processed = null };
    const result = try g.LedgerRecords.decode(g.Control.Disposition, encoded);
    if (result.input != receipt.position or result.principal != self.principal or !std.mem.eql(u8, &result.payload, &try g.catalog.Model.fingerprint(prepared.signed.request.command.send.value))) return error.GatewayIdentityConflict;
    return .{ .processed = result };
}
test "ledger client persists exact current signed controls and validates identity without I/O" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(31));
    const config: g.Ledger.Configuration = .{ .realm = 1, .resource = 7, .owner = 3, .worker = 2, .ingress = 4, .control = 5, .coordinator = 10, .table_principal = 6, .reader = 11, .account = @splat(7), .bindings = &.{.{ .resource = 8, .catalog = 1, .owner = 9 }}, .intent_bytes = 4096, .operation_quota = 100, .byte_quota = 1024 * 1024 };
    var client: Self = .{ .transport = undefined, .ledger = .{ .configuration = config }, .principal = 5, .key = key };
    const original: Prepared = .{ .version = 1, .definition = native.current_definition, .realm = config.realm, .resource = config.resource, .owner = config.owner, .configuration = try config.digest(), .signed = try native.sign(.{ .realm = 1, .principal = 5, .sequence = 1, .command = .{ .send = .{ .pid = 3, .value = try (g.station.Frame{ .kind = .cast, .payload = try (g.Control.Command{ .reconcile = 7 }).encode() }).encode() } } }, key) };
    try client.validate(original);
    const bytes = try original.save(t.allocator);
    defer t.allocator.free(bytes);
    try t.expect(bytes.len <= Prepared.max_saved_bytes);
    const restored = try Prepared.restore(t.allocator, bytes);
    try t.expectEqualDeep(original, restored);
    var changed = original;
    changed.configuration[0] ^= 1;
    try t.expectError(error.GatewayIdentityConflict, client.validate(changed));
    changed = original;
    changed.signed.signature[0] ^= 1;
    if (client.validate(changed)) |_| return error.ExpectedSignatureFailure else |_| {}
    const spaced = try std.fmt.allocPrint(t.allocator, "{s}\n", .{bytes});
    defer t.allocator.free(spaced);
    try t.expectError(error.InvalidGatewayPrepared, Prepared.restore(t.allocator, spaced));
}

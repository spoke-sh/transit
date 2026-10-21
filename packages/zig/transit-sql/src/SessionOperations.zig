//! Paged, account-scoped references to independently owned durable operations.
//! This index records original identities; it grants no configuration/query rights.
const std = @import("std");
const g = @import("root.zig");
const s = g.station;
const p = g.catalog.protocol;
const r = g.LedgerRecords;
pub const Kind = enum(u8) { table = 1, configuration = 2, captured = 3 };
pub const Reference = struct {
    pub const magic = "GSR1";
    id: u64,
    kind: Kind,
    nonce: [16]u8,
    pub fn validate(self: Reference) !void {
        if (self.id == 0 or self.id > p.max_counter) return error.InvalidSqlOperationReference;
    }
};
pub const Begin = struct {
    nonce: [16]u8,
    fingerprint: [32]u8,
    kind: Kind,
    binding: g.Ledger.Binding,
    original: [16]u8,
    source: [32]u8,
    expected_generation: u64,
    reservation: u32,
};
pub const External = struct {
    pub const magic = "GSX1";
    id: u64,
    nonce: [16]u8,
    kind: Kind,
    resource: u64,
    catalog: u64,
    owner: u64,
    namespace: u64,
    role: u64,
    role_present: u8,
    original: [16]u8,
    source: [32]u8,
    expected_generation: u64,
    phase: enum(u8) { reserved = 1, ready = 2, terminal = 3 },
    length: u32 = 0,
    digest: [32]u8 = @splat(0),
    reservation: u64,
    summary: enum(u8) { none = 0, applied = 1, rejected = 2, cancelled = 3, partial = 4 } = .none,
    pub fn binding(self: External) g.Ledger.Binding {
        return .{ .resource = self.resource, .catalog = self.catalog, .owner = self.owner, .namespace = self.namespace, .role = if (self.role_present == 1) self.role else null };
    }
    pub fn validate(self: External) !void {
        if (self.id == 0 or self.id > p.max_counter or self.kind == .table or self.resource == 0 or self.catalog == 0 or self.owner == 0 or self.namespace == 0 or self.role_present > 1 or self.role > p.max_counter or (self.role_present == 0 and self.role != 0) or self.expected_generation == 0) return error.InvalidSqlOperationReference;
        if ((self.phase == .terminal) != (self.summary != .none) or (self.phase == .terminal and self.reservation != 0) or (self.phase != .terminal and self.reservation < 512)) return error.InvalidSqlOperationReference;
        if (self.phase == .reserved and (self.length != 0 or !std.mem.allEqual(u8, &self.digest, 0))) return error.InvalidSqlOperationReference;
    }
};
pub fn decodeReference(bytes: p.Value) !Reference {
    if (std.mem.startsWith(u8, bytes.slice(), r.Operation.magic)) {
        const item = try r.decode(r.Operation, bytes);
        return .{ .id = item.id, .kind = .table, .nonce = item.nonce };
    }
    const item = try r.decode(External, bytes);
    return .{ .id = item.id, .kind = item.kind, .nonce = item.nonce };
}
pub fn reference(ledger: g.Ledger, source: anytype, id: u64) !Reference {
    _ = try ledger.head(source);
    const value = try decodeReference((try source.read(r.key('o', id, 0))) orelse return error.MissingGatewayOperation);
    if (value.id != id) return error.GatewayIdentityConflict;
    return value;
}
pub fn lookup(ledger: g.Ledger, source: anytype, nonce: [16]u8, fingerprint: ?[32]u8) !?Reference {
    _ = try ledger.head(source);
    const index = try r.decode(r.Nonce, (try source.read(r.nonceKey(nonce))) orelse return null);
    if (!std.mem.eql(u8, &index.nonce, &nonce)) return error.GatewayIdentityConflict;
    if (fingerprint) |expected| if (!std.mem.eql(u8, &expected, &index.fingerprint)) return error.SqlTokenConflict;
    const value = try reference(ledger, source, index.id);
    if (!std.mem.eql(u8, &value.nonce, &nonce)) return error.GatewayIdentityConflict;
    return value;
}
pub fn external(ledger: g.Ledger, source: anytype, id: u64) !External {
    const ref = try reference(ledger, source, id);
    if (ref.kind == .table) return error.InvalidSqlOperationReference;
    const value = try r.decode(External, (try source.read(r.key('o', id, 0))) orelse return error.MissingGatewayOperation);
    if (value.id != id or value.kind != ref.kind or !std.mem.eql(u8, &value.nonce, &ref.nonce)) return error.GatewayIdentityConflict;
    try ledger.admittedBinding(value.binding());
    return value;
}
pub fn begin(ledger: g.Ledger, turn: *s.Turn, input: Begin) !External {
    const before = turn.decision;
    errdefer turn.decision = before;
    try ledger.actor(turn, .ingress, null);
    try ledger.admittedBinding(input.binding);
    if (input.kind == .table or input.reservation < 512 or input.reservation > 4 * 1024 * 1024) return error.InvalidSqlOperationReference;
    if (try lookup(ledger, turn, input.nonce, input.fingerprint)) |ref| {
        if (ref.kind != input.kind) return error.SqlTokenConflict;
        // The recorded original identity wins; a caller cannot replace it with
        // a freshly generated ID or a new configuration generation on retry.
        return external(ledger, turn, ref.id);
    }
    var header = try ledger.head(turn);
    if (header.operations == header.operation_quota or header.unsettled == header.pending_quota or input.reservation > header.byte_quota - header.used_bytes - header.reserved_bytes) return error.GatewayAdmissionCapacity;
    const value: External = .{ .id = turn.delivery.input.position, .nonce = input.nonce, .kind = input.kind, .resource = input.binding.resource, .catalog = input.binding.catalog, .owner = input.binding.owner, .namespace = input.binding.namespace, .role = input.binding.role orelse 0, .role_present = @intFromBool(input.binding.role != null), .original = input.original, .source = input.source, .expected_generation = input.expected_generation, .phase = .reserved, .reservation = input.reservation };
    try value.validate();
    header.operations += 1;
    header.unsettled += 1;
    header.reserved_bytes += value.reservation;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
    try turn.write(r.nonceKey(input.nonce), try r.encode(r.Nonce{ .id = value.id, .nonce = value.nonce, .fingerprint = input.fingerprint }));
    try turn.write(r.key('o', value.id, 0), try r.encode(value));
    try turn.write(r.key('w', value.id, 0), try r.encode(Reference{ .id = value.id, .kind = value.kind, .nonce = value.nonce }));
    return value;
}
pub fn ready(ledger: g.Ledger, turn: *s.Turn, id: u64, generation: u64, length: u32, digest: [32]u8) !void {
    try ledger.actor(turn, .ingress, generation);
    var value = try external(ledger, turn, id);
    if (value.phase != .reserved) {
        if (value.length != length or !std.mem.eql(u8, &value.digest, &digest)) return error.GatewayIdentityConflict;
        return;
    }
    if (length == 0 or @as(u64, length) + 512 > value.reservation) return error.GatewayRecoveryCapacity;
    value.phase = .ready;
    value.length = length;
    value.digest = digest;
    try turn.write(r.key('o', id, 0), try r.encode(value));
}
pub fn complete(ledger: g.Ledger, turn: *s.Turn, id: u64, generation: u64, summary: @FieldType(External, "summary")) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try ledger.actor(turn, .ingress, generation);
    var value = try external(ledger, turn, id);
    if (summary == .none) return error.InvalidSqlOperationReference;
    if (value.kind == .captured) {
        const capture = try g.CapturedLedger.state(ledger, turn, id);
        if (capture.pending != 0 or capture.staging != 0) return error.GatewayUnresolvedStep;
        if (value.phase == .reserved and (summary != .cancelled or capture.cancel != 1)) return error.InvalidSqlOperationReference;
    } else if (value.phase == .reserved) return error.InvalidSqlOperationReference;
    if (value.phase == .terminal) {
        if (value.summary != summary) return error.GatewayIdentityConflict;
        return;
    }
    var header = try ledger.head(turn);
    if (header.unsettled == 0 or header.reserved_bytes < value.reservation) return error.InvalidGatewayReservation;
    header.reserved_bytes -= value.reservation;
    // Charge the full declared journal bound: physical cleanup cannot create
    // logical admission capacity without an explicit reclamation contract.
    header.used_bytes += value.reservation;
    header.unsettled -= 1;
    value.phase = .terminal;
    value.summary = summary;
    value.reservation = 0;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
    try turn.write(r.key('o', id, 0), try r.encode(value));
    try turn.write(r.key('w', id, 0), null);
}
pub const Page = struct { entries: [p.Growth.page_size]?Reference = @splat(null), next: ?u64 = null };
pub fn list(ledger: g.Ledger, source: anytype, after_id: u64, pending: bool) !Page {
    _ = try ledger.head(source);
    const after = r.key(if (pending) 'w' else 'o', after_id, 0);
    const found = try source.page(after);
    try g.catalog.Inspection.validatePage(found, after, source.view.revision);
    var page: Page = .{};
    var count: usize = 0;
    for (found.entries) |entry| {
        const item = entry orelse break;
        if (!std.mem.startsWith(u8, item.key.slice(), after.data[0..4])) break;
        if (item.key.len != 20 or std.mem.readInt(u64, item.key.data[12..20], .big) != 0) return error.InvalidGatewayInventory;
        const ref = if (pending) try r.decode(Reference, item.value) else try decodeReference(item.value);
        if (ref.id != std.mem.readInt(u64, item.key.data[4..12], .big)) return error.GatewayIdentityConflict;
        page.entries[count] = ref;
        count += 1;
    }
    if (count == page.entries.len and found.next != null) page.next = page.entries[count - 1].?.id;
    return page;
}

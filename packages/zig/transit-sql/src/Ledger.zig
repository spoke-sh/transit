//! Account-private paged operation ownership above Station. These transitions
//! record work; dispatch remains an explicit coordinator responsibility.
const std = @import("std");
const g = @import("root.zig");
const s = g.station;
const c = g.catalog;
const p = c.protocol;
const Pub = s.Publication;
const r = g.LedgerRecords;
const Self = @This();
configuration: Configuration,
pub const Binding = struct {
    resource: u64,
    catalog: u64,
    owner: u64,
    namespace: u64 = 1,
    role: ?u64 = null,
};
pub const Configuration = struct {
    realm: u64,
    resource: u64,
    owner: u64,
    worker: u64,
    ingress: u64,
    control: u64,
    coordinator: u64,
    table_principal: u64,
    reader: u64,
    account: [32]u8,
    bindings: []const Binding,
    intent_bytes: u32 = c.DirectTableIntent.max_bytes,
    operation_quota: u64,
    byte_quota: u64,
    pending_quota: u32 = 16,
    pub fn validate(self: Configuration) !void {
        inline for (.{ self.realm, self.resource, self.owner, self.worker, self.ingress, self.control, self.coordinator, self.table_principal, self.reader }) |id| if (id == 0 or id > p.max_counter) return error.InvalidGatewayConfiguration;
        const identities = [_]u64{ self.worker, self.ingress, self.control, self.coordinator, self.table_principal, self.reader };
        for (identities, 0..) |id, i| for (identities[0..i]) |other| if (id == other) return error.InvalidGatewayConfiguration;
        if (self.bindings.len == 0 or self.bindings.len > 8 or self.intent_bytes < c.DirectTableIntent.prefix_bytes or self.intent_bytes > c.DirectTableIntent.max_bytes or self.operation_quota == 0 or self.byte_quota < self.reservation() or self.pending_quota == 0 or self.pending_quota > 1024) return error.InvalidGatewayConfiguration;
        for (self.bindings, 0..) |binding, i| {
            if (binding.resource == self.resource or binding.resource == 0 or binding.resource > p.max_counter or binding.owner == 0 or binding.owner > p.max_counter or binding.catalog == 0 or binding.namespace == 0 or binding.namespace > p.max_counter or (binding.role != null and binding.role.? > p.max_counter)) return error.InvalidGatewayConfiguration;
            for (self.bindings[0..i]) |other| if (binding.resource == other.resource and binding.catalog == other.catalog and binding.namespace == other.namespace) return error.InvalidGatewayConfiguration;
        }
    }
    /// Only a bounded reference and terminal projection use private control
    /// storage. Complete work is separately charged by the direct data owner.
    pub fn reservation(_: Configuration) u64 {
        return g.IntentReference.max_bytes + 512;
    }
    pub fn digest(self: Configuration) ![32]u8 {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.sql-gateway.account.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(&self.account);
        var number: [8]u8 = undefined;
        inline for (.{ self.realm, self.resource, self.owner, self.worker, self.ingress, self.control, self.coordinator, self.table_principal, self.reader, @as(u64, self.intent_bytes), @as(u64, self.bindings.len) }) |id| {
            std.mem.writeInt(u64, &number, id, .little);
            hash.update(&number);
        }
        for (self.bindings) |binding| inline for (.{ binding.resource, binding.catalog, binding.owner, binding.namespace, @as(u64, @intFromBool(binding.role != null)), binding.role orelse 0 }) |id| {
            std.mem.writeInt(u64, &number, id, .little);
            hash.update(&number);
        };
        return hash.finalResult();
    }
};
pub fn publication(self: Self, id: u64) Pub {
    return .{ .resource = self.configuration.resource, .domain = .sql_gateway, .namespace = id };
}
pub fn actor(self: Self, turn: *s.Turn, who: enum { ingress, control, coordinator }, generation: ?u64) !void {
    try self.configuration.validate();
    if (turn.delivery.realm != self.configuration.realm or turn.delivery.pid != self.configuration.owner or turn.delivery.principal != self.configuration.worker or turn.view.resource != self.configuration.resource) return error.GatewayOwnerChanged;
    if (generation) |expected| if (expected == 0 or expected != turn.delivery.generation) return error.StaleGatewayCoordinator;
    const principal = switch (turn.delivery.input.origin) {
        .external => |origin| origin.principal,
        else => return error.GatewayDenied,
    };
    if (principal != switch (who) {
        .ingress => self.configuration.ingress,
        .control => self.configuration.control,
        .coordinator => self.configuration.coordinator,
    }) return error.GatewayDenied;
}
pub fn head(self: Self, source: anytype) !r.Head {
    if (source.view.resource != self.configuration.resource) return error.CrossResourceTransaction;
    const result = try r.decode(r.Head, (try source.read(r.key('h', 0, 0))) orelse return error.GatewayNotInitialized);
    if (!std.mem.eql(u8, &result.configuration, &try self.configuration.digest())) return error.GatewayConfigurationChanged;
    return result;
}
pub fn admittedBinding(self: Self, binding: Binding) !void {
    for (self.configuration.bindings) |candidate| if (std.meta.eql(candidate, binding)) return;
    return error.GatewayCatalogDenied;
}
pub fn operation(self: Self, source: anytype, id: u64) !r.Operation {
    _ = try self.head(source);
    const result = try r.decode(r.Operation, (try source.read(r.key('o', id, 0))) orelse return error.GatewayOperationNotFound);
    if (result.id != id) return error.GatewayIdentityConflict;
    try self.admittedBinding(.{ .resource = result.resource, .catalog = result.catalog, .owner = result.owner, .namespace = result.namespace, .role = result.selectedRole() });
    return result;
}
pub fn initialize(self: Self, turn: *s.Turn) !void {
    try self.actor(turn, .control, turn.delivery.generation);
    if (try turn.read(r.key('h', 0, 0)) != null) {
        _ = try self.head(turn);
        return;
    }
    // A provisioner dedicates a fresh private resource to this owner. A public
    // page proves it contains no gateway/publication records before adoption.
    var committed = turn.committed();
    const entries = try committed.page(null);
    for (entries.entries) |slot| if (slot) |entry| {
        if (!entry.key.eql(s.GenServer.descriptor_key) or !entry.value.eql(s.GenServer.descriptor)) return error.GatewayAlreadyPopulated;
    };
    if (entries.next != null) return error.GatewayAlreadyPopulated;
    try turn.write(r.key('h', 0, 0), try r.encode(r.Head{ .configuration = try self.configuration.digest(), .operation_quota = self.configuration.operation_quota, .byte_quota = self.configuration.byte_quota, .pending_quota = self.configuration.pending_quota }));
}
/// The input position allocates the operation ID. A nonce permits discovery
/// even if the caller loses the accepted begin receipt before seeing that ID.
pub fn begin(self: Self, turn: *s.Turn, nonce: [16]u8, binding: Binding, fingerprint: [32]u8) !r.Operation {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .ingress, null);
    try self.admittedBinding(binding);
    var header = try self.head(turn);
    if (try turn.read(r.nonceKey(nonce))) |value| {
        const previous = try r.decode(r.Nonce, value);
        if (!std.mem.eql(u8, &previous.nonce, &nonce)) return error.GatewayIdentityConflict;
        if (!std.mem.eql(u8, &previous.fingerprint, &fingerprint)) return error.SqlTokenConflict;
        const current = try self.operation(turn, previous.id);
        if (!std.mem.eql(u8, &current.nonce, &nonce) or current.resource != binding.resource or current.catalog != binding.catalog or current.owner != binding.owner or current.namespace != binding.namespace or current.selectedRole() != binding.role) return error.GatewayIdentityConflict;
        return current;
    }
    const reserve = self.configuration.reservation();
    if (header.operations == header.operation_quota or header.unsettled == header.pending_quota or reserve > header.byte_quota - header.used_bytes - header.reserved_bytes) return error.GatewayAdmissionCapacity;
    const result: r.Operation = .{ .id = turn.delivery.input.position, .nonce = nonce, .resource = binding.resource, .catalog = binding.catalog, .owner = binding.owner, .namespace = binding.namespace, .role_present = @intFromBool(binding.role != null), .role = binding.role orelse 0, .reservation = reserve };
    if (try turn.read(r.key('o', result.id, 0)) != null) return error.GatewayIdentityConflict;
    header.operations += 1;
    header.unsettled += 1;
    header.reserved_bytes += reserve;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
    try turn.write(r.key('o', result.id, 0), try r.encode(result));
    try turn.write(r.nonceKey(nonce), try r.encode(r.Nonce{ .id = result.id, .nonce = nonce, .fingerprint = fingerprint }));
    try turn.write(r.key('u', result.id, 0), try p.Value.init("upload"));
    return result;
}
pub fn beginIntent(self: Self, turn: *s.Turn, id: u64, spec: Pub.Spec) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .ingress, null);
    var item = try self.operation(turn, id);
    if (spec.format != r.intent_format or spec.length <= g.IntentReference.prefix_bytes or spec.length > g.IntentReference.max_bytes) return error.InvalidGatewayIntent;
    if (item.phase != .reserved) {
        if (!std.meta.eql(item.spec(), spec) or item.phase == .abandoned) return error.GatewayIdentityConflict;
        return;
    }
    const pubn = try Pub.create(turn, .sql_gateway, id, .{ .record_bytes = g.IntentReference.max_bytes, .staging_bytes = g.IntentReference.max_bytes, .staging_records = 1 });
    _ = try pubn.begin(turn, 1, spec);
    item.phase = .uploading;
    item.intent_length = spec.length;
    item.stored_bytes = spec.length;
    item.intent_digest = spec.digest;
    try turn.write(r.key('o', id, 0), try r.encode(item));
}
pub fn intentPart(self: Self, turn: *s.Turn, id: u64, offset: u32, bytes: []const u8) !void {
    try self.actor(turn, .ingress, null);
    const item = try self.operation(turn, id);
    if (item.phase != .uploading) return error.GatewayUploadClosed;
    _ = try g.Upload.append(self.publication(id), turn, 1, offset, bytes);
}
/// Seal is a persistence boundary only. A later committed read validates the
/// complete immutable reference before changing sealed bytes into dispatchable work.
pub fn sealIntent(self: Self, turn: *s.Turn, id: u64) !void {
    try self.actor(turn, .ingress, null);
    const item = try self.operation(turn, id);
    if (item.phase != .uploading) return error.GatewayUploadClosed;
    try g.Upload.seal(self.publication(id), turn, 1);
}
pub fn admitIntent(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, id: u64, generation: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .coordinator, generation);
    var item = try self.operation(turn, id);
    if (item.phase != .uploading) {
        if (item.phase == .abandoned) return error.GatewayUploadClosed;
        return;
    }
    var committed = turn.committed();
    const bytes = try g.Upload.read(allocator, self.publication(id), &committed, 1, g.IntentReference.max_bytes);
    defer allocator.free(bytes);
    const reference = try g.IntentReference.decode(allocator, bytes);
    try self.checkReference(item, reference);
    if (!std.meta.eql(try Pub.Digest.of(r.intent_format, bytes), item.spec())) return error.GatewayIdentityConflict;
    item.phase = .ready;
    item.stored_bytes = bytes.len;
    try turn.write(r.key('o', id, 0), try r.encode(item));
    try turn.write(r.key('q', id, 0), try p.Value.init("ready"));
    try turn.write(r.key('b', id, 0), try r.encode(try r.IntentBinding.from(reference)));
    try turn.write(r.key('u', id, 0), null);
}

/// Scheduling cursor over unsettled uploads or ready work. It is advisory:
/// every call uses a fresh authorized source and validates the referenced row.
/// Retained terminal history is outside either index's key range.
pub fn indexed(self: Self, source: anytype, kind: enum { admission, ready }, after_id: u64) !?r.Operation {
    _ = try self.head(source);
    const tag: u8 = if (kind == .admission) 'u' else 'q';
    const after = r.key(tag, after_id, 0);
    const page = try source.page(after);
    try c.Inspection.validatePage(page, after, source.view.revision);
    const first = page.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, first.key.slice(), after.data[0..4])) return null;
    if (first.key.len != 20 or std.mem.readInt(u64, first.key.data[12..20], .big) != 0 or !std.mem.eql(u8, first.value.slice(), if (kind == .admission) "upload" else "ready")) return error.InvalidGatewayInventory;
    const item = try self.operation(source, std.mem.readInt(u64, first.key.data[4..12], .big));
    if (kind == .admission) {
        if (item.phase != .reserved and item.phase != .uploading) return error.InvalidGatewayInventory;
    } else if (item.phase != .ready) return error.InvalidGatewayInventory;
    return item;
}

pub const Cursor = struct { realm: u64, resource: u64, configuration: [32]u8, revision: u64, after: u64 };
pub const Page = struct { entries: [p.Growth.page_size]?r.Operation = @splat(null), next: ?Cursor = null, revision: u64 };
/// Ordered discovery over append-only operation identities. Each page has its
/// own authorized cut; progress may advance, but cannot rewind, a saved cursor.
/// This method performs no sends or reconciliation.
pub fn list(self: Self, source: anytype, cursor: ?Cursor) !Page {
    const header = try self.head(source);
    if (cursor) |saved| if (saved.realm != self.configuration.realm or saved.resource != self.configuration.resource or !std.mem.eql(u8, &saved.configuration, &header.configuration) or saved.revision > source.view.revision) return error.GatewayCursorChanged;
    const after = r.key('o', if (cursor) |saved| saved.after else 0, 0);
    const found = try source.page(after);
    try c.Inspection.validatePage(found, after, source.view.revision);
    var result: Page = .{ .revision = source.view.revision };
    var count: usize = 0;
    var scanned: usize = 0;
    var last_id: u64 = 0;
    for (found.entries) |slot| {
        const entry = slot orelse break;
        if (!std.mem.startsWith(u8, entry.key.slice(), "\x00GWo")) break;
        if (entry.key.len != 20 or std.mem.readInt(u64, entry.key.data[12..20], .big) != 0) return error.InvalidGatewayInventory;
        const reference = try g.SessionOperations.decodeReference(entry.value);
        if (reference.id != std.mem.readInt(u64, entry.key.data[4..12], .big)) return error.GatewayIdentityConflict;
        scanned += 1;
        last_id = reference.id;
        if (reference.kind != .table) continue;
        const item = try r.decode(r.Operation, entry.value);
        if (item.id != std.mem.readInt(u64, entry.key.data[4..12], .big)) return error.GatewayIdentityConflict;
        try self.admittedBinding(.{ .resource = item.resource, .catalog = item.catalog, .owner = item.owner, .namespace = item.namespace, .role = item.selectedRole() });
        result.entries[count] = item;
        count += 1;
    }
    if (scanned == p.Growth.page_size and found.next != null) result.next = .{ .realm = self.configuration.realm, .resource = self.configuration.resource, .configuration = header.configuration, .revision = result.revision, .after = last_id };
    return result;
}
pub fn discover(self: Self, source: anytype, nonce: [16]u8) !?r.Operation {
    _ = try self.head(source);
    const index = try r.decode(r.Nonce, (try source.read(r.nonceKey(nonce))) orelse return null);
    if (!std.mem.eql(u8, &index.nonce, &nonce)) return error.GatewayIdentityConflict;
    const item = try self.operation(source, index.id);
    if (!std.mem.eql(u8, &item.nonce, &nonce)) return error.GatewayIdentityConflict;
    return item;
}
/// Select the oldest ready operation from a separate paged ready index. Durable
/// history never becomes a resident queue, nor does it add work to this lookup.
pub fn activate(self: Self, turn: *s.Turn, generation: u64) !?r.Operation {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .coordinator, generation);
    var header = try self.head(turn);
    if (header.active != 0) {
        const item = try self.operation(turn, header.active);
        if (item.phase != .active) return error.InvalidGatewayInventory;
        return item;
    }
    var committed = turn.committed();
    const after = r.key('q', 0, 0);
    const found = try committed.page(after);
    try c.Inspection.validatePage(found, after, turn.view.revision);
    const first = found.entries[0] orelse return null;
    if (!std.mem.startsWith(u8, first.key.slice(), "\x00GWq")) return null;
    if (first.key.len != 20 or std.mem.readInt(u64, first.key.data[12..20], .big) != 0 or !std.mem.eql(u8, first.value.slice(), "ready")) return error.InvalidGatewayInventory;
    const id = std.mem.readInt(u64, first.key.data[4..12], .big);
    var item = try self.operation(turn, id);
    if (item.phase != .ready) return error.InvalidGatewayInventory;
    item.phase = .active;
    header.active = id;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
    try turn.write(r.key('o', id, 0), try r.encode(item));
    try turn.write(first.key, null);
    return item;
}

fn active(self: Self, turn: *s.Turn, id: u64, generation: u64) !r.Operation {
    try self.actor(turn, .coordinator, generation);
    if ((try self.head(turn)).active != id) return error.GatewayOperationInactive;
    const item = try self.operation(turn, id);
    if (item.phase != .active) return error.GatewayOperationInactive;
    return item;
}
pub fn checkReference(self: Self, item: r.Operation, reference: g.IntentReference.Reference) !void {
    try reference.validate();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = self.configuration.realm, .resource = item.resource, .catalog = item.catalog }, .branch = 1, .audience = item.owner, .principal = self.configuration.table_principal, .role = item.selectedRole() };
    if (!std.meta.eql(connection, reference.connection()) or reference.namespace() != item.namespace or reference.identity().operation != item.id or try reference.workBytes() > self.configuration.intent_bytes) return error.GatewayIdentityConflict;
}
/// Publish dispatch eligibility before any direct admission attempt. A restart
/// may repeat only the immutable original binding with current credentials.
pub fn authorizeDispatch(self: Self, turn: *s.Turn, id: u64, generation: u64) !void {
    var item = try self.active(turn, id, generation);
    if (item.published != 0) return;
    if (item.cancel != 0) return error.GatewayRequiresQualifiedCancellation;
    item.published = 1;
    item.reconcile = 0;
    item.blocked = 0;
    try turn.write(r.key('o', id, 0), try r.encode(item));
}
/// Read a previously admitted reference at a committed source. No data-plane
/// bytes, operation admission, execution or signing occurs here.
pub fn readReference(self: Self, allocator: std.mem.Allocator, source: anytype, item: r.Operation) !g.IntentReference.Reference {
    if (item.phase == .reserved or item.phase == .uploading or item.phase == .abandoned) return error.InvalidGatewayIntent;
    const bytes = try g.Upload.read(allocator, self.publication(item.id), source, 1, g.IntentReference.max_bytes);
    defer allocator.free(bytes);
    const value = try g.IntentReference.decode(allocator, bytes);
    try self.checkReference(item, value);
    if (!std.meta.eql(try Pub.Digest.of(r.intent_format, bytes), item.spec())) return error.GatewayIdentityConflict;
    return value;
}
/// Operator controls can request progress/cancellation; they cannot manufacture
/// receipts, signed steps or SQL outcomes. Inspection calls never invoke this.
pub fn request(self: Self, turn: *s.Turn, id: u64, action: enum { reconcile, cancel }) !void {
    try self.actor(turn, .control, null);
    return self.markRequest(turn, id, if (action == .cancel) .cancel else .reconcile);
}
/// Authenticated SQL ingress may control its own account's operations. It cannot
/// alter quotas, publish coordinator evidence or choose a foreign signing owner.
pub fn sessionRequest(self: Self, turn: *s.Turn, id: u64, action: enum { reconcile, cancel }) !void {
    try self.actor(turn, .ingress, null);
    return self.markRequest(turn, id, if (action == .cancel) .cancel else .reconcile);
}
fn markRequest(self: Self, turn: *s.Turn, id: u64, action: enum { reconcile, cancel }) !void {
    var item = try self.operation(turn, id);
    if (item.phase == .terminal or item.phase == .abandoned) return;
    switch (action) {
        .cancel => item.cancel = 1,
        .reconcile => {
            item.reconcile = 1;
            item.blocked = 0;
            if (item.cancel != 0) item.cancel = 1;
        },
    }
    try turn.write(r.key('o', id, 0), try r.encode(item));
}
fn settle(self: Self, turn: *s.Turn, item: *r.Operation) !void {
    var header = try self.head(turn);
    const charge = try std.math.add(u64, item.stored_bytes, 512);
    if (charge > item.reservation or header.reserved_bytes < item.reservation or header.unsettled == 0) return error.InvalidGatewayReservation;
    header.reserved_bytes -= item.reservation;
    header.used_bytes = try std.math.add(u64, header.used_bytes, charge);
    header.unsettled -= 1;
    if (header.active == item.id) header.active = 0;
    item.reservation = 0;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
}
/// Cancellation before any step was published proves no Table dispatch was
/// authorized. An incomplete upload is abandoned, not called a Table outcome.
pub fn cancelUnsent(self: Self, turn: *s.Turn, id: u64, generation: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .coordinator, generation);
    var item = try self.operation(turn, id);
    if (item.phase == .terminal or item.phase == .abandoned) return;
    if (item.cancel == 0 or item.published != 0) return error.GatewayRequiresQualifiedCancellation;
    const ready = item.phase == .ready;
    const admitted = ready or item.phase == .active;
    item.phase = .abandoned;
    item.summary = .none;
    try self.settle(turn, &item);
    try turn.write(r.key('o', id, 0), try r.encode(item));
    if (ready) try turn.write(r.key('q', id, 0), null);
    if (!admitted) try turn.write(r.key('u', id, 0), null);
    // Private marker distinguishes a gateway-local cancellation from a native
    // Table receipt. Discovery exposes the retained summary and original phase.
    try turn.write(r.key('t', id, 0), try p.Value.init("gateway.cancelled.before-dispatch.v1"));
}
/// Capacity increases are explicit account-scoped operator changes. They do not
/// rewrite identity, expire records or grant additional catalog permissions.
pub fn increaseCapacity(self: Self, turn: *s.Turn, operations: u64, bytes: u64, pending: u32) !void {
    try self.actor(turn, .control, null);
    var header = try self.head(turn);
    if (operations < header.operation_quota or bytes < header.byte_quota or pending < header.pending_quota) return error.GatewayCapacityDecrease;
    header.operation_quota = operations;
    header.byte_quota = bytes;
    header.pending_quota = pending;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
}
pub fn reserveRecovery(self: Self, turn: *s.Turn, id: u64, bytes: u64) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .control, null);
    var item = try self.operation(turn, id);
    if (item.phase == .terminal or item.phase == .abandoned or bytes == 0) return error.InvalidGatewayReservation;
    var header = try self.head(turn);
    if (bytes > header.byte_quota - header.used_bytes - header.reserved_bytes) return error.GatewayRecoveryCapacity;
    item.reservation = try std.math.add(u64, item.reservation, bytes);
    header.reserved_bytes += bytes;
    try turn.write(r.key('h', 0, 0), try r.encode(header));
    try turn.write(r.key('o', id, 0), try r.encode(item));
}

/// Retain attributed terminal facts. Current-rights Table reads still govern
/// wire/control disclosure and detailed native witnesses are not copied here.
pub fn complete(self: Self, turn: *s.Turn, id: u64, generation: u64, outcome: g.Terminal) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, .coordinator, generation);
    var item = try self.operation(turn, id);
    const bound = try r.decode(r.IntentBinding, (try turn.read(r.key('b', id, 0))) orelse return error.InvalidGatewayIntent);
    try outcome.validate();
    if (bound.id != id or outcome.operation != id or outcome.principal != self.configuration.table_principal or outcome.resource != item.resource or !std.mem.eql(u8, &bound.binding, &outcome.identity)) return error.GatewayIdentityConflict;
    const encoded = try r.encode(outcome);
    if (item.phase == .terminal) {
        const previous = (try turn.read(r.key('t', id, 0))) orelse return error.InvalidGatewayObservation;
        if (!previous.eql(encoded) or item.summary != outcome.summary() or item.matched != outcome.matched or item.changed != outcome.changed) return error.GatewayIdentityConflict;
        return;
    }
    if (item.phase != .active or (try self.head(turn)).active != id or item.published != 1) return error.GatewayUnresolvedStep;
    item.phase = .terminal;
    item.summary = outcome.summary();
    item.matched = outcome.matched;
    item.changed = outcome.changed;
    try self.settle(turn, &item);
    try turn.write(r.key('o', id, 0), try r.encode(item));
    try turn.write(r.key('t', id, 0), encoded);
}

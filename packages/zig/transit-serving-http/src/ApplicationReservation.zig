//! One bounded, transient request reservation. The HTTP owner serializes access
//! and joins borrowers before destruction. No method establishes native rights:
//! the mandatory authority callback verifies original acquisition/commit evidence
//! through public native operations on every access, including cached values.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const a = c.fuze.ApplicationProgram;
const V = a.Values.Value;
const Key = c.DirectClientToken.Key;
const Self = @This();

/// Exact ingress or committed handoff row. Copying a handle into another Queue
/// record cannot copy this binding, even when the payload/request UUID matches.
pub const Input = p.StreamQueue.RecordIdentity;
pub const Access = struct {
    owner: Key,
    input: Input,
    /// Host monotonic milliseconds; never a program operand or client clock.
    now_ms: u64,
};
pub const Transfer = struct {
    from: Key,
    input: Input,
    destination: Input,
    effect: [16]u8,
    transaction: Key,
};
pub const Evidence = union(enum) {
    /// Verify the live original invocation, acquired row and current scoped
    /// authority. A syntactically valid Key/Claim is insufficient.
    access: Access,
    /// The native owner additionally checks any referenced secret/sink policy
    /// for this particular use. No protected bytes enter this evidence.
    redemption: struct { access: Access, handle: V, use: Use },
    /// Observe the original committed common transaction and its exact handoff,
    /// enqueue, input ACK and checkpoint. Unknown/aborted decisions must reject.
    transfer: Transfer,
};
pub const Authority = struct {
    context: *anyopaque,
    check: *const fn (*anyopaque, Evidence) anyerror!void,
};
pub const Observation = struct {
    step: u32,
    node: a.Id,
    /// Commitment to the operation and its public operands/opaque references.
    /// Protected bytes must never be serialized to compute this binding.
    arguments: [32]u8,
};
pub const Material = union(enum) {
    secret: struct { bytes: []const u8, revision: []const u8, origin: Origin },
    json: []const u8,
    /// Scalar bytes/values remain inside this reservation, including protected
    /// conditions. Records and references cannot be nested in a sealed scalar.
    scalar: V,
};
pub const Origin = enum { named, request_query, request_cookie, derived, random, provider_token, bearer };
pub const Use = enum { current, commitment, comparison, derive, s256, bearer, form, header, cookie, json_projection, scalar };
pub const Slot = struct {
    owner: Key,
    observation: Observation,
    reference: a.Values.Reference,
    material: Material,
};

reference: a.Values.Reference,
request_id: [16]u8,
input: Input,
owner: ?Key,
expires_ms: u64,
authority: Authority,
memory: std.heap.FixedBufferAllocator,
slots: []Slot,
used: usize,
last_transfer: ?Transfer,
closed: bool,

/// Memory and slots belong to the caller and outlive this reservation. Capacity
/// is a per-active-request admission budget, never a durable population limit.
pub fn init(io: std.Io, memory: []u8, slots: []Slot, request_id: [16]u8, input: Input, now_ms: u64, expires_ms: u64, authority: Authority) !Self {
    try input.validate();
    if (memory.len == 0 or slots.len == 0 or expires_ms <= now_ms or std.mem.allEqual(u8, &request_id, 0)) return error.InvalidApplicationReservation;
    var reference: a.Values.Reference = undefined;
    try randomReference(io, &reference);
    return .{ .reference = reference, .request_id = request_id, .input = input, .owner = null, .expires_ms = expires_ms, .authority = authority, .memory = .init(memory), .slots = slots, .used = 0, .last_transfer = null, .closed = false };
}
pub fn deinit(self: *Self) void {
    self.close();
    self.* = undefined;
}
/// Completion, expiry or socket/request loss destroys every protected byte.
/// Durable work is resolved separately; this never cancels or retries a write.
pub fn close(self: *Self) void {
    std.crypto.secureZero(u8, self.memory.buffer);
    std.crypto.secureZero(u8, std.mem.sliceAsBytes(self.slots));
    self.used = 0;
    self.owner = null;
    self.last_transfer = null;
    self.closed = true;
}
fn live(self: *Self, now_ms: u64) !void {
    if (self.closed) return error.ApplicationReservationLost;
    if (now_ms >= self.expires_ms) {
        self.close();
        return error.ApplicationReservationExpired;
    }
}
fn authorize(self: *Self, access: Access) !void {
    try self.live(access.now_ms);
    try access.owner.validate();
    try access.input.validate();
    if (!std.meta.eql(self.input, access.input) or !std.meta.eql(access.owner.connection.scope, self.input.operation.scope)) return error.ApplicationRequestOwnerMismatch;
    if (self.owner) |owner| try owner.requireSame(access.owner);
    try self.authority.check(self.authority.context, .{ .access = access });
    if (self.owner == null) self.owner = access.owner;
}
pub fn request(self: *Self, access: Access, value: V) !void {
    if (value != .capability or !std.crypto.timing_safe.eql([32]u8, value.capability.id, self.reference.id)) return error.ApplicationRequestOwnerMismatch;
    try self.authorize(access);
}
fn locate(self: *Self, access: Access, observation: Observation) !?*Slot {
    if (observation.node == 0 or std.mem.allEqual(u8, &observation.arguments, 0)) return error.InvalidApplicationReservation;
    for (self.slots[0..self.used]) |*slot| {
        if (!std.meta.eql(slot.owner, access.owner) or slot.observation.step != observation.step or slot.observation.node != observation.node) continue;
        if (!std.mem.eql(u8, &slot.observation.arguments, &observation.arguments)) return error.ProtectedObservationChanged;
        return slot;
    }
    return null;
}
/// Check before generating entropy, reading a secret or obtaining a response.
/// A cached observation still requires fresh native authority and a live owner.
pub fn find(self: *Self, access: Access, observation: Observation) !?V {
    try self.authorize(access);
    const slot = try self.locate(access, observation) orelse return null;
    return handleFor(slot.*);
}
pub fn retain(self: *Self, io: std.Io, access: Access, observation: Observation, material: Material) !V {
    try self.authorize(access);
    if (try self.locate(access, observation)) |slot| {
        if (!same(slot.material, material)) return error.ProtectedObservationChanged;
        return handleFor(slot.*);
    }
    if (self.used == self.slots.len) return error.ApplicationReservationCapacity;
    // Restore the bounded bump allocator after a failed copy and erase its
    // partial material. No failed observation consumes capacity or leaks bytes.
    const before = self.memory.end_index;
    errdefer {
        std.crypto.secureZero(u8, self.memory.buffer[before..self.memory.end_index]);
        self.memory.end_index = before;
    }
    const retained = self.copy(material) catch |err| return if (err == error.OutOfMemory) error.ApplicationReservationCapacity else err;
    var reference: a.Values.Reference = undefined;
    try randomReference(io, &reference);
    if (std.mem.eql(u8, &reference.id, &self.reference.id)) return error.ApplicationReferenceCollision;
    for (self.slots[0..self.used]) |slot| if (std.mem.eql(u8, &reference.id, &slot.reference.id)) return error.ApplicationReferenceCollision;
    const slot = &self.slots[self.used];
    slot.* = .{ .owner = access.owner, .observation = observation, .reference = reference, .material = retained };
    self.used += 1;
    return handleFor(slot.*);
}
/// Borrow only inside the serialized authorized operation. Recheck authority
/// again before dispatch/disclosure; neither a borrow nor a handle is a lease.
pub fn read(self: *Self, access: Access, handle: V, use: Use) !Material {
    try self.authorize(access);
    const reference = switch (handle) {
        .secret => |secret| secret.reference,
        .protected_json => |ref| ref,
        .sealed => |sealed| sealed.reference,
        else => return error.ProtectedProgramValue,
    };
    for (self.slots[0..self.used]) |slot| {
        if (!std.crypto.timing_safe.eql([32]u8, slot.reference.id, reference.id)) continue;
        try slot.owner.requireSame(access.owner);
        const expected = handleFor(slot);
        if (std.meta.activeTag(handle) != std.meta.activeTag(expected)) return error.ProtectedProgramValue;
        if (handle == .secret and !std.mem.eql(u8, handle.secret.revision, expected.secret.revision)) return error.ProtectedObservationChanged;
        if (handle == .sealed and handle.sealed.kind != expected.sealed.kind) return error.ProtectedProgramValue;
        try purpose(slot.material, use);
        try self.authority.check(self.authority.context, .{ .redemption = .{ .access = access, .handle = handle, .use = use } });
        return slot.material;
    }
    return error.ApplicationReservationLost;
}
/// Native commit evidence, not a local flag, transfers response ownership. A
/// repeated observed transfer cannot reset an already acquired destination.
pub fn handoff(self: *Self, now_ms: u64, transfer: Transfer) !void {
    try self.live(now_ms);
    try transfer.from.validate();
    try transfer.input.validate();
    try transfer.destination.validate();
    try transfer.transaction.validate();
    if (!std.meta.eql(transfer.input.target.interpretation.object.scope, transfer.destination.target.interpretation.object.scope) or
        std.meta.eql(transfer.input, transfer.destination)) return error.ApplicationRequestOwnerMismatch;
    if (self.last_transfer) |previous| {
        if (!std.meta.eql(previous, transfer)) return error.ApplicationRequestOwnerMismatch;
        return self.authority.check(self.authority.context, .{ .transfer = transfer });
    }
    if (!std.meta.eql(self.input, transfer.input) or self.owner == null) return error.ApplicationRequestOwnerMismatch;
    try self.owner.?.requireSame(transfer.from);
    try self.authority.check(self.authority.context, .{ .transfer = transfer });
    self.last_transfer = transfer;
    self.input = transfer.destination;
    self.owner = null;
}
fn handleFor(slot: Slot) V {
    return switch (slot.material) {
        .secret => |secret| .{ .secret = .{ .reference = slot.reference, .revision = secret.revision } },
        .json => .{ .protected_json = slot.reference },
        .scalar => |scalar| .{ .sealed = .{ .kind = scalar.kind(), .reference = slot.reference } },
    };
}
fn copy(self: *Self, material: Material) !Material {
    const allocator = self.memory.allocator();
    return switch (material) {
        .secret => |secret| blk: {
            if (secret.bytes.len == 0 or secret.revision.len == 0 or secret.revision.len > 2048) return error.InvalidApplicationReservation;
            break :blk .{ .secret = .{ .bytes = try allocator.dupe(u8, secret.bytes), .revision = try allocator.dupe(u8, secret.revision), .origin = secret.origin } };
        },
        .json => |bytes| .{ .json = try allocator.dupe(u8, bytes) },
        .scalar => |scalar| .{ .scalar = switch (scalar) {
            .text => |bytes| .{ .text = try allocator.dupe(u8, bytes) },
            .binary => |bytes| .{ .binary = try allocator.dupe(u8, bytes) },
            .json => |bytes| .{ .json = try allocator.dupe(u8, bytes) },
            .boolean, .integer, .uuid, .timestamp, .duration => scalar,
            else => return error.ProtectedProgramValue,
        } },
    };
}
fn same(left: Material, right: Material) bool {
    if (std.meta.activeTag(left) != std.meta.activeTag(right)) return false;
    return switch (left) {
        .secret => |secret| secret.origin == right.secret.origin and std.mem.eql(u8, secret.bytes, right.secret.bytes) and std.mem.eql(u8, secret.revision, right.secret.revision),
        .json => |bytes| std.mem.eql(u8, bytes, right.json),
        .scalar => |scalar| blk: {
            if (std.meta.activeTag(scalar) != std.meta.activeTag(right.scalar)) break :blk false;
            break :blk switch (scalar) {
                inline .text, .binary, .json => |bytes, tag| std.mem.eql(u8, bytes, @field(right.scalar, @tagName(tag))),
                .boolean, .integer, .uuid, .timestamp, .duration => std.meta.eql(scalar, right.scalar),
                else => false,
            };
        },
    };
}
fn purpose(material: Material, use: Use) !void {
    const allowed = switch (material) {
        .secret => |secret| switch (use) {
            .current => secret.origin == .named or secret.origin == .derived,
            .commitment, .comparison, .derive, .s256, .bearer, .form => true,
            .header => secret.origin == .bearer,
            // Cookie delivery cannot declassify a mounted provider credential,
            // callback code or provider token as a browser credential.
            .cookie => secret.origin == .random or secret.origin == .derived,
            else => false,
        },
        .json => use == .json_projection,
        .scalar => use == .scalar,
    };
    if (!allowed) return error.ProtectedProgramValue;
}
fn randomReference(io: std.Io, reference: *a.Values.Reference) !void {
    try io.randomSecure(&reference.id);
    if (std.mem.allEqual(u8, &reference.id, 0)) return error.ApplicationReferenceCollision;
}

const Proof = struct {
    allowed: bool = true,
    redemption_allowed: bool = true,
    committed: bool = false,
    checks: usize = 0,
    fn check(context: *anyopaque, evidence: Evidence) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.checks += 1;
        if (!self.allowed) return error.AccessDenied;
        if (evidence == .redemption and !self.redemption_allowed) return error.AccessDenied;
        if (evidence == .transfer and !self.committed) return error.ClientOperationPending;
    }
    fn authority(self: *@This()) Authority {
        return .{ .context = self, .check = check };
    }
    fn access() Access {
        const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
        return .{
            .owner = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 5, .principal = 17, .role = 19 }, .account = @splat(1), .token = @splat(2) },
            .input = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(3) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 23, .operation = 29 }, .ordinal = 0 },
            .now_ms = 100,
        };
    }
};

test "protected application reservation binds original input and rechecks authority on cached reads" {
    const t = std.testing;
    var memory: [512]u8 = @splat(0);
    var slots: [4]Slot = undefined;
    var proof: Proof = .{};
    const access = Proof.access();
    var self = try init(t.io, &memory, &slots, @splat(1), access.input, access.now_ms, 200, proof.authority());
    defer self.deinit();
    const capability: V = .{ .capability = self.reference };
    try self.request(access, capability);
    var copied = access;
    copied.input.operation.operation += 1;
    try t.expectError(error.ApplicationRequestOwnerMismatch, self.request(copied, capability));
    copied = access;
    copied.owner.token[0] += 1;
    try t.expectError(error.DataIdentityConflict, self.request(copied, capability));
    try t.expectError(error.ApplicationRequestOwnerMismatch, self.request(access, .{ .binary = &self.reference.id }));
    const site: Observation = .{ .step = 0, .node = 1, .arguments = @splat(2) };
    var bytes = "private credential".*;
    const secret = try self.retain(t.io, access, site, .{ .secret = .{ .bytes = &bytes, .revision = "r1", .origin = .named } });
    @memset(&bytes, 0);
    try t.expectEqualStrings("private credential", (try self.read(access, secret, .commitment)).secret.bytes);
    try t.expectError(error.ProtectedProgramValue, self.read(access, secret, .cookie));
    try t.expectError(error.ProtectedProgramValue, self.read(access, secret, .header));
    proof.redemption_allowed = false;
    try t.expectError(error.AccessDenied, self.read(access, secret, .form));
    try t.expectEqualDeep(secret, (try self.find(access, site)).?);
    proof.redemption_allowed = true;
    try t.expectEqualDeep(secret, (try self.find(access, site)).?);
    try t.expectEqualDeep(secret, try self.retain(t.io, access, site, .{ .secret = .{ .bytes = "private credential", .revision = "r1", .origin = .named } }));
    try t.expectEqual(@as(usize, 1), self.used);
    try t.expectError(error.ProtectedObservationChanged, self.retain(t.io, access, site, .{ .secret = .{ .bytes = "changed", .revision = "r1", .origin = .named } }));
    var changed = site;
    changed.arguments[0] += 1;
    try t.expectError(error.ProtectedObservationChanged, self.find(access, changed));
    try t.expectError(error.ProtectedProgramValue, self.read(access, .{ .protected_json = secret.secret.reference }, .json_projection));
    var revision = secret;
    revision.secret.revision = "r2";
    try t.expectError(error.ProtectedObservationChanged, self.read(access, revision, .commitment));
    proof.allowed = false;
    const before = proof.checks;
    try t.expectError(error.AccessDenied, self.read(access, secret, .commitment));
    try t.expectError(error.AccessDenied, self.find(access, site));
    try t.expectError(error.AccessDenied, self.retain(t.io, access, site, .{ .secret = .{ .bytes = "private credential", .revision = "r1", .origin = .named } }));
    try t.expectEqual(before + 3, proof.checks);
    proof.allowed = true;
    var expired = access;
    expired.now_ms = 200;
    try t.expectError(error.ApplicationReservationExpired, self.read(expired, secret, .commitment));
    try t.expect(std.mem.allEqual(u8, &memory, 0));
    try t.expect(std.mem.allEqual(u8, std.mem.sliceAsBytes(&slots), 0));
    try t.expectError(error.ApplicationReservationLost, self.find(access, site));
    try t.expectError(error.ApplicationReservationLost, self.retain(t.io, access, site, .{ .secret = .{ .bytes = "replacement", .revision = "r1", .origin = .named } }));
}

test "protected application handoff requires observed commit and cannot rewind the destination owner" {
    const t = std.testing;
    var memory: [256]u8 = @splat(0);
    var slots: [2]Slot = undefined;
    var proof: Proof = .{};
    const source = Proof.access();
    var self = try init(t.io, &memory, &slots, @splat(1), source.input, source.now_ms, 200, proof.authority());
    defer self.deinit();
    const capability: V = .{ .capability = self.reference };
    try self.request(source, capability);
    const secret = try self.retain(t.io, source, .{ .step = 0, .node = 1, .arguments = @splat(1) }, .{ .secret = .{ .bytes = "source-only", .revision = "r1", .origin = .named } });
    var destination = source;
    destination.owner.token[0] += 1;
    destination.input.target.interpretation.object.object += 1;
    destination.input.operation.operation += 1;
    const transfer: Transfer = .{ .from = source.owner, .input = source.input, .destination = destination.input, .effect = @splat(8), .transaction = source.owner };
    try t.expectError(error.ClientOperationPending, self.handoff(source.now_ms, transfer));
    try self.request(source, capability);
    try t.expectError(error.ApplicationRequestOwnerMismatch, self.request(destination, capability));
    proof.committed = true;
    try self.handoff(source.now_ms, transfer);
    try t.expectError(error.ApplicationRequestOwnerMismatch, self.request(source, capability));
    try self.request(destination, capability);
    try t.expectError(error.DataIdentityConflict, self.read(destination, secret, .commitment));
    try self.handoff(source.now_ms, transfer);
    try t.expectEqualDeep(destination.owner, self.owner.?);
    var conflicting = transfer;
    conflicting.effect[0] += 1;
    try t.expectError(error.ApplicationRequestOwnerMismatch, self.handoff(source.now_ms, conflicting));
    proof.allowed = false;
    try t.expectError(error.AccessDenied, self.handoff(source.now_ms, transfer));
    try t.expectEqualDeep(destination.owner, self.owner.?);
}

test "protected application capacity refusal erases partial material without evicting accepted values" {
    const t = std.testing;
    var memory: [16]u8 = @splat(0);
    var slots: [2]Slot = undefined;
    var proof: Proof = .{};
    const access = Proof.access();
    var self = try init(t.io, &memory, &slots, @splat(1), access.input, access.now_ms, 200, proof.authority());
    defer self.deinit();
    const first: Observation = .{ .step = 0, .node = 1, .arguments = @splat(1) };
    const second: Observation = .{ .step = 1, .node = 2, .arguments = @splat(2) };
    const secret = try self.retain(t.io, access, first, .{ .secret = .{ .bytes = "kept", .revision = "r1", .origin = .named } });
    const before = self.memory.end_index;
    try t.expectError(error.ApplicationReservationCapacity, self.retain(t.io, access, second, .{ .secret = .{ .bytes = "partial", .revision = "too long to fit", .origin = .named } }));
    try t.expectEqual(before, self.memory.end_index);
    try t.expect(std.mem.allEqual(u8, memory[before..], 0));
    try t.expectEqualStrings("kept", (try self.read(access, secret, .commitment)).secret.bytes);
    _ = try self.retain(t.io, access, second, .{ .scalar = .{ .boolean = false } });
    try t.expectError(error.ApplicationReservationCapacity, self.retain(t.io, access, .{ .step = 2, .node = 3, .arguments = @splat(3) }, .{ .scalar = .{ .boolean = true } }));
    try t.expectEqualStrings("kept", (try self.read(access, secret, .commitment)).secret.bytes);
    self.close();
    try t.expect(std.mem.allEqual(u8, &memory, 0));
}

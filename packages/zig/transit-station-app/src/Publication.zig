//! Conditional interface visibility on ordinary single-resource Station turns.
//! The host supplies an authorized immutable body; it is validated again here.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const s = root.station;
const m = root.Model;
const c = root.Records;
const Pub = s.Publication;
const Turn = s.Turn;
const Self = @This();
pub const format: u32 = 0x41505031;
pub const limits: Pub.Limits = .{ .record_bytes = m.max_program_bytes, .staging_bytes = 2 * m.max_program_bytes, .staging_records = 2 };
pub const Configuration = struct { application: u64, namespace: m.Wide, realm: u64, administrator: u64, name_digest: [32]u8 };
pub const Policy = struct { revision: m.Wide, publish: bool };
pub const Proposal = struct {
    operation: m.Wide,
    record: m.Wide,
    expected: m.Wide,
    expected_digest: [32]u8,
    revision: m.Wide,
    spec: Pub.Spec,
};
pub const Phase = enum(u8) { staging = 1, applied = 2, conflict = 3, abandoned = 4 };
/// Original head at the rejected conditional publication, never a later read.
pub const ConflictBasis = union(enum(u8)) { none = 0, absent = 1, head: struct { revision: m.Wide, digest: [32]u8 } = 2 };
pub const Receipt = struct { proposal: Proposal, phase: Phase, input: u64, owns_record: bool, conflict_basis: ConflictBasis = .none };
pub const Head = struct { revision: m.Wide, record: m.Wide, spec: Pub.Spec, principal: u64, operation: m.Wide, input: u64 };
configuration: Configuration,
failure: ?*root.PublicationFailure.Context = null,

pub fn nameDigest(name: []const u8) [32]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(name, &digest, .{});
    return digest;
}
fn key(self: Self, tag: u8, who: u64, operation: u64) p.Value {
    return c.key(self.configuration.application, tag, who, operation);
}
fn principal(turn: *const Turn) !u64 {
    if (turn.delivery.input.origin != .external) return error.ApplicationDenied;
    return turn.delivery.input.origin.external.principal;
}
pub fn initialize(self: Self, turn: *Turn) !void {
    const config = self.configuration;
    if (config.application == 0 or config.application > p.max_counter or config.realm == 0 or config.realm != turn.delivery.realm or config.namespace.value == 0 or config.administrator == 0 or config.administrator > p.max_counter) return error.InvalidApplicationConfiguration;
    if (try principal(turn) != config.administrator) return error.ApplicationDenied;
    const before = turn.decision;
    errdefer turn.decision = before;
    const encoded = try c.encode('c', config);
    if (try turn.read(self.key('c', 0, 0))) |previous| {
        if (!previous.eql(encoded)) return error.ApplicationConfigurationChanged;
    } else {
        // Never adopt a namespace whose contents were created by another owner.
        if (try turn.read(Pub.key(.application_definition, config.namespace.value, 'b', 0, 0)) != null) return error.PublicationUploadNamespaceInUse;
        _ = try Pub.create(turn, .application_definition, config.namespace.value, limits);
        try turn.write(self.key('c', 0, 0), encoded);
    }
}
fn check(self: Self, turn: *Turn) !void {
    if (turn.delivery.realm != self.configuration.realm) return error.ApplicationConfigurationChanged;
    const stored = (try turn.read(self.key('c', 0, 0))) orelse return error.ApplicationNotInitialized;
    if (!stored.eql(try c.encode('c', self.configuration))) return error.ApplicationConfigurationChanged;
}
pub fn policy(self: Self, reader: anytype, who: u64) !?Policy {
    return if (try reader.read(self.key('p', who, 0))) |value| try c.decode(Policy, 'p', value) else null;
}
pub fn setPolicy(self: Self, turn: *Turn, who: u64, expected: m.Wide, next: Policy) !void {
    try self.check(turn);
    if (try principal(turn) != self.configuration.administrator) return error.ApplicationDenied;
    if (who == 0 or who > p.max_counter or next.revision.value != try std.math.add(u64, expected.value, 1)) return error.InvalidApplicationPolicy;
    const previous = try self.policy(turn, who);
    if (self.failure) |detail| detail.witness = .{ .policy = .{ .principal = who, .expected = expected, .actual = if (previous) |value| value.revision else .{}, .present = previous != null, .publish = if (previous) |value| value.publish else false } };
    if ((if (previous) |value| value.revision.value else 0) != expected.value) return error.ApplicationPolicyConflict;
    try turn.write(self.key('p', who, 0), try c.encode('p', next));
}
fn authorize(self: Self, turn: *Turn) !u64 {
    try self.check(turn);
    const who = try principal(turn);
    const rights = try self.policy(turn, who);
    if (self.failure) |detail| detail.witness = .{ .policy = .{ .principal = who, .expected = .{}, .actual = if (rights) |value| value.revision else .{}, .present = rights != null, .publish = if (rights) |value| value.publish else false } };
    if (rights == null or !rights.?.publish) return error.ApplicationDenied;
    return who;
}
pub fn head(self: Self, reader: anytype) !?Head {
    return if (try reader.read(self.key('h', 0, 0))) |value| try c.decode(Head, 'h', value) else null;
}
pub fn receipt(self: Self, reader: anytype, who: u64, operation: m.Wide) !?Receipt {
    const value = (try reader.read(self.key('o', who, operation.value))) orelse return null;
    const result = try c.decode(Receipt, 'o', value);
    try validateReceipt(result);
    if (result.proposal.operation.value != operation.value) return error.InvalidApplicationRecord;
    return result;
}
pub fn reference(self: Self, resource: u64, value: Head) s.PublicationReference {
    return .{ .domain = .application_definition, .resource = resource, .namespace = self.configuration.namespace.value, .record = value.record.value, .spec = value.spec };
}
fn publication(self: Self, turn: *Turn) Pub {
    return .{ .domain = .application_definition, .resource = turn.view.resource, .namespace = self.configuration.namespace.value };
}
fn baseMatches(previous: ?Head, proposal: Proposal) bool {
    const revision = if (previous) |value| value.revision.value else 0;
    const digest = if (previous) |value| value.spec.digest else @as([32]u8, @splat(0));
    return revision == proposal.expected.value and std.mem.eql(u8, &digest, &proposal.expected_digest);
}
pub fn validateProposal(proposal: Proposal) !void {
    if (proposal.operation.value == 0 or proposal.record.value == 0 or proposal.revision.value != try std.math.add(u64, proposal.expected.value, 1) or proposal.spec.format != format or proposal.spec.length == 0 or proposal.spec.length > m.max_program_bytes) return error.InvalidApplicationProposal;
}
fn reserve(self: Self, turn: *Turn, who: u64, proposal: Proposal) !void {
    if (try turn.read(Pub.key(.application_definition, self.configuration.namespace.value, 'r', proposal.record.value, 0)) != null) return error.ApplicationRecordOccupied;
    _ = try self.publication(turn).begin(turn, proposal.record.value, proposal.spec);
    try turn.write(self.key('o', who, proposal.operation.value), try c.encode('o', Receipt{ .proposal = proposal, .phase = .staging, .input = turn.delivery.input.position, .owns_record = true }));
}
pub fn validateReceipt(value: Receipt) !void {
    try validateProposal(value.proposal);
    if (value.input == 0 or value.input > p.max_counter or
        (value.phase == .conflict and value.conflict_basis == .none) or
        ((value.phase == .staging or value.phase == .applied) and value.conflict_basis != .none)) return error.InvalidApplicationRecord;
    if ((value.phase == .staging or value.phase == .applied) and !value.owns_record) return error.InvalidApplicationRecord;
    switch (value.conflict_basis) {
        .none => {},
        .absent => if (value.proposal.expected.value == 0 and std.mem.allEqual(u8, &value.proposal.expected_digest, 0)) return error.InvalidApplicationRecord,
        .head => |basis| if (basis.revision.value == 0 or (basis.revision.value == value.proposal.expected.value and std.mem.eql(u8, &basis.digest, &value.proposal.expected_digest))) return error.InvalidApplicationRecord,
    }
}
fn conflict(self: Self, turn: *Turn, who: u64, proposal: Proposal, owns_record: bool, observed: ?Head) !Phase {
    try turn.write(self.key('o', who, proposal.operation.value), try c.encode('o', Receipt{ .proposal = proposal, .phase = .conflict, .input = turn.delivery.input.position, .owns_record = owns_record, .conflict_basis = if (observed) |head_value| .{ .head = .{ .revision = head_value.revision, .digest = head_value.spec.digest } } else .absent }));
    return .conflict;
}
/// Explicit byte-upload admission, not administrative publication. The compiler
/// validates before a normal caller uploads; the owner still validates the entire
/// assembled program before activation, even for a malicious direct native caller.
pub fn beginUpload(self: Self, turn: *Turn, proposal: Proposal) !Phase {
    const before = turn.decision;
    errdefer turn.decision = before;
    const who = try self.authorize(turn);
    try validateProposal(proposal);
    if (try self.receipt(turn, who, proposal.operation)) |old| {
        if (!std.meta.eql(old.proposal, proposal)) return error.ApplicationIdentityConflict;
        return old.phase;
    }
    const observed = try self.head(turn);
    if (!baseMatches(observed, proposal)) return self.conflict(turn, who, proposal, false, observed);
    try self.reserve(turn, who, proposal);
    return .staging;
}
pub fn appendUpload(self: Self, turn: *Turn, operation: m.Wide, part: s.PublicationParts.Part) !Phase {
    const before = turn.decision;
    errdefer turn.decision = before;
    const who = try self.authorize(turn);
    const current = (try self.receipt(turn, who, operation)) orelse return error.ApplicationOperationNotFound;
    if (current.phase != .staging) return current.phase;
    if (!current.owns_record) return error.ApplicationPublicationChanged;
    try validateProposal(current.proposal);
    const observed = try self.head(turn);
    if (!baseMatches(observed, current.proposal)) return self.conflict(turn, who, current.proposal, true, observed);
    try s.PublicationParts.append(turn, .{ .domain = .application_definition, .resource = turn.view.resource, .namespace = self.configuration.namespace.value, .record = current.proposal.record.value, .spec = current.proposal.spec }, self.key('x', who, operation.value), part);
    return .staging;
}
pub fn finishUpload(self: Self, allocator: std.mem.Allocator, turn: *Turn, operation: m.Wide) !Phase {
    const who = try self.authorize(turn);
    const current = (try self.receipt(turn, who, operation)) orelse return error.ApplicationOperationNotFound;
    if (current.phase != .staging) return current.phase;
    if (!current.owns_record) return error.ApplicationPublicationChanged;
    try validateProposal(current.proposal);
    const observed = try self.head(turn);
    if (!baseMatches(observed, current.proposal)) return self.conflict(turn, who, current.proposal, true, observed);
    const descriptor = try self.publication(turn).inspect(turn, current.proposal.record.value);
    if (descriptor.state != .staging or !std.meta.eql(descriptor.spec, current.proposal.spec)) return error.ApplicationPublicationChanged;
    if (self.failure) |detail| detail.witness = .{ .upload = .{ .record = current.proposal.record, .written = descriptor.written, .required = descriptor.spec.chunks(), .length = descriptor.spec.length } };
    if (descriptor.written != descriptor.spec.chunks()) return error.IncompletePublication;
    var bytes: [m.max_program_bytes]u8 = undefined;
    for (0..descriptor.written) |i| {
        const index: u32 = @intCast(i);
        const chunk = (try turn.read(Pub.key(.application_definition, self.configuration.namespace.value, 'c', current.proposal.record.value, index))) orelse return error.MissingPublicationChunk;
        if (chunk.len != try descriptor.spec.size(index)) return error.InvalidPublicationChunk;
        @memcpy(bytes[i * Pub.chunk_bytes ..][0..chunk.len], chunk.slice());
    }
    return self.step(allocator, turn, current.proposal, bytes[0..descriptor.spec.length]);
}
/// One bounded staging operation, or atomic publish/head/receipt (four mutations).
/// A transport retry recovers this exact proposal; it cannot change the body/base.
pub fn step(self: Self, allocator: std.mem.Allocator, turn: *Turn, proposal: Proposal, body: []const u8) !Phase {
    const before = turn.decision;
    errdefer turn.decision = before;
    const who = try self.authorize(turn);
    try validateProposal(proposal);
    if (body.len > m.max_program_bytes) return error.InvalidApplicationProposal;
    if (!std.meta.eql(proposal.spec, try Pub.Digest.of(format, body))) return error.ApplicationDigestMismatch;
    const old = try self.receipt(turn, who, proposal.operation);
    if (old) |receipt_value| {
        if (!std.meta.eql(proposal, receipt_value.proposal)) return error.ApplicationIdentityConflict;
        if (receipt_value.phase != .staging) return receipt_value.phase;
    }
    // Reject complete invalid programs before even reserving staging quota.
    var compiler: root.Diagnostic = .{};
    var program = root.Sql.parseDiagnostic(allocator, body, &compiler) catch |err| {
        if (self.failure) |detail| detail.program(compiler, err, proposal.spec.digest);
        return if (err == error.OutOfMemory) err else error.InvalidApplicationProgram;
    };
    defer program.deinit();
    var canonical: [m.max_program_bytes]u8 = undefined;
    if (!std.mem.eql(u8, body, try root.Api.canonical(program.definition, &canonical))) return error.NoncanonicalApplicationProgram;
    if (program.definition.realm != self.configuration.realm or program.definition.revision.value != proposal.revision.value or !std.mem.eql(u8, &nameDigest(program.definition.name), &self.configuration.name_digest)) return error.ApplicationDefinitionMismatch;
    const pub_record = self.publication(turn);
    const observed = try self.head(turn);
    if (!baseMatches(observed, proposal)) {
        // A conflict is durable evidence, not implicit expiry/cleanup of its body.
        return self.conflict(turn, who, proposal, if (old) |value| value.owns_record else false, observed);
    }
    if (old == null) {
        // Each body identity has exactly one attributable owner/proposal.
        try self.reserve(turn, who, proposal);
        return .staging;
    }
    const descriptor = try pub_record.inspect(turn, proposal.record.value);
    if (!std.meta.eql(descriptor.spec, proposal.spec) or descriptor.state != .staging) return error.ApplicationPublicationChanged;
    if (descriptor.written < descriptor.spec.chunks()) {
        if (try turn.read(self.key('x', who, proposal.operation.value)) != null) return error.ApplicationUploadPartConflict;
        const index = descriptor.written;
        const size = try descriptor.spec.size(index);
        _ = try pub_record.append(turn, proposal.record.value, index, body[@as(usize, index) * Pub.chunk_bytes ..][0..size]);
        return .staging;
    }
    _ = try pub_record.publish(turn, proposal.record.value);
    try turn.write(self.key('h', 0, 0), try c.encode('h', Head{ .revision = proposal.revision, .record = proposal.record, .spec = proposal.spec, .principal = who, .operation = proposal.operation, .input = turn.delivery.input.position }));
    try turn.write(self.key('o', who, proposal.operation.value), try c.encode('o', Receipt{ .proposal = proposal, .phase = .applied, .input = turn.delivery.input.position, .owns_record = true }));
    return .applied;
}

/// Explicitly close a staging/conflicted upload; accepted active revisions cannot
/// be abandoned. Cleanup remains a separate, bounded and authorized operation.
pub fn abandon(self: Self, turn: *Turn, operation: m.Wide) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    const who = try self.authorize(turn);
    var value = (try self.receipt(turn, who, operation)) orelse return error.ApplicationOperationNotFound;
    if (value.phase == .applied) return error.ApplicationAlreadyApplied;
    if (value.phase == .abandoned) return;
    const pub_record = self.publication(turn);
    if (value.owns_record) _ = try pub_record.abandon(turn, value.proposal.record.value);
    value.phase = .abandoned;
    try turn.write(self.key('o', who, operation.value), try c.encode('o', value));
    try turn.write(self.key('x', who, operation.value), null);
}

pub fn collect(self: Self, turn: *Turn, operation: m.Wide) !bool {
    const who = try self.authorize(turn);
    const value = (try self.receipt(turn, who, operation)) orelse return error.ApplicationOperationNotFound;
    if (value.phase != .abandoned) return error.ApplicationNotAbandoned;
    if (!value.owns_record) return true;
    return self.publication(turn).collect(turn, value.proposal.record.value);
}

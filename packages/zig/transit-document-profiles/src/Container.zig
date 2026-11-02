//! Constant-memory construction and verification of compound-document manifests.
//! Local bytes are verified incrementally. Grammar, external references, storage,
//! current authorization and durable acceptance remain separate responsibilities.
const std = @import("std");
const Profile = @import("Profile.zig");
const contract = Profile.contract.Container;
const Hash = std.crypto.hash.sha2.Sha256;
const Self = @This();

pub const Limits = struct {
    parts: u64,
    relationships: u64,
    retained_bytes: u64,
    work: u64,

    pub fn validate(self: Limits) !void {
        if (self.parts == 0 or self.work == 0) return error.InvalidDocumentContainerLimits;
    }
};

commitment: contract.Commitment,
limits: Limits,
expected: ?contract.Manifest,
active: ?Profile.contract.Part = null,
part_hash: Hash = .init(.{}),
observed: u64 = 0,
work: u64 = 0,
failed: bool = false,
finished: ?contract.Manifest = null,

/// Profile is an exact interpretation commitment, not proof of parser support.
/// root is the ordinal in the strictly ID-sorted local part directory.
pub fn init(profile: [32]u8, root: u64, limits: Limits) !Self {
    try limits.validate();
    if (root >= limits.parts) return error.DocumentProfileContainerLimitExceeded;
    return .{ .commitment = try contract.Commitment.init(profile, root), .limits = limits, .expected = null };
}

/// A verifier never reports success for a different prefix, order or valid
/// replacement part. No default interpretation is attached to an old manifest.
pub fn verify(manifest: contract.Manifest, limits: Limits) !Self {
    try manifest.validate();
    var result = try init(manifest.profile, manifest.root, limits);
    if (manifest.parts > limits.parts or manifest.relationships > limits.relationships or
        manifest.retained_bytes > limits.retained_bytes) return error.DocumentProfileContainerLimitExceeded;
    result.expected = manifest;
    return result;
}

pub fn beginPart(self: *Self, part: Profile.contract.Part) !void {
    try self.requireActive();
    errdefer self.failed = true;
    if (self.active != null) return error.DocumentContainerPartActive;
    try part.validate();
    if (self.commitment.relationships_started or part.id <= self.commitment.last_id) return error.DocumentProfilePartOrder;
    if (self.commitment.parts == self.limits.parts or
        part.bytes > self.limits.retained_bytes - self.commitment.retained_bytes) return error.DocumentProfileContainerLimitExceeded;
    if (self.expected) |expected| {
        if (self.commitment.parts == expected.parts or
            part.bytes > expected.retained_bytes - self.commitment.retained_bytes) return error.DocumentProfileManifestConflict;
    }
    try self.charge(1);
    self.active = part;
    self.part_hash = .init(.{});
    self.observed = 0;
}

/// Consumes at most work_budget bytes; resubmit the unconsumed tail. Input can
/// be released immediately. Zero budget is a caller error, not a poisoned frame.
pub fn append(self: *Self, input: []const u8, work_budget: u32) !usize {
    if (work_budget == 0) return error.InvalidDocumentWorkBudget;
    try self.requireActive();
    errdefer self.failed = true;
    const part = self.active orelse return error.DocumentContainerNoPart;
    if (input.len > part.bytes - self.observed) return error.DocumentProfilePartConflict;
    const count = @min(input.len, work_budget);
    try self.charge(count);
    self.part_hash.update(input[0..count]);
    self.observed += count;
    return count;
}

pub fn endPart(self: *Self) !void {
    try self.requireActive();
    errdefer self.failed = true;
    const part = self.active orelse return error.DocumentContainerNoPart;
    if (self.observed != part.bytes) return error.IncompleteDocumentFrame;
    if (!std.mem.eql(u8, &part.sha256, &self.part_hash.finalResult())) return error.DocumentProfilePartConflict;
    try self.charge(1);
    try self.commitment.addPart(part);
    self.active = null;
}

/// Relationships follow all local parts. Endpoints are directory ordinals;
/// external references remain unresolved, and cycles require grammar validation.
pub fn addRelationship(self: *Self, relationship: contract.Relationship) !void {
    try self.requireActive();
    errdefer self.failed = true;
    if (self.active != null) return error.DocumentContainerPartActive;
    if (self.commitment.relationships == self.limits.relationships) return error.DocumentProfileContainerLimitExceeded;
    if (self.expected) |expected| {
        if (self.commitment.parts != expected.parts or self.commitment.relationships == expected.relationships)
            return error.DocumentProfileManifestConflict;
    }
    try relationship.validate(self.commitment.parts);
    try self.charge(1);
    try self.commitment.addRelationship(relationship);
}

/// Seals only the observed local representation. This does not publish a stored
/// revision or resolve external references. Prefix/redacted coverage stays so.
pub fn finish(self: *Self) !contract.Manifest {
    if (self.failed) return error.DocumentContainerFailed;
    if (self.finished) |manifest| return manifest;
    errdefer self.failed = true;
    if (self.active != null) return error.IncompleteDocumentFrame;
    try self.charge(1);
    const manifest = try self.commitment.finish();
    if (self.expected) |expected| {
        if (!std.meta.eql(manifest, expected)) return error.DocumentProfileManifestConflict;
    }
    self.finished = manifest;
    return manifest;
}

/// Intermediate verified parts remain provisional with respect to the container.
pub fn verifiedManifest(self: *const Self) !contract.Manifest {
    if (self.failed) return error.DocumentContainerFailed;
    return self.finished orelse error.IncompleteDocumentFrame;
}

fn requireActive(self: *const Self) !void {
    if (self.failed) return error.DocumentContainerFailed;
    if (self.finished != null) return error.DocumentContainerComplete;
}

fn charge(self: *Self, amount: u64) !void {
    if (amount > self.limits.work - self.work) return error.DocumentWorkLimitExceeded;
    self.work += amount;
}

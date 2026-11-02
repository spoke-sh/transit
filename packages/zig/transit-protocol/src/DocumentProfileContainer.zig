//! Ordered compound-document metadata. Commitments establish exact attribution,
//! not byte availability, grammar validity, accepted revisions or authority.
const std = @import("std");
const p = @import("root.zig");
const profile = @import("DocumentProfile.zig");
pub const fixture_json = @embedFile("fixtures/document-profile-container-v1.json");
const Hash = std.crypto.hash.sha2.Sha256;

pub const Revision = struct {
    target: p.DocumentOperation.Target,
    revision: u64,
    manifest: [32]u8,

    pub fn validate(self: Revision) !void {
        try self.target.validate();
        if (self.revision == 0 or std.mem.allEqual(u8, &self.manifest, 0)) return error.InvalidDocumentProfileRevision;
    }
};

/// Resolve this exact revision and ordinal, then require the complete Part to
/// match. Shape validation neither resolves the reference nor acquires a pin.
pub const Reference = struct {
    revision: Revision,
    ordinal: u64,
    part: profile.Part,

    pub fn validate(self: Reference) !void {
        try self.revision.validate();
        try self.part.validate();
    }
};

pub const Relationship = struct {
    kind: enum(u8) { contains = 1, references = 2, derived_from = 3, response_to = 4, attachment = 5 },
    from: u64,
    to: union(enum) { local: u64, external: Reference },
    label: ?p.DataLifecycle.Content,

    pub fn validate(self: Relationship, parts: u64) !void {
        if (self.from >= parts) return error.DocumentProfileRelationshipConflict;
        switch (self.to) {
            .local => |ordinal| if (ordinal >= parts) return error.DocumentProfileRelationshipConflict,
            .external => |reference| try reference.validate(),
        }
        if (self.label) |label| try label.validate();
    }
};

pub const Manifest = struct {
    definition: p.Growth.Definition,
    profile: [32]u8,
    root: u64,
    parts: u64,
    relationships: u64,
    retained_bytes: u64,
    complete_parts: u64,
    redacted_parts: u64,
    prefix_parts: u64,
    digest: [32]u8,

    pub fn validate(self: Manifest) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.parts == 0 or self.root >= self.parts or std.mem.allEqual(u8, &self.profile, 0) or
            std.mem.allEqual(u8, &self.digest, 0)) return error.InvalidDocumentProfileManifest;
        const known = std.math.add(u64, self.complete_parts, self.redacted_parts) catch return error.InvalidDocumentProfileManifest;
        const total = std.math.add(u64, known, self.prefix_parts) catch return error.InvalidDocumentProfileManifest;
        if (total != self.parts) return error.InvalidDocumentProfileManifest;
    }

    /// All local permitted parts are complete. External references still need
    /// independent resolution, current authorization and retention ownership.
    pub fn requireExact(self: Manifest) !void {
        try self.validate();
        if (self.redacted_parts != 0 or self.prefix_parts != 0) return error.DocumentProfileCoverageGap;
    }
};

/// A streaming metadata commitment with constant resident state. Parts are in
/// strictly increasing ID order; relationship order is significant. Cycles and
/// shared references are representable, not certified as valid for a grammar.
pub const Commitment = struct {
    hash: Hash,
    profile_digest: [32]u8,
    root: u64,
    parts: u64 = 0,
    relationships: u64 = 0,
    retained_bytes: u64 = 0,
    complete_parts: u64 = 0,
    redacted_parts: u64 = 0,
    prefix_parts: u64 = 0,
    last_id: u64 = 0,
    relationships_started: bool = false,

    pub fn init(profile_digest: [32]u8, root: u64) !Commitment {
        if (std.mem.allEqual(u8, &profile_digest, 0)) return error.InvalidDocumentProfileManifest;
        var hash = Hash.init(.{});
        hash.update("transit.document.container.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(&profile_digest);
        number(&hash, root);
        return .{ .hash = hash, .profile_digest = profile_digest, .root = root };
    }

    pub fn addPart(self: *Commitment, part: profile.Part) !void {
        try part.validate();
        if (self.relationships_started or part.id <= self.last_id) return error.DocumentProfilePartOrder;
        const count = std.math.add(u64, self.parts, 1) catch return error.DocumentProfileContainerLimitExceeded;
        const bytes = std.math.add(u64, self.retained_bytes, part.bytes) catch return error.DocumentProfileContainerLimitExceeded;
        self.hash.update(&.{1});
        partBytes(&self.hash, part);
        self.parts = count;
        self.retained_bytes = bytes;
        switch (part.coverage) {
            .complete => self.complete_parts += 1,
            .redacted => self.redacted_parts += 1,
            .prefix => self.prefix_parts += 1,
        }
        self.last_id = part.id;
    }

    pub fn addRelationship(self: *Commitment, relationship: Relationship) !void {
        try relationship.validate(self.parts);
        const count = std.math.add(u64, self.relationships, 1) catch return error.DocumentProfileContainerLimitExceeded;
        self.hash.update(&.{ 2, @backingInt(relationship.kind) });
        number(&self.hash, relationship.from);
        switch (relationship.to) {
            .local => |ordinal| {
                self.hash.update(&.{1});
                number(&self.hash, ordinal);
            },
            .external => |reference| {
                self.hash.update(&.{2});
                const target = reference.revision.target;
                const interpretation = target.partition.interpretation;
                const object = interpretation.object;
                self.hash.update(&p.Growth.definition_bytes);
                for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, interpretation.revision }) |value| number(&self.hash, value);
                self.hash.update(&interpretation.digest);
                number(&self.hash, target.partition.partition);
                self.hash.update(&target.document);
                number(&self.hash, reference.revision.revision);
                self.hash.update(&reference.revision.manifest);
                number(&self.hash, reference.ordinal);
                partBytes(&self.hash, reference.part);
            },
        }
        optionalContent(&self.hash, relationship.label);
        self.relationships_started = true;
        self.relationships = count;
    }

    /// Finalizes a copy; the owning builder determines publication/terminality.
    pub fn finish(self: Commitment) !Manifest {
        var hash = self.hash;
        hash.update(&.{3});
        for ([_]u64{ self.parts, self.relationships, self.retained_bytes, self.complete_parts, self.redacted_parts, self.prefix_parts }) |value| number(&hash, value);
        const result: Manifest = .{
            .definition = p.Growth.current_definition,
            .profile = self.profile_digest,
            .root = self.root,
            .parts = self.parts,
            .relationships = self.relationships,
            .retained_bytes = self.retained_bytes,
            .complete_parts = self.complete_parts,
            .redacted_parts = self.redacted_parts,
            .prefix_parts = self.prefix_parts,
            .digest = hash.finalResult(),
        };
        try result.validate();
        return result;
    }
};

fn number(hash: *Hash, value: u64) void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    hash.update(&bytes);
}

fn content(hash: *Hash, value: p.DataLifecycle.Content) void {
    number(hash, value.bytes);
    hash.update(&value.sha256);
}

fn optionalContent(hash: *Hash, value: ?p.DataLifecycle.Content) void {
    hash.update(&.{@intFromBool(value != null)});
    if (value) |some| content(hash, some);
}

fn spanBytes(hash: *Hash, span: profile.Span) void {
    number(hash, span.part_id);
    hash.update(&.{@backingInt(span.space)});
    number(hash, span.byte_start);
    number(hash, span.byte_end);
}

fn partBytes(hash: *Hash, part: profile.Part) void {
    hash.update(&p.Growth.definition_bytes);
    hash.update(&part.profile);
    number(hash, part.id);
    number(hash, part.bytes);
    hash.update(&part.sha256);
    hash.update(&.{switch (part.coverage) {
        .prefix => 1,
        .complete => 2,
        .redacted => 3,
    }});
    if (part.source) |source| {
        switch (source) {
            .exact => |span| {
                hash.update(&.{1});
                spanBytes(hash, span);
            },
            .derived => |derived| {
                hash.update(&.{2});
                spanBytes(hash, derived.source);
                content(hash, derived.transform);
            },
        }
    } else hash.update(&.{0});
}

test "container independent commitment and full-width external references" {
    const Fixture = struct { manifest: Manifest, parts: []const profile.Part, relationships: []const Relationship };
    const parsed = try p.Json.parseFromSlice(Fixture, std.testing.allocator, fixture_json);
    defer parsed.deinit();
    const sample = parsed.value;
    var commitment = try Commitment.init(sample.manifest.profile, sample.manifest.root);
    for (sample.parts) |part| try commitment.addPart(part);
    for (sample.relationships) |relationship| try commitment.addRelationship(relationship);
    try std.testing.expectEqualDeep(sample.manifest, try commitment.finish());
    try std.testing.expectEqual(std.math.maxInt(u64), sample.relationships[1].to.external.revision.revision);
}

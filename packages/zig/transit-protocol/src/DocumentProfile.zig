//! Document interpretation and provenance, independent of merge, storage and
//! transport authority. Shape validation does not admit a parser or data owner.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const Format = enum(u8) {
    json = 1,
    xml = 2,
    http = 3,
    mime = 4,
    ftp = 5,
    edi_x12 = 6,
    edifact = 7,
    hl7 = 8,
    smtp = 9,
    imap = 10,
    pop3 = 11,
    ldap = 12,
    ldif = 13,
    sip = 14,
    sdp = 15,
    amqp = 16,
    mqtt = 17,
    ntp = 18,
    docx = 19,
    xlsx = 20,
    odf = 21,
    pdf = 22,
    grpc = 23,
};

pub const Encoding = enum(u8) { utf8 = 1, ascii = 2, binary = 3, latin1 = 4, ebcdic_cp037 = 5, ebcdic_cp500 = 6, ebcdic_cp1047 = 7 };
pub const Framing = enum(u8) { single = 1, delimited = 2, length_prefixed = 3, multipart = 4, ber = 5, zip = 6, pdf_xref = 7 };
pub const Collation = enum(u8) { utf8_binary = 1, ascii_ci = 2, ebcdic_cp037 = 3 };

/// Explicit per-operation limits, not bounds on durable collection cardinality.
/// Parsers may support a narrower profile and must refuse it before work starts.
pub const Limits = struct {
    input_bytes: u64,
    expanded_bytes: u64,
    expansion_ratio: u32,
    parts: u32,
    nodes: u64,
    depth: u32,
    token_bytes: u32,
    attributes: u32,
    diagnostics: u32,
    work: u64,

    pub fn validate(self: Limits) !void {
        inline for (@typeInfo(Limits).@"struct".field_names) |name| {
            if (@field(self, name) == 0) return error.InvalidDocumentProfileLimits;
        }
    }
};

/// Grammar/schema bytes identify immutable interpretation, not an implementation
/// binary, process generation, merge profile or permission. There are no defaults
/// for persisted definition markers or interpretation fields.
pub const Descriptor = struct {
    definition: p.Growth.Definition,
    format: Format,
    revision: u64,
    grammar: d.Content,
    schema: ?d.Content,
    segmenter: ?d.Content,
    encoding: Encoding,
    framing: Framing,
    key_collation: Collation,
    value_collation: Collation,
    limits: Limits,
    digest: [32]u8,

    pub fn validate(self: Descriptor) !void {
        try self.validateFields();
        if (!std.mem.eql(u8, &self.digest, &self.commitment())) return error.DocumentProfileConflict;
    }

    fn validateFields(self: Descriptor) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.revision == 0) return error.InvalidDocumentProfile;
        try self.grammar.validate();
        if (self.schema) |value| try value.validate();
        if (self.segmenter) |value| try value.validate();
        try self.limits.validate();
    }

    /// SHA-256(domain, current definition bytes, tags, BE u64 fields, content
    /// commitments). Independent fixtures own the byte-level oracle.
    pub fn commitment(self: Descriptor) [32]u8 {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.document.profile.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        hash.update(&.{@backingInt(self.format)});
        number(&hash, self.revision);
        content(&hash, self.grammar);
        optionalContent(&hash, self.schema);
        optionalContent(&hash, self.segmenter);
        hash.update(&.{ @backingInt(self.encoding), @backingInt(self.framing), @backingInt(self.key_collation), @backingInt(self.value_collation) });
        inline for (@typeInfo(Limits).@"struct".field_names) |name| number(&hash, @field(self.limits, name));
        return hash.finalResult();
    }

    pub fn sealed(self: Descriptor) !Descriptor {
        try self.validateFields();
        var result = self;
        result.digest = self.commitment();
        return result;
    }
};

fn number(hash: *std.crypto.hash.sha2.Sha256, value: u64) void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    hash.update(&bytes);
}

fn content(hash: *std.crypto.hash.sha2.Sha256, value: d.Content) void {
    number(hash, value.bytes);
    hash.update(&value.sha256);
}

fn optionalContent(hash: *std.crypto.hash.sha2.Sha256, value: ?d.Content) void {
    hash.update(&.{@intFromBool(value != null)});
    if (value) |some| content(hash, some);
}

/// Offsets are half-open and relative to the named immutable part/space, never
/// silently converted from compressed bytes to decoded text coordinates.
pub const Span = struct {
    part_id: u64,
    space: enum(u8) { raw = 1, decoded = 2, derived = 3 },
    byte_start: u64,
    byte_end: u64,

    pub fn validate(self: Span) !void {
        if (self.part_id == 0 or self.byte_end < self.byte_start) return error.InvalidDocumentProfileSpan;
    }

    pub fn requireWithin(self: Span, part_id: u64, space: @FieldType(Span, "space"), bytes: u64) !void {
        try self.validate();
        if (self.part_id != part_id or self.space != space or self.byte_end > bytes) return error.DocumentProfileSpanConflict;
    }
};

pub const Provenance = union(enum) {
    exact: Span,
    derived: struct { source: Span, transform: d.Content },

    pub fn validate(self: Provenance) !void {
        switch (self) {
            .exact => |span| try span.validate(),
            .derived => |value| {
                try value.source.validate();
                try value.transform.validate();
            },
        }
    }
};

/// The hash covers permitted retained bytes. An omission never acquires a
/// byte-exact commitment to the unretained secret-bearing source.
pub const Part = struct {
    definition: p.Growth.Definition,
    profile: [32]u8,
    id: u64,
    bytes: u64,
    sha256: [32]u8,
    coverage: enum { prefix, complete, redacted },
    source: ?Provenance,

    pub fn validate(self: Part) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.id == 0 or std.mem.allEqual(u8, &self.profile, 0)) return error.InvalidDocumentProfilePart;
        if (self.source) |source| try source.validate();
        if (self.bytes == 0) {
            var empty: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash("", &empty, .{});
            if (!std.mem.eql(u8, &empty, &self.sha256)) return error.DocumentProfilePartConflict;
        }
    }

    pub fn requireExact(self: Part) !void {
        try self.validate();
        if (self.coverage != .complete) return error.DocumentProfileCoverageGap;
    }
};

/// Capture availability does not encode validation, acknowledgement, an effect
/// permit or a remote outcome. These observations remain independently bound.
pub const Capture = enum { preparing, ready, capturing, complete, unknown, retired };
pub const Validation = struct {
    revision: u64,
    validator: d.Content,
    status: enum { valid, invalid, incomplete },
    diagnostics: u64,

    pub fn validate(self: Validation) !void {
        if (self.revision == 0 or (self.status == .valid and self.diagnostics != 0) or
            (self.status == .invalid and self.diagnostics == 0)) return error.InvalidDocumentProfileValidation;
        try self.validator.validate();
    }
};

pub const SchemaTypes = struct {
    descriptor: Descriptor,
    part: Part,
    span: Span,
    provenance: Provenance,
    capture: Capture,
    validation: Validation,
};

test "document profile independent fixture and interpretation commitments" {
    const t = std.testing;
    const parsed = try p.Json.parseFromSlice(SchemaTypes, t.allocator, @embedFile("fixtures/document-profile-v1.json"));
    defer parsed.deinit();
    const sample = parsed.value;
    try sample.descriptor.validate();
    try sample.part.validate();
    try sample.span.validate();
    try sample.provenance.validate();
    try sample.validation.validate();
    try t.expectEqual(@as(u64, std.math.maxInt(u64)), sample.span.part_id);
    try t.expectError(error.DocumentProfileCoverageGap, sample.part.requireExact());
    var changed = sample.descriptor;
    changed.value_collation = .ascii_ci;
    try t.expectError(error.DocumentProfileConflict, changed.validate());
    changed = sample.descriptor;
    changed.limits.input_bytes += 1;
    try t.expectError(error.DocumentProfileConflict, changed.validate());
    changed = sample.descriptor;
    changed.schema = .{ .bytes = 1, .sha256 = @splat(1) };
    try t.expectError(error.DocumentProfileConflict, changed.validate());
    const foreign = try t.allocator.dupe(u8, @embedFile("fixtures/document-profile-v1.json"));
    defer t.allocator.free(foreign);
    const marker = std.mem.indexOf(u8, foreign, @tagName(p.Growth.current_definition)).?;
    @memset(foreign[marker..][0..64], '0');
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(SchemaTypes, t.allocator, foreign));
    changed = sample.descriptor;
    changed.limits.work = 0;
    try t.expectError(error.InvalidDocumentProfileLimits, changed.validate());
    var part = sample.part;
    part.coverage = .complete;
    try part.requireExact();
    part.bytes = 0;
    try t.expectError(error.DocumentProfilePartConflict, part.validate());
    var span = sample.span;
    span.byte_end = span.byte_start - 1;
    try t.expectError(error.InvalidDocumentProfileSpan, span.validate());
    try t.expectError(error.DocumentProfileSpanConflict, sample.span.requireWithin(sample.span.part_id, .decoded, sample.span.byte_end));
    var validation = sample.validation;
    validation.status = .valid;
    try t.expectError(error.InvalidDocumentProfileValidation, validation.validate());
}

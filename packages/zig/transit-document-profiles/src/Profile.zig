const std = @import("std");
const p = @import("transit_protocol");
pub const contract = p.DocumentProfile;

/// These exact bytes identify this parser's interpretation choices, including
/// deliberate restrictions. Changes to meaning require a new grammar commitment.
pub const json_grammar = "transit.document.json.rfc8259.utf8.v1;ordered-duplicate-keys;exact-number-lexemes;unicode-scalars;no-bom";
pub const xml_grammar = "transit.document.xml10.5.utf8.v1;no-dtd;no-external-entities;ascii-names;no-namespaces;normalized-text;predefined-and-numeric-entities;no-bom";
pub const mime_grammar = "transit.document.mime.entity-frame.v1;rfc5322-ascii-fields;crlf;ordered-duplicates;unfold-crlf;header-line-998;required-separator;opaque-binary-body;no-field-semantics;no-multipart-interpretation;no-transfer-decoding;no-encoded-words";

pub fn grammar(bytes: []const u8) p.DataLifecycle.Content {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return .{ .bytes = bytes.len, .sha256 = digest };
}

pub fn descriptor(format: contract.Format, limits: contract.Limits) !contract.Descriptor {
    const selected = switch (format) {
        .json => json_grammar,
        .xml => xml_grammar,
        .mime => mime_grammar,
        else => return error.UnsupportedDocumentProfile,
    };
    return (contract.Descriptor{
        .definition = p.Growth.current_definition,
        .format = format,
        .revision = 1,
        .grammar = grammar(selected),
        .schema = null,
        .segmenter = null,
        .encoding = if (format == .mime) .binary else .utf8,
        .framing = .single,
        .key_collation = if (format == .mime) .ascii_ci else .utf8_binary,
        .value_collation = .utf8_binary,
        .limits = limits,
        .digest = undefined,
    }).sealed();
}

pub fn require(value: contract.Descriptor, format: contract.Format) !void {
    try value.validate();
    const expected = try descriptor(format, value.limits);
    if (!std.meta.eql(value, expected)) return error.UnsupportedDocumentProfile;
}

/// Report only the exact implemented offline interpretation. A resealed but
/// unsupported descriptor cannot inherit capabilities from its format name.
pub fn capabilities(value: contract.Descriptor) !contract.Capabilities {
    try require(value, value.format);
    return .{ .descriptor = value, .operations = .{
        .parse = true,
        .construct = true,
        .validate_schema = false,
        .edit = false,
        .persist = false,
        .query = false,
        .search = false,
        .branch = false,
        .live_transport = false,
    } };
}

pub const Budget = struct {
    limits: contract.Limits,
    offset: u64 = 0,
    work: u64 = 0,
    nodes: u64 = 0,
    expanded: u64 = 0,

    pub fn chargeWork(self: *Budget, amount: u64) !void {
        if (amount > self.limits.work - self.work) return error.DocumentWorkLimitExceeded;
        self.work += amount;
    }

    pub fn consume(self: *Budget) !void {
        if (self.offset == self.limits.input_bytes) return error.DocumentInputLimitExceeded;
        try self.chargeWork(1);
        self.offset += 1;
    }

    pub fn node(self: *Budget) !void {
        if (self.nodes == self.limits.nodes) return error.DocumentNodeLimitExceeded;
        self.nodes += 1;
    }

    pub fn output(self: *Budget, amount: usize) !void {
        if (amount > self.limits.expanded_bytes - self.expanded) return error.DocumentExpansionLimitExceeded;
        self.expanded += amount;
    }
};

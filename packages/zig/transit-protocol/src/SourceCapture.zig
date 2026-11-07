//! Complete finite HTTP observations and opaque destination-owned references.
//! These values bind evidence. Only the capture owner can verify and admit it.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const chunk_bytes = 64 * 1024;
pub const max_reference_bytes = 4096;

/// Unlike immutable metadata content, a response body may be empty.
pub const Body = struct {
    bytes: u64,
    sha256: [32]u8,

    pub fn validate(self: Body) !void {
        if (self.bytes == 0) {
            var empty: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash("", &empty, .{});
            if (!std.mem.eql(u8, &empty, &self.sha256)) return error.InvalidSourceCapture;
        }
    }
};

/// A host verifier binds the original attempt and complete retained exchange,
/// independently of the application's claim that its poll is captured.
pub const Evidence = struct {
    definition: p.Growth.Definition,
    poll: p.Source.Poll,
    connection: d.Definition,
    destination: d.Definition,
    columns: [7]u64,
    attempt: d.Operation,
    exchange: d.Content,
    terminal: d.Content,
    verifier: d.Definition,
    observed_at_ms: u64,
    http_status: u16,
    body: Body,

    pub fn validate(self: Evidence) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.poll.validate();
        try self.connection.validate();
        try self.destination.validate();
        try self.attempt.validate();
        try self.exchange.validate();
        try self.terminal.validate();
        try self.verifier.validate();
        try self.body.validate();
        if (self.poll.state != .captured or self.poll.source.object.branch != 1 or
            self.http_status < 200 or self.http_status > 599 or self.observed_at_ms < self.poll.due_ms or
            !std.meta.eql(self.attempt.scope, self.poll.operation.scope)) return error.InvalidSourceCapture;
        for ([_]d.Definition{ self.connection, self.destination, self.verifier }) |value| {
            if (!std.meta.eql(value.object.scope, self.poll.source.object.scope) or value.object.branch != 1)
                return error.InvalidSourceCapture;
        }
        if (std.meta.eql(self.poll.source.object, self.connection.object) or
            std.meta.eql(self.poll.source.object, self.destination.object) or
            std.meta.eql(self.connection.object, self.destination.object)) return error.InvalidSourceCapture;
        for (self.columns, 0..) |column, i| {
            if (column == 0) return error.InvalidSourceCapture;
            for (self.columns[0..i]) |previous| if (column == previous) return error.InvalidSourceCapture;
        }
    }

    pub fn requireSource(self: Evidence, source: p.Source.Definition) !void {
        try self.validate();
        try source.validate();
        if (!std.meta.eql(self.poll.source, source.interpretation) or
            !std.meta.eql(self.connection, source.connection) or !std.meta.eql(self.destination, source.destination) or
            !std.meta.eql(self.columns, source.columns) or self.body.bytes > source.http.response_max_bytes)
            return error.InvalidSourceCapture;
    }

    pub fn capture(self: Evidence, manifest: d.Content) !p.Source.Capture {
        try self.validate();
        const value: p.Source.Capture = .{
            .definition = self.definition,
            .source = self.poll.source,
            .connection = self.connection,
            .destination = self.destination,
            .operation = self.poll.operation,
            .capture_id = self.poll.capture_id,
            .sequence = self.poll.sequence,
            .observed_at_ms = self.observed_at_ms,
            .http_status = self.http_status,
            .body_bytes = self.body.bytes,
            .body_sha256 = self.body.sha256,
            .manifest = manifest,
        };
        try value.validate();
        return value;
    }
};

/// Saved row value, not a bearer capability. Resolution requires an accepted
/// attachment and current destination policy. Candidate is the original token
/// commitment, not a provider path or a name that can be rebound.
pub const Reference = struct {
    definition: p.Growth.Definition,
    destination: d.Definition,
    candidate: [32]u8,
    manifest: d.Content,

    pub fn validate(self: Reference) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.destination.validate();
        try self.manifest.validate();
        if (self.destination.object.branch != 1 or std.mem.allEqual(u8, &self.candidate, 0))
            return error.InvalidSourceCapture;
    }
    pub fn encode(self: Reference, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(allocator, self, max_reference_bytes);
    }
};

pub const Attachment = struct {
    reference: Reference,
    transaction: p.Transaction.Identity,
    pub fn validate(self: Attachment) !void {
        try self.reference.validate();
        try self.transaction.validate();
        if (self.transaction.branch != self.reference.destination.object.branch or
            !std.meta.eql(self.transaction.begin.scope, self.reference.destination.object.scope)) return error.InvalidSourceCapture;
    }
};
pub const SchemaTypes = struct { evidence: Evidence, reference: Reference };

test "capture evidence binds finite original and reference stays below the row budget" {
    const t = std.testing;
    const parsed = try p.Json.parseFromSlice(SchemaTypes, t.allocator, @embedFile("fixtures/source-capture-v1.json"));
    defer parsed.deinit();
    const value = parsed.value;
    try value.evidence.validate();
    try value.reference.validate();
    var changed = value.evidence;
    changed.poll.state = .unknown;
    try t.expectError(error.InvalidSourceCapture, changed.validate());
    changed = value.evidence;
    changed.body.sha256[0] ^= 1;
    try t.expectError(error.InvalidSourceCapture, changed.validate());
    changed = value.evidence;
    changed.columns[1] = changed.columns[0];
    try t.expectError(error.InvalidSourceCapture, changed.validate());
    changed = value.evidence;
    changed.attempt.scope.catalog += 1;
    try t.expectError(error.InvalidSourceCapture, changed.validate());
    const encoded = try value.reference.encode(t.allocator);
    defer t.allocator.free(encoded);
    try t.expect(encoded.len < max_reference_bytes);
    var largest = value.reference;
    largest.destination.object.scope.catalog = std.math.maxInt(u64);
    largest.destination.object.object = std.math.maxInt(u64);
    largest.destination.revision = std.math.maxInt(u64);
    largest.manifest.bytes = std.math.maxInt(u64);
    largest.destination.digest = @splat(255);
    largest.candidate = @splat(255);
    largest.manifest.sha256 = @splat(255);
    const maximum = try largest.encode(t.allocator);
    defer t.allocator.free(maximum);
    try t.expect(maximum.len < max_reference_bytes);
}

//! Immutable import identity, saved before acquiring an Exchange consumer hold.
const std = @import("std");
const root = @import("root.zig");
const c = root.data.catalog;
const p = c.protocol;
const x = root.http.exchange;
const Self = @This();
pub const format: u32 = 0x53484931; // SHI1, immutable handoff input.
pub const max_bytes = 24 * 1024;

definition: p.Growth.Definition,
key: c.DirectClientToken.Key,
namespace: u64,
operation: p.DataLifecycle.Operation,
source: p.Source.Definition,
poll: p.Source.Poll,
attempt: p.DataLifecycle.Operation,
verifier: p.DataLifecycle.Definition,
observed_at_ms: u64,
origin: struct { reference: x.Client.Reference, descriptor: x.Descriptor, token: u64, holder: u64 },
candidate: struct { key: c.DirectClientToken.Key, budget: c.DirectClientToken.Budget, limits: c.DirectSourceCapture.Limits },
publication: struct { key: c.DirectClientToken.Key, begin: p.DataLifecycle.Operation, append: p.DataLifecycle.Operation, settlement: p.DataLifecycle.Operation, limits: p.Transaction.Limits, budget: c.DirectClientToken.Budget },
budget: c.DirectClientToken.Budget,
work: struct { bytes: u64, parts: u64 },

pub fn validate(self: Self) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.key.validate();
    try self.key.connection.owner(self.operation);
    try self.key.connection.owner(self.poll.operation);
    try self.source.validate();
    try self.poll.validate();
    try self.attempt.validate();
    try self.verifier.validate();
    try self.origin.reference.validate();
    try self.origin.descriptor.validate();
    try self.budget.validate();
    try self.candidate.budget.validate();
    try self.candidate.limits.validate();
    try self.publication.budget.validate();
    try self.publication.limits.validate();
    if (self.namespace == 0 or self.origin.token == 0 or self.origin.holder == 0 or
        self.origin.descriptor.phase != .complete or self.origin.descriptor.protocol != root.http.protocol_format or
        self.origin.descriptor.bytes > 8 * 1024 * 1024 or self.origin.descriptor.segments > 65536 or
        !std.mem.eql(u8, &self.origin.reference.chain, &self.origin.descriptor.chain) or
        self.source.http.response_max_bytes > 4 * 1024 * 1024 or self.poll.state != .captured or
        !std.meta.eql(self.poll.source, self.source.interpretation) or self.observed_at_ms < self.poll.due_ms or
        self.work.bytes < 2 * self.origin.descriptor.bytes or self.work.parts < 2 * self.passParts()) return error.InvalidSourceHandoff;
    const keys = [_]c.DirectClientToken.Key{ self.key, self.candidate.key, self.publication.key };
    for (keys, 0..) |key, i| {
        try key.validate();
        if (!std.meta.eql(key.scope(), self.key.scope())) return error.InvalidSourceHandoff;
        for (keys[0..i]) |previous| if (std.mem.eql(u8, &try key.digest(), &try previous.digest())) return error.InvalidSourceHandoff;
    }
    const operations = [_]p.DataLifecycle.Operation{ self.operation, self.poll.operation, self.publication.begin, self.publication.append, self.publication.settlement };
    for (operations, 0..) |operation, i| {
        try self.key.connection.owner(operation);
        for (operations[0..i]) |previous| if (std.meta.eql(operation, previous)) return error.InvalidSourceHandoff;
    }
}
pub fn passParts(self: Self) u64 {
    return self.origin.descriptor.bytes / x.Publication.chunk_bytes + self.origin.descriptor.segments + 1;
}
pub fn encode(self: Self, allocator: std.mem.Allocator) ![]u8 {
    try self.validate();
    return p.Json.valueAllocBounded(allocator, self, max_bytes);
}
pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Self) {
    if (bytes.len == 0 or bytes.len > max_bytes) return error.InvalidSourceHandoff;
    const parsed = try p.Json.parseFromSlice(Self, allocator, bytes);
    errdefer parsed.deinit();
    const canonical = try parsed.value.encode(allocator);
    defer allocator.free(canonical);
    if (!std.mem.eql(u8, canonical, bytes)) return error.InvalidSourceHandoff;
    return parsed;
}
pub fn evidence(self: Self, completion: root.http.Completion, body: p.SourceCapture.Body) !p.SourceCapture.Evidence {
    const encoded = try self.origin.descriptor.encode();
    const terminal = try x.codec.encode(completion);
    const result: p.SourceCapture.Evidence = .{
        .definition = p.Growth.current_definition,
        .poll = self.poll,
        .connection = self.source.connection,
        .destination = self.source.destination,
        .columns = self.source.columns,
        .attempt = self.attempt,
        .exchange = c.storage.LogBatch.content(encoded.slice()),
        .terminal = c.storage.LogBatch.content(terminal.slice()),
        .verifier = self.verifier,
        .observed_at_ms = self.observed_at_ms,
        .http_status = completion.status,
        .body = body,
    };
    try result.requireSource(self.source);
    return result;
}
pub fn descriptor(self: Self, evidence_value: p.SourceCapture.Evidence) !c.DirectSourceCapture.Descriptor {
    try evidence_value.requireSource(self.source);
    const result: c.DirectSourceCapture.Descriptor = .{ .key = self.candidate.key, .operation = self.poll.operation, .namespace = self.namespace, .evidence = evidence_value, .budget = self.candidate.budget, .limits = self.candidate.limits };
    try result.validate();
    return result;
}
pub fn plan(self: Self, manifest: p.DataLifecycle.Content) !c.DirectSourcePublication {
    const result: c.DirectSourcePublication = .{
        .definition = p.Growth.current_definition,
        .candidate = self.candidate.key,
        .key = self.publication.key,
        .reference = .{ .definition = p.Growth.current_definition, .candidate = try self.candidate.key.digest(), .destination = self.source.destination, .manifest = manifest },
        .namespace = self.namespace,
        .operation = self.publication.begin,
        .append = self.publication.append,
        .settlement = self.publication.settlement,
        .limits = self.publication.limits,
        .budget = self.publication.budget,
    };
    try result.validate();
    return result;
}

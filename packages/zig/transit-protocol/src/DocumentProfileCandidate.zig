//! Offline candidate attribution. A binding neither reserves storage nor proves
//! grammar, current authority, a retained dependency or revision acceptance.
const std = @import("std");
const p = @import("root.zig");
const profile = @import("DocumentProfile.zig");
const Hash = std.crypto.hash.sha2.Sha256;

pub const Binding = struct {
    definition: p.Growth.Definition,
    target: p.DocumentOperation.Target,
    operation: p.DataLifecycle.Operation,
    /// Null selects creation; a revision selects an exact edit base. The data
    /// owner must check that precondition again at acceptance.
    base: ?profile.Container.Revision,
    interpretation: profile.Descriptor,
    source: profile.Container.Manifest,
    digest: [32]u8,

    pub fn validate(self: Binding) !void {
        try self.validateFields();
        if (!std.mem.eql(u8, &self.digest, &self.commitment())) return error.DocumentCandidateConflict;
    }

    fn validateFields(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target.requireOperation(self.operation);
        if (self.base) |base| {
            try base.validate();
            try self.target.requireSame(base.target);
        }
        try self.interpretation.validate();
        try self.source.validate();
        if (!std.mem.eql(u8, &self.interpretation.digest, &self.source.profile)) return error.DocumentCandidateConflict;
        const limits = self.interpretation.limits;
        if (self.source.parts > limits.parts or self.source.retained_bytes > limits.input_bytes or
            self.source.relationships > limits.work) return error.DocumentProfileContainerLimitExceeded;
    }

    pub fn sealed(self: Binding) !Binding {
        try self.validateFields();
        var result = self;
        result.digest = self.commitment();
        return result;
    }

    pub fn requireSame(self: Binding, other: Binding) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentCandidateConflict;
    }

    /// Explicit canonical bytes, never native struct layout or JSON formatting.
    pub fn commitment(self: Binding) [32]u8 {
        var hash = Hash.init(.{});
        hash.update("transit.document.candidate.v1\x00");
        hash.update(&p.Growth.definition_bytes);
        targetBytes(&hash, self.target);
        const scope = self.operation.scope;
        for ([_]u64{ scope.realm, scope.resource, scope.catalog, self.operation.principal, self.operation.operation }) |value| number(&hash, value);
        hash.update(&.{@intFromBool(self.base != null)});
        if (self.base) |base| {
            targetBytes(&hash, base.target);
            number(&hash, base.revision);
            hash.update(&base.manifest);
        }
        hash.update(&self.interpretation.digest);
        const source = self.source;
        hash.update(&p.Growth.definition_bytes);
        hash.update(&source.profile);
        for ([_]u64{ source.root, source.parts, source.relationships, source.retained_bytes, source.complete_parts, source.redacted_parts, source.prefix_parts }) |value| number(&hash, value);
        hash.update(&source.digest);
        return hash.finalResult();
    }
};

fn number(hash: *Hash, value: u64) void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    hash.update(&bytes);
}

fn targetBytes(hash: *Hash, value: p.DocumentOperation.Target) void {
    const interpretation = value.partition.interpretation;
    const object = interpretation.object;
    hash.update(&p.Growth.definition_bytes);
    for ([_]u64{ object.scope.realm, object.scope.resource, object.scope.catalog, object.branch, object.object, interpretation.revision }) |field| number(hash, field);
    hash.update(&interpretation.digest);
    number(hash, value.partition.partition);
    hash.update(&value.document);
}

test "candidate commitment binds the original operation target base and source" {
    const t = std.testing;
    const parsed = try p.Json.parseFromSlice(profile.SchemaTypes, t.allocator, profile.fixture_json);
    defer parsed.deinit();
    const binding = parsed.value.candidate;
    try binding.validate();
    try binding.requireSame(binding);
    try t.expectEqual(std.math.maxInt(u64), binding.operation.operation);
    inline for (.{ "operation", "target", "base", "source", "interpretation" }) |field| {
        var changed = binding;
        if (comptime std.mem.eql(u8, field, "operation")) changed.operation.operation -= 1;
        if (comptime std.mem.eql(u8, field, "target")) {
            changed.target.partition.interpretation.digest[0] ^= 1;
            changed.base.?.target = changed.target;
        }
        if (comptime std.mem.eql(u8, field, "base")) changed.base.?.revision -= 1;
        if (comptime std.mem.eql(u8, field, "source")) changed.source.digest[0] ^= 1;
        if (comptime std.mem.eql(u8, field, "interpretation")) {
            changed.interpretation.limits.work += 1;
            changed.interpretation = try changed.interpretation.sealed();
            changed.source.profile = changed.interpretation.digest;
        }
        try t.expectError(error.DocumentCandidateConflict, changed.validate());
        changed = try changed.sealed();
        try t.expectError(error.DocumentCandidateConflict, binding.requireSame(changed));
    }
    var changed = binding;
    changed.operation.scope.catalog -= 1;
    try t.expectError(error.DocumentPartitionConflict, changed.sealed());
    changed = binding;
    changed.base.?.target.document[0] ^= 1;
    try t.expectError(error.DocumentTargetConflict, changed.sealed());
    changed = binding;
    changed.source.retained_bytes = binding.interpretation.limits.input_bytes + 1;
    try t.expectError(error.DocumentProfileContainerLimitExceeded, changed.sealed());
    changed = binding;
    changed.base = null;
    _ = try changed.sealed();
}

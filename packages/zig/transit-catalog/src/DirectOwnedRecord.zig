//! Original external work with reservation before creation and irreversible closure.
//! The token and operation commitments outlive the removable payload.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const R = c.DirectRecord;
const Token = c.DirectClientToken;
pub const format: u32 = 0x534f5231; // SOR1

pub const State = struct {
    phase: enum { reserved, ready, retained, attaching, attached, closed },
    attachment: ?p.DataLifecycle.Binding,
    pub fn initial() State {
        return .{ .phase = .reserved, .attachment = null };
    }
    pub fn validate(self: State) !void {
        if (self.attachment) |binding| {
            try binding.validate();
            if (binding.action != .insert or binding.expected_definition == null or
                (self.phase != .attaching and self.phase != .attached and self.phase != .closed)) return error.InvalidOwnedRecord;
        } else if (self.phase == .attaching or self.phase == .attached) return error.InvalidOwnedRecord;
    }
    pub fn transition(before: State, after: State) !void {
        try before.validate();
        try after.validate();
        if (std.meta.eql(before, after)) return;
        const valid = switch (before.phase) {
            .reserved => after.phase == .ready or after.phase == .closed,
            .ready => after.phase == .retained or after.phase == .attaching or after.phase == .closed,
            .attaching => after.phase == .attached or after.phase == .closed,
            .attached => after.phase == .closed,
            .retained, .closed => false,
        };
        if (!valid or (!std.meta.eql(before.attachment, after.attachment) and !(before.phase == .ready and after.phase == .attaching))) return error.InvalidOwnedRecord;
    }
};
pub const Envelope = struct {
    definition: p.Growth.Definition,
    key: Token.Key,
    format: u32,
    bytes: c.DirectTableProtocol.Binary,
    pub fn validate(self: Envelope, reference: R.Reference) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.key.validate();
        try reference.validate();
        if (self.format == 0 or reference.format != format or
            !std.meta.eql(self.key.scope(), reference.scope)) return error.InvalidOwnedRecord;
    }
};
pub const Stage = struct {
    binding: Token.Binding,
    format: u32,
    bytes: c.DirectTableProtocol.Binary,
    pub fn validate(self: Stage) !void {
        try self.binding.validate();
        if (self.binding.intent != .external or self.binding.intent.external.record.format != format or
            self.format == 0) return error.InvalidOwnedRecord;
    }
    pub fn encode(self: Stage, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const bytes = try c.DirectOwnedRecord.encode(allocator, self.binding.key, self.format, self.bytes);
        errdefer allocator.free(bytes);
        try self.binding.intent.external.record.requireSame(try R.reference(self.binding.key.scope(), format, bytes));
        return bytes;
    }
};
pub const Control = struct {
    key: Token.Key,
    expected: p.DataLifecycle.Position,
    pub fn validate(self: Control) !void {
        try self.key.validate();
        try self.expected.validate();
    }
};
pub const Attach = struct {
    key: Token.Key,
    expected: p.DataLifecycle.Position,
    mutation: c.DirectKV.Mutation,
    pub fn validate(self: Attach) !void {
        try (Control{ .key = self.key, .expected = self.expected }).validate();
        try self.key.connection.binding(self.mutation.binding);
    }
};
pub fn encode(allocator: std.mem.Allocator, key: Token.Key, inner_format: u32, bytes: c.DirectTableProtocol.Binary) ![]u8 {
    const payload = try bytes.decode(allocator, R.max_bytes);
    defer allocator.free(payload);
    try R.validatePayload(allocator, key.connection, inner_format, payload);
    return p.Json.valueAllocBounded(allocator, Envelope{ .definition = p.Growth.current_definition, .key = key, .format = inner_format, .bytes = bytes }, R.max_bytes);
}
pub fn stage(client: c.DirectTableClient, key: Token.Key, namespace: u64, operation: u64, fingerprint: [32]u8, budget: Token.Budget, inner_format: u32, payload: []const u8) !Token.Progress {
    const binary = try c.DirectTableProtocol.Binary.encode(client.allocator, payload);
    defer client.allocator.free(binary.base64);
    const bytes = try encode(client.allocator, key, inner_format, binary);
    defer client.allocator.free(bytes);
    const reference = try R.reference(key.scope(), format, bytes);
    return call(client, .{ .stage_original = .{ .binding = .{ .key = key, .fingerprint = fingerprint, .budget = budget, .intent = .{ .external = .{ .connection = client.connection, .namespace = namespace, .operation = operation, .record = reference } } }, .format = inner_format, .bytes = binary } });
}
pub fn call(client: c.DirectTableClient, request: Token.ProgressRequest) !Token.Progress {
    const response = try client.call(.{ .client_progress = request });
    defer response.deinit();
    return response.value.result.client_progress.state orelse error.InvalidTableResponse;
}

test "owned original signatures bind staging attachment and irreversible controls" {
    const Fixture = struct {
        requests: struct {
            stage_original: c.DirectTableProtocol.Request,
            retain_original: c.DirectTableProtocol.Request,
            attach_original: c.DirectTableProtocol.Request,
            close_original: c.DirectTableProtocol.Request,
        },
        public_key: [32]u8,
    };
    const t = std.testing;
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-owned-record-v1.json"));
    defer parsed.deinit();
    inline for (@typeInfo(@FieldType(Fixture, "requests")).@"struct".field_names) |name| {
        const request = @field(parsed.value.requests, name);
        try request.validate(t.allocator);
        try request.proof.verify(parsed.value.public_key);
        try t.expect(request.transport().mutation);
    }
    try t.expect(parsed.value.requests.close_original.transport().control != null);
    const staged = parsed.value.requests.stage_original.action.client_progress.stage_original;
    const encoded = try staged.encode(t.allocator);
    defer t.allocator.free(encoded);
    var changed = parsed.value.requests.stage_original;
    changed.action.client_progress.stage_original.bytes.base64 = "Y2hhbmdlZA==";
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = parsed.value.requests.attach_original;
    changed.action.client_progress.attach_original.mutation.binding.identity.operation -= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
    changed = parsed.value.requests.close_original;
    changed.action.client_progress.close_original.expected.next_lsn += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
}

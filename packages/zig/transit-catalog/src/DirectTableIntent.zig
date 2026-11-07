//! Complete frozen direct Table work. Loading and inspecting saved bytes never
//! resolves a name, binds SQL parameters, signs a request or admits work.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const d = p.DataLifecycle;
const Self = @This();
pub const prefix_bytes = 36;
pub const max_bytes = prefix_bytes + w.max_request_bytes;
pub const Work = union(enum) {
    ddl: w.Ddl,
    rows: w.Rows,
    statement: w.Statement,
    pub fn binding(self: Work) d.Binding {
        return switch (self) {
            inline else => |value| value.binding,
        };
    }
    pub fn action(self: Work) w.Action {
        return switch (self) {
            .ddl => |value| .{ .admit_ddl = value },
            .rows => |value| .{ .admit_rows = value },
            .statement => |value| .{ .admit_statement = value },
        };
    }
};
pub const Saved = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    work: Work,
    pub fn validate(self: Saved, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.binding(self.work.binding());
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit();
        switch (self.work) {
            .ddl => |value| try value.validate(arena.allocator(), self.connection),
            .rows => |value| _ = try value.native(arena.allocator()),
            .statement => |value| _ = try value.native(arena.allocator()),
        }
    }
};
/// Small durable control-plane reference to complete private data-plane bytes.
/// It is not operation admission, a capability, or permission to fetch payloads.
pub const Reference = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    namespace: u64,
    binding: d.Binding,
    content: d.Content,
    pub fn validate(self: Reference) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.binding(self.binding);
        try c.Model.nativeId(self.namespace);
        try self.content.validate();
        if (self.content.bytes <= prefix_bytes or self.content.bytes > max_bytes) return error.InvalidTableIntent;
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DataIdentityConflict;
    }
    pub fn admit(self: Reference, client: c.DirectTableClient) !c.DirectTableClient.OwnedResponse {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        return client.call(.{ .admit_saved = self });
    }
    pub fn operation(self: Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !c.DirectTableClient.OwnedResponse {
        try self.validate();
        if (!std.meta.eql(self.connection, client.connection)) return error.CatalogIdentityConflict;
        return client.call(.{ .operation = .{ .binding = self.binding, .command = command, .steps = steps } });
    }
};
allocator: std.mem.Allocator,
bytes: []u8,
parsed: std.json.Parsed(Saved),

pub fn encode(allocator: std.mem.Allocator, value: Saved) ![]u8 {
    var scratch: [256]u8 = undefined;
    var count: std.Io.Writer.Discarding = .init(&scratch);
    var counter: std.json.Stringify = .{ .writer = &count.writer };
    try p.Json.write(value, &counter);
    if (count.fullCount() > w.max_request_bytes) return error.TablePayloadTooLarge;
    const bytes = try allocator.alloc(u8, prefix_bytes + @as(usize, @intCast(count.fullCount())));
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    try writer.writeAll("TDI1");
    try writer.writeAll(&p.Growth.definition_bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    std.debug.assert(writer.buffered().len == bytes.len);
    return bytes;
}
pub fn create(allocator: std.mem.Allocator, connection: w.Connection, work: Work) !Self {
    const saved: Saved = .{ .definition = p.Growth.current_definition, .connection = connection, .work = work };
    try saved.validate(allocator);
    const bytes = try encode(allocator, saved);
    errdefer allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes[prefix_bytes..]);
    return .{ .allocator = allocator, .bytes = bytes, .parsed = parsed };
}
/// Pure lowering of a bound Fuze plan. Row-changing statements freeze the
/// supplied current data frontier; INSERT needs only the exact definition.
pub fn fromDml(allocator: std.mem.Allocator, connection: w.Connection, metadata: w.Definition, operation_id: u64, plan: c.fuze.TableDml.Plan, ingestion: c.storage.TablePartition.Ingestion) !Self {
    const f = c.fuze;
    try plan.validate();
    const prepared = try c.DirectTableBinding.init(connection, metadata);
    if (!std.mem.eql(u8, plan.name, metadata.name.slice()) or !std.mem.eql(u8, &try plan.schema.fingerprint(), &metadata.interpretation.schema_fingerprint)) return error.TableDefinitionChanged;
    const original: d.Binding = .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = connection.scope, .principal = connection.principal, .operation = operation_id },
        .target = prepared.interpretation.interpretation.object,
        .action = switch (plan.action) {
            .insert => .insert,
            .update => .update,
            .delete => .delete,
        },
        .expected_definition = prepared.interpretation.interpretation,
        .expected_data = if (plan.action == .insert) null else if (metadata.workspace) |private| private.private_position else metadata.position,
        .intent = @splat(0),
    };
    try original.validate();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    if (plan.action == .insert) {
        var max_row_len: usize = 0;
        var total: usize = 0;
        for (plan.action.insert, 0..) |cells, index| {
            const row: f.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(original.identity, @intCast(index)), .cells = cells };
            const len = try row.encodedSize(plan.schema);
            if (len > w.max_work_bytes - total) return error.TableBatchTooLarge;
            total += len;
            max_row_len = @max(max_row_len, len);
        }
        const scratch = try alloc.alloc(u8, @max(f.TableSchema.max_bytes, max_row_len));
        const schema = try w.Binary.encode(alloc, try plan.schema.encode(scratch));
        const changes = try alloc.alloc(w.RowChange, plan.action.insert.len);
        for (plan.action.insert, changes, 0..) |cells, *change, index| {
            const row: f.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(original.identity, @intCast(index)), .cells = cells };
            const encoded = try row.encode(plan.schema, scratch);
            change.* = .{ .insert = try w.Binary.encode(alloc, encoded) };
        }
        var work: w.Rows = .{ .binding = original, .interpretation = metadata.interpretation, .schema = schema, .changes = changes, .ingestion = ingestion };
        work.binding.intent = try work.digest(alloc);
        return create(allocator, connection, .{ .rows = work });
    }
    const scratch = try alloc.alloc(u8, @max(f.TableSchema.max_bytes, f.TableDmlCodec.max_bytes));
    const schema = try w.Binary.encode(alloc, try plan.schema.encode(scratch));
    var work: w.Statement = .{ .binding = original, .interpretation = metadata.interpretation, .schema = schema, .plan = try w.Binary.encode(alloc, try f.TableDmlCodec.encode(alloc, plan, scratch)) };
    work.binding.intent = try work.digest(alloc);
    return create(allocator, connection, .{ .statement = work });
}
pub fn restoreOwned(allocator: std.mem.Allocator, bytes: []u8) !Self {
    errdefer allocator.free(bytes);
    if (bytes.len <= prefix_bytes or bytes.len > max_bytes or !std.mem.eql(u8, bytes[0..4], "TDI1")) return error.InvalidTableIntent;
    if (!std.mem.eql(u8, bytes[4..prefix_bytes], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes[prefix_bytes..]);
    errdefer parsed.deinit();
    try parsed.value.validate(allocator);
    if (!p.Json.eqlSlice(bytes[prefix_bytes..], parsed.value)) return error.InvalidTableIntent;
    return .{ .allocator = allocator, .bytes = bytes, .parsed = parsed };
}
pub fn restore(allocator: std.mem.Allocator, input: []const u8) !Self {
    if (input.len <= prefix_bytes or input.len > max_bytes or !std.mem.eql(u8, input[0..4], "TDI1")) return error.InvalidTableIntent;
    if (!std.mem.eql(u8, input[4..prefix_bytes], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const bytes = try allocator.dupe(u8, input);
    return restoreOwned(allocator, bytes);
}
pub fn restoreRows(output: std.mem.Allocator, scratch: std.mem.Allocator, input: []const u8, namespace: u64, sha256: [32]u8) !struct { reference: Reference, request: ?c.storage.TableDmlIntent.Request } {
    if (input.len <= prefix_bytes or input.len > max_bytes or !std.mem.eql(u8, input[0..4], "TDI1")) return error.InvalidTableIntent;
    if (!std.mem.eql(u8, input[4..prefix_bytes], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Saved, scratch, input[prefix_bytes..]);
    defer parsed.deinit();
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try parsed.value.connection.validate();
    try parsed.value.connection.binding(parsed.value.work.binding());
    const request: ?c.storage.TableDmlIntent.Request = switch (parsed.value.work) {
        inline .rows, .statement => |value| try value.native(output),
        .ddl => |value| blk: {
            try value.validate(scratch, parsed.value.connection);
            break :blk null;
        },
    };
    if (!p.Json.eqlSlice(input[prefix_bytes..], parsed.value)) return error.InvalidTableIntent;
    return .{ .reference = try referenceFromSaved(parsed.value, namespace, input.len, sha256), .request = request };
}
pub fn deinit(self: *Self) void {
    self.parsed.deinit();
    self.allocator.free(self.bytes);
    self.* = undefined;
}
pub fn binding(self: *const Self) d.Binding {
    return self.parsed.value.work.binding();
}
pub fn referenceFromSaved(saved: Saved, namespace: u64, bytes_len: usize, sha256: [32]u8) !Reference {
    const result: Reference = .{ .definition = p.Growth.current_definition, .connection = saved.connection, .namespace = namespace, .binding = saved.work.binding(), .content = .{ .bytes = bytes_len, .sha256 = sha256 } };
    try result.validate();
    if (saved.work == .ddl and saved.work.ddl.namespace != namespace) return error.DataIdentityConflict;
    return result;
}
pub fn reference(self: *const Self, namespace: u64) !Reference {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(self.bytes, &hash, .{});
    return referenceFromSaved(self.parsed.value, namespace, self.bytes.len, hash);
}
/// Stage complete immutable work directly, then persist only its reference in
/// an orchestrator's control ledger. Staging never claims or admits operation ID.
pub fn stage(self: *const Self, client: c.DirectTableClient, namespace: u64) !Reference {
    try self.check(client.connection);
    const expected = try self.reference(namespace);
    const response = try client.call(.{ .stage = .{ .namespace = namespace, .intent = self.parsed.value } });
    defer response.deinit();
    try expected.requireSame(response.value.result.staged);
    return response.value.result.staged;
}
pub fn check(self: *const Self, connection: w.Connection) !void {
    if (!std.meta.eql(self.parsed.value.connection, connection)) return error.CatalogIdentityConflict;
}
/// Submission remains separate from execution. The caller must retain these
/// bytes before either mutation attempt; errors may follow accepted admission.
pub fn admit(self: *const Self, client: c.DirectTableClient) !c.DirectTableClient.OwnedResponse {
    try self.check(client.connection);
    return client.call(self.parsed.value.work.action());
}
/// Re-sign current authorization for the same immutable operation. This never
/// reconstructs its payload, replaces its expectations or submits fresh SQL.
pub fn operation(self: *const Self, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !c.DirectTableClient.OwnedResponse {
    try self.check(client.connection);
    return client.call(.{ .operation = .{ .binding = self.binding(), .command = command, .steps = steps } });
}

test {
    _ = @import("direct_table_intent_test.zig");
}

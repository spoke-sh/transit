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
allocator: std.mem.Allocator,
bytes: []u8,
parsed: std.json.Parsed(Saved),

fn encode(allocator: std.mem.Allocator, value: Saved) ![]u8 {
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
        .expected_data = if (plan.action == .insert) null else metadata.position,
        .intent = @splat(0),
    };
    try original.validate();
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const scratch = try alloc.alloc(u8, w.max_work_bytes);
    const schema = try w.Binary.encode(alloc, try plan.schema.encode(scratch));
    if (plan.action == .insert) {
        const changes = try alloc.alloc(w.RowChange, plan.action.insert.len);
        var total: usize = 0;
        for (plan.action.insert, changes, 0..) |cells, *change, index| {
            const row: f.TableRow.Row = .{ .identity = try w.Rows.insertIdentity(original.identity, @intCast(index)), .cells = cells };
            const encoded = try row.encode(plan.schema, scratch);
            if (encoded.len > w.max_work_bytes - total) return error.TableBatchTooLarge;
            total += encoded.len;
            change.* = .{ .insert = try w.Binary.encode(alloc, encoded) };
        }
        var work: w.Rows = .{ .binding = original, .interpretation = metadata.interpretation, .schema = schema, .changes = changes, .ingestion = ingestion };
        work.binding.intent = try work.digest(alloc);
        return create(allocator, connection, .{ .rows = work });
    }
    var work: w.Statement = .{ .binding = original, .interpretation = metadata.interpretation, .schema = schema, .plan = try w.Binary.encode(alloc, try f.TableDmlCodec.encode(alloc, plan, scratch)) };
    work.binding.intent = try work.digest(alloc);
    return create(allocator, connection, .{ .statement = work });
}
pub fn restore(allocator: std.mem.Allocator, input: []const u8) !Self {
    if (input.len <= prefix_bytes or input.len > max_bytes or !std.mem.eql(u8, input[0..4], "TDI1")) return error.InvalidTableIntent;
    if (!std.mem.eql(u8, input[4..prefix_bytes], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const bytes = try allocator.dupe(u8, input);
    errdefer allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(Saved, allocator, bytes[prefix_bytes..]);
    errdefer parsed.deinit();
    try parsed.value.validate(allocator);
    const canonical = try encode(allocator, parsed.value);
    defer allocator.free(canonical);
    if (!std.mem.eql(u8, input, canonical)) return error.InvalidTableIntent;
    return .{ .allocator = allocator, .bytes = bytes, .parsed = parsed };
}
pub fn deinit(self: *Self) void {
    self.parsed.deinit();
    self.allocator.free(self.bytes);
    self.* = undefined;
}
pub fn binding(self: *const Self) d.Binding {
    return self.parsed.value.work.binding();
}
pub fn check(self: *const Self, connection: w.Connection) !void {
    if (!std.meta.eql(self.parsed.value.connection, connection)) return error.CatalogIdentityConflict;
}
/// Submission remains separate from execution. The caller must retain these
/// bytes before either mutation attempt; errors may follow accepted admission.
pub fn admit(self: *const Self, client: c.DirectTableClient) !std.json.Parsed(w.Response) {
    try self.check(client.connection);
    return client.call(self.parsed.value.work.action());
}
/// Re-sign current authorization for the same immutable operation. This never
/// reconstructs its payload, replaces its expectations or submits fresh SQL.
pub fn operation(self: *const Self, client: c.DirectTableClient, command: @FieldType(@FieldType(w.Action, "operation"), "command"), steps: u16) !std.json.Parsed(w.Response) {
    try self.check(client.connection);
    return client.call(.{ .operation = .{ .binding = self.binding(), .command = command, .steps = steps } });
}

test {
    _ = @import("direct_table_intent_test.zig");
}

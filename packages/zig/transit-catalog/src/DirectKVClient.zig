//! Explicit named KV calls over the shared signed database connection. Local
//! saved requests preserve original operation identity after uncertain replies.
const std = @import("std");
const c = @import("root.zig");
const K = c.DirectKV;
const w = c.DirectTableProtocol;
const d = c.protocol.DataLifecycle;
const types = c.fuze.Types;

pub const Action = union(enum) {
    declaration: K.DeclarationRequest,
    lookup: @FieldType(w.Action, "kv_lookup"),
    list: @FieldType(w.Action, "kv_list"),
    observe: d.Object,
    mutate: K.Mutation,
    operation: d.Binding,
    get: struct { object: d.Object, key: []const u8, source: ?c.storage.TablePartition.SnapshotHandle = null },
    pin: @FieldType(K.Request, "pin"),
    pin_status: @FieldType(K.Request, "pin_status"),
    release: @FieldType(K.Request, "release"),
    pub fn encode(self: Action, scratch: std.mem.Allocator) !w.Action {
        return switch (self) {
            .declaration => |value| .{ .kv_declaration = value },
            .lookup => |value| .{ .kv_lookup = value },
            .list => |value| .{ .kv_list = value },
            .get => |value| .{ .kv = .{ .get = .{ .object = value.object, .key = try w.Binary.encode(scratch, value.key), .source = value.source } } },
            inline else => |value, tag| .{ .kv = @unionInit(K.Request, @tagName(tag), value) },
        };
    }
};
pub const Read = struct {
    interpretation: c.storage.TableDeclaration.Stored,
    position: d.Position,
    changed_lsn: u64,
    spec: c.storage.KVDeclaration.Spec,
    source: ?c.storage.TablePartition.SnapshotHandle,
    workspace: ?c.protocol.Transaction.ReadView,
    value: ?types.Values.Cell,
};
pub const Result = union(enum) {
    declaration: K.DeclarationResult,
    lookup: ?K.Definition,
    list: w.StateList,
    definition: K.Definition,
    operation: ?c.storage.TablePartition.Evidence,
    value: Read,
    pin: c.storage.TablePartition.SnapshotHandle,
    pin_status: c.storage.TablePartition.PinState,
    released,
};

/// Freeze a complete declaration locally before preview/admission/execution.
pub fn prepareDeclaration(allocator: std.mem.Allocator, value: K.Declaration) !K.Declaration {
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    var result = value;
    result.binding.intent = try (try value.intent(scratch.allocator())).digest(scratch.allocator());
    _ = try result.request(scratch.allocator());
    return result;
}

/// Encode one bounded batch and fill its content commitment before submission.
/// All returned bytes belong to output; no durable operation is accepted here.
pub fn prepareMutation(arena: *std.heap.ArenaAllocator, original: d.Binding, spec: c.storage.KVDeclaration.Spec, changes: []const c.storage.KVPartition.Change) !K.Mutation {
    const output = arena.allocator();
    if (changes.len == 0 or changes.len > c.storage.KVPartition.max_changes) return error.InvalidKVOperation;
    var scratch: std.heap.ArenaAllocator = .init(output);
    defer scratch.deinit();
    const buffer = try scratch.allocator().alloc(u8, types.Codec.max_bytes);
    const encoded = try output.alloc(K.Change, changes.len);
    var initialized: usize = 0;
    var encoded_bytes: usize = 0;
    errdefer {
        for (encoded[0..initialized]) |change| switch (change) {
            .put => |value| {
                output.free(value.key.base64);
                output.free(value.value.base64);
            },
            .remove => |value| output.free(value.base64),
        };
        output.free(encoded);
    }
    for (changes, encoded) |change, *value| {
        const key_bytes = switch (change) {
            .put => |put| put.key,
            .remove => |key| key,
        };
        if (key_bytes.len == 0 or key_bytes.len > c.storage.KVPartition.max_key_bytes) return error.InvalidKVKey;
        value.* = switch (change) {
            .put => |put| blk: {
                const bytes = try types.Codec.encodeBound(put.value, .{ .name = "value", .type = spec.typeOf(), .nullable = spec.nullable }, buffer);
                // Bound retained encoding before allocating another payload.
                // The final digest additionally checks exact serialized bytes.
                const required = 128 + std.base64.standard.Encoder.calcSize(put.key.len) + std.base64.standard.Encoder.calcSize(bytes.len);
                if (required > w.max_work_bytes - encoded_bytes) return error.KVBatchTooLarge;
                encoded_bytes += required;
                const key = try w.Binary.encode(output, put.key);
                errdefer output.free(key.base64);
                break :blk .{ .put = .{ .key = key, .value = try w.Binary.encode(output, bytes), .expect = put.expect } };
            },
            .remove => |key| blk: {
                const required = 64 + std.base64.standard.Encoder.calcSize(key.len);
                if (required > w.max_work_bytes - encoded_bytes) return error.KVBatchTooLarge;
                encoded_bytes += required;
                break :blk .{ .remove = try w.Binary.encode(output, key) };
            },
        };
        initialized += 1;
    }
    var result: K.Mutation = .{ .binding = original, .changes = encoded };
    result.binding.intent = try result.digest(scratch.allocator());
    try result.validate(scratch.allocator());
    return result;
}

pub const Saved = struct {
    definition: c.protocol.Growth.Definition,
    connection: w.Connection,
    mutation: K.Mutation,
    pub fn validate(self: Saved, scratch: std.mem.Allocator) !void {
        if (self.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.connection.binding(self.mutation.binding);
        try self.mutation.validate(scratch);
    }
};
pub fn save(allocator: std.mem.Allocator, connection: w.Connection, mutation: K.Mutation) ![]u8 {
    const saved: Saved = .{ .definition = c.protocol.Growth.current_definition, .connection = connection, .mutation = mutation };
    try saved.validate(allocator);
    return c.protocol.Json.valueAllocBounded(allocator, saved, w.max_request_bytes);
}
pub fn load(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Saved) {
    if (bytes.len == 0 or bytes.len > w.max_request_bytes) return error.InvalidKVOperation;
    const parsed = try c.protocol.Json.parseFromSliceOwned(Saved, allocator, bytes);
    errdefer parsed.deinit();
    try parsed.value.validate(allocator);
    return parsed;
}

/// Returned values survive response cleanup and the next call until output is
/// reset. No retry, pin release, rebind or mutation follows a failed call.
pub fn apply(output: *std.heap.ArenaAllocator, client: c.DirectTableClient, action: Action) !Result {
    var scratch: std.heap.ArenaAllocator = .init(client.allocator);
    defer scratch.deinit();
    const response = try client.call(try action.encode(scratch.allocator()));
    defer response.deinit();
    return switch (response.value.result) {
        .kv_declaration => |value| .{ .declaration = value },
        .kv_lookup => |value| .{ .lookup = value },
        .kv_list => |value| .{ .list = value },
        .kv => |result| switch (result) {
            .value => |value| .{ .value = .{ .interpretation = value.interpretation, .position = value.position, .changed_lsn = value.changed_lsn, .spec = value.spec, .source = value.source, .workspace = value.workspace, .value = if (value.encoded) |encoded| try types.Codec.decodeBoundInto(output.allocator(), .{ .name = "value", .type = value.spec.typeOf(), .nullable = value.spec.nullable }, try encoded.decode(scratch.allocator(), types.Codec.max_bytes)) else null } },
            inline else => |value, tag| @unionInit(Result, @tagName(tag), value),
        },
        else => error.InvalidKVResponse,
    };
}

test "direct KV caller refuses an oversized batch before exhausting bounded output memory" {
    const t = std.testing;
    var memory: c.fuze.MemoryBudget = .{ .parent = t.allocator, .limit = 16 * 1024 * 1024 };
    var output: std.heap.ArenaAllocator = .init(memory.allocator());
    defer output.deinit();
    const payload = try t.allocator.alloc(u8, 512 * 1024);
    defer t.allocator.free(payload);
    @memset(payload, 0xa5);
    var changes: [32]c.storage.KVPartition.Change = undefined;
    var keys: [32][1]u8 = undefined;
    for (&changes, &keys, 0..) |*change, *key, index| {
        key.* = .{@intCast(index + 1)};
        change.* = .{ .put = .{ .key = key, .value = .{ .value = .{ .atom = .{ .bytes = payload } } }, .expect = .any } };
    }
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
    const object: d.Object = .{ .scope = scope, .branch = 1, .object = 7 };
    const binding: d.Binding = .{ .definition = c.protocol.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 2 }, .target = object, .action = .insert, .expected_definition = .{ .object = object, .revision = 1, .digest = @splat(1) }, .expected_data = null, .intent = @splat(0) };
    try t.expectError(error.KVBatchTooLarge, prepareMutation(&output, binding, .{ .value_type = .binary, .nullable = false }, &changes));
    try t.expect(!memory.exhausted);
}

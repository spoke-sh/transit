//! Neutral local codec operations for native/foreign adapters. Embedded logical
//! JSON is a separately versioned document, never authority or a query request.
const std = @import("std");
const f = @import("root.zig");
const t = f.Types;
const j = f.LogicalJson;
pub const max_request_bytes = 256 * 1024;
pub const max_result_bytes = 256 * 1024;
pub const max_value_bytes = 96 * 1024;
pub const Capabilities = struct {
    definition: []const u8 = t.definition,
    arrow_definition: []const u8 = f.LogicalArrow.definition,
    logical_json: bool = true,
    canonical_binary: bool = true,
    arrow_ipc_export: bool = true,
    arrow_ipc_import: bool = false,
    logical_c_data: bool = false,
    file_acquisition: bool = false,
    durable_file_queries: bool = false,
    request_bytes: u32 = max_request_bytes,
    result_bytes: u32 = max_result_bytes,
    value_bytes: u32 = max_value_bytes,
};
pub const Cast = struct { value_json: []const u8, type_json: []const u8, rounding: t.Semantics.Rounding = .reject };
pub const Pair = struct { left_json: []const u8, right_json: []const u8 };
pub const Action = union(enum) {
    capabilities,
    type_json: []const u8,
    type_bytes: []const u8,
    value_json: []const u8,
    value_bytes: []const u8,
    bind: struct { type_json: []const u8, literal: []const u8 },
    cast: Cast,
    equal: Pair,
    order: Pair,
    hash: []const u8,
    arrow: []const u8,
};
pub const TypeResult = struct { json: []const u8, bytes: []const u8, fingerprint: []const u8, equality: bool, ordering: bool };
pub const ValueResult = struct { json: []const u8, bytes: []const u8 };
pub const Result = union(enum) { capabilities: Capabilities, type: TypeResult, value: ValueResult, equal: bool, order: std.math.Order, hash: []const u8, arrow: struct { schema_json: []const u8, ipc: []const u8 } };
fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, bytes.len * 2);
    const alphabet = "0123456789abcdef";
    for (bytes, 0..) |byte, i| {
        result[i * 2] = alphabet[byte >> 4];
        result[i * 2 + 1] = alphabet[byte & 15];
    }
    return result;
}
fn unhex(allocator: std.mem.Allocator, bytes: []const u8, limit: usize) ![]u8 {
    if (bytes.len % 2 != 0 or bytes.len / 2 > limit) return error.InvalidHexEncoding;
    for (bytes) |byte| if (!(std.ascii.isDigit(byte) or (byte >= 'a' and byte <= 'f'))) return error.InvalidHexEncoding;
    const result = try allocator.alloc(u8, bytes.len / 2);
    errdefer allocator.free(result);
    return std.fmt.hexToBytes(result, bytes);
}
fn typeResult(allocator: std.mem.Allocator, descriptor: t.Type) !Result {
    var bytes: [t.max_encoding_bytes]u8 = undefined;
    const json = try j.encodeType(allocator, descriptor);
    errdefer allocator.free(json);
    const encoded = try hex(allocator, try descriptor.encode(&bytes));
    errdefer allocator.free(encoded);
    const fingerprint = try hex(allocator, &try descriptor.fingerprint());
    errdefer allocator.free(fingerprint);
    return .{ .type = .{ .json = json, .bytes = encoded, .fingerprint = fingerprint, .equality = try t.Operations.supports(descriptor, .equality), .ordering = try t.Operations.supports(descriptor, .ordering) } };
}
fn valueResult(allocator: std.mem.Allocator, cell: t.Values.Cell, field: t.Field) !Result {
    const buffer = try allocator.alloc(u8, max_value_bytes);
    defer allocator.free(buffer);
    // The root field label is not part of FVL1 identity; nested names remain.
    var canonical = field;
    canonical.name = "value";
    const json = try j.encode(allocator, cell, canonical);
    errdefer allocator.free(json);
    const bytes = try hex(allocator, try t.Codec.encode(cell, field, buffer));
    return .{ .value = .{ .json = json, .bytes = bytes } };
}
/// Result slices belong to the caller allocator; an arena provides one release.
/// This function does not perform I/O or access native handles/credentials.
pub fn apply(allocator: std.mem.Allocator, action: Action) !Result {
    return switch (action) {
        .capabilities => .{ .capabilities = .{} },
        .type_json => |bytes| blk: {
            var owner = try j.decodeType(allocator, bytes);
            defer owner.deinit();
            break :blk try typeResult(allocator, owner.type);
        },
        .type_bytes => |text| blk: {
            const bytes = try unhex(allocator, text, t.max_encoding_bytes);
            defer allocator.free(bytes);
            var owner = try t.decode(allocator, bytes);
            defer owner.deinit();
            break :blk try typeResult(allocator, owner.type);
        },
        .value_json => |bytes| blk: {
            var owner = try j.decode(allocator, bytes);
            defer owner.deinit();
            break :blk try valueResult(allocator, owner.cell, owner.field);
        },
        .value_bytes => |text| blk: {
            const bytes = try unhex(allocator, text, max_value_bytes);
            defer allocator.free(bytes);
            var owner = try t.Codec.decode(allocator, bytes);
            defer owner.deinit();
            break :blk try valueResult(allocator, owner.cell, owner.field);
        },
        .bind => |input| blk: {
            if (input.literal.len > 65536) return error.LiteralTooLarge;
            var owner = try j.decodeType(allocator, input.type_json);
            defer owner.deinit();
            const atom = try t.Semantics.bind(input.literal, owner.type);
            break :blk try valueResult(allocator, .{ .value = .{ .atom = atom } }, .{ .name = "value", .type = owner.type });
        },
        .cast => |input| blk: {
            var owner = try j.decode(allocator, input.value_json);
            defer owner.deinit();
            var target = try j.decodeType(allocator, input.type_json);
            defer target.deinit();
            if (owner.cell != .value or owner.cell.value != .atom) return error.NonScalarCast;
            const atom = try t.Semantics.cast(owner.cell.value.atom, owner.field.type, target.type, input.rounding);
            break :blk try valueResult(allocator, .{ .value = .{ .atom = atom } }, .{ .name = "value", .type = target.type, .nullable = owner.field.nullable, .optional = owner.field.optional });
        },
        .equal, .order => |input| blk: {
            var left = try j.decode(allocator, input.left_json);
            defer left.deinit();
            var right = try j.decode(allocator, input.right_json);
            defer right.deinit();
            if (left.field.nullable != right.field.nullable or left.field.optional != right.field.optional or !try left.field.type.eql(right.field.type)) return error.IncompatibleTypes;
            break :blk if (action == .equal) .{ .equal = try t.Operations.eql(left.field, left.cell, right.cell) } else .{ .order = try t.Operations.order(left.field, left.cell, right.cell) };
        },
        .hash => |bytes| blk: {
            var owner = try j.decode(allocator, bytes);
            defer owner.deinit();
            break :blk .{ .hash = try hex(allocator, &try t.Operations.hash(owner.field, owner.cell)) };
        },
        .arrow => |bytes| blk: {
            var owner = try j.decode(allocator, bytes);
            defer owner.deinit();
            const workspace = try allocator.alloc(u8, f.LogicalArrow.working_bytes);
            defer allocator.free(workspace);
            const output = try allocator.alloc(u8, f.LogicalArrow.segment_bytes);
            defer allocator.free(output);
            const schema: t.Type = .{ .structure = &.{owner.field} };
            const ipc = try f.LogicalArrow.encode(schema, &.{.{ .cells = &.{owner.cell} }}, workspace, output);
            const encoded = try hex(allocator, ipc);
            errdefer allocator.free(encoded);
            break :blk .{ .arrow = .{ .schema_json = try j.encodeType(allocator, schema), .ipc = encoded } };
        },
    };
}
/// Owned complete JSON response, including a strict transport bound. Parse and
/// apply allocations are released together even on partial-result failure.
pub fn execute(allocator: std.mem.Allocator, bytes: []const u8) ![]u8 {
    if (bytes.len == 0 or bytes.len > max_request_bytes) return error.CodecBudgetExceeded;
    try t.Json.preflight(bytes, .{ .bytes = max_request_bytes, .depth = 16, .tokens = 128, .fields = 16 });
    var arena: std.heap.ArenaAllocator = .init(allocator);
    defer arena.deinit();
    const action = try std.json.parseFromSliceLeaky(Action, arena.allocator(), bytes, .{ .allocate = .alloc_always, .max_value_len = max_request_bytes });
    const result = try apply(arena.allocator(), action);
    const output = try std.json.Stringify.valueAlloc(allocator, result, .{});
    errdefer allocator.free(output);
    if (output.len > max_result_bytes) return error.CodecBudgetExceeded;
    return output;
}
test "logical codec owns complete results and rejects incompatible definitions without I/O" {
    const testing = std.testing;
    const input = "{\"bind\":{\"type_json\":\"{\\\"definition\\\":\\\"transit.fuze.types.v1.2026-09-30\\\",\\\"type\\\":{\\\"uint128\\\":{}}}\",\"literal\":\"340282366920938463463374607431768211455\"}}";
    try testing.checkAllAllocationFailures(testing.allocator, struct {
        fn run(allocator: std.mem.Allocator, bytes: []const u8) !void {
            const output = try execute(allocator, bytes);
            defer allocator.free(output);
            try testing.expect(std.mem.indexOf(u8, output, "340282366920938463463374607431768211455") != null);
        }
    }.run, .{input});
    try testing.expectError(error.MissingField, execute(testing.allocator, "{\"type_json\":\"{\\\"type\\\":{\\\"int64\\\":{}}}\"}"));
}

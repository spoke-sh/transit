const std = @import("std");
const t = std.testing;
const transit = @import("root.zig");

test "canonical cross-language request fixture and strict schema" {
    const wire = "{\"version\":2,\"realm\":42,\"principal\":0,\"sequence\":1,\"command\":{\"send\":{\"pid\":3,\"value\":\"37\"}}}";
    var parsed = try std.json.parseFromSlice(transit.Request, t.allocator, wire, .{});
    defer parsed.deinit();
    const canonical = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
    defer t.allocator.free(canonical);
    try t.expectEqualStrings(wire, canonical);
    try t.expectError(error.UnknownField, std.json.parseFromSlice(transit.Request, t.allocator, "{\"realm\":42,\"principal\":0,\"sequence\":1,\"command\":{\"spawn\":{}},\"admin\":true}", .{}));
}

test "shared JSON request vectors preserve canonical bytes, digests and signatures" {
    const Vectors = struct {
        version: u32,
        seed_hex: []const u8,
        public_key: [32]u8,
        cases: []const struct { canonical: []const u8, sha256: []const u8, signature: [64]u8 },
    };
    var vectors = try std.json.parseFromSlice(Vectors, t.allocator, transit.fixtures.requests, .{});
    defer vectors.deinit();
    try t.expectEqual(@as(u32, 2), vectors.value.version);
    var seed: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&seed, vectors.value.seed_hex);
    const key = try transit.Ed25519.KeyPair.generateDeterministic(seed);
    try t.expectEqualSlices(u8, &vectors.value.public_key, &key.public_key.toBytes());
    for (vectors.value.cases) |vector| {
        var parsed = try std.json.parseFromSlice(transit.Request, t.allocator, vector.canonical, .{});
        defer parsed.deinit();
        const canonical = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
        defer t.allocator.free(canonical);
        try t.expectEqualStrings(vector.canonical, canonical);
        var expected: [32]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected, vector.sha256);
        try t.expectEqualSlices(u8, &expected, &transit.digest(parsed.value));
        try t.expectEqualSlices(u8, &vector.signature, &(try transit.sign(parsed.value, key)).signature);
        try transit.Ed25519.Signature.fromBytes(vector.signature).verify(&expected, key.public_key);
    }
}

fn largest(comptime T: type) T {
    if (T == transit.Value) return transit.Value.init(&(@as([transit.Value.max_bytes]u8, @splat(255)))) catch unreachable;
    if (T == transit.State.Mutation) return .{ .key = transit.Value.init(&@as([transit.State.max_key_bytes]u8, @splat(255))) catch unreachable, .value = largest(transit.Value) };
    if (T == transit.State.Associate) return .{ .pid = transit.max_counter, .name = transit.Value.init(&@as([transit.State.max_key_bytes]u8, @splat(255))) catch unreachable, .expected_revision = transit.max_counter, .resource = transit.max_counter };
    return switch (@typeInfo(T)) {
        .int => |i| if (i.signedness == .signed) std.math.minInt(T) else std.math.maxInt(T),
        .bool => false,
        .void => {},
        .optional => |i| largest(i.child),
        .array => |i| @splat(largest(i.child)),
        .@"struct" => |i| blk: {
            var value: T = undefined;
            inline for (i.field_names, i.field_types) |name, F| @field(value, name) = largest(F);
            break :blk value;
        },
        .@"enum" => |i| blk: {
            comptime var at: usize = 0;
            inline for (i.field_names, 0..) |name, n| {
                if (comptime name.len > i.field_names[at].len) at = n;
            }
            break :blk @fromBackingInt(@intCast(i.field_values[at]));
        },
        else => @compileError("Unsupported fixture type"),
    };
}
test "every full command fits canonical signing and the bounded journal envelope" {
    const info = @typeInfo(transit.Command).@"union";
    inline for (info.field_names, info.field_types) |name, T| {
        if (comptime T == transit.State.Command) {
            const variants = @typeInfo(T).@"union";
            inline for (variants.field_names, variants.field_types) |tag, V| try envelope(.{ .state = @unionInit(T, tag, largest(V)) });
        } else try envelope(@unionInit(transit.Command, name, largest(T)));
    }
}

test "runtime binding keeps legacy checkpoint bytes and accepts optional upgrade evidence" {
    const legacy = .{
        .revision = @as(u64, 2),
        .operation = @as(u64, 10),
        .instance = @as([16]u8, @splat(1)),
        .resource = @as([32]u8, @splat(2)),
        .workload = @as([32]u8, @splat(3)),
        .incarnation = @as(?[16]u8, @splat(4)),
        .desired = "stopped",
        .phase = "stopped",
        .activation = @as(?transit.Runtime.Activation, null),
        .last_worker_incarnation = @as(?[16]u8, @splat(5)),
    };
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, legacy, .{});
    defer t.allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(transit.Runtime.Binding, t.allocator, bytes, .{});
    defer parsed.deinit();
    const canonical = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
    defer t.allocator.free(canonical);
    try t.expectEqualStrings(bytes, canonical);
    parsed.value.upgrade_from = @splat(6);
    const pending = try std.json.Stringify.valueAlloc(t.allocator, parsed.value, .{});
    defer t.allocator.free(pending);
    var recovered = try std.json.parseFromSlice(transit.Runtime.Binding, t.allocator, pending, .{});
    defer recovered.deinit();
    try t.expectEqual(@as(?[32]u8, @splat(6)), recovered.value.upgrade_from);
}

fn envelope(command: transit.Command) !void {
    const request: transit.Request = .{ .realm = transit.max_counter, .principal = 15, .sequence = transit.max_counter, .command = command };
    const encoded = try std.json.Stringify.valueAlloc(t.allocator, request, .{});
    defer t.allocator.free(encoded);
    try t.expect(encoded.len + 1024 <= transit.max_entry_bytes);
    _ = transit.digest(request);
}

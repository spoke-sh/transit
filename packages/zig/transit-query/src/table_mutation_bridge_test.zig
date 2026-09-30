const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const b = q.TableMutationBridge;
const r = q.TableMutationRecords;
const c = q.document.JsonValues;

test "neutral mutation values retain independent bytes, wide identities and owned fields" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const records = try std.json.parseFromSlice(std.json.Value, alloc, @embedFile("fixtures/table-mutation-records-v1.json"), .{});
    const object = records.value.object;
    const ref_text = object.get("reference").?.string;
    const ref = try b.reference(alloc, ref_text);
    const commands: [6]b.Command = .{
        .{ .begin = .{ .reference = ref_text, .table = 9, .policy_revision = "4" } },
        .{ .part = .{ .reference = ref_text, .ordinal = 0, .second = false, .bytes = object.get("commands").?.array.items[1].string[77 * 2 ..] } },
        .{ .part = .{ .reference = ref_text, .ordinal = 0, .second = true, .bytes = object.get("commands").?.array.items[2].string[77 * 2 ..] } },
        .{ .seal = ref_text },
        .{ .apply = ref_text },
        .{ .cancel = ref_text },
    };
    for (commands, object.get("commands").?.array.items) |command, expected| {
        const native = try command.native(alloc);
        try t.expectEqualStrings(expected.string, try c.hex(alloc, (try native.encode()).slice()));
    }
    const requests = try std.json.parseFromSlice(std.json.Value, alloc, @embedFile("fixtures/table-mutation-v1.json"), .{});
    for (requests.value.object.get("cases").?.array.items) |case| {
        const bytes = try c.unhex(alloc, case.object.get("wire_hex").?.string, q.TableMutationRequest.max_bytes);
        const request = try q.TableMutationRequest.decode(bytes);
        for ([_]u64{ 99, std.math.maxInt(u64) }) |namespace| {
            const value = try b.Compiled.fromNative(alloc, request, namespace);
            const owned = try value.native(alloc);
            try t.expectEqual(namespace, owned.reference.namespace);
            try t.expect(std.meta.eql(request, owned.request));
            try t.expectEqualStrings(case.object.get("wire_hex").?.string, value.request);
            if (namespace == 99 and request.plan.operation == .insert and request.plan.schema.value_type == .int64) try t.expect(std.meta.eql(ref, owned.reference));
            @memset(@constCast(value.request), '0');
            @memset(@constCast(value.reference), '0');
            try t.expect(std.meta.eql(request, owned.request));
            try t.expectEqual(namespace, owned.reference.namespace);
        }
    }
    for (object.get("statuses").?.array.items) |case| {
        var native = try r.Status.decode(try q.protocol.Value.init(try c.unhex(alloc, case.object.get("wire_hex").?.string, 135)));
        native.policy_revision = q.protocol.max_counter;
        const value = try b.Status.fromNative(alloc, native);
        try t.expectEqualStrings("9007199254740991", value.policy_revision);
        try t.expectEqualStrings(ref_text, value.reference);
        try t.expectEqual(native.phase, value.phase);
        try t.expectEqual(native.input, value.input);
        try t.expectEqual(native.affected_rows, value.affected_rows);
        try t.expectEqual(native.reason, value.reason);
        @memset(&native.declaration, 0);
        try t.expectEqualStrings(object.get("declaration").?.string, value.declaration);
    }
}
test "neutral mutation rejects changed references and malformed recovery before transport" {
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var client: q.TableMutationClient = .{ .wire = undefined, .connection = .{ .realm = 46, .principal = 10, .writer = 2, .resource = 7, .table = 9 }, .key = try q.protocol.Ed25519.KeyPair.generateDeterministic(@splat(10)) };
    const caps = (try b.apply(alloc, &client, .capabilities)).capabilities;
    try t.expectEqual(@as(u8, 3), caps.max_rows);
    try t.expect(caps.insert and caps.update_primary_key and caps.delete_primary_key);
    const request = try q.TableMutationRequest.fromSql(46, 2, .{ .resource = 7, .id = 9, .schema = .{ .names = .{ try .init("id"), try .init("value") }, .value_type = .int64 } }, try .init("items"), "DELETE FROM items WHERE id=-9223372036854775808");
    const compiled = try b.Compiled.fromNative(alloc, request, 1);
    var foreign = try request.reference(1);
    foreign.spec.digest[0] ^= 1;
    try t.expectError(error.MutationIdentityConflict, b.apply(alloc, &client, .{ .next = .{ .request = compiled.request, .reference = try c.hex(alloc, (try foreign.encode()).slice()) } }));
    try t.expectError(error.InvalidMutationPrepared, b.apply(alloc, &client, .{ .submit = "{}" }));
    try t.expectError(error.InvalidMutationPrepared, b.apply(alloc, &client, .{ .observe = .{ .prepared = "{}", .input = 1 } }));
    for ([_][]const u8{ "", "00", "+1", "-1", "18446744073709551616" }) |invalid| {
        if (b.apply(alloc, &client, .{ .compile = .{ .name = "items", .sql = "DELETE FROM items WHERE id=1", .namespace = invalid } })) |_| return error.AcceptedInvalidNamespace else |_| {}
    }
    for (0..compiled.reference.len) |len| {
        if (b.reference(alloc, compiled.reference[0..len])) |_| return error.AcceptedTruncatedReference else |_| {}
    }
}

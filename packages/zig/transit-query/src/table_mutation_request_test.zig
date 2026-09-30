const std = @import("std");
const t = std.testing;
const q = @import("root.zig");
const m = q.fuze.model;
const Request = q.TableMutationRequest;

test "owned mutation requests agree with independent neutral bytes and reject every truncation" {
    const Fixtures = struct {
        version: u8,
        definition: []const u8,
        realm: u64,
        writer: u64,
        resource: u64,
        table: u32,
        cases: []const struct { kind: m.Type, sql: []const u8, wire_hex: []const u8 },
    };
    const fixtures = try std.json.parseFromSlice(Fixtures, t.allocator, @embedFile("fixtures/table-mutation-v1.json"), .{});
    defer fixtures.deinit();
    const fixture = fixtures.value;
    try t.expectEqual(@as(u8, 1), fixture.version);
    try t.expectEqualStrings(@tagName(q.protocol.Growth.current_definition), fixture.definition);
    for (fixture.cases) |case| {
        const table: q.station.Table = .{ .resource = fixture.resource, .id = fixture.table, .schema = .{ .names = .{ try m.Name.init("id"), try m.Name.init("value") }, .value_type = case.kind } };
        const request = try Request.fromSql(fixture.realm, fixture.writer, table, try m.Name.init("items"), case.sql);
        var output: [Request.max_bytes]u8 = undefined;
        const encoded = try request.encode(&output);
        var expected: [Request.max_bytes]u8 = undefined;
        try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&expected, case.wire_hex), encoded);
        const recovered = try Request.decode(encoded);
        try t.expect(std.meta.eql(request, recovered));
        const ref = try request.reference(1);
        try t.expectEqual(fixture.resource, ref.resource);
        try t.expectEqual(Request.format, ref.spec.format);
        try t.expectEqual(encoded.len, ref.spec.length);
        try Request.checkReference(ref);
        for (0..encoded.len) |length| {
            if (Request.decode(encoded[0..length])) |_| return error.AcceptedTruncation else |_| {}
        }
        var foreign = output;
        foreign[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, Request.decode(foreign[0..encoded.len]));
        var missing: [Request.max_bytes]u8 = undefined;
        @memcpy(missing[0..4], output[0..4]);
        @memcpy(missing[4..][0 .. encoded.len - 36], output[36..encoded.len]);
        try t.expectError(error.IncompatibleDefinition, Request.decode(missing[0 .. encoded.len - 32]));
        var other_protocol = output;
        other_protocol[0..4].* = "UQB1".*;
        try t.expectError(error.InvalidTableMutationRequest, Request.decode(other_protocol[0..encoded.len]));
        var trailing = output;
        trailing[encoded.len] = 0;
        try t.expectError(error.InvalidTableMutationRequest, Request.decode(trailing[0 .. encoded.len + 1]));
        @memset(&output, 0);
        try t.expect(std.meta.eql(request, recovered)); // No decoded text/binary borrows.
    }
}

test "mutation request bound fits full Table values and validates destination and operation shape" {
    const schema: m.Schema = .{ .names = .{ try m.Name.init("primary_key_name"), try m.Name.init("value_field_name") }, .value_type = .binary };
    const value: m.Cell = .{ .binary = try m.Bytes.init(&@as([220]u8, @splat(255))) };
    var request: Request = .{ .realm = 1, .writer = 2, .resource = 3, .table = 4, .plan = .{ .schema = schema, .operation = .{ .insert = .{
        .{ .key = -1, .value = value }, .{ .key = 0, .value = value }, .{ .key = 1, .value = value },
    } } } };
    var output: [Request.max_bytes]u8 = undefined;
    const encoded = try request.encode(&output);
    try t.expectEqual(@as(usize, Request.max_bytes), encoded.len);
    try t.expect(std.meta.eql(request, try Request.decode(encoded)));
    try t.expectError(error.WriteFailed, request.encode(output[0 .. encoded.len - 1]));
    inline for (.{ "realm", "writer", "resource" }) |field| {
        var invalid = request;
        @field(invalid, field) = 0;
        try t.expectError(error.InvalidTableMutationRequest, invalid.validate());
        @field(invalid, field) = q.protocol.max_counter + 1;
        try t.expectError(error.InvalidTableMutationRequest, invalid.validate());
    }
    request.table = 0;
    try t.expectError(error.InvalidTableMutationRequest, request.encode(&output));
    request.table = 4;
    _ = try request.encode(&output);
    const tag_offset = 65 + output[64];
    output[tag_offset] = 99;
    try t.expectError(error.InvalidTableMutationRequest, Request.decode(output[0..encoded.len]));
    output[tag_offset] = 1;
    output[tag_offset + 1] = 4;
    try t.expectError(error.InvalidTableMutationRequest, Request.decode(output[0..encoded.len]));
    var ref = try request.reference(2);
    ref.record = 2;
    try t.expectError(error.InvalidTableMutationRequest, Request.checkReference(ref));
}

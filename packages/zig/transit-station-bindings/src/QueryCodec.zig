//! Native ABI wrapper over transit-query's shared neutral values/codecs.
const std = @import("std");
pub const query = @import("transit_query");
const v = query.Values;
const base = @import("Abi.zig");
pub const maximum_json_bytes = v.maximum_json_bytes;
pub const unsigned = v.unsigned;
pub const unhex = v.unhex;
pub const Column = v.Column;
pub const columns = v.columns;
pub const foreignColumns = v.foreignColumns;
pub const Scalar = v.Scalar;
pub const Projection = v.Projection;
pub const Source = v.Source;
pub const Plan = v.Plan;
pub const Limits = v.Limits;
pub const Bundle = v.Bundle;
pub const Alternative = v.Alternative;
pub const Cell = v.Cell;
pub const rows = v.rows;
pub const Action = v.Action;
pub const Result = v.Result;
pub const apply = v.apply;
pub fn codec(json: [*]const u8, len: usize, out: *?*base.Buffer) callconv(.c) base.Status {
    out.* = null;
    if (len == 0 or len > maximum_json_bytes) return .invalid_argument;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const parsed = std.json.parseFromSlice(Action, alloc, json[0..len], .{}) catch |err| return base.failure(err, out);
    const result = apply(alloc, parsed.value) catch |err| return base.failure(err, out);
    base.output(result, out) catch |err| return base.status(err);
    return .ok;
}
test "unified foreign bundles preserve every source and full-width scalar through owned JSON" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const sources = [_]Source{
        .{ .resource = 7, .source = .{ .kv = .{ .prefix = "646174612f", .key = .{ .type = .binary }, .value = .{ .type = .uint64 } } } },
        .{ .resource = 7, .source = .{ .table = .{ .id = 9, .names = .{ "id", "label" }, .value_type = .utf8 } } },
        .{ .resource = 7, .source = .{ .document = .{ .reference = .{ .resource = 7, .document = "18446744073709551615", .epoch = "3", .type_revision = 1, .revision = "42" }, .projections = &.{.{ .column = .{ .name = "body", .type = .utf8 }, .path = &.{"東京🙂"}, .mode = .text }} } } },
    };
    for (sources) |source| {
        const input: Bundle = .{ .source = source, .plan = .{ .projection = &.{0}, .limit = "18446744073709551615" }, .limits = .{ .pages = "1000", .segments = "500", .result_bytes = "1048576" } };
        const prepared = (try apply(alloc, .{ .prepare = input })).prepared;
        const decoded = (try apply(alloc, .{ .decode = prepared.bytes })).bundle;
        try t.expectEqualStrings(input.plan.limit.?, decoded.plan.limit.?);
        const json = try std.json.Stringify.valueAlloc(alloc, Action{ .prepare = decoded }, .{});
        try t.expect(std.mem.indexOf(u8, json, "\"projection\":[0]") != null);
        var buffer: ?*base.Buffer = null;
        try t.expectEqual(.ok, codec(json.ptr, json.len, &buffer));
        defer base.Api.station_buffer_destroy(buffer);
        const output = try std.json.parseFromSlice(Result, alloc, base.Api.station_buffer_data(buffer.?)[0..base.Api.station_buffer_size(buffer.?)], .{});
        try t.expectEqualStrings(prepared.bytes, output.value.prepared.bytes);
        try t.expectEqualDeep(prepared.spec, output.value.prepared.spec);
    }
    const scalars = [_]Scalar{ .{ .int64 = "-9223372036854775808" }, .{ .uint64 = "18446744073709551615" }, .{ .float_bits = "0000000000000080" }, .{ .boolean = false }, .{ .utf8 = "é 東京🙂" }, .{ .binary = "00ff80" } };
    for (scalars) |scalar| {
        const restored = try Scalar.fromNative(alloc, try scalar.native(alloc));
        try t.expectEqualStrings(try std.json.Stringify.valueAlloc(alloc, scalar, .{}), try std.json.Stringify.valueAlloc(alloc, restored, .{}));
    }
    try t.expectError(error.InvalidQueryInteger, (Scalar{ .int64 = "-0" }).native(alloc));
    try t.expectError(error.InvalidDocumentInteger, (Scalar{ .uint64 = "01" }).native(alloc));
    try t.expectError(error.NonFiniteValue, (Scalar{ .float_bits = "000000000000f07f" }).native(alloc));
    var invalid = sources[0];
    invalid.source.kv.value.version = 2;
    try t.expectError(error.UnsupportedDecoder, invalid.native(alloc));
}

//! Bounded parser/codec properties. No authority mutation or foreign engine.
const std = @import("std");
const t = std.testing;
const p = @import("transit_protocol");
const Frame = @import("station_frame");

fn requestBytes(bytes: []const u8) !void {
    // Parser rejection, including workspace exhaustion, is an allowed result.
    // Every accepted value must validate and retain its canonical identity.
    var memory: [128 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&memory);
    const alloc = fixed.allocator();
    const parsed = std.json.parseFromSlice(p.SignedRequest, alloc, bytes, .{ .max_value_len = p.max_entry_bytes }) catch return;
    defer parsed.deinit();
    p.validate(parsed.value.request) catch return;
    const before = try p.digest(parsed.value.request);
    const encoded = try std.json.Stringify.valueAlloc(alloc, parsed.value, .{});
    defer alloc.free(encoded);
    const again = try std.json.parseFromSlice(p.SignedRequest, alloc, encoded, .{});
    defer again.deinit();
    const after = try p.digest(again.value.request);
    try t.expectEqualSlices(u8, &before, &after);
    try t.expectEqualSlices(u8, &parsed.value.signature, &again.value.signature);
}
fn fuzzRequest(_: void, smith: *t.Smith) !void {
    var bytes: [p.max_entry_bytes]u8 = undefined;
    try requestBytes(bytes[0..smith.slice(&bytes)]);
}
fn growingBytes(comptime query: bool, bytes: []const u8) !void {
    const g = p.Growth;
    const Signed = if (query) g.SignedQuery else g.SignedRequest;
    var memory: [128 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(&memory);
    const alloc = fixed.allocator();
    const parsed = std.json.parseFromSlice(Signed, alloc, bytes, .{ .max_value_len = p.max_entry_bytes }) catch return;
    defer parsed.deinit();
    const before = if (query) g.queryDigest(parsed.value.query) catch return else g.digest(parsed.value.request) catch return;
    const encoded = try std.json.Stringify.valueAlloc(alloc, parsed.value, .{});
    defer alloc.free(encoded);
    const again = try std.json.parseFromSlice(Signed, alloc, encoded, .{});
    defer again.deinit();
    const after = if (query) try g.queryDigest(again.value.query) else try g.digest(again.value.request);
    try t.expectEqualSlices(u8, &before, &after);
    try t.expectEqualSlices(u8, &parsed.value.signature, &again.value.signature);
}
fn fuzzGrowing(_: void, smith: *t.Smith) !void {
    var bytes: [p.max_entry_bytes]u8 = undefined;
    const input = bytes[0..smith.slice(&bytes)];
    try growingBytes(false, input);
    try growingBytes(true, input);
}
fn frameBytes(bytes: []const u8) !void {
    const encoded = p.Value.init(bytes) catch return;
    const decoded = Frame.decode(encoded) catch return;
    try t.expect(encoded.eql(try decoded.encode()));
}
fn fuzzFrame(_: void, smith: *t.Smith) !void {
    var bytes: [p.Value.max_bytes + 1]u8 = undefined;
    try frameBytes(bytes[0..smith.slice(&bytes)]);
}
fn seed(bytes: []const u8, out: []u8) []const u8 {
    // Pinned Zig Smith.slice corpus encoding: little-endian u32, then bytes.
    std.mem.writeInt(u32, out[0..4], @intCast(bytes.len), .little);
    @memcpy(out[4..][0..bytes.len], bytes);
    return out[0 .. bytes.len + 4];
}

test "fuzz signed request parsing and canonical identity within a fixed workspace" {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const signed = try p.sign(.{ .realm = 42, .principal = 0, .sequence = 1, .command = .{ .send = .{ .pid = 2, .value = try p.Value.init(&.{ 0, 255, 34, 10 }) } } }, key);
    const bytes = try std.json.Stringify.valueAlloc(t.allocator, signed, .{});
    defer t.allocator.free(bytes);
    try requestBytes(bytes);
    for (0..@min(bytes.len, 64)) |length| try requestBytes(bytes[0..length]);
    var buffer: [p.max_entry_bytes + 4]u8 = undefined;
    try t.fuzz({}, fuzzRequest, .{ .corpus = &.{ seed(bytes, &buffer), "\x04\x00\x00\x00null", "\x01\x00\x00\x00{" } });
}

test "fuzz Station frames preserve exact correlation and owned payload bytes" {
    const frame = try (Frame{ .kind = .reply, .correlation = std.math.maxInt(u64), .payload = try p.Value.init(&.{ 0, 255 }) }).encode();
    try frameBytes(frame.slice());
    for (0..frame.len) |length| try frameBytes(frame.slice()[0..length]);
    var buffer: [p.Value.max_bytes + 4]u8 = undefined;
    try t.fuzz({}, fuzzFrame, .{ .corpus = &.{ seed(frame.slice(), &buffer), "\x04\x00\x00\x00STN1" } });
}

test "fuzz growing request and query encodings preserve wide identity and signature domains" {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const signed = try p.Growth.sign(.{ .realm = 42, .principal = 65536, .sequence = p.max_counter, .command = .{ .send = .{ .pid = p.max_counter, .value = try p.Value.init(&.{ 0, 255, 34, 10 }) } } }, key);
    const query = try p.Growth.signQuery(.{ .realm = 42, .principal = p.max_counter, .kind = .{ .version_entries = .{ .id = .{ .pid = p.max_counter, .input = 65536, .index = 0 }, .generation = 2 } } }, key);
    const command_bytes = try std.json.Stringify.valueAlloc(t.allocator, signed, .{});
    defer t.allocator.free(command_bytes);
    const query_bytes = try std.json.Stringify.valueAlloc(t.allocator, query, .{});
    defer t.allocator.free(query_bytes);
    try growingBytes(false, command_bytes);
    try growingBytes(true, query_bytes);
    for (0..query_bytes.len) |length| try growingBytes(true, query_bytes[0..length]);
    var command_seed: [p.max_entry_bytes + 4]u8 = undefined;
    var query_seed: [p.max_entry_bytes + 4]u8 = undefined;
    try t.fuzz({}, fuzzGrowing, .{ .corpus = &.{ seed(command_bytes, &command_seed), seed(query_bytes, &query_seed), "\x04\x00\x00\x00null" } });
}

fn allocatedRoundtrip(allocator: std.mem.Allocator) !void {
    const text = "\"00ff220a\"";
    var parsed = try std.json.parseFromSlice(p.Value, allocator, text, .{});
    const value = parsed.value;
    parsed.deinit();
    const encoded = try std.json.Stringify.valueAlloc(allocator, value, .{});
    defer allocator.free(encoded);
    try t.expectEqualStrings(text, encoded);
}

test "allocation failures release parser and canonical output ownership" {
    try t.checkAllAllocationFailures(t.allocator, allocatedRoundtrip, .{});
}

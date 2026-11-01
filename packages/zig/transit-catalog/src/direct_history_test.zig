const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const Selector = c.DirectHistory.Selector;

test "historical acquisition independent signed intent and full width selector" {
    try verifyFixture(@embedFile("fixtures/direct-history-v1.json"));
}
test "historical common transaction independent signature and selector bytes" {
    try verifyFixture(@embedFile("fixtures/direct-history-common-v1.json"));
}
fn verifyFixture(bytes: []const u8) !void {
    const t = std.testing;
    const Fixture = struct { request: w.Request, public_key: [32]u8, intent_digest: [32]u8, snapshot: d.Snapshot, selector: []const u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, bytes);
    defer parsed.deinit();
    const value = parsed.value;
    try value.request.validate(t.allocator);
    try value.request.proof.verify(value.public_key);
    try t.expectEqual(value.intent_digest, try value.request.action.historical_catalog.acquire.intent.digest());
    var encoded: [Selector.text_bytes]u8 = undefined;
    try t.expectEqualStrings(value.selector, try Selector.encode(value.snapshot, &encoded));
    try t.expectEqualDeep(value.snapshot, try Selector.decode(value.selector));
    // Reserved fields and old shorter records must fail
    // canonical decoding even when the source identity otherwise looks valid.
    var reserved = encoded;
    const offset: usize = if (value.snapshot.consistency == .common_transaction) 177 * 2 else 193 * 2;
    reserved[offset] = '1';
    try t.expectError(error.InvalidHistoricalSelector, Selector.decode(&reserved));
    try t.expectError(error.InvalidHistoricalSelector, Selector.decode(encoded[0..386]));
    var changed = value.request;
    changed.action.historical_catalog.acquire.intent.selection.count += 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
}

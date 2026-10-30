//! Private immutable work objects. The owning service must authorize staging
//! and admission; storage alone establishes neither authority nor acceptance.
const std = @import("std");
const c = @import("root.zig");
const I = c.DirectTableIntent;
const Objects = c.storage.TransitObjectStore;
fn key(reference: I.Reference, output: *[96]u8) ![]const u8 {
    try reference.validate();
    return std.fmt.bufPrint(output, "direct-intents/{x}.data", .{&reference.content.sha256});
}
pub fn stage(objects: Objects.ObjectStore, intent: *const I, namespace: u64) !I.Reference {
    const reference = try intent.reference(namespace);
    var name: [96]u8 = undefined;
    const stored = try objects.putImmutable(try key(reference, &name), intent.bytes, reference.content.sha256);
    if (stored.size != reference.content.bytes or !std.mem.eql(u8, &stored.sha256, &reference.content.sha256)) return error.InvalidTableIntent;
    return reference;
}
pub fn stageWithBinding(objects: Objects.ObjectStore, intent: *const I, namespace: u64, claim_binding: bool) !I.Reference {
    const reference = try intent.reference(namespace);
    if (!claim_binding) return stage(objects, intent, namespace);
    var binding_name: [96]u8 = undefined;
    const binding_key = try c.OperationBinding.key(reference.binding.identity, &binding_name);
    if (try objects.head(binding_key) != null) return stage(objects, intent, namespace);
    var intent_name: [96]u8 = undefined;
    const intent_key = try key(reference, &intent_name);
    var binding_buf: [c.OperationBinding.max_bytes]u8 = undefined;
    const encoded_binding = try c.OperationBinding.encodeData(reference.binding, &binding_buf);
    const puts = [2]Objects.ImmutablePut{
        .{ .key = intent_key, .bytes = intent.bytes, .sha256 = reference.content.sha256 },
        .{ .key = binding_key, .bytes = encoded_binding.bytes, .sha256 = encoded_binding.sha256 },
    };
    var metas: [2]Objects.ObjectMeta = undefined;
    try objects.putImmutableBatch(&puts, &metas);
    if (metas[0].size != reference.content.bytes or !std.mem.eql(u8, &metas[0].sha256, &reference.content.sha256)) return error.InvalidTableIntent;
    if (metas[1].size != encoded_binding.bytes.len or !std.mem.eql(u8, &metas[1].sha256, &encoded_binding.sha256)) return error.InvalidOperationBinding;
    return reference;
}
pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, reference: I.Reference) !I {
    var name: [96]u8 = undefined;
    const path = try key(reference, &name);
    const metadata = try objects.head(path) orelse return error.TableIntentMissing;
    if (metadata.size != reference.content.bytes or !std.mem.eql(u8, &metadata.sha256, &reference.content.sha256)) return error.InvalidTableIntent;
    const bytes = try allocator.alloc(u8, @intCast(reference.content.bytes));
    defer allocator.free(bytes);
    if ((try objects.getRange(path, 0, @intCast(bytes.len), bytes)).len != bytes.len) return error.InvalidTableIntent;
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &hash, .{});
    if (!std.mem.eql(u8, &hash, &reference.content.sha256)) return error.InvalidTableIntent;
    var intent = try I.restore(allocator, bytes);
    errdefer intent.deinit();
    try reference.requireSame(try intent.reference(reference.namespace));
    return intent;
}

//! Generic immutable bytes and bounded publication batches. Logical digests do
//! not contain provider coordinates. Visibility belongs to the resource turn.
const std = @import("std");
const p = @import("root.zig");
pub const max_records = 16;
pub const max_block_bytes = 64 * 1024;
pub const max_batch_bytes = 128 * 1024;
pub const digest_domain = "transit.immutable.block.v1\x00";

pub const Spec = struct {
    bytes: u32,
    digest: [32]u8,
    pub fn of(bytes: []const u8) !Spec {
        if (bytes.len > max_block_bytes) return error.BlockTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update(digest_domain);
        hash.update(bytes);
        return .{ .bytes = @intCast(bytes.len), .digest = hash.finalResult() };
    }
    pub fn validate(self: Spec) !void {
        if (self.bytes > max_block_bytes) return error.BlockTooLarge;
    }
    pub fn verify(self: Spec, bytes: []const u8) !void {
        try self.validate();
        if (bytes.len != self.bytes or !std.meta.eql(self, try of(bytes))) return error.CorruptBlock;
    }
};
pub const Mutation = struct { key: p.Value, value: ?Spec };
pub const Mutations = [max_records]?Mutation;
pub const Entry = struct { key: p.Value, value: Spec, revision: u64 };

/// One owned body for the entire batch, including after parser disposal or an
/// uncertain reply. No allocation depends on a retained collection's size.
/// JSON uses canonical padded base64; the descriptors bind the decoded bytes.
pub const Body = struct {
    len: u32 = 0,
    data: [max_batch_bytes]u8 = @splat(0),
    pub const max_encoded_bytes = std.base64.standard.Encoder.calcSize(max_batch_bytes);
    pub fn slice(self: *const Body) []const u8 {
        return self.data[0..self.len];
    }
    pub fn validate(self: *const Body) !void {
        if (self.len > max_batch_bytes or !std.mem.allEqual(u8, self.data[self.len..], 0)) return error.InvalidBlockBody;
    }
    pub fn jsonSchema(out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.write(.{
            .type = "string",
            .maxLength = max_encoded_bytes,
            .contentEncoding = "base64",
            .pattern = "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/][AQgw]==|[A-Za-z0-9+/]{2}[AEIMQUYcgkosw048]=)?$",
        });
    }
    pub fn jsonStringify(self: Body, out: *std.json.Stringify) std.Io.Writer.Error!void {
        self.validate() catch return error.WriteFailed;
        var buffer: [max_encoded_bytes]u8 = undefined;
        try out.write(std.base64.standard.Encoder.encode(&buffer, self.slice()));
    }
    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !Body {
        return fromText(try std.json.innerParse([]const u8, allocator, source, options)) catch return error.InvalidCharacter;
    }
    pub fn jsonParseFromValue(_: std.mem.Allocator, value: std.json.Value, _: std.json.ParseOptions) !Body {
        return switch (value) {
            .string => |text| fromText(text) catch return error.InvalidCharacter,
            else => error.UnexpectedToken,
        };
    }
    fn fromText(text: []const u8) !Body {
        if (text.len > max_encoded_bytes) return error.InvalidBlockBody;
        const size = std.base64.standard.Decoder.calcSizeForSlice(text) catch return error.InvalidBlockBody;
        if (size > max_batch_bytes) return error.InvalidBlockBody;
        var result: Body = .{ .len = @intCast(size) };
        std.base64.standard.Decoder.decode(result.data[0..size], text) catch return error.InvalidBlockBody;
        var buffer: [max_encoded_bytes]u8 = undefined;
        if (!std.mem.eql(u8, text, std.base64.standard.Encoder.encode(&buffer, result.slice()))) return error.InvalidBlockBody;
        return result;
    }
};

/// Validate descriptors without requiring bytes, so an already accepted exact
/// identity can reconcile its receipt without a fresh physical write.
pub fn validate(mutations: Mutations) !usize {
    var total: usize = 0;
    var ended = false;
    for (mutations, 0..) |slot, i| {
        const mutation = slot orelse {
            ended = true;
            continue;
        };
        if (ended) return error.InvalidBlockBatch;
        try p.State.key(mutation.key);
        for (mutations[0..i]) |previous| if (previous.?.key.eql(mutation.key)) return error.DuplicateBlockKey;
        if (mutation.value) |spec| {
            try spec.validate();
            total += spec.bytes;
            if (total > max_batch_bytes) return error.BlockBatchTooLarge;
        }
    }
    return total;
}
/// Verify the complete body before any candidate is staged. Deletes consume a
/// descriptor, but no body bytes. Missing/trailing/substituted bytes reject.
pub fn verify(mutations: Mutations, body: *const Body) !void {
    if (try validate(mutations) != body.len) return error.InvalidBlockBody;
    try body.validate();
    var offset: usize = 0;
    for (mutations) |slot| if (slot) |mutation| if (mutation.value) |spec| {
        try spec.verify(body.slice()[offset..][0..spec.bytes]);
        offset += spec.bytes;
    };
}

pub const Batch = struct {
    mutations: Mutations = @splat(null),
    body: Body = .{},
    /// An exact repeated private write shares its slot. Conflicting reuse must
    /// be resolved by the caller before constructing the publication proposal.
    pub fn put(self: *Batch, key: p.Value, bytes: ?[]const u8) !void {
        try p.State.key(key);
        const spec: ?Spec = if (bytes) |value| try Spec.of(value) else null;
        const selected = for (self.mutations, 0..) |slot, i| {
            const previous = slot orelse break i;
            if (previous.key.eql(key)) {
                if (!std.meta.eql(previous.value, spec)) return error.ConflictingBlockMutation;
                return;
            }
        } else return error.BlockBatchTooLarge;
        const length = if (bytes) |value| value.len else 0;
        if (self.body.len > max_batch_bytes or length > max_batch_bytes - self.body.len) return error.BlockBatchTooLarge;
        if (bytes) |value| @memcpy(self.body.data[self.body.len..][0..length], value);
        self.body.len += @intCast(length);
        self.mutations[selected] = .{ .key = key, .value = spec };
    }
};

test "bulk publication verifies every descriptor and owns canonical body bytes" {
    const t = std.testing;
    var batch: Batch = .{};
    try batch.put(try .init("binary"), &.{ 0, 255, 128 });
    try batch.put(try .init("empty"), "");
    try batch.put(try .init("deleted"), null);
    try batch.put(try .init("binary"), &.{ 0, 255, 128 });
    try verify(batch.mutations, &batch.body);
    try t.expectEqual(3, batch.body.len);
    // Independent hashlib SHA-256 vector: domain || 00 ff 80.
    try t.expectEqualStrings("bfe1ba4ab1f4f755de79b2375ea09a59c7bab2689b46b10745b8ec05729ec761", &std.fmt.bytesToHex(batch.mutations[0].?.value.?.digest, .lower));
    const text = try std.json.Stringify.valueAlloc(t.allocator, batch.body, .{});
    defer t.allocator.free(text);
    try t.expectEqualStrings("\"AP+A\"", text);
    var parsed = try std.json.parseFromSlice(Body, t.allocator, text, .{});
    var owned = parsed.value;
    parsed.deinit();
    try verify(batch.mutations, &owned);
    owned.data[2] ^= 1;
    try t.expectError(error.CorruptBlock, verify(batch.mutations, &owned));
    try t.expectError(error.ConflictingBlockMutation, batch.put(try .init("binary"), "different"));
    try verify(batch.mutations, &batch.body);
    for ([_][]const u8{ "A", "AA", "AB==", "AA===", "AA==\n", "-_==" }) |invalid| {
        try t.expectError(error.InvalidBlockBody, Body.fromText(invalid));
    }
}

test "bulk byte and operation bounds reject without partial private writes" {
    const t = std.testing;
    var batch: Batch = .{};
    const bytes: [max_block_bytes]u8 = @splat(7);
    try batch.put(try .init("first"), &bytes);
    try batch.put(try .init("second"), &bytes);
    try t.expectError(error.BlockBatchTooLarge, batch.put(try .init("third"), "x"));
    try t.expectEqual(null, batch.mutations[2]);
    try t.expectEqual(max_batch_bytes, batch.body.len);
    try verify(batch.mutations, &batch.body);
    for (2..max_records) |i| {
        var key: [8]u8 = undefined;
        std.mem.writeInt(u64, &key, i, .big);
        try batch.put(try .init(&key), null);
    }
    try t.expectError(error.BlockBatchTooLarge, batch.put(try .init("extra"), null));
    try verify(batch.mutations, &batch.body);
    batch.mutations[1] = batch.mutations[0];
    try t.expectError(error.DuplicateBlockKey, validate(batch.mutations));
    batch.mutations[0] = null;
    try t.expectError(error.InvalidBlockBatch, validate(batch.mutations));
}

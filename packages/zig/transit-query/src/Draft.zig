//! One explicit finite draft budget per requester generation. History is point
//! addressed; the eight slots bound an operation group, never total cardinality.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const Turn = q.station.Turn;
pub const max_starts = 8;
pub const Open = struct {
    expected: u64,
    limit: u8,
    contract: [32]u8,
    limits: q.Bundle.Limits,
    pub fn validate(self: Open) !void {
        if (self.expected == std.math.maxInt(u64) or self.limit == 0 or self.limit > max_starts) return error.InvalidQueryDraft;
        self.limits.validate() catch return error.InvalidQueryDraft;
    }
    pub fn write(self: Open, out: *std.Io.Writer) !void {
        try self.validate();
        try out.writeInt(u64, self.expected, .little);
        try out.writeByte(self.limit);
        try out.writeAll(&self.contract);
        inline for (.{ "pages", "segments", "result_bytes" }) |name| try out.writeInt(u64, @field(self.limits, name), .little);
    }
    pub fn read(input: *std.Io.Reader) !Open {
        var value: Open = .{ .expected = try input.takeInt(u64, .little), .limit = try input.takeByte(), .contract = undefined, .limits = undefined };
        @memcpy(&value.contract, try input.take(32));
        inline for (.{ "pages", "segments", "result_bytes" }) |name| @field(value.limits, name) = try input.takeInt(u64, .little);
        try value.validate();
        return value;
    }
};
pub const Selection = struct { generation: u64, namespace: u64 };
pub const Record = struct {
    generation: u64,
    open: Open,
    starts: u8 = 0,
    enabled: bool = true,
    namespaces: [max_starts]u64 = @splat(0),
    pub fn encode(self: Record) !p.Value {
        try self.open.validate();
        if (self.generation != self.open.expected + 1 or self.starts > self.open.limit) return error.InvalidQueryDraft;
        for (self.namespaces, 0..) |namespace, index| {
            if ((index < self.starts) != (namespace != 0)) return error.InvalidQueryDraft;
            if (namespace != 0) for (self.namespaces[0..index]) |prior| {
                if (prior == namespace) return error.InvalidQueryDraft;
            };
        }
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("UQD1");
        try out.writeInt(u64, self.generation, .little);
        try self.open.write(&out);
        try out.writeByte(self.starts);
        try out.writeByte(@intFromBool(self.enabled));
        for (self.namespaces) |namespace| try out.writeInt(u64, namespace, .little);
        return p.Value.init(out.buffered());
    }
    pub fn decode(value: p.Value) !Record {
        try value.validate();
        var input: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try input.take(4), "UQD1")) return error.InvalidQueryDraft;
        var result: Record = .{ .generation = try input.takeInt(u64, .little), .open = try Open.read(&input), .starts = try input.takeByte() };
        result.enabled = switch (try input.takeByte()) {
            0 => false,
            1 => true,
            else => return error.InvalidQueryDraft,
        };
        for (&result.namespaces) |*namespace| namespace.* = try input.takeInt(u64, .little);
        if (input.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidQueryDraft;
        return result;
    }
};
pub fn key(generation: u64) p.Value {
    return q.UnifiedRecords.key('D', generation, 0);
}
pub fn head(reader: anytype) !u64 {
    const value = (try reader.read(key(0))) orelse return 0;
    if (value.len != 8) return error.InvalidQueryDraftRecord;
    const generation = std.mem.readInt(u64, value.data[0..8], .little);
    if (generation == 0) return error.InvalidQueryDraftRecord;
    return generation;
}
pub fn status(reader: anytype, generation: u64) !?Record {
    if (generation == 0) return error.InvalidQueryDraft;
    const value = (try reader.read(key(generation))) orelse return null;
    const record = Record.decode(value) catch return error.InvalidQueryDraftRecord;
    if (record.generation != generation) return error.InvalidQueryDraftRecord;
    return record;
}
pub fn open(turn: *Turn, input: Open) !void {
    const before = turn.decision;
    errdefer turn.decision = before;
    try input.validate();
    const generation = input.expected + 1;
    if (try status(turn, generation)) |record| {
        if (!std.meta.eql(record.open, input)) return error.QueryDraftConflict;
        return;
    }
    if (try head(turn) != input.expected) return error.QueryDraftConflict;
    if (input.expected != 0) {
        const previous = (try status(turn, input.expected)) orelse return error.InvalidQueryDraftRecord;
        if (previous.enabled and previous.starts < previous.open.limit) return error.QueryDraftActive;
    }
    try turn.write(key(generation), try (Record{ .generation = generation, .open = input }).encode());
    try turn.write(key(0), q.UnifiedRecords.identityValue(generation));
}
pub fn close(turn: *Turn, generation: u64) !void {
    var record = (try status(turn, generation)) orelse return error.QueryDraftNotFound;
    if (!record.enabled) return;
    record.enabled = false;
    try turn.write(key(generation), try record.encode());
}
pub fn submit(turn: *Turn, selected: Selection, destination: u64, observer: ?u64) !u64 {
    const before = turn.decision;
    errdefer turn.decision = before;
    if (selected.namespace == 0) return error.InvalidQueryDraft;
    var record = (try status(turn, selected.generation)) orelse return error.QueryDraftNotFound;
    const current = (try q.UnifiedUpload.status(turn, selected.namespace)) orelse return error.QueryUploadNotFound;
    for (record.namespaces[0..record.starts]) |namespace| if (namespace == selected.namespace) {
        if (current.correlation == 0) return error.InvalidQueryDraftRecord;
        return current.correlation;
    };
    if (try head(turn) != selected.generation or !record.enabled) return error.QueryDraftClosed;
    if (record.starts == record.open.limit) return error.QueryDraftExhausted;
    if (current.correlation != 0 or current.phase != .sealed) return error.QueryDraftConflict;
    // Verify the immutable request in bounded caller-owned memory. Reads remain
    // on the original turn so native read poison cannot be hidden by a copy.
    var bytes: [q.Bundle.max_bytes]u8 = undefined;
    var used: usize = 0;
    try q.Bundle.checkReference(current.reference);
    var cursor = try current.reference.publication().open(turn, current.reference.record);
    if (!std.meta.eql(cursor.spec, current.reference.spec)) return error.PublicationReferenceChanged;
    while (true) {
        const part = try current.reference.publication().read(turn, cursor);
        if (part.bytes.len > bytes.len - used) return error.InvalidQueryDraft;
        @memcpy(bytes[used..][0..part.bytes.len], part.bytes.slice());
        used += part.bytes.len;
        cursor = part.next orelse break;
    }
    var memory: [64 * 1024]u8 = undefined;
    var fixed: std.heap.FixedBufferAllocator = .init(&memory);
    const bundle = q.Bundle.decode(fixed.allocator(), bytes[0..used]) catch |err| return if (err == error.OutOfMemory) err else error.InvalidQueryDraft;
    if (!std.mem.eql(u8, &try bundle.source.fingerprint(), &record.open.contract)) return error.QueryDraftConflict;
    if (!record.open.limits.permits(bundle.limits)) return error.QueryBudgetExceeded;
    const correlation = try q.UnifiedUpload.submitWithObserver(turn, selected.namespace, destination, observer);
    record.namespaces[record.starts] = selected.namespace;
    record.starts += 1;
    try turn.write(key(selected.generation), try record.encode());
    return correlation;
}

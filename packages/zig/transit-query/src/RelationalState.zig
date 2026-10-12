//! Immutable relational operator records over Station Publication. A candidate
//! is private and bounded by tree height. Its host atomically publishes the
//! checkpoint reference and allocation counters with input/output progress.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const Index = f.RelationalIndex;
const Pub = q.station.Publication;
const Turn = q.station.Turn;
const Self = @This();
pub const node_format: u32 = 0x314e5246;
pub const checkpoint_format: u32 = 0x31435246;
pub const max_record_bytes = @max(Index.max_record_bytes, f.RelationalCheckpoint.max_bytes);
publication: Pub,

pub fn create(turn: *Turn, namespace: u64) !Self {
    return .{ .publication = try Pub.create(turn, .query_result, namespace, .{ .record_bytes = max_record_bytes, .staging_bytes = max_record_bytes, .staging_records = 1 }) };
}
fn check(self: Self) !void {
    if (self.publication.domain != .query_result or self.publication.resource == 0 or self.publication.namespace == 0) return error.InvalidRelationalState;
}
/// Reads one exact record through a public captured/retained resource reader.
/// Group identity/digest/basis validation is performed by Fuze after this read.
pub fn read(self: Self, source: anytype, id: u64, format: u32, output: []u8) ![]const u8 {
    try self.check();
    if (id == 0 or source.view.resource != self.publication.resource) return error.InvalidRelationalState;
    var cursor = try self.publication.open(source, id);
    if (cursor.spec.format != format or cursor.spec.length == 0 or cursor.spec.length > max_record_bytes or cursor.spec.length > output.len) return error.InvalidRelationalState;
    const length = cursor.spec.length;
    var at: usize = 0;
    while (true) {
        const part = try self.publication.read(source, cursor);
        if (part.bytes.len > length - at) return error.InvalidRelationalState;
        @memcpy(output[at..][0..part.bytes.len], part.bytes.slice());
        at += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (at != length) return error.InvalidRelationalState;
    return output[0..at];
}
pub fn stageCheckpoint(self: Self, turn: *Turn, id: u64, bound: r.Bound, saved: f.RelationalCheckpoint) !bool {
    try self.check();
    var bytes: [f.RelationalCheckpoint.max_bytes]u8 = undefined;
    const body = try saved.encode(bound, &bytes);
    return self.publication.stage(turn, id, try Pub.Digest.of(checkpoint_format, body), body);
}
pub fn checkpoint(self: Self, source: anytype, id: u64, bound: r.Bound) !f.RelationalCheckpoint {
    var bytes: [f.RelationalCheckpoint.max_bytes]u8 = undefined;
    return f.RelationalCheckpoint.decode(bound, try self.read(source, id, checkpoint_format, &bytes));
}
pub fn Candidate(comptime Source: type) type {
    return struct {
        const C = @This();
        const Record = struct { len: u16, bytes: [Index.max_record_bytes]u8 };
        pages: Self,
        source: Source,
        first: u64,
        previous_bytes: u64,
        quota: u64,
        work_limit: u64,
        work: u64 = 0,
        count: u16 = 0,
        bytes: u64 = 0,
        records: [Index.max_candidate_records]Record = undefined,
        pub const resident_bytes = @sizeOf(C) + Index.resident_bytes;
        pub fn init(pages: Self, source: Source, first: u64, previous_bytes: u64, bound: r.Bound, work_limit: u64) !C {
            try pages.check();
            try bound.validate();
            if (bound.plan.lifetime == .interactive or first == 0 or work_limit == 0 or source.view.resource != pages.publication.resource) return error.InvalidRelationalState;
            if (previous_bytes > bound.plan.budgets.spill_bytes) return error.RelationalSpillBudget;
            if (bound.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
            return .{ .pages = pages, .source = source, .first = first, .previous_bytes = previous_bytes, .quota = bound.plan.budgets.spill_bytes, .work_limit = work_limit };
        }
        fn charge(self: *C) !void {
            if (self.work == self.work_limit) return error.RelationalWorkBudget;
            self.work += 1;
        }
        pub fn read(self: *C, id: u64, output: []u8) ![]const u8 {
            try self.charge();
            if (id >= self.first) {
                const offset = id - self.first;
                if (offset >= self.count) return error.InvalidRelationalState;
                const record = &self.records[@intCast(offset)];
                if (output.len < record.len) return error.InvalidRelationalState;
                @memcpy(output[0..record.len], record.bytes[0..record.len]);
                return output[0..record.len];
            }
            return self.pages.read(self.source, id, node_format, output);
        }
        pub fn save(self: *C, bytes: []const u8) !u64 {
            try self.charge();
            if (bytes.len == 0 or bytes.len > Index.max_record_bytes or self.count == self.records.len) return error.InvalidRelationalState;
            if (bytes.len > self.quota - self.previous_bytes - self.bytes) return error.RelationalSpillBudget;
            const id = std.math.add(u64, self.first, self.count) catch return error.InvalidRelationalState;
            // Always leave an identity for the checkpoint following the nodes.
            if (id == std.math.maxInt(u64)) return error.InvalidRelationalState;
            const record = &self.records[self.count];
            record.len = @intCast(bytes.len);
            @memcpy(record.bytes[0..bytes.len], bytes);
            self.bytes += bytes.len;
            self.count += 1;
            return id;
        }
        /// Deterministic reconstruction always uses the same first ID and exact
        /// candidate bytes. Reopening staging records cannot reinterpret them.
        /// Returns false after bounded private staging; the caller commits that
        /// progress and its continuation without changing the accepted root.
        pub fn stage(self: *C, turn: *Turn) !bool {
            const before = turn.decision;
            errdefer turn.decision = before;
            for (self.records[0..self.count], 0..) |record, i| {
                const body = record.bytes[0..record.len];
                const ready = self.pages.publication.stage(turn, self.first + i, try Pub.Digest.of(node_format, body), body) catch |err| {
                    if (err == error.MutationBudgetExceeded and !std.meta.eql(before.mutations, turn.decision.mutations)) return false;
                    return err;
                };
                if (!ready) return false;
            }
            return true;
        }
        pub fn checkpointId(self: C) !u64 {
            return std.math.add(u64, self.first, self.count);
        }
        /// Total retained logical record bytes, including older COW versions;
        /// Publication additionally enforces the active staging reservation.
        /// Nothing here expires old records or invents a retention opt-in.
        pub fn retainedBytes(self: C, checkpoint_bytes: usize) !u64 {
            if (checkpoint_bytes > self.quota - self.previous_bytes - self.bytes) return error.RelationalSpillBudget;
            return self.previous_bytes + self.bytes + checkpoint_bytes;
        }
    };
}

test {
    _ = @import("relational_state_test.zig");
}

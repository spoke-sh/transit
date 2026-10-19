//! Resource-owned immutable block indexes. Publication returns a private root;
//! only the containing authority turn can install it and grant visibility.
const std = @import("std");
const core = @import("root.zig");
const p = core.protocol;
const b = p.Blocks;
const c = core.catalog;
const pages = core.pages;
pub const Reference = struct { value: b.Spec, location: [32]u8 };
pub const Record = struct { key: p.Value, reference: Reference, revision: u64 };
pub const Snapshot = c.Snapshot;

fn address(key: p.Value) !pages.Key {
    try p.State.key(key);
    // The owning resource supplies the root, never a provider namespace. Keys
    // cannot escape that root or grant access to another resource's block.
    return c.key(.entry, 0, 0, key.slice());
}
fn public(record: Record) b.Entry {
    return .{ .key = record.key, .value = record.reference.value, .revision = record.revision };
}
pub fn Index(comptime Store: type) type {
    return struct {
        const Self = @This();
        store: *Store,

        /// Store.stageBlock owns durable byte verification. The descriptor and
        /// complete body are checked before the first write, and no candidate
        /// root escapes after any partial/lost staging acknowledgement.
        pub fn publish(self: Self, basis: Snapshot, mutations: b.Mutations, body: *const b.Body, revision: u64) !Snapshot {
            if (revision == 0 or revision > p.max_counter) return error.InvalidPosition;
            try b.verify(mutations, body);
            var candidate = try c.Catalog(Store).open(self.store, basis);
            var pending: c.Candidate = .{};
            candidate.pending = &pending;
            var offset: usize = 0;
            for (mutations) |slot| if (slot) |mutation| {
                const key = try address(mutation.key);
                if (mutation.value) |spec| {
                    const reference = try self.store.stageBlock(spec, body.slice()[offset..][0..spec.bytes]);
                    if (!std.meta.eql(reference.value, spec)) return error.CorruptBlock;
                    offset += spec.bytes;
                    try candidate.put(key, Record{ .key = mutation.key, .reference = reference, .revision = revision });
                } else try candidate.mutate(&.{.{ .key = key, .value = null }});
            };
            try candidate.flush();
            if (candidate.snapshot.records > p.max_counter) return error.Overflow;
            return candidate.snapshot;
        }

        /// The host authorizes the captured resource before calling and
        /// revalidates current authority before disclosing the completed body.
        /// Metadata-only reads do not acquire an implicit permission cache.
        pub fn read(self: Self, basis: Snapshot, keys: [p.Growth.page_size]?p.Value, body: ?*b.Body) ![p.Growth.page_size]?b.Entry {
            if (body) |output| output.* = .{};
            errdefer if (body) |output| {
                output.* = .{};
            };
            const catalog = try c.Catalog(Store).open(self.store, basis);
            var addresses: [p.Growth.page_size]pages.Key = undefined;
            var count: usize = 0;
            for (keys) |key| if (key) |value| {
                addresses[count] = try address(value);
                count += 1;
            };
            const records = try catalog.getMany(Record, addresses[0..count]);
            var total: usize = 0;
            for (records[0..count]) |slot| if (slot) |record| {
                try record.reference.value.validate();
                total += record.reference.value.bytes;
                if (body != null and total > b.max_batch_bytes) return error.BlockBatchTooLarge;
            };
            var result: [p.Growth.page_size]?b.Entry = @splat(null);
            var record_index: usize = 0;
            var offset: usize = 0;
            for (keys, 0..) |key, i| if (key) |value| {
                defer record_index += 1;
                const record = records[record_index] orelse continue;
                if (!record.key.eql(value) or record.revision == 0 or record.revision > p.max_counter) return error.InvalidHistory;
                if (body) |output| {
                    const size = record.reference.value.bytes;
                    const acquired = try self.store.loadBlock(record.reference, output.data[offset..][0..size]);
                    try record.reference.value.verify(acquired);
                    offset += size;
                }
                result[i] = public(record);
            };
            if (body) |output| output.len = @intCast(offset);
            return result;
        }

        pub fn scan(self: Self, basis: Snapshot, after: ?p.Value) !p.Growth.Batch(b.Entry, p.Value) {
            const catalog = try c.Catalog(Store).open(self.store, basis);
            const page = try catalog.scan(Record, .{ .namespace = .entry, .major = 0, .minor = 0 }, if (after) |key| try address(key) else null);
            var result: p.Growth.Batch(b.Entry, p.Value) = .{};
            for (page.records, 0..) |slot, i| if (slot) |record| {
                if (!std.mem.eql(u8, record.key.slice()[17..], record.value.key.slice())) return error.InvalidHistory;
                if (record.value.revision == 0 or record.value.revision > p.max_counter) return error.InvalidHistory;
                try record.value.reference.value.validate();
                result.entries[i] = public(record.value);
            };
            if (page.next) |key| result.next = try p.Value.init(key.slice()[17..]);
            return result;
        }
    };
}

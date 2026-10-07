//! A bounded private overlay for point or finite statement work. Intermediate index paths never
//! need durable publication. IDs come from the owner's reserved interval.
const std = @import("std");
const f = @import("transit_fuze");
const Data = @import("TableData.zig");
const Index = @import("ImmutableIndex.zig");
const Pub = @import("Publication.zig");

// A key-changing UPDATE performs at most three index edits, each saving at most
// two nodes per level and one new root. The same record/byte budget also admits
// a finite INSERT batch; it never grows with the number of statement rows.
pub const max_nodes = 3 * (2 * (Index.max_level + 1) + 1);
pub const max_records = max_nodes + 1;
pub const max_bytes = max_nodes * Index.node_bytes + f.TableRow.max_bytes;
pub const Record = struct { id: u64, spec: Pub.Spec, bytes: []const u8, reachable: bool = false };

pub fn Overlay(comptime Source: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        source: Source,
        first: u64,
        end: u64,
        records: std.ArrayList(Record) = .empty,
        bytes: usize = 0,
        sealed: bool = false,

        pub fn init(allocator: std.mem.Allocator, source: Source, first: u64, end: u64) !Self {
            if (first == 0 or end <= first) return error.InvalidTableReservation;
            return .{ .allocator = allocator, .source = source, .first = first, .end = end };
        }
        pub fn deinit(self: *Self) void {
            for (self.records.items) |record| self.allocator.free(record.bytes);
            self.records.deinit(self.allocator);
        }
        pub fn nextId(self: Self) u64 {
            return self.first + @as(u64, @intCast(self.records.items.len));
        }
        /// Roll back an unsealed, unstaged attempt at the next batch row. The
        /// caller keeps its previous root; these private IDs have never escaped.
        pub fn discardAfter(self: *Self, count: usize) void {
            std.debug.assert(!self.sealed and count <= self.records.items.len);
            for (self.records.items[count..]) |record| {
                self.bytes -= record.bytes.len;
                self.allocator.free(record.bytes);
            }
            self.records.shrinkRetainingCapacity(count);
        }
        fn local(self: *Self, id: u64, spec: Pub.Spec, output: []u8) !?[]const u8 {
            if (id < self.first) return null;
            if (id >= self.nextId()) return error.InvalidTableCandidate;
            const record = self.records.items[@intCast(id - self.first)];
            if (!std.meta.eql(spec, record.spec) or record.bytes.len > output.len) return error.InvalidTableCandidate;
            @memcpy(output[0..record.bytes.len], record.bytes);
            return output[0..record.bytes.len];
        }
        pub fn load(self: *Self, ref: Index.Reference, output: []u8) ![]const u8 {
            return (try self.local(ref.id, ref.spec, output)) orelse try self.source.load(ref, output);
        }
        pub fn loadBlob(self: *Self, ref: Data.Blob, output: []u8) ![]const u8 {
            return (try self.local(ref.id, ref.spec, output)) orelse try self.source.loadBlob(ref, output);
        }
        fn append(self: *Self, spec: Pub.Spec, bytes: []const u8) !u64 {
            if (self.sealed) return error.TableCandidateSealed;
            if (self.records.items.len == max_records or self.nextId() == self.end or bytes.len > max_bytes - self.bytes) return error.TableCandidateCapacity;
            if (!std.meta.eql(try Pub.Digest.of(spec.format, bytes), spec)) return error.InvalidTableCandidate;
            const owned = try self.allocator.dupe(u8, bytes);
            errdefer self.allocator.free(owned);
            const id = self.nextId();
            try self.records.append(self.allocator, .{ .id = id, .spec = spec, .bytes = owned });
            self.bytes += bytes.len;
            return id;
        }
        pub fn save(self: *Self, spec: Pub.Spec, bytes: []const u8) !u64 {
            if (spec.format != Index.format or bytes.len > Index.node_bytes) return error.InvalidTableCandidate;
            return self.append(spec, bytes);
        }
        pub fn saveBlob(self: *Self, spec: Pub.Spec, bytes: []const u8) !u64 {
            if (spec.format != Data.row_format or bytes.len > f.TableRow.max_bytes) return error.InvalidTableCandidate;
            return self.append(spec, bytes);
        }
        fn markBlob(self: *Self, blob: Data.Blob, parent: u64) !void {
            if (blob.id < self.first) return;
            if (blob.id >= parent or blob.id >= self.nextId()) return error.InvalidTableCandidate;
            const record = &self.records.items[@intCast(blob.id - self.first)];
            if (!std.meta.eql(record.spec, blob.spec)) return error.InvalidTableCandidate;
            record.reachable = true;
        }
        fn mark(self: *Self, ref: Index.Reference) anyerror!void {
            if (ref.id < self.first) return;
            if (ref.id >= self.nextId()) return error.InvalidTableCandidate;
            const record = &self.records.items[@intCast(ref.id - self.first)];
            if (!std.meta.eql(record.spec, ref.spec)) return error.InvalidTableCandidate;
            const node = try Index.inspect(self, ref);
            record.reachable = true;
            if (node.level == 0) {
                for (node.items.leaves[0..node.used]) |entry| {
                    if (entry.key.data[0] == 'R') {
                        if (entry.key.len != 21) return error.InvalidTableCandidate;
                        try self.markBlob(try Data.Blob.decode(entry.value), ref.id);
                    } else if (entry.key.data[0] != 'K' or entry.key.len != 53 or entry.value.len != 0) return error.InvalidTableCandidate;
                }
            } else for (node.items.branches[0..node.used]) |child| {
                if (child.id >= ref.id) return error.InvalidTableCandidate;
                try self.mark(child);
            }
        }
        /// Seal before staging. Only reachable records may be written; reserved
        /// IDs of discarded paths remain consumed. No publication occurs here.
        pub fn finish(self: *Self, index: Index) !usize {
            if (self.sealed) return error.TableCandidateSealed;
            for (self.records.items) |*record| record.reachable = false;
            if (index.root) |root| try self.mark(root);
            self.sealed = true;
            var count: usize = 0;
            for (self.records.items) |record| count += @intFromBool(record.reachable);
            return count;
        }
    };
}

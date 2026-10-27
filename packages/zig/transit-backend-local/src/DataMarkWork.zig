//! Private paged marks and pending graph work. The collection checkpoint, not
//! an immutable staging call, publishes these roots and progress counters.
const std = @import("std");
const core = @import("transit_core");
const storage = @import("transit_storage");
const pages = storage.TreeStore.pages;
const Objects = storage.TransitObjectStore;
const d = core.protocol.DataLifecycle;
const header_bytes = 40;
pub const max_work_bytes = 128 * 1024;

pub const State = struct {
    marks: ?pages.Reference = null,
    scopes: ?pages.Reference = null,
    queue: ?pages.Reference = null,
    cursor: u64 = 0,
    tail: u64 = 0,

    pub fn validate(self: State) !void {
        if (self.cursor > self.tail or (self.cursor == self.tail) != (self.queue == null)) return error.InvalidStorageCollection;
    }
};

fn key(digest: [32]u8) !pages.Key {
    return pages.Key.init(&digest);
}
fn position(value: u64) !pages.Key {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .big);
    return pages.Key.init(&bytes);
}
pub fn objectKey(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    return std.fmt.bufPrint(output, "data-maintenance/{x}.work", .{&content.sha256});
}
fn hash(bytes: []const u8) [32]u8 {
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &result, .{});
    return result;
}
fn encodedMetadata(meta: Objects.ObjectMeta) !pages.Value {
    var bytes: [40]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], meta.size, .little);
    bytes[8..40].* = meta.sha256;
    return pages.Value.init(&bytes);
}
fn metadata(encoded: pages.Value) !Objects.ObjectMeta {
    if (encoded.len != 40) return error.InvalidStorageGraph;
    return .{ .size = std.mem.readInt(u64, encoded.data[0..8], .little), .sha256 = encoded.data[8..40].* };
}

/// Work must own every field: JSON's temporary decoding arena is released
/// before returning it. Both private roots and a caller's active work item must
/// publish in the same checkpoint. Discard State on any failed step.
pub fn Workspace(comptime Work: type) type {
    return struct {
        const Self = @This();
        state: *State,
        index: *storage.TreeStore,

        fn tree(self: *Self) pages.Tree(storage.TreeStore) {
            return .{ .store = self.index };
        }

        /// True means this exact typed scope already has durable pending or
        /// completed work in this checkpoint's graph. Physical marks are separate.
        pub fn visited(self: *Self, scope: [32]u8) !bool {
            const identity = try key(scope);
            if (try self.tree().get(self.state.scopes, identity)) |known| {
                if (known.len != 0) return error.InvalidStorageGraph;
                return true;
            }
            self.state.scopes = try self.tree().put(self.state.scopes, identity, try pages.Value.init(&.{}));
            return false;
        }

        pub fn mark(self: *Self, object_key: []const u8, expected: Objects.ObjectMeta) !void {
            try @import("Backend.zig").dataKey(object_key);
            const identity = try key(hash(object_key));
            if (try self.tree().get(self.state.marks, identity)) |known| {
                if (!std.meta.eql(try metadata(known), expected)) return error.InvalidStorageGraph;
                return;
            }
            const actual = try self.index.store.head(object_key) orelse return error.ObjectNotFound;
            if (!std.meta.eql(actual, expected)) return error.InvalidStorageGraph;
            self.state.marks = try self.tree().put(self.state.marks, identity, try encodedMetadata(actual));
        }

        pub fn marked(self: *Self, object_key: []const u8, expected: Objects.ObjectMeta) !bool {
            const known = try self.tree().get(self.state.marks, try key(hash(object_key))) orelse return false;
            if (!std.meta.eql(try metadata(known), expected)) return error.InvalidStorageGraph;
            return true;
        }

        pub fn enqueue(self: *Self, work: Work) !void {
            try self.state.validate();
            const successor = try std.math.add(u64, self.state.tail, 1);
            var bytes: [max_work_bytes]u8 = undefined;
            bytes[0..8].* = "TDWORK1\x00".*;
            bytes[8..40].* = core.protocol.Growth.definition_bytes;
            var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
            std.json.Stringify.value(work, .{}, &writer) catch return error.StorageMaintenanceBudget;
            const encoded = bytes[0 .. header_bytes + writer.end];
            const content: d.Content = .{ .bytes = encoded.len, .sha256 = hash(encoded) };
            var name: [96]u8 = undefined;
            const actual = try self.index.store.putImmutable(try objectKey(content, &name), encoded, content.sha256);
            if (actual.size != content.bytes or !std.mem.eql(u8, &actual.sha256, &content.sha256)) return error.InvalidStorageGraph;
            self.state.queue = try self.tree().put(self.state.queue, try position(self.state.tail), try encodedMetadata(actual));
            self.state.tail = successor;
        }

        pub fn take(self: *Self, allocator: std.mem.Allocator) !?Work {
            try self.state.validate();
            if (self.state.cursor == self.state.tail) return null;
            const identity = try position(self.state.cursor);
            const entry = try self.tree().get(self.state.queue, identity) orelse return error.InvalidStorageGraph;
            const meta = try metadata(entry);
            if (meta.size <= header_bytes or meta.size > max_work_bytes) return error.InvalidStorageGraph;
            var name: [96]u8 = undefined;
            const object_key = try objectKey(.{ .bytes = meta.size, .sha256 = meta.sha256 }, &name);
            const actual = try self.index.store.head(object_key) orelse return error.ObjectNotFound;
            if (!std.meta.eql(actual, meta)) return error.InvalidStorageGraph;
            const bytes = try allocator.alloc(u8, @intCast(meta.size));
            defer allocator.free(bytes);
            const encoded = try self.index.store.getRange(object_key, 0, @intCast(meta.size), bytes);
            if (encoded.len != meta.size or !std.mem.eql(u8, &hash(encoded), &meta.sha256) or
                !std.mem.eql(u8, encoded[0..8], "TDWORK1\x00")) return error.InvalidStorageGraph;
            if (!std.mem.eql(u8, encoded[8..40], &core.protocol.Growth.definition_bytes)) return error.IncompatibleDefinition;
            const parsed = try std.json.parseFromSlice(Work, allocator, encoded[header_bytes..], .{});
            defer parsed.deinit();
            const queue = try self.tree().remove(self.state.queue, identity);
            self.state.queue = queue;
            self.state.cursor += 1;
            return parsed.value;
        }
    };
}

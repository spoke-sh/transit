//! Isolated structural experiment, not a native storage profile or disk benchmark.
const std = @import("std");
const p = @import("pages");
const Store = struct {
    allocator: std.mem.Allocator,
    pages: std.AutoHashMapUnmanaged(p.Reference, p.Page) = .empty,
    reads: u64 = 0,
    writes: u64 = 0,
    bytes: u64 = 0,
    pub fn load(self: *@This(), reference: p.Reference) !p.Page {
        self.reads += 1;
        return self.pages.get(reference) orelse error.MissingPage;
    }
    pub fn stage(self: *@This(), reference: p.Reference, page: *const p.Page) !p.Reference {
        var bytes: [p.max_encoded_bytes]u8 = undefined;
        const encoded = try page.encode(&bytes);
        // Exercise actual codecs and independently owned decoded values at
        // every page, including full reference/locator and retained roots.
        const decoded = try p.Page.decode(self.allocator, encoded);
        if (!std.meta.eql(page.*, decoded)) return error.CodecMismatch;
        self.writes += 1;
        self.bytes += encoded.len;
        var located = reference;
        std.mem.writeInt(u64, located.location[0..8], self.writes, .little);
        try self.pages.put(self.allocator, located, decoded);
        return located;
    }
};
fn key(namespace: u8, id: u64) p.Key {
    var bytes: [17]u8 = @splat(0);
    bytes[0] = namespace;
    std.mem.writeInt(u64, bytes[1..9], 1, .big);
    std.mem.writeInt(u64, bytes[9..17], id, .big);
    return p.Key.init(&bytes) catch unreachable;
}
fn value(id: u64) !p.Value {
    var bytes: [160]u8 = @splat('a');
    std.mem.writeInt(u64, bytes[0..8], id, .little);
    return p.Value.init(&bytes);
}
fn run(init: std.process.Init, rows: usize, split: bool) !void {
    var store: Store = .{ .allocator = init.gpa };
    defer store.pages.deinit(init.gpa);
    const tree: p.BoundedTree(Store, 16) = .{ .store = &store };
    var control: ?p.Reference = null;
    var data: ?p.Reference = null;
    // Equal row/history populations in each geometry. No provider, permission
    // cache or durable acceptance cost is represented by this structural model.
    for (0..rows) |i| {
        control = try tree.put(control, key(6, i), try value(i));
        if (split) data = try tree.put(data, key(17, i), try value(i)) else control = try tree.put(control, key(17, i), try value(i));
    }
    for ([_]u8{ 1, 2, 3, 5, 30, 31 }) |namespace| control = try tree.put(control, key(namespace, 1), try value(1));
    const old_control = control;
    const old_data = if (split) data else control;
    const before = .{ store.reads, store.writes, store.bytes };
    for (0..50) |i| {
        var changes: [10]p.Mutation = undefined;
        var count: usize = 0;
        for ([_]u8{ 1, 2, 3, 5, 30, 31 }) |namespace| {
            changes[count] = .{ .key = key(namespace, 1), .value = if (namespace >= 30) null else try value(i + 2) };
            count += 1;
        }
        changes[count] = .{ .key = key(6, rows + i), .value = try value(i) };
        count += 1;
        const row: p.Mutation = .{ .key = key(17, i % rows), .value = try value(10000 + i) };
        const outcome: p.Mutation = .{ .key = key(17, rows + i), .value = try value(i) };
        if (split) {
            data = try tree.mutate(data, &.{ row, outcome });
            var root_bytes: [512]u8 = undefined;
            var writer: std.Io.Writer = .fixed(&root_bytes);
            try std.json.Stringify.value(data, .{}, &writer);
            changes[2].value = try p.Value.init(writer.buffered());
        } else {
            changes[count] = row;
            changes[count + 1] = outcome;
            count += 2;
        }
        control = try tree.mutate(control, changes[0..count]);
    }
    const measured = .{ .reads = store.reads - before[0], .stages = store.writes - before[1], .encoded_bytes = store.bytes - before[2] };
    if (!std.meta.eql(try value(0), (try tree.get(old_data, key(17, 0))).?)) return error.RetainedRootChanged;
    if (!std.meta.eql(try value(10000), (try tree.get(if (split) data else control, key(17, 0))).?)) return error.NewRootMissing;
    if (!std.meta.eql(try value(1), (try tree.get(old_control, key(1, 1))).?)) return error.ControlRootChanged;
    var output = std.Io.File.stdout().writerStreaming(init.io, &.{});
    try std.json.Stringify.value(.{ .rows = rows, .retained_receipts = rows, .turns = 50, .split_roots = split, .leaf_entries = p.leaf_entries, .branch_children = p.branch_children, .resident_page_bytes = @sizeOf(p.Page), .work = measured }, .{}, &output.interface);
    try output.interface.writeByte('\n');
}
pub fn main(init: std.process.Init) !void {
    for ([_]usize{ 64, 1024 }) |rows| for ([_]bool{ false, true }) |split| try run(init, rows, split);
}

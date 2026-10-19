//! Bounded relocation of current immutable ownership. Old published roots keep
//! their bytes until history/pin release and a subsequent verified collection.
const std = @import("std");
const core = @import("root.zig");
const c = core.catalog;
pub const Cursor = struct {
    phase: enum { resources, blocks, catalog, policy, complete } = .resources,
    resource: u64 = 0,
    after: ?core.pages.Key = null,
};
pub fn step(engine: anytype, candidate: anytype, next: *core.growing.Head) !void {
    var cursor = &next.compaction;
    const Store = @TypeOf(engine.page_store.*);
    switch (cursor.phase) {
        .resources => {
            const batch = try candidate.scan(c.Snapshot, .{ .namespace = .resource_blocks }, if (cursor.resource == 0) null else core.growing.address(.resource_blocks, cursor.resource));
            if (batch.records[0]) |record| {
                if (record.key.len != 17) return error.InvalidStorageGraph;
                cursor.resource = std.mem.readInt(u64, record.key.data[1..9], .big);
                if (cursor.resource == 0) return error.InvalidStorageGraph;
                cursor.phase = .blocks;
            } else cursor.phase = .catalog;
            cursor.after = null;
        },
        .blocks => {
            const key = core.growing.address(.resource_blocks, cursor.resource);
            const snapshot = (try candidate.get(c.Snapshot, key)) orelse {
                cursor.phase = .resources;
                cursor.after = null;
                return;
            };
            var index = try c.Catalog(Store).open(engine.page_store, snapshot);
            const batch = try index.scan(core.blocks.Record, .{ .namespace = .entry }, cursor.after);
            if (batch.records[0]) |entry| {
                var record = entry.value;
                const expected = try c.key(.entry, 0, 0, record.key.slice());
                if (!std.meta.eql(expected, entry.key)) return error.InvalidStorageGraph;
                var bytes: [core.protocol.Blocks.max_block_bytes]u8 = undefined;
                const body = try engine.page_store.loadBlock(record.reference, &bytes);
                record.reference = try engine.page_store.stageBlock(record.reference.value, body);
                try index.put(entry.key, record);
                try candidate.put(key, index.snapshot);
                cursor.after = entry.key;
            } else {
                cursor.phase = .resources;
                cursor.after = null;
            }
        },
        .catalog => {
            try candidate.flush();
            const result = try (core.pages.Tree(Store){ .store = engine.page_store }).rewrite(candidate.snapshot.root, cursor.after);
            candidate.snapshot.root = result.root;
            cursor.after = result.after;
            if (cursor.after == null) cursor.phase = .policy;
        },
        .policy => {
            const result = try (core.pages.Tree(Store){ .store = engine.page_store }).rewrite(next.authorization.catalog.root, cursor.after);
            next.authorization.catalog.root = result.root;
            cursor.after = result.after;
            if (cursor.after == null) cursor.phase = .complete;
        },
        .complete => cursor.* = .{},
    }
}

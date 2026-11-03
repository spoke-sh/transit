//! Bounded ordered trees in shared .tseg records, with persisted BP topology.
//! Every sealed index is private until DocumentPartition accepts its descriptor.
const std = @import("std");
const change = @import("transit_document").OrderedChange;
const wire = @import("transit_document").codec;
const Topology = @import("transit_document").SuccinctTree;
const Index = @import("DocumentIndex.zig");
pub const chunk_bytes = 240;
pub const Navigation = Topology.Navigation;

/// One owned topology chunk. The durable tree may be larger than every cache.
const TopologyReader = struct {
    index: Index,
    store: *Index.Store,
    budget: *Budget,
    bit_count: u64,
    position: u64 = 0,
    chunk: Index.Value = .{},

    pub fn next(self: *TopologyReader) !?bool {
        if (self.position == self.bit_count) return null;
        try self.budget.charge();
        const within = self.position % (chunk_bytes * 8);
        if (within == 0) {
            self.chunk = try get(self.index, self.store, 'B', 0, self.position / (chunk_bytes * 8), self.budget);
            const remaining = (self.bit_count - self.position + 7) / 8;
            if (self.chunk.len != @min(chunk_bytes, remaining)) return error.InvalidOrderedState;
            if (remaining <= chunk_bytes and self.bit_count % 8 != 0 and
                self.chunk.data[self.chunk.len - 1] >> @as(u3, @intCast(self.bit_count % 8)) != 0) return error.InvalidOrderedState;
        }
        const open = self.chunk.data[@intCast(within / 8)] & (@as(u8, 1) << @as(u3, @intCast(within % 8))) != 0;
        self.position += 1;
        return open;
    }
};

pub fn navigate(index: Index, store: *Index.Store, count: u64, ordinal: u64, ancestors: []u64, budget: *Budget) !Navigation {
    const bits = std.math.mul(u64, count, 2) catch return error.InvalidOrderedState;
    if (bits > std.math.maxInt(u64) - 7) return error.InvalidOrderedState;
    var reader: TopologyReader = .{ .index = index, .store = store, .budget = budget, .bit_count = bits };
    const result = Topology.navigate(&reader, count, ordinal, ancestors) catch |err| switch (err) {
        error.NodeOutOfBounds => return error.DocumentPathMissing,
        error.InvalidSuccinctTree => return error.InvalidOrderedState,
        else => return err,
    };
    if ((try node(index, store, ordinal, budget)).depth != result.depth) return error.InvalidOrderedState;
    return result;
}
pub const Node = struct {
    depth: u32,
    kind: change.Kind,
    name_bytes: u32,
    value_bytes: u32,
    span: ?change.Span,
    pub fn encode(self: Node) !Index.Value {
        var bytes: [64]u8 = undefined;
        var w: wire.Writer = .{ .bytes = &bytes };
        try w.int(u32, self.depth);
        try w.int(u8, @backingInt(self.kind));
        try w.int(u32, self.name_bytes);
        try w.int(u32, self.value_bytes);
        try w.int(u8, @intFromBool(self.span != null));
        if (self.span) |span| {
            try w.int(u64, span.part);
            try w.int(u64, span.start);
            try w.int(u64, span.end);
        }
        return Index.Value.init(bytes[0..w.offset]);
    }
    pub fn decode(value: Index.Value) !Node {
        var r: wire.Reader = .{ .bytes = value.slice() };
        const depth = try r.int(u32);
        const kind = std.enums.fromInt(change.Kind, try r.int(u8)) orelse return error.InvalidOrderedState;
        const name_bytes = try r.int(u32);
        const value_bytes = try r.int(u32);
        const span: ?change.Span = switch (try r.int(u8)) {
            0 => null,
            1 => .{ .part = try r.int(u64), .start = try r.int(u64), .end = try r.int(u64) },
            else => return error.InvalidOrderedState,
        };
        try r.finish();
        return .{ .depth = depth, .kind = kind, .name_bytes = name_bytes, .value_bytes = value_bytes, .span = span };
    }
};
pub const Part = struct {
    bytes: u64,
    digest: [32]u8,
    pub fn encode(self: Part) !Index.Value {
        var bytes: [40]u8 = undefined;
        std.mem.writeInt(u64, bytes[0..8], self.bytes, .little);
        bytes[8..40].* = self.digest;
        return Index.Value.init(&bytes);
    }
    pub fn decode(value: Index.Value) !Part {
        if (value.len != 40) return error.InvalidOrderedState;
        return .{ .bytes = std.mem.readInt(u64, value.data[0..8], .little), .digest = value.data[8..40].* };
    }
};
pub const Budget = struct {
    remaining: u64,
    used: u64 = 0,
    pub fn charge(self: *Budget) !void {
        if (self.remaining == 0) return error.DocumentEvaluationBudget;
        self.remaining -= 1;
        self.used += 1;
    }
};
pub fn key(tag: u8, id: u64, chunk: u64) !Index.Key {
    var bytes: [17]u8 = undefined;
    bytes[0] = tag;
    std.mem.writeInt(u64, bytes[1..9], id, .big);
    std.mem.writeInt(u64, bytes[9..17], chunk, .big);
    return Index.Key.init(&bytes);
}
pub fn get(index: Index, store: *Index.Store, tag: u8, id: u64, chunk: u64, budget: *Budget) !Index.Value {
    try budget.charge();
    return (try index.get(store, try key(tag, id, chunk))) orelse return error.InvalidOrderedState;
}
pub fn node(index: Index, store: *Index.Store, ordinal: u64, budget: *Budget) !Node {
    return Node.decode(try get(index, store, 'N', ordinal, 0, budget));
}
pub fn part(index: Index, store: *Index.Store, id: u64, budget: *Budget) !Part {
    return Part.decode(try get(index, store, 'P', id, 0, budget));
}
pub fn subtreeEnd(index: Index, store: *Index.Store, ordinal: u64, count: u64, budget: *Budget) !u64 {
    const depth = (try node(index, store, ordinal, budget)).depth;
    var end = ordinal + 1;
    while (end < count) : (end += 1) if ((try node(index, store, end, budget)).depth <= depth) return end;
    return end;
}
pub fn resolve(index: Index, store: *Index.Store, path: []const u8, count: u64, budget: *Budget) !u64 {
    var selected: u64 = 0;
    var at: usize = 0;
    while (at < path.len) : (at += 4) {
        const parent = try node(index, store, selected, budget);
        if (!parent.kind.container()) return error.DocumentPathTypeError;
        var ordinal = std.mem.readInt(u32, path[at..][0..4], .little);
        selected += 1;
        while (ordinal != 0) : (ordinal -= 1) {
            if (selected >= count or (try node(index, store, selected, budget)).depth <= parent.depth) return error.DocumentPathMissing;
            selected = try subtreeEnd(index, store, selected, count, budget);
        }
        if (selected >= count or (try node(index, store, selected, budget)).depth != parent.depth + 1) return error.DocumentPathMissing;
    }
    return selected;
}

pub const Builder = struct {
    store: *Index.Store,
    index: Index,
    index_bytes: usize,
    staged_start: u64,
    budget: *Budget,
    validator: change.Validator,
    count: u64 = 0,
    parts: u64 = 0,
    topology: [chunk_bytes]u8 = @splat(0),
    topology_bits: u64 = 0,
    depth: u32 = 0,
    pub fn init(store: *Index.Store, index_bytes: usize, frames: []change.Frame, budget: *Budget) !Builder {
        return .{ .store = store, .index = try store.begin(.{}, index_bytes), .index_bytes = index_bytes, .staged_start = store.tree.staged_bytes, .budget = budget, .validator = .{ .frames = frames } };
    }
    pub fn put(self: *Builder, tag: u8, id: u64, chunk: u64, value: Index.Value) !void {
        try self.budget.charge();
        if (self.index.pending == self.store.pending.len) {
            const sealed = try self.store.seal(self.index);
            const used = self.store.tree.staged_bytes - self.staged_start;
            if (used >= self.index_bytes) return error.StorageCandidateTooLarge;
            self.index = try self.store.begin(sealed, self.index_bytes - @as(usize, @intCast(used)));
        }
        self.index = try self.index.put(self.store, try key(tag, id, chunk), value);
    }
    fn bytes(self: *Builder, tag: u8, id: u64, data: []const u8) !void {
        var offset: usize = 0;
        while (offset < data.len) : (offset += @min(chunk_bytes, data.len - offset)) {
            try self.put(tag, id, offset / chunk_bytes, try Index.Value.init(data[offset..][0..@min(chunk_bytes, data.len - offset)]));
        }
    }
    fn copyBytes(self: *Builder, source: Index, tag: u8, old: u64, new: u64, length: u64) !void {
        var offset: u64 = 0;
        while (offset < length) {
            const value = try get(source, self.store, tag, old, offset / chunk_bytes, self.budget);
            if (value.len != @min(chunk_bytes, length - offset)) return error.InvalidOrderedState;
            try self.put(tag, new, offset / chunk_bytes, value);
            offset += value.len;
        }
    }
    pub fn copyParts(self: *Builder, source: Index) !void {
        var after: ?Index.Key = try key('P', 0, 0);
        while (true) {
            try self.budget.charge();
            const entry = (try source.next(self.store, after)) orelse break;
            if (entry.key.len != 17 or entry.key.data[0] != 'P') break;
            const id = std.mem.readInt(u64, entry.key.data[1..9], .big);
            const part_info = try Part.decode(entry.value);
            try self.put('P', id, 0, entry.value);
            try self.copyBytes(source, 'R', id, id, part_info.bytes);
            self.parts += 1;
            after = entry.key;
        }
    }
    pub fn addPart(self: *Builder, value: change.Part) !void {
        try self.budget.charge();
        if (try self.index.get(self.store, try key('P', value.id, 0))) |existing| {
            const part_info = try Part.decode(existing);
            if (part_info.bytes != value.bytes.len or !std.mem.eql(u8, &part_info.digest, &value.digest)) return error.DocumentPartIdentityConflict;
            return;
        }
        try self.put('P', value.id, 0, try (Part{ .bytes = value.bytes.len, .digest = value.digest }).encode());
        try self.bytes('R', value.id, value.bytes);
        self.parts += 1;
    }
    fn bit(self: *Builder, open: bool) !void {
        const within: usize = @intCast(self.topology_bits % (chunk_bytes * 8));
        if (open) self.topology[within / 8] |= @as(u8, 1) << @intCast(within % 8);
        self.topology_bits += 1;
        if (self.topology_bits % (chunk_bytes * 8) == 0) {
            try self.put('B', 0, self.topology_bits / (chunk_bytes * 8) - 1, try Index.Value.init(&self.topology));
            @memset(&self.topology, 0);
        }
    }
    fn metadata(self: *Builder, value: Node) !void {
        try self.validator.pushStructure(value.depth, value.kind);
        if (value.span) |span| {
            const raw = try part(self.index, self.store, span.part, self.budget);
            if (span.end < span.start or span.end > raw.bytes) return error.InvalidOrderedSpan;
        }
        if (self.count != 0) {
            while (self.depth >= value.depth) {
                try self.bit(false);
                if (self.depth == 0) return error.InvalidOrderedTree;
                self.depth -= 1;
            }
        }
        try self.bit(true);
        self.depth = value.depth;
        try self.put('N', self.count, 0, try value.encode());
    }
    pub fn add(self: *Builder, value: change.Node, depth_offset: u32) !void {
        const depth = std.math.add(u32, value.depth, depth_offset) catch return error.DocumentDepthLimitExceeded;
        try self.metadata(.{ .depth = depth, .kind = value.kind, .name_bytes = @intCast(value.name.len), .value_bytes = @intCast(value.value.len), .span = value.span });
        try self.bytes('K', self.count, value.name);
        try self.bytes('V', self.count, value.value);
        self.count += 1;
    }
    pub fn copyNode(self: *Builder, source: Index, ordinal: u64) !void {
        const metadata_ = try node(source, self.store, ordinal, self.budget);
        try self.metadata(metadata_);
        try self.copyBytes(source, 'K', ordinal, self.count, metadata_.name_bytes);
        try self.copyBytes(source, 'V', ordinal, self.count, metadata_.value_bytes);
        self.count += 1;
    }
    pub fn finish(self: *Builder) !Index {
        try self.validator.finish();
        while (true) {
            try self.bit(false);
            if (self.depth == 0) break;
            self.depth -= 1;
        }
        if (self.topology_bits != self.count * 2) return error.InvalidOrderedTree;
        const used = self.topology_bits % (chunk_bytes * 8);
        if (used != 0) try self.put('B', 0, self.topology_bits / (chunk_bytes * 8), try Index.Value.init(self.topology[0..@intCast((used + 7) / 8)]));
        return self.store.seal(self.index);
    }
};

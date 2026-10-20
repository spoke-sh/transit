//! Qualified immutable reads. Source identities are not bearer capabilities.
const std = @import("std");
const p = @import("root.zig");
const g = p.Growth;
pub const Query = struct {
    source: union(enum) {
        resource: struct { id: u64, revision: u64 },
        view: u64,
        version: struct { id: g.ReadVersionId, generation: u64 },
    },
    keys: [g.page_size]?p.Value = @splat(null),
    /// Empty keys select a metadata scan; continuation remains at this source cut.
    after: ?p.Value = null,
};
pub const Result = struct {
    resource: g.Resource,
    view: ?g.View = null,
    version: ?g.ReadVersion = null,
    entries: [g.page_size]?p.Blocks.Entry,
    next: ?p.Value = null,
};
pub const Response = struct {
    response: g.Response,
    blocks: p.Blocks.Body,
};
pub fn validate(query: Query) !void {
    switch (query.source) {
        .resource => |value| if (value.id == 0) return error.InvalidRead,
        .view => |id| if (id == 0) return error.InvalidRead,
        .version => |value| try g.validateVersionId(value.id),
    }
    try keys(query.keys);
    if (query.after) |after| {
        if (query.keys[0] != null) return error.InvalidRead;
        try g.validateKey(after);
    }
}
pub fn keys(values: [g.page_size]?p.Value) !void {
    var ended = false;
    for (values, 0..) |slot, i| {
        const key = slot orelse {
            ended = true;
            continue;
        };
        if (ended) return error.InvalidRead;
        try g.validateKey(key);
        for (values[0..i]) |previous| if (previous.?.eql(key)) return error.InvalidRead;
    }
}
pub fn entries(values: [g.page_size]?p.Blocks.Entry, requested: [g.page_size]?p.Value, revision: u64) !void {
    for (values, requested) |slot, key| if (slot) |entry| {
        if (key == null or !key.?.eql(entry.key) or entry.revision == 0 or entry.revision > revision) return error.InvalidRead;
        try entry.value.validate();
    };
}
pub fn validateResult(value: Result, query: Query) !void {
    if (value.resource.phase != .active) return error.InvalidRead;
    switch (query.source) {
        .resource => |source| if (value.view != null or value.version != null or value.resource.id != source.id or value.resource.revision != source.revision) return error.InvalidRead,
        .view => |id| {
            const view = value.view orelse return error.InvalidRead;
            if (value.version != null or view.id != id or view.resource != value.resource.id or view.revision != value.resource.revision or view.closed_at != null) return error.InvalidRead;
        },
        .version => |source| {
            const version = value.version orelse return error.InvalidRead;
            if (value.view != null or !std.meta.eql(version.id, source.id) or version.resource != value.resource.id or version.revision != value.resource.revision or version.released_at != null) return error.InvalidRead;
        },
    }
    if (query.keys[0] != null) {
        if (value.next != null) return error.InvalidRead;
        try entries(value.entries, query.keys, value.resource.revision);
    } else {
        var ended = false;
        var previous = query.after;
        var count: usize = 0;
        for (value.entries) |slot| {
            const entry = slot orelse {
                ended = true;
                continue;
            };
            if (ended or entry.revision == 0 or entry.revision > value.resource.revision) return error.InvalidRead;
            try g.validateKey(entry.key);
            try entry.value.validate();
            if (previous) |key| if (std.mem.order(u8, key.slice(), entry.key.slice()) != .lt) return error.InvalidRead;
            previous = entry.key;
            count += 1;
        }
        if (value.next) |next| if (count == 0 or !next.eql(previous.?)) return error.InvalidRead;
    }
}
pub fn verify(value: *const Response, query: g.Query) !void {
    try g.validateResponse(value.response, query);
    const records = switch (value.response.body) {
        .block_entries => |result| result.entries,
        .snapshot_read => |result| result.blocks,
        else => return error.InvalidRead,
    };
    try value.blocks.validate();
    var offset: usize = 0;
    for (records) |slot| if (slot) |entry| {
        if (entry.value.bytes > value.blocks.len - offset) return error.InvalidBlockBody;
        try entry.value.verify(value.blocks.slice()[offset..][0..entry.value.bytes]);
        offset += entry.value.bytes;
    };
    if (offset != value.blocks.len) return error.InvalidBlockBody;
}

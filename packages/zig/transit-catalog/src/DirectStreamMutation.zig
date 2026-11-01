//! Original Stream work bound in the shared catalog operation namespace.
//! Reserving this immutable identity is neither mutation acceptance nor a grant.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueue;

pub const Request = p.LogWorkload.StreamRequest;

pub const Binding = p.LogWorkload.StreamBinding;

test "stream operation bindings freeze target payload producer and read intent" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 9 };
    const target: q.Partition = .{
        .definition = p.Growth.current_definition,
        .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 7 }, .revision = 1, .digest = @splat(3) },
        .partition = 0,
    };
    const original: Request = .{ .append = .{
        .target = target,
        .operation = .{ .scope = scope, .principal = 0, .operation = std.math.maxInt(u64) },
        .kind = .stream,
        .producer = .{ .id = @splat(9), .epoch = 1, .sequence = 1 },
        .rows = 1,
        .payload = .{ .bytes = 100, .sha256 = @splat(2) },
    } };
    const bound = try original.binding(t.allocator);
    try bound.requireSame(try original.binding(t.allocator));
    for (0..6) |change| {
        var changed = original;
        switch (change) {
            0 => changed.append.target.partition += 1,
            1 => changed.append.target.interpretation.object.object += 1,
            2 => changed.append.payload.sha256[0] ^= 1,
            3 => changed.append.producer.?.sequence += 1,
            4 => changed.append.producer.?.epoch += 1,
            5 => changed.append.rows += 1,
            else => unreachable,
        }
        try t.expectError(error.DataIdentityConflict, bound.requireSame(try changed.binding(t.allocator)));
    }
    var request: Request = .{ .consume = .{ .target = target, .operation = original.identity(), .group = null, .from = 0, .until = null, .timestamp = null } };
    const read_bound = try request.binding(t.allocator);
    try t.expectError(error.DataIdentityConflict, bound.requireSame(read_bound));
    request.consume.until = 0;
    try t.expectError(error.DataIdentityConflict, read_bound.requireSame(try request.binding(t.allocator)));
    request.consume.until = null;
    request.consume.timestamp = .{ .from_us = -1, .until_us = 10 };
    try t.expectError(error.DataIdentityConflict, read_bound.requireSame(try request.binding(t.allocator)));
    var queue = original;
    queue.append.kind = .queue;
    try t.expectError(error.CatalogKindMismatch, queue.validate());
}

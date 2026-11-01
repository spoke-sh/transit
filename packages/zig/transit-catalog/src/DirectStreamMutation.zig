//! Original Stream work bound in the shared catalog operation namespace.
//! Reserving this immutable identity is neither mutation acceptance nor a grant.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueue;
const read = p.StreamRead;

pub const Request = union(p.LogWorkload.StreamKind) {
    append: q.Append,
    assign: q.GroupAssignment,
    consume: read.Request,
    release: read.Release,
    offset: struct {
        commit: q.OffsetCommit,
        cursor: read.Cursor,
        pub fn validate(self: @This()) !void {
            try self.commit.validate();
            try self.cursor.validate();
            if (!std.meta.eql(self.commit.coverage, self.cursor.coverage) or
                self.commit.operation.principal != self.cursor.read.owner.principal)
                return error.StreamReadConflict;
        }
    },

    pub fn validate(self: Request) !void {
        switch (self) {
            inline else => |value| try value.validate(),
        }
        if (self == .append and self.append.kind != .stream) return error.CatalogKindMismatch;
    }
    pub fn identity(self: Request) d.Operation {
        return switch (self) {
            .offset => |value| value.commit.operation,
            inline else => |value| value.operation,
        };
    }
    pub fn target(self: Request) q.Partition {
        return switch (self) {
            .assign => |value| value.cut.target,
            .offset => |value| value.commit.coverage.cut.target,
            inline else => |value| value.target,
        };
    }
    pub fn access(self: Request) c.LogAuthority.Access {
        return switch (self) {
            .append => .append,
            .assign => .administer,
            .consume => |value| if (value.group != null) .acquire else .read,
            .release => .read,
            .offset => .settle,
        };
    }
    pub fn control(self: Request) bool {
        return switch (self) {
            .assign => |value| value.expected != null,
            .release, .offset => true,
            .append, .consume => false,
        };
    }
    /// Payload bytes are already bound by Append.payload. Hash every remaining
    /// frozen field, including cursor authentication and exact consumer basis.
    pub fn binding(self: Request, scratch: std.mem.Allocator) !Binding {
        try self.validate();
        const bytes = try p.Json.valueAllocBounded(scratch, self, 16 * 1024);
        defer scratch.free(bytes);
        var digest = std.crypto.hash.sha2.Sha256.init(.{});
        digest.update("transit.catalog.stream.operation.v1\x00");
        digest.update(&p.Growth.definition_bytes);
        digest.update(bytes);
        const result: Binding = .{
            .definition = p.Growth.current_definition,
            .operation = self.identity(),
            .target = self.target(),
            .kind = std.meta.activeTag(self),
            .intent = digest.finalResult(),
        };
        try result.validate();
        return result;
    }
};

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

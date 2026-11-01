//! Read-only original-result messages on the signed direct service boundary.
//! Every request resolves its immutable operation; delivery positions are not
//! credentials, new mutations or independent completion evidence.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const w = c.DirectTableProtocol;
const r = c.DirectWorkloadResult;

pub const Request = union(enum) {
    open: struct { intent: c.DirectWorkloadIntent.Reference, limits: r.Limits },
    page: struct { reference: r.Reference, position: r.Position },
    pub fn intentReference(self: Request) c.DirectWorkloadIntent.Reference {
        return switch (self) {
            .open => |value| value.intent,
            .page => |value| value.reference.intent,
        };
    }
    pub fn target(self: Request) p.StreamQueue.Partition {
        return self.intentReference().binding.target();
    }
    pub fn validate(self: Request, connection: w.Connection) !void {
        const intent = self.intentReference();
        try intent.validate();
        if (!std.meta.eql(intent.connection, connection)) return error.CatalogIdentityConflict;
        switch (self) {
            .open => |value| {
                try value.limits.validate();
                if (value.limits.rows > intent.source.declaration.limits.read_rows or
                    value.limits.encoded_bytes > intent.source.declaration.limits.read_bytes) return error.InvalidWorkloadResultBudget;
            },
            .page => |value| try value.position.validate(value.reference),
        }
    }
};

pub const Opened = struct {
    reference: r.Reference,
    position: r.Position,
    source: c.DirectLogProtocol.Definition,
};
pub const Result = union(enum) {
    opened: Opened,
    page: struct { reference: r.Reference, position: r.Position, page: r.Page },
    pub fn deinit(self: Result, allocator: std.mem.Allocator) void {
        switch (self) {
            .opened => |value| allocator.free(value.source.schema.base64),
            .page => |value| value.page.deinit(allocator),
        }
    }
};

pub fn apply(output: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, request: Request, native: r.Native) !Result {
    try request.validate(request.intentReference().connection);
    var owned = switch (request) {
        .open => |value| try r.open(catalog.allocator, catalog, value.intent, value.limits, policy, native),
        .page => |value| try r.reopen(catalog.allocator, catalog, value.reference, policy, native),
    };
    defer owned.deinit();
    var scratch: std.heap.ArenaAllocator = .init(catalog.allocator);
    defer scratch.deinit();
    const result: Result = switch (request) {
        .open => blk: {
            var source = owned.intent.parsed.value.source;
            source.schema.base64 = try output.dupe(u8, source.schema.base64);
            break :blk .{ .opened = .{ .reference = owned.reference, .position = owned.position(), .source = source } };
        },
        .page => |value| blk: {
            try owned.seek(value.position);
            const page = try owned.next(&scratch, output, catalog, policy, native);
            break :blk .{ .page = .{ .reference = owned.reference, .position = owned.position(), .page = page } };
        },
    };
    errdefer result.deinit(output);
    try owned.checkDisclosure(scratch.allocator(), catalog, policy);
    return result;
}

fn requireSource(allocator: std.mem.Allocator, connection: w.Connection, reference: r.Reference, source: c.DirectLogProtocol.Definition) !void {
    try reference.validate();
    try c.DirectLogProtocol.validateMetadata(allocator, connection, source);
    if (!std.meta.eql(reference.intent.source, source.declaration.stored) or
        reference.intent.namespace != source.declaration.properties.namespace) return error.WorkloadResultConflict;
    const accepted = switch (reference.selection) {
        inline else => |value| value.accepted,
    };
    if (accepted.partition != try source.declaration.partition(reference.intent.binding.target().partition)) return error.WorkloadResultConflict;
}

pub fn validate(allocator: std.mem.Allocator, connection: w.Connection, request: Request, response: Result) !void {
    try request.validate(connection);
    switch (request) {
        .open => |value| {
            if (response != .opened) return error.InvalidWorkloadResultResponse;
            const opened = response.opened;
            try value.intent.requireSame(opened.reference.intent);
            if (!std.meta.eql(value.limits, opened.reference.limits)) return error.InvalidWorkloadResultResponse;
            try requireSource(allocator, connection, opened.reference, opened.source);
            try opened.position.validate(opened.reference);
            switch (opened.position) {
                .append => |ordinal| if (ordinal != 0) return error.InvalidWorkloadResultResponse,
                .consume => |cursor| if (cursor.coverage.rows != 0 or cursor.coverage.through != cursor.coverage.from) return error.InvalidWorkloadResultResponse,
                .claim => |cursor| if (cursor.next != 0) return error.InvalidWorkloadResultResponse,
            }
        },
        .page => |value| {
            if (response != .page) return error.InvalidWorkloadResultResponse;
            const page = response.page;
            try value.reference.requireSame(page.reference);
            try page.position.validate(page.reference);
            if (!std.mem.eql(u8, @tagName(page.page), @tagName(page.position))) return error.InvalidWorkloadResultResponse;
            const source = switch (page.page) {
                inline else => |body| body.source,
            };
            try requireSource(allocator, connection, page.reference, source);
            const limits = page.reference.limits;
            switch (page.page) {
                .consume => |body| {
                    if (!std.meta.eql(page.position.consume, body.cursor)) return error.InvalidWorkloadResultResponse;
                    try c.DirectStreamResponse.validate(allocator, connection, .{ .page = .{ .cursor = value.position.consume, .limits = .{ .rows = limits.rows, .encoded_bytes = limits.encoded_bytes, .scanned_rows = limits.scanned_rows } } }, .{ .page = body });
                },
                .claim => |body| {
                    if (!std.meta.eql(page.position.claim, body.cursor)) return error.InvalidWorkloadResultResponse;
                    try c.DirectQueueResponse.validate(allocator, connection, .{ .page = .{ .cursor = value.position.claim, .limits = .{ .rows = limits.rows, .encoded_bytes = limits.encoded_bytes } } }, .{ .page = body });
                },
                .append => |body| {
                    const original = page.reference.selection.append;
                    const prior = value.position.append;
                    if (body.next != page.position.append or body.next < prior or body.next - prior != body.rows.len or
                        body.rows.len > limits.rows or body.complete != (body.next == original.append.rows) or
                        (!body.complete and body.rows.len == 0) or body.encoded_bytes > limits.encoded_bytes) return error.InvalidWorkloadResultResponse;
                    var declared = try c.DirectLogProtocol.decodeMetadata(allocator, connection, source);
                    defer declared.deinit();
                    var scratch: std.heap.ArenaAllocator = .init(allocator);
                    defer scratch.deinit();
                    var bytes: usize = 0;
                    for (body.rows, 0..) |row, index| {
                        _ = scratch.reset(.retain_capacity);
                        if (row.ordinal != prior + index or row.offset != original.first + row.ordinal or
                            (original.append.kind == .stream and row.visible_ms != 0) or
                            (original.append.kind == .queue and row.tombstone) or
                            (row.tombstone and source.declaration.stored.declaration.configuration.policy.stream.compact_key_column == null)) return error.InvalidWorkloadResultResponse;
                        const encoded = try row.encoded.decode(scratch.allocator(), @min(c.fuze.TableRow.max_bytes, limits.encoded_bytes));
                        const decoded = try c.fuze.TableRow.decodeInto(scratch.allocator(), declared.definition.schema, encoded);
                        const operation = original.append.operation;
                        if (!std.meta.eql(decoded.identity, c.fuze.TableRow.Identity{ .origin = operation.principal + 1, .operation = operation.operation, .ordinal = row.ordinal })) return error.InvalidWorkloadResultResponse;
                        bytes = std.math.add(usize, bytes, encoded.len + c.storage.LogBatch.row_header_bytes) catch return error.InvalidWorkloadResultResponse;
                    }
                    if (bytes != body.encoded_bytes) return error.InvalidWorkloadResultResponse;
                },
            }
        },
    }
}

test "workload result requests verify independent signatures and original positions" {
    const t = std.testing;
    const Fixture = struct { request: w.Request, public_key: [32]u8 };
    const parsed = try p.Json.parseFromSlice([4]Fixture, t.allocator, @embedFile("fixtures/direct-workload-result-v1.json"));
    defer parsed.deinit();
    for (parsed.value) |fixture| {
        try fixture.request.validate(t.allocator);
        try fixture.request.proof.verify(fixture.public_key);
        var changed = fixture.request;
        changed.connection.branch += 1;
        try t.expectError(error.CatalogIdentityConflict, changed.action.workload_result.validate(changed.connection));
        changed = fixture.request;
        switch (changed.action.workload_result) {
            .open => |*value| value.limits.rows += 1,
            .page => |*value| switch (value.position) {
                .append => unreachable,
                .consume => |*cursor| cursor.authentication[0] ^= 1,
                .claim => |*cursor| cursor.next -= 1,
            },
        }
        try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
        if (fixture.request.action.workload_result == .page) {
            changed = fixture.request;
            changed.action.workload_result.page.reference.intent.record.scope.account[0] ^= 1;
            try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
        }
    }
}

//! Explicit forward interpretation of an unchanged retained data source.
const std = @import("std");
const c = @import("root.zig");
const w = c.DirectTableProtocol;
const d = c.protocol.DataLifecycle;
const P = c.storage.TablePartition;
const Stored = c.storage.TableDeclaration.Stored;
pub const Accepted = c.storage.TableInterpretations.Accepted;

pub const Source = union(enum) {
    snapshot: w.Snapshot,
    historical: struct { snapshot: d.Snapshot, object: u64 },
    pub fn object(self: Source) d.Object {
        return switch (self) {
            .snapshot => |value| value.object,
            .historical => |value| .{ .scope = value.snapshot.owner.scope, .branch = value.snapshot.branch, .object = value.object },
        };
    }
};
pub const Request = union(enum) {
    /// Null target selects CURRENT once. The response always identifies an
    /// exact accepted target, which subsequent reads must preserve.
    prepare: struct { source: Stored, target: ?Stored },
    scan: struct { source: Source, target: Stored, after: ?P.SnapshotCursor, limits: P.ReadLimits },
    pub fn validate(self: Request, connection: w.Connection) !void {
        switch (self) {
            .prepare => |value| {
                try definition(connection, value.source);
                if (value.target) |target| try pair(connection, value.source, target);
            },
            .scan => |value| {
                try definition(connection, value.target);
                if (!std.meta.eql(value.source.object(), value.target.interpretation.object)) return error.InvalidSchemaProjection;
                switch (value.source) {
                    .snapshot => |source| {
                        try connection.owner(source.handle.owner);
                        try source.handle.content.validate();
                    },
                    .historical => |source| {
                        try source.snapshot.validate();
                        if (source.snapshot.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
                    },
                }
                try value.limits.validate();
                if (value.limits.encoded_bytes > w.max_page_bytes) return error.InvalidTableReadBudget;
                if (value.after) |after| try after.source.validate();
            },
        }
    }
};
pub const Prepared = struct { source: Stored, target: Accepted, schema: w.Binary };
pub const Page = struct { source: w.Page, target: Accepted, catalog: ?d.Snapshot, historical_source: ?d.SourceCut };
pub const Result = union(enum) { prepared: Prepared, page: Page };

fn definition(connection: w.Connection, value: Stored) !void {
    try value.validate();
    try connection.object(value.interpretation.object);
    if (value.kind != .table or value.retired) return error.InvalidSchemaProjection;
}
fn pair(connection: w.Connection, source: Stored, target: Stored) !void {
    try definition(connection, source);
    try definition(connection, target);
    if (!std.meta.eql(source.interpretation.object, target.interpretation.object) or source.interpretation.revision > target.interpretation.revision) return error.IncompatibleSchemaProjection;
}
pub fn validateResult(allocator: std.mem.Allocator, connection: w.Connection, request: Request, result: Result) !void {
    try request.validate(connection);
    switch (request) {
        .prepare => |input| {
            if (result != .prepared) return error.InvalidSchemaProjection;
            const value = result.prepared;
            _ = try value.target.encode();
            try pair(connection, value.source, value.target.declaration);
            if (!std.meta.eql(value.source, input.source)) return error.InvalidSchemaProjection;
            if (input.target) |target| if (!std.meta.eql(target, value.target.declaration)) return error.InvalidSchemaProjection;
            const bytes = try value.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
            defer allocator.free(bytes);
            var decoded = try c.fuze.TableSchema.decode(allocator, bytes);
            defer decoded.deinit();
            if (decoded.schema.object != input.source.interpretation.object.object or !std.mem.eql(u8, &try decoded.schema.fingerprint(), &value.target.declaration.schema_fingerprint)) return error.InvalidSchemaProjection;
        },
        .scan => |input| {
            if (result != .page) return error.InvalidSchemaProjection;
            const value = result.page;
            _ = try value.target.encode();
            const page = value.source;
            try pair(connection, page.interpretation, value.target.declaration);
            if (!std.meta.eql(input.target, value.target.declaration) or !std.meta.eql(input.source.object(), page.snapshot.object)) return error.InvalidSchemaProjection;
            try page.snapshot.handle.content.validate();
            try page.accepted.validate();
            if (page.accepted.next_lsn == 0 or page.changed_lsn > page.accepted.next_lsn) return error.InvalidSchemaProjection;
            switch (input.source) {
                .snapshot => |source| if (value.catalog != null or value.historical_source != null or !std.meta.eql(source, page.snapshot)) return error.InvalidSchemaProjection,
                .historical => |source| {
                    if (value.catalog == null or !std.meta.eql(source.snapshot, value.catalog.?) or !std.meta.eql(source.snapshot.owner, page.snapshot.handle.owner)) return error.InvalidSchemaProjection;
                    const cut = value.historical_source orelse return error.InvalidSchemaProjection;
                    if (!std.meta.eql(cut.interpretation, page.interpretation.interpretation) or !std.meta.eql(cut.accepted, page.accepted)) return error.InvalidSchemaProjection;
                    try source.snapshot.requireSource(cut);
                },
            }
            if (page.rows.len > input.limits.rows or page.rows.len > page.total_rows or page.encoded_bytes > input.limits.encoded_bytes) return error.InvalidSchemaProjection;
            const cursor_source = try P.projectionCursorSource(page.snapshot.handle, value.target);
            if (input.after) |after| if (!std.meta.eql(after.source, cursor_source)) return error.InvalidSchemaProjection;
            var total: usize = 0;
            for (page.rows) |row| {
                const bytes = try row.decode(allocator, c.fuze.TableRow.max_bytes);
                defer allocator.free(bytes);
                total = try std.math.add(usize, total, bytes.len);
            }
            if (total != page.encoded_bytes) return error.InvalidSchemaProjection;
            if (page.next) |next| {
                if (page.rows.len == 0 or !std.meta.eql(next.source, cursor_source)) return error.InvalidSchemaProjection;
                if (input.after) |after| if (std.mem.order(u8, &next.after, &after.after) != .gt) return error.InvalidSchemaProjection;
            } else if (input.after == null and page.rows.len != page.total_rows) return error.InvalidSchemaProjection;
        },
    }
}

pub fn call(client: c.DirectTableClient, request: Request) !std.json.Parsed(w.Response) {
    return client.call(.{ .schema_projection = request });
}

pub const Target = union(enum) { current, snapshot: d.Snapshot };
/// A target snapshot selects metadata for the original stable object. Its name
/// never participates in resolution and no target data is acquired or read.
pub fn resolve(client: c.DirectTableClient, source: Stored, target: Target) !std.json.Parsed(w.Response) {
    const exact: ?Stored = switch (target) {
        .current => null,
        .snapshot => |snapshot| blk: {
            const response = try c.DirectHistory.call(client, .{ .source = .{ .snapshot = snapshot, .object = source.interpretation.object.object, .rows = false } });
            defer response.deinit();
            break :blk response.value.result.historical_catalog.source.binding.declaration;
        },
    };
    return call(client, .{ .prepare = .{ .source = source, .target = exact } });
}

pub fn dispatch(output: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, request: Request) !Result {
    switch (request) {
        .prepare => |input| {
            var target = try catalog.prepareSchemaProjection(catalog.allocator, input.source, input.target, policy);
            defer target.deinit();
            const buffer = try catalog.allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
            defer catalog.allocator.free(buffer);
            return .{ .prepared = .{ .source = input.source, .target = target.accepted, .schema = try w.Binary.encode(output, try target.definition.schema.schema.encode(buffer)) } };
        },
        .scan => |input| {
            var scratch = std.heap.ArenaAllocator.init(catalog.allocator);
            defer scratch.deinit();
            // Resolve exact accepted metadata before encoding rows. Both owner
            // paths recheck current SELECT, including empty terminal pages.
            var target = try catalog.prepareSchemaProjection(catalog.allocator, input.target, input.target, policy);
            defer target.deinit();
            var selected: ?c.DirectCatalog.RetainedHistoryRead = null;
            defer if (selected) |*read| read.deinit();
            var found = switch (input.source) {
                .snapshot => |source| try catalog.scanSchemaProjection(catalog.allocator, source, input.target, input.after, input.limits, policy),
                .historical => |source| blk: {
                    selected = try catalog.openHistory(scratch.allocator(), source.snapshot, source.object, true, policy);
                    const read = &selected.?;
                    break :blk try read.access.view.table.scanSnapshotProjected(catalog.allocator, read.binding.pin.?, input.target, input.after, input.limits, read.access.current);
                },
            };
            defer found.deinit();
            if (!std.meta.eql(target.accepted, found.target)) return error.InvalidSchemaProjection;
            const page = &found.page;
            const rows = try output.alloc(w.Binary, page.count);
            const buffer = try catalog.allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer catalog.allocator.free(buffer);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(output, try page.rows[i].?.row().encode(target.definition.schema.schema, buffer));
            return .{ .page = .{
                .source = .{ .snapshot = .{ .object = input.source.object(), .handle = page.source }, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next },
                .target = found.target,
                .catalog = if (input.source == .historical) input.source.historical.snapshot else null,
                .historical_source = if (selected) |read| read.binding.source else null,
            } };
        },
    }
}

test "independent schema projection request binds both accepted interpretations" {
    const t = std.testing;
    const fixture = try c.protocol.Json.parseFromSlice(struct { request: w.Request, public_key: [32]u8 }, t.allocator, @embedFile("fixtures/direct-schema-projection-v1.json"));
    defer fixture.deinit();
    const request = fixture.value.request;
    try request.validate(t.allocator);
    try request.proof.verify(fixture.value.public_key);
    try t.expect(!request.transport().mutation);
    var changed = request;
    changed.action.schema_projection.prepare.target.?.schema_fingerprint[0] ^= 1;
    try t.expectError(error.InvalidAuthorizationCredential, changed.validate(t.allocator));
}

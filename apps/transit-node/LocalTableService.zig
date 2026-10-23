//! Direct Table dispatch inside the local storage owner. The host coordinates
//! catalog DDL/admission and each Table's mutations before entering this helper.
const std = @import("std");
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Policy = @import("LocalCatalogPolicy.zig");
const Runner = @import("LocalCatalogRunner.zig");
const w = c.DirectTableProtocol;
const d = c.protocol.DataLifecycle;
const D = c.DirectCatalog;
const Self = @This();

engine: *backend.DataAuthority.Engine,
configuration: D.Configuration,
registrar: struct { principal: u64, key: c.protocol.Ed25519.KeyPair, role: ?u64 = null },
options: D.Options = .{},
/// Inject a real authority change after response serialization in fault proofs.
before_reply: ?struct { context: *anyopaque, run: *const fn (*anyopaque, *backend.DataAuthority.Engine) anyerror!void } = null,

/// All borrowed result fields live in the request arena until the buffered
/// response is sent. The final fence can discard it after a revocation race.
pub fn execute(self: *Self, arena: *std.heap.ArenaAllocator, request: w.Request, output: []u8) ![]const u8 {
    const allocator = arena.allocator();
    try request.validate(allocator);
    if (!request.connection.matches(self.configuration)) return error.CatalogDenied;
    const context = try w.Request.context(request.input(), allocator);
    var policy = try Policy.init(self.engine, self.configuration, request.proof, context);
    const owner = self.engine.journal.backend;
    var control: backend.DataStore = .{ .backend = owner, .control = true };
    var data: backend.DataStore = .{ .backend = owner };
    var catalog = try D.init(allocator, self.configuration, control.log(), control.objects(), data.log(), data.objects(), self.options);
    defer catalog.deinit();
    try catalog.recover();
    const result = try self.apply(allocator, &catalog, policy.policy(), request.action);
    const revision = try policy.check();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, w.max_response_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try c.protocol.Json.write(w.Response{ .definition = c.protocol.Growth.current_definition, .context = context, .policy_revision = revision, .result = result }, &encoder);
    if (self.before_reply) |inject| try inject.run(inject.context, self.engine);
    if (try policy.check() != revision) return error.AuthorizationChanged;
    return writer.buffered();
}

fn schema(allocator: std.mem.Allocator, value: c.fuze.TableSchema.Schema) !w.Binary {
    const buffer = try allocator.alloc(u8, c.fuze.TableSchema.max_bytes);
    defer allocator.free(buffer);
    return w.Binary.encode(allocator, try value.encode(buffer));
}
fn apply(self: *Self, allocator: std.mem.Allocator, catalog: *D, policy: D.Policy, action: w.Action) !w.Result {
    switch (action) {
        .initialize => {
            try catalog.initialize(policy);
            return .initialized;
        },
        .describe => return .{ .description = self.configuration },
        .lookup => |value| {
            var view = (try catalog.resolve(allocator, value.namespace, try .init(value.name), policy)) orelse return .{ .lookup = null };
            defer view.deinit();
            return .{ .lookup = .{
                .interpretation = view.table.root.declared(),
                .namespace = view.properties.namespace,
                .name = view.properties.name,
                .position = .{ .partition = view.table.root.partition, .next_lsn = view.table.root.next_lsn },
                .changed_lsn = view.table.root.changed_lsn,
                .row_count = view.table.root.live_rows,
                .schema = try schema(allocator, view.table.declaration.schema.schema),
            } };
        },
        .list => |value| {
            var bytes: [8]u8 = undefined;
            const after = if (value.after) |id| blk: {
                std.mem.writeInt(u64, &bytes, id, .big);
                break :blk try c.storage.TreeStore.pages.Key.init(&bytes);
            } else null;
            const page = try catalog.list(value.namespace, after, policy);
            const next = if (page.next) |cursor| blk: {
                if (cursor.len != 8) return error.InvalidCatalogCursor;
                break :blk std.mem.readInt(u64, cursor.data[0..8], .big);
            } else null;
            return .{ .list = .{ .entries = page.entries, .next = next, .directory_position = page.directory_position, .consistency = .independent } };
        },
        .preview => |value| return .{ .preview = try catalog.preview(try value.native(allocator, self.configuration), policy) },
        .admit_ddl => |value| {
            _ = try catalog.admit(try value.native(allocator, self.configuration), policy);
            return .{ .ddl = try catalog.status(value.binding, policy) };
        },
        inline .admit_rows, .admit_statement => |value| return .{ .rows = try catalog.admitRows(try value.native(allocator), policy) },
        .operation => |value| switch (value.binding.action) {
            .create, .alter, .rename, .drop => return .{ .ddl = switch (value.command) {
                .inspect => try catalog.status(value.binding, policy),
                .cancel => try catalog.cancel(value.binding, policy),
                .execute => blk: {
                    var runner: Runner = .{ .engine = self.engine, .principal = self.registrar.principal, .key = self.registrar.key, .role = self.registrar.role };
                    break :blk (try runner.run(catalog, value.binding, policy, value.steps)).observation;
                },
            } },
            .insert, .update, .delete => return .{ .rows = switch (value.command) {
                .inspect => try catalog.rowStatus(value.binding, policy),
                .cancel => try catalog.cancelRows(value.binding, policy),
                .execute => try catalog.performRows(value.binding, policy),
            } },
        },
        .pin => |value| return .{ .pin = try catalog.pinRows(value.object, value.owner, value.expected, policy) },
        .snapshot => |value| {
            var found = try catalog.snapshotDefinition(allocator, value.object, value.handle, policy);
            defer found.deinit();
            return .{ .snapshot = .{
                .snapshot = value,
                .interpretation = found.root.declared(),
                .accepted = .{ .partition = found.root.partition, .next_lsn = found.root.next_lsn },
                .changed_lsn = found.root.changed_lsn,
                .row_count = found.root.live_rows,
                .schema = try schema(allocator, found.schema.schema),
            } };
        },
        .scan => |value| {
            var definition = try catalog.snapshotDefinition(allocator, value.snapshot.object, value.snapshot.handle, policy);
            defer definition.deinit();
            var page = try catalog.scanRows(allocator, value.snapshot.object, value.snapshot.handle, value.after, value.limits, policy);
            defer page.deinit();
            const rows = try allocator.alloc(w.Binary, page.count);
            const scratch = try allocator.alloc(u8, c.fuze.TableRow.max_bytes);
            defer allocator.free(scratch);
            for (rows, 0..) |*row, i| row.* = try w.Binary.encode(allocator, try page.rows[i].?.row().encode(definition.schema.schema, scratch));
            return .{ .page = .{ .snapshot = value.snapshot, .interpretation = page.interpretation, .accepted = page.accepted, .changed_lsn = page.changed_lsn, .total_rows = page.total_rows, .rows = rows, .encoded_bytes = page.encoded_bytes, .next = page.next } };
        },
        .release => |value| {
            try catalog.releaseRows(value.object, value.handle, policy);
            return .released;
        },
    }
}

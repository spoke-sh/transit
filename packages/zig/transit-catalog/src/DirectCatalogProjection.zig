//! Owned host projections of retained interpretation and placement evidence.
//! One call is one bounded page; local cleanup never releases its saved pin.
const std = @import("std");
const c = @import("root.zig");
const h = c.DirectTableValues;
const v = c.TableValues;
const R = c.DirectCatalogRetention;
const P = c.storage.TablePartition;
const A = std.mem.Allocator;
pub const Cursor = struct {
    pub const json_schema_text_bounds = .{ .after = 40 };
    snapshot: R.Snapshot,
    after: []const u8,
};
pub const Input = struct { snapshot: R.Snapshot, after: ?Cursor };
pub const Action = union(enum) { definitions: Input, locations: Input };
pub const Column = struct {
    column: []const u8,
    source: union(enum) {
        physical: []const u8,
        initial: struct { definition: h.Interpretation, state: c.fuze.Types.State },
    },
};
pub const Definition = struct {
    pub const json_schema_sequence_bounds = .{ .columns = c.fuze.TableSchema.max_columns };
    physical: h.Stored,
    schema_revision: []const u8,
    rows: []const u8,
    columns: []const Column,
};
pub const Location = struct {
    identity: struct { origin: []const u8, operation: []const u8, ordinal: u32 },
    physical: h.Stored,
    schema_revision: []const u8,
    location: union(enum) {
        wal: struct { lsn: []const u8, offset: u32, bytes: u32, row_digest: []const u8 },
        segment: struct { id: []const u8, row: u32, content: h.Content },
    },
};
pub const Result = struct {
    snapshot: R.Snapshot,
    logical: h.Stored,
    accepted: h.Position,
    total_rows: []const u8,
    coverage: union(enum) {
        pub const json_schema_sequence_bounds = .{ .locations = 8 };
        definitions: ?Definition,
        locations: []const Location,
    },
    next: ?Cursor,
};

pub fn apply(allocator: A, client: c.DirectTableClient, action: Action) !Result {
    const input = switch (action) {
        inline else => |value| value,
    };
    const snapshot = try input.snapshot.native(client.connection);
    if (input.after) |cursor| if (!std.meta.eql(try cursor.snapshot.native(client.connection), snapshot)) return error.InvalidCatalogCursor;
    const request: c.DirectTableProtocol.Action = switch (action) {
        .definitions => .{ .projection_definitions = .{ .snapshot = snapshot, .after = if (input.after) |cursor| .{ .source = snapshot.handle.content, .after = try v.unsigned(cursor.after) } else null } },
        .locations => .{ .projection_locations = .{ .snapshot = snapshot, .after = if (input.after) |cursor| .{ .source = snapshot.handle.content, .after = try locationKey(cursor.after) } else null } },
    };
    const response = try client.call(request);
    defer response.deinit();
    return switch (response.value.result) {
        .projection_definitions => |page| blk: {
            const retained = try R.Snapshot.foreign(allocator, input.snapshot.owner, page.snapshot);
            var entry: ?Definition = null;
            if (page.entry) |value| {
                const columns = try allocator.alloc(Column, value.column_count);
                for (columns, value.columns[0..value.column_count]) |*out, slot| {
                    const column = slot.?;
                    out.* = .{ .column = try v.decimal(allocator, column.column), .source = switch (column.source) {
                        .physical => |id| .{ .physical = try v.decimal(allocator, id) },
                        .initial => |initial| .{ .initial = .{ .definition = try h.Interpretation.foreign(allocator, initial.definition), .state = initial.state } },
                    } };
                }
                entry = .{ .physical = try h.Stored.foreign(allocator, value.physical), .schema_revision = try v.decimal(allocator, value.schema_revision), .rows = try v.decimal(allocator, value.rows), .columns = columns };
            }
            break :blk .{ .snapshot = retained, .logical = try h.Stored.foreign(allocator, page.logical), .accepted = try h.Position.foreign(allocator, page.accepted), .total_rows = try v.decimal(allocator, page.total_rows), .coverage = .{ .definitions = entry }, .next = if (page.next) |next| .{ .snapshot = retained, .after = try v.decimal(allocator, next.after) } else null };
        },
        .projection_locations => |page| blk: {
            const retained = try R.Snapshot.foreign(allocator, input.snapshot.owner, page.snapshot);
            const entries = try allocator.alloc(Location, page.count);
            for (entries, page.entries[0..page.count]) |*out, slot| {
                const value = slot.?;
                out.* = .{ .identity = .{ .origin = try v.decimal(allocator, value.identity.origin), .operation = try v.decimal(allocator, value.identity.operation), .ordinal = value.identity.ordinal }, .physical = try h.Stored.foreign(allocator, value.physical), .schema_revision = try v.decimal(allocator, value.schema_revision), .location = switch (value.location) {
                    .wal => |wal| .{ .wal = .{ .lsn = try v.decimal(allocator, wal.lsn), .offset = wal.offset, .bytes = wal.bytes, .row_digest = try v.hex(allocator, &wal.row_digest) } },
                    .segment => |segment| .{ .segment = .{ .id = try v.decimal(allocator, segment.id), .row = segment.row, .content = try h.Content.foreign(allocator, segment.content) } },
                } };
            }
            break :blk .{ .snapshot = retained, .logical = try h.Stored.foreign(allocator, page.logical), .accepted = try h.Position.foreign(allocator, page.accepted), .total_rows = try v.decimal(allocator, page.total_rows), .coverage = .{ .locations = entries }, .next = if (page.next) |next| .{ .snapshot = retained, .after = try v.hex(allocator, &next.after) } else null };
        },
        else => error.InvalidTableResponse,
    };
}

fn locationKey(encoded: []const u8) ![c.fuze.TableRow.Identity.encoded_bytes]u8 {
    var key: [c.fuze.TableRow.Identity.encoded_bytes]u8 = undefined;
    if (encoded.len != key.len * 2) return error.InvalidCatalogCursor;
    _ = std.fmt.hexToBytes(&key, encoded) catch return error.InvalidCatalogCursor;
    var canonical: [key.len * 2]u8 = undefined;
    const text = std.fmt.bufPrint(&canonical, "{x}", .{&key}) catch unreachable;
    if (!std.mem.eql(u8, text, encoded)) return error.InvalidCatalogCursor;
    _ = try c.fuze.TableRow.Identity.decode(&key);
    return key;
}

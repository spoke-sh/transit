//! General application-owned Tables through the shared private-turn boundary.
//! The caller owns the result arena, stable intent and continuation scheduling.
const std = @import("std");
const s = @import("transit_station");
const c = @import("transit_catalog");
const f = s.fuze;
const p = s.protocol;
const v = c.TableValues;
const Allocator = std.mem.Allocator;
const Cell = f.LogicalJson.Cell;
pub const Source = struct { object: []const u8, version: ?p.Growth.ReadVersionId = null };
pub const Basis = struct { resource: u64, revision: u64, object: []const u8, head: []const u8 };
pub const Row = struct {
    identity: []const u8,
    cells: []const Cell,
    pub const json_schema_sequence_bounds = .{ .cells = f.TableSchema.max_columns };
};
pub const Page = struct {
    definition: Definition,
    rows: []const Row,
    next: ?[]const u8,
    pub const json_schema_sequence_bounds = .{ .rows = s.TableReader.max_page_rows };
};
pub const Definition = struct { schema: v.Schema, basis: Basis };
pub const Mutation = struct { realm: u64, resource: u64, principal: u64, operation: []const u8, schema: v.Schema, mutation: c.TableTyped.Mutation };
pub const Reference = struct {
    definition: p.Growth.Definition,
    realm: u64,
    resource: u64,
    object: []const u8,
    principal: u64,
    operation: []const u8,
    digest: []const u8,
    fn native(self: Reference, turn: *s.Turn) !s.TableWrite.Reference {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        if (self.realm != turn.delivery.realm or self.resource != turn.view.resource) return error.WrongResource;
        const result: s.TableWrite.Reference = .{ .resource = self.resource, .object = try v.unsigned(self.object), .principal = self.principal, .operation = try v.unsigned(self.operation), .digest = try v.digest(self.digest) };
        try result.validate();
        return result;
    }
    fn foreign(allocator: Allocator, realm: u64, value: s.TableWrite.Reference) !Reference {
        return .{ .definition = p.Growth.current_definition, .realm = realm, .resource = value.resource, .object = try v.decimal(allocator, value.object), .principal = value.principal, .operation = try v.decimal(allocator, value.operation), .digest = try v.hex(allocator, &value.digest) };
    }
};
pub const Status = struct {
    reference: Reference,
    state: @FieldType(s.TableWrite.Status, "state"),
    route: s.TableWrite.Status.Route,
    admitted_input: u64,
    completed_input: ?u64,
    counts: ?v.Counts,
    rejection: @FieldType(s.TableWrite.Status, "rejection"),
    witness: ?struct { source: f.TableWitness.Source, row: ?[]const u8, column: []const u8, text: []const u8, truncated: bool },
    fn foreign(allocator: Allocator, realm: u64, value: s.TableWrite.Status) !Status {
        try value.validate();
        return .{
            .reference = try Reference.foreign(allocator, realm, value.reference),
            .state = value.state,
            .route = value.route,
            .admitted_input = value.admitted_input,
            .completed_input = if (value.completed_input == 0) null else value.completed_input,
            .counts = if (value.state == .applied) .{ .matched = try v.decimal(allocator, value.matched), .changed = try v.decimal(allocator, value.changed) } else null,
            .rejection = value.rejection,
            .witness = if (value.witness.source == .none) null else .{
                .source = value.witness.source,
                .row = if (value.witness.source == .withheld) null else try v.hex(allocator, &try value.witness.row.encode()),
                .column = try v.decimal(allocator, value.witness.column),
                .text = try allocator.dupe(u8, value.witness.text()),
                .truncated = value.witness.truncated,
            },
        };
    }
};
pub const Action = union(enum) {
    create: struct { realm: u64, resource: u64, schema: v.Schema, limits: v.Configuration.Limits },
    schema: Source,
    get: struct { source: Source, identity: []const u8 },
    get_key: struct { source: Source, key: []const Cell },
    page: struct { source: Source, cursor: ?[]const u8 = null, limit: u8 = s.TableReader.max_page_rows },
    mutate: Mutation,
    status: Reference,
    cancel: Reference,
};
pub const Result = union(enum) {
    created: s.TableCreation.Result,
    schema: Definition,
    row: struct { definition: Definition, row: ?Row },
    page: Page,
    mutation: ?Status,
};
fn definition(arena: *std.heap.ArenaAllocator, table: *const s.TableReader) !Definition {
    const allocator = arena.allocator();
    return .{ .schema = try f.TableSchemaJson.foreign(arena, table.schema.schema), .basis = .{ .resource = table.basis.resource, .revision = table.basis.revision, .object = try v.decimal(allocator, table.basis.object), .head = try v.hex(allocator, &table.basis.head) } };
}
fn row(allocator: Allocator, schema: f.TableSchema.Schema, value: f.TableRow.Row) !Row {
    try schema.validateRow(value.cells);
    const cells = try allocator.alloc(Cell, value.cells.len);
    for (cells, value.cells, schema.columns) |*output, input, column| output.* = try f.LogicalJson.foreignCell(allocator, input, column.type);
    return .{ .identity = try v.hex(allocator, &try value.identity.encode()), .cells = cells };
}
fn identity(allocator: Allocator, text: []const u8) !f.TableRow.Identity {
    if (text.len != 2 * f.TableRow.Identity.encoded_bytes) return error.InvalidRowIdentity;
    const bytes = try v.unhex(allocator, text, f.TableRow.Identity.encoded_bytes);
    return f.TableRow.Identity.decode(bytes[0..f.TableRow.Identity.encoded_bytes]);
}
fn read(arena: *std.heap.ArenaAllocator, source: anytype, object: u64, action: Action) !Result {
    const allocator = arena.allocator();
    var table = try s.TableReader.open(allocator, source, object);
    defer table.deinit();
    const metadata = try definition(arena, &table);
    switch (action) {
        .schema => return .{ .schema = metadata },
        .get, .get_key => {
            var found = switch (action) {
                .get => |value| try table.get(allocator, source, try identity(allocator, value.identity)),
                .get_key => |value| blk: {
                    const schema = table.schema.schema;
                    if (value.key.len != schema.primary_key.len or value.key.len == 0) return error.InvalidPrimaryKey;
                    const cells = try allocator.alloc(f.Types.Values.Cell, value.key.len);
                    for (value.key, cells, schema.primary_key) |input, *output, column| output.* = try f.LogicalJson.fromForeign(allocator, input, schema.columns[try schema.index(column)].field());
                    break :blk try table.getKey(allocator, source, cells);
                },
                else => unreachable,
            };
            defer if (found) |*value| value.deinit();
            return .{ .row = .{ .definition = metadata, .row = if (found) |*value| try row(allocator, table.schema.schema, value.row()) else null } };
        },
        .page => |value| {
            const cursor = if (value.cursor) |encoded| blk: {
                if (encoded.len == 0 or encoded.len > 2048) return error.InvalidCursor;
                const parsed = try std.json.parseFromSlice(s.TableReader.Cursor, allocator, encoded, .{});
                defer parsed.deinit();
                const canonical = try std.json.Stringify.valueAlloc(allocator, parsed.value, .{});
                if (!std.mem.eql(u8, encoded, canonical)) return error.InvalidCursor;
                break :blk parsed.value;
            } else null;
            var page = try table.page(allocator, source, cursor, value.limit);
            defer page.deinit();
            const rows = try allocator.alloc(Row, page.len);
            for (rows, page.rows[0..page.len]) |*output, item| output.* = try row(allocator, table.schema.schema, item.?.row());
            return .{ .page = .{ .definition = metadata, .rows = rows, .next = if (page.next) |next| try std.json.Stringify.valueAlloc(allocator, next, .{}) else null } };
        },
        else => unreachable,
    }
}
/// All returned bytes belong to arena. No action commits, loops until complete,
/// grants permission, invents a durable intent identity or schedules an input.
/// Caller policy governs any later disclosure of application-owned rows/witnesses.
pub fn apply(arena: *std.heap.ArenaAllocator, turn: *s.Turn, action: Action) !Result {
    const before = turn.decision;
    errdefer turn.decision = before;
    const allocator = arena.allocator();
    switch (action) {
        .create => |value| {
            if (value.realm != turn.delivery.realm or value.resource != turn.view.resource) return error.WrongResource;
            return .{ .created = try s.TableCreation.step(allocator, turn, try f.TableSchemaJson.native(arena, value.schema), try value.limits.native()) };
        },
        .schema, .get, .get_key, .page => {
            const input: Source = switch (action) {
                .schema => |value| value,
                inline .get, .get_key, .page => |value| value.source,
                else => unreachable,
            };
            const object = try v.unsigned(input.object);
            if (input.version) |id| {
                var source = try turn.openVersion(id);
                return read(arena, &source, object, action);
            }
            return read(arena, turn, object, action);
        },
        .mutate => |value| {
            if (value.realm != turn.delivery.realm or value.resource != turn.view.resource) return error.WrongResource;
            const schema = try f.TableSchemaJson.native(arena, value.schema);
            const plan = try c.TableTyped.plan(arena, schema, "table", value.mutation);
            const request: s.TableStatement.Request = .{ .resource = turn.view.resource, .principal = value.principal, .operation = try v.unsigned(value.operation), .plan = plan };
            return .{ .mutation = try Status.foreign(allocator, turn.delivery.realm, try s.TableStatement.step(allocator, turn, request)) };
        },
        .status => |value| {
            const reference = try value.native(turn);
            const result = try s.TableWrite.status(turn, reference);
            return .{ .mutation = if (result) |stored| try Status.foreign(allocator, turn.delivery.realm, stored) else null };
        },
        .cancel => |value| return .{ .mutation = try Status.foreign(allocator, turn.delivery.realm, try s.TableStatement.cancel(turn, try value.native(turn))) },
    }
}

//! Lossless, bounded caller interface over the shared interactive executor.
//! A handle is ephemeral. Only the current page can be repeated; its ordinal
//! advances explicitly, and every disclosure rechecks all current sources.
const std = @import("std");
const q = @import("root.zig");
const f = q.fuze;
const r = f.Relational;
const v = q.catalog.TableValues;
const h = q.catalog.DirectTableValues;
const c = q.catalog;
const Allocator = std.mem.Allocator;
pub const Options = struct {
    consistency: q.DirectRelationalQuery.Consistency,
    resident_bytes: []const u8,
    spill_bytes: []const u8,
    result_bytes: []const u8,
    output_rows: []const u8,
    work_steps: []const u8,
    source_pins: u8,
    requests: []const u8,
    spill_work: []const u8,
    pub fn native(self: Options) !q.DirectRelationalQuery.Options {
        const result: q.DirectRelationalQuery.Options = .{ .consistency = self.consistency, .budgets = .{
            .resident_bytes = try v.unsigned(self.resident_bytes),
            .spill_bytes = try v.unsigned(self.spill_bytes),
            .result_bytes = try v.unsigned(self.result_bytes),
            .output_rows = try v.unsigned(self.output_rows),
            .work_steps = try v.unsigned(self.work_steps),
            .source_pins = self.source_pins,
        }, .requests = try v.unsigned(self.requests), .spill_work = try v.unsigned(self.spill_work) };
        if (result.consistency != .independent_table_snapshots) return error.UnsupportedRelationalConsistency;
        if (result.budgets.resident_bytes <= q.DirectRelationalQuery.resident_base or result.budgets.resident_bytes > std.math.maxInt(usize)) return error.RelationalResidentBudget;
        if (result.budgets.result_bytes == 0 or result.budgets.output_rows == 0 or result.budgets.work_steps == 0 or result.requests == 0 or result.spill_work == 0 or self.source_pins == 0 or self.source_pins > r.max_sources) return error.InvalidRelationalBudgets;
        return result;
    }
};
pub const Config = struct {
    definition: q.protocol.Growth.Definition,
    catalogs: []const h.Connection,
    service_url: ?[]const u8 = null,
    options: Options,
    spill_directory: []const u8,
    pub const json_schema_sequence_bounds = .{ .catalogs = r.max_sources };
};
pub const Statement = struct {
    namespace: u64 = 1,
    sql: []const u8,
    /// Configured catalog indices, one per FROM/JOIN target in SQL order.
    routes: []const u16,
    pub const json_schema_sequence_bounds = .{ .routes = r.max_sources };
};
pub const Open = struct {
    id: []const u8,
    statement: Statement,
    bindings: []const h.PreparedBinding,
    snapshots: []const c.DirectCatalogRetention.Snapshot,
    pub const json_schema_sequence_bounds = .{ .bindings = r.max_sources, .snapshots = r.max_sources };
};
pub const Reference = struct { definition: q.protocol.Growth.Definition, id: []const u8, plan: []const u8, basis: []const u8 };
pub const Action = union(enum) {
    capabilities,
    explain: Statement,
    open: Open,
    page: struct { reference: Reference, ordinal: []const u8 },
    close: Reference,
};
pub const Capabilities = struct {
    definition: q.protocol.Growth.Definition = q.protocol.Growth.current_definition,
    sources: u8 = r.max_sources,
    active_queries: u8 = 1,
    page_rows: u8 = 1,
    interactive: bool = true,
    captured: bool = false,
    maintained: bool = false,
    consistency: q.DirectRelationalQuery.Consistency = .independent_table_snapshots,
};
pub const Source = struct { alias: []const u8, binding: h.PreparedBinding, position: h.Position };
pub const Cut = struct { object: h.Object, position: h.Position, commitment: []const u8, schema: []const u8 };
pub const Description = struct {
    definition: q.protocol.Growth.Definition = q.protocol.Growth.current_definition,
    plan: []const u8,
    sources: []const Source,
    columns: []const f.QueryValues.Column,
    join: ?@FieldType(r.Join, "kind"),
    grouped: bool,
    executed: bool = false,
    pub const json_schema_sequence_bounds = .{ .sources = r.max_sources, .columns = r.max_outputs };
};
pub const Opened = struct {
    reference: Reference,
    description: Description,
    cuts: []const Cut,
    complete_coverage: bool = false,
    pub const json_schema_sequence_bounds = .{ .cuts = r.max_sources };
};
pub const GroupScalar = union(enum) { signed: []const u8, utf8: []const u8 };
pub const Identity = union(enum) {
    pair: struct { left: []const u8, right: ?[]const u8 },
    group: []const ?GroupScalar,
    pub const json_schema_sequence_bounds = .{ .group = r.max_groups };
};
pub const Row = struct {
    identity: Identity,
    cells: []const f.LogicalJson.Cell,
    pub const json_schema_sequence_bounds = .{ .cells = r.max_outputs };
};
pub const Page = struct { reference: Reference, ordinal: []const u8, row: ?Row, complete_coverage: bool };
pub const Result = union(enum) { capabilities: Capabilities, explained: Description, opened: Opened, page: Page, closed };
fn id(text: []const u8) ![16]u8 {
    if (text.len != 32) return error.InvalidQueryRequest;
    for (text) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.InvalidQueryRequest;
    var result: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, text) catch return error.InvalidQueryRequest;
    if (std.mem.allEqual(u8, &result, 0)) return error.InvalidQueryRequest;
    return result;
}
fn describe(allocator: Allocator, plan: r.Plan, bindings: []const c.DirectTableBinding, positions: []const q.protocol.DataLifecycle.Position) !Description {
    var fields: [r.max_outputs]f.Types.Field = undefined;
    const sources = try allocator.alloc(Source, plan.sources.len);
    for (sources, plan.sources, bindings, positions) |*out, source, binding, position| out.* = .{ .alias = try allocator.dupe(u8, source.alias), .binding = try h.PreparedBinding.foreign(allocator, binding), .position = try h.Position.foreign(allocator, position) };
    var grouped = plan.group_by.len != 0;
    for (plan.outputs) |output| if (output.expression != .column) {
        grouped = true;
    };
    return .{ .plan = try v.hex(allocator, &try plan.fingerprint()), .sources = sources, .columns = try f.QueryValues.foreignColumns(allocator, try plan.outputSchema(&fields)), .join = if (plan.join) |join| join.kind else null, .grouped = grouped };
}
pub fn row(allocator: Allocator, value: f.RelationalExecution.Output, schema: f.Types.Type) !Row {
    if (schema != .structure or schema.structure.len != value.len) return error.InvalidQuerySchema;
    const cells = try allocator.alloc(f.LogicalJson.Cell, value.len);
    for (cells, value.cells[0..value.len], schema.structure) |*out, cell, field| out.* = try f.LogicalJson.foreignCell(allocator, cell, field.type);
    return .{ .cells = cells, .identity = switch (value.identity) {
        .pair => |pair| .{ .pair = .{ .left = try v.hex(allocator, &try pair.left.encode()), .right = if (pair.right) |right| try v.hex(allocator, &try right.encode()) else null } },
        .group => |group| blk: {
            const keys = try allocator.alloc(?GroupScalar, group.len);
            for (keys, group.values[0..group.len]) |*out, key| out.* = if (key) |scalar| switch (scalar) {
                .integer => |number| .{ .signed = try std.fmt.allocPrint(allocator, "{d}", .{number}) },
                .text => |text| .{ .utf8 = try allocator.dupe(u8, text) },
            } else null;
            break :blk .{ .group = keys };
        },
    } };
}
/// Owns no clients or directory. The host serializes calls, joins them before
/// destruction, and keeps these borrowed dependencies alive until deinit.
pub const Session = struct {
    allocator: Allocator,
    io: std.Io,
    directory: std.Io.Dir,
    clients: []const c.DirectTableClient,
    options: q.DirectRelationalQuery.Options,
    closed: ?struct { id: [16]u8, plan: [32]u8, basis: [32]u8 } = null,
    active: ?struct {
        query: *q.DirectRelationalQuery,
        bindings: [r.max_sources]c.DirectTableBinding,
        positions: [r.max_sources]q.protocol.DataLifecycle.Position,
        id: [16]u8,
        input: [32]u8,
        plan: [32]u8,
        basis: [32]u8,
        ordinal: u64 = 0,
        read: bool = false,
        pending: ?f.RelationalExecution.Output = null,
        failure: ?anyerror = null,
    } = null,
    pub fn deinit(self: *Session) void {
        if (self.active) |*active| {
            if (active.pending) |*pending| pending.deinit();
            active.query.deinit();
        }
        self.active = null;
    }
    pub const Progress = struct { opened: Opened, ordinal: []const u8, read: bool };
    /// Inspect this host's current query under all current source rights. This
    /// does not advance execution or restore a query lost with an earlier host.
    pub fn current(self: *Session, allocator: Allocator) !?Progress {
        const active = self.active orelse return null;
        return .{ .opened = try self.opened(allocator), .ordinal = try v.decimal(allocator, active.ordinal), .read = active.read };
    }
    fn opened(self: *Session, allocator: Allocator) !Opened {
        const active = self.active orelse return error.InvalidQueryCursor;
        const query = active.query;
        try query.tables.validate(query.execution.bound);
        const cuts = try allocator.alloc(Cut, query.execution.bound.cuts.len);
        for (cuts, query.execution.bound.cuts, active.bindings[0..cuts.len], active.positions[0..cuts.len]) |*out, cut, binding, position| out.* = .{ .object = try h.Object.foreign(allocator, binding.interpretation.interpretation.object), .position = try h.Position.foreign(allocator, position), .commitment = try v.hex(allocator, &cut.commitment), .schema = try v.hex(allocator, &cut.schema) };
        return .{ .reference = try self.reference(allocator), .description = try describe(allocator, query.execution.bound.plan, active.bindings[0..cuts.len], active.positions[0..cuts.len]), .cuts = cuts };
    }
    fn selected(self: *Session, statement: Statement, storage: *[r.max_sources]c.DirectTableClient) ![]const c.DirectTableClient {
        if (self.clients.len == 0 or self.clients.len > r.max_sources or statement.routes.len == 0 or statement.routes.len > r.max_sources) return error.InvalidRelationalSources;
        try c.Model.nativeId(statement.namespace);
        for (statement.routes, 0..) |route, i| {
            if (route >= self.clients.len) return error.InvalidRelationalSources;
            storage[i] = self.clients[route];
        }
        return storage[0..statement.routes.len];
    }
    fn reference(self: *Session, allocator: Allocator) !Reference {
        const active = self.active orelse return error.InvalidQueryCursor;
        return .{ .definition = q.protocol.Growth.current_definition, .id = try v.hex(allocator, &active.id), .plan = try v.hex(allocator, &active.plan), .basis = try v.hex(allocator, &active.basis) };
    }
    fn check(self: *Session, ref: Reference) !void {
        if (ref.definition != q.protocol.Growth.current_definition) return error.IncompatibleDefinition;
        const active = self.active orelse return error.InvalidQueryCursor;
        if (!std.mem.eql(u8, &try id(ref.id), &active.id) or !std.mem.eql(u8, &(v.digest(ref.plan) catch return error.QueryIdentityMismatch), &active.plan) or !std.mem.eql(u8, &(v.digest(ref.basis) catch return error.QueryIdentityMismatch), &active.basis)) return error.QueryIdentityMismatch;
    }
    /// Attach only caller-known progress until current disclosure succeeds.
    /// A saved executor witness never bypasses a later source revocation.
    pub fn diagnostic(self: *Session, action: Action, cause: anyerror, detail: *q.protocol.Diagnostic) void {
        if (action != .page) return;
        self.check(action.page.reference) catch return;
        const active = &self.active.?;
        detail.fact(.completion, .execution, .{ .boolean = false }) catch {};
        if (v.unsigned(action.page.ordinal)) |ordinal| {
            detail.fact(.step, .caller, .{ .unsigned = .init(ordinal) }) catch {};
        } else |_| {}
        const original = active.failure orelse return;
        if (original != cause) return;
        active.query.tables.validate(active.query.execution.bound) catch return;
        const failed = active.query.execution.failure orelse return;
        const plan = active.query.execution.bound.plan;
        if (failed.output >= plan.outputs.len) return;
        const output = plan.outputs[failed.output];
        detail.text(.column, .schema, output.name) catch {};
        detail.fact(.expression, .execution, .{ .unsigned = .init(failed.output) }) catch {};
        detail.fact(.source_basis, .execution, .{ .digest = active.basis }) catch {};
        var buffer: [96]u8 = undefined;
        const keys = if (failed.pair.right) |right|
            std.fmt.bufPrint(&buffer, "{s}:{s}", .{ std.fmt.bytesToHex(failed.pair.left.encode() catch return, .lower), std.fmt.bytesToHex(right.encode() catch return, .lower) }) catch return
        else
            std.fmt.bufPrint(&buffer, "{s}", .{std.fmt.bytesToHex(failed.pair.left.encode() catch return, .lower)}) catch return;
        detail.text(.source_key, .execution, keys) catch {};
    }
    pub fn apply(self: *Session, allocator: Allocator, action: Action, location: ?*f.Sql.Location) !Result {
        var routes: [r.max_sources]c.DirectTableClient = undefined;
        switch (action) {
            .capabilities => return .{ .capabilities = .{} },
            .explain => |statement| {
                const compilation = try q.DirectRelationalCompilation.prepare(self.allocator, try self.selected(statement, &routes), statement.namespace, statement.sql, .interactive, self.options, location);
                defer compilation.deinit();
                return .{ .explained = try describe(allocator, compilation.plan, compilation.bindings[0..compilation.plan.sources.len], compilation.positions[0..compilation.plan.sources.len]) };
            },
            .open => |input| {
                const nonce = try id(input.id);
                const clients = try self.selected(input.statement, &routes);
                if (input.bindings.len != clients.len or input.snapshots.len != clients.len) return error.InvalidRelationalSources;
                var bindings: [r.max_sources]c.DirectTableBinding = undefined;
                var snapshots: [r.max_sources]c.DirectTableProtocol.Snapshot = undefined;
                for (input.bindings, input.snapshots, clients, 0..) |binding, snapshot, client, i| {
                    if (!std.meta.eql(client.connection, clients[0].connection) or client.service != clients[0].service or client.authority != clients[0].authority) return error.RelationalCallerChanged;
                    bindings[i] = binding.native() catch return error.InvalidQueryRequest;
                    snapshots[i] = snapshot.native(client.connection) catch return error.InvalidQueryRequest;
                    if (!std.meta.eql(bindings[i].connection, client.connection)) return error.RelationalCallerChanged;
                }
                var temporary = std.heap.ArenaAllocator.init(self.allocator);
                defer temporary.deinit();
                const encoded = try q.protocol.Json.valueAlloc(temporary.allocator(), input);
                var hasher = std.crypto.hash.sha2.Sha256.init(.{});
                hasher.update("transit.direct.relational.caller.v1\x00");
                hasher.update(encoded);
                const fingerprint = hasher.finalResult();
                if (self.active) |active| {
                    if (!std.mem.eql(u8, &active.id, &nonce) or !std.mem.eql(u8, &active.input, &fingerprint)) return error.QueryIdentityMismatch;
                } else {
                    if (self.closed) |previous| if (std.mem.eql(u8, &previous.id, &nonce)) return error.QueryIdentityMismatch;
                    const prepared = try q.DirectRelationalCompilation.fromRetained(self.allocator, clients[0], input.statement.namespace, input.statement.sql, bindings[0..clients.len], snapshots[0..clients.len], self.options, location);
                    defer prepared.deinit();
                    // The spill owner creates an exclusive private file and
                    // immediately unlinks it. Names never become recovery state.
                    var name: [64]u8 = undefined;
                    const filename = try std.fmt.bufPrint(&name, "transit-relational-{s}", .{input.id});
                    const query = try q.DirectRelationalQuery.openPreparedRetained(self.allocator, self.io, self.directory, filename, clients[0], prepared, snapshots[0..clients.len], self.options, null);
                    errdefer query.deinit();
                    self.active = .{ .query = query, .bindings = prepared.bindings, .positions = prepared.positions, .id = nonce, .input = fingerprint, .plan = try query.execution.bound.plan.fingerprint(), .basis = try query.execution.bound.fingerprint() };
                }
                return .{ .opened = try self.opened(allocator) };
            },
            .page => |input| {
                try self.check(input.reference);
                const ordinal = v.unsigned(input.ordinal) catch return error.InvalidQueryCursor;
                const active = &self.active.?;
                const next = active.read and active.pending != null and ordinal > active.ordinal and ordinal - active.ordinal == 1;
                if (ordinal != active.ordinal and !next) return error.InvalidQueryCursor;
                // A cached row is still source-derived disclosure.
                try active.query.tables.validate(active.query.execution.bound);
                if (active.failure) |failure| return failure;
                if (!active.read or next) {
                    if (active.pending) |*pending| pending.deinit();
                    active.pending = null;
                    // Advancing acknowledges the previous row. Retain the
                    // requested ordinal even when execution fails, so repeating
                    // that fetch returns its original failure under current rights.
                    active.ordinal = ordinal;
                    active.read = true;
                    const value = active.query.next() catch |err| {
                        active.failure = err;
                        return err;
                    };
                    active.pending = value;
                }
                var fields: [r.max_outputs]f.Types.Field = undefined;
                const schema = try active.query.execution.bound.plan.outputSchema(&fields);
                // Retain the native row before any caller-result allocation.
                // Output/encoding failure can repeat the identical ordinal.
                return .{ .page = .{ .reference = try self.reference(allocator), .ordinal = try v.decimal(allocator, ordinal), .row = if (active.pending) |value| try row(allocator, value, schema) else null, .complete_coverage = active.pending == null and active.query.complete } };
            },
            .close => |ref| {
                if (self.active == null) {
                    if (ref.definition != q.protocol.Growth.current_definition) return error.IncompatibleDefinition;
                    const previous = self.closed orelse return error.InvalidQueryCursor;
                    if (!std.mem.eql(u8, &try id(ref.id), &previous.id) or !std.mem.eql(u8, &(v.digest(ref.plan) catch return error.QueryIdentityMismatch), &previous.plan) or !std.mem.eql(u8, &(v.digest(ref.basis) catch return error.QueryIdentityMismatch), &previous.basis)) return error.QueryIdentityMismatch;
                    return .closed;
                }
                try self.check(ref);
                self.active.?.query.close();
                self.closed = .{ .id = self.active.?.id, .plan = self.active.?.plan, .basis = self.active.?.basis };
                self.deinit();
                return .closed;
            },
        }
    }
};

test "relational neutral options and references reject lossy and foreign input before I/O" {
    const t = std.testing;
    try t.expectError(error.InvalidQueryRequest, id("ABCDEF00000000000000000000000001"));
    try t.expectError(error.InvalidQueryRequest, id("00000000000000000000000000000000"));
    const options: Options = .{ .consistency = .independent_table_snapshots, .resident_bytes = "8388608", .spill_bytes = "18446744073709551615", .result_bytes = "1048576", .output_rows = "18446744073709551615", .work_steps = "100000", .source_pins = 2, .requests = "100000", .spill_work = "100000" };
    try t.expectEqual(std.math.maxInt(u64), (try options.native()).budgets.output_rows);
    var invalid = options;
    invalid.output_rows = "01";
    try t.expectError(error.InvalidCatalogInteger, invalid.native());
    var session: Session = .{ .allocator = t.allocator, .io = t.io, .directory = .cwd(), .clients = &.{}, .options = try options.native() };
    defer session.deinit();
    try t.expectError(error.InvalidRelationalSources, session.apply(t.allocator, .{ .open = .{ .id = "00000000000000000000000000000001", .statement = .{ .sql = "SELECT COUNT(*) FROM t", .routes = &.{0} }, .bindings = &.{}, .snapshots = &.{} } }, null));
}

test "neutral output keeps full-width bag identity and exact signed and unsigned cells" {
    const t = std.testing;
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    var output: f.RelationalExecution.Output = .{ .identity = .{ .pair = .{ .left = .{ .origin = std.math.maxInt(u64), .operation = std.math.maxInt(u64), .ordinal = std.math.maxInt(u32) }, .right = null } }, .len = 3 };
    output.cells[0] = .{ .value = .{ .atom = .{ .signed = std.math.minInt(i64) } } };
    output.cells[1] = .{ .value = .{ .atom = .{ .unsigned = std.math.maxInt(u64) } } };
    output.cells[2] = .null;
    const schema: f.Types.Type = .{ .structure = &.{ .{ .name = "signed", .type = .int64 }, .{ .name = "count", .type = .uint64 }, .{ .name = "nullable", .type = .int64, .nullable = true } } };
    const foreign = try row(arena.allocator(), output, schema);
    try t.expectEqualStrings("ffffffffffffffffffffffffffffffffffffffff", foreign.identity.pair.left);
    try t.expect(foreign.identity.pair.right == null);
    try t.expectEqualStrings("-9223372036854775808", foreign.cells[0].value.atom.signed);
    try t.expectEqualStrings("18446744073709551615", foreign.cells[1].value.atom.unsigned);
    try t.expect(foreign.cells[2] == .null);
    const json = try std.json.Stringify.valueAlloc(arena.allocator(), foreign, .{});
    const parsed = try f.QueryValues.parse(Row, arena.allocator(), json);
    try t.expectEqualDeep(foreign, parsed.value);
}

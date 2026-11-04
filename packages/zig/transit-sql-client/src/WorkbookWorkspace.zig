//! Bounded temporary relation graphs over the shared SQL reader and Fuze plans.
//! Hosts serialize apply. This owner creates no catalog objects or durable work.
const std = @import("std");
const s = @import("root.zig");
const f = @import("transit_fuze");
const r = s.results;
const g = s.WorkbookGraph;
const Self = @This();
pub const capacity = 2;
pub const max_rows = 10000;
pub const max_value_bytes = 16 * 1024 * 1024;
pub const max_sources = 8;
pub const evaluations = 32;
pub const lifetime_ms = 300000;
pub const Request = struct {
    definition: s.protocol.native.Definition,
    action: union(enum) {
        describe,
        validate: struct {
            pub const json_schema_sequence_bounds = .{ .cells = g.max_cells };
            cells: []const g.Cell,
        },
        open: []const u8,
        evaluate: Evaluation,
        status: struct { id: []const u8, sequence: u32 },
        observe: struct { id: []const u8, cell: []const u8, result: []const u8, offset: u32 = 0 },
        close: []const u8,
    },
};
pub const Evaluation = struct {
    pub const json_schema_sequence_bounds = .{ .cells = g.max_cells, .targets = g.max_cells };
    id: []const u8,
    sequence: u32,
    cells: []const g.Cell,
    targets: []const []const u8,
    affected: bool = false,
    force: bool = false,
};
pub const Result = struct { cell: []const u8, result: []const u8, sql: []const u8, name: []const u8, input: ?[]const u8 };
pub const Status = struct {
    pub const json_schema_sequence_bounds = .{ .results = g.max_cells };
    id: []const u8,
    sequence: u32,
    remaining: u8,
    results: []const Result,
    failure: ?struct { cell: []const u8, code: []const u8 } = null,
};
pub const Response = union(enum) {
    description: struct { definition: s.protocol.native.Definition = s.protocol.native.current_definition, cells: u8 = g.max_cells, rows: u32 = max_rows, value_bytes: u32 = max_value_bytes, evaluations: u8 = evaluations, lifetime_ms: u32 = lifetime_ms, namespace: []const u8 = "workbook." },
    validation: g.Validation,
    status: Status,
    result: struct { id: []const u8, cell: []const u8, sequence: u32, binding: Result, view: s.ReadView.View },
    closed,
};
allocator: std.mem.Allocator,
io: std.Io,
config: s.Client.Config,
slots: [capacity]?*Session = @splat(null),
pub fn deinit(self: *Self) void {
    for (&self.slots) |*slot| if (slot.*) |session| {
        session.destroy();
        slot.* = null;
    };
}
fn expire(self: *Self) void {
    for (&self.slots) |*slot| if (slot.*) |session| {
        if (session.opened.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() >= lifetime_ms) {
            session.destroy();
            slot.* = null;
        }
    };
}
fn find(self: *Self, id: []const u8) !*Session {
    for (self.slots) |slot| if (slot) |session| {
        if (std.mem.eql(u8, &session.id, id)) return session;
    };
    return error.WorkbookExpired;
}
pub fn apply(self: *Self, allocator: std.mem.Allocator, request: Request) !Response {
    if (request.definition != s.protocol.native.current_definition) return error.IncompatibleSqlDefinition;
    self.expire();
    if (request.action == .describe) return .{ .description = .{} };
    if (request.action == .validate) return .{ .validation = (try g.analyze(allocator, request.action.validate.cells)).validation };
    const id = switch (request.action) {
        .describe, .validate => unreachable,
        .open, .close => |id| id,
        inline .evaluate, .status, .observe => |value| value.id,
    };
    if (!g.validId(id)) return error.InvalidWorkbookIdentity;
    if (request.action == .close) {
        for (&self.slots) |*slot| if (slot.*) |session| {
            if (std.mem.eql(u8, &session.id, id)) {
                session.destroy();
                slot.* = null;
            }
        };
        return .closed;
    }
    if (request.action == .open) {
        _ = self.find(id) catch blk: {
            const slot = for (&self.slots) |*slot| {
                if (slot.* == null) break slot;
            } else return error.WorkbookCapacity;
            slot.* = try Session.create(self, id);
            break :blk slot.*.?;
        };
    }
    const session = try self.find(id);
    return applySession(session, allocator, request) catch |err| {
        if (err == error.SqlObservationDenied or err == error.AuthenticationFailed) session.clear();
        return err;
    };
}
fn applySession(session: *Session, allocator: std.mem.Allocator, request: Request) !Response {
    switch (request.action) {
        .evaluate => |input| try session.evaluate(allocator, input),
        .status => |input| if (input.sequence != session.sequence) {
            return error.WorkbookSequenceConflict;
        },
        .observe => |input| {
            const output = session.output(input.cell) orelse return error.WorkbookResultUnavailable;
            const identity = try hex(allocator, output.identity);
            if (!std.mem.eql(u8, identity, input.result)) return error.WorkbookResultChanged;
            return .{ .result = .{ .id = &session.id, .cell = input.cell, .sequence = session.sequence, .binding = try output.binding(allocator), .view = try output.view(allocator, input.offset) } };
        },
        .open => {},
        else => unreachable,
    }
    return .{ .status = try session.status(allocator) };
}
fn hex(allocator: std.mem.Allocator, value: [32]u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{x}", .{&value});
}
fn digest(value: []const u8) [32]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(value, &hash, .{});
    return hash;
}
const Session = struct {
    host: *Self,
    id: [32]u8,
    opened: std.Io.Timestamp,
    memory: f.MemoryBudget,
    sources: u8 = 0,
    remaining: u8 = evaluations,
    sequence: u32 = 0,
    request_hash: [32]u8 = @splat(0),
    outputs: [g.max_cells]?*Output = @splat(null),
    failure: ?struct { cell: [32]u8, code: []const u8 } = null,
    fn create(host: *Self, id: []const u8) !*Session {
        const self = try host.allocator.create(Session);
        self.* = .{ .host = host, .id = id[0..32].*, .opened = std.Io.Clock.awake.now(host.io), .memory = .{ .parent = host.allocator, .limit = max_value_bytes } };
        return self;
    }
    fn clear(self: *Session) void {
        for (&self.outputs) |*slot| if (slot.*) |value| {
            value.release();
            slot.* = null;
        };
    }
    fn destroy(self: *Session) void {
        self.clear();
        self.host.allocator.destroy(self);
    }
    fn output(self: *Session, id: []const u8) ?*Output {
        for (self.outputs) |slot| if (slot) |value| {
            if (std.mem.eql(u8, value.cell.id, id)) return value;
        };
        return null;
    }
    fn evaluate(self: *Session, allocator: std.mem.Allocator, input: Evaluation) !void {
        const hash = digest(try s.protocol.Json.valueAlloc(allocator, input));
        if (input.sequence == self.sequence) {
            if (!std.mem.eql(u8, &hash, &self.request_hash)) return error.WorkbookSequenceConflict;
            return;
        }
        if (input.sequence != self.sequence + 1 or input.sequence > 128) return error.WorkbookSequenceConflict;
        const graph = try g.analyze(allocator, input.cells);
        if (graph.validation.issue != null) return error.InvalidWorkbookGraph;
        if (input.targets.len == 0 or input.targets.len > g.max_cells) return error.InvalidWorkbookTargets;
        var selected: [g.max_cells]bool = @splat(false);
        for (input.targets) |id| {
            const index = for (graph.cells, 0..) |cell, i| {
                if (std.mem.eql(u8, id, cell.id)) break i;
            } else return error.InvalidWorkbookTargets;
            selected[index] = true;
        }
        self.sequence = input.sequence;
        self.request_hash = hash;
        self.failure = null;
        // Retire removed cell handles; retained downstream relations still own
        // their exact earlier inputs until their own replacement/closure.
        for (&self.outputs) |*slot| if (slot.*) |old| {
            const kept = for (graph.cells) |cell| {
                if (std.mem.eql(u8, cell.id, old.cell.id)) break true;
            } else false;
            if (!kept) {
                old.release();
                slot.* = null;
            }
        };
        var wanted = selected;
        if (input.affected) for (graph.cells, 0..) |_, i| {
            for (selected[0..graph.cells.len], 0..) |yes, changed| {
                if (yes and graph.affects(changed, i)) wanted[i] = true;
            }
        };
        var done: [g.max_cells]bool = @splat(false);
        for (wanted[0..graph.cells.len], 0..) |yes, i| if (yes) {
            _ = self.evaluateCell(graph, i, &done, selected, input.force) catch |err| {
                if (err == error.SqlObservationDenied or err == error.AuthenticationFailed) return err;
                if (self.failure == null) self.failure = .{ .cell = graph.cells[i].id[0..32].*, .code = @errorName(err) };
                return;
            };
        };
    }
    fn evaluateCell(self: *Session, graph: g.Graph, index: usize, done: *[g.max_cells]bool, selected: [g.max_cells]bool, force: bool) anyerror!*Output {
        const cell = graph.cells[index];
        if (done[index]) return self.output(cell.id) orelse error.WorkbookResultUnavailable;
        const input = if (graph.inputs[index]) |upstream| try self.evaluateCell(graph, upstream, done, selected, force) else null;
        const old = self.output(cell.id);
        if (old) |previous| {
            if (!(force and selected[index]) and previous.matches(cell, input)) {
                try previous.validate();
                done[index] = true;
                return previous;
            }
        }
        if (self.remaining == 0) return error.WorkbookBudgetExhausted;
        self.remaining -= 1;
        const next = (if (input) |source| Output.derive(self, cell, graph.targets[index], source) else Output.read(self, cell)) catch |err| {
            if (self.failure == null) self.failure = .{ .cell = cell.id[0..32].*, .code = @errorName(err) };
            return err;
        };
        const slot = for (&self.outputs) |*slot| {
            if (slot.* == old and old != null) break slot;
        } else for (&self.outputs) |*slot| {
            if (slot.* == null) break slot;
        } else unreachable;
        slot.* = next;
        if (old) |previous| previous.release();
        done[index] = true;
        return next;
    }
    fn status(self: *Session, allocator: std.mem.Allocator) !Status {
        var list: std.ArrayList(Result) = .empty;
        for (self.outputs) |slot| if (slot) |value| {
            try value.validate();
            try list.append(allocator, try value.binding(allocator));
        };
        return .{ .id = &self.id, .sequence = self.sequence, .remaining = self.remaining, .results = list.items, .failure = if (self.failure) |*failure| .{ .cell = &failure.cell, .code = failure.code } else null };
    }
};
const Output = struct {
    session: *Session,
    refs: u8 = 1,
    arena: std.heap.ArenaAllocator,
    cell: g.Cell,
    identity: [32]u8 = undefined,
    schema: r.Types.Type = undefined,
    rows: std.ArrayList([]const r.Types.Values.Cell) = .empty,
    input: ?*Output = null,
    source: ?*s.ReadSession = null,
    outcome: ?*s.Executor.Outcome = null,
    fn create(session: *Session, cell: g.Cell) !*Output {
        const self = try session.memory.allocator().create(Output);
        self.* = .{ .session = session, .arena = .init(session.memory.allocator()), .cell = undefined };
        errdefer {
            self.arena.deinit();
            session.memory.allocator().destroy(self);
        }
        const a = self.arena.allocator();
        self.cell = .{ .id = try a.dupe(u8, cell.id), .name = try a.dupe(u8, cell.name), .sql = try a.dupe(u8, cell.sql) };
        return self;
    }
    fn release(self: *Output) void {
        self.refs -= 1;
        if (self.refs != 0) return;
        if (self.input) |input| input.release();
        if (self.outcome) |outcome| outcome.deinit();
        if (self.source) |source| {
            source.close();
            self.session.sources -= 1;
        }
        const allocator = self.session.memory.allocator();
        self.arena.deinit();
        allocator.destroy(self);
    }
    fn matches(self: *Output, cell: g.Cell, input: ?*Output) bool {
        return self.input == input and std.mem.eql(u8, self.cell.name, cell.name) and std.mem.eql(u8, self.cell.sql, cell.sql);
    }
    fn validate(self: *Output) !void {
        if (self.input) |input| return input.validate();
        try self.outcome.?.value.rows.validateDisclosure();
    }
    fn append(self: *Output, cells: []const r.Types.Values.Cell) !void {
        if (self.rows.items.len == max_rows) return error.WorkbookRowBudget;
        const a = self.arena.allocator();
        const copy = try a.alloc(r.Types.Values.Cell, cells.len);
        for (cells, copy) |cell, *value| value.* = try r.Types.Values.cloneValidated(a, cell);
        try self.rows.append(a, copy);
    }
    fn read(session: *Session, cell: g.Cell) !*Output {
        if (session.sources == max_sources) return error.WorkbookSourceCapacity;
        const self = try create(session, cell);
        errdefer self.release();
        self.source = try s.ReadSession.open(session.host.allocator, session.host.io, session.host.config);
        session.sources += 1;
        self.outcome = try self.source.?.executor.read(cell.sql, .{});
        const outcome = self.outcome.?;
        if (outcome.value == .failure) return if (outcome.value.failure.denied()) error.SqlObservationDenied else error.SqlReadRejected;
        if (outcome.value != .rows or outcome.value.rows.observation != .data) return error.WorkbookDataRelationRequired;
        try self.collect(&outcome.value.rows);
        return self;
    }
    fn collect(self: *Output, result: *r.ResultSet) !void {
        try result.holdDisclosure();
        self.schema = (try result.schema.clone(self.arena.allocator())).type;
        self.identity = result.progress.identity.result;
        while (try result.nextRow()) |row| {
            if (self.session.opened.durationTo(std.Io.Clock.awake.now(self.session.host.io)).toMilliseconds() >= lifetime_ms) return error.WorkbookExpired;
            try self.append(row);
        }
        const completion = result.completion() orelse return error.WorkbookIncompleteInput;
        if (completion.rows != self.rows.items.len) return error.WorkbookIncompleteInput;
        try self.validate();
    }
    fn derive(session: *Session, cell: g.Cell, target: []const u8, input: *Output) !*Output {
        try input.validate();
        const self = try create(session, cell);
        errdefer self.release();
        self.input = input;
        input.refs += 1;
        const a = self.arena.allocator();
        const plan = try f.TableSelect.planDiagnostic(a, cell.sql, target, input.schema, input.identity, null);
        self.identity = try plan.fingerprint();
        var fields: [128]r.Types.Field = undefined;
        self.schema = (try (try plan.outputSchema(&fields)).clone(a)).type;
        var counters: f.LogicalQuery.Counters = .{};
        var scalar: f.LogicalQuery.Scalar.Workspace = .{};
        try plan.scalars.prepare(plan.schema.structure, &scalar);
        var failure: ?f.LogicalQuery.Counters.FailureSite = null;
        var projected: [128]r.Types.Values.Cell = undefined;
        for (input.rows.items) |row| {
            if (!try counters.observePrepared(plan, row, &scalar, &failure)) continue;
            if (plan.aggregate == .rows) {
                for (plan.projection, 0..) |column, i| projected[i] = plan.evaluated(row, &scalar)[column];
                try self.append(projected[0..plan.projection.len]);
            }
        }
        if (plan.aggregate != .rows) try self.append(&.{try counters.result(plan)});
        try self.validate();
        return self;
    }
    fn binding(self: *Output, allocator: std.mem.Allocator) !Result {
        return .{ .cell = self.cell.id, .result = try hex(allocator, self.identity), .sql = self.cell.sql, .name = self.cell.name, .input = if (self.input) |input| try hex(allocator, input.identity) else null };
    }
    fn view(self: *Output, allocator: std.mem.Allocator, offset: u32) !s.ReadView.View {
        if (offset > self.rows.items.len) return error.InvalidReadPosition;
        try self.validate();
        const end = @min(self.rows.items.len, offset + s.ReadView.max_rows);
        const rows = try allocator.alloc([]const f.LogicalJson.Cell, end - offset);
        for (self.rows.items[offset..end], rows) |row, *out| {
            const cells = try allocator.alloc(f.LogicalJson.Cell, row.len);
            for (row, cells, self.schema.structure) |value, *converted, field| converted.* = try f.LogicalJson.foreignCell(allocator, value, field.type);
            out.* = cells;
        }
        var root = self;
        while (root.input) |input| root = input;
        // The canonical observation is the original source evidence. Binding
        // supplies the exact local derivation; it is never a new snapshot claim.
        return .{ .result = try hex(allocator, self.identity), .columns = self.schema.structure, .rows = rows, .observation = try s.protocol.Json.valueAlloc(allocator, root.outcome.?.value.rows.observation), .observation_kind = .data, .start = try std.fmt.allocPrint(allocator, "{d}", .{offset}), .delivered = try std.fmt.allocPrint(allocator, "{d}", .{end}), .complete_rows = try std.fmt.allocPrint(allocator, "{d}", .{self.rows.items.len}), .stopped = if (end == self.rows.items.len) .complete else .row_limit };
    }
};

test "workspace capacity, graph validation and closure do not open SQL sessions" {
    const t = std.testing;
    var host: Self = .{ .allocator = t.allocator, .io = t.io, .config = .{ .endpoint = "http://127.0.0.1:1", .authentication = .trust, .account = "reader", .database = "db" } };
    defer host.deinit();
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const definition = s.protocol.native.current_definition;
    for ([_][]const u8{ "00000000000000000000000000000001", "00000000000000000000000000000002" }) |id| {
        const response = try host.apply(a, .{ .definition = definition, .action = .{ .open = id } });
        try t.expectEqual(@as(u8, evaluations), response.status.remaining);
        try t.expectEqual(@as(u8, 0), (try host.find(id)).sources);
    }
    try t.expectError(error.WorkbookCapacity, host.apply(a, .{ .definition = definition, .action = .{ .open = "00000000000000000000000000000003" } }));
    _ = try host.apply(a, .{ .definition = definition, .action = .{ .close = "00000000000000000000000000000001" } });
    try t.expectError(error.WorkbookExpired, host.apply(a, .{ .definition = definition, .action = .{ .status = .{ .id = "00000000000000000000000000000001", .sequence = 0 } } }));
}

const Oracle = struct {
    count: u64 = 145,
    at: u64 = 0,
    denied: bool = false,
    incomplete: bool = false,
    cells: [2]r.Types.Values.Cell = undefined,
    row: [1]r.Row = undefined,
    label: [16]u8 = undefined,
    fn next(context: *anyopaque) anyerror!r.ResultSet.Chunk {
        const self: *Oracle = @ptrCast(@alignCast(context));
        if (self.incomplete and self.at == self.count) return error.UnexpectedEof;
        if (self.at == self.count) return .{ .values = .{}, .completion = .{ .rows = self.count } };
        const name = try std.fmt.bufPrint(&self.label, "row-{d}", .{self.at});
        self.cells = .{ .{ .value = .{ .atom = .{ .signed = self.at } } }, .{ .value = .{ .atom = .{ .bytes = name } } } };
        self.row[0] = &self.cells;
        self.at += 1;
        return .{ .values = .fromRows(&self.row), .completion = if (!self.incomplete and self.at == self.count) .{ .rows = self.count } else null };
    }
    fn validate(context: *anyopaque) !void {
        const self: *Oracle = @ptrCast(@alignCast(context));
        if (self.denied) return error.SqlObservationDenied;
    }
    fn close(_: *anyopaque) !void {}
    fn deinit(_: *anyopaque) void {}
    fn output(self: *Oracle, session: *Session) !*Output {
        const value = try Output.create(session, .{ .id = "00000000000000000000000000000001", .name = "source", .sql = "SELECT * FROM metrics" });
        errdefer value.release();
        const allocator = session.host.allocator;
        const outcome = try allocator.create(s.Executor.Outcome);
        outcome.* = .{ .parent = allocator, .memory = .{ .parent = allocator, .limit = 1024 * 1024 }, .arena = undefined, .value = undefined };
        outcome.arena = .init(outcome.memory.allocator());
        const schema: r.Types.Type = .{ .structure = &.{ .{ .name = "id", .type = .int64 }, .{ .name = "label", .type = .utf8 } } };
        const observation: r.Observation.Value = .{ .data = .{ .source = .{ .kind = .table, .resource = 7, .position = .{ .native_revision = 1 }, .contract = @splat(1), .schema = try schema.fingerprint() } } };
        outcome.value = .{ .rows = try r.ResultSet.init(schema, observation, .{ .result = @splat(1), .schema = try schema.fingerprint(), .observation = try r.Observation.fingerprint(allocator, observation) }, .{ .context = self, .next = next, .close = close, .deinit = Oracle.deinit, .validate_disclosure = validate }) };
        value.outcome = outcome;
        try value.collect(&outcome.value.rows);
        return value;
    }
};
test "complete owned inputs outlive reused fetch scratch; chains exceed display windows and recheck rights" {
    const t = std.testing;
    var host: Self = .{ .allocator = t.allocator, .io = t.io, .config = .{ .endpoint = "http://127.0.0.1:1", .authentication = .trust, .account = "reader", .database = "db" } };
    const session = try Session.create(&host, "00000000000000000000000000000001");
    defer session.destroy();
    var oracle: Oracle = .{};
    const input = try oracle.output(session);
    defer input.release();
    try t.expectEqual(@as(usize, 145), input.rows.items.len);
    try t.expectEqualStrings("row-0", input.rows.items[0][1].value.atom.bytes);
    try t.expectEqualStrings("row-144", input.rows.items[144][1].value.atom.bytes);
    const filtered = try Output.derive(session, .{ .id = "00000000000000000000000000000002", .name = "filtered", .sql = "SELECT id FROM \"workbook.source\" WHERE id >= 100" }, "workbook.source", input);
    defer filtered.release();
    const counted = try Output.derive(session, .{ .id = "00000000000000000000000000000003", .name = "counted", .sql = "SELECT COUNT(*) AS n FROM \"workbook.filtered\"" }, "workbook.filtered", filtered);
    defer counted.release();
    try t.expectEqual(@as(u128, 45), counted.rows.items[0][0].value.atom.unsigned);
    var arena: std.heap.ArenaAllocator = .init(t.allocator);
    defer arena.deinit();
    const view = try input.view(arena.allocator(), 0);
    try t.expectEqual(@as(usize, 100), view.rows.len);
    try t.expectEqualStrings("145", view.complete_rows.?);
    oracle.denied = true;
    try t.expectError(error.SqlObservationDenied, counted.view(arena.allocator(), 0));
    try t.expectError(error.SqlObservationDenied, Output.derive(session, .{ .id = "00000000000000000000000000000004", .name = "copy", .sql = "SELECT * FROM \"workbook.counted\"" }, "workbook.counted", counted));
}
test "incomplete prefixes and row or allocation budgets never produce reusable inputs" {
    const t = std.testing;
    var host: Self = .{ .allocator = t.allocator, .io = t.io, .config = .{ .endpoint = "http://127.0.0.1:1", .authentication = .trust, .account = "reader", .database = "db" } };
    const session = try Session.create(&host, "00000000000000000000000000000001");
    defer session.destroy();
    var oracle: Oracle = .{ .incomplete = true };
    try t.expectError(error.UnexpectedEof, oracle.output(session));
    try t.expectEqual(@as(usize, 0), session.memory.used);
    oracle = .{ .count = max_rows + 1 };
    try t.expectError(error.WorkbookRowBudget, oracle.output(session));
    try t.expectEqual(@as(usize, 0), session.memory.used);
    oracle = .{};
    session.memory.limit = 4096;
    try t.expectError(error.OutOfMemory, oracle.output(session));
    try t.expectEqual(@as(usize, 0), session.memory.used);
}

//! Counter data acceptance is separate from its native progress and replies.
//! The installer supplies an existing Table; application turns retain the exact
//! staged reference before a committed continuation can dispatch that operation.
const std = @import("std");
const q = @import("transit_serving").query;
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const f = q.fuze;
const w = c.DirectTableProtocol;

pub const Binding = struct {
    definition: p.Growth.Definition,
    scope: p.DataLifecycle.Scope,
    branch: u64,
    audience: u64,
    namespace: u64,
    object: u64,
    role: ?u64,

    pub fn connection(self: Binding, principal: u64) !w.Connection {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target().validate();
        try c.Model.nativeId(self.namespace);
        const value: w.Connection = .{ .scope = self.scope, .branch = self.branch, .audience = self.audience, .principal = principal, .role = self.role };
        try value.validate();
        return value;
    }
    pub fn target(self: Binding) p.DataLifecycle.Object {
        return .{ .scope = self.scope, .branch = self.branch, .object = self.object };
    }
    pub fn bind(self: Binding, turn: *s.Turn, initialize: bool) !void {
        _ = try self.connection(turn.delivery.principal);
        if (self.scope.realm != turn.delivery.realm) return error.CounterDataBindingChanged;
        var bytes: [2048]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("CDB1");
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        const address = try p.Value.init("\x00counter.data");
        var stored: [2048]u8 = undefined;
        if (try turn.readBlock(address, &stored)) |value| {
            if (!std.mem.eql(u8, value, writer.buffered())) return error.CounterDataBindingChanged;
        } else if (initialize) {
            try turn.writeBlock(address, writer.buffered());
        } else return error.CounterInitializationRequired;
    }
};

/// Production always delegates to the public signed direct client. The explicit
/// exchange seam lets domain tests compose the actual catalog dispatcher.
pub const Client = struct {
    context: *anyopaque,
    connection: w.Connection,
    exchange: *const fn (*anyopaque, w.Connection, w.Action) anyerror!std.json.Parsed(w.Response),
    pub fn call(self: Client, action: w.Action) !std.json.Parsed(w.Response) {
        return self.exchange(self.context, self.connection, action);
    }
    pub fn direct(client: *c.DirectTableClient) Client {
        return .{ .context = client, .connection = client.connection, .exchange = http };
    }
    fn http(raw: *anyopaque, connection: w.Connection, action: w.Action) !std.json.Parsed(w.Response) {
        const client: *c.DirectTableClient = @ptrCast(@alignCast(raw));
        if (!std.meta.eql(connection, client.connection)) return error.CounterDataBindingChanged;
        return client.call(action);
    }
};
pub const Definition = struct {
    response: std.json.Parsed(w.Response),
    value: w.Definition,
    pub fn deinit(self: *Definition) void {
        self.response.deinit();
        self.* = undefined;
    }
};
pub fn definition(client: Client, binding: Binding, schema: f.TableSchema.Schema) !Definition {
    if (!std.meta.eql(try binding.connection(client.connection.principal), client.connection)) return error.CounterDataBindingChanged;
    const lookup = try client.call(.{ .lookup = .{ .namespace = binding.namespace, .name = "counter" } });
    defer lookup.deinit();
    const found = lookup.value.result.lookup orelse return error.CounterInitializationRequired;
    if (!std.meta.eql(found.interpretation.interpretation.object, binding.target()) or
        !std.mem.eql(u8, &found.interpretation.schema_fingerprint, &try schema.fingerprint())) return error.CounterSchemaChanged;
    const observed = try client.call(.{ .observe = .{ .namespace = binding.namespace, .interpretation = found.interpretation.interpretation, .rows = null } });
    return .{ .response = observed, .value = observed.value.result.observation.definition };
}
pub const Row = struct { identity: f.TableRow.Identity, key: i64, value: i64 };
pub fn get(allocator: std.mem.Allocator, client: Client, metadata: w.Definition, schema: f.TableSchema.Schema, key: i64) !?Row {
    var scratch: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = key } } }}, false, &scratch));
    defer allocator.free(encoded.base64);
    const response = try client.call(.{ .read_current = .{ .namespace = metadata.namespace, .interpretation = metadata.interpretation.interpretation, .expected = metadata.position, .selection = .{ .key = encoded } } });
    defer response.deinit();
    const binary = response.value.result.current_read.selection.key orelse return null;
    const bytes = try binary.decode(allocator, f.TableRow.max_bytes);
    defer allocator.free(bytes);
    var owned = try f.TableRow.decode(allocator, schema, bytes);
    defer owned.deinit();
    const row = owned.row();
    if (row.cells.len != 2) return error.InvalidCounterValue;
    for (row.cells) |cell| if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidCounterValue;
    if (row.cells[0].value.atom.signed != key) return error.InvalidCounterValue;
    return .{ .identity = row.identity, .key = key, .value = std.math.cast(i64, row.cells[1].value.atom.signed) orelse return error.InvalidCounterValue };
}
pub fn mutation(allocator: std.mem.Allocator, client: Client, metadata: w.Definition, schema: f.TableSchema.Schema, input: u64, value: Row, insert: bool) !c.DirectTableIntent {
    const row: f.TableRow.Row = .{ .identity = value.identity, .cells = &.{ .{ .value = .{ .atom = .{ .signed = value.key } } }, .{ .value = .{ .atom = .{ .signed = value.value } } } } };
    var row_bytes: [4096]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try row.encode(schema, &row_bytes));
    defer allocator.free(encoded.base64);
    var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const key_value = try w.Binary.encode(allocator, try row.storageKey(schema, &key_bytes));
    defer allocator.free(key_value.base64);
    var work: w.Rows = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = input }, .target = metadata.interpretation.interpretation.object, .action = if (insert) .insert else .update, .expected_definition = metadata.interpretation.interpretation, .expected_data = metadata.position, .prerequisite = null, .intent = @splat(0) },
        .interpretation = metadata.interpretation,
        .schema = metadata.schema,
        .changes = &.{if (insert) .{ .insert = encoded } else .{ .update = .{ .key = key_value, .row = encoded } }},
        .ingestion = .point,
    };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    work.binding.intent = try work.digest(arena.allocator());
    return c.DirectTableIntent.create(allocator, client.connection, .{ .rows = work });
}
pub fn stage(client: Client, intent: *const c.DirectTableIntent, namespace: u64) !c.DirectTableIntent.Reference {
    try intent.check(client.connection);
    const expected = try intent.reference(namespace);
    const response = try client.call(.{ .stage = .{ .namespace = namespace, .intent = intent.parsed.value } });
    defer response.deinit();
    try expected.requireSame(response.value.result.staged);
    return response.value.result.staged;
}
pub const Dispatch = struct {
    resource: u64,
    worker: u64,
    input: u64,
    invocation: [32]u8,
    reference: c.DirectTableIntent.Reference,
    fn validate(self: Dispatch) !void {
        try c.Model.nativeId(self.resource);
        try c.Model.nativeId(self.worker);
        try c.Model.nativeId(self.input);
        try self.reference.validate();
        if (self.reference.binding.identity.operation != self.input or
            (self.reference.binding.action != .insert and self.reference.binding.action != .update)) return error.InvalidCounterDispatch;
    }
};
const max_record_bytes = 16 * 1024;
fn dispatchKey(input: u64) p.Value {
    var bytes: [12]u8 = undefined;
    bytes[0..4].* = "\x00CDI".*;
    std.mem.writeInt(u64, bytes[4..], input, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn inspect(allocator: std.mem.Allocator, reader: anytype, worker: u64, input: u64) !?Dispatch {
    var buffer: [max_record_bytes]u8 = undefined;
    const bytes = (try reader.readBlock(dispatchKey(input), &buffer)) orelse return null;
    if (bytes.len <= 36 or !std.mem.eql(u8, bytes[0..4], "CDI1")) return error.InvalidCounterDispatch;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Dispatch, allocator, bytes[36..]);
    defer parsed.deinit();
    const value = parsed.value;
    try value.validate();
    if (value.resource != reader.view.resource or value.worker != worker or value.input != input) return error.InvalidCounterDispatch;
    return value;
}
pub fn prepare(allocator: std.mem.Allocator, turn: *s.Turn, record: Dispatch) !void {
    try record.validate();
    if (record.resource != turn.view.resource or record.worker != turn.delivery.pid or record.input > turn.delivery.input.position or record.reference.connection.principal != turn.delivery.principal) return error.InvalidCounterDispatch;
    if (try inspect(allocator, turn, record.worker, record.input)) |existing| {
        if (!std.meta.eql(existing, record)) return error.DataIdentityConflict;
        return;
    }
    var bytes: [max_record_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("CDI1");
    try writer.writeAll(&p.Growth.definition_bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    try turn.writeBlock(dispatchKey(record.input), writer.buffered());
}
pub const Outcome = union(enum) { pending, committed: c.storage.TablePartition.Evidence, rejected, cancelled };
fn outcome(result: w.Result) !Outcome {
    if (result != .rows) return error.InvalidCounterDataResponse;
    return switch (result.rows) {
        .not_observed, .admitted => .pending,
        .committed => |evidence| .{ .committed = evidence },
        .rejected => .rejected,
        .cancelled => .cancelled,
    };
}
pub fn advance(allocator: std.mem.Allocator, turn: *s.Turn, client: Client, input: u64, invocation: [32]u8) !Outcome {
    var committed = turn.committed();
    const record = (try inspect(allocator, &committed, turn.delivery.pid, input)) orelse return error.CounterDispatchNotCommitted;
    if (!std.mem.eql(u8, &record.invocation, &invocation) or !std.meta.eql(record.reference.connection, client.connection)) return error.DataIdentityConflict;
    const inspected = try client.call(.{ .operation = .{ .binding = record.reference.binding, .command = .inspect, .steps = 1 } });
    defer inspected.deinit();
    const current = try outcome(inspected.value.result);
    if (current != .pending) return current;
    const response = try client.call(if (inspected.value.result.rows == .not_observed)
        .{ .admit_saved = record.reference }
    else
        .{ .operation = .{ .binding = record.reference.binding, .command = .execute, .steps = 32 } });
    defer response.deinit();
    return outcome(response.value.result);
}

//! The ledger's explicit direct Table binding and native dispatch eligibility.
//! Direct acceptance and the application's audit/reply are separate commits.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const f = q.fuze;

pub const Binding = struct {
    definition: p.Growth.Definition,
    scope: d.Scope,
    branch: u64,
    audience: u64,
    namespace: u64,
    object: u64,
    owner_role: u64,
    executor: u64,

    pub fn validate(self: Binding) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.target().validate();
        try c.Model.nativeId(self.namespace);
        try c.Model.nativeId(self.executor);
        try p.Authorization.roleId(self.owner_role);
        try (w.Connection{ .scope = self.scope, .branch = self.branch, .audience = self.audience, .principal = 0, .role = null }).validate();
    }
    pub fn target(self: Binding) d.Object {
        return .{ .scope = self.scope, .branch = self.branch, .object = self.object };
    }
    pub fn client(self: Binding, allocator: std.mem.Allocator, authority: s.client.AuthorizationClient) !c.DirectTableClient {
        try self.validate();
        if (authority.realm != self.scope.realm) return error.InvalidLedgerDataBinding;
        return .{ .allocator = allocator, .authority = authority.transport, .service = authority.transport, .key = authority.key, .connection = .{ .scope = self.scope, .branch = self.branch, .audience = self.audience, .principal = authority.principal, .role = authority.role } };
    }
    /// Configuration is part of the application declaration. Restart cannot
    /// silently redirect previously accepted ledger work to another Table.
    pub fn bind(self: Binding, turn: *s.Turn, initialize: bool) !void {
        try self.validate();
        if (self.scope.realm != turn.delivery.realm) return error.InvalidLedgerDataBinding;
        var bytes: [2048]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("LDB1");
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(self, &encoder);
        const binding_key = try p.Value.init("\x00ledger.data");
        var stored: [2048]u8 = undefined;
        if (try turn.readBlock(binding_key, &stored)) |value| {
            if (!std.mem.eql(u8, value, writer.buffered())) return error.LedgerDataBindingChanged;
        } else if (initialize) {
            try turn.writeBlock(binding_key, writer.buffered());
        } else return error.MissingLedgerDataBinding;
    }
};

pub const Definition = struct {
    response: std.json.Parsed(w.Response),
    value: w.Definition,
    authority: c.DirectReadAuthority,
    pub fn deinit(self: *Definition) void {
        self.response.deinit();
        self.* = undefined;
    }
};
pub fn definition(client: c.DirectTableClient, binding: Binding, schema: f.TableSchema.Schema) !Definition {
    const lookup = try client.call(.{ .lookup = .{ .namespace = binding.namespace, .name = "ledger" } });
    defer lookup.deinit();
    const found = lookup.value.result.lookup orelse return error.LedgerInitializationRequired;
    if (!std.meta.eql(found.interpretation.interpretation.object, binding.target()) or
        !std.mem.eql(u8, &found.interpretation.schema_fingerprint, &try schema.fingerprint())) return error.LedgerSchemaChanged;
    const observed = try client.call(.{ .observe = .{ .namespace = binding.namespace, .interpretation = found.interpretation.interpretation, .rows = null } });
    errdefer observed.deinit();
    return .{ .response = observed, .value = observed.value.result.observation.definition, .authority = observed.value.result.observation.authority };
}
pub const Row = struct { identity: f.TableRow.Identity, amount: i64 };
pub fn get(allocator: std.mem.Allocator, client: c.DirectTableClient, metadata: w.Definition, schema: f.TableSchema.Schema) !?Row {
    var scratch: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try f.Collation.encodePrimaryKeySortKey(schema, &.{.{ .value = .{ .atom = .{ .signed = 1 } } }}, false, &scratch));
    defer allocator.free(encoded.base64);
    const response = try client.call(.{ .read_current = .{ .namespace = metadata.namespace, .interpretation = metadata.interpretation.interpretation, .expected = metadata.position, .selection = .{ .key = encoded } } });
    defer response.deinit();
    const binary = response.value.result.current_read.selection.key orelse return null;
    const bytes = try binary.decode(allocator, f.TableRow.max_bytes);
    defer allocator.free(bytes);
    var owned = try f.TableRow.decode(allocator, schema, bytes);
    defer owned.deinit();
    const row = owned.row();
    if (row.cells.len != 2) return error.InvalidLedgerValue;
    for (row.cells) |cell| if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidLedgerValue;
    if (row.cells[0].value.atom.signed != 1) return error.InvalidLedgerValue;
    return .{ .identity = row.identity, .amount = std.math.cast(i64, row.cells[1].value.atom.signed) orelse return error.InvalidLedgerValue };
}
pub fn creation(allocator: std.mem.Allocator, client: c.DirectTableClient, binding: Binding, schema: f.TableSchema.Schema, input: u64, prerequisite: p.Authorization.Guard) !c.DirectTableIntent {
    var scratch: [f.TableSchema.max_bytes]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try schema.encode(&scratch));
    defer allocator.free(encoded.base64);
    var work: w.Ddl = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = binding.scope, .principal = client.connection.principal, .operation = input }, .target = binding.target(), .action = .create, .expected_definition = null, .expected_data = null, .prerequisite = prerequisite, .intent = @splat(0) },
        .namespace = binding.namespace,
        .name = "ledger",
        .action = .{ .create = .{ .owner = binding.owner_role, .schema = encoded } },
    };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    work.binding.intent = try work.digest(arena.allocator());
    return c.DirectTableIntent.create(allocator, client.connection, .{ .ddl = work });
}
pub fn mutation(allocator: std.mem.Allocator, client: c.DirectTableClient, metadata: w.Definition, schema: f.TableSchema.Schema, input: u64, value: Row, insert: bool, prerequisite: p.Authorization.Guard) !c.DirectTableIntent {
    const identity: d.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = input };
    const row: f.TableRow.Row = .{ .identity = value.identity, .cells = &.{ .{ .value = .{ .atom = .{ .signed = 1 } } }, .{ .value = .{ .atom = .{ .signed = value.amount } } } } };
    var row_bytes: [4096]u8 = undefined;
    const encoded = try w.Binary.encode(allocator, try row.encode(schema, &row_bytes));
    defer allocator.free(encoded.base64);
    var key_bytes: [f.Collation.max_sort_key_bytes]u8 = undefined;
    const key_value = try w.Binary.encode(allocator, try row.storageKey(schema, &key_bytes));
    defer allocator.free(key_value.base64);
    var work: w.Rows = .{
        .binding = .{ .definition = p.Growth.current_definition, .identity = identity, .target = metadata.interpretation.interpretation.object, .action = if (insert) .insert else .update, .expected_definition = metadata.interpretation.interpretation, .expected_data = metadata.position, .prerequisite = prerequisite, .intent = @splat(0) },
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

pub const Purpose = enum { create, delta };
pub const Dispatch = struct {
    resource: u64,
    worker: u64,
    input: u64,
    purpose: Purpose,
    reference: c.DirectTableIntent.Reference,

    fn validate(self: Dispatch) !void {
        try c.Model.nativeId(self.resource);
        try c.Model.nativeId(self.worker);
        try c.Model.nativeId(self.input);
        try self.reference.validate();
        if (self.reference.binding.identity.operation != self.input or self.reference.binding.prerequisite == null) return error.InvalidLedgerDispatch;
        if ((self.purpose == .create) != (self.reference.binding.action == .create)) return error.InvalidLedgerDispatch;
        if (self.purpose == .delta and self.reference.binding.action != .insert and self.reference.binding.action != .update) return error.InvalidLedgerDispatch;
        if (self.reference.binding.prerequisite.?.subject.audience() != self.worker) return error.InvalidLedgerDispatch;
    }
};
const max_record_bytes = 16 * 1024;
fn key(input: u64) p.Value {
    var bytes: [12]u8 = undefined;
    bytes[0..4].* = "\x00LDI".*;
    std.mem.writeInt(u64, bytes[4..], input, .big);
    return p.Value.init(&bytes) catch unreachable;
}
pub fn inspect(allocator: std.mem.Allocator, reader: anytype, worker: u64, input: u64) !?Dispatch {
    var buffer: [max_record_bytes]u8 = undefined;
    const bytes = (try reader.readBlock(key(input), &buffer)) orelse return null;
    if (bytes.len <= 36 or !std.mem.eql(u8, bytes[0..4], "LDI1")) return error.InvalidLedgerDispatch;
    if (!std.mem.eql(u8, bytes[4..36], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const parsed = try p.Json.parseFromSlice(Dispatch, allocator, bytes[36..]);
    defer parsed.deinit();
    const value = parsed.value;
    try value.validate();
    if (value.resource != reader.view.resource or value.worker != worker or value.input != input) return error.InvalidLedgerDispatch;
    return value;
}
/// Staging immutable bytes is not admission. The caller commits the returned
/// reference and eligibility with its native application progress before advance.
pub fn stage(client: c.DirectTableClient, intent: *const c.DirectTableIntent, namespace: u64) !c.DirectTableIntent.Reference {
    try intent.check(client.connection);
    const expected = try intent.reference(namespace);
    const response = try client.call(.{ .stage = .{ .namespace = namespace, .intent = intent.parsed.value } });
    defer response.deinit();
    try expected.requireSame(response.value.result.staged);
    return response.value.result.staged;
}
pub fn prepare(allocator: std.mem.Allocator, turn: *s.Turn, record: Dispatch) !void {
    try record.validate();
    if (record.resource != turn.view.resource or record.worker != turn.delivery.pid or record.input > turn.delivery.input.position or record.reference.connection.principal != turn.delivery.principal) return error.InvalidLedgerDispatch;
    if (try inspect(allocator, turn, record.worker, record.input)) |existing| {
        if (!std.meta.eql(existing, record)) return error.DataIdentityConflict;
        return;
    }
    _ = try turn.requireAuthorization(record.reference.binding.prerequisite.?);
    var bytes: [max_record_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll("LDI1");
    try writer.writeAll(&p.Growth.definition_bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(record, &encoder);
    try turn.writeBlock(key(record.input), writer.buffered());
}
pub const Outcome = union(enum) { pending, committed: c.storage.TablePartition.Evidence, rejected, cancelled };
fn outcome(result: w.Result) !Outcome {
    return switch (result) {
        inline .ddl, .rows => |value| switch (value) {
            .not_observed, .admitted => .pending,
            .committed => |evidence| .{ .committed = evidence },
            .rejected => .rejected,
            .cancelled => .cancelled,
        },
        else => error.InvalidLedgerDataResponse,
    };
}
/// Reopen committed native state before dispatch. A private proposal cannot
/// authorize admission, and an uncertain response never chooses another intent.
pub fn advance(allocator: std.mem.Allocator, turn: *s.Turn, client: c.DirectTableClient, input: u64, purpose: Purpose) !Outcome {
    var committed = turn.committed();
    const record = (try inspect(allocator, &committed, turn.delivery.pid, input)) orelse return error.LedgerDispatchNotCommitted;
    if (record.purpose != purpose or !std.meta.eql(record.reference.connection, client.connection)) return error.DataIdentityConflict;
    const inspected = try client.call(.{ .operation = .{ .binding = record.reference.binding, .command = .inspect, .steps = 1 } });
    defer inspected.deinit();
    const current = try outcome(inspected.value.result);
    if (current != .pending) return current;
    const unseen = switch (inspected.value.result) {
        inline .ddl, .rows => |value| value == .not_observed,
        else => unreachable,
    };
    const response = try client.call(if (unseen) .{ .admit_saved = record.reference } else .{ .operation = .{ .binding = record.reference.binding, .command = .execute, .steps = 32 } });
    defer response.deinit();
    return outcome(response.value.result);
}

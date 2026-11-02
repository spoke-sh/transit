//! Application binding and committed dispatch records for the direct data owner.
//! Native progress and Table acceptance are separate decisions. Private turn
//! proposals can stage immutable bytes but cannot authorize their admission.
const std = @import("std");
const q = @import("transit_query");
const c = q.catalog;
const s = q.station;
const p = q.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;

pub const Binding = struct {
    definition: [32]u8,
    scope: d.Scope,
    branch: u64,
    audience: u64,
    namespace: u64,
    first_object: u64,
    owner_role: u64,

    pub fn validate(self: Binding) !void {
        if (!std.mem.eql(u8, &self.definition, &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        try (w.Connection{ .scope = self.scope, .branch = self.branch, .audience = self.audience, .principal = 0, .role = null }).validate();
        try c.Model.nativeId(self.namespace);
        try p.Authorization.roleId(self.owner_role);
        if (self.first_object == 0) return error.InvalidWorkItemDataBinding;
    }
    pub fn object(self: Binding, table: u32) !d.Object {
        try self.validate();
        if (table == 0) return error.InvalidWorkItemPlan;
        return .{ .scope = self.scope, .branch = self.branch, .object = try std.math.add(u64, self.first_object, table - 1) };
    }
    pub fn connection(self: Binding, principal: u64, role: ?u64) !w.Connection {
        try self.validate();
        const value: w.Connection = .{ .scope = self.scope, .branch = self.branch, .audience = self.audience, .principal = principal, .role = role };
        try value.validate();
        return value;
    }
};

/// A local application composition seam. Production always uses Http, which
/// signs and validates through the public client. Domain tests can compose the
/// actual catalog dispatcher with an explicitly injected authorization provider.
pub const Transport = struct {
    context: *anyopaque,
    principal: u64,
    role: ?u64 = null,
    select_owner: bool = false,
    exchange: *const fn (*anyopaque, w.Connection, w.Action) anyerror!std.json.Parsed(w.Response),
    pub fn bind(self: Transport, binding: Binding) !Client {
        return .{ .transport = self, .connection = try binding.connection(self.principal, if (self.select_owner) binding.owner_role else self.role) };
    }
};
pub const Http = struct {
    allocator: std.mem.Allocator,
    resources: s.client.ResourceReader,
    role: ?u64 = null,
    select_owner: bool = false,
    pub fn transport(self: *Http) Transport {
        return .{ .context = self, .principal = self.resources.principal, .role = self.role, .select_owner = self.select_owner, .exchange = exchange };
    }
    /// Current caller checks for native application readers. Data reads still
    /// authenticate independently through the direct Table service.
    pub fn authorization(self: *Http, binding: Binding) !c.TableAuthority.Context {
        const client = try self.transport().bind(binding);
        if (binding.scope.realm != self.resources.realm) return error.WorkItemScopeChanged;
        const authority: s.client.AuthorizationClient = .{ .transport = self.resources.wire, .realm = self.resources.realm, .principal = self.resources.principal, .key = self.resources.key, .role = client.connection.role };
        return .{ .client = authority, .subject = try authority.proof(binding.audience, try c.TableAuthority.binding(binding.scope, .database, 0)) };
    }
    fn exchange(context: *anyopaque, connection: w.Connection, action: w.Action) !std.json.Parsed(w.Response) {
        const self: *Http = @ptrCast(@alignCast(context));
        if (connection.scope.realm != self.resources.realm or connection.principal != self.resources.principal or (!self.select_owner and connection.role != self.role)) return error.WorkItemDenied;
        const client: c.DirectTableClient = .{ .allocator = self.allocator, .authority = self.resources.wire, .service = self.resources.wire, .connection = connection, .key = self.resources.key };
        return client.call(action);
    }
};
pub const Client = struct {
    transport: Transport,
    connection: w.Connection,
    pub fn call(self: Client, action: w.Action) !std.json.Parsed(w.Response) {
        return self.transport.exchange(self.transport.context, self.connection, action);
    }
    pub fn stage(self: Client, intent: *const c.DirectTableIntent, namespace: u64) !c.DirectTableIntent.Reference {
        try intent.check(self.connection);
        const expected = try intent.reference(namespace);
        const response = try self.call(.{ .stage = .{ .namespace = namespace, .intent = intent.parsed.value } });
        defer response.deinit();
        if (response.value.result != .staged) return error.InvalidWorkItemDataResponse;
        try expected.requireSame(response.value.result.staged);
        return response.value.result.staged;
    }
};

pub const Purpose = enum { create, put, copy };
pub const Dispatch = struct {
    application: u64,
    resource: u64,
    worker: u64,
    input: u64,
    table: u32,
    purpose: Purpose,
    source_row: ?c.fuze.TableRow.Identity,
    reference: c.DirectTableIntent.Reference,

    fn validate(self: Dispatch) !void {
        try c.Model.nativeId(self.application);
        try c.Model.nativeId(self.resource);
        try c.Model.nativeId(self.worker);
        try c.Model.nativeId(self.input);
        if (self.table == 0) return error.InvalidWorkItemPlan;
        try self.reference.validate();
        if (self.reference.binding.identity.operation != self.input) return error.InvalidWorkItemDispatch;
        const prerequisite = self.reference.binding.prerequisite orelse return error.InvalidWorkItemDispatch;
        if (prerequisite.subject != .accepted or prerequisite.subject.accepted.pid != self.worker or prerequisite.subject.accepted.input != self.input) return error.InvalidWorkItemDispatch;
        if ((self.purpose == .create) != (self.reference.binding.action == .create)) return error.InvalidWorkItemDispatch;
        if (self.purpose != .create and self.reference.binding.action != .insert and self.reference.binding.action != .update) return error.InvalidWorkItemDispatch;
        if ((self.purpose == .copy) != (self.source_row != null)) return error.InvalidWorkItemDispatch;
        if (self.source_row) |identity| try identity.validate();
    }
};
const max_record_bytes = 16 * 1024;
const prefix_bytes = 36;
fn key(input: u64) p.Value {
    var bytes: [12]u8 = undefined;
    bytes[0..4].* = "\x00WID".*;
    std.mem.writeInt(u64, bytes[4..], input, .big);
    return p.Value.init(&bytes) catch unreachable;
}
/// Reading a record is not permission to dispatch it. Execution below always
/// reopens the committed native view, regardless of the caller's private writes.
pub fn inspect(allocator: std.mem.Allocator, reader: anytype, application: u64, worker: u64, input: u64) !?Dispatch {
    var buffer: [max_record_bytes]u8 = undefined;
    const bytes = (try reader.readBlock(key(input), &buffer)) orelse return null;
    if (bytes.len <= prefix_bytes or !std.mem.eql(u8, bytes[0..4], "WDI1")) return error.InvalidWorkItemDispatch;
    if (!std.mem.eql(u8, bytes[4..prefix_bytes], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
    const decoded = try p.Json.parseFromSlice(Dispatch, allocator, bytes[prefix_bytes..]);
    defer decoded.deinit();
    const value = decoded.value;
    try value.validate();
    if (value.application != application or value.resource != reader.view.resource or value.worker != worker or value.input != input) return error.InvalidWorkItemDispatch;
    return value;
}
/// The immutable reference and eligibility become durable with the caller's
/// native decision. One bounded block; no growing in-memory operation registry.
pub fn prepare(allocator: std.mem.Allocator, turn: *s.Turn, record: Dispatch) !void {
    try record.validate();
    if (record.resource != turn.view.resource or record.worker != turn.delivery.pid or record.input > turn.delivery.input.position or record.reference.connection.principal != turn.delivery.principal) return error.InvalidWorkItemDispatch;
    if (try inspect(allocator, turn, record.application, record.worker, record.input)) |existing| {
        if (!std.meta.eql(existing, record)) return error.DataIdentityConflict;
        return;
    }
    _ = try turn.requireAuthorization(record.reference.binding.prerequisite.?);
    var buffer: [max_record_bytes]u8 = undefined;
    var out: std.Io.Writer = .fixed(&buffer);
    try out.writeAll("WDI1");
    try out.writeAll(&p.Growth.definition_bytes);
    var encoder: std.json.Stringify = .{ .writer = &out };
    try p.Json.write(record, &encoder);
    try turn.writeBlock(key(record.input), out.buffered());
}
pub const Outcome = union(enum) { pending, committed: c.storage.TablePartition.Evidence, rejected, cancelled };
fn outcome(result: w.Result) !Outcome {
    return switch (result) {
        .ddl => |value| switch (value) {
            .not_observed, .admitted, .finalizing => .pending,
            .committed => |evidence| .{ .committed = evidence },
            .rejected => .rejected,
            .cancelled => .cancelled,
        },
        .rows => |value| switch (value) {
            .not_observed, .admitted => .pending,
            .committed => |evidence| .{ .committed = evidence },
            .rejected => .rejected,
            .cancelled => .cancelled,
        },
        else => error.InvalidWorkItemDataResponse,
    };
}
/// At most one admission/execution follows inspection. An uncertain exchange
/// leaves the original reference and native pending work intact for replacement.
pub fn advance(allocator: std.mem.Allocator, turn: *s.Turn, client: Client, application: u64, input: u64, table: u32, purpose: Purpose) !Outcome {
    var committed = turn.committed();
    const record = (try inspect(allocator, &committed, application, turn.delivery.pid, input)) orelse return error.WorkItemDispatchNotCommitted;
    if (record.table != table or record.purpose != purpose or !std.meta.eql(record.reference.connection, client.connection)) return error.DataIdentityConflict;
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

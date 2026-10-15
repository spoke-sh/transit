//! Stateless neutral administration boundary. Returned saved records belong to
//! the caller's arena; only the explicit submit action dispatches a command.
const std = @import("std");
const wire = @import("root.zig");
const p = wire.protocol;
const a = p.Authorization;
const Change = wire.AuthorizationChange;
pub const codes = @import("AuthorizationCodes.zig");
pub const max_input_bytes = 256 * 1024;
pub const Connection = struct {
    definition: p.Growth.Definition,
    realm: u64,
    principal: u64,
    role: ?u64 = null,
    pub fn validate(self: Connection) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try p.Growth.validateQuery(.{ .realm = self.realm, .principal = self.principal, .kind = .{ .authorization = .{ .role = self.role, .kind = .identity } } });
    }
};
pub const Capabilities = struct {
    definition: p.Growth.Definition = p.Growth.current_definition,
    max_input_bytes: u32 = max_input_bytes,
    max_record_bytes: u32 = Change.Record.max_bytes,
    explicit_submit: bool = true,
};
const NativeRead = @FieldType(a.Query, "kind");
/// Administration inspection only. Subject proofs and full native request
/// receipts have dedicated operations; they do not expand this public surface.
pub const Read = union(enum) {
    identity,
    preview: @FieldType(NativeRead, "preview"),
    decision: @FieldType(NativeRead, "decision"),
    role: @FieldType(NativeRead, "role"),
    resolve: @FieldType(NativeRead, "resolve"),
    roles: @FieldType(NativeRead, "roles"),
    memberships: @FieldType(NativeRead, "memberships"),
    object: @FieldType(NativeRead, "object"),
    binding: @FieldType(NativeRead, "binding"),
    registration: @FieldType(NativeRead, "registration"),
    grants: @FieldType(NativeRead, "grants"),
    defaults: @FieldType(NativeRead, "defaults"),
    change: @FieldType(NativeRead, "change"),
    operation: @FieldType(NativeRead, "operation"),
    pub fn native(self: Read) NativeRead {
        return switch (self) {
            inline else => |value, tag| @unionInit(NativeRead, @tagName(tag), value),
        };
    }
};
pub const Observation = struct {
    definition: p.Growth.Definition,
    realm: u64,
    position: u64,
    principal_sequence: u64,
    body: struct { authorization: a.Result },
    fn from(response: p.Growth.Response) !Observation {
        if (response.body != .authorization) return error.InvalidAuthorityResponse;
        return .{ .definition = response.definition, .realm = response.realm, .position = response.position, .principal_sequence = response.principal_sequence, .body = .{ .authorization = response.body.authorization } };
    }
};
pub const Action = union(enum) {
    capabilities,
    read: Read,
    prepare: struct { expected_revision: u64, action: a.Action },
    restore: []const u8,
    next: []const u8,
    submit: []const u8,
    observe: []const u8,
    received: struct { record: []const u8, receipt: p.Receipt },
    recover_pending: []const u8,
    abandon: []const u8,
};
pub const Result = union(enum) {
    capabilities: Capabilities,
    observation: Observation,
    prepared: struct { preview: a.Preview, record: []const u8 },
    record: []const u8,
    next: union(enum) { pending: []const u8, terminal: a.Outcome },
    receipt: p.Receipt,
    recovered: ?[]const u8,
};

pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Action) {
    if (bytes.len == 0 or bytes.len > max_input_bytes) return error.InvalidAuthorizationInput;
    return p.Json.parseFromSlice(Action, allocator, bytes);
}
pub fn record(allocator: std.mem.Allocator, connection: Connection, bytes: []const u8) !Change.Record {
    try connection.validate();
    const saved = try Change.Record.restore(allocator, bytes);
    const request = saved.begin.signed.request;
    if (request.realm != connection.realm or request.principal != connection.principal) return error.InvalidAuthorizationChange;
    return saved;
}
/// Local validation runs before transport dispatch. Recovery uses the retained
/// selected role, so changing a session's selected role cannot replace it.
pub fn validate(allocator: std.mem.Allocator, connection: Connection, action: Action) !void {
    try connection.validate();
    switch (action) {
        .capabilities => {},
        .read => |kind| try a.validateQuery(.{ .role = connection.role, .kind = kind.native() }),
        .prepare => |value| try a.validateQuery(.{ .role = connection.role, .kind = .{ .preview = .{ .expected_revision = value.expected_revision, .action = value.action } } }),
        .received => |value| _ = try (try record(allocator, connection, value.record)).received(value.receipt),
        .restore, .next, .submit, .observe, .recover_pending, .abandon => |bytes| {
            const saved = try record(allocator, connection, bytes);
            if ((action == .submit or action == .recover_pending) and saved.pending == null) return error.AuthorizationChangeNotPending;
        },
    }
}

pub fn apply(allocator: std.mem.Allocator, transport: anytype, key: p.Ed25519.KeyPair, connection: Connection, action: Action, dispatched: *bool) !Result {
    dispatched.* = false;
    try validate(allocator, connection, action);
    const Transport = @typeInfo(@TypeOf(transport)).pointer.child;
    const client: Change.WithTransport(Transport) = .{ .authority = .{ .transport = transport, .key = key, .realm = connection.realm, .principal = connection.principal, .role = connection.role } };
    return switch (action) {
        .capabilities => .{ .capabilities = .{} },
        .read => |kind| .{ .observation = try Observation.from(try client.authority.read(kind.native())) },
        .prepare => |value| result: {
            const prepared = try client.prepare(value.expected_revision, value.action);
            break :result .{ .prepared = .{ .preview = prepared.preview, .record = try prepared.record.save(allocator) } };
        },
        .restore => |bytes| .{ .record = try (try record(allocator, connection, bytes)).save(allocator) },
        .next => |bytes| .{ .next = switch (try client.next(try record(allocator, connection, bytes))) {
            .pending => |saved| .{ .pending = try saved.save(allocator) },
            .terminal => |outcome| .{ .terminal = outcome },
        } },
        .submit => |bytes| result: {
            const saved = try record(allocator, connection, bytes);
            dispatched.* = true;
            break :result .{ .receipt = try client.submit(saved) };
        },
        .observe => |bytes| .{ .observation = try Observation.from(try client.observe(try record(allocator, connection, bytes))) },
        .received => |value| .{ .record = try (try (try record(allocator, connection, value.record)).received(value.receipt)).save(allocator) },
        .recover_pending => |bytes| .{ .recovered = if (try client.recoverPending(try record(allocator, connection, bytes))) |saved| try saved.save(allocator) else null },
        .abandon => |bytes| .{ .record = try (try client.abandon(try record(allocator, connection, bytes))).save(allocator) },
    };
}

/// Diagnostics describe this attempt only. A rejected retry does not change
/// the outcome of a previously accepted command with the same saved identity.
pub fn identity(allocator: std.mem.Allocator, connection: Connection, action: Action) !?p.Diagnostic.Identity {
    if (action != .submit) return null;
    const saved = try record(allocator, connection, action.submit);
    const request = (saved.pending orelse return error.AuthorizationChangeNotPending).signed.request;
    return .{ .domain = .transport, .id = .init(request.sequence), .sequence = .init(request.sequence), .realm = .init(request.realm) };
}
pub fn diagnostic(action: Action, cause: anyerror, dispatched: bool, target: ?p.Diagnostic.Identity, native: ?p.ErrorCode) !p.Diagnostic {
    const d = p.Diagnostic;
    const rejected = cause == error.AccessDenied or cause == error.Rejected or cause == error.Conflict;
    const read = action == .read or action == .observe or action == .recover_pending;
    const category = codes.category(cause);
    var detail = if (dispatched and !rejected)
        try d.init("authorization.send_unknown", .unavailable, .submit, .unknown, .saved_intent, "The administration step's outcome is unknown. Retain the exact saved record and reconcile its receipt before preparing another step.")
    else if (dispatched)
        try d.init("authorization.command_rejected", category, .submit, .not_applicable, .none, "The authority rejected this attempt. Inspect the original saved change before inferring its earlier outcome.")
    else
        try d.init("authorization.operation_failed", category, if (read) .read else .prepare, if (read) .not_applicable else .not_submitted, if (read) .none else .local_before_dispatch, "The administration operation did not complete. No command was submitted by this attempt.");
    detail.cause = try d.Code.init(@errorName(cause));
    detail.identity = target;
    try detail.text(.operation, .caller, @tagName(action));
    if (native) |value| try detail.text(.native_cause, .authority, @tagName(value));
    if (dispatched) {
        try detail.action(.inspect_status);
        if (!rejected and target != null) try detail.action(.resume_exact);
    } else try detail.action(if (category == .access or category == .conflict) .inspect_scope else if (read and category == .unavailable) .retry_read else if (category == .integrity or category == .internal) .contact_operator else .correct_input);
    try detail.validate();
    return detail;
}

test "administration diagnostic classifications preserve the actual dispatch boundary" {
    const t = std.testing;
    for (codes.entries) |entry| {
        const failed_read = try diagnostic(.{ .read = .identity }, entry.cause, false, null, null);
        try t.expectEqualStrings(entry.code, failed_read.code.slice());
        try t.expectEqual(entry.category, failed_read.category);
        try t.expectEqual(.not_applicable, failed_read.outcome);
        const prepared = try diagnostic(.{ .restore = "saved" }, entry.cause, false, null, null);
        try t.expectEqual(.not_submitted, prepared.outcome);
        const sent = try diagnostic(.{ .submit = "saved" }, entry.cause, true, .{ .domain = .transport, .id = .init(9), .sequence = .init(9), .realm = .init(1) }, null);
        try t.expectEqual(if (entry.cause == error.AccessDenied or entry.cause == error.Rejected or entry.cause == error.Conflict) p.Diagnostic.Outcome.not_applicable else .unknown, sent.outcome);
    }
}

test "neutral administration never dispatches during prepare or recovery and retains uncertain bytes" {
    const t = std.testing;
    const Fake = struct {
        response: p.Growth.Response = .{ .definition = p.Growth.current_definition, .realm = 1, .position = 1, .principal_sequence = 0, .body = .{ .authorization = .{ .revision = 1, .role = 0, .body = .{ .preview = .{ .complete = true, .changed_records = 1, .steps = 1, .pages = 2, .reads = 3 } } } } },
        calls: usize = 0,
        submitted: ?p.Growth.SignedRequest = null,
        pub fn query(self: *@This(), query_value: p.Growth.Query, pair: p.Ed25519.KeyPair) !p.Growth.Response {
            _ = try p.Growth.signQuery(query_value, pair);
            self.calls += 1;
            return self.response;
        }
        pub fn submit(self: *@This(), value: p.Growth.SignedRequest) !p.Receipt {
            self.submitted = value;
            return error.AuthorityTimeout;
        }
    };
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var fake: Fake = .{};
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const connection: Connection = .{ .definition = p.Growth.current_definition, .realm = 1, .principal = 0 };
    var dispatched = true;
    const prepared = try apply(alloc, &fake, key, connection, .{ .prepare = .{ .expected_revision = 1, .action = .{ .create_role = .{ .name = try p.Value.init("reader") } } } }, &dispatched);
    try t.expect(!dispatched and fake.submitted == null);
    const saved = prepared.prepared.record;
    const next = try apply(alloc, &fake, key, connection, .{ .next = saved }, &dispatched);
    try t.expectEqualStrings(saved, next.next.pending);
    try t.expectEqual(@as(usize, 1), fake.calls);
    try t.expectError(error.AuthorityTimeout, apply(alloc, &fake, key, connection, .{ .submit = saved }, &dispatched));
    try t.expect(dispatched);
    const unknown = try diagnostic(.{ .submit = saved }, error.AuthorityTimeout, dispatched, try identity(alloc, connection, .{ .submit = saved }), null);
    try unknown.validate();
    try t.expectEqual(.unknown, unknown.outcome);
    try t.expect(std.meta.eql(fake.submitted.?, (try record(alloc, connection, saved)).pending.?.signed));
    fake.response.body.authorization.body = .{ .receipt = null };
    try t.expect((try apply(alloc, &fake, key, connection, .{ .recover_pending = saved }, &dispatched)).recovered == null);
    try t.expect(!dispatched);
    fake.response.body.authorization.body = .{ .receipt = .{ .position = 2 } };
    const recovered = (try apply(alloc, &fake, key, connection, .{ .recover_pending = saved }, &dispatched)).recovered.?;
    try t.expect((try record(alloc, connection, recovered)).pending == null);
    var foreign = connection;
    foreign.principal = 9;
    try t.expectError(error.InvalidAuthorizationChange, apply(alloc, &fake, key, foreign, .{ .submit = saved }, &dispatched));
    try t.expect(!dispatched);
    try t.expectError(error.AuthorizationChangeNotPending, apply(alloc, &fake, key, connection, .{ .submit = recovered }, &dispatched));
    try t.expect(!dispatched);
}

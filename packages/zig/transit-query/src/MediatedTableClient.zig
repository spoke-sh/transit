//! Restricted Table caller. Native credentials authenticate the original subject;
//! data, metadata and recovery reads use the trusted service's private reader.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const c = q.catalog;
const Service = q.TableService;
const Table = c.TableClient;
const Self = @This();
allocator: std.mem.Allocator,
authority: *q.wire.Client,
service: *q.wire.Client,
connection: Table.Connection,
key: p.Ed25519.KeyPair,
limits: q.wire.Client.OwnedLimits = .{},

pub fn signed(self: Self, action: Service.Action, nonce: [16]u8) !Service.Request {
    try self.connection.validate();
    try self.limits.validate();
    var request: Service.Request = .{ .definition = p.Growth.current_definition, .connection = try c.TableValues.Connection.foreign(self.allocator, self.connection), .nonce = nonce, .action = action, .proof = undefined };
    const authority: q.wire.AuthorizationClient = .{ .transport = self.authority, .realm = self.connection.scope.realm, .principal = self.connection.principal, .role = self.connection.role, .key = self.key };
    request.proof = (try authority.proof(self.connection.owner, try request.context(self.allocator))).signed;
    _ = try request.validate(self.allocator);
    return request;
}
/// The response owns every string and row until deinit. No service action
/// submits a Table mutation or signs one with the service's private credential.
pub fn call(self: Self, action: Service.Action) !std.json.Parsed(Service.Response) {
    self.authority.last_rejection = null;
    self.service.last_rejection = null;
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();
    var temporary = self;
    temporary.allocator = arena.allocator();
    var nonce: [16]u8 = undefined;
    try self.authority.http.io.randomSecure(&nonce);
    const request = try temporary.signed(action, nonce);
    const response = try self.service.callOwned(Service.Response, "/table/v1", request, self.limits);
    errdefer response.deinit();
    try validateResponse(arena.allocator(), self.connection, action, response.value);
    return response;
}
pub fn signCandidate(self: Self, candidate: Table.Candidate) !Table.Prepared {
    if (!std.meta.eql(self.connection, candidate.connection)) return error.CatalogIdentityConflict;
    return candidate.sign(self.key);
}
/// Only this explicit operation sends the retained mutation bytes. A fresh
/// credential is used for receipt recovery, never to re-sign accepted work.
pub fn submit(self: Self, prepared: Table.Prepared) !p.Receipt {
    try self.validatePrepared(prepared);
    return self.authority.submit(prepared.signed);
}
pub fn receipt(self: Self, prepared: Table.Prepared) !?p.Receipt {
    try self.validatePrepared(prepared);
    const authority: q.wire.AuthorizationClient = .{ .transport = self.authority, .realm = self.connection.scope.realm, .principal = self.connection.principal, .key = self.key };
    return (try authority.read(.{ .receipt = prepared.signed.request })).body.authorization.body.receipt;
}
fn validatePrepared(self: Self, prepared: Table.Prepared) !void {
    if (!std.meta.eql(self.connection, prepared.connection)) return error.CatalogIdentityConflict;
    try prepared.verify();
}
pub fn validateResponse(allocator: std.mem.Allocator, connection: Table.Connection, action: Service.Action, response: Service.Response) !void {
    if (response.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try p.Authorization.revision(response.policy_revision);
    const expected: std.meta.Tag(Service.Result) = switch (action) {
        .describe => .description,
        .schemas => .schemas,
        .schema_lookup => .schema,
        .schema_status => .schema_outcome,
        .schema_prepare, .schema_plan_prepare, .prepare_resume, .control => .candidate,
        .compile_authorization => .authorization_plan,
        .list => .list,
        .lookup => .lookup,
        .definition => .definition,
        .lifecycle => .lifecycle,
        .dependents, .dependencies => .dependencies,
        .policy_references => .policy_references,
        .preview => .preview,
        .compile, .prepare => .compiled,
        .next => .next,
        .status => .state,
        .observe => .observation,
        .disposition => .disposition,
        .progress => .progress,
        .query => .query,
    };
    if (std.meta.activeTag(response.result) != expected) return error.InvalidTableServiceResponse;
    switch (response.result) {
        .candidate => |candidate| {
            try candidateCheck(connection, candidate, switch (action) {
                .schema_prepare => |value| value.sequence,
                .schema_plan_prepare => |value| value.sequence,
                .prepare_resume => |value| value.sequence,
                .control => |value| value.sequence,
                else => unreachable,
            });
            const payload = try candidate.command();
            switch (action) {
                .schema_prepare => |value| if (payload != .control or !std.meta.eql(payload.control, c.TableControl.Command{ .schema = try value.request.native() })) return error.InvalidTableServiceResponse,
                .schema_plan_prepare => |value| {
                    const plan = try value.plan.native();
                    if (plan.action != .schema or payload != .control or !std.meta.eql(payload.control, c.TableControl.Command{ .schema = plan.action.schema })) return error.InvalidTableServiceResponse;
                },
                .prepare_resume => |value| {
                    if (payload == .control and payload.control != .drive) return error.InvalidTableServiceResponse;
                    try intentCandidate(allocator, connection, value.saved, candidate);
                },
                .control => |value| {
                    if (payload != .control) return error.InvalidTableServiceResponse;
                    const matches = switch (value.kind) {
                        .cancel_operation => payload.control == .cancel_ddl or payload.control == .cancel_dml,
                        .cleanup_operation => payload.control == .cleanup_ddl or payload.control == .cleanup_dml,
                        .cancel_upload => payload.control == .cancel_upload,
                        .collect_upload => payload.control == .collect_upload,
                    };
                    if (!matches) return error.InvalidTableServiceResponse;
                    try intentCandidate(allocator, connection, value.saved, candidate);
                },
                else => unreachable,
            }
        },
        .next => |next| if (next == .send) {
            try candidateCheck(connection, next.send, action.next.sequence);
            const payload = try next.send.command();
            if (payload == .control) switch (payload.control) {
                .begin, .part, .seal, .drive => {},
                else => return error.InvalidTableServiceResponse,
            };
            try intentCandidate(allocator, connection, action.next.saved, next.send);
        },
        .query => |value| {
            if (!value.complete or value.rows.len > action.query.rows) return error.InvalidTableServiceResponse;
            const schema = try q.Values.columns(allocator, value.columns);
            for (value.rows) |row| {
                if (row.len != schema.structure.len) return error.InvalidTableServiceResponse;
                for (row, schema.structure) |cell, field| _ = try q.fuze.LogicalJson.fromForeign(allocator, cell, field);
            }
        },
        .authorization_plan => |value| {
            const plan = try value.native();
            if (plan.principal != connection.principal or !std.meta.eql(plan.scope, connection.scope)) return error.InvalidTableServiceResponse;
        },
        else => {},
    }
}
fn candidateCheck(connection: Table.Connection, candidate: Table.Candidate, sequence: u64) !void {
    if (!std.meta.eql(connection, candidate.connection) or candidate.request.sequence != sequence) return error.InvalidTableServiceResponse;
    _ = try candidate.command();
}
fn intentCandidate(allocator: std.mem.Allocator, connection: Table.Connection, saved: c.TableBridge.Saved, candidate: Table.Candidate) !void {
    if (saved.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    const bytes = try c.TableValues.unhex(allocator, saved.bytes, c.TableIntent.max_bytes);
    defer allocator.free(bytes);
    var intent = try c.TableIntent.restore(allocator, bytes);
    defer intent.deinit();
    try connection.header(intent.header);
    if (!try candidate.matches(&intent)) return error.InvalidTableServiceResponse;
}

test "mediated result validation rejects action substitution and incomplete rows" {
    const t = std.testing;
    const connection: Table.Connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .principal = 4, .owner = 5 };
    const response: Service.Response = .{ .definition = p.Growth.current_definition, .policy_revision = 1, .result = .{ .lookup = null } };
    try validateResponse(t.allocator, connection, .{ .lookup = "a" }, response);
    try t.expectError(error.InvalidTableServiceResponse, validateResponse(t.allocator, connection, .{ .schema_lookup = "a" }, response));
    try t.expectError(error.InvalidTableServiceResponse, validateResponse(t.allocator, connection, .{ .query = .{ .sql = "SELECT * FROM a", .rows = 1, .reads = 1 } }, .{ .definition = p.Growth.current_definition, .policy_revision = 1, .result = .{ .query = .{ .columns = &.{}, .rows = &.{}, .complete = false } } }));
    try t.expectError(error.MissingField, p.Json.parseFromSliceOwned(Service.Response, t.allocator, "{\"policy_revision\":1,\"result\":{\"lookup\":null}}"));
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSliceOwned(Service.Response, t.allocator, "{\"definition\":\"previous-v1-definition\",\"policy_revision\":1,\"result\":{\"lookup\":null}}"));
}

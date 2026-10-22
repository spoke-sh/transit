//! Trusted Table mediation. Storage credentials stay in the service; every
//! request carries an independently signed original caller and exact action.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const a = p.Authorization;
const v = c.TableValues;
const b = c.TableBridge;
const Client = c.TableClient;
const Self = @This();
resources: q.wire.ResourceReader,
scope: c.Model.Scope,
owner: u64,
limits: Limits = .{},
spill_directory: ?std.Io.Dir = null,

pub const Limits = struct {
    request_bytes: u32 = 1048576,
    response_bytes: u32 = 1048576,
    resident_bytes: u32 = 32 * 1048576,
    rows: u32 = 1024,
    reads: u32 = 4096,
    spill_bytes: u64 = 64 * 1048576,
    work_steps: u32 = 1048576,
    spill_operations: u32 = 1048576,
    pub fn validate(self: Limits) !void {
        if (self.request_bytes == 0 or self.request_bytes > b.max_input_bytes or self.response_bytes == 0 or self.response_bytes > 16 * 1048576 or self.resident_bytes < self.request_bytes or self.resident_bytes > 256 * 1048576 or self.rows == 0 or self.rows > 65536 or self.reads == 0 or self.reads > 1048576) return error.InvalidTableServiceLimits;
        if (self.spill_bytes == 0 or self.spill_bytes > 4 * 1024 * 1048576 or self.work_steps == 0 or self.work_steps > 16 * 1048576 or self.spill_operations == 0 or self.spill_operations > 16 * 1048576) return error.InvalidTableServiceLimits;
    }
};
pub const Action = union(enum) {
    describe,
    schemas: ?v.SchemaCursor,
    schema_lookup: []const u8,
    schema_status: v.SchemaRequest,
    schema_prepare: struct { request: v.SchemaRequest, sequence: u64 },
    schema_plan_prepare: struct { plan: v.AuthorizationPlan, sequence: u64 },
    compile_authorization: @FieldType(b.Action, "compile_authorization"),
    list: ?v.Cursor,
    lookup: []const u8,
    definition: struct { object: []const u8, revision: []const u8 },
    lifecycle: []const u8,
    dependents: @FieldType(b.Action, "dependents"),
    dependencies: @FieldType(b.Action, "dependencies"),
    policy_references: []const u8,
    computation: []const u8,
    compile: @FieldType(b.Action, "compile"),
    prepare: c.TableTyped.Request,
    preview: b.Saved,
    next: struct { saved: b.Saved, sequence: u64 },
    prepare_resume: struct { saved: b.Saved, sequence: u64 },
    observe: struct { prepared: Client.Prepared, input: u64 },
    disposition: struct { prepared: Client.Prepared, input: u64 },
    progress: struct { saved: b.Saved, prepared: Client.Prepared, input: u64 },
    status: b.Saved,
    control: struct { saved: b.Saved, kind: b.Control, sequence: u64 },
    query: struct { sql: []const u8, rows: u32, reads: u32 },
};
pub const Request = struct {
    definition: p.Growth.Definition,
    connection: v.Connection,
    nonce: [16]u8,
    action: Action,
    proof: a.Proof,
    const Input = struct { definition: p.Growth.Definition, connection: v.Connection, nonce: [16]u8, action: Action };
    pub fn context(self: Request, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try p.Json.valueAlloc(allocator, Input{ .definition = self.definition, .connection = self.connection, .nonce = self.nonce, .action = self.action });
        defer allocator.free(bytes);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.service.request.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    pub fn validate(self: Request, allocator: std.mem.Allocator) !Client.Connection {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        const connection = try self.connection.native();
        try self.proof.claim.validate();
        const claim = self.proof.claim;
        if (claim.realm != connection.scope.realm or claim.principal != connection.principal or claim.role != connection.role or claim.audience != connection.owner or !std.mem.eql(u8, &claim.context, &try self.context(allocator))) return error.CatalogDenied;
        return connection;
    }
};
pub const Next = union(enum) { send: Client.Candidate, running, terminal: v.Outcome, upload_cancelled };
pub const Result = union(enum) {
    description: v.Description,
    schemas: v.Schemas,
    schema: ?v.Namespace,
    schema_outcome: ?v.SchemaOutcome,
    authorization_plan: v.AuthorizationPlan,
    list: v.Page,
    lookup: ?v.Definition,
    definition: ?v.HistoricalDefinition,
    lifecycle: ?v.LifecycleEvidence,
    dependencies: v.DependencyPage,
    policy_references: ?v.PolicyReferences,
    computation: ?v.ComputationEvidence,
    preview: v.Preview,
    compiled: b.Compiled,
    next: Next,
    state: @FieldType(b.Result, "state"),
    candidate: Client.Candidate,
    observation: Client.Observation,
    disposition: ?v.Disposition,
    progress: b.Progress,
    query: struct { columns: []const q.Values.Column, rows: []const []const q.Values.Cell, complete: bool },
};
pub const Response = struct { definition: p.Growth.Definition, policy_revision: u64, result: Result };

/// The caller supplies a bounded request arena and output buffer. No data is
/// released until serialization and the final current-authority check succeed.
pub fn execute(self: Self, arena: *std.heap.ArenaAllocator, request: Request, output: []u8) ![]const u8 {
    try self.limits.validate();
    const alloc = arena.allocator();
    const connection = try request.validate(alloc);
    if (!std.meta.eql(connection.scope, self.scope) or connection.owner != self.owner or self.resources.realm != self.scope.realm or self.resources.principal == connection.principal) return error.CatalogDenied;
    const authority: q.wire.AuthorizationClient = .{ .transport = self.resources.wire, .realm = self.resources.realm, .principal = self.resources.principal, .key = self.resources.key };
    const subject: a.Subject = .{ .signed = request.proof };
    _ = authority.authenticate(subject) catch |err| {
        if (err == error.AccessDenied or (err == error.Conflict and authority.transport.last_rejection == .StaleAuthorizationCredential)) return error.CatalogDenied;
        return err;
    };
    var observed: ?a.Guard = null;
    var client: Client = .{ .transport = self.resources.wire, .connection = connection, .key = self.resources.key, .reader = self.resources, .authority = .{ .client = authority, .subject = subject, .observed = &observed } };
    // Different caller epochs and actions cannot collide in the service's
    // native snapshot namespace, even if callers reuse the same nonce.
    const claim_digest = try request.proof.claim.digest();
    const result = try self.apply(arena, &client, request.action, claim_digest[0..16].*);
    const guard = observed orelse return error.CatalogDenied;
    const before = try authority.read(.{ .check = guard });
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, self.limits.response_bytes)]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(Response{ .definition = p.Growth.current_definition, .policy_revision = before.body.authorization.revision, .result = result }, &encoder);
    // Repeat all source requirements, including empty and noncontributing inputs.
    const after = try authority.read(.{ .check = guard });
    if (after.body.authorization.revision != before.body.authorization.revision) return error.AuthorizationChanged;
    _ = try self.resources.query(.{ .read_access = self.scope.resource });
    return writer.buffered();
}
fn apply(self: Self, arena: *std.heap.ArenaAllocator, client: *Client, action: Action, nonce: [16]u8) !Result {
    const alloc = arena.allocator();
    switch (action) {
        .observe => |value| return .{ .observation = try client.observe(value.prepared, value.input) },
        .disposition => |value| return .{ .disposition = if (try client.inputDisposition(value.prepared, value.input)) |found| try v.Disposition.foreign(found) else null },
        .schemas => |cursor| return .{ .schemas = try v.Schemas.foreign(alloc, try client.schemas(if (cursor) |value| try value.native() else null)) },
        .schema_lookup => |name| return .{ .schema = if (try client.schema(try .init(name))) |value| try v.Namespace.foreign(alloc, value) else null },
        .schema_status => |value| return .{ .schema_outcome = if (try client.schemaStatus(try value.native())) |outcome| try v.SchemaOutcome.foreign(alloc, outcome) else null },
        .schema_prepare => |value| return .{ .candidate = try client.controlCandidate(.{ .schema = try value.request.native() }, value.sequence) },
        .schema_plan_prepare => |value| return .{ .candidate = try client.schemaPlanCandidate(try value.plan.native(), value.sequence) },
        .compile_authorization => |value| return .{ .authorization_plan = try v.AuthorizationPlan.foreign(alloc, try c.AuthorizationSql.compile(client, alloc, value.sql, value.identity, null)) },
        .describe => {
            const value = try client.describe();
            return .{ .description = .{ .configuration = try v.Configuration.foreign(alloc, value.configuration), .subject = value.subject, .authorization_revision = value.authorization_revision, .resource_revision = value.resource_revision } };
        },
        .list => |cursor| return .{ .list = try v.Page.foreign(alloc, try client.list(if (cursor) |value| try value.native() else null)) },
        .lookup => |name| {
            var found = (try client.lookup(alloc, try .init(name))) orelse return .{ .lookup = null };
            defer found.deinit();
            return .{ .lookup = try v.Definition.foreign(arena, found) };
        },
        .definition => |target| {
            var found = (try client.definition(alloc, try v.unsigned(target.object), try v.unsigned(target.revision))) orelse return .{ .definition = null };
            defer found.deinit();
            return .{ .definition = try v.HistoricalDefinition.foreign(arena, found) };
        },
        .lifecycle => |object| return .{ .lifecycle = if (try client.inspectLifecycle(try v.unsigned(object))) |found| try v.LifecycleEvidence.foreign(alloc, found) else null },
        .dependents => |query| return .{ .dependencies = try v.DependencyPage.foreign(alloc, try client.dependents(try v.unsigned(query.object), if (query.cursor) |cursor| try cursor.native() else null)) },
        .dependencies => |query| return .{ .dependencies = try v.DependencyPage.foreign(alloc, try client.dependencies(try v.unsigned(query.identity), if (query.cursor) |cursor| try cursor.native() else null)) },
        .policy_references => |object| return .{ .policy_references = if (try client.policyReferences(try v.unsigned(object))) |found| try v.PolicyReferences.foreign(alloc, found) else null },
        .computation => |object| return .{ .computation = if (try client.inspectComputation(try v.unsigned(object))) |found| try v.ComputationEvidence.foreign(alloc, found) else null },
        .compile, .prepare => {
            var session: b.Session = .{ .allocator = alloc };
            defer session.deinit();
            const prepared = try session.apply(arena, client, switch (action) {
                .compile => |value| .{ .compile = value },
                .prepare => |value| .{ .prepare = value },
                else => unreachable,
            });
            const intent = try session.get(prepared.compiled.intent.reference, client.connection);
            _ = try client.requireObject(intent.header.object, intent.header.right());
            return .{ .compiled = prepared.compiled };
        },
        .next, .prepare_resume, .status, .preview, .control, .progress => {
            var session: b.Session = .{ .allocator = alloc };
            defer session.deinit();
            const saved = switch (action) {
                .next => |value| value.saved,
                .prepare_resume => |value| value.saved,
                .progress => |value| value.saved,
                .status, .preview => |value| value,
                .control => |value| value.saved,
                else => unreachable,
            };
            const loaded = (try session.apply(arena, client, .{ .load = saved })).loaded;
            const intent = try session.get(loaded.reference, client.connection);
            if (action == .status) return .{ .state = (try session.apply(arena, client, .{ .status = loaded.reference })).state };
            if (action == .preview) return .{ .preview = (try session.apply(arena, client, .{ .preview = loaded.reference })).preview };
            if (action == .prepare_resume) return .{ .candidate = try client.resumeCandidate(intent, action.prepare_resume.sequence) };
            if (action == .progress) return .{ .progress = switch (try client.progress(intent, action.progress.prepared, action.progress.input)) {
                .pending => .pending,
                .processed => |value| .{ .processed = .{
                    .disposition = if (value.disposition) |item| try v.Disposition.foreign(item) else null,
                    .outcome = if (value.outcome) |item| try v.Outcome.foreign(alloc, intent, item) else null,
                    .upload = if (value.upload) |item| try v.Upload.foreign(item) else null,
                } },
            } };
            if (action == .control) {
                const control = action.control;
                const command: c.TableControl.Command = switch (control.kind) {
                    .cancel_operation => switch (intent.identity) {
                        .ddl => |value| .{ .cancel_ddl = value },
                        .dml => |value| .{ .cancel_dml = .{ .scope = intent.header.scope, .reference = value.reference } },
                    },
                    .cleanup_operation => switch (intent.identity) {
                        .ddl => |value| .{ .cleanup_ddl = value },
                        .dml => |value| .{ .cleanup_dml = .{ .scope = intent.header.scope, .reference = value.reference } },
                    },
                    .cancel_upload => .{ .cancel_upload = intent.upload() },
                    .collect_upload => .{ .collect_upload = intent.upload() },
                };
                return .{ .candidate = try client.controlCandidate(command, control.sequence) };
            }
            return .{ .next = switch (try client.nextCandidate(intent, action.next.sequence)) {
                .send => |value| .{ .send = value },
                .running => .running,
                .terminal => |value| .{ .terminal = try v.Outcome.foreign(alloc, intent, value) },
                .upload_cancelled => .upload_cancelled,
            } };
        },
        .query => |input| {
            if (input.sql.len > 4096 or input.rows == 0 or input.rows > self.limits.rows or input.reads == 0 or input.reads > self.limits.reads) return error.InvalidQueryBudget;
            if (try q.fuze.RelationalSql.required(input.sql)) return self.relational(arena, client, input, nonce);
            var query = try q.TableQuery.open(alloc, client, input.sql, nonce, .{ .requests = input.reads, .rows = input.rows, .result_bytes = self.limits.response_bytes }, null, null);
            defer query.deinit();
            var fields: [q.fuze.TableSchema.max_columns]q.fuze.Types.Field = undefined;
            const schema = try query.schema(&fields);
            var rows: std.ArrayList([]const q.Values.Cell) = .empty;
            while (true) {
                var batch = try query.nextBatch(8);
                defer batch.deinit();
                for (batch.rows[0..batch.len]) |row| {
                    const cells = try alloc.alloc(q.Values.Cell, row.?.cells.len);
                    for (row.?.cells, schema.structure, cells) |cell, field, *out| out.* = try q.fuze.LogicalJson.foreignCell(alloc, cell, field.type);
                    try rows.append(alloc, cells);
                }
                if (batch.complete) break;
            }
            try query.close();
            return .{ .query = .{ .columns = try q.Values.foreignColumns(alloc, schema), .rows = try rows.toOwnedSlice(alloc), .complete = true } };
        },
    }
}

fn relational(self: Self, arena: *std.heap.ArenaAllocator, client: *Client, input: @FieldType(Action, "query"), nonce: [16]u8) !Result {
    const directory = self.spill_directory orelse return error.TableServiceSpillRequired;
    const alloc = arena.allocator();
    var targets: [q.fuze.Relational.max_sources]q.fuze.RelationalSql.Target = undefined;
    const count = try q.fuze.RelationalSql.discoverTargets(alloc, input.sql, &targets);
    var clients: [q.fuze.Relational.max_sources]*Client = @splat(client);
    var nonces: [q.fuze.Relational.max_sources][16]u8 = undefined;
    for (&nonces, 0..) |*value, index| {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.service.source.v1\x00");
        hash.update(&nonce);
        hash.update(&.{@intCast(index)});
        value.* = hash.finalResult()[0..16].*;
    }
    var filename_buffer: [64]u8 = undefined;
    const filename = try std.fmt.bufPrint(&filename_buffer, "table-query-{s}.spill", .{std.fmt.bytesToHex(nonce, .lower)});
    const query = try q.RelationalQuery.open(alloc, client.transport.http.io, directory, filename, clients[0..count], input.sql, nonces, .{
        .consistency = .per_resource_snapshot_vector,
        .budgets = .{ .resident_bytes = self.limits.resident_bytes, .spill_bytes = self.limits.spill_bytes, .result_bytes = self.limits.response_bytes, .output_rows = input.rows, .work_steps = self.limits.work_steps, .source_pins = 1 },
        .requests = input.reads,
        .spill_work = self.limits.spill_operations,
    }, null, null);
    defer query.deinit();
    var fields: [q.fuze.Relational.max_outputs]q.fuze.Types.Field = undefined;
    const schema = try query.schema(&fields);
    var rows: std.ArrayList([]const q.Values.Cell) = .empty;
    while (try query.next()) |row| {
        const cells = try alloc.alloc(q.Values.Cell, row.len);
        for (row.cells[0..row.len], schema.structure, cells) |cell, field, *out| out.* = try q.fuze.LogicalJson.foreignCell(alloc, cell, field.type);
        try rows.append(alloc, cells);
    }
    try query.close();
    return .{ .query = .{ .columns = try q.Values.foreignColumns(alloc, schema), .rows = try rows.toOwnedSlice(alloc), .complete = true } };
}

test "service proof binds the action, nonce, scope and selected role" {
    const t = std.testing;
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    var request: Request = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = "3" }, .owner = 4, .principal = 5 }, .nonce = @splat(6), .action = .{ .lookup = "people" }, .proof = undefined };
    request.proof = try a.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = 1, .principal = 5, .credential_epoch = 1, .role = null, .audience = 4, .context = try request.context(t.allocator) }, key);
    _ = try request.validate(t.allocator);
    const original = request;
    request.action = .{ .lookup = "private" };
    try t.expectError(error.CatalogDenied, request.validate(t.allocator));
    request = original;
    request.nonce[0] ^= 1;
    try t.expectError(error.CatalogDenied, request.validate(t.allocator));
    request = original;
    request.connection.role = 7;
    try t.expectError(error.CatalogDenied, request.validate(t.allocator));
    request = original;
    request.connection.scope.resource += 1;
    try t.expectError(error.CatalogDenied, request.validate(t.allocator));
}

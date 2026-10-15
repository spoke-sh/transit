//! General Table caller boundary. One ephemeral handle owns one exact intent;
//! callers persist its immutable bytes and each signed step before dispatch.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const f = c.fuze;
const v = c.TableValues;
const Client = c.TableClient;
const Allocator = std.mem.Allocator;
pub const Connection = v.Connection;
pub const max_input_bytes = 16 * 1024 * 1024;
pub const Reference = struct { definition: p.Growth.Definition, digest: []const u8 };
pub const Saved = struct { definition: p.Growth.Definition, bytes: []const u8 };
pub const Summary = struct {
    reference: Reference,
    scope: v.Scope,
    owner: u64,
    principal: u64,
    operation: []const u8,
    namespace: []const u8,
    object: []const u8,
    kind: c.TableCommand.Kind,
};
pub const Compiled = struct { intent: Summary, saved: Saved };
pub const Capabilities = struct {
    version: u8 = 1,
    definition: p.Growth.Definition = p.Growth.current_definition,
    max_columns: u16 = f.TableSchema.max_columns,
    max_rows: u16 = f.TableDml.max_rows,
    max_sql_bytes: u16 = 4096,
    max_intent_bytes: u32 = c.TableIntent.max_bytes,
    max_action_bytes: u32 = max_input_bytes,
    max_prepared_bytes: u16 = Client.Prepared.max_saved_bytes,
    resident_intents: u8 = 1,
};
pub const Input = struct { prepared: []const u8, input: u64 };
pub const ProgressInput = struct { intent: Reference, prepared: []const u8, input: u64 };
pub const Control = enum { cancel_operation, cleanup_operation, cancel_upload, collect_upload };
pub const Action = union(enum) {
    capabilities,
    describe,
    schemas: ?v.SchemaCursor,
    schema_lookup: []const u8,
    schema_status: v.SchemaRequest,
    prepare_schema: v.SchemaRequest,
    prepare_schema_plan: v.AuthorizationPlan,
    compile_authorization: struct { sql: []const u8, identity: c.AuthorizationSql.Identity = .{} },
    lookup: []const u8,
    definition: struct { object: []const u8, revision: []const u8 },
    list: ?v.Cursor,
    compile: struct { identity: v.Identity, create_object: ?[]const u8, sql: []const u8 },
    prepare: c.TableTyped.Request,
    load: Saved,
    forget: Reference,
    next: Reference,
    status: Reference,
    prepare_resume: Reference,
    prepare_control: struct { intent: Reference, control: Control },
    prepare_initialize: v.Configuration,
    prepare_dependency: v.DependencyChange,
    submit: []const u8,
    receipt: []const u8,
    observe: Input,
    wait_observe: Input,
    input_disposition: Input,
    progress: ProgressInput,
    wait_progress: ProgressInput,
};
pub const Next = union(enum) { send: []const u8, running, terminal: v.Outcome, upload_cancelled };
pub const Progress = union(enum) { pending, processed: struct { disposition: ?v.Disposition, outcome: ?v.Outcome, upload: ?v.Upload } };
pub const Result = union(enum) {
    capabilities: Capabilities,
    description: v.Description,
    schemas: v.Schemas,
    schema: ?v.Namespace,
    schema_outcome: ?v.SchemaOutcome,
    authorization_plan: v.AuthorizationPlan,
    definition: ?v.Definition,
    historical: ?v.HistoricalDefinition,
    page: v.Page,
    compiled: Compiled,
    loaded: Summary,
    forgotten,
    next: Next,
    state: v.State,
    prepared: []const u8,
    receipt: p.Receipt,
    receipt_status: ?p.Receipt,
    observation: Client.Observation,
    disposition: ?v.Disposition,
    progress: Progress,
};
pub fn parse(allocator: Allocator, bytes: []const u8) !std.json.Parsed(Action) {
    try f.Types.Json.preflight(bytes, .{ .bytes = max_input_bytes, .depth = 96, .tokens = 1024 * 1024, .fields = 256 });
    return p.Json.parseFromSlice(Action, allocator, bytes);
}
pub fn prepared(allocator: Allocator, bytes: []const u8) !Client.Prepared {
    return Client.Prepared.restore(allocator, bytes);
}
fn commitment(intent: *const c.TableIntent) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.saved-intent.v1\x00");
    hash.update(intent.bytes);
    return hash.finalResult();
}
fn summary(allocator: Allocator, intent: *const c.TableIntent, hash: [32]u8) !Summary {
    return .{ .reference = .{ .definition = p.Growth.current_definition, .digest = try v.hex(allocator, &hash) }, .scope = try v.Scope.foreign(allocator, intent.header.scope), .owner = intent.header.owner, .principal = intent.header.principal, .operation = try v.decimal(allocator, intent.header.operation), .namespace = try v.decimal(allocator, intent.namespace), .object = try v.decimal(allocator, intent.header.object), .kind = intent.header.kind };
}
pub const Session = struct {
    allocator: Allocator,
    active: ?struct { intent: c.TableIntent, digest: [32]u8 } = null,
    pub fn deinit(self: *Session) void {
        if (self.active) |*active| active.intent.deinit();
        self.* = undefined;
    }
    /// References confer no authority. Every remote method still checks current
    /// rights. Replacing/destroying a handle neither cancels nor forgets a send.
    pub fn get(self: *Session, reference: Reference, connection: Client.Connection) !*const c.TableIntent {
        if (reference.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        const expected = try v.digest(reference.digest);
        const active = if (self.active) |*value| value else return error.TableIntentNotLoaded;
        if (!std.mem.eql(u8, &active.digest, &expected)) return error.CatalogIdentityConflict;
        try connection.header(active.intent.header);
        return &active.intent;
    }
    /// Take ownership, but keep the previous active intent intact until every
    /// result allocation succeeds. No mutation or send occurs at installation.
    fn install(self: *Session, arena: *std.heap.ArenaAllocator, owned: c.TableIntent, export_saved: bool) !Result {
        var intent = owned;
        errdefer intent.deinit();
        const hash = commitment(&intent);
        const description = try summary(arena.allocator(), &intent, hash);
        const result: Result = if (export_saved) .{ .compiled = .{ .intent = description, .saved = .{ .definition = p.Growth.current_definition, .bytes = try v.hex(arena.allocator(), intent.bytes) } } } else .{ .loaded = description };
        if (self.active) |*active| active.intent.deinit();
        self.active = .{ .intent = intent, .digest = hash };
        return result;
    }
    pub fn apply(self: *Session, arena: *std.heap.ArenaAllocator, client: *Client, action: Action) !Result {
        return self.applyDiagnostic(arena, client, action, null);
    }
    pub fn applyDiagnostic(self: *Session, arena: *std.heap.ArenaAllocator, client: *Client, action: Action, location: ?*f.Sql.Location) !Result {
        if (location) |value| value.* = .{};
        const allocator = arena.allocator();
        return switch (action) {
            .capabilities => .{ .capabilities = .{} },
            .schemas => |cursor| .{ .schemas = try v.Schemas.foreign(allocator, try client.schemas(if (cursor) |value| try value.native() else null)) },
            .schema_lookup => |name| .{ .schema = if (try client.schema(try .init(name))) |value| try v.Namespace.foreign(allocator, value) else null },
            .schema_status => |request| .{ .schema_outcome = if (try client.schemaStatus(try request.native())) |value| try v.SchemaOutcome.foreign(allocator, value) else null },
            .prepare_schema => |request| .{ .prepared = try (try client.prepareControl(.{ .schema = try request.native() })).save(allocator) },
            .prepare_schema_plan => |plan| .{ .prepared = try (try client.prepareSchemaPlan(try plan.native())).save(allocator) },
            .compile_authorization => |value| .{ .authorization_plan = try v.AuthorizationPlan.foreign(allocator, try c.AuthorizationSql.compile(client, allocator, value.sql, value.identity, location)) },
            .describe => blk: {
                const value = try client.describe();
                break :blk .{ .description = .{ .configuration = try v.Configuration.foreign(allocator, value.configuration), .subject = value.subject, .authorization_revision = value.authorization_revision, .resource_revision = value.resource_revision } };
            },
            .lookup => |name| blk: {
                var value = (try client.lookup(allocator, try c.TableMetadata.Name.init(name))) orelse break :blk .{ .definition = null };
                defer value.deinit();
                break :blk .{ .definition = try v.Definition.foreign(arena, value) };
            },
            .definition => |identity| blk: {
                var value = (try client.definition(allocator, try v.unsigned(identity.object), try v.unsigned(identity.revision))) orelse break :blk .{ .historical = null };
                defer value.deinit();
                break :blk .{ .historical = try v.HistoricalDefinition.foreign(arena, value) };
            },
            .list => |cursor| .{ .page = try v.Page.foreign(allocator, try client.list(if (cursor) |value| try value.native() else null)) },
            .compile => |value| blk: {
                var identity = try value.identity.native();
                identity.create_object = if (value.create_object) |id| try v.unsigned(id) else null;
                break :blk try self.install(arena, try client.compile(self.allocator, value.sql, identity, location), true);
            },
            .prepare => |value| blk: {
                // Validate local shape/identities before acquiring any source.
                if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
                _ = try value.identity.native();
                const name = try c.TableMetadata.Name.init(value.name);
                var current = if (value.action == .create) null else try client.lookup(allocator, name);
                defer if (current) |*entry| entry.deinit();
                break :blk try self.install(arena, try c.TableTyped.intent(self.allocator, client.connection, value, current), true);
            },
            .load => |value| blk: {
                if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
                const bytes = try v.unhex(allocator, value.bytes, c.TableIntent.max_bytes);
                var intent = try c.TableIntent.restore(self.allocator, bytes);
                client.connection.header(intent.header) catch |err| {
                    intent.deinit();
                    return err;
                };
                break :blk try self.install(arena, intent, false);
            },
            .forget => |reference| blk: {
                _ = try self.get(reference, client.connection);
                self.active.?.intent.deinit();
                self.active = null;
                break :blk .forgotten;
            },
            .next => |reference| blk: {
                const intent = try self.get(reference, client.connection);
                break :blk .{ .next = switch (try client.next(intent)) {
                    .send => |value| .{ .send = try value.save(allocator) },
                    .running => .running,
                    .terminal => |value| .{ .terminal = try v.Outcome.foreign(allocator, intent, value) },
                    .upload_cancelled => .upload_cancelled,
                } };
            },
            .status => |reference| blk: {
                const intent = try self.get(reference, client.connection);
                const value = try client.inspectIntent(intent);
                break :blk .{ .state = .{ .outcome = if (value.outcome) |outcome| try v.Outcome.foreign(allocator, intent, outcome) else null, .upload = if (value.upload) |upload| try v.Upload.foreign(upload) else null } };
            },
            .prepare_resume => |reference| .{ .prepared = try (try client.prepareResume(try self.get(reference, client.connection))).save(allocator) },
            .prepare_control => |value| blk: {
                const intent = try self.get(value.intent, client.connection);
                const command: c.TableControl.Command = switch (value.control) {
                    .cancel_operation => switch (intent.identity) {
                        .ddl => |ref| .{ .cancel_ddl = ref },
                        .dml => |ref| .{ .cancel_dml = .{ .scope = intent.header.scope, .reference = ref.reference } },
                    },
                    .cleanup_operation => switch (intent.identity) {
                        .ddl => |ref| .{ .cleanup_ddl = ref },
                        .dml => |ref| .{ .cleanup_dml = .{ .scope = intent.header.scope, .reference = ref.reference } },
                    },
                    .cancel_upload => .{ .cancel_upload = intent.upload() },
                    .collect_upload => .{ .collect_upload = intent.upload() },
                };
                break :blk .{ .prepared = try (try client.prepareControl(command)).save(allocator) };
            },
            .prepare_initialize => |value| .{ .prepared = try (try client.prepareControl(.{ .initialize = try value.native() })).save(allocator) },
            .prepare_dependency => |value| .{ .prepared = try (try client.prepareControl(.{ .dependency = try value.native() })).save(allocator) },
            .submit => |value| .{ .receipt = try client.submit(try prepared(allocator, value)) },
            .receipt => |value| .{ .receipt_status = try client.receipt(try prepared(allocator, value)) },
            .observe => |value| .{ .observation = try client.observe(try prepared(allocator, value.prepared), value.input) },
            .wait_observe => |value| .{ .observation = try client.waitObserve(try prepared(allocator, value.prepared), value.input) },
            .input_disposition => |value| .{ .disposition = if (try client.inputDisposition(try prepared(allocator, value.prepared), value.input)) |result| try v.Disposition.foreign(result) else null },
            .progress, .wait_progress => |value| blk: {
                const intent = try self.get(value.intent, client.connection);
                const command = try prepared(allocator, value.prepared);
                const progress = if (action == .progress) try client.progress(intent, command, value.input) else try client.waitProgress(intent, command, value.input);
                break :blk .{ .progress = switch (progress) {
                    .pending => .pending,
                    .processed => |result| .{ .processed = .{ .disposition = if (result.disposition) |disposition| try v.Disposition.foreign(disposition) else null, .outcome = if (result.outcome) |outcome| try v.Outcome.foreign(allocator, intent, outcome) else null, .upload = if (result.upload) |upload| try v.Upload.foreign(upload) else null } },
                } };
            },
        };
    }
};

//! Shared host-side direct caller. Loading owns one immutable local intent;
//! staging, admission, execution and observation are explicit separate calls.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const f = c.fuze;
const h = c.DirectTableValues;
const v = c.TableValues;
const Allocator = std.mem.Allocator;
pub const max_input_bytes = 2 * c.DirectTableIntent.max_bytes + 16384;
pub const Id = struct { definition: p.Growth.Definition, digest: []const u8 };
pub const Saved = union(enum) {
    table: struct {
        pub const json_schema_text_bounds = .{ .bytes = 2 * c.DirectTableIntent.max_bytes };
        definition: p.Growth.Definition,
        namespace: u64,
        bytes: []const u8,
    },
    name_assertion: h.NameAssertion,
};
pub const Recovery = union(enum) { table: h.Reference, name_assertion: h.NameAssertion };
pub const Summary = struct {
    id: Id,
    namespace: u64,
    binding: union(enum) { table: h.Binding, name_assertion: h.NameAssertion },
};
pub const Compiled = struct { summary: Summary, saved: Saved };
pub const Action = union(enum) {
    catalog: c.DirectCatalogInspection.Action,
    administration: c.DirectCatalogAdministration.Action,
    dependencies: c.DirectCatalogDependencies.Action,
    lookup: struct { namespace: u64, name: []const u8 },
    compile: struct {
        pub const json_schema_text_bounds = .{ .sql = 4096 };
        namespace: u64,
        operation: []const u8,
        create_object: ?[]const u8,
        sql: []const u8,
        dialect: f.Sql.Dialect,
        ingestion: c.storage.TablePartition.Ingestion,
    },
    load: Saved,
    prepare: c.DirectTableTyped.Request,
    forget: Id,
    preview: Id,
    stage: Id,
    admit: Recovery,
    operation: struct { reference: Recovery, command: enum { inspect, execute, cancel }, steps: u16 },
};
pub const Result = union(enum) {
    catalog: c.DirectCatalogInspection.Result,
    administration: c.DirectCatalogAdministration.Result,
    dependencies: c.DirectCatalogDependencies.Result,
    metadata: ?h.Metadata,
    compiled: Compiled,
    loaded: Summary,
    forgotten,
    preview: h.Preview,
    staged: Recovery,
    observation: h.Observation,
};
pub fn parse(allocator: Allocator, bytes: []const u8) !std.json.Parsed(Action) {
    try f.Types.Json.preflight(bytes, .{ .bytes = max_input_bytes, .depth = 96, .tokens = 1024 * 1024, .fields = 256 });
    return p.Json.parseFromSlice(Action, allocator, bytes);
}
const Work = c.DirectTablePreparedDdl.Write;
const Entry = struct {
    namespace: u64,
    work: Work,
    digest: [32]u8,
    fn check(self: *const Entry, connection: c.DirectTableProtocol.Connection) !void {
        switch (self.work) {
            .table => |*intent| try intent.check(connection),
            .name_assertion => |binding| {
                try binding.validate();
                if (!std.meta.eql(connection, binding.connection)) return error.CatalogIdentityConflict;
            },
        }
    }
    fn summary(self: *const Entry, allocator: Allocator) !Summary {
        return .{ .id = .{ .definition = p.Growth.current_definition, .digest = try v.hex(allocator, &self.digest) }, .namespace = self.namespace, .binding = switch (self.work) {
            .table => |*intent| .{ .table = try h.Binding.foreign(allocator, intent.binding()) },
            .name_assertion => |binding| .{ .name_assertion = try h.NameAssertion.foreign(allocator, binding) },
        } };
    }
    fn saved(self: *const Entry, allocator: Allocator) !Saved {
        return switch (self.work) {
            .table => |*intent| .{ .table = .{ .definition = p.Growth.current_definition, .namespace = self.namespace, .bytes = try v.hex(allocator, intent.bytes) } },
            .name_assertion => |binding| .{ .name_assertion = try h.NameAssertion.foreign(allocator, binding) },
        };
    }
};
pub const Session = struct {
    allocator: Allocator,
    active: ?Entry = null,
    pub fn deinit(self: *Session) void {
        if (self.active) |*entry| entry.work.deinit();
        self.* = undefined;
    }
    fn get(self: *Session, id: Id, connection: c.DirectTableProtocol.Connection) !*const Entry {
        if (id.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        const digest = try v.digest(id.digest);
        const entry = if (self.active) |*value| value else return error.TableIntentNotLoaded;
        if (!std.mem.eql(u8, &entry.digest, &digest)) return error.CatalogIdentityConflict;
        try entry.check(connection);
        return entry;
    }
    /// Installation transfers owned work only after every output allocation
    /// succeeds. Failure preserves the previously loaded intent.
    fn install(self: *Session, allocator: Allocator, namespace: u64, owned: Work, export_saved: bool) !Result {
        var entry: Entry = .{ .namespace = namespace, .work = owned, .digest = undefined };
        errdefer entry.work.deinit();
        try c.Model.nativeId(namespace);
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.direct.host-work.v1\x00");
        var ns: [8]u8 = undefined;
        std.mem.writeInt(u64, &ns, namespace, .little);
        hash.update(&ns);
        switch (entry.work) {
            .table => |*intent| {
                hash.update("table\x00");
                // DDL also rejects a namespace substituted around valid bytes.
                _ = try intent.reference(namespace);
                hash.update(intent.bytes);
            },
            .name_assertion => |binding| {
                try binding.validate();
                if (namespace != binding.namespace) return error.CatalogIdentityConflict;
                hash.update("name_assertion\x00");
                const bytes = try p.Json.valueAlloc(self.allocator, binding);
                defer self.allocator.free(bytes);
                hash.update(bytes);
            },
        }
        entry.digest = hash.finalResult();
        const summary = try entry.summary(allocator);
        const result: Result = if (export_saved) .{ .compiled = .{ .summary = summary, .saved = try entry.saved(allocator) } } else .{ .loaded = summary };
        if (self.active) |*previous| previous.work.deinit();
        self.active = entry;
        return result;
    }
    pub fn apply(self: *Session, arena: *std.heap.ArenaAllocator, client: c.DirectTableClient, action: Action, location: ?*f.Sql.Location) !Result {
        const allocator = arena.allocator();
        switch (action) {
            .catalog => |input| return .{ .catalog = try c.DirectCatalogInspection.apply(allocator, client, input) },
            .administration => |input| return .{ .administration = try c.DirectCatalogAdministration.apply(allocator, client, input, location) },
            .dependencies => |input| return .{ .dependencies = try c.DirectCatalogDependencies.apply(allocator, client, input) },
            .lookup => |input| {
                const response = try client.call(.{ .lookup = .{ .namespace = input.namespace, .name = input.name } });
                defer response.deinit();
                return .{ .metadata = if (response.value.result.lookup) |value| try h.Metadata.foreign(allocator, client.connection, value) else null };
            },
            .compile => |input| {
                const operation = try v.unsigned(input.operation);
                try f.Sql.validateText(input.sql);
                var lexer: f.Sql.Lexer = .{ .text = input.sql, .dialect = input.dialect, .parameters_enabled = true };
                const first = try lexer.next();
                if (first.tag != .word) return error.InvalidTableIntent;
                if (std.ascii.eqlIgnoreCase(first.text, "INSERT") or std.ascii.eqlIgnoreCase(first.text, "UPDATE") or std.ascii.eqlIgnoreCase(first.text, "DELETE")) {
                    if (input.create_object != null) return error.InvalidTableIntent;
                    var prepared = try c.DirectTablePreparedDml.prepare(self.allocator, client, input.namespace, input.sql, input.dialect, location);
                    defer prepared.deinit();
                    return self.install(allocator, input.namespace, .{ .table = try prepared.bind(self.allocator, client, operation, &.{}, input.ingestion, location) }, true);
                }
                var prepared = try c.DirectTablePreparedDdl.prepare(self.allocator, client, input.namespace, input.sql, input.dialect, location);
                defer prepared.deinit();
                return self.install(allocator, input.namespace, try prepared.bind(self.allocator, client, operation, if (input.create_object) |value| try v.unsigned(value) else null), true);
            },
            .load => |saved| {
                const namespace = switch (saved) {
                    .table => |value| value.namespace,
                    .name_assertion => |value| value.namespace,
                };
                var work: Work = switch (saved) {
                    .table => |value| table: {
                        if (value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
                        const bytes = try v.unhex(allocator, value.bytes, c.DirectTableIntent.max_bytes);
                        break :table .{ .table = try c.DirectTableIntent.restore(self.allocator, bytes) };
                    },
                    .name_assertion => |value| .{ .name_assertion = try value.native() },
                };
                const temporary: Entry = .{ .namespace = namespace, .work = work, .digest = undefined };
                temporary.check(client.connection) catch |err| {
                    work.deinit();
                    return err;
                };
                return self.install(allocator, namespace, work, false);
            },
            .prepare => |input| return self.install(allocator, input.namespace, try c.DirectTableTyped.prepare(self.allocator, client, input), true),
            .forget => |id| {
                _ = try self.get(id, client.connection);
                self.active.?.work.deinit();
                self.active = null;
                return .forgotten;
            },
            .preview => |id| {
                const entry = try self.get(id, client.connection);
                const response = try client.call(switch (entry.work) {
                    .table => |*intent| switch (intent.parsed.value.work) {
                        .ddl => |value| .{ .preview = value },
                        .rows => |value| .{ .preview_rows = value },
                        .statement => |value| .{ .preview_statement = value },
                    },
                    .name_assertion => |binding| .{ .name_preview = binding },
                });
                defer response.deinit();
                return .{ .preview = try h.Preview.foreign(allocator, response.value.result) };
            },
            .stage => |id| {
                const entry = try self.get(id, client.connection);
                return .{ .staged = switch (entry.work) {
                    .table => |*intent| .{ .table = try h.Reference.foreign(allocator, try intent.stage(client, entry.namespace)) },
                    .name_assertion => |binding| .{ .name_assertion = try h.NameAssertion.foreign(allocator, binding) },
                } };
            },
            .admit => |reference| return observe(allocator, client, reference, .admit, 1),
            .operation => |input| return observe(allocator, client, input.reference, switch (input.command) {
                .inspect => .inspect,
                .execute => .execute,
                .cancel => .cancel,
            }, input.steps),
        }
    }
};
fn observe(allocator: Allocator, client: c.DirectTableClient, reference: Recovery, command: enum { admit, inspect, execute, cancel }, steps: u16) !Result {
    const response = switch (reference) {
        .table => |value| table: {
            const original = try value.native();
            break :table if (command == .admit) try original.admit(client) else try original.operation(client, switch (command) {
                .inspect => .inspect,
                .execute => .execute,
                .cancel => .cancel,
                .admit => unreachable,
            }, steps);
        },
        .name_assertion => |value| assertion: {
            const binding = try value.native();
            if (!std.meta.eql(binding.connection, client.connection)) return error.CatalogIdentityConflict;
            if (command == .execute) return error.InvalidCatalogAssertion;
            break :assertion try client.call(.{ .name_assertion = .{ .binding = binding, .command = switch (command) {
                .admit => .accept,
                .inspect => .inspect,
                .cancel => .cancel,
                .execute => unreachable,
            } } });
        },
    };
    defer response.deinit();
    return .{ .observation = try h.Observation.foreign(allocator, response.value.result) };
}

test "direct host session restores without I/O and preserves loaded work on allocation failure" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Fixture = struct { saved: c.DirectTableIntent.Saved, base64: []const u8 };
    const fixture = try p.Json.parseFromSlice(Fixture, a, @embedFile("fixtures/direct-table-intent-v1.json"));
    defer fixture.deinit();
    const bytes = try (c.DirectTableProtocol.Binary{ .base64 = fixture.value.base64 }).decode(a, c.DirectTableIntent.max_bytes);
    var wire = c.station.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    const client: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &wire, .service = &wire, .connection = fixture.value.saved.connection, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1)) };
    var session: Session = .{ .allocator = t.allocator };
    defer session.deinit();
    const saved: Saved = .{ .table = .{ .definition = p.Growth.current_definition, .namespace = 1, .bytes = try v.hex(a, bytes) } };
    const original = (try session.apply(&arena, client, .{ .load = saved }, null)).loaded;
    var failing = t.FailingAllocator.init(t.allocator, .{ .fail_index = 0 });
    try t.expectError(error.OutOfMemory, session.install(failing.allocator(), 1, .{ .table = try c.DirectTableIntent.restore(t.allocator, bytes) }, false));
    try t.expectEqualDeep(original, try (try session.get(original.id, client.connection)).summary(a));
    var wrong_namespace = saved;
    wrong_namespace.table.namespace = 2;
    try t.expectError(error.DataIdentityConflict, session.apply(&arena, client, .{ .load = wrong_namespace }, null));
    try t.expectEqualDeep(original, try (try session.get(original.id, client.connection)).summary(a));
    var wrong_client = client;
    wrong_client.connection.principal += 1;
    try t.expectError(error.CatalogIdentityConflict, session.apply(&arena, wrong_client, .{ .load = saved }, null));
    try t.expectEqualDeep(original, try (try session.get(original.id, client.connection)).summary(a));
    _ = try session.apply(&arena, client, .{ .forget = original.id }, null);
    try t.expectError(error.TableIntentNotLoaded, session.get(original.id, client.connection));
}

//! Common native transaction composition for an ordered program. Preparation
//! freezes targets and limits; staging returns metadata that the invocation
//! owner must persist before execution. No method settles an uncertain write
//! under another identity.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const p = q.protocol;
const d = p.DataLifecycle;
const x = p.Transaction;
const T = c.DirectClientToken;
const Tx = c.DirectTransactionClient;
/// All resources used by the block are selected before acquisition. Source
/// Queue consumption uses its original partition; partitioned append targets
/// include every possible destination because their keys may depend on reads.
/// The caller supplies reviewed native limits and retains the returned Begin.
pub fn prepareBegin(output: std.mem.Allocator, value: q.ApplicationDeclaration, executor_role: u64, claim: p.StreamQueue.Claim, key: T.Key, operation: d.Operation) !c.DirectTransactionRequest.Begin {
    try value.validate(output);
    try p.Authorization.roleId(executor_role);
    if (executor_role == 0) return error.InvalidAuthorizationRole;
    try claim.validate();
    const limits = value.limits.transaction;
    try limits.validate();
    var bound = try value.bind(output);
    defer bound.deinit();
    var connection = value.connection;
    connection.role = executor_role;
    if (!std.meta.eql(claim, try value.inputClaim(output, claim.target.partition, claim.operation)) or
        !std.meta.eql(key.connection, connection)) return error.DataflowIdentityConflict;
    var count: u64 = 1; // The control KV publishes the continuation.
    for (bound.uses) |use| {
        const resource = value.resources[use.resource];
        if (resource.value == .sink) continue;
        count = try std.math.add(u64, count, if (resource.value == .log and use.write)
            resource.value.log.declaration.stored.declaration.configuration.partitioning.count
        else
            1);
    }
    if (count > limits.participants or count > 100_000 or count > value.limits.requests) return error.TransactionCapacity;
    const targets = try output.alloc(x.Target, @intCast(count));
    errdefer output.free(targets);
    targets[0] = .{ .object = value.object, .kind = .kv, .partition = null };
    var at: usize = 1;
    for (bound.uses) |use| {
        const resource = value.resources[use.resource];
        if (resource.value == .sink) continue;
        const object = resource.interpretation().object;
        if (resource.value == .log) {
            const log = resource.value.log.declaration;
            const count_ = if (use.write) log.stored.declaration.configuration.partitioning.count else 1;
            for (0..count_) |ordinal| {
                const partition: u32 = if (use.write) @intCast(ordinal) else claim.target.partition;
                if (!use.write and (!use.consume or !std.meta.eql(object, claim.target.interpretation.object))) return error.ProgramResourceKindMismatch;
                targets[at] = .{ .object = object, .kind = if (log.kind() == .queue) .queue else .stream, .partition = partition };
                at += 1;
            }
        } else {
            // The current SQL row Document is a TablePartition with an
            // immutable Document policy. It is not a tree DocumentPartition.
            targets[at] = .{ .object = object, .kind = if (resource.value == .kv) .kv else .table, .partition = null };
            at += 1;
        }
    }
    std.mem.sort(x.Target, targets, {}, struct {
        fn less(_: void, left: x.Target, right: x.Target) bool {
            return left.order(right) == .lt;
        }
    }.less);
    const request: c.DirectTransactionRequest.Begin = .{
        .key = key,
        .fingerprint = try value.digest(output),
        .operation = operation,
        .namespace = value.namespace,
        .mode = .serializable,
        .deadline = null,
        .execution = null,
        .selection = .{ .explicit_objects = targets },
        .limits = limits,
        .budget = .{},
    };
    try request.validate();
    return request;
}

pub fn privateClient(client: c.DirectTableClient, key: T.Key) !c.DirectTableClient {
    var result = client;
    const tx: Tx = .{ .catalog = client };
    const status = try tx.inspect(key);
    if (!status.acquired or status.attempt != null) return error.TransactionCutNotAcquired;
    result.transaction = .{ .key = key, .revision = status.revision };
    return result;
}

/// Exact metadata comes from the existing transaction view. Name resolution
/// cannot substitute a new native resource definition after compilation.
pub fn table(client: c.DirectTableClient, binding: q.ApplicationBinding) !c.DirectTableClient.OwnedResponse {
    if (client.transaction == null or binding.value != .table) return error.InvalidTransactionRead;
    const response = try client.call(if (binding.kind() == .document) .{ .document_lookup = .{ .namespace = binding.namespace(), .name = binding.name().slice() } } else .{ .lookup = .{ .namespace = binding.namespace(), .name = binding.name().slice() } });
    errdefer response.deinit();
    const metadata = try tableMetadata(response.value.result);
    if (!std.meta.eql(metadata.interpretation.interpretation, binding.interpretation()) or metadata.workspace == null) return error.TableDefinitionChanged;
    return response;
}
pub fn tableMetadata(result: c.DirectTableProtocol.Result) !c.DirectTableProtocol.Definition {
    return switch (result) {
        .lookup => |value| value orelse error.TableNotFound,
        .document_lookup => |value| (value orelse return error.TableNotFound).definition,
        else => error.InvalidTableResponse,
    };
}
pub fn snapshot(metadata: c.DirectTableProtocol.Definition) !c.DirectTableProtocol.Snapshot {
    const view = metadata.workspace orelse return error.InvalidTransactionRead;
    return .{ .object = metadata.interpretation.interpretation.object, .handle = .{ .owner = view.cut.begin.identity.begin, .content = view.private } };
}

/// Only the native statement completion advances an instruction. The result
/// remains provisional until the common transaction decides; all native
/// rejection reasons survive without a parallel application outcome protocol.
pub fn execute(client: c.DirectTableClient, key: T.Key, statement: c.DirectTransactionWorkspace.StatementWork) !c.DirectTransactionWorkspace.StatementCompletion {
    try statement.validate();
    const tx: Tx = .{ .catalog = client };
    const result: c.DirectTransactionWorkspace.StatementCompletion = switch (statement) {
        .state => |request| .{ .state = .{ .request = request, .outcome = try tx.execute(key, request) } },
        .log => |request| .{ .log = .{ .request = request, .outcome = try tx.executeLog(key, request) } },
    };
    try result.validate();
    return result;
}

test "application transactions select exact mixed owners and bound partition expansion" {
    const t = std.testing;
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const allocator = output.allocator();
    const connection: c.DirectTableProtocol.Connection = .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .audience = 5, .principal = 4, .role = 6 };
    const object = struct {
        fn get(id: u64) d.Object {
            return .{ .scope = .{ .realm = 42, .resource = 3, .catalog = 9 }, .branch = 1, .object = id };
        }
    }.get;
    var bindings: [5]q.ApplicationBinding = undefined;
    for ([_][]const u8{ "CREATE QUEUE jobs (id BIGINT NOT NULL, payload_key BINARY NOT NULL, request_id UUID NOT NULL)", "CREATE STREAM outcomes (id BIGINT NOT NULL)" }, 0..) |source, index| {
        var parsed = try q.fuze.LogDdl.compile(t.allocator, source, .transit, null);
        defer parsed.deinit();
        const id: u64 = if (index == 0) 7 else 10;
        const schema = try parsed.statement.action.create.bind(id);
        var configuration = try parsed.statement.configure(null, schema);
        configuration.configuration.partitioning.count = if (index == 0) 2 else 3;
        configuration.configuration.partitioning.key_column = 1;
        const properties: c.DirectCatalog.Properties = .{ .namespace = 1, .name = try .init(if (index == 0) "jobs" else "outcomes"), .authorization = 100 + id };
        var properties_buffer: [4096]u8 = undefined;
        var native = try c.storage.LogDeclaration.prepare(t.allocator, .{ .object = object(id), .revision = 1, .schema = schema, .configuration = configuration.configuration, .limits = configuration.limits, .properties = try properties.encode(&properties_buffer) });
        defer native.deinit();
        const stored = try native.stored();
        var buffer: [q.fuze.TableSchema.max_bytes]u8 = undefined;
        bindings[index] = .{ .value = .{ .log = .{ .declaration = .{ .stored = stored, .properties = properties, .seed = stored, .initialization = .{ .scope = connection.scope, .principal = 4, .operation = 1000 + id }, .first_partition = 1 }, .schema = try c.DirectTableProtocol.Binary.encode(allocator, try schema.encode(&buffer)) } } };
    }
    const spec: c.storage.KVDeclaration.Spec = .{ .value_type = .row, .nullable = false, .fields = &.{.{ .name = "id", .type = .int64, .nullable = false }} };
    const kv_properties: c.DirectCatalog.Properties = .{ .namespace = 1, .name = try .init("states"), .authorization = 108 };
    var properties_buffer: [4096]u8 = undefined;
    var kv = try c.storage.KVDeclaration.prepare(t.allocator, .{ .object = object(8), .revision = 1, .spec = spec, .properties = try kv_properties.encode(&properties_buffer) });
    defer kv.deinit();
    bindings[2] = .{ .value = .{ .kv = .{ .stored = try kv.stored(), .spec = spec, .properties = kv_properties } } };
    const table_schema: q.fuze.TableSchema.Schema = .{ .object = 9, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }}, .primary_key = &.{1} };
    const table_properties: c.DirectCatalog.Properties = .{ .namespace = 1, .name = try .init("items"), .authorization = 109 };
    var native_table = try c.storage.TableDeclaration.prepare(t.allocator, .{ .kind = .table, .object = object(9), .revision = 1, .schema = table_schema, .properties = try table_properties.encode(&properties_buffer) });
    defer native_table.deinit();
    var schema_buffer: [q.fuze.TableSchema.max_bytes]u8 = undefined;
    bindings[3] = .{ .value = .{ .table = .{ .stored = try native_table.stored(), .properties = table_properties, .schema = try c.DirectTableProtocol.Binary.encode(allocator, try table_schema.encode(&schema_buffer)) } } };
    const sink: c.SourceDeclaration.Definition = .{
        .definition = p.Growth.current_definition,
        .object = object(12),
        .revision = 1,
        .properties = .{ .namespace = 1, .authorization = 112, .name = try .init("exchange") },
        .owner = 6,
        .payload = .{ .sink = .{ .connection = .{ .object = object(13), .revision = 1, .digest = @splat(1) }, .http = .{
            .method = .POST,
            .path = "/token",
            .request_encoding = .form,
            .accept = "application/json",
            .user_agent = null,
            .response = .protected_json,
            .capture = .redacted_metadata,
            .request_timeout_ms = 5000,
            .response_max_bytes = 65536,
            .follow_redirects = false,
            .max_attempts = 1,
            .unknown_outcome = .retain,
        } } },
    };
    bindings[4] = .{ .value = .{ .sink = .{ .stored = try sink.stored(t.allocator), .profile = sink.payload.sink } } };
    const declared = try q.ApplicationDeclaration.prepare(t.allocator, .{
        .connection = connection,
        .namespace = 1,
        .object = 11,
        .operation = 2000,
        .source =
        \\CREATE DATAFLOW apply_event FROM QUEUE jobs AS event AS BEGIN
        \\ LET result = EXECUTE SINK exchange EFFECT OPERATION_ID(event.request_id, 'exchange')
        \\  GUARD TRUE FORM (value = 'test') ON REPLAY OBSERVE ONLY;
        \\ BEGIN ATOMIC
        \\  PUT INTO states KEY event.payload_key VALUE ROW(event.id) IF ABSENT;
        \\  INSERT INTO items VALUES (event.id) ON CONFLICT (id) DO ASSERT SAME ROW;
        \\  PRODUCE INTO outcomes VALUES (event.id);
        \\ END;
        \\END;
        ,
        .resources = &bindings,
        .limits = .{ .requests = 1000, .scan_rows = 1000, .result_bytes = 65536, .continuation_bytes = 65536, .retained_bytes = 64 * 1024 * 1024, .transaction = c.DirectTransaction.default_limits },
    });
    defer declared.deinit();
    var value = declared.value;
    const claim = try value.inputClaim(t.allocator, 1, .{ .scope = connection.scope, .principal = 4, .operation = 2001 });
    const key: T.Key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(3), .token = @splat(4) };
    const operation: d.Operation = .{ .scope = connection.scope, .principal = 4, .operation = 2002 };
    var limits = c.DirectTransaction.default_limits;
    limits.participants = 7;
    value.limits.transaction = limits;
    const begin = try prepareBegin(allocator, value, 6, claim, key, operation);
    const expected = [_]x.Target{
        .{ .object = object(7), .kind = .queue, .partition = 1 },
        .{ .object = object(8), .kind = .kv, .partition = null },
        .{ .object = object(9), .kind = .table, .partition = null },
        .{ .object = object(10), .kind = .stream, .partition = 0 },
        .{ .object = object(10), .kind = .stream, .partition = 1 },
        .{ .object = object(10), .kind = .stream, .partition = 2 },
        .{ .object = object(11), .kind = .kv, .partition = null },
    };
    try t.expectEqualDeep(@as([]const x.Target, &expected), begin.selection.explicit_objects);
    // Dispatch is a control dependency, never a fictitious Table participant.
    var bound = try value.bind(t.allocator);
    defer bound.deinit();
    var dispatch = false;
    for (bound.uses) |use| if (use.dispatch) {
        dispatch = true;
        try t.expectEqual(c.SourceAuthority.inspect | c.SourceAuthority.use, try value.resources[use.resource].privileges(use));
    };
    try t.expect(dispatch);
    try t.expectEqual(.serializable, begin.mode);
    value.limits.transaction.participants = 6;
    try t.expectError(error.TransactionCapacity, prepareBegin(allocator, value, 6, claim, key, operation));
    var foreign = key;
    foreign.connection.role = 8;
    try t.expectError(error.DataflowIdentityConflict, prepareBegin(allocator, value, 6, claim, foreign, operation));
}

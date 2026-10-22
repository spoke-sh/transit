//! The existing neutral catalog lifecycle over an authenticated Table service.
//! Local intent ownership and native mutation submission remain with the caller.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const B = c.TableBridge;
const p = q.protocol;
const Service = q.TableService;
const Mediated = q.MediatedTableClient;
fn saved(allocator: std.mem.Allocator, session: *B.Session, connection: c.TableClient.Connection, reference: B.Reference) !B.Saved {
    const intent = try session.get(reference, connection);
    return .{ .definition = p.Growth.current_definition, .bytes = try c.TableValues.hex(allocator, intent.bytes) };
}
fn sequence(client: *c.TableClient) !u64 {
    const authority: q.wire.AuthorizationClient = .{ .transport = client.transport, .realm = client.connection.scope.realm, .principal = client.connection.principal, .role = client.connection.role, .key = client.key };
    const observation = try authority.read(.identity);
    return std.math.add(u64, observation.principal_sequence, 1);
}
fn retain(arena: *std.heap.ArenaAllocator, result: B.Result) !B.Result {
    const bytes = try p.Json.valueAlloc(arena.allocator(), result);
    return std.json.parseFromSliceLeaky(B.Result, arena.allocator(), bytes, .{ .allocate = .alloc_always });
}
pub fn apply(arena: *std.heap.ArenaAllocator, session: *B.Session, client: *c.TableClient, service: *q.wire.Client, limits: q.wire.Client.OwnedLimits, action: B.Action) !B.Result {
    const allocator = arena.allocator();
    const mediated: Mediated = .{ .allocator = allocator, .authority = client.transport, .service = service, .connection = client.connection, .key = client.key, .limits = limits };
    switch (action) {
        .capabilities, .load, .forget => return session.apply(arena, client, action),
        .submit => |bytes| return .{ .receipt = try mediated.submit(try B.prepared(allocator, bytes)) },
        .receipt => |bytes| return .{ .receipt_status = try mediated.receipt(try B.prepared(allocator, bytes)) },
        .prepare_initialize, .prepare_dependency => return error.UnsupportedTableServiceAction,
        .apply => |reference| {
            var steps: usize = 0;
            const max_steps: usize = (c.TableIntent.max_bytes / c.TableUpload.part_bytes) + 64;
            while (steps < max_steps) : (steps += 1) {
                const next_res = (try apply(arena, session, client, service, limits, .{ .next = reference })).next;
                switch (next_res) {
                    .send => |prepared_bytes| {
                        const accepted = (try apply(arena, session, client, service, limits, .{ .submit = prepared_bytes })).receipt;
                        var polls: usize = 0;
                        while (polls < 64) : (polls += 1) {
                            const obs = (try apply(arena, session, client, service, limits, .{ .wait_observe = .{ .prepared = prepared_bytes, .input = accepted.position } })).observation;
                            if (obs == .processed) break;
                        }
                        if ((try apply(arena, session, client, service, limits, .{ .input_disposition = .{ .prepared = prepared_bytes, .input = accepted.position } })).disposition) |disp| {
                            switch (disp.outcome) {
                                .denied => return error.CatalogDenied,
                                .identity_conflict => return error.CatalogIdentityConflict,
                                .stale_policy => return error.CatalogPolicyConflict,
                                .invalid_command => return error.InvalidCatalogCommand,
                                .blocked => return error.CatalogDefinitionChanged,
                                else => {},
                            }
                        }
                    },
                    .running => {
                        var waits: usize = 0;
                        while (waits < 32) : (waits += 1) {
                            try client.transport.http.io.sleep(.fromMilliseconds(c.TableClient.completion_wait_ms), .awake);
                            const current_state = (try apply(arena, session, client, service, limits, .{ .status = reference })).state;
                            if (current_state.outcome) |out| if (out.terminal) return .{ .state = current_state };
                            if (current_state.upload) |up| if (up.phase == .cancelled) return error.TableUploadClosed;
                        }
                        return apply(arena, session, client, service, limits, .{ .status = reference });
                    },
                    .terminal => return apply(arena, session, client, service, limits, .{ .status = reference }),
                    .upload_cancelled => return error.TableUploadClosed,
                }
            }
            return apply(arena, session, client, service, limits, .{ .status = reference });
        },
        else => {},
    }
    const remote: Service.Action = switch (action) {
        .describe => .describe,
        .schemas => |value| .{ .schemas = value },
        .schema_lookup => |value| .{ .schema_lookup = value },
        .schema_status => |value| .{ .schema_status = value },
        .prepare_schema => |value| .{ .schema_prepare = .{ .request = value, .sequence = try sequence(client) } },
        .prepare_schema_plan => |value| .{ .schema_plan_prepare = .{ .plan = value, .sequence = try sequence(client) } },
        .compile_authorization => |value| .{ .compile_authorization = value },
        .lookup => |value| .{ .lookup = value },
        .definition => |value| .{ .definition = .{ .object = value.object, .revision = value.revision } },
        .lifecycle => |value| .{ .lifecycle = value },
        .dependents => |value| .{ .dependents = value },
        .dependencies => |value| .{ .dependencies = value },
        .policy_references => |value| .{ .policy_references = value },
        .computation => |value| .{ .computation = value },
        .list => |value| .{ .list = value },
        .compile => |value| .{ .compile = value },
        .prepare => |value| .{ .prepare = value },
        .preview => |reference| .{ .preview = try saved(allocator, session, client.connection, reference) },
        .next => |reference| .{ .next = .{ .saved = try saved(allocator, session, client.connection, reference), .sequence = try sequence(client) } },
        .status => |reference| .{ .status = try saved(allocator, session, client.connection, reference) },
        .prepare_resume => |reference| .{ .prepare_resume = .{ .saved = try saved(allocator, session, client.connection, reference), .sequence = try sequence(client) } },
        .prepare_control => |value| .{ .control = .{ .saved = try saved(allocator, session, client.connection, value.intent), .kind = value.control, .sequence = try sequence(client) } },
        .observe, .wait_observe => |value| .{ .observe = .{ .prepared = try B.prepared(allocator, value.prepared), .input = value.input } },
        .input_disposition => |value| .{ .disposition = .{ .prepared = try B.prepared(allocator, value.prepared), .input = value.input } },
        .progress, .wait_progress => |value| .{ .progress = .{ .saved = try saved(allocator, session, client.connection, value.intent), .prepared = try B.prepared(allocator, value.prepared), .input = value.input } },
        .capabilities, .load, .forget, .apply, .submit, .receipt, .prepare_initialize, .prepare_dependency => unreachable,
    };
    // Wait variants use bounded polling at this adapter. They return one fresh
    // observation; scheduling never changes authorization or implies completion.
    if (action == .wait_observe or action == .wait_progress) try client.transport.http.io.sleep(.fromMilliseconds(c.TableClient.completion_wait_ms), .awake);
    const response = try mediated.call(remote);
    defer response.deinit();
    const result: B.Result = switch (response.value.result) {
        .description => |value| .{ .description = value },
        .schemas => |value| .{ .schemas = value },
        .schema => |value| .{ .schema = value },
        .schema_outcome => |value| .{ .schema_outcome = value },
        .authorization_plan => |value| .{ .authorization_plan = value },
        .lookup => |value| .{ .definition = value },
        .definition => |value| .{ .historical = value },
        .lifecycle => |value| .{ .lifecycle = value },
        .dependencies => |value| .{ .dependencies = value },
        .policy_references => |value| .{ .policy_references = value },
        .computation => |value| .{ .computation = value },
        .preview => |value| .{ .preview = value },
        .list => |value| .{ .page = value },
        .compiled => |value| {
            var replacement: B.Session = .{ .allocator = session.allocator };
            defer replacement.deinit();
            const loaded = (try replacement.apply(arena, client, .{ .load = value.saved })).loaded;
            const expected = try p.Json.valueAlloc(allocator, loaded);
            const actual = try p.Json.valueAlloc(allocator, value.intent);
            if (!std.mem.eql(u8, expected, actual)) return error.InvalidTableServiceResponse;
            const retained = try retain(arena, .{ .compiled = value });
            if (session.active) |*previous| previous.intent.deinit();
            session.active = replacement.active;
            replacement.active = null;
            return retained;
        },
        .candidate => |value| .{ .prepared = try (try mediated.signCandidate(value)).save(allocator) },
        .next => |value| .{ .next = switch (value) {
            .send => |candidate| .{ .send = try (try mediated.signCandidate(candidate)).save(allocator) },
            .running => .running,
            .terminal => |outcome| .{ .terminal = outcome },
            .upload_cancelled => .upload_cancelled,
        } },
        .state => |value| .{ .state = value },
        .observation => |value| .{ .observation = value },
        .disposition => |value| .{ .disposition = value },
        .progress => |value| .{ .progress = value },
        .query => return error.InvalidTableServiceResponse,
    };
    return retain(arena, result);
}

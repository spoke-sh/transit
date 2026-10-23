const std = @import("std");
const t = std.testing;
const c = @import("transit_catalog");
const backend = @import("transit_backend_local");
const Policy = @import("LocalCatalogPolicy.zig");
const p = c.protocol;
const g = p.Growth;
const a = p.Authorization;
const Engine = backend.DataAuthority.Engine;
const D = c.DirectCatalog;

fn key(seed: u8) !p.Ed25519.KeyPair {
    return p.Ed25519.KeyPair.generateDeterministic(@splat(seed));
}
fn command(engine: *Engine, value: g.Command) !u64 {
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = value }, try key(17)));
}
fn outcome(engine: *Engine, id: u64) !a.Outcome {
    const response = try engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = .{ .authorization = .{ .kind = .{ .change = id } } } }, try key(17)));
    return response.body.authorization.body.change;
}
fn change(engine: *Engine, action: a.Action) !?u64 {
    const id = try command(engine, .{ .authorization = .{ .begin = .{ .expected_revision = engine.head.authorization.revision, .action = action } } });
    while (true) {
        const observed = try outcome(engine, id);
        switch (observed.status) {
            .preparing => _ = try command(engine, .{ .authorization = .{ .advance = id } }),
            .ready => _ = try command(engine, .{ .authorization = .{ .publish = id } }),
            .published => return observed.created_id,
            .abandoned => return error.UnexpectedAbandonedChange,
        }
    }
}
fn proof(engine: *Engine, context: [32]u8) !a.Proof {
    return a.Proof.sign(.{ .definition = g.current_definition, .realm = 42, .principal = 101, .credential_epoch = (try engine.principal(101)).credential_epoch, .role = null, .audience = 100, .context = context }, try key(29));
}

test "local catalog checks real native registrations, current ownership and exact request proof" {
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    var owner = try backend.Backend.open(t.allocator, t.io, tmp.dir, "native", .{});
    defer owner.deinit();
    var pages = try backend.PageStore.init(&owner, 1);
    defer pages.deinit();
    var journal: backend.Store = .{ .backend = &owner };
    var engine = try Engine.bootstrap(&journal, &pages, .{ .realm = 42, .root_key = (try key(17)).public_key.toBytes() });
    const pid = try command(&engine, .{ .spawn = .{} });
    const resource = try command(&engine, .{ .create_resource = .{ .writer = pid, .owned = false } });
    const role = (try change(&engine, .{ .create_role = .{ .name = try p.Value.init("catalog-owner"), .login = true } })).?;
    _ = try change(&engine, .{ .bind_credential = .{ .principal = 101, .role = role, .public_key = (try key(29)).public_key.toBytes() } });
    const database_domain = (try change(&engine, .{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.connect } })).?;
    const schema_domain = (try change(&engine, .{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.usage | c.TableAuthority.create } })).?;
    const table_domain = (try change(&engine, .{ .register_domain = .{ .registrar = 0, .actions = c.TableAuthority.table_actions } })).?;
    const scope: p.DataLifecycle.Scope = .{ .realm = 42, .resource = resource, .catalog = 1 };
    const database = (try change(&engine, .{ .register_object = .{ .domain = database_domain, .owner = role, .binding = try c.TableAuthority.binding(scope, .database, 0) } })).?;
    const namespace = (try change(&engine, .{ .register_object = .{ .domain = schema_domain, .owner = role, .schema = c.TableAuthority.reference(database), .binding = try c.TableAuthority.binding(scope, .schema, 1) } })).?;
    const table = (try change(&engine, .{ .register_object = .{ .domain = table_domain, .owner = role, .schema = c.TableAuthority.reference(namespace), .binding = try c.TableAuthority.binding(scope, .table, 7) } })).?;
    const config: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 100, .authority = .{ .database_domain = database_domain, .schema_domain = schema_domain, .table_domain = table_domain, .database = database, .initial_schema = 1, .initial_schema_authority = namespace }, .database_name = try c.TableAuthority.Name.init("main"), .initial_schema_name = try c.TableAuthority.Name.init("public") };
    const request_digest: [32]u8 = @splat(5);
    const signed = try proof(&engine, request_digest);
    try t.expectError(error.InvalidAuthorizationCredential, Policy.init(&engine, config, signed, @splat(6)));
    var forged = signed;
    forged.signature[0] ^= 1;
    try t.expectError(error.Forbidden, Policy.init(&engine, config, forged, request_digest));
    var policy = try Policy.init(&engine, config, signed, request_digest);
    var control: backend.DataStore = .{ .backend = &owner, .control = true };
    var data: backend.DataStore = .{ .backend = &owner };
    var catalog = try D.init(t.allocator, config, control.log(), control.objects(), data.log(), data.objects(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
    defer catalog.deinit();
    try catalog.recover();
    try catalog.initialize(policy.policy());
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
    const intent: D.Intent = .{ .namespace = 1, .name = try c.TableAuthority.Name.init("events"), .action = .{ .create = .{ .authorization = table, .schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} } } } };
    const request: D.Request = .{ .intent = intent, .binding = .{ .definition = g.current_definition, .identity = .{ .scope = scope, .principal = 101, .operation = 1 }, .target = .{ .scope = scope, .branch = 1, .object = 7 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(t.allocator) } };
    _ = try catalog.admit(request, policy.policy());
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = 0 } });
    try t.expectError(error.Forbidden, catalog.perform(request.binding, policy.policy()));
    try t.expect((try catalog.resolve(t.allocator, 1, intent.name, policy.policy())) == null);
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = role } });
    try t.expect((try catalog.perform(request.binding, policy.policy())) == .committed);
    var view = (try catalog.resolve(t.allocator, 1, intent.name, policy.policy())).?;
    defer view.deinit();
    try t.expectEqual(@as(u64, 7), view.table.root.interpretation.object.object);
    // Domain ownership works without granting the caller raw resource access.
    var raw: a.Guard = .{ .subject = .{ .signed = signed }, .requirements = @splat(null) };
    raw.requirements[0] = .{ .object = .{ .kind = .resource, .id = resource }, .privileges = p.State.permission(.read) };
    try t.expectError(error.Forbidden, engine.authorizeDomain(raw, config.audience));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = 0 } });
    try t.expectError(error.Forbidden, catalog.status(request.binding, policy.policy()));
    try t.expectError(error.Forbidden, catalog.resolve(t.allocator, 1, intent.name, policy.policy()));
    _ = try change(&engine, .{ .transfer_object = .{ .object = c.TableAuthority.reference(table), .owner = role } });
    try t.expect((try catalog.status(request.binding, policy.policy())) == .committed);
    _ = try command(&engine, .{ .retire_resource = resource });
    try t.expectError(error.StateResourceExpired, catalog.status(request.binding, policy.policy()));
}

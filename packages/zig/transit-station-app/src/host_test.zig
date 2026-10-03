const std = @import("std");
const t = std.testing;
const app = @import("root.zig");
test "host compile and visual formatting share canonical meaning without transport" {
    var config: app.Host.Config = .{ .scope = .{ .realm = 49, .application = 9, .pid = 17, .resource = 19, .namespace = .{ .value = 23 } } };
    config.operators[0] = 44;
    var wire = app.station.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    var compiled = try app.Host.run(t.allocator, &wire, config, .{ .compile = .{ .source = @embedFile("fixtures/board.sql") } });
    defer compiled.deinit();
    var formatted = try app.Host.run(t.allocator, &wire, config, .{ .format = compiled.value.compiled.definition });
    defer formatted.deinit();
    try t.expectEqualDeep(compiled.value.compiled, formatted.value.compiled);
    try t.expectEqualDeep(try app.station.Publication.Digest.of(app.Publication.format, compiled.value.compiled.canonical), compiled.value.compiled.spec);
    try t.expectError(error.InvalidApplicationProgram, app.Host.run(t.allocator, &wire, config, .{ .compile = .{ .source = "CREATE INTERFACE broken;" } }));
    try t.expectError(error.ApplicationOperatorDenied, app.Host.run(t.allocator, &wire, config, .{ .prepare = .{ .principal = 45, .sequence = .{ .value = 1 }, .command = .initialize } }));
    var signed: app.Native.Signed = .{ .prepared = try app.Native.prepare(config.scope, 45, .{ .value = 1 }, .initialize), .signature = @splat(0) };
    try t.expectError(error.ApplicationOperatorDenied, app.Host.run(t.allocator, &wire, config, .{ .submit = signed }));
    signed.prepared = try app.Native.prepare(config.scope, 44, .{ .value = 1 }, .initialize);
    signed.prepared.digest[0] ^= 1;
    try t.expectError(error.ApplicationDigestMismatch, app.Host.run(t.allocator, &wire, config, .{ .submit = signed }));
    config.operators[1] = 44;
    try t.expectError(error.InvalidApplicationOperators, config.validate());
    config.operators[1] = null;
    config.operators[2] = 46;
    try t.expectError(error.InvalidApplicationOperators, config.validate());
}

test "application host keeps declaration coordinates and exact attempt evidence" {
    var config: app.Host.Config = .{ .scope = .{ .realm = 49, .application = 9, .pid = 17, .resource = 19, .namespace = .{ .value = 23 } } };
    config.operators[0] = 44;
    var wire = app.station.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    var diagnostic: ?app.protocol.Diagnostic = null;
    try t.expectError(error.InvalidApplicationProgram, app.Host.runDiagnostic(t.allocator, &wire, config, .{ .compile = .{ .source = "\nCREATE INTERFACE broken WITH (realm = 49);" } }, &diagnostic));
    try t.expectEqualStrings("application.missing_interface_option", diagnostic.?.code.slice());
    try t.expectEqual(.not_submitted, diagnostic.?.outcome);
    try t.expectEqual(@as(u64, 2), try diagnostic.?.location.?.line.value());
    try t.expectEqualStrings("revision", diagnostic.?.facts[1].?.value.?.text.slice());
    const preceding = @embedFile("fixtures/board.sql");
    try t.expectError(error.InvalidApplicationProgram, app.Host.runDiagnostic(t.allocator, &wire, config, .{ .compile = .{ .source = preceding ++ "\nDROP INTERFACE board;" } }, &diagnostic));
    try t.expectEqual(@as(u64, preceding.len + 1), try diagnostic.?.location.?.offset.value());
    for (diagnostic.?.facts) |slot| if (slot) |fact| {
        try t.expect(fact.field != .name and fact.field != .option);
    };
    var compiled = try app.Host.compile(t.allocator, @embedFile("fixtures/board.sql"));
    defer compiled.deinit();
    var definition = compiled.value.compiled.definition;
    definition.theme = "absent";
    try t.expectError(error.InvalidApplicationProgram, app.Host.runDiagnostic(t.allocator, &wire, config, .{ .format = definition }, &diagnostic));
    try t.expectEqualStrings("application.missing_interface_reference", diagnostic.?.code.slice());
    try t.expectEqual(@as(?app.protocol.Diagnostic.Location, null), diagnostic.?.location);
    var signed: app.Native.Signed = .{ .prepared = try app.Native.prepare(config.scope, 44, .{ .value = app.protocol.max_counter }, .{ .publish = .{ .value = std.math.maxInt(u64) } }), .signature = @splat(0) };
    signed.prepared.digest[0] ^= 1;
    try t.expectError(error.ApplicationDigestMismatch, app.Host.runDiagnostic(t.allocator, &wire, config, .{ .submit = signed }, &diagnostic));
    try t.expectEqual(.not_submitted, diagnostic.?.outcome);
    try t.expectEqualStrings("application.digest_mismatch", diagnostic.?.code.slice());
    signed.prepared.digest[0] ^= 1;
    const unknown = try app.HostDiagnostic.attempt(config, .{ .submit = signed }, error.InvalidAuthorityResponse, true, null);
    try t.expectEqual(.unknown, unknown.outcome);
    try t.expectEqual(.saved_intent, unknown.evidence);
    try t.expectEqual(app.protocol.max_counter, try unknown.identity.?.sequence.?.value());
    try t.expectEqual(.resume_exact, unknown.actions[1].?.kind);
    try t.expectEqual(std.math.maxInt(u64), try unknown.facts[2].?.value.?.unsigned.value());
    const denied = try app.HostDiagnostic.attempt(config, .{ .submit = signed }, error.AccessDenied, true, .AccessDenied);
    try t.expectEqual(.not_applicable, denied.outcome);
    try t.expectEqual(.none, denied.evidence);
    try t.expectEqual(.inspect_scope, denied.actions[1].?.kind);
    const read_denied = try app.HostDiagnostic.attempt(config, .{ .prepare_read = .{ .principal = 44, .selection = .identity } }, error.AccessDenied, false, null);
    try t.expectEqual(.not_applicable, read_denied.outcome);
    try t.expectEqual(.read, read_denied.stage);
}

test "every application host cause preserves failed-read and dispatched-command evidence" {
    const config: app.Host.Config = .{ .scope = .{ .realm = 1, .application = 2, .pid = 3, .resource = 4, .namespace = .{ .value = 5 } } };
    const signed: app.Native.Signed = .{ .prepared = try app.Native.prepare(config.scope, 6, .{ .value = 7 }, .initialize), .signature = @splat(0) };
    for (app.HostDiagnostic.entries) |entry| {
        const read = try app.HostDiagnostic.attempt(config, .info, entry.cause, false, null);
        try t.expectEqualStrings(entry.code, read.code.slice());
        try t.expectEqual(entry.category, read.category);
        try t.expectEqual(.not_applicable, read.outcome);
        const sent = try app.HostDiagnostic.attempt(config, .{ .submit = signed }, entry.cause, true, null);
        const rejected = entry.cause == error.AccessDenied or entry.cause == error.Conflict or entry.cause == error.Rejected;
        try t.expectEqual(if (rejected) app.protocol.Diagnostic.Outcome.not_applicable else .unknown, sent.outcome);
        try t.expectEqualDeep(sent.identity, sent.actions[1].?.target);
        try t.expectEqual(if (rejected) app.protocol.Diagnostic.ActionKind.inspect_scope else .resume_exact, sent.actions[1].?.kind);
    }
    var invalid = config;
    var wire = app.station.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    var detail: ?app.protocol.Diagnostic = null;
    try t.expectError(error.InvalidApplicationOperators, app.Host.runDiagnostic(t.allocator, &wire, invalid, .info, &detail));
    try t.expectEqualStrings("application.invalid_operators", detail.?.code.slice());
    invalid.operators[0] = 6;
    var result = try app.Host.runDiagnostic(t.allocator, &wire, invalid, .info, &detail);
    defer result.deinit();
    try t.expect(detail == null);
}

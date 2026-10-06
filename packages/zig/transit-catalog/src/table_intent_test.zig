const std = @import("std");
const t = std.testing;
const c = @import("root.zig");
const Intent = c.TableIntent;
const scope: c.Model.Scope = .{ .realm = 1, .resource = 7, .catalog = 9 };
const schema: c.fuze.TableSchema.Schema = .{ .object = 100, .revision = 1, .next_column = 3, .columns = &.{ .{ .id = 1, .name = "id", .type = .int64 }, .{ .id = 2, .name = "name", .type = .utf8 } }, .primary_key = &.{} };
fn metadata() !c.TableMetadata.Record {
    var buffer: [c.fuze.TableSchema.max_bytes]u8 = undefined;
    return .{ .scope = scope, .object = 100, .revision = 1, .name = try c.TableMetadata.Name.init("people"), .schema = .{ .id = 1, .spec = try c.station.Publication.Digest.of(c.station.TablePages.schema_format, try schema.encode(&buffer)) }, .schema_fingerprint = try schema.fingerprint(), .principal = 17, .operation = 1, .admitted_input = 10 };
}
fn creation(allocator: std.mem.Allocator) !Intent {
    const request: c.TableDdlRequest = .{ .principal = 17, .operation = 1, .object = 100, .expected_revision = 0, .name = try c.TableMetadata.Name.init("people"), .action = .{ .create = .{ .schema = schema } } };
    return Intent.create(allocator, try c.TableCommand.fromDdl(scope, 3, request, null), std.math.maxInt(u64));
}
fn mutation(allocator: std.mem.Allocator) !Intent {
    const basis = try metadata();
    var compiled = try c.fuze.TableDml.compile(allocator, "INSERT INTO people VALUES (1, '人々'), (1, NULL)", "people", schema, null);
    defer compiled.deinit();
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = .{ .id = 1, .spec = try basis.spec() }, .plan = compiled.plan };
    return Intent.create(allocator, try c.TableCommand.fromDml(scope, 3, request, basis), 1000);
}
test "saved typed intent restores original bytes schema counts and coordinator without source access" {
    for (0..2) |index| {
        var original = if (index == 0) try creation(t.allocator) else try mutation(t.allocator);
        defer original.deinit();
        const bytes = try t.allocator.dupe(u8, original.bytes);
        defer t.allocator.free(bytes);
        var restored = try Intent.restore(t.allocator, bytes);
        defer restored.deinit();
        @memset(bytes, 0);
        try t.expectEqualSlices(u8, original.bytes, restored.bytes);
        try t.expectEqualDeep(original.identity, restored.identity);
        try t.expectEqualDeep(original.spec, restored.spec);
        var command = try restored.command(t.allocator);
        defer command.deinit();
        if (index == 0) {
            try t.expectEqual(null, restored.metadata);
            try t.expectEqual(@as(usize, 0), restored.schema_bytes.len);
            try t.expectEqual(std.math.maxInt(u64), restored.namespace);
            try t.expectEqualDeep(schema, command.body.request.ddl.action.create.schema);
        } else {
            try t.expectEqual(.statement, restored.identity.dml.route);
            try t.expectEqual(@as(u64, 2), restored.identity.dml.reference.operation);
            try t.expectEqual(@as(usize, 2), command.body.request.dml.plan.action.insert.len);
            try t.expectEqualDeep(schema, command.body.request.dml.plan.schema);
            try t.expectEqualDeep(try metadata(), restored.metadata.?);
        }
        for (0..original.bytes.len) |length| {
            if (Intent.restore(t.allocator, original.bytes[0..length])) |valid| {
                var unexpected = valid;
                unexpected.deinit();
                return error.TestUnexpectedResult;
            } else |_| {}
        }
        const changed = try t.allocator.dupe(u8, original.bytes);
        defer t.allocator.free(changed);
        changed[4] ^= 1;
        try t.expectError(error.IncompatibleDefinition, Intent.restore(t.allocator, changed));
        @memcpy(changed, original.bytes);
        @memset(changed[36..44], 0);
        try t.expectError(error.InvalidTableIntent, Intent.restore(t.allocator, changed));
    }
}
test "saved intent refuses substitution of original metadata schema and signed transport steps" {
    var original = try mutation(t.allocator);
    defer original.deinit();
    const header: c.TableControl.Begin = .{ .header = try original.header.encode(), .namespace = original.namespace, .spec = original.spec };
    try t.expect(try original.matches(try (c.TableControl.Command{ .begin = header }).encode()));
    var changed = header;
    changed.namespace += 1;
    try t.expect(!try original.matches(try (c.TableControl.Command{ .begin = changed }).encode()));
    changed = header;
    changed.spec.digest[0] ^= 1;
    try t.expect(!try original.matches(try (c.TableControl.Command{ .begin = changed }).encode()));
    var part = try c.TableControl.Part.init(original.upload(), 0, original.body[0..128]);
    try t.expect(try original.matches(try (c.TableControl.Command{ .part = part }).encode()));
    part.bytes[0] ^= 1;
    try t.expect(!try original.matches(try (c.TableControl.Command{ .part = part }).encode()));
    try t.expect(try original.matches(try (c.TableControl.Command{ .drive = original.upload() }).encode()));
    try t.expect(try original.matches(try (c.TableControl.Command{ .cancel_dml = .{ .scope = scope, .reference = original.identity.dml.reference } }).encode()));
    try t.expect(!try original.matches(try (c.TableControl.Command{ .cancel_ddl = .{ .scope = scope, .principal = 17, .operation = 2, .digest = original.identity.dml.reference.digest } }).encode()));
    const bytes = try t.allocator.dupe(u8, original.bytes);
    defer t.allocator.free(bytes);
    const schema_start = Intent.prefix_bytes + std.mem.readInt(u16, bytes[44..46], .little);
    bytes[schema_start + 10] ^= 1;
    try t.expectError(error.CatalogDefinitionChanged, Intent.restore(t.allocator, bytes));
}
fn failureSchedule(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var restored = try Intent.restore(allocator, bytes);
    defer restored.deinit();
    var command = try restored.command(allocator);
    defer command.deinit();
    try t.expectEqualDeep(schema, command.body.request.dml.plan.schema);
}
test "saved typed intent owns allocation failure cleanup" {
    var original = try mutation(t.allocator);
    defer original.deinit();
    try t.checkAllAllocationFailures(t.allocator, failureSchedule, .{original.bytes});
}

test "saved rename intent matches independent bytes without a redundant schema" {
    const Fixture = struct { rename_intent_hex: []const u8, rename_command_hex: []const u8 };
    const parsed = try std.json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/table-metadata.json"), .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    var bytes: [2048]u8 = undefined;
    var intent = try Intent.restore(t.allocator, try std.fmt.hexToBytes(&bytes, parsed.value.rename_intent_hex));
    defer intent.deinit();
    var body: [1024]u8 = undefined;
    try t.expectEqualSlices(u8, try std.fmt.hexToBytes(&body, parsed.value.rename_command_hex), intent.body);
    try t.expectEqual(std.math.maxInt(u64), intent.namespace);
    try t.expectEqual(@as(usize, 0), intent.schema_bytes.len);
    try t.expectEqual(.rename, intent.header.kind);
    try t.expect(try intent.matches(try c.protocol.Value.init(intent.body)));
    try t.expect(try intent.matches(try (c.TableControl.Command{ .cancel_ddl = intent.identity.ddl }).encode()));
}

test "saved wide typed intent takes bounded large workspace and restores complete values" {
    const basis = try metadata();
    const text = try t.allocator.alloc(u8, 20000);
    defer t.allocator.free(text);
    @memset(text, 'x');
    const cells = [_]c.fuze.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = 5 } } }, .{ .value = .{ .atom = .{ .bytes = text } } } };
    const request: c.TableDmlRequest = .{ .principal = 17, .operation = 2, .metadata = .{ .id = 1, .spec = try basis.spec() }, .plan = .{ .name = "people", .schema = schema, .action = .{ .insert = &.{&cells} } } };
    var intent = try Intent.create(t.allocator, try c.TableCommand.fromDml(scope, 3, request, basis), 1000);
    defer intent.deinit();
    @memset(text, 'z');
    try t.expect(intent.body.len > 20000 and intent.body.len < 21000);
    var restored = try Intent.restore(t.allocator, intent.bytes);
    defer restored.deinit();
    var decoded = try restored.command(t.allocator);
    defer decoded.deinit();
    const value = decoded.body.request.dml.plan.action.insert[0][1].value.atom.bytes;
    try t.expectEqual(@as(usize, 20000), value.len);
    for (value) |byte| try t.expectEqual(@as(u8, 'x'), byte);
}

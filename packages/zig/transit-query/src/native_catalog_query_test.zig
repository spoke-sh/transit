//! Query contract checks with injected native authorization. Direct HTTP proofs
//! own Table lifecycle, retention and result disclosure evidence.
const std = @import("std");
const e = std.testing;
const q = @import("transit_query");
const f = q.fuze;
const c = q.catalog;
const s = q.station;
const r = q.UnifiedRecords;
const Store = q.testing.Store;
const scope: q.protocol.DataLifecycle.Scope = .{ .realm = 1, .resource = 17, .catalog = 9 };
const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 1000, .result_bytes = 1048576 };
const authority: c.DirectReadAuthority = .{ .database = 4, .schema = 5, .table = 100 };
fn publicationSubject(turn: *s.Turn, bundle: q.Bundle) !void {
    try bundle.bindSubject(turn, 9, 8, 17);
    try q.CapturedTablePin.authorizeSource(turn, bundle.retention.?, authority);
}
fn seal(allocator: std.mem.Allocator, description: q.Bundle, epoch: u64, role: u64) !q.Bundle {
    var bundle = description;
    bundle.authorization = null;
    bundle.retention.?.proof.claim.credential_epoch = epoch;
    bundle.retention.?.proof.claim.role = role;
    bundle.retention.?.binding.connection.role = role;
    bundle.retention.?.proof.claim.context = try bundle.retention.?.binding.context(allocator);
    const key = try c.testing.Authority.key(17);
    bundle.retention.?.proof = try q.protocol.Authorization.Proof.sign(bundle.retention.?.proof.claim, key);
    bundle = try Store.signQuery(bundle, 17, 3, 9, 8);
    bundle.authorization.?.proof.claim.credential_epoch = epoch;
    bundle.authorization.?.proof.claim.role = role;
    bundle.authorization.?.proof = try q.protocol.Authorization.Proof.sign(bundle.authorization.?.proof.claim, key);
    return bundle;
}
test "direct native contracts reject changed execution proofs and current denial before publication" {
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    var store: Store = .{};
    defer store.deinit();
    // An offline declaration supplies contract input only. No fake catalog
    // admission, retained Table handle or stored rows are asserted here.
    const schema: f.TableSchema.Schema = .{ .object = 100, .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "id", .type = .int64 }} };
    var declaration = try c.storage.TableDeclaration.prepare(alloc, .{ .object = .{ .scope = scope, .branch = 1, .object = 100 }, .revision = 1, .schema = schema, .properties = "" });
    defer declaration.deinit();
    var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
    const table: q.TableSource = .{ .scope = scope, .owner = 19, .branch = 1, .namespace = 1, .object = 100, .interpretation = try declaration.stored(), .row_type = try schema.rowType(&fields) };
    var description = try q.Bundle.fromSql(alloc, .{ .resource = scope.resource, .source = .{ .table = table } }, "items", "SELECT * FROM items LIMIT 0", limits);
    const binding: c.DirectReadDelegation.Binding = .{ .definition = q.protocol.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 19, .principal = 17, .role = 17 }, .executor = 2, .interpretation = table.interpretation.interpretation, .expected = .{ .partition = 1, .next_lsn = 10 }, .owner = .{ .scope = scope, .principal = 17, .operation = 1 }, .retention = .snapshot, .purpose = try description.retentionPurpose(3, 7, 9, 8) };
    description.retention = .{ .binding = binding, .proof = .{ .claim = .{ .definition = q.protocol.Growth.current_definition, .realm = 1, .principal = 17, .credential_epoch = 1, .role = 17, .audience = 19, .context = @splat(0) }, .signature = @splat(0) } };
    const original = try seal(alloc, description, 1, 17);
    try e.expectError(error.QueryAlreadyAuthorized, Store.signQuery(original, 17, 3, 9, 8));
    for (0..9) |kind| {
        var invalid = original;
        switch (kind) {
            0 => invalid.authorization = null,
            1 => invalid.limits.pages -= 1,
            2 => invalid.authorization.?.proof.claim.audience += 1,
            3 => invalid.authorization.?.requester += 1,
            4 => invalid.authorization.?.proof.signature[0] ^= 1,
            5 => invalid = try seal(alloc, description, 2, 17),
            6 => invalid = try seal(alloc, description, 1, 18),
            7, 8 => {
                if (kind == 7) invalid.retention.?.binding.executor += 1 else invalid.retention.?.binding.purpose[0] ^= 1;
                invalid = try seal(alloc, invalid, 1, 17);
            },
            else => unreachable,
        }
        var turn = try store.capture();
        const before = turn.decision;
        try e.expectError(if (kind >= 4 and kind <= 6) error.AccessDenied else error.QueryDenied, publicationSubject(&turn, invalid));
        try e.expectEqualDeep(before, turn.decision);
        try e.expect(turn.read_error == null);
    }
    var turn = try store.capture();
    try publicationSubject(&turn, original);
    try e.expectEqualDeep(original.authorization.?.proof, turn.decision.authorization.?.subject.signed);
    try e.expectEqualDeep((try authority.guard(.{ .signed = original.authorization.?.proof })).requirements, turn.decision.authorization.?.requirements);
    try e.expectEqual(@as(usize, 0), store.versions.count());
    try store.setRights(.{ .principal = 17, .read = false });
    turn = try store.capture();
    const before = turn.decision;
    try e.expectError(error.AccessDenied, publicationSubject(&turn, original));
    try e.expectEqualDeep(before, turn.decision);
    try store.setRights(.{ .principal = 17 });
    turn = try store.capture();
    try publicationSubject(&turn, original);
}

test "direct native contracts retain the maximum checkpoint key and require the original bundle" {
    var arena: std.heap.ArenaAllocator = .init(e.allocator);
    defer arena.deinit();
    const source: q.SourceDefinition = .{ .resource = 7, .source = .{ .kv = .{ .prefix = try q.protocol.Value.init(""), .key = .{ .type = .binary }, .value = .{ .type = .int64 } } } };
    const bundle = try q.Bundle.fromSql(arena.allocator(), source, "items", "SELECT * FROM items", limits);
    const basis = try q.UnifiedSource.basis(source, 42);
    const plan = try bundle.bind(try basis.fingerprint());
    var progress = try f.LogicalStream.Progress.start(plan);
    progress.pages = 1;
    progress.counters = .{ .scanned = 8, .selected = 8 };
    progress.segments = 1;
    progress.rows = 8;
    const checkpoint: r.Checkpoint = .{ .cut = basis.cut, .progress = progress, .bytes = 8192, .chain = @splat(42), .cursor = .{ .ordinal = 1, .after = try q.protocol.Value.init(&@as([q.protocol.Growth.key_bytes]u8, @splat(255))) } };
    const bytes = try checkpoint.encode();
    try e.expectEqual(@as(u16, 230), bytes.len);
    const decoded = try r.Checkpoint.decode(bytes);
    try e.expectEqualDeep(checkpoint, decoded);
    _ = try decoded.bound(bundle);
    for (0..bytes.len) |length| {
        if (r.Checkpoint.decode(try q.protocol.Value.init(bytes.slice()[0..length]))) |_| return error.AcceptedTruncatedCheckpoint else |_| {}
    }
    var changed = decoded;
    changed.cut.position.native_revision += 1;
    try e.expectError(error.SourceChanged, changed.bound(bundle));
    changed = decoded;
    changed.progress.pages = 2;
    try e.expectError(error.InvalidQueryRecord, changed.encode());
    var corrupt = bytes;
    corrupt.data[20] = 255; // Native revisions retain the native counter bound.
    try e.expectError(error.SourceChanged, r.Checkpoint.decode(corrupt));
}

test "direct native contracts preserve exact prepared scalar descriptors and independently owned values" {
    const Case = struct { type: f.Types.Type, atom: f.Types.Values.Atom };
    const cases = [_]Case{
        .{ .type = .int8, .atom = .{ .signed = -128 } },
        .{ .type = .int16, .atom = .{ .signed = -32768 } },
        .{ .type = .int32, .atom = .{ .signed = std.math.minInt(i32) } },
        .{ .type = .int64, .atom = .{ .signed = std.math.minInt(i64) } },
        .{ .type = .int128, .atom = .{ .signed = std.math.minInt(i128) } },
        .{ .type = .uint8, .atom = .{ .unsigned = std.math.maxInt(u8) } },
        .{ .type = .uint16, .atom = .{ .unsigned = std.math.maxInt(u16) } },
        .{ .type = .uint32, .atom = .{ .unsigned = std.math.maxInt(u32) } },
        .{ .type = .uint64, .atom = .{ .unsigned = std.math.maxInt(u64) } },
        .{ .type = .uint128, .atom = .{ .unsigned = std.math.maxInt(u128) } },
        .{ .type = .float32, .atom = .{ .float = -0.0 } },
        .{ .type = .float64, .atom = .{ .float = -0.0 } },
        .{ .type = .{ .decimal = .{ .precision = 38, .scale = 12 } }, .atom = .{ .decimal = 12345678901234567890123456789012345678 } },
        .{ .type = .boolean, .atom = .{ .boolean = true } },
        .{ .type = .utf8, .atom = .{ .bytes = "東京" } },
        .{ .type = .binary, .atom = .{ .bytes = "\x00\xff\x1b" } },
        .{ .type = .date, .atom = .{ .date = -1 } },
        .{ .type = .time, .atom = .{ .time = 86399999999999 } },
        .{ .type = .{ .timestamp = .civil }, .atom = .{ .timestamp = -1 } },
        .{ .type = .{ .timestamp = .utc }, .atom = .{ .timestamp = -1 } },
        .{ .type = .uuid, .atom = .{ .uuid = @splat(255) } },
    };
    for (cases) |case| {
        var arena: std.heap.ArenaAllocator = .init(e.allocator);
        defer arena.deinit();
        const schema: f.TableSchema.Schema = .{ .object = std.math.maxInt(u64), .revision = 1, .next_column = 2, .columns = &.{.{ .id = 1, .name = "value", .type = case.type, .nullable = true }} };
        var declaration = try c.storage.TableDeclaration.prepare(e.allocator, .{ .object = .{ .scope = scope, .branch = 1, .object = schema.object }, .revision = 1, .schema = schema, .properties = "" });
        defer declaration.deinit();
        var schema_bytes: [f.TableSchema.max_bytes]u8 = undefined;
        var owned = try q.TableSource.from(e.allocator, .{ .scope = scope, .branch = 1, .audience = 3, .principal = 17, .role = null }, .{ .interpretation = try declaration.stored(), .namespace = 1, .authorization = 23, .name = try .init("items"), .position = .{ .partition = 1, .next_lsn = 2 }, .changed_lsn = 2, .row_count = 0, .schema = try c.DirectTableProtocol.Binary.encode(arena.allocator(), try schema.encode(&schema_bytes)) });
        defer owned.deinit();
        const source: q.SourceDefinition = .{ .resource = scope.resource, .source = .{ .table = owned.source } };
        var template = try q.SqlTemplate.init(e.allocator, source, "items", "SELECT value FROM items WHERE value = $1 LIMIT $2");
        var bound = try template.bind(e.allocator, source, &.{ case.atom, .{ .unsigned = 1 } }, limits);
        defer bound.deinit();
        template.deinit();
        const copied = try q.Values.Bundle.fromNative(arena.allocator(), bound.bundle);
        const restored = try copied.native(arena.allocator());
        try e.expect(try restored.plan.schema.eql(bound.bundle.plan.schema));
        var original: [q.Bundle.max_bytes]u8 = undefined;
        var again: [q.Bundle.max_bytes]u8 = undefined;
        try e.expectEqualSlices(u8, try bound.bundle.encode(&original), try restored.encode(&again));
        const foreign = try q.Values.foreignScalar(arena.allocator(), case.atom, case.type);
        const scalar = try q.Values.scalar(arena.allocator(), foreign, case.type);
        try e.expectEqual(.eq, try f.Types.Values.atomOrder(case.atom, scalar, case.type));
    }
}

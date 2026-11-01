//! Original declaration tokens and immutable bodies survive two process deaths.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const t = std.testing;
const Saved = struct { definition: p.Growth.Definition, bindings: [2]c.DirectClientToken.Binding };
fn load(init: std.process.Init, path: []const u8) !Saved {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(64 * 1024));
    const parsed = try p.Json.parseFromSlice(Saved, init.arena.allocator(), bytes);
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    for (parsed.value.bindings) |binding| try binding.validate();
    return parsed.value;
}
fn declaration(init: std.process.Init, client: c.DirectTableClient, role: u64, kind: c.DirectLog.Kind, i: u64) !c.DirectClientToken.Binding {
    const object = 644010 + i;
    const columns = [_]c.fuze.TableSchema.Column{.{ .id = 1, .name = "value", .type = .int64, .nullable = false }};
    const intent: c.DirectLog.Intent = .{ .kind = kind, .namespace = 1, .name = try .init(if (kind == .stream) "token_events" else "token_work"), .action = .{ .create = .{
        .owner = role,
        .schema = .{ .object = object, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{} },
        .configuration = .{ .partitioning = .{ .count = 2, .key_column = null, .hash = .sha256_64 }, .retention = .{ .max_age_ms = null }, .policy = if (kind == .stream) .{ .stream = .{ .compact_key_column = null, .timestamp_column = null } } else .{ .queue = .{ .ordering = .unordered, .key_column = null, .lease_ms = 30000, .maximum_lease_ms = 30000, .maximum_attempts = 5, .backoff = .{ .initial_ms = 10, .maximum_ms = 1000, .multiplier = 2 }, .dead_letter = null } } },
        .limits = .{ .append_rows = 128, .append_bytes = 1024 * 1024, .claim_rows = 16, .read_rows = 128, .read_bytes = 1024 * 1024, .active_leases = 64, .waiters = 64, .timer_steps = 64 },
    } } };
    const request: c.DirectLog.Request = .{ .intent = intent, .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 644001 + i }, .target = .{ .scope = client.connection.scope, .branch = 1, .object = object }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try intent.digest(init.gpa) } };
    var scratch = std.heap.ArenaAllocator.init(init.gpa);
    defer scratch.deinit();
    var frozen = try c.DirectLogIntent.create(init.gpa, client.connection, try c.DirectLogProtocol.Ddl.encode(scratch.allocator(), request));
    defer frozen.deinit();
    const reference: c.DirectIntent.Reference = .{ .log = try frozen.stage(client, @splat(0x46)) };
    return .{ .key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(0x46), .token = @splat(@intCast(0x47 + i)) }, .fingerprint = try reference.digest(), .intent = reference };
}
pub fn prepare(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    const saved: Saved = .{ .definition = p.Growth.current_definition, .bindings = .{ try declaration(init, client, role, .stream, 0), try declaration(init, client, role, .queue, 1) } };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    _ = try c.DirectClientToken.bind(client, saved.bindings[0]);
    try t.expectError(error.InvalidTableResponse, c.DirectClientToken.bind(client, saved.bindings[1]));
}
pub fn recover(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings) |binding| {
        const receipt = (try c.DirectClientToken.lookup(client, binding.key)).?;
        try t.expectEqualDeep(binding, receipt.binding);
        const observed = try receipt.binding.intent.operation(client, .inspect, 1);
        defer observed.deinit();
        try t.expect(observed.value.result.log_operation == .not_observed);
        try t.expectEqualDeep(receipt, try c.DirectClientToken.bind(client, binding));
    }
    (try saved.bindings[0].intent.admit(client)).deinit();
    try t.expectError(error.InvalidTableResponse, saved.bindings[1].intent.admit(client));
}
pub fn verify(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings) |binding| {
        const initial = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expect(initial.pending);
        try t.expectEqualDeep(binding, initial.receipt.binding);
        const observed = try binding.intent.operation(client, .inspect, 1);
        defer observed.deinit();
        try t.expect(observed.value.result.log_operation.operation.pending());
        const original_admission = try binding.intent.admit(client);
        defer original_admission.deinit();
        try t.expectEqualDeep(observed.value.result.log_operation.operation, original_admission.value.result.log_admitted);
        const completed = try binding.intent.operation(client, .execute, 16);
        defer completed.deinit();
        const value = completed.value.result.log_operation.operation;
        try t.expectEqual(.complete, value.phase);
        try t.expectEqual(@as(u32, 2), value.initialized);
        try t.expectEqual(binding.intent.log.kind, value.kind);
        try binding.intent.log.binding.requireSame(value.binding);
        const terminal = try c.DirectClientToken.update(client, .{ .key = binding.key, .expected = initial.revision, .pending = false, .cancel = false, .record = null });
        try t.expect(!terminal.pending);
        const repeat = try binding.intent.operation(client, .execute, 16);
        defer repeat.deinit();
        try t.expectEqualDeep(completed.value.result.log_operation, repeat.value.result.log_operation);
        try t.expectEqualDeep(initial.receipt, (try c.DirectClientToken.lookup(client, binding.key)).?);
    }
}

/// Exercise account selection, bounded native recovery and terminal settlement
/// separately. The proxy saves signed requests and withholds one Queue reply at
/// each boundary; every following phase uses the retained original bindings.
pub fn prepareWorkloads(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var bindings: [2]c.DirectClientToken.Binding = undefined;
    for ([_]c.DirectLog.Kind{ .stream, .queue }, 0..) |kind, i| {
        const ddl = try declaration(init, client, role, kind, i);
        (try ddl.intent.admit(client)).deinit();
        const completed = try ddl.intent.operation(client, .execute, 16);
        defer completed.deinit();
        const definition = completed.value.result.log_operation.operation.resulting.?;
        try t.expectEqual(.complete, completed.value.result.log_operation.operation.phase);
        const metadata = try client.call(.{ .log_lookup = .{ .namespace = 1, .name = definition.properties.name.slice() } });
        defer metadata.deinit();
        const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = 0 };
        const identity: p.DataLifecycle.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 644101 + i };
        const work: c.DirectWorkloadIntent.Work = if (kind == .stream)
            .{ .stream = .{ .work = .{ .consume = .{ .target = target, .operation = identity, .group = null, .from = 0, .until = null, .timestamp = null } }, .payload = null } }
        else
            .{ .queue = .{ .work = .{ .claim = .{ .target = target, .operation = identity, .maximum = 1, .lease_ms = 30000 } }, .payload = null } };
        var frozen = try c.DirectWorkloadIntent.create(init.gpa, client.connection, metadata.value.result.log_lookup.?, work);
        defer frozen.deinit();
        const reference: c.DirectIntent.Reference = .{ .workload = try frozen.stage(client, @splat(0x56)) };
        bindings[i] = .{ .key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(0x56), .token = @splat(@intCast(0x57 + i)) }, .fingerprint = try reference.digest(), .intent = reference, .budget = .{ .bytes = try reference.workload.reservationBytes() } };
        // More than the native owner's 256-frame replay step. These closures
        // retain no payload, lease or read pin and have distinct saved identities.
        for (0..257) |step| {
            const action: c.DirectTableProtocol.Action = switch (work) {
                .stream => |value| blk: {
                    var original = value.work;
                    original.consume.operation.operation = 645000 + step;
                    break :blk .{ .stream = .{ .cancel = original } };
                },
                .queue => |value| blk: {
                    var original = value.work;
                    original.claim.operation.operation = 646000 + step;
                    break :blk .{ .queue = .{ .cancel = original } };
                },
            };
            const closed = try client.call(action);
            defer closed.deinit();
            if (kind == .stream) try t.expect(closed.value.result.stream.operation.? == .closed) else try t.expect(closed.value.result.queue.operation.? == .closed);
        }
    }
    const saved: Saved = .{ .definition = p.Growth.current_definition, .bindings = bindings };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), saved, 64 * 1024) });
    _ = try c.DirectClientToken.bind(client, saved.bindings[0]);
    try t.expectError(error.InvalidTableResponse, c.DirectClientToken.bind(client, saved.bindings[1]));
}

fn workloadOperation(reference: c.DirectIntent.Reference, client: c.DirectTableClient, command: @FieldType(@FieldType(c.DirectTableProtocol.Action, "operation"), "command")) !std.json.Parsed(c.DirectTableProtocol.Response) {
    // A recovering response accepts no new work. The same frozen request is
    // retained across every bounded owner step, never regenerated from a name.
    for (0..4) |_| {
        const result = try reference.operation(client, command, 1);
        errdefer result.deinit();
        const recovering = switch (result.value.result) {
            .stream => |value| value == .recovering,
            .queue => |value| value == .recovering,
            else => return error.InvalidTableResponse,
        };
        if (!recovering) return result;
        result.deinit();
    }
    return error.FixtureBudget;
}

pub fn executeWorkloads(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings, 0..) |binding, i| {
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expectEqualDeep(binding, state.receipt.binding);
        try t.expect(state.pending);
        try t.expectError(error.Conflict, c.DirectClientToken.update(client, .{ .key = binding.key, .expected = state.revision, .pending = false, .cancel = false, .record = null }));
        if (i == 0) {
            const result = try workloadOperation(binding.intent, client, .execute);
            defer result.deinit();
            try t.expectEqual(@as(u64, 0), result.value.result.stream.operation.?.consume.cut.next);
        } else try t.expectError(error.InvalidTableResponse, workloadOperation(binding.intent, client, .execute));
    }
}

fn settleWorkload(client: c.DirectTableClient, binding: c.DirectClientToken.Binding, revision: p.DataLifecycle.Position) !struct { state: c.DirectClientToken.Progress, recovering: usize } {
    for (0..4) |step| {
        const state = c.DirectClientToken.update(client, .{ .key = binding.key, .expected = revision, .pending = false, .cancel = false, .record = null }) catch |err| {
            if (err == error.Conflict) continue;
            return err;
        };
        return .{ .state = state, .recovering = step };
    }
    return error.FixtureBudget;
}

pub fn settleWorkloads(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings, 0..) |binding, i| {
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expect(state.pending);
        if (i == 0) {
            const settled = try settleWorkload(client, binding, state.revision);
            try t.expect(!settled.state.pending);
            try t.expectEqual(@as(usize, 1), settled.recovering);
        } else try t.expectError(error.InvalidTableResponse, settleWorkload(client, binding, state.revision));
    }
}

pub fn verifyWorkloads(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try load(init, path);
    for (saved.bindings, 0..) |binding, i| {
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        try t.expect(!state.pending);
        try t.expectEqualDeep(binding, state.receipt.binding);
        try t.expectEqualDeep(state, try c.DirectClientToken.update(client, .{ .key = binding.key, .expected = state.revision, .pending = false, .cancel = false, .record = null }));
        const original = try workloadOperation(binding.intent, client, .inspect);
        defer original.deinit();
        const late_cancel = try workloadOperation(binding.intent, client, .cancel);
        defer late_cancel.deinit();
        if (i == 0) {
            try t.expectEqualDeep(original.value.result.stream, late_cancel.value.result.stream);
            try t.expectEqual(@as(u64, 0), original.value.result.stream.operation.?.consume.cut.next);
        } else {
            try t.expectEqualDeep(original.value.result.queue, late_cancel.value.result.queue);
            try t.expectEqual(@as(u32, 0), original.value.result.queue.operation.?.claim.rows);
        }
    }
}

const ResultSaved = struct { definition: p.Growth.Definition, bindings: [6]c.DirectClientToken.Binding };
const Delivery = struct { reference: c.DirectWorkloadResult.Reference, position: c.DirectWorkloadResult.Position };
const Deliveries = struct { definition: p.Growth.Definition, values: [6]Delivery };
fn saveResultValue(init: std.process.Init, path: []const u8, value: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = try p.Json.valueAllocBounded(init.arena.allocator(), value, 128 * 1024) });
}
fn loadResultValue(comptime T: type, init: std.process.Init, path: []const u8) !T {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.arena.allocator(), .limited(128 * 1024));
    const parsed = try p.Json.parseFromSlice(T, init.arena.allocator(), bytes);
    if (parsed.value.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    return parsed.value;
}
fn saveWorkload(init: std.process.Init, client: c.DirectTableClient, source: c.DirectLogProtocol.Definition, work: c.DirectWorkloadIntent.Work, index: usize) !c.DirectClientToken.Binding {
    var frozen = try c.DirectWorkloadIntent.create(init.gpa, client.connection, source, work);
    defer frozen.deinit();
    const reference: c.DirectIntent.Reference = .{ .workload = try frozen.stage(client, @splat(0x66)) };
    const binding: c.DirectClientToken.Binding = .{ .key = .{ .definition = p.Growth.current_definition, .connection = client.connection, .account = @splat(0x66), .token = @splat(@intCast(0x70 + index)) }, .fingerprint = try reference.digest(), .intent = reference, .budget = .{ .bytes = try reference.workload.reservationBytes() } };
    _ = try c.DirectClientToken.bind(client, binding);
    return binding;
}

/// Save all original bodies before dispatch. Empty selections precede later
/// appends; the final nonempty claim reply is withheld by the installed proxy.
pub fn prepareResults(init: std.process.Init, client: c.DirectTableClient, role: u64, path: []const u8) !void {
    (try client.call(.initialize)).deinit();
    var saved: ResultSaved = .{ .definition = p.Growth.current_definition, .bindings = undefined };
    for ([_]c.DirectLog.Kind{ .stream, .queue }, 0..) |kind, i| {
        const ddl = try declaration(init, client, role, kind, i);
        (try ddl.intent.admit(client)).deinit();
        const completed = try ddl.intent.operation(client, .execute, 16);
        defer completed.deinit();
        const definition = completed.value.result.log_operation.operation.resulting.?;
        try t.expectEqual(.complete, completed.value.result.log_operation.operation.phase);
        const metadata = try client.call(.{ .log_lookup = .{ .namespace = 1, .name = definition.properties.name.slice() } });
        defer metadata.deinit();
        const source = metadata.value.result.log_lookup.?;
        const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = definition.stored.declaration.interpretation, .partition = 0 };
        const identity: p.DataLifecycle.Operation = .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = 647001 + i * 2 };
        var declared = try c.DirectLogProtocol.decodeMetadata(init.gpa, client.connection, source);
        defer declared.deinit();
        var bytes: [8192]u8 = undefined;
        const payload = try c.storage.LogBatch.encode(declared.definition.schema, identity, kind, &.{
            .{ .cells = &.{.{ .value = .{ .atom = .{ .signed = 10 } } }} },
            .{ .cells = &.{.{ .value = .{ .atom = .{ .signed = 20 } } }} },
            .{ .cells = &.{.{ .value = .{ .atom = .{ .signed = 30 } } }} },
        }, &bytes);
        const encoded = try c.DirectTableProtocol.Binary.encode(init.gpa, payload);
        defer init.gpa.free(encoded.base64);
        const append: p.StreamQueue.Append = .{ .target = target, .operation = identity, .kind = if (kind == .stream) .stream else .queue, .producer = null, .rows = 3, .payload = c.storage.LogBatch.content(payload) };
        saved.bindings[i * 2] = try saveWorkload(init, client, source, if (kind == .stream)
            .{ .stream = .{ .work = .{ .append = append }, .payload = encoded } }
        else
            .{ .queue = .{ .work = .{ .enqueue = append }, .payload = encoded } }, i * 2);
        var operation = identity;
        operation.operation += 1;
        var selection: c.DirectWorkloadIntent.Work = if (kind == .stream)
            .{ .stream = .{ .work = .{ .consume = .{ .target = target, .operation = operation, .group = null, .from = 0, .until = null, .timestamp = null } }, .payload = null } }
        else
            .{ .queue = .{ .work = .{ .claim = .{ .target = target, .operation = operation, .maximum = 3, .lease_ms = 1000 } }, .payload = null } };
        saved.bindings[i * 2 + 1] = try saveWorkload(init, client, source, selection, i * 2 + 1);
        if (kind == .stream) selection.stream.work.consume.operation.operation = 647010 + i else selection.queue.work.claim.operation.operation = 647010 + i;
        saved.bindings[4 + i] = try saveWorkload(init, client, source, selection, 4 + i);
        // Exercise cold recovery beyond one native 256-frame step without
        // creating additional payload, leases or read pins.
        for (0..257) |step| {
            const action: c.DirectTableProtocol.Action = if (kind == .stream) blk: {
                var original = selection.stream.work;
                original.consume.operation.operation = 645000 + step;
                break :blk .{ .stream = .{ .cancel = original } };
            } else blk: {
                var original = selection.queue.work;
                original.claim.operation.operation = 646000 + step;
                break :blk .{ .queue = .{ .cancel = original } };
            };
            (try client.call(action)).deinit();
        }
    }
    try saveResultValue(init, path, saved);
    for ([_]usize{ 4, 5, 0, 1, 2 }) |index| (try workloadOperation(saved.bindings[index].intent, client, .execute)).deinit();
    try t.expectError(error.InvalidTableResponse, workloadOperation(saved.bindings[3].intent, client, .execute));
}

fn resultCall(client: c.DirectTableClient, request: c.DirectWorkloadResultProtocol.Request) !std.json.Parsed(c.DirectTableProtocol.Response) {
    for (0..4) |_| {
        return client.call(.{ .workload_result = request }) catch |err| {
            if (err == error.Conflict) continue;
            return err;
        };
    }
    return error.FixtureBudget;
}
fn checkResultPage(init: std.process.Init, client: c.DirectTableClient, page: c.DirectWorkloadResult.Page, first: usize, count: usize, complete: bool, expired: bool) !void {
    const source = switch (page) {
        inline else => |value| value.source,
    };
    var declared = try c.DirectLogProtocol.decodeMetadata(init.gpa, client.connection, source);
    defer declared.deinit();
    var scratch: std.heap.ArenaAllocator = .init(init.gpa);
    defer scratch.deinit();
    switch (page) {
        inline else => |value, tag| {
            try t.expectEqual(count, value.rows.len);
            const done = switch (tag) {
                .append => value.complete,
                .consume => value.cursor.coverage.complete,
                .claim => value.cursor.complete(),
            };
            try t.expectEqual(complete, done);
            for (value.rows, first..) |row, ordinal| {
                _ = scratch.reset(.retain_capacity);
                const offset = if (tag == .claim) row.lease.original.offset else row.offset;
                try t.expectEqual(ordinal, offset);
                const encoded = try row.encoded.decode(scratch.allocator(), 8192);
                const decoded = try c.fuze.TableRow.decodeInto(scratch.allocator(), declared.definition.schema, encoded);
                try t.expectEqual(@as(i64, @intCast((ordinal + 1) * 10)), decoded.row().cells[0].value.atom.signed);
                if (tag == .claim and expired) try t.expectEqual(p.QueueRead.Liveness.expired, row.lease.liveness);
            }
        },
    }
}
pub fn openResults(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try loadResultValue(ResultSaved, init, path);
    var deliveries: Deliveries = .{ .definition = p.Growth.current_definition, .values = undefined };
    for (saved.bindings, 0..) |binding, index| {
        const request: c.DirectWorkloadResultProtocol.Request = .{ .open = .{ .intent = binding.intent.workload, .limits = .{ .rows = 2, .encoded_bytes = 8192, .scanned_rows = 2 } } };
        if (index == 3) try t.expectError(error.InvalidTableResponse, resultCall(client, request));
        const opened = try resultCall(client, request);
        defer opened.deinit();
        const value = opened.value.result.workload_result.opened;
        const page_request: c.DirectWorkloadResultProtocol.Request = .{ .page = .{ .reference = value.reference, .position = value.position } };
        if (index == 3) try t.expectError(error.InvalidTableResponse, resultCall(client, page_request));
        const response = try resultCall(client, page_request);
        defer response.deinit();
        const page = response.value.result.workload_result.page;
        try checkResultPage(init, client, page.page, 0, if (index < 4) 2 else 0, index >= 4, false);
        deliveries.values[index] = .{ .reference = page.reference, .position = page.position };
    }
    try saveResultValue(init, try std.fmt.allocPrint(init.arena.allocator(), "{s}.positions", .{path}), deliveries);
}
pub fn verifyResults(init: std.process.Init, client: c.DirectTableClient, path: []const u8) !void {
    const saved = try loadResultValue(ResultSaved, init, path);
    const deliveries = try loadResultValue(Deliveries, init, try std.fmt.allocPrint(init.arena.allocator(), "{s}.positions", .{path}));
    for (saved.bindings, deliveries.values, 0..) |binding, delivery, index| {
        try binding.intent.workload.requireSame(delivery.reference.intent);
        const response = try resultCall(client, .{ .page = .{ .reference = delivery.reference, .position = delivery.position } });
        defer response.deinit();
        const page = response.value.result.workload_result.page;
        try checkResultPage(init, client, page.page, if (index < 4) 2 else 0, if (index < 4) 1 else 0, true, true);
        const terminal = try resultCall(client, .{ .page = .{ .reference = page.reference, .position = page.position } });
        defer terminal.deinit();
        try checkResultPage(init, client, terminal.value.result.workload_result.page.page, if (index < 4) 3 else 0, 0, true, true);
        const state = (try c.DirectClientToken.inspect(client, binding.key)).?;
        const settled = try settleWorkload(client, binding, state.revision);
        try t.expect(!settled.state.pending);
    }
}

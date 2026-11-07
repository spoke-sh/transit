const std = @import("std");
const t = std.testing;
const runtime = @import("fixture_runtime.zig");
const root = @import("root.zig");
const c = root.data.catalog;
const p = c.protocol;
const x = root.http.exchange;
const f = @import("catalog_fixture.zig");
const exchange = @import("exchange_fixture.zig");
const Source = struct {
    origin: *Origin,
    view: struct { id: u64 = 1, resource: u64 = 7, revision: u64, position: u64 },
    pub fn read(self: *Source, key: p.Value) !?p.Value {
        if (self.origin.denied) return error.CatalogDenied;
        return self.origin.store.state.get(key);
    }
};
pub const Origin = struct {
    store: *exchange.Store,
    access: *f.Access,
    expected: ?root.Saved = null,
    denied: bool = false,
    lose_hold: bool = false,
    lose_release: bool = false,
    reads: usize = 0,
    pub fn source(self: *Origin) Source {
        return .{ .origin = self, .view = .{ .revision = self.store.revision, .position = self.store.input } };
    }
    pub fn authorize(self: *Origin, saved: root.Saved) !void {
        if (self.denied) return error.CatalogDenied;
        const expected = self.expected orelse return error.SourceOriginalUnverified;
        // This fixture is explicitly configured with one authenticated original;
        // declarations and arbitrary caller-provided evidence confer no authority.
        if (!std.meta.eql(saved.origin, expected.origin) or !std.meta.eql(saved.poll, expected.poll) or !std.meta.eql(saved.attempt, expected.attempt)) return error.SourceOriginalUnverified;
        var current = self.source();
        const observed = try (x.Exchange{ .resource = saved.origin.reference.resource, .id = saved.origin.reference.exchange }).inspect(&current);
        if (!std.meta.eql(observed, saved.origin.descriptor)) return error.SourceOriginalUnverified;
        const control = try (x.Exchange{ .resource = saved.origin.reference.resource, .id = saved.origin.reference.exchange }).control(&current);
        if (control.disposition != .observed or control.effect != observed.effect) return error.SourceOriginalUnverified;
    }
    const Guard = struct { origin: *Origin, saved: root.Saved, base: c.storage.PublicationGuard };
    pub fn guard(self: *Origin, allocator: std.mem.Allocator, required: p.Authorization.Guard, saved: root.Saved) !c.storage.PublicationGuard {
        const context = try allocator.create(Guard);
        context.* = .{ .origin = self, .saved = saved, .base = try f.Access.make(self.access, allocator, required, null) };
        return .{ .context = context, .acquire = acquire, .release = unlock };
    }
    fn acquire(raw: *anyopaque) !c.storage.PublicationGuard.Fence {
        const context: *Guard = @ptrCast(@alignCast(raw));
        try context.origin.authorize(context.saved);
        return context.base.acquire(context.base.context);
    }
    fn unlock(raw: *anyopaque) void {
        const context: *Guard = @ptrCast(@alignCast(raw));
        context.base.release(context.base.context);
    }
    pub fn retain(self: *Origin, saved: root.Saved) !void {
        try self.authorize(saved);
        try runtime.hit("reservation");
        var turn = try self.store.capture();
        _ = try (x.Exchange{ .resource = saved.origin.reference.resource, .id = saved.origin.reference.exchange }).retain(&turn, saved.origin.token, saved.origin.holder);
        try self.store.commit(turn);
        try runtime.hit("hold");
        if (self.lose_hold) {
            self.lose_hold = false;
            return error.LostAcknowledgement;
        }
    }
    pub fn release(self: *Origin, saved: root.Saved) !void {
        if (self.denied) return error.CatalogDenied;
        try t.expectEqualDeep(self.expected.?.origin, saved.origin);
        try runtime.hit("release_pending");
        var turn = try self.store.capture();
        _ = try (x.Exchange{ .resource = saved.origin.reference.resource, .id = saved.origin.reference.exchange }).release(&turn, saved.origin.token, saved.origin.holder);
        try self.store.commit(turn);
        try runtime.hit("release_accepted");
        if (self.lose_release) {
            self.lose_release = false;
            return error.LostAcknowledgement;
        }
    }
    pub fn open(self: *Origin, reference: x.Client.Reference) !x.Exchange.Cursor {
        var current = self.source();
        const cursor = try (x.Exchange{ .resource = reference.resource, .id = reference.exchange }).open(&current, &current);
        if (!std.mem.eql(u8, &cursor.descriptor.chain, &reference.chain)) return error.InvalidExchangeCoverage;
        return cursor;
    }
    pub fn read(self: *Origin, reference: x.Client.Reference, cursor: x.Exchange.Cursor) !x.Exchange.Part {
        self.reads += 1;
        var current = self.source();
        const ex: x.Exchange = .{ .resource = reference.resource, .id = reference.exchange };
        if (!std.meta.eql((try self.open(reference)).descriptor, cursor.descriptor)) return error.StaleExchangeSource;
        var resumed = cursor;
        if (cursor.member_cursor) |previous| {
            var next = try ex.publication().open(&current, previous.id);
            if (!std.meta.eql(next.spec, previous.spec)) return error.InvalidExchangeCoverage;
            next.index = previous.index;
            next.chain = previous.chain;
            resumed.member_cursor = next;
        }
        return ex.read(&current, &current, resumed);
    }
};

pub fn original(store: *exchange.Store, length: usize, status: u16, omit_completion: bool) !x.Descriptor {
    var turn = try store.capture();
    const ex = try x.Exchange.create(&turn, 1, .{ .caller = 9, .input = 8, .protocol = root.http.protocol_format }, .{ .segment_bytes = 4096, .capture_bytes = 8 * 1024 * 1024, .segments = 65536 }, 10000);
    try store.commit(turn);
    try exchange.segment(store, ex, 0, @backingInt(root.http.Kind.request_template), "{}");
    try exchange.segment(store, ex, 1, @backingInt(root.http.Kind.request_head), "GET /feed HTTP/1.1\r\nContent-Length: 0\r\n\r\n");
    try exchange.segment(store, ex, 2, @backingInt(root.http.Kind.request_body), "");
    turn = try store.capture();
    _ = try ex.commitIntent(&turn);
    const payload = turn.decision.effect.?;
    try store.commit(turn);
    turn = try store.capture();
    _ = try ex.bind(&turn, .{ .id = 19, .pid = 2, .payload = payload, .phase = .authorized, .attempt = 20, .executor = 7, .reconcile_before_ms = 10000 });
    try store.commit(turn);
    var head: [128]u8 = undefined;
    const text = if (status == 204) "HTTP/1.1 204 No Content\r\n\r\n" else try std.fmt.bufPrint(&head, "HTTP/1.1 {d} Response\r\nContent-Length: {d}\r\n\r\n", .{ status, length });
    try exchange.segment(store, ex, 3, @backingInt(root.http.Kind.response_head), text);
    var buffer: [4093]u8 = undefined;
    var offset: usize = 0;
    var ordinal: u32 = 4;
    while (offset < length or ordinal == 4) : (ordinal += 1) {
        const count = @min(buffer.len, length - offset);
        for (buffer[0..count], 0..) |*byte, i| byte.* = @truncate((offset + i) *% 73 +% 19);
        try exchange.segment(store, ex, ordinal, @backingInt(root.http.Kind.response_body), buffer[0..count]);
        offset += count;
    }
    try exchange.segment(store, ex, ordinal, @backingInt(root.http.Kind.timing), (try x.codec.encode(root.http.Timing{ .started_ms = 100, .elapsed_ns = 100 })).slice());
    ordinal += 1;
    try exchange.segment(store, ex, ordinal, @backingInt(root.http.Kind.omission), (try x.codec.encode(root.http.Omission{ .request_secrets = 0, .response_headers = 0 })).slice());
    ordinal += 1;
    if (!omit_completion) try exchange.segment(store, ex, ordinal, @backingInt(root.http.Kind.completion), (try x.codec.encode(root.http.Completion{ .status = status, .heads = 1, .request_bytes = 0, .response_bytes = length, .framing = if (status == 204) .none else .length })).slice());
    turn = try store.capture();
    _ = try ex.finish(&turn, status);
    try store.commit(turn);
    turn = try store.capture();
    _ = try ex.settle(&turn, .{ .id = 19, .pid = 2, .payload = payload, .phase = .observed, .result = try (x.Client.Reference{ .resource = 7, .exchange = 1, .chain = (try ex.inspect(&turn)).chain }).encode(), .attempt = 20, .executor = 7, .reconcile_before_ms = 10000 });
    try store.commit(turn);
    turn = try store.capture();
    return ex.inspect(&turn);
}
pub fn savedInput(source: p.Source.Definition, descriptor: x.Descriptor) root.Saved {
    const key: c.DirectClientToken.Key = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = f.scope, .branch = 1, .audience = 3, .principal = 1, .role = null }, .account = @splat(98), .token = @splat(1) };
    var candidate = key;
    candidate.token = @splat(2);
    var publication = key;
    publication.token = @splat(3);
    const operation: p.DataLifecycle.Operation = .{ .scope = f.scope, .principal = 1, .operation = 90000 };
    var poll = operation;
    poll.operation += 1;
    var begin = operation;
    begin.operation += 2;
    var append = operation;
    append.operation += 3;
    var settlement = operation;
    settlement.operation += 4;
    return .{
        .definition = p.Growth.current_definition,
        .key = key,
        .namespace = 1,
        .operation = operation,
        .source = source,
        .poll = .{ .definition = p.Growth.current_definition, .source = source.interpretation, .operation = poll, .capture_id = @splat(1), .sequence = 1, .control_epoch = 1, .due_ms = 100, .state = .captured },
        .attempt = .{ .scope = f.scope, .principal = 7, .operation = 20 },
        .verifier = source.interpretation,
        .observed_at_ms = 100,
        .origin = .{ .reference = .{ .resource = 7, .exchange = 1, .chain = descriptor.chain }, .descriptor = descriptor, .holder = 700, .token = 800 },
        .candidate = .{ .key = candidate, .budget = .{ .bytes = 32 * 1024 * 1024 }, .limits = .{ .work_bytes = 128 * 1024 * 1024, .work_pages = 100000 } },
        .publication = .{ .key = publication, .begin = begin, .append = append, .settlement = settlement, .limits = .{ .resident_bytes = 8 * 1024 * 1024, .workspace_bytes = 16 * 1024 * 1024, .participants = 1, .statements = 1, .savepoints = 1 }, .budget = .{ .bytes = 16 * 1024 * 1024 } },
        .budget = .{ .bytes = 256 * 1024 },
        .work = .{ .bytes = 128 * 1024 * 1024, .parts = 1000000 },
    };
}

const DestinationReader = struct {
    catalog: *c.DirectCatalog,
    access: *f.Access,
    connection: c.DirectTableProtocol.Connection,
    cached: ?c.DirectStream.Cached = null,
    lose_open: bool = true,
    lose_release: bool = true,
    fn call(raw: *anyopaque, output: *std.heap.ArenaAllocator, request: c.DirectSourceRead.Request) !root.data.Catalog.CaptureOutcome {
        const self: *DestinationReader = @ptrCast(@alignCast(raw));
        const result = try c.DirectSourceRead.apply(output.allocator(), output.allocator(), self.catalog, &self.cached, .{ .resident_pages = 1 }, .{ .authority = try c.storage.LogRead.Authority.init(@splat(9)), .clock = null }, self.connection, request, self.access.policy());
        if ((request == .open and self.lose_open) or (request == .close and self.lose_release)) {
            if (request == .open) self.lose_open = false else self.lose_release = false;
            return error.LostAcknowledgement;
        }
        return .{ .value = .{ .result = result }, .attempt = .{} };
    }
};
pub fn readPublished(catalog: *c.DirectCatalog, access: *f.Access, input: root.Saved, state: root.Journal.State) !void {
    const previous = access.principal;
    defer access.principal = previous;
    access.principal = 2;
    var connection = input.key.connection;
    connection.principal = 2;
    var transport: DestinationReader = .{ .catalog = catalog, .access = access, .connection = connection };
    defer if (transport.cached) |*cached| cached.deinit();
    var reader: root.data.CaptureReader = undefined;
    try reader.init(runtime.allocator(), .{
        .definition = p.Growth.current_definition,
        .connection = connection,
        .open = .{ .reference = (try input.plan(state.manifest.?)).reference, .operation = .{ .scope = f.scope, .principal = 2, .operation = 100000 } },
        .release = .{ .scope = f.scope, .principal = 2, .operation = 100001 },
    }, .{ .context = &transport, .connection = connection, .call = DestinationReader.call });
    defer reader.deinit();
    try t.expectError(error.LostAcknowledgement, reader.open());
    try t.expect((try reader.observe()) != null);
    _ = try reader.open();
    var offset: u64 = 0;
    while (true) {
        const page = try reader.next(runtime.allocator());
        defer runtime.allocator().free(page.bytes);
        try t.expectEqual(offset, page.offset);
        for (page.bytes, 0..) |byte, i| try t.expectEqual(@as(u8, @truncate((offset + i) *% 73 +% 19)), byte);
        offset += page.bytes.len;
        if (page.complete) break;
    }
    try t.expectEqual(state.evidence.?.body.bytes, offset);
    try t.expectError(error.LostAcknowledgement, reader.close());
    try reader.close();
    try t.expect(reader.memory.peak <= root.data.CaptureReader.scratch_bytes);
}

test "sealed HTTP handoff copies complete responses with restart and original hold recovery" {
    for ([_]struct { bytes: usize, status: u16 }{ .{ .bytes = 0, .status = 204 }, .{ .bytes = 65537, .status = 200 }, .{ .bytes = 1, .status = 404 }, .{ .bytes = 65535, .status = 200 }, .{ .bytes = 65536, .status = 503 }, .{ .bytes = 4 * 1024 * 1024, .status = 200 } }) |case| {
        var tmp = t.tmpDir(.{});
        defer tmp.cleanup();
        var wal = try c.storage.LocalWal.LocalWal.openDiskWithOptions(runtime.allocator(), runtime.io(), tmp.dir, "wal", .{});
        defer wal.deinit();
        var objects = try c.storage.LocalSegmentStore.LocalSegmentStore.openDiskAt(runtime.allocator(), runtime.io(), tmp.dir, "objects");
        defer objects.deinit();
        var catalog = try f.owner(&wal, &objects);
        defer catalog.deinit();
        var access: f.Access = .{ .exclusive = true };
        try catalog.initialize(access.policy());
        const source = try f.captureSetup(&catalog, &access);
        var store: exchange.Store = .{};
        defer store.deinit();
        const input = savedInput(source, try original(&store, case.bytes, case.status, false));
        var origin: Origin = .{ .store = &store, .access = &access, .expected = input, .lose_hold = true, .lose_release = true };
        var admission: c.DirectSourceCapture.Admission = .{};
        var importer: root.Importer(Origin) = undefined;
        try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
        defer importer.deinit();
        var previous: root.Journal.State = .{};
        var faults: usize = 0;
        var injected: u16 = 0;
        for (0..2048) |_| {
            const bit = @as(u16, 1) << @intCast(@backingInt(previous.phase));
            if (injected & bit == 0) {
                injected |= bit;
                catalog.store.lose_reply = true;
            }
            const state = importer.step() catch |err| {
                catalog.store.lose_reply = false;
                if (err != error.LostAcknowledgement) return err;
                faults += 1;
                continue;
            };
            catalog.store.lose_reply = false;
            if (state.phase == .released) {
                try t.expectEqual(case.bytes, state.evidence.?.body.bytes);
                try t.expectEqual(case.status, state.evidence.?.http_status);
                try t.expectEqual(0, state.outcome.?.append.?.first);
                try t.expectEqual(1, state.outcome.?.append.?.next);
                var changed = state;
                changed.evidence.?.poll.capture_id[0] ^= 1;
                try t.expectError(error.InvalidSourceHandoff, changed.validate(input));
                changed = state;
                changed.evidence.?.attempt.operation += 1;
                try t.expectError(error.InvalidSourceHandoff, changed.validate(input));
                break;
            }
            if (state.phase != previous.phase) {
                previous = state;
                importer.deinit();
                catalog.deinit();
                catalog = try f.owner(&wal, &objects);
                try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
            }
        } else return error.TestUnexpectedResult;
        try t.expect(faults >= 2);
        try t.expect(importer.memory.peak <= @TypeOf(importer).scratch_bytes);
        var current = origin.source();
        const hold = try x.codec.decode(x.Exchange.Dependency, (try current.read(x.Exchange.dependencyKey(1, input.origin.token))).?);
        try t.expectEqual(.released, hold.phase);
        const control = try (x.Exchange{ .resource = 7, .id = 1 }).control(&current);
        try t.expectEqual(.held, control.caller);
        try t.expectEqual(0, control.dependents);
        // The downstream reader has only destination authority. It shares the
        // real Stream pin and raw-reader path, with uncertain original replies.
        origin.denied = true;
        try readPublished(&catalog, &access, input, (try importer.inspect()).?.state);
        origin.denied = false;
        var arena: std.heap.ArenaAllocator = .init(runtime.allocator());
        defer arena.deinit();
        var selection: c.DirectClientToken.Selection = .{ .scope = input.key.scope(), .after = null, .pending = false };
        var found = false;
        while (true) {
            _ = arena.reset(.retain_capacity);
            const page = try importer.journal.list(arena.allocator(), selection);
            for (page.entries) |slot| if (slot) |entry| {
                if (std.meta.eql(entry.receipt.binding.key, input.key)) found = true;
            };
            selection.after = page.next orelse break;
        }
        try t.expect(found);
    }
}

test "HTTP handoff incomplete replay and exhausted recovery preserve originals for explicit close" {
    for ([_]bool{ false, true }) |incomplete| {
        var wal = c.storage.LocalWal.LocalWal.initMemory(runtime.allocator());
        defer wal.deinit();
        var objects = c.storage.LocalSegmentStore.LocalSegmentStore.initMemory(runtime.allocator());
        defer objects.deinit();
        var catalog = try f.owner(&wal, &objects);
        defer catalog.deinit();
        var access: f.Access = .{ .exclusive = true };
        try catalog.initialize(access.policy());
        const source = try f.captureSetup(&catalog, &access);
        var store: exchange.Store = .{};
        defer store.deinit();
        var input = savedInput(source, try original(&store, 65537, 200, incomplete));
        input.work.bytes = 2 * input.origin.descriptor.bytes;
        input.work.parts = 2 * input.passParts();
        var origin: Origin = .{ .store = &store, .access = &access, .expected = input };
        var admission: c.DirectSourceCapture.Admission = .{};
        var importer: root.Importer(Origin) = undefined;
        try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
        defer importer.deinit();
        _ = try importer.step(); // Hold is accepted after the original is saved.
        if (incomplete) {
            for (0..8) |_| {
                _ = importer.step() catch |err| {
                    try t.expectEqual(error.HttpReplayGap, err);
                    break;
                };
            } else return error.TestUnexpectedResult;
        } else {
            for (0..2) |_| {
                _ = try importer.step(); // A bounded incomplete first pass.
                importer.deinit();
                try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
            }
            try t.expectError(error.SourceHandoffWorkLimit, importer.step());
        }
        const observed = (try importer.inspect()).?;
        try t.expectEqual(.held, observed.state.phase);
        try t.expectEqual(null, observed.state.evidence);
        // No candidate, transaction or capture row can result from a prefix.
        try t.expectEqual(null, try catalog.store.clientToken(input.candidate.key));
        try t.expectEqual(null, try catalog.store.clientToken(input.publication.key));
        _ = try importer.cancel();
        admission.limit = 0;
        try t.expectEqual(.settled, (try importer.step()).phase);
        try t.expectEqual(.released, (try importer.step()).phase);
        var current = origin.source();
        try t.expectEqual(0, (try (x.Exchange{ .resource = 7, .id = 1 }).control(&current)).dependents);
    }
}

test "HTTP handoff refuses source revocation during copy and closes only its candidate" {
    var wal = c.storage.LocalWal.LocalWal.initMemory(runtime.allocator());
    defer wal.deinit();
    var objects = c.storage.LocalSegmentStore.LocalSegmentStore.initMemory(runtime.allocator());
    defer objects.deinit();
    var catalog = try f.owner(&wal, &objects);
    defer catalog.deinit();
    var access: f.Access = .{ .exclusive = true };
    try catalog.initialize(access.policy());
    const source = try f.captureSetup(&catalog, &access);
    var store: exchange.Store = .{};
    defer store.deinit();
    const input = savedInput(source, try original(&store, 65537, 200, false));
    var origin: Origin = .{ .store = &store, .access = &access, .expected = input };
    var admission: c.DirectSourceCapture.Admission = .{};
    var importer: root.Importer(Origin) = undefined;
    try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
    defer importer.deinit();
    for (0..16) |_| {
        if ((try importer.step()).phase == .copying) break;
    } else return error.TestUnexpectedResult;
    origin.denied = true;
    try t.expectError(error.CatalogDenied, importer.step());
    try t.expectEqual(.copying, (try importer.inspect()).?.state.phase);
    _ = try importer.cancel();
    try t.expectError(error.CatalogDenied, importer.step());
    origin.denied = false;
    try t.expectEqual(.settled, (try importer.step()).phase);
    try t.expectEqual(.released, (try importer.step()).phase);
    const state = (try catalog.store.clientTokenState(input.candidate.key)).?.capture.?;
    try t.expectEqual(.closed, state.phase);
    try t.expectEqual(null, try catalog.store.clientToken(input.publication.key));
}

test "full importer admission leaves reserved nested workspace for accepted progress" {
    var wal = c.storage.LocalWal.LocalWal.initMemory(runtime.allocator());
    defer wal.deinit();
    var objects = c.storage.LocalSegmentStore.LocalSegmentStore.initMemory(runtime.allocator());
    defer objects.deinit();
    var catalog = try f.owner(&wal, &objects);
    defer catalog.deinit();
    var access: f.Access = .{ .exclusive = true };
    try catalog.initialize(access.policy());
    const source = try f.captureSetup(&catalog, &access);
    var store: exchange.Store = .{};
    defer store.deinit();
    const input = savedInput(source, try original(&store, 65537, 200, false));
    var origin: Origin = .{ .store = &store, .access = &access, .expected = input };
    var admission: c.DirectSourceCapture.Admission = .{};
    const Importer = root.Importer(Origin);
    var active: [4]Importer = undefined;
    var count: usize = 0;
    defer for (active[0..count]) |*importer| importer.deinit();
    for (&active) |*importer| {
        try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
        count += 1;
    }
    var rejected: Importer = undefined;
    try t.expectError(error.SourceCaptureResidentLimit, rejected.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission));
    try t.expectEqual(admission.limit, admission.used);
    // Other owners are admitted but idle. Finishing this original must not
    // require spare aggregate capacity for staging, verification or closure.
    for (0..128) |_| {
        if ((try active[0].step()).phase == .released) break;
    } else return error.TestUnexpectedResult;
    try t.expectEqual(admission.limit, admission.used);
}

test "complete HTTP body one byte beyond the capture limit never admits a candidate" {
    var wal = c.storage.LocalWal.LocalWal.initMemory(runtime.allocator());
    defer wal.deinit();
    var objects = c.storage.LocalSegmentStore.LocalSegmentStore.initMemory(runtime.allocator());
    defer objects.deinit();
    var catalog = try f.owner(&wal, &objects);
    defer catalog.deinit();
    var access: f.Access = .{ .exclusive = true };
    try catalog.initialize(access.policy());
    const source = try f.captureSetup(&catalog, &access);
    var store: exchange.Store = .{};
    defer store.deinit();
    const input = savedInput(source, try original(&store, 4 * 1024 * 1024 + 1, 200, false));
    var origin: Origin = .{ .store = &store, .access = &access, .expected = input };
    var admission: c.DirectSourceCapture.Admission = .{};
    var importer: root.Importer(Origin) = undefined;
    try importer.init(runtime.allocator(), input, &origin, .{ .catalog = &catalog, .policy = access.policy() }, &admission);
    defer importer.deinit();
    for (0..128) |_| {
        _ = importer.step() catch |err| {
            try t.expectEqual(error.SourceCaptureWorkLimit, err);
            break;
        };
    } else return error.TestUnexpectedResult;
    try t.expectEqual(null, try catalog.store.clientToken(input.candidate.key));
    try t.expectEqual(null, try catalog.store.clientToken(input.publication.key));
    _ = try importer.cancel();
    try t.expectEqual(.settled, (try importer.step()).phase);
    try t.expectEqual(.released, (try importer.step()).phase);
}

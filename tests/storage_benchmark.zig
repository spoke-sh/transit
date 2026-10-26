//! Disk owner measurements. storage_benchmark.py owns fixtures, conditioning,
//! independent value oracles, repetitions and the report's completion status.
const std = @import("std");
const s = @import("transit_storage");
const f = @import("transit_fuze");
const core = @import("transit_core");
const local = @import("transit_backend_local");
const p = core.protocol;
const g = p.Growth;
const Tracker = @import("fuze_benchmarks/Allocator.zig");
const P = s.TablePartition;
const Engine = core.growing.Engine(local.Store, local.PageStore);
const rows_per_segment = 16;
const body_bytes = @import("storage_benchmark_options").body_bytes;
const segment_cache_bytes = @max(128 * 1024, body_bytes * rows_per_segment * 2);

const Counters = struct {
    wal_appends: u64 = 0,
    wal_bytes: u64 = 0,
    wal_syncs: u64 = 0,
    wal_startup_frames: u64 = 0,
    object_puts: u64 = 0,
    object_write_bytes: u64 = 0,
    object_ranges: u64 = 0,
    object_read_bytes: u64 = 0,
    index_misses: u64 = 0,
    segment_opens: u64 = 0,
    segment_ranges: u64 = 0,
    segment_bytes: u64 = 0,
    decoded_groups: u64 = 0,
    table_replay_frames: u64 = 0,
    fn read(wal: *const s.LocalWal.LocalWal, objects: *const s.LocalSegmentStore.LocalSegmentStore) Counters {
        return .{ .wal_appends = wal.appends, .wal_bytes = wal.bytes_written, .wal_syncs = wal.syncs, .wal_startup_frames = wal.recovered_frames, .object_puts = objects.puts + objects.conditional_puts, .object_write_bytes = objects.bytes_written, .object_ranges = objects.range_reads, .object_read_bytes = objects.bytes_read };
    }
    fn table(wal: *const s.LocalWal.LocalWal, objects: *const s.LocalSegmentStore.LocalSegmentStore, owner: *const P) Counters {
        var result = read(wal, objects);
        result.index_misses = owner.index.misses;
        result.segment_opens = owner.segment_reads;
        result.segment_ranges = owner.segment_range_reads;
        result.segment_bytes = owner.segment_bytes_read;
        result.decoded_groups = owner.row_groups_decoded;
        result.table_replay_frames = owner.recovery_work.replayed_frames;
        return result;
    }
    fn difference(after: Counters, before: Counters) Counters {
        var result: Counters = .{};
        inline for (comptime std.meta.fieldNames(Counters)) |name| @field(result, name) = @field(after, name) - @field(before, name);
        return result;
    }
};
const Phase = struct {
    name: []const u8,
    elapsed_ns: i96,
    allocations: usize,
    allocated_bytes: usize,
    baseline_live_bytes: usize,
    peak_live_bytes: usize,
    end_live_bytes: usize,
    counters: Counters,
    /// Table-only measurement around the real Log.append call, including sync.
    /// Native commit is measured as its own owner phase instead.
    wal_append_ns: ?i96,
    timed_appends: usize,
};
const Meter = struct {
    io: std.Io,
    tracker: *Tracker,
    start: std.Io.Timestamp = undefined,
    before: Counters = .{},
    baseline: usize = 0,
    phases: [4]Phase = undefined,
    count: usize = 0,
    timed_log: bool = false,
    append_ns: i96 = 0,
    append_calls: usize = 0,
    fn begin(self: *Meter, before: Counters) void {
        self.before = before;
        self.tracker.reset();
        self.baseline = self.tracker.live_bytes;
        self.append_ns = 0;
        self.append_calls = 0;
        self.start = std.Io.Clock.awake.now(self.io);
    }
    fn end(self: *Meter, name: []const u8, after: Counters) void {
        const elapsed = self.start.durationTo(std.Io.Clock.awake.now(self.io)).toNanoseconds();
        self.phases[self.count] = .{ .name = name, .elapsed_ns = elapsed, .allocations = self.tracker.allocations, .allocated_bytes = self.tracker.allocated_bytes, .baseline_live_bytes = self.baseline, .peak_live_bytes = self.tracker.peak_bytes, .end_live_bytes = self.tracker.live_bytes, .counters = after.difference(self.before), .wal_append_ns = if (self.timed_log) self.append_ns else null, .timed_appends = self.append_calls };
        self.count += 1;
    }
};

// Transparent instrumentation of the existing synchronous interface. There is
// no synthetic append, acknowledgement delay, batching or background worker.
const TimedLog = struct {
    inner: s.TransitLog.Log,
    meter: *Meter,
    fn log(self: *TimedLog) s.TransitLog.Log {
        return .{ .context = self, .vtable = &.{ .append = append, .read = read, .tail = tail, .trim = trim, .fence = fence } };
    }
    fn append(context: *anyopaque, partition: u64, expected: ?u64, writer: u64, policy: u64, kind: s.TransitLog.FrameKind, payload: []const u8) !s.TransitLog.AppendReceipt {
        const self: *TimedLog = @ptrCast(@alignCast(context));
        const start = std.Io.Clock.awake.now(self.meter.io);
        const receipt = try self.inner.append(partition, expected, writer, policy, kind, payload);
        self.meter.append_ns += start.durationTo(std.Io.Clock.awake.now(self.meter.io)).toNanoseconds();
        self.meter.append_calls += 1;
        return receipt;
    }
    fn read(context: *anyopaque, allocator: std.mem.Allocator, partition: u64, from: u64, count: usize) !s.TransitLog.Log.OwnedBatch {
        const self: *TimedLog = @ptrCast(@alignCast(context));
        return self.inner.read(allocator, partition, from, count);
    }
    fn tail(context: *anyopaque, partition: u64) !u64 {
        const self: *TimedLog = @ptrCast(@alignCast(context));
        return self.inner.tail(partition);
    }
    fn trim(context: *anyopaque, partition: u64, until: u64) !void {
        const self: *TimedLog = @ptrCast(@alignCast(context));
        return self.inner.trim(partition, until);
    }
    fn fence(context: *anyopaque, partition: u64, writer: u64, policy: u64) !void {
        const self: *TimedLog = @ptrCast(@alignCast(context));
        return self.inner.fence(partition, writer, policy);
    }
};
const Values = struct {
    count: u64 = 0,
    sum: i128 = 0,
    digest: [32]u8 = @splat(0),
    fn add(self: *Values, id: u64, value: i64, payload: []const u8) void {
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        var numbers: [16]u8 = undefined;
        std.mem.writeInt(u64, numbers[0..8], id, .little);
        std.mem.writeInt(i64, numbers[8..16], value, .little);
        hash.update(&numbers);
        hash.update(payload);
        const digest = hash.finalResult();
        for (&self.digest, digest) |*byte, item| byte.* ^= item;
        self.count += 1;
        self.sum += value;
    }
};
fn body(id: usize, output: *[body_bytes]u8) []const u8 {
    @memset(output, @as(u8, @intCast('a' + id % 26)));
    _ = std.fmt.bufPrint(output[0..16], "row-{d:0>12}", .{id}) catch unreachable;
    return output;
}
fn score(id: usize) i64 {
    return @as(i64, @intCast(id)) * 17 - 9;
}
fn emit(init: std.process.Init, meter: *const Meter, values: Values, visited: Values, position: u64, checkpoint: u64) !void {
    const file = try std.Io.Dir.cwd().openFile(init.io, "/proc/self/status", .{});
    defer file.close(init.io);
    var buffer: [8192]u8 = undefined;
    var reader = file.readerStreaming(init.io, &buffer);
    const status = try reader.interface.allocRemaining(init.arena.allocator(), .limited(8192));
    var lines = std.mem.splitScalar(u8, status, '\n');
    var rss: ?u64 = null;
    var virtual: ?u64 = null;
    while (lines.next()) |line| if (std.mem.startsWith(u8, line, "VmHWM:")) {
        var words = std.mem.tokenizeAny(u8, line[6..], " \t");
        rss = try std.fmt.parseInt(u64, words.next() orelse return error.MissingRss, 10);
        if (!std.mem.eql(u8, words.next() orelse return error.MissingRss, "kB")) return error.MissingRss;
    } else if (std.mem.startsWith(u8, line, "VmPeak:")) {
        var words = std.mem.tokenizeAny(u8, line[7..], " \t");
        virtual = try std.fmt.parseInt(u64, words.next() orelse return error.MissingRss, 10);
        if (!std.mem.eql(u8, words.next() orelse return error.MissingRss, "kB")) return error.MissingRss;
    };
    const selected_hash = std.fmt.bytesToHex(values.digest, .lower);
    const visited_hash = std.fmt.bytesToHex(visited.digest, .lower);
    const result = try std.json.Stringify.valueAlloc(init.arena.allocator(), .{ .complete = true, .build_mode = @tagName(@import("builtin").mode), .fixture_body_bytes = body_bytes, .phases = meter.phases[0..meter.count], .count = values.count, .sum = values.sum, .digest = selected_hash[0..], .visited = visited.count, .visited_sum = visited.sum, .visited_digest = visited_hash[0..], .position = position, .checkpoint = checkpoint, .image_peak_rss_kib = rss orelse return error.MissingRss, .image_peak_virtual_kib = virtual orelse return error.MissingRss }, .{});
    try std.Io.File.stdout().writeStreamingAll(init.io, result);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}

const object: p.DataLifecycle.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const declaration: s.TableDeclaration.Definition = .{ .object = object, .revision = 1, .properties = "", .schema = .{ .object = 7, .revision = 1, .next_column = 4, .primary_key = &.{1}, .columns = &.{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "score", .type = .int64, .nullable = false },
    .{ .id = 3, .name = "body", .type = .utf8, .nullable = false, .collation = .utf8_binary },
} } };
const pin_owner: p.DataLifecycle.Operation = .{ .scope = object.scope, .principal = 4, .operation = 1000000 };
const Access = struct {
    fn acquire(_: *anyopaque) !P.Guard.Fence {
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Access) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};
fn binding(owner: *P, id: u64) p.DataLifecycle.Binding {
    return .{ .definition = g.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = id }, .target = object, .action = if (id == 1) .create else .insert, .expected_definition = if (id == 1) null else owner.root.interpretation, .expected_data = null, .intent = @splat(7) };
}
fn verifyTable(row: f.TableRow.Row, rows: usize) !usize {
    if (row.cells.len != 3) return error.WrongRow;
    const id = std.math.cast(usize, row.cells[0].value.atom.signed) orelse return error.WrongRow;
    if (id >= rows or row.cells[1].value.atom.signed != score(id)) return error.WrongRow;
    if (row.identity.origin != 7 or row.identity.operation != id / rows_per_segment + 1 or row.identity.ordinal != rows_per_segment - 1 - id % rows_per_segment) return error.WrongIdentity;
    var expected: [body_bytes]u8 = undefined;
    if (!std.mem.eql(u8, row.cells[2].value.atom.bytes, body(id, &expected))) return error.WrongBody;
    return id;
}
fn table(init: std.process.Init, directory: std.Io.Dir, operation: []const u8, rows: usize, mode: []const u8, meter: *Meter) !void {
    const a = meter.tracker.allocator();
    meter.timed_log = true;
    meter.begin(.{});
    var wal = try s.LocalWal.LocalWal.openDiskWithOptions(a, init.io, directory, "wal", .{ .segment_bytes = 64 * 1024 });
    defer wal.deinit();
    var objects = try s.LocalSegmentStore.LocalSegmentStore.openDiskAt(a, init.io, directory, "objects");
    defer objects.deinit();
    meter.end("physical_open", Counters.read(&wal, &objects));
    meter.begin(Counters.read(&wal, &objects));
    var timed: TimedLog = .{ .inner = wal.log(), .meter = meter };
    var owner = try P.init(a, 17, declaration, timed.log(), objects.objectStore(), .{ .resident_pages = 1, .segment_cache_bytes = segment_cache_bytes, .segment_rows_per_group = rows_per_segment, .segment_decode_bytes = 128 * 1024 });
    defer owner.deinit();
    try owner.recover();
    meter.end("recover", Counters.table(&wal, &objects, &owner));
    var access: Access = .{};
    var values: Values = .{};
    var visited: Values = .{};
    meter.begin(Counters.table(&wal, &objects, &owner));
    if (std.mem.eql(u8, operation, "init")) {
        if (owner.root.next_lsn != 0) return error.ExpectedEmptyFixture;
        var cells: [rows_per_segment][3]f.Types.Values.Cell = undefined;
        var bodies: [rows_per_segment][body_bytes]u8 = undefined;
        var changes: [rows_per_segment]P.Change = undefined;
        for (0..rows / rows_per_segment) |segment| {
            for (&cells, &bodies, &changes, 0..) |*row, *bytes, *change, i| {
                const id = segment * rows_per_segment + i;
                row.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(id) } } }, .{ .value = .{ .atom = .{ .signed = score(id) } } }, .{ .value = .{ .atom = .{ .bytes = body(id, bytes) } } } };
                change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = segment + 1, .ordinal = @intCast(rows_per_segment - i - 1) }, .cells = row }, .expect = .absent } };
                values.add(id, score(id), bytes);
            }
            _ = try owner.apply(binding(&owner, segment + 1), &changes, .bulk, access.guard());
        }
        _ = try owner.pin(pin_owner, .{ .partition = 17, .next_lsn = owner.root.next_lsn }, access.guard());
        visited = values;
    } else if (std.mem.eql(u8, operation, "ingest")) {
        if (owner.root.live_rows != rows or owner.root.next_segment != rows / rows_per_segment + 1) return error.WrongFixtureSize;
        const ingestion: P.Ingestion = if (std.mem.eql(u8, mode, "point")) .point else if (std.mem.eql(u8, mode, "bulk")) .bulk else return error.InvalidArguments;
        const id = rows / rows_per_segment + 1;
        var cells: [rows_per_segment][3]f.Types.Values.Cell = undefined;
        var bodies: [rows_per_segment][body_bytes]u8 = undefined;
        var changes: [rows_per_segment]P.Change = undefined;
        for (&cells, &bodies, &changes, 0..) |*row, *bytes, *change, i| {
            const key_id = rows + i;
            row.* = .{ .{ .value = .{ .atom = .{ .signed = @intCast(key_id) } } }, .{ .value = .{ .atom = .{ .signed = score(key_id) } } }, .{ .value = .{ .atom = .{ .bytes = body(key_id, bytes) } } } };
            change.* = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = id, .ordinal = @intCast(rows_per_segment - i - 1) }, .cells = row }, .expect = .absent } };
        }
        const outcome = try owner.apply(binding(&owner, id), &changes, ingestion, access.guard());
        if (outcome.affected != rows_per_segment or owner.root.live_rows != rows + rows_per_segment) return error.IncompleteWrite;
        if (owner.root.next_segment != id + @as(u64, @intFromBool(ingestion == .bulk))) return error.WrongIngestionPath;
        for (&bodies, 0..) |*bytes, i| values.add(rows + i, score(rows + i), bytes);
        visited = values;
    } else if (std.mem.eql(u8, operation, "verify") or std.mem.eql(u8, operation, "verify-all")) {
        const appended = std.mem.eql(u8, operation, "verify");
        if (owner.root.live_rows != rows) return error.WrongFixtureSize;
        const bulk = if (std.mem.eql(u8, mode, "bulk")) true else if (std.mem.eql(u8, mode, "point")) false else return error.InvalidArguments;
        if (owner.root.next_segment != rows / rows_per_segment + @as(u64, @intFromBool(!appended or bulk))) return error.WrongIngestionPath;
        var after: ?s.TreeStore.pages.Key = null;
        while (true) {
            const page = try owner.scan(owner.root, after);
            for (page.entries) |slot| if (slot) |entry| {
                var row = try owner.readRow(a, owner.root, entry.key, entry.value);
                defer row.deinit();
                const id = try verifyTable(row.row(), rows);
                values.add(id, score(id), row.row().cells[2].value.atom.bytes);
            };
            after = page.next orelse break;
        }
        if (values.count != rows) return error.IncompleteRead;
        const original = (try owner.observe(binding(&owner, rows / rows_per_segment), access.guard())) orelse return error.MissingWriteReceipt;
        if (original.affected != rows_per_segment) return error.WrongWriteReceipt;
        // The new write preserves the original pin and its smaller retained cut.
        const pin = (try owner.pinState(pin_owner, access.guard())).handle orelse return error.MissingPin;
        var retained = try owner.inspectSnapshot(a, pin, access.guard());
        defer retained.deinit();
        if (retained.root.live_rows != rows - @as(u64, if (appended) rows_per_segment else 0)) return error.ChangedRetainedCut;
        visited = values;
    } else if (std.mem.eql(u8, operation, "checkpoint")) {
        _ = try owner.checkpoint(.{ .partition = 17, .next_lsn = owner.root.next_lsn }, access.guard());
    } else if (std.mem.eql(u8, operation, "measure")) {
        const pin = (try owner.pinState(pin_owner, access.guard())).handle orelse return error.MissingPin;
        // Capture/recovery reads are reported separately. Do not inherit a hot
        // index page from locating the retained handle into either query arm.
        owner.index.clearCache();
        const first = rows / 2 - 2;
        if (std.mem.eql(u8, mode, "range")) {
            var low: [4096]u8 = undefined;
            var high: [4096]u8 = undefined;
            const interval: P.KeyRange = .{ .lower = .{ .key = try f.Collation.encodePrimaryKeySortKey(declaration.schema, &.{.{ .value = .{ .atom = .{ .signed = @intCast(first) } } }}, false, &low) }, .upper = .{ .key = try f.Collation.encodePrimaryKeySortKey(declaration.schema, &.{.{ .value = .{ .atom = .{ .signed = @intCast(first + 4) } } }}, false, &high), .inclusive = false } };
            var after: ?P.KeyRange.Cursor = null;
            while (true) {
                var page = try owner.rangeSnapshot(a, pin, interval, after, .{ .rows = 2 }, access.guard());
                defer page.deinit();
                for (page.rows[0..page.count]) |slot| {
                    const row = slot.?.row();
                    const id = try verifyTable(row, rows);
                    if (id != first + visited.count) return error.WrongRange;
                    values.add(id, score(id), row.cells[2].value.atom.bytes);
                    visited.add(id, score(id), row.cells[2].value.atom.bytes);
                }
                after = page.next orelse break;
            }
        } else if (std.mem.eql(u8, mode, "scan")) {
            var after: ?P.SnapshotCursor = null;
            while (true) {
                var page = try owner.scanSnapshot(a, pin, after, .{}, access.guard());
                defer page.deinit();
                for (page.rows[0..page.count]) |slot| {
                    const row = slot.?.row();
                    const id = try verifyTable(row, rows);
                    if (id >= first and id < first + 4) values.add(id, score(id), row.cells[2].value.atom.bytes);
                    visited.add(id, score(id), row.cells[2].value.atom.bytes);
                }
                after = page.next orelse break;
            }
        } else return error.InvalidArguments;
        if (values.count != 4 or visited.count != (if (std.mem.eql(u8, mode, "range")) @as(usize, 4) else rows)) return error.IncompleteRead;
    } else return error.InvalidArguments;
    meter.end(operation, Counters.table(&wal, &objects, &owner));
    try emit(init, meter, values, visited, owner.root.next_lsn, if (owner.root.recovery) |ref| ref.next_lsn else 0);
}

fn key() !core.Ed25519.KeyPair {
    return core.Ed25519.KeyPair.generateDeterministic(@splat(17));
}
fn submit(engine: *Engine, command: g.Command) !u64 {
    return engine.submit(try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = command }, try key()));
}
fn query(engine: *Engine, kind: @FieldType(g.Query, "kind")) !g.Response {
    return engine.query(try g.signQuery(.{ .realm = 42, .principal = 0, .kind = kind }, try key()));
}
fn clock(_: *anyopaque) !core.Time.Sample {
    return .{ .unix_ms = 100 };
}
fn native(init: std.process.Init, directory: std.Io.Dir, operation: []const u8, rows: usize, meter: *Meter) !void {
    const a = meter.tracker.allocator();
    meter.begin(.{});
    var backend = try local.Backend.open(a, init.io, directory, "native", .{});
    defer backend.deinit();
    meter.end("physical_open", Counters.read(&backend.wal, &backend.objects));
    meter.begin(Counters.read(&backend.wal, &backend.objects));
    var pages = try local.PageStore.init(&backend, 1);
    defer pages.deinit();
    var journal: local.Store = .{ .backend = &backend };
    const genesis: core.growing.Genesis = .{ .realm = 42, .root_key = (try key()).public_key.toBytes(), .max_clock_error_ms = 5, .allow_history_trim = true };
    var engine = if (std.mem.eql(u8, operation, "init")) try Engine.bootstrap(&journal, &pages, genesis) else try Engine.open(&journal, &pages, genesis);
    var context: u8 = 0;
    engine.clock = .{ .context = &context, .read = clock };
    var counters = Counters.read(&backend.wal, &backend.objects);
    counters.index_misses = pages.misses;
    meter.end("recover", counters);
    meter.begin(counters);
    var values: Values = .{};
    const ingest = std.mem.eql(u8, operation, "ingest");
    if (std.mem.eql(u8, operation, "init") or ingest) {
        if (!ingest) {
            if (engine.head.position != 1) return error.ExpectedEmptyFixture;
            const pid = try submit(&engine, .{ .spawn = .{} });
            const sink = try submit(&engine, .{ .spawn = .{} });
            const resource = try submit(&engine, .{ .create_resource = .{ .writer = pid } });
            if (pid != 1 or sink != 2 or resource != 3) return error.WrongFixtureIdentity;
            _ = try submit(&engine, .{ .grant_resource = .{ .resource = resource, .subject = 0, .permissions = p.State.all_permissions } });
            _ = try submit(&engine, .{ .associate = .{ .pid = pid, .name = try core.Value.init("data"), .resource = resource } });
            _ = try submit(&engine, .{ .own = .{ .pid = pid, .expected_generation = 1, .worker = 0 } });
        } else if (engine.head.position != 7 + rows * 3 or (try engine.process(1)).consumed != rows) return error.WrongFixtureSize;
        const pid = 1;
        const sink = 2;
        const resource = 3;
        const start: usize = if (ingest) rows else 0;
        const end: usize = if (ingest) rows + 1 else rows;
        for (start..end) |id| {
            const input = try submit(&engine, .{ .send = .{ .pid = pid, .value = .{} } });
            const process = try engine.process(pid);
            const data = (try query(&engine, .{ .resource = resource })).body.resource;
            const view = try submit(&engine, .{ .open_view = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .resource = resource, .revision = data.revision, .deadline_ms = 150 } });
            const row_key = core.Value.integer(@intCast(id));
            var bytes: [body_bytes]u8 = undefined;
            var batch: p.Blocks.Batch = .{};
            try batch.put(row_key, body(id, &bytes));
            const turn: g.Turn = .{ .pid = pid, .generation = process.generation, .input = input, .expected_revision = process.revision, .views = .{ view, null, null, null }, .write_view = view, .mutations = .{ .{ .key = row_key, .value = core.Value.integer(score(id)) }, null, null, null }, .blocks = batch.mutations, .outputs = .{ .{ .pid = sink, .value = core.Value.integer(@intCast(id)) }, null, null, null } };
            const request = try g.sign(.{ .realm = 42, .principal = 0, .sequence = (try engine.principal(0)).sequence + 1, .command = .{ .turn = turn } }, try key());
            const prepared = try engine.prepareWithBlocks(request, &batch.body);
            if (ingest) {
                counters = Counters.read(&backend.wal, &backend.objects);
                counters.index_misses = pages.misses;
                meter.end("prepare", counters);
                meter.begin(counters);
            }
            _ = try engine.commit(prepared);
            if (ingest) {
                counters = Counters.read(&backend.wal, &backend.objects);
                counters.index_misses = pages.misses;
                meter.end("commit", counters);
            }
            values.add(id, score(id), &bytes);
        }
    } else if (std.mem.eql(u8, operation, "checkpoint")) {
        _ = try submit(&engine, .{ .checkpoint = {} });
        try journal.maintain(engine.head);
    } else if (std.mem.eql(u8, operation, "measure")) {
        const data = (try query(&engine, .{ .resource = 3 })).body.resource;
        if (data.entries != rows or data.block_entries != rows or (try engine.process(1)).consumed != rows or engine.head.outputs != rows) return error.WrongNativeState;
        for (0..rows) |id| {
            const row_key = core.Value.integer(@intCast(id));
            const record = try query(&engine, .{ .read_entries = .{ .resource = 3, .keys = .{ row_key, null, null, null, null, null, null, null } } });
            const value = try (record.body.read_entries.entries[0] orelse return error.MissingNativeValue).value.asInteger();
            if (value != score(id)) return error.WrongNativeValue;
            const read: g.Query = .{ .realm = 42, .principal = 0, .kind = .{ .block_entries = .{ .source = .{ .resource = .{ .id = 3, .revision = data.revision } }, .keys = .{ row_key, null, null, null, null, null, null, null } } } };
            var response: g.BlockRead.Response = undefined;
            response.response = try engine.queryBlocks(try g.signQuery(read, try key()), {}, &response.blocks);
            try g.BlockRead.verify(&response, read);
            var expected: [body_bytes]u8 = undefined;
            if (!std.mem.eql(u8, response.blocks.slice(), body(id, &expected))) return error.WrongNativeBlock;
            values.add(id, value, response.blocks.slice());
        }
    } else return error.InvalidArguments;
    counters = Counters.read(&backend.wal, &backend.objects);
    counters.index_misses = pages.misses;
    if (!ingest) meter.end(operation, counters);
    try emit(init, meter, values, values, engine.head.position, engine.head.history_floor);
}

pub fn main(init: std.process.Init) !void {
    if (@import("builtin").mode != .safe) return error.ExpectedReleaseSafe;
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 7) return error.InvalidArguments;
    const rows = try std.fmt.parseInt(usize, args[5], 10);
    if (rows == 0 or rows > 1048576) return error.InvalidArguments;
    if (!std.mem.eql(u8, args[4], "--rows")) return error.InvalidArguments;
    var tracker: Tracker = .{ .backing = init.gpa };
    var meter: Meter = .{ .io = init.io, .tracker = &tracker };
    const directory = try std.Io.Dir.cwd().openDir(init.io, args[3], .{});
    defer directory.close(init.io);
    if (std.mem.eql(u8, args[1], "table")) {
        if (rows < rows_per_segment or rows % rows_per_segment != 0) return error.InvalidArguments;
        try table(init, directory, args[2], rows, args[6], &meter);
    } else if (std.mem.eql(u8, args[1], "native")) {
        try native(init, directory, args[2], rows, &meter);
    } else return error.InvalidArguments;
    if (tracker.live_bytes != 0) return error.LeakedOwnerMemory;
}

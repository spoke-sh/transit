//! Replay StorageLifecycle.tla counterexample traces against production
//! TablePartition, TableArchive, TableMaintenanceState, TableStorageRoots,
//! TableStorageWalk, and DirectStorageGraph.
const std = @import("std");
const c = @import("transit_catalog");
const s = c.storage;
const p = c.protocol;
const f = c.fuze;
const a = c.TableAuthority;
const d = p.DataLifecycle;
const D = c.DirectCatalog;
const P = s.TablePartition;
const Graph = c.DirectStorageGraph;

const Event = enum {
    Init,
    FlushWal,
    PinSegment,
    StageWorkspaceSegment,
    BeginCompaction,
    CompactSegments,
    PublishArchive,
    PublishCheckpoint,
    TrimWal,
    ExpireHistory,
    ReleasePins,
    StartGC,
    AdvanceClockGrace,
    SweepGC,
};

const scope: d.Scope = .{ .realm = 1, .resource = 3, .catalog = 1 };
const profile: a.Profile = .{ .database_domain = 1, .schema_domain = 2, .table_domain = 3, .stream_domain = 31, .queue_domain = 32, .kv_domain = 33, .database = 4, .initial_schema = 1, .initial_schema_authority = 5 };
const columns = [_]f.TableSchema.Column{.{ .id = 1, .name = "id", .type = .int64, .nullable = false }};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} };
const object: d.Object = .{ .scope = scope, .branch = 1, .object = 7 };

const TableAccess = struct {
    fn acquire(_: *anyopaque) !P.Guard.Fence {
        return .{ .writer_epoch = 1, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *TableAccess) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};

const CatAccess = struct {
    const Context = struct { requested: p.Authorization.Guard };
    fn make(_: *anyopaque, allocator: std.mem.Allocator, requested: p.Authorization.Guard, prerequisite: ?p.Authorization.Guard) !P.Guard {
        if (prerequisite != null) return error.CatalogDenied;
        try requested.validate();
        const result = try allocator.create(Context);
        result.* = .{ .requested = requested };
        return .{ .context = result, .acquire = TableAccess.acquire, .release = TableAccess.release };
    }
    fn registered(_: *anyopaque, kind: a.Kind, id: u64) !?p.Authorization.Object {
        const native: u64 = switch (kind) {
            .database => profile.database,
            .schema => if (id == 1) profile.initial_schema_authority else 20000 + id,
            .table => 100 + id,
            .stream, .queue, .kv => return null,
        };
        return .{
            .reference = a.reference(native),
            .owner = 0,
            .registrar = 1,
            .actions = a.actions(kind),
            .domain = profile.domain(kind),
            .binding = try a.binding(scope, kind, id),
            .parent = switch (kind) {
                .database => null,
                .schema => a.reference(profile.database),
                .table => a.reference(profile.initial_schema_authority),
                .stream, .queue, .kv => return null,
            },
            .revision = 1,
        };
    }
    fn policy(self: *CatAccess) D.Policy {
        return .{ .context = self, .subject = .{ .accepted = .{ .pid = 3, .input = 1, .principal = 1 } }, .make_guard = make, .registered = registered };
    }
};

const MarkSet = struct {
    allocator: std.mem.Allocator,
    jobs: std.ArrayList(Graph.Work) = .empty,
    marks: std.StringHashMap(void),
    fn init(allocator: std.mem.Allocator) MarkSet {
        return .{ .allocator = allocator, .marks = .init(allocator) };
    }
    fn deinit(self: *MarkSet) void {
        var keys = self.marks.keyIterator();
        while (keys.next()) |k| self.allocator.free(k.*);
        self.marks.deinit();
        self.jobs.deinit(self.allocator);
    }
    pub fn enqueue(self: *MarkSet, work: Graph.Work) !void {
        try self.jobs.append(self.allocator, work);
    }
    pub fn mark(self: *MarkSet, key: []const u8, _: s.TransitObjectStore.ObjectMeta) !void {
        if (self.marks.contains(key)) return;
        const owned = try self.allocator.dupe(u8, key);
        errdefer self.allocator.free(owned);
        try self.marks.put(owned, {});
    }
    pub fn visited(_: *MarkSet, _: [32]u8) !bool {
        return false;
    }
};

fn binding(table: *P, op: u64) d.Binding {
    return .{
        .definition = p.Growth.current_definition,
        .identity = .{ .scope = scope, .principal = 1, .operation = op },
        .target = object,
        .action = if (table.root.next_lsn == 0) .create else .insert,
        .expected_definition = if (table.root.next_lsn == 0) null else table.root.interpretation,
        .expected_data = null,
        .intent = @splat(7),
    };
}

fn firstSegmentKey(allocator: std.mem.Allocator, table: *P) ![]u8 {
    var walk = try s.TableStorageWalk.init(try .fromRoot(table.root), .{ .kind = .rows, .reference = table.root.rows.? });
    while (try walk.next(&table.index)) |edge| {
        if (edge == .segment) {
            return std.fmt.allocPrint(allocator, "table-segments/{x}.tseg", .{&edge.segment.sha256});
        }
    }
    return error.MissingSegment;
}

fn firstArchiveKey(allocator: std.mem.Allocator, table: *P) ![]u8 {
    const tree: s.TreeStore.pages.Tree(s.TreeStore) = .{ .store = &table.index };
    const value = (try tree.get(table.root.archive.directory, try s.TableArchive.key(0))).?;
    const content = try s.TableArchive.decodeReference(value);
    var name: [96]u8 = undefined;
    const key = try s.TableArchive.objectKey(content.sha256, &name);
    return allocator.dupe(u8, key);
}

fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.InvalidTableMaintenance,
        error.GracePeriodPending,
        error.TableHistoryCoverageRequired,
        error.TableHistoryPinned,
        => @errorName(err),
        else => return err,
    };
}

fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    var table = try P.init(allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    defer table.deinit();
    try table.recover();
    var access: TableAccess = .{};

    const one: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 1 } } };
    const row_change: P.Change = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 1, .ordinal = 0 }, .cells = &.{one} }, .expect = .absent } };
    _ = try table.apply(binding(&table, 1), &.{row_change}, .point, access.guard());
    const wal_pin = try table.pin(.{ .scope = scope, .principal = 1, .operation = 100 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
    var initial_changed_lsn = table.root.changed_lsn;

    var segment_pin: ?P.SnapshotHandle = null;
    var pinned_seg_key: ?[]u8 = null;
    defer if (pinned_seg_key) |k| allocator.free(k);
    var pinned_archive_key: ?[]u8 = null;
    defer if (pinned_archive_key) |k| allocator.free(k);
    var pins_released = false;

    var ws_wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer ws_wal.deinit();
    var ws_objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer ws_objects.deinit();
    var ws_staged = false;
    var ws_seg_key: ?[]u8 = null;
    defer if (ws_seg_key) |k| allocator.free(k);

    var gc_phase: []const u8 = "idle";
    var grace_elapsed = false;
    var last_error: []const u8 = "none";
    var wal_trimmed: u64 = 0;
    var pinned_seg_preserved = true;
    var pinned_wal_preserved = true;
    var workspace_seg_preserved = true;

    for (events) |event| {
        last_error = "none";
        switch (event) {
            .Init => {},
            .FlushWal => {
                _ = try table.flush(access.guard());
                if (pinned_seg_key == null) {
                    pinned_seg_key = try firstSegmentKey(allocator, &table);
                }
            },
            .PinSegment => {
                segment_pin = try table.pin(.{ .scope = scope, .principal = 1, .operation = 101 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
                const two: f.Types.Values.Cell = .{ .value = .{ .atom = .{ .signed = 2 } } };
                const row_change_2: P.Change = .{ .put = .{ .row = .{ .identity = .{ .origin = 7, .operation = 2, .ordinal = 0 }, .cells = &.{two} }, .expect = .absent } };
                _ = try table.apply(binding(&table, 2), &.{row_change_2}, .point, access.guard());
                _ = try table.flush(access.guard());
                initial_changed_lsn = table.root.changed_lsn;
            },
            .StageWorkspaceSegment => {
                var cat_access: CatAccess = .{};
                const cfg: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 3, .authority = profile, .database_name = try a.Name.init("main"), .initial_schema_name = try a.Name.init("public") };
                var catalog = try D.init(allocator, cfg, ws_wal.log(), ws_objects.objectStore(), ws_wal.log(), ws_objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
                defer catalog.deinit();
                try catalog.recover();
                try catalog.initialize(cat_access.policy());
                const create_intent: D.Intent = .{ .namespace = 1, .name = try a.Name.init("selected_0"), .action = .{ .create = .{ .schema = .{ .object = 10, .revision = 1, .next_column = 2, .columns = &columns, .primary_key = &.{1} }, .owner = 0 } } };
                const create_req: D.Request = .{
                    .binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 10 }, .target = .{ .scope = scope, .branch = 1, .object = 10 }, .action = .create, .expected_definition = null, .expected_data = null, .intent = try create_intent.digest(allocator) },
                    .intent = create_intent,
                };
                _ = try catalog.admit(create_req, cat_access.policy());
                _ = try catalog.perform(create_req.binding, cat_access.policy());
                _ = try catalog.settle(create_req.binding, cat_access.policy());

                const connection: c.DirectTableProtocol.Connection = .{ .scope = scope, .branch = 1, .audience = 3, .principal = 1, .role = null };
                const tx_id: p.Transaction.Identity = .{ .begin = .{ .scope = scope, .principal = 1, .operation = 50 }, .branch = 1 };
                var selected = try s.TransactionDirectory.init(allocator, catalog.data_objects, tx_id, .participants, 100, 1, 1024 * 1024);
                defer selected.deinit();
                var view = (try catalog.resolve(allocator, 1, try a.Name.init("selected_0"), cat_access.policy())).?;
                defer view.deinit();
                const root = view.table.root;
                try selected.put(.{ .participant = .{ .state = .{ .kind = .table, .access = .read, .guard = .{ .source = .{ .interpretation = root.interpretation, .accepted = .{ .partition = root.partition, .next_lsn = root.next_lsn } }, .changed_lsn = root.changed_lsn } } } });
                const tx_binding: c.DirectClientToken.Binding = .{
                    .key = .{ .definition = p.Growth.current_definition, .connection = connection, .account = @splat(9), .token = @splat(1) },
                    .fingerprint = @splat(11),
                    .intent = .{ .transaction = .{
                        .connection = connection,
                        .namespace = 1,
                        .begin = .{ .definition = p.Growth.current_definition, .identity = tx_id, .mode = .serializable, .selection = .explicit_tables, .tables = try selected.seal(), .catalog = .{ .partition = 1, .next_lsn = catalog.store.root.next_lsn }, .limits = .{ .resident_bytes = 16 * 1024 * 1024, .workspace_bytes = 256 * 1024, .participants = 100, .statements = 100, .savepoints = 16 } },
                    } },
                };
                _ = try catalog.clientToken(.{ .bind = tx_binding }, cat_access.policy());
                _ = try catalog.acquireTransaction(tx_binding.key, cat_access.policy());
                const stmt_binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .principal = 1, .operation = 500 }, .target = root.interpretation.object, .action = .insert, .expected_definition = root.interpretation, .expected_data = null, .intent = @splat(3) };
                const dml_req: s.TableDmlIntent.Request = .{ .binding = stmt_binding, .interpretation = root.declared(), .changes = &.{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(stmt_binding.identity, 0), .cells = &.{one} }, .expect = .absent } }}, .ingestion = .bulk };
                const ws_req: c.DirectTransactionWorkspace.Request = .{ .basis = (try catalog.inspectTransaction(tx_binding.key, cat_access.policy())).revision, .statement = .{ .transaction = tx_id, .sequence = 1, .intent = stmt_binding.intent }, .binding = stmt_binding, .intent = try s.TableDmlIntent.stage(allocator, catalog.data_objects, dml_req) };
                _ = try catalog.admitTransactionStatement(tx_binding.key, ws_req, cat_access.policy());
                _ = try catalog.executeTransactionStatement(tx_binding.key, ws_req, cat_access.policy());
                for (ws_objects.objects.items) |stored| {
                    if (std.mem.startsWith(u8, stored.key, "table-segments/")) {
                        ws_seg_key = try allocator.dupe(u8, stored.key);
                        break;
                    }
                }
                ws_staged = true;
            },
            .BeginCompaction => {},
            .CompactSegments => {
                if (table.root.next_segment > 0) {
                    _ = try table.compact(table.root.next_segment, .{}, access.guard());
                }
                const before_seg = @max(table.root.next_segment, 1);
                // Attempting to compact or skip a segment >= before_segment must fail closed.
                var illegal_root = table.root;
                illegal_root.maintenance.compaction_target = .{ .before_segment = before_seg, .source_lsn = table.root.maintenance.compacted_source_lsn, .after_segment = 0 };
                const action: @FieldType(s.TablePartitionRecord.Record, "action") = .{ .maintenance = .{ .skip_compaction = before_seg } };
                _ = @FieldType(P.Root, "maintenance").transition(illegal_root, illegal_root, action) catch |err| {
                    last_error = try expectedError(err);
                };
            },
            .PublishArchive => {
                const cut: d.Position = .{ .partition = 17, .next_lsn = table.root.next_lsn };
                while (!(try table.archive(cut, .{}, access.guard())).complete) {}
                if (pinned_archive_key == null) {
                    pinned_archive_key = try firstArchiveKey(allocator, &table);
                }
            },
            .PublishCheckpoint => {
                _ = try table.checkpoint(.{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
            },
            .TrimWal => {
                if (table.trimArchived(access.guard())) |trimmed| {
                    wal_trimmed = trimmed;
                } else |err| {
                    last_error = try expectedError(err);
                }
            },
            .ExpireHistory => {
                const cut: d.Position = .{ .partition = 17, .next_lsn = 2 };
                if (table.expireHistory(cut, access.guard())) |_| {} else |err| {
                    last_error = try expectedError(err);
                }
            },
            .ReleasePins => {
                try table.releaseSnapshot(wal_pin, access.guard());
                if (segment_pin) |sp| try table.releaseSnapshot(sp, access.guard());
                pins_released = true;
            },
            .StartGC => {
                gc_phase = "wait";
            },
            .AdvanceClockGrace => {
                grace_elapsed = true;
            },
            .SweepGC => {
                if (!grace_elapsed) {
                    last_error = try expectedError(error.GracePeriodPending);
                } else {
                    gc_phase = "complete";
                    var marks = MarkSet.init(allocator);
                    defer marks.deinit();
                    try marks.enqueue(.{ .table_history = try .init(.{ .root = table.root, .chain = table.chain }) });
                    var at: usize = 0;
                    while (at < marks.jobs.items.len) : (at += 1) {
                        var work = marks.jobs.items[at];
                        while (!try Graph.step(allocator, &table.index, wal.log(), &work, &marks)) {}
                    }
                    if (pinned_seg_key) |k| {
                        pinned_seg_preserved = marks.marks.contains(k);
                    }
                    if (pinned_archive_key) |k| {
                        pinned_wal_preserved = marks.marks.contains(k);
                    }
                    if (ws_staged) {
                        const cfg: D.Configuration = .{ .scope = scope, .branch = 1, .partition = 1, .audience = 3, .authority = profile, .database_name = try a.Name.init("main"), .initial_schema_name = try a.Name.init("public") };
                        var catalog = try D.init(allocator, cfg, ws_wal.log(), ws_objects.objectStore(), ws_wal.log(), ws_objects.objectStore(), .{ .resident_pages = 1, .table = .{ .resident_pages = 1 } });
                        defer catalog.deinit();
                        try catalog.recover();
                        var ws_marks = MarkSet.init(allocator);
                        defer ws_marks.deinit();
                        try ws_marks.enqueue(.{ .catalog_history = try .init(try catalog.store.recoveryState()) });
                        var ws_at: usize = 0;
                        while (ws_at < ws_marks.jobs.items.len) : (ws_at += 1) {
                            var work = ws_marks.jobs.items[ws_at];
                            while (!try Graph.step(allocator, &catalog.store.index, ws_wal.log(), &work, &ws_marks)) {}
                        }
                        if (ws_seg_key) |k| {
                            workspace_seg_preserved = ws_marks.marks.contains(k);
                        }
                    }
                }
            },
        }
    }

    try std.json.Stringify.value(.{
        .changed_lsn = table.root.changed_lsn,
        .initial_changed_lsn = initial_changed_lsn,
        .archive_through = table.root.archive.through,
        .wal_trimmed = wal_trimmed,
        .history_floor = table.root.history_floor,
        .gc_phase = gc_phase,
        .pinned_seg_preserved = pinned_seg_preserved,
        .pinned_wal_preserved = pinned_wal_preserved,
        .workspace_seg_preserved = workspace_seg_preserved,
        .last_error = last_error,
    }, .{}, out);
    try out.writeByte('\n');
}

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedTracePath;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(bytes);
    var traces = try std.json.parseFromSlice([]const []const Event, init.gpa, bytes, .{});
    defer traces.deinit();
    if (traces.value.len > 128) return error.TooManyTraces;
    var output_buffer: [8192]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    for (traces.value) |events| {
        if (events.len > 128) return error.TraceTooLong;
        try replay(init.gpa, events, &output.interface);
    }
    try output.interface.flush();
}

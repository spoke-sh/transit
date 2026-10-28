//! Selected lifecycle counterexamples against the real TablePartition owner.
//! Catalog token binding, proposed TRUNCATE/combined SQL acceptance and physical
//! power loss have separate owners; this adapter does not simulate them.
const std = @import("std");
const s = @import("transit_storage");
const p = @import("transit_protocol");
const f = @import("transit_fuze");
const d = p.DataLifecycle;
const P = s.TablePartition;
const Event = enum { Init, Freeze, Accept, Commit, Retry, Cancel, Observe, LaterInsert, Crash, Recover, Fence, Execution, Inspection, LoseReply, Cleanup };
const columns = [_]f.TableSchema.Column{
    .{ .id = 1, .name = "id", .type = .int64, .nullable = false },
    .{ .id = 2, .name = "value", .type = .int64, .nullable = false },
};
const schema: f.TableSchema.Schema = .{ .object = 7, .revision = 1, .next_column = 3, .columns = &columns, .primary_key = &.{1} };
const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 7 };
const Access = struct {
    allowed: bool = true,
    epoch: u64 = 1,
    fn acquire(context: *anyopaque) !P.Guard.Fence {
        const self: *Access = @ptrCast(@alignCast(context));
        if (!self.allowed) return error.PermissionDenied;
        return .{ .writer_epoch = self.epoch, .policy_epoch = 1 };
    }
    fn release(_: *anyopaque) void {}
    fn guard(self: *Access) P.Guard {
        return .{ .context = self, .acquire = acquire, .release = release };
    }
};
fn owner(allocator: std.mem.Allocator, wal: *s.LocalWal.LocalWal, objects: *s.LocalSegmentStore.LocalSegmentStore) !P {
    var table = try P.init(allocator, 17, .{ .object = object, .revision = 1, .schema = schema, .properties = "" }, wal.log(), objects.objectStore(), .{ .resident_pages = 1 });
    errdefer table.deinit();
    try table.recover();
    return table;
}
fn binding(table: *P, id: u64, action: d.Action) d.Binding {
    return .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 4, .operation = id }, .target = object, .action = action, .expected_definition = if (action == .create) null else table.root.interpretation, .expected_data = if (action == .create) null else .{ .partition = 17, .next_lsn = table.root.next_lsn }, .intent = @splat(7) };
}
fn insert(table: *P, access: *Access, id: i64, operation: u64) !void {
    const exact = binding(table, operation, .insert);
    const cells = [_]f.Types.Values.Cell{ .{ .value = .{ .atom = .{ .signed = id } } }, .{ .value = .{ .atom = .{ .signed = 1 } } } };
    const changes = [_]P.Change{.{ .put = .{ .row = .{ .identity = try s.TableDmlIntent.insertIdentity(exact.identity, 0), .cells = &cells }, .expect = .absent } }};
    const state = try table.commit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = &changes, .ingestion = .point }, access.guard());
    if (state != .committed) return error.InsertNotCommitted;
}
fn expectedError(err: anyerror) ![]const u8 {
    return switch (err) {
        error.LostAcknowledgement, error.PermissionDenied, error.StaleWriterEpoch => @errorName(err),
        else => return err,
    };
}
fn replay(allocator: std.mem.Allocator, events: []const Event, out: *std.Io.Writer) !void {
    var wal = s.LocalWal.LocalWal.initMemory(allocator);
    defer wal.deinit();
    var objects = s.LocalSegmentStore.LocalSegmentStore.initMemory(allocator);
    defer objects.deinit();
    var table = try owner(allocator, &wal, &objects);
    defer table.deinit();
    var access: Access = .{};
    _ = try table.apply(binding(&table, 1, .create), &.{}, .point, access.guard());
    try insert(&table, &access, 1, 2);
    try insert(&table, &access, 2, 3);
    const snapshot = try table.pin(.{ .scope = object.scope, .principal = 4, .operation = 4 }, .{ .partition = 17, .next_lsn = table.root.next_lsn }, access.guard());
    var compiled = try f.TableDml.compile(allocator, "UPDATE events SET value = 2", "events", schema, null);
    defer compiled.deinit();
    var exact = binding(&table, 10, .update);
    exact.intent = try compiled.plan.fingerprint(allocator);
    var execution = true;
    var inspection = true;
    var online = true;
    var epoch: u64 = 1;
    var first: ?P.Evidence = null;
    var last_error: []const u8 = "none";
    for (events) |event| {
        last_error = "none";
        access.allowed = execution;
        switch (event) {
            .Init, .LoseReply => {},
            .Freeze => {
                exact = binding(&table, 10, .update);
                exact.intent = try compiled.plan.fingerprint(allocator);
            },
            .Accept => {
                _ = table.admit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = &.{}, .ingestion = .bulk, .statement = compiled.plan }, access.guard()) catch |err| blk: {
                    last_error = try expectedError(err);
                    break :blk P.OperationState.not_observed;
                };
            },
            .Commit, .Retry, .Cancel, .Observe => {
                if (!online) return error.UnmappedOfflineAction;
                access.allowed = if (event == .Observe or event == .Retry) inspection else execution;
                // The first completion reply is deliberately lost. Observation
                // below must recover the exact receipt, including after retry.
                table.lose_reply = event == .Commit and first == null;
                const result = (switch (event) {
                    .Commit => table.commit(.{ .binding = exact, .interpretation = table.root.declared(), .changes = &.{}, .ingestion = .bulk, .statement = compiled.plan }, access.guard()),
                    .Cancel => table.cancel(exact, access.guard()),
                    else => table.operationState(exact, access.guard()),
                }) catch |err| blk: {
                    last_error = try expectedError(err);
                    break :blk P.OperationState.not_observed;
                };
                table.lose_reply = false;
                if (result == .committed) {
                    if (first) |original| if (!std.meta.eql(original, result.committed)) return error.ChangedOriginalOutcome;
                }
            },
            .LaterInsert => {
                var current: Access = .{ .epoch = epoch };
                try insert(&table, &current, 3, 20);
            },
            .Execution => execution = !execution,
            .Inspection => inspection = !inspection,
            .Fence => {
                epoch = 2;
                try wal.fenceEpochs(17, epoch, 1);
            },
            .Crash => {
                online = false;
            },
            .Recover => {
                table.deinit();
                table = try owner(allocator, &wal, &objects);
                access.epoch = epoch;
                online = true;
            },
            .Cleanup => {
                var current: Access = .{ .epoch = epoch };
                _ = try table.checkpoint(.{ .partition = 17, .next_lsn = table.root.next_lsn }, current.guard());
            },
        }
        // An uncertain append poisons the owner. Reconstruct it before the
        // oracle reads; this extra recovery is recorded in the model guide.
        if (table.recovery_required) try table.recover();
        // Independent inspection for the oracle, never caller disclosure.
        var auditor: Access = .{ .epoch = epoch };
        const state = try table.operationState(exact, auditor.guard());
        if (state == .committed) {
            if (first) |original| {
                if (!std.meta.eql(original, state.committed)) return error.ChangedOriginalOutcome;
            } else first = state.committed;
        }
    }
    var auditor: Access = .{ .epoch = epoch };
    const state = try table.operationState(exact, auditor.guard());
    var rows: [3]i128 = @splat(0);
    var after: ?s.TreeStore.pages.Key = null;
    while (true) {
        const batch = try table.scan(table.root, after);
        for (batch.entries) |slot| if (slot) |entry| {
            var row = try table.readRow(allocator, table.root, entry.key, entry.value);
            defer row.deinit();
            const index = row.row().cells[0].value.atom.signed - 1;
            if (index < 0 or index >= rows.len or rows[@intCast(index)] != 0) return error.UnexpectedRow;
            rows[@intCast(index)] = row.row().cells[1].value.atom.signed;
        };
        after = batch.next orelse break;
    }
    var retained = try table.scanSnapshot(allocator, snapshot, null, .{}, auditor.guard());
    defer retained.deinit();
    if (retained.total_rows != 2) return error.RetainedSnapshotChanged;
    for (retained.rows) |slot| if (slot) |row| {
        if (row.row().cells[1].value.atom.signed != 1) return error.RetainedSnapshotChanged;
    };
    try std.json.Stringify.value(.{ .rows = rows, .decision = @tagName(state), .matched = if (state == .committed) state.committed.outcome.matched else 0, .changed = if (state == .committed) state.committed.outcome.affected else 0, .last_error = last_error, .retained_rows = retained.total_rows }, .{}, out);
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

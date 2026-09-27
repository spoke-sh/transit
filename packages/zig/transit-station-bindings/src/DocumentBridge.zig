//! Bounded scoped owner operations and independent current-policy reads. This
//! layer only converts owned host values; Station owns all Document semantics.
const std = @import("std");
const codec = @import("DocumentCodec.zig");
const d = codec.document;
const s = d.station;
const p = s.protocol;
const a = @import("Actions.zig");
const Allocator = std.mem.Allocator;
const unsigned = codec.unsigned;
pub const Identity = struct {
    resource: u64,
    document: []const u8,
    pub fn native(self: Identity) !d.Client.Identity {
        const out: d.Client.Identity = .{ .resource = self.resource, .document = try unsigned(self.document) };
        _ = try out.service();
        return out;
    }
};
pub const Job = struct { document: []const u8, job: []const u8 };
pub const Action = union(enum) {
    create: struct { document: []const u8, type_revision: u32, record_bytes: u32, staging_bytes: []const u8, staging_records: u32 },
    stage: struct { document: []const u8, job: []const u8, change: []const u8, node_limit: u32 },
    checkpoint: Job,
    merge_window: struct { document: []const u8, revisions: []const u8 },
    reject: struct { document: []const u8, job: []const u8, checkpoint: bool = false },
    collect: struct { document: []const u8, job: []const u8, checkpoint: bool = false, retired: bool = false },
    retire: []const u8,
};
pub const Progress = struct { phase: enum { progress, accepted, duplicate, checkpoint_complete }, revision: ?[]const u8 = null };
pub const Result = union(enum) { none, progress: Progress, collected: bool };
fn service(turn: *s.GrowingTurn, name: []const u8) !d.Service {
    return (try (Identity{ .resource = turn.view.resource, .document = name }).native()).service();
}
pub fn apply(alloc: Allocator, turn: *s.GrowingTurn, action: Action) !Result {
    // Also preserve private proposals when called outside the foreign ABI.
    const before = turn.decision;
    errdefer turn.decision = before;
    switch (action) {
        .create => |v| try (try service(turn, v.document)).create(turn, v.type_revision, .{ .record_bytes = v.record_bytes, .staging_bytes = try unsigned(v.staging_bytes), .staging_records = v.staging_records }),
        .stage => |v| {
            const owner = try service(turn, v.document);
            const id = try unsigned(v.job);
            const change = try d.codec.decode(try codec.unhex(alloc, v.change, d.Model.max_change_bytes));
            const existing = owner.job(turn, id) catch |err| switch (err) {
                error.DocumentJobNotFound => {
                    _ = try owner.prepare(turn, id, change, v.node_limit);
                    return .{ .progress = .{ .phase = .progress } };
                },
                else => return err,
            };
            // Recheck commitment and current retirement even for duplicate jobs.
            _ = try owner.prepare(turn, id, change, v.node_limit);
            switch (existing.phase) {
                .preparing => {
                    _ = try owner.upload(turn, id, change);
                    return .{ .progress = .{ .phase = .progress } };
                },
                .rejected => return error.DocumentJobClosed,
                .building, .accepted => switch (try owner.advance(turn, id)) {
                    .progress => return .{ .progress = .{ .phase = .progress } },
                    .accepted => |revision| return .{ .progress = .{ .phase = .accepted, .revision = try a.decimal(alloc, revision) } },
                    .duplicate => |revision| return .{ .progress = .{ .phase = .duplicate, .revision = try a.decimal(alloc, revision) } },
                },
            }
        },
        .checkpoint => |v| {
            const owner = try service(turn, v.document);
            const id = try unsigned(v.job);
            _ = d.Checkpoint.inspect(owner, turn, id) catch |err| switch (err) {
                error.DocumentCheckpointNotFound => {
                    try d.Checkpoint.begin(owner, turn, id);
                    return .{ .progress = .{ .phase = .progress } };
                },
                else => return err,
            };
            return switch (try d.Checkpoint.step(owner, turn, id)) {
                .progress => .{ .progress = .{ .phase = .progress } },
                .complete => |revision| .{ .progress = .{ .phase = .checkpoint_complete, .revision = try a.decimal(alloc, revision) } },
            };
        },
        .merge_window => |v| try (try service(turn, v.document)).configureMergeWindow(turn, try unsigned(v.revisions)),
        .reject => |v| {
            const owner = try service(turn, v.document);
            if (v.checkpoint) try d.Checkpoint.reject(owner, turn, try unsigned(v.job)) else try owner.reject(turn, try unsigned(v.job));
        },
        .collect => |v| {
            const owner = try service(turn, v.document);
            const id = try unsigned(v.job);
            return .{ .collected = if (v.checkpoint)
                if (v.retired) try d.Checkpoint.collectRetired(owner, turn, id) else try d.Checkpoint.collectRejected(owner, turn, id)
            else if (v.retired) try owner.collectRetired(turn, id) else try owner.collectRejected(turn, id) };
        },
        .retire => |v| try (try service(turn, v)).retire(turn),
    }
    try turn.validate();
    return .none;
}
pub const ReadAction = union(enum) {
    describe: Identity,
    path: struct { reference: p.Value, names: []const []const u8 },
    sequence: struct { reference: p.Value, object: codec.Dot, cursor: ?[]const u8 = null },
    resynchronize: struct { identity: Identity, replica: []const u8 },
    accepted_change: p.Value,
};
pub const Assignment = struct { id: codec.Dot, value: codec.Scalar };
pub const Register = struct {
    status: d.Document.Register.Status,
    assignments: []const Assignment,
    pub fn fromNative(alloc: Allocator, value: d.Document.Register) !Register {
        if (value.len > d.Model.max_conflicts) return error.InvalidDocumentState;
        const values = try alloc.alloc(Assignment, value.len);
        for (values, value.assignments[0..value.len]) |*out, in| out.* = .{ .id = try codec.Dot.fromNative(alloc, in.id), .value = try codec.Scalar.fromNative(alloc, in.value) };
        return .{ .status = value.status(), .assignments = values };
    }
};
pub const Description = struct { reference: p.Value, source_revision: u64, floor: []const u8, merge_window: []const u8, retired: bool, active_job: []const u8, change_format: u32 };
pub const Item = struct { id: codec.Dot, values: Register };
pub const ReadResult = union(enum) {
    description: Description,
    field: struct { reference: p.Value, source_revision: u64, value: Register },
    page: struct { reference: p.Value, source_revision: u64, items: []const Item, next: ?[]const u8 },
    resynchronization: struct { reference: p.Value, floor: []const u8, replica: []const u8, previous_counter: []const u8, clock: []const u8 },
    change: codec.Change,
};
const Cursor = struct { reference: p.Value, object: codec.Dot, current: codec.Dot, phase: @FieldType(d.Document.SequenceCursor, "phase") };
pub fn read(alloc: Allocator, client: d.Client, action: ReadAction) !ReadResult {
    switch (action) {
        .describe => |v| {
            const out = try client.describe(try v.native());
            return .{ .description = .{ .reference = try out.reference.encode(), .source_revision = out.source_revision, .floor = try a.decimal(alloc, out.floor), .merge_window = try a.decimal(alloc, out.merge_window), .retired = out.retired, .active_job = try a.decimal(alloc, out.active_job), .change_format = out.change_format } };
        },
        .path => |v| {
            if (v.names.len == 0 or v.names.len > 16) return error.InvalidDocumentPath;
            var names: [16]d.Model.Name = undefined;
            for (v.names, 0..) |name, i| names[i] = try d.Model.Name.init(name);
            const out = try client.readPath(try d.Client.Reference.decode(v.reference), names[0..v.names.len]);
            return .{ .field = .{ .reference = v.reference, .source_revision = out.source_revision, .value = try Register.fromNative(alloc, out.value) } };
        },
        .sequence => |v| {
            const ref = try d.Client.Reference.decode(v.reference);
            var cursor: d.Service.PageCursor = .{ .revision = ref.revision, .object = try v.object.native() };
            if (v.cursor) |bytes| {
                if (bytes.len == 0 or bytes.len > 1024) return error.InvalidDocumentCursor;
                const parsed = try std.json.parseFromSlice(Cursor, alloc, bytes, .{});
                const saved = parsed.value;
                if (!std.mem.eql(u8, bytes, try std.json.Stringify.valueAlloc(alloc, saved, .{})) or !p.Value.eql(saved.reference, v.reference) or !std.meta.eql(try saved.object.native(), cursor.object)) return error.InvalidDocumentCursor;
                cursor.traversal = .{ .current = try saved.current.native(), .phase = saved.phase };
            }
            const out = try client.readSequence(ref, cursor);
            const items = try alloc.alloc(Item, out.value.len);
            for (items, out.value.items[0..out.value.len]) |*target, item| target.* = .{ .id = try codec.Dot.fromNative(alloc, item.id), .values = try Register.fromNative(alloc, item.values) };
            const next = if (out.value.next) |more| try std.json.Stringify.valueAlloc(alloc, Cursor{ .reference = v.reference, .object = try codec.Dot.fromNative(alloc, more.object), .current = try codec.Dot.fromNative(alloc, more.traversal.current), .phase = more.traversal.phase }, .{}) else null;
            return .{ .page = .{ .reference = v.reference, .source_revision = out.source_revision, .items = items, .next = next } };
        },
        .resynchronize => |v| {
            const identity = try v.identity.native();
            const replica = try unsigned(v.replica);
            if (replica == 0) return error.InvalidDocumentIdentity;
            const out = try client.resynchronize(identity, replica);
            const ref: d.Client.Reference = .{ .resource = identity.resource, .document = out.document, .epoch = out.epoch, .type_revision = out.type_revision, .revision = out.revision };
            return .{ .resynchronization = .{ .reference = try ref.encode(), .floor = try a.decimal(alloc, out.floor), .replica = try a.decimal(alloc, out.replica), .previous_counter = try a.decimal(alloc, out.previous_counter), .clock = try a.decimal(alloc, out.clock) } };
        },
        .accepted_change => |v| return .{ .change = try codec.Change.fromNative(alloc, try client.acceptedChange(try d.Client.Reference.decode(v))) },
    }
}
test "foreign Document registers expose only initialized conflict assignments" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const missing = try Register.fromNative(alloc, .{});
    try t.expectEqual(.missing, missing.status);
    try t.expectEqual(@as(usize, 0), missing.assignments.len);
    var value: d.Document.Register = .{ .len = 2 };
    value.assignments[0] = .{ .id = .{ .replica = 1, .counter = 1 }, .value = .null_value };
    value.assignments[1] = .{ .id = .{ .replica = std.math.maxInt(u64), .counter = 2 }, .value = .{ .character = '🙂' } };
    const conflict = try Register.fromNative(alloc, value);
    try t.expectEqual(.conflict, conflict.status);
    try t.expectEqual(@as(usize, 2), conflict.assignments.len);
    try t.expectEqualStrings("18446744073709551615", conflict.assignments[1].id.replica);
    _ = try std.json.Stringify.valueAlloc(alloc, conflict, .{});
}

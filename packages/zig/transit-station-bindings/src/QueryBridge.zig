//! Owned foreign query operations over the signed shared Zig client. No native
//! handle is recovery state; prepared bytes and cursors belong to the caller.
const std = @import("std");
const c = @import("QueryCodec.zig");
pub const q = c.query;
const a = @import("Actions.zig");
const m = q.fuze.Unified;
const p = q.protocol;
const Allocator = std.mem.Allocator;
pub const Command = union(enum) {
    initialize,
    begin: p.Value,
    part: struct { namespace: []const u8, ordinal: u32, second: bool, bytes: []const u8 },
    seal: []const u8,
    submit: []const u8,
    cancel: []const u8,
    collect: []const u8,
    retire: []const u8,
    pub fn native(self: Command, alloc: Allocator) !q.UnifiedRequest.Command {
        const result: q.UnifiedRequest.Command = switch (self) {
            .initialize => .initialize,
            .begin => |v| .{ .begin = try q.station.PublicationReference.decode(v) },
            .part => |v| .{ .part = .{ .namespace = try c.unsigned(v.namespace), .ordinal = v.ordinal, .second = v.second, .bytes = try c.unhex(alloc, v.bytes, q.UnifiedRequest.part_bytes) } },
            inline else => |v, tag| @unionInit(q.UnifiedRequest.Command, @tagName(tag), try c.unsigned(v)),
        };
        _ = try result.encode();
        return result;
    }
};
pub const Action = union(enum) {
    capabilities,
    describe: c.Source,
    prepare: Command,
    next: struct { namespace: []const u8, bundle: []const u8 },
    submit: []const u8,
    observe: u64,
    status: []const u8,
    page: struct { namespace: []const u8, cursor: ?[]const u8 = null },
};
pub const Description = struct {
    capabilities: q.UnifiedClient.Capabilities,
    source: c.Source,
    resource_revision: u64,
    policy_revision: []const u8,
    limits: c.Limits,
    active: ?[]const u8,
};
pub const Status = struct {
    reference: p.Value,
    phase: q.UnifiedRequest.Phase,
    correlation: []const u8,
    manifest: ?p.Value,
    collected: bool,
    pub fn fromNative(alloc: Allocator, value: q.UnifiedRequest.Status) !Status {
        return .{ .reference = try value.reference.encode(), .phase = value.phase, .correlation = try a.decimal(alloc, value.correlation), .manifest = if (value.manifest) |ref| try ref.encode() else null, .collected = value.collected };
    }
};
pub const Manifest = struct {
    job: u64,
    source: p.Growth.ReadVersionId,
    requester: u64,
    correlation: []const u8,
    policy_revision: []const u8,
    request: p.Value,
    basis: m.Basis,
    plan: [32]u8,
    pages: []const u8,
    scanned: []const u8,
    selected: []const u8,
    segments: []const u8,
    rows: []const u8,
    bytes: []const u8,
    sum: ?[]const u8,
    finished: @FieldType(m.Stream.Progress, "finished"),
    chain: [32]u8,
    pub fn fromNative(alloc: Allocator, value: q.UnifiedRecords.Manifest) !Manifest {
        const progress = value.checkpoint.progress;
        return .{ .job = value.job.id, .source = value.job.source, .requester = value.job.destination, .correlation = try a.decimal(alloc, value.job.correlation), .policy_revision = try a.decimal(alloc, value.job.policy_revision), .request = try value.job.request.encode(), .basis = progress.basis, .plan = progress.plan, .pages = try a.decimal(alloc, progress.pages), .scanned = try a.decimal(alloc, progress.scanned), .selected = try a.decimal(alloc, progress.selected), .segments = try a.decimal(alloc, progress.segments), .rows = try a.decimal(alloc, progress.rows), .bytes = try a.decimal(alloc, value.checkpoint.bytes), .sum = if (progress.sum) |sum| try a.decimal(alloc, sum) else null, .finished = progress.finished, .chain = value.checkpoint.chain };
    }
};
pub const Page = struct {
    manifest: Manifest,
    columns: []const c.Column,
    ordinal: []const u8,
    rows: u8,
    ipc: []const u8,
    next: ?[]const u8,
};
pub const Result = union(enum) {
    capabilities: q.UnifiedClient.Capabilities,
    description: Description,
    prepared: ?[]const u8,
    receipt: p.Receipt,
    observation: q.UnifiedClient.Observation,
    status: ?Status,
    page: Page,
};
pub fn prepared(alloc: Allocator, bytes: []const u8) !q.UnifiedClient.Prepared {
    if (bytes.len == 0 or bytes.len > 8192) return error.InvalidQueryRequest;
    const parsed = try std.json.parseFromSlice(q.UnifiedClient.Prepared, alloc, bytes, .{});
    if (!std.mem.eql(u8, bytes, try std.json.Stringify.valueAlloc(alloc, parsed.value, .{}))) return error.InvalidQueryRequest;
    return parsed.value;
}
fn cursor(alloc: Allocator, bytes: []const u8) !q.UnifiedResult.Cursor {
    if (bytes.len == 0 or bytes.len > 4096) return error.InvalidQueryCursor;
    const parsed = try std.json.parseFromSlice(q.UnifiedResult.Cursor, alloc, bytes, .{});
    if (!std.mem.eql(u8, bytes, try std.json.Stringify.valueAlloc(alloc, parsed.value, .{}))) return error.InvalidQueryCursor;
    return parsed.value;
}
pub fn apply(alloc: Allocator, client: *q.UnifiedClient, action: Action) !Result {
    switch (action) {
        .capabilities => return .{ .capabilities = .{} },
        .describe => |v| {
            const result = try client.describe(try v.native(alloc));
            return .{ .description = .{ .capabilities = result.capabilities, .source = try c.Source.fromNative(alloc, result.definition), .resource_revision = result.resource_revision, .policy_revision = try a.decimal(alloc, result.policy_revision), .limits = try c.Limits.fromNative(alloc, result.limits), .active = if (result.active) |id| try a.decimal(alloc, id) else null } };
        },
        .prepare => |v| return .{ .prepared = try std.json.Stringify.valueAlloc(alloc, try client.prepare(try v.native(alloc)), .{}) },
        .next => |v| {
            const bundle = try q.Bundle.decode(alloc, try c.unhex(alloc, v.bundle, q.Bundle.max_bytes));
            const next = try client.prepareNext(try c.unsigned(v.namespace), bundle);
            return .{ .prepared = if (next) |value| try std.json.Stringify.valueAlloc(alloc, value, .{}) else null };
        },
        .submit => |v| return .{ .receipt = try client.submit(try prepared(alloc, v)) },
        .observe => |v| return .{ .observation = try client.observe(v) },
        .status => |v| return .{ .status = if (try client.status(try c.unsigned(v))) |value| try Status.fromNative(alloc, value) else null },
        .page => |v| {
            const previous = if (v.cursor) |bytes| try cursor(alloc, bytes) else null;
            const workspace = try alloc.alloc(u8, m.Arrow.working_bytes);
            const output = try alloc.alloc(u8, m.Arrow.segment_bytes);
            var decoded: m.Inspect.Batch = undefined;
            const result = try client.page(try c.unsigned(v.namespace), previous, alloc, workspace, output, &decoded);
            return .{ .page = .{ .manifest = try Manifest.fromNative(alloc, result.manifest), .columns = try c.foreignColumns(alloc, result.schema), .ordinal = try a.decimal(alloc, if (previous) |old| old.ordinal else 0), .rows = decoded.count, .ipc = try a.hex(alloc, result.arrow), .next = if (result.next) |value| try std.json.Stringify.valueAlloc(alloc, value, .{}) else null } };
        },
    }
}

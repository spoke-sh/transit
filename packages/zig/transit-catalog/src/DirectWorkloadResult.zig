//! Original workload rows for service composition. This is an in-process owner,
//! not a second wire result protocol or permission authority. Opening and paging
//! inspect accepted work; they never append, consume, claim, renew or settle it.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const s = c.storage;
const w = c.DirectTableProtocol;
const Intent = c.DirectWorkloadIntent;
const Self = @This();

pub const Limits = struct {
    rows: u32,
    encoded_bytes: u32,
    scanned_rows: u32,
    pub fn validate(self: Limits) !void {
        if (self.rows == 0 or self.rows > 128 or self.encoded_bytes == 0 or
            self.encoded_bytes > 1024 * 1024 or self.scanned_rows == 0 or self.scanned_rows > 65536)
            return error.InvalidWorkloadResultBudget;
    }
};

pub const Selection = p.LogWorkloadResult.Selection;

/// Full frozen schema and operation come from intent; selection binds the
/// owner's actual accepted offsets/read basis/claim, not a requested row count.
/// A reference establishes neither current rights nor continued retention.
pub const Reference = struct {
    intent: Intent.Reference,
    selection: Selection,
    limits: Limits,
    pub fn validate(self: Reference) !void {
        try self.intent.validate();
        try self.limits.validate();
        if (self.limits.rows > self.intent.source.declaration.limits.read_rows or
            self.limits.encoded_bytes > self.intent.source.declaration.limits.read_bytes) return error.InvalidWorkloadResultBudget;
        var bytes: [16 * 1024]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&bytes);
        try self.intent.binding.requireSame(try self.selection.binding(scratch.allocator()));
    }
    pub fn requireSame(self: Reference, other: Reference) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.WorkloadResultConflict;
    }
};

/// Request-local adapters to the existing native owners. The host retains their
/// locks and current policy through disclosure. Returned values belong to output.
pub const Native = struct {
    context: *anyopaque,
    stream: *const fn (*anyopaque, std.mem.Allocator, *c.DirectCatalog, c.DirectCatalog.Policy, c.DirectStream.Request) anyerror!c.DirectStream.Result,
    queue: *const fn (*anyopaque, std.mem.Allocator, *c.DirectCatalog, c.DirectCatalog.Policy, c.DirectQueue.Request) anyerror!c.DirectQueue.Result,
};

pub const AppendRow = struct { offset: u64, ordinal: u32, visible_ms: u64, tombstone: bool, encoded: w.Binary };
pub const AppendPage = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 128 };
    source: c.DirectLogProtocol.Definition,
    rows: []const AppendRow,
    next: u32,
    complete: bool,
    encoded_bytes: u32,
};
pub const RenewalPage = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 1 };
    source: c.DirectLogProtocol.Definition,
    rows: []const p.StreamQueue.Lease,
    next: u32,
};
pub const Page = union(enum) {
    append: AppendPage,
    consume: c.DirectStream.Page,
    claim: c.DirectQueue.Page,
    renewal: RenewalPage,
    pub fn deinit(self: Page, allocator: std.mem.Allocator) void {
        switch (self) {
            .append => |page| {
                allocator.free(page.source.schema.base64);
                for (page.rows) |row| allocator.free(row.encoded.base64);
                allocator.free(page.rows);
            },
            .consume => |page| (c.DirectStream.Result{ .page = page }).deinit(allocator),
            .claim => |page| (c.DirectQueue.Result{ .page = page }).deinit(allocator),
            .renewal => |page| {
                allocator.free(page.source.schema.base64);
                allocator.free(page.rows);
            },
        }
    }
};

/// Delivery position, separate from operation completion. Only the native
/// Stream owner can authenticate a supplied coverage cursor; shape validation
/// here cannot turn a caller-supplied position into settlement authority.
pub const Position = p.LogWorkloadResult.Position;

allocator: std.mem.Allocator,
intent: Intent,
reference: Reference,
payload: ?[]const u8,
cursor: union(enum) { append: s.LogBatch.Iterator, consume: p.StreamRead.Cursor, claim: p.QueueRead.Cursor, renewal: u32 },

/// Reopening starts a separate delivery at the original selection's beginning.
/// It does not splice a new selection into an incomplete previous delivery.
pub fn open(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, intent_reference: Intent.Reference, limits: Limits, policy: c.DirectCatalog.Policy, native: Native) !Self {
    return openInternal(allocator, catalog, intent_reference, limits, policy, native, null);
}

fn openInternal(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, intent_reference: Intent.Reference, limits: Limits, policy: c.DirectCatalog.Policy, native: Native, initial_position: ?Position) !Self {
    try limits.validate();
    var intent = try catalog.loadWorkloadIntent(allocator, intent_reference);
    errdefer intent.deinit();
    var scratch: std.heap.ArenaAllocator = .init(allocator);
    defer scratch.deinit();
    try authorize(scratch.allocator(), catalog, intent.parsed.value.work, policy);
    const selected = try observe(allocator, catalog, intent, policy, native);
    const accepted = switch (selected) {
        inline else => |value| value.accepted,
    };
    if (accepted.partition != try intent.parsed.value.source.declaration.partition(intent_reference.binding.target().partition)) return error.WorkloadResultConflict;
    const reference: Reference = .{ .intent = intent_reference, .selection = selected, .limits = limits };
    try reference.validate();
    var self: Self = .{ .allocator = allocator, .intent = intent, .reference = reference, .payload = null, .cursor = undefined };
    errdefer if (self.payload) |bytes| allocator.free(bytes);
    switch (selected) {
        .append => |receipt| {
            const binary = switch (intent.parsed.value.work) {
                inline else => |value| value.payload.?,
            };
            self.payload = try binary.decode(allocator, c.DirectRecord.max_bytes);
            var declared = try c.DirectLogProtocol.decodeMetadata(allocator, intent_reference.connection, intent.parsed.value.source);
            defer declared.deinit();
            self.cursor = .{ .append = try s.LogBatch.Iterator.init(self.payload.?, declared.definition.schema, if (receipt.append.kind == .stream) .stream else .queue, receipt.append.rows) };
        },
        .consume => |receipt| {
            if (initial_position) |at| {
                try at.validate(selected);
                self.cursor = .{ .consume = at.consume };
            } else {
                const request: c.DirectStream.Request = .{ .cursor = .{ .target = receipt.request.target, .read = receipt.handle() } };
                const result = try native.stream(native.context, allocator, catalog, policy, request);
                defer result.deinit(allocator);
                try c.DirectStreamResponse.validate(allocator, intent_reference.connection, request, result);
                if (result == .recovering) return error.ClientOperationPending;
                try result.cursor.requireReceipt(receipt);
                self.cursor = .{ .consume = result.cursor };
            }
        },
        .claim => |receipt| self.cursor = .{ .claim = .{ .receipt = receipt, .next = 0 } },
        .renewal => self.cursor = .{ .renewal = 0 },
    }
    if (initial_position) |at| if (selected != .consume) try self.seek(at);
    try authorize(scratch.allocator(), catalog, intent.parsed.value.work, policy);
    return self;
}

pub fn reopen(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, expected: Reference, policy: c.DirectCatalog.Policy, native: Native) !Self {
    try expected.validate();
    var self = try open(allocator, catalog, expected.intent, expected.limits, policy, native);
    errdefer self.deinit();
    try expected.requireSame(self.reference);
    return self;
}

pub fn reopenAt(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, expected: Reference, at: Position, policy: c.DirectCatalog.Policy, native: Native) !Self {
    try expected.validate();
    var self = try openInternal(allocator, catalog, expected.intent, expected.limits, policy, native, at);
    errdefer self.deinit();
    try expected.requireSame(self.reference);
    return self;
}

pub fn position(self: *const Self) Position {
    return switch (self.cursor) {
        .append => |iterator| .{ .append = iterator.ordinal },
        .consume => |cursor| .{ .consume = cursor },
        .claim => |cursor| .{ .claim = cursor },
        .renewal => |ordinal| .{ .renewal = ordinal },
    };
}

/// Select a position in the same original result. Append seeking is bounded by
/// the frozen 4-MiB workload; it never trusts an external byte offset. Native
/// pages still verify pin/selection retention and authenticated Stream coverage.
pub fn seek(self: *Self, at: Position) !void {
    try self.reference.validate();
    try at.validate(self.reference.selection);
    switch (at) {
        .append => |ordinal| {
            var iterator = self.cursor.append;
            iterator.ordinal = 0;
            iterator.at = s.LogBatch.header_bytes;
            while (iterator.ordinal < ordinal) _ = try iterator.next() orelse return error.WorkloadResultConflict;
            self.cursor = .{ .append = iterator };
        },
        .consume => |cursor| self.cursor = .{ .consume = cursor },
        .claim => |cursor| self.cursor = .{ .claim = cursor },
        .renewal => |ordinal| self.cursor = .{ .renewal = ordinal },
    }
}

/// Frees local delivery resources only. Explicit native read release remains a
/// separate durable operation; closing cannot release another reader's retained
/// selection, ACK a message or advance a consumer group.
pub fn deinit(self: *Self) void {
    if (self.payload) |bytes| self.allocator.free(bytes);
    self.intent.deinit();
    self.* = undefined;
}

/// Prepare a separate settlement without dispatching it. Save this exact work
/// before acceptance (for example in DirectWorkloadIntent). Only the native
/// owner can authenticate coverage, check current assignment/rights and commit.
/// SQL output counts and requested offsets cannot supply this handoff.
pub fn offsetWork(self: *const Self, operation: p.DataLifecycle.Operation) !p.LogWorkload.StreamRequest {
    if (self.reference.selection != .consume or self.cursor != .consume) return error.WorkloadResultUnavailable;
    const receipt = self.reference.selection.consume;
    const cursor = self.cursor.consume;
    try cursor.requireReceipt(receipt);
    if (!cursor.coverage.complete) return error.WorkloadResultIncomplete;
    return self.offsetProgressWork(operation, .{ .exhausted = cursor });
}

/// Settle only the traversed interval after an earlier issued boundary from
/// this same read. Both boundaries remain subject to native authentication.
pub fn offsetIntervalWork(self: *const Self, operation: p.DataLifecycle.Operation, first: p.StreamRead.Cursor) !p.LogWorkload.StreamRequest {
    if (self.reference.selection != .consume or self.cursor != .consume) return error.WorkloadResultUnavailable;
    return self.offsetProgressWork(operation, try p.StreamRead.Progress.between(first, self.cursor.consume));
}
fn offsetProgressWork(self: *const Self, operation: p.DataLifecycle.Operation, issued: p.StreamRead.Progress) !p.LogWorkload.StreamRequest {
    const receipt = self.reference.selection.consume;
    try issued.requireReceipt(receipt);
    const coverage = try issued.coverage();
    const group = receipt.request.group orelse return error.WorkloadResultGroupRequired;
    const request: p.LogWorkload.StreamRequest = .{ .offset = .{
        .commit = .{ .operation = operation, .group = group, .coverage = coverage, .expected_next = coverage.from, .next = coverage.until },
        .progress = issued,
    } };
    try request.validate();
    return request;
}

/// Recheck disclosure after copying metadata or before exposing a buffered page.
/// The host holds the same object/catalog locks as for native result calls.
pub fn checkDisclosure(self: *const Self, scratch: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy) !void {
    try authorize(scratch, catalog, self.intent.parsed.value.work, policy);
}

/// Every page (including repeated empty completion) checks original outcome and
/// current disclosure rights after buffering. Cursor advancement is transactional
/// with disclosure: failure leaves the local cursor unchanged. Output is owned
/// by the caller and must be distinct from scratch; neither allocator is retained.
/// Free a successful page with Page.deinit; failures free partial output.
pub fn next(self: *Self, scratch_arena: *std.heap.ArenaAllocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, native: Native) !Page {
    return self.nextRows(scratch_arena, output, catalog, policy, native, self.reference.limits.rows);
}

/// A caller may lower one page's row budget without changing the frozen result
/// identity. This bounds the traversal frontier for a logical LIMIT.
pub fn nextRows(self: *Self, scratch_arena: *std.heap.ArenaAllocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, native: Native, row_budget: u32) !Page {
    return self.nextRowsVerified(scratch_arena, output, catalog, policy, native, row_budget, false);
}

pub fn nextRowsVerified(self: *Self, scratch_arena: *std.heap.ArenaAllocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, native: Native, row_budget: u32, already_observed: bool) !Page {
    if (row_budget == 0 or row_budget > self.reference.limits.rows) return error.InvalidWorkloadResultBudget;
    const scratch = scratch_arena.allocator();
    if (scratch.ptr == output.ptr) return error.InvalidWorkloadResultBudget;
    if (!already_observed) {
        try authorize(scratch, catalog, self.intent.parsed.value.work, policy);
        if (!std.meta.eql(self.reference.selection, try observe(scratch, catalog, self.intent, policy, native))) return error.WorkloadResultConflict;
    }
    var limits = self.reference.limits;
    limits.rows = row_budget;
    var cursor = self.cursor;
    const result: Page = switch (cursor) {
        .renewal => |ordinal| blk: {
            const count: usize = if (ordinal == 0) 1 else 0;
            if (count != 0 and limits.encoded_bytes < p.QueueLeaseHandle.encoded_bytes) return error.WorkloadResultRowTooLarge;
            const rows = try output.alloc(p.StreamQueue.Lease, count);
            errdefer output.free(rows);
            if (count != 0) rows[0] = try p.LogWorkloadResult.renewedLease(self.reference.selection.renewal);
            var source = self.intent.parsed.value.source;
            source.schema.base64 = try output.dupe(u8, source.schema.base64);
            cursor = .{ .renewal = 1 };
            break :blk .{ .renewal = .{ .source = source, .rows = rows, .next = 1 } };
        },
        .append => |*iterator| blk: {
            var rows: [128]AppendRow = undefined;
            var length: usize = 0;
            errdefer for (rows[0..length]) |row| output.free(row.encoded.base64);
            var encoded_bytes: u32 = 0;
            while (length < limits.rows) {
                var advanced = iterator.*;
                const row = try advanced.next() orelse break;
                const bytes: u32 = @intCast(row.bytes.len + s.LogBatch.row_header_bytes);
                if (bytes > limits.encoded_bytes - encoded_bytes) {
                    if (length == 0) return error.WorkloadResultRowTooLarge;
                    break;
                }
                rows[length] = .{ .offset = self.reference.selection.append.first + row.ordinal, .ordinal = row.ordinal, .visible_ms = row.visible_ms, .tombstone = row.tombstone, .encoded = try w.Binary.encode(output, row.bytes) };
                length += 1;
                encoded_bytes += bytes;
                iterator.* = advanced;
            }
            const owned_rows = try output.dupe(AppendRow, rows[0..length]);
            errdefer output.free(owned_rows);
            var source = self.intent.parsed.value.source;
            source.schema.base64 = try output.dupe(u8, source.schema.base64);
            break :blk .{ .append = .{ .source = source, .rows = owned_rows, .next = iterator.ordinal, .complete = iterator.ordinal == iterator.count, .encoded_bytes = encoded_bytes } };
        },
        .consume => |prior| blk: {
            const request: c.DirectStream.Request = .{ .page = .{ .cursor = prior, .limits = .{ .rows = limits.rows, .encoded_bytes = limits.encoded_bytes, .scanned_rows = limits.scanned_rows } } };
            const value = try native.stream(native.context, output, catalog, policy, request);
            errdefer value.deinit(output);
            try c.DirectStreamResponse.validate(scratch, self.reference.intent.connection, request, value);
            if (value == .recovering) return error.ClientOperationPending;
            try value.page.cursor.requireReceipt(self.reference.selection.consume);
            cursor = .{ .consume = value.page.cursor };
            break :blk .{ .consume = value.page };
        },
        .claim => |prior| blk: {
            const request: c.DirectQueue.Request = .{ .page = .{ .cursor = prior, .limits = .{ .rows = limits.rows, .encoded_bytes = limits.encoded_bytes } } };
            const value = try native.queue(native.context, output, catalog, policy, request);
            errdefer value.deinit(output);
            try c.DirectQueueResponse.validate(scratch, self.reference.intent.connection, request, value);
            if (value == .recovering) return error.ClientOperationPending;
            try value.page.cursor.requireReceipt(self.reference.selection.claim);
            cursor = .{ .claim = value.page.cursor };
            break :blk .{ .claim = value.page };
        },
    };
    errdefer result.deinit(output);
    try authorize(scratch, catalog, self.intent.parsed.value.work, policy);
    self.cursor = cursor;
    return result;
}

fn authorize(scratch: std.mem.Allocator, catalog: *c.DirectCatalog, work: Intent.Work, policy: c.DirectCatalog.Policy) !void {
    if (work.identity().principal != policy.subject.principal()) return error.CatalogDenied;
    _ = try catalog.logAuthorization(scratch, if (work == .stream) .stream else .queue, work.target(), work.access(), policy);
    // Renewal discloses only the claimant's own accepted descriptor. It does
    // not read message payloads or acquire any additional permission.
    if (work == .queue and work.queue.work == .settle and work.queue.work.settle.action == .extend) return;
    _ = try catalog.logAuthorization(scratch, if (work == .stream) .stream else .queue, work.target(), .read, policy);
}

fn observe(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, intent: Intent, policy: c.DirectCatalog.Policy, native: Native) !Selection {
    const saved = intent.parsed.value;
    return switch (saved.work) {
        .stream => |work| blk: {
            const request: c.DirectStream.Request = .{ .operation = work.work };
            const result = try native.stream(native.context, allocator, catalog, policy, request);
            defer result.deinit(allocator);
            try c.DirectStreamResponse.validate(allocator, saved.connection, request, result);
            if (result == .recovering or result.operation == null) return error.ClientOperationPending;
            break :blk switch (result.operation.?) {
                .append => |value| .{ .append = value },
                .consume => |value| .{ .consume = value },
                .closed => error.WorkloadResultClosed,
                else => error.WorkloadResultUnavailable,
            };
        },
        .queue => |work| blk: {
            const request: c.DirectQueue.Request = .{ .operation = work.work };
            const result = try native.queue(native.context, allocator, catalog, policy, request);
            defer result.deinit(allocator);
            try c.DirectQueueResponse.validate(allocator, saved.connection, request, result);
            if (result == .recovering or result.operation == null) return error.ClientOperationPending;
            break :blk switch (result.operation.?) {
                .enqueue => |value| .{ .append = value },
                .claim => |value| .{ .claim = value },
                .settle => |value| if (value.settlement.action == .extend) .{ .renewal = value } else error.WorkloadResultUnavailable,
                .closed => error.WorkloadResultClosed,
                else => error.WorkloadResultUnavailable,
            };
        },
    };
}

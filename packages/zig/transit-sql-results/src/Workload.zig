//! Result attribution for an original native workload. Output cardinality and
//! native traversal coverage are separate. These values confer no permission,
//! retained read dependency or authority to acknowledge a Queue lease.
const std = @import("std");
const r = @import("root.zig");
const p = r.protocol;
const d = p.DataLifecycle;

/// Original native owner evidence, separate from result delivery. It can settle
/// an accepted operation while its returned rows remain undisclosed/incomplete.
pub const Evidence = struct {
    intent: d.Content,
    binding: p.LogWorkload.Binding,
    receipt: union(enum) {
        append: p.StreamQueue.AppendReceipt,
        consume: p.StreamRead.Receipt,
        claim: p.StreamQueue.ClaimReceipt,
        offset: struct { request: @FieldType(p.LogWorkload.StreamRequest, "offset"), receipt: p.StreamQueue.OffsetReceipt },
        settle: p.StreamQueue.SettlementReceipt,
        closed: p.LogWorkload.Closure,
    },
    pub fn validate(self: Evidence, command: r.Command) !void {
        try self.intent.validate();
        try self.binding.validate();
        if (!command.workload()) return error.InvalidWorkloadEvidence;
        const expected = switch (self.binding) {
            .stream => |value| switch (value.kind) {
                .append => command == .produce,
                .consume => command == .consume,
                .offset => command == .commit_offset,
                else => false,
            },
            .queue => |value| switch (value.kind) {
                .enqueue => command == .enqueue,
                .claim => command == .claim,
                .settle => command == .ack or command == .nack or command == .extend_lease,
                else => false,
            },
        };
        if (!expected) return error.InvalidWorkloadEvidence;
        var buffer: [16 * 1024]u8 = undefined;
        var scratch = std.heap.FixedBufferAllocator.init(&buffer);
        const binding: p.LogWorkload.Binding = switch (self.receipt) {
            .append => |value| try (p.LogWorkloadResult.Selection{ .append = value }).binding(scratch.allocator()),
            .consume => |value| try (p.LogWorkloadResult.Selection{ .consume = value }).binding(scratch.allocator()),
            .claim => |value| try (p.LogWorkloadResult.Selection{ .claim = value }).binding(scratch.allocator()),
            .offset => |value| blk: {
                try value.receipt.requireCommit(value.request.commit);
                break :blk .{ .stream = try (p.LogWorkload.StreamRequest{ .offset = value.request }).binding(scratch.allocator()) };
            },
            .settle => |value| blk: {
                try value.validate();
                const actual: r.Command = switch (value.settlement.action) {
                    .ack => .ack,
                    .nack => .nack,
                    .extend => .extend_lease,
                };
                if (command != actual) return error.InvalidWorkloadEvidence;
                break :blk .{ .queue = try (p.LogWorkload.QueueRequest{ .settle = value.settlement }).binding(scratch.allocator()) };
            },
            .closed => |value| blk: {
                try value.validate();
                break :blk value.binding;
            },
        };
        try self.binding.requireSame(binding);
    }
    pub fn outcome(self: Evidence) r.Outcome {
        return if (self.receipt == .closed) switch (self.receipt.closed.reason) {
            .cancelled => .cancelled,
            .refused => .rejected,
        } else .applied;
    }
    pub fn counts(self: Evidence, command: r.Command) ?r.Counts {
        if (command != .produce and command != .enqueue) return null;
        const rows: u64 = if (self.receipt == .append) self.receipt.append.append.rows else 0;
        return .{ .matched = rows, .changed = rows };
    }
    pub fn requireObservation(self: Evidence, observation: Observation) !void {
        try observation.validate();
        if (!std.meta.eql(self.intent, observation.intent)) return error.WorkloadResultConflict;
        const selected: p.LogWorkloadResult.Selection = switch (self.receipt) {
            .append => |value| .{ .append = value },
            .consume => |value| .{ .consume = value },
            .claim => |value| .{ .claim = value },
            else => return error.WorkloadResultUnavailable,
        };
        if (!std.meta.eql(selected, observation.selection)) return error.WorkloadResultConflict;
    }
};

pub const Observation = struct {
    intent: d.Content,
    schema: [32]u8,
    projection: [32]u8,
    selection: p.LogWorkloadResult.Selection,
    /// Frozen logical output limit; native coverage retains its original range.
    limit: ?u64,

    pub fn validate(self: Observation) !void {
        try self.intent.validate();
        try self.selection.validate();
        if (self.limit != null and self.selection != .consume) return error.InvalidWorkloadObservation;
        if (std.mem.allEqual(u8, &self.schema, 0) or std.mem.allEqual(u8, &self.projection, 0)) return error.InvalidWorkloadObservation;
    }
};

pub const Completion = struct {
    intent: d.Content,
    position: p.LogWorkloadResult.Position,

    pub fn validateShape(self: Completion) !void {
        try self.intent.validate();
        switch (self.position) {
            .append => {},
            inline .consume, .claim => |cursor| try cursor.validate(),
        }
    }
    pub fn validate(self: Completion, observation: Observation, rows: u64) !void {
        try self.validateShape();
        try observation.validate();
        if (!std.meta.eql(self.intent, observation.intent)) return error.WorkloadResultConflict;
        const exhausted = try self.position.complete(observation.selection);
        if (observation.limit) |limit| {
            if (rows > limit) return error.InvalidWorkloadResultCount;
            if (!exhausted and rows != limit) return error.IncompleteWorkloadCoverage;
        } else if (!exhausted) return error.IncompleteWorkloadCoverage;
        switch (self.position) {
            .append => |ordinal| if (rows != ordinal) return error.InvalidWorkloadResultCount,
            .claim => |cursor| if (rows != cursor.next) return error.InvalidWorkloadResultCount,
            // A Stream predicate may remove rows; gaps and timestamp filtering
            // also leave native coverage distinct from the offset interval.
            .consume => |cursor| if (rows > cursor.coverage.rows) return error.InvalidWorkloadResultCount,
        }
    }
};

test "settlement evidence binds the action and authenticated offset request" {
    const t = std.testing;
    const scope: d.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
    const target: p.StreamQueue.Partition = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(5) }, .partition = 0 };
    const operation: d.Operation = .{ .scope = scope, .principal = 6, .operation = 7 };
    const lease: p.StreamQueue.Lease = .{ .target = target, .claim = operation, .offset = 10, .epoch = 2, .attempt = 3, .expires_ms = 1000 };
    const settlement: p.StreamQueue.Settlement = .{ .operation = .{ .scope = scope, .principal = 6, .operation = 8 }, .lease = lease, .action = .{ .extend = .{ .expires_ms = 2000 } } };
    const content: d.Content = .{ .sha256 = @splat(9), .bytes = 100 };
    var evidence: Evidence = .{ .intent = content, .binding = .{ .queue = try (p.LogWorkload.QueueRequest{ .settle = settlement }).binding(t.allocator) }, .receipt = .{ .settle = .{ .settlement = settlement, .accepted = .{ .partition = 11, .next_lsn = 12 } } } };
    try evidence.validate(.extend_lease);
    try t.expectEqual(null, evidence.counts(.extend_lease));
    try t.expectError(error.InvalidWorkloadEvidence, evidence.validate(.ack));
    evidence.receipt.settle.settlement.lease.epoch += 1;
    try t.expectError(error.DataIdentityConflict, evidence.validate(.extend_lease));

    const cut: p.StreamQueue.Cut = .{ .target = target, .accepted = .{ .partition = 11, .next_lsn = 10 }, .retained_from = 0, .next = 100 };
    const coverage: p.StreamQueue.Coverage = .{ .cut = cut, .from = 0, .until = 100, .through = 100, .rows = 2, .complete = true };
    const cursor: p.StreamRead.Cursor = .{ .read = .{ .owner = operation, .source = content }, .coverage = coverage, .authentication = @splat(13) };
    const request: @FieldType(p.LogWorkload.StreamRequest, "offset") = .{ .commit = .{ .operation = settlement.operation, .group = .{ .id = 1, .generation = 2, .principal = 6 }, .coverage = coverage, .expected_next = 0, .next = 100 }, .progress = .{ .exhausted = cursor } };
    evidence = .{ .intent = content, .binding = .{ .stream = try (p.LogWorkload.StreamRequest{ .offset = request }).binding(t.allocator) }, .receipt = .{ .offset = .{ .request = request, .receipt = .{ .commit = request.commit, .accepted = .{ .partition = 11, .next_lsn = 12 } } } } };
    try evidence.validate(.commit_offset);
    evidence.receipt.offset.request.progress.exhausted.authentication[0] ^= 1;
    try t.expectError(error.DataIdentityConflict, evidence.validate(.commit_offset));
    evidence.receipt.offset.request = request;
    evidence.receipt.offset.receipt.commit.group.generation += 1;
    try t.expectError(error.LogOffsetConflict, evidence.validate(.commit_offset));
}

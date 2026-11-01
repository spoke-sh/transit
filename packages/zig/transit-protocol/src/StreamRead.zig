//! Finite retained Stream reads and authenticated traversal attribution. Shape
//! validation grants no pin, current authority, or truth to a supplied cursor.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const q = p.StreamQueue;

pub const TimestampRange = struct {
    from_us: i64,
    until_us: i64,
    pub fn validate(self: TimestampRange) !void {
        if (self.until_us < self.from_us) return error.InvalidStreamTimestampRange;
    }
    pub fn matches(self: TimestampRange, value_us: i64) bool {
        return value_us >= self.from_us and value_us < self.until_us;
    }
};

pub const Request = struct {
    target: q.Partition,
    operation: d.Operation,
    group: ?q.Group,
    from: u64,
    /// Null chooses the observed upper frontier once, at original acceptance.
    until: ?u64,
    timestamp: ?TimestampRange,
    pub fn validate(self: Request) !void {
        try self.target.requireOperation(self.operation);
        if (self.until) |until| if (until < self.from) return error.InvalidStreamRead;
        if (self.timestamp) |range| try range.validate();
        if (self.group) |group| {
            try group.validate();
            if (group.principal != self.operation.principal) return error.LogGroupFenced;
        }
    }
    pub fn requireSame(self: Request, other: Request) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.StreamReadConflict;
    }
};
pub const Handle = struct {
    owner: d.Operation,
    source: d.Content,
    pub fn validate(self: Handle) !void {
        try self.owner.validate();
        try self.source.validate();
    }
};
pub const Receipt = struct {
    request: Request,
    cut: q.Cut,
    until: u64,
    source: d.Content,
    accepted: d.Position,
    pub fn validate(self: Receipt) !void {
        try self.request.validate();
        try self.request.target.requireSame(self.cut.target);
        try self.cut.requireOffset(self.request.from);
        try self.cut.requireOffset(self.until);
        try self.source.validate();
        try self.accepted.validate();
        const next_lsn = std.math.add(u64, self.cut.accepted.next_lsn, 1) catch return error.InvalidStreamRead;
        if (self.cut.accepted.next_lsn == 0 or self.accepted.partition != self.cut.accepted.partition or
            self.accepted.next_lsn != next_lsn or
            self.until != (self.request.until orelse self.cut.next) or self.until < self.request.from) return error.InvalidStreamRead;
    }
    pub fn handle(self: Receipt) Handle {
        return .{ .owner = self.request.operation, .source = self.source };
    }
    pub fn initialCoverage(self: Receipt) !q.Coverage {
        try self.validate();
        return .{ .cut = self.cut, .from = self.request.from, .until = self.until, .through = self.request.from, .rows = 0, .complete = self.request.from == self.until };
    }
    pub fn requireRequest(self: Receipt, request: Request) !void {
        try self.validate();
        try self.request.requireSame(request);
    }
};

/// The storage owner authenticates this body under its private read authority.
/// Possession never replaces current read/settlement rights or a live pin.
pub const Cursor = struct {
    read: Handle,
    coverage: q.Coverage,
    authentication: [32]u8,
    pub fn validate(self: Cursor) !void {
        try self.read.validate();
        try self.coverage.validate();
        try self.coverage.cut.target.requireOperation(self.read.owner);
        if (std.mem.allEqual(u8, &self.authentication, 0)) return error.InvalidStreamCursor;
    }
    pub fn requireReceipt(self: Cursor, receipt: Receipt) !void {
        try self.validate();
        try receipt.validate();
        if (!std.meta.eql(self.read, receipt.handle()) or !std.meta.eql(self.coverage.cut, receipt.cut) or
            self.coverage.from != receipt.request.from or self.coverage.until != receipt.until) return error.StreamReadConflict;
    }
};

/// Complete traversal of the original read, or one verified interval between
/// its cumulative cursors. Shape validation authenticates neither boundary.
/// The native owner must verify every cursor, its live pin and current group.
pub const Progress = union(enum) {
    exhausted: Cursor,
    interval: struct { first: Cursor, last: Cursor },

    fn intervalCoverage(first: Cursor, last: Cursor) !q.Coverage {
        try first.validate();
        try last.validate();
        if (!std.meta.eql(first.read, last.read) or
            !std.meta.eql(first.coverage.cut, last.coverage.cut) or
            first.coverage.from != last.coverage.from or first.coverage.until != last.coverage.until or
            first.coverage.through > last.coverage.through or first.coverage.rows > last.coverage.rows)
            return error.InvalidStreamProgress;
        const result: q.Coverage = .{
            .cut = last.coverage.cut,
            .from = first.coverage.through,
            .until = last.coverage.through,
            .through = last.coverage.through,
            .rows = last.coverage.rows - first.coverage.rows,
            .complete = true,
        };
        try result.validate();
        return result;
    }
    /// Choose one canonical representation; an interval spanning the entire
    /// exhausted read uses the existing final cursor alone.
    pub fn between(first: Cursor, last: Cursor) !Progress {
        const selected = try intervalCoverage(first, last);
        return if (last.coverage.complete and selected.from == last.coverage.from)
            .{ .exhausted = last }
        else
            .{ .interval = .{ .first = first, .last = last } };
    }
    pub fn end(self: Progress) Cursor {
        return switch (self) {
            .exhausted => |cursor| cursor,
            .interval => |value| value.last,
        };
    }
    /// The interval has its own complete coverage; neither cursor is modified
    /// or relabeled as exhaustion of the larger original read.
    pub fn coverage(self: Progress) !q.Coverage {
        return switch (self) {
            .exhausted => |cursor| blk: {
                try cursor.validate();
                if (!cursor.coverage.complete) return error.InvalidStreamProgress;
                break :blk cursor.coverage;
            },
            .interval => |value| blk: {
                const selected = try intervalCoverage(value.first, value.last);
                if (value.last.coverage.complete and selected.from == value.last.coverage.from) return error.InvalidStreamProgress;
                break :blk selected;
            },
        };
    }
    pub fn validate(self: Progress) !void {
        _ = try self.coverage();
    }
    pub fn requireReceipt(self: Progress, receipt: Receipt) !void {
        try self.validate();
        try self.end().requireReceipt(receipt);
        if (self == .interval) try self.interval.first.requireReceipt(receipt);
    }
};

pub const Release = struct {
    target: q.Partition,
    operation: d.Operation,
    read: Handle,
    pub fn validate(self: Release) !void {
        try self.target.requireOperation(self.operation);
        try self.target.requireOperation(self.read.owner);
        try self.read.validate();
        if (self.operation.principal != self.read.owner.principal or std.meta.eql(self.operation, self.read.owner)) return error.InvalidStreamRelease;
    }
};
pub const ReleaseReceipt = struct {
    release: Release,
    accepted: d.Position,
    pub fn validate(self: ReleaseReceipt) !void {
        try self.release.validate();
        try self.accepted.validate();
        if (self.accepted.next_lsn == 0) return error.InvalidStreamRelease;
    }
    pub fn requireRelease(self: ReleaseReceipt, release: Release) !void {
        try self.validate();
        try release.validate();
        if (!std.meta.eql(self.release, release)) return error.StreamReadConflict;
    }
};

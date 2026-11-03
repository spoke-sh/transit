//! Retained membership of one Document partition. Independent partition cuts
//! are a vector, not an atomic collection snapshot or transaction acquisition.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;

pub const max_page_heads = 16;

pub const Cut = struct {
    target: doc.Partition,
    observed: d.Position,
    /// Position immediately after the last logical-head change, or genesis (1).
    changed_next_lsn: u64,
    /// Null is the accepted empty directory, never missing storage.
    heads_digest: ?[32]u8,

    pub fn validate(self: Cut) !void {
        try self.target.validate();
        try self.observed.validate();
        if (self.changed_next_lsn == 0 or self.changed_next_lsn > self.observed.next_lsn)
            return error.InvalidDocumentCollection;
        if (self.heads_digest) |digest| {
            if (std.mem.allEqual(u8, &digest, 0) or self.changed_next_lsn <= 1)
                return error.InvalidDocumentCollection;
        }
    }
};

pub const Request = struct {
    target: doc.Partition,
    operation: d.Operation,
    max_steps: u32,
    max_bytes: u32,
    page_heads: u8,
    page_bytes: u32,

    pub fn validate(self: Request) !void {
        try self.target.requireOperation(self.operation);
        if (self.max_steps == 0 or self.max_bytes == 0 or self.page_heads == 0 or
            self.page_heads > max_page_heads or self.page_bytes == 0 or self.page_bytes > self.max_bytes)
            return error.InvalidDocumentCollection;
    }

    pub fn requireSame(self: Request, other: Request) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentReadConflict;
    }
};

pub const Receipt = struct {
    request: Request,
    cut: Cut,
    source: d.Content,
    accepted: d.Position,

    pub fn validate(self: Receipt) !void {
        try self.request.validate();
        try self.cut.validate();
        try self.request.target.requireSame(self.cut.target);
        try self.source.validate();
        try self.accepted.validate();
        const next = std.math.add(u64, self.cut.observed.next_lsn, 1) catch return error.InvalidDocumentCollection;
        if (self.accepted.partition != self.cut.observed.partition or self.accepted.next_lsn != next)
            return error.InvalidDocumentCollection;
    }

    pub fn handle(self: Receipt) doc.Read.Handle {
        return .{ .owner = self.request.operation, .source = self.source };
    }

    pub fn requireRequest(self: Receipt, request: Request) !void {
        try self.validate();
        try self.request.requireSame(request);
    }
};

pub const Coverage = struct {
    after: ?[16]u8,
    heads: u64,
    steps: u32,
    bytes: u32,
    complete: bool,

    pub fn validate(self: Coverage) !void {
        if ((self.after != null) != (self.heads != 0)) return error.InvalidDocumentCoverage;
        if (self.after) |id| if (std.mem.allEqual(u8, &id, 0)) return error.InvalidDocumentCoverage;
        if ((self.heads == 0) != (self.bytes == 0)) return error.InvalidDocumentCoverage;
        if (self.steps == 0 and (self.heads != 0 or self.complete)) return error.InvalidDocumentCoverage;
    }
};

pub const Cursor = struct {
    read: doc.Read.Handle,
    coverage: Coverage,
    authentication: [32]u8,

    pub fn validate(self: Cursor) !void {
        try self.read.validate();
        try self.coverage.validate();
        if (std.mem.allEqual(u8, &self.authentication, 0)) return error.InvalidDocumentCursor;
    }
};

pub const Head = struct {
    cut: doc.Cut,
    unresolved_conflicts: u16,
};

pub const Page = struct {
    heads: [max_page_heads]?Head,
    count: u8,
    cursor: Cursor,

    pub fn validate(self: Page) !void {
        try self.cursor.validate();
        if (self.count > max_page_heads or self.count > self.cursor.coverage.heads)
            return error.InvalidDocumentCollection;
        var previous: ?[16]u8 = null;
        for (self.heads, 0..) |slot, i| {
            if (i >= self.count) {
                if (slot != null) return error.InvalidDocumentCollection;
                continue;
            }
            const head = slot orelse return error.InvalidDocumentCollection;
            try head.cut.validate();
            if (previous) |id| {
                if (std.mem.order(u8, &id, &head.cut.target.document) != .lt)
                    return error.InvalidDocumentCollection;
            }
            previous = head.cut.target.document;
        }
        if (previous) |id| {
            if (!std.meta.eql(self.cursor.coverage.after, @as(?[16]u8, id)))
                return error.InvalidDocumentCollection;
        } else if (!self.cursor.coverage.complete) return error.InvalidDocumentCollection;
    }
};

pub const Release = struct {
    target: doc.Partition,
    operation: d.Operation,
    read: doc.Read.Handle,

    pub fn validate(self: Release) !void {
        try self.target.requireOperation(self.operation);
        try self.target.requireOperation(self.read.owner);
        try self.read.validate();
        if (self.operation.principal != self.read.owner.principal or std.meta.eql(self.operation, self.read.owner))
            return error.InvalidDocumentRelease;
    }
};

pub const ReleaseReceipt = struct {
    release: Release,
    accepted: d.Position,

    pub fn validate(self: ReleaseReceipt) !void {
        try self.release.validate();
        try self.accepted.validate();
        if (self.accepted.next_lsn == 0) return error.InvalidDocumentRelease;
    }

    pub fn requireRelease(self: ReleaseReceipt, release: Release) !void {
        try self.validate();
        try release.validate();
        if (!std.meta.eql(self.release, release)) return error.DocumentReadConflict;
    }
};

pub const SchemaTypes = struct {
    receipt: Receipt,
    cursor: Cursor,
    page: Page,
    release: ReleaseReceipt,
};

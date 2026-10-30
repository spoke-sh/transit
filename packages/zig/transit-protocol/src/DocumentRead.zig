//! Finite retained Document revision read pins, authenticated traversal cursors,
//! and explicit pin releases.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const doc = @import("DocumentOperation.zig");

pub const Request = struct {
    target: doc.Target,
    operation: d.Operation,
    from_revision: u64,
    through_revision: ?u64,
    max_steps: u32,
    max_bytes: u32,

    pub fn validate(self: Request) !void {
        try self.target.requireOperation(self.operation);
        if (self.from_revision == 0 or self.max_steps == 0 or self.max_bytes == 0) {
            return error.InvalidDocumentRead;
        }
        if (self.through_revision) |through| {
            if (through < self.from_revision) return error.InvalidDocumentRead;
        }
    }

    pub fn requireSame(self: Request, other: Request) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentReadConflict;
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

pub const Coverage = struct {
    cut: doc.Cut,
    from_revision: u64,
    through_revision: u64,
    next_revision: u64,
    steps: u32,
    bytes: u32,
    complete: bool,

    pub fn validate(self: Coverage) !void {
        try self.cut.requireRevision(self.from_revision);
        try self.cut.requireRevision(self.through_revision);
        if (self.through_revision < self.from_revision) {
            return error.InvalidDocumentCoverage;
        }
        const terminal = std.math.add(u64, self.through_revision, 1) catch return error.InvalidDocumentCoverage;
        if (self.next_revision < self.from_revision or self.next_revision > terminal) {
            return error.InvalidDocumentCoverage;
        }
        if (self.complete != (self.next_revision == terminal)) {
            return error.InvalidDocumentCoverage;
        }
    }
};

pub const Receipt = struct {
    request: Request,
    cut: doc.Cut,
    through_revision: u64,
    source: d.Content,
    accepted: d.Position,

    pub fn validate(self: Receipt) !void {
        try self.request.validate();
        try self.request.target.requireSame(self.cut.target);
        try self.cut.requireRevision(self.request.from_revision);
        try self.cut.requireRevision(self.through_revision);
        try self.source.validate();
        try self.accepted.validate();
        const next_lsn = std.math.add(u64, self.cut.accepted.next_lsn, 1) catch return error.InvalidDocumentRead;
        if (self.cut.accepted.next_lsn == 0 or
            self.accepted.partition != self.cut.accepted.partition or
            self.accepted.next_lsn != next_lsn or
            self.through_revision != (self.request.through_revision orelse self.cut.accepted_revision) or
            self.through_revision < self.request.from_revision)
        {
            return error.InvalidDocumentRead;
        }
    }

    pub fn handle(self: Receipt) Handle {
        return .{ .owner = self.request.operation, .source = self.source };
    }

    pub fn initialCoverage(self: Receipt) !Coverage {
        try self.validate();
        return .{
            .cut = self.cut,
            .from_revision = self.request.from_revision,
            .through_revision = self.through_revision,
            .next_revision = self.request.from_revision,
            .steps = 0,
            .bytes = 0,
            .complete = false,
        };
    }

    pub fn requireRequest(self: Receipt, request: Request) !void {
        try self.validate();
        try self.request.requireSame(request);
    }
};

pub const Cursor = struct {
    read: Handle,
    coverage: Coverage,
    authentication: [32]u8,

    pub fn validate(self: Cursor) !void {
        try self.read.validate();
        try self.coverage.validate();
        try self.coverage.cut.target.requireOperation(self.read.owner);
        if (std.mem.allEqual(u8, &self.authentication, 0)) return error.InvalidDocumentCursor;
    }

    pub fn requireReceipt(self: Cursor, receipt: Receipt) !void {
        try self.validate();
        try receipt.validate();
        if (!std.meta.eql(self.read, receipt.handle()) or
            !std.meta.eql(self.coverage.cut, receipt.cut) or
            self.coverage.from_revision != receipt.request.from_revision or
            self.coverage.through_revision != receipt.through_revision)
        {
            return error.DocumentReadConflict;
        }
    }
};

pub const Release = struct {
    target: doc.Target,
    operation: d.Operation,
    read: Handle,

    pub fn validate(self: Release) !void {
        try self.target.requireOperation(self.operation);
        try self.target.requireOperation(self.read.owner);
        try self.read.validate();
        if (self.operation.principal != self.read.owner.principal or
            std.meta.eql(self.operation, self.read.owner))
        {
            return error.InvalidDocumentRelease;
        }
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

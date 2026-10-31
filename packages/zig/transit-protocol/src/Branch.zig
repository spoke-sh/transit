//! Immutable branch/candidate attribution. Validation proves shape and binding,
//! never pin acquisition, current authorization, candidate validity or acceptance.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const Identity = struct {
    scope: d.Scope,
    branch: u64,

    pub fn validate(self: Identity) !void {
        try self.scope.validate();
        if (self.branch == 0) return error.InvalidBranchIdentity;
    }

    pub fn requireScope(self: Identity, scope: d.Scope) !void {
        try self.validate();
        try scope.validate();
        if (!std.meta.eql(self.scope, scope)) return error.BranchIdentityConflict;
    }
};

/// An immutable manifest reference; versions order one branch, not all logs.
pub const Reference = struct {
    identity: Identity,
    version: u64,
    content: d.Content,

    pub fn validate(self: Reference) !void {
        try self.identity.validate();
        try self.content.validate();
        if (self.version == 0 or std.mem.allEqual(u8, &self.content.sha256, 0)) return error.InvalidBranchReference;
    }
};

pub const Mode = enum { full_data, schema_only };
pub const Kind = enum { genesis, fork, commit, merge, restore };

/// Paged immutable catalog/data closure. Count is durable cardinality, never a
/// resident array capacity. Even an empty closure has a content commitment.
pub const Directory = struct {
    content: d.Content,
    objects: u64,

    pub fn validate(self: Directory) !void {
        try self.content.validate();
        if (std.mem.allEqual(u8, &self.content.sha256, 0)) return error.InvalidBranchDirectory;
    }
};

/// A complete logical publication proposal. The owner must verify the closure,
/// retain every data/WAL dependency and acquire one supported atomic cut.
/// Security, operation receipts and execution control are never in this closure.
pub const Manifest = struct {
    definition: p.Growth.Definition,
    identity: Identity,
    version: u64,
    kind: Kind,
    mode: Mode,
    catalog: d.Position,
    objects: Directory,
    retention_owner: d.Operation,
    parent: ?Reference,
    merge_parent: ?Reference,
    restored_from: ?Reference,

    pub fn validate(self: Manifest) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
        try self.catalog.validate();
        try self.objects.validate();
        try self.retention_owner.validate();
        try self.identity.requireScope(self.retention_owner.scope);
        if (self.version == 0 or self.catalog.next_lsn == 0) return error.InvalidBranchManifest;
        inline for (.{ self.parent, self.merge_parent, self.restored_from }) |maybe| if (maybe) |reference| {
            try reference.validate();
            try self.identity.requireScope(reference.identity.scope);
            if (std.meta.eql(reference.identity, self.identity) and reference.version >= self.version) return error.InvalidBranchAncestry;
        };
        if ((self.kind == .merge) != (self.merge_parent != null) or
            (self.kind == .restore) != (self.restored_from != null)) return error.InvalidBranchAncestry;
        switch (self.kind) {
            .genesis => if (self.version != 1 or self.parent != null) return error.InvalidBranchAncestry,
            .fork => {
                const source = self.parent orelse return error.InvalidBranchAncestry;
                if (self.version != 1 or std.meta.eql(source.identity, self.identity)) return error.InvalidBranchAncestry;
            },
            .commit, .merge, .restore => {
                const previous = self.parent orelse return error.InvalidBranchAncestry;
                if (!std.meta.eql(previous.identity, self.identity) or self.version <= 1 or previous.version != self.version - 1) return error.InvalidBranchAncestry;
            },
        }
        if (self.merge_parent) |source| if (std.meta.eql(source.identity, self.identity)) return error.InvalidBranchAncestry;
    }
};

/// Generation also changes on rename/policy/retirement. A data version alone
/// cannot protect publication from a changed destination or reused name.
pub const Head = struct {
    reference: Reference,
    generation: u64,

    pub fn validate(self: Head) !void {
        try self.reference.validate();
        if (self.generation == 0) return error.InvalidBranchHead;
    }

    pub fn requireSame(self: Head, other: Head) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.StaleBranchHead;
    }
};

pub const Limits = struct {
    resident_bytes: u64,
    staged_bytes: u64,
    objects: u64,
    work: u64,

    pub fn validate(self: Limits) !void {
        if (self.resident_bytes == 0 or self.staged_bytes == 0 or self.objects == 0 or self.work == 0) return error.InvalidBranchLimits;
    }
};

/// Selected and retained once. An ambiguous LCA must be rejected by the owner;
/// equal scope/version fields alone cannot prove that base is an ancestor.
pub const MergeBasis = struct {
    base: Reference,
    source: Reference,
    target: Head,

    pub fn validate(self: MergeBasis) !void {
        try self.base.validate();
        try self.source.validate();
        try self.target.validate();
        try self.target.reference.identity.requireScope(self.base.identity.scope);
        try self.target.reference.identity.requireScope(self.source.identity.scope);
        if (std.meta.eql(self.source.identity, self.target.reference.identity)) return error.InvalidBranchMerge;
        if (std.meta.eql(self.base.identity, self.source.identity) and self.base.version > self.source.version) return error.InvalidBranchAncestry;
        if (std.meta.eql(self.base.identity, self.target.reference.identity) and self.base.version > self.target.reference.version) return error.InvalidBranchAncestry;
    }
};

pub const Intent = union(enum) {
    create: struct { target: Identity, source: Reference, mode: Mode },
    merge: MergeBasis,
    restore: struct { target: Head, source: Reference },
    drop: Head,

    pub fn target(self: Intent) Identity {
        return switch (self) {
            .create => |value| value.target,
            .merge => |value| value.target.reference.identity,
            .restore => |value| value.target.reference.identity,
            .drop => |value| value.reference.identity,
        };
    }

    pub fn validate(self: Intent) !void {
        try self.target().validate();
        switch (self) {
            .create => |value| {
                try value.source.validate();
                try value.target.requireScope(value.source.identity.scope);
                if (std.meta.eql(value.target, value.source.identity)) return error.InvalidBranchCreation;
            },
            .merge => |value| try value.validate(),
            .restore => |value| {
                try value.target.validate();
                try value.source.validate();
                try value.target.reference.identity.requireScope(value.source.identity.scope);
            },
            .drop => |value| try value.validate(),
        }
    }
};

/// Names, resolutions and options are committed by request; accepted operations
/// keep the original identity, exact source references and expected target.
pub const Attempt = struct {
    definition: p.Growth.Definition,
    operation: d.Operation,
    request: [32]u8,
    intent: Intent,
    limits: Limits,

    pub fn validate(self: Attempt) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.operation.validate();
        try self.intent.validate();
        try self.limits.validate();
        try self.intent.target().requireScope(self.operation.scope);
        if (std.mem.allEqual(u8, &self.request, 0)) return error.InvalidBranchAttempt;
    }

    pub fn requireSame(self: Attempt, other: Attempt) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.BranchIdentityConflict;
    }
};

/// Counts describe a complete verification only when complete=true. A preview,
/// budget stop or failed read cannot manufacture an empty conflict set.
pub const Validation = struct {
    attempt: Attempt,
    candidate: d.Content,
    checked_objects: u64,
    conflicts: u64,
    complete: bool,

    pub fn validate(self: Validation) !void {
        try self.attempt.validate();
        try self.candidate.validate();
        if (std.mem.allEqual(u8, &self.candidate.sha256, 0) or self.checked_objects > self.attempt.limits.objects) return error.InvalidBranchValidation;
    }

    pub fn requirePublishable(self: Validation, candidate: d.Content, object_count: u64) !void {
        try self.validate();
        if (!std.meta.eql(candidate, self.candidate)) return error.BranchIdentityConflict;
        if (!self.complete or self.checked_objects != object_count) return error.IncompleteBranchValidation;
        if (self.conflicts != 0) return error.UnresolvedBranchConflicts;
    }
};

/// Shape validation is not a durable acceptance proof. The publishing owner
/// binds this result to its WAL record under current writer and policy fences.
pub const Decision = struct {
    attempt: Attempt,
    position: d.Position,
    writer_epoch: u64,
    policy_epoch: u64,
    outcome: union(enum) { published: Head, dropped, rejected, cancelled },

    pub fn validate(self: Decision) !void {
        try self.attempt.validate();
        try self.position.validate();
        if (self.position.next_lsn == 0 or self.writer_epoch == 0 or self.policy_epoch == 0) return error.InvalidBranchDecision;
        switch (self.outcome) {
            .published => |head| {
                try head.validate();
                if (!std.meta.eql(head.reference.identity, self.attempt.intent.target())) return error.BranchIdentityConflict;
                switch (self.attempt.intent) {
                    .create => if (head.reference.version != 1 or head.generation != 1) return error.InvalidBranchDecision,
                    .merge => |basis| try successor(basis.target, head),
                    .restore => |basis| try successor(basis.target, head),
                    .drop => return error.InvalidBranchDecision,
                }
            },
            .dropped => if (self.attempt.intent != .drop) return error.InvalidBranchDecision,
            .rejected, .cancelled => {},
        }
    }
};

fn successor(previous: Head, next: Head) !void {
    if (next.reference.version != try std.math.add(u64, previous.reference.version, 1) or
        next.generation != try std.math.add(u64, previous.generation, 1)) return error.InvalidBranchDecision;
}

pub const SchemaTypes = struct {
    manifest: Manifest,
    head: Head,
    attempt: Attempt,
    validation: Validation,
    decision: Decision,
};

test {
    _ = @import("branch_test.zig");
}

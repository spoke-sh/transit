//! Direct Document partition targets, causal and versioned lineage, mutation
//! receipts, replica deduplication floors, snapshot cuts, and checkpoints.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;
const decl = @import("DocumentDeclaration.zig");
pub const Read = @import("DocumentRead.zig");
pub const fixture_json = @embedFile("fixtures/document-v1.json");

pub const Profile = decl.Profile;
pub const Collation = decl.Collation;
pub const Partitioning = decl.Partitioning;
pub const Shredding = decl.Shredding;
pub const Retention = decl.Retention;
pub const Configuration = decl.Configuration;
pub const Limits = decl.Limits;
pub const Declaration = decl.Declaration;

pub const Partition = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    partition: u32,

    pub fn validate(self: Partition) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        if (self.interpretation.object.branch != 1) return error.UnsupportedTransactionDomain;
    }

    pub fn requireSame(self: Partition, other: Partition) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentPartitionConflict;
    }

    pub fn requireOperation(self: Partition, operation: d.Operation) !void {
        try self.validate();
        try operation.validate();
        if (!std.meta.eql(self.interpretation.object.scope, operation.scope)) {
            return error.DocumentPartitionConflict;
        }
    }
};

pub const Target = struct {
    partition: Partition,
    document: [16]u8,

    pub fn validate(self: Target) !void {
        try self.partition.validate();
        if (std.mem.allEqual(u8, &self.document, 0)) return error.InvalidDocumentTarget;
    }

    pub fn requireSame(self: Target, other: Target) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentTargetConflict;
    }

    pub fn requireOperation(self: Target, operation: d.Operation) !void {
        try self.validate();
        try self.partition.requireOperation(operation);
    }

    pub fn sameDocument(self: Target, other: Target) bool {
        return self.partition.partition == other.partition.partition and
            std.meta.eql(self.partition.interpretation.object, other.partition.interpretation.object) and
            std.mem.eql(u8, &self.document, &other.document);
    }
};

pub const RawSpan = struct {
    part_id: u32,
    byte_start: u32,
    byte_end: u32,

    pub fn validate(self: RawSpan) !void {
        if (self.part_id == 0 or self.byte_end < self.byte_start) {
            return error.InvalidDocumentRawSpan;
        }
    }
};

pub const Replica = struct {
    id: [16]u8,
    epoch: u64,
    sequence: u64,
    preceding_sequence: u64,

    pub fn validate(self: Replica) !void {
        if (std.mem.allEqual(u8, &self.id, 0) or self.epoch == 0 or self.sequence == 0) {
            return error.InvalidDocumentReplica;
        }
        if (self.preceding_sequence == std.math.maxInt(u64) or
            self.preceding_sequence + 1 != self.sequence)
        {
            return error.InvalidDocumentReplica;
        }
    }
};

pub const Lineage = struct {
    profile: Profile,
    merge_epoch: u64,
    base_revision: u64,
    parent_revision: ?u64,
    replica: ?Replica,
    raw_span: ?RawSpan,

    pub fn validate(self: Lineage) !void {
        if (self.merge_epoch == 0) return error.InvalidDocumentLineage;
        switch (self.profile) {
            .causal_crdt => {
                if (self.parent_revision != null) return error.InvalidDocumentLineage;
                const rep = self.replica orelse return error.InvalidDocumentLineage;
                try rep.validate();
                if (rep.epoch != self.merge_epoch) return error.InvalidDocumentLineage;
            },
            .versioned => {
                if (self.parent_revision) |parent| {
                    if (self.base_revision == 0 or parent == 0 or parent == self.base_revision) {
                        return error.InvalidDocumentLineage;
                    }
                }
                if (self.replica) |rep| {
                    try rep.validate();
                    if (rep.epoch != self.merge_epoch) return error.InvalidDocumentLineage;
                }
            },
        }
        if (self.raw_span) |span| try span.validate();
    }
};

pub const Mutation = struct {
    target: Target,
    operation: d.Operation,
    lineage: Lineage,
    operations: u16,
    payload: d.Content,

    pub fn validate(self: Mutation) !void {
        try self.target.requireOperation(self.operation);
        try self.lineage.validate();
        try self.payload.validate();
        if (self.operations == 0) return error.InvalidDocumentMutation;
    }

    pub fn requireSame(self: Mutation, other: Mutation) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentMutationConflict;
    }
};

pub const MutationReceipt = struct {
    mutation: Mutation,
    accepted_revision: u64,
    state: d.Content,
    unresolved_conflicts: u16,
    accepted: d.Position,

    pub fn validate(self: MutationReceipt) !void {
        try self.mutation.validate();
        try self.state.validate();
        try self.accepted.validate();
        if (self.accepted_revision == 0 or self.accepted.next_lsn == 0) {
            return error.InvalidDocumentMutationReceipt;
        }
        if (self.accepted_revision <= self.mutation.lineage.base_revision) {
            return error.InvalidDocumentMutationReceipt;
        }
        if (self.mutation.lineage.parent_revision) |parent| {
            if (self.accepted_revision <= parent) return error.InvalidDocumentMutationReceipt;
        }
    }

    pub fn requireMutation(self: MutationReceipt, candidate: Mutation) !void {
        try self.validate();
        try self.mutation.requireSame(candidate);
    }
};

pub const ReplicaState = struct {
    target: Target,
    principal: u64,
    replica: Replica,
    discarded_through: u64,

    pub fn validate(self: ReplicaState) !void {
        try self.target.validate();
        try self.replica.validate();
        if (self.principal > p.max_counter or self.discarded_through > self.replica.sequence) {
            return error.InvalidDocumentReplicaState;
        }
    }

    pub fn initial(mutation: Mutation) !ReplicaState {
        try mutation.validate();
        const replica = mutation.lineage.replica orelse return error.DocumentReplicaRequired;
        if (replica.sequence != 1) return error.DocumentReplicaSequenceGap;
        return .{
            .target = mutation.target,
            .principal = mutation.operation.principal,
            .replica = replica,
            .discarded_through = 0,
        };
    }

    pub fn check(self: ReplicaState, mutation: Mutation) !enum { apply, advance_epoch, retry } {
        try self.validate();
        try mutation.validate();
        if (!self.target.sameDocument(mutation.target)) return error.DocumentTargetConflict;
        const replica = mutation.lineage.replica orelse return error.DocumentReplicaRequired;
        if (!std.mem.eql(u8, &self.replica.id, &replica.id) or
            self.principal != mutation.operation.principal)
        {
            return error.DocumentReplicaConflict;
        }
        if (replica.epoch < self.replica.epoch) return error.DocumentReplicaFenced;
        if (replica.epoch > self.replica.epoch) {
            if (replica.sequence != 1) return error.DocumentReplicaSequenceGap;
            return .advance_epoch;
        }
        if (replica.sequence <= self.discarded_through) {
            return error.DocumentReplicaReceiptExpired;
        }
        if (replica.sequence <= self.replica.sequence) return .retry;
        if (replica.sequence - self.replica.sequence != 1) {
            return error.DocumentReplicaSequenceGap;
        }
        return .apply;
    }

    pub fn forgetThrough(self: ReplicaState, sequence: u64) !ReplicaState {
        try self.validate();
        if (sequence < self.discarded_through or sequence > self.replica.sequence) {
            return error.InvalidDocumentReplicaFloor;
        }
        var result = self;
        result.discarded_through = sequence;
        return result;
    }
};

pub const Cut = struct {
    target: Target,
    merge_epoch: u64,
    retained_from: u64,
    accepted_revision: u64,
    state: d.Content,
    accepted: d.Position,

    pub fn validate(self: Cut) !void {
        try self.target.validate();
        try self.state.validate();
        try self.accepted.validate();
        if (self.merge_epoch == 0 or
            self.retained_from == 0 or
            self.accepted_revision == 0 or
            self.retained_from > self.accepted_revision or
            self.accepted.next_lsn == 0)
        {
            return error.InvalidDocumentCut;
        }
    }

    pub fn requireRevision(self: Cut, revision: u64) !void {
        try self.validate();
        if (revision < self.retained_from) return error.DocumentHistoryUnavailable;
        if (revision > self.accepted_revision) return error.DocumentRevisionBeyondCut;
    }
};

pub const Checkpoint = struct {
    target: Target,
    operation: d.Operation,
    previous_epoch: u64,
    next_epoch: u64,
    retained_from: u64,
    checkpoint_revision: u64,
    checkpoint: d.Content,

    pub fn validate(self: Checkpoint) !void {
        try self.target.requireOperation(self.operation);
        try self.checkpoint.validate();
        if (self.previous_epoch == 0 or
            self.previous_epoch == std.math.maxInt(u64) or
            self.next_epoch != self.previous_epoch + 1 or
            self.retained_from == 0 or
            self.checkpoint_revision == 0 or
            self.retained_from > self.checkpoint_revision)
        {
            return error.InvalidDocumentCheckpoint;
        }
    }

    pub fn requireSame(self: Checkpoint, other: Checkpoint) !void {
        try self.validate();
        try other.validate();
        if (!std.meta.eql(self, other)) return error.DocumentCheckpointConflict;
    }
};

pub const CheckpointReceipt = struct {
    checkpoint: Checkpoint,
    cut: Cut,

    pub fn validate(self: CheckpointReceipt) !void {
        try self.checkpoint.validate();
        try self.cut.validate();
        try self.checkpoint.target.requireSame(self.cut.target);
        if (self.cut.merge_epoch != self.checkpoint.next_epoch or
            self.cut.retained_from != self.checkpoint.retained_from or
            self.cut.accepted_revision != self.checkpoint.checkpoint_revision or
            !std.meta.eql(self.cut.state, self.checkpoint.checkpoint))
        {
            return error.InvalidDocumentCheckpointReceipt;
        }
    }

    pub fn requireCheckpoint(self: CheckpointReceipt, candidate: Checkpoint) !void {
        try self.validate();
        try self.checkpoint.requireSame(candidate);
    }
};

pub const SchemaTypes = struct {
    declaration: Declaration,
    mutation: MutationReceipt,
    replica: ReplicaState,
    checkpoint: CheckpointReceipt,
    read: Read.Receipt,
    read_cursor: Read.Cursor,
    read_release: Read.ReleaseReceipt,
};

test {
    _ = @import("document_protocol_test.zig");
}

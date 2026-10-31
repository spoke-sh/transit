//! Serialized direct Document partition owner (`DocumentPartition`).
//!
//! Accepts single-append WAL mutations, resolves duplicate client tokens and
//! replica sequence floors across disk reopen and lost replies, advances finite
//! merge-window epochs via checkpoints, pins and authenticates retained revision
//! reads, and coordinates WAL archival, recovery checkpoints, and physical trim.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const Declaration = @import("DocumentDeclaration.zig");
const Initialization = @import("DocumentInitialization.zig");
const Evidence = @import("DocumentEvidence.zig");
const Read = @import("DocumentRead.zig");
const History = @import("LogHistory.zig");
const Recovery = @import("DocumentRecovery.zig");
const TreeStore = @import("TreeStore.zig");
const Guard = @import("PublicationGuard.zig");
const Records = @import("DocumentPartitionRecord.zig");
const pages = TreeStore.pages;
const Self = @This();

pub const Options = struct {
    resident_pages: usize = 16,
    index_work_bytes: usize = 8 * 1024 * 1024,
    read_secret: [32]u8 = @splat(7),
};

pub const DocumentHead = struct {
    cut: doc.Cut,
    unresolved_conflicts: u16,
};

pub const RevisionEntry = struct {
    state: d.Content,
    payload: d.Content,
    merge_epoch: u64,
    unresolved_conflicts: u16,
    lsn: u64,
};

pub const PinEntry = struct {
    released: bool,
    source: d.Content,
};

pub const RevisionStep = struct {
    revision: u64,
    state: []u8,
    cursor: doc.Read.Cursor,

    pub fn deinit(self: *RevisionStep, allocator: std.mem.Allocator) void {
        allocator.free(self.state);
        self.* = undefined;
    }
};

allocator: std.mem.Allocator,
log: Log.Log,
objects: Objects.ObjectStore,
store: TreeStore,
scratch: std.heap.ArenaAllocator,
authority: Read.Authority,
options: Options,
root: Records.Root,
commitment: [32]u8,
ready: bool = false,

pub fn open(
    allocator: std.mem.Allocator,
    log: Log.Log,
    objects: Objects.ObjectStore,
    request: Initialization.Request,
    guard: Guard,
    options: Options,
) !Self {
    const authority = try Read.Authority.init(options.read_secret);
    const initial = try Initialization.observe(allocator, log, objects, request, guard);
    var store = try TreeStore.init(allocator, objects, options.resident_pages);
    errdefer store.deinit();
    var self: Self = .{
        .allocator = allocator,
        .log = log,
        .objects = objects,
        .store = store,
        .scratch = .init(allocator),
        .authority = authority,
        .options = options,
        .root = .{
            .definition = p.Growth.current_definition,
            .initialization = request,
            .declared = request.declared,
            .next_lsn = 1,
            .documents_root = null,
            .revisions_root = null,
            .replicas_root = null,
            .operations_root = null,
            .reads_root = null,
            .archive = null,
            .recovery = null,
        },
        .commitment = initial.record.sha256,
        .ready = false,
    };
    errdefer self.deinit();
    try self.recover(guard);
    return self;
}

pub fn deinit(self: *Self) void {
    self.store.deinit();
    self.scratch.deinit();
    self.* = undefined;
}

pub fn recover(self: *Self, guard: Guard) !void {
    defer _ = self.scratch.reset(.retain_capacity);
    try authorize(guard);
    const end = try self.log.tail(self.root.initialization.partition);
    if (end == 0) return error.DocumentInitializationMissing;
    if (end > 1) {
        try self.selectCheckpoint(end, guard);
    }
    while (self.root.next_lsn < end) {
        var batch = try self.log.read(self.scratch.allocator(), self.root.initialization.partition, self.root.next_lsn, 1);
        defer batch.deinit();
        if (batch.frames.len != 1) return error.DocumentHistoryUnavailable;
        const decoded = try Records.decode(
            self.scratch.allocator(),
            batch.frames[0],
            self.root.initialization.partition,
            self.root.next_lsn,
        );
        try self.root.initialization.requireSame(decoded.record.root.initialization);
        if (!std.mem.eql(u8, &decoded.record.previous_commitment, &self.commitment)) {
            return error.InvalidDocumentPartitionRecord;
        }
        if (decoded.record.evidence) |ev| {
            _ = try Evidence.load(self.scratch.allocator(), self.objects, ev);
        }
        self.root = decoded.record.root;
        self.commitment = decoded.commitment;
    }
    try authorize(guard);
    self.ready = true;
}

pub fn applyMutation(
    self: *Self,
    mutation: doc.Mutation,
    payload_bytes: []const u8,
    state_bytes: []const u8,
    unresolved_conflicts: u16,
    guard: Guard,
) !doc.MutationReceipt {
    defer _ = self.scratch.reset(.retain_capacity);
    try mutation.validate();
    try self.requirePartition(mutation.target.partition);
    try authorize(guard);
    try self.requireReady();

    if (try self.findOutcome(mutation.operation)) |existing| {
        if (existing != .mutation) return error.DocumentOperationConflict;
        try existing.mutation.requireMutation(mutation);
        try authorize(guard);
        return existing.mutation;
    }

    const limits = self.root.declared.declaration.limits;
    if (mutation.operations > limits.operations_per_change or
        payload_bytes.len == 0 or
        payload_bytes.len > limits.change_bytes or
        state_bytes.len == 0 or
        unresolved_conflicts > limits.unresolved_conflicts)
    {
        return error.DocumentMutationLimitExceeded;
    }
    if (mutation.payload.bytes != payload_bytes.len or
        !std.mem.eql(u8, &Evidence.hash(payload_bytes), &mutation.payload.sha256))
    {
        return error.InvalidDocumentMutation;
    }
    if (mutation.lineage.profile != self.root.declared.declaration.configuration.profile) {
        return error.InvalidDocumentLineage;
    }

    const current_head = try self.getDocumentHead(mutation.target.document);
    if (current_head) |head| {
        if (mutation.lineage.merge_epoch != head.cut.merge_epoch) {
            return error.DocumentEpochFenced;
        }
        if (mutation.lineage.base_revision < head.cut.retained_from) {
            return error.DocumentHistoryUnavailable;
        }
        if (mutation.lineage.base_revision > head.cut.accepted_revision) {
            return error.DocumentRevisionBeyondCut;
        }
        if (mutation.lineage.parent_revision) |parent| {
            if (parent < head.cut.retained_from) return error.DocumentHistoryUnavailable;
            if (parent > head.cut.accepted_revision) return error.DocumentRevisionBeyondCut;
        }
    } else {
        if (mutation.lineage.base_revision != 0 or
            mutation.lineage.parent_revision != null or
            mutation.lineage.merge_epoch != 1)
        {
            return error.InvalidDocumentLineage;
        }
    }

    var next_replica: ?doc.ReplicaState = null;
    if (mutation.lineage.replica) |rep| {
        if (try self.getReplicaState(mutation.target.document, rep.id)) |existing_rep| {
            const disp = try existing_rep.check(mutation);
            switch (disp) {
                .retry => return error.DocumentReplicaConflict,
                .apply, .advance_epoch => {
                    var updated = existing_rep;
                    updated.replica = rep;
                    if (disp == .advance_epoch) updated.discarded_through = 0;
                    next_replica = updated;
                },
            }
        } else {
            next_replica = try doc.ReplicaState.initial(mutation);
        }
    }

    const payload_content = try self.stageBytes("document-payloads", payload_bytes);
    const state_content = try self.stageBytes("document-states", state_bytes);
    const next_revision: u64 = if (current_head) |h| h.cut.accepted_revision + 1 else 1;
    const retained_from: u64 = if (current_head) |h| h.cut.retained_from else 1;
    const accepted_pos = try self.nextPosition();

    const receipt: doc.MutationReceipt = .{
        .mutation = mutation,
        .accepted_revision = next_revision,
        .state = state_content,
        .unresolved_conflicts = unresolved_conflicts,
        .accepted = accepted_pos,
    };
    try receipt.validate();
    const evidence_content = try Evidence.stage(self.objects, .{ .mutation = receipt });

    const new_cut: doc.Cut = .{
        .target = mutation.target,
        .merge_epoch = mutation.lineage.merge_epoch,
        .retained_from = retained_from,
        .accepted_revision = next_revision,
        .state = state_content,
        .accepted = accepted_pos,
    };
    const new_head: DocumentHead = .{
        .cut = new_cut,
        .unresolved_conflicts = unresolved_conflicts,
    };
    const rev_entry: RevisionEntry = .{
        .state = state_content,
        .payload = payload_content,
        .merge_epoch = mutation.lineage.merge_epoch,
        .unresolved_conflicts = unresolved_conflicts,
        .lsn = self.root.next_lsn,
    };

    try self.store.begin(self.options.index_work_bytes);
    defer self.store.end();
    var next_root = self.root;
    next_root.next_lsn = accepted_pos.next_lsn;
    next_root.documents_root = try self.tree().put(
        next_root.documents_root,
        try docKey(mutation.target.document),
        try self.encodeValue(new_head),
    );
    next_root.revisions_root = try self.tree().put(
        next_root.revisions_root,
        try revisionKey(mutation.target.document, next_revision),
        try self.encodeValue(rev_entry),
    );
    if (next_replica) |rep_state| {
        next_root.replicas_root = try self.tree().put(
            next_root.replicas_root,
            try replicaKey(mutation.target.document, rep_state.replica.id),
            try self.encodeValue(rep_state),
        );
    }
    next_root.operations_root = try self.tree().put(
        next_root.operations_root,
        try operationKey(mutation.operation),
        try self.encodeValue(evidence_content),
    );

    try self.publishRecord(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = self.commitment,
        .root = next_root,
        .action = .{ .mutation = receipt },
        .evidence = evidence_content,
    }, .row_delta, guard);
    return receipt;
}

pub fn publishCheckpoint(
    self: *Self,
    checkpoint: doc.Checkpoint,
    checkpoint_bytes: []const u8,
    guard: Guard,
) !doc.CheckpointReceipt {
    defer _ = self.scratch.reset(.retain_capacity);
    try checkpoint.validate();
    try self.requirePartition(checkpoint.target.partition);
    try authorize(guard);
    try self.requireReady();

    if (try self.findOutcome(checkpoint.operation)) |existing| {
        if (existing != .checkpoint) return error.DocumentOperationConflict;
        try existing.checkpoint.requireCheckpoint(checkpoint);
        try authorize(guard);
        return existing.checkpoint;
    }

    const head = (try self.getDocumentHead(checkpoint.target.document)) orelse return error.DocumentHistoryUnavailable;
    if (checkpoint.previous_epoch != head.cut.merge_epoch or
        checkpoint.checkpoint_revision != head.cut.accepted_revision or
        checkpoint.retained_from < head.cut.retained_from or
        checkpoint.retained_from > head.cut.accepted_revision)
    {
        return error.InvalidDocumentCheckpoint;
    }
    if (checkpoint.checkpoint.bytes != checkpoint_bytes.len or
        !std.mem.eql(u8, &Evidence.hash(checkpoint_bytes), &checkpoint.checkpoint.sha256))
    {
        return error.InvalidDocumentCheckpoint;
    }

    const state_content = try self.stageBytes("document-states", checkpoint_bytes);
    const accepted_pos = try self.nextPosition();
    const new_cut: doc.Cut = .{
        .target = checkpoint.target,
        .merge_epoch = checkpoint.next_epoch,
        .retained_from = checkpoint.retained_from,
        .accepted_revision = checkpoint.checkpoint_revision,
        .state = state_content,
        .accepted = accepted_pos,
    };
    const receipt: doc.CheckpointReceipt = .{
        .checkpoint = checkpoint,
        .cut = new_cut,
    };
    try receipt.validate();
    const evidence_content = try Evidence.stage(self.objects, .{ .checkpoint = receipt });

    const new_head: DocumentHead = .{
        .cut = new_cut,
        .unresolved_conflicts = head.unresolved_conflicts,
    };

    try self.store.begin(self.options.index_work_bytes);
    defer self.store.end();
    var next_root = self.root;
    next_root.next_lsn = accepted_pos.next_lsn;
    next_root.documents_root = try self.tree().put(
        next_root.documents_root,
        try docKey(checkpoint.target.document),
        try self.encodeValue(new_head),
    );
    next_root.operations_root = try self.tree().put(
        next_root.operations_root,
        try operationKey(checkpoint.operation),
        try self.encodeValue(evidence_content),
    );

    try self.publishRecord(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = self.commitment,
        .root = next_root,
        .action = .{ .checkpoint = receipt },
        .evidence = evidence_content,
    }, .manifest_checkpoint, guard);
    return receipt;
}

pub fn beginRead(
    self: *Self,
    request: doc.Read.Request,
    guard: Guard,
) !doc.Read.Receipt {
    defer _ = self.scratch.reset(.retain_capacity);
    try request.validate();
    try self.requirePartition(request.target.partition);
    try authorize(guard);
    try self.requireReady();

    if (try self.findOutcome(request.operation)) |existing| {
        if (existing != .read) return error.DocumentOperationConflict;
        try existing.read.requireRequest(request);
        try authorize(guard);
        return existing.read;
    }

    const limits = self.root.declared.declaration.limits;
    if (request.max_steps > limits.read_steps or request.max_bytes > limits.read_bytes) {
        return error.InvalidDocumentRead;
    }

    const head = (try self.getDocumentHead(request.target.document)) orelse return error.DocumentHistoryUnavailable;
    try head.cut.requireRevision(request.from_revision);
    const through_revision = request.through_revision orelse head.cut.accepted_revision;
    try head.cut.requireRevision(through_revision);

    const source: Read.Source = .{
        .definition = p.Growth.current_definition,
        .request = request,
        .cut = head.cut,
        .through_revision = through_revision,
    };
    const source_content = try Read.stage(self.objects, source);
    const accepted_pos = try self.nextPosition();
    const receipt: doc.Read.Receipt = .{
        .request = request,
        .cut = head.cut,
        .through_revision = through_revision,
        .source = source_content,
        .accepted = accepted_pos,
    };
    try receipt.validate();
    const evidence_content = try Evidence.stage(self.objects, .{ .read = receipt });
    const pin: PinEntry = .{ .released = false, .source = source_content };

    try self.store.begin(self.options.index_work_bytes);
    defer self.store.end();
    var next_root = self.root;
    next_root.next_lsn = accepted_pos.next_lsn;
    next_root.reads_root = try self.tree().put(
        next_root.reads_root,
        try operationKey(request.operation),
        try self.encodeValue(pin),
    );
    next_root.operations_root = try self.tree().put(
        next_root.operations_root,
        try operationKey(request.operation),
        try self.encodeValue(evidence_content),
    );

    try self.publishRecord(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = self.commitment,
        .root = next_root,
        .action = .{ .read = receipt },
        .evidence = evidence_content,
    }, .manifest_checkpoint, guard);
    return receipt;
}

pub fn readCursor(self: *Self, receipt: doc.Read.Receipt, guard: Guard) !doc.Read.Cursor {
    defer _ = self.scratch.reset(.retain_capacity);
    try receipt.validate();
    try authorize(guard);
    try self.requireReady();
    _ = try self.requireLivePin(receipt.handle());
    const outcome = (try self.findOutcome(receipt.request.operation)) orelse return error.DocumentReadMissing;
    if (outcome != .read or !std.meta.eql(outcome.read, receipt)) return error.DocumentReadConflict;
    const coverage = try receipt.initialCoverage();
    const cursor = try self.authority.sign(receipt.handle(), coverage);
    try authorize(guard);
    return cursor;
}

pub fn readNextRevision(
    self: *Self,
    output: std.mem.Allocator,
    cursor: doc.Read.Cursor,
    guard: Guard,
) !?RevisionStep {
    defer _ = self.scratch.reset(.retain_capacity);
    try authorize(guard);
    try self.requireReady();
    try self.authority.verify(cursor);
    const pin = try self.requireLivePin(cursor.read);
    const source = try Read.load(self.scratch.allocator(), self.objects, pin.source);
    try self.requirePartition(source.cut.target.partition);
    if (!std.meta.eql(source.cut, cursor.coverage.cut) or
        source.request.from_revision != cursor.coverage.from_revision or
        source.through_revision != cursor.coverage.through_revision or
        !std.meta.eql(source.request.operation, cursor.read.owner) or
        cursor.coverage.steps != cursor.coverage.next_revision - cursor.coverage.from_revision or
        cursor.coverage.steps > source.request.max_steps or
        cursor.coverage.bytes > source.request.max_bytes)
    {
        return error.DocumentReadConflict;
    }
    if (cursor.coverage.complete) {
        try authorize(guard);
        return null;
    }

    const rev = cursor.coverage.next_revision;
    const rev_val = (try self.tree().get(
        self.root.revisions_root,
        try revisionKey(source.cut.target.document, rev),
    )) orelse return error.DocumentHistoryUnavailable;
    const rev_entry = try self.decodeValue(RevisionEntry, rev_val);
    // These are cumulative request budgets. Refuse before loading or allocating
    // the next state; exhausting a budget is not successful read completion.
    if (cursor.coverage.steps == source.request.max_steps or
        rev_entry.state.bytes > source.request.max_bytes - cursor.coverage.bytes)
    {
        return error.DocumentReadLimitExceeded;
    }
    const state_bytes = try self.loadBytes(output, "document-states", rev_entry.state);
    errdefer output.free(state_bytes);

    var next_coverage = cursor.coverage;
    next_coverage.next_revision = rev + 1;
    next_coverage.steps += 1;
    next_coverage.bytes += @intCast(state_bytes.len);
    next_coverage.complete = next_coverage.next_revision == next_coverage.through_revision + 1;
    const next_cursor = try self.authority.sign(cursor.read, next_coverage);
    try authorize(guard);
    return .{
        .revision = rev,
        .state = state_bytes,
        .cursor = next_cursor,
    };
}

pub fn releaseRead(
    self: *Self,
    release: doc.Read.Release,
    guard: Guard,
) !doc.Read.ReleaseReceipt {
    defer _ = self.scratch.reset(.retain_capacity);
    try release.validate();
    try self.requirePartition(release.target.partition);
    try authorize(guard);
    try self.requireReady();

    if (try self.findOutcome(release.operation)) |existing| {
        if (existing != .read_release) return error.DocumentOperationConflict;
        try existing.read_release.requireRelease(release);
        try authorize(guard);
        return existing.read_release;
    }

    const pin = try self.requireLivePin(release.read);
    const source = try Read.load(self.scratch.allocator(), self.objects, pin.source);
    try source.request.target.requireSame(release.target);
    if (!std.meta.eql(source.request.operation, release.read.owner)) return error.DocumentReadConflict;
    const accepted_pos = try self.nextPosition();
    const receipt: doc.Read.ReleaseReceipt = .{
        .release = release,
        .accepted = accepted_pos,
    };
    try receipt.validate();
    const evidence_content = try Evidence.stage(self.objects, .{ .read_release = receipt });
    const released_pin: PinEntry = .{ .released = true, .source = pin.source };

    try self.store.begin(self.options.index_work_bytes);
    defer self.store.end();
    var next_root = self.root;
    next_root.next_lsn = accepted_pos.next_lsn;
    next_root.reads_root = try self.tree().put(
        next_root.reads_root,
        try operationKey(release.read.owner),
        try self.encodeValue(released_pin),
    );
    next_root.operations_root = try self.tree().put(
        next_root.operations_root,
        try operationKey(release.operation),
        try self.encodeValue(evidence_content),
    );

    try self.publishRecord(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = self.commitment,
        .root = next_root,
        .action = .{ .read_release = receipt },
        .evidence = evidence_content,
    }, .manifest_checkpoint, guard);
    return receipt;
}

pub fn archive(
    self: *Self,
    cut: d.Position,
    limits: History.Limits,
    guard: Guard,
) !History.Coverage {
    defer _ = self.scratch.reset(.retain_capacity);
    try cut.validate();
    try limits.validate();
    try authorize(guard);
    try self.requireReady();
    if (cut.partition != self.root.initialization.partition or
        cut.next_lsn == 0 or
        cut.next_lsn > self.root.next_lsn)
    {
        return error.InvalidDocumentArchive;
    }
    const current_archive = self.root.archive orelse History.Coverage.empty;
    if (current_archive.through >= cut.next_lsn) {
        try authorize(guard);
        return current_archive;
    }

    try self.store.begin(self.options.index_work_bytes);
    defer self.store.end();
    const staged = try History.stage(
        self.scratch.allocator(),
        &self.store,
        self.log,
        cut.partition,
        current_archive,
        cut,
        limits,
    );
    if (staged.frames == 0) return error.InvalidDocumentArchive;
    try History.verifyExtension(
        self.scratch.allocator(),
        &self.store,
        current_archive,
        staged.coverage,
        cut.partition,
        self.root.next_lsn,
    );
    var next_root = self.root;
    next_root.next_lsn = (try self.nextPosition()).next_lsn;
    next_root.archive = staged.coverage;
    try self.publishRecord(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = self.commitment,
        .root = next_root,
        .action = .{ .archive = staged.coverage },
        .evidence = null,
    }, .manifest_checkpoint, guard);
    return staged.coverage;
}

pub fn checkpointRecovery(
    self: *Self,
    cut: d.Position,
    guard: Guard,
) !Records.RecoveryReference {
    defer _ = self.scratch.reset(.retain_capacity);
    try cut.validate();
    try authorize(guard);
    try self.requireReady();
    if (cut.partition != self.root.initialization.partition or
        cut.next_lsn == 0 or
        cut.next_lsn > self.root.next_lsn)
    {
        return error.InvalidDocumentRecovery;
    }
    if (self.root.recovery) |reference| {
        if (reference.next_lsn >= cut.next_lsn) {
            try authorize(guard);
            return reference;
        }
    }
    const reference = try Recovery.stage(self.objects, self.root, self.commitment);
    const next_lsn = (try self.nextPosition()).next_lsn;
    const loaded = try Recovery.load(self.scratch.allocator(), self.objects, reference, next_lsn, self.root.initialization);
    if (!std.meta.eql(loaded.root, self.root) or !std.mem.eql(u8, &loaded.commitment, &self.commitment)) {
        return error.InvalidDocumentRecovery;
    }
    var next_root = self.root;
    next_root.next_lsn = next_lsn;
    next_root.recovery = reference;
    try self.publishRecord(.{
        .definition = p.Growth.current_definition,
        .previous_commitment = self.commitment,
        .root = next_root,
        .action = .{ .recovery_checkpoint = reference },
        .evidence = null,
    }, .manifest_checkpoint, guard);
    return reference;
}

pub fn archivedThrough(allocator: std.mem.Allocator, frame: Log.Frame) !u64 {
    if (std.mem.startsWith(u8, frame.payload, "DINIT001")) {
        _ = try Initialization.decode(allocator, frame);
        return 0;
    }
    const root = (try Records.decode(allocator, frame, frame.header.partition_id, frame.header.lsn)).record.root;
    const cov = root.archive orelse return 0;
    const reference = root.recovery orelse return 0;
    return @min(cov.through, reference.next_lsn);
}

pub fn trimArchived(self: *Self, guard: Guard) !u64 {
    try self.requireReady();
    _ = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    const cov = self.root.archive orelse return 0;
    if (cov.through == 0) return 0;
    const reference = self.root.recovery orelse return error.DocumentCheckpointRequired;
    const through = @min(cov.through, reference.next_lsn);
    self.log.trim(self.root.initialization.partition, through) catch |err| {
        self.ready = false;
        return err;
    };
    return through;
}

fn selectCheckpoint(self: *Self, end: u64, guard: Guard) !void {
    if (end <= 1) return;
    var latest = try self.log.read(self.scratch.allocator(), self.root.initialization.partition, end - 1, 1);
    defer latest.deinit();
    if (latest.frames.len != 1) return error.DocumentHistoryUnavailable;
    const record = (try Records.decode(
        self.scratch.allocator(),
        latest.frames[0],
        self.root.initialization.partition,
        end - 1,
    )).record;
    try self.root.initialization.requireSame(record.root.initialization);
    const reference = record.root.recovery orelse return;
    if (reference.next_lsn <= self.root.next_lsn) return;
    const basis = try Recovery.load(self.scratch.allocator(), self.objects, reference, end, self.root.initialization);
    var publication = try self.log.read(self.scratch.allocator(), self.root.initialization.partition, reference.next_lsn, 1);
    defer publication.deinit();
    if (publication.frames.len != 1) return error.DocumentRecoveryMissing;
    try Recovery.requirePublication(
        basis,
        reference,
        (try Records.decode(
            self.scratch.allocator(),
            publication.frames[0],
            self.root.initialization.partition,
            reference.next_lsn,
        )).record,
    );
    try authorize(guard);
    self.root = basis.root;
    self.commitment = basis.commitment;
}

fn publishRecord(self: *Self, record: Records.Record, kind: Log.FrameKind, guard: Guard) !void {
    var buffer: [Records.max_bytes]u8 = undefined;
    const bytes = try Records.encode(record, &buffer);
    const fence = try guard.acquire(guard.context);
    defer guard.release(guard.context);
    if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidWalEpoch;
    const receipt = self.log.append(
        self.root.initialization.partition,
        self.root.next_lsn,
        fence.writer_epoch,
        fence.policy_epoch,
        kind,
        bytes,
    ) catch |err| {
        self.ready = false;
        return switch (err) {
            error.StaleWriterEpoch, error.StalePolicyEpoch => err,
            else => error.DocumentAppendUncertain,
        };
    };
    if (receipt.partition_id != record.root.initialization.partition or
        receipt.lsn != self.root.next_lsn or
        receipt.next_lsn != record.root.next_lsn)
    {
        self.ready = false;
        return error.DocumentAppendUncertain;
    }
    self.root = record.root;
    self.commitment = Evidence.hash(bytes);
}

fn stageBytes(self: *Self, prefix: []const u8, bytes: []const u8) !d.Content {
    const content: d.Content = .{ .bytes = bytes.len, .sha256 = Evidence.hash(bytes) };
    var name: [96]u8 = undefined;
    const key = try std.fmt.bufPrint(&name, "{s}/{x}.data", .{ prefix, &content.sha256 });
    const accepted = try self.objects.putImmutable(key, bytes, content.sha256);
    if (accepted.size != content.bytes or !std.mem.eql(u8, &accepted.sha256, &content.sha256)) {
        return error.InvalidDocumentStateObject;
    }
    return content;
}

fn loadBytes(self: *Self, allocator: std.mem.Allocator, prefix: []const u8, content: d.Content) ![]u8 {
    try content.validate();
    var name: [96]u8 = undefined;
    const key = try std.fmt.bufPrint(&name, "{s}/{x}.data", .{ prefix, &content.sha256 });
    const meta = (try self.objects.head(key)) orelse return error.DocumentStateObjectMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) {
        return error.InvalidDocumentStateObject;
    }
    const out = try allocator.alloc(u8, @intCast(content.bytes));
    errdefer allocator.free(out);
    if ((try self.objects.getRange(key, 0, @intCast(out.len), out)).len != out.len) {
        return error.InvalidDocumentStateObject;
    }
    if (!std.mem.eql(u8, &Evidence.hash(out), &content.sha256)) {
        return error.InvalidDocumentStateObject;
    }
    return out;
}

fn findOutcome(self: *Self, op: d.Operation) !?Evidence.Outcome {
    try op.validate();
    if (!std.meta.eql(op.scope, self.root.initialization.operation.scope)) {
        return error.DocumentPartitionConflict;
    }
    if (std.meta.eql(op, self.root.initialization.operation)) {
        return error.DocumentOperationConflict;
    }
    const val = (try self.tree().get(self.root.operations_root, try operationKey(op))) orelse return null;
    const content = try self.decodeValue(d.Content, val);
    return try Evidence.load(self.scratch.allocator(), self.objects, content);
}

fn requireLivePin(self: *Self, handle: doc.Read.Handle) !PinEntry {
    try handle.validate();
    const val = (try self.tree().get(self.root.reads_root, try operationKey(handle.owner))) orelse return error.DocumentReadMissing;
    const pin = try self.decodeValue(PinEntry, val);
    if (!std.meta.eql(pin.source, handle.source)) return error.DocumentReadConflict;
    if (pin.released) return error.DocumentReadReleased;
    return pin;
}

fn getDocumentHead(self: *Self, document_id: [16]u8) !?DocumentHead {
    const val = (try self.tree().get(self.root.documents_root, try docKey(document_id))) orelse return null;
    return try self.decodeValue(DocumentHead, val);
}

fn getReplicaState(self: *Self, document_id: [16]u8, replica_id: [16]u8) !?doc.ReplicaState {
    const val = (try self.tree().get(self.root.replicas_root, try replicaKey(document_id, replica_id))) orelse return null;
    return try self.decodeValue(doc.ReplicaState, val);
}

fn encodeValue(self: *Self, value: anytype) !pages.Value {
    _ = self;
    var buffer: [2048]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return pages.Value.init(writer.buffered());
}

fn decodeValue(self: *Self, comptime T: type, value: pages.Value) !T {
    const parsed = try p.Json.parseFromSlice(T, self.scratch.allocator(), value.slice());
    return parsed.value;
}

fn docKey(document_id: [16]u8) !pages.Key {
    return pages.Key.init(&document_id);
}

fn revisionKey(document_id: [16]u8, revision: u64) !pages.Key {
    var bytes: [24]u8 = undefined;
    @memcpy(bytes[0..16], &document_id);
    std.mem.writeInt(u64, bytes[16..24], revision, .big);
    return pages.Key.init(&bytes);
}

fn replicaKey(document_id: [16]u8, replica_id: [16]u8) !pages.Key {
    var bytes: [32]u8 = undefined;
    @memcpy(bytes[0..16], &document_id);
    @memcpy(bytes[16..32], &replica_id);
    return pages.Key.init(&bytes);
}

fn operationKey(op: d.Operation) !pages.Key {
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], op.principal, .big);
    std.mem.writeInt(u64, bytes[8..16], op.operation, .big);
    return pages.Key.init(&bytes);
}

fn tree(self: *Self) pages.Tree(TreeStore) {
    return .{ .store = &self.store };
}

fn nextPosition(self: *Self) !d.Position {
    return .{
        .partition = self.root.initialization.partition,
        .next_lsn = std.math.add(u64, self.root.next_lsn, 1) catch return error.DocumentPositionExhausted,
    };
}

fn authorize(guard: Guard) !void {
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
}

fn requireReady(self: *Self) !void {
    if (!self.ready) return error.DocumentRecoveryRequired;
    if (try self.log.tail(self.root.initialization.partition) != self.root.next_lsn) {
        self.ready = false;
        return error.DocumentRecoveryRequired;
    }
}

fn requirePartition(self: *Self, target: doc.Partition) !void {
    try target.validate();
    if (target.partition != self.root.initialization.ordinal or
        !std.meta.eql(
            target.interpretation.object,
            self.root.initialization.declared.declaration.interpretation.object,
        ))
    {
        return error.DocumentPartitionConflict;
    }
}

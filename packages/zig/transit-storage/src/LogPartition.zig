//! Shared serialized log publication and recovery owner. The adapter binds
//! current catalog metadata,
//! global operation identity and authorization; it must serialize declaration
//! edits with this owner. Staging indexes confers no acceptance or authority.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const q = p.StreamQueue;
const Log = @import("TransitLog.zig");
const Objects = @import("TransitObjectStore.zig");
const Declaration = @import("LogDeclaration.zig");
const Initialization = @import("LogInitialization.zig");
const Evidence = @import("LogEvidence.zig");
const Read = @import("LogRead.zig");
const History = @import("LogHistory.zig");
const Checkpoint = @import("LogRecovery.zig");
const read = p.StreamRead;
const Batch = @import("LogBatch.zig");
const Segment = @import("LogSegment.zig");
const f = @import("transit_fuze");
const Tail = @import("LogTail.zig");
const Time = @import("LogTime.zig");
const Compaction = @import("StreamCompaction.zig");
const Bitmap = @import("BitmapDirectory.zig");
const Keys = @import("OrderedKeyIndex.zig");
const TreeStore = @import("TreeStore.zig");
const Guard = @import("PublicationGuard.zig");
const r = @import("LogPartitionRecord.zig");
const pages = TreeStore.pages;
const CandidateObjects = @import("CandidateObjects.zig");
const Transaction = @import("LogTransaction.zig");
const Actions = @import("LogTransactionActions.zig");
const QueueIndex = @import("QueueIndex.zig");
const QueueClaims = @import("QueueClaims.zig");
const QueueSelection = @import("QueueSelection.zig");
const QueueLeaseHeap = @import("QueueLeaseHeap.zig");
const QueueTimingWheel = @import("QueueTimingWheel.zig");
const QueueVisibilityCache = @import("QueueVisibilityCache.zig");
const QueueSchedule = @import("QueueSchedule.zig");
const QueueAffinity = @import("QueueAffinity.zig");
const DeadlineCache = struct {
    root: ?pages.Reference = null,
    valid: bool = false,
    heap: QueueLeaseHeap,
    fn clear(self: *@This()) void {
        self.valid = false;
        self.root = null;
        self.heap.clear();
    }
};
const queue_read = p.QueueRead;
pub fn Owner(comptime kind: p.StreamQueueDeclaration.Kind) type {
    return struct {
        const Self = @This();
        pub const Root = r.Root;
        pub const Options = struct {
            resident_pages: usize = 16,
            index_work_bytes: usize = 8 * 1024 * 1024,
            batch_bytes: u32 = 1024 * 1024,
            read_rows: u32 = 4096,
            read_scan_rows: u32 = 4096,
            read_bytes: u32 = 4 * 1024 * 1024,
            key_bytes: u32 = 64 * 1024,
            segment_work_bytes: usize = 64 * 1024 * 1024,
            segment_rows_per_group: u32 = 1024,
            queue_candidate_objects: u32 = 4096,
            queue_candidate_resident_bytes: usize = 16 * 1024 * 1024,
            queue_claim_rows: u32 = 256,
            /// Cached earliest active deadlines, independent of durable active count.
            queue_deadline_rows: u32 = 64,
            /// Cached visibility prefix; remaining work stays in paged storage.
            queue_visibility_rows: u32 = 64,
            /// Full canonical FIFO keys cached independently of durable key count.
            queue_affinity_rows: u32 = 64,
            /// Bounded scheduling source scans; independent of the wheel capacity.
            queue_timer_read_work: u32 = 4096,
            /// Same physical namespace and authority, with deployment control reserve.
            /// Only progress/closure and physical recovery use this capability.
            control: ?struct { log: Log.Log, objects: Objects.ObjectStore } = null,
            /// Only the common transaction recovery owner may cross a barrier.
            transaction_control: bool = false,
            clock: ?Time.Source = null,
            tail: Tail.Options = .{ .slots = 2, .borrow_slots = 16, .slot_bytes = 1024 * 1024, .resident_bytes = 3 * 1024 * 1024 },
        };

        allocator: std.mem.Allocator,
        log: Log.Log,
        objects: Objects.ObjectStore,
        store: TreeStore,
        cache: Tail,
        scratch: std.heap.ArenaAllocator,
        encoded: []u8,
        key_buffer: []u8,
        options: Options,
        root: Root,
        commitment: [32]u8,
        ready: bool = false,
        private_position: ?d.Position = null,
        candidate_objects: if (kind == .queue) CandidateObjects else void,
        queue_container: if (kind == .queue) Bitmap.Container else void,
        queue_leases: if (kind == .queue) []q.Lease else void,
        queue_selection: if (kind == .queue) []u8 else void,
        queue_deadlines: if (kind == .queue) DeadlineCache else void,
        queue_visibility: if (kind == .queue) QueueVisibilityCache else void,
        queue_timers: if (kind == .queue) *QueueSchedule.Workspace else void,
        queue_affinity: if (kind == .queue) QueueAffinity else void,

        /// Opens the original initialization only. Recovery is explicit bounded work;
        /// a caller cannot serve reads or accept writes until recoverStep completes.
        pub fn open(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Initialization.Request, guard: Guard, options: Options) !Self {
            if (std.meta.activeTag(request.declared.declaration.configuration.policy) != kind) return error.LogPartitionConflict;
            if (kind == .queue and (options.queue_deadline_rows == 0 or options.queue_deadline_rows > 4096 or options.queue_visibility_rows == 0 or options.queue_visibility_rows > 4096)) return error.InvalidQueueScheduleBudget;
            if (kind == .queue and (options.queue_claim_rows == 0 or options.queue_claim_rows > QueueSelection.max_rows)) return error.InvalidQueueClaimBudget;
            if (kind == .queue and (options.queue_timer_read_work == 0 or options.queue_timer_read_work > 65536)) return error.InvalidQueueScheduleBudget;
            if (kind == .queue and (options.queue_affinity_rows == 0 or options.queue_affinity_rows > 4096)) return error.InvalidQueueAffinityBudget;
            if (options.read_scan_rows == 0 or options.read_scan_rows > 65536) return error.InvalidStreamBudget;
            if (options.segment_work_bytes == 0 or options.segment_work_bytes > 1024 * 1024 * 1024 or options.segment_rows_per_group == 0 or options.segment_rows_per_group > 1024) return error.InvalidStreamBudget;
            if (options.batch_bytes == 0 or options.batch_bytes > r.max_batch_bytes or options.key_bytes == 0 or options.key_bytes > 1024 * 1024 or options.index_work_bytes == 0 or options.tail.slot_bytes < options.batch_bytes or options.read_rows == 0 or options.read_rows > 65536 or options.read_bytes == 0 or options.read_bytes > 64 * 1024 * 1024) return error.InvalidStreamBudget;
            const initial = try Initialization.observe(allocator, log, objects, request, guard);
            var store = try TreeStore.init(allocator, objects, options.resident_pages);
            errdefer store.deinit();
            var cache = try Tail.init(allocator, options.tail);
            errdefer cache.deinit() catch unreachable;
            const encoded = try allocator.alloc(u8, @as(usize, options.batch_bytes) + r.header_bytes + r.max_metadata_bytes);
            errdefer allocator.free(encoded);
            const key_buffer = try allocator.alloc(u8, options.key_bytes);
            errdefer allocator.free(key_buffer);
            var candidates: if (kind == .queue) CandidateObjects else void = if (kind == .queue)
                try CandidateObjects.init(allocator, objects, .{ .bytes = options.index_work_bytes, .objects = options.queue_candidate_objects, .resident_bytes = options.queue_candidate_resident_bytes })
            else {};
            errdefer if (kind == .queue) candidates.deinit();
            const queue_leases = if (kind == .queue) try allocator.alloc(q.Lease, options.queue_claim_rows) else {};
            errdefer if (kind == .queue) allocator.free(queue_leases);
            const queue_selection = if (kind == .queue) try allocator.alloc(u8, QueueSelection.header_bytes + QueueSelection.max_metadata_bytes + QueueSelection.item_bytes * options.queue_claim_rows) else {};
            errdefer if (kind == .queue) allocator.free(queue_selection);
            const deadline_entries = if (kind == .queue) try allocator.alloc(q.Lease, options.queue_deadline_rows) else {};
            errdefer if (kind == .queue) allocator.free(deadline_entries);
            const visibility_entries = if (kind == .queue) try allocator.alloc(QueueTimingWheel.Entry, options.queue_visibility_rows) else {};
            errdefer if (kind == .queue) allocator.free(visibility_entries);
            const queue_timers = if (kind == .queue) try allocator.create(QueueSchedule.Workspace) else {};
            errdefer if (kind == .queue) allocator.destroy(queue_timers);
            const affinity_buckets = if (kind == .queue) try allocator.alloc(QueueAffinity.Atomic, options.queue_affinity_rows) else {};
            errdefer if (kind == .queue) allocator.free(affinity_buckets);
            const affinity_slots = if (kind == .queue) try allocator.alloc(QueueAffinity.Slot, options.queue_affinity_rows * 2) else {};
            errdefer if (kind == .queue) allocator.free(affinity_slots);
            return .{ .allocator = allocator, .log = log, .objects = objects, .store = store, .cache = cache, .scratch = .init(allocator), .encoded = encoded, .key_buffer = key_buffer, .options = options, .root = try Root.initial(request), .commitment = initial.record.sha256, .candidate_objects = candidates, .queue_container = if (kind == .queue) .{} else {}, .queue_leases = queue_leases, .queue_selection = queue_selection, .queue_deadlines = if (kind == .queue) .{ .heap = .{ .entries = deadline_entries } } else {}, .queue_visibility = if (kind == .queue) .{ .wheel = try QueueTimingWheel.init(visibility_entries, 0) } else {}, .queue_timers = queue_timers, .queue_affinity = if (kind == .queue) try QueueAffinity.init(affinity_buckets, affinity_slots) else {} };
        }
        pub fn deinit(self: *Self) !void {
            try self.cache.deinit();
            self.store.deinit();
            self.scratch.deinit();
            if (kind == .queue) {
                self.candidate_objects.deinit();
                self.allocator.free(self.queue_leases);
                self.allocator.free(self.queue_selection);
                self.allocator.free(self.queue_deadlines.heap.entries);
                self.allocator.free(self.queue_visibility.wheel.entries);
                self.allocator.destroy(self.queue_timers);
                self.allocator.free(self.queue_affinity.buckets);
                self.allocator.free(self.queue_affinity.slots);
            }
            self.allocator.free(self.encoded);
            self.allocator.free(self.key_buffer);
            self.* = undefined;
        }
        fn tree(self: *Self) pages.Tree(TreeStore) {
            return .{ .store = &self.store };
        }
        const IoScope = struct {
            log: Log.Log,
            objects: Objects.ObjectStore,
            index_objects: Objects.ObjectStore,
        };
        fn enterControl(self: *Self, enabled: bool) IoScope {
            const previous: IoScope = .{ .log = self.log, .objects = self.objects, .index_objects = self.store.store };
            if (enabled) if (self.options.control) |control| {
                self.log = control.log;
                self.objects = control.objects;
                self.store.store = control.objects;
            };
            return previous;
        }
        fn leaveControl(self: *Self, previous: IoScope) void {
            self.log = previous.log;
            self.objects = previous.objects;
            self.store.store = previous.index_objects;
        }
        fn loadEvidence(self: *Self, value: pages.Value) !Evidence.Record {
            defer _ = self.scratch.reset(.retain_capacity);
            return Evidence.load(self.scratch.allocator(), self.objects, value);
        }
        fn decodeValue(self: *Self, comptime T: type, value: pages.Value) !T {
            defer _ = self.scratch.reset(.retain_capacity);
            return r.valueDecode(T, self.scratch.allocator(), value);
        }
        fn decodeFrame(self: *Self, frame: Log.Frame, partition: u64, lsn: u64) !r.Decoded {
            defer _ = self.scratch.reset(.retain_capacity);
            return r.decode(self.scratch.allocator(), frame, partition, lsn);
        }
        fn authorize(guard: Guard) !void {
            _ = try guard.acquire(guard.context);
            guard.release(guard.context);
        }
        fn requireReady(self: *Self) !void {
            if (!self.ready) return error.LogRecoveryRequired;
            if (self.private_position != null) return;
            if (!self.options.transaction_control and self.root.transaction != null) return error.TransactionPrepared;
            if (try self.log.tail(self.root.initialization.partition) != self.root.next_lsn) {
                self.ready = false;
                return error.LogRecoveryRequired;
            }
        }
        fn requireTarget(self: *Self, target: q.Partition) !void {
            try target.validate();
            if (target.partition != self.root.initialization.ordinal or !std.meta.eql(target.interpretation.object, self.root.initialization.declared.declaration.interpretation.object)) return error.LogPartitionConflict;
        }
        pub fn transactionPinState(self: *Self, owner: d.Operation, guard: Guard) !Transaction.PinState {
            try owner.validate();
            if (!std.meta.eql(owner.scope, self.root.initialization.operation.scope)) return error.TransactionIdentityConflict;
            try authorize(guard);
            try self.requireReady();
            const encoded = try self.tree().get(self.root.transaction_pins, try Evidence.operationKey(owner));
            const pin = if (encoded) |value| try Transaction.Pin.decode(value) else null;
            const result: Transaction.PinState = .{ .handle = if (pin) |value| .{ .owner = owner, .content = value.source } else null, .released = if (pin) |value| value.released else false, .position = self.root.position() };
            try authorize(guard);
            return result;
        }
        /// The embedding catalog serializes acquisition across selected owners.
        /// An exact retry observes the original cut, never a replacement snapshot.
        pub fn pinTransactionSource(self: *Self, declared: Declaration.Stored, identity: p.Transaction.Identity, expected: d.Position, guard: Guard) !p.Transaction.Pin {
            try identity.validate();
            try identity.requireObject(self.root.declared.declaration.interpretation.object);
            try expected.validate();
            const prior_pin = try self.transactionPinState(identity.begin, guard);
            if (prior_pin.handle) |handle| {
                if (prior_pin.released) return error.LogTransactionSourceReleased;
                const source = try Transaction.loadSource(self.objects, handle);
                if (!std.meta.eql(source.identity, identity) or !std.meta.eql(source.root.declared, declared) or !std.meta.eql(source.root.position(), expected)) return error.TransactionIdentityConflict;
                try authorize(guard);
                return handle;
            }
            if (self.root.transaction != null) return error.TransactionPrepared;
            try self.root.requireDeclaration(declared);
            if (!std.meta.eql(self.root.position(), expected)) return error.TransactionConflict;
            var basis = self.root;
            basis.declared = declared;
            basis.transaction_pins = null;
            const handle = try Transaction.stageSource(self.objects, .{ .definition = p.Growth.current_definition, .identity = identity, .root = basis });
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var next = self.root;
            next.declared = declared;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.transaction_pins = try self.tree().put(next.transaction_pins, try Evidence.operationKey(identity.begin), try (Transaction.Pin{ .source = handle.content, .released = false }).encode());
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .transaction_pin = handle } }, &.{}, guard);
            return handle;
        }
        pub fn inspectTransactionSource(self: *Self, handle: p.Transaction.Pin, guard: Guard) !Transaction.Source {
            const state = try self.transactionPinState(handle.owner, guard);
            if (state.released) return error.LogTransactionSourceReleased;
            if (!std.meta.eql(state.handle, @as(?p.Transaction.Pin, handle))) return error.LogTransactionSourceNotPinned;
            const source = try Transaction.loadSource(self.objects, handle);
            if (source.root.initialization.partition != self.root.initialization.partition or
                !std.meta.eql(source.root.initialization, self.root.initialization) or source.root.next_lsn > self.root.next_lsn) return error.InvalidLogTransaction;
            try authorize(guard);
            return source;
        }
        pub fn releaseTransactionSource(self: *Self, handle: p.Transaction.Pin, guard: Guard) !void {
            const state = try self.transactionPinState(handle.owner, guard);
            if (!std.meta.eql(state.handle, @as(?p.Transaction.Pin, handle))) return error.LogTransactionSourceNotPinned;
            if (state.released) return;
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.transaction_pins = try self.tree().put(next.transaction_pins, try Evidence.operationKey(handle.owner), try (Transaction.Pin{ .source = handle.content, .released = true }).encode());
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .transaction_release = handle } }, &.{}, guard);
        }
        /// Build an immutable successor while borrowing this serialized owner's
        /// bounded caches. No WAL acceptance or externally visible root changes.
        pub fn evaluateTransaction(self: *Self, handle: p.Transaction.Pin, directory: p.Transaction.Directory, limits: Transaction.EvaluationLimits, authority: ?Read.Authority, guard: Guard) !Transaction.Evaluation {
            try limits.validate();
            if (self.private_position != null) return error.PrivateLogWorkspace;
            if (self.root.transaction != null) return error.TransactionPrepared;
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = limits.resident_bytes };
            const result = self.evaluateTransactionBounded(memory.allocator(), handle, directory, limits, authority, guard) catch |err| return if (memory.exhausted) error.TransactionMemoryLimit else err;
            return .{ .root = result.root, .observed = result.observed, .resident_peak = memory.peak };
        }
        fn evaluateTransactionBounded(self: *Self, allocator: std.mem.Allocator, handle: p.Transaction.Pin, directory: p.Transaction.Directory, limits: Transaction.EvaluationLimits, authority: ?Read.Authority, guard: Guard) !Transaction.Evaluation {
            const source = try self.inspectTransactionSource(handle, guard);
            const basis = try source.guard();
            try basis.requireUnchanged(try Transaction.logGuard(self.root));
            for (self.cache.held) |held| if (held != null) return error.OutstandingTailBorrows;
            var actions = try Actions.init(allocator, self.objects, source.identity, basis, limits.actions, limits.payload_bytes, 1, self.options.index_work_bytes);
            defer actions.deinit();
            try actions.restore(directory);
            try actions.verify();
            if (actions.root.last == null or actions.root.last.?.cursor.sequence > limits.last_statement) return error.InvalidTransactionActions;
            // Settlement-only actions need no append buffer. A verified action
            // directory bounds each append by its total retained payload bytes;
            // large directories still use at most one ordinary batch buffer.
            const buffer = try allocator.alloc(u8, @intCast(@min(self.options.batch_bytes, actions.root.payload_bytes)));
            defer allocator.free(buffer);
            const observed = try Time.bounds(self.options.clock, self.root.clock_ms, false);
            var fixed_time: Transaction.FixedTime = .{ .value = observed orelse .exact(0) };
            const saved_root = self.root;
            const saved_options = self.options;
            const saved_allocator = self.allocator;
            const saved_scratch = self.scratch;
            const saved_index_allocator = self.store.allocator;
            const prospective = try self.nextPosition();
            const ordinary = self.enterControl(false);
            self.private_position = prospective;
            self.allocator = allocator;
            self.store.allocator = allocator;
            self.scratch = .init(allocator);
            self.options.clock = if (observed != null) fixed_time.source() else null;
            defer {
                self.root = saved_root;
                self.options = saved_options;
                self.allocator = saved_allocator;
                self.store.allocator = saved_index_allocator;
                self.scratch.deinit();
                self.scratch = saved_scratch;
                self.private_position = null;
                self.leaveControl(ordinary);
                self.store.clearCache();
                if (kind == .queue) {
                    self.queue_deadlines.clear();
                    self.queue_visibility.reset(null, 0, saved_root.clock_ms orelse 0);
                    self.queue_affinity.clear();
                }
            }
            var after: ?Actions.Cursor = null;
            while (true) {
                const page = try actions.page(after);
                for (page.entries) |entry| if (entry) |value| {
                    const work = value.work;
                    if (try self.original(Actions.operation(work)) != null) return error.TransactionIdentityConflict;
                    switch (work.action) {
                        .append => |request| {
                            const payload = try actions.readPayload(work, buffer);
                            _ = try self.append(source.root.declared, request, payload, guard);
                        },
                        .queue_transfer_append => |transfer| {
                            const payload = try actions.readPayload(work, buffer);
                            _ = try self.append(source.root.declared, transfer.destination, payload, guard);
                        },
                        .stream_offset => |request| {
                            _ = try self.commitOffset(source.root.declared, request, value.offset_cursor orelse return error.InvalidTransactionActions, authority orelse return error.InvalidStreamReadAuthority, guard);
                        },
                        .queue_ack => |request| {
                            if (kind != .queue) return error.InvalidTransactionActions;
                            _ = try self.settle(source.root.declared, request, guard);
                        },
                        .queue_terminal => |request| {
                            if (kind != .queue) return error.InvalidTransactionActions;
                            _ = try self.transferPrivate(source.root.declared, request, guard);
                        },
                    }
                };
                after = page.next orelse break;
            }
            try authorize(guard);
            return .{ .root = self.root, .observed = observed, .resident_peak = 0 };
        }
        fn transactionBarrier(preparation: Transaction.Preparation, reference: Transaction.Reference) !Root {
            var barrier = preparation.predecessor;
            barrier.next_lsn = (try preparation.prepared(reference)).position.next_lsn;
            barrier.transaction = reference;
            barrier.maintenance = try @import("StreamMaintenanceState.zig").transition(preparation.predecessor, barrier, @as(@FieldType(r.Record, "action"), .transaction_prepare));
            return barrier;
        }
        fn transactionSuccessor(before: Root, preparation: Transaction.Preparation) !Root {
            var next = preparation.successor;
            next.next_lsn = try std.math.add(u64, before.next_lsn, 1);
            next.changed_lsn = next.next_lsn;
            next.transaction = null;
            return next;
        }
        fn requireTransactionTransition(self: *Self, record: r.Record) !void {
            // A terminal transfer exists only inside a private successor whose
            // paired destination append shares the transaction's decision.
            if (record.action == .operation and record.action.operation.outcome == .terminal) return error.InvalidLogPreparation;
            const before = self.root;
            const after = record.root;
            const reference = if (record.action == .transaction_prepare) after.transaction else before.transaction;
            if (reference) |ref| {
                const preparation = try Transaction.loadPreparation(self.objects, ref);
                if (record.action != .transaction_prepare and !std.meta.eql(before, try transactionBarrier(preparation, ref))) return error.InvalidLogPreparation;
                var expected = before;
                expected.next_lsn = try std.math.add(u64, before.next_lsn, 1);
                switch (record.action) {
                    .transaction_prepare => {
                        if (before.transaction != null or !std.meta.eql(before, preparation.predecessor) or
                            after.next_lsn != (try preparation.prepared(ref)).position.next_lsn) return error.InvalidLogPreparation;
                        var journal = try @import("TransactionDecisionLog.zig").init(self.allocator, self.log, self.objects, preparation.coordination, preparation.binding);
                        try journal.recover();
                        if (journal.next_lsn == 0) return error.TransactionNotFrozen;
                        expected.transaction = ref;
                    },
                    .transaction_commit, .transaction_abort => |resolution| {
                        if (!std.meta.eql(ref, resolution.prepared)) return error.InvalidLogPreparation;
                        const decision = try Transaction.decision(self.allocator, self.log, self.objects, preparation, ref) orelse return error.TransactionPrepared;
                        if (!std.meta.eql(decision, resolution.decision) or
                            (record.action == .transaction_commit) != (decision.outcome == .committed)) return error.InvalidTransactionDecision;
                        if (decision.outcome == .committed) expected = try transactionSuccessor(before, preparation) else expected.transaction = null;
                    },
                    else => return error.TransactionPrepared,
                }
                expected.maintenance = try @import("StreamMaintenanceState.zig").transition(before, expected, record.action);
                if (!std.meta.eql(expected, after)) return error.InvalidLogPreparation;
            } else if (record.action == .transaction_prepare or record.action == .transaction_commit or
                record.action == .transaction_abort or after.transaction != null) return error.InvalidLogPreparation;
        }

        /// Accept one immutable successor behind a barrier. The host must retain
        /// the frozen attempt and serialize all selected owners and policy edits.
        pub fn prepareTransaction(self: *Self, binding: @import("TransactionDecisionLog.zig").Binding, coordination: u64, basis: p.Transaction.LogGuard, pin: p.Transaction.Pin, directory: p.Transaction.Directory, limits: Transaction.EvaluationLimits, authority: ?Read.Authority, guard: Guard) !p.Transaction.Prepared {
            if (self.private_position != null) return error.PrivateLogWorkspace;
            try binding.validate();
            try limits.validate();
            try authorize(guard);
            if (!self.ready or try self.log.tail(self.root.initialization.partition) != self.root.next_lsn) return error.LogRecoveryRequired;
            if (self.root.transaction) |reference| {
                const prior_preparation = try Transaction.loadPreparation(self.objects, reference);
                if (!std.meta.eql(prior_preparation.binding, binding) or prior_preparation.coordination != coordination or
                    !std.meta.eql(prior_preparation.guard, basis) or !std.meta.eql(prior_preparation.source, pin) or
                    !std.meta.eql(prior_preparation.actions, directory)) return error.TransactionPrepared;
                try authorize(guard);
                return prior_preparation.prepared(reference);
            }
            if (limits.resident_bytes > binding.begin.limits.resident_bytes or limits.payload_bytes > binding.begin.limits.workspace_bytes or
                limits.actions > binding.begin.limits.workspace_bytes or limits.last_statement != binding.attempt.last_statement) return error.InvalidTransactionLimits;
            const source = try self.inspectTransactionSource(pin, guard);
            if (!std.meta.eql(source.identity, binding.begin.identity) or !std.meta.eql(try source.guard(), basis)) return error.InvalidLogPreparation;
            try basis.requireUnchanged(try Transaction.logGuard(self.root));
            var journal = try @import("TransactionDecisionLog.zig").init(self.allocator, self.log, self.objects, coordination, binding);
            try journal.recover();
            if (journal.next_lsn != 1) return error.TransactionNotFrozen;
            var selected = try @import("TransactionDirectory.zig").init(self.allocator, self.objects, binding.begin.identity, .participants, binding.begin.limits.participants, 1, self.options.index_work_bytes);
            defer selected.deinit();
            try selected.restore(binding.attempt.participants);
            const participant = (try selected.get((p.Transaction.Guard{ .log = basis }).target()) orelse return error.TransactionObjectNotSelected).participant;
            if (participant != .log or !std.meta.eql(participant.log.guard, basis) or
                !std.meta.eql(participant.log.actions, @as(?p.Transaction.Directory, directory))) return error.InvalidLogPreparation;
            const evaluated = try self.evaluateTransaction(pin, directory, limits, authority, guard);
            const preparation: Transaction.Preparation = .{
                .definition = p.Growth.current_definition,
                .coordination = coordination,
                .binding = binding,
                .guard = basis,
                .source = pin,
                .actions = directory,
                .predecessor = self.root,
                .successor = evaluated.root,
                .observed = evaluated.observed,
            };
            const reference = try Transaction.stagePreparation(self.objects, preparation);
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.transaction = reference;
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .transaction_prepare }, &.{}, guard);
            return preparation.prepared(reference);
        }

        /// Called with a borrowed view of the host's already-held common guard.
        /// It cannot reacquire the underlying lock. Current names/rights remain the host's
        /// responsibility; live ACK leases are checked here immediately before
        /// the decision. Recovery never calls this time-sensitive check.
        pub fn verifyPrepared(self: *Self, expected: p.Transaction.Prepared, held_guard: Guard) !Transaction.DecisionTime {
            try authorize(held_guard);
            if (!self.ready or self.private_position != null or try self.log.tail(self.root.initialization.partition) != self.root.next_lsn) return error.LogRecoveryRequired;
            const reference = self.root.transaction orelse return error.InvalidLogPreparation;
            const preparation = try Transaction.loadPreparation(self.objects, reference);
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = @intCast(preparation.binding.begin.limits.resident_bytes) };
            const saved_allocator = self.allocator;
            const saved_scratch = self.scratch;
            const saved_index_allocator = self.store.allocator;
            self.allocator = memory.allocator();
            self.store.allocator = self.allocator;
            self.scratch = .init(self.allocator);
            defer {
                self.allocator = saved_allocator;
                self.store.allocator = saved_index_allocator;
                self.scratch.deinit();
                self.scratch = saved_scratch;
                self.store.clearCache();
            }
            return self.verifyPreparedBounded(expected, preparation, reference, held_guard) catch |err| return if (memory.exhausted) error.TransactionMemoryLimit else err;
        }
        fn verifyPreparedBounded(self: *Self, expected: p.Transaction.Prepared, preparation: Transaction.Preparation, reference: Transaction.Reference, held_guard: Guard) !Transaction.DecisionTime {
            if (!std.meta.eql(expected, try preparation.prepared(reference))) return error.InvalidLogPreparation;
            if (!std.meta.eql(try transactionBarrier(preparation, reference), self.root)) return error.InvalidLogPreparation;
            const pinned = try Transaction.Pin.decode(try self.tree().get(self.root.transaction_pins, try Evidence.operationKey(preparation.source.owner)) orelse return error.LogTransactionSourceNotPinned);
            if (pinned.released or !std.meta.eql(pinned.source, preparation.source.content)) return error.LogTransactionSourceNotPinned;
            const source = try Transaction.loadSource(self.objects, preparation.source);
            if (!std.meta.eql(source.identity, preparation.binding.begin.identity) or !std.meta.eql(try source.guard(), preparation.guard)) return error.InvalidLogPreparation;
            var actions = try Actions.init(self.allocator, self.objects, preparation.binding.begin.identity, preparation.guard, preparation.actions.count, preparation.binding.begin.limits.workspace_bytes, 1, self.options.index_work_bytes);
            defer actions.deinit();
            try actions.restore(preparation.actions);
            try actions.verify();
            const now = try Time.bounds(self.options.clock, preparation.successor.clock_ms, preparation.guard.kind == .queue);
            var check: Transaction.DecisionTime = .{ .reference = reference, .floor_ms = if (now) |sample| sample.latest_ms else preparation.successor.clock_ms };
            var after: ?Actions.Cursor = null;
            while (true) {
                const page = try actions.page(after);
                for (page.entries) |entry| if (entry) |value| switch (value.work.action) {
                    .queue_ack => |request| {
                        if (kind != .queue) return error.InvalidTransactionActions;
                        var bitmap: Bitmap = undefined;
                        const index = self.queueIndex(&bitmap);
                        const item = try index.item(self.root.queue.?, request.lease.offset);
                        _ = try item.settle(try index.state(self.root.queue.?, item), request, self.root.declared.declaration.configuration.policy.queue, now.?);
                        check.lease_expires_ms = @min(check.lease_expires_ms orelse std.math.maxInt(u64), request.lease.expires_ms);
                    },
                    .append, .queue_transfer_append => {
                        if (preparation.observed) |observed| if (self.root.declared.declaration.configuration.retention.max_age_ms) |age| {
                            if (now.?.latest_ms - observed.latest_ms >= age) return error.LogRetentionWindowElapsed;
                            // An overflowing expiry lies beyond representable
                            // time and cannot expire within this clock domain.
                            if (std.math.add(u64, observed.latest_ms, age)) |expires| {
                                check.append_expires_ms = @min(check.append_expires_ms orelse std.math.maxInt(u64), expires);
                            } else |_| {}
                        };
                    },
                    .stream_offset => {},
                    .queue_terminal => |request| {
                        if (kind != .queue) return error.InvalidTransactionActions;
                        var bitmap: Bitmap = undefined;
                        const index = self.queueIndex(&bitmap);
                        const offset = transferOffset(request);
                        const item = try index.item(self.root.queue.?, offset);
                        _ = try item.transfer(try index.state(self.root.queue.?, item), request, self.root.declared.declaration.configuration.policy.queue, now.?);
                        try self.verifyTransferPayload(request, self.encoded[0..self.options.batch_bytes], held_guard);
                        switch (request.source) {
                            .nack => |lease| check.lease_expires_ms = @min(check.lease_expires_ms orelse std.math.maxInt(u64), lease.expires_ms),
                            .exhausted => |item_value| check.transfer_not_before_ms = @max(check.transfer_not_before_ms orelse 0, item_value.not_before_ms),
                        }
                    },
                };
                after = page.next orelse break;
            }
            return check;
        }

        /// No allocation or object traversal: the host calls this for every
        /// collected owner immediately before the common decision append.
        pub fn verifyDecisionTime(self: *Self, check: Transaction.DecisionTime) !void {
            if (!self.ready or !std.meta.eql(self.root.transaction, @as(?Transaction.Reference, check.reference))) return error.InvalidLogPreparation;
            if (check.lease_expires_ms == null and check.append_expires_ms == null and check.transfer_not_before_ms == null) return;
            const now = (try Time.bounds(self.options.clock, check.floor_ms, true)).?;
            if (check.lease_expires_ms) |expires| {
                if (now.earliest_ms >= expires) return error.QueueLeaseExpired;
                if (now.latest_ms >= expires) return error.QueueTimeUnavailable;
            }
            if (check.append_expires_ms) |expires| if (now.latest_ms >= expires) return error.LogRetentionWindowElapsed;
            if (check.transfer_not_before_ms) |after| if (now.earliest_ms < after) return error.QueueTimeUnavailable;
        }

        /// Only an actual decision in the frozen coordination log can remove
        /// the barrier. An expired lease after that decision does not undo ACK.
        pub fn resolveTransaction(self: *Self, guard: Guard) !?p.Transaction.Decision {
            if (self.private_position != null) return error.PrivateLogWorkspace;
            try authorize(guard);
            if (!self.ready or try self.log.tail(self.root.initialization.partition) != self.root.next_lsn) return error.LogRecoveryRequired;
            const reference = self.root.transaction orelse return null;
            const preparation = try Transaction.loadPreparation(self.objects, reference);
            const decision = try Transaction.decision(self.allocator, self.log, self.objects, preparation, reference) orelse return error.TransactionPrepared;
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.transaction = null;
            const resolution: r.Resolution = .{ .prepared = reference, .decision = decision };
            if (decision.outcome == .committed) next = try transactionSuccessor(self.root, preparation);
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = if (decision.outcome == .committed) .{ .transaction_commit = resolution } else .{ .transaction_abort = resolution } }, &.{}, guard);
            return decision;
        }
        fn original(self: *Self, identity: d.Operation) !?Evidence.Record {
            try identity.validate();
            if (!std.meta.eql(identity.scope, self.root.initialization.operation.scope)) return error.LogPartitionConflict;
            if (std.meta.eql(identity, self.root.initialization.operation)) return error.LogOperationConflict;
            const value = try self.tree().get(self.root.receipts, try Evidence.operationKey(identity)) orelse return null;
            const record = try self.loadEvidence(value);
            if (!std.meta.eql(record.operation(), identity) or record.accepted().partition != self.root.initialization.partition or record.accepted().next_lsn > self.root.next_lsn) return error.InvalidLogHistory;
            try self.requireTarget(record.target());
            return record;
        }

        /// Exact operation inspection, including receipts from older declarations or
        /// producer epochs. The current guard still applies after buffering the result.
        pub fn operation(self: *Self, identity: d.Operation, guard: Guard) !?Evidence.Record {
            try authorize(guard);
            try self.requireReady();
            const result = try self.original(identity);
            try authorize(guard);
            return result;
        }
        pub fn observe(self: *Self, declared: Declaration.Stored, guard: Guard) !q.Cut {
            try authorize(guard);
            try self.requireReady();
            const result = try self.root.cut(declared);
            try authorize(guard);
            return result;
        }
        fn producerState(self: *Self, request: q.Append) !?q.ProducerState {
            const value = try self.tree().get(self.root.producers, try r.producerKey(request, false)) orelse return null;
            const state = try self.decodeValue(q.ProducerState, value);
            try self.requireTarget(state.target);
            return state;
        }
        fn nextProducer(self: *Self, request: q.Append) !?q.ProducerState {
            const producer = request.producer orelse return null;
            if (try self.producerState(request)) |previous| {
                const disposition = try previous.check(request);
                if (disposition == .retry) return error.LogProducerConflict;
                return .{ .target = request.target, .principal = request.operation.principal, .producer = producer, .discarded_through = if (disposition == .advance_epoch) 0 else previous.discarded_through };
            }
            return try q.ProducerState.initial(request);
        }
        fn progress(self: *Self, id: u64) !?q.GroupProgress {
            if (id == 0) return error.InvalidLogGroup;
            const value = try self.tree().get(self.root.groups, try r.integerKey(id)) orelse return null;
            const result = try self.decodeValue(q.GroupProgress, value);
            try self.requireTarget(result.target);
            if (result.group.id != id or result.next > self.root.next_offset) return error.InvalidLogHistory;
            return result;
        }
        pub fn group(self: *Self, id: u64, guard: Guard) !?q.GroupProgress {
            try authorize(guard);
            try self.requireReady();
            const result = try self.progress(id);
            try authorize(guard);
            return result;
        }

        pub fn append(self: *Self, declared: Declaration.Stored, request: q.Append, payload: []const u8, guard: Guard) !q.AppendReceipt {
            try request.validate();
            try self.requireTarget(request.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(request.operation)) |record| {
                if (record.outcome != .append) return error.LogOperationConflict;
                try record.outcome.append.requireAppend(request);
                if (!std.meta.eql(Batch.content(payload), request.payload)) return error.LogPayloadConflict;
                try authorize(guard);
                return record.outcome.append;
            }
            try self.root.requireDeclaration(declared);
            try request.target.requireSame((try self.root.cut(declared)).target);
            const append_kind: @FieldType(q.Append, "kind") = switch (kind) {
                .stream => .stream,
                .queue => .queue,
            };
            if (request.kind != append_kind) return error.LogPartitionConflict;
            if (payload.len > self.options.batch_bytes) return error.LogAppendLimitExceeded;
            _ = try self.nextProducer(request);
            var declaration = try Declaration.load(self.allocator, self.objects, declared);
            defer declaration.deinit();
            try Batch.validate(payload, &declaration, request, &self.scratch, self.key_buffer);
            const observed_ms = try Time.observe(self.options.clock, self.root.clock_ms, declared.declaration.configuration.retention.max_age_ms != null);
            const receipt: q.AppendReceipt = .{ .append = request, .first = self.root.next_offset, .next = std.math.add(u64, self.root.next_offset, request.rows) catch return error.LogOffsetExhausted, .accepted = try self.nextPosition(), .observed_ms = observed_ms };
            try self.publish(.{ .declared = declared, .outcome = .{ .append = receipt } }, payload, guard);
            return receipt;
        }
        fn queueIndex(self: *Self, bitmap: *Bitmap) QueueIndex {
            bitmap.* = .{ .store = &self.store, .objects = self.objects };
            return .{ .store = &self.store, .scratch = &self.scratch, .bitmap = bitmap, .container = &self.queue_container, .key_buffer = self.key_buffer, .visibility = &self.queue_visibility, .affinity = &self.queue_affinity, .timer_workspace = self.queue_timers, .timer_seed = .{ .definition = p.Growth.current_definition, .interpretation = self.root.initialization.declared.declaration.interpretation, .partition = self.root.initialization.ordinal }, .timer_read_work = self.options.queue_timer_read_work };
        }
        fn persistQueue(self: *Self, next: Root) !void {
            try self.candidate_objects.persistSelected(try QueueSchedule.Buffers.init(next.queue.?.eligible, next.queue.?.deadlines));
        }
        fn queueTime(self: *Self, floor: ?u64) !Time.Sample {
            return (Time.bounds(self.options.clock, floor, true) catch |err| return if (err == error.LogTimeUnavailable) error.QueueTimeUnavailable else err).?;
        }
        pub const ClaimReadiness = struct { available: bool, wake_after_ms: ?u64 };

        pub const DeadLetterCandidate = struct {
            source: @FieldType(@FieldType(p.Transaction.TerminalTransfer, "source"), "exhausted"),
            destination: d.Definition,
        };
        /// A finite metadata sweep, not a retained snapshot. Each call observes
        /// current state. A newly blocked earlier offset belongs to the next
        /// sweep; later appends cannot extend this sweep's fixed upper bound.
        pub const DeadLetterCursor = struct {
            target: q.Partition,
            until: u64,
            next: u64,
            pub fn complete(self: DeadLetterCursor) bool {
                return self.next == self.until;
            }
        };
        pub const DeadLetterPage = struct {
            observed: q.Cut,
            cursor: DeadLetterCursor,
            scanned: u16,
            candidate: ?DeadLetterCandidate,
        };

        /// Returns at most one blocked item's exact accepted exhaustion and
        /// destination. Discovery writes nothing, claims no lease and supplies
        /// no transfer authority. The caller must retain an original attempt
        /// before dispatch and use the common paired transaction decision.
        pub fn deadLetterNext(self: *Self, declared: Declaration.Stored, after: ?DeadLetterCursor, maximum: u16, guard: Guard) !DeadLetterPage {
            if (maximum == 0 or maximum > 256 or maximum > declared.declaration.limits.timer_steps) return error.InvalidQueueTimerBudget;
            try authorize(guard);
            try self.requireReady();
            if (self.private_position != null) return error.PrivateLogWorkspace;
            const observed = try self.root.retainedCut(declared);
            var cursor = after orelse DeadLetterCursor{ .target = observed.target, .until = observed.next, .next = 0 };
            try cursor.target.requireSame(observed.target);
            if (cursor.next > cursor.until or cursor.until > observed.next) return error.InvalidQueueCursor;
            var result: DeadLetterPage = .{ .observed = observed, .cursor = cursor, .scanned = 0, .candidate = null };
            const root = self.root.queue.?;
            if (root.blocked == 0) cursor.next = cursor.until;
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            while (!cursor.complete() and result.scanned < maximum) {
                const item = try index.item(root, cursor.next);
                try item.validate();
                cursor.next += 1;
                result.scanned += 1;
                if (item.blocked != .dead_letter) continue;
                if (try index.state(root, item) != .available or item.offset < observed.retained_from) return error.QueueStateConflict;
                result.candidate = .{
                    .source = .{ .target = observed.target, .offset = item.offset, .lease_epoch = item.epoch, .attempt = item.attempts, .not_before_ms = item.blocked_after_ms.? },
                    .destination = item.blocked.dead_letter,
                };
                break;
            }
            result.cursor = cursor;
            try authorize(guard);
            return result;
        }

        /// No operation binding, selection artifact or WAL record is published.
        /// Hosts serialize this probe with the subsequent claim. Running the
        /// actual selection also preserves budget, capacity and time refusals.
        pub fn claimReadiness(self: *Self, declared: Declaration.Stored, request: q.Claim, guard: Guard) !ClaimReadiness {
            try request.validate();
            try self.requireTarget(request.target);
            try authorize(guard);
            try self.requireReady();
            const now = try self.queueTime(self.root.clock_ms);
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            const leases = try QueueClaims.select(index, self.root, declared, request, now, self.queue_leases);
            const next = if (leases.len == 0) try index.nextVisibleMs(self.root.queue.?) else null;
            try authorize(guard);
            return .{ .available = leases.len != 0, .wake_after_ms = if (next) |at| @max(1, at -| now.earliest_ms) else null };
        }

        pub fn claim(self: *Self, declared: Declaration.Stored, request: q.Claim, guard: Guard) !q.ClaimReceipt {
            return self.claimSelected(declared, request, guard, true);
        }
        pub fn claimNonempty(self: *Self, declared: Declaration.Stored, request: q.Claim, guard: Guard) !q.ClaimReceipt {
            return self.claimSelected(declared, request, guard, false);
        }
        fn claimSelected(self: *Self, declared: Declaration.Stored, request: q.Claim, guard: Guard, accept_empty: bool) !q.ClaimReceipt {
            try request.validate();
            try self.requireTarget(request.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(request.operation)) |record| {
                if (record.outcome != .claim) return error.LogOperationConflict;
                try record.outcome.claim.receipt.requireClaim(request);
                try authorize(guard);
                return record.outcome.claim.receipt;
            }
            const now = try self.queueTime(self.root.clock_ms);
            var bitmap: Bitmap = undefined;
            const leases = try QueueClaims.select(self.queueIndex(&bitmap), self.root, declared, request, now, self.queue_leases);
            // A wider trusted-time interval between readiness and acceptance
            // can withdraw eligibility. Never turn that into an empty claim.
            if (!accept_empty and leases.len == 0) return error.QueueNotEligible;
            const meta = try QueueClaims.metadata(self.root, declared, request, now, @intCast(leases.len));
            const receipt = try QueueClaims.receipt(meta, leases, self.queue_selection);
            if (receipt.leases) |content| {
                const staged = try QueueSelection.stage(self.objects, meta, leases, self.queue_selection);
                if (!std.meta.eql(content, staged)) return error.InvalidQueueSelection;
            }
            try self.publish(.{ .declared = declared, .outcome = .{ .claim = .{ .receipt = receipt, .observed = now } } }, &.{}, guard);
            return receipt;
        }
        fn candidateClaim(self: *Self, evidence: Evidence.Record) !QueueIndex.Root {
            const value = evidence.outcome.claim;
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            const leases = try QueueClaims.select(index, self.root, evidence.declared, value.receipt.claim, value.observed, self.queue_leases);
            const meta = try QueueClaims.metadata(self.root, evidence.declared, value.receipt.claim, value.observed, @intCast(leases.len));
            if (!std.meta.eql(try QueueClaims.receipt(meta, leases, self.queue_selection), value.receipt)) return error.InvalidLogHistory;
            if (value.receipt.leases) |content| {
                defer _ = self.scratch.reset(.retain_capacity);
                const selection = try QueueSelection.load(self.scratch.allocator(), self.objects, content, self.queue_selection);
                try selection.requireReceipt(value.receipt);
                if (!std.meta.eql(selection.metadata, meta)) return error.InvalidLogHistory;
            }
            var next = self.root.queue.?;
            for (leases) |lease| next = try index.acquire(next, lease.offset, value.receipt.claim, evidence.declared.declaration.configuration.policy.queue, value.observed, value.receipt.accepted);
            return next;
        }

        fn requireOriginalClaim(self: *Self, claim_receipt: q.ClaimReceipt) !void {
            const evidence = try self.original(claim_receipt.claim.operation) orelse return error.QueueClaimMissing;
            if (evidence.outcome != .claim) return error.LogOperationConflict;
            try (queue_read.Cursor{ .receipt = claim_receipt, .next = 0 }).requireReceipt(evidence.outcome.claim.receipt);
        }
        fn claimReadReleased(self: *Self, receipt: q.ClaimReceipt) !bool {
            return (try @import("QueueReadRelease.zig").find(self.allocator, &self.store, self.root.queue.?.read_releases, receipt, self.root.position())) != null;
        }
        pub fn releaseClaimRead(self: *Self, declared: Declaration.Stored, request: queue_read.Release, guard: Guard) !queue_read.ReleaseReceipt {
            try request.validate();
            try self.requireTarget(request.claim.claim.target);
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            if (try self.original(request.operation)) |record| {
                if (record.outcome != .queue_release) return error.LogOperationConflict;
                try record.outcome.queue_release.requireRelease(request);
                try authorize(guard);
                return record.outcome.queue_release;
            }
            try self.requireOriginalClaim(request.claim);
            if (try self.claimReadReleased(request.claim)) return error.QueueReadReleased;
            const receipt: queue_read.ReleaseReceipt = .{ .release = request, .accepted = try self.nextPosition() };
            try self.publish(.{ .declared = declared, .outcome = .{ .queue_release = receipt } }, &.{}, guard);
            return receipt;
        }

        pub const ClaimReadLimits = struct { rows: u32 = 256, encoded_bytes: u32 = 1024 * 1024 };
        pub const ClaimReadRow = struct {
            lease: queue_read.LeaseObservation,
            operation: d.Operation,
            ordinal: u32,
            visible_ms: u64,
            encoded: []const u8,
        };
        pub const ClaimReadPage = struct {
            allocator: std.mem.Allocator,
            source: Declaration.Stored,
            basis: queue_read.Basis,
            from: queue_read.Cursor,
            cursor: queue_read.Cursor,
            encoded_bytes: u32,
            entries: []ClaimReadRow,
            len: u32,
            pub fn rows(self: ClaimReadPage) []const ClaimReadRow {
                return self.entries[0..self.len];
            }
            pub fn deinit(self: *ClaimReadPage) void {
                for (self.rows()) |row| self.allocator.free(row.encoded);
                self.allocator.free(self.entries);
                self.* = undefined;
            }
        };
        fn leaseObservation(original_lease: q.Lease, item: @import("QueueItem.zig"), state: @import("Tack.zig").State, basis: queue_read.Basis, receipt: q.ClaimReceipt) !queue_read.LeaseObservation {
            var liveness: queue_read.Liveness = .fenced;
            if (item.lease) |current| if (std.meta.eql(current, original_lease)) {
                liveness = if (basis.time) |time|
                    (if (time.earliest_ms >= current.expires_ms) .expired else if (time.latest_ms < current.expires_ms) .live else .unavailable)
                else
                    .unavailable;
            };
            const result: queue_read.LeaseObservation = .{ .original = original_lease, .state = state, .epoch = item.epoch, .attempt = item.attempts, .expires_ms = if (item.lease) |lease| lease.expires_ms else null, .blocked = item.blocked, .blocked_after_ms = item.blocked_after_ms, .liveness = liveness };
            try result.requireBasis(basis, receipt);
            return result;
        }
        /// Payload belongs to the original immutable selection. Current state is
        /// separately observed; page traversal never acquires or settles work.
        pub fn readClaimPage(self: *Self, declared: Declaration.Stored, cursor: queue_read.Cursor, limits: ClaimReadLimits, output: std.mem.Allocator, guard: Guard) !ClaimReadPage {
            try cursor.validate();
            try self.requireTarget(cursor.receipt.claim.target);
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            if (limits.rows == 0 or limits.rows > QueueSelection.max_rows or limits.encoded_bytes == 0 or limits.encoded_bytes > 64 * 1024 * 1024) return error.InvalidQueueReadBudget;
            const evidence = try self.original(cursor.receipt.claim.operation) orelse return error.QueueClaimMissing;
            if (evidence.outcome != .claim) return error.LogOperationConflict;
            try cursor.requireReceipt(evidence.outcome.claim.receipt);
            if (try self.claimReadReleased(cursor.receipt)) return error.QueueReadReleased;
            var declaration = try Declaration.load(self.allocator, self.objects, evidence.declared);
            defer declaration.deinit();
            if (!std.meta.eql(declared, evidence.declared)) {
                var current = try Declaration.load(self.allocator, self.objects, declared);
                current.deinit();
            }
            const now: ?Time.Sample = self.queueTime(self.root.clock_ms) catch |err| switch (err) {
                error.QueueTimeUnavailable, error.LogTimeRegression => null,
                else => return err,
            };
            const basis: queue_read.Basis = .{ .cut = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = declared.declaration.interpretation, .partition = self.root.initialization.ordinal }, .accepted = self.root.position(), .retained_from = self.root.retained_from, .next = self.root.next_offset }, .time = now };
            try basis.requireReceipt(cursor.receipt);
            const capacity = @min(cursor.receipt.rows - cursor.next, limits.rows, self.options.read_rows, declared.declaration.limits.read_rows);
            const byte_limit = @min(limits.encoded_bytes, self.options.read_bytes, declared.declaration.limits.read_bytes);
            var page: ClaimReadPage = .{ .allocator = output, .source = evidence.declared, .basis = basis, .from = cursor, .cursor = cursor, .encoded_bytes = 0, .entries = try output.alloc(ClaimReadRow, capacity), .len = 0 };
            errdefer page.deinit();
            if (cursor.receipt.leases) |content| {
                const selected = try QueueSelection.load(self.scratch.allocator(), self.objects, content, self.queue_selection);
                _ = self.scratch.reset(.retain_capacity);
                try selected.requireReceipt(cursor.receipt);
                if (!std.meta.eql(selected.metadata.declared, evidence.declared)) return error.InvalidQueueSelection;
                const source = selected.metadata.source;
                const cut: q.Cut = .{ .target = cursor.receipt.claim.target, .accepted = source.accepted, .retained_from = source.retained_from, .next = source.next_offset };
                var bitmap: Bitmap = undefined;
                const index = self.queueIndex(&bitmap);
                while (page.len < capacity) {
                    const lease = try selected.lease(page.cursor.next);
                    const item = try index.item(self.root.queue.?, lease.offset);
                    const observed = try leaseObservation(lease, item, try index.state(self.root.queue.?, item), basis, cursor.receipt);
                    var borrowed = try self.borrowAt(cut, source.batches, source.segments, .empty, lease.offset, guard) orelse return error.QueueItemMissing;
                    defer borrowed.deinit();
                    var rows = try borrowed.iterator(declaration.definition.schema);
                    var found: ?Batch.EncodedRow = null;
                    while (try rows.next()) |row| if (row.ordinal == lease.offset - borrowed.receipt.first) {
                        found = row;
                        break;
                    };
                    const row = found orelse return error.QueueItemMissing;
                    if (row.bytes.len > byte_limit - page.encoded_bytes) {
                        if (page.len == 0) return error.QueueReadBudgetExceeded;
                        break;
                    }
                    page.entries[page.len] = .{ .lease = observed, .operation = borrowed.receipt.append.operation, .ordinal = row.ordinal, .visible_ms = row.visible_ms, .encoded = try output.dupe(u8, row.bytes) };
                    page.len += 1;
                    page.cursor.next += 1;
                    page.encoded_bytes += @intCast(row.bytes.len);
                }
            }
            try authorize(guard);
            return page;
        }

        pub fn settle(self: *Self, declared: Declaration.Stored, request: q.Settlement, guard: Guard) !q.SettlementReceipt {
            try request.validate();
            try self.requireTarget(request.lease.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(request.operation)) |record| {
                if (record.outcome != .settlement) return error.LogOperationConflict;
                try record.outcome.settlement.receipt.requireSettlement(request);
                try authorize(guard);
                return record.outcome.settlement.receipt;
            }
            try self.root.requireControlDeclaration(declared);
            const now = try self.queueTime(self.root.clock_ms);
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            const item = try index.item(self.root.queue.?, request.lease.offset);
            _ = try item.settle(try index.state(self.root.queue.?, item), request, declared.declaration.configuration.policy.queue, now);
            const receipt: q.SettlementReceipt = .{ .settlement = request, .accepted = try self.nextPosition() };
            try self.publish(.{ .declared = declared, .outcome = .{ .settlement = .{ .receipt = receipt, .observed = now } } }, &.{}, guard);
            return receipt;
        }
        fn transferOffset(request: p.Transaction.TerminalTransfer) u64 {
            return switch (request.source) {
                .nack => |lease| lease.offset,
                .exhausted => |item| item.offset,
            };
        }
        fn transferPrivate(self: *Self, declared: Declaration.Stored, request: p.Transaction.TerminalTransfer, guard: Guard) !p.Transaction.TerminalReceipt {
            if (self.private_position == null) return error.PrivateLogWorkspace;
            try request.validate();
            try self.requireTarget(request.target());
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            const now = try self.queueTime(self.root.clock_ms);
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            const item = try index.item(self.root.queue.?, transferOffset(request));
            _ = try item.transfer(try index.state(self.root.queue.?, item), request, declared.declaration.configuration.policy.queue, now);
            // Source borrows own a tail slab. Once verified, the publication
            // buffer can be reused by the terminal record below.
            try self.verifyTransferPayload(request, self.encoded[0..self.options.batch_bytes], guard);
            const receipt: p.Transaction.TerminalReceipt = .{ .transfer = request, .accepted = try self.nextPosition() };
            try self.publish(.{ .declared = declared, .outcome = .{ .terminal = .{ .receipt = receipt, .observed = now } } }, &.{}, guard);
            return receipt;
        }
        /// Re-encode the source's verified logical values under the exact
        /// destination definition and operation. Caller-chosen replacement
        /// payloads cannot terminalize the original source.
        pub fn validateTransferPayload(self: *Self, request: p.Transaction.TerminalTransfer, guard: Guard) !void {
            if (kind != .queue) return error.InvalidTransactionTransfer;
            try request.validate();
            try self.requireTarget(request.target());
            try authorize(guard);
            try self.requireReady();
            // borrowAt pins its own tail slab before returning. Encoding the
            // destination can reuse this owner's publication buffer safely.
            try self.verifyTransferPayload(request, self.encoded[0..self.options.batch_bytes], guard);
            try authorize(guard);
        }
        fn verifyTransferPayload(self: *Self, request: p.Transaction.TerminalTransfer, buffer: []u8, guard: Guard) !void {
            var source = try Declaration.load(self.allocator, self.objects, self.root.declared);
            defer source.deinit();
            var destination = try Declaration.resolve(self.allocator, self.objects, request.destination.target.interpretation);
            defer destination.deinit();
            if (destination.definition.retired or destination.definition.configuration.policy != .queue or
                request.destination.target.partition >= destination.definition.configuration.partitioning.count) return error.InvalidQueueDestination;
            var normalized = destination.definition.schema;
            normalized.object = source.definition.schema.object;
            normalized.revision = source.definition.schema.revision;
            if (!std.mem.eql(u8, &try normalized.fingerprint(), &try source.definition.schema.fingerprint())) return error.QueueDestinationSchemaMismatch;
            const offset = transferOffset(request);
            const cut = try self.root.retainedCut(self.root.declared);
            var borrowed = try self.borrowAt(cut, self.root.batches, self.root.segments, .empty, offset, guard) orelse return error.QueueItemMissing;
            defer borrowed.deinit();
            var rows = try borrowed.iterator(source.definition.schema);
            while (try rows.next()) |row| {
                if (row.ordinal != offset - borrowed.receipt.first) continue;
                defer _ = self.scratch.reset(.retain_capacity);
                const decoded = try row.decode(self.scratch.allocator(), source.definition.schema, borrowed.receipt.append.operation);
                const bytes = try Batch.encode(destination.definition.schema, request.destination.operation, .queue, &.{decoded}, buffer);
                if (!std.meta.eql(Batch.content(bytes), request.destination.payload)) return error.LogPayloadConflict;
                return;
            }
            return error.QueueItemMissing;
        }
        fn queueCanonicalKey(self: *Self, offset: u64, guard: Guard) ![]const u8 {
            const policy = self.root.initialization.declared.declaration.configuration.policy.queue;
            const key_column = policy.key_column orelse return error.InvalidQueueHead;
            var declaration = try Declaration.load(self.allocator, self.objects, self.root.initialization.declared);
            defer declaration.deinit();
            const ci = try declaration.definition.schema.index(key_column);
            const column = declaration.definition.schema.columns[ci];
            const cut: q.Cut = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = self.root.declared.declaration.interpretation, .partition = self.root.initialization.ordinal }, .accepted = self.root.position(), .retained_from = self.root.retained_from, .next = self.root.next_offset };
            var borrowed = try self.borrowAt(cut, self.root.batches, self.root.segments, .empty, offset, guard) orelse return error.QueueItemMissing;
            defer borrowed.deinit();
            var rows = try borrowed.iterator(declaration.definition.schema);
            while (try rows.next()) |row| {
                if (row.ordinal != offset - borrowed.receipt.first) continue;
                defer _ = self.scratch.reset(.retain_capacity);
                const decoded = try row.decode(self.scratch.allocator(), declaration.definition.schema, borrowed.receipt.append.operation);
                return f.Collation.encodeSortKey(decoded.cells[ci], column.type, column.collation, self.key_buffer);
            }
            return error.QueueItemMissing;
        }
        fn candidateSettlement(self: *Self, evidence: Evidence.Record, guard: Guard) !QueueIndex.Root {
            const value = evidence.outcome.settlement;
            const policy = evidence.declared.declaration.configuration.policy.queue;
            const key = if (value.receipt.settlement.action == .ack and policy.ordering == .key_fifo)
                try self.queueCanonicalKey(value.receipt.settlement.lease.offset, guard)
            else
                null;
            var bitmap: Bitmap = undefined;
            return self.queueIndex(&bitmap).settle(self.root.queue.?, value.receipt.settlement, policy, value.observed, value.receipt.accepted, key);
        }

        /// One authoritative deadline transition. A timer may request this work;
        /// only current time and the accepted exact lease authorize reassignment.
        pub fn expireQueueOne(self: *Self, declared: Declaration.Stored, guard: Guard) !bool {
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            const now = try self.queueTime(self.root.clock_ms);
            const expired = try self.queueDeadline(declared, now.earliest_ms) orelse {
                try authorize(guard);
                return false;
            };
            const action: @FieldType(@FieldType(r.Record, "action"), "queue_expire") = .{ .lease = expired, .observed = now };
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            try self.candidate_objects.reset(self.objects);
            self.objects = self.candidate_objects.objectStore();
            self.store.store = self.objects;
            self.store.clearCache();
            defer self.store.clearCache();
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            const next = try self.candidateQueueExpiry(declared, action);
            try self.persistQueue(next);
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .queue_expire = action } }, &.{}, guard);
            return true;
        }
        /// Load only a bounded earliest prefix. A cache miss never limits total
        /// active leases or establishes that the durable directory is empty.
        fn queueDeadline(self: *Self, declared: Declaration.Stored, earliest_ms: u64) !?q.Lease {
            const root = self.root.queue.?;
            const cached = &self.queue_deadlines;
            if (!cached.valid or !std.meta.eql(cached.root, root.items) or (cached.heap.len == 0 and root.active != 0)) {
                cached.clear();
                var bitmap: Bitmap = undefined;
                const index = self.queueIndex(&bitmap);
                var after: ?pages.Key = null;
                const limit = @min(cached.heap.entries.len, declared.declaration.limits.timer_steps);
                while (cached.heap.len < limit) {
                    const item = try index.deadlineAfter(root, after) orelse break;
                    const lease = item.lease.?;
                    try cached.heap.insert(lease);
                    after = try QueueIndex.timedKey(lease.expires_ms, lease.offset);
                }
                if (cached.heap.len == 0 and root.active != 0) return error.InvalidQueueSchedule;
                cached.root = root.items;
                cached.valid = true;
            }
            const lease = cached.heap.peek() orelse return null;
            return if (lease.expires_ms <= earliest_ms) lease else null;
        }

        /// Only an accepted expiry can remove the cached earliest entry while
        /// preserving the rest of its prefix. Every other directory replacement
        /// invalidates the cache. Physical publications can retain the same root.
        fn acceptedDeadlines(self: *Self, record: r.Record) void {
            const cached = &self.queue_deadlines;
            if (!cached.valid) return;
            if (!std.meta.eql(cached.root, self.root.queue.?.items)) {
                cached.clear();
                return;
            }
            if (std.meta.eql(cached.root, record.root.queue.?.items)) return;
            if (record.action == .queue_expire) {
                cached.heap.removeExact(record.action.queue_expire.lease) catch {
                    cached.clear();
                    return;
                };
                cached.root = record.root.queue.?.items;
            } else cached.clear();
        }

        fn candidateQueueExpiry(self: *Self, declared: Declaration.Stored, action: @FieldType(@FieldType(r.Record, "action"), "queue_expire")) !Root {
            try self.root.requireControlDeclaration(declared);
            var declaration = try Declaration.load(self.allocator, self.objects, declared);
            defer declaration.deinit();
            var next = self.root;
            next.clock_ms = try Time.advance(self.root.clock_ms, action.observed.latest_ms);
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            const expired = try index.firstExpired(self.root.queue.?, action.observed.earliest_ms) orelse return error.InvalidQueueExpiration;
            if (!std.meta.eql(expired.lease.?, action.lease)) return error.InvalidQueueExpiration;
            const accepted = try self.nextPosition();
            next.next_lsn = accepted.next_lsn;
            next.declared = declared;
            next.queue = try index.expire(self.root.queue.?, expired.offset, declared.declaration.configuration.policy.queue, action.observed, accepted);
            try next.validate();
            return next;
        }

        /// Scheduling cleanup has its own accepted progress, so recovery and
        /// physical-owner replacement never restart an unbounded merge.
        pub fn scheduleQueueUnit(self: *Self, declared: Declaration.Stored, maximum: u16, guard: Guard) !bool {
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            if (maximum == 0 or maximum > @import("QueueTimeRun.zig").max_rows or maximum > declared.declaration.limits.timer_steps) return error.InvalidQueueTimerBudget;
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            try self.candidate_objects.reset(self.objects);
            self.objects = self.candidate_objects.objectStore();
            self.store.store = self.objects;
            self.store.clearCache();
            defer self.store.clearCache();
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            const first = self.root.queue.?.timer_next;
            const second: @import("QueueTimeRun.zig").Kind = if (first == .visible) .lease else .visible;
            for ([_]@import("QueueTimeRun.zig").Kind{ first, second }) |selected| {
                const action: @FieldType(@FieldType(r.Record, "action"), "queue_schedule") = .{ .kind = selected, .steps = maximum };
                if (try self.candidateQueueSchedule(declared, action)) |next| {
                    try self.persistQueue(next);
                    try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .queue_schedule = action } }, &.{}, guard);
                    return true;
                }
            }
            try authorize(guard);
            return false;
        }
        fn candidateQueueSchedule(self: *Self, declared: Declaration.Stored, action: @FieldType(@FieldType(r.Record, "action"), "queue_schedule")) !?Root {
            try self.root.requireControlDeclaration(declared);
            if (action.steps == 0 or action.steps > declared.declaration.limits.timer_steps or action.steps > @import("QueueTimeRun.zig").max_rows) return error.InvalidQueueTimerBudget;
            var declaration = try Declaration.load(self.allocator, self.objects, declared);
            defer declaration.deinit();
            const current = self.root.queue.?;
            var bitmap: Bitmap = undefined;
            const index = self.queueIndex(&bitmap);
            const selected = if (action.kind == .visible) current.eligible else current.deadlines;
            const scheduled = try index.timers(action.kind).maintain(selected, QueueIndex.timerBasis(current), action.steps, QueueIndex.TimerFilter{ .index = index }) orelse return null;
            var next = self.root;
            next.declared = declared;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            if (action.kind == .visible) next.queue.?.eligible = scheduled else next.queue.?.deadlines = scheduled;
            next.queue.?.timer_next = if (action.kind == .visible) .lease else .visible;
            try next.validate();
            return next;
        }

        pub fn assign(self: *Self, declared: Declaration.Stored, assignment: q.GroupAssignment, guard: Guard) !q.GroupAssignmentReceipt {
            try assignment.validate();
            try self.requireTarget(assignment.cut.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(assignment.operation)) |record| {
                if (record.outcome != .assignment) return error.LogOperationConflict;
                try record.outcome.assignment.requireAssignment(assignment);
                try authorize(guard);
                return record.outcome.assignment;
            }
            try assignment.requireCurrent(try self.progress(assignment.group.id), try self.root.cut(declared));
            const receipt: q.GroupAssignmentReceipt = .{ .assignment = assignment, .accepted = try self.nextPosition() };
            try self.publish(.{ .declared = declared, .outcome = .{ .assignment = receipt } }, &.{}, guard);
            return receipt;
        }

        fn requireGroup(self: *Self, selected: q.Group, expected_next: ?u64) !q.GroupProgress {
            const current = try self.progress(selected.id) orelse return error.LogGroupFenced;
            if (!std.meta.eql(current.group, selected)) return error.LogGroupFenced;
            if (expected_next) |next| if (current.next != next) return error.LogOffsetConflict;
            return current;
        }
        fn loadRead(self: *Self, handle: read.Handle) !Read.Basis {
            defer _ = self.scratch.reset(.retain_capacity);
            return Read.load(self.scratch.allocator(), self.objects, handle);
        }
        fn activePin(self: *Self, handle: read.Handle) !Read.Pin {
            try handle.validate();
            const value = try self.tree().get(self.root.pins, try Evidence.operationKey(handle.owner)) orelse return error.StreamReadMissing;
            const pin = try Read.Pin.decode(value);
            if (!std.meta.eql(pin.source, handle.source)) return error.StreamReadConflict;
            if (pin.released) return error.StreamReadReleased;
            return pin;
        }
        const RetainedRead = struct { receipt: read.Receipt, basis: Read.Basis };
        fn retainedRead(self: *Self, handle: read.Handle) !RetainedRead {
            _ = try self.activePin(handle);
            const original_read = try self.original(handle.owner) orelse return error.StreamReadMissing;
            if (original_read.outcome != .read) return error.StreamReadConflict;
            const receipt = original_read.outcome.read;
            if (!std.meta.eql(receipt.handle(), handle)) return error.StreamReadConflict;
            try self.requireTarget(receipt.cut.target);
            const basis = try self.loadRead(handle);
            if (!std.meta.eql(try basis.receipt(handle.source), receipt) or receipt.cut.accepted.partition != self.root.initialization.partition or receipt.accepted.next_lsn > self.root.next_lsn) return error.InvalidLogHistory;
            return .{ .receipt = receipt, .basis = basis };
        }
        fn readBasis(self: *Self, declared: Declaration.Stored, request: read.Request) !Read.Basis {
            try request.validate();
            const cut = try self.root.cut(declared);
            try request.target.requireSame(cut.target);
            if (request.from < cut.retained_from) return error.LogRangeExpired;
            try cut.requireOffset(request.from);
            if (request.group) |selected| _ = try self.requireGroup(selected, request.from);
            const basis: Read.Basis = .{ .request = request, .declared = declared, .cut = cut, .until = request.until orelse cut.next, .batches = self.root.batches, .segments = self.root.segments, .hidden = self.root.hidden };
            try basis.validate();
            return basis;
        }
        pub fn beginRead(self: *Self, declared: Declaration.Stored, request: read.Request, guard: Guard) !read.Receipt {
            try request.validate();
            try self.requireTarget(request.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(request.operation)) |record| {
                if (record.outcome != .read) return error.LogOperationConflict;
                try record.outcome.read.requireRequest(request);
                try authorize(guard);
                return record.outcome.read;
            }
            const basis = try self.readBasis(declared, request);
            const receipt = try Read.stage(self.objects, basis);
            try self.publish(.{ .declared = declared, .outcome = .{ .read = receipt } }, &.{}, guard);
            return receipt;
        }
        pub fn releaseRead(self: *Self, declared: Declaration.Stored, request: read.Release, guard: Guard) !read.ReleaseReceipt {
            try request.validate();
            try self.requireTarget(request.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(request.operation)) |record| {
                if (record.outcome != .release) return error.LogOperationConflict;
                try record.outcome.release.requireRelease(request);
                try authorize(guard);
                return record.outcome.release;
            }
            try self.root.requireControlDeclaration(declared);
            const retained = try self.retainedRead(request.read);
            try request.target.requireSame(retained.receipt.request.target);
            const receipt: read.ReleaseReceipt = .{ .release = request, .accepted = try self.nextPosition() };
            try self.publish(.{ .declared = declared, .outcome = .{ .release = receipt } }, &.{}, guard);
            return receipt;
        }
        fn advanceGroup(self: *Self, commit: q.OffsetCommit, cursor: read.Cursor) !q.GroupProgress {
            try commit.validate();
            const retained = try self.retainedRead(cursor.read);
            try cursor.requireReceipt(retained.receipt);
            if (!std.meta.eql(commit.coverage, cursor.coverage)) return error.LogOffsetConflict;
            const selected = retained.receipt.request.group orelse return error.LogGroupRequired;
            if (!std.meta.eql(selected, commit.group)) return error.LogGroupFenced;
            return (try self.requireGroup(commit.group, commit.expected_next)).advance(commit);
        }
        pub fn commitOffset(self: *Self, declared: Declaration.Stored, commit: q.OffsetCommit, cursor: read.Cursor, authority: Read.Authority, guard: Guard) !q.OffsetReceipt {
            try commit.validate();
            try cursor.validate();
            try self.requireTarget(commit.coverage.cut.target);
            try authorize(guard);
            try self.requireReady();
            if (try self.original(commit.operation)) |record| {
                if (record.outcome != .offset) return error.LogOperationConflict;
                try record.outcome.offset.receipt.requireCommit(commit);
                if (!std.meta.eql(record.outcome.offset.cursor, cursor)) return error.LogOffsetConflict;
                try authorize(guard);
                return record.outcome.offset.receipt;
            }
            try self.root.requireControlDeclaration(declared);
            try authority.verify(cursor);
            _ = try self.advanceGroup(commit, cursor);
            const receipt: q.OffsetReceipt = .{ .commit = commit, .accepted = try self.nextPosition() };
            try self.publish(.{ .declared = declared, .outcome = .{ .offset = .{ .receipt = receipt, .cursor = cursor } } }, &.{}, guard);
            return receipt;
        }
        fn nextPosition(self: *Self) !d.Position {
            if (self.private_position) |position| return position;
            return .{ .partition = self.root.initialization.partition, .next_lsn = std.math.add(u64, self.root.next_lsn, 1) catch return error.LogPositionExhausted };
        }
        fn putGroup(self: *Self, next: *Root, previous: ?q.GroupProgress, updated: q.GroupProgress) !void {
            const value = try r.valueEncode(updated);
            const key = try r.groupOffsetKey(updated);
            next.groups = try self.tree().put(next.groups, try r.integerKey(updated.group.id), value);
            if (previous) |old| {
                const old_key = try r.groupOffsetKey(old);
                if (!std.meta.eql(old_key, key)) next.group_offsets = try self.tree().remove(next.group_offsets, old_key);
            }
            next.group_offsets = try self.tree().put(next.group_offsets, key, value);
        }
        fn verifyGroup(self: *Self, next: Root, previous: ?q.GroupProgress, updated: q.GroupProgress) !void {
            const value = try r.valueEncode(updated);
            const key = try r.groupOffsetKey(updated);
            try self.verifyValue(next.groups, try r.integerKey(updated.group.id), value);
            try self.verifyValue(next.group_offsets, key, value);
            if (previous) |old| {
                const old_key = try r.groupOffsetKey(old);
                if (!std.meta.eql(old_key, key) and try self.tree().get(next.group_offsets, old_key) != null) return error.InvalidLogHistory;
            }
        }
        fn protectedOffset(self: *Self) !u64 {
            const page = try self.tree().scan(self.root.group_offsets, null);
            if (page.entries[0]) |entry| {
                const selected = try self.decodeValue(q.GroupProgress, entry.value);
                const current = try self.progress(selected.group.id) orelse return error.InvalidLogHistory;
                if (!std.meta.eql(entry.key, try r.groupOffsetKey(selected)) or !std.meta.eql(selected, current) or selected.next < self.root.retained_from or selected.next > self.root.next_offset) return error.InvalidLogHistory;
                return selected.next;
            }
            if (self.root.groups != null) return error.InvalidLogHistory;
            return self.root.next_offset;
        }
        fn candidate(self: *Self, evidence: Evidence.Record, payload: []const u8, guard: Guard) !Root {
            try evidence.validate();
            if (evidence.outcome == .offset or evidence.outcome == .release or evidence.outcome == .settlement or evidence.outcome == .terminal or evidence.outcome == .queue_release)
                try self.root.requireControlDeclaration(evidence.declared)
            else
                try self.root.requireDeclaration(evidence.declared);
            try self.requireTarget(evidence.target());
            if (!std.meta.eql(evidence.accepted(), try self.nextPosition()) or try self.original(evidence.operation()) != null) return error.InvalidLogHistory;
            var queue_declaration: if (kind == .queue) Declaration.Owned else void = if (kind == .queue)
                try Declaration.load(self.allocator, self.objects, evidence.declared)
            else {};
            defer if (kind == .queue) queue_declaration.deinit();
            const reference = try Evidence.stage(self.objects, evidence);
            var result = self.root;
            result.declared = evidence.declared;
            result.next_lsn = evidence.accepted().next_lsn;
            result.receipts = try self.tree().put(result.receipts, try Evidence.operationKey(evidence.operation()), reference);
            switch (evidence.outcome) {
                .queue_release => |receipt| if (kind == .queue) {
                    try self.requireOriginalClaim(receipt.release.claim);
                    if (try self.claimReadReleased(receipt.release.claim)) return error.QueueReadReleased;
                    result.queue.?.read_releases = try self.tree().put(result.queue.?.read_releases, try Evidence.operationKey(receipt.release.claim.claim.operation), reference);
                } else return error.InvalidLogHistory,
                .claim => |value| if (kind == .queue) {
                    result.clock_ms = try Time.advance(self.root.clock_ms, value.observed.latest_ms);
                    result.queue = try self.candidateClaim(evidence);
                } else return error.InvalidLogHistory,
                .settlement => |value| if (kind == .queue) {
                    result.clock_ms = try Time.advance(self.root.clock_ms, value.observed.latest_ms);
                    result.queue = try self.candidateSettlement(evidence, guard);
                } else return error.InvalidLogHistory,
                .terminal => |value| if (kind == .queue) {
                    result.clock_ms = try Time.advance(self.root.clock_ms, value.observed.latest_ms);
                    const request = value.receipt.transfer;
                    const offset = switch (request.source) {
                        .nack => |lease| lease.offset,
                        .exhausted => |item| item.offset,
                    };
                    const policy = evidence.declared.declaration.configuration.policy.queue;
                    const key = if (policy.ordering == .key_fifo) try self.queueCanonicalKey(offset, guard) else null;
                    var bitmap: Bitmap = undefined;
                    result.queue = try self.queueIndex(&bitmap).transfer(self.root.queue.?, request, policy, value.observed, value.receipt.accepted, key);
                } else return error.InvalidLogHistory,
                .append => |receipt| {
                    if (receipt.first != self.root.next_offset) return error.InvalidLogHistory;
                    result.clock_ms = try Time.advance(self.root.clock_ms, receipt.observed_ms);
                    result.next_offset = receipt.next;
                    result.batches = try self.tree().put(result.batches, try r.integerKey(receipt.next), reference);
                    if (try self.nextProducer(receipt.append)) |producer| {
                        result.producers = try self.tree().put(result.producers, try r.producerKey(receipt.append, false), try r.valueEncode(producer));
                        result.producer_receipts = try self.tree().put(result.producer_receipts, try r.producerKey(receipt.append, true), reference);
                    }
                    if (kind == .queue) {
                        var bitmap: Bitmap = .{ .store = &self.store, .objects = self.objects };
                        const index = self.queueIndex(&bitmap);
                        result.queue = try index.enqueue(self.root.queue.?, &queue_declaration, receipt, payload);
                    }
                },
                .assignment => |receipt| {
                    const assignment = receipt.assignment;
                    try assignment.requireCurrent(try self.progress(assignment.group.id), try self.root.cut(evidence.declared));
                    try self.putGroup(&result, assignment.expected, try assignment.resulting());
                },
                .read => |receipt| {
                    const expected = try self.readBasis(evidence.declared, receipt.request);
                    if (!std.meta.eql(expected, try self.loadRead(receipt.handle())) or !std.meta.eql(try expected.receipt(receipt.source), receipt)) return error.InvalidLogHistory;
                    result.pins = try self.tree().put(result.pins, try Evidence.operationKey(receipt.request.operation), try (Read.Pin{ .source = receipt.source, .released = false }).encode());
                },
                .release => |receipt| {
                    const retained = try self.retainedRead(receipt.release.read);
                    try receipt.release.target.requireSame(retained.receipt.request.target);
                    result.pins = try self.tree().put(result.pins, try Evidence.operationKey(receipt.release.read.owner), try (Read.Pin{ .source = receipt.release.read.source, .released = true }).encode());
                },
                .offset => |value| {
                    const advanced = try self.advanceGroup(value.receipt.commit, value.cursor);
                    try self.putGroup(&result, try self.progress(advanced.group.id), advanced);
                },
            }
            try result.validate();
            return result;
        }
        fn publish(self: *Self, evidence: Evidence.Record, payload: []const u8, guard: Guard) !void {
            const reserve = switch (evidence.outcome) {
                .release, .offset, .settlement, .terminal, .queue_release => true,
                .assignment => |value| value.assignment.expected != null,
                .append, .read, .claim => false,
            };
            const ordinary = self.enterControl(reserve);
            defer self.leaveControl(ordinary);
            if (kind == .queue) {
                try self.candidate_objects.reset(self.objects);
                self.objects = self.candidate_objects.objectStore();
                self.store.store = self.objects;
                self.store.clearCache();
            }
            defer if (kind == .queue) self.store.clearCache();
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var next = try self.candidate(evidence, payload, guard);
            if (self.private_position != null and evidence.outcome == .append) {
                var declaration = try Declaration.load(self.allocator, self.objects, evidence.declared);
                defer declaration.deinit();
                const segment = try Segment.stage(self.allocator, self.objects, &declaration, evidence, payload, self.options.segment_rows_per_group);
                next.segments = try self.tree().put(next.segments, try r.integerKey(evidence.outcome.append.next), try segment.encode());
                if (next.sealed_through == evidence.outcome.append.first) next.sealed_through = evidence.outcome.append.next;
            }
            const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .operation = evidence } };
            if (kind == .queue) try self.persistQueue(next);
            try self.publishRecord(record, payload, guard);
            // Cache admission is optional after acceptance. Pressure cannot turn an
            // accepted append into rejection; reads can load its verified WAL payload.
            if (self.private_position == null and evidence.outcome == .append) self.cache.admit(.{ .position = evidence.accepted(), .first = evidence.outcome.append.first, .content = evidence.outcome.append.append.payload }, payload) catch {};
        }
        fn publishRecord(self: *Self, input: r.Record, payload: []const u8, guard: Guard) !void {
            var record = input;
            record.root.changed_lsn = if (record.changesData()) record.root.next_lsn else self.root.changed_lsn;
            record.root.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, record.root, record.action);
            const next = record.root;
            if (next.next_lsn != (try self.nextPosition()).next_lsn or !std.mem.eql(u8, &record.previous, &self.commitment)) return error.InvalidLogHistory;
            if (self.private_position != null) {
                if (record.action != .operation) return error.PrivateLogWorkspace;
                try record.validate(next.next_lsn - 1);
                try authorize(guard);
                self.root = next;
                return;
            }
            try self.requireTransactionTransition(record);
            const bytes = try r.encode(record, payload, self.encoded);
            const fence = try guard.acquire(guard.context);
            defer guard.release(guard.context);
            if (fence.writer_epoch == 0 or fence.policy_epoch == 0) return error.InvalidWalEpoch;
            if (record.action == .operation and record.action.operation.outcome == .append) {
                const observed_ms = record.action.operation.outcome.append.observed_ms;
                if (observed_ms != null) {
                    const now = (try Time.observe(self.options.clock, observed_ms, true)).?;
                    if (record.root.declared.declaration.configuration.retention.max_age_ms) |age| if (now - observed_ms.? >= age) return error.LogRetentionWindowElapsed;
                }
            }
            if (record.action == .expire) {
                const now = (try Time.bounds(self.options.clock, record.root.clock_ms, true)).?;
                if (now.earliest_ms < record.action.expire.observed_ms) return error.LogTimeRegression;
            }
            if (record.action == .queue_expire) {
                const value = record.action.queue_expire;
                const now = try self.queueTime(value.observed.latest_ms);
                if (now.earliest_ms < value.lease.expires_ms) return error.QueueTimeUnavailable;
            }
            if (record.action == .operation and record.action.operation.outcome == .claim) {
                const claim_value = record.action.operation.outcome.claim;
                const now = try self.queueTime(claim_value.observed.latest_ms);
                if (now.earliest_ms < claim_value.observed.earliest_ms) return error.LogTimeRegression;
                if (claim_value.receipt.rows != 0) {
                    if (now.earliest_ms >= claim_value.receipt.expires_ms) return error.QueueLeaseExpired;
                    if (now.latest_ms >= claim_value.receipt.expires_ms) return error.QueueTimeUnavailable;
                }
            }
            if (record.action == .operation and record.action.operation.outcome == .settlement) {
                const value = record.action.operation.outcome.settlement;
                const now = try self.queueTime(value.observed.latest_ms);
                try value.receipt.settlement.requireLive(value.receipt.settlement.lease, now.earliest_ms);
                if (now.latest_ms >= value.receipt.settlement.lease.expires_ms) return error.QueueTimeUnavailable;
            }
            const receipt = self.log.append(next.initialization.partition, self.root.next_lsn, fence.writer_epoch, fence.policy_epoch, record.frameKind(), bytes) catch |err| {
                self.ready = false;
                return switch (err) {
                    error.StaleWriterEpoch, error.StalePolicyEpoch => err,
                    else => error.LogAppendUncertain,
                };
            };
            if (receipt.partition_id != next.initialization.partition or receipt.lsn != self.root.next_lsn or receipt.next_lsn != next.next_lsn or receipt.writer_epoch != fence.writer_epoch or receipt.policy_epoch != fence.policy_epoch) {
                self.ready = false;
                return error.LogAppendUncertain;
            }
            if (kind == .queue) self.acceptedDeadlines(record);
            self.root = next;
            self.commitment = Evidence.hash(bytes);
        }

        fn historyFrame(self: *Self, lsn: u64) !Log.Log.OwnedBatch {
            if (lsn < self.root.archive.through) return History.read(self.allocator, &self.store, self.root.archive, self.root.initialization.partition, lsn);
            return self.log.read(self.allocator, self.root.initialization.partition, lsn, 1);
        }

        pub const ArchiveProgress = struct { through: d.Position, frames: u8, encoded_bytes: u64, complete: bool };

        pub const FlushProgress = struct { cut: d.Position, through: u64, rows: u32, complete: bool };
        fn flushCandidate(self: *Self, through: u64, cut: d.Position) !?Evidence.Record {
            if (through == self.root.next_offset) return null;
            const page = try self.tree().scanFrom(self.root.batches, try r.integerKey(through + 1));
            const entry = page.entries[0] orelse return error.LogHistoryUnavailable;
            const evidence = try self.loadEvidence(entry.value);
            if (evidence.outcome != .append) return error.InvalidLogHistory;
            const receipt = evidence.outcome.append;
            if (receipt.first != through or receipt.next > self.root.next_offset or receipt.accepted.partition != cut.partition or !std.meta.eql(entry.key, try r.integerKey(receipt.next))) return error.InvalidLogHistory;
            return if (receipt.accepted.next_lsn <= cut.next_lsn) evidence else null;
        }
        /// Seal one accepted append under a fixed physical cut. Publication changes
        /// placement only; existing pins retain their exact placement directories.
        pub fn flush(self: *Self, cut: d.Position, guard: Guard) !FlushProgress {
            try cut.validate();
            try authorize(guard);
            try self.requireReady();
            if (cut.partition != self.root.initialization.partition or cut.next_lsn == 0 or cut.next_lsn > self.root.next_lsn) return error.InvalidLogSegment;
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
            return self.flushWithinBudget(memory.allocator(), cut, guard) catch |err| return if (memory.exhausted) error.LogSegmentBudgetExceeded else err;
        }
        fn flushWithinBudget(self: *Self, allocator: std.mem.Allocator, cut: d.Position, guard: Guard) !FlushProgress {
            const evidence = try self.flushCandidate(self.root.sealed_through, cut) orelse {
                try authorize(guard);
                return .{ .cut = cut, .through = self.root.sealed_through, .rows = 0, .complete = true };
            };
            const receipt = evidence.outcome.append;
            const complete = try self.flushCandidate(receipt.next, cut) == null;
            var borrowed = (try self.borrowWithinBudget(try self.root.retainedCut(self.root.declared), self.root.batches, self.root.segments, self.root.hidden, receipt.first, guard, allocator)) orelse return error.LogHistoryUnavailable;
            defer borrowed.deinit();
            var declaration = try Declaration.load(allocator, self.objects, evidence.declared);
            defer declaration.deinit();
            const segment = try Segment.stage(allocator, self.objects, &declaration, evidence, try borrowed.payload.bytes(), self.options.segment_rows_per_group);
            _ = try Segment.materialize(allocator, self.objects, segment, &declaration, evidence, self.encoded[0..self.options.batch_bytes]);
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.sealed_through = receipt.next;
            next.segments = try self.tree().put(next.segments, try r.integerKey(receipt.next), try segment.encode());
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .{ .flush = .{ .cut = cut, .receipt = receipt, .segment = segment } } }, &.{}, guard);
            return .{ .cut = cut, .through = receipt.next, .rows = @intCast(receipt.append.rows), .complete = complete };
        }

        pub const ExpirationStatus = enum { progress, complete, consumer, nonterminal, unsealed, untimed, not_due };
        pub const ExpirationProgress = struct { cut: d.Position, position: d.Position, retained_from: u64, expired_rows: u32, status: ExpirationStatus };
        fn expirationObservation(self: *Self, cut: d.Position, status: ExpirationStatus, guard: Guard) !ExpirationProgress {
            try authorize(guard);
            return .{ .cut = cut, .position = self.root.position(), .retained_from = self.root.retained_from, .expired_rows = 0, .status = status };
        }
        fn validateExpiration(self: *Self, declared: Declaration.Stored, receipt: q.AppendReceipt, now: Time.Sample, protected: u64) !void {
            if (self.root.compaction != null) return error.LogMaintenanceConflict;
            if (kind == .queue) try self.root.requireControlDeclaration(declared) else try self.root.requireDeclaration(declared);
            const age = declared.declaration.configuration.retention.max_age_ms orelse return error.LogRetentionNotDeclared;
            try now.validate();
            _ = try Time.advance(self.root.clock_ms, now.latest_ms);
            const observed = receipt.observed_ms orelse return error.InvalidLogExpiration;
            if (now.earliest_ms < observed) return error.InvalidLogExpiration;
            if (receipt.first != self.root.retained_from or receipt.next > self.root.sealed_through or protected != try self.protectedOffset() or receipt.next > protected or now.earliest_ms - observed < age) return error.InvalidLogExpiration;
            if (!try self.terminalExpirationBatch(receipt)) return error.InvalidLogExpiration;
            const value = try self.tree().get(self.root.segments, try r.integerKey(receipt.next)) orelse return error.InvalidLogExpiration;
            const descriptor = try Segment.Descriptor.decode(value);
            const evidence = try self.original(receipt.append.operation) orelse return error.InvalidLogExpiration;
            if (evidence.outcome != .append or !std.meta.eql(evidence.outcome.append, receipt) or !std.meta.eql(descriptor.evidence, try Evidence.decodeReference(try Evidence.expectedReference(evidence)))) return error.InvalidLogExpiration;
        }
        /// Expire at most one sealed batch from the current logical prefix. Retained
        /// read bases and replay keep their old placement roots until their own closure.
        /// Original receipts and producer fences outlive the payload's public range.
        pub fn expireHistory(self: *Self, declared: Declaration.Stored, cut: d.Position, guard: Guard) !ExpirationProgress {
            try cut.validate();
            try authorize(guard);
            try self.requireReady();
            if (kind == .queue) try self.root.requireControlDeclaration(declared) else try self.root.requireDeclaration(declared);
            const age = declared.declaration.configuration.retention.max_age_ms orelse return error.LogRetentionNotDeclared;
            if (self.root.compaction != null) return error.LogMaintenanceConflict;
            if (cut.partition != self.root.initialization.partition or cut.next_lsn == 0 or cut.next_lsn > self.root.next_lsn) return error.InvalidLogExpiration;
            var declaration = try Declaration.load(self.allocator, self.objects, declared);
            defer declaration.deinit();
            const evidence = try self.flushCandidate(self.root.retained_from, cut) orelse return self.expirationObservation(cut, .complete, guard);
            const receipt = evidence.outcome.append;
            const protected = try self.protectedOffset();
            if (receipt.next > protected) return self.expirationObservation(cut, .consumer, guard);
            if (receipt.next > self.root.sealed_through) return self.expirationObservation(cut, .unsealed, guard);
            if (!try self.terminalExpirationBatch(receipt)) return self.expirationObservation(cut, .nonterminal, guard);
            const observed = receipt.observed_ms orelse return self.expirationObservation(cut, .untimed, guard);
            const now = (try Time.bounds(self.options.clock, self.root.clock_ms, true)).?;
            if (now.earliest_ms < observed or now.earliest_ms - observed < age) return self.expirationObservation(cut, .not_due, guard);
            try self.validateExpiration(declared, receipt, now, protected);
            const complete = try self.flushCandidate(receipt.next, cut) == null;
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            const action: @FieldType(@FieldType(r.Record, "action"), "expire") = .{ .cut = cut, .receipt = receipt, .observed_ms = now.earliest_ms, .clock_ms = now.latest_ms, .protected_next = protected };
            const next = try self.candidateExpiration(declared, action);
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .{ .expire = action } }, &.{}, guard);
            return .{ .cut = cut, .position = next.position(), .retained_from = next.retained_from, .expired_rows = @intCast(receipt.append.rows), .status = if (complete) .complete else .progress };
        }

        fn terminalExpirationBatch(self: *Self, receipt: q.AppendReceipt) !bool {
            if (kind == .stream) return true;
            var bitmap: Bitmap = undefined;
            return self.queueIndex(&bitmap).terminalBatch(self.root.queue.?, receipt, self.root.position());
        }
        fn candidateExpiration(self: *Self, declared: Declaration.Stored, value: @FieldType(@FieldType(r.Record, "action"), "expire")) !Root {
            try value.cut.validate();
            if (value.cut.partition != self.root.initialization.partition or value.cut.next_lsn == 0 or value.cut.next_lsn > self.root.next_lsn) return error.InvalidLogExpiration;
            const evidence = try self.flushCandidate(self.root.retained_from, value.cut) orelse return error.InvalidLogExpiration;
            if (!std.meta.eql(evidence.outcome.append, value.receipt)) return error.InvalidLogExpiration;
            try self.validateExpiration(declared, value.receipt, .{ .earliest_ms = value.observed_ms, .latest_ms = value.clock_ms }, value.protected_next);
            var next = self.root;
            next.declared = declared;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.clock_ms = value.clock_ms;
            next.retained_from = value.receipt.next;
            const key = try r.integerKey(value.receipt.next);
            next.batches = try self.tree().remove(next.batches, key);
            next.segments = try self.tree().remove(next.segments, key);
            return next;
        }

        fn compactionSource(self: *Self, declared: Declaration.Stored) !Compaction.Source {
            return .{ .declared = declared, .cut = try self.root.cut(declared), .batches = self.root.batches, .segments = self.root.segments, .hidden = self.root.hidden, .sealed_through = self.root.sealed_through };
        }
        fn compactionProgress(self: *Self, cut: d.Position, examined: u32, status: @FieldType(Compaction.Progress, "status"), guard: Guard) !Compaction.Progress {
            try authorize(guard);
            return .{ .cut = cut, .position = self.root.position(), .next = if (self.root.compaction) |work| work.next else self.root.next_offset, .examined = examined, .hidden = self.root.hidden.cardinality, .status = status };
        }
        const CompactionRow = struct { offset: u64, key: []const u8, tombstone: bool };
        const CompactionRows = struct { values: [Compaction.max_rows]CompactionRow = undefined, count: usize = 0, through: u64 };
        fn compactionRows(self: *Self, work: Compaction.State, maximum: u16, output: std.mem.Allocator, guard: Guard) !CompactionRows {
            if (maximum == 0 or maximum > Compaction.max_rows or work.phase == .ready) return error.InvalidStreamCompactionBudget;
            var declaration = try Declaration.load(output, self.objects, work.source.declared);
            defer declaration.deinit();
            const schema = declaration.definition.schema;
            const column = schema.columns[try schema.index(declaration.definition.configuration.policy.stream.compact_key_column.?)];
            const column_index = try schema.index(column.id);
            var batch = (try self.borrowAt(work.source.cut, work.source.batches, work.source.segments, work.source.hidden, work.next, guard)) orelse return error.LogHistoryUnavailable;
            defer batch.deinit();
            var iterator = try batch.iterator(schema);
            var result: CompactionRows = .{ .through = work.next };
            defer _ = self.scratch.reset(.retain_capacity);
            var visibility: Bitmap = .{ .store = &self.store, .objects = self.objects };
            const until = @min(work.until(), batch.receipt.next, work.next +| maximum);
            while (try iterator.next()) |encoded| {
                const offset = try std.math.add(u64, batch.receipt.first, encoded.ordinal);
                if (offset < work.next) continue;
                while (result.through < @min(offset, until)) : (result.through += 1)
                    if (!try visibility.contains(work.source.hidden, result.through)) return error.LogHistoryUnavailable;
                if (result.through == until) break;
                if (offset != result.through) return error.LogHistoryUnavailable;
                if (try visibility.contains(work.source.hidden, offset)) {
                    result.through += 1;
                    continue;
                }
                _ = self.scratch.reset(.retain_capacity);
                const row = try encoded.decode(self.scratch.allocator(), schema, batch.receipt.append.operation);
                const key = try f.Collation.encodeSortKey(row.cells[column_index], column.type, column.collation, self.key_buffer);
                result.values[result.count] = .{ .offset = offset, .key = try output.dupe(u8, key), .tombstone = row.tombstone };
                result.count += 1;
                result.through += 1;
                if (result.through == until) break;
            }
            while (result.through < until) : (result.through += 1)
                if (!try visibility.contains(work.source.hidden, result.through)) return error.LogHistoryUnavailable;
            if (result.through == work.next) return error.InvalidStreamCompaction;
            return result;
        }
        fn superseded(index: Keys, work: Compaction.State, row: CompactionRow) !bool {
            const value = try index.get(work.latest, row.key) orelse return error.InvalidStreamCompaction;
            const latest = try Compaction.decodeOffset(value, work.source.cut.retained_from, work.source.cut.next);
            if (latest < row.offset) return error.InvalidStreamCompaction;
            // Tombstones remain explicit records until age-based history expiry. A
            // later tombstone can supersede an earlier value, never the reverse here.
            return !row.tombstone and latest > row.offset;
        }
        fn requireCompactionPublication(self: *Self, work: Compaction.State, cut: d.Position) !void {
            try work.validate();
            if (work.phase != .ready or !std.meta.eql(work.source.cut.accepted, cut) or !std.meta.eql(work.source.hidden, self.root.hidden)) return error.LogCompactionConflict;
            if (try self.protectedOffset() < work.protected_next) return error.LogCompactionConsumerProtected;
        }

        /// Each call accepts one bounded maintenance step. The first captures the exact
        /// current cut; subsequent calls resume that same cut across appends/restarts.
        /// The final publication changes new read bases atomically. Existing pins keep
        /// their prior visibility. Concurrent expiry waits for completion or cancel.
        pub fn compactStep(self: *Self, declared: Declaration.Stored, cut: d.Position, maximum: u16, guard: Guard) !Compaction.Progress {
            try cut.validate();
            try authorize(guard);
            try self.requireReady();
            try self.root.requireDeclaration(declared);
            if (declared.declaration.configuration.policy.stream.compact_key_column == null) return error.StreamCompactionNotDeclared;
            if (maximum == 0 or maximum > Compaction.max_rows) return error.InvalidStreamCompactionBudget;
            if (self.root.compaction == null) {
                if (std.meta.eql(self.root.compacted, @as(?d.Position, cut))) return self.compactionProgress(cut, 0, .complete, guard);
                if (!std.meta.eql(cut, self.root.position())) return error.LogCompactionConflict;
                if (self.root.next_offset == self.root.retained_from) return self.compactionProgress(cut, 0, .complete, guard);
                const protected = try self.protectedOffset();
                if (protected == self.root.retained_from) return self.compactionProgress(cut, 0, .consumer, guard);
                if (self.root.sealed_through == self.root.retained_from) return self.compactionProgress(cut, 0, .unsealed, guard);
                var next = self.root;
                next.declared = declared;
                next.next_lsn = (try self.nextPosition()).next_lsn;
                next.compaction = try Compaction.State.init(try self.compactionSource(declared), protected);
                try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .compaction_start }, &.{}, guard);
                return self.compactionProgress(cut, 0, .progress, guard);
            }
            const work = self.root.compaction.?;
            if (!std.meta.eql(work.source.cut.accepted, cut)) return error.LogCompactionConflict;
            if (work.phase == .ready) {
                if (try self.protectedOffset() < work.protected_next) return self.compactionProgress(cut, 0, .consumer, guard);
                try self.requireCompactionPublication(work, cut);
                var next = self.root;
                next.next_lsn = (try self.nextPosition()).next_lsn;
                next.hidden = work.candidate;
                next.compaction = null;
                next.compacted = cut;
                try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .{ .compaction_publish = cut } }, &.{}, guard);
                return self.compactionProgress(cut, 0, .complete, guard);
            }
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
            var output = std.heap.ArenaAllocator.init(memory.allocator());
            defer output.deinit();
            const rows = self.compactionRows(work, maximum, output.allocator(), guard) catch |err| return if (memory.exhausted) error.LogCompactionBudgetExceeded else err;
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var updated = work;
            const keys: Keys = .{ .store = &self.store };
            var bitmap: Bitmap = .{ .store = &self.store, .objects = self.objects };
            var scratch: Bitmap.Container = .{};
            for (rows.values[0..rows.count]) |row| switch (work.phase) {
                .index => updated.latest = try keys.put(updated.latest, row.key, Compaction.encodeOffset(row.offset)),
                .mark => if (try superseded(keys, work, row)) {
                    updated.candidate = try bitmap.edit(updated.candidate, row.offset >> 16, &.{.{ .offset = @truncate(row.offset), .present = true }}, &scratch);
                },
                .ready => unreachable,
            };
            try updated.advance(rows.through);
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.compaction = updated;
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .{ .compaction_step = .{ .from = work.next, .through = rows.through } } }, &.{}, guard);
            return self.compactionProgress(cut, @intCast(rows.count), .progress, guard);
        }

        /// Cancels only unpublished maintenance. Already visible compaction and all
        /// accepted application work keep their own identities and retention owners.
        pub fn cancelCompaction(self: *Self, cut: d.Position, guard: Guard) !void {
            try cut.validate();
            try authorize(guard);
            try self.requireReady();
            const work = self.root.compaction orelse return;
            if (!std.meta.eql(work.source.cut.accepted, cut)) return error.LogCompactionConflict;
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.compaction = null;
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .{ .compaction_cancel = cut } }, &.{}, guard);
        }

        fn verifyCompactionStep(self: *Self, before: Compaction.State, after: Compaction.State, through: u64, guard: Guard) !void {
            if (through <= before.next or through - before.next > Compaction.max_rows) return error.InvalidStreamCompaction;
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
            var output = std.heap.ArenaAllocator.init(memory.allocator());
            defer output.deinit();
            const rows = self.compactionRows(before, @intCast(through - before.next), output.allocator(), guard) catch |err| return if (memory.exhausted) error.LogCompactionBudgetExceeded else err;
            if (rows.through != through) return error.InvalidStreamCompaction;
            var expected = before;
            const keys: Keys = .{ .store = &self.store };
            switch (before.phase) {
                .index => {
                    for (rows.values[0..rows.count], 0..) |row, i| {
                        var overwritten = false;
                        for (rows.values[i + 1 .. rows.count]) |later| if (std.mem.eql(u8, row.key, later.key)) {
                            overwritten = true;
                            break;
                        };
                        if (!overwritten) {
                            const value = try keys.get(after.latest, row.key) orelse return error.InvalidStreamCompaction;
                            if (!std.mem.eql(u8, &value, &Compaction.encodeOffset(row.offset))) return error.InvalidStreamCompaction;
                        }
                    }
                    expected.latest = after.latest;
                },
                .mark => {
                    var bitmap: Bitmap = .{ .store = &self.store, .objects = self.objects };
                    var count = before.candidate.cardinality;
                    for (rows.values[0..rows.count]) |row| {
                        const old = try bitmap.contains(before.candidate, row.offset);
                        const present = old or try superseded(keys, before, row);
                        if (present and !old) count += 1;
                        if (try bitmap.contains(after.candidate, row.offset) != present) return error.InvalidStreamCompaction;
                    }
                    if (after.candidate.cardinality != count or (count == before.candidate.cardinality and !std.meta.eql(before.candidate, after.candidate))) return error.InvalidStreamCompaction;
                    expected.candidate = after.candidate;
                },
                .ready => return error.InvalidStreamCompaction,
            }
            try expected.advance(through);
            if (!std.meta.eql(expected, after)) return error.InvalidStreamCompaction;
        }

        pub fn archive(self: *Self, cut: d.Position, limits: History.Limits, guard: Guard) !ArchiveProgress {
            try cut.validate();
            try limits.validate();
            try authorize(guard);
            try self.requireReady();
            if (cut.partition != self.root.initialization.partition or cut.next_lsn == 0 or cut.next_lsn > self.root.next_lsn) return error.InvalidLogArchive;
            if (self.root.archive.through >= cut.next_lsn) {
                try authorize(guard);
                return .{ .through = .{ .partition = cut.partition, .next_lsn = self.root.archive.through }, .frames = 0, .encoded_bytes = 0, .complete = true };
            }
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            const staged = try History.stage(self.allocator, &self.store, self.log, cut.partition, self.root.archive, cut, limits);
            if (staged.frames == 0) return error.InvalidLogArchive;
            try History.verifyExtension(self.allocator, &self.store, self.root.archive, staged.coverage, cut.partition, self.root.next_lsn);
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.archive = staged.coverage;
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .archive = .{ .cut = cut, .from_lsn = self.root.archive.through } } }, &.{}, guard);
            return .{ .through = .{ .partition = cut.partition, .next_lsn = next.archive.through }, .frames = staged.frames, .encoded_bytes = staged.bytes, .complete = staged.complete };
        }

        fn publishMaintenance(self: *Self, action: @import("StreamMaintenanceState.zig").Action, guard: Guard) !void {
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .maintenance = action } }, &.{}, guard);
        }

        fn rewriteCandidate(self: *Self) !Evidence.Record {
            const target = self.root.maintenance.rewrite_target orelse return error.InvalidStreamMaintenance;
            if (target.after_offset < self.root.retained_from or target.after_offset >= target.through_offset) return error.InvalidStreamMaintenance;
            const evidence = try self.flushCandidate(target.after_offset, self.root.position()) orelse return error.LogHistoryUnavailable;
            if (evidence.outcome.append.next > target.through_offset) return error.InvalidStreamMaintenance;
            return evidence;
        }

        /// Build only from the accepted old placement. Missing rows must already be
        /// hidden; surviving canonical bytes are copied without changing identities.
        fn rewriteView(self: *Self, allocator: std.mem.Allocator, declaration: *const Declaration.Owned, evidence: Evidence.Record, guard: Guard) !?[]u8 {
            const receipt = evidence.outcome.append;
            var batch = (try self.borrowWithinBudget(try self.root.cut(self.root.declared), self.root.batches, self.root.segments, self.root.hidden, receipt.first, guard, allocator)) orelse return error.LogHistoryUnavailable;
            defer batch.deinit();
            const schema = declaration.definition.schema;
            var visibility: Bitmap = .{ .store = &self.store, .objects = self.objects };
            var rows = try batch.iterator(schema);
            var kept: u32 = 0;
            var present: u32 = 0;
            while (try rows.next()) |row| {
                present += 1;
                if (!try visibility.contains(self.root.hidden, receipt.first + row.ordinal)) kept += 1;
            }
            if (kept == present or kept > receipt.append.rows / 2) return null;
            const buffer = try allocator.alloc(u8, @intCast(receipt.append.payload.bytes));
            defer allocator.free(buffer);
            var encoder = try @import("LogView.zig").Encoder.init(schema, @intCast(receipt.append.rows), kept, buffer);
            rows = try batch.iterator(schema);
            while (try rows.next()) |row| if (!try visibility.contains(self.root.hidden, receipt.first + row.ordinal)) try encoder.append(row);
            return try allocator.dupe(u8, try encoder.finish());
        }

        fn rewriteWithinBudget(self: *Self, allocator: std.mem.Allocator, guard: Guard) !void {
            const evidence = try self.rewriteCandidate();
            var declaration = try Declaration.load(allocator, self.objects, evidence.declared);
            defer declaration.deinit();
            const view = try self.rewriteView(allocator, &declaration, evidence, guard);
            defer if (view) |bytes| allocator.free(bytes);
            var segment: ?Segment.Descriptor = null;
            if (view) |bytes| {
                segment = try Segment.stageSparse(allocator, self.objects, &declaration, evidence, bytes, self.options.segment_rows_per_group);
                const rebuilt = try Segment.materialize(allocator, self.objects, segment.?, &declaration, evidence, self.encoded[0..self.options.batch_bytes]);
                if (!std.mem.eql(u8, bytes, rebuilt)) return error.LogPayloadConflict;
                try Segment.requireVisibility(segment.?, rebuilt, declaration.definition.schema, evidence.outcome.append, &self.store, self.root.hidden);
            }
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            if (segment) |value| next.segments = try self.tree().put(next.segments, try r.integerKey(evidence.outcome.append.next), try value.encode());
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .rewrite = .{ .receipt = evidence.outcome.append, .segment = segment } } }, &.{}, guard);
        }

        fn verifyRewrite(self: *Self, allocator: std.mem.Allocator, record: r.Record, guard: Guard) !void {
            const value = record.action.rewrite;
            const evidence = try self.rewriteCandidate();
            if (!std.meta.eql(evidence.outcome.append, value.receipt)) return error.InvalidLogSegment;
            var declaration = try Declaration.load(allocator, self.objects, evidence.declared);
            defer declaration.deinit();
            const expected = try self.rewriteView(allocator, &declaration, evidence, guard);
            defer if (expected) |bytes| allocator.free(bytes);
            if ((expected != null) != (value.segment != null)) return error.InvalidLogSegment;
            if (value.segment) |segment| {
                try self.verifyValue(record.root.segments, try r.integerKey(value.receipt.next), try segment.encode());
                const bytes = try Segment.materialize(allocator, self.objects, segment, &declaration, evidence, self.encoded[0..self.options.batch_bytes]);
                if (!std.mem.eql(u8, expected.?, bytes)) return error.LogPayloadConflict;
                try Segment.requireVisibility(segment, bytes, declaration.definition.schema, value.receipt, &self.store, self.root.hidden);
            } else if (!std.meta.eql(record.root.segments, self.root.segments)) return error.InvalidLogSegment;
        }

        /// One accepted rewrite or cursor transition per call. The retained upper bound
        /// is finite even with concurrent appends. Read pins keep their old directories.
        pub fn rewriteMaintenanceUnit(self: *Self, declared: Declaration.Stored, guard: Guard) !bool {
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            if (declared.retired) {
                if (self.root.maintenance.rewrite_target != null) {
                    try self.publishMaintenance(.cancel_rewrite, guard);
                    return true;
                }
                return false;
            }
            const target = self.root.maintenance.rewrite_target orelse {
                if (self.root.maintenance.rewrite_source_lsn <= self.root.maintenance.rewritten_source_lsn) return false;
                try self.publishMaintenance(.begin_rewrite, guard);
                return true;
            };
            if (target.after_offset == target.through_offset) {
                try self.publishMaintenance(.complete_rewrite, guard);
                return true;
            }
            if (target.after_offset < self.root.retained_from) {
                try self.publishMaintenance(.skip_expired_rewrite, guard);
                return true;
            }
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
            self.rewriteWithinBudget(memory.allocator(), guard) catch |err| return if (memory.exhausted) error.LogSegmentBudgetExceeded else err;
            return true;
        }

        /// Advance a retained archive/checkpoint target with at most one publication.
        /// Recovering the root resolves a lost reply. Bookkeeping alone cannot select
        /// another target after the finite workload has settled.
        pub fn archiveMaintenanceUnit(self: *Self, limits: History.Limits, guard: Guard) !bool {
            try limits.validate();
            try authorize(guard);
            try self.requireReady();
            const target = self.root.maintenance.archive_target orelse {
                if (self.root.maintenance.archive_source_lsn <= self.root.maintenance.archived_source_lsn) return false;
                try self.publishMaintenance(.begin_archive, guard);
                return true;
            };
            const partition = self.root.initialization.partition;
            if (self.root.archive.through < target.through_lsn) {
                _ = try self.archive(.{ .partition = partition, .next_lsn = target.through_lsn }, limits, guard);
                return true;
            }
            const checkpoint_lsn = target.checkpoint_lsn orelse return error.InvalidStreamMaintenance;
            if (self.root.recovery == null or self.root.recovery.?.next_lsn < checkpoint_lsn) {
                _ = try self.checkpoint(.{ .partition = partition, .next_lsn = checkpoint_lsn }, guard);
                return true;
            }
            try self.publishMaintenance(.complete_archive, guard);
            return true;
        }

        /// Resume the accepted compaction cut, or select one after new logical input or
        /// sealing progress. Retiring a declaration cancels only unpublished candidates.
        pub fn compactionMaintenanceUnit(self: *Self, declared: Declaration.Stored, maximum: u16, guard: Guard) !bool {
            try authorize(guard);
            try self.requireReady();
            try self.root.requireControlDeclaration(declared);
            if (maximum == 0 or maximum > Compaction.max_rows) return error.InvalidStreamCompactionBudget;
            if (declared.retired) {
                if (self.root.compaction) |work| {
                    try self.cancelCompaction(work.source.cut.accepted, guard);
                    return true;
                }
                return self.rewriteMaintenanceUnit(declared, guard);
            }
            if (declared.declaration.configuration.policy.stream.compact_key_column == null) return false;
            if (self.root.maintenance.rewrite_target != null or self.root.maintenance.rewrite_source_lsn > self.root.maintenance.rewritten_source_lsn)
                return self.rewriteMaintenanceUnit(declared, guard);
            const cut = if (self.root.compaction) |work| work.source.cut.accepted else selected: {
                if (self.root.maintenance.compaction_source_lsn <= self.root.maintenance.compacted_through_lsn) return false;
                break :selected self.root.position();
            };
            const before = self.root.next_lsn;
            _ = try self.compactStep(declared, cut, maximum, guard);
            return self.root.next_lsn != before;
        }

        pub fn checkpoint(self: *Self, cut: d.Position, guard: Guard) !Checkpoint.Reference {
            try cut.validate();
            try authorize(guard);
            try self.requireReady();
            if (cut.partition != self.root.initialization.partition or cut.next_lsn == 0 or cut.next_lsn > self.root.next_lsn) return error.InvalidLogRecovery;
            if (self.root.recovery) |reference| if (reference.next_lsn >= cut.next_lsn) {
                try authorize(guard);
                return reference;
            };
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            const reference = try Checkpoint.stage(self.objects, .{ .root = self.root, .commitment = self.commitment });
            const stored = try Checkpoint.load(self.allocator, self.objects, reference, (try self.nextPosition()).next_lsn, self.root.initialization);
            if (!std.meta.eql(stored, Checkpoint.Basis{ .root = self.root, .commitment = self.commitment })) return error.InvalidLogRecovery;
            var next = self.root;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.recovery = reference;
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .checkpoint }, &.{}, guard);
            return reference;
        }
        pub fn archivedThrough(allocator: std.mem.Allocator, frame: Log.Frame) !u64 {
            if (std.mem.startsWith(u8, frame.payload, "LINIT001")) {
                _ = try Initialization.decode(allocator, frame);
                return 0;
            }
            const root = (try r.decode(allocator, frame, frame.header.partition_id, frame.header.lsn)).record.root;
            const reference = root.recovery orelse return 0;
            return @min(root.archive.through, reference.next_lsn);
        }
        pub fn trimArchived(self: *Self, guard: Guard) !u64 {
            try self.requireReady();
            _ = try guard.acquire(guard.context);
            defer guard.release(guard.context);
            if (self.root.archive.through == 0) return 0;
            const reference = self.root.recovery orelse return error.LogCheckpointRequired;
            const through = @min(self.root.archive.through, reference.next_lsn);
            self.log.trim(self.root.initialization.partition, through) catch |err| {
                self.ready = false;
                return err;
            };
            return through;
        }
        fn selectCheckpoint(self: *Self, end: u64, guard: Guard) !void {
            if (end <= 1) return;
            var latest = try self.log.read(self.allocator, self.root.initialization.partition, end - 1, 1);
            defer latest.deinit();
            if (latest.frames.len != 1) return error.LogHistoryUnavailable;
            const record = (try self.decodeFrame(latest.frames[0], self.root.initialization.partition, end - 1)).record;
            try self.root.initialization.requireSame(record.root.initialization);
            const reference = record.root.recovery orelse return;
            if (reference.next_lsn <= self.root.next_lsn) return;
            const basis = try Checkpoint.load(self.allocator, self.objects, reference, end, self.root.initialization);
            var publication = try self.log.read(self.allocator, self.root.initialization.partition, reference.next_lsn, 1);
            defer publication.deinit();
            if (publication.frames.len != 1) return error.LogRecoveryMissing;
            try Checkpoint.requirePublication(basis, reference, (try self.decodeFrame(publication.frames[0], self.root.initialization.partition, reference.next_lsn)).record);
            try authorize(guard);
            self.root = basis.root;
            self.commitment = basis.commitment;
        }

        pub const Recovery = struct { examined: u16, position: d.Position, complete: bool };
        /// Same-process evidence from a completely validated immutable prefix. This
        /// owned hint is neither a persisted checkpoint nor authorization. Discard it
        /// when replacing the physical owner; a collision only requires full recovery.
        pub const RecoveryState = struct { root: Root, commitment: [32]u8 };
        pub fn recoveryState(self: *Self) !RecoveryState {
            try self.requireReady();
            return .{ .root = self.root, .commitment = self.commitment };
        }
        pub fn recoverStep(self: *Self, guard: Guard, budget: u16) !Recovery {
            return self.recoverStepSince(guard, budget, null);
        }
        pub fn recoverStepSince(self: *Self, guard: Guard, budget: u16, prior: ?RecoveryState) !Recovery {
            if (budget == 0 or budget > 256) return error.InvalidLogRecoveryBudget;
            try authorize(guard);
            self.ready = false;
            const through = try self.log.tail(self.root.initialization.partition);
            if (through < self.root.next_lsn) return error.InvalidLogHistory;
            try self.selectCheckpoint(through, guard);
            if (prior) |known| {
                try known.root.validate();
                try self.root.initialization.requireSame(known.root.initialization);
                if (known.root.next_lsn > through) return error.InvalidLogHistory;
                if (known.root.next_lsn > self.root.next_lsn) {
                    // A newer accepted checkpoint wins over obsolete hints. Otherwise
                    // this boundary remains in the WAL; verify it before reusing the
                    // same owner's earlier full replay, never trust a provider cache.
                    var anchor = try self.log.read(self.allocator, self.root.initialization.partition, known.root.next_lsn - 1, 1);
                    defer anchor.deinit();
                    if (anchor.frames.len != 1) return error.LogHistoryUnavailable;
                    const frame = anchor.frames[0];
                    const record = (try self.decodeFrame(frame, self.root.initialization.partition, known.root.next_lsn - 1)).record;
                    if (!std.meta.eql(record.root, known.root) or !std.mem.eql(u8, &Evidence.hash(frame.payload), &known.commitment)) return error.InvalidLogHistory;
                    try authorize(guard);
                    self.root = known.root;
                    self.commitment = known.commitment;
                }
            }
            var examined: u16 = 0;
            while (examined < budget and self.root.next_lsn < through) : (examined += 1) {
                var batch = try self.historyFrame(self.root.next_lsn);
                defer batch.deinit();
                if (batch.frames.len != 1) return error.LogHistoryUnavailable;
                const frame = batch.frames[0];
                const decoded = try self.decodeFrame(frame, self.root.initialization.partition, self.root.next_lsn);
                if (!std.mem.eql(u8, &decoded.record.previous, &self.commitment)) return error.InvalidLogHistory;
                try self.verifyTransition(decoded.record, decoded.payload, guard);
                const next_commitment = Evidence.hash(frame.payload);
                try authorize(guard);
                self.root = decoded.record.root;
                self.commitment = next_commitment;
            }
            for ([_]?pages.Reference{ self.root.batches, self.root.segments, self.root.hidden.containers, self.root.receipts, self.root.producers, self.root.producer_receipts, self.root.groups, self.root.group_offsets, self.root.pins, self.root.transaction_pins, self.root.archive.directory }) |reference| if (reference) |value| {
                _ = try self.store.load(value);
            };
            if (kind == .queue) {
                const queue = self.root.queue.?;
                for ([_]?pages.Reference{ queue.items, queue.sidecars, queue.keys, queue.read_releases }) |reference| if (reference) |value| {
                    _ = try self.store.load(value);
                };
                var bitmap: Bitmap = undefined;
                const index = self.queueIndex(&bitmap);
                try index.timers(.visible).verifyRoots(queue.eligible);
                try index.timers(.lease).verifyRoots(queue.deadlines);
            }
            if (self.root.compaction) |work| for ([_]?pages.Reference{ work.source.batches, work.source.segments, work.latest, work.candidate.containers }) |reference| if (reference) |value| {
                _ = try self.store.load(value);
            };
            try authorize(guard);
            self.ready = self.root.next_lsn == try self.log.tail(self.root.initialization.partition);
            return .{ .examined = examined, .position = self.root.position(), .complete = self.ready };
        }
        fn verifyValue(self: *Self, root: ?pages.Reference, key: pages.Key, value: pages.Value) !void {
            const found = try self.tree().get(root, key) orelse return error.InvalidLogHistory;
            if (!std.mem.eql(u8, found.data[0..found.len], value.data[0..value.len])) return error.InvalidLogHistory;
        }
        fn verifyTransition(self: *Self, record: r.Record, payload: []const u8, guard: Guard) !void {
            if (record.action == .operation and record.action.operation.outcome == .terminal) return error.InvalidLogPreparation;
            const next = record.root;
            if (next.changed_lsn != (if (record.changesData()) next.next_lsn else self.root.changed_lsn)) return error.InvalidLogHistory;
            try self.root.initialization.requireSame(next.initialization);
            if (self.root.transaction != null or record.action == .transaction_prepare or record.action == .transaction_commit or record.action == .transaction_abort) {
                try self.requireTransactionTransition(record);
                return;
            }
            if (next.transaction != null) return error.InvalidLogPreparation;
            if (kind == .queue and (record.action == .operation or record.action == .queue_expire or record.action == .queue_schedule or record.action == .expire)) {
                const ordinary = self.enterControl(true);
                defer self.leaveControl(ordinary);
                try self.candidate_objects.reset(self.objects);
                self.objects = self.candidate_objects.objectStore();
                self.store.store = self.objects;
                self.store.clearCache();
                defer self.store.clearCache();
                try self.store.begin(self.options.index_work_bytes);
                defer self.store.end();
                var expected = switch (record.action) {
                    .operation => try self.candidate(record.action.operation, payload, guard),
                    .queue_expire => try self.candidateQueueExpiry(next.declared, record.action.queue_expire),
                    .expire => try self.candidateExpiration(next.declared, record.action.expire),
                    .queue_schedule => (try self.candidateQueueSchedule(next.declared, record.action.queue_schedule)) orelse return error.InvalidLogHistory,
                    else => unreachable,
                };
                expected.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, next, record.action);
                expected.changed_lsn = next.changed_lsn;
                if (!std.meta.eql(expected, next)) return error.InvalidLogHistory;
                return;
            }
            if (record.action != .operation) {
                var expected = self.root;
                expected.next_lsn = next.next_lsn;
                expected.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, next, record.action);
                expected.changed_lsn = next.changed_lsn;
                switch (record.action) {
                    .operation => unreachable,
                    .transaction_prepare, .transaction_commit, .transaction_abort => return error.InvalidLogPreparation,
                    .queue_expire, .queue_schedule => return error.InvalidLogHistory,
                    .maintenance => {},
                    .transaction_pin => |handle| {
                        if (self.root.transaction != null or try self.tree().get(self.root.transaction_pins, try Evidence.operationKey(handle.owner)) != null) return error.InvalidLogTransaction;
                        try self.root.requireDeclaration(next.declared);
                        const source = try Transaction.loadSource(self.objects, handle);
                        var basis = self.root;
                        basis.declared = next.declared;
                        basis.transaction_pins = null;
                        if (!std.meta.eql(source.root, basis)) return error.InvalidLogTransaction;
                        expected.declared = next.declared;
                        expected.transaction_pins = next.transaction_pins;
                        try self.verifyValue(next.transaction_pins, try Evidence.operationKey(handle.owner), try (Transaction.Pin{ .source = handle.content, .released = false }).encode());
                    },
                    .transaction_release => |handle| {
                        const previous = try self.tree().get(self.root.transaction_pins, try Evidence.operationKey(handle.owner)) orelse return error.InvalidLogTransaction;
                        const pin = try Transaction.Pin.decode(previous);
                        if (pin.released or !std.meta.eql(pin.source, handle.content)) return error.InvalidLogTransaction;
                        expected.transaction_pins = next.transaction_pins;
                        try self.verifyValue(next.transaction_pins, try Evidence.operationKey(handle.owner), try (Transaction.Pin{ .source = handle.content, .released = true }).encode());
                    },
                    .archive => |value| {
                        if (value.from_lsn != self.root.archive.through) return error.InvalidLogArchive;
                        try History.verifyExtension(self.allocator, &self.store, self.root.archive, next.archive, next.initialization.partition, self.root.next_lsn);
                        expected.archive = next.archive;
                    },
                    .checkpoint => {
                        const reference = next.recovery orelse return error.InvalidLogRecovery;
                        const basis = try Checkpoint.load(self.allocator, self.objects, reference, next.next_lsn, self.root.initialization);
                        if (!std.meta.eql(basis.root, self.root) or !std.mem.eql(u8, &basis.commitment, &self.commitment)) return error.InvalidLogRecovery;
                        try Checkpoint.requirePublication(basis, reference, record);
                        expected.recovery = next.recovery;
                    },
                    .flush => |value| {
                        const evidence = try self.flushCandidate(self.root.sealed_through, value.cut) orelse return error.InvalidLogSegment;
                        if (!std.meta.eql(evidence.outcome.append, value.receipt) or value.segment.layout != .complete) return error.InvalidLogSegment;
                        try self.verifyValue(next.segments, try r.integerKey(value.receipt.next), try value.segment.encode());
                        _ = try self.materialize(value.segment, evidence);
                        expected.segments = next.segments;
                        expected.sealed_through = value.receipt.next;
                    },
                    .rewrite => {
                        var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
                        self.verifyRewrite(memory.allocator(), record, guard) catch |err| return if (memory.exhausted) error.LogSegmentBudgetExceeded else err;
                        expected.segments = next.segments;
                    },
                    .expire => |value| {
                        const evidence = try self.flushCandidate(self.root.retained_from, value.cut) orelse return error.InvalidLogExpiration;
                        try self.validateExpiration(next.declared, evidence.outcome.append, .{ .earliest_ms = value.observed_ms, .latest_ms = value.clock_ms }, value.protected_next);
                        if (!std.meta.eql(evidence.outcome.append, value.receipt)) return error.InvalidLogExpiration;
                        const key = try r.integerKey(value.receipt.next);
                        if (try self.tree().get(next.batches, key) != null or try self.tree().get(next.segments, key) != null) return error.InvalidLogExpiration;
                        expected.declared = next.declared;
                        expected.clock_ms = value.clock_ms;
                        expected.retained_from = value.receipt.next;
                        expected.batches = next.batches;
                        expected.segments = next.segments;
                    },
                    .compaction_start => {
                        try self.root.requireDeclaration(next.declared);
                        expected.declared = next.declared;
                        expected.compaction = try Compaction.State.init(try self.compactionSource(next.declared), try self.protectedOffset());
                    },
                    .compaction_step => |step| {
                        const work = self.root.compaction orelse return error.InvalidStreamCompaction;
                        if (step.from != work.next) return error.InvalidStreamCompaction;
                        try self.verifyCompactionStep(work, next.compaction orelse return error.InvalidStreamCompaction, step.through, guard);
                        expected.compaction = next.compaction;
                    },
                    .compaction_publish => |cut| {
                        const work = self.root.compaction orelse return error.InvalidStreamCompaction;
                        try self.requireCompactionPublication(work, cut);
                        expected.hidden = work.candidate;
                        expected.compaction = null;
                        expected.compacted = cut;
                    },
                    .compaction_cancel => |cut| {
                        const work = self.root.compaction orelse return error.InvalidStreamCompaction;
                        if (!std.meta.eql(work.source.cut.accepted, cut)) return error.LogCompactionConflict;
                        expected.compaction = null;
                    },
                }
                if (!std.meta.eql(expected, next)) return error.InvalidLogHistory;
                return;
            }
            const evidence = record.action.operation;
            if (evidence.outcome == .offset or evidence.outcome == .release)
                try self.root.requireControlDeclaration(evidence.declared)
            else
                try self.root.requireDeclaration(evidence.declared);
            try self.root.initialization.requireSame(next.initialization);
            if (next.retained_from != self.root.retained_from or try self.original(evidence.operation()) != null) return error.InvalidLogHistory;
            const reference = try Evidence.expectedReference(evidence);
            try self.verifyValue(next.receipts, try Evidence.operationKey(evidence.operation()), reference);
            if (!std.meta.eql(evidence, try self.loadEvidence(reference))) return error.InvalidLogHistory;
            var declared = try Declaration.load(self.allocator, self.objects, evidence.declared);
            defer declared.deinit();
            var expected = self.root;
            expected.declared = next.declared;
            expected.next_lsn = next.next_lsn;
            expected.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, next, record.action);
            expected.changed_lsn = next.changed_lsn;
            expected.receipts = next.receipts;
            switch (evidence.outcome) {
                .claim, .settlement, .terminal, .queue_release => return error.InvalidLogHistory,
                .append => |receipt| {
                    if (receipt.first != self.root.next_offset) return error.InvalidLogHistory;
                    expected.clock_ms = try Time.advance(self.root.clock_ms, receipt.observed_ms);
                    expected.next_offset = receipt.next;
                    expected.batches = next.batches;
                    try self.verifyValue(next.batches, try r.integerKey(receipt.next), reference);
                    if (try self.nextProducer(receipt.append)) |producer| {
                        expected.producers = next.producers;
                        expected.producer_receipts = next.producer_receipts;
                        try self.verifyValue(next.producers, try r.producerKey(receipt.append, false), try r.valueEncode(producer));
                        try self.verifyValue(next.producer_receipts, try r.producerKey(receipt.append, true), reference);
                    }
                },
                .assignment => |receipt| {
                    const assignment = receipt.assignment;
                    try assignment.requireCurrent(try self.progress(assignment.group.id), try self.root.cut(evidence.declared));
                    expected.groups = next.groups;
                    expected.group_offsets = next.group_offsets;
                    try self.verifyGroup(next, assignment.expected, try assignment.resulting());
                },
                .read => |receipt| {
                    const basis = try self.readBasis(evidence.declared, receipt.request);
                    if (!std.meta.eql(basis, try self.loadRead(receipt.handle())) or !std.meta.eql(try basis.receipt(receipt.source), receipt)) return error.InvalidLogHistory;
                    expected.pins = next.pins;
                    try self.verifyValue(next.pins, try Evidence.operationKey(receipt.request.operation), try (Read.Pin{ .source = receipt.source, .released = false }).encode());
                },
                .release => |receipt| {
                    const retained = try self.retainedRead(receipt.release.read);
                    try receipt.release.target.requireSame(retained.receipt.request.target);
                    expected.pins = next.pins;
                    try self.verifyValue(next.pins, try Evidence.operationKey(receipt.release.read.owner), try (Read.Pin{ .source = receipt.release.read.source, .released = true }).encode());
                },
                .offset => |value| {
                    // Acceptance already authenticated coverage under the then-current
                    // key. Key rotation cannot revoke that accepted result on replay.
                    const advanced = try self.advanceGroup(value.receipt.commit, value.cursor);
                    expected.groups = next.groups;
                    expected.group_offsets = next.group_offsets;
                    try self.verifyGroup(next, try self.progress(advanced.group.id), advanced);
                },
            }
            if (!std.meta.eql(expected, next)) return error.InvalidLogHistory;
        }

        pub const BorrowedBatch = struct {
            cut: q.Cut,
            receipt: q.AppendReceipt,
            payload: Tail.Borrow,
            layout: Segment.Layout,
            pub fn iterator(self: *BorrowedBatch, schema: f.TableSchema.Schema) !@import("LogView.zig").Rows {
                const bytes = try self.payload.bytes();
                return switch (self.layout) {
                    .complete => .{ .complete = try Batch.Iterator.init(bytes, schema, if (self.receipt.append.kind == .stream) .stream else .queue, self.receipt.append.rows) },
                    .sparse => .{ .sparse = try @import("LogView.zig").Iterator.init(bytes, schema, self.receipt.append.rows) },
                };
            }
            pub fn deinit(self: *BorrowedBatch) void {
                self.payload.release() catch unreachable;
                self.* = undefined;
            }
        };
        /// One current batch, borrowed from a bounded verified tail slab. The receipt
        /// supplies its actual offset range; the current cut is not a retention pin or
        /// proof of a completed multi-batch traversal. Callers enforce row/byte budgets.
        pub fn readBatch(self: *Self, declared: Declaration.Stored, offset: u64, guard: Guard) !?BorrowedBatch {
            try authorize(guard);
            try self.requireReady();
            const cut = try self.root.cut(declared);
            return self.borrowAt(cut, self.root.batches, self.root.segments, self.root.hidden, offset, guard);
        }
        fn materialize(self: *Self, segment: Segment.Descriptor, evidence: Evidence.Record) ![]const u8 {
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
            return self.materializeWithinBudget(memory.allocator(), segment, evidence) catch |err| return if (memory.exhausted) error.LogSegmentBudgetExceeded else err;
        }
        fn materializeWithinBudget(self: *Self, allocator: std.mem.Allocator, segment: Segment.Descriptor, evidence: Evidence.Record) ![]const u8 {
            var declaration = try Declaration.load(allocator, self.objects, evidence.declared);
            defer declaration.deinit();
            return Segment.materialize(allocator, self.objects, segment, &declaration, evidence, self.encoded[0..self.options.batch_bytes]);
        }
        fn borrowAt(self: *Self, cut: q.Cut, batches: ?pages.Reference, segments: ?pages.Reference, hidden: Bitmap.Root, offset: u64, guard: Guard) !?BorrowedBatch {
            return self.borrowWithinBudget(cut, batches, segments, hidden, offset, guard, null);
        }
        fn borrowWithinBudget(self: *Self, cut: q.Cut, batches: ?pages.Reference, segments: ?pages.Reference, hidden: Bitmap.Root, offset: u64, guard: Guard, work_allocator: ?std.mem.Allocator) !?BorrowedBatch {
            try cut.requireOffset(offset);
            if (offset == cut.next) {
                try authorize(guard);
                return null;
            }
            const selected = try self.tree().scanFrom(batches, try r.integerKey(offset + 1));
            const entry = selected.entries[0] orelse return error.LogHistoryUnavailable;
            const evidence = try self.loadEvidence(entry.value);
            if (evidence.outcome != .append) return error.InvalidLogHistory;
            const receipt = evidence.outcome.append;
            try self.requireTarget(receipt.append.target);
            if (receipt.first > offset or receipt.next <= offset or receipt.next > cut.next or receipt.accepted.partition != cut.accepted.partition or receipt.accepted.next_lsn > cut.accepted.next_lsn or !std.meta.eql(entry.key, try r.integerKey(receipt.next))) return error.InvalidLogHistory;
            const segment: ?Segment.Descriptor = if (try self.tree().get(segments, entry.key)) |value| try Segment.Descriptor.decode(value) else null;
            if (segment) |value| {
                if (!std.meta.eql(value.evidence, try Evidence.decodeReference(try Evidence.expectedReference(evidence)))) return error.InvalidLogSegment;
                if (value.layout == .complete and (value.rows != receipt.append.rows or !std.meta.eql(value.view, receipt.append.payload))) return error.InvalidLogSegment;
            }
            const binding: Tail.Binding = .{ .position = receipt.accepted, .first = receipt.first, .content = receipt.append.payload, .view = if (segment) |value| (if (value.layout == .sparse) value.view else null) else null };
            var borrowed = try self.cache.borrow(binding);
            if (borrowed == null) {
                if (segment) |value| {
                    const payload = if (work_allocator) |allocator| try self.materializeWithinBudget(allocator, value, evidence) else try self.materialize(value, evidence);
                    try self.cache.admit(binding, payload);
                } else {
                    var frames = try self.historyFrame(receipt.accepted.next_lsn - 1);
                    defer frames.deinit();
                    if (frames.frames.len != 1) return error.LogHistoryUnavailable;
                    const decoded = try self.decodeFrame(frames.frames[0], receipt.accepted.partition, receipt.accepted.next_lsn - 1);
                    if (decoded.record.action != .operation or !std.meta.eql(decoded.record.action.operation, evidence)) return error.InvalidLogHistory;
                    try self.cache.admit(binding, decoded.payload);
                }
                borrowed = try self.cache.borrow(binding);
            }
            const result = borrowed orelse return error.LogHistoryUnavailable;
            errdefer result.release() catch unreachable;
            if (segment) |value| if (value.layout == .sparse) {
                var declaration = try Declaration.load(work_allocator orelse self.allocator, self.objects, evidence.declared);
                defer declaration.deinit();
                try Segment.requireVisibility(value, try result.bytes(), declaration.definition.schema, receipt, &self.store, hidden);
            };
            try authorize(guard);
            return .{ .cut = cut, .receipt = receipt, .payload = result, .layout = if (segment) |value| value.layout else .complete };
        }

        pub fn readCursor(self: *Self, handle: read.Handle, authority: Read.Authority, guard: Guard) !read.Cursor {
            try authorize(guard);
            try self.requireReady();
            const retained = try self.retainedRead(handle);
            if (retained.receipt.request.group) |selected| _ = try self.requireGroup(selected, null);
            const cursor = try authority.issue(handle, try retained.receipt.initialCoverage());
            try authorize(guard);
            return cursor;
        }
        pub const ReadLimits = struct { rows: u32, encoded_bytes: u32, scanned_rows: u32 = 4096 };
        pub const ReadRow = struct {
            offset: u64,
            operation: d.Operation,
            encoded: Batch.EncodedRow,
        };
        pub const ReadPage = struct {
            allocator: std.mem.Allocator,
            storage: []ReadRow,
            count: u32,
            encoded_bytes: u32,
            examined: u32 = 0,
            cursor: read.Cursor,
            pub fn rows(self: ReadPage) []const ReadRow {
                return self.storage[0..self.count];
            }
            pub fn deinit(self: *ReadPage) void {
                for (self.rows()) |row| self.allocator.free(row.encoded.bytes);
                self.allocator.free(self.storage);
                self.* = undefined;
            }
        };

        /// Copy a bounded window into caller-owned output, preserving the original
        /// snapshot and cumulative authenticated coverage across physical batches.
        /// Its raw rows decode with the pinned schema; no output points into cache or
        /// scratch. Early close does not imply traversal completion or group progress.
        pub fn readPage(self: *Self, cursor: read.Cursor, authority: Read.Authority, limits: ReadLimits, output: std.mem.Allocator, guard: Guard) !ReadPage {
            try authorize(guard);
            try self.requireReady();
            try authority.verify(cursor);
            const retained = try self.retainedRead(cursor.read);
            try cursor.requireReceipt(retained.receipt);
            if (retained.receipt.request.group) |selected| _ = try self.requireGroup(selected, null);
            const declared_limits = retained.basis.declared.declaration.limits;
            if (limits.scanned_rows == 0 or limits.scanned_rows > self.options.read_scan_rows) return error.InvalidStreamReadBudget;
            if (limits.rows == 0 or limits.rows > @min(declared_limits.read_rows, self.options.read_rows) or limits.encoded_bytes == 0 or limits.encoded_bytes > @min(declared_limits.read_bytes, self.options.read_bytes)) return error.InvalidStreamReadBudget;
            var declaration = try Declaration.load(self.allocator, self.objects, retained.basis.declared);
            defer declaration.deinit();
            var result: ReadPage = .{ .allocator = output, .storage = try output.alloc(ReadRow, if (cursor.coverage.complete) 0 else limits.rows), .count = 0, .encoded_bytes = 0, .cursor = cursor };
            errdefer result.deinit();
            var coverage = cursor.coverage;
            var visibility: Bitmap = .{ .store = &self.store, .objects = self.objects };
            outer: while (!coverage.complete and result.count < limits.rows and result.examined < limits.scanned_rows) {
                if (try visibility.contains(retained.basis.hidden, coverage.through)) {
                    coverage.through += 1;
                    result.examined += 1;
                    coverage.complete = coverage.through == coverage.until;
                    continue;
                }
                if (retained.basis.request.timestamp) |range| {
                    const maximum: u32 = @intCast(@min(coverage.until - coverage.through, limits.scanned_rows - result.examined));
                    const skipped = try self.skipTimestamp(retained.basis, range, coverage.through, maximum);
                    if (skipped != 0) {
                        coverage.through += skipped;
                        result.examined += skipped;
                        coverage.complete = coverage.through == coverage.until;
                        continue;
                    }
                }
                var batch = (try self.borrowAt(retained.basis.cut, retained.basis.batches, retained.basis.segments, retained.basis.hidden, coverage.through, guard)) orelse return error.LogHistoryUnavailable;
                defer batch.deinit();
                var iterator = try batch.iterator(declaration.definition.schema);
                var advanced = false;
                while (try iterator.next()) |row| {
                    const offset = try std.math.add(u64, batch.receipt.first, row.ordinal);
                    if (offset < coverage.through) continue;
                    while (coverage.through < offset) {
                        if (!try visibility.contains(retained.basis.hidden, coverage.through)) return error.LogHistoryUnavailable;
                        coverage.through += 1;
                        result.examined += 1;
                        coverage.complete = coverage.through == coverage.until;
                        advanced = true;
                        if (coverage.complete or result.examined == limits.scanned_rows) break :outer;
                    }
                    if (offset != coverage.through) return error.LogHistoryUnavailable;
                    if (try visibility.contains(retained.basis.hidden, offset)) {
                        coverage.through += 1;
                        result.examined += 1;
                        coverage.complete = coverage.through == coverage.until;
                        advanced = true;
                        if (coverage.complete or result.examined == limits.scanned_rows) break :outer;
                        continue;
                    }
                    if (retained.basis.request.timestamp) |range| {
                        const ci = try declaration.definition.schema.index(declaration.definition.configuration.policy.stream.timestamp_column.?);
                        if (!try self.timestampMatches(row, declaration.definition.schema, batch.receipt.append.operation, ci, range)) {
                            coverage.through += 1;
                            result.examined += 1;
                            coverage.complete = coverage.through == coverage.until;
                            advanced = true;
                            if (coverage.complete or result.examined == limits.scanned_rows) break :outer;
                            continue;
                        }
                    }
                    const bytes = row.bytes.len + Batch.row_header_bytes;
                    if (bytes > limits.encoded_bytes - result.encoded_bytes) {
                        if (result.count == 0) return error.StreamReadByteBudgetTooSmall;
                        break :outer;
                    }
                    var copied = row;
                    copied.bytes = try output.dupe(u8, row.bytes);
                    result.storage[result.count] = .{ .offset = offset, .operation = batch.receipt.append.operation, .encoded = copied };
                    result.count += 1;
                    result.encoded_bytes += @intCast(bytes);
                    coverage.through += 1;
                    result.examined += 1;
                    coverage.rows += 1;
                    coverage.complete = coverage.through == coverage.until;
                    advanced = true;
                    if (coverage.complete or result.count == limits.rows or result.examined == limits.scanned_rows) break :outer;
                }
                if (!advanced) return error.LogHistoryUnavailable;
            }
            result.cursor = try authority.issue(cursor.read, coverage);
            try authorize(guard);
            return result;
        }

        fn timestampMatches(self: *Self, row: Batch.EncodedRow, schema: f.TableSchema.Schema, operation_value: d.Operation, ci: usize, range: read.TimestampRange) !bool {
            defer _ = self.scratch.reset(.retain_capacity);
            const decoded = try row.decode(self.scratch.allocator(), schema, operation_value);
            const cell = decoded.cells[ci];
            if (cell != .value or cell.value != .atom or cell.value.atom != .timestamp) return error.InvalidStreamTimestampColumn;
            return range.matches(cell.value.atom.timestamp);
        }
        fn skipTimestamp(self: *Self, basis: Read.Basis, range: read.TimestampRange, offset: u64, maximum: u32) !u32 {
            if (basis.segments == null) return 0;
            const page = try self.tree().scanFrom(basis.batches, try r.integerKey(offset + 1));
            const entry = page.entries[0] orelse return error.LogHistoryUnavailable;
            const evidence = try self.loadEvidence(entry.value);
            if (evidence.outcome != .append) return error.InvalidLogHistory;
            const receipt = evidence.outcome.append;
            try self.requireTarget(receipt.append.target);
            if (receipt.first > offset or receipt.next <= offset or receipt.next > basis.cut.next or receipt.accepted.partition != basis.cut.accepted.partition or receipt.accepted.next_lsn > basis.cut.accepted.next_lsn or !std.meta.eql(entry.key, try r.integerKey(receipt.next))) return error.InvalidLogHistory;
            const value = try self.tree().get(basis.segments, entry.key) orelse return 0;
            var memory: f.MemoryBudget = .{ .parent = self.allocator, .limit = self.options.segment_work_bytes };
            return self.skipTimestampWithinBudget(memory.allocator(), try Segment.Descriptor.decode(value), evidence, range, @intCast(offset - receipt.first), maximum) catch |err| return if (memory.exhausted) error.LogSegmentBudgetExceeded else err;
        }
        fn skipTimestampWithinBudget(self: *Self, allocator: std.mem.Allocator, descriptor: Segment.Descriptor, evidence: Evidence.Record, range: read.TimestampRange, ordinal: u32, maximum: u32) !u32 {
            var declaration = try Declaration.load(allocator, self.objects, evidence.declared);
            defer declaration.deinit();
            return Segment.skipTimestamp(allocator, self.objects, descriptor, &declaration, evidence, range, ordinal, maximum);
        }
    };
}

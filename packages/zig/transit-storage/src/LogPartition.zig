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
const QueueIndex = @import("QueueIndex.zig");
const QueueClaims = @import("QueueClaims.zig");
const QueueSelection = @import("QueueSelection.zig");
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
            /// Same physical namespace and authority, with deployment control reserve.
            /// Only progress/closure and physical recovery use this capability.
            control: ?struct { log: Log.Log, objects: Objects.ObjectStore } = null,
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
        candidate_objects: if (kind == .queue) CandidateObjects else void,
        queue_container: if (kind == .queue) Bitmap.Container else void,
        queue_leases: if (kind == .queue) []q.Lease else void,
        queue_selection: if (kind == .queue) []u8 else void,

        /// Opens the original initialization only. Recovery is explicit bounded work;
        /// a caller cannot serve reads or accept writes until recoverStep completes.
        pub fn open(allocator: std.mem.Allocator, log: Log.Log, objects: Objects.ObjectStore, request: Initialization.Request, guard: Guard, options: Options) !Self {
            if (std.meta.activeTag(request.declared.declaration.configuration.policy) != kind) return error.LogPartitionConflict;
            if (kind == .queue and (options.queue_claim_rows == 0 or options.queue_claim_rows > QueueSelection.max_rows)) return error.InvalidQueueClaimBudget;
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
            return .{ .allocator = allocator, .log = log, .objects = objects, .store = store, .cache = cache, .scratch = .init(allocator), .encoded = encoded, .key_buffer = key_buffer, .options = options, .root = try Root.initial(request), .commitment = initial.record.sha256, .candidate_objects = candidates, .queue_container = if (kind == .queue) .{} else {}, .queue_leases = queue_leases, .queue_selection = queue_selection };
        }
        pub fn deinit(self: *Self) !void {
            try self.cache.deinit();
            self.store.deinit();
            self.scratch.deinit();
            if (kind == .queue) {
                self.candidate_objects.deinit();
                self.allocator.free(self.queue_leases);
                self.allocator.free(self.queue_selection);
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
            if (try self.log.tail(self.root.initialization.partition) != self.root.next_lsn) {
                self.ready = false;
                return error.LogRecoveryRequired;
            }
        }
        fn requireTarget(self: *Self, target: q.Partition) !void {
            try target.validate();
            if (target.partition != self.root.initialization.ordinal or !std.meta.eql(target.interpretation.object, self.root.initialization.declared.declaration.interpretation.object)) return error.LogPartitionConflict;
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
            return .{ .store = &self.store, .scratch = &self.scratch, .bitmap = bitmap, .container = &self.queue_container, .key_buffer = self.key_buffer };
        }
        fn queueTime(self: *Self, floor: ?u64) !Time.Sample {
            return (Time.bounds(self.options.clock, floor, true) catch |err| return if (err == error.LogTimeUnavailable) error.QueueTimeUnavailable else err).?;
        }
        pub fn claim(self: *Self, declared: Declaration.Stored, request: q.Claim, guard: Guard) !q.ClaimReceipt {
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
        fn queueCanonicalKey(self: *Self, offset: u64, guard: Guard) ![]const u8 {
            const policy = self.root.initialization.declared.declaration.configuration.policy.queue;
            const key_column = policy.key_column orelse return error.InvalidQueueHead;
            var declaration = try Declaration.load(self.allocator, self.objects, self.root.initialization.declared);
            defer declaration.deinit();
            const ci = try declaration.definition.schema.index(key_column);
            const column = declaration.definition.schema.columns[ci];
            const cut: q.Cut = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = self.root.declared.declaration.interpretation, .partition = self.root.initialization.ordinal }, .accepted = self.root.position(), .retained_from = 0, .next = self.root.next_offset };
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
            var bitmap: Bitmap = undefined;
            const expired = try self.queueIndex(&bitmap).firstExpired(self.root.queue.?, now.earliest_ms) orelse {
                try authorize(guard);
                return false;
            };
            const action: @FieldType(@FieldType(r.Record, "action"), "queue_expire") = .{ .lease = expired.lease.?, .observed = now };
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
            try self.candidate_objects.persist();
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .queue_expire = action } }, &.{}, guard);
            return true;
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
            if (evidence.outcome == .offset or evidence.outcome == .release or evidence.outcome == .settlement)
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
                .claim => |value| if (kind == .queue) {
                    result.clock_ms = try Time.advance(self.root.clock_ms, value.observed.latest_ms);
                    result.queue = try self.candidateClaim(evidence);
                } else return error.InvalidLogHistory,
                .settlement => |value| if (kind == .queue) {
                    result.clock_ms = try Time.advance(self.root.clock_ms, value.observed.latest_ms);
                    result.queue = try self.candidateSettlement(evidence, guard);
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
                        const index: QueueIndex = .{ .store = &self.store, .scratch = &self.scratch, .bitmap = &bitmap, .container = &self.queue_container, .key_buffer = self.key_buffer };
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
                .release, .offset, .settlement => true,
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
            const next = try self.candidate(evidence, payload, guard);
            const record: r.Record = .{ .definition = p.Growth.current_definition, .previous = self.commitment, .root = next, .action = .{ .operation = evidence } };
            if (kind == .queue) try self.candidate_objects.persist();
            try self.publishRecord(record, payload, guard);
            // Cache admission is optional after acceptance. Pressure cannot turn an
            // accepted append into rejection; reads can load its verified WAL payload.
            if (evidence.outcome == .append) self.cache.admit(.{ .position = evidence.accepted(), .content = evidence.outcome.append.append.payload }, payload) catch {};
        }
        fn publishRecord(self: *Self, input: r.Record, payload: []const u8, guard: Guard) !void {
            var record = input;
            record.root.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, record.root, record.action);
            const next = record.root;
            if (next.next_lsn != (try self.nextPosition()).next_lsn or !std.mem.eql(u8, &record.previous, &self.commitment)) return error.InvalidLogHistory;
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
            var borrowed = (try self.borrowWithinBudget(try self.root.cut(self.root.declared), self.root.batches, self.root.segments, self.root.hidden, receipt.first, guard, allocator)) orelse return error.LogHistoryUnavailable;
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

        pub const ExpirationStatus = enum { progress, complete, consumer, unsealed, untimed, not_due };
        pub const ExpirationProgress = struct { cut: d.Position, position: d.Position, retained_from: u64, expired_rows: u32, status: ExpirationStatus };
        fn expirationObservation(self: *Self, cut: d.Position, status: ExpirationStatus, guard: Guard) !ExpirationProgress {
            try authorize(guard);
            return .{ .cut = cut, .position = self.root.position(), .retained_from = self.root.retained_from, .expired_rows = 0, .status = status };
        }
        fn validateExpiration(self: *Self, declared: Declaration.Stored, receipt: q.AppendReceipt, now: Time.Sample, protected: u64) !void {
            if (self.root.compaction != null) return error.LogMaintenanceConflict;
            try self.root.requireDeclaration(declared);
            const age = declared.declaration.configuration.retention.max_age_ms orelse return error.LogRetentionNotDeclared;
            try now.validate();
            _ = try Time.advance(self.root.clock_ms, now.latest_ms);
            const observed = receipt.observed_ms orelse return error.InvalidLogExpiration;
            if (now.earliest_ms < observed) return error.InvalidLogExpiration;
            if (receipt.first != self.root.retained_from or receipt.next > self.root.sealed_through or protected != try self.protectedOffset() or receipt.next > protected or now.earliest_ms - observed < age) return error.InvalidLogExpiration;
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
            try self.root.requireDeclaration(declared);
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
            const observed = receipt.observed_ms orelse return self.expirationObservation(cut, .untimed, guard);
            const now = (try Time.bounds(self.options.clock, self.root.clock_ms, true)).?;
            if (now.earliest_ms < observed or now.earliest_ms - observed < age) return self.expirationObservation(cut, .not_due, guard);
            try self.validateExpiration(declared, receipt, now, protected);
            const complete = try self.flushCandidate(receipt.next, cut) == null;
            const ordinary = self.enterControl(true);
            defer self.leaveControl(ordinary);
            try self.store.begin(self.options.index_work_bytes);
            defer self.store.end();
            var next = self.root;
            next.declared = declared;
            next.next_lsn = (try self.nextPosition()).next_lsn;
            next.clock_ms = now.latest_ms;
            next.retained_from = receipt.next;
            const key = try r.integerKey(receipt.next);
            next.batches = try self.tree().remove(next.batches, key);
            next.segments = try self.tree().remove(next.segments, key);
            try self.publishRecord(.{ .definition = p.Growth.current_definition, .root = next, .previous = self.commitment, .action = .{ .expire = .{ .cut = cut, .receipt = receipt, .observed_ms = now.earliest_ms, .clock_ms = now.latest_ms, .protected_next = protected } } }, &.{}, guard);
            return .{ .cut = cut, .position = next.position(), .retained_from = next.retained_from, .expired_rows = @intCast(receipt.append.rows), .status = if (complete) .complete else .progress };
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
            for ([_]?pages.Reference{ self.root.batches, self.root.segments, self.root.hidden.containers, self.root.receipts, self.root.producers, self.root.producer_receipts, self.root.groups, self.root.group_offsets, self.root.pins, self.root.archive.directory }) |reference| if (reference) |value| {
                _ = try self.store.load(value);
            };
            if (self.root.queue) |queue| for ([_]?pages.Reference{ queue.items, queue.sidecars, queue.keys, queue.eligible, queue.deadlines }) |reference| if (reference) |value| {
                _ = try self.store.load(value);
            };
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
            const next = record.root;
            try self.root.initialization.requireSame(next.initialization);
            if (kind == .queue and (record.action == .operation or record.action == .queue_expire)) {
                const ordinary = self.enterControl(true);
                defer self.leaveControl(ordinary);
                try self.candidate_objects.reset(self.objects);
                self.objects = self.candidate_objects.objectStore();
                self.store.store = self.objects;
                self.store.clearCache();
                defer self.store.clearCache();
                try self.store.begin(self.options.index_work_bytes);
                defer self.store.end();
                var expected = if (record.action == .operation)
                    try self.candidate(record.action.operation, payload, guard)
                else
                    try self.candidateQueueExpiry(next.declared, record.action.queue_expire);
                expected.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, next, record.action);
                if (!std.meta.eql(expected, next)) return error.InvalidLogHistory;
                return;
            }
            if (record.action != .operation) {
                var expected = self.root;
                expected.next_lsn = next.next_lsn;
                expected.maintenance = try @import("StreamMaintenanceState.zig").transition(self.root, next, record.action);
                switch (record.action) {
                    .operation => unreachable,
                    .queue_expire => return error.InvalidLogHistory,
                    .maintenance => {},
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
            expected.receipts = next.receipts;
            switch (evidence.outcome) {
                .claim, .settlement => return error.InvalidLogHistory,
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
            const binding: Tail.Binding = .{ .position = receipt.accepted, .content = receipt.append.payload, .view = if (segment) |value| (if (value.layout == .sparse) value.view else null) else null };
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

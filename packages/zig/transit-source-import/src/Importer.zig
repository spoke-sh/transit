const std = @import("std");
const root = @import("root.zig");
const c = root.data.catalog;
const p = c.protocol;
const Capture = c.DirectSourceCapture;
const Saved = root.Saved;
const Journal = root.Journal;

/// Origin supplies current-authorized Exchange open/read, original verification,
/// a combined publication guard, and authenticated retain/release operations for
/// the saved token/holder. These callbacks belong to the explicitly trusted host;
/// arbitrary caller assertions and a declaration executor ID are insufficient.
pub fn Importer(comptime Origin: type) type {
    return struct {
        const Self = @This();
        const Replay = root.http.ReplayWithClient(Origin);
        pub const scratch_bytes = 2 * 1024 * 1024;
        saved: Saved,
        origin: *Origin,
        journal: Journal,
        admission: *Capture.Admission,
        active: Capture.Admission = .{ .limit = Capture.resident_bytes },
        memory: c.fuze.MemoryBudget,
        scratch: std.heap.ArenaAllocator,
        replay: ?Replay = null,
        verifier: ?Capture.Verifier = null,
        hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
        raw: [Capture.storage.chunk_bytes]u8 = undefined,
        used: usize = 0,
        body_bytes: u64 = 0,
        read_bytes: u64 = 0,
        read_parts: u64 = 0,
        expected: ?p.SourceCapture.Evidence = null,

        /// Saved's borrowed strings and Origin must outlive this stable owner.
        pub fn init(self: *Self, allocator: std.mem.Allocator, saved: Saved, origin: *Origin, journal: Journal, admission: *Capture.Admission) !void {
            try saved.validate();
            try admission.acquire();
            errdefer admission.release();
            // Reserve the adapter and its nested candidate operation together.
            // Accepted active owners cannot exhaust the pool and deadlock while
            // each waits to acquire its own staging/verification workspace.
            try admission.acquire();
            self.* = .{ .saved = saved, .origin = origin, .journal = journal, .admission = admission, .memory = .{ .parent = allocator, .limit = scratch_bytes }, .scratch = undefined };
            self.scratch = .init(self.memory.allocator());
        }
        pub fn deinit(self: *Self) void {
            self.resetPass();
            self.scratch.deinit();
            self.admission.release();
            self.admission.release();
            std.debug.assert(self.memory.used == 0);
            self.* = undefined;
        }
        fn resetPass(self: *Self) void {
            self.replay = null;
            if (self.verifier) |*value| value.deinit();
            self.verifier = null;
            @memset(&self.raw, 0);
            self.used = 0;
            self.body_bytes = 0;
            self.read_bytes = 0;
            self.read_parts = 0;
            self.hash = .init(.{});
        }
        fn verifyOriginal(raw: *anyopaque, evidence: p.SourceCapture.Evidence) !void {
            const self: *Self = @ptrCast(@alignCast(raw));
            if (self.expected == null or !std.meta.eql(self.expected.?, evidence)) return error.SourceOriginalUnverified;
            try self.origin.authorize(self.saved);
        }
        fn guard(raw: *anyopaque, allocator: std.mem.Allocator, required: p.Authorization.Guard, evidence: p.SourceCapture.Evidence) !c.storage.PublicationGuard {
            const self: *Self = @ptrCast(@alignCast(raw));
            if (self.expected == null or !std.meta.eql(self.expected.?, evidence)) return error.SourceOriginalUnverified;
            return self.origin.guard(allocator, required, self.saved);
        }
        fn destination(self: *Self) root.data.CaptureOwner {
            return .{ .catalog = self.journal.catalog, .policy = self.journal.policy, .authority = .{ .context = self, .admission = &self.active, .verify_original = verifyOriginal, .make_guard = guard } };
        }
        pub fn inspect(self: *Self) !?Journal.Observation {
            _ = self.scratch.reset(.retain_capacity);
            return self.journal.inspect(self.scratch.allocator(), self.saved);
        }
        pub fn cancel(self: *Self) !Journal.State {
            _ = self.scratch.reset(.retain_capacity);
            self.resetPass();
            const allocator = self.scratch.allocator();
            const observed = try self.resumeOriginal(allocator);
            if (observed.state.phase == .released or observed.state.cancel) return observed.state;
            var next = observed.state;
            next.cancel = true;
            return (try self.journal.advance(allocator, self.saved, observed, next)).state;
        }
        fn resumeOriginal(self: *Self, allocator: std.mem.Allocator) !Journal.Observation {
            const observed = self.journal.inspect(allocator, self.saved) catch |err| {
                if (err != error.OwnedRecordPending) return err;
                return self.journal.reserve(allocator, self.saved);
            };
            return observed orelse try self.journal.reserve(allocator, self.saved);
        }
        /// One durable transition or at most 256 Exchange parts. Reopening a
        /// pass charges its entire bounded coverage before any read; uncertain
        /// progress never refunds work. No body-sized allocation is made.
        pub fn step(self: *Self) !Journal.State {
            _ = self.scratch.reset(.retain_capacity);
            errdefer self.resetPass();
            const allocator = self.scratch.allocator();
            var observed = try self.resumeOriginal(allocator);
            var next = observed.state;
            self.expected = next.evidence;
            if (next.phase == .released) return next;
            // Closure needs no body work budget. A denied/uncertain original
            // operation remains pending, and cannot become an inferred abort.
            if (next.cancel) return self.closeOriginal(allocator, observed);
            switch (next.phase) {
                .reserved => {
                    try self.origin.authorize(self.saved);
                    try self.origin.retain(self.saved);
                    next.phase = .held;
                },
                .held, .copying => {
                    if (self.replay == null) {
                        next.work_bytes = try std.math.add(u64, next.work_bytes, self.saved.origin.descriptor.bytes);
                        next.work_parts = try std.math.add(u64, next.work_parts, self.saved.passParts());
                        if (next.work_bytes > self.saved.work.bytes or next.work_parts > self.saved.work.parts) return error.SourceHandoffWorkLimit;
                        observed = try self.journal.advance(allocator, self.saved, observed, next);
                        try self.origin.authorize(self.saved);
                        self.replay = try Replay.open(self.origin, self.saved.origin.reference, .captured);
                        if (!std.meta.eql(self.replay.?.cursor.descriptor, self.saved.origin.descriptor)) return error.SourceOriginalUnverified;
                    }
                    if (!try self.readPass(next.phase == .copying)) return observed.state;
                    const completion = try self.replay.?.validator.finish();
                    const evidence = try self.saved.evidence(completion, .{ .bytes = self.body_bytes, .sha256 = self.hash.finalResult() });
                    if (next.phase == .held) {
                        next.evidence = evidence;
                        next.phase = .verified;
                    } else {
                        if (!std.meta.eql(evidence, next.evidence.?)) return error.SourceOriginalUnverified;
                        next.phase = .copied;
                    }
                    self.resetPass();
                },
                .verified => {
                    _ = try self.destination().reserve(try self.saved.descriptor(next.evidence.?));
                    next.phase = .copying;
                },
                .copied => {
                    if (self.verifier == null) self.verifier = try Capture.Verifier.init(self.saved.candidate.key, &self.active);
                    const capture = try self.destination().verify(&self.verifier.?, .{ .bytes = Capture.storage.chunk_bytes, .pages = 64 });
                    if (capture.state.phase != .verified) return next;
                    next.manifest = capture.state.manifest;
                    self.resetPass();
                    next.phase = .sealed;
                },
                .sealed => {
                    // Journal the decision intent before entering the protected
                    // transaction so cancellation can inspect that same original.
                    next.phase = .publishing;
                },
                .publishing => {
                    var capture = try self.destination().publish(try self.saved.plan(next.manifest.?));
                    capture = try self.destination().advance(self.saved.candidate.key, .commit, 8);
                    if (capture.state.phase == .closed or capture.state.phase == .aborted) return error.SourceCaptureClosed;
                    if (capture.state.phase != .published) return next;
                    next.outcome = capture.state.outcome;
                    next.phase = .settled;
                },
                .settled => {
                    try self.origin.release(self.saved);
                    next.phase = .released;
                },
                .released => unreachable,
            }
            return (try self.journal.advance(allocator, self.saved, observed, next)).state;
        }
        fn readPass(self: *Self, copying: bool) !bool {
            for (0..256) |_| {
                const part = (try self.replay.?.read()) orelse return error.HttpReplayGap;
                self.read_bytes = try std.math.add(u64, self.read_bytes, part.bytes.len);
                self.read_parts += 1;
                if (self.read_bytes > self.saved.origin.descriptor.bytes or self.read_parts > self.saved.passParts()) return error.SourceHandoffWorkLimit;
                if (part.kind == .response_body) {
                    const bytes = part.bytes.slice();
                    self.body_bytes = try std.math.add(u64, self.body_bytes, bytes.len);
                    if (self.body_bytes > self.saved.source.http.response_max_bytes) return error.SourceCaptureWorkLimit;
                    self.hash.update(bytes);
                    if (copying) {
                        var remaining = bytes;
                        while (remaining.len != 0) {
                            const count = @min(self.raw.len - self.used, remaining.len);
                            @memcpy(self.raw[self.used..][0..count], remaining[0..count]);
                            self.used += count;
                            remaining = remaining[count..];
                            if (self.used == self.raw.len) try self.upload(self.body_bytes - remaining.len - self.used);
                        }
                    }
                }
                if (part.complete) {
                    if (self.read_bytes != self.saved.origin.descriptor.bytes) return error.HttpReplayGap;
                    if (copying and self.used != 0) try self.upload(self.body_bytes - self.used);
                    return true;
                }
            }
            return false;
        }
        fn upload(self: *Self, offset: u64) !void {
            const original = (try self.destination().inspect(.{ .key = self.saved.candidate.key })) orelse return error.SourceOriginalUnverified;
            _ = try self.destination().upload(.{ .control = .{ .key = self.saved.candidate.key, .expected = original.revision }, .chunk = .{ .offset = offset, .content = c.storage.LogBatch.content(self.raw[0..self.used]) }, .bytes = self.raw[0..self.used] });
            @memset(&self.raw, 0);
            self.used = 0;
        }
        fn closeOriginal(self: *Self, allocator: std.mem.Allocator, observed: Journal.Observation) !Journal.State {
            var next = observed.state;
            if (next.phase == .settled) {
                try self.origin.release(self.saved);
                next.phase = .released;
            } else {
                // Resolve an uncertain hold with its permanent token before
                // considering its release. Never dispose the finite caller hold.
                if (next.phase == .reserved) try self.origin.retain(self.saved);
                if (next.evidence != null) {
                    if (try self.destination().inspect(.{ .key = self.saved.candidate.key })) |original| {
                        if (original.state.phase == .publishing) {
                            const result = try self.destination().advance(self.saved.candidate.key, .abort, 8);
                            if (result.state.phase == .publishing) return next;
                            next.outcome = result.state.outcome;
                        } else if (original.state.phase == .published) next.outcome = original.state.outcome else {
                            _ = try self.destination().close(.{ .key = self.saved.candidate.key, .expected = original.revision });
                            next.outcome = original.state.outcome;
                        }
                    }
                }
                next.phase = .settled;
            }
            return (try self.journal.advance(allocator, self.saved, observed, next)).state;
        }
    };
}

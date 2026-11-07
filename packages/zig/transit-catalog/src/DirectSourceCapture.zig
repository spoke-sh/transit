//! Destination-owned raw captures; staging is private until an original
//! transaction attaches a complete verified manifest to its Stream envelope.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const Token = c.DirectClientToken;
pub const storage = c.storage.CaptureChunks;
pub const format: u32 = 0x53434331; // SCC1, reserved original candidate descriptor.
pub const manifest_format: u32 = 0x53434d31; // SCM1, no generic record access.
pub const publication_bytes = 64 * 1024;
pub const index_bytes = publication_bytes - @import("DirectCatalogRecords.zig").max_record_bytes;
pub const initial_bytes = 6 * publication_bytes;
pub const resident_bytes = 8 * 1024 * 1024;
pub const aggregate_resident_bytes = 64 * 1024 * 1024;
pub const Limits = c.DirectDocumentSource.Limits;

pub const Descriptor = struct {
    key: Token.Key,
    operation: d.Operation,
    namespace: u64,
    evidence: p.SourceCapture.Evidence,
    budget: Token.Budget,
    limits: Limits,

    pub fn validate(self: Descriptor) !void {
        try self.key.validate();
        try self.operation.validate();
        try self.key.connection.owner(self.operation);
        try self.evidence.validate();
        try self.key.connection.object(self.evidence.destination.object);
        try self.budget.validate();
        try self.limits.validate();
        if (!std.meta.eql(self.operation, self.evidence.poll.operation) or self.namespace == 0 or self.budget.bytes < initial_bytes or self.limits.work_bytes < initial_bytes)
            return error.InvalidSourceCapture;
    }
    pub fn encode(self: Descriptor, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        const payload = try p.Json.valueAllocBounded(allocator, self, 16 * 1024);
        defer allocator.free(payload);
        const binary = try c.DirectTableProtocol.Binary.encode(allocator, payload);
        defer allocator.free(binary.base64);
        return c.DirectOwnedRecord.encode(allocator, self.key, format, binary);
    }
    pub fn requireBinding(self: Descriptor, accepted: Token.Binding) !void {
        var bytes: [64 * 1024]u8 = undefined;
        var scratch: std.heap.FixedBufferAllocator = .init(&bytes);
        if (!std.meta.eql(accepted, try self.binding(scratch.allocator()))) return error.InvalidSourceCapture;
    }
    pub fn binding(self: Descriptor, allocator: std.mem.Allocator) !Token.Binding {
        const bytes = try self.encode(allocator);
        defer allocator.free(bytes);
        const reference = try c.DirectRecord.reference(self.key.scope(), c.DirectOwnedRecord.format, bytes);
        return .{ .key = self.key, .fingerprint = reference.content.sha256, .budget = self.budget, .intent = .{ .external = .{
            .connection = self.key.connection,
            .namespace = self.namespace,
            .operation = self.operation.operation,
            .record = reference,
        } } };
    }
    pub fn target(self: Descriptor) p.StreamQueue.Partition {
        return .{ .definition = p.Growth.current_definition, .interpretation = self.evidence.destination, .partition = 0 };
    }
};

pub const Manifest = struct {
    definition: p.Growth.Definition,
    candidate: [32]u8,
    evidence: p.SourceCapture.Evidence,
    inventory: ?storage.pages.Reference,
    pub fn validate(self: Manifest) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.evidence.validate();
        if ((self.inventory == null) != (self.evidence.body.bytes == 0) or std.mem.allEqual(u8, &self.candidate, 0)) return error.InvalidSourceCapture;
    }
    pub fn encode(self: Manifest, allocator: std.mem.Allocator) ![]u8 {
        try self.validate();
        return p.Json.valueAllocBounded(allocator, self, 16 * 1024);
    }
    pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
        try content.validate();
        if (content.bytes > 16 * 1024) return error.InvalidSourceCapture;
        return std.fmt.bufPrint(output, "source-capture-manifests/{x}.data", .{&content.sha256});
    }
    pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, reference: p.SourceCapture.Reference) !Manifest {
        try reference.validate();
        var name: [96]u8 = undefined;
        const path = try key(reference.manifest, &name);
        const meta = try objects.head(path) orelse return error.SourceCaptureMissing;
        if (meta.size != reference.manifest.bytes or !std.mem.eql(u8, &meta.sha256, &reference.manifest.sha256)) return error.InvalidSourceCapture;
        var buffer: [16 * 1024]u8 = undefined;
        const bytes = try objects.getRange(path, 0, @intCast(reference.manifest.bytes), &buffer);
        if (!std.meta.eql(c.storage.LogBatch.content(bytes), reference.manifest)) return error.InvalidSourceCapture;
        const parsed = try p.Json.parseFromSlice(Manifest, allocator, bytes);
        defer parsed.deinit();
        const canonical = try parsed.value.encode(allocator);
        defer allocator.free(canonical);
        if (!std.mem.eql(u8, bytes, canonical) or !std.mem.eql(u8, &parsed.value.candidate, &reference.candidate) or
            !std.meta.eql(parsed.value.evidence.destination, reference.destination)) return error.InvalidSourceCapture;
        return parsed.value;
    }
};
pub const State = struct {
    descriptor: Descriptor,
    root: ?storage.pages.Reference,
    ready_bytes: u64,
    staged: ?storage.Chunk,
    phase: enum { uploading, sealing, verified, publishing, published, aborted, failed, closed },
    manifest: ?d.Content,
    publication: ?c.DirectSourcePublication,
    outcome: ?struct { decision: p.Transaction.Decision, append: ?p.StreamQueue.AppendReceipt },
    observed: ?[32]u8,
    charged_bytes: u64,
    work_bytes: u64,
    work_pages: u64,

    pub fn initial(descriptor: Descriptor) State {
        return .{ .descriptor = descriptor, .root = null, .ready_bytes = 0, .staged = null, .phase = .uploading, .manifest = null, .publication = null, .outcome = null, .observed = null, .charged_bytes = initial_bytes, .work_bytes = initial_bytes, .work_pages = 0 };
    }
    pub fn validate(self: State) !void {
        try self.descriptor.validate();
        if (self.ready_bytes > self.descriptor.evidence.body.bytes or (self.root != null) != (self.ready_bytes != 0) or
            (self.ready_bytes != self.descriptor.evidence.body.bytes and self.ready_bytes % storage.chunk_bytes != 0) or
            self.charged_bytes < initial_bytes or self.charged_bytes > self.descriptor.budget.bytes or
            self.work_bytes > self.descriptor.limits.work_bytes or self.work_pages > self.descriptor.limits.work_pages)
            return error.InvalidSourceCaptureState;
        if (self.staged) |chunk| {
            try chunk.validate(self.descriptor.evidence.body.bytes);
            if (self.phase != .uploading or chunk.offset != self.ready_bytes) return error.InvalidSourceCaptureState;
        }
        const sealed = self.phase == .sealing or self.phase == .verified or self.phase == .publishing or self.phase == .published or self.phase == .aborted;
        if (sealed or self.phase == .failed) {
            if (self.ready_bytes != self.descriptor.evidence.body.bytes or self.staged != null or self.observed == null or
                (self.phase != .failed) != std.mem.eql(u8, &self.observed.?, &self.descriptor.evidence.body.sha256)) return error.InvalidSourceCaptureState;
        } else if (self.phase == .uploading and self.observed != null) return error.InvalidSourceCaptureState;
        if (sealed != (self.manifest != null) and self.phase != .closed) return error.InvalidSourceCaptureState;
        if (self.manifest) |manifest| try manifest.validate();
        if ((self.phase == .publishing or self.phase == .published or self.phase == .aborted) != (self.publication != null) and self.phase != .closed) return error.InvalidSourceCaptureState;
        if (self.publication) |publication| try publication.requireCandidate(self);
        const settled = self.phase == .published or self.phase == .aborted or (self.phase == .closed and self.publication != null);
        if (settled != (self.outcome != null)) return error.InvalidSourceCaptureState;
        if (self.outcome) |outcome| {
            try outcome.decision.validate();
            const publication = self.publication orelse return error.InvalidSourceCaptureState;
            if (!std.meta.eql(outcome.decision.attempt.transaction.begin, publication.operation) or
                !std.meta.eql(outcome.decision.attempt.operation, publication.settlement) or
                (outcome.decision.outcome == .committed) != (self.phase == .published) or
                (outcome.append != null) != (self.phase == .published)) return error.InvalidSourceCaptureState;
            if (outcome.append) |receipt| {
                try receipt.validate();
                if (!std.meta.eql(receipt.append.operation, publication.append) or receipt.append.capture == null or
                    !std.meta.eql(receipt.append.capture.?.reference, publication.reference) or
                    !std.meta.eql(receipt.append.capture.?.transaction, outcome.decision.attempt.transaction)) return error.InvalidSourceCaptureState;
            }
        }
    }
    pub fn charge(self: *State, bytes: u64, pages: u64, retained: u64) !void {
        var next = self.*;
        next.work_bytes = try std.math.add(u64, next.work_bytes, bytes);
        next.work_pages = try std.math.add(u64, next.work_pages, pages);
        next.charged_bytes = try std.math.add(u64, next.charged_bytes, retained);
        if (next.work_bytes > next.descriptor.limits.work_bytes or next.work_pages > next.descriptor.limits.work_pages) return error.SourceCaptureWorkLimit;
        if (next.charged_bytes > next.descriptor.budget.bytes) return error.ClientTokenBudget;
        self.* = next;
    }
    pub fn transition(before: State, after: State) !void {
        try before.validate();
        try after.validate();
        if (!std.meta.eql(before.descriptor, after.descriptor) or before.phase == .closed or
            after.ready_bytes < before.ready_bytes or after.charged_bytes < before.charged_bytes or
            after.work_bytes < before.work_bytes or after.work_pages < before.work_pages) return error.InvalidSourceCaptureTransition;
        if (after.phase == .closed) {
            if (before.phase == .publishing or before.phase == .published) return error.InvalidSourceCaptureTransition;
            var expected = before;
            expected.phase = .closed;
            expected.staged = null;
            if (!std.meta.eql(expected, after)) return error.InvalidSourceCaptureTransition;
            return;
        }
        if (before.phase == .verified and after.phase == .publishing) {
            var expected = before;
            expected.phase = .publishing;
            expected.publication = after.publication;
            expected.charged_bytes = after.charged_bytes;
            expected.work_bytes = after.work_bytes;
            expected.work_pages = after.work_pages;
            if (!std.meta.eql(expected, after)) return error.InvalidSourceCaptureTransition;
            return;
        }
        if (before.phase == .publishing and (after.phase == .published or after.phase == .aborted)) {
            var expected = before;
            expected.phase = after.phase;
            expected.outcome = after.outcome;
            if (!std.meta.eql(expected, after)) return error.InvalidSourceCaptureTransition;
            return;
        }
        if (before.phase == .sealing and after.phase == .verified) {
            var expected = before;
            expected.phase = .verified;
            if (!std.meta.eql(expected, after)) return error.InvalidSourceCaptureTransition;
            return;
        }
        if (before.phase != .uploading) {
            var charged = before;
            charged.charged_bytes = after.charged_bytes;
            charged.work_bytes = after.work_bytes;
            charged.work_pages = after.work_pages;
            if (!std.meta.eql(charged, after)) return error.InvalidSourceCaptureTransition;
            return;
        }
        if (after.ready_bytes != before.ready_bytes) {
            const chunk = before.staged orelse return error.InvalidSourceCaptureTransition;
            if (after.ready_bytes != try std.math.add(u64, chunk.offset, chunk.content.bytes) or after.staged != null or
                after.phase != .uploading or after.charged_bytes != before.charged_bytes or
                after.work_bytes != before.work_bytes or after.work_pages != before.work_pages) return error.InvalidSourceCaptureTransition;
        } else {
            if (!std.meta.eql(before.root, after.root)) return error.InvalidSourceCaptureTransition;
            if (before.staged != null and !std.meta.eql(before.staged, after.staged)) return error.InvalidSourceCaptureTransition;
        }
    }
};

pub const Control = c.DirectOwnedRecord.Control;
pub const Upload = struct { control: Control, chunk: storage.Chunk, bytes: []const u8 };
pub const StepBudget = struct {
    bytes: u32,
    pages: u32,
    pub fn validate(self: StepBudget) !void {
        if (self.bytes == 0 or self.bytes > storage.step_bytes or self.pages == 0) return error.InvalidSourceCaptureLimits;
    }
};
pub const Admission = struct {
    limit: u64 = aggregate_resident_bytes,
    used: u64 = 0,
    pub fn acquire(self: *Admission) !void {
        if (self.used > self.limit or resident_bytes > self.limit - self.used) return error.SourceCaptureResidentLimit;
        self.used += resident_bytes;
    }
    pub fn release(self: *Admission) void {
        std.debug.assert(self.used >= resident_bytes);
        self.used -= resident_bytes;
    }
};

/// The host verifies a retained original and composes its source disclosure
/// requirements with the Catalog's destination requirements. No installed
/// capture mutation route supplies this authority implicitly.
pub const Authority = struct {
    context: *anyopaque,
    admission: *Admission,
    verify_original: *const fn (*anyopaque, p.SourceCapture.Evidence) anyerror!void,
    make_guard: *const fn (*anyopaque, std.mem.Allocator, p.Authorization.Guard, p.SourceCapture.Evidence) anyerror!c.storage.PublicationGuard,
};
pub const Lookup = union(enum) {
    key: Token.Key,
    operation: struct { scope: c.DirectRecord.Scope, id: u64 },
    pub fn scope(self: Lookup) c.DirectRecord.Scope {
        return switch (self) {
            .key => |key| key.scope(),
            .operation => |value| value.scope,
        };
    }
};
pub const Selection = struct {
    scope: c.DirectRecord.Scope,
    pending: bool,
    pub fn validate(self: Selection) !void {
        try self.scope.validate();
    }
};
pub const Cursor = struct { selection: Selection, after: u64 };
pub const Page = struct { entries: [8]?Observation = @splat(null), next: ?Cursor = null, examined: u8 = 0 };
pub const Observation = struct {
    revision: d.Position,
    descriptor: Descriptor,
    state: State,
    pub fn from(progress: Token.Progress) !Observation {
        const state = progress.capture orelse return error.SourceCaptureOperationRequired;
        return .{ .revision = progress.revision, .descriptor = state.descriptor, .state = state };
    }
};
/// Trusted process-local continuation: never deserialize it from a caller.
/// Reopening starts again at zero; completed step charges survive process loss.
pub const Verifier = struct {
    key: Token.Key,
    admission: *Admission,
    root: ?storage.pages.Reference = null,
    offset: u64 = 0,
    hash: std.crypto.hash.sha2.Sha256 = .init(.{}),
    buffer: [storage.chunk_bytes]u8 = undefined,
    held: bool = true,
    done: bool = false,
    pub fn init(key: Token.Key, admission: *Admission) !Verifier {
        try key.validate();
        try admission.acquire();
        return .{ .key = key, .admission = admission };
    }
    pub fn deinit(self: *Verifier) void {
        if (self.held) self.admission.release();
        self.held = false;
        @memset(&self.buffer, 0);
    }
};

test "SOURCE capture independent commitment namespace and mandatory saved owner" {
    const t = std.testing;
    const Fixture = struct { descriptor: Descriptor, binding: Token.Binding, chunk_key: []const u8 };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/source-capture-v1.json"));
    defer fixture.deinit();
    const value = fixture.value;
    try value.descriptor.validate();
    try value.descriptor.requireBinding(value.binding);
    const chunk: storage.Chunk = .{ .offset = 0, .content = .{ .bytes = value.descriptor.evidence.body.bytes, .sha256 = value.descriptor.evidence.body.sha256 } };
    var path: [96]u8 = undefined;
    try t.expectEqualStrings(value.chunk_key, try storage.key(try value.descriptor.key.digest(), chunk, &path));
    var changed = value.descriptor;
    changed.evidence.terminal.sha256[0] ^= 1;
    try t.expectError(error.InvalidSourceCapture, changed.requireBinding(value.binding));
    var progress = Token.Progress.initial(.{ .binding = value.binding, .position = .{ .partition = 1, .next_lsn = 2 }, .coordination = null });
    progress.capture = .initial(value.descriptor);
    try progress.validate();
    progress.capture = null;
    const encoded = try p.Json.valueAlloc(t.allocator, progress);
    defer t.allocator.free(encoded);
    const omitted = try std.mem.replaceOwned(u8, t.allocator, encoded, ",\"capture\":null", "");
    defer t.allocator.free(omitted);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(Token.Progress, t.allocator, omitted));
}

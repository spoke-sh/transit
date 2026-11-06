//! Protected Document source ownership. Source verification is independent of
//! profile validation, logical tree construction and Document acceptance.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const Token = c.DirectClientToken;
pub const storage = c.storage.DocumentSource;
pub const format: u32 = 0x44535331; // DSS1 inside a Catalog-owned SOR1 envelope.
// One charged publication covers bounded index writes plus the WAL record.
pub const publication_bytes = 64 * 1024;
pub const index_bytes = publication_bytes - @import("DirectCatalogRecords.zig").max_record_bytes;
// Descriptor bytes plus reservation, readiness and the reserved close step.
pub const initial_bytes = 4 * publication_bytes;
pub const resident_bytes = 8 * 1024 * 1024;
pub const aggregate_resident_bytes = 64 * 1024 * 1024;

pub const Limits = struct {
    work_bytes: u64,
    work_pages: u64,
    pub fn validate(self: Limits) !void {
        if (self.work_bytes == 0 or self.work_pages == 0) return error.InvalidDocumentSourceLimits;
    }
};

pub const Descriptor = struct {
    key: Token.Key,
    operation: d.Operation,
    namespace: u64,
    target: p.DocumentOperation.Target,
    kind: enum { create, replace },
    expected: ?p.DocumentOperation.Cut,
    profile: p.DocumentProfile.Descriptor,
    part: u32,
    source: d.Content,
    budget: Token.Budget,
    limits: Limits,

    pub fn validate(self: Descriptor) !void {
        try self.key.validate();
        try self.target.requireOperation(self.operation);
        try self.key.connection.object(self.target.partition.interpretation.object);
        try self.profile.validate();
        try self.source.validate();
        try self.budget.validate();
        try self.limits.validate();
        if (self.operation.principal != self.key.connection.principal or self.namespace == 0 or self.part == 0 or
            (self.kind == .replace) != (self.expected != null) or self.profile.framing != .single or
            self.source.bytes > self.profile.limits.input_bytes or self.budget.bytes < initial_bytes or self.limits.work_bytes < initial_bytes)
            return error.InvalidDocumentSource;
        if (self.expected) |cut| {
            try cut.validate();
            try self.target.requireSame(cut.target);
        }
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
        var bytes: [48 * 1024]u8 = undefined;
        var scratch: std.heap.FixedBufferAllocator = .init(&bytes);
        if (!std.meta.eql(accepted, try self.binding(scratch.allocator()))) return error.InvalidDocumentSource;
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
};

pub const State = struct {
    descriptor: Descriptor,
    root: ?storage.pages.Reference,
    ready_bytes: u64,
    staged: ?storage.Chunk,
    phase: enum { uploading, verified, failed, closed },
    observed: ?[32]u8,
    charged_bytes: u64,
    work_bytes: u64,
    work_pages: u64,

    pub fn initial(descriptor: Descriptor) State {
        return .{ .descriptor = descriptor, .root = null, .ready_bytes = 0, .staged = null, .phase = .uploading, .observed = null, .charged_bytes = initial_bytes, .work_bytes = initial_bytes, .work_pages = 0 };
    }
    pub fn validate(self: State) !void {
        try self.descriptor.validate();
        if (self.ready_bytes > self.descriptor.source.bytes or (self.root != null) != (self.ready_bytes != 0) or
            (self.ready_bytes != self.descriptor.source.bytes and self.ready_bytes % storage.chunk_bytes != 0) or
            self.charged_bytes < initial_bytes or self.charged_bytes > self.descriptor.budget.bytes or
            self.work_bytes > self.descriptor.limits.work_bytes or self.work_pages > self.descriptor.limits.work_pages)
            return error.InvalidDocumentSourceState;
        if (self.staged) |chunk| {
            try chunk.validate(self.descriptor.source.bytes);
            if (self.phase != .uploading or chunk.offset != self.ready_bytes) return error.InvalidDocumentSourceState;
        }
        if (self.phase == .verified or self.phase == .failed) {
            if (self.ready_bytes != self.descriptor.source.bytes or self.staged != null or self.observed == null or
                (self.phase == .verified) != std.mem.eql(u8, &self.observed.?, &self.descriptor.source.sha256)) return error.InvalidDocumentSourceState;
        } else if (self.phase == .uploading and self.observed != null) return error.InvalidDocumentSourceState;
    }
    pub fn charge(self: *State, bytes: u64, pages: u64, retained: u64) !void {
        var next = self.*;
        next.work_bytes = try std.math.add(u64, next.work_bytes, bytes);
        next.work_pages = try std.math.add(u64, next.work_pages, pages);
        next.charged_bytes = try std.math.add(u64, next.charged_bytes, retained);
        if (next.work_bytes > next.descriptor.limits.work_bytes or next.work_pages > next.descriptor.limits.work_pages) return error.DocumentSourceWorkLimit;
        if (next.charged_bytes > next.descriptor.budget.bytes) return error.ClientTokenBudget;
        self.* = next;
    }
    pub fn transition(before: State, after: State) !void {
        try before.validate();
        try after.validate();
        if (!std.meta.eql(before.descriptor, after.descriptor) or before.phase == .closed or
            after.ready_bytes < before.ready_bytes or after.charged_bytes < before.charged_bytes or
            after.work_bytes < before.work_bytes or after.work_pages < before.work_pages) return error.InvalidDocumentSourceTransition;
        if (after.phase == .closed) {
            var expected = before;
            expected.phase = .closed;
            expected.staged = null;
            if (!std.meta.eql(expected, after)) return error.InvalidDocumentSourceTransition;
            return;
        }
        if (before.phase != .uploading) {
            var charged = before;
            charged.charged_bytes = after.charged_bytes;
            charged.work_bytes = after.work_bytes;
            charged.work_pages = after.work_pages;
            if (!std.meta.eql(charged, after)) return error.InvalidDocumentSourceTransition;
            return;
        }
        if (after.ready_bytes != before.ready_bytes) {
            const chunk = before.staged orelse return error.InvalidDocumentSourceTransition;
            if (after.ready_bytes != try std.math.add(u64, chunk.offset, chunk.content.bytes) or after.staged != null or
                after.phase != .uploading or after.charged_bytes != before.charged_bytes or
                after.work_bytes != before.work_bytes or after.work_pages != before.work_pages) return error.InvalidDocumentSourceTransition;
        } else {
            if (!std.meta.eql(before.root, after.root)) return error.InvalidDocumentSourceTransition;
            if (before.staged != null and !std.meta.eql(before.staged, after.staged)) return error.InvalidDocumentSourceTransition;
        }
    }
};

pub const Control = c.DirectOwnedRecord.Control;
pub const Upload = struct { control: Control, chunk: storage.Chunk, bytes: []const u8 };
pub const StepBudget = struct {
    bytes: u32,
    pages: u32,
    pub fn validate(self: StepBudget) !void {
        if (self.bytes == 0 or self.bytes > storage.step_bytes or self.pages == 0) return error.InvalidDocumentSourceLimits;
    }
};
pub const Selection = struct {
    scope: c.DirectRecord.Scope,
    target: ?p.DocumentOperation.Target,
    pending: bool,
    pub fn validate(self: Selection) !void {
        try self.scope.validate();
        if (self.target) |target| {
            try target.validate();
            try self.scope.connection.object(target.partition.interpretation.object);
        }
    }
};
pub const Cursor = struct { selection: Selection, after: u64 };
pub const Entry = struct {
    id: u64,
    revision: d.Position,
    target: p.DocumentOperation.Target,
    expected: ?p.DocumentOperation.Cut,
    phase: enum { reserved, uploading, verified, failed, closed },
    ready_bytes: u64,
    source_bytes: u64,
    pub fn from(progress: Token.Progress) !Entry {
        const state = progress.source orelse return error.InvalidDocumentSource;
        return .{
            .id = progress.id(),
            .revision = progress.revision,
            .target = state.descriptor.target,
            .expected = state.descriptor.expected,
            .phase = if (progress.original.?.phase == .reserved) .reserved else switch (state.phase) {
                .uploading => .uploading,
                .verified => .verified,
                .failed => .failed,
                .closed => .closed,
            },
            .ready_bytes = state.ready_bytes,
            .source_bytes = state.descriptor.source.bytes,
        };
    }
};
pub const Page = struct { entries: [8]?Entry = @splat(null), next: ?Cursor = null, examined: u8 = 0 };

/// Host-shared active allocation admission, independent of retained account
/// charges. Sharing this across accounts also bounds every role of one account.
/// The host serializes admission and Catalog operations; no worker is spawned.
pub const Admission = struct {
    limit: u64 = aggregate_resident_bytes,
    used: u64 = 0,
    pub fn acquire(self: *Admission) !void {
        if (self.used > self.limit or resident_bytes > self.limit - self.used) return error.DocumentSourceResidentLimit;
        self.used += resident_bytes;
    }
    pub fn release(self: *Admission) void {
        std.debug.assert(self.used >= resident_bytes);
        self.used -= resident_bytes;
    }
};

/// Component-only native authorization composition. The embedding owner must
/// serialize Catalog access through each call and share admission across roles.
/// No installed Document authorization domain or signed route is enabled here.
pub const Access = enum { inspect, read, mutate };
pub const Authority = struct {
    context: *anyopaque,
    admission: *Admission,
    make_guard: *const fn (*anyopaque, std.mem.Allocator, p.Authorization.Guard, ?p.DocumentOperation.Target, Access) anyerror!c.storage.PublicationGuard,
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
pub const Observation = struct {
    entry: Entry,
    descriptor: Descriptor,
    staged: ?storage.Chunk,
    charged_bytes: u64,
    work_bytes: u64,
    work_pages: u64,
    pub fn from(progress: Token.Progress) !Observation {
        const source = progress.source orelse return error.InvalidDocumentSource;
        return .{ .entry = try Entry.from(progress), .descriptor = source.descriptor, .staged = source.staged, .charged_bytes = source.charged_bytes, .work_bytes = source.work_bytes, .work_pages = source.work_pages };
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

test "Document source independent descriptor commitment and scoped chunk fixture" {
    const t = std.testing;
    const Fixture = struct { descriptor: Descriptor, binding: Token.Binding, chunk_key: []const u8 };
    const fixture = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/document-source-v1.json"));
    defer fixture.deinit();
    try fixture.value.descriptor.validate();
    try fixture.value.descriptor.requireBinding(fixture.value.binding);
    const chunk: storage.Chunk = .{ .offset = 0, .content = fixture.value.descriptor.source };
    var path: [96]u8 = undefined;
    try t.expectEqualStrings(fixture.value.chunk_key, try storage.key(try fixture.value.descriptor.key.digest(), chunk, &path));
    var changed = fixture.value.descriptor;
    changed.part += 1;
    try t.expectError(error.InvalidDocumentSource, changed.requireBinding(fixture.value.binding));
    changed = fixture.value.descriptor;
    changed.target.document[0] ^= 1;
    try t.expectError(error.InvalidDocumentSource, changed.requireBinding(fixture.value.binding));
    changed = fixture.value.descriptor;
    changed.limits.work_bytes += 1;
    try t.expectError(error.InvalidDocumentSource, changed.requireBinding(fixture.value.binding));
    var progress = Token.Progress.initial(.{ .binding = fixture.value.binding, .position = .{ .partition = 1, .next_lsn = 2 }, .coordination = null });
    progress.source = State.initial(fixture.value.descriptor);
    try progress.validate();
    progress.source = null;
    const encoded = try p.Json.valueAlloc(t.allocator, progress);
    defer t.allocator.free(encoded);
    const omitted = try std.mem.replaceOwned(u8, t.allocator, encoded, ",\"source\":null", "");
    defer t.allocator.free(omitted);
    try t.expectError(error.MissingField, p.Json.parseFromSlice(Token.Progress, t.allocator, omitted));
}

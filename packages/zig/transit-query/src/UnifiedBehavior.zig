//! Public v1 behaviors above Transit. Signed host retry/fencing remains Station's
//! responsibility; this layer owns query admission and explicit dispositions.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const r = q.UnifiedRecords;
const wire = q.UnifiedRequest;
const upload = q.UnifiedUpload;
const Turn = s.Turn;
pub const adapter_bytes = 1024 * 1024;
pub const TableEndpoint = struct {
    url: []const u8,
    scope: p.DataLifecycle.Scope,
    branch: u64,
    audience: u64,
};
pub const PolicyChange = struct {
    expected_revision: u64,
    policy: r.Policy,
    pub fn encode(self: PolicyChange) !p.Value {
        if (self.expected_revision >= p.max_counter or self.policy.revision != self.expected_revision + 1 or self.policy.target != .catalog) return error.InvalidQueryPolicyChange;
        const policy = try self.policy.encode();
        var bytes: [12 + r.Policy.max_bytes]u8 = undefined;
        bytes[0..4].* = "CQG1".*;
        std.mem.writeInt(u64, bytes[4..12], self.expected_revision, .little);
        @memcpy(bytes[12..][0..policy.len], policy.slice());
        return p.Value.init(bytes[0 .. 12 + policy.len]);
    }
    pub fn decode(value: p.Value) !PolicyChange {
        try value.validate();
        if (value.len != 12 + r.Policy.max_bytes or !std.mem.eql(u8, value.data[0..4], "CQG1")) return error.InvalidQueryPolicyChange;
        const result: PolicyChange = .{ .expected_revision = std.mem.readInt(u64, value.data[4..12], .little), .policy = try r.Policy.decode(try p.Value.init(value.slice()[12..])) };
        _ = try result.encode();
        return result;
    }
};
fn configuration(first: u64, second: u64) !p.Value {
    try r.identity(first);
    try r.identity(second);
    var bytes: [20]u8 = undefined;
    bytes[0..4].* = "UQH1".*;
    std.mem.writeInt(u64, bytes[4..12], first, .little);
    std.mem.writeInt(u64, bytes[12..20], second, .little);
    return p.Value.init(&bytes);
}
fn initialized(turn: anytype, tag: u8, expected: p.Value) !void {
    const current = (try turn.read(r.key(tag, 0, 0))) orelse return error.UninitializedQueryBehavior;
    if (!current.eql(expected)) return error.QueryConfigurationChanged;
}
fn external(turn: *Turn, principal: u64) bool {
    return switch (turn.delivery.input.origin) {
        .external => |origin| origin.principal == principal,
        else => false,
    };
}
fn collectLater(turn: *Turn, namespace: u64) !void {
    try turn.cast(turn.delivery.pid, try (wire.Command{ .collect = namespace }).encode());
}
fn rejected(turn: *Turn, reason: []const u8) !void {
    try turn.write(r.key('e', turn.delivery.input.position, 0), try p.Value.init(reason));
}
pub const Requester = struct {
    principal: u64,
    source: u64,
    pub fn check(self: Requester, reader: anytype) !void {
        try initialized(reader, 'w', try configuration(self.principal, self.source));
    }
    pub fn interface(self: *Requester) s.GenServer.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn initialize(raw: ?*anyopaque, turn: *Turn) !void {
        const self: *Requester = @ptrCast(@alignCast(raw.?));
        try turn.write(r.key('w', 0, 0), try configuration(self.principal, self.source));
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) anyerror!void {
        const self: *Requester = @ptrCast(@alignCast(raw.?));
        try initialized(turn, 'w', try configuration(self.principal, self.source));
        if (frame.kind == .reply) return upload.reply(turn, frame, self.source);
        if (frame.kind == .timeout) return collectLater(turn, try upload.timeout(turn, frame.correlation));
        if (frame.kind != .cast) return rejected(turn, "UnsupportedQueryFrame");
        const command = wire.Command.decode(&frame.payload) catch return rejected(turn, "InvalidQueryUpload");
        if (!external(turn, self.principal)) {
            if (command != .collect or (s.Frame.source(turn.delivery.input) catch 0) != turn.delivery.pid) return rejected(turn, "QueryPrincipalMismatch");
        }
        const before = turn.decision;
        apply(self, turn, command) catch |err| {
            // Never acknowledge infrastructure/read/corruption failures as a
            // malformed user command. Read poison remains sticky in Station.
            turn.decision = before;
            if (turn.read_error != null or !requestError(err)) return err;
            try rejected(turn, @errorName(err));
        };
    }
    fn apply(self: *Requester, turn: *Turn, command: wire.Command) !void {
        switch (command) {
            .initialize => {},
            .draft_open => |value| try q.Draft.open(turn, value),
            .draft_close => |value| try q.Draft.close(turn, value),
            .draft_submit => |value| {
                _ = try q.Draft.submit(turn, value, self.source, self.principal);
            },
            .begin => |ref| try upload.begin(turn, ref),
            .part => |part| try upload.part(turn, part),
            .seal => |namespace| try upload.seal(turn, namespace),
            .submit => |namespace| {
                _ = try upload.submitWithObserver(turn, namespace, self.source, self.principal);
            },
            .cancel => |namespace| {
                try upload.cancel(turn, namespace);
                const status = (try upload.status(turn, namespace)) orelse return error.QueryUploadNotFound;
                if (status.phase == .cancelled and !status.collected) try collectLater(turn, namespace);
            },
            .retire => |namespace| {
                try upload.retire(turn, namespace);
                try collectLater(turn, namespace);
            },
            .retry_cleanup => |value| {
                const status = (try upload.status(turn, value.namespace)) orelse return error.QueryUploadNotFound;
                if (status.phase == .uploading or status.phase == .sealed or status.phase == .admitted or status.correlation == 0) return error.QueryActive;
                try turn.cast(self.source, try (Cleanup{ .correlation = status.correlation, .authorization = value.authorization }).encode());
            },
            .collect => |namespace| if (!try upload.collect(turn, namespace)) try collectLater(turn, namespace),
        }
    }
};
fn requestError(err: anyerror) bool {
    return switch (err) {
        error.InvalidQueryDraft, error.QueryDraftConflict, error.QueryDraftActive, error.QueryDraftNotFound, error.QueryDraftClosed, error.QueryDraftExhausted, error.QueryBudgetExceeded => true,
        error.InvalidQueryUpload, error.InvalidQueryBundle, error.QueryUploadIdentityConflict, error.QueryBusy, error.QueryActive, error.QueryNamespaceInUse, error.QueryUploadClosed, error.QueryUploadNotFound, error.QueryUploadNotActive, error.QueryUploadActive, error.PublicationGap, error.InvalidPublicationOrdinal, error.InvalidPublicationChunk, error.IncompletePublication, error.InvalidPublicationDigest, error.MutationBudgetExceeded => true,
        else => false,
    };
}
pub const Source = struct {
    peer: u64,
    initializer: u64,
    resources: s.client.ResourceReader,
    tables: ?q.catalog.DirectTableClient = null,
    adapter: []u8,
    workspace: []u8,
    cancellation: *const q.fuze.execution.Cancellation,
    pub fn interface(self: *Source) s.GenServer.Handler {
        return .{ .context = self, .initialize = initialize, .handle = handle };
    }
    fn initialize(raw: ?*anyopaque, turn: *Turn) !void {
        const self: *Source = @ptrCast(@alignCast(raw.?));
        try turn.write(r.key('v', 0, 0), try configuration(self.peer, self.initializer));
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) anyerror!void {
        const self: *Source = @ptrCast(@alignCast(raw.?));
        dispatchSource(turn, frame, self.peer, self.initializer, Resources{ .native = self.resources, .tables = self.tables }, self.adapter, self.workspace, self.cancellation) catch |err| {
            // Current request-resource expiry may arrive through the wire's
            // rejection envelope. Own-source read failure still poisons the turn
            // and cannot authorize a fabricated successful closure.
            if (turn.read_error == null and (err == error.Rejected or err == error.Conflict) and (self.resources.wire.last_rejection == .StateResourceExpired or self.resources.wire.last_rejection == .UnknownStateResource)) {
                const cause = if (self.resources.wire.last_rejection == .StateResourceExpired) error.RequestResourceExpired else error.RequestResourceMissing;
                if (frame.kind == .call) return turn.reply(try q.QueryFailure.fromError(cause, .admission).?.encode());
                if (frame.kind == .cast and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid) return q.UnifiedCapture.closeFailure(turn, (try r.Continuation.decode(frame.payload)).job, q.QueryFailure.fromError(cause, .execution).?);
            }
            return err;
        };
    }
};
pub const Resources = struct {
    native: s.client.ResourceReader,
    tables: ?q.catalog.DirectTableClient,
    pub fn open(self: Resources, resource: u64) !s.client.ResourceReader.Reader {
        return self.native.open(resource);
    }
};
pub const Cleanup = struct {
    correlation: u64,
    authorization: ?q.catalog.DirectReadDelegation.Closure = null,
    pub fn encode(self: Cleanup) !p.Value {
        try r.identity(self.correlation);
        var bytes: [13 + q.catalog.DirectReadDelegation.Closure.encoded_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("UQZ1");
        try (wire.Cleanup{ .namespace = self.correlation, .authorization = self.authorization }).write(&writer);
        return p.Value.init(writer.buffered());
    }
    pub fn decode(value: p.Value) !Cleanup {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "UQZ1")) return error.InvalidQueryContinuation;
        const control = try wire.Cleanup.read(&reader);
        const result: Cleanup = .{ .correlation = control.namespace, .authorization = control.authorization };
        if (reader.bufferedLen() != 0 or !(try result.encode()).eql(value)) return error.InvalidQueryContinuation;
        return result;
    }
};
/// Public composition point used by source hosts and component fixtures. The
/// resource reader is current and authenticated; adapter/Arrow memory is bounded.
pub fn dispatchSource(turn: *Turn, frame: s.Frame, peer: u64, initializer: u64, resources: anytype, adapter: []u8, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation) !void {
    try initialized(turn, 'v', try configuration(peer, initializer));
    if (frame.kind == .cast and external(turn, initializer) and frame.payload.eql(try wire.Command.encode(.initialize))) return;
    if (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "CQG1")) {
        if (!external(turn, initializer)) return rejected(turn, "QueryPrincipalMismatch");
        const change = PolicyChange.decode(frame.payload) catch return rejected(turn, "InvalidQueryPolicyChange");
        if (change.policy.peer != peer) return rejected(turn, "UnexpectedQueryPeer");
        const current = try q.UnifiedCapture.policy(turn, peer);
        if (current) |old| if (std.meta.eql(old, change.policy)) return;
        if ((if (current) |old| old.revision else @as(u64, 0)) != change.expected_revision) return rejected(turn, "StaleQueryPolicy");
        try q.UnifiedCapture.setPolicy(turn, change.policy);
        return;
    }
    return dispatch(turn, frame, peer, resources, adapter, workspace, cancellation);
}
/// Catalog composition uses the durable per-requester policy. No process ID is
/// reinterpreted as a catalog principal; Capture validates the explicit mapping.
pub fn dispatchCatalogSource(turn: *Turn, frame: s.Frame, catalog: q.catalog.TableCatalogRecords.Configuration, resources: anytype, adapter: []u8, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation) !void {
    try q.CatalogQueryOwner.check(catalog, turn);
    return dispatch(turn, frame, null, resources, adapter, workspace, cancellation);
}
fn dispatch(turn: *Turn, frame: s.Frame, peer: ?u64, resources: anytype, adapter: []u8, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation) !void {
    const origin = s.Frame.source(turn.delivery.input) catch 0;
    if (frame.kind == .cast and std.mem.startsWith(u8, frame.payload.slice(), "UQZ1")) {
        if (origin == 0 or (peer != null and origin != peer.?)) return rejected(turn, "UnexpectedQueryPeer");
        const control = try Cleanup.decode(frame.payload);
        const index = (try turn.read(r.key('i', origin, control.correlation))) orelse return rejected(turn, "QueryNotFound");
        var fixed: std.heap.FixedBufferAllocator = .init(adapter);
        q.UnifiedCapture.retryCleanup(fixed.allocator(), turn, try r.readIdentity(index), resources, control.authorization) catch |err| {
            if (turn.read_error != null) return err;
            return switch (err) {
                error.QueryActive, error.QueryDenied, error.CatalogDenied, error.SourceChanged => rejected(turn, @errorName(err)),
                else => err,
            };
        };
        return;
    }
    if (frame.kind == .call) {
        if (origin == 0 or (peer != null and origin != peer.?)) return turn.reply(try q.QueryFailure.fromError(error.UnexpectedQueryPeer, .admission).?.encode());
        const ref = s.PublicationReference.decode(frame.payload) catch return turn.reply(try q.QueryFailure.fromError(error.InvalidPublicationReference, .admission).?.encode());
        var diagnostic: ?q.QueryFailure = null;
        _ = q.UnifiedCapture.startBoundedDiagnostic(turn, ref, resources, adapter, &diagnostic) catch |err| {
            if (turn.read_error != null) return err;
            const failure = diagnostic orelse q.QueryFailure.fromError(err, .admission) orelse return err;
            return turn.reply(try failure.encode());
        };
        return;
    }
    if (frame.kind == .cancel) {
        if (origin == 0 or (peer != null and origin != peer.?)) return rejected(turn, "UnexpectedQueryPeer");
        const index = (try turn.read(r.key('i', origin, frame.correlation))) orelse return;
        try q.UnifiedCapture.close(turn, try q.UnifiedRecords.readIdentity(index), .cancelled);
        return;
    }
    if (frame.kind != .cast or origin != turn.delivery.pid) return rejected(turn, "UnexpectedQueryContinuation");
    const continuation = try r.Continuation.decode(frame.payload);
    var diagnostic: ?q.QueryFailure = null;
    _ = q.UnifiedCapture.advanceBoundedDiagnostic(turn, continuation, resources, adapter, workspace, cancellation, &diagnostic) catch |err| {
        if (turn.read_error != null) return err;
        const failure = diagnostic orelse q.QueryFailure.fromError(err, .execution) orelse return err;
        return q.UnifiedCapture.closeFailure(turn, continuation.job, failure);
    };
}

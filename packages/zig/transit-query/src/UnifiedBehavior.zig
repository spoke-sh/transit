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
            .collect => |namespace| if (!try upload.collect(turn, namespace)) try collectLater(turn, namespace),
        }
    }
};
fn requestError(err: anyerror) bool {
    return switch (err) {
        error.InvalidQueryDraft, error.QueryDraftConflict, error.QueryDraftActive, error.QueryDraftNotFound, error.QueryDraftClosed, error.QueryDraftExhausted, error.QueryBudgetExceeded => true,
        error.InvalidQueryUpload, error.InvalidQueryBundle, error.QueryUploadIdentityConflict, error.QueryBusy, error.QueryNamespaceInUse, error.QueryUploadClosed, error.QueryUploadNotFound, error.QueryUploadNotActive, error.QueryUploadActive, error.PublicationGap, error.InvalidPublicationOrdinal, error.InvalidPublicationChunk, error.IncompletePublication, error.InvalidPublicationDigest, error.MutationBudgetExceeded => true,
        else => false,
    };
}
pub const Source = struct {
    peer: u64,
    initializer: u64,
    resources: s.client.ResourceReader,
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
        dispatchSource(turn, frame, self.peer, self.initializer, self.resources, self.adapter, self.workspace, self.cancellation) catch |err| {
            // Current request-resource expiry may arrive through the wire's
            // rejection envelope. Own-source read failure still poisons the turn
            // and cannot authorize a fabricated successful closure.
            if (turn.read_error == null and (err == error.Rejected or err == error.Conflict) and (self.resources.wire.last_rejection == .StateResourceExpired or self.resources.wire.last_rejection == .UnknownStateResource)) {
                if (frame.kind == .call) return turn.reply(try p.Value.init("query.v1.denied"));
                if (frame.kind == .cast and (s.Frame.source(turn.delivery.input) catch 0) == turn.delivery.pid) return q.UnifiedCapture.close(turn, (try r.Continuation.decode(frame.payload)).job, .denied);
            }
            return err;
        };
    }
};
/// Public composition point used by source hosts and component fixtures. The
/// resource reader is current and authenticated; adapter/Arrow memory is bounded.
pub fn dispatchSource(turn: *Turn, frame: s.Frame, peer: u64, initializer: u64, resources: anytype, adapter: []u8, workspace: []u8, cancellation: *const q.fuze.execution.Cancellation) !void {
    try initialized(turn, 'v', try configuration(peer, initializer));
    if (frame.kind == .cast and external(turn, initializer) and frame.payload.eql(try wire.Command.encode(.initialize))) return;
    var fixed = std.heap.FixedBufferAllocator.init(adapter);
    const origin = s.Frame.source(turn.delivery.input) catch 0;
    if (frame.kind == .call) {
        if (origin != peer) return turn.reply(try p.Value.init("query.v1.denied"));
        const ref = s.PublicationReference.decode(frame.payload) catch return turn.reply(try p.Value.init("query.v1.rejected"));
        _ = q.UnifiedCapture.start(turn, ref, resources, fixed.allocator()) catch |err| {
            if (turn.read_error != null) return err;
            const reason = disposition(err) orelse return err;
            return turn.reply(try p.Value.init(if (reason == .denied) "query.v1.denied" else "query.v1.rejected"));
        };
        return;
    }
    if (frame.kind == .cancel) {
        if (origin != peer) return rejected(turn, "UnexpectedQueryPeer");
        const index = (try turn.read(r.key('i', peer, frame.correlation))) orelse return;
        try q.UnifiedCapture.close(turn, try q.UnifiedRecords.readIdentity(index), .cancelled);
        return;
    }
    if (frame.kind != .cast or origin != turn.delivery.pid) return rejected(turn, "UnexpectedQueryContinuation");
    const continuation = try r.Continuation.decode(frame.payload);
    _ = q.UnifiedCapture.advance(turn, continuation, resources, fixed.allocator(), workspace, cancellation) catch |err| {
        if (turn.read_error != null) return err;
        const reason = disposition(err) orelse return err;
        return q.UnifiedCapture.close(turn, continuation.job, if (reason == .denied) .denied else .failed);
    };
}
const Disposition = enum { denied, failed };
fn disposition(err: anyerror) ?Disposition {
    return switch (err) {
        error.QueryDenied, error.AccessDenied, error.ResourceUnavailable, error.PublicationNotPublished, error.UnexpectedQueryPublisher, error.DocumentHistoryGap, error.DocumentRetired, error.DocumentResyncRequired => .denied,
        error.QueryBudgetExceeded, error.QueryProjectionBudget, error.QueryExpansionMissing, error.QueryExpansionNull, error.QueryExpansionConflict, error.QueryExpansionTypeError, error.QueryTypeError, error.QueryConflict, error.Overflow, error.QuerySegmentBudgetExceeded, error.TypeMismatch, error.UnsupportedAggregate, error.UnknownColumn, error.InvalidProjection, error.DuplicateProjection, error.InvalidQueryBundle, error.InvalidQuerySource, error.InvalidQueryPrefix, error.InvalidQueryPath, error.InvalidProjectionBudget, error.InvalidTextProjection, error.InvalidElementProjection, error.UnsupportedSource, error.UnsupportedDecoder, error.UnsupportedDocumentSource, error.InvalidSourceEncoding, error.InvalidPlanEncoding, error.UnsupportedPlanDefinition, error.InvalidOutputNames, error.UnsupportedPlan, error.PlanTooLarge, error.QueryBundleTooLarge, error.EndOfStream, error.SourceChanged, error.TableSchemaChanged, error.InvalidQueryBudget, error.QueryNamespaceInUse, error.QueryAfterMutation, error.NonFiniteValue, error.InvalidUtf8, error.CellTooLarge, error.InvalidColumnName, error.InvalidColumnCount, error.DuplicateColumn, error.UnsupportedSchema => .failed,
        else => null,
    };
}

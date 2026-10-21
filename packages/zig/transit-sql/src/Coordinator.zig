//! Bounded recovery scheduler over committed native ledger and Table reads.
//! It proposes controls; only a published saved step permits Table dispatch.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
const r = g.LedgerRecords;
const Self = @This();
allocator: std.mem.Allocator,
client: *g.Client,
table_key: p.Ed25519.KeyPair,
reader_key: p.Ed25519.KeyPair,
generation: u64,
admission_after: u64 = 0,
intent: ?c.TableIntent = null,
candidate: ?struct { operation: u64, prepared: c.TableClient.Prepared } = null,
pub const Dispatch = struct { operation: u64, record: u64, prepared: c.TableClient.Prepared };
pub const Action = union(enum) { idle, blocked: u64, control: g.Control.Command, dispatch: Dispatch };
pub fn deinit(self: *Self) void {
    if (self.intent) |*intent| intent.deinit();
    self.intent = null;
    self.candidate = null;
}
/// Every scheduling pass rechecks the actual native owner. The generation also
/// travels in each control and is checked inside the committing ledger turn.
pub fn fence(self: *Self) !void {
    const config = self.client.ledger.configuration;
    if (self.client.principal != config.coordinator or self.generation == 0) return error.GatewayIdentityConflict;
    const state = try self.client.reader().query(.{ .process = config.owner });
    if (state.body != .process) return error.InvalidAuthorityResponse;
    const process = state.body.process.process;
    if (process.generation != self.generation or process.owner != config.worker) return error.StaleGatewayCoordinator;
    if (process.lifecycle != .running or process.failure != null or !p.Growth.processReady(process)) return error.GatewayOwnerUnavailable;
}
pub fn table(self: *Self, item: r.Operation) c.TableClient {
    const config = self.client.ledger.configuration;
    return .{ .transport = self.client.transport, .connection = .{ .scope = .{ .realm = config.realm, .resource = item.resource, .catalog = item.catalog }, .owner = item.owner, .principal = config.table_principal, .role = item.selectedRole(), .namespace = item.namespace }, .key = self.table_key, .reader = .{ .wire = self.client.transport, .realm = config.realm, .principal = config.reader, .key = self.reader_key } };
}
fn target(self: *Self, id: u64) g.Control.Qualified {
    return .{ .operation = id, .generation = self.generation };
}
fn record(self: *Self, id: u64, step: u64) g.Control.Record {
    return .{ .operation = id, .generation = self.generation, .record = step };
}
fn loadIntent(self: *Self, source: anytype, item: r.Operation) !*const c.TableIntent {
    const ledger = self.client.ledger;
    const descriptor = try ledger.publication(item.id).inspect(source, 1);
    if (descriptor.state != .published or !std.meta.eql(descriptor.spec, item.spec())) return error.InvalidGatewayIntent;
    if (self.intent) |*intent| if (intent.header.operation != item.id) {
        intent.deinit();
        self.intent = null;
    };
    if (self.intent == null) {
        var cached = try self.client.cachedSource(source.view.revision);
        const bytes = try g.Upload.read(self.allocator, ledger.publication(item.id), &cached, 1, ledger.configuration.intent_bytes);
        defer self.allocator.free(bytes);
        self.intent = try c.TableIntent.restore(self.allocator, bytes);
    }
    const intent = &self.intent.?;
    try self.table(item).connection.header(intent.header);
    if (intent.namespace != item.id or intent.header.operation != item.id) return error.GatewayIdentityConflict;
    return intent;
}
fn propose(self: *Self, item: r.Operation, step: c.TableClient.Prepared) !Action {
    if (!try step.matches(&self.intent.?)) return error.GatewayIdentityConflict;
    var buffer: [g.SavedStep.max_bytes]u8 = undefined;
    const bytes = try g.SavedStep.encode(step, &buffer);
    self.candidate = .{ .operation = item.id, .prepared = step };
    return .{ .control = .{ .begin_step = .{ .target = self.target(item.id), .spec = try g.station.Publication.Digest.of(g.SavedStep.format, bytes) } } };
}
fn staging(self: *Self, source: anytype, item: r.Operation) !Action {
    const publication = self.client.ledger.publication(item.id);
    const descriptor = try publication.inspect(source, item.staging);
    if (descriptor.state != .staging) return error.InvalidGatewayUpload;
    const offset = try g.Upload.receivedBytes(publication, source, item.staging);
    if (offset == descriptor.spec.length) return .{ .control = .{ .publish_step = self.record(item.id, item.staging) } };
    // A replacement has no authority to reconstruct a partly saved signature.
    // Abandon only this unpublished record; the signed native send never ran.
    const candidate = self.candidate orelse return .{ .control = .{ .abandon_step = self.record(item.id, item.staging) } };
    if (candidate.operation != item.id) return .{ .control = .{ .abandon_step = self.record(item.id, item.staging) } };
    var buffer: [g.SavedStep.max_bytes]u8 = undefined;
    const bytes = try g.SavedStep.encode(candidate.prepared, &buffer);
    if (!std.meta.eql(try g.station.Publication.Digest.of(g.SavedStep.format, bytes), descriptor.spec)) return error.GatewayStepIdentityConflict;
    return .{ .control = .{ .step_part = .{ .target = self.record(item.id, item.staging), .part = try g.Control.Part.init(offset, bytes[offset..][0..@min(g.Upload.part_bytes, bytes.len - offset)]) } } };
}
/// One pass observes at most one upload candidate and one active write. The
/// caller serializes and retains an exact signed control until its disposition.
/// A failed/uncertain control does not authorize calling next for a successor.
pub fn next(self: *Self) !Action {
    try self.fence();
    const ledger = self.client.ledger;
    var source = try self.client.source();
    const head = try ledger.head(&source);
    if (try ledger.indexed(&source, .admission, self.admission_after)) |item| {
        self.admission_after = item.id;
        if (item.cancel != 0) return .{ .control = .{ .cancel_unsent = self.target(item.id) } };
        if (item.phase == .uploading and (try ledger.publication(item.id).inspect(&source, 1)).state == .published) return .{ .control = .{ .admit_intent = self.target(item.id) } };
    } else self.admission_after = 0;
    if (head.active == 0) {
        self.candidate = null;
        if (self.intent) |*intent| intent.deinit();
        self.intent = null;
        return if (try ledger.indexed(&source, .ready, 0) != null) .{ .control = .{ .activate = self.generation } } else .idle;
    }
    const item = try ledger.operation(&source, head.active);
    if (item.phase != .active) return error.InvalidGatewayInventory;
    var table_client = self.table(item);
    if (item.pending != 0) {
        self.candidate = null;
        const saved = (try ledger.pendingStep(self.allocator, &source, item.id)) orelse return error.GatewayUnresolvedStep;
        if (item.input == 0) return .{ .dispatch = .{ .operation = item.id, .record = item.pending, .prepared = saved } };
        return switch (try table_client.progress(try self.loadIntent(&source, item), saved, item.input)) {
            .pending => .idle,
            .processed => |state| .{ .control = .{ .processed = .{ .target = self.record(item.id, item.pending), .disposition = state.disposition } } },
        };
    }
    if (item.staging != 0) return self.staging(&source, item);
    if (item.records > 1) {
        const last = try ledger.publication(item.id).inspect(&source, item.records);
        if (last.state == .abandoned and last.reserved) return .{ .control = .{ .collect_step = self.record(item.id, item.records) } };
    }
    if (item.cancel != 0 and item.published == 0) return .{ .control = .{ .cancel_unsent = self.target(item.id) } };
    const intent = try self.loadIntent(&source, item);
    const observed = try table_client.inspectIntent(intent);
    if (observed.outcome) |outcome| if (outcome.terminal()) return .{ .control = .{ .complete = .{ .target = self.target(item.id), .outcome = try g.Terminal.fromOutcome(outcome) } } };
    if (observed.upload) |upload| if (upload.phase == .cancelled) return .{ .control = .{ .complete = .{ .target = self.target(item.id), .outcome = try g.Terminal.fromUpload(upload) } } };
    if (item.blocked != 0) return .{ .blocked = item.id };
    if (item.cancel == 1) {
        const command: c.TableControl.Command = if (observed.outcome != null) switch (intent.identity) {
            .ddl => |identity| .{ .cancel_ddl = identity },
            .dml => |identity| .{ .cancel_dml = .{ .scope = intent.header.scope, .reference = identity.reference } },
        } else if (observed.upload != null) .{ .cancel_upload = intent.upload() } else return .{ .blocked = item.id };
        return self.propose(item, try (try table_client.controlCandidate(command, try std.math.add(u64, head.sequence, 1))).sign(self.table_key));
    }
    if (item.cancel == 2) return .idle;
    return switch (try table_client.nextCandidate(intent, try std.math.add(u64, head.sequence, 1))) {
        .send => |step| try self.propose(item, try step.sign(self.table_key)),
        .running => if (item.reconcile != 0) try self.propose(item, try (try table_client.resumeCandidate(intent, try std.math.add(u64, head.sequence, 1))).sign(self.table_key)) else .idle,
        .terminal => |outcome| .{ .control = .{ .complete = .{ .target = self.target(item.id), .outcome = try g.Terminal.fromOutcome(outcome) } } },
        .upload_cancelled => .idle, // A fresh pass records the attributed status.
    };
}
/// Attempt exactly the committed signed step. Recheck the live native fence and
/// pending pointer immediately before dispatch; never sign on this path.
pub fn dispatch(self: *Self, action: Dispatch) !g.Control.Command {
    try self.fence();
    var source = try self.client.source();
    const ledger = self.client.ledger;
    const item = try ledger.operation(&source, action.operation);
    if (item.pending != action.record or item.input != 0) return error.GatewayStepIdentityConflict;
    const saved = (try ledger.pendingStep(self.allocator, &source, item.id)) orelse return error.GatewayUnresolvedStep;
    if (!std.meta.eql(saved, action.prepared)) return error.GatewayStepIdentityConflict;
    var caller = self.table(item);
    // Rotation can invalidate the old signer after admission but before a
    // receipt was recorded. Recover exact acceptance with the current key first;
    // absence permits only the original signed attempt, never re-signing.
    const receipt = (try caller.receipt(saved)) orelse try caller.submit(saved);
    return .{ .receipt = .{ .target = self.record(item.id, item.pending), .input = receipt.position } };
}

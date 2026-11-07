//! Paged original-token directory and replaceable bounded handoff progress.
//! This journal records adapter work, never fabricates a destination decision.
const std = @import("std");
const root = @import("root.zig");
const c = root.data.catalog;
const p = c.protocol;
const Saved = root.Saved;
const Self = @This();
pub const format: u32 = 0x53485031; // SHP1
pub const State = struct {
    definition: p.Growth.Definition = p.Growth.current_definition,
    phase: enum { reserved, held, verified, copying, copied, sealed, publishing, settled, released } = .reserved,
    cancel: bool = false,
    work_bytes: u64 = 0,
    work_parts: u64 = 0,
    evidence: ?p.SourceCapture.Evidence = null,
    manifest: ?p.DataLifecycle.Content = null,
    outcome: @FieldType(c.DirectSourceCapture.State, "outcome") = null,
    pub fn validate(self: State, saved: Saved) !void {
        if (self.definition != p.Growth.current_definition or self.work_bytes > saved.work.bytes or self.work_parts > saved.work.parts) return error.InvalidSourceHandoff;
        if (self.evidence) |value| {
            try value.requireSource(saved.source);
            if (!std.meta.eql(value.poll, saved.poll) or !std.meta.eql(value.attempt, saved.attempt) or
                !std.meta.eql(value.verifier, saved.verifier) or value.observed_at_ms != saved.observed_at_ms)
                return error.InvalidSourceHandoff;
        }
        if (self.manifest) |value| try value.validate();
        if (self.outcome) |value| {
            try value.decision.validate();
            if (!std.meta.eql(value.decision.attempt.transaction.begin, saved.publication.begin) or !std.meta.eql(value.decision.attempt.operation, saved.publication.settlement)) return error.InvalidSourceHandoff;
            if (value.append) |append| {
                try append.validate();
                const plan = try saved.plan(self.manifest orelse return error.InvalidSourceHandoff);
                if (value.decision.outcome != .committed or !std.meta.eql(append.append.operation, plan.append) or append.append.capture == null or !std.meta.eql(append.append.capture.?.reference, plan.reference)) return error.InvalidSourceHandoff;
            } else if (value.decision.outcome == .committed) return error.InvalidSourceHandoff;
        }
        if (!self.cancel) switch (self.phase) {
            .reserved, .held => if (self.evidence != null or self.manifest != null or self.outcome != null) return error.InvalidSourceHandoff,
            .verified, .copying, .copied => if (self.evidence == null or self.manifest != null or self.outcome != null) return error.InvalidSourceHandoff,
            .sealed, .publishing => if (self.evidence == null or self.manifest == null or self.outcome != null) return error.InvalidSourceHandoff,
            .settled, .released => if (self.outcome == null or self.outcome.?.decision.outcome != .committed) return error.InvalidSourceHandoff,
        };
    }
    pub fn transition(before: State, after: State) !void {
        if (before.phase == .released or (before.cancel and !after.cancel) or after.work_bytes < before.work_bytes or after.work_parts < before.work_parts) return error.InvalidSourceHandoff;
        if (before.evidence != null and !std.meta.eql(before.evidence, after.evidence)) return error.InvalidSourceHandoff;
        if (before.manifest != null and !std.meta.eql(before.manifest, after.manifest)) return error.InvalidSourceHandoff;
        if (before.outcome != null and !std.meta.eql(before.outcome, after.outcome)) return error.InvalidSourceHandoff;
        const valid = before.phase == after.phase or (after.cancel and after.phase == .settled) or switch (before.phase) {
            .reserved => after.phase == .held,
            .held => after.phase == .verified,
            .verified => after.phase == .copying,
            .copying => after.phase == .copied,
            .copied => after.phase == .sealed,
            .sealed => after.phase == .publishing,
            .publishing => after.phase == .settled,
            .settled => after.phase == .released,
            .released => false,
        };
        if (!valid) return error.InvalidSourceHandoff;
    }
};
pub const Observation = struct { progress: c.DirectClientToken.Progress, state: State };
catalog: *c.DirectCatalog,
policy: c.DirectCatalog.Policy,

pub fn reserve(self: Self, allocator: std.mem.Allocator, saved: Saved) !Observation {
    const payload = try saved.encode(allocator);
    const binary = try c.DirectTableProtocol.Binary.encode(allocator, payload);
    const original = try c.DirectOwnedRecord.encode(allocator, saved.key, Saved.format, binary);
    const reference = try c.DirectRecord.reference(saved.key.scope(), c.DirectOwnedRecord.format, original);
    var progress = (try self.catalog.clientProgress(.{ .stage_original = .{ .binding = .{
        .key = saved.key,
        .fingerprint = reference.content.sha256,
        .budget = saved.budget,
        .intent = .{ .external = .{ .connection = saved.key.connection, .namespace = saved.namespace, .operation = saved.operation.operation, .record = reference } },
    }, .format = Saved.format, .bytes = binary } }, self.policy)).state.?;
    if (progress.original.?.phase == .ready) progress = (try self.catalog.clientProgress(.{ .retain_original = .{ .key = saved.key, .expected = progress.revision } }, self.policy)).state.?;
    return try self.decode(allocator, saved, progress);
}
pub fn inspect(self: Self, allocator: std.mem.Allocator, saved: Saved) !?Observation {
    const progress = (try self.catalog.clientProgress(.{ .inspect = saved.key }, self.policy)).state orelse return null;
    if (progress.original != null and progress.original.?.phase != .retained) return error.OwnedRecordPending;
    return try self.decode(allocator, saved, progress);
}
fn read(self: Self, allocator: std.mem.Allocator, reference: c.DirectRecord.Reference) ![]const u8 {
    const result = try self.catalog.directRecord(allocator, .{ .read = reference }, self.policy);
    return (result.bytes orelse return error.InvalidSourceHandoff).decode(allocator, c.DirectRecord.max_bytes);
}
fn decode(self: Self, allocator: std.mem.Allocator, saved: Saved, progress: c.DirectClientToken.Progress) !Observation {
    const intent = progress.receipt.binding.intent;
    if (intent != .external or progress.original == null or progress.original.?.phase != .retained) return error.InvalidSourceHandoff;
    const original = try self.read(allocator, intent.external.record);
    const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, allocator, original);
    if (envelope.value.format != Saved.format) return error.InvalidSourceHandoff;
    const input = try envelope.value.bytes.decode(allocator, Saved.max_bytes);
    if (!std.mem.eql(u8, input, try saved.encode(allocator))) return error.ClientTokenConflict;
    var state: State = .{};
    if (progress.record) |reference| {
        const encoded = try self.read(allocator, reference);
        const current = try p.Json.parseFromSlice(c.DirectProgressRecord.Envelope, allocator, encoded);
        try current.value.validate(reference);
        if (current.value.advance.format != format) return error.InvalidSourceHandoff;
        const bytes = try current.value.advance.bytes.decode(allocator, 16 * 1024);
        state = (try p.Json.parseFromSlice(State, allocator, bytes)).value;
    }
    try state.validate(saved);
    if (progress.cancel != state.cancel or progress.pending == (state.phase == .released)) return error.InvalidSourceHandoff;
    return .{ .progress = progress, .state = state };
}
pub fn advance(self: Self, allocator: std.mem.Allocator, saved: Saved, observed: Observation, next: State) !Observation {
    try next.validate(saved);
    try State.transition(observed.state, next);
    const bytes = try p.Json.valueAllocBounded(allocator, next, 16 * 1024);
    const progress = (try self.catalog.clientProgress(.{ .advance = .{
        .key = saved.key,
        .expected = observed.progress.revision,
        .pending = next.phase != .released,
        .cancel = next.cancel,
        .format = format,
        .bytes = try c.DirectTableProtocol.Binary.encode(allocator, bytes),
    } }, self.policy)).state.?;
    return .{ .progress = progress, .state = next };
}
/// Reuse the Catalog's bounded pending directory. The application can route each
/// immutable format to its owner; no process-local list owns unfinished work.
pub fn list(self: Self, allocator: std.mem.Allocator, selection: c.DirectClientToken.Selection) !c.DirectClientToken.Page {
    var page = (try self.catalog.clientProgress(.{ .list = selection }, self.policy)).page;
    for (&page.entries) |*slot| if (slot.*) |progress| {
        if (progress.original == null or progress.receipt.binding.intent != .external) {
            slot.* = null;
            continue;
        }
        // A not-yet-created original remains discoverable by its reserved
        // identity; it cannot have acquired an Exchange hold yet.
        if (progress.original.?.phase == .reserved) continue;
        if (progress.receipt.binding.intent.external.record.content.bytes > 48 * 1024) {
            slot.* = null;
            continue;
        }
        const bytes = try self.read(allocator, progress.receipt.binding.intent.external.record);
        const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, allocator, bytes);
        if (envelope.value.format != Saved.format) slot.* = null;
    };
    return page;
}

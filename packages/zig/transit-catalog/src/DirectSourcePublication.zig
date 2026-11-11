//! One frozen SOURCE output and its protected standard transaction. The
//! candidate owns its graph until the decision and participant cleanup settle.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const x = p.Transaction;
const Self = @This();

definition: p.Growth.Definition,
candidate: c.DirectClientToken.Key,
key: c.DirectClientToken.Key,
reference: p.SourceCapture.Reference,
namespace: u64,
operation: d.Operation,
append: d.Operation,
settlement: d.Operation,
limits: x.Limits,
budget: c.DirectClientToken.Budget,

pub const format: u32 = 0x53435031; // SCP1, immutable protected output plan.
pub const max_bytes = 8192;
pub fn validate(self: Self) !void {
    if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try self.candidate.validate();
    try self.key.validate();
    try self.reference.validate();
    try c.Model.nativeId(self.namespace);
    try self.limits.validate();
    try self.budget.validate();
    if (!std.meta.eql(self.candidate.scope(), self.key.scope()) or std.meta.eql(self.candidate, self.key) or
        !std.mem.eql(u8, &try self.candidate.digest(), &self.reference.candidate) or
        self.limits.participants != 1 or self.limits.statements != 1 or self.budget.bytes < 2 * max_bytes)
        return error.InvalidSourcePublication;
    try self.key.connection.object(self.reference.destination.object);
    const originals = [_]d.Operation{ self.operation, self.append, self.settlement };
    for (originals, 0..) |original, i| {
        try self.key.connection.owner(original);
        for (originals[0..i]) |other| if (std.meta.eql(original, other)) return error.InvalidSourcePublication;
    }
}
pub fn requireCandidate(self: Self, state: c.DirectSourceCapture.State) !void {
    try self.validate();
    try state.descriptor.key.requireSame(self.candidate);
    if (state.manifest == null or !std.meta.eql(state.manifest.?, self.reference.manifest) or
        !std.meta.eql(state.descriptor.evidence.destination, self.reference.destination) or
        self.namespace != state.descriptor.namespace) return error.InvalidSourcePublication;
    for ([_]d.Operation{ self.operation, self.append, self.settlement }) |original|
        if (std.meta.eql(original, state.descriptor.operation)) return error.InvalidSourcePublication;
}
pub fn encode(self: Self, output: []u8) ![]const u8 {
    try self.validate();
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    var json: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(self, &json);
    return writer.buffered();
}
pub fn digest(self: Self) ![32]u8 {
    var bytes: [max_bytes]u8 = undefined;
    var result: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(try self.encode(&bytes), &result, .{});
    return result;
}
pub fn stored(self: Self) !c.DirectRecord.Reference {
    var bytes: [max_bytes]u8 = undefined;
    return c.DirectRecord.reference(self.key.scope(), format, try self.encode(&bytes));
}
pub fn store(self: Self, objects: c.storage.TransitObjectStore.ObjectStore) !c.DirectRecord.Reference {
    var bytes: [max_bytes]u8 = undefined;
    return c.DirectRecord.store(objects, self.key.scope(), format, try self.encode(&bytes));
}
pub fn load(allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, reference: c.DirectRecord.Reference) !Self {
    if (reference.format != format or reference.content.bytes > max_bytes) return error.InvalidSourcePublication;
    const bytes = try c.DirectRecord.load(allocator, objects, reference);
    defer allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(Self, allocator, bytes);
    defer parsed.deinit();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, bytes, try parsed.value.encode(&canonical)) or !std.meta.eql(parsed.value.key.scope(), reference.scope)) return error.InvalidSourcePublication;
    return parsed.value;
}
pub fn requireReceipt(self: Self, receipt: c.DirectClientToken.Receipt) !void {
    try self.validate();
    try receipt.validate();
    try self.key.requireSame(receipt.binding.key);
    if (receipt.binding.intent != .transaction) return error.InvalidSourcePublication;
    const value = receipt.binding.intent.transaction;
    if (value.purpose != .source_capture or !std.meta.eql(value.purpose.source_capture, try self.stored()) or
        value.namespace != self.namespace or !std.meta.eql(value.begin.identity.begin, self.operation) or
        value.begin.mode != .serializable or value.begin.selection != .explicit_objects or value.begin.objects.count != 1 or
        !std.meta.eql(value.begin.limits, self.limits) or !std.meta.eql(receipt.binding.budget, self.budget) or
        !std.mem.eql(u8, &receipt.binding.fingerprint, &try self.digest())) return error.InvalidSourcePublication;
}
pub fn requireProgress(self: Self, allocator: std.mem.Allocator, objects: c.storage.TransitObjectStore.ObjectStore, progress: c.DirectClientToken.Progress) !void {
    try self.requireReceipt(progress.receipt);
    if (progress.cancel) return error.InvalidSourcePublication;
    const reference = progress.record orelse {
        if (!progress.pending) return error.InvalidSourcePublication;
        return;
    };
    const head = if (reference.format == c.DirectTransactionControl.format) blk: {
        const control = try c.DirectTransactionControl.load(allocator, objects, progress);
        if (!std.meta.eql(control.binding.attempt.operation, self.settlement)) return error.InvalidSourcePublication;
        if (control.decision) |decision| if (decision.outcome == .committed and
            (control.binding.attempt.last_statement != 1 or control.binding.attempt.writes != 1)) return error.InvalidSourcePublication;
        break :blk control.workspace;
    } else try c.DirectTransactionWorkspace.recover(allocator, objects, progress);
    if (head) |workspace| {
        if (workspace.last_control != 0 or workspace.controls != null or workspace.savepoints != null or
            workspace.pending_control != null or workspace.tables != null or workspace.last_statement > 1) return error.InvalidSourcePublication;
        if (workspace.pending) |pending| {
            if (pending != .log or pending.log.statement.sequence != 1 or pending.log.work != .append) return error.InvalidSourcePublication;
            const append = pending.log.work.append;
            if (append.capture == null or !std.meta.eql(append.capture.?.reference, self.reference) or
                !std.meta.eql(append.operation, self.append) or !std.meta.eql(append.capture.?.transaction.begin, self.operation)) return error.InvalidSourcePublication;
        }
    }
}
pub fn begin(self: Self, targets: *[1]x.Target) !c.DirectTransactionRequest.Begin {
    try self.validate();
    targets.* = .{.{ .object = self.reference.destination.object, .kind = .stream, .partition = 0 }};
    return .{ .key = self.key, .fingerprint = try self.digest(), .operation = self.operation, .namespace = self.namespace, .mode = .serializable, .deadline = null, .execution = null, .selection = .{ .explicit_objects = targets }, .limits = self.limits, .budget = self.budget };
}
pub fn envelope(self: Self, allocator: std.mem.Allocator, evidence: p.SourceCapture.Evidence, declaration: *const c.storage.LogDeclaration.Owned, output: []u8) ![]const u8 {
    try self.validate();
    try evidence.validate();
    const columns = try c.SourceBinding.columns(declaration.schema.schema, declaration.definition.configuration);
    if (!std.meta.eql(columns, evidence.columns) or !std.meta.eql(evidence.destination, self.reference.destination) or
        !std.meta.eql((try declaration.stored()).declaration.interpretation, self.reference.destination)) return error.InvalidSourcePublication;
    const body_ref = try self.reference.encode(allocator);
    defer allocator.free(body_ref);
    const milliseconds = std.math.cast(i64, evidence.observed_at_ms) orelse return error.InvalidSourceCapture;
    const values = [_]c.fuze.Types.Values.Atom{
        .{ .uuid = evidence.poll.capture_id },                       .{ .unsigned = evidence.poll.sequence },
        .{ .timestamp = try std.math.mul(i64, milliseconds, 1000) }, .{ .signed = evidence.http_status },
        .{ .bytes = body_ref },                                      .{ .unsigned = evidence.body.bytes },
        .{ .bytes = &evidence.body.sha256 },
    };
    var cells: [7]c.fuze.Types.Values.Cell = undefined;
    for (declaration.schema.schema.columns, &cells) |column, *cell| {
        const i = std.mem.indexOfScalar(u64, &columns, column.id) orelse return error.InvalidSourcePublication;
        cell.* = .{ .value = .{ .atom = values[i] } };
    }
    return c.storage.LogBatch.encode(declaration.schema.schema, self.append, .stream, &.{.{ .cells = &cells }}, output);
}
pub fn work(self: Self, payload: []const u8) p.StreamQueue.Append {
    return .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = self.reference.destination, .partition = 0 }, .operation = self.append, .kind = .stream, .producer = null, .rows = 1, .payload = c.storage.LogBatch.content(payload), .capture = .{ .reference = self.reference, .transaction = .{ .begin = self.operation, .branch = self.key.connection.branch } } };
}

//! Current scoped authority and finite result evidence for the durable scheduler.
//! The owning host provides its authenticated reader and bounded scratch space.
const std = @import("std");
const root = @import("root.zig");
const p = root.protocol;
const q = root.query;
const f = root.ServingFailure;
const Self = @This();
resources: root.station.client.ResourceReader,
ingress: u64,
resource: u64,
source: u64,
scratch: []u8,
diagnostic: ?*root.ServingFailure.Context = null,
pub fn withDiagnostic(self: Self, context: ?*root.ServingFailure.Context) Self {
    var scoped_reader = self;
    scoped_reader.diagnostic = context;
    return scoped_reader;
}

fn rememberRead(self: Self, operation: f.ReaderOperation, principal: u64, resource: u64, namespace: u64, cause: anyerror) void {
    const reason = std.meta.stringToEnum(f.ReaderCause, @errorName(cause)) orelse return;
    f.remember(self.diagnostic, .{ .reader_failure = .{ .operation = operation, .principal = principal, .resource = resource, .namespace = namespace, .cause = reason } });
    if (self.diagnostic) |context| context.cause = cause;
}
fn rememberResourceRead(self: Self, operation: f.ReaderOperation, namespace: u64, failure: ?root.station.client.ResourceReader.Failure, cause: anyerror) void {
    if (failure) |original| switch (original) {
        .rejected => |value| {
            const reason = std.meta.stringToEnum(f.ReaderCause, @tagName(value.cause)) orelse return;
            switch (reason) {
                inline else => |known| self.rememberRead(operation, self.resources.principal, value.resource, namespace, @field(anyerror, @tagName(known))),
            }
            return;
        },
        .unavailable => |value| {
            f.remember(self.diagnostic, .{ .reader_resource = .{ .role = if (value.id == self.resource) .requester else .source, .resource = value.id, .expected_writer = value.writer, .actual_writer = value.writer, .phase = value.phase, .writer_check = false, .revision = value.revision } });
            return;
        },
    };
    self.rememberRead(operation, self.resources.principal, 0, namespace, cause);
}
fn checkResource(self: Self, role: f.ResourceRole, expected_writer: u64, resource: p.Growth.Resource) !void {
    if (resource.writer == expected_writer and resource.phase == .active) return;
    f.remember(self.diagnostic, .{ .reader_resource = .{ .role = role, .resource = resource.id, .expected_writer = expected_writer, .actual_writer = resource.writer, .phase = resource.phase, .writer_check = resource.writer != expected_writer, .revision = resource.revision } });
    return error.ResourceUnavailable;
}
fn authority(self: Self, principal: u64, proof: root.RefreshModel.Proof) !q.catalog.TableAuthority.Context {
    const subject: p.Authorization.Subject = .{ .accepted = proof };
    try subject.validate();
    if (proof.principal != principal or proof.pid != self.ingress) return error.ServingDenied;
    return q.QueryAuthorization.readerContext(self.resources, subject, null);
}
pub fn authorize(self: Self, turn: *root.station.Turn, principal: u64, source: root.ReactiveModel.Source, proof: root.RefreshModel.Proof) !void {
    const context = try self.authority(principal, proof);
    const request_resource = (try self.resources.query(.{ .resource = self.resource })).body.resource;
    try self.checkResource(.requester, self.ingress, request_resource);
    var reader = try root.TableWatch.Reader.init(self.resources, context.subject, source);
    const required = root.TableWatch.authorize(&reader, principal, source) catch |err| {
        self.rememberRead(.source, principal, source.resource, 0, err);
        return err;
    };
    // The same original subject and complete Table requirements also fence the
    // native turn publication; a successful earlier read is never a lease.
    _ = try turn.requireAuthorization(try required.guard(context.subject));
}
pub fn observe(self: Self, principal: u64, source: root.ReactiveModel.Source, proof: root.RefreshModel.Proof) !root.TableWatch.Observation {
    var reader = try root.TableWatch.Reader.init(self.resources, (try self.authority(principal, proof)).subject, source);
    const result_value = root.TableWatch.observeDiagnostic(self.resources.wire.http.allocator, &reader, principal, source, self.diagnostic) catch |err| {
        self.rememberRead(.source, principal, source.resource, 0, err);
        return err;
    };
    try reader.finish();
    return result_value;
}
fn requireTemplate(self: Self, namespace: u64, phase: ?q.UnifiedRequest.Phase, manifest: bool) !void {
    if (phase == .complete and manifest) return;
    f.remember(self.diagnostic, .{ .reader_template = .{ .namespace = namespace, .present = phase != null, .phase = phase orelse .uploading, .manifest = phase != null and manifest } });
    return error.InvalidRefreshTemplate;
}
/// Follow authorizes only the finite requests already prepared by this caller.
/// Each has the original template's exact source, plan, limits and route, and a
/// separate current-capture grant. No executor signs or renews caller authority.
pub fn templates(self: Self, turn: *root.station.Turn, input: root.RefreshModel.Follow, source: root.ReactiveModel.Source, proof: root.RefreshModel.Proof) !void {
    try root.RefreshModel.validateCaptures(input.captures, input.limit, input.template);
    const context = try self.authority(proof.principal, proof);
    const accepted = try context.client.authenticate(context.subject);
    const original = (try q.UnifiedUpload.status(turn, input.template.value)) orelse return error.InvalidRefreshTemplate;
    try self.requireTemplate(input.template.value, original.phase, original.manifest != null);
    var fixed = std.heap.FixedBufferAllocator.init(self.scratch);
    var buffer: [q.Bundle.max_bytes]u8 = undefined;
    const template = try q.Bundle.decode(fixed.allocator(), try original.reference.read(self.resources, &buffer));
    if (template.source.source != .table) return error.InvalidRefreshTemplate;
    const purpose = try template.retentionPurpose(self.source, original.manifest.?.resource, self.ingress, self.resource);
    const original_grant = template.retention orelse return error.InvalidRefreshTemplate;
    const original_owner = original_grant.binding.owner;
    const executor = original_grant.binding.executor;
    var operations: [root.RefreshModel.max_starts]u64 = undefined;
    for (input.captures[0..input.limit], 0..) |namespace, i| {
        fixed.reset();
        const pending = (try q.UnifiedUpload.status(turn, namespace.value)) orelse return error.InvalidRefreshTemplate;
        if (pending.phase != .prepared or pending.correlation != 0) return error.InvalidRefreshTemplate;
        const bundle = try q.Bundle.decode(fixed.allocator(), try pending.reference.read(self.resources, &buffer));
        if (bundle.source.source != .table or !std.meta.eql(source, try root.ReactiveModel.Source.from(source.revision, bundle.source.source.table)) or
            !std.mem.eql(u8, &purpose, &try bundle.retentionPurpose(self.source, original.manifest.?.resource, self.ingress, self.resource))) return error.InvalidRefreshTemplate;
        const grant = bundle.retention orelse return error.InvalidRefreshTemplate;
        if (grant.binding.selection != .current or grant.binding.retention != .snapshot or grant.binding.executor != executor or
            !std.mem.eql(u8, &grant.binding.purpose, &purpose) or std.meta.eql(grant.binding.owner, original_owner)) return error.InvalidRefreshTemplate;
        for (operations[0..i]) |operation| if (grant.binding.owner.operation == operation) return error.InvalidRefreshTemplate;
        operations[i] = grant.binding.owner.operation;
        const subject = (try bundle.subject(self.source, self.ingress, self.resource)) orelse return error.InvalidRefreshTemplate;
        const caller = try context.client.authenticate(subject);
        if (caller.principal != accepted.principal or caller.role != accepted.role or caller.credential_epoch != accepted.credential_epoch) return error.ServingDenied;
        _ = try context.client.authenticate(.{ .signed = grant.proof });
    }
    // Recheck the accepted Follow subject after all prepared bytes have been
    // buffered and verified. The enclosing native decision retains its guard.
    try self.authorize(turn, proof.principal, source, proof);
}
pub fn result(self: Self, turn: *root.station.Turn, namespace: u64, source: root.ReactiveModel.Source, proof: root.RefreshModel.Proof) !q.TablePosition {
    try source.validate();
    if (turn.view.resource != self.resource) {
        f.remember(self.diagnostic, .{ .target = .{ .kind = .resource, .expected = self.resource, .actual = turn.view.resource } });
        return error.ServingDenied;
    }
    if (turn.delivery.pid != self.ingress) {
        f.remember(self.diagnostic, .{ .reader_identity = .{ .field = .turn_pid, .expected = self.ingress, .actual = turn.delivery.pid } });
        return error.ServingDenied;
    }
    const found = try q.UnifiedUpload.status(turn, namespace);
    try self.requireTemplate(namespace, if (found) |value| value.phase else null, if (found) |value| value.manifest != null else false);
    const status = found.?;
    var fixed = std.heap.FixedBufferAllocator.init(self.scratch);
    var failure: ?root.station.client.ResourceReader.Failure = null;
    const opened = q.UnifiedResult.open(status.manifest.?, .{ .resource = status.manifest.?.resource, .source = self.source, .requester = self.ingress, .correlation = status.correlation, .request = status.reference, .disclosure = .{ .accepted = proof } }, self.resources.withFailure(&failure), fixed.allocator()) catch |err| {
        self.rememberResourceRead(.result, namespace, failure, err);
        return err;
    };
    const basis = opened.table_basis orelse {
        f.remember(self.diagnostic, .{ .source_kind = .{ .expected = .table, .actual = std.meta.activeTag(opened.bundle.source.source) } });
        return error.InvalidRefreshTemplate;
    };
    return q.TablePosition.captured(basis);
}

test "refresh authority retains native admission and rejects a foreign principal or ingress" {
    const t = std.testing;
    const reader: Self = .{ .resources = .{ .wire = undefined, .realm = 1, .principal = 90, .key = undefined }, .ingress = 7, .resource = 9, .source = 8, .scratch = &.{} };
    const original: root.RefreshModel.Proof = .{ .pid = 7, .input = 19, .principal = 3 };
    try t.expectEqualDeep(p.Authorization.Subject{ .accepted = original }, (try reader.authority(3, original)).subject);
    try t.expectError(error.ServingDenied, reader.authority(4, original));
    var foreign = original;
    foreign.pid = 8;
    try t.expectError(error.ServingDenied, reader.authority(3, foreign));
    foreign = original;
    foreign.input = 0;
    try t.expectError(error.InvalidAuthorizationCredential, reader.authority(3, foreign));
}

test "refresh reader retains writer, lifecycle and original read cause separately" {
    const t = std.testing;
    var context: f.Context = .{};
    const reader: Self = .{ .resources = undefined, .ingress = 7, .resource = 9, .source = 8, .scratch = &.{}, .diagnostic = &context };
    var resource: p.Growth.Resource = .{ .id = 12, .writer = 8, .owner = null, .revision = 1, .deadline_ms = null };
    try t.expectError(error.ResourceUnavailable, reader.checkResource(.source, 7, resource));
    try t.expectEqual(.source, context.witness.reader_resource.role);
    try t.expectEqual(@as(u64, 1), context.witness.reader_resource.revision);
    try t.expect(context.witness.reader_resource.writer_check);
    try t.expectEqual(@as(u64, 8), context.witness.reader_resource.actual_writer);
    resource.writer = 7;
    resource.phase = .retired;
    try t.expectError(error.ResourceUnavailable, reader.checkResource(.requester, 7, resource));
    try t.expect(!context.witness.reader_resource.writer_check);
    try t.expectEqual(.retired, context.witness.reader_resource.phase);
    resource.phase = .active;
    try reader.checkResource(.source, 7, resource);
    inline for (comptime std.meta.fieldNames(f.ReaderCause)) |name| {
        reader.rememberRead(.source, 3, 12, 0, @field(anyerror, name));
        try t.expectEqual(@field(anyerror, name), context.cause.?);
        try t.expectEqualStrings(name, @tagName(context.witness.reader_failure.cause));
        const original = context;
        reader.rememberRead(.source, 3, 12, 0, error.OutOfMemory);
        try t.expectEqualDeep(original, context);
        reader.rememberRead(.source, 3, 12, 0, error.ConnectionResetByPeer);
        try t.expectEqualDeep(original, context);
        const retained = root.RefreshFailure.record(17, .resource_unavailable, context);
        const encoded = try root.Codec.encode('x', retained);
        const restored = try root.Codec.decode(root.RefreshFailure.Record, 'x', encoded);
        try t.expectEqualDeep(retained, restored);
        try t.expectEqualStrings(name, @tagName(restored.stopped.witness.reader_failure.cause));
        var diagnostic = try p.Diagnostic.init("refresh.resource_unavailable", .unavailable, .control, .not_applicable, .domain_status, "Original check");
        try f.facts(&diagnostic, restored.stopped.witness);
        try t.expectEqualStrings(name, diagnostic.cause.?.slice());
    }
}

test "refresh templates distinguish absence and every unfinished phase from a verified complete result" {
    const t = std.testing;
    var context: f.Context = .{};
    const reader: Self = .{ .resources = undefined, .ingress = 7, .resource = 9, .source = 8, .scratch = &.{}, .diagnostic = &context };
    const namespace = std.math.maxInt(u64);
    try t.expectError(error.InvalidRefreshTemplate, reader.requireTemplate(namespace, null, false));
    try t.expect(!context.witness.reader_template.present);
    for (std.enums.values(q.UnifiedRequest.Phase)) |phase| {
        try t.expectError(error.InvalidRefreshTemplate, reader.requireTemplate(namespace, phase, false));
        const witness = context.witness.reader_template;
        try t.expect(witness.present and !witness.manifest);
        try t.expectEqual(namespace, witness.namespace);
        try t.expectEqual(phase, witness.phase);
        const encoded = try root.Codec.encode('x', context.witness);
        try t.expectEqualDeep(context.witness, try root.Codec.decode(f.Witness, 'x', encoded));
    }
    const original = context;
    try reader.requireTemplate(namespace, .complete, true);
    try t.expectEqualDeep(original, context);
}

test "refresh result failure retains the actual nested resource and does not borrow stale rejection" {
    const t = std.testing;
    var context: f.Context = .{};
    const reader: Self = .{ .resources = .{ .wire = undefined, .realm = 1, .principal = 3, .key = undefined }, .ingress = 7, .resource = 9, .source = 8, .scratch = &.{}, .diagnostic = &context };
    reader.rememberResourceRead(.result, 99, .{ .rejected = .{ .resource = 15, .cause = .StateResourceExpired } }, error.ResourceUnavailable);
    try t.expectEqual(error.StateResourceExpired, context.cause.?);
    try t.expectEqual(@as(u64, 15), context.witness.reader_failure.resource);
    try t.expectEqual(@as(u64, 99), context.witness.reader_failure.namespace);
    const original = context;
    reader.rememberResourceRead(.result, 99, null, error.OutOfMemory);
    try t.expectEqualDeep(original, context);
    reader.rememberResourceRead(.result, 99, null, error.InvalidQueryManifest);
    try t.expectEqualDeep(original, context);
    context = .{};
    reader.rememberResourceRead(.result, 99, .{ .unavailable = .{ .id = 9, .writer = 7, .owner = null, .revision = 41, .deadline_ms = null, .phase = .retired } }, error.ResourceUnavailable);
    try t.expectEqual(.requester, context.witness.reader_resource.role);
    try t.expectEqual(@as(u64, 41), context.witness.reader_resource.revision);
    try t.expectEqual(.retired, context.witness.reader_resource.phase);
    try t.expectEqual(null, context.cause);
}

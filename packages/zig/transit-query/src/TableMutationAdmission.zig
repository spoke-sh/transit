//! Explicit application composition for Table writes. This owner only proposes
//! private state; native fenced acceptance remains the commit authority.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const r = q.TableMutationRecords;
const Request = q.TableMutationRequest;
const Turn = s.Turn;
const Pub = s.Publication;

pub fn policy(source: anytype, principal: u64, table: u32) !?r.Policy {
    const value = (try source.read(r.key('p', principal, table))) orelse return null;
    const result = try r.Policy.decode(value);
    if (result.principal != principal or result.table != table) return error.InvalidMutationRecord;
    return result;
}
/// Only an explicitly authorized application configuration path calls this.
/// Zero permissions revokes; deleting/restarting revision history is unsupported.
pub fn setPolicy(turn: *Turn, expected_revision: u64, next: r.Policy) !void {
    const encoded = try next.encode();
    const current = try policy(turn, next.principal, next.table);
    if (current) |old| if (std.meta.eql(old, next)) return;
    if (expected_revision != (if (current) |old| old.revision else 0) or expected_revision >= p.max_counter or next.revision != expected_revision + 1) return error.StaleMutationPolicy;
    if (!std.mem.eql(u8, &next.declaration, &try r.declaration(try s.Table.open(turn, next.table)))) return error.MutationSourceChanged;
    try turn.write(r.key('p', next.principal, next.table), encoded);
}
pub fn status(source: anytype, namespace: u64) !?r.Status {
    if (namespace == 0) return error.InvalidMutationCommand;
    const value = (try source.read(r.key('u', namespace, 0))) orelse return null;
    const result = try r.Status.decode(value);
    if (result.reference.namespace != namespace or result.reference.resource != source.view.resource) return error.InvalidMutationRecord;
    return result;
}
pub fn active(source: anytype) !?u64 {
    const value = (try source.read(r.key('a', 0, 0))) orelse return null;
    if (value.len != 8) return error.InvalidMutationRecord;
    const namespace = std.mem.readInt(u64, value.data[0..8], .little);
    if (namespace == 0) return error.InvalidMutationRecord;
    return namespace;
}
fn required(turn: *Turn, namespace: u64, principal: u64) !r.Status {
    const current = (try status(turn, namespace)) orelse return error.MutationNotFound;
    if (current.principal != principal) return error.MutationPrincipalMismatch;
    return current;
}
fn store(turn: *Turn, current: r.Status) !void {
    try turn.write(r.key('u', current.reference.namespace, 0), try current.encode());
}
fn checkActive(turn: *Turn, namespace: u64) !void {
    if (try active(turn) != namespace) return error.MutationNotActive;
}
fn permitted(turn: *Turn, current: r.Status) !r.Policy {
    const grant = (try policy(turn, current.principal, current.table)) orelse return error.MutationDenied;
    if (grant.permissions == 0 or grant.revision != current.policy_revision or !std.mem.eql(u8, &grant.declaration, &current.declaration)) return error.MutationDenied;
    const table = s.Table.open(turn, current.table) catch |err| return if (err == error.TableNotFound) error.MutationSourceChanged else err;
    if (!std.mem.eql(u8, &current.declaration, &try r.declaration(table))) return error.MutationSourceChanged;
    return grant;
}
fn begin(turn: *Turn, principal: u64, value: r.Begin) !r.Status {
    if (value.reference.resource != turn.view.resource) return error.InvalidMutationCommand;
    if (try status(turn, value.reference.namespace)) |existing| {
        if (existing.principal != principal) return error.MutationPrincipalMismatch;
        if (!std.meta.eql(existing.reference, value.reference) or existing.table != value.table or existing.policy_revision != value.policy_revision) return error.MutationIdentityConflict;
        if (!existing.terminal()) _ = try permitted(turn, existing);
        return existing;
    }
    const table = s.Table.open(turn, value.table) catch |err| return if (err == error.TableNotFound) error.MutationSourceChanged else err;
    const current: r.Status = .{ .reference = value.reference, .principal = principal, .table = value.table, .declaration = try r.declaration(table), .policy_revision = value.policy_revision };
    _ = try permitted(turn, current);
    if (try active(turn)) |namespace| {
        const previous = (try status(turn, namespace)) orelse return error.InvalidMutationRecord;
        if (!previous.terminal()) return error.MutationBusy;
    }
    if (try turn.read(Pub.key(value.reference.namespace, 'b', 0, 0)) != null) return error.MutationNamespaceInUse;
    const publication = try Pub.create(turn, value.reference.namespace, .{ .record_bytes = Request.max_bytes, .staging_bytes = Request.max_bytes, .staging_records = 1 });
    _ = try publication.begin(turn, value.reference.record, value.reference.spec);
    try store(turn, current);
    try turn.write(r.key('a', 0, 0), q.UnifiedRecords.identityValue(value.reference.namespace));
    return current;
}
fn close(turn: *Turn, current: *r.Status, phase: r.Phase, reason: r.Reason, affected: u8) !void {
    current.phase = phase;
    current.reason = reason;
    current.affected_rows = affected;
    current.input = turn.delivery.input.position;
    // Leave the active pointer: the next begin may replace a terminal pointer.
    // Three rows plus this result fit the existing four-mutation boundary.
    try store(turn, current.*);
}
fn readRequest(turn: *Turn, current: r.Status, output: *[Request.max_bytes]u8) ![]const u8 {
    const publication = current.reference.publication();
    var cursor = try publication.open(turn, current.reference.record);
    if (!std.meta.eql(cursor.spec, current.reference.spec)) return error.PublicationReferenceChanged;
    var offset: usize = 0;
    while (true) {
        const part = try publication.read(turn, cursor);
        if (offset + part.bytes.len > output.len) return error.InvalidMutationRecord;
        @memcpy(output[offset..][0..part.bytes.len], part.bytes.slice());
        offset += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (offset != current.reference.spec.length) return error.InvalidMutationRecord;
    return output[0..offset];
}
fn apply(turn: *Turn, current: *r.Status) !void {
    if (current.terminal()) return;
    if (current.phase != .sealed) return error.MutationNotSealed;
    const grant = permitted(turn, current.*) catch |err| return switch (err) {
        error.MutationDenied => close(turn, current, .rejected, .denied, 0),
        error.MutationSourceChanged => close(turn, current, .rejected, .source_changed, 0),
        else => err,
    };
    var buffer: [Request.max_bytes]u8 = undefined;
    // Integrity/storage failures propagate. Only the caller's verified immutable
    // bytes are classified as an invalid request; no failed read is acknowledged.
    const bytes = try readRequest(turn, current.*, &buffer);
    const request = Request.decode(bytes) catch return close(turn, current, .rejected, .invalid_request, 0);
    if (request.realm != turn.delivery.realm or request.writer != turn.delivery.pid or request.resource != turn.view.resource or request.table != current.table) return close(turn, current, .rejected, .invalid_request, 0);
    if (!std.mem.eql(u8, &current.declaration, &try r.declaration(request.target()))) return close(turn, current, .rejected, .source_changed, 0);
    if (!grant.permits(request.plan.operation)) return close(turn, current, .rejected, .denied, 0);
    const result = s.TableMutation.apply(turn, request.target(), request.plan) catch |err| {
        if (turn.read_error != null) return err;
        return switch (err) {
            error.RowExists => close(turn, current, .rejected, .row_exists, 0),
            error.TableNotFound, error.TableSchemaChanged => close(turn, current, .rejected, .source_changed, 0),
            error.MutationBudgetExceeded => close(turn, current, .rejected, .budget, 0),
            else => err,
        };
    };
    try close(turn, current, .applied, .none, result.affected_rows);
}
/// Called only by an application that explicitly exposes the mutation protocol.
/// The authenticated envelope supplies the caller. No payload can choose it.
/// Requires a fresh proposal so verified publication reads precede all writes.
/// Any error restores the complete incoming decision; read poison is preserved.
pub fn dispatch(turn: *Turn) !r.Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    try turn.validate();
    for (before.mutations) |mutation| if (mutation != null) return error.MutationAfterWrite;
    const frame = try s.Frame.decode(turn.delivery.input.value);
    if (frame.kind != .cast) return error.ExpectedCast;
    const principal = switch (turn.delivery.input.origin) {
        .external => |origin| origin.principal,
        else => return error.ExpectedExternalOrigin,
    };
    if (principal == 0 or principal > p.max_counter) return error.MutationPrincipalMismatch;
    const command = try r.Command.decode(&frame.payload);
    if (command == .begin) return begin(turn, principal, command.begin);
    const namespace = switch (command) {
        .begin => unreachable,
        .part => |value| value.namespace,
        .seal, .apply, .cancel => |value| value,
    };
    var current = try required(turn, namespace, principal);
    if (!current.terminal()) try checkActive(turn, namespace);
    switch (command) {
        .begin => unreachable,
        .part => |value| {
            if (current.phase != .uploading) return error.MutationUploadClosed;
            _ = try permitted(turn, current);
            try s.PublicationParts.append(turn, current.reference, r.key('h', namespace, 0), .{ .ordinal = value.ordinal, .second = value.second, .bytes = value.bytes });
        },
        .seal => {
            if (current.phase != .uploading and current.phase != .sealed) return error.MutationUploadClosed;
            _ = try permitted(turn, current);
            if (current.phase == .uploading) {
                _ = try current.reference.publication().publish(turn, current.reference.record);
                current.phase = .sealed;
                try store(turn, current);
            }
        },
        .apply => try apply(turn, &current),
        .cancel => if (!current.terminal()) {
            // Cancellation is allowed after policy revocation. It cannot apply
            // rows, undo a committed result, delete evidence or dispatch effects.
            if (current.phase == .uploading) _ = try current.reference.publication().abandon(turn, current.reference.record);
            try close(turn, &current, .cancelled, .none, 0);
        },
    }
    try turn.validate();
    return current;
}

//! Document initialization over the existing native resource owner. Each step is a private Station turn; the caller commits it
//! before the next step. This owner neither allocates nor publishes a catalog
//! name, grants access, nor promises atomicity between those separate owners.
const std = @import("std");
const app = @import("root.zig");
const s = app.station;
const p = app.protocol;
const d = p.DataLifecycle;
const c = app.query.catalog;
const Resource = c.DirectResource;
const Service = app.query.document.Service;
const Self = @This();

/// Keep the initial interpretation after rename. A later definition must not
/// manufacture a new initialization identity for the same resource.
initial: Resource.Definition,
pub const Step = enum { reserved, initialized, complete };

pub fn reservationKey() p.Value {
    return p.Value.init("\x00NP") catch unreachable;
}

fn marker(self: Self, allocator: std.mem.Allocator, source: anytype) !d.ResourceInitialization {
    const expected = try self.initial.initialization(allocator);
    if (source.view.resource != expected.resource) return error.NamedResourceIdentityConflict;
    return expected;
}

fn requireSame(expected: d.ResourceInitialization, value: p.Value) !void {
    if (!std.meta.eql(expected, try d.ResourceInitialization.decode(value))) return error.NamedResourceIdentityConflict;
}

fn rights(self: Self, source: anytype, who: u64, write: bool) !void {
    if (@TypeOf(source) == *s.client.ResourceReader.Reader) {
        // A public reader acts only as its own signed native caller. The read
        // access operation checks current resource lifetime and data rights;
        // it does not create a version, input or execution grant.
        if (write or source.client.principal != who or source.client.realm != self.initial.object.scope.realm) return error.NamedResourceIdentityConflict;
        const current = (try source.client.query(.{ .read_access = self.initial.resource })).body.read_access;
        if (current.writer != self.initial.creation.writer) return error.NamedResourceIdentityConflict;
        return;
    }
    var required: p.Authorization.Guard = .{ .subject = try source.authorizationSubject(who), .requirements = @splat(null) };
    required.requirements[0] = .{ .object = .{ .kind = .resource, .id = self.initial.resource }, .privileges = p.State.permission(.inspect) | p.State.permission(.read) | if (write) p.State.permission(.write) else @as(u8, 0) };
    _ = try source.requireAuthorization(required);
}

/// No mutation, allocation, job admission or scheduler wakeup. The marker
/// describes initialization, not current resource lifetime or caller access;
/// the native read and guard establish those independently.
pub fn inspect(self: Self, allocator: std.mem.Allocator, source: anytype, who: u64) !?Step {
    const expected = try self.marker(allocator, source);
    try self.rights(source, who, false);
    const ready = try source.read(d.ResourceInitialization.key());
    const reserved = try source.read(reservationKey());
    if (reserved) |value| try requireSame(expected, value);
    if (ready) |value| {
        try requireSame(expected, value);
        if (reserved == null) return error.NamedResourceNotInitialized;
        _ = try self.documentHead(source, false);
        try self.rights(source, who, false);
        return .complete;
    }
    if (reserved == null) {
        try self.rights(source, who, false);
        return null;
    }
    const service = try self.document();
    if (try source.read(service.key('h', 0)) != null) {
        _ = try self.documentHead(source, true);
        try self.rights(source, who, false);
        return .initialized;
    }
    try self.rights(source, who, false);
    return .reserved;
}

/// Bounded, replayable initialization. A Document first reserves its exact
/// interpretation, then uses Document.Service.create, then commits the marker.
/// A missing acknowledgement repeats the same durable state transition. There
/// is no implicit adoption of a pre-existing Document or populated resource.
pub fn initialize(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, who: u64) !Step {
    const before = turn.decision;
    errdefer turn.decision = before;
    const expected = try self.marker(allocator, turn);
    if (turn.delivery.realm != self.initial.object.scope.realm or turn.delivery.pid != self.initial.creation.writer) return error.NamedResourceIdentityConflict;
    try self.rights(turn, who, true);
    const observed = try self.inspect(allocator, turn, who);
    if (observed == .complete) return .complete;
    if (observed == null) {
        // Framework records occupy the zero prefix. All user keys begin above
        // it; one bounded scan establishes whether the user namespace is empty.
        var last_framework: [p.Growth.key_bytes]u8 = @splat(255);
        last_framework[0] = 0;
        // GenServer may already propose its protected behavior descriptor. Read
        // the committed cut explicitly and reject private user mutations too;
        // neither private writes nor deletes may hide populated application data.
        for (turn.decision.mutations) |slot| if (slot) |mutation| {
            if (mutation.key.slice()[0] != 0) return error.NamedResourceNotEmpty;
        };
        var committed = turn.committed();
        const page = try committed.page(try p.Value.init(&last_framework));
        for (page.entries) |entry| if (entry != null) return error.NamedResourceNotEmpty;
        if (page.next != null) return error.NamedResourceIncomplete;
        const service = try self.document();
        if (try turn.read(service.key('h', 0)) != null) return error.NamedResourceNotEmpty;
        if (service.publication().budget(turn)) |_| return error.NamedResourceNotEmpty else |err| {
            if (err != error.PublicationNamespaceNotFound) return err;
        }
        try turn.write(reservationKey(), try expected.encode());
        return .reserved;
    } else if (observed == .reserved) {
        const spec = self.initial.creation.spec.document;
        try (try self.document()).create(turn, spec.type_revision, spec.limits);
        return .initialized;
    }
    _ = try self.documentHead(turn, true);
    try turn.write(d.ResourceInitialization.key(), try expected.encode());
    return .complete;
}

pub fn document(self: Self) !Service {
    try self.initial.validate();
    return .{ .resource = self.initial.resource, .document = self.initial.creation.spec.document.document };
}

fn documentHead(self: Self, source: anytype, empty: bool) !Service.Head {
    const service = try self.document();
    const spec = self.initial.creation.spec.document;
    const head = try service.head(source);
    if (head.retired) return error.DocumentRetired;
    if (head.state.type_revision != spec.type_revision or !std.meta.eql((try service.publication().budget(source)).limits, spec.limits)) return error.NamedResourceIdentityConflict;
    if (empty and (head.state.revision != 0 or head.state.epoch != 1 or head.state.index.root != null or head.active_job != 0)) return error.NamedResourceNotEmpty;
    _ = try service.open(source, head.state.revision);
    return head;
}

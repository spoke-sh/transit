//! A host-pumped behavior loop. A step performs bounded public-client work.
//! An uncertain submission always remains pending ahead of another handler.
const std = @import("std");
const client = @import("transit_client");
const p = client.protocol;
const Turn = @import("Turn.zig");
const Frame = @import("Frame.zig");
const GenServer = @This();

session: client.Session,
association: p.Value,
pending: ?client.Session.Pending = null,
pending_kind: enum { permit, open, commit } = .permit,
delivery: ?client.Session.Delivery = null,
resource: ?p.State.Resource = null,
view_id: ?u64 = null,
blocked: bool = false,
handler_error: ?anyerror = null,

pub const Step = enum { idle, progress, committed, blocked };
pub const Handler = struct {
    context: ?*anyopaque = null,
    initialize: ?*const fn (?*anyopaque, *Turn) anyerror!void = null,
    handle: *const fn (?*anyopaque, *Turn, Frame) anyerror!void,
};
pub const descriptor_key = p.Value.init("\x00station") catch unreachable;
pub const descriptor = p.Value.init("station.genserver.v1") catch unreachable;

pub fn init(session: client.Session, association: []const u8) !GenServer {
    const name = try p.Value.init(association);
    try p.State.key(name);
    return .{ .session = session, .association = name };
}

/// The proposed read deadline is checked by authority, never accepted as a
/// substitute for it. The host supplies time outside the deterministic handler.
pub fn step(self: *GenServer, handler: Handler, read_deadline_ms: u64) !Step {
    if (self.blocked) return .blocked;
    if (self.pending) |*pending| {
        const receipt = try pending.submit(self.session.client);
        // Retain the exact proposal on every error. The host must reconcile or
        // acquire a new activation before abandoning an uncertain operation.
        self.pending = null;
        switch (self.pending_kind) {
            .permit => self.delivery = null,
            .open => self.view_id = receipt.position,
            .commit => {
                self.delivery = null;
                self.resource = null;
                self.view_id = null;
                if (self.handler_error != null) {
                    self.blocked = true;
                    return .blocked;
                }
                return .committed;
            },
        }
        return .progress;
    }
    if (self.delivery == null) {
        self.delivery = (try self.session.receive()) orelse return .idle;
        if (self.delivery.?.needs_permit) {
            self.pending = try self.session.prepareBegin(self.delivery.?);
            self.pending_kind = .permit;
            return .progress;
        }
    }
    if (self.resource == null) {
        const id = try self.resolveAssociation();
        const page = try self.session.client.state(.{ .realm = self.session.realm, .principal = self.session.principal, .kind = .resources, .resource = id }, self.session.key);
        const resource = page.resources[0] orelse return error.MissingStateResource;
        if (resource.id != id or resource.writer != self.session.pid) return error.InvalidStateAssociation;
        self.resource = resource;
    }
    if (self.view_id == null) {
        var deadline = read_deadline_ms;
        if (self.resource.?.deadline_ms) |limit| deadline = @min(deadline, limit);
        self.pending = try self.session.prepareStateView(self.delivery.?, self.resource.?, deadline);
        self.pending_kind = .open;
        return .progress;
    }
    var page = try self.session.readStateView(self.view_id.?, null);
    const view = page.view orelse return error.InvalidAuthorityResponse;
    if (view.id != self.view_id.? or view.resource != self.resource.?.id) return error.InvalidAuthorityResponse;
    var entries: [p.State.max_entries]?p.State.Entry = @splat(null);
    var count: usize = 0;
    var after: u16 = 0;
    while (true) {
        for (page.entries) |slot| if (slot) |entry| {
            if (count == entries.len) return error.InvalidAuthorityResponse;
            entries[count] = entry;
            count += 1;
        };
        const next = page.next orelse break;
        if (next <= after or next > p.State.max_entries) return error.InvalidAuthorityResponse;
        after = next;
        page = try self.session.client.state(.{ .realm = self.session.realm, .principal = self.session.principal, .kind = .view, .pid = self.session.pid, .view = view.id, .after = after, .cut = page.cut }, self.session.key);
        if (page.view == null or !std.meta.eql(page.view.?, view)) return error.InvalidAuthorityResponse;
    }
    const fresh = (try self.session.receive()) orelse return error.InvalidAuthorityResponse;
    if (fresh.input.position != self.delivery.?.input.position or fresh.revision != self.delivery.?.revision) return error.InvalidAuthorityResponse;
    var turn = try Turn.init(fresh, view, entries);
    turn.resource_deadline_ms = self.resource.?.deadline_ms;
    self.handler_error = null;
    dispatch(&turn, handler) catch |err| {
        self.handler_error = err;
        // A failed handler cannot publish any private writes, sends or effects.
        turn.decision = .{ .views = .{ view, null, null, null }, .failed = true };
    };
    self.pending = try self.session.prepareStateCommit(fresh, turn.decision);
    self.pending_kind = .commit;
    return .progress;
}

fn dispatch(turn: *Turn, handler: Handler) !void {
    if (turn.get(descriptor_key)) |stored| {
        if (!stored.eql(descriptor)) return error.UnsupportedBehavior;
    } else {
        if (handler.initialize) |initialize| try initialize(handler.context, turn);
        try turn.write(descriptor_key, descriptor);
    }
    const frame = try Frame.decode(turn.delivery.input.value);
    if (try @import("Waiting.zig").dispatch(turn, frame)) return turn.validate();
    if (try @import("Query.zig").dispatch(turn, frame)) return turn.validate();
    if (frame.kind == .reply) switch (try turn.acceptReply()) {
        .accepted => {},
        .closed => {
            // Record a disposition in the same ordered turn. This is not an
            // application callback or reopening of a completed wait.
            try turn.write(try p.Value.init("\x00disposition"), try p.Value.init("station.closed-reply.v1"));
            return turn.validate();
        },
    };
    try handler.handle(handler.context, turn, frame);
    try turn.validate();
}

fn resolveAssociation(self: *GenServer) !u64 {
    var page = try self.session.associations();
    var after: u16 = 0;
    while (true) {
        for (page.associations) |slot| if (slot) |association| {
            if (association.name.eql(self.association)) {
                if (!association.required) return error.RequiredStateAssociation;
                return association.resource;
            }
        };
        const next = page.next orelse return error.MissingStateAssociation;
        if (next <= after or next > p.State.max_associations) return error.InvalidAuthorityResponse;
        after = next;
        page = try self.session.client.state(.{ .realm = self.session.realm, .principal = self.session.principal, .kind = .associations, .pid = self.session.pid, .after = after, .cut = page.cut }, self.session.key);
    }
}

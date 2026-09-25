//! Shared host-pumped behavior loop. Exact pending mutations always precede
//! another handler. Growing handlers read bounded keys through a captured view.
const std = @import("std");
const client = @import("transit_client");
const p = client.protocol;
const Frame = @import("Frame.zig");
pub const Legacy = Type(false);
pub const Growing = Type(true);
pub fn Type(comptime growing: bool) type {
    return struct {
        const GenServer = @This();
        const Session = if (growing) client.GrowingSession else client.Session;
        const Turn = @import("Turn.zig").Type(growing);
        const Resource = if (growing) p.Growth.Resource else p.State.Resource;
        session: Session,
        association: p.Value,
        pending: ?Session.Pending = null,
        pending_kind: enum { permit, open, commit } = .permit,
        delivery: ?Session.Delivery = null,
        resource: ?Resource = null,
        view_id: ?u64 = null,
        blocked: bool = false,
        handler_error: ?anyerror = null,
        ready: ?Turn = null,
        initializing: bool = false,

        pub const Step = enum { idle, progress, committed, blocked };
        pub const Poll = enum { idle, progress, ready, committed, blocked };
        pub const Handler = struct {
            context: ?*anyopaque = null,
            initialize: ?*const fn (?*anyopaque, *Turn) anyerror!void = null,
            handle: *const fn (?*anyopaque, *Turn, Frame) anyerror!void,
        };
        pub const descriptor_key = p.Value.init("\x00station") catch unreachable;
        pub const descriptor = p.Value.init(if (growing) "station.genserver.growing.v1" else "station.genserver.v1") catch unreachable;

        pub fn init(session: Session, association: []const u8) !GenServer {
            const name = try p.Value.init(association);
            try p.State.key(name);
            return .{ .session = session, .association = name };
        }

        /// The proposed read deadline is checked by authority, never accepted as a
        /// substitute for it. The host supplies time outside the deterministic handler.
        pub fn step(self: *GenServer, handler: Handler, read_deadline_ms: u64) !Step {
            return switch (try self.poll(read_deadline_ms)) {
                .idle => .idle,
                .progress => .progress,
                .committed => .committed,
                .blocked => .blocked,
                .ready => blk: {
                    var failure: ?anyerror = null;
                    if (self.initializing) if (handler.initialize) |initialize| initialize(handler.context, &self.ready.?) catch |err| {
                        failure = err;
                    };
                    if (failure == null) handler.handle(handler.context, &self.ready.?, try Frame.decode(self.ready.?.delivery.input.value)) catch |err| {
                        failure = err;
                    };
                    try self.finish(failure);
                    break :blk .progress;
                },
            };
        }
        /// The same turn machine exposed to foreign hosts. Polling does not acknowledge
        /// an application input; finish explicitly freezes its private proposal.
        pub fn poll(self: *GenServer, read_deadline_ms: u64) !Poll {
            if (self.ready != null) return .ready;
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
                const resource = if (growing) (try self.session.client.queryGrowing(.{ .realm = self.session.realm, .principal = self.session.principal, .kind = .{ .resource = id } }, self.session.key)).body.resource else blk: {
                    const page = try self.session.client.state(.{ .realm = self.session.realm, .principal = self.session.principal, .kind = .resources, .resource = id }, self.session.key);
                    break :blk page.resources[0] orelse return error.MissingStateResource;
                };
                if (resource.id != id or resource.writer != self.session.pid) return error.InvalidStateAssociation;
                self.resource = resource;
            }
            if (self.view_id == null) {
                var deadline = read_deadline_ms;
                if (self.resource.?.deadline_ms) |limit| deadline = @min(deadline, limit);
                if (growing) if (self.delivery.?.settle_before_ms) |limit| {
                    deadline = @min(deadline, limit);
                };
                self.pending = if (growing) try self.session.prepareView(self.delivery.?, self.resource.?, deadline) else try self.session.prepareStateView(self.delivery.?, self.resource.?, deadline);
                self.pending_kind = .open;
                return .progress;
            }
            try self.prepareTurn();
            self.ready.?.resource_deadline_ms = self.resource.?.deadline_ms;
            self.handler_error = null;
            self.initializing = (self.ready.?.read(descriptor_key) catch |err| {
                self.ready = null;
                return err;
            }) == null;
            const internal = preprocess(&self.ready.?) catch |err| {
                try self.finish(err);
                return .progress;
            };
            if (internal) {
                try self.finish(if (self.initializing) error.UninitializedBehavior else null);
                return .progress;
            }
            return .ready;
        }
        pub fn finish(self: *GenServer, failure: ?anyerror) !void {
            const turn = if (self.ready) |*value| value else return error.NoPreparedTurn;
            if (turn.read_error) |err| {
                // No proposal was sent. Drop all private writes and rerun reads against
                // this view on a later poll; never manufacture an application failure.
                self.ready = null;
                return err;
            }
            self.handler_error = failure;
            if (self.handler_error == null) turn.validate() catch |err| {
                self.handler_error = err;
            };
            if (self.handler_error != null) turn.decision = .{ .views = .{ turn.view, null, null, null }, .failed = true };
            self.pending = if (growing) try self.session.prepareCommit(turn.delivery, turn.decision) else try self.session.prepareStateCommit(turn.delivery, turn.decision);
            self.pending_kind = .commit;
            self.ready = null;
        }

        fn preprocess(turn: *Turn) !bool {
            if (try turn.read(descriptor_key)) |stored| {
                if (!stored.eql(descriptor)) return error.UnsupportedBehavior;
            } else {
                try turn.write(descriptor_key, descriptor);
            }
            const frame = try Frame.decode(turn.delivery.input.value);
            if (try @import("Waiting.zig").dispatch(turn, frame)) return true;
            if (growing) {
                switch (frame.kind) {
                    .result_chunk, .result_complete, .result_ack => return error.UnsupportedGrowingQuery,
                    else => {},
                }
            } else if (try @import("Query.zig").dispatch(turn, frame)) return true;
            if (frame.kind == .reply) switch (try turn.acceptReply()) {
                .accepted => {},
                .closed => {
                    // Record a disposition in the same ordered turn. This is not an
                    // application callback or reopening of a completed wait.
                    try turn.write(try p.Value.init("\x00disposition"), try p.Value.init("station.closed-reply.v1"));
                    return true;
                },
            };
            return false;
        }

        fn resolveAssociation(self: *GenServer) !u64 {
            if (growing) {
                const association = (try self.session.association(self.association)) orelse return error.MissingStateAssociation;
                if (!association.required) return error.RequiredStateAssociation;
                return association.resource;
            }
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

        fn prepareTurn(self: *GenServer) !void {
            if (growing) {
                const page = try self.session.readView(self.view_id.?, descriptor_key, null);
                const view = page.view orelse return error.InvalidAuthorityResponse;
                if (view.resource != self.resource.?.id) return error.InvalidAuthorityResponse;
                const fresh = try self.freshDelivery();
                self.ready = try Turn.init(fresh, view, .{ .context = self, .read = readKey, .page = readPage, .version = readVersion, .version_entries = readVersionEntries });
                return;
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
            self.ready = try Turn.init(fresh, view, entries);
        }
        fn freshDelivery(self: *GenServer) !Session.Delivery {
            const fresh = (try self.session.receive()) orelse return error.InvalidAuthorityResponse;
            if (fresh.input.position != self.delivery.?.input.position or fresh.revision != self.delivery.?.revision) return error.InvalidAuthorityResponse;
            return fresh;
        }
        fn readKey(context: *anyopaque, view: p.Growth.View, key: p.Value) anyerror!?p.Value {
            const self: *GenServer = @ptrCast(@alignCast(context));
            const page = try self.session.readView(view.id, key, null);
            if (page.view == null or !std.meta.eql(page.view.?, view)) return error.InvalidAuthorityResponse;
            return if (page.page.entries[0]) |entry| entry.value else null;
        }
        fn readPage(context: *anyopaque, view: p.Growth.View, after: ?p.Value) anyerror!@import("Turn.zig").Page {
            const self: *GenServer = @ptrCast(@alignCast(context));
            const page = try self.session.readView(view.id, null, after);
            if (page.view == null or !std.meta.eql(page.view.?, view)) return error.InvalidAuthorityResponse;
            return page.page;
        }
        fn readVersion(context: *anyopaque, id: p.Growth.ReadVersionId) anyerror!p.Growth.ReadVersion {
            const self: *GenServer = @ptrCast(@alignCast(context));
            return self.session.version(id);
        }
        fn readVersionEntries(context: *anyopaque, basis: p.Growth.ReadVersion, key: ?p.Value, after: ?p.Value) anyerror!@import("Turn.zig").Page {
            const self: *GenServer = @ptrCast(@alignCast(context));
            return (try self.session.readVersion(basis, key, after)).page;
        }
    };
}

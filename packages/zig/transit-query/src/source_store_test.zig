//! Private-turn in-memory reference store, not a durability/authority proof.
const std = @import("std");
const q = @import("root.zig");
const p = q.protocol;
const t = std.testing;
const Turn = q.station.Turn;
const Self = @This();
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
const Revisions = std.AutoHashMapUnmanaged(p.Value, u64);
const Version = struct { view: p.Growth.ReadVersion, state: Map, revisions: Revisions, blocks: q.station.testing.Blocks };
state: Map = .empty,
blocks: q.station.testing.Blocks = .{},
revisions: Revisions = .empty,
versions: std.AutoHashMapUnmanaged(p.Growth.ReadVersionId, Version) = .empty,
resource: u64 = 7,
pid: u64 = 3,
revision: u64 = 1,
input: u64 = 1,
denied: bool = false,
authority: Authority = .{},
const Authority = q.catalog.testing.Authority;
pub const profile = Authority.profile;
pub const Rights = Authority.Rights;
/// Read-only domain mediation in the reference model. Unlike a committing
/// Turn, a reader may check a subject admitted by a different requester PID.
/// Native integration separately proves that subject through the authority.
pub const Reader = struct {
    store: *Self,
    data: Turn,
    view: p.Growth.View,
    subject: ?p.Authorization.Subject = null,
    pub fn read(self: *Reader, key: p.Value) !?p.Value {
        return self.data.read(key);
    }
    pub fn readBlock(self: *Reader, key: p.Value, output: []u8) !?[]const u8 {
        return self.data.readBlock(key, output);
    }
    pub fn prefetchBlocks(self: *Reader, keys: []const p.Value) !void {
        return self.data.prefetchBlocks(keys);
    }
    pub fn currentReader(self: *Reader) *Turn {
        return &self.data;
    }
    pub fn bindAuthorizationSubject(self: *Reader, subject: p.Authorization.Subject) !void {
        try subject.validate();
        self.subject = subject;
    }
    pub fn authorizationSubject(self: *Reader, who: u64) !p.Authorization.Subject {
        const subject = self.subject orelse return error.AccessDenied;
        if (subject.principal() != who) return error.AccessDenied;
        return subject;
    }
    pub fn requireAuthorization(self: *Reader, guard: p.Authorization.Guard) !p.Authorization.Verified {
        if (!std.meta.eql(self.subject orelse return error.AccessDenied, guard.subject)) return error.AccessDenied;
        return self.store.requireAuthorization(guard);
    }
};
pub fn reader(self: *Self) !Reader {
    const data = try self.capture();
    return .{ .store = self, .data = data, .view = data.view };
}
/// Explicit test credential and routing. Call before publishing or fingerprinting
/// a request; the immutable query is never resigned by upload/recovery helpers.
pub fn signQuery(description: anytype, principal: u64, audience: u64, requester: u64, requests: u64) !@TypeOf(description) {
    const Bundle = @TypeOf(description);
    if (Bundle == q.Bundle) if (description.source.source != .table) return description;
    if (description.authorization != null) return error.QueryAlreadyAuthorized;
    var bytes: [Bundle.max_bytes]u8 = undefined;
    var bundle = description;
    bundle.authorization = .{ .requester = requester, .requests = requests, .proof = try p.Authorization.Proof.sign(.{
        .definition = p.Growth.current_definition,
        .realm = 1,
        .principal = principal,
        .credential_epoch = 1,
        .role = principal,
        .audience = audience,
        .context = try q.QueryAuthorization.context(requester, requests, try description.encode(&bytes)),
    }, try Authority.key(principal)) };
    return bundle;
}
pub fn setRights(self: *Self, rights: Rights) !void {
    try self.authority.setRights(rights);
}
pub fn grantObject(self: *Self, principal: u64, object: u64, privileges: u64) !void {
    try self.authority.grantObject(principal, object, privileges);
}
pub fn authorizationSubject(self: *Self, who: u64) !p.Authorization.Subject {
    self.authority.input = self.input;
    self.authority.audience = self.pid;
    return self.authority.authorizationSubject(who);
}
pub fn requireAuthorization(self: *Self, guard: p.Authorization.Guard) !p.Authorization.Verified {
    return self.authority.requireAuthorization(guard);
}
fn authorize(raw: *anyopaque, guard: p.Authorization.Guard) !?p.Authorization.Verified {
    const self: *Self = @ptrCast(@alignCast(raw));
    return Authority.authorize(&self.authority, guard);
}
fn binding(raw: *anyopaque, domain: u64, identity: [32]u8) !?p.Authorization.Object {
    const self: *Self = @ptrCast(@alignCast(raw));
    return Authority.binding(&self.authority, domain, identity);
}

pub fn deinit(self: *Self) void {
    self.authority.deinit();
    self.state.deinit(t.allocator);
    self.blocks.deinit(t.allocator);
    self.revisions.deinit(t.allocator);
    var versions = self.versions.valueIterator();
    while (versions.next()) |retained| {
        retained.state.deinit(t.allocator);
        retained.blocks.deinit(t.allocator);
        retained.revisions.deinit(t.allocator);
    }
    self.versions.deinit(t.allocator);
}
pub fn clone(self: *Self) !Self {
    var copy: Self = .{ .resource = self.resource, .pid = self.pid, .revision = self.revision, .input = self.input };
    copy.authority = try self.authority.clone();
    errdefer copy.authority.deinit();
    copy.state = try self.state.clone(t.allocator);
    copy.blocks = try self.blocks.clone(t.allocator);
    copy.revisions = try self.revisions.clone(t.allocator);
    return copy;
}
fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    return self.state.get(key);
}
fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    return pageMap(&self.state, &self.revisions, after);
}
fn pageMap(state: *Map, revisions: *Revisions, after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
    var next: p.Growth.Batch(p.Growth.Entry, p.Value) = .{};
    var cursor = after;
    for (0..p.Growth.page_size + 1) |index| {
        var minimum: ?p.Value = null;
        var entries = state.keyIterator();
        while (entries.next()) |key| {
            if (cursor) |previous| if (std.mem.order(u8, key.slice(), previous.slice()) != .gt) continue;
            if (minimum == null or std.mem.order(u8, key.slice(), minimum.?.slice()) == .lt) minimum = key.*;
        }
        const key = minimum orelse break;
        if (index == p.Growth.page_size) {
            next.next = cursor;
            break;
        }
        next.entries[index] = .{ .key = key, .value = state.get(key).?, .revision = revisions.get(key).? };
        cursor = key;
    }
    return next;
}
fn version(raw: *anyopaque, id: p.Growth.ReadVersionId) !p.Growth.ReadVersion {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    return (self.versions.get(id) orelse return error.InvalidReadVersion).view;
}
fn versionEntries(raw: *anyopaque, view: p.Growth.ReadVersion, key: ?p.Value, after: ?p.Value) !p.Growth.Batch(p.Growth.Entry, p.Value) {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    const retained = self.versions.getPtr(view.id) orelse return error.InvalidReadVersion;
    if (retained.view.released_at != null or retained.view.revision != view.revision) return error.InvalidReadVersion;
    if (key) |address| {
        var result: p.Growth.Batch(p.Growth.Entry, p.Value) = .{};
        if (retained.state.get(address)) |value| result.entries[0] = .{ .key = address, .value = value, .revision = retained.revisions.get(address).? };
        return result;
    }
    return pageMap(&retained.state, &retained.revisions, after);
}
fn readBlocks(raw: *anyopaque, query: p.Growth.BlockRead.Query, body: *p.Blocks.Body) !p.Growth.BlockRead.Result {
    const self: *Self = @ptrCast(@alignCast(raw));
    if (self.denied) return error.AccessDenied;
    if (query.source == .view) return self.blocks.read(query, body, self.blocks.views.get(query.source.view) orelse return error.InvalidRead);
    const retained = self.versions.getPtr(query.source.version.id) orelse return error.InvalidReadVersion;
    if (retained.view.released_at != null) return error.InvalidReadVersion;
    const view: p.Growth.View = .{ .id = 1, .pid = self.pid, .principal = 2, .generation = 1, .input = 1, .process_revision = retained.view.revision, .resource = self.resource, .revision = retained.view.revision, .deadline_ms = 10000 };
    var selected = query;
    selected.source = .{ .view = 1 };
    var result = try retained.blocks.read(selected, body, view);
    result.view = null;
    result.version = retained.view;
    return result;
}
pub fn capture(self: *Self) !Turn {
    const proposal = try Turn.init(.{ .realm = 1, .principal = 2, .pid = self.pid, .generation = 1, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = 0, .policy_revision = 0 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = self.pid, .principal = 2, .generation = 1, .input = self.input, .process_revision = self.revision, .resource = self.resource, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .blocks = readBlocks, .page = page, .version = version, .version_entries = versionEntries, .authorization = authorize, .authorization_binding = binding });
    try self.blocks.views.put(t.allocator, proposal.view.id, proposal.view);
    return proposal;
}
pub fn commit(self: *Self, turn: Turn) !void {
    try turn.validate();
    for (turn.decision.retain, 0..) |slot, index| if (slot) |id| {
        try t.expectEqual(turn.view.id, id);
        const identity: p.Growth.ReadVersionId = .{ .pid = turn.delivery.pid, .input = turn.delivery.input.position, .index = @intCast(index) };
        try self.versions.put(t.allocator, identity, .{ .blocks = try self.blocks.clone(t.allocator), .state = try self.state.clone(t.allocator), .revisions = try self.revisions.clone(t.allocator), .view = .{ .id = identity, .resource = self.resource, .revision = self.revision, .created_at = self.input } });
    };
    for (turn.decision.release) |slot| if (slot) |id| {
        const retained = self.versions.getPtr(id) orelse return error.InvalidReadVersion;
        retained.view.released_at = self.input;
    };
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.value) |value| {
            try self.state.put(t.allocator, mutation.key, value);
            try self.revisions.put(t.allocator, mutation.key, self.revision + 1);
        } else {
            _ = self.state.remove(mutation.key);
            _ = self.revisions.remove(mutation.key);
        }
    };
    try self.blocks.apply(t.allocator, &turn.decision.blocks, self.revision + 1);
    self.revision += 1;
    self.input += 1;
}

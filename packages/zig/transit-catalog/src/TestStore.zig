//! Independent dynamic-map fixture, not storage or native authority evidence.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const t = std.testing;
const Self = @This();
const Map = std.AutoHashMapUnmanaged(p.Value, p.Value);
state: Map = .empty,
changed_at: std.AutoHashMapUnmanaged(p.Value, u64) = .empty,
revision: u64 = 1,
input: u64 = 1,
reads: usize = 0,
pages: usize = 0,
fail_at: ?usize = null,
fail_page: bool = false,
bad_page: enum { none, gap, next, revision, order } = .none,
authority: Authority = .{},
const Authority = @import("TestAuthority.zig");
pub const profile = Authority.profile;
pub const Rights = Authority.Rights;
pub fn setRights(self: *Self, rights: Rights) !void {
    try self.authority.setRights(rights);
}
pub fn grantObject(self: *Self, principal: u64, object: u64, privileges: u64) !void {
    try self.authority.grantObject(principal, object, privileges);
}
pub fn authorizationSubject(self: *Self, who: u64, audience: u64) !p.Authorization.Subject {
    self.authority.input = self.input;
    return self.authority.authorizationSubject(who, audience);
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
    self.state.deinit(t.allocator);
    self.changed_at.deinit(t.allocator);
    self.authority.deinit();
}
pub fn clone(self: *Self) !Self {
    var state = try self.state.clone(t.allocator);
    errdefer state.deinit(t.allocator);
    var changed_at = try self.changed_at.clone(t.allocator);
    errdefer changed_at.deinit(t.allocator);
    return .{ .state = state, .changed_at = changed_at, .authority = try self.authority.clone(), .revision = self.revision, .input = self.input };
}
fn read(raw: *anyopaque, _: p.Growth.View, key: p.Value) !?p.Value {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.reads += 1;
    if (self.fail_at == self.reads) return error.Unavailable;
    return self.state.get(key);
}
fn page(raw: *anyopaque, _: p.Growth.View, after: ?p.Value) !c.station.Turn.Page {
    const self: *Self = @ptrCast(@alignCast(raw));
    self.pages += 1;
    if (self.fail_page) return error.Unavailable;
    var result: c.station.Turn.Page = .{};
    var cursor = after;
    // Slow independent selection deliberately shares no production index code.
    for (0..p.Growth.page_size + 1) |index| {
        var minimum: ?p.Value = null;
        var keys = self.state.keyIterator();
        while (keys.next()) |key| {
            if (cursor) |old| if (std.mem.order(u8, old.slice(), key.slice()) != .lt) continue;
            if (minimum == null or std.mem.order(u8, key.slice(), minimum.?.slice()) == .lt) minimum = key.*;
        }
        const key = minimum orelse break;
        if (index == p.Growth.page_size) {
            result.next = cursor;
            break;
        }
        result.entries[index] = .{ .key = key, .value = self.state.get(key).?, .revision = self.changed_at.get(key) orelse self.revision };
        cursor = key;
    }
    switch (self.bad_page) {
        .none => {},
        .gap => result.entries[0] = null,
        .next => result.next = try p.Value.init("invalid"),
        .revision => result.entries[0].?.revision = self.revision + 1,
        .order => std.mem.swap(?p.Growth.Entry, &result.entries[0], &result.entries[1]),
    }
    return result;
}
pub fn capture(self: *Self, principal: u64) !c.station.Turn {
    return c.station.Turn.init(.{ .realm = 1, .principal = 2, .pid = 3, .generation = 1, .sequence = self.input, .revision = self.revision, .input = .{ .position = self.input, .ordinal = self.input, .value = .{}, .origin = .{ .external = .{ .principal = principal, .policy_revision = 1 } } }, .permit = null, .needs_permit = false }, .{ .id = self.input + 1000, .pid = 3, .principal = 2, .generation = 1, .input = self.input, .process_revision = self.revision, .resource = 7, .revision = self.revision, .deadline_ms = 10000 }, .{ .context = self, .read = read, .page = page, .authorization = authorize, .authorization_binding = binding });
}
pub fn commit(self: *Self, turn: c.station.Turn) !void {
    try turn.validate();
    if (turn.view.revision != self.revision) return error.Conflict;
    for (turn.decision.mutations) |slot| if (slot) |mutation| {
        if (mutation.value) |value| {
            try self.state.put(t.allocator, mutation.key, value);
            try self.changed_at.put(t.allocator, mutation.key, self.revision + 1);
        } else {
            _ = self.state.remove(mutation.key);
            _ = self.changed_at.remove(mutation.key);
        }
    };
    self.revision += 1;
    self.input += 1;
}

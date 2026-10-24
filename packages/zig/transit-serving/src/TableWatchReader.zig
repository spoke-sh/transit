//! Direct Table observations mediated by the original watch subject. The
//! configured reader's data grant never supplies missing caller permission.
const std = @import("std");
const root = @import("root.zig");
const c = root.query.catalog;
const r = root.ReactiveModel;
const w = c.DirectTableProtocol;
const Self = @This();
tables: c.DirectTableClient,
subject: c.TableAuthority.Context,
observed: ?c.DirectReadAuthority = null,

pub fn init(resources: root.station.client.ResourceReader, subject: root.protocol.Authorization.Subject, source: r.Source) !Self {
    try source.validate();
    if (source.realm != resources.realm) return error.InvalidReactiveSource;
    return .{
        .tables = .{ .allocator = resources.wire.http.allocator, .authority = resources.wire, .service = resources.wire, .connection = .{ .scope = source.scope(), .branch = source.branch, .audience = source.audience, .principal = resources.principal, .role = null }, .key = resources.key },
        .subject = root.query.QueryAuthorization.readerContext(resources, subject, null),
    };
}
fn requireSource(self: *Self, source: r.Source) !void {
    try source.validate();
    if (!std.meta.eql(source.scope(), self.tables.connection.scope) or source.branch != self.tables.connection.branch or source.audience != self.tables.connection.audience) return error.InvalidReactiveSource;
}
pub fn requirements(self: *Self, source: r.Source) !c.DirectReadAuthority {
    try self.requireSource(source);
    const response = try self.tables.call(.{ .read_authority = source.interpretation().object });
    defer response.deinit();
    return response.value.result.read_authority;
}
pub fn check(self: *Self, principal: u64, authority: c.DirectReadAuthority) !void {
    _ = try self.subject.authorizationSubject(principal);
    _ = try self.subject.requireAuthorization(try authority.guard(self.subject.subject));
    self.observed = authority;
}
pub fn observe(self: *Self, source: r.Source, rows: ?c.storage.TablePartition.ReadLimits) !std.json.Parsed(w.Response) {
    try self.requireSource(source);
    return self.tables.call(.{ .observe = .{ .namespace = source.namespace, .interpretation = source.interpretation(), .rows = rows } }) catch |err| {
        if (err == error.Conflict and self.tables.service.last_rejection == .Conflict) return error.ReactiveResetRequired;
        return err;
    };
}
pub fn finish(self: *Self) !void {
    const authority = self.observed orelse return error.CatalogDenied;
    try self.check(self.subject.subject.principal(), authority);
}

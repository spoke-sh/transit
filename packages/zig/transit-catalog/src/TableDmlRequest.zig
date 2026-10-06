//! Catalog-bound DML routing. Point qualification consumes the full predicate;
//! all other finite statements keep the shared frozen-source coordinator.
const std = @import("std");
const c = @import("root.zig");
const f = c.fuze;
const s = c.station;
const m = c.TableCatalogRecords;
const Self = @This();
principal: u64,
operation: u64,
metadata: s.TablePages.Reference,
plan: f.TableDml.Plan,
pub const Route = union(enum) {
    point: s.TableWrite.Request,
    finite: s.TableStatement.Request,
    pub fn receiptRoute(self: Route) s.TableWrite.Status.Route {
        return switch (self) {
            .point => .point,
            .finite => .statement,
        };
    }
    pub fn reference(self: Route, allocator: std.mem.Allocator) !s.TableWrite.Reference {
        return switch (self) {
            inline else => |request| request.reference(allocator),
        };
    }
    pub fn step(self: Route, allocator: std.mem.Allocator, turn: *s.Turn) !s.TableWrite.Status {
        return switch (self) {
            .point => |request| s.TableWrite.step(allocator, turn, request),
            .finite => |request| s.TableStatement.step(allocator, turn, request),
        };
    }
    pub fn cancel(self: Route, allocator: std.mem.Allocator, turn: *s.Turn) !s.TableWrite.Status {
        const ref = try self.reference(allocator);
        return switch (self) {
            .point => s.TableWrite.cancel(turn, ref),
            .finite => s.TableStatement.cancel(turn, ref),
        };
    }
};
pub fn right(self: Self) m.Right {
    return switch (self.plan.action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
    };
}
pub fn binding(self: Self, allocator: std.mem.Allocator, scope: m.Scope) ![32]u8 {
    try scope.validate();
    try m.metadataReference(self.metadata);
    if (self.principal > c.protocol.max_counter or self.operation == 0) return error.InvalidCatalogIdentity;
    const name = try c.TableMetadata.Name.init(self.plan.name);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.catalog.dml.v1\x00");
    hash.update(&c.TableMetadata.definition());
    var bytes: [128]u8 = undefined;
    var out: std.Io.Writer = .fixed(&bytes);
    try c.TableMetadata.scopeWrite(&out, scope);
    try out.writeInt(u64, self.principal, .little);
    try out.writeInt(u64, self.operation, .little);
    try out.writeInt(u64, self.metadata.id, .little);
    try out.writeInt(u32, self.metadata.spec.format, .little);
    try out.writeInt(u32, self.metadata.spec.length, .little);
    try out.writeAll(&self.metadata.spec.digest);
    hash.update(out.buffered());
    hash.update(&try name.digest());
    hash.update(&try self.plan.fingerprint(allocator));
    return hash.finalResult();
}
/// Returned point key cells borrow scratch; all other values borrow the request.
pub fn route(self: Self, allocator: std.mem.Allocator, scope: m.Scope, scratch: *[f.TableSchema.max_columns]f.Types.Values.Cell) !Route {
    const context = try self.binding(allocator, scope);
    const change: ?s.TableWrite.Change = switch (self.plan.action) {
        .insert => |rows| if (rows.len == 1) .{ .insert = .{ .identity = .{ .origin = self.principal + 1, .operation = self.operation, .ordinal = 0 }, .cells = rows[0] } } else null,
        .update => |assignments| if (try self.plan.primaryKeyEquality(scratch)) |key| .{ .patch = .{ .key = key, .assignments = assignments } } else null,
        .delete => if (try self.plan.primaryKeyEquality(scratch)) |key| .{ .delete_key = key } else null,
    };
    if (change) |point| return .{ .point = .{ .resource = scope.resource, .principal = self.principal, .operation = self.operation, .schema = self.plan.schema, .change = point, .owner_binding = context } };
    return .{ .finite = .{ .resource = scope.resource, .principal = self.principal, .operation = self.operation, .plan = self.plan, .owner_binding = context } };
}

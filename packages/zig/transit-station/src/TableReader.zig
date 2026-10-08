//! Owned general Table schema and bounded rows at one captured or retained cut.
//! Reads never see private mutations and never confer current authorization.
const std = @import("std");
const p = @import("transit_client").protocol;
const f = @import("transit_fuze");
const Turn = @import("Turn.zig");
const Head = @import("TableHead.zig");
const Pages = @import("TablePages.zig");
const Data = @import("TableData.zig");
const Self = @This();

pub const max_page_rows = p.Growth.page_size;
pub const Cut = union(enum) { view: u64, version: p.Growth.ReadVersionId };
pub const Basis = struct { cut: Cut, resource: u64, revision: u64, object: u64, head: [32]u8 };
pub const Cursor = struct { basis: Basis, after: f.TableRow.Identity };
pub const Page = struct {
    rows: [max_page_rows]?f.TableRow.Owned = @splat(null),
    len: u8 = 0,
    next: ?Cursor = null,
    pub fn deinit(self: *Page) void {
        for (&self.rows) |*slot| if (slot.*) |*row| row.deinit();
        self.* = undefined;
    }
};

head: Head,
schema: f.TableSchema.Owned,
basis: Basis,

fn Source(comptime T: type) type {
    return if (T == *Turn) Turn.Committed else @typeInfo(T).pointer.child;
}
fn committed(source: anytype) Source(@TypeOf(source)) {
    return if (@TypeOf(source) == *Turn) source.committed() else source.*;
}
fn basisOf(source: anytype, head: Head) !Basis {
    const encoded = try head.encode();
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(encoded.slice(), &digest, .{});
    return .{
        .cut = if (@TypeOf(source.view.id) == u64) .{ .view = source.view.id } else .{ .version = source.view.id },
        .resource = source.view.resource,
        .revision = source.view.revision,
        .object = head.object,
        .head = digest,
    };
}
pub fn open(allocator: std.mem.Allocator, source: anytype, object: u64) !Self {
    var snapshot = committed(source);
    const head = try Head.load(&snapshot, object);
    if (head.retired) return error.TableRetired;
    const basis = try basisOf(&snapshot, head);
    return .{ .head = head, .basis = basis, .schema = try head.readSchema(allocator, &snapshot) };
}
pub fn deinit(self: *Self) void {
    self.schema.deinit();
    self.* = undefined;
}
fn check(self: *const Self, source: anytype) !void {
    // Reject a moved handle before following any immutable data reference.
    if (!std.meta.eql(self.basis, try basisOf(source, self.head))) return error.StaleTableCursor;
    const actual = try Head.load(source, self.head.object);
    if (!std.meta.eql(self.basis, try basisOf(source, actual))) return error.TableHeadChanged;
}
/// Validate the exact captured handle before another owner retains its source.
pub fn validate(self: *const Self, source: anytype) !void {
    var snapshot = committed(source);
    try self.check(&snapshot);
}
fn data(self: *const Self) Data {
    return .{ .schema = self.schema.schema, .index = self.head.index };
}
fn pages(self: *const Self, source: anytype) Pages.Reader(@TypeOf(source)) {
    return .{ .pages = .{ .resource = self.head.resource, .object = self.head.object }, .source = source };
}
pub fn get(self: *const Self, allocator: std.mem.Allocator, source: anytype, identity: f.TableRow.Identity) !?f.TableRow.Owned {
    var snapshot = committed(source);
    try self.check(&snapshot);
    var reader = self.pages(&snapshot);
    return self.data().get(allocator, &reader, identity);
}
pub fn getKey(self: *const Self, allocator: std.mem.Allocator, source: anytype, key: []const f.Types.Values.Cell) !?f.TableRow.Owned {
    var snapshot = committed(source);
    try self.check(&snapshot);
    var reader = self.pages(&snapshot);
    const table = self.data();
    const identity = (try table.findKey(allocator, &reader, key)) orelse return null;
    return (try table.get(allocator, &reader, identity)) orelse error.InvalidTableIndex;
}
/// A continuation on a full page may yield an empty final page. Ordering is
/// stable internal row identity, never SQL ORDER BY or primary-key ordering.
/// Every row owns its descriptors and cells independently of this reader.
pub fn page(self: *const Self, allocator: std.mem.Allocator, source: anytype, cursor: ?Cursor, limit: u8) !Page {
    if (limit == 0 or limit > max_page_rows) return error.InvalidTablePageSize;
    if (cursor) |previous| if (!std.meta.eql(previous.basis, self.basis)) return error.StaleTableCursor;
    var snapshot = committed(source);
    try self.check(&snapshot);
    var reader = self.pages(&snapshot);
    var result: Page = .{};
    errdefer result.deinit();
    result.len = @intCast(try self.data().page(allocator, &reader, if (cursor) |previous| previous.after else null, result.rows[0..limit]));
    if (result.len == limit) result.next = .{ .basis = self.basis, .after = result.rows[result.len - 1].?.identity };
    return result;
}

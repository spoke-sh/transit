//! Owned exact SQL intent for caller persistence. The original schema is saved
//! for offline validation, never used as authority or sent as a replacement basis.
const std = @import("std");
const c = @import("root.zig");
const Command = c.TableCommand;
const Meta = c.TableMetadata;
const Schema = c.fuze.TableSchema;
const Pub = c.station.Publication;
const Self = @This();
pub const prefix_bytes = 54;
pub const max_bytes = prefix_bytes + Meta.max_bytes + Schema.max_bytes + Command.max_bytes;
allocator: std.mem.Allocator,
bytes: []u8,
namespace: u64,
header: Command.Header,
metadata: ?Meta.Record,
schema_bytes: []const u8,
body: []const u8,
spec: Pub.Spec,
identity: Identity,
pub const Identity = union(enum) {
    ddl: c.TableControl.Ddl,
    dml: struct { reference: c.station.TableWrite.Reference, route: c.station.TableWrite.Status.Route },
};
pub fn deinit(self: *Self) void {
    self.allocator.free(self.bytes);
    self.* = undefined;
}
fn identify(allocator: std.mem.Allocator, body: Command.Body) !Identity {
    return switch (body.request) {
        .ddl => |request| .{ .ddl = .{ .scope = body.header.scope, .principal = request.principal, .operation = request.operation, .digest = try request.digest(body.header.scope) } },
        .dml => |request| blk: {
            var scratch: [Schema.max_columns]c.fuze.Types.Values.Cell = undefined;
            const route = try request.route(allocator, body.header.scope, &scratch);
            break :blk .{ .dml = .{ .reference = try route.reference(allocator), .route = route.receiptRoute() } };
        },
    };
}
fn basisSchema(body: Command.Body) ?Schema.Schema {
    return switch (body.request) {
        .ddl => |request| if (request.action == .alter) request.action.alter.schema else null,
        .dml => |request| request.plan.schema,
    };
}
fn schemaCommitment(record: Meta.Record, bytes: []const u8) !void {
    if (!std.meta.eql(try Pub.Digest.of(c.station.TablePages.schema_format, bytes), record.schema.spec)) return error.CatalogDefinitionChanged;
}
/// Encode once, keeping small point intent preparation on a small workspace.
/// Larger command storage is temporary; the returned saved record is exact-sized.
pub fn create(allocator: std.mem.Allocator, body: Command.Body, namespace: u64) !Self {
    if (namespace == 0) return error.InvalidTableIntent;
    try body.validate();
    var small: [4096]u8 = undefined;
    var large: ?[]u8 = null;
    defer if (large) |value| allocator.free(value);
    const encoded = Command.encode(allocator, body, &small) catch |err| blk: {
        if (err != error.WriteFailed) return err;
        large = try allocator.alloc(u8, Command.max_bytes);
        break :blk try Command.encode(allocator, body, large.?);
    };
    var meta_buffer: [Meta.max_bytes]u8 = undefined;
    const metadata = if (body.basis) |record| try record.encode(&meta_buffer) else &.{};
    var schema_buffer: [Schema.max_bytes]u8 = undefined;
    const schema = if (basisSchema(body)) |value| try value.encode(&schema_buffer) else &.{};
    if (schema.len != 0) try schemaCommitment(body.basis.?, schema);
    const identity = try identify(allocator, body);
    const spec = try Pub.Digest.of(Command.format, encoded);
    const bytes = try allocator.alloc(u8, prefix_bytes + metadata.len + schema.len + encoded.len);
    errdefer allocator.free(bytes);
    var writer: std.Io.Writer = .fixed(bytes);
    try writer.writeAll("TCI1");
    try writer.writeAll(&Meta.definition());
    try writer.writeInt(u64, namespace, .little);
    try writer.writeInt(u16, @intCast(metadata.len), .little);
    try writer.writeInt(u32, @intCast(schema.len), .little);
    try writer.writeInt(u32, @intCast(encoded.len), .little);
    try writer.writeAll(metadata);
    try writer.writeAll(schema);
    try writer.writeAll(encoded);
    std.debug.assert(writer.buffered().len == bytes.len);
    return .{ .allocator = allocator, .bytes = bytes, .namespace = namespace, .header = body.header, .metadata = body.basis, .schema_bytes = bytes[prefix_bytes + metadata.len ..][0..schema.len], .body = bytes[prefix_bytes + metadata.len + schema.len ..], .spec = spec, .identity = identity };
}
/// Complete canonical bytes, mandatory current definition and original schema.
/// Restoration performs no network access, recompile, re-signing or name lookup.
pub fn restore(allocator: std.mem.Allocator, input: []const u8) !Self {
    if (input.len < prefix_bytes or input.len > max_bytes) return error.InvalidTableIntent;
    var reader: std.Io.Reader = .fixed(input);
    if (!std.mem.eql(u8, try reader.take(4), "TCI1")) return error.InvalidTableIntent;
    if (!std.mem.eql(u8, try reader.take(32), &Meta.definition())) return error.IncompatibleDefinition;
    const namespace = try reader.takeInt(u64, .little);
    const metadata_len = try reader.takeInt(u16, .little);
    const schema_len = try reader.takeInt(u32, .little);
    const body_len = try reader.takeInt(u32, .little);
    if (namespace == 0 or metadata_len > Meta.max_bytes or schema_len > Schema.max_bytes or body_len > Command.max_bytes or @as(u64, metadata_len) + schema_len + body_len != input.len - prefix_bytes) return error.InvalidTableIntent;
    const metadata = if (metadata_len == 0) null else try Meta.Record.decode(try reader.take(metadata_len));
    const schema = try reader.take(schema_len);
    const body = try reader.take(body_len);
    const header = try Command.inspect(body);
    if ((header.metadata.id == 0) != (metadata == null)) return error.InvalidTableIntent;
    const needs_schema = header.kind == .alter or header.kind == .insert or header.kind == .update or header.kind == .delete;
    if (needs_schema != (schema.len != 0)) return error.InvalidTableIntent;
    var decoded = try decode(allocator, metadata, schema, body);
    defer decoded.deinit();
    const identity = try identify(allocator, decoded.body);
    // Canonical schema and body codecs reject ambiguous saved representations.
    // Re-encoding also checks every unused/reserved byte before persistence reuse.
    var canonical = try create(allocator, decoded.body, namespace);
    errdefer canonical.deinit();
    if (!std.mem.eql(u8, canonical.bytes, input)) return error.InvalidTableIntent;
    std.debug.assert(std.meta.eql(canonical.identity, identity));
    return canonical;
}
fn decode(allocator: std.mem.Allocator, metadata: ?Meta.Record, schema_bytes: []const u8, body: []const u8) !Command.Owned {
    var schema: ?Schema.Owned = null;
    defer if (schema) |*value| value.deinit();
    if (schema_bytes.len != 0) {
        try schemaCommitment(metadata orelse return error.InvalidTableIntent, schema_bytes);
        schema = try Schema.decode(allocator, schema_bytes);
    }
    return Command.decode(allocator, body, if (metadata) |record| .{ .record = record, .schema = if (schema) |value| value.schema else null } else null);
}
pub fn command(self: *const Self, allocator: std.mem.Allocator) !Command.Owned {
    return decode(allocator, self.metadata, self.schema_bytes, self.body);
}
pub fn upload(self: *const Self) c.TableControl.Upload {
    return .{ .scope = self.header.scope, .namespace = self.namespace };
}
/// Saved signed transport steps must belong to this original complete intent.
/// This check does not authenticate a signature or assert that SQL was admitted.
pub fn matches(self: *const Self, payload: c.protocol.Value) !bool {
    if (std.mem.startsWith(u8, payload.slice(), "TCQ1")) return std.mem.eql(u8, payload.slice(), self.body);
    const control = try c.TableControl.Command.decode(payload);
    return switch (control) {
        .initialize, .policy, .dependency => false,
        .begin => |value| value.namespace == self.namespace and std.mem.eql(u8, &value.header, self.body[0..Command.header_bytes]) and std.meta.eql(value.spec, self.spec),
        .part => |value| blk: {
            if (!std.meta.eql(value.upload, self.upload()) or value.offset >= self.body.len or value.length != @min(c.TableUpload.part_bytes, self.body.len - value.offset)) break :blk false;
            break :blk std.mem.eql(u8, value.bytes[0..value.length], self.body[value.offset..][0..value.length]);
        },
        .seal, .drive, .cancel_upload, .collect_upload => |value| std.meta.eql(value, self.upload()),
        .cancel_ddl, .cleanup_ddl => |value| self.identity == .ddl and std.meta.eql(value, self.identity.ddl),
        .cancel_dml, .cleanup_dml => |value| self.identity == .dml and std.meta.eql(value.scope, self.header.scope) and std.meta.eql(value.reference, self.identity.dml.reference),
    };
}

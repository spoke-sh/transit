//! Stream/Queue values carried by the existing signed catalog connection.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const q = p.StreamQueueDeclaration;
const w = c.DirectTableProtocol;
const L = c.DirectLog;

pub const Ddl = struct {
    binding: d.Binding,
    kind: L.Kind,
    namespace: u64,
    name: []const u8,
    action: union(enum) {
        create: struct { owner: u64, schema: w.Binary, configuration: q.Configuration, limits: q.Limits },
        alter: struct { configuration: q.Configuration, limits: q.Limits },
        rename: []const u8,
        drop,
    },
    /// All decoding belongs to the supplied request arena.
    pub fn request(self: Ddl, allocator: std.mem.Allocator) !L.Request {
        return .{ .binding = self.binding, .intent = .{ .kind = self.kind, .namespace = self.namespace, .name = try .init(self.name), .action = switch (self.action) {
            .create => |value| .{ .create = .{ .owner = value.owner, .schema = (try c.fuze.TableSchema.decode(allocator, try value.schema.decode(allocator, c.fuze.TableSchema.max_bytes))).schema, .configuration = value.configuration, .limits = value.limits } },
            .alter => |value| .{ .alter = .{ .configuration = value.configuration, .limits = value.limits } },
            .rename => |value| .{ .rename = try .init(value) },
            .drop => .drop,
        } } };
    }
    pub fn validate(self: Ddl, allocator: std.mem.Allocator, connection: w.Connection) !void {
        try connection.binding(self.binding);
        const value = try self.request(allocator);
        try value.intent.validate(value.binding);
        if (!std.mem.eql(u8, &try value.intent.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
    /// Encoded slices belong to the supplied request arena.
    pub fn encode(allocator: std.mem.Allocator, value: L.Request) !Ddl {
        try value.intent.validate(value.binding);
        if (!std.mem.eql(u8, &try value.intent.digest(allocator), &value.binding.intent)) return error.DataIdentityConflict;
        return .{ .binding = value.binding, .kind = value.intent.kind, .namespace = value.intent.namespace, .name = try allocator.dupe(u8, value.intent.name.slice()), .action = switch (value.intent.action) {
            .create => |creation| blk: {
                var buffer: [c.fuze.TableSchema.max_bytes]u8 = undefined;
                break :blk .{ .create = .{ .owner = creation.owner, .schema = try w.Binary.encode(allocator, try creation.schema.encode(&buffer)), .configuration = creation.configuration, .limits = creation.limits } };
            },
            .alter => |alteration| .{ .alter = .{ .configuration = alteration.configuration, .limits = alteration.limits } },
            .rename => |name| .{ .rename = try allocator.dupe(u8, name.slice()) },
            .drop => .drop,
        } };
    }
};
pub const Operation = struct { binding: d.Binding, command: enum { inspect, execute, cancel }, steps: u16 };
pub const Definition = struct { declaration: L.Definition, schema: w.Binary };
pub const Page = struct { entries: [8]?L.Definition, next: ?u64, position: d.Position };
pub const PendingPage = struct { entries: [8]?L.Operation, next: ?u64, position: d.Position };

pub fn validateMetadata(allocator: std.mem.Allocator, connection: w.Connection, value: Definition) !void {
    const definition = value.declaration;
    try definition.validate();
    try connection.object(definition.stored.declaration.interpretation.object);
    const schema_bytes = try value.schema.decode(allocator, c.fuze.TableSchema.max_bytes);
    defer allocator.free(schema_bytes);
    var decoded = try c.fuze.TableSchema.decode(allocator, schema_bytes);
    defer decoded.deinit();
    var properties: [c.storage.LogDeclaration.max_properties_bytes]u8 = undefined;
    var candidate = try c.storage.LogDeclaration.prepare(allocator, .{ .object = definition.stored.declaration.interpretation.object, .revision = definition.stored.declaration.interpretation.revision, .schema = decoded.schema, .properties = try definition.properties.encode(&properties), .configuration = definition.stored.declaration.configuration, .limits = definition.stored.declaration.limits, .retired = definition.stored.retired });
    defer candidate.deinit();
    if (!std.meta.eql(try candidate.stored(), definition.stored)) return error.InvalidTableResponse;
}

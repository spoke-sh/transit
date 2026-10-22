//! Exact typed Table command bytes. Header inspection precedes authorized
//! immutable-schema resolution; parsing a header is never execution admission.
const std = @import("std");
const c = @import("root.zig");
const m = c.TableCatalogRecords;
const Meta = c.TableMetadata;
const s = c.station;
pub const header_bytes = 149;
pub const max_bytes = header_bytes + c.fuze.TableDmlCodec.max_bytes + c.fuze.TableSchema.max_bytes + 512;
pub const format: u32 = 0x54435101;
pub const Kind = enum(u8) { create = 1, alter = 2, rename = 3, drop = 4, insert = 5, update = 6, delete = 7 };
pub const Header = struct {
    scope: m.Scope,
    owner: u64,
    principal: u64,
    operation: u64,
    object: u64,
    namespace: u64 = 1,
    metadata: s.TablePages.Reference,
    kind: Kind,
    pub fn right(self: Header) m.Right {
        return switch (self.kind) {
            .create => .create,
            .alter, .rename => .alter,
            .drop => .drop,
            .insert => .insert,
            .update => .update,
            .delete => .delete,
        };
    }
    pub fn validate(self: Header) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.owner);
        try c.Model.nativeId(self.namespace);
        if (self.principal > c.protocol.max_counter or self.operation == 0) return error.InvalidCatalogIdentity;
        if (self.object == 0 and self.kind != .drop) return error.InvalidCatalogIdentity;
        if (self.kind == .create or self.object == 0) {
            if (!std.meta.eql(self.metadata, m.empty_reference)) return error.InvalidCatalogDefinition;
        } else try m.metadataReference(self.metadata);
    }
    pub fn encode(self: Header) ![header_bytes]u8 {
        try self.validate();
        var bytes: [header_bytes]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("TCQ1");
        try out.writeAll(&Meta.definition());
        try Meta.scopeWrite(&out, self.scope);
        inline for (.{ "owner", "principal", "operation", "object", "namespace" }) |name| try out.writeInt(u64, @field(self, name), .little);
        try out.writeInt(u64, self.metadata.id, .little);
        try out.writeInt(u32, self.metadata.spec.format, .little);
        try out.writeInt(u32, self.metadata.spec.length, .little);
        try out.writeAll(&self.metadata.spec.digest);
        try out.writeByte(@backingInt(self.kind));
        std.debug.assert(out.buffered().len == header_bytes);
        return bytes;
    }
};
/// No schema-dependent bytes are interpreted here. The enclosing owner verifies
/// native origin/current policy before fetching the exact accepted metadata.
pub fn inspect(bytes: []const u8) !Header {
    if (bytes.len < header_bytes or bytes.len > max_bytes) return error.InvalidTableCommand;
    var reader: std.Io.Reader = .fixed(bytes[0..header_bytes]);
    if (!std.mem.eql(u8, try reader.take(4), "TCQ1")) return error.InvalidTableCommand;
    if (!std.mem.eql(u8, try reader.take(32), &Meta.definition())) return error.IncompatibleDefinition;
    const header: Header = .{
        .scope = .{ .realm = try reader.takeInt(u64, .little), .resource = try reader.takeInt(u64, .little), .catalog = try reader.takeInt(u64, .little) },
        .owner = try reader.takeInt(u64, .little),
        .principal = try reader.takeInt(u64, .little),
        .operation = try reader.takeInt(u64, .little),
        .object = try reader.takeInt(u64, .little),
        .namespace = try reader.takeInt(u64, .little),
        .metadata = .{ .id = try reader.takeInt(u64, .little), .spec = .{ .format = try reader.takeInt(u32, .little), .length = try reader.takeInt(u32, .little), .digest = (try reader.take(32))[0..32].* } },
        .kind = std.enums.fromInt(Kind, try reader.takeByte()) orelse return error.InvalidTableCommand,
    };
    try header.validate();
    return header;
}

pub const Request = union(enum) { ddl: c.TableDdlRequest, dml: c.TableDmlRequest };
pub const Basis = struct { record: Meta.Record, schema: ?c.fuze.TableSchema.Schema = null };
pub const ResolvedBasis = struct {
    record: Meta.Record,
    schema: ?c.fuze.TableSchema.Owned = null,
    pub fn borrow(self: *const ResolvedBasis) Basis {
        return .{ .record = self.record, .schema = if (self.schema) |value| value.schema else null };
    }
    pub fn deinit(self: *ResolvedBasis) void {
        if (self.schema) |*value| value.deinit();
        self.* = undefined;
    }
};
pub const Body = struct {
    header: Header,
    request: Request,
    /// Immutable basis supplied by an authorized resolver; never a newer name.
    basis: ?Meta.Record = null,
    pub fn validate(self: Body) !void {
        try self.header.validate();
        const h = self.header;
        if (h.metadata.id == 0) {
            if (self.basis != null) return error.InvalidTableCommand;
        } else {
            const basis = self.basis orelse return error.CatalogDefinitionMissing;
            try checkBasis(h, basis);
        }
        switch (self.request) {
            .ddl => |request| {
                if (h.kind != ddlKind(request) or h.principal != request.principal or h.operation != request.operation or h.object != request.object or h.namespace != request.namespace or h.metadata.id != request.expected_revision) return error.InvalidTableCommand;
                _ = try request.digest(h.scope);
                if (self.basis) |basis| {
                    if (!request.name.eql(&basis.name)) return error.CatalogDefinitionChanged;
                    if (request.action == .alter and !std.mem.eql(u8, &try request.action.alter.schema.fingerprint(), &basis.schema_fingerprint)) return error.TableSchemaChanged;
                }
            },
            .dml => |request| {
                if (h.kind != dmlKind(request) or h.principal != request.principal or h.operation != request.operation or h.object != request.plan.schema.object or !std.meta.eql(h.metadata, request.metadata)) return error.InvalidTableCommand;
                const basis = self.basis orelse return error.CatalogDefinitionMissing;
                if (!std.mem.eql(u8, basis.name.slice(), request.plan.name)) return error.CatalogDefinitionChanged;
                if (!std.mem.eql(u8, &try request.plan.schema.fingerprint(), &basis.schema_fingerprint)) return error.TableSchemaChanged;
                try request.plan.validate();
            },
        }
    }
};
fn checkBasis(header: Header, record: Meta.Record) !void {
    try record.validate();
    if (!std.meta.eql(header.scope, record.scope) or header.object != record.object or header.namespace != record.namespace or header.metadata.id != record.revision or !std.meta.eql(header.metadata.spec, try record.spec())) return error.CatalogDefinitionChanged;
}
fn ddlKind(request: c.TableDdlRequest) Kind {
    return switch (request.action) {
        .create => .create,
        .alter => .alter,
        .rename => .rename,
        .drop => .drop,
    };
}
fn dmlKind(request: c.TableDmlRequest) Kind {
    return switch (request.plan.action) {
        .insert => .insert,
        .update => .update,
        .delete => .delete,
    };
}
pub fn fromDdl(scope: m.Scope, owner: u64, request: c.TableDdlRequest, basis: ?Meta.Record) !Body {
    const body: Body = .{ .header = .{ .scope = scope, .owner = owner, .principal = request.principal, .operation = request.operation, .object = request.object, .namespace = request.namespace, .metadata = if (basis) |record| .{ .id = record.revision, .spec = try record.spec() } else m.empty_reference, .kind = ddlKind(request) }, .request = .{ .ddl = request }, .basis = basis };
    try body.validate();
    return body;
}
pub fn fromDml(scope: m.Scope, owner: u64, request: c.TableDmlRequest, basis: Meta.Record) !Body {
    const body: Body = .{ .header = .{ .scope = scope, .owner = owner, .principal = request.principal, .operation = request.operation, .object = request.plan.schema.object, .namespace = basis.namespace, .metadata = request.metadata, .kind = dmlKind(request) }, .request = .{ .dml = request }, .basis = basis };
    try body.validate();
    return body;
}
fn nameWrite(writer: *std.Io.Writer, name: []const u8) !void {
    _ = try Meta.Name.init(name);
    try writer.writeByte(@intCast(name.len));
    try writer.writeAll(name);
}
fn cellWrite(writer: *std.Io.Writer, cell: c.fuze.Types.Values.Cell, field: c.fuze.Types.Field) !void {
    var scratch: [256]u8 = undefined;
    var count: std.Io.Writer.Discarding = .init(&scratch);
    try c.fuze.Types.Codec.writeBound(cell, field, &count.writer);
    if (count.fullCount() > c.fuze.Types.Codec.max_bytes) return error.ValueBudgetExceeded;
    try writer.writeInt(u32, @intCast(count.fullCount()), .little);
    try c.fuze.Types.Codec.writeBound(cell, field, writer);
}
fn typeWrite(writer: *std.Io.Writer, data_type: c.fuze.Types.Type) !void {
    var bytes: [c.fuze.Types.max_encoding_bytes]u8 = undefined;
    const encoded = try data_type.encode(&bytes);
    try writer.writeInt(u16, @intCast(encoded.len), .little);
    try writer.writeAll(encoded);
}
fn changeWrite(writer: *std.Io.Writer, schema: c.fuze.TableSchema.Schema, change: c.fuze.TableEvolution.Change) !void {
    switch (change) {
        .add => |column| {
            try writer.writeByte(1);
            try nameWrite(writer, column.name);
            try typeWrite(writer, column.type);
            try writer.writeByte(@intFromBool(column.nullable));
            try writer.writeInt(u32, column.max_characters orelse 0, .little);
            try writer.writeByte(@intFromBool(column.default != null));
            if (column.default) |cell| try cellWrite(writer, cell, .{ .name = column.name, .type = column.type, .nullable = column.nullable });
        },
        .drop => |column| {
            try writer.writeByte(2);
            try writer.writeInt(u64, column, .little);
        },
        .rename => |column| {
            try writer.writeByte(3);
            try writer.writeInt(u64, column.column, .little);
            try nameWrite(writer, column.name);
        },
        .default => |column| {
            try writer.writeByte(4);
            try writer.writeInt(u64, column.column, .little);
            try writer.writeByte(@intFromBool(column.value != null));
            if (column.value) |cell| try cellWrite(writer, cell, schema.columns[try schema.index(column.column)].field());
        },
        .nullable => |column| {
            try writer.writeByte(5);
            try writer.writeInt(u64, column.column, .little);
            try writer.writeByte(@intFromBool(column.value));
        },
        .type => |column| {
            try writer.writeByte(6);
            try writer.writeInt(u64, column.column, .little);
            try typeWrite(writer, column.type);
            try writer.writeInt(u32, column.max_characters orelse 0, .little);
        },
        .physical => |column| {
            try writer.writeByte(7);
            try writer.writeInt(u64, column.column, .little);
            try writer.writeByte(@backingInt(column.encoding));
            try writer.writeByte(@backingInt(column.collation));
        },
    }
}
pub fn encode(allocator: std.mem.Allocator, body: Body, output: []u8) ![]const u8 {
    try body.validate();
    if (output.len < header_bytes) return error.WriteFailed;
    var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
    try writer.writeAll(&try body.header.encode());
    switch (body.request) {
        .dml => |request| {
            // The header commitment already binds the exact accepted schema/name.
            // Embed only the shared action/predicate payload, never another envelope.
            const bytes = try c.fuze.TableDmlCodec.encodePayload(allocator, request.plan, output[header_bytes..@min(output.len, max_bytes)]);
            return output[0 .. header_bytes + bytes.len];
        },
        .ddl => |request| switch (request.action) {
            .create => |creation| {
                try nameWrite(&writer, request.name.slice());
                try writer.writeByte(@intFromBool(creation.if_not_exists));
                var schema_bytes: [c.fuze.TableSchema.max_bytes]u8 = undefined;
                const encoded = try creation.schema.encode(&schema_bytes);
                try writer.writeInt(u32, @intCast(encoded.len), .little);
                try writer.writeAll(encoded);
            },
            .alter => |alter| try changeWrite(&writer, alter.schema, alter.change),
            .rename => |name| try nameWrite(&writer, name.slice()),
            .drop => |drop| {
                try writer.writeByte(@intFromBool(drop.if_exists));
                if (request.object == 0) try nameWrite(&writer, request.name.slice());
            },
        },
    }
    return writer.buffered();
}

pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    dml: ?c.fuze.TableDml.Owned = null,
    body: Body,
    pub fn deinit(self: *Owned) void {
        if (self.dml) |*value| value.deinit();
        self.arena.deinit();
        self.* = undefined;
    }
};
fn boolean(reader: *std.Io.Reader) !bool {
    return switch (try reader.takeByte()) {
        0 => false,
        1 => true,
        else => error.InvalidTableCommand,
    };
}
fn nameRead(reader: *std.Io.Reader) !Meta.Name {
    return Meta.Name.init(try reader.take(try reader.takeByte()));
}
fn typeRead(arena: *std.heap.ArenaAllocator, reader: *std.Io.Reader) !c.fuze.Types.Type {
    const owned = try c.fuze.Types.decode(arena.allocator(), try reader.take(try reader.takeInt(u16, .little)));
    return owned.type;
}
fn cellRead(arena: *std.heap.ArenaAllocator, reader: *std.Io.Reader, field: c.fuze.Types.Field) !c.fuze.Types.Values.Cell {
    const size = try reader.takeInt(u32, .little);
    if (size > c.fuze.Types.Codec.max_bytes) return error.ValueBudgetExceeded;
    return c.fuze.Types.Codec.decodeBound(arena, field, try reader.take(size));
}
fn changeRead(arena: *std.heap.ArenaAllocator, reader: *std.Io.Reader, schema: c.fuze.TableSchema.Schema) !c.fuze.TableEvolution.Change {
    return switch (try reader.takeByte()) {
        1 => blk: {
            const name = try nameRead(reader);
            const owned_name = try arena.allocator().dupe(u8, name.slice());
            const data_type = try typeRead(arena, reader);
            const nullable = try boolean(reader);
            const length = try reader.takeInt(u32, .little);
            const value = if (try boolean(reader)) try cellRead(arena, reader, .{ .name = owned_name, .type = data_type, .nullable = nullable }) else null;
            break :blk .{ .add = .{ .name = owned_name, .type = data_type, .nullable = nullable, .max_characters = if (length == 0) null else length, .default = value } };
        },
        2 => .{ .drop = try reader.takeInt(u64, .little) },
        3 => blk: {
            const id = try reader.takeInt(u64, .little);
            const name = try nameRead(reader);
            break :blk .{ .rename = .{ .column = id, .name = try arena.allocator().dupe(u8, name.slice()) } };
        },
        4 => blk: {
            const id = try reader.takeInt(u64, .little);
            const column = schema.columns[try schema.index(id)];
            break :blk .{ .default = .{ .column = id, .value = if (try boolean(reader)) try cellRead(arena, reader, column.field()) else null } };
        },
        5 => .{ .nullable = .{ .column = try reader.takeInt(u64, .little), .value = try boolean(reader) } },
        6 => blk: {
            const id = try reader.takeInt(u64, .little);
            const data_type = try typeRead(arena, reader);
            const length = try reader.takeInt(u32, .little);
            break :blk .{ .type = .{ .column = id, .type = data_type, .max_characters = if (length == 0) null else length } };
        },
        7 => blk: {
            const id = try reader.takeInt(u64, .little);
            const encoding = std.enums.fromInt(c.fuze.TableSchema.Encoding, try reader.takeByte()) orelse return error.InvalidTableCommand;
            const collation = std.enums.fromInt(c.fuze.TableSchema.Collation, try reader.takeByte()) orelse return error.InvalidTableCommand;
            break :blk .{ .physical = .{ .column = id, .encoding = encoding, .collation = collation } };
        },
        else => error.InvalidTableCommand,
    };
}
/// Basis must come from authorized accepted metadata, including its historical
/// receipt proof. DDL slices live in the parent arena; DML retains its existing
/// independently owned schema/value allocation groups and releases them once.
pub fn decode(allocator: std.mem.Allocator, bytes: []const u8, basis: ?Basis) !Owned {
    const h = try inspect(bytes);
    if (h.metadata.id == 0) {
        if (basis != null) return error.InvalidTableCommand;
    } else try checkBasis(h, (basis orelse return error.CatalogDefinitionMissing).record);
    const needs_schema = h.kind == .alter or h.kind == .insert or h.kind == .update or h.kind == .delete;
    const original: ?c.fuze.TableSchema.Schema = if (needs_schema) blk: {
        const value = basis.?.schema orelse return error.TableSchemaRequired;
        if (value.object != h.object or !std.mem.eql(u8, &try value.fingerprint(), &basis.?.record.schema_fingerprint)) return error.TableSchemaChanged;
        break :blk value;
    } else null;
    var arena: std.heap.ArenaAllocator = .init(allocator);
    errdefer arena.deinit();
    var dml_owner: ?c.fuze.TableDml.Owned = null;
    errdefer if (dml_owner) |*value| value.deinit();
    const a = arena.allocator();
    var reader: std.Io.Reader = .fixed(bytes[header_bytes..]);
    const request: Request = if (h.kind == .insert or h.kind == .update or h.kind == .delete) blk: {
        dml_owner = try c.fuze.TableDmlCodec.decodePayload(allocator, original.?, basis.?.record.name.slice(), bytes[header_bytes..]);
        break :blk .{ .dml = .{ .principal = h.principal, .operation = h.operation, .metadata = h.metadata, .plan = dml_owner.?.plan } };
    } else blk: {
        var ddl: c.TableDdlRequest = .{ .principal = h.principal, .operation = h.operation, .object = h.object, .namespace = h.namespace, .expected_revision = h.metadata.id, .name = if (basis) |value| value.record.name else undefined, .action = undefined };
        ddl.action = switch (h.kind) {
            .create => creation: {
                ddl.name = try nameRead(&reader);
                const if_not_exists = try boolean(&reader);
                const size = try reader.takeInt(u32, .little);
                if (size > c.fuze.TableSchema.max_bytes) return error.TableSchemaTooLarge;
                const owned = try c.fuze.TableSchema.decode(a, try reader.take(size));
                break :creation .{ .create = .{ .schema = owned.schema, .if_not_exists = if_not_exists } };
            },
            .alter => alteration: {
                const owned = try original.?.clone(a);
                break :alteration .{ .alter = .{ .schema = owned.schema, .change = try changeRead(&arena, &reader, owned.schema) } };
            },
            .rename => .{ .rename = try nameRead(&reader) },
            .drop => dropping: {
                const if_exists = try boolean(&reader);
                if (h.object == 0) ddl.name = try nameRead(&reader);
                break :dropping .{ .drop = .{ .if_exists = if_exists } };
            },
            else => unreachable,
        };
        if (reader.bufferedLen() != 0) return error.InvalidTableCommand;
        break :blk .{ .ddl = ddl };
    };
    const body: Body = .{ .header = h, .request = request, .basis = if (basis) |value| value.record else null };
    try body.validate();
    return .{ .arena = arena, .dml = dml_owner, .body = body };
}

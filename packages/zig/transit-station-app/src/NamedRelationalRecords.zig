//! Canonical application-owned records. Every record carries the current native
//! definition; keys address exact names and revisions, never truncated hashes.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const p = root.protocol;
const Ref = root.station.PublicationReference;
pub const Scope = struct {
    realm: u64,
    resource: u64,
    owner: u64,
    namespace: u64,
    pub fn validate(self: Scope) !void {
        inline for (@typeInfo(Scope).@"struct".field_names) |name| if (@field(self, name) == 0) return error.InvalidNamedQuery;
        if (self.realm > p.max_counter or self.resource > p.max_counter or self.owner > p.max_counter) return error.InvalidNamedQuery;
    }
};
pub const Name = struct {
    len: u8,
    bytes: [21]u8,
    pub fn init(text: []const u8) !Name {
        if (text.len == 0 or text.len > 21) return error.InvalidNamedQuery;
        var result: Name = .{ .len = @intCast(text.len), .bytes = @splat(0) };
        @memcpy(result.bytes[0..text.len], text);
        try result.validate();
        return result;
    }
    pub fn validate(self: Name) !void {
        if (self.len == 0 or self.len > self.bytes.len) return error.InvalidNamedQuery;
        for (self.bytes[0..self.len], 0..) |byte, i| if (byte != '_' and !std.ascii.isAlphabetic(byte) and !(i != 0 and std.ascii.isDigit(byte))) return error.InvalidNamedQuery;
        for (self.bytes[self.len..]) |byte| if (byte != 0) return error.InvalidNamedQuery;
    }
    pub fn slice(self: *const Name) []const u8 {
        return self.bytes[0..self.len];
    }
};
pub const Identity = struct {
    scope: Scope,
    name: Name,
    object: u64,
    revision: u64,
    pub fn validate(self: Identity) !void {
        try self.scope.validate();
        try self.name.validate();
        if (self.object == 0 or self.revision == 0) return error.InvalidNamedQuery;
    }
};
pub const Reference = struct {
    definition: p.Growth.Definition,
    identity: Identity,
    digest: [32]u8,
    pub fn validate(self: Reference) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.identity.validate();
    }
    pub fn interpretation(self: Reference) !p.DataLifecycle.Definition {
        try self.validate();
        const scope = self.identity.scope;
        return .{ .object = .{ .scope = .{ .realm = scope.realm, .resource = scope.resource, .catalog = scope.namespace }, .branch = 1, .object = self.identity.object }, .revision = self.identity.revision, .digest = self.digest };
    }
    pub fn encode(self: Reference) !p.Value {
        try self.validate();
        return encodeRecord("NRR1", .{ .identity = self.identity, .digest = self.digest });
    }
    pub fn decode(value: p.Value) !Reference {
        const body = try decodeRecord(struct { identity: Identity, digest: [32]u8 }, "NRR1", value);
        const result: Reference = .{ .definition = p.Growth.current_definition, .identity = body.identity, .digest = body.digest };
        try result.validate();
        return result;
    }
};
pub const Configuration = struct {
    scope: Scope,
    administrator: u64,
    records: u64,
    bytes: u64,
    pub fn validate(self: Configuration) !void {
        try self.scope.validate();
        if (self.administrator > p.max_counter or self.records < 2 or self.bytes < 144) return error.InvalidNamedQuery;
    }
};
pub const Budget = struct { records: u64, bytes: u64 };
/// Logical identity can be frozen before publication. The native version is a
/// retained physical locator in Definition, not part of the declared meaning.
pub const Logical = struct {
    identity: Identity,
    peer: u64,
    request: Ref,
    fingerprint: [32]u8,
    lifetime: q.fuze.Relational.Lifetime,
    pub fn validate(self: Logical) !void {
        try self.identity.validate();
        try q.RelationalBundle.checkReference(self.request);
        if (self.peer == 0 or self.lifetime == .interactive) return error.InvalidNamedQuery;
    }
    pub fn reference(self: Logical) !Reference {
        try self.validate();
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.application.named-relational.v1\x00");
        hash.update((try encodeRecord("NRL1", self)).slice());
        return .{ .definition = p.Growth.current_definition, .identity = self.identity, .digest = hash.finalResult() };
    }
};
pub const Definition = struct {
    identity: Identity,
    peer: u64,
    request: Ref,
    version: p.Growth.ReadVersionId,
    fingerprint: [32]u8,
    lifetime: q.fuze.Relational.Lifetime,
    pub fn logical(self: Definition) Logical {
        return .{ .identity = self.identity, .peer = self.peer, .request = self.request, .fingerprint = self.fingerprint, .lifetime = self.lifetime };
    }
    pub fn validate(self: Definition) !void {
        try self.identity.validate();
        try q.RelationalBundle.checkReference(self.request);
        try p.Growth.validateVersionId(self.version);
        if (self.peer == 0 or self.version.pid != self.identity.scope.owner or self.lifetime == .interactive) return error.InvalidNamedQuery;
    }
    pub fn reference(self: Definition) !Reference {
        try self.validate();
        return self.logical().reference();
    }
};
pub const Authorization = struct { identity: Identity, digest: [32]u8, policy: q.RelationalRecords.Policy };
pub const Draft = struct { name: Name, object: u64, expected: u64, peer: u64, request: Ref };
pub const Proposal = struct {
    name: Name,
    object: u64,
    expected: u64,
    peer: u64,
    request: Ref,
    expected_digest: [32]u8,
    /// Pure preparation binds the complete bundle publication and resulting
    /// logical reference before any dependency registration or native send.
    pub fn prepare(scope: Scope, draft: Draft, bundle: q.RelationalBundle) !Proposal {
        try scope.validate();
        if (!std.meta.eql(draft.request, try bundle.reference(draft.request.resource, draft.request.namespace))) return error.NamedQueryChanged;
        for (bundle.sources) |source| if (source.scope.realm != scope.realm) return error.RelationalSourceChanged;
        const logical: Logical = .{ .identity = .{ .scope = scope, .name = draft.name, .object = draft.object, .revision = std.math.add(u64, draft.expected, 1) catch return error.InvalidNamedQuery }, .peer = draft.peer, .request = draft.request, .fingerprint = try bundle.fingerprint(), .lifetime = bundle.plan.lifetime };
        return .{ .name = draft.name, .object = draft.object, .expected = draft.expected, .peer = draft.peer, .request = draft.request, .expected_digest = (try logical.reference()).digest };
    }
    pub fn reference(self: Proposal, scope: Scope) !Reference {
        const result: Reference = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = scope, .name = self.name, .object = self.object, .revision = std.math.add(u64, self.expected, 1) catch return error.InvalidNamedQuery }, .digest = self.expected_digest };
        try result.validate();
        return result;
    }
};
pub const Permission = struct { reference: Reference, expected: u64, principal: u64, allow: bool };
/// Casts from the configured external administrator. This command does not
/// include activation; activation is a separate authenticated publishing-peer call.
pub const Control = union(enum) {
    initialize,
    publish: Proposal,
    authorize: Permission,
    retire: Reference,
    pub fn encode(self: Control) !p.Value {
        return switch (self) {
            .initialize => encodeRecord("NRI1", .{}),
            .publish => |value| blk: {
                try value.name.validate();
                try q.RelationalBundle.checkReference(value.request);
                if (value.object == 0 or value.peer == 0 or value.expected == std.math.maxInt(u64)) return error.InvalidNamedQuery;
                break :blk encodeRecord("NRU1", value);
            },
            .authorize => |value| blk: {
                try value.reference.validate();
                if (value.principal == 0 or value.expected == std.math.maxInt(u64)) return error.InvalidNamedQuery;
                break :blk encodeRecord("NRG1", .{ .identity = value.reference.identity, .digest = value.reference.digest, .expected = value.expected, .principal = value.principal, .allow = value.allow });
            },
            .retire => |value| blk: {
                try value.validate();
                break :blk encodeRecord("NRT1", .{ .identity = value.identity, .digest = value.digest });
            },
        };
    }
    pub fn decode(value: p.Value) !Control {
        try value.validate();
        if (value.len < 4) return error.InvalidNamedQuery;
        const magic = value.data[0..4];
        const result: Control = if (std.mem.eql(u8, magic, "NRI1")) blk: {
            _ = try decodeRecord(struct {}, "NRI1", value);
            break :blk .initialize;
        } else if (std.mem.eql(u8, magic, "NRU1")) .{ .publish = try decodeRecord(Proposal, "NRU1", value) } else if (std.mem.eql(u8, magic, "NRG1")) blk: {
            const body = try decodeRecord(struct { identity: Identity, digest: [32]u8, expected: u64, principal: u64, allow: bool }, "NRG1", value);
            break :blk .{ .authorize = .{ .reference = .{ .definition = p.Growth.current_definition, .identity = body.identity, .digest = body.digest }, .expected = body.expected, .principal = body.principal, .allow = body.allow } };
        } else if (std.mem.eql(u8, magic, "NRT1")) blk: {
            const body = try decodeRecord(struct { identity: Identity, digest: [32]u8 }, "NRT1", value);
            break :blk .{ .retire = .{ .definition = p.Growth.current_definition, .identity = body.identity, .digest = body.digest } };
        } else return error.InvalidNamedQuery;
        if (!(try result.encode()).eql(value)) return error.InvalidNamedQuery;
        return result;
    }
};
pub const Activation = struct {
    reference: Reference,
    policy_revision: u64,
    pub fn encode(self: Activation) !p.Value {
        try self.reference.validate();
        if (self.policy_revision == 0) return error.InvalidNamedQuery;
        return encodeRecord("NRA1", .{ .identity = self.reference.identity, .digest = self.reference.digest, .policy_revision = self.policy_revision });
    }
    pub fn decode(value: p.Value) !Activation {
        const body = try decodeRecord(struct { identity: Identity, digest: [32]u8, policy_revision: u64 }, "NRA1", value);
        const result: Activation = .{ .reference = .{ .definition = p.Growth.current_definition, .identity = body.identity, .digest = body.digest }, .policy_revision = body.policy_revision };
        _ = try result.encode();
        return result;
    }
};
pub fn key(tag: u8, namespace: u64, first: ?u64, second: ?u64) p.Value {
    var bytes: [27]u8 = undefined;
    bytes[0..2].* = "\x00N".*;
    bytes[2] = tag;
    std.mem.writeInt(u64, bytes[3..11], namespace, .big);
    var len: usize = 11;
    if (first) |value| {
        std.mem.writeInt(u64, bytes[11..19], value, .big);
        len = 19;
    }
    if (second) |value| {
        std.debug.assert(first != null);
        std.mem.writeInt(u64, bytes[19..27], value, .big);
        len = 27;
    }
    return p.Value.init(bytes[0..len]) catch unreachable;
}
pub fn nameKey(namespace: u64, name: Name) !p.Value {
    try name.validate();
    var result = key('n', namespace, null, null);
    @memcpy(result.data[result.len..][0..name.len], name.slice());
    result.len += name.len;
    return result;
}
pub fn definitionKey(identity: Identity) p.Value {
    return key('d', identity.scope.namespace, identity.object, identity.revision);
}
/// The underlying query policy is per peer across the coordinator resource, so
/// its immutable archive has that same scope, independent of any namespace.
pub fn authorizationKey(peer: u64, revision: u64) p.Value {
    return key('a', peer, revision, null);
}
fn write(writer: *std.Io.Writer, value: anytype) !void {
    const T = @TypeOf(value);
    if (T == Ref) return writer.writeAll((try value.encode()).slice());
    switch (@typeInfo(T)) {
        .int => try writer.writeInt(T, value, .little),
        .bool => try writer.writeByte(@intFromBool(value)),
        .@"enum" => try writer.writeByte(@intCast(@backingInt(value))),
        .array => try writer.writeAll(&value),
        .@"struct" => |info| inline for (info.field_names) |name| try write(writer, @field(value, name)),
        else => @compileError("unsupported named relational record field"),
    }
}
fn read(comptime T: type, reader: *std.Io.Reader) !T {
    if (T == Ref) return Ref.decode(try p.Value.init(try reader.take(Ref.encoded_bytes)));
    return switch (@typeInfo(T)) {
        .int => try reader.takeInt(T, .little),
        .bool => switch (try reader.takeByte()) {
            0 => false,
            1 => true,
            else => error.InvalidNamedQuery,
        },
        .@"enum" => std.enums.fromInt(T, try reader.takeByte()) orelse error.InvalidNamedQuery,
        .array => |array| (try reader.takeArray(array.len)).*,
        .@"struct" => |info| blk: {
            var result: T = undefined;
            inline for (info.field_names, info.field_types) |name, F| @field(result, name) = try read(F, reader);
            break :blk result;
        },
        else => @compileError("unsupported named relational record field"),
    };
}
pub fn encodeRecord(comptime magic: *const [4]u8, value: anytype) !p.Value {
    var bytes: [p.Value.max_bytes]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&bytes);
    try writer.writeAll(magic);
    try writer.writeAll(&q.catalog.TableMetadata.definition());
    try write(&writer, value);
    return p.Value.init(writer.buffered());
}
pub fn decodeRecord(comptime T: type, comptime magic: *const [4]u8, value: p.Value) !T {
    try value.validate();
    var reader: std.Io.Reader = .fixed(value.slice());
    if (!std.mem.eql(u8, try reader.take(4), magic)) return error.InvalidNamedQuery;
    if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
    const result = try read(T, &reader);
    if (reader.bufferedLen() != 0 or !(try encodeRecord(magic, result)).eql(value)) return error.InvalidNamedQuery;
    return result;
}

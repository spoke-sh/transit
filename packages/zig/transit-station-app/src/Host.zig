//! Bounded administrative transport values. Hosts never receive signing keys.
const std = @import("std");
const root = @import("root.zig");
const n = root.Native;
const client = root.station.client;
pub const max_body_bytes = 512 * 1024; // JSON escaping of a 64 KiB UTF-8 program.
pub const Config = struct {
    scope: n.Scope,
    operators: [16]?u64 = @splat(null),
    pub fn validate(self: Config) !void {
        try self.scope.validate();
        var ended = false;
        var count: usize = 0;
        for (self.operators, 0..) |slot, index| {
            const principal = slot orelse {
                ended = true;
                continue;
            };
            if (ended or principal == 0 or principal > root.protocol.max_counter) return error.InvalidApplicationOperators;
            for (self.operators[0..index]) |before| if (before == principal) return error.InvalidApplicationOperators;
            count += 1;
        }
        if (count == 0) return error.InvalidApplicationOperators;
    }
    pub fn admit(self: Config, principal: u64) !void {
        for (self.operators) |slot| if (slot == principal) return;
        return error.ApplicationOperatorDenied;
    }
};
pub const Request = union(enum) {
    info: void,
    compile: struct {
        source: []const u8,
        pub const json_schema_fields = .{ .source = .{ .type = "string", .maxLength = root.Model.max_program_bytes } };
    },
    format: root.Model.Definition,
    next_upload: root.Upload.Input,
    prepare: struct { principal: u64, sequence: root.Model.Wide, command: root.Request.Command },
    submit: n.Signed,
    prepare_read: struct { principal: u64, selection: n.Selection },
    read: n.SignedRead,
};
pub const Compiled = struct {
    definition: root.Model.Definition,
    canonical: []const u8,
    spec: root.station.Publication.Spec,
    pub const json_schema_fields = .{ .canonical = .{ .type = "string", .maxLength = root.Model.max_program_bytes } };
};
pub const Response = union(enum) {
    info: struct { scope: n.Scope, program_bytes: u32 = root.Model.max_program_bytes, part_bytes: u16 = root.station.PublicationParts.part_bytes },
    compiled: Compiled,
    builtin: Compiled,
    published: struct { head: root.Publication.Head, compiled: Compiled },
    prepared: n.Prepared,
    admitted: client.Receipt,
    next_upload: ?root.Request.Command,
    prepared_read: n.PreparedRead,
    observation: n.Observation,
};
pub const Owned = struct {
    arena: std.heap.ArenaAllocator,
    value: Response,
    pub fn deinit(self: *Owned) void {
        self.arena.deinit();
        self.* = undefined;
    }
};
/// All compiler errors are finite diagnostics; no partial model or SQL escapes.
pub fn compile(allocator: std.mem.Allocator, source: []const u8) !Owned {
    var parsed = root.Sql.parse(allocator, source) catch |err| return switch (err) {
        error.OutOfMemory => err,
        else => error.InvalidApplicationProgram,
    };
    errdefer parsed.deinit();
    var buffer: [root.Model.max_program_bytes]u8 = undefined;
    const bytes = root.Api.canonical(parsed.definition, &buffer) catch return error.InvalidApplicationProgram;
    const canonical = try parsed.arena.allocator().dupe(u8, bytes);
    return .{ .arena = parsed.arena, .value = .{ .compiled = .{ .definition = parsed.definition, .canonical = canonical, .spec = try root.station.Publication.Digest.of(root.Publication.format, canonical) } } };
}
/// `wire` is used only by signed read/submit. Compiler and signature preparation
/// cannot admit native commands. Deployment admission is additional to native
/// signature, current grants and the durable owner's current publication policy.
pub fn run(allocator: std.mem.Allocator, wire: *client.Client, config: Config, request: Request) !Owned {
    try config.validate();
    switch (request) {
        .compile => |value| return compile(allocator, value.source),
        .format => |definition| {
            var buffer: [root.Model.max_program_bytes]u8 = undefined;
            const source = root.Api.canonical(definition, &buffer) catch return error.InvalidApplicationProgram;
            return compile(allocator, source);
        },
        else => {},
    }
    const result: Response = switch (request) {
        .next_upload => |value| .{ .next_upload = try root.Upload.next(allocator, value) },
        .info => .{ .info = .{ .scope = config.scope } },
        .prepare => |value| blk: {
            try config.admit(value.principal);
            break :blk .{ .prepared = try n.prepare(config.scope, value.principal, value.sequence, value.command) };
        },
        .submit => |value| blk: {
            try config.admit(value.prepared.principal);
            break :blk .{ .admitted = try n.submit(wire, config.scope, value) };
        },
        .prepare_read => |value| blk: {
            try config.admit(value.principal);
            break :blk .{ .prepared_read = try n.prepareRead(config.scope, value.principal, value.selection) };
        },
        .read => |value| blk: {
            try config.admit(value.prepared.principal);
            break :blk .{ .observation = try n.read(wire, config.scope, value) };
        },
        .compile, .format => unreachable,
    };
    return .{ .arena = .init(allocator), .value = result };
}

/// Materialize one active immutable definition using a currently authorized
/// public reader. Each bounded chunk group and final head read rechecks access.
/// No compiled result or read authority is cached across acquisitions.
pub fn published(allocator: std.mem.Allocator, source: client.ResourceReader, scope: n.Scope) !Owned {
    try scope.validate();
    if (source.realm != scope.realm) return error.ApplicationScopeChanged;
    const selected = [_]root.protocol.Value{ root.Records.key(scope.application, 'c', 0, 0), root.Records.key(scope.application, 'h', 0, 0) };
    const initial = try source.readBatch(scope.resource, null, &selected);
    const config = try root.Records.decode(root.Publication.Configuration, 'c', (try initial.read(selected[0])) orelse return error.ApplicationNotInitialized);
    if (config.application != scope.application or config.realm != scope.realm or config.namespace.value != scope.namespace.value or initial.resource.writer != scope.pid) return error.ApplicationScopeChanged;
    const owner: root.Publication = .{ .configuration = config };
    const head = (try owner.head(&initial)) orelse return error.ApplicationNotPublished;
    if (head.spec.format != root.Publication.format or head.spec.length > root.Model.max_program_bytes) return error.InvalidApplicationProgram;
    var buffer: [root.Model.max_program_bytes]u8 = undefined;
    const body = try owner.reference(scope.resource, head).read(source, &buffer);
    var result = try compile(allocator, body);
    errdefer result.deinit();
    const compiled = result.value.compiled;
    if (!std.mem.eql(u8, compiled.canonical, body) or compiled.definition.realm != scope.realm or compiled.definition.revision.value != head.revision.value or !std.mem.eql(u8, &root.Publication.nameDigest(compiled.definition.name), &config.name_digest)) return error.InvalidApplicationProgram;
    const final = try source.readBatch(scope.resource, null, &selected);
    const final_config = (try final.read(selected[0])) orelse return error.ApplicationPublicationChanged;
    if (!final_config.eql((try initial.read(selected[0])).?) or !std.meta.eql(try owner.head(&final), @as(?root.Publication.Head, head))) return error.ApplicationPublicationChanged;
    result.value = .{ .published = .{ .head = head, .compiled = compiled } };
    return result;
}

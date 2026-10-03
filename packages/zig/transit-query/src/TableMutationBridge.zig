//! Owned neutral values for the explicit mutation caller. No language adapter
//! owns signing, upload progress or recovery semantics.
const std = @import("std");
const q = @import("root.zig");
const c = q.document.JsonValues;
const p = q.protocol;
const r = q.TableMutationRecords;
const Client = q.TableMutationClient;
const Request = q.TableMutationRequest;
const Ref = q.station.PublicationReference;
const Allocator = std.mem.Allocator;

pub const Capabilities = struct {
    version: u8 = 1,
    max_rows: u8 = q.fuze.TableMutation.max_rows,
    max_request_bytes: u16 = Request.max_bytes,
    max_saved_bytes: u16 = Client.Prepared.max_saved_bytes,
    insert: bool = true,
    update_primary_key: bool = true,
    delete_primary_key: bool = true,
};
pub const Command = union(enum) {
    begin: struct { reference: []const u8, table: u32, policy_revision: []const u8 },
    part: struct { reference: []const u8, ordinal: u32, second: bool, bytes: []const u8 },
    seal: []const u8,
    apply: []const u8,
    cancel: []const u8,
    pub fn native(self: Command, alloc: Allocator) !r.Command {
        const command: r.Command = switch (self) {
            .begin => |v| .{ .begin = .{ .reference = try reference(alloc, v.reference), .table = v.table, .policy_revision = try c.unsigned(v.policy_revision) } },
            .part => |v| .{ .part = .{ .reference = try reference(alloc, v.reference), .ordinal = v.ordinal, .second = v.second, .bytes = try c.unhex(alloc, v.bytes, r.part_bytes) } },
            inline else => |v, tag| @unionInit(r.Command, @tagName(tag), try reference(alloc, v)),
        };
        _ = try command.encode();
        return command;
    }
};
pub const Compiled = struct {
    request: []const u8,
    reference: []const u8,
    pub fn fromNative(alloc: Allocator, value: Request, namespace: u64) !Compiled {
        var buffer: [Request.max_bytes]u8 = undefined;
        return .{ .request = try c.hex(alloc, try value.encode(&buffer)), .reference = try c.hex(alloc, (try (try value.reference(namespace)).encode()).slice()) };
    }
    pub fn native(self: Compiled, alloc: Allocator) !struct { request: Request, reference: Ref } {
        const request = try Request.decode(try c.unhex(alloc, self.request, Request.max_bytes));
        const ref = try reference(alloc, self.reference);
        if (!std.meta.eql(ref, try request.reference(ref.namespace))) return error.MutationIdentityConflict;
        return .{ .request = request, .reference = ref };
    }
};
pub const Input = struct { prepared: []const u8, input: u64 };
pub const Action = union(enum) {
    capabilities,
    describe,
    compile: struct { name: []const u8, sql: []const u8, namespace: []const u8 },
    prepare: Command,
    next: Compiled,
    submit: []const u8,
    observe: Input,
    rejection: Input,
    status: []const u8,
};
pub const Description = struct {
    resource: u64,
    table: u32,
    names: [2][]const u8,
    value_type: q.fuze.model.Type,
    resource_revision: u64,
    policy_revision: []const u8,
    declaration: []const u8,
    permissions: u8,
    active: ?[]const u8,
    pub fn fromNative(alloc: Allocator, value: Client.Description) !Description {
        return .{ .resource = value.table.resource, .table = value.table.id, .names = .{ try alloc.dupe(u8, value.table.schema.names[0].slice()), try alloc.dupe(u8, value.table.schema.names[1].slice()) }, .value_type = value.table.schema.value_type, .resource_revision = value.resource_revision, .policy_revision = try c.decimal(alloc, value.policy.revision), .declaration = try c.hex(alloc, &value.policy.declaration), .permissions = value.policy.permissions, .active = if (value.active) |id| try c.decimal(alloc, id) else null };
    }
};
pub const Status = struct {
    reference: []const u8,
    principal: u64,
    table: u32,
    declaration: []const u8,
    policy_revision: []const u8,
    phase: r.Phase,
    affected_rows: u8,
    reason: r.Reason,
    input: u64,
    conflict: ?struct { key: []const u8, row: u8 },
    pub fn fromNative(alloc: Allocator, value: r.Status) !Status {
        _ = try value.encode();
        return .{ .reference = try c.hex(alloc, (try value.reference.encode()).slice()), .principal = value.principal, .table = value.table, .declaration = try c.hex(alloc, &value.declaration), .policy_revision = try c.decimal(alloc, value.policy_revision), .phase = value.phase, .affected_rows = value.affected_rows, .reason = value.reason, .input = value.input, .conflict = if (value.conflict) |conflict| .{ .key = try std.fmt.allocPrint(alloc, "{d}", .{conflict.key}), .row = conflict.row } else null };
    }
};
pub const Result = union(enum) {
    capabilities: Capabilities,
    description: Description,
    compiled: Compiled,
    prepared: ?[]const u8,
    receipt: p.Receipt,
    observation: Client.Observation,
    rejection: ?q.TableMutationWriter.Rejection,
    status: ?Status,
};
pub fn reference(alloc: Allocator, text: []const u8) !Ref {
    const result = try Ref.decode(try p.Value.init(try c.unhex(alloc, text, Ref.encoded_bytes)));
    try Request.checkReference(result);
    return result;
}
pub fn prepared(alloc: Allocator, bytes: []const u8) !Client.Prepared {
    return Client.Prepared.restore(alloc, bytes);
}
pub fn apply(alloc: Allocator, client: *Client, action: Action) !Result {
    return applyDiagnostic(alloc, client, action, null);
}
pub fn applyDiagnostic(alloc: Allocator, client: *Client, action: Action, binding: ?*q.fuze.Sql.Binding) !Result {
    if (binding) |detail| detail.* = .{};
    return switch (action) {
        .capabilities => .{ .capabilities = .{} },
        .describe => .{ .description = try Description.fromNative(alloc, try client.describe()) },
        .compile => |v| blk: {
            const namespace = try c.unsigned(v.namespace);
            if (namespace == 0) return error.InvalidTableMutationRequest;
            const request = try client.compileSqlDiagnostic(try .init(v.name), v.sql, binding);
            break :blk .{ .compiled = try Compiled.fromNative(alloc, request, namespace) };
        },
        .prepare => |v| .{ .prepared = try (try client.prepare(try v.native(alloc))).save(alloc) },
        .next => |v| blk: {
            const bound = try v.native(alloc);
            const next = try client.prepareNext(bound.reference.namespace, bound.request);
            break :blk .{ .prepared = if (next) |value| try value.save(alloc) else null };
        },
        .submit => |v| .{ .receipt = try client.submit(try prepared(alloc, v)) },
        .observe => |v| .{ .observation = try client.observe(try prepared(alloc, v.prepared), v.input) },
        .rejection => |v| .{ .rejection = try client.rejection(try prepared(alloc, v.prepared), v.input) },
        .status => |v| .{ .status = if (try client.status(try reference(alloc, v))) |value| try Status.fromNative(alloc, value) else null },
    };
}

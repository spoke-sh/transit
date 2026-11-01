//! Verify direct KV outcomes against the exact requested identity and basis.
const std = @import("std");
const c = @import("root.zig");
const d = c.protocol.DataLifecycle;
const K = c.DirectKV;
const s = c.storage;

fn frontier(position: d.Position, changed_lsn: u64) !void {
    try position.validate();
    if (position.next_lsn == 0 or changed_lsn > position.next_lsn) return error.InvalidKVResponse;
}
fn stored(value: s.TableDeclaration.Stored, spec: s.KVDeclaration.Spec) !void {
    try value.validate();
    if (value.kind != .kv) return error.InvalidKVResponse;
    var columns: [2]c.fuze.TableSchema.Column = undefined;
    if (!std.mem.eql(u8, &try spec.schema(value.interpretation.object.object, &columns).fingerprint(), &value.schema_fingerprint)) return error.InvalidKVResponse;
}
pub fn definition(allocator: std.mem.Allocator, value: K.Definition) !void {
    try stored(value.interpretation, value.spec);
    try frontier(value.position, value.changed_lsn);
    const properties: c.DirectCatalog.Properties = .{ .namespace = value.namespace, .authorization = value.authorization, .name = value.name };
    var buffer: [s.TableDeclaration.max_properties_bytes]u8 = undefined;
    var prepared = try s.KVDeclaration.prepare(allocator, .{ .object = value.interpretation.interpretation.object, .revision = value.interpretation.interpretation.revision, .spec = value.spec, .properties = try properties.encode(&buffer), .retired = value.retired });
    defer prepared.deinit();
    if (!std.meta.eql(value.interpretation, try prepared.stored())) return error.InvalidKVResponse;
}
pub fn declaration(allocator: std.mem.Allocator, request: K.DeclarationRequest, result: K.DeclarationResult) !void {
    const original = request.declaration.binding;
    if ((request.command == .preview) != (result == .preview)) return error.InvalidKVResponse;
    switch (result) {
        .operation => |value| {
            if (request.command == .admit and value == .not_observed) return error.InvalidKVResponse;
            try @import("DirectTableResponse.zig").stateDdl(.kv, original, value);
        },
        .preview => |value| {
            try original.requireSame(value.binding);
            try frontier(value.directory_position, 0);
            if ((value.reason == .none) != (value.work != null) or (value.work == null) != (value.schema_fingerprint == null) or value.rebuild_key) return error.InvalidKVResponse;
            if (value.work) |work| if (work != .metadata) return error.InvalidKVResponse;
            if (value.current) |current| {
                try current.interpretation.validate();
                if (current.interpretation.kind != .kv or !std.meta.eql(current.interpretation.interpretation.object, original.target)) return error.InvalidKVResponse;
                try frontier(current.position, current.changed_lsn);
            }
            if (request.declaration.action == .create and value.reason == .none) {
                if (value.current != null) return error.InvalidKVResponse;
                var scratch: std.heap.ArenaAllocator = .init(allocator);
                defer scratch.deinit();
                const proposed = try request.declaration.request(scratch.allocator());
                if (!std.mem.eql(u8, &try proposed.intent.action.create.schema.fingerprint(), &value.schema_fingerprint.?)) return error.InvalidKVResponse;
            }
        },
    }
}
pub fn validate(allocator: std.mem.Allocator, request: K.Request, result: K.Result) !void {
    const expected: std.meta.Tag(K.Result) = switch (request) {
        .observe => .definition,
        .mutate, .operation => .operation,
        .get => .value,
        .pin => .pin,
        .pin_status => .pin_status,
        .release => .released,
    };
    if (std.meta.activeTag(result) != expected) return error.InvalidKVResponse;
    switch (result) {
        .definition => |value| {
            try definition(allocator, value);
            if (!std.meta.eql(value.interpretation.interpretation.object, request.target())) return error.InvalidKVResponse;
        },
        .operation => |maybe| {
            if (maybe) |value| {
                const original = if (request == .mutate) request.mutate.binding else request.operation;
                try @import("DirectTableResponse.zig").stateEvidence(.kv, original, value);
                if (value.transaction != null) return error.InvalidKVResponse;
            } else if (request == .mutate) return error.InvalidKVResponse;
        },
        .value => |value| {
            try stored(value.interpretation, value.spec);
            try frontier(value.position, value.changed_lsn);
            if (!std.meta.eql(value.interpretation.interpretation.object, request.target()) or !std.meta.eql(value.source, request.get.source)) return error.InvalidKVResponse;
            if (value.workspace) |view| {
                try view.validate();
                if (value.source != null or !std.meta.eql(view.source.source.interpretation, value.interpretation.interpretation) or !std.meta.eql(view.source.source.accepted, value.position) or view.source.changed_lsn != value.changed_lsn) return error.InvalidKVResponse;
            }
            if (value.encoded) |binary| {
                const bytes = try binary.decode(allocator, c.fuze.Types.Codec.max_bytes);
                defer allocator.free(bytes);
                var scratch: std.heap.ArenaAllocator = .init(allocator);
                defer scratch.deinit();
                _ = try c.fuze.Types.Codec.decodeBoundInto(scratch.allocator(), .{ .name = "value", .type = value.spec.typeOf(), .nullable = value.spec.nullable }, bytes);
            }
        },
        .pin => |value| {
            try value.owner.validate();
            try value.content.validate();
            if (!std.meta.eql(value.owner, request.pin.owner)) return error.InvalidKVResponse;
        },
        .pin_status => |value| {
            try value.interpretation.validate();
            try frontier(value.position, 0);
            if (!std.meta.eql(value.interpretation.object, request.target()) or (value.released and value.handle == null)) return error.InvalidKVResponse;
            if (value.handle) |handle| {
                try handle.content.validate();
                if (!std.meta.eql(handle.owner, request.pin_status.owner)) return error.InvalidKVResponse;
            }
        },
        .released => {},
    }
}

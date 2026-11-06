//! Typed connector declaration publication. This owner admits no HTTP work.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const r = @import("DirectCatalogRecords.zig");
const A = c.SourceDeclaration;
pub const Intent = struct {
    kind: A.Kind,
    namespace: u64,
    name: c.TableAuthority.Name,
    action: union(enum) {
        create: struct { owner: u64, payload: A.Payload },
        control: struct { expected_epoch: u64, command: p.Source.Command },
        drop: struct { expected_epoch: ?u64 },
    },
    pub fn validate(self: Intent, binding: d.Binding) !void {
        try binding.validate();
        if (binding.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (binding.target.branch != 1 or binding.expected_data != null or binding.action != switch (self.action) {
            .create => d.Action.create,
            .control => .alter,
            .drop => .drop,
        }) return error.InvalidSourceDeclaration;
        switch (self.action) {
            .create => |value| {
                try p.Authorization.roleId(value.owner);
                if (std.meta.activeTag(value.payload) != self.kind) return error.CatalogKindMismatch;
                try value.payload.validate(binding.target);
            },
            .control => |value| {
                if (self.kind != .source or value.expected_epoch == 0) return error.InvalidSourceControl;
                // This gate lives at the typed boundary, independently of SQL.
                if (value.command != .retire) return error.SourceExecutionUnsupported;
            },
            .drop => |value| {
                if ((self.kind == .source) != (value.expected_epoch != null)) return error.InvalidSourceControl;
                if (value.expected_epoch) |epoch| if (epoch == 0) return error.InvalidSourceControl;
            },
        }
    }
    pub fn digest(self: Intent, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        if (bytes.len > A.max_bytes) return error.CatalogRecordTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.source.intent.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
};
pub const Request = struct {
    binding: d.Binding,
    intent: Intent,
    pub fn validate(self: Request, allocator: std.mem.Allocator, configuration: r.Configuration) !void {
        try self.intent.validate(self.binding);
        if (!std.meta.eql(self.binding.target.scope, configuration.scope) or self.binding.target.branch != configuration.branch or !std.mem.eql(u8, &try self.intent.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
};
pub const IntentStore = @import("CatalogIntentCodec.zig").BoundedCodec(Request, "catalog-source-intents", "TSRCREQ1", A.max_bytes);
pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, stale_control, dependency, writer_conflict, not_retired };
pub const Command = enum { preview, inspect, reserve, execute, cancel };
pub const State = struct {
    declaration: A.Stored,
    control: ?p.Source.Control,
    dropped: bool,
    pub fn validate(self: State) !void {
        try self.declaration.validate();
        if ((self.declaration.kind == .source) != (self.control != null)) return error.InvalidSourceControl;
        if (self.control) |control| {
            try control.validate();
            if ((control.state != .published and control.state != .retired) or (self.dropped and control.state != .retired)) return error.InvalidSourceControl;
        }
    }
};
/// Reservation and terminal receipt share the existing Catalog operation index.
/// The immutable request content is committed before its bytes are staged.
pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    kind: A.Kind,
    namespace: u64,
    name: c.TableAuthority.Name,
    position: d.Position,
    phase: enum { reserved, applied, rejected, cancelled },
    reason: Reason,
    previous: ?State,
    resulting: ?State,
    destination: ?d.Definition,
    removed: [2]?c.DirectDependency.Edge = @splat(null),
    added: [2]?c.DirectDependency.Edge = @splat(null),
    pub fn pending(self: Operation) bool {
        return self.phase == .reserved;
    }
    pub fn validate(self: Operation) !void {
        try self.binding.validate();
        if (self.binding.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.intent.validate();
        try self.position.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (self.intent.bytes <= A.header_bytes or self.intent.bytes > A.max_bytes or self.position.next_lsn == 0 or (self.phase == .rejected) != (self.reason != .none) or (self.phase == .applied) != (self.resulting != null)) return error.InvalidSourceDeclaration;
        if (self.destination) |destination| {
            try destination.validate();
            if (self.kind != .source or !std.meta.eql(destination.object.scope, self.binding.target.scope) or destination.object.branch != self.binding.target.branch) return error.InvalidSourceDeclaration;
        }
        if (self.previous) |value| {
            try value.validate();
            if (value.dropped or self.binding.action == .create or !std.meta.eql(value.declaration.interpretation, self.binding.expected_definition.?)) return error.InvalidSourceDeclaration;
        }
        if (self.resulting) |value| {
            try value.validate();
            const declaration = value.declaration;
            if (!std.meta.eql(declaration.interpretation.object, self.binding.target) or declaration.kind != self.kind or declaration.properties.namespace != self.namespace or !std.meta.eql(declaration.properties.name, self.name) or value.dropped != (self.binding.action == .drop)) return error.InvalidSourceDeclaration;
            if (self.binding.action == .create) {
                if (self.previous != null or (value.control != null and !std.meta.eql(value.control.?, p.Source.Control.initial()))) return error.InvalidSourceDeclaration;
            } else {
                const previous = self.previous orelse return error.InvalidSourceDeclaration;
                if (!std.meta.eql(previous.declaration, declaration)) return error.InvalidSourceDeclaration;
                if (self.binding.action == .alter) {
                    if (previous.control == null or !std.meta.eql(try previous.control.?.apply(.retire), value.control.?)) return error.InvalidSourceControl;
                } else if (self.binding.action != .drop or !std.meta.eql(previous.control, value.control)) return error.InvalidSourceControl;
            }
        }
        for (self.removed) |maybe| if (maybe) |edge| {
            try edge.validate();
            if (self.phase != .applied or self.binding.action != .drop or self.previous == null or !std.meta.eql(edge.dependent.interpretation, self.previous.?.declaration.interpretation)) return error.InvalidSourceDeclaration;
        };
        for (self.added) |maybe| if (maybe) |edge| {
            try edge.validate();
            if (self.phase != .applied or self.binding.action != .create or !std.meta.eql(edge.dependent.interpretation, self.resulting.?.declaration.interpretation)) return error.InvalidSourceDeclaration;
        };
    }
};
pub const Writer = struct { destination: d.Definition, source: d.Object, operation: d.Operation };
pub const Preview = struct { position: d.Position, current: ?State, reason: Reason };
pub const Observation = union(enum) { not_observed, operation: Operation };
pub const Metadata = struct {
    state: State,
    definition: A.Definition,
    position: d.Position,
    execution_supported: bool = false,
    execution: enum { never_run } = .never_run,
    dependency_state: enum { current, definition_changed },
    last_poll: ?d.Operation = null,
    last_publication: ?d.Position = null,
};
pub const Selection = struct { namespace: u64, kind: A.Kind };
pub const Cursor = struct { selection: Selection, principal: u64, role: ?u64, after: u64 };
pub const Page = struct { entries: [4]?State = @splat(null), next: ?Cursor, position: d.Position };

test "SOURCE typed publication refuses every execution control before admission" {
    const t = std.testing;
    const object: d.Object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 };
    const binding: d.Binding = .{ .definition = p.Growth.current_definition, .identity = .{ .scope = object.scope, .principal = 17, .operation = 1 }, .target = object, .action = .alter, .expected_definition = .{ .object = object, .revision = 1, .digest = @splat(1) }, .expected_data = null, .intent = @splat(1) };
    var intent: Intent = .{ .kind = .source, .namespace = 1, .name = try .init("earthquakes"), .action = .{ .control = .{ .expected_epoch = 1, .command = .retire } } };
    try intent.validate(binding);
    for ([_]p.Source.Command{ .authorize, .activate, .suspend_source, .resume_source }) |command| {
        intent.action.control.command = command;
        try t.expectError(error.SourceExecutionUnsupported, intent.validate(binding));
    }
}

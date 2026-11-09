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
                if (self.kind == .connection or value.expected_epoch == 0) return error.InvalidSourceControl;
                // This gate lives at the typed boundary, independently of SQL.
                if (value.command != .retire) return error.SourceExecutionUnsupported;
            },
            .drop => |value| {
                if ((self.kind != .connection) != (value.expected_epoch != null)) return error.InvalidSourceControl;
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
/// Includes request, declaration, bounded directory updates and terminal WAL
/// capacity. Charged once; resumption and closure do not admit another operation.
pub const reservation_bytes = 2 * A.max_bytes + 16 * r.max_record_bytes;
pub const State = struct {
    declaration: A.Stored,
    control: ?p.Source.Control,
    dropped: bool,
    pub fn validate(self: State) !void {
        try self.declaration.validate();
        if ((self.declaration.kind != .connection) != (self.control != null)) return error.InvalidSourceControl;
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
    expected_control: ?p.Source.Control,
    resulting: ?State,
    destination: ?d.Definition,
    staged: ?A.Stored,
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
        if (self.expected_control) |control| {
            try control.validate();
            if (self.phase != .applied or self.binding.action == .create or self.kind == .connection) return error.InvalidSourceControl;
        }
        if (self.staged) |stored| {
            try stored.validate();
            if (self.phase == .applied or self.binding.action != .create or !std.meta.eql(stored.interpretation.object, self.binding.target) or stored.kind != self.kind or stored.properties.namespace != self.namespace or !std.meta.eql(stored.properties.name, self.name)) return error.InvalidSourceDeclaration;
        }
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
                if (self.staged != null) return error.InvalidSourceDeclaration;
                if (self.previous != null or (value.control != null and !std.meta.eql(value.control.?, p.Source.Control.initial()))) return error.InvalidSourceDeclaration;
            } else {
                if (self.previous != null or !std.meta.eql(self.binding.expected_definition.?, declaration.interpretation)) return error.InvalidSourceDeclaration;
                if (self.binding.action == .alter) {
                    const previous_control = self.expected_control orelse return error.InvalidSourceControl;
                    if (!std.meta.eql(try previous_control.apply(.retire), value.control.?)) return error.InvalidSourceControl;
                } else if (self.binding.action != .drop or !std.meta.eql(self.expected_control, value.control)) return error.InvalidSourceControl;
            }
        }
        if (self.kind == .connection) {
            if (!std.meta.eql(self.added, @as([2]?c.DirectDependency.Edge, @splat(null))) or !std.meta.eql(self.removed, @as([2]?c.DirectDependency.Edge, @splat(null))) or self.destination != null) return error.InvalidSourceDeclaration;
        } else if (self.kind == .sink) {
            if (self.destination != null) return error.InvalidSourceDeclaration;
            if (self.phase == .applied and (self.binding.action == .create or self.binding.action == .drop)) {
                const edges = if (self.binding.action == .create) self.added else self.removed;
                const connection = edges[0] orelse return error.InvalidSourceDeclaration;
                if (edges[1] != null or connection.dependent.kind != .sink or connection.privileges != c.SourceAuthority.use)
                    return error.InvalidSourceDeclaration;
            }
        } else if (self.phase == .applied and (self.binding.action == .create or self.binding.action == .drop)) {
            const edges = if (self.binding.action == .create) self.added else self.removed;
            const connection = edges[0] orelse return error.InvalidSourceDeclaration;
            const destination = edges[1] orelse return error.InvalidSourceDeclaration;
            if (connection.dependent.kind != .source or destination.dependent.kind != .source or connection.privileges != c.SourceAuthority.use or destination.privileges != c.LogAuthority.inspect | c.LogAuthority.append or self.destination == null or !std.meta.eql(destination.source, self.destination.?) or std.meta.eql(connection.source.object, destination.source.object)) return error.InvalidSourceDeclaration;
        }
        for (self.removed) |maybe| if (maybe) |edge| {
            try edge.validate();
            if (self.phase != .applied or self.binding.action != .drop or self.resulting == null or !std.meta.eql(edge.dependent.interpretation, self.resulting.?.declaration.interpretation)) return error.InvalidSourceDeclaration;
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

/// A proposal has no object or operation identity and performs no allocation.
pub const Proposal = struct {
    namespace: u64,
    name: c.TableAuthority.Name,
    owner: u64,
    payload: A.Payload,
    pub fn validate(self: Proposal, connection: c.DirectTableProtocol.Connection) !void {
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        try p.Authorization.roleId(self.owner);
        // A placeholder establishes scope without reserving a catalog identity.
        // Avoid dependencies so preview never refuses a valid object numbered 1.
        var placeholder: u64 = 1;
        switch (self.payload) {
            .connection => {},
            .source => |value| while (placeholder == value.connection.object.object or placeholder == value.destination.object.object) : (placeholder += 1) {},
            .sink => |value| if (placeholder == value.connection.object.object) {
                placeholder += 1;
            },
        }
        try self.payload.validate(.{ .scope = connection.scope, .branch = 1, .object = placeholder });
    }
};
pub const Action = union(enum) {
    prepare: Proposal,
    declaration: struct { request: Request, command: Command, steps: u16 = 16 },
    lookup: struct { selection: Selection, name: c.TableAuthority.Name },
    inspect: d.Definition,
    list: struct { selection: Selection, cursor: ?Cursor },
    pub fn mutation(self: Action) bool {
        return self == .declaration and switch (self.declaration.command) {
            .reserve, .execute, .cancel => true,
            else => false,
        };
    }
    pub fn validate(self: Action, allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection) !void {
        switch (self) {
            .prepare => |value| try value.validate(connection),
            .declaration => |value| {
                try connection.binding(value.request.binding);
                try value.request.intent.validate(value.request.binding);
                if (value.steps == 0 or value.steps > 256) return error.InvalidCatalogStepBudget;
                if (!std.mem.eql(u8, &try value.request.intent.digest(allocator), &value.request.binding.intent)) return error.DataIdentityConflict;
            },
            .lookup => |value| {
                try c.Model.nativeId(value.selection.namespace);
                try value.name.validate();
            },
            .inspect => |value| {
                try value.validate();
                try connection.object(value.object);
            },
            .list => |value| {
                try c.Model.nativeId(value.selection.namespace);
                if (value.cursor) |cursor| if (cursor.after == 0 or cursor.principal != connection.principal or (connection.role != null and cursor.role != connection.role) or !std.meta.eql(cursor.selection, value.selection)) return error.InvalidCatalogCursor;
            },
        }
    }
};
pub const Result = union(enum) { preview: Preview, observation: Observation, metadata: ?Metadata, page: Page };
pub fn dispatch(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, action: Action, execution: c.DirectTableDispatch.Execution) !Result {
    return switch (action) {
        .prepare => |value| .{ .preview = try catalog.prepareSource(value, policy) },
        .declaration => |value| switch (value.command) {
            .preview => .{ .preview = try catalog.previewSource(value.request, policy) },
            .execute => .{ .observation = try (execution.source orelse return error.SourceExecutionUnsupported)(execution.context, catalog, value.request, policy, value.steps) },
            else => .{ .observation = try catalog.sourceOperation(value.request, value.command, policy) },
        },
        .inspect => |value| blk: {
            var owned = try catalog.inspectSource(catalog.allocator, value, policy);
            defer owned.deinit();
            break :blk .{ .metadata = try clone(allocator, owned.value) };
        },
        .lookup => |value| blk: {
            var owned = try catalog.resolveSource(catalog.allocator, value.selection, value.name, policy) orelse break :blk .{ .metadata = null };
            defer owned.deinit();
            break :blk .{ .metadata = try clone(allocator, owned.value) };
        },
        .list => |value| .{ .page = try catalog.listSources(value.selection, value.cursor, policy) },
    };
}
pub fn clone(allocator: std.mem.Allocator, value: Metadata) !Metadata {
    const bytes = try p.Json.valueAlloc(allocator, value);
    defer allocator.free(bytes);
    return std.json.parseFromSliceLeaky(Metadata, allocator, bytes, .{ .allocate = .alloc_always });
}
pub fn validateResult(allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, request: Action, result: Result) !void {
    try request.validate(allocator, connection);
    switch (request) {
        .prepare => {
            if (result != .preview or result.preview.current != null) return error.InvalidTableResponse;
            try result.preview.position.validate();
        },
        .declaration => |input| {
            if (input.command == .preview) {
                if (result != .preview) return error.InvalidTableResponse;
                try result.preview.position.validate();
                if (result.preview.current) |state| {
                    try state.validate();
                    if (!std.meta.eql(state.declaration.interpretation.object, input.request.binding.target)) return error.InvalidTableResponse;
                }
            } else {
                if (result != .observation) return error.InvalidTableResponse;
                switch (result.observation) {
                    .not_observed => if (input.command != .inspect) return error.InvalidTableResponse,
                    .operation => |value| {
                        try value.validate();
                        try value.binding.requireSame(input.request.binding);
                        if (value.kind != input.request.intent.kind or value.namespace != input.request.intent.namespace or !std.meta.eql(value.name, input.request.intent.name)) return error.InvalidTableResponse;
                        if (!std.meta.eql(value.intent, try IntentStore.encodedContent(allocator, input.request))) return error.InvalidTableResponse;
                    },
                }
            }
        },
        .lookup, .inspect => {
            if (result != .metadata) return error.InvalidTableResponse;
            const value = result.metadata orelse {
                if (request == .inspect) return error.InvalidTableResponse;
                return;
            };
            try value.state.validate();
            try value.position.validate();
            try connection.object(value.definition.object);
            if (value.execution_supported or value.last_poll != null or value.last_publication != null or !std.meta.eql(try value.definition.stored(allocator), value.state.declaration)) return error.InvalidTableResponse;
            if (request == .inspect) {
                if (!std.meta.eql(value.state.declaration.interpretation, request.inspect)) return error.InvalidTableResponse;
            } else if (value.state.dropped or value.state.declaration.kind != request.lookup.selection.kind or value.definition.properties.namespace != request.lookup.selection.namespace or !std.meta.eql(value.definition.properties.name, request.lookup.name)) return error.InvalidTableResponse;
        },
        .list => |input| {
            if (result != .page) return error.InvalidTableResponse;
            try result.page.position.validate();
            var after = if (input.cursor) |cursor| cursor.after else 0;
            var ended = false;
            for (result.page.entries) |maybe| if (maybe) |state| {
                try state.validate();
                try connection.object(state.declaration.interpretation.object);
                if (ended or state.dropped or state.declaration.kind != input.selection.kind or state.declaration.properties.namespace != input.selection.namespace or state.declaration.interpretation.object.object <= after) return error.InvalidTableResponse;
                after = state.declaration.interpretation.object.object;
            } else {
                ended = true;
            };
            if (result.page.next) |cursor| {
                try (Action{ .list = .{ .selection = input.selection, .cursor = cursor } }).validate(allocator, connection);
                if (cursor.after < after or cursor.after <= if (input.cursor) |prior| prior.after else @as(u64, 0)) return error.InvalidTableResponse;
            }
        },
    }
}

//! Named interpretation metadata over the direct catalog control partition.
//! One accepted control record publishes the name, immutable definition and
//! dependency replacement together. Native registration precedes that boundary;
//! retries retain the original binding and never infer acceptance from it.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const a = c.TableAuthority;
const A = c.CatalogDefinition;
const r = @import("DirectCatalogRecords.zig");
pub const Payload = struct {
    schema: c.DirectTableProtocol.Binary,
    sources: []const A.Source,
    body: @FieldType(A.Definition, "body"),
    pub const json_schema_sequence_bounds = .{ .sources = A.max_sources };
    pub fn definition(self: Payload, object: d.Object, revision: u64, properties: r.Properties) A.Definition {
        return .{ .definition = p.Growth.current_definition, .object = object, .revision = revision, .properties = properties, .retired = false, .schema = self.schema, .sources = self.sources, .body = self.body };
    }
};
pub const Intent = struct {
    kind: A.Kind,
    namespace: u64,
    name: a.Name,
    action: union(enum) { create: struct { owner: u64, payload: Payload }, replace: Payload, rename: a.Name, drop },
    pub fn validate(self: Intent, allocator: std.mem.Allocator, binding: d.Binding) !void {
        try binding.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (binding.expected_data != null or binding.action != switch (self.action) {
            .create => d.Action.create,
            .replace => .alter,
            .rename => .rename,
            .drop => .drop,
        }) return error.InvalidCatalogDescriptor;
        if (self.action == .create) try p.Authorization.roleId(self.action.create.owner);
        if (self.action == .rename) try self.action.rename.validate();
        if (self.payload()) |value| {
            if (std.meta.activeTag(value.body) != self.kind) return error.CatalogKindMismatch;
            // Syntax validation has no native registration. This placeholder is
            // never staged as a definition or used as an authorization claim.
            try value.definition(binding.target, try self.revision(binding), .{ .namespace = self.namespace, .authorization = 1, .name = self.name }).validate(allocator);
        }
    }
    pub fn payload(self: Intent) ?Payload {
        return switch (self.action) {
            .create => |value| value.payload,
            .replace => |value| value,
            else => null,
        };
    }
    pub fn revision(self: Intent, binding: d.Binding) !u64 {
        return if (self.action == .create) 1 else std.math.add(u64, binding.expected_definition.?.revision, 1);
    }
    pub fn digest(self: Intent, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try p.Json.valueAlloc(allocator, self);
        defer allocator.free(bytes);
        if (bytes.len > A.max_bytes) return error.CatalogRecordTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.catalog.interpretation.intent.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
};
pub const Request = struct {
    binding: d.Binding,
    intent: Intent,
    pub fn validate(self: Request, allocator: std.mem.Allocator, configuration: r.Configuration) !void {
        try self.intent.validate(allocator, self.binding);
        if (!std.meta.eql(self.binding.target.scope, configuration.scope) or self.binding.target.branch != configuration.branch or !std.mem.eql(u8, &try self.intent.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
};
pub const IntentStore = @import("CatalogIntentCodec.zig").Codec(Request, "catalog-definition-intents", "DCATREQ1");
pub const Reason = enum { none, name_conflict, object_conflict, stale_definition, dependency };
pub const Command = enum { preview, inspect, accept, cancel };
pub const Operation = struct {
    binding: d.Binding,
    intent: d.Content,
    kind: A.Kind,
    namespace: u64,
    name: a.Name,
    position: d.Position,
    phase: enum { applied, rejected, cancelled },
    reason: Reason,
    previous: ?A.Stored,
    resulting: ?A.Stored,
    /// Fixed per-declaration work bound, independent of catalog cardinality.
    removed: [A.max_sources]?c.DirectDependency.Edge = @splat(null),
    added: [A.max_sources]?c.DirectDependency.Edge = @splat(null),
    pub fn validate(self: Operation) !void {
        try self.binding.validate();
        try self.intent.validate();
        try self.position.validate();
        try c.Model.nativeId(self.namespace);
        try self.name.validate();
        if (self.position.next_lsn == 0 or (self.phase == .rejected) != (self.reason != .none) or (self.phase == .applied) != (self.resulting != null)) return error.InvalidCatalogDescriptor;
        if (self.previous) |value| {
            try value.validate();
            if (!std.meta.eql(value.interpretation.object, self.binding.target)) return error.InvalidCatalogDescriptor;
        }
        if (self.resulting) |value| {
            try value.validate();
            if (!std.meta.eql(value.interpretation.object, self.binding.target) or value.kind != self.kind or value.properties.namespace != self.namespace or !std.meta.eql(value.properties.name, self.name) or value.retired != (self.binding.action == .drop)) return error.InvalidCatalogDescriptor;
            if (self.binding.action == .create) {
                if (value.interpretation.revision != 1 or self.previous != null) return error.InvalidCatalogDescriptor;
            } else {
                const previous = self.previous orelse return error.InvalidCatalogDescriptor;
                if (previous.retired or previous.kind != value.kind or !std.meta.eql(previous.interpretation, self.binding.expected_definition.?) or value.interpretation.revision != try std.math.add(u64, previous.interpretation.revision, 1)) return error.InvalidCatalogDescriptor;
            }
        }
        for (self.removed) |maybe| if (maybe) |edge| {
            try edge.validate();
            if (self.phase != .applied or self.previous == null or !std.meta.eql(edge.dependent.interpretation, self.previous.?.interpretation)) return error.InvalidCatalogDescriptor;
        };
        for (self.added) |maybe| if (maybe) |edge| {
            try edge.validate();
            if (self.phase != .applied or self.resulting == null or self.resulting.?.retired or !std.meta.eql(edge.dependent.interpretation, self.resulting.?.interpretation)) return error.InvalidCatalogDescriptor;
        };
    }
};
pub const Preview = struct { binding: d.Binding, position: d.Position, current: ?A.Stored, reason: Reason };
pub const Observation = union(enum) { not_observed, registration_pending, operation: Operation };
pub const Page = struct { entries: [4]?A.Stored = @splat(null), next: ?u64, position: d.Position };
pub const Action = union(enum) {
    historical_list: struct { snapshot: d.Snapshot, namespace: u64, after: ?u64 },
    declaration: struct { request: Request, command: Command, steps: u16 = 16 },
    lookup: struct { namespace: u64, name: a.Name },
    inspect: d.Definition,
    authorize: struct { interpretation: d.Definition, rows: bool },
    historical: struct { snapshot: d.Snapshot, namespace: u64, name: a.Name, rows: bool },
    list: struct { namespace: u64, after: ?u64 },
    stage_input: struct { namespace: u64, bytes: c.DirectTableProtocol.Binary },
    pub fn mutation(self: Action) bool {
        return switch (self) {
            .declaration => |value| value.command == .accept or value.command == .cancel,
            .stage_input => true,
            else => false,
        };
    }
    pub fn validate(self: Action, allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection) !void {
        switch (self) {
            .historical_list => |value| {
                try value.snapshot.validate();
                if (value.snapshot.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
                if (!std.meta.eql(value.snapshot.owner.scope, connection.scope) or value.snapshot.branch != connection.branch) return error.HistoricalIdentityConflict;
                try c.Model.nativeId(value.namespace);
                if (value.after) |after| if (after == 0) return error.InvalidCatalogCursor;
            },
            .declaration => |value| {
                try connection.binding(value.request.binding);
                try value.request.intent.validate(allocator, value.request.binding);
                if (value.steps == 0 or value.steps > 256) return error.InvalidCatalogStepBudget;
                if (!std.mem.eql(u8, &try value.request.intent.digest(allocator), &value.request.binding.intent)) return error.DataIdentityConflict;
            },
            .authorize => |value| {
                try value.interpretation.validate();
                try connection.object(value.interpretation.object);
            },
            .historical => |value| {
                try value.snapshot.validate();
                if (value.snapshot.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
                if (!std.meta.eql(value.snapshot.owner.scope, connection.scope) or value.snapshot.branch != connection.branch) return error.HistoricalIdentityConflict;
                try c.Model.nativeId(value.namespace);
                try value.name.validate();
            },
            .lookup => |value| {
                try c.Model.nativeId(value.namespace);
                try value.name.validate();
            },
            .inspect => |value| {
                try value.validate();
                try connection.object(value.object);
            },
            .list => |value| {
                try c.Model.nativeId(value.namespace);
                if (value.after) |after| if (after == 0) return error.InvalidCatalogCursor;
            },
            .stage_input => |value| try c.Model.nativeId(value.namespace),
        }
    }
};
pub const HistoricalPage = struct { snapshot: d.Snapshot, entries: [4]?c.DirectHistoryDirectory.DescriptorEntry = @splat(null), next: ?u64 };
pub const Historical = struct { snapshot: d.Snapshot, binding: c.DirectHistoryDirectory.DescriptorEntry, value: A.Definition };
pub const Result = union(enum) { historical_page: HistoricalPage, authorized: d.Definition, historical: ?Historical, preview: Preview, observation: Observation, definition: ?A.Definition, page: Page, input: d.Content };
/// Preserve the owning retention failure through the shared HTTP category.
pub fn call(client: c.DirectTableClient, action: Action) !std.json.Parsed(c.DirectTableProtocol.Response) {
    return client.call(.{ .descriptor = action }) catch |err| {
        if ((action == .historical or action == .historical_list) and err == error.Conflict and client.service.last_rejection == .QueryExpired) return error.HistoricalSnapshotReleased;
        return err;
    };
}
pub fn dependentKind(kind: A.Kind) @FieldType(c.DirectDependency.Dependent, "kind") {
    return switch (kind) {
        .view => .view,
        .property_graph => .property_graph,
        .foreign => .foreign,
    };
}
pub fn edges(value: A.Definition, stored: A.Stored) ![A.max_sources]?c.DirectDependency.Edge {
    var result: [A.max_sources]?c.DirectDependency.Edge = @splat(null);
    if (stored.retired) return result;
    for (value.sources, 0..) |source, i| {
        const edge: c.DirectDependency.Edge = .{ .source = source.declaration.interpretation, .dependent = .{ .kind = dependentKind(stored.kind), .interpretation = stored.interpretation }, .privileges = a.select };
        try edge.validate();
        result[i] = edge;
    }
    return result;
}

pub fn definitionKey(value: d.Definition) !c.storage.TreeStore.pages.Key {
    try value.validate();
    var bytes: [16]u8 = undefined;
    std.mem.writeInt(u64, bytes[0..8], value.object.object, .big);
    std.mem.writeInt(u64, bytes[8..16], value.revision, .big);
    return c.storage.TreeStore.pages.Key.init(&bytes);
}

/// Output data belongs to the caller's request arena. No artifact contains a
/// dispatch callback or credential; inspection only copies verified metadata.
pub fn dispatch(allocator: std.mem.Allocator, catalog: *c.DirectCatalog, policy: c.DirectCatalog.Policy, action: Action, execution: c.DirectTableDispatch.Execution) !Result {
    return switch (action) {
        .historical_list => |value| .{ .historical_page = try catalog.historicalDefinitions(value.snapshot, value.namespace, value.after, policy) },
        .authorize => |value| blk: {
            try catalog.authorizeDefinition(value.interpretation, value.rows, policy);
            break :blk .{ .authorized = value.interpretation };
        },
        .historical => |value| .{ .historical = try catalog.historicalDefinition(allocator, value.snapshot, value.namespace, value.name, value.rows, policy) },
        .declaration => |value| switch (value.command) {
            .preview => .{ .preview = try catalog.previewDefinition(value.request, policy) },
            .inspect, .cancel => .{ .observation = try catalog.definitionOperation(value.request, value.command, policy) },
            .accept => .{ .observation = try (execution.descriptor orelse return error.CatalogRegistrationRequired)(execution.context, catalog, value.request, policy, value.steps) },
        },
        .lookup => |value| blk: {
            var owned = try catalog.resolveDefinition(catalog.allocator, value.namespace, value.name, policy) orelse break :blk .{ .definition = null };
            defer owned.deinit();
            break :blk .{ .definition = try clone(allocator, owned.value) };
        },
        .inspect => |value| blk: {
            var owned = try catalog.inspectDefinition(catalog.allocator, value, policy);
            defer owned.deinit();
            break :blk .{ .definition = try clone(allocator, owned.value) };
        },
        .list => |value| .{ .page = try catalog.listDefinitions(value.namespace, value.after, policy) },
        .stage_input => |value| blk: {
            const bytes = try value.bytes.decode(catalog.allocator, A.max_input_bytes);
            defer catalog.allocator.free(bytes);
            break :blk .{ .input = try catalog.stageDefinitionInput(value.namespace, bytes, policy) };
        },
    };
}
pub fn clone(allocator: std.mem.Allocator, value: A.Definition) !A.Definition {
    const bytes = try p.Json.valueAlloc(allocator, value);
    defer allocator.free(bytes);
    return std.json.parseFromSliceLeaky(A.Definition, allocator, bytes, .{ .allocate = .alloc_always });
}

pub fn validateResult(allocator: std.mem.Allocator, connection: c.DirectTableProtocol.Connection, request: Action, result: Result) !void {
    try request.validate(allocator, connection);
    switch (request) {
        .historical_list => |input| {
            if (result != .historical_page or !std.meta.eql(result.historical_page.snapshot, input.snapshot)) return error.InvalidTableResponse;
            var after = input.after orelse 0;
            var ended = false;
            for (result.historical_page.entries) |maybe| {
                const entry_value = maybe orelse {
                    ended = true;
                    continue;
                };
                try entry_value.validate(input.snapshot.owner, input.snapshot.branch);
                const id = entry_value.declaration.interpretation.object.object;
                if (ended or entry_value.namespace.id != input.namespace or id <= after) return error.InvalidTableResponse;
                after = id;
            }
            if (result.historical_page.next) |next| if (next < after or next <= (input.after orelse 0)) return error.InvalidTableResponse;
        },
        .authorize => |input| {
            if (result != .authorized or !std.meta.eql(input.interpretation, result.authorized)) return error.InvalidTableResponse;
        },
        .historical => |input| {
            if (result != .historical) return error.InvalidTableResponse;
            if (result.historical) |value| {
                if (!std.meta.eql(input.snapshot, value.snapshot) or value.binding.namespace.id != input.namespace or !std.meta.eql(value.binding.declaration.properties.name, input.name)) return error.InvalidTableResponse;
                try value.binding.validate(input.snapshot.owner, input.snapshot.branch);
                if (!std.meta.eql(try value.value.stored(allocator), value.binding.declaration)) return error.InvalidTableResponse;
            }
        },
        .declaration => |input| {
            if (input.command == .preview) {
                if (result != .preview) return error.InvalidTableResponse;
                try result.preview.binding.requireSame(input.request.binding);
                try result.preview.position.validate();
                if (result.preview.position.next_lsn == 0) return error.InvalidTableResponse;
                if (result.preview.current) |value| {
                    try value.validate();
                    if (!std.meta.eql(value.interpretation.object, input.request.binding.target)) return error.InvalidTableResponse;
                }
            } else {
                if (result != .observation) return error.InvalidTableResponse;
                switch (result.observation) {
                    .not_observed => if (input.command != .inspect) return error.InvalidTableResponse,
                    .registration_pending => if (input.command != .accept) return error.InvalidTableResponse,
                    .operation => |value| {
                        try value.validate();
                        try value.binding.requireSame(input.request.binding);
                        if (value.kind != input.request.intent.kind or value.namespace != input.request.intent.namespace or !std.meta.eql(value.name, if (input.request.intent.action == .rename) input.request.intent.action.rename else input.request.intent.name)) return error.InvalidTableResponse;
                        if (value.resulting) |stored| if (input.request.intent.payload()) |payload| {
                            const expected = payload.definition(stored.interpretation.object, stored.interpretation.revision, stored.properties);
                            if (!std.meta.eql(try expected.stored(allocator), stored)) return error.InvalidTableResponse;
                        };
                    },
                }
            }
        },
        .lookup, .inspect => {
            if (result != .definition) return error.InvalidTableResponse;
            if (result.definition) |value| {
                try value.validate(allocator);
                try connection.object(value.object);
                if (request == .inspect) {
                    if (!std.meta.eql((try value.stored(allocator)).interpretation, request.inspect)) return error.InvalidTableResponse;
                } else if (value.retired or value.properties.namespace != request.lookup.namespace or !std.meta.eql(value.properties.name, request.lookup.name)) return error.InvalidTableResponse;
            } else if (request == .inspect) return error.InvalidTableResponse;
        },
        .list => |input| {
            if (result != .page) return error.InvalidTableResponse;
            try result.page.position.validate();
            var previous = input.after orelse 0;
            var ended = false;
            for (result.page.entries) |maybe| if (maybe) |stored| {
                if (ended) return error.InvalidTableResponse;
                try stored.validate();
                try connection.object(stored.interpretation.object);
                if (stored.retired or stored.properties.namespace != input.namespace or stored.interpretation.object.object <= previous) return error.InvalidTableResponse;
                previous = stored.interpretation.object.object;
            } else {
                ended = true;
            };
            if (result.page.next) |next| if (next <= (input.after orelse 0) or next < previous) return error.InvalidTableResponse;
        },
        .stage_input => |input| {
            if (result != .input) return error.InvalidTableResponse;
            const bytes = try input.bytes.decode(allocator, A.max_input_bytes);
            defer allocator.free(bytes);
            if (result.input.bytes != bytes.len or !std.mem.eql(u8, &result.input.sha256, &r.hash(bytes))) return error.InvalidTableResponse;
        },
    }
}

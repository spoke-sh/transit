//! Language-neutral catalog values. Conversions retain owned native identities;
//! admission, authority and recovery remain in the shared signed client.
const std = @import("std");
const c = @import("root.zig");
const m = c.Model;
const p = c.protocol;
const Allocator = std.mem.Allocator;

pub fn unsigned(text: []const u8) !u64 {
    if (text.len == 0 or text.len > 20 or (text.len > 1 and text[0] == '0')) return error.InvalidCatalogInteger;
    for (text) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidCatalogInteger;
    return std.fmt.parseInt(u64, text, 10) catch return error.InvalidCatalogInteger;
}
fn decimal(allocator: Allocator, value: u64) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}", .{value});
}
pub const Scope = struct {
    realm: u64,
    resource: u64,
    catalog: []const u8,
    pub fn native(self: Scope) !m.Scope {
        const value: m.Scope = .{ .realm = self.realm, .resource = self.resource, .catalog = try unsigned(self.catalog) };
        try value.validate();
        return value;
    }
    pub fn fromNative(allocator: Allocator, value: m.Scope) !Scope {
        try value.validate();
        return .{ .realm = value.realm, .resource = value.resource, .catalog = try decimal(allocator, value.catalog) };
    }
};
pub const Connection = struct {
    scope: Scope,
    owner: u64,
    principal: u64,
    pub fn native(self: Connection) !c.Client.Connection {
        const value: c.Client.Connection = .{ .scope = try self.scope.native(), .owner = self.owner, .principal = self.principal };
        try value.validate();
        return value;
    }
};
pub const Configuration = struct {
    scope: Scope,
    owner: u64,
    administrator: u64,
    pub fn native(self: Configuration) !m.Configuration {
        const value: m.Configuration = .{ .scope = try self.scope.native(), .owner = self.owner, .administrator = self.administrator };
        try value.validate();
        return value;
    }
    pub fn fromNative(allocator: Allocator, value: m.Configuration) !Configuration {
        try value.validate();
        return .{ .scope = try Scope.fromNative(allocator, value.scope), .owner = value.owner, .administrator = value.administrator };
    }
};
pub const Schema = struct {
    names: [2][]const u8,
    value_type: c.fuze.model.Type,
    pub fn native(self: Schema) !c.fuze.model.Schema {
        const value: c.fuze.model.Schema = .{ .names = .{ try .init(self.names[0]), try .init(self.names[1]) }, .value_type = self.value_type };
        try value.validate();
        return value;
    }
    pub fn fromNative(allocator: Allocator, value: c.fuze.model.Schema) !Schema {
        try value.validate();
        return .{ .names = .{ try allocator.dupe(u8, value.names[0].slice()), try allocator.dupe(u8, value.names[1].slice()) }, .value_type = value.value_type };
    }
};
pub const CreateTable = struct {
    scope: Scope,
    operation: []const u8,
    object: []const u8,
    table: u32,
    name: []const u8,
    schema: Schema,
    pub fn native(self: CreateTable) !m.CreateTable {
        const value: m.CreateTable = .{ .scope = try self.scope.native(), .operation = try unsigned(self.operation), .object = try unsigned(self.object), .table = self.table, .name = try .init(self.name), .schema = try self.schema.native() };
        try value.validate();
        return value;
    }
    pub fn fromNative(allocator: Allocator, value: m.CreateTable) !CreateTable {
        try value.validate();
        return .{ .scope = try Scope.fromNative(allocator, value.scope), .operation = try decimal(allocator, value.operation), .object = try decimal(allocator, value.object), .table = value.table, .name = try allocator.dupe(u8, value.name.slice()), .schema = try Schema.fromNative(allocator, value.schema) };
    }
};
pub const Policy = struct {
    scope: Scope,
    principal: u64,
    revision: []const u8,
    inspect: bool,
    create: bool,
    pub fn native(self: Policy) !m.Policy {
        const value: m.Policy = .{ .scope = try self.scope.native(), .principal = self.principal, .revision = try unsigned(self.revision), .inspect = self.inspect, .create = self.create };
        try value.validate();
        return value;
    }
    pub fn fromNative(allocator: Allocator, value: m.Policy) !Policy {
        try value.validate();
        return .{ .scope = try Scope.fromNative(allocator, value.scope), .principal = value.principal, .revision = try decimal(allocator, value.revision), .inspect = value.inspect, .create = value.create };
    }
};
pub const PolicyChange = struct {
    expected_revision: []const u8,
    policy: Policy,
    pub fn native(self: PolicyChange) !m.PolicyChange {
        const value: m.PolicyChange = .{ .expected_revision = try unsigned(self.expected_revision), .policy = try self.policy.native() };
        try value.validate();
        return value;
    }
};
pub const Description = struct {
    configuration: Configuration,
    policy: Policy,
    resource_revision: u64,
};
pub const Receipt = struct {
    request: CreateTable,
    principal: u64,
    input: u64,
    outcome: m.Outcome,
    pub fn fromNative(allocator: Allocator, value: m.Receipt) !Receipt {
        try value.validate();
        return .{ .request = try CreateTable.fromNative(allocator, value.request), .principal = value.principal, .input = value.input, .outcome = value.outcome };
    }
};
pub const Disposition = struct {
    scope: Scope,
    origin: @FieldType(m.Disposition, "origin"),
    principal: u64,
    input: u64,
    payload: p.Value,
    outcome: @FieldType(m.Disposition, "outcome"),
    pub fn fromNative(allocator: Allocator, value: m.Disposition) !Disposition {
        try value.validate();
        return .{ .scope = try Scope.fromNative(allocator, value.scope), .origin = value.origin, .principal = value.principal, .input = value.input, .payload = try .init(&value.payload), .outcome = value.outcome };
    }
};
/// Neutral metadata owns its text through the supplied allocator. These values
/// carry no authorization; each reader independently enforces current rights.
pub const Definition = struct {
    scope: Scope,
    object: []const u8,
    revision: []const u8,
    name: []const u8,
    source: union(enum) { table: struct { id: u32, schema: Schema } },
    principal: u64,
    operation: []const u8,
    input: u64,
    pub fn native(self: Definition) !m.Definition {
        const value: m.Definition = .{
            .scope = try self.scope.native(),
            .object = try unsigned(self.object),
            .revision = try unsigned(self.revision),
            .name = try .init(self.name),
            .source = switch (self.source) {
                .table => |table| .{ .table = .{ .id = table.id, .schema = try table.schema.native() } },
            },
            .principal = self.principal,
            .operation = try unsigned(self.operation),
            .input = self.input,
        };
        try value.validate();
        return value;
    }
    pub fn fromNative(allocator: Allocator, value: m.Definition) !Definition {
        try value.validate();
        return .{
            .scope = try Scope.fromNative(allocator, value.scope),
            .object = try decimal(allocator, value.object),
            .revision = try decimal(allocator, value.revision),
            .name = try allocator.dupe(u8, value.name.slice()),
            .source = switch (value.source) {
                .table => |table| .{ .table = .{ .id = table.id, .schema = try Schema.fromNative(allocator, table.schema) } },
            },
            .principal = value.principal,
            .operation = try decimal(allocator, value.operation),
            .input = value.input,
        };
    }
};
pub const Cursor = struct {
    // Mandatory on decode, including a cursor retained by a foreign host.
    definition: p.Growth.Definition,
    scope: Scope,
    resource_revision: u64,
    after: []const u8,
    pub fn native(self: Cursor) !c.Inspection.Cursor {
        try m.nativeId(self.resource_revision);
        const name = try c.fuze.model.Name.init(self.after);
        try m.validName(name);
        return .{ .scope = try self.scope.native(), .resource_revision = self.resource_revision, .after = name };
    }
    pub fn fromNative(allocator: Allocator, value: c.Inspection.Cursor) !Cursor {
        try m.nativeId(value.resource_revision);
        try m.validName(value.after);
        return .{ .definition = p.Growth.current_definition, .scope = try Scope.fromNative(allocator, value.scope), .resource_revision = value.resource_revision, .after = try allocator.dupe(u8, value.after.slice()) };
    }
};
pub const Page = struct {
    resource_revision: u64,
    entries: [p.Growth.page_size]?Definition,
    next: ?Cursor,
    fn validate(value: c.Inspection.Page) !void {
        try m.nativeId(value.resource_revision);
        var previous: ?m.Definition = null;
        var ended = false;
        for (value.entries) |slot| {
            const entry = slot orelse {
                ended = true;
                continue;
            };
            if (ended) return error.InvalidCatalogPage;
            try entry.validate();
            if (previous) |old| {
                if (!std.meta.eql(old.scope, entry.scope) or std.mem.order(u8, old.name.slice(), entry.name.slice()) != .lt) return error.InvalidCatalogPage;
            }
            previous = entry;
        }
        if (value.next) |cursor| {
            const last = previous orelse return error.InvalidCatalogPage;
            if (!std.meta.eql(last.scope, cursor.scope) or !std.meta.eql(last.name, cursor.after) or cursor.resource_revision != value.resource_revision) return error.InvalidCatalogPage;
        }
    }
    pub fn native(self: Page) !c.Inspection.Page {
        var result: c.Inspection.Page = .{ .resource_revision = self.resource_revision, .next = if (self.next) |cursor| try cursor.native() else null };
        for (self.entries, 0..) |slot, index| if (slot) |entry| {
            result.entries[index] = try entry.native();
        };
        try validate(result);
        return result;
    }
    pub fn fromNative(allocator: Allocator, value: c.Inspection.Page) !Page {
        try validate(value);
        var result: Page = .{ .resource_revision = value.resource_revision, .entries = @splat(null), .next = if (value.next) |cursor| try Cursor.fromNative(allocator, cursor) else null };
        for (value.entries, 0..) |slot, index| if (slot) |entry| {
            result.entries[index] = try Definition.fromNative(allocator, entry);
        };
        return result;
    }
};
pub const Capabilities = struct {
    version: u8 = 1,
    definition: p.Growth.Definition = p.Growth.current_definition,
    initialize: bool = true,
    create_table: bool = true,
    conditional_policy: bool = true,
    current_metadata: bool = true,
    max_saved_bytes: u16 = c.Client.Prepared.max_saved_bytes,
    table_columns: u8 = 2,
};
pub const Compiled = struct { request: CreateTable, canonical: p.Value };
pub const Input = struct { prepared: []const u8, input: u64 };
pub const Action = union(enum) {
    capabilities,
    describe,
    lookup: []const u8,
    definition: struct { object: []const u8, revision: []const u8 },
    list: ?Cursor,
    compile: struct { operation: []const u8, object: []const u8, table: u32, sql: []const u8 },
    prepare_initialize: Configuration,
    prepare_create: CreateTable,
    prepare_policy: PolicyChange,
    submit: []const u8,
    observe: Input,
    input_disposition: Input,
    status: CreateTable,
};
pub const Result = union(enum) {
    capabilities: Capabilities,
    description: Description,
    definition: ?Definition,
    page: Page,
    compiled: Compiled,
    prepared: []const u8,
    receipt: p.Receipt,
    observation: c.Client.Observation,
    disposition: ?Disposition,
    status: ?Receipt,
};
pub fn prepared(allocator: Allocator, bytes: []const u8) !c.Client.Prepared {
    return c.Client.Prepared.restore(allocator, bytes);
}
/// Offline compilation needs an explicit identity scope, never credentials or transport.
pub fn compile(allocator: Allocator, connection: c.Client.Connection, value: @FieldType(Action, "compile")) !Compiled {
    try connection.validate();
    const request = try m.CreateTable.compile(connection.scope, try unsigned(value.operation), try unsigned(value.object), value.table, value.sql);
    return .{ .request = try CreateTable.fromNative(allocator, request), .canonical = try c.Records.encode('q', request) };
}
pub fn apply(allocator: Allocator, client: *c.Client, action: Action) !Result {
    return switch (action) {
        .capabilities => .{ .capabilities = .{} },
        .describe => blk: {
            const value = try client.describe();
            break :blk .{ .description = .{ .configuration = try Configuration.fromNative(allocator, value.configuration), .policy = try Policy.fromNative(allocator, value.policy), .resource_revision = value.resource_revision } };
        },
        .lookup => |value| .{ .definition = if (try client.lookup(try .init(value))) |result| try Definition.fromNative(allocator, result) else null },
        .definition => |value| .{ .definition = if (try client.definition(try unsigned(value.object), try unsigned(value.revision))) |result| try Definition.fromNative(allocator, result) else null },
        .list => |value| .{ .page = try Page.fromNative(allocator, try client.list(if (value) |cursor| try cursor.native() else null)) },
        .compile => |value| .{ .compiled = try compile(allocator, client.connection, value) },
        .prepare_initialize => |value| .{ .prepared = try (try client.prepareInitialize(try value.native())).save(allocator) },
        .prepare_create => |value| .{ .prepared = try (try client.prepareCreate(try value.native())).save(allocator) },
        .prepare_policy => |value| .{ .prepared = try (try client.preparePolicy(try value.native())).save(allocator) },
        .submit => |value| .{ .receipt = try client.submit(try prepared(allocator, value)) },
        .observe => |value| .{ .observation = try client.observe(try prepared(allocator, value.prepared), value.input) },
        .input_disposition => |value| .{ .disposition = if (try client.inputDisposition(try prepared(allocator, value.prepared), value.input)) |result| try Disposition.fromNative(allocator, result) else null },
        .status => |value| .{ .status = if (try client.status(try value.native())) |result| try Receipt.fromNative(allocator, result) else null },
    };
}

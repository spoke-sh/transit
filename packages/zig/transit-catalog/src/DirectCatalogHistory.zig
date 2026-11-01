//! Owned, lossless caller values for the existing historical catalog owner.
//! One action makes one bounded request. Callers save acquisition inputs before
//! dispatch and resume their original key; local close never releases history.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const H = c.DirectHistory;
const h = c.DirectTableValues;
const v = c.TableValues;
const A = std.mem.Allocator;

pub const Key = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    account: []const u8,
    token: []const u8,
    pub fn native(self: Key) !c.DirectClientToken.Key {
        const result: c.DirectClientToken.Key = .{ .definition = self.definition, .connection = try self.connection.native(), .account = try fixedHex(32, self.account), .token = try fixedHex(16, self.token) };
        try result.validate();
        return result;
    }
    pub fn foreign(allocator: A, value: c.DirectClientToken.Key) !Key {
        try value.validate();
        return .{ .definition = value.definition, .connection = try h.Connection.foreign(allocator, value.connection), .account = try v.hex(allocator, &value.account), .token = try v.hex(allocator, &value.token) };
    }
};
pub const Directory = struct {
    content: h.Content,
    count: []const u8,
    fn native(self: Directory) !c.DirectHistoryDirectory.Reference {
        const value: c.DirectHistoryDirectory.Reference = .{ .content = try self.content.native(), .count = try v.unsigned(self.count) };
        if (value.count == 0) return error.EmptyHistoricalSelection;
        return value;
    }
    fn foreign(allocator: A, value: c.DirectHistoryDirectory.Reference) !Directory {
        return .{ .content = try h.Content.foreign(allocator, value.content), .count = try v.decimal(allocator, value.count) };
    }
};
pub const Selection = struct {
    definition: p.Growth.Definition,
    owner: h.Operation,
    branch: []const u8,
    directory: ?Directory,
    fn native(self: Selection) !H.Selection {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        return .{ .owner = try self.owner.native(), .branch = try v.unsigned(self.branch), .directory = if (self.directory) |value| try value.native() else null };
    }
    fn foreign(allocator: A, value: H.Selection) !Selection {
        return .{ .definition = p.Growth.current_definition, .owner = try h.Operation.foreign(allocator, value.owner), .branch = try v.decimal(allocator, value.branch), .directory = if (value.directory) |directory| try Directory.foreign(allocator, directory) else null };
    }
};
pub const CommonCut = struct {
    transaction: h.Operation,
    acquired: h.Position,
    sources: h.Content,
    source_count: []const u8,
    fn native(self: CommonCut) !d.CommonCut {
        const value: d.CommonCut = .{ .transaction = try self.transaction.native(), .acquired = try self.acquired.native(), .sources = try self.sources.native(), .source_count = try v.unsigned(self.source_count) };
        try value.validate();
        return value;
    }
    fn foreign(allocator: A, value: d.CommonCut) !CommonCut {
        return .{ .transaction = try h.Operation.foreign(allocator, value.transaction), .acquired = try h.Position.foreign(allocator, value.acquired), .sources = try h.Content.foreign(allocator, value.sources), .source_count = try v.decimal(allocator, value.source_count) };
    }
};
pub const Common = struct { key: Key, cut: CommonCut };
pub const Intent = struct {
    definition: p.Growth.Definition,
    connection: h.Connection,
    namespace: u64,
    operation: []const u8,
    selection: Directory,
    common: ?Common,
    pub fn native(self: Intent) !H.Intent {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        const value: H.Intent = .{ .connection = try self.connection.native(), .namespace = self.namespace, .operation = try v.unsigned(self.operation), .selection = try self.selection.native(), .common = if (self.common) |common| .{ .key = try common.key.native(), .cut = try common.cut.native() } else null };
        try value.validate();
        return value;
    }
    fn foreign(allocator: A, value: H.Intent) !Intent {
        try value.validate();
        return .{ .definition = p.Growth.current_definition, .connection = try h.Connection.foreign(allocator, value.connection), .namespace = value.namespace, .operation = try v.decimal(allocator, value.operation), .selection = try Directory.foreign(allocator, value.selection), .common = if (value.common) |common| .{ .key = try Key.foreign(allocator, common.key), .cut = try CommonCut.foreign(allocator, common.cut) } else null };
    }
};
pub const Budget = struct {
    operations: []const u8 = "1000000",
    bytes: []const u8 = "4294967296",
    pending: []const u8 = "1024",
    charge_bytes: []const u8 = "4608",
    fn native(self: Budget) !c.DirectClientToken.Budget {
        const value: c.DirectClientToken.Budget = .{ .limits = .{ .operations = try v.unsigned(self.operations), .bytes = try v.unsigned(self.bytes), .pending = try v.unsigned(self.pending) }, .bytes = try v.unsigned(self.charge_bytes) };
        try value.validate();
        return value;
    }
};
/// The canonical selector is the input identity. These expanded fields make
/// attribution inspectable without host-number truncation or another lookup.
pub const Snapshot = struct {
    selector: []const u8,
    definition: p.Growth.Definition,
    owner: h.Operation,
    branch: []const u8,
    catalog_root: h.Content,
    sources_root: h.Content,
    source_count: []const u8,
    consistency: union(enum) { single_partition: h.Position, independent, common_transaction: CommonCut },
    pub fn foreign(allocator: A, value: d.Snapshot) !Snapshot {
        var buffer: [H.Selector.text_bytes]u8 = undefined;
        return .{ .selector = try allocator.dupe(u8, try H.Selector.encode(value, &buffer)), .definition = value.definition, .owner = try h.Operation.foreign(allocator, value.owner), .branch = try v.decimal(allocator, value.branch), .catalog_root = try h.Content.foreign(allocator, value.catalog_root), .sources_root = try h.Content.foreign(allocator, value.sources_root), .source_count = try v.decimal(allocator, value.source_count), .consistency = switch (value.consistency) {
            .single_partition => |position| .{ .single_partition = try h.Position.foreign(allocator, position) },
            .independent => .independent,
            .common_transaction => |cut| .{ .common_transaction = try CommonCut.foreign(allocator, cut) },
        } };
    }
};
pub const Cursor = struct { selector: []const u8, namespace: u64, directory: Directory, after: []const u8 };
pub const Status = struct {
    key: Key,
    intent: Intent,
    admitted: h.Position,
    revision: h.Position,
    phase: H.Phase,
    retained: ?Directory,
    after: ?[]const u8,
    inflight: ?[]const u8,
    verified_after: ?[]const u8,
    policy_epoch: ?[]const u8,
    released_after: ?[]const u8,
    snapshot: ?Snapshot,
};
pub const Namespace = struct {
    scope: h.Scope,
    id: u64,
    authorization: u64,
    name: []const u8,
    revision: []const u8,
    fn foreign(allocator: A, value: c.TableAuthority.Schema) !Namespace {
        try value.validate();
        if (value.retired) return error.InvalidHistoricalResponse;
        return .{ .scope = try h.Scope.foreign(allocator, value.scope), .id = value.id, .authorization = value.authorization, .name = try allocator.dupe(u8, value.name.slice()), .revision = try v.decimal(allocator, value.revision) };
    }
};
pub const Entry = struct {
    namespace: Namespace,
    name: []const u8,
    declaration: h.Stored,
    accepted: h.Position,
    catalog: h.Position,
    fn foreign(allocator: A, value: c.DirectHistoryDirectory.Entry) !Entry {
        return .{ .namespace = try Namespace.foreign(allocator, value.namespace), .name = try allocator.dupe(u8, value.properties.name.slice()), .declaration = try h.Stored.foreign(allocator, value.declaration), .accepted = try h.Position.foreign(allocator, value.source.accepted), .catalog = try h.Position.foreign(allocator, value.catalog) };
    }
};
pub const Action = union(enum) {
    select: struct { selection: Selection, namespace: u64, name: []const u8 },
    acquire: struct { key: Key, intent: Intent, budget: Budget = .{} },
    inspect: Key,
    advance: Key,
    abandon: Key,
    release: Key,
    lookup: struct { selector: []const u8, namespace: u64, name: []const u8 },
    namespace: struct { selector: []const u8, name: []const u8 },
    list: struct { selector: []const u8, namespace: u64, after: ?Cursor },
    /// Metadata only. Rows use the shared SQL/query result lifecycle.
    source: struct { selector: []const u8, object: []const u8 },

    pub fn native(self: Action) !H.Request {
        return switch (self) {
            .select => |value| .{ .select = .{ .selection = try value.selection.native(), .namespace = value.namespace, .name = try .init(value.name) } },
            .acquire => |value| .{ .acquire = .{ .key = try value.key.native(), .intent = try value.intent.native(), .budget = try value.budget.native() } },
            inline .inspect, .advance, .abandon, .release => |key, tag| @unionInit(H.Request, @tagName(tag), try key.native()),
            .lookup => |value| .{ .lookup = .{ .snapshot = try H.Selector.decode(value.selector), .namespace = value.namespace, .name = try .init(value.name) } },
            .namespace => |value| .{ .namespace = .{ .snapshot = try H.Selector.decode(value.selector), .name = try .init(value.name) } },
            .source => |value| .{ .source = .{ .snapshot = try H.Selector.decode(value.selector), .object = try v.unsigned(value.object), .rows = false } },
            .list => |value| blk: {
                const snapshot = try H.Selector.decode(value.selector);
                if (value.after) |after| if (!std.mem.eql(u8, after.selector, value.selector) or after.namespace != value.namespace) return error.InvalidHistoricalCursor;
                break :blk .{ .list = .{ .snapshot = snapshot, .namespace = value.namespace, .after = if (value.after) |after| .{ .directory = try after.directory.native(), .after = try v.unsigned(after.after) } else null } };
            },
        };
    }
    pub fn identity(self: Action) !?d.Operation {
        return switch (self) {
            .select => |value| try value.selection.owner.native(),
            .acquire => |value| (try value.intent.native()).identity(),
            else => null,
        };
    }
    pub fn isRead(self: Action) bool {
        return switch (self) {
            .inspect, .lookup, .namespace, .list, .source => true,
            else => false,
        };
    }
};
pub const Result = union(enum) {
    selection: Selection,
    status: ?Status,
    object: ?[]const u8,
    namespace: ?Namespace,
    listing: struct {
        pub const json_schema_sequence_bounds = .{ .entries = 8 };
        snapshot: Snapshot,
        namespace: u64,
        entries: []const Entry,
        next: ?Cursor,
    },
    source: struct { snapshot: Snapshot, binding: Entry, schema: c.fuze.TableSchemaJson.Schema, rows: []const u8, changed_lsn: []const u8, authority: c.DirectReadAuthority },
};
pub fn apply(allocator: A, client: c.DirectTableClient, action: Action) !Result {
    const request = try action.native();
    const response = try H.call(client, request);
    defer response.deinit();
    return project(allocator, response.value.result.historical_catalog);
}
fn project(allocator: A, result: H.Result) !Result {
    return switch (result) {
        .selection => |value| .{ .selection = try Selection.foreign(allocator, value) },
        .status => |value| .{ .status = if (value) |status| .{
            .key = try Key.foreign(allocator, status.receipt.binding.key),
            .intent = try Intent.foreign(allocator, status.receipt.binding.intent.history),
            .admitted = try h.Position.foreign(allocator, status.receipt.position),
            .revision = try h.Position.foreign(allocator, status.revision),
            .phase = status.state.phase,
            .retained = if (status.state.retained) |directory| try Directory.foreign(allocator, directory) else null,
            .after = try optionalNumber(allocator, status.state.after),
            .inflight = try optionalNumber(allocator, status.state.inflight),
            .verified_after = try optionalNumber(allocator, status.state.verified_after),
            .policy_epoch = try optionalNumber(allocator, status.state.policy_epoch),
            .released_after = try optionalNumber(allocator, status.state.released_after),
            .snapshot = if (status.state.snapshot) |snapshot| try Snapshot.foreign(allocator, snapshot) else null,
        } else null },
        .object => |value| .{ .object = try optionalNumber(allocator, value) },
        .namespace => |value| .{ .namespace = if (value) |namespace| try Namespace.foreign(allocator, namespace) else null },
        .listing => |page| blk: {
            const snapshot = try Snapshot.foreign(allocator, page.snapshot);
            const entries = try allocator.alloc(Entry, page.entries.len);
            for (entries, page.entries) |*out, value| out.* = try Entry.foreign(allocator, value);
            break :blk .{ .listing = .{ .snapshot = snapshot, .namespace = page.namespace, .entries = entries, .next = if (page.next) |next| .{ .selector = snapshot.selector, .namespace = page.namespace, .directory = try Directory.foreign(allocator, next.directory), .after = try v.decimal(allocator, next.after) } else null } };
        },
        .source => |value| blk: {
            var scratch: std.heap.ArenaAllocator = .init(allocator);
            defer scratch.deinit();
            var schema = try c.fuze.TableSchema.decode(allocator, try value.schema.decode(scratch.allocator(), c.fuze.TableSchema.max_bytes));
            defer schema.deinit();
            break :blk .{ .source = .{ .snapshot = try Snapshot.foreign(allocator, value.snapshot), .binding = try Entry.foreign(allocator, value.binding), .schema = try c.fuze.TableSchemaJson.foreignInto(allocator, schema.schema), .rows = try v.decimal(allocator, value.rows), .changed_lsn = try v.decimal(allocator, value.changed_lsn), .authority = value.authority } };
        },
        .page => error.InvalidHistoricalResponse,
    };
}
fn optionalNumber(allocator: A, value: ?u64) !?[]const u8 {
    return if (value) |number| try v.decimal(allocator, number) else null;
}
fn fixedHex(comptime length: usize, text: []const u8) ![length]u8 {
    if (text.len != length * 2) return error.InvalidHistoricalBinding;
    var output: [length]u8 = undefined;
    _ = std.fmt.hexToBytes(&output, text) catch return error.InvalidHistoricalBinding;
    if (!std.mem.eql(u8, text, &std.fmt.bytesToHex(&output, .lower))) return error.InvalidHistoricalBinding;
    return output;
}

test "historical caller projections preserve maximum identities and cursor scope after source cleanup" {
    const t = std.testing;
    const snapshot: d.Snapshot = .{ .definition = p.Growth.current_definition, .owner = .{ .scope = .{ .realm = 46, .resource = 3, .catalog = std.math.maxInt(u64) }, .principal = 17, .operation = std.math.maxInt(u64) }, .branch = 1, .catalog_root = .{ .bytes = std.math.maxInt(u64), .sha256 = @splat(1) }, .sources_root = .{ .bytes = 4096, .sha256 = @splat(2) }, .source_count = std.math.maxInt(u64), .consistency = .independent };
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const copied = try Snapshot.foreign(output.allocator(), snapshot);
    try t.expectEqualStrings("18446744073709551615", copied.owner.operation);
    try t.expectEqualStrings("18446744073709551615", copied.source_count);
    try t.expectEqualDeep(snapshot, try H.Selector.decode(copied.selector));
    const cursor: Cursor = .{ .selector = copied.selector, .namespace = 1, .directory = .{ .content = copied.sources_root, .count = copied.source_count }, .after = "18446744073709551614" };
    const action: Action = .{ .list = .{ .selector = copied.selector, .namespace = 1, .after = cursor } };
    const native = try action.native();
    try t.expectEqual(std.math.maxInt(u64) - 1, native.list.after.?.after);
    var changed = action;
    changed.list.namespace = 2;
    try t.expectError(error.InvalidHistoricalCursor, changed.native());
    const bytes = try p.Json.valueAlloc(output.allocator(), action);
    var restored = try p.Json.parseFromSliceOwned(Action, t.allocator, bytes);
    defer restored.deinit();
    _ = output.reset(.free_all);
    try t.expectEqualDeep(native, try restored.value.native());
}

test "historical common caller values retain full width cut and original recovery key" {
    const t = std.testing;
    const Fixture = struct { request: c.DirectTableProtocol.Request, public_key: [32]u8, intent_digest: [32]u8, snapshot: d.Snapshot, selector: []const u8 };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/direct-history-common-v1.json"));
    defer parsed.deinit();
    const intent = parsed.value.request.action.historical_catalog.acquire.intent;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const foreign = try Intent.foreign(output.allocator(), intent);
    try t.expectEqualStrings("18446744073709551614", foreign.common.?.cut.transaction.operation);
    try t.expectEqualDeep(intent, try foreign.native());
    const snapshot = try Snapshot.foreign(output.allocator(), parsed.value.snapshot);
    try t.expectEqualStrings(parsed.value.selector, snapshot.selector);
    try t.expectEqualDeep(intent.common.?.cut, try snapshot.consistency.common_transaction.native());
    const saved = try p.Json.valueAlloc(output.allocator(), foreign);
    var restored = try p.Json.parseFromSliceOwned(Intent, t.allocator, saved);
    defer restored.deinit();
    _ = output.reset(.free_all);
    try t.expectEqualDeep(intent, try restored.value.native());
}

test "historical shared host rejects invalid selectors before transport and preserves read diagnostics" {
    const t = std.testing;
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    var wire = c.client.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    var attempt: c.DirectTableClient.Attempt = .{};
    const client: c.DirectTableClient = .{ .allocator = t.allocator, .authority = &wire, .service = &wire, .connection = .{ .scope = .{ .realm = 46, .resource = 3, .catalog = 1 }, .branch = 1, .audience = 3, .principal = 17, .role = null }, .key = try p.Ed25519.KeyPair.generateDeterministic(@splat(1)), .attempt = &attempt };
    var session: c.DirectTableBridge.Session = .{ .allocator = t.allocator };
    defer session.deinit();
    const action: c.DirectTableBridge.Action = .{ .history = .{ .lookup = .{ .selector = "bad", .namespace = 1, .name = "events" } } };
    try t.expectError(error.InvalidHistoricalSelector, session.apply(&output, client, action, null));
    try t.expect(attempt.mutation == null);
    const failure = try c.DirectTableDiagnostic.failure(action, error.InvalidHistoricalSelector, .{}, attempt, null);
    try t.expectEqual(.read, failure.stage);
    try t.expectEqual(.not_applicable, failure.outcome);
}

//! Signed direct Table requests. Binary schemas/rows retain their exact Fuze
//! interpretation; operation identity is independent of a transport nonce.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const f = c.fuze;
const D = c.DirectCatalog;
const P = c.storage.TablePartition;
pub const max_request_bytes = 8 * 1024 * 1024;
pub const max_response_bytes = 16 * 1024 * 1024;
pub const max_page_bytes = 8 * 1024 * 1024;
pub const max_work_bytes = c.storage.TransitLog.max_payload_bytes;

/// Canonical padded RFC 4648 base64, never a JSON byte string or number array.
pub const Binary = struct {
    pub const json_schema_text_bounds = .{ .base64 = 4 * ((max_work_bytes + 2) / 3) };
    base64: []const u8,
    pub fn encode(allocator: std.mem.Allocator, bytes: []const u8) !Binary {
        if (bytes.len > max_work_bytes) return error.TablePayloadTooLarge;
        const output = try allocator.alloc(u8, std.base64.standard.Encoder.calcSize(bytes.len));
        return .{ .base64 = std.base64.standard.Encoder.encode(output, bytes) };
    }
    pub fn decode(self: Binary, allocator: std.mem.Allocator, limit: usize) ![]const u8 {
        if (self.base64.len > std.base64.standard.Encoder.calcSize(@min(limit, max_work_bytes))) return error.TablePayloadTooLarge;
        const size = std.base64.standard.Decoder.calcSizeForSlice(self.base64) catch return error.InvalidTableBinary;
        if (size > limit or size > max_work_bytes) return error.TablePayloadTooLarge;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        std.base64.standard.Decoder.decode(output, self.base64) catch return error.InvalidTableBinary;
        // Reject ignored pad bits and alternate spellings before any admission.
        const canonical = try encode(allocator, output);
        defer allocator.free(canonical.base64);
        if (!std.mem.eql(u8, canonical.base64, self.base64)) return error.InvalidTableBinary;
        return output;
    }
};

pub const Connection = struct {
    scope: d.Scope,
    branch: u64,
    audience: u64,
    principal: u64,
    role: ?u64,
    pub fn validate(self: Connection) !void {
        try self.scope.validate();
        try c.Model.nativeId(self.audience);
        if (self.branch != 1 or self.principal > p.max_counter or (self.role orelse 0) > p.max_counter) return error.InvalidTableConnection;
    }
    pub fn matches(self: Connection, configuration: D.Configuration) bool {
        return std.meta.eql(self.scope, configuration.scope) and self.branch == configuration.branch and self.audience == configuration.audience;
    }
    pub fn binding(self: Connection, value: d.Binding) !void {
        try value.validate();
        if (!std.meta.eql(value.target.scope, self.scope) or value.target.branch != self.branch or value.identity.principal != self.principal) return error.CatalogDenied;
    }
    pub fn object(self: Connection, value: d.Object) !void {
        try value.validate();
        if (!std.meta.eql(value.scope, self.scope) or value.branch != self.branch) return error.CatalogDenied;
    }
    pub fn owner(self: Connection, value: d.Operation) !void {
        try value.validate();
        if (!std.meta.eql(value.scope, self.scope) or value.principal != self.principal) return error.CatalogDenied;
    }
};

/// Defaults are FVL1 typed cells, preserving binary values and floating bits.
/// The Table owner validates the resulting value against its accepted column.
pub const Change = union(enum) {
    add: struct { name: []const u8, type: f.Types.Type, nullable: bool, default: ?Binary, max_characters: ?u32, encoding: f.TableSchema.Encoding, collation: f.TableSchema.Collation },
    drop: u64,
    rename: struct { column: u64, name: []const u8 },
    default: struct { column: u64, value: ?Binary },
    nullable: struct { column: u64, value: bool },
    type: struct { column: u64, type: f.Types.Type, max_characters: ?u32 },
    physical: struct { column: u64, encoding: f.TableSchema.Encoding, collation: f.TableSchema.Collation },

    fn cell(allocator: std.mem.Allocator, value: ?Binary) !?f.Types.Values.Cell {
        const binary = value orelse return null;
        const bytes = try binary.decode(allocator, f.TableSchema.max_bytes);
        // All child storage belongs to the request arena.
        return (try f.Types.Codec.decode(allocator, bytes)).cell;
    }
    pub fn native(self: Change, allocator: std.mem.Allocator) !f.TableEvolution.Change {
        return switch (self) {
            .add => |value| .{ .add = .{ .name = value.name, .type = value.type, .nullable = value.nullable, .default = try cell(allocator, value.default), .max_characters = value.max_characters, .encoding = value.encoding, .collation = value.collation } },
            .drop => |value| .{ .drop = value },
            .rename => |value| .{ .rename = .{ .column = value.column, .name = value.name } },
            .default => |value| .{ .default = .{ .column = value.column, .value = try cell(allocator, value.value) } },
            .nullable => |value| .{ .nullable = .{ .column = value.column, .value = value.value } },
            .type => |value| .{ .type = .{ .column = value.column, .type = value.type, .max_characters = value.max_characters } },
            .physical => |value| .{ .physical = .{ .column = value.column, .encoding = value.encoding, .collation = value.collation } },
        };
    }
};
pub const Ddl = struct {
    binding: d.Binding,
    namespace: u64,
    name: []const u8,
    action: union(enum) { create: struct { owner: u64, schema: Binary }, alter: Change, rename: []const u8, drop },
    pub fn native(self: Ddl, allocator: std.mem.Allocator, configuration: D.Configuration) !D.Request {
        const intent: D.Intent = .{ .namespace = self.namespace, .name = try .init(self.name), .action = switch (self.action) {
            .create => |value| .{ .create = .{ .owner = value.owner, .schema = (try f.TableSchema.decode(allocator, try value.schema.decode(allocator, f.TableSchema.max_bytes))).schema } },
            .alter => |value| .{ .alter = try value.native(allocator) },
            .rename => |value| .{ .rename = try .init(value) },
            .drop => .drop,
        } };
        const result: D.Request = .{ .binding = self.binding, .intent = intent };
        try result.validate(allocator, configuration);
        return result;
    }
};
pub const RowChange = union(enum) {
    insert: Binary,
    update: struct { key: Binary, row: Binary },
    delete: Binary,
};
pub const Rows = struct {
    pub const json_schema_sequence_bounds = .{ .changes = P.max_changes };
    binding: d.Binding,
    interpretation: c.storage.TableDeclaration.Stored,
    schema: Binary,
    changes: []const RowChange,
    ingestion: P.Ingestion,
    pub fn digest(self: Rows, allocator: std.mem.Allocator) ![32]u8 {
        const Payload = struct { interpretation: c.storage.TableDeclaration.Stored, schema: Binary, changes: []const RowChange, ingestion: P.Ingestion };
        const bytes = try p.Json.valueAlloc(allocator, Payload{ .interpretation = self.interpretation, .schema = self.schema, .changes = self.changes, .ingestion = self.ingestion });
        defer allocator.free(bytes);
        if (bytes.len > max_request_bytes) return error.TablePayloadTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.direct.rows.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    /// Conversion is pure and uses a caller-owned bounded request arena. The
    /// storage owner checks the alleged immutable interpretation before admission.
    pub fn native(self: Rows, allocator: std.mem.Allocator) !c.storage.TableDmlIntent.Request {
        try self.binding.validate();
        try self.interpretation.validate();
        if (self.changes.len > P.max_changes) return error.TableBatchTooLarge;
        const schema_bytes = try self.schema.decode(allocator, f.TableSchema.max_bytes);
        const schema = (try f.TableSchema.decode(allocator, schema_bytes)).schema;
        if (schema.object != self.binding.target.object or !std.mem.eql(u8, &try schema.fingerprint(), &self.interpretation.schema_fingerprint)) return error.TableSchemaChanged;
        const changes = try allocator.alloc(P.Change, self.changes.len);
        var total: usize = 0;
        for (self.changes, changes) |value, *output| {
            switch (value) {
                .insert => |row| {
                    const bytes = try row.decode(allocator, @min(f.TableRow.max_bytes, max_work_bytes - total));
                    total += bytes.len;
                    output.* = .{ .put = .{ .row = (try f.TableRow.decode(allocator, schema, bytes)).row(), .expect = .absent } };
                },
                .update => |row| {
                    const key = try row.key.decode(allocator, @min(f.Collation.max_sort_key_bytes, max_work_bytes - total));
                    total += key.len;
                    const bytes = try row.row.decode(allocator, @min(f.TableRow.max_bytes, max_work_bytes - total));
                    total += bytes.len;
                    output.* = .{ .replace = .{ .key = key, .row = (try f.TableRow.decode(allocator, schema, bytes)).row() } };
                },
                .delete => |key| {
                    const bytes = try key.decode(allocator, @min(f.Collation.max_sort_key_bytes, max_work_bytes - total));
                    total += bytes.len;
                    output.* = .{ .remove = bytes };
                },
            }
        }
        const result: c.storage.TableDmlIntent.Request = .{ .binding = self.binding, .interpretation = self.interpretation, .changes = changes, .ingestion = self.ingestion };
        try result.validate();
        if (!std.mem.eql(u8, &self.binding.intent, &try self.digest(allocator))) return error.DataIdentityConflict;
        return result;
    }
};

pub const Snapshot = struct { object: d.Object, handle: P.SnapshotHandle };
pub const Action = union(enum) {
    initialize,
    describe,
    list: struct { namespace: u64, after: ?u64 },
    lookup: struct { namespace: u64, name: []const u8 },
    admit_ddl: Ddl,
    admit_rows: Rows,
    operation: struct { binding: d.Binding, command: enum { inspect, execute, cancel }, steps: u16 },
    pin: struct { object: d.Object, owner: d.Operation, expected: d.Position },
    snapshot: Snapshot,
    scan: struct { snapshot: Snapshot, after: ?P.SnapshotCursor, limits: P.ReadLimits },
    release: Snapshot,
};
pub const Request = struct {
    definition: p.Growth.Definition,
    connection: Connection,
    nonce: [16]u8,
    action: Action,
    proof: p.Authorization.Proof,
    pub const Input = struct { definition: p.Growth.Definition, connection: Connection, nonce: [16]u8, action: Action };
    pub fn context(value: Input, allocator: std.mem.Allocator) ![32]u8 {
        const bytes = try p.Json.valueAlloc(allocator, value);
        defer allocator.free(bytes);
        if (bytes.len > max_request_bytes) return error.TablePayloadTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.direct.request.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    pub fn input(self: Request) Input {
        return .{ .definition = self.definition, .connection = self.connection, .nonce = self.nonce, .action = self.action };
    }
    /// Transport hints classify a request attempt; the server validates its
    /// parsed action and current rights before using reserved admission.
    pub fn transport(self: Request) struct { operation: []const u8, mutation: bool, control: ?[]const u8 } {
        const mutation = switch (self.action) {
            .initialize, .admit_ddl, .admit_rows, .pin, .release => true,
            .operation => |value| value.command != .inspect,
            else => false,
        };
        const control = self.action == .release or (self.action == .operation and self.action.operation.command != .execute);
        return .{ .operation = @tagName(self.action), .mutation = mutation, .control = if (control) "table" else null };
    }
    pub fn validate(self: Request, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.proof.claim.validate();
        const claim = self.proof.claim;
        const connection = self.connection;
        if (claim.realm != connection.scope.realm or claim.principal != connection.principal or claim.role != connection.role or claim.audience != connection.audience or
            !std.mem.eql(u8, &claim.context, &try context(self.input(), allocator))) return error.InvalidAuthorizationCredential;
        switch (self.action) {
            .initialize, .describe => {},
            .list => |value| {
                try c.Model.nativeId(value.namespace);
                if (value.after) |after| if (after == 0) return error.InvalidCatalogCursor;
            },
            .lookup => |value| {
                try c.Model.nativeId(value.namespace);
                _ = try c.TableAuthority.Name.init(value.name);
            },
            inline .admit_ddl, .admit_rows => |value| try connection.binding(value.binding),
            .operation => |value| {
                try connection.binding(value.binding);
                if (value.steps == 0 or value.steps > 256) return error.InvalidCatalogStepBudget;
            },
            .pin => |value| {
                try connection.object(value.object);
                try connection.owner(value.owner);
                try value.expected.validate();
            },
            inline .snapshot, .release => |value| try validateSnapshot(connection, value),
            .scan => |value| {
                try validateSnapshot(connection, value.snapshot);
                try value.limits.validate();
                if (value.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                if (value.after) |cursor| if (!std.meta.eql(cursor.source, value.snapshot.handle.content)) return error.InvalidTableCursor;
            },
        }
    }
    pub fn parse(allocator: std.mem.Allocator, bytes: []const u8) !std.json.Parsed(Request) {
        try f.Types.Json.preflight(bytes, .{ .bytes = max_request_bytes, .depth = 96, .tokens = 1024 * 1024, .fields = 256 });
        const parsed = try p.Json.parseFromSlice(Request, allocator, bytes);
        errdefer parsed.deinit();
        try parsed.value.validate(allocator);
        return parsed;
    }
};
fn validateSnapshot(connection: Connection, value: Snapshot) !void {
    try connection.object(value.object);
    try connection.owner(value.handle.owner);
    try value.handle.content.validate();
}

pub const Definition = struct {
    interpretation: c.storage.TableDeclaration.Stored,
    namespace: u64,
    name: c.TableAuthority.Name,
    position: d.Position,
    changed_lsn: u64,
    row_count: u64,
    schema: Binary,
};
pub const Source = struct { snapshot: Snapshot, interpretation: c.storage.TableDeclaration.Stored, accepted: d.Position, changed_lsn: u64, row_count: u64, schema: Binary };
pub const Page = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 8 };
    snapshot: Snapshot,
    interpretation: c.storage.TableDeclaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    total_rows: u64,
    rows: []const Binary,
    encoded_bytes: u32,
    next: ?P.SnapshotCursor,
};
pub const Result = union(enum) {
    initialized,
    description: D.Configuration,
    list: struct { entries: [8]?D.Listed, next: ?u64, directory_position: d.Position, consistency: enum { independent } },
    lookup: ?Definition,
    ddl: D.Observation,
    rows: P.OperationState,
    pin: P.SnapshotHandle,
    snapshot: Source,
    page: Page,
    released,
};
pub const Response = struct { definition: p.Growth.Definition, context: [32]u8, policy_revision: u64, result: Result };

test {
    _ = @import("direct_table_protocol_test.zig");
}

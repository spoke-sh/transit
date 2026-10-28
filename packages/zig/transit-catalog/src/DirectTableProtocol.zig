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

pub const KeyBound = struct { key: Binary, inclusive: bool };
pub const KeyInterval = struct {
    lower: ?KeyBound,
    upper: ?KeyBound,
    /// Decoded bound bytes belong to the supplied request/response arena.
    pub fn native(self: KeyInterval, allocator: std.mem.Allocator) !P.KeyRange {
        const result: P.KeyRange = .{
            .lower = if (self.lower) |bound| .{ .key = try bound.key.decode(allocator, f.Collation.max_sort_key_bytes), .inclusive = bound.inclusive } else null,
            .upper = if (self.upper) |bound| .{ .key = try bound.key.decode(allocator, f.Collation.max_sort_key_bytes), .inclusive = bound.inclusive } else null,
        };
        try result.validate();
        return result;
    }
    pub fn encode(allocator: std.mem.Allocator, value: P.KeyRange) !KeyInterval {
        try value.validate();
        return .{
            .lower = if (value.lower) |bound| .{ .key = try Binary.encode(allocator, bound.key), .inclusive = bound.inclusive } else null,
            .upper = if (value.upper) |bound| .{ .key = try Binary.encode(allocator, bound.key), .inclusive = bound.inclusive } else null,
        };
    }
};
pub const KeyCursor = struct {
    source: d.Content,
    interval: [32]u8,
    after: Binary,
    pub fn native(self: KeyCursor, allocator: std.mem.Allocator) !P.KeyRange.Cursor {
        try self.source.validate();
        const bytes = try self.after.decode(allocator, f.Collation.max_sort_key_bytes);
        defer allocator.free(bytes);
        if (bytes.len == 0) return error.InvalidTableCursor;
        return .{ .source = self.source, .interval = self.interval, .after = try P.KeyRange.Key.init(bytes) };
    }
    pub fn encode(allocator: std.mem.Allocator, value: P.KeyRange.Cursor) !KeyCursor {
        try value.after.validate();
        return .{ .source = value.source, .interval = value.interval, .after = try Binary.encode(allocator, value.after.slice()) };
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
    fn intent(self: Ddl, allocator: std.mem.Allocator) !D.Intent {
        return .{ .namespace = self.namespace, .name = try .init(self.name), .action = switch (self.action) {
            .create => |value| .{ .create = .{ .owner = value.owner, .schema = (try f.TableSchema.decode(allocator, try value.schema.decode(allocator, f.TableSchema.max_bytes))).schema } },
            .alter => |value| .{ .alter = try value.native(allocator) },
            .rename => |value| .{ .rename = try .init(value) },
            .drop => .drop,
        } };
    }
    /// The same canonical intent used by admission, independent of credentials.
    /// Child decoding belongs to the supplied request arena.
    pub fn digest(self: Ddl, allocator: std.mem.Allocator) ![32]u8 {
        return (try self.intent(allocator)).digest(allocator);
    }
    pub fn validate(self: Ddl, allocator: std.mem.Allocator, connection: Connection) !void {
        try connection.binding(self.binding);
        const decoded = try self.intent(allocator);
        try decoded.validate(self.binding);
        if (!std.mem.eql(u8, &try decoded.digest(allocator), &self.binding.intent)) return error.DataIdentityConflict;
    }
    pub fn native(self: Ddl, allocator: std.mem.Allocator, configuration: D.Configuration) !D.Request {
        const result: D.Request = .{ .binding = self.binding, .intent = try self.intent(allocator) };
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
    pub const insertIdentity = c.storage.TableDmlIntent.insertIdentity;
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

/// A complete typed UPDATE/DELETE plan evaluated privately by the Table owner.
/// INSERT uses Rows so point ingestion retains its WAL path.
pub const Statement = struct {
    binding: d.Binding,
    interpretation: c.storage.TableDeclaration.Stored,
    schema: Binary,
    plan: Binary,
    pub fn digest(self: Statement, allocator: std.mem.Allocator) ![32]u8 {
        const Payload = struct { interpretation: c.storage.TableDeclaration.Stored, schema: Binary, plan: Binary };
        const bytes = try p.Json.valueAlloc(allocator, Payload{ .interpretation = self.interpretation, .schema = self.schema, .plan = self.plan });
        defer allocator.free(bytes);
        if (bytes.len > max_request_bytes) return error.TablePayloadTooLarge;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.table.direct.statement.v1\x00");
        hash.update(bytes);
        return hash.finalResult();
    }
    /// All decoded values belong to the bounded request arena.
    pub fn native(self: Statement, allocator: std.mem.Allocator) !c.storage.TableDmlIntent.Request {
        try self.binding.validate();
        try self.interpretation.validate();
        const schema = (try f.TableSchema.decode(allocator, try self.schema.decode(allocator, f.TableSchema.max_bytes))).schema;
        if (schema.object != self.binding.target.object or !std.mem.eql(u8, &try schema.fingerprint(), &self.interpretation.schema_fingerprint)) return error.TableSchemaChanged;
        const plan = try f.TableDmlCodec.decode(allocator, schema, try self.plan.decode(allocator, max_work_bytes));
        const result: c.storage.TableDmlIntent.Request = .{ .binding = self.binding, .interpretation = self.interpretation, .changes = &.{}, .ingestion = .bulk, .statement = plan.plan };
        try result.validate();
        if (!std.mem.eql(u8, &self.binding.intent, &try self.digest(allocator))) return error.DataIdentityConflict;
        return result;
    }
};

pub const Snapshot = struct { object: d.Object, handle: P.SnapshotHandle };
/// Exact selection requires the supplied frontier. Current selection freezes
/// the first authorized frontier at or above it, under an exact interpretation.
/// Repeating either selection recovers the same retained cut for this owner.
pub const CaptureSelection = enum(u8) { exact = 1, current = 2 };
pub const Acquisition = struct { object: d.Object, owner: d.Operation, expected: d.Position, selection: CaptureSelection = .exact };
pub const Historical = struct { object: d.Object, point: P.HistoryPoint };
pub const HistoryRequest = struct { snapshot: Snapshot, from: d.Position, through: d.Position, frames: u8 };
pub const ReadCheck = union(enum) { access: D.AccessRequest, snapshot: Snapshot };
/// Read current data only while this exact definition and original logical
/// basis remain valid. The seek key does not retain data or prove prior reads.
pub const CurrentRead = struct {
    namespace: u64,
    interpretation: d.Definition,
    expected: d.Position,
    selection: union(enum) { key: Binary, rows: struct { after: ?f.TableRow.Identity, limits: P.ReadLimits } },
};
pub const ColumnScan = struct {
    pub const json_schema_sequence_bounds = .{ .columns = 128 };
    snapshot: Snapshot,
    columns: []const u16,
    after: ?P.SnapshotCursor,
    limits: P.ReadLimits,
    pub fn projection(self: ColumnScan) !f.TableProjection {
        if (self.columns.len == 0 or self.columns.len > f.TableSchema.max_columns) return error.InvalidProjection;
        var indices: [f.TableSchema.max_columns]u8 = undefined;
        for (self.columns, indices[0..self.columns.len]) |value, *index| {
            if (value >= f.TableSchema.max_columns) return error.InvalidProjection;
            index.* = @intCast(value);
        }
        return f.TableProjection.fromColumns(indices[0..self.columns.len]);
    }
};
/// FQP1 is decoded against the authorized retained schema and complete source
/// basis. The declared fingerprint must match that canonical decoded plan.
pub const FilterScan = struct {
    snapshot: Snapshot,
    plan: Binary,
    fingerprint: [32]u8,
    after: ?P.SnapshotCursor,
    limits: P.ReadLimits,
    /// The request arena owns all decoded plan values. Only the authorized
    /// source owner supplies this basis and schema; caller bytes cannot do so.
    pub fn decodePlan(self: FilterScan, arena: std.mem.Allocator, schema: f.TableSchema.Schema, basis: [32]u8) !f.LogicalQuery.Plan {
        var fields: [f.TableSchema.max_columns]f.Types.Field = undefined;
        const bytes = try self.plan.decode(arena, f.LogicalPlanCodec.max_bytes);
        const plan = f.LogicalPlanCodec.decodeInto(arena, try schema.rowType(&fields), basis, bytes) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return error.InvalidPlanEncoding,
        };
        if (!std.mem.eql(u8, &try plan.fingerprint(), &self.fingerprint)) return error.SourceChanged;
        _ = try f.TableProjection.fromPlan(schema, plan);
        return plan;
    }
};
pub const Action = union(enum) {
    pub const json_schema_sequence_bounds = .{ .check_set = 16 };
    client_token: c.DirectClientToken.Request,
    initialize,
    describe,
    namespace: u64,
    namespaces: struct { after: ?u64 },
    namespace_preview: c.DirectNamespace.Binding,
    namespace_operation: struct { binding: c.DirectNamespace.Binding, command: c.DirectNamespace.Command, steps: u16 },
    dependency_operation: struct { binding: c.DirectDependency.Binding, command: c.DirectDependency.Command },
    dependency_state: c.DirectDependency.Edge,
    dependencies: struct { selection: c.DirectDependency.Selection, cursor: ?c.DirectDependency.Cursor, authority: c.DirectDependency.Authority },
    resource_preview: c.DirectResource.Binding,
    resource_operation: struct { binding: c.DirectResource.Binding, command: c.DirectResource.Command, steps: u16, signed_allocation: ?c.DirectResource.SignedAllocation },
    resource_lookup: struct { namespace: u64, name: []const u8 },
    resource_list: struct { namespace: u64, after: ?u64 },
    check: D.AccessRequest,
    /// All requirements are checked together before disclosing the response.
    check_set: []const ReadCheck,
    list: struct { namespace: u64, after: ?u64 },
    lookup: struct { namespace: u64, name: []const u8 },
    /// One read-only current observation; rows are optional and never resumable.
    observe: struct { namespace: u64, interpretation: d.Definition, rows: ?P.ReadLimits },
    storage: struct { object: d.Object, pending_limit: u16 },
    flush: D.FlushTarget,
    read_current: CurrentRead,
    read_authority: d.Object,
    name_assertion: struct { binding: c.NameAssertion.Binding, command: c.NameAssertion.Command },
    preview: Ddl,
    name_preview: c.NameAssertion.Binding,
    preview_rows: Rows,
    preview_statement: Statement,
    stage: struct { namespace: u64, intent: c.DirectTableIntent.Saved },
    admit_saved: c.DirectTableIntent.Reference,
    admit_ddl: Ddl,
    admit_rows: Rows,
    admit_statement: Statement,
    operation: struct { binding: d.Binding, command: enum { inspect, execute, cancel }, steps: u16 },
    pin: Acquisition,
    retain_history: Acquisition,
    pin_status: struct { object: d.Object, owner: d.Operation },
    snapshot: Snapshot,
    history_start: Snapshot,
    history_source: Historical,
    history: HistoryRequest,
    history_scan: struct { source: Historical, after: ?P.SnapshotCursor, limits: P.ReadLimits },
    read_key: struct { snapshot: Snapshot, key: Binary },
    scan: struct { snapshot: Snapshot, after: ?P.SnapshotCursor, limits: P.ReadLimits },
    column_scan: ColumnScan,
    filter_scan: FilterScan,
    key_range: struct { snapshot: Snapshot, interval: KeyInterval, after: ?KeyCursor, limits: P.ReadLimits },
    release: Snapshot,
};
pub const Request = struct {
    definition: p.Growth.Definition,
    connection: Connection,
    nonce: [16]u8,
    action: Action,
    delegation: ?c.DirectReadDelegation,
    closure: ?c.DirectReadDelegation.Closure = null,
    borrow: ?c.DirectReadDelegation.Borrow = null,
    proof: p.Authorization.Proof,
    pub const Input = struct { definition: p.Growth.Definition, connection: Connection, nonce: [16]u8, action: Action, delegation: ?c.DirectReadDelegation, closure: ?c.DirectReadDelegation.Closure = null, borrow: ?c.DirectReadDelegation.Borrow = null };
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
        return .{ .definition = self.definition, .connection = self.connection, .nonce = self.nonce, .action = self.action, .delegation = self.delegation, .closure = self.closure, .borrow = self.borrow };
    }
    /// Transport hints classify a request attempt; the server validates its
    /// parsed action and current rights before using reserved admission.
    pub fn transport(self: Request) struct { operation: []const u8, mutation: bool, control: ?[]const u8 } {
        const mutation = switch (self.action) {
            .client_token => |value| value == .bind,
            .initialize, .stage, .admit_saved, .admit_ddl, .admit_rows, .admit_statement, .pin, .retain_history, .release, .flush => true,
            .operation => |value| value.command != .inspect,
            .name_assertion => |value| value.command != .inspect,
            .namespace_operation => |value| value.command != .inspect,
            .dependency_operation => |value| value.command != .inspect,
            .resource_operation => |value| value.command != .inspect,
            else => false,
        };
        const control = self.action == .release or self.action == .pin_status or self.action == .namespace_operation or self.action == .dependency_operation or (self.action == .resource_operation and (self.action.resource_operation.command == .inspect or self.action.resource_operation.command == .cancel)) or (self.action == .operation and self.action.operation.command != .execute) or (self.action == .name_assertion and self.action.name_assertion.command != .accept);
        return .{ .operation = @tagName(self.action), .mutation = mutation, .control = if (control) "table" else null };
    }
    pub fn validate(self: Request, allocator: std.mem.Allocator) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        try self.proof.claim.validate();
        const claim = self.proof.claim;
        const connection = self.connection;
        if (self.delegation) |delegation| {
            try delegation.validate(allocator);
            if (!std.meta.eql(delegation.binding.connection, connection)) return error.InvalidTableDelegation;
            try delegation.allow(self.action);
        }
        if (self.borrow) |borrow| {
            if (self.closure != null) return error.InvalidTableDelegation;
            const original = self.delegation orelse return error.InvalidTableDelegation;
            _ = try borrow.proof(original, allocator);
            try borrow.allow(self.action);
        }
        if (self.closure) |closure| {
            const original = self.delegation orelse return error.InvalidTableDelegation;
            _ = try closure.proof(original, allocator);
            try c.DirectReadDelegation.Closure.allow(self.action);
        }
        const principal = if (self.borrow) |borrow| borrow.binding.executor else if (self.delegation) |delegation| delegation.binding.executor else connection.principal;
        const role: ?u64 = if (self.delegation != null) null else connection.role;
        if (claim.realm != connection.scope.realm or claim.principal != principal or claim.role != role or claim.audience != connection.audience or
            !std.mem.eql(u8, &claim.context, &try context(self.input(), allocator))) return error.InvalidAuthorizationCredential;
        switch (self.action) {
            .client_token => |value| {
                try value.validate();
                if (!std.meta.eql(value.key().connection, connection)) return error.CatalogIdentityConflict;
            },
            .resource_preview => |binding| {
                try binding.validate();
                if (!std.meta.eql(binding.connection, self.connection)) return error.CatalogIdentityConflict;
            },
            .resource_operation => |value| {
                try value.binding.validate();
                if (!std.meta.eql(value.binding.connection, connection)) return error.CatalogIdentityConflict;
                if (value.steps == 0 or value.steps > 256) return error.InvalidCatalogStepBudget;
                if (value.signed_allocation) |signed| {
                    if (value.command != .execute or value.binding.action != .create) return error.InvalidNamedResourceOperation;
                    try signed.allocation.validate();
                }
            },
            .dependency_operation => |value| {
                try value.binding.validate();
                if (!std.meta.eql(value.binding.connection, connection)) return error.CatalogIdentityConflict;
            },
            .dependency_state => |edge| {
                try edge.validate();
                try connection.object(edge.source.object);
            },
            .dependencies => |value| {
                switch (value.selection) {
                    .dependents => |object| try connection.object(object),
                    .dependencies => |object| {
                        try object.validate();
                        if (object.scope.realm != connection.scope.realm or object.branch != 1) return error.CatalogDenied;
                    },
                }
                if (value.cursor) |cursor| {
                    try cursor.position.validate();
                    if (cursor.position.next_lsn == 0 or !std.meta.eql(cursor.selection, value.selection) or cursor.authority != value.authority) return error.InvalidCatalogCursor;
                }
            },
            .namespace_preview => |binding| {
                try binding.validate();
                if (!std.meta.eql(binding.connection, connection)) return error.CatalogIdentityConflict;
            },
            .namespace_operation => |value| {
                try value.binding.validate();
                if (!std.meta.eql(value.binding.connection, connection)) return error.CatalogIdentityConflict;
                if (value.steps == 0 or value.steps > 256) return error.InvalidCatalogStepBudget;
            },
            .initialize, .describe => {},
            .name_assertion => |value| {
                try value.binding.validate();
                if (!std.meta.eql(value.binding.connection, connection)) return error.CatalogIdentityConflict;
            },
            .stage => |value| {
                try c.Model.nativeId(value.namespace);
                if (!std.meta.eql(value.intent.connection, connection)) return error.CatalogIdentityConflict;
                try value.intent.validate(allocator);
                if (value.intent.work == .ddl and value.intent.work.ddl.namespace != value.namespace) return error.DataIdentityConflict;
            },
            .admit_saved => |value| {
                try value.validate();
                if (!std.meta.eql(value.connection, connection)) return error.CatalogIdentityConflict;
            },
            .namespace => |id| try c.Model.nativeId(id),
            .namespaces => |value| if (value.after) |after| if (after == 0) return error.InvalidCatalogCursor,
            .check => |value| try value.validate(connection.scope, connection.branch),
            .check_set => |values| {
                if (values.len == 0 or values.len > 16) return error.InvalidTableReadBudget;
                for (values) |value| switch (value) {
                    .access => |access| try access.validate(connection.scope, connection.branch),
                    .snapshot => |snapshot| try validateSnapshot(connection, snapshot),
                };
            },
            inline .list, .resource_list => |value| {
                try c.Model.nativeId(value.namespace);
                if (value.after) |after| if (after == 0) return error.InvalidCatalogCursor;
            },
            inline .lookup, .resource_lookup => |value| {
                try c.Model.nativeId(value.namespace);
                _ = try c.TableAuthority.Name.init(value.name);
            },
            .observe => |value| {
                try c.Model.nativeId(value.namespace);
                try value.interpretation.validate();
                try connection.object(value.interpretation.object);
                if (value.rows) |limits| try limits.validate();
            },
            .storage => |value| {
                try connection.object(value.object);
                if (value.pending_limit == 0 or value.pending_limit > P.max_changes) return error.InvalidTableReadBudget;
            },
            .flush => |value| {
                try connection.object(value.object);
                try value.through.validate();
            },
            .read_current => |value| {
                try c.Model.nativeId(value.namespace);
                try value.interpretation.validate();
                try connection.object(value.interpretation.object);
                try value.expected.validate();
                if (value.expected.next_lsn == 0) return error.InvalidTableBasis;
                switch (value.selection) {
                    .key => |binary| {
                        const key = try binary.decode(allocator, f.Collation.max_sort_key_bytes);
                        defer allocator.free(key);
                        if (key.len == 0) return error.InvalidTableKey;
                    },
                    .rows => |value_rows| {
                        try value_rows.limits.validate();
                        if (value_rows.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                        if (value_rows.after) |after| try after.validate();
                    },
                }
            },
            .read_authority => |value| try connection.object(value),
            .name_preview => |binding| {
                try binding.validate();
                if (!std.meta.eql(binding.connection, connection)) return error.CatalogIdentityConflict;
            },
            inline .preview, .admit_ddl => |value| {
                try connection.binding(value.binding);
                if (!std.mem.eql(u8, @tagName(value.binding.action), @tagName(value.action))) return error.InvalidDirectCatalogOperation;
            },
            inline .preview_rows, .preview_statement, .admit_rows, .admit_statement => |value| try connection.binding(value.binding),
            .operation => |value| {
                try connection.binding(value.binding);
                if (value.steps == 0 or value.steps > 256) return error.InvalidCatalogStepBudget;
            },
            inline .pin, .retain_history => |value| {
                try connection.object(value.object);
                try connection.owner(value.owner);
                try value.expected.validate();
                if (value.expected.next_lsn == 0) return error.InvalidTableBasis;
                if (value.selection == .current and (self.action == .retain_history or self.delegation == null)) return error.InvalidTableDelegation;
            },
            .pin_status => |value| {
                try connection.object(value.object);
                try connection.owner(value.owner);
            },
            inline .snapshot, .history_start, .release => |value| try validateSnapshot(connection, value),
            .history_source => |value| try validateHistorical(connection, value),
            .history => |value| {
                try validateSnapshot(connection, value.snapshot);
                try value.from.validate();
                try value.through.validate();
                if (value.from.next_lsn == 0 or value.from.partition != value.through.partition or value.from.next_lsn > value.through.next_lsn) return error.InvalidTableBasis;
                if (value.frames == 0 or value.frames > 8) return error.InvalidTableReadBudget;
            },
            .history_scan => |value| {
                try validateHistorical(connection, value.source);
                try value.limits.validate();
                if (value.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                if (value.after) |cursor| if (!std.meta.eql(cursor.source, try value.source.point.cursorSource())) return error.InvalidTableCursor;
            },
            .read_key => |value| {
                try validateSnapshot(connection, value.snapshot);
                const key = try value.key.decode(allocator, f.Collation.max_sort_key_bytes);
                defer allocator.free(key);
                if (key.len == 0) return error.InvalidTableKey;
            },
            .scan => |value| {
                try validateSnapshot(connection, value.snapshot);
                try value.limits.validate();
                if (value.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                if (value.after) |cursor| if (!std.meta.eql(cursor.source, value.snapshot.handle.content)) return error.InvalidTableCursor;
            },
            .column_scan => |value| {
                try validateSnapshot(connection, value.snapshot);
                try value.limits.validate();
                if (value.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                const selected = try value.projection();
                if (value.after) |cursor| if (!std.meta.eql(cursor.source, try selected.cursorSource(value.snapshot.handle.content))) return error.InvalidTableCursor;
            },
            .filter_scan => |value| {
                try validateSnapshot(connection, value.snapshot);
                try value.limits.validate();
                if (value.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                const bytes = try value.plan.decode(allocator, f.LogicalPlanCodec.max_bytes);
                defer allocator.free(bytes);
                if (bytes.len == 0) return error.InvalidPlanEncoding;
                if (value.after) |cursor| if (!std.meta.eql(cursor.source, try P.filteredCursorFingerprint(value.snapshot.handle, value.fingerprint))) return error.InvalidTableCursor;
            },
            .key_range => |value| {
                try validateSnapshot(connection, value.snapshot);
                try value.limits.validate();
                if (value.limits.encoded_bytes > max_page_bytes) return error.InvalidTableReadBudget;
                var arena = std.heap.ArenaAllocator.init(allocator);
                defer arena.deinit();
                const interval = try value.interval.native(arena.allocator());
                if (value.after) |encoded| {
                    const cursor = try encoded.native(arena.allocator());
                    if (!std.meta.eql(cursor.source, value.snapshot.handle.content) or !std.mem.eql(u8, &cursor.interval, &try interval.fingerprint()) or
                        !interval.contains(cursor.after.slice())) return error.InvalidTableCursor;
                }
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
fn validateHistorical(connection: Connection, value: Historical) !void {
    try validateSnapshot(connection, .{ .object = value.object, .handle = value.point.lease });
    _ = try value.point.cursorSource();
}

pub const Definition = struct {
    interpretation: c.storage.TableDeclaration.Stored,
    namespace: u64,
    authorization: u64,
    name: c.TableAuthority.Name,
    position: d.Position,
    changed_lsn: u64,
    row_count: u64,
    schema: Binary,
};
pub const Source = struct { snapshot: Snapshot, interpretation: c.storage.TableDeclaration.Stored, accepted: d.Position, changed_lsn: u64, row_count: u64, schema: Binary, authority: c.DirectReadAuthority };
pub const CurrentPage = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 8 };
    rows: []const Binary,
    encoded_bytes: u32,
    more: bool,
};
pub const Current = struct { definition: Definition, authority: c.DirectReadAuthority, page: ?CurrentPage };
pub const CurrentReadResult = struct {
    pub const RowSuffix = struct {
        pub const json_schema_sequence_bounds = .{ .rows = 8 };
        rows: []const Binary,
        encoded_bytes: u32,
        next: ?f.TableRow.Identity,
    };
    definition: Definition,
    authority: c.DirectReadAuthority,
    selection: union(enum) { key: ?Binary, rows: RowSuffix },
};
pub const HistorySource = struct { point: P.HistoryPoint, source: Source };
pub const HistoryEntry = struct { point: P.HistoryPoint, interpretation: c.storage.TableDeclaration.Stored, changed_lsn: u64, row_count: u64, receipt: P.HistoryReceipt };
pub const HistoryPage = struct {
    pub const json_schema_sequence_bounds = .{ .entries = 8 };
    snapshot: Snapshot,
    through: d.Position,
    next: d.Position,
    scanned: u8,
    entries: []const HistoryEntry,
};
pub const PinState = struct {
    interpretation: d.Definition,
    position: d.Position,
    retired: bool,
    handle: ?P.SnapshotHandle,
    released: bool,
    authority: c.DirectReadAuthority,
};
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
pub const FilteredPage = struct {
    page: Page,
    examined: u8,
    offsets: [8]u8,
    failure: ?struct {
        identity: f.TableRow.Identity,
        column: u8,
        instruction: u8,
        outcome: enum { type_error, conflict },
    },
    /// Envelope checks independent of schema decoding and traversal progress.
    pub fn validate(self: FilteredPage) !void {
        if (self.examined > 8 or self.page.rows.len > self.examined or self.examined > self.page.total_rows) return error.InvalidTableResponse;
        var previous: u8 = 0;
        for (self.offsets, 0..) |offset, i| {
            if (i < self.page.rows.len) {
                if (offset <= previous or offset > self.examined) return error.InvalidTableResponse;
                previous = offset;
            } else if (offset != 0) return error.InvalidTableResponse;
        }
        if (self.failure) |failure| {
            if (self.page.next != null or self.examined == 8 or self.examined == self.page.total_rows or failure.column >= f.TableSchema.max_columns or failure.instruction >= f.LogicalPredicate.Program.max_instructions) return error.InvalidTableResponse;
            _ = try failure.identity.encode();
        } else if (self.page.next != null and self.examined == 0) return error.InvalidTableResponse;
    }
};
pub const KeyRangePage = struct {
    pub const json_schema_sequence_bounds = .{ .rows = 8 };
    snapshot: Snapshot,
    interpretation: c.storage.TableDeclaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    total_rows: u64,
    rows: []const Binary,
    encoded_bytes: u32,
    next: ?KeyCursor,
};
/// A key lookup is complete for that key, not evidence of a full Table scan.
pub const Point = struct {
    snapshot: Snapshot,
    interpretation: c.storage.TableDeclaration.Stored,
    accepted: d.Position,
    changed_lsn: u64,
    total_rows: u64,
    row: ?Binary,
};
pub const Result = union(enum) {
    client_token: ?c.DirectClientToken.Receipt,
    initialized,
    description: D.Configuration,
    namespace: ?c.TableAuthority.Schema,
    namespaces: struct { entries: [8]?c.TableAuthority.Schema, next: ?u64, directory_position: d.Position },
    namespace_preview: c.DirectNamespace.Preview,
    namespace_operation: c.DirectNamespace.Observation,
    dependency_operation: c.DirectDependency.Observation,
    dependency_state: c.DirectDependency.State,
    dependencies: c.DirectDependency.Page,
    resource_preview: c.DirectResource.Preview,
    resource_operation: c.DirectResource.Observation,
    resource_lookup: ?D.ResourceView,
    resource_list: struct { entries: [8]?D.ResourceView, next: ?u64, position: d.Position },
    checked,
    staged: c.DirectTableIntent.Reference,
    list: struct { entries: [8]?D.Listed, next: ?u64, directory_position: d.Position, consistency: enum { independent } },
    lookup: ?Definition,
    observation: Current,
    storage: D.StorageObservation,
    flush: D.FlushObservation,
    current_read: CurrentReadResult,
    read_authority: c.DirectReadAuthority,
    name_assertion: c.NameAssertion.Observation,
    preview: D.Preview,
    name_preview: c.NameAssertion.Preview,
    row_preview: D.RowPreview,
    ddl: D.Observation,
    rows: P.OperationState,
    pin: P.SnapshotHandle,
    pin_state: PinState,
    snapshot: Source,
    history_source: HistorySource,
    history: HistoryPage,
    history_page: struct { point: P.HistoryPoint, page: Page },
    point: Point,
    page: Page,
    filtered_page: FilteredPage,
    key_range: KeyRangePage,
    released,
};
pub const Response = struct { definition: p.Growth.Definition, context: [32]u8, policy_revision: u64, subject: p.Authorization.Verified, result: Result };

test {
    _ = @import("direct_table_protocol_test.zig");
}

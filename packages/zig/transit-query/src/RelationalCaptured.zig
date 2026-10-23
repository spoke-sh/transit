//! Retained Table vector for the shared relational executor. Catalog policy is
//! read from registered current views and guarded at the enclosing native turn;
//! data and schemas are reopened only from the originally retained versions.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const p = q.protocol;
const f = q.fuze;
const r = f.Relational;
const e = f.RelationalExecution;
const Self = @This();
turn: *s.Turn,
allocator: std.mem.Allocator,
bundle: q.RelationalBundle,
principal: u64,
vector: Vector,
current: [r.max_sources]?s.Turn.Captured = @splat(null),
data: [r.max_sources]?s.Turn.Retained = @splat(null),
bases: [r.max_sources]q.TableSource.Basis = undefined,
cuts: [r.max_sources]r.Cut = undefined,
reads: u64 = 0,
read_limit: u64,
// Source row decoding and Table/index traversal use bounded caller-owned frames.
pub const resident_bytes = @sizeOf(Self) + 2 * f.TableRow.max_bytes + 2 * f.TableSchema.max_bytes;

pub const Entry = struct { version: p.Growth.ReadVersionId, revision: u64, head: [32]u8 };
pub const Vector = struct {
    request: [32]u8,
    count: u8,
    entries: [r.max_sources]Entry = undefined,
    pub fn validate(self: Vector, bundle: q.RelationalBundle) !void {
        try bundle.validate();
        if (bundle.plan.lifetime != .captured) return error.InvalidRelationalCapture;
        if (self.count != bundle.sources.len or !std.mem.eql(u8, &self.request, &try bundle.fingerprint())) return error.RelationalSourceChanged;
        for (self.entries[0..self.count], bundle.sources, 0..) |entry, source, i| {
            try p.Growth.validateVersionId(entry.version);
            if (entry.revision == 0) return error.InvalidRelationalCapture;
            for (self.entries[0..i], bundle.sources[0..i]) |previous, declared| {
                if (entry.version.pid != previous.version.pid or entry.version.input != previous.version.input) return error.InvalidRelationalCapture;
                if (source.scope.resource == declared.scope.resource) {
                    if (!std.meta.eql(entry.version, previous.version) or entry.revision != previous.revision) return error.InvalidRelationalCapture;
                } else if (entry.version.index == previous.version.index) return error.InvalidRelationalCapture;
            }
        }
    }
    pub fn encode(self: Vector, bundle: q.RelationalBundle) !p.Value {
        try self.validate(bundle);
        var bytes: [p.Value.max_bytes]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("RQV1");
        try writer.writeAll(&q.catalog.TableMetadata.definition());
        try writer.writeAll(&self.request);
        try writer.writeByte(self.count);
        for (self.entries[0..self.count]) |entry| {
            try writer.writeInt(u64, entry.version.pid, .little);
            try writer.writeInt(u64, entry.version.input, .little);
            try writer.writeByte(entry.version.index);
            try writer.writeInt(u64, entry.revision, .little);
            try writer.writeAll(&entry.head);
        }
        return p.Value.init(writer.buffered());
    }
    pub fn decode(bundle: q.RelationalBundle, value: p.Value) !Vector {
        const result = try decodeStored(value);
        if (!(try result.encode(bundle)).eql(value)) return error.InvalidRelationalCapture;
        return result;
    }
    /// Accepted vector records remain sufficient to release pins even when the
    /// requester publication or a source has become unreadable.
    pub fn decodeStored(value: p.Value) !Vector {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "RQV1")) return error.InvalidRelationalCapture;
        if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
        var result: Vector = .{ .request = (try reader.takeArray(32)).*, .count = try reader.takeByte() };
        if (result.count == 0 or result.count > r.max_sources) return error.InvalidRelationalCapture;
        for (result.entries[0..result.count]) |*entry| entry.* = .{ .version = .{ .pid = try reader.takeInt(u64, .little), .input = try reader.takeInt(u64, .little), .index = try reader.takeByte() }, .revision = try reader.takeInt(u64, .little), .head = (try reader.takeArray(32)).* };
        if (reader.bufferedLen() != 0) return error.InvalidRelationalCapture;
        for (result.entries[0..result.count]) |entry| {
            try p.Growth.validateVersionId(entry.version);
            if (entry.revision == 0) return error.InvalidRelationalCapture;
        }
        return result;
    }
    pub fn boundCuts(self: Vector, bundle: q.RelationalBundle, output: *[r.max_sources]r.Cut) !void {
        try self.validate(bundle);
        for (self.entries[0..self.count], bundle.plan.sources, 0..) |entry, source, i| output[i] = .{ .domain = .native_resource, .resource = source.resource, .revision = entry.revision, .commitment = commitment(source.realm, source.resource, entry), .schema = try source.schema.fingerprint() };
        try (r.Bound{ .plan = bundle.plan, .cuts = output[0..self.count] }).validate();
    }
    /// Closure releases each distinct pin once. Native release deliberately does
    /// not depend on continuing source read rights; no retained read occurs here.
    pub fn release(self: Vector, bundle: q.RelationalBundle, turn: *s.Turn) !void {
        try self.validate(bundle);
        try self.releaseStored(turn, self.entries[0].version.input);
    }
    pub fn releaseStored(self: Vector, turn: *s.Turn, input: u64) !void {
        const before = turn.decision;
        errdefer turn.decision = before;
        if (self.count == 0 or self.count > r.max_sources) return error.InvalidRelationalCapture;
        for (self.entries[0..self.count]) |entry| {
            try p.Growth.validateVersionId(entry.version);
            if (entry.version.pid != turn.delivery.pid or entry.version.input != input) return error.InvalidRelationalCapture;
        }
        for (self.entries[0..self.count], 0..) |entry, i| {
            var shared = false;
            for (self.entries[0..i]) |previous| if (std.meta.eql(entry.version, previous.version)) {
                shared = true;
                break;
            };
            if (!shared) try turn.release(entry.version);
        }
    }
};
fn commitment(realm: u64, resource: u64, entry: Entry) [32]u8 {
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.relational.retained-resource.v1\x00");
    hash.update(@tagName(p.Growth.current_definition));
    inline for (.{ realm, resource, entry.revision, entry.version.pid, entry.version.input }) |value| {
        var bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &bytes, value, .little);
        hash.update(&bytes);
    }
    hash.update(&.{entry.version.index});
    return hash.finalResult();
}
/// Called only after the coordinator's committed policy chooses `principal`.
/// Every required resource must have been explicitly opened by its Station host.
pub fn capture(turn: *s.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, principal: u64) !Vector {
    const before = turn.decision;
    errdefer turn.decision = before;
    try bundle.validate();
    if (bundle.plan.lifetime != .captured) return error.InvalidRelationalCapture;
    var result: Vector = .{ .request = try bundle.fingerprint(), .count = @intCast(bundle.sources.len) };
    for (bundle.sources, 0..) |source, i| {
        if (source.scope.realm != turn.delivery.realm) return error.CrossRealmRelationalQuery;
        var current = try turn.captured(source.scope.resource);
        const basis = try source.capture(allocator, &current, &current, principal);
        try checkSchema(allocator, &current, basis.head, bundle.plan.sources[i].schema);
        try current.requireCurrent();
        result.entries[i] = .{ .version = try current.retain(), .revision = basis.revision, .head = try q.Basis.tableHead(basis.head) };
    }
    try result.validate(bundle);
    return result;
}
/// Returned adapters must reach a stable address before giving pointers to an
/// executor. Plan descriptors borrow the caller's immutable bundle arena.
pub fn open(turn: *s.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, principal: u64, vector: Vector, read_limit: u64) !Self {
    try vector.validate(bundle);
    if (read_limit == 0) return error.InvalidQueryBudget;
    if (bundle.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    var self: Self = .{ .turn = turn, .allocator = allocator, .bundle = bundle, .principal = principal, .vector = vector, .read_limit = read_limit };
    try vector.boundCuts(bundle, &self.cuts);
    for (bundle.sources, vector.entries[0..vector.count], 0..) |source, entry, i| {
        if (source.scope.realm != turn.delivery.realm or entry.version.pid != turn.delivery.pid) return error.InvalidRelationalCapture;
        self.current[i] = try turn.captured(source.scope.resource);
        try self.current[i].?.requireCurrent();
        self.data[i] = try turn.openVersion(entry.version);
        const expected: q.Basis = .{ .cut = .{ .kind = .table, .resource = source.scope.resource, .revision = entry.revision, .head = entry.head }, .contract = try source.fingerprint(), .schema = try source.row_type.fingerprint() };
        self.bases[i] = try source.restore(allocator, &self.data[i].?, &self.current[i].?, principal, expected);
        try checkSchema(allocator, &self.data[i].?, self.bases[i].head, bundle.plan.sources[i].schema);
    }
    return self;
}
pub fn bound(self: *const Self) r.Bound {
    return .{ .plan = self.bundle.plan, .cuts = self.cuts[0..self.vector.count] };
}
pub fn validate(self: *Self, expected: r.Bound) !void {
    if (!std.mem.eql(u8, &try expected.fingerprint(), &try self.bound().fingerprint())) return error.RelationalSourceChanged;
    for (self.bundle.sources, 0..) |source, i| {
        _ = try source.checkCurrent(&self.current[i].?, self.principal);
        try self.current[i].?.requireCurrent();
    }
}
pub fn next(self: *Self, ordinal: u8, after: ?r.RowIdentity) !?e.Row {
    if (ordinal >= self.vector.count) return error.InvalidRelationalSources;
    if (self.reads == self.read_limit) return error.RelationalWorkBudget;
    self.reads += 1;
    try self.validate(self.bound());
    const basis = self.bases[ordinal];
    const schema = self.bundle.plan.sources[ordinal].schema;
    const table: s.TableData = .{ .schema = schema, .index = basis.head.index };
    var pages: s.TablePages.Reader(*s.Turn.Retained) = .{ .pages = .{ .resource = basis.resource, .object = schema.object }, .source = &self.data[ordinal].? };
    var owned = (try table.next(self.allocator, &pages, after)) orelse return null;
    defer owned.deinit();
    var row: e.Row = .{ .identity = owned.identity };
    for (schema.columns, owned.row().cells, 0..) |column, cell, i| {
        if (column.type != .int64) continue;
        row.values[i] = if (cell == .null) null else value: {
            if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidRelationalSourceRow;
            break :value std.math.cast(i64, cell.value.atom.signed) orelse return error.InvalidRelationalSourceRow;
        };
    }
    try self.validate(self.bound());
    return row;
}

fn checkSchema(allocator: std.mem.Allocator, data: anytype, head: s.TableHead, expected: f.TableSchema.Schema) !void {
    var actual = try head.readSchema(allocator, data);
    defer actual.deinit();
    if (!std.mem.eql(u8, &try actual.schema.fingerprint(), &try expected.fingerprint())) return error.RelationalSourceChanged;
}

test {
    _ = @import("relational_captured_test.zig");
}

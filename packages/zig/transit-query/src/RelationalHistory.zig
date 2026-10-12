//! Complete Table-history vectors for maintained execution. Logical data cuts
//! and the fresh backing views used for current authorization remain distinct.
const std = @import("std");
const q = @import("root.zig");
const s = q.station;
const f = q.fuze;
const r = f.Relational;
const p = q.protocol;
const History = s.TableHistory;
const Self = @This();
turn: *s.Turn,
allocator: std.mem.Allocator,
bundle: q.RelationalBundle,
principal: u64,
vector: Vector,
current: [r.max_sources]?s.Turn.Captured = @splat(null),
cuts: [r.max_sources]r.Cut = undefined,
reads: u64 = 0,
read_limit: u64,
pub const resident_bytes = @sizeOf(Self) + 2 * f.TableRow.max_bytes + 2 * f.TableSchema.max_bytes;
pub const Entry = struct { position: u64, record: History.Record };
pub const Vector = struct {
    request: [32]u8,
    count: u8,
    entries: [r.max_sources]Entry = undefined,
    pub const max_bytes = 69 + r.max_sources * (8 + 2 + p.Value.max_bytes);
    pub fn validate(self: Vector, bundle: q.RelationalBundle) !void {
        try bundle.validate();
        if (bundle.plan.lifetime != .maintained or self.count != bundle.sources.len or !std.mem.eql(u8, &self.request, &try bundle.fingerprint())) return error.InvalidRelationalHistory;
        for (self.entries[0..self.count], bundle.sources, 0..) |entry, source, i| {
            try entry.record.validate();
            if (entry.position == 0 or entry.position > p.max_counter or entry.record.committed > entry.position or entry.record.head.resource != source.scope.resource or entry.record.head.object != source.object) return error.InvalidRelationalHistory;
            for (self.entries[0..i], bundle.sources[0..i]) |earlier, declared| {
                if (declared.scope.resource != source.scope.resource) continue;
                if (entry.position != earlier.position) return error.InconsistentRelationalCut;
                if (declared.object == source.object and !(try entry.record.encode()).eql(try earlier.record.encode())) return error.InconsistentRelationalCut;
            }
        }
    }
    pub fn encode(self: Vector, bundle: q.RelationalBundle, output: []u8) ![]const u8 {
        try self.validate(bundle);
        var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
        try writer.writeAll("RQH1");
        try writer.writeAll(&q.catalog.TableMetadata.definition());
        try writer.writeAll(&self.request);
        try writer.writeByte(self.count);
        for (self.entries[0..self.count]) |entry| {
            try writer.writeInt(u64, entry.position, .little);
            const value = try entry.record.encode();
            try writer.writeInt(u16, value.len, .little);
            try writer.writeAll(value.slice());
        }
        return writer.buffered();
    }
    pub fn decode(bundle: q.RelationalBundle, bytes: []const u8) !Vector {
        if (bytes.len > max_bytes) return error.InvalidRelationalHistory;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "RQH1")) return error.InvalidRelationalHistory;
        if (!std.mem.eql(u8, try reader.take(32), &q.catalog.TableMetadata.definition())) return error.IncompatibleDefinition;
        var result: Vector = .{ .request = (try reader.takeArray(32)).*, .count = try reader.takeByte() };
        if (result.count == 0 or result.count > r.max_sources) return error.InvalidRelationalHistory;
        for (result.entries[0..result.count]) |*entry| {
            entry.* = .{ .position = try reader.takeInt(u64, .little), .record = try History.Record.decode(try p.Value.init(try reader.take(try reader.takeInt(u16, .little)))) };
        }
        if (reader.bufferedLen() != 0) return error.InvalidRelationalHistory;
        var canonical: [max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try result.encode(bundle, &canonical))) return error.InvalidRelationalHistory;
        return result;
    }
    /// Each same-resource alias shares one commitment covering every required
    /// Table at that coordinate. This is explicitly Table-history evidence.
    pub fn boundCuts(self: Vector, bundle: q.RelationalBundle, output: *[r.max_sources]r.Cut) !void {
        try self.validate(bundle);
        for (self.entries[0..self.count], bundle.plan.sources, 0..) |entry, source, i| {
            var hash: std.crypto.hash.sha2.Sha256 = .init(.{});
            hash.update("transit.relational.table-history-cut.v1\x00");
            hash.update(&self.request);
            var coordinate: [8]u8 = undefined;
            std.mem.writeInt(u64, &coordinate, entry.position, .little);
            hash.update(&coordinate);
            for (self.entries[0..self.count]) |required| if (required.record.head.resource == source.resource) {
                hash.update((try required.record.encode()).slice());
            };
            output[i] = .{ .resource = source.resource, .revision = entry.position, .commitment = hash.finalResult(), .schema = try source.schema.fingerprint() };
        }
        try (r.Bound{ .plan = bundle.plan, .cuts = output[0..self.count] }).validate();
    }
};
fn checkSchema(allocator: std.mem.Allocator, source: anytype, head: s.TableHead, expected: f.TableSchema.Schema) !void {
    if (head.retired) return error.TableRetired;
    var schema = try head.readSchema(allocator, source);
    defer schema.deinit();
    if (!std.mem.eql(u8, &try schema.schema.fingerprint(), &try expected.fingerprint())) return error.TableSchemaChanged;
}
/// Initial activation resolves the configured live definitions. Subsequent
/// vectors follow object identities, never a replacement of the same name.
pub fn capture(turn: *s.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, principal: u64) !Vector {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try bundle.validate();
    if (bundle.plan.lifetime != .maintained) return error.InvalidRelationalHistory;
    var vector: Vector = .{ .request = try bundle.fingerprint(), .count = @intCast(bundle.sources.len) };
    for (bundle.sources, bundle.plan.sources, 0..) |source, declared, i| {
        if (source.scope.realm != turn.delivery.realm) return error.CrossRealmRelationalQuery;
        var current = try turn.captured(source.scope.resource);
        try current.requireCurrent();
        const basis = try source.capture(allocator, &current, &current, principal);
        const record = try History.current(&current, source.object);
        if (!(try record.head.encode()).eql(try basis.head.encode())) return error.TableHeadChanged;
        try checkSchema(allocator, &current, record.head, declared.schema);
        vector.entries[i] = .{ .position = current.view.revision, .record = record };
    }
    try vector.validate(bundle);
    return vector;
}
/// Select one resource's next relevant transaction. Every required Table in
/// that resource moves together, including aliases and no-op head revisions.
/// The owner persists the returned vector before doing any successor work.
/// Round-robin preference is scheduling, not an order between authorities.
pub fn successor(turn: *s.Turn, bundle: q.RelationalBundle, principal: u64, previous: Vector, preference: u8) !?Vector {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try previous.validate(bundle);
    if (preference >= previous.count) return error.InvalidRelationalHistory;
    var current: [r.max_sources]s.Turn.Captured = undefined;
    var upper: [r.max_sources]History.Record = undefined;
    var following: [r.max_sources]?History.Record = @splat(null);
    for (bundle.sources, previous.entries[0..previous.count], 0..) |source, entry, i| {
        if (source.scope.realm != turn.delivery.realm) return error.CrossRealmRelationalQuery;
        current[i] = try turn.captured(source.scope.resource);
        _ = try source.checkCurrent(&current[i], principal);
        try current[i].requireCurrent();
        upper[i] = try History.current(&current[i], source.object);
        const observed = try History.at(&current[i], upper[i], entry.position);
        if (!(try observed.encode()).eql(try entry.record.encode())) return error.TableHistoryConflict;
        if (upper[i].head.revision != entry.record.head.revision) {
            const transaction = (try s.TableChanges.next(&current[i], entry.record)) orelse return error.TableHistoryGap;
            if (transaction.after.committed <= entry.position) return error.InvalidRelationalHistory;
            following[i] = transaction.after;
        }
    }
    for (0..previous.count) |offset| {
        const selected = (preference + offset) % previous.count;
        if (following[selected] == null) continue;
        const resource = bundle.sources[selected].scope.resource;
        var position = following[selected].?.committed;
        for (following) |candidate| if (candidate) |head| if (head.head.resource == resource) {
            position = @min(position, head.committed);
        };
        var result = previous;
        for (bundle.sources, 0..) |source, i| if (source.scope.resource == resource) {
            result.entries[i] = .{ .position = position, .record = try History.at(&current[i], upper[i], position) };
        };
        try result.validate(bundle);
        return result;
    }
    return null;
}
pub fn open(turn: *s.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, principal: u64, vector: Vector, read_limit: u64) !Self {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try vector.validate(bundle);
    if (read_limit == 0) return error.InvalidQueryBudget;
    if (bundle.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    var self: Self = .{ .turn = turn, .allocator = allocator, .bundle = bundle, .principal = principal, .vector = vector, .read_limit = read_limit };
    try vector.boundCuts(bundle, &self.cuts);
    for (bundle.sources, vector.entries[0..vector.count], 0..) |source, entry, i| {
        if (source.scope.realm != turn.delivery.realm) return error.CrossRealmRelationalQuery;
        self.current[i] = try turn.captured(source.scope.resource);
        const current = &self.current[i].?;
        _ = try source.checkCurrent(current, principal);
        try current.requireCurrent();
        const observed = try History.at(current, try History.current(current, source.object), entry.position);
        if (!(try observed.encode()).eql(try entry.record.encode())) return error.TableHistoryConflict;
        try checkSchema(allocator, current, entry.record.head, bundle.plan.sources[i].schema);
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
pub fn next(self: *Self, ordinal: u8, after: ?r.RowIdentity) !?f.RelationalExecution.Row {
    if (ordinal >= self.vector.count) return error.InvalidRelationalSources;
    if (self.reads == self.read_limit) return error.RelationalWorkBudget;
    self.reads += 1;
    try self.validate(self.bound());
    const head = self.vector.entries[ordinal].record.head;
    const schema = self.bundle.plan.sources[ordinal].schema;
    const data: s.TableData = .{ .schema = schema, .index = head.index };
    var pages: s.TablePages.Reader(*s.Turn.Captured) = .{ .pages = .{ .resource = head.resource, .object = head.object }, .source = &self.current[ordinal].? };
    var owned = (try data.next(self.allocator, &pages, after)) orelse return null;
    defer owned.deinit();
    var row: f.RelationalExecution.Row = .{ .identity = owned.identity };
    for (schema.columns, owned.row().cells, 0..) |column, cell, i| {
        if (column.type != .int64) continue;
        row.values[i] = if (cell == .null) null else value: {
            if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidRelationalSourceRow;
            break :value std.math.cast(i64, cell.value.atom.signed) orelse return error.InvalidRelationalSourceRow;
        };
    }
    return row;
}
test {
    _ = @import("relational_history_test.zig");
}

//! Retained direct Table vectors for finite exchanges and maintained execution.
//! Logical source positions are independent of native computation progress.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const f = q.fuze;
const r = f.Relational;
const p = q.protocol;
const Pin = q.CapturedTablePin;
const Self = @This();
pub const Record = q.RelationalHistoryRecord;
turn: *q.station.Turn,
allocator: std.mem.Allocator,
bundle: q.RelationalBundle,
vector: Vector,
clients: [r.max_sources]c.DirectTableClient,
cuts: [r.max_sources]r.Cut = undefined,
reads: u64 = 0,
read_limit: u64,
pub const resident_bytes = @sizeOf(Self) + 2 * f.TableRow.max_bytes + 2 * f.TableSchema.max_bytes;
pub const Entry = struct { position: u64, record: Record };
pub const Vector = struct {
    request: [32]u8,
    count: u8,
    entries: [r.max_sources]Entry = undefined,
    pub const max_bytes = 69 + r.max_sources * (8 + 2 + Record.encoded_bytes);
    pub fn validate(self: Vector, bundle: q.RelationalBundle) !void {
        try bundle.validate();
        if (bundle.retention.len != bundle.sources.len) return error.QueryCaptureRequired;
        if (bundle.plan.lifetime == .interactive or self.count != bundle.sources.len or !std.mem.eql(u8, &self.request, &try bundle.fingerprint())) return error.InvalidRelationalHistory;
        for (self.entries[0..self.count], bundle.sources, bundle.retention, 0..) |entry, source, grant, i| {
            try entry.record.validate(source, grant);
            try checkSchema(entry.record, bundle.plan.sources[i].schema);
            if (entry.position != entry.record.basis.accepted.next_lsn) return error.InvalidRelationalHistory;
            const original = try bundle.sourceOrdinal(i);
            if (original != i and !std.meta.eql(entry, self.entries[original])) return error.InconsistentRelationalCut;
        }
    }
    pub fn encode(self: Vector, bundle: q.RelationalBundle, output: []u8) ![]const u8 {
        try self.validate(bundle);
        var writer: std.Io.Writer = .fixed(output[0..@min(output.len, max_bytes)]);
        try writer.writeAll("RQH1");
        try writer.writeAll(&p.Growth.definition_bytes);
        try writer.writeAll(&self.request);
        try writer.writeByte(self.count);
        for (self.entries[0..self.count], bundle.sources, bundle.retention) |entry, source, grant| {
            try writer.writeInt(u64, entry.position, .little);
            const value = try entry.record.encode(source, grant);
            try writer.writeInt(u16, value.len, .little);
            try writer.writeAll(value.slice());
        }
        return writer.buffered();
    }
    pub fn decode(bundle: q.RelationalBundle, bytes: []const u8) !Vector {
        if (bytes.len > max_bytes) return error.InvalidRelationalHistory;
        try bundle.validate();
        if (bundle.retention.len != bundle.sources.len) return error.QueryCaptureRequired;
        var reader: std.Io.Reader = .fixed(bytes);
        if (!std.mem.eql(u8, try reader.take(4), "RQH1")) return error.InvalidRelationalHistory;
        if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        var result: Vector = .{ .request = (try reader.takeArray(32)).*, .count = try reader.takeByte() };
        if (result.count == 0 or result.count != bundle.sources.len) return error.InvalidRelationalHistory;
        for (result.entries[0..result.count], bundle.sources, bundle.retention) |*entry, source, grant| {
            entry.* = .{ .position = try reader.takeInt(u64, .little), .record = try Record.decode(source, grant, try p.Value.init(try reader.take(try reader.takeInt(u16, .little)))) };
        }
        if (reader.bufferedLen() != 0) return error.InvalidRelationalHistory;
        var canonical: [max_bytes]u8 = undefined;
        if (!std.mem.eql(u8, bytes, try result.encode(bundle, &canonical))) return error.InvalidRelationalHistory;
        return result;
    }
    pub fn fingerprint(self: Vector, bundle: q.RelationalBundle) ![32]u8 {
        var bytes: [max_bytes]u8 = undefined;
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        hash.update("transit.query.direct-history-vector.v1\x00");
        hash.update(try self.encode(bundle, &bytes));
        return hash.finalResult();
    }
    /// Same-Table aliases share their exact cut. Distinct Tables in one catalog
    /// remain independent; there is no resource-wide native transaction here.
    pub fn boundCuts(self: Vector, bundle: q.RelationalBundle, output: *[r.max_sources]r.Cut) !void {
        try self.validate(bundle);
        for (self.entries[0..self.count], bundle.sources, bundle.plan.sources, 0..) |entry, source, declared, i| output[i] = .{
            .domain = .{ .table_partition = .{ .branch = source.branch, .object = source.object, .partition = entry.record.basis.accepted.partition } },
            .resource = source.scope.resource,
            .revision = entry.position,
            .commitment = try entry.record.fingerprint(),
            .schema = try declared.schema.fingerprint(),
        };
        try (r.Bound{ .plan = bundle.plan, .cuts = output[0..self.count] }).validate();
    }
};
fn checkSchema(record: Record, expected: f.TableSchema.Schema) !void {
    if (record.basis.interpretation.retired) return error.TableRetired;
    if (!std.mem.eql(u8, &record.basis.interpretation.schema_fingerprint, &try expected.fingerprint())) return error.TableSchemaChanged;
}
fn route(bundle: q.RelationalBundle, clients: []const c.DirectTableClient, ordinal: usize) !c.DirectTableClient {
    if (clients.len != bundle.sources.len or ordinal >= clients.len) return error.InvalidRelationalSources;
    return Pin.delegatedClient(clients[ordinal], bundle.retention[ordinal]);
}
fn read(allocator: std.mem.Allocator, client: c.DirectTableClient, record: Record) !c.DirectTableReader {
    var reader = if (record.point()) |point|
        c.DirectTableReader.openHistory(allocator, client, .{ .object = record.basis.snapshot.object, .point = point }) catch |err| return Pin.readFailure(client, err)
    else
        c.DirectTableReader.open(allocator, client, record.basis.snapshot) catch |err| return Pin.readFailure(client, err);
    errdefer reader.deinit();
    if (!std.meta.eql(reader.basis, record.basis) or !std.meta.eql(reader.history_point, record.point())) return error.RelationalSourceChanged;
    return reader;
}
/// Acquisition eligibility and the handle must already be committed. Resolving
/// a vector never acquires a lease or substitutes a later cut after replacement.
pub fn capture(turn: *q.station.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, job: u64, clients: []const c.DirectTableClient) !Vector {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try bundle.validate();
    if (bundle.retention.len != bundle.sources.len) return error.QueryCaptureRequired;
    if (clients.len != bundle.sources.len) return error.InvalidRelationalSources;
    var current = turn.committed();
    var vector: Vector = .{ .request = try bundle.fingerprint(), .count = @intCast(bundle.sources.len) };
    for (bundle.sources, bundle.plan.sources, 0..) |source, declared, i| {
        if (source.scope.realm != turn.delivery.realm) return error.CrossRealmRelationalQuery;
        const original = try bundle.sourceOrdinal(i);
        if (original != i) {
            vector.entries[i] = vector.entries[original];
            continue;
        }
        const basis = try Pin.source(allocator, &current, .{ .job = job, .source = @intCast(original) }, turn.delivery.pid);
        var record: Record = .{ .basis = basis, .record = null };
        if (bundle.retention[i].binding.retention == .history) {
            const client = try route(bundle, clients, i);
            var reader = c.DirectTableReader.openHistoryStart(allocator, client, basis.snapshot) catch |err| return Pin.readFailure(client, err);
            defer reader.deinit();
            if (!std.meta.eql(basis, reader.basis)) return error.RelationalSourceChanged;
            record.record = reader.history_point.?.commitment;
        }
        try record.validate(source, bundle.retention[i]);
        try checkSchema(record, declared.schema);
        try Pin.authorizeSource(turn, bundle.retention[i], basis.authority);
        vector.entries[i] = .{ .position = basis.accepted.next_lsn, .record = record };
    }
    try vector.validate(bundle);
    return vector;
}
pub fn open(turn: *q.station.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, vector: Vector, clients: []const c.DirectTableClient, read_limit: u64) !Self {
    try vector.validate(bundle);
    var routes: [r.max_sources]c.DirectTableClient = undefined;
    for (bundle.sources, 0..) |_, i| routes[i] = try route(bundle, clients, i);
    return openRouted(turn, allocator, bundle, vector, routes, read_limit);
}
/// Workers use their own credentials and the original caller's exact borrowed
/// reads. The saved assignment binds the native PID and immutable destination.
pub fn openExchange(turn: *q.station.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, vector: Vector, clients: []const c.DirectTableClient, authorization: q.ExchangeAuthorization, borrows: []const c.DirectReadDelegation.Borrow, read_limit: u64) !Self {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try vector.validate(bundle);
    if (clients.len != bundle.sources.len or borrows.len != clients.len) return error.InvalidRelationalSources;
    try authorization.bind(turn, authorization.assignment, bundle, vector);
    var routes: [r.max_sources]c.DirectTableClient = undefined;
    for (clients, borrows, 0..) |client, borrow, i| {
        const expected = try authorization.readBinding(bundle, vector, i, turn.delivery.principal);
        if (!std.meta.eql(expected, borrow.binding)) return error.QueryDenied;
        routes[i] = try Pin.borrowedClient(client, bundle.retention[i], borrow);
    }
    return openRouted(turn, allocator, bundle, vector, routes, read_limit);
}
fn openRouted(turn: *q.station.Turn, allocator: std.mem.Allocator, bundle: q.RelationalBundle, vector: Vector, clients: [r.max_sources]c.DirectTableClient, read_limit: u64) !Self {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try vector.validate(bundle);
    if (read_limit == 0) return error.InvalidQueryBudget;
    if (bundle.plan.budgets.resident_bytes < resident_bytes) return error.RelationalResidentBudget;
    var self: Self = .{ .turn = turn, .allocator = allocator, .bundle = bundle, .vector = vector, .clients = clients, .read_limit = read_limit };
    try vector.boundCuts(bundle, &self.cuts);
    for (bundle.sources, bundle.plan.sources, vector.entries[0..vector.count], 0..) |source, declared, entry, i| {
        if (source.scope.realm != turn.delivery.realm) return error.CrossRealmRelationalQuery;
        try checkSchema(entry.record, declared.schema);
        if (try bundle.sourceOrdinal(i) != i) continue;
        var reader = try read(allocator, clients[i], entry.record);
        reader.deinit();
    }
    try self.validate(self.bound());
    return self;
}
pub fn bound(self: *const Self) r.Bound {
    return .{ .plan = self.bundle.plan, .cuts = self.cuts[0..self.vector.count] };
}
pub fn validate(self: *Self, expected: r.Bound) !void {
    if (!std.mem.eql(u8, &try expected.fingerprint(), &try self.bound().fingerprint())) return error.RelationalSourceChanged;
    for (self.vector.entries[0..self.vector.count], self.bundle.retention, 0..) |entry, grant, i| {
        if (try self.bundle.sourceOrdinal(i) != i) continue;
        try Pin.authorizeSource(self.turn, grant, entry.record.basis.authority);
    }
}
pub fn next(self: *Self, ordinal: u8, after: ?r.RowIdentity) !?f.RelationalExecution.Row {
    if (ordinal >= self.vector.count) return error.InvalidRelationalSources;
    if (self.reads == self.read_limit) return error.RelationalWorkBudget;
    self.reads += 1;
    try self.validate(self.bound());
    const client = self.clients[ordinal];
    var reader = try read(self.allocator, client, self.vector.entries[ordinal].record);
    defer reader.deinit();
    var batch = reader.readAfter(client, after, .{ .rows = 1 }) catch |err| return Pin.readFailure(client, err);
    defer batch.deinit();
    try self.validate(self.bound());
    if (batch.count == 0) return null;
    const owned = &batch.rows[0].?;
    var row: f.RelationalExecution.Row = .{ .identity = owned.identity };
    for (reader.schema.schema.columns, owned.row().cells, 0..) |column, cell, i| {
        if (column.type != .int64) continue;
        row.values[i] = if (cell == .null) null else value: {
            if (cell != .value or cell.value != .atom or cell.value.atom != .signed) return error.InvalidRelationalSourceRow;
            break :value std.math.cast(i64, cell.value.atom.signed) orelse return error.InvalidRelationalSourceRow;
        };
    }
    return row;
}

/// Physical traversal progress is distinct from a selected logical result cut.
/// Persist each pending Scan before continuing; otherwise empty pages could be
/// rescanned forever or later writes could silently expand the chosen interval.
pub const Scan = struct {
    basis: [32]u8,
    count: u8,
    preference: u8,
    cursors: [r.max_sources]u64 = @splat(0),
    uppers: [r.max_sources]u64 = @splat(0),
    pub fn validate(self: Scan, bundle: q.RelationalBundle, previous: Vector) !void {
        try previous.validate(bundle);
        if (bundle.plan.lifetime != .maintained or self.count != previous.count or self.preference >= self.count or !std.mem.eql(u8, &self.basis, &try previous.fingerprint(bundle))) return error.InvalidRelationalHistory;
        for (self.cursors, self.uppers, 0..) |cursor, upper, i| {
            if (i >= self.count) {
                if (cursor != 0 or upper != 0) return error.InvalidRelationalHistory;
                continue;
            }
            if (cursor < previous.entries[i].position or cursor > upper) return error.InvalidRelationalHistory;
            const original = try bundle.sourceOrdinal(i);
            if (original != i and (cursor != self.cursors[original] or upper != self.uppers[original])) return error.InconsistentRelationalCut;
        }
    }
    pub fn encode(self: Scan, bundle: q.RelationalBundle, previous: Vector) !p.Value {
        try self.validate(bundle, previous);
        var bytes: [70 + 16 * r.max_sources]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&bytes);
        try writer.writeAll("QHS1");
        try writer.writeAll(&p.Growth.definition_bytes);
        try writer.writeAll(&self.basis);
        try writer.writeByte(self.count);
        try writer.writeByte(self.preference);
        for (self.cursors, self.uppers) |cursor, upper| {
            try writer.writeInt(u64, cursor, .little);
            try writer.writeInt(u64, upper, .little);
        }
        return p.Value.init(writer.buffered());
    }
    pub fn decode(bundle: q.RelationalBundle, previous: Vector, value: p.Value) !Scan {
        try value.validate();
        var reader: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try reader.take(4), "QHS1")) return error.InvalidRelationalHistory;
        if (!std.mem.eql(u8, try reader.take(32), &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
        var result: Scan = .{ .basis = (try reader.takeArray(32)).*, .count = try reader.takeByte(), .preference = try reader.takeByte() };
        for (&result.cursors, &result.uppers) |*cursor, *upper| {
            cursor.* = try reader.takeInt(u64, .little);
            upper.* = try reader.takeInt(u64, .little);
        }
        if (reader.bufferedLen() != 0 or !(try result.encode(bundle, previous)).eql(value)) return error.InvalidRelationalHistory;
        return result;
    }
};
pub fn begin(turn: *q.station.Turn, bundle: q.RelationalBundle, previous: Vector, preference: u8, clients: []const c.DirectTableClient) !Scan {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try previous.validate(bundle);
    if (bundle.plan.lifetime != .maintained or preference >= previous.count) return error.InvalidRelationalHistory;
    var scan: Scan = .{ .basis = try previous.fingerprint(bundle), .count = previous.count, .preference = preference };
    for (previous.entries[0..previous.count], 0..) |entry, i| {
        const original = try bundle.sourceOrdinal(i);
        if (original != i) {
            scan.cursors[i] = scan.cursors[original];
            scan.uppers[i] = scan.uppers[original];
            continue;
        }
        const client = try route(bundle, clients, i);
        const snapshot = entry.record.basis.snapshot;
        const response = client.call(.{ .pin_status = .{ .object = snapshot.object, .owner = snapshot.handle.owner } }) catch |err| return Pin.readFailure(client, err);
        defer response.deinit();
        const state = response.value.result.pin_state;
        if (state.released or state.handle == null or !std.meta.eql(state.handle.?, snapshot.handle) or state.position.partition != entry.record.basis.accepted.partition or
            !std.meta.eql(state.authority, entry.record.basis.authority)) return error.RelationalSourceChanged;
        try Pin.authorizeSource(turn, bundle.retention[i], entry.record.basis.authority);
        scan.cursors[i] = entry.position;
        scan.uppers[i] = state.position.next_lsn;
    }
    try scan.validate(bundle, previous);
    return scan;
}
pub const Successor = union(enum) { idle, pending: Scan, next: struct { vector: Vector, preference: u8 } };
pub fn successor(turn: *q.station.Turn, bundle: q.RelationalBundle, previous: Vector, scan: Scan, clients: []const c.DirectTableClient) !Successor {
    const decision = turn.decision;
    errdefer turn.decision = decision;
    try scan.validate(bundle, previous);
    for (previous.entries[0..previous.count], bundle.retention, 0..) |entry, grant, i| {
        if (try bundle.sourceOrdinal(i) != i) continue;
        try Pin.authorizeSource(turn, grant, entry.record.basis.authority);
    }
    for (0..scan.count) |offset| {
        const selected = (scan.preference + offset) % scan.count;
        if (try bundle.sourceOrdinal(selected) != selected or scan.cursors[selected] == scan.uppers[selected]) continue;
        const before = previous.entries[selected].record;
        const client = try route(bundle, clients, selected);
        const partition = before.basis.accepted.partition;
        const response = client.call(.{ .history = .{ .snapshot = before.basis.snapshot, .from = .{ .partition = partition, .next_lsn = scan.cursors[selected] }, .through = .{ .partition = partition, .next_lsn = scan.uppers[selected] }, .frames = 8 } }) catch |err| return Pin.readFailure(client, err);
        defer response.deinit();
        const page = response.value.result.history;
        if (page.entries.len != 0) {
            const logical = page.entries[0];
            const source = client.call(.{ .history_source = .{ .object = before.basis.snapshot.object, .point = logical.point } }) catch |err| return Pin.readFailure(client, err);
            defer source.deinit();
            const record = try Record.from(source.value.result.history_source);
            if (!std.meta.eql(record.basis.interpretation, logical.interpretation) or record.basis.changed_lsn != logical.changed_lsn or record.basis.row_count != logical.row_count or !std.meta.eql(record.basis.authority, before.basis.authority)) return error.InvalidRelationalHistory;
            try record.validate(bundle.sources[selected], bundle.retention[selected]);
            try checkSchema(record, bundle.plan.sources[selected].schema);
            try Pin.authorizeSource(turn, bundle.retention[selected], record.basis.authority);
            var vector = previous;
            for (vector.entries[0..vector.count], 0..) |*entry, i| if (try bundle.sourceOrdinal(i) == selected) {
                entry.* = .{ .position = record.basis.accepted.next_lsn, .record = record };
            };
            try vector.validate(bundle);
            return .{ .next = .{ .vector = vector, .preference = @intCast((selected + 1) % vector.count) } };
        }
        var progress = scan;
        for (progress.cursors[0..progress.count], 0..) |*cursor, i| if (try bundle.sourceOrdinal(i) == selected) {
            cursor.* = page.next.next_lsn;
        };
        progress.preference = @intCast((selected + 1) % progress.count);
        try progress.validate(bundle, previous);
        return .{ .pending = progress };
    }
    return .idle;
}
test {
    _ = @import("relational_history_test.zig");
}

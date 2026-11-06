//! Paged SQL operation inspection over the database recovery index.
const std = @import("std");
const g = @import("root.zig");
const c = g.catalog;
const p = c.protocol;
pub const Kind = enum(u8) {
    table = 1,
    configuration = 2,
    captured = 3,
    transaction = 4,
    dataflow = 5,
    workload = 6,
    connector = 7,
    pub fn database(self: Kind) bool {
        return self == .table or self == .transaction or self == .workload;
    }
};
pub const Reference = struct {
    pub const magic = "GSR1";
    id: u64,
    kind: Kind,
    nonce: [16]u8,
    pub fn validate(self: Reference) !void {
        if (self.id == 0 or self.id > p.max_counter) return error.InvalidSqlOperationReference;
    }
};
pub const Begin = struct {
    nonce: [16]u8,
    fingerprint: [32]u8,
    kind: Kind,
    binding: g.DatabaseAccount.Binding,
    original: [16]u8,
    source: [32]u8,
    expected_generation: u64,
    reservation: u32,
};
pub const External = struct {
    pub const magic = "GSX1";
    id: u64,
    nonce: [16]u8,
    kind: Kind,
    resource: u64,
    catalog: u64,
    owner: u64,
    namespace: u64,
    role: u64,
    role_present: u8,
    source_executor: ?u64 = null,
    original: [16]u8,
    source: [32]u8,
    expected_generation: u64,
    phase: enum { ready, terminal },
    length: u32 = 0,
    digest: [32]u8 = @splat(0),
    reservation: u64,
    summary: enum(u8) { none = 0, applied = 1, rejected = 2, cancelled = 3, partial = 4 } = .none,
    pub fn binding(self: External) g.DatabaseAccount.Binding {
        return .{ .resource = self.resource, .catalog = self.catalog, .owner = self.owner, .namespace = self.namespace, .role = if (self.role_present == 1) self.role else null, .source_executor = self.source_executor };
    }
    pub fn validate(self: External) !void {
        if (self.id == 0 or self.id > p.max_counter or self.kind.database() or self.resource == 0 or self.catalog == 0 or self.owner == 0 or self.namespace == 0 or self.role_present > 1 or self.role > p.max_counter or (self.role_present == 0 and self.role != 0) or self.expected_generation == 0) return error.InvalidSqlOperationReference;
        if (self.source_executor) |executor| if (executor == 0 or executor > p.max_counter) return error.InvalidSqlOperationReference;
        if ((self.phase == .terminal) != (self.summary != .none) or (self.phase == .terminal and self.reservation != 0) or (self.phase != .terminal and self.reservation < 512)) return error.InvalidSqlOperationReference;
    }
};

pub const initial_format: u32 = 0x53514f31;
pub const progress_format: u32 = 0x53515031;
pub const Initial = struct { begin: Begin, body: ?c.DirectRecord.Reference, inline_body: ?c.DirectTableProtocol.Binary = null };
pub fn isInitial(format_value: u32) bool {
    return format_value == initial_format or format_value == c.DirectOwnedRecord.format;
}
pub const Capture = struct {
    records: u64 = 1,
    staging: u64 = 0,
    pending: u64 = 0,
    input: u64 = 0,
    stored: u64 = 0,
    cancel: u8 = 0,
    rejected: u8 = 0,
    saved: ?c.DirectRecord.Reference = null,
};
pub const Progress = struct { summary: @FieldType(External, "summary") = .none, capture: Capture = .{} };
pub fn decode(comptime T: type, source: *g.Client.Source, reference_value: c.DirectRecord.Reference) !T {
    var caller = source.client.table(source.client.execution.configuration.bindings[0]);
    caller.connection = reference_value.scope.connection;
    const bytes = try c.DirectRecord.read(source.client.transport.http.allocator, caller, reference_value);
    defer source.client.transport.http.allocator.free(bytes);
    const parsed = try p.Json.parseFromSlice(T, source.client.transport.http.allocator, bytes);
    defer parsed.deinit();
    return parsed.value;
}
pub fn readInitial(source: *g.Client.Source, state: c.DirectClientToken.Progress) !Initial {
    if (state.receipt.binding.intent != .external or !isInitial(state.receipt.binding.intent.external.record.format)) return error.InvalidSqlOperationReference;
    const record = state.receipt.binding.intent.external.record;
    const value = if (record.format == initial_format) try decode(Initial, source, record) else blk: {
        const caller = source.direct(state);
        const bytes = try c.DirectRecord.read(caller.allocator, caller, record);
        defer caller.allocator.free(bytes);
        const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, caller.allocator, bytes);
        defer envelope.deinit();
        try envelope.value.validate(record);
        try envelope.value.key.requireSame(state.receipt.binding.key);
        if (envelope.value.format != initial_format) return error.InvalidSqlOperationReference;
        const payload = try envelope.value.bytes.decode(caller.allocator, c.DirectRecord.max_bytes);
        defer caller.allocator.free(payload);
        const parsed = try p.Json.parseFromSlice(Initial, caller.allocator, payload);
        defer parsed.deinit();
        // Initial is otherwise fixed-width. The inline bytes are separately
        // returned by readInline, so no borrowed text escapes this parse.
        var initial = parsed.value;
        initial.inline_body = null;
        break :blk initial;
    };
    if (!std.mem.eql(u8, &value.begin.nonce, &state.receipt.binding.key.token) or !std.mem.eql(u8, &value.begin.fingerprint, &state.receipt.binding.fingerprint)) return error.GatewayIdentityConflict;
    const connection = state.receipt.binding.key.connection;
    const selected = value.begin.binding;
    if (value.begin.kind.database() or value.begin.expected_generation == 0 or value.begin.reservation < 512 or
        selected.resource != connection.scope.resource or selected.catalog != connection.scope.catalog or selected.owner != connection.audience or selected.role != connection.role or selected.namespace != state.receipt.binding.intent.external.namespace) return error.InvalidSqlOperationReference;
    if (value.body) |body| {
        try body.validate();
        if (!std.meta.eql(body.scope, state.receipt.binding.key.scope()) or body.content.bytes > value.begin.reservation - 512) return error.InvalidSqlOperationReference;
    }
    return value;
}
pub fn progress(source: *g.Client.Source, state: c.DirectClientToken.Progress) !Progress {
    const reference_value = state.record orelse {
        const initial = try readInitial(source, state);
        return .{ .capture = .{ .stored = if (initial.body) |body| body.content.bytes else 0 } };
    };
    if (reference_value.format == c.DirectProgressRecord.format) {
        const caller = source.direct(state);
        const bytes = try c.DirectRecord.read(caller.allocator, caller, reference_value);
        defer caller.allocator.free(bytes);
        const envelope = try p.Json.parseFromSlice(c.DirectProgressRecord.Envelope, caller.allocator, bytes);
        defer envelope.deinit();
        try envelope.value.validate(reference_value);
        try envelope.value.advance.key.requireSame(state.receipt.binding.key);
        if (envelope.value.advance.format != progress_format) return error.InvalidSqlOperationReference;
        const payload = try envelope.value.advance.bytes.decode(caller.allocator, c.DirectRecord.max_bytes);
        defer caller.allocator.free(payload);
        const parsed = try p.Json.parseFromSlice(Progress, caller.allocator, payload);
        defer parsed.deinit();
        return parsed.value;
    }
    if (reference_value.format != progress_format) return error.InvalidSqlOperationReference;
    return decode(Progress, source, reference_value);
}
pub fn save(source: *g.Client.Source, state: c.DirectClientToken.Progress, value: Progress, pending: bool, cancel: bool) !c.DirectClientToken.Progress {
    const bytes = try p.Json.valueAlloc(source.client.transport.http.allocator, value);
    defer source.client.transport.http.allocator.free(bytes);
    const caller = source.direct(state);
    if (state.original != null) {
        const binary = try c.DirectTableProtocol.Binary.encode(caller.allocator, bytes);
        defer caller.allocator.free(binary.base64);
        return c.DirectProgressRecord.advance(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = pending, .cancel = cancel, .format = progress_format, .bytes = binary });
    }
    const record = try c.DirectRecord.stage(caller, state.receipt.binding.key.account, progress_format, bytes);
    return c.DirectClientToken.update(caller, .{ .key = state.receipt.binding.key, .expected = state.revision, .pending = pending, .cancel = cancel, .record = record });
}
pub fn reference(_: g.DatabaseAccount, source: *g.Client.Source, id: u64) !Reference {
    return projection(source, try source.operation(id));
}
fn projection(source: *g.Client.Source, state: c.DirectClientToken.Progress) !Reference {
    if (state.receipt.binding.intent == .workload) {
        if (!g.WorkloadOperations.supported(state.receipt.binding.intent.workload)) return error.UnsupportedSqlWorkload;
        return .{ .id = state.id(), .nonce = state.receipt.binding.key.token, .kind = .workload };
    }
    return .{ .id = state.id(), .nonce = state.receipt.binding.key.token, .kind = if (state.receipt.binding.intent == .external) (try readInitial(source, state)).begin.kind else if (state.receipt.binding.intent == .transaction_call) .transaction else .table };
}
pub fn lookup(_: g.DatabaseAccount, source: *g.Client.Source, nonce: [16]u8, fingerprint: ?[32]u8) !?Reference {
    return try projection(source, (try source.lookup(nonce, fingerprint)) orelse return null);
}
pub fn external(execution: g.DatabaseAccount, source: *g.Client.Source, id: u64) !External {
    const state = try source.operation(id);
    const initial = try readInitial(source, state);
    const value = initial.begin;
    const current = try progress(source, state);
    try execution.admittedBinding(value.binding);
    return .{ .id = id, .nonce = value.nonce, .kind = value.kind, .resource = value.binding.resource, .catalog = value.binding.catalog, .owner = value.binding.owner, .namespace = value.binding.namespace, .role = value.binding.role orelse 0, .role_present = @intFromBool(value.binding.role != null), .source_executor = value.binding.source_executor, .original = value.original, .source = value.source, .expected_generation = value.expected_generation, .phase = if (state.pending) .ready else .terminal, .length = if (initial.body) |body| @intCast(body.content.bytes) else 0, .digest = if (initial.body) |body| body.content.sha256 else @splat(0), .reservation = if (state.pending) value.reservation else 0, .summary = current.summary };
}
pub fn begin(source: *g.Client.Source, input: Begin, body: ?c.DirectRecord.Reference) !Reference {
    if (try lookup(source.client.execution, source, input.nonce, input.fingerprint)) |existing| return existing;
    try source.client.execution.admittedBinding(input.binding);
    if (input.kind.database()) return error.InvalidSqlOperationReference;
    const caller = source.client.table(input.binding);
    const initial: Initial = .{ .begin = input, .body = body };
    const bytes = try p.Json.valueAlloc(caller.allocator, initial);
    defer caller.allocator.free(bytes);
    const record = try c.DirectRecord.stage(caller, source.client.execution.configuration.account, initial_format, bytes);
    var random: [8]u8 = undefined;
    try source.client.transport.http.io.randomSecure(&random);
    const id = (std.mem.readInt(u64, &random, .little) % p.max_counter) + 1;
    const receipt = try c.DirectClientToken.bind(caller, .{ .key = .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = source.client.execution.configuration.account, .token = input.nonce }, .fingerprint = input.fingerprint, .intent = .{ .external = .{ .connection = caller.connection, .namespace = input.binding.namespace, .operation = id, .record = record } }, .budget = source.client.execution.configuration.budget(input.reservation) });
    return projection(source, c.DirectClientToken.Progress.initial(receipt));
}
pub fn complete(source: *g.Client.Source, id: u64, summary: @FieldType(External, "summary")) !void {
    const state = try source.operation(id);
    var current = try progress(source, state);
    if (summary == .none or current.capture.pending != 0) return error.GatewayUnresolvedStep;
    if (!state.pending) {
        if (current.summary != summary) return error.GatewayIdentityConflict;
        return;
    }
    current.summary = summary;
    _ = try save(source, state, current, false, state.cancel);
}
pub const Page = struct { entries: [8]?Reference = @splat(null), next: ?u64 = null };
pub fn list(execution: g.DatabaseAccount, source: *g.Client.Source, after_id: u64, pending: bool) !Page {
    var states: [64]?c.DirectClientToken.Progress = @splat(null);
    var count: usize = 0;
    var through: ?u64 = null;
    const bindings = execution.configuration.bindings;
    for (bindings, 0..) |binding, index| {
        if (g.Client.isDuplicateBindingConnection(bindings, index)) continue;
        const page = try c.DirectClientToken.list(source.client.table(binding), execution.configuration.account, after_id, pending);
        if (page.next) |next| through = if (through) |previous| @min(previous, next) else next;
        for (page.entries) |slot| if (slot) |state| {
            if (state.receipt.binding.intent == .branch or state.receipt.binding.intent == .history) continue;
            if (state.receipt.binding.intent == .workload and !g.WorkloadOperations.supported(state.receipt.binding.intent.workload)) continue;
            if (state.receipt.binding.intent == .external and !isInitial(state.receipt.binding.intent.external.record.format)) continue;
            for (states[0..count]) |other| if (other.?.id() == state.id()) break else continue else {
                states[count] = state;
                count += 1;
            }
        };
    }
    std.mem.sort(?c.DirectClientToken.Progress, states[0..count], {}, struct {
        fn less(_: void, lhs: ?c.DirectClientToken.Progress, rhs: ?c.DirectClientToken.Progress) bool {
            return lhs.?.id() < rhs.?.id();
        }
    }.less);
    var ids: [64]u64 = undefined;
    for (states[0..count], 0..) |state, i| ids[i] = state.?.id();
    const selected = pageWindow(ids[0..count], through);
    var result: Page = .{ .next = selected.next };
    for (states[0..selected.count], 0..) |state, i| result.entries[i] = try projection(source, state.?);
    return result;
}

// Do not skip unseen SQL work behind another binding's filtered page. An empty
// output page still advances the shared database cursor through excluded work.
fn pageWindow(ids: []const u64, through: ?u64) struct { count: usize, next: ?u64 } {
    var count: usize = 0;
    while (count < @min(ids.len, 8) and (through == null or ids[count] <= through.?)) : (count += 1) {}
    return .{ .count = count, .next = if (count == 8 and (ids.len > 8 or through != null)) ids[7] else through };
}

test "SQL recovery pagination crosses excluded branch pages without skipping another binding" {
    const t = std.testing;
    const empty = pageWindow(&.{}, 17);
    try t.expectEqual(0, empty.count);
    try t.expectEqual(@as(?u64, 17), empty.next);
    // One binding scanned through 17; another supplied 10, 20, 30. The latter
    // two must wait until the former's as-yet-unseen SQL work has been read.
    const partial = pageWindow(&.{ 10, 20, 30 }, 17);
    try t.expectEqual(1, partial.count);
    try t.expectEqual(@as(?u64, 17), partial.next);
    const final = pageWindow(&.{ 18, 20, 30 }, null);
    try t.expectEqual(3, final.count);
    try t.expectEqual(@as(?u64, null), final.next);
    const bounded = pageWindow(&.{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, null);
    try t.expectEqual(8, bounded.count);
    try t.expectEqual(@as(?u64, 8), bounded.next);
}

/// Reserve the original SQL token and complete saved typed request before any
/// retained payload is written. A failure preserves the same token commitment.
pub fn beginOwned(source: *g.Client.Source, input: Begin, payload: []const u8) !Reference {
    if (try lookup(source.client.execution, source, input.nonce, input.fingerprint)) |existing| return existing;
    try source.client.execution.admittedBinding(input.binding);
    if (input.kind != .connector) return error.InvalidSqlOperationReference;
    const caller = source.client.table(input.binding);
    const binary = try c.DirectTableProtocol.Binary.encode(caller.allocator, payload);
    defer caller.allocator.free(binary.base64);
    const bytes = try p.Json.valueAllocBounded(caller.allocator, Initial{ .begin = input, .body = null, .inline_body = binary }, c.DirectRecord.max_bytes);
    defer caller.allocator.free(bytes);
    const id = connectorTokenOperation(input.original);
    const state = try c.DirectOwnedRecord.stage(caller, .{ .definition = p.Growth.current_definition, .connection = caller.connection, .account = source.client.execution.configuration.account, .token = input.nonce }, input.binding.namespace, id, input.fingerprint, source.client.execution.configuration.budget(input.reservation), initial_format, bytes);
    return projection(source, state);
}
pub fn readInline(source: *g.Client.Source, state: c.DirectClientToken.Progress, allocator: std.mem.Allocator) ![]const u8 {
    const record = state.receipt.binding.intent.external.record;
    if (record.format != c.DirectOwnedRecord.format) return error.InvalidSqlOperationReference;
    const caller = source.direct(state);
    const bytes = try c.DirectRecord.read(allocator, caller, record);
    defer allocator.free(bytes);
    const envelope = try p.Json.parseFromSlice(c.DirectOwnedRecord.Envelope, allocator, bytes);
    defer envelope.deinit();
    try envelope.value.validate(record);
    try envelope.value.key.requireSame(state.receipt.binding.key);
    if (envelope.value.format != initial_format) return error.InvalidSqlOperationReference;
    const payload = try envelope.value.bytes.decode(allocator, c.DirectRecord.max_bytes);
    defer allocator.free(payload);
    const initial = try p.Json.parseFromSlice(Initial, allocator, payload);
    defer initial.deinit();
    if (initial.value.body != null or initial.value.begin.kind != .connector) return error.InvalidSqlOperationReference;
    return (initial.value.inline_body orelse return error.InvalidSqlOperationReference).decode(allocator, c.SourceDeclaration.max_bytes);
}
pub fn retain(source: *g.Client.Source, id: u64) !void {
    const state = try source.operation(id);
    if (state.original) |owned| {
        if (owned.phase == .retained) return;
        _ = try c.DirectOwnedRecord.call(source.direct(state), .{ .retain_original = .{ .key = state.receipt.binding.key, .expected = state.revision } });
    }
}

// SQL token bookkeeping and its connector operation share the Catalog's global
// caller-operation namespace. Reserve a distinct ID even before either exists.
fn connectorTokenOperation(original: [16]u8) u64 {
    const connector = (std.mem.readInt(u64, original[8..16], .big) % p.max_counter) + 1;
    return if (connector == p.max_counter) 1 else connector + 1;
}
test "SOURCE SQL token and native publication use distinct operation identities" {
    for ([_]u64{ 0, 1, 9007199254741011, p.max_counter - 1, p.max_counter }) |suffix| {
        var original: [16]u8 = @splat(0);
        std.mem.writeInt(u64, original[8..16], suffix, .big);
        const native = (suffix % p.max_counter) + 1;
        const bookkeeping = connectorTokenOperation(original);
        try std.testing.expect(bookkeeping > 0 and bookkeeping <= p.max_counter);
        try std.testing.expect(bookkeeping != native);
    }
}

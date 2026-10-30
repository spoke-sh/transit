//! Explicit interactive query ownership for an installed service. The direct
//! Table owner is authoritative; this journal preserves original pin requests
//! before dispatch. A replaced service closes interrupted work, never resumes
//! its lost executor or silently chooses newer data.
const std = @import("std");
const q = @import("root.zig");
const c = q.catalog;
const b = q.RelationalBridge;
const h = c.DirectTableValues;
const retention = c.DirectCatalogRetention;
const Self = @This();
pub const max_request_bytes = 16384;
pub const max_journal_bytes = 32768;
pub const schema_options = q.RelationalCaller.schema_options;
pub const request_schema_options = q.RelationalCaller.request_schema_options;
pub const Open = struct {
    id: []const u8,
    statement: b.Statement,
    sources: []const b.Source,
    pub const json_schema_sequence_bounds = .{ .sources = 2 };
};
pub const Action = union(enum) {
    capabilities,
    explain: b.Statement,
    open: Open,
    page: @FieldType(b.Action, "page"),
    close: b.Reference,
};
pub const StorageRequest = struct { route: u16, binding: h.PreparedBinding };
pub const Storage = struct { binding: h.PreparedBinding, observed: h.StorageObservation };
pub const Request = union(enum) { describe, storage: StorageRequest, query: Action, recover: struct { id: []const u8 } };
pub const Recovery = struct { id: []const u8, state: enum { acquiring, active, closing }, remaining_pins: u8 };
pub const Profile = struct {
    capabilities: b.Capabilities,
    routes: []const q.RelationalCaller.Route,
    active: ?b.Session.Progress,
    recovery: ?Recovery,
    pub const json_schema_sequence_bounds = .{ .routes = 2 };
};
pub const Response = union(enum) { description: Profile, storage: Storage, query: b.Result, recovered };
const Pin = struct {
    operation: u64,
    handle: ?c.storage.TablePartition.SnapshotHandle,
    released: bool,
};
const Record = struct {
    definition: q.protocol.Growth.Definition,
    profile: [32]u8,
    input: Open,
    pins: []Pin,
    reference: ?b.Reference,
    state: enum { acquiring, active, closing, closed },
    pub const json_schema_sequence_bounds = .{ .pins = 2 };
};
allocator: std.mem.Allocator,
io: std.Io,
caller: *q.RelationalCaller,
directory: std.Io.Dir,
lock: std.Io.File,
profile: [32]u8,
attempt: c.DirectTableClient.Attempt = .{},

/// Borrows the caller. The host serializes all methods and joins them before
/// destroying either owner. The lock excludes concurrent owners of the journal.
pub fn create(allocator: std.mem.Allocator, io: std.Io, caller: *q.RelationalCaller, path: []const u8) !*Self {
    if (path.len == 0 or path.len > 4096) return error.InvalidRelationalRecovery;
    const directory = try std.Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    errdefer directory.close(io);
    const lock = try directory.createFile(io, "relational.lock", .{ .truncate = false, .permissions = .fromMode(0o600) });
    errdefer lock.close(io);
    if (!try lock.tryLock(io, .exclusive)) return error.RelationalWorkspaceInUse;
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("transit.relational.workspace.owner.v1\x00");
    const identity = try q.protocol.Json.valueAlloc(allocator, .{ .connection = caller.catalogs[0].connection, .authority = caller.catalogs[0].authority.url, .service = caller.service_url });
    defer allocator.free(identity);
    hasher.update(identity);
    self.* = .{ .allocator = allocator, .io = io, .caller = caller, .directory = directory, .lock = lock, .profile = hasher.finalResult() };
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    if (try self.read(arena.allocator())) |saved| {
        var record = saved;
        // This process has no executor for its predecessor's work. Persist the
        // closure decision before permitting any new query or cleanup attempt.
        if (record.state != .closed) {
            record.state = .closing;
            try self.write(record);
        }
    }
    return self;
}
pub fn destroy(self: *Self) void {
    // No network operation in destruction. The durable journal remains until
    // explicit closure, or a replacement exposes it as interrupted work.
    self.caller.session.deinit();
    self.lock.close(self.io);
    self.directory.close(self.io);
    self.allocator.destroy(self);
}
fn nonce(value: []const u8) ![16]u8 {
    if (value.len != 32) return error.InvalidQueryRequest;
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return error.InvalidQueryRequest;
    var result: [16]u8 = undefined;
    _ = std.fmt.hexToBytes(&result, value) catch return error.InvalidQueryRequest;
    if (std.mem.allEqual(u8, &result, 0)) return error.InvalidQueryRequest;
    return result;
}
fn sameReference(a: b.Reference, other: b.Reference) bool {
    return a.definition == other.definition and std.mem.eql(u8, a.id, other.id) and std.mem.eql(u8, a.plan, other.plan) and std.mem.eql(u8, a.basis, other.basis);
}
fn sameInput(a: Open, other: Open) !bool {
    if (!std.mem.eql(u8, a.id, other.id) or a.statement.namespace != other.statement.namespace or
        !std.mem.eql(u8, a.statement.sql, other.statement.sql) or !std.mem.eql(u16, a.statement.routes, other.statement.routes) or a.sources.len != other.sources.len) return false;
    for (a.sources, other.sources) |first, second| {
        if (!std.mem.eql(u8, first.alias, second.alias) or !std.meta.eql(try first.binding.native(), try second.binding.native()) or !std.meta.eql(try first.position.native(), try second.position.native())) return false;
    }
    return true;
}
fn clientFor(self: *Self, input: Open, index: usize) !c.DirectTableClient {
    if (input.sources.len == 0 or input.sources.len > 2 or input.statement.routes.len != input.sources.len or index >= input.sources.len) return error.InvalidRelationalSources;
    const route = input.statement.routes[index];
    if (route >= self.caller.count) return error.InvalidRelationalSources;
    var client = self.caller.catalogs[route];
    client.attempt = &self.attempt;
    const binding = try input.sources[index].binding.native();
    if (!std.meta.eql(binding.connection, client.connection) or binding.namespace != input.statement.namespace) return error.RelationalCallerChanged;
    return client;
}
fn validate(self: *Self, record: Record) !void {
    if (record.definition != q.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    if (!std.mem.eql(u8, &record.profile, &self.profile) or record.pins.len != record.input.sources.len) return error.InvalidRelationalRecovery;
    if (record.input.sources.len == 0 or record.input.sources.len > 2 or record.input.statement.routes.len != record.input.sources.len) return error.InvalidRelationalRecovery;
    _ = try nonce(record.input.id);
    if (record.input.statement.sql.len == 0 or record.input.statement.sql.len > 4096) return error.InvalidRelationalRecovery;
    for (record.pins, record.input.sources, 0..) |pin, source, i| {
        const client = try self.clientFor(record.input, i);
        const expected = try source.position.native();
        if (expected.next_lsn == 0 or pin.operation == 0) return error.InvalidRelationalRecovery;
        for (record.pins[0..i]) |previous| if (previous.operation == pin.operation) return error.InvalidRelationalRecovery;
        if (pin.handle) |handle| {
            try handle.content.validate();
            if (!std.meta.eql(handle.owner, pinOwner(client, pin))) return error.InvalidRelationalRecovery;
        }
        if (record.state == .active and (pin.handle == null or pin.released)) return error.InvalidRelationalRecovery;
        if (record.state == .closed and !pin.released) return error.InvalidRelationalRecovery;
    }
    if (record.reference) |ref| {
        if (ref.definition != record.definition or !std.mem.eql(u8, ref.id, record.input.id)) return error.InvalidRelationalRecovery;
        _ = try c.TableValues.digest(ref.plan);
        _ = try c.TableValues.digest(ref.basis);
    } else if (record.state == .active) return error.InvalidRelationalRecovery;
}
fn read(self: *Self, allocator: std.mem.Allocator) !?Record {
    const bytes = self.directory.readFileAlloc(self.io, "relational.json", allocator, .limited(max_journal_bytes)) catch |err| if (err == error.FileNotFound) return null else return err;
    defer allocator.free(bytes);
    // All fields, including the shared definition, are mandatory. No foreign
    // saved format is defaulted or silently reset during startup.
    // The response arena owns the decoded record; its strings must not borrow
    // this temporary file buffer, which is released before the caller uses it.
    const parsed = try q.protocol.Json.parseFromSliceOwned(Record, allocator, bytes);
    try self.validate(parsed.value);
    return parsed.value;
}
fn write(self: *Self, record: Record) !void {
    try self.validate(record);
    const bytes = try q.protocol.Json.valueAlloc(self.allocator, record);
    defer self.allocator.free(bytes);
    if (bytes.len > max_journal_bytes) return error.InvalidRelationalRecovery;
    var file = try self.directory.createFileAtomic(self.io, "relational.json", .{ .replace = true, .permissions = .fromMode(0o600) });
    defer file.deinit(self.io);
    try file.file.writeStreamingAll(self.io, bytes);
    try file.file.sync(self.io);
    try file.replace(self.io);
    if (std.c.fsync(self.directory.handle) != 0) return error.RelationalRecoverySyncFailed;
}
fn pinOwner(client: c.DirectTableClient, pin: Pin) q.protocol.DataLifecycle.Operation {
    return .{ .scope = client.connection.scope, .principal = client.connection.principal, .operation = pin.operation };
}
fn acquire(self: *Self, record: *Record) !void {
    for (record.pins, record.input.sources, 0..) |*pin, source, i| {
        if (pin.released) return error.InvalidRelationalRecovery;
        if (pin.handle != null) continue;
        const client = try self.clientFor(record.input, i);
        const object = (try source.binding.native()).interpretation.interpretation.object;
        // An original request is already durable. The same exact owner and
        // frontier reconcile a lost acquisition reply; they cannot retarget.
        const response = try client.call(.{ .pin = .{ .object = object, .owner = pinOwner(client, pin.*), .expected = try source.position.native(), .selection = .exact } });
        defer response.deinit();
        pin.handle = response.value.result.pin;
        try self.write(record.*);
    }
}
fn closeRecord(self: *Self, record: *Record) !void {
    if (record.state == .closed) return;
    record.state = .closing;
    try self.write(record.*);
    self.caller.session.deinit();
    for (record.pins, record.input.sources, 0..) |*pin, source, i| {
        if (pin.released) continue;
        const client = try self.clientFor(record.input, i);
        const object = (try source.binding.native()).interpretation.interpretation.object;
        try client.closeOriginalPin(object, pinOwner(client, pin.*), try source.position.native(), pin.handle);
        pin.released = true;
        try self.write(record.*);
    }
    record.state = .closed;
    try self.write(record.*);
}
fn open(self: *Self, allocator: std.mem.Allocator, input: Open, location: *q.fuze.Sql.Location) !b.Result {
    _ = try nonce(input.id);
    var record: Record = undefined;
    if (try self.read(allocator)) |saved| {
        if (saved.state != .closed) {
            if (!try sameInput(saved.input, input)) return error.QueryIdentityMismatch;
            if (saved.state == .closing) return error.RelationalRecoveryRequired;
            record = saved;
        } else {
            if (std.mem.eql(u8, saved.input.id, input.id)) return error.QueryIdentityMismatch;
            record = try self.prepare(allocator, input, location);
        }
    } else record = try self.prepare(allocator, input, location);
    try self.acquire(&record);
    var bindings: [2]h.PreparedBinding = undefined;
    var snapshots: [2]retention.Snapshot = undefined;
    for (record.pins, input.sources, 0..) |pin, source, i| {
        const client = try self.clientFor(input, i);
        bindings[i] = source.binding;
        snapshots[i] = .{ .owner = .{ .definition = q.protocol.Growth.current_definition, .connection = source.binding.connection, .object = source.binding.interpretation.interpretation.object, .operation = try c.TableValues.decimal(allocator, pinOwner(client, pin).operation) }, .content = try h.Content.foreign(allocator, pin.handle.?.content) };
    }
    const result = try self.caller.session.apply(allocator, .{ .open = .{ .id = input.id, .statement = input.statement, .bindings = bindings[0..input.sources.len], .snapshots = snapshots[0..input.sources.len] } }, location);
    record.reference = result.opened.reference;
    record.state = .active;
    try self.write(record);
    return result;
}
fn prepare(self: *Self, allocator: std.mem.Allocator, input: Open, location: *q.fuze.Sql.Location) !Record {
    for (input.sources, 0..) |_, i| _ = try self.clientFor(input, i);
    const pins = try allocator.alloc(Pin, input.sources.len);
    for (pins, 0..) |*pin, i| {
        var bytes: [8]u8 = undefined;
        try self.io.randomSecure(&bytes);
        const operation = std.mem.readInt(u64, &bytes, .little);
        if (operation == 0) return error.InvalidRelationalRecovery;
        for (pins[0..i]) |previous| if (operation == previous.operation) return error.InvalidRelationalRecovery;
        pin.* = .{ .operation = operation, .handle = null, .released = false };
    }
    const record: Record = .{ .definition = q.protocol.Growth.current_definition, .profile = self.profile, .input = input, .pins = pins, .reference = null, .state = .acquiring };
    try self.write(record);
    // Freeze ownership before the current-source recheck. A changed source or
    // lost metadata reply must still leave an exact original request that an
    // explicit close can fence, even though no acquisition was dispatched yet.
    const explained = try self.caller.session.apply(allocator, .{ .explain = input.statement }, location);
    const expected: Open = .{ .id = input.id, .statement = input.statement, .sources = explained.explained.sources };
    if (!try sameInput(input, expected)) return error.RelationalSourceChanged;
    return record;
}
fn recovery(record: ?Record) ?Recovery {
    const saved = record orelse return null;
    if (saved.state == .closed) return null;
    var remaining: u8 = 0;
    for (saved.pins) |pin| if (!pin.released) {
        remaining += 1;
    };
    return .{ .id = saved.input.id, .state = switch (saved.state) {
        .acquiring => .acquiring,
        .active => .active,
        .closing => .closing,
        .closed => unreachable,
    }, .remaining_pins = remaining };
}
fn apply(self: *Self, allocator: std.mem.Allocator, request: Request, location: *q.fuze.Sql.Location) !Response {
    switch (request) {
        .storage => |input| {
            if (input.route >= self.caller.count) return error.InvalidRelationalSources;
            const client = self.caller.catalogs[input.route];
            const binding = try input.binding.native();
            if (!std.meta.eql(binding.connection, client.connection)) return error.RelationalCallerChanged;
            const response = try client.call(.{ .storage = .{ .object = binding.interpretation.interpretation.object, .pending_limit = 1024 } });
            defer response.deinit();
            const observed = response.value.result.storage;
            if (!std.meta.eql(binding.interpretation, observed.interpretation)) return error.CatalogDefinitionChanged;
            const current = try client.call(.{ .lookup = .{ .namespace = binding.namespace, .name = binding.name.slice() } });
            defer current.deinit();
            const current_binding = try c.DirectTableBinding.init(client.connection, current.value.result.lookup orelse return error.CatalogDefinitionChanged);
            if (!std.meta.eql(binding, current_binding)) return error.CatalogDefinitionChanged;
            return .{ .storage = .{ .binding = try h.PreparedBinding.foreign(allocator, binding), .observed = try h.StorageObservation.foreign(allocator, observed) } };
        },
        .describe => {
            const profile = try self.caller.describe(allocator);
            return .{ .description = .{ .capabilities = profile.capabilities, .routes = profile.routes, .active = profile.active, .recovery = recovery(try self.read(allocator)) } };
        },
        .recover => |input| {
            _ = try nonce(input.id);
            var record = (try self.read(allocator)) orelse return error.InvalidQueryCursor;
            if (!std.mem.eql(u8, input.id, record.input.id)) return error.QueryIdentityMismatch;
            try self.closeRecord(&record);
            return .recovered;
        },
        .query => |action| return .{ .query = switch (action) {
            .capabilities => .{ .capabilities = .{} },
            .explain => |statement| try self.caller.session.apply(allocator, .{ .explain = statement }, location),
            .open => |input| try self.open(allocator, input, location),
            .page => |input| try self.caller.session.apply(allocator, .{ .page = input }, location),
            .close => |reference| closed: {
                var record = (try self.read(allocator)) orelse return error.InvalidQueryCursor;
                if (!sameReference(reference, record.reference orelse return error.QueryIdentityMismatch)) return error.QueryIdentityMismatch;
                try self.closeRecord(&record);
                break :closed .closed;
            },
        } },
    }
}
/// `allocator` is the request/response arena, released after consuming the result.
pub fn applyStructured(self: *Self, allocator: std.mem.Allocator, request: Request, out: *?q.protocol.Diagnostic) !Response {
    out.* = null;
    self.attempt = .{};
    const wire = self.caller.catalogs[0].authority;
    wire.last_rejection = null;
    self.caller.service.last_rejection = null;
    var location: q.fuze.Sql.Location = .{};
    return self.apply(allocator, request, &location) catch |err| {
        const rejection = self.caller.service.last_rejection orelse wire.last_rejection;
        const action: b.Action = switch (request) {
            .describe, .storage, .recover => .capabilities,
            .query => |value| switch (value) {
                .capabilities => .capabilities,
                .explain => |s| .{ .explain = s },
                .open => |input| .{ .open = .{ .id = input.id, .statement = input.statement, .bindings = &.{}, .snapshots = &.{} } },
                .page => |page| .{ .page = page },
                .close => |ref| .{ .close = ref },
            },
        };
        out.* = (self.attempt.failure(err, rejection) catch null) orelse (q.ApiDiagnostic.project(.{ .relational = action }, err, .{ .location = location }, false, null) catch null);
        if (out.*) |*value| {
            self.caller.session.diagnostic(action, err, value);
            if (self.attempt.mutation == null) if (rejection) |native| value.text(.native_cause, .authority, @tagName(native)) catch {};
        }
        wire.last_rejection = rejection;
        return err;
    };
}

test "relational workspace fences concurrent hosts and preserves interrupted original ownership" {
    const t = std.testing;
    var tmp = t.tmpDir(.{});
    defer tmp.cleanup();
    const path = try tmp.dir.realPathFileAlloc(t.io, ".", t.allocator);
    defer t.allocator.free(path);
    var wire = q.wire.Client.init(t.allocator, t.io, "http://127.0.0.1:1");
    defer wire.deinit();
    const connection: h.Connection = .{ .scope = .{ .realm = 1, .resource = 3, .catalog = "7" }, .branch = "1", .audience = 2, .principal = 9, .role = null };
    const config: b.Config = .{ .definition = q.protocol.Growth.current_definition, .catalogs = &.{connection}, .spill_directory = path, .options = .{ .consistency = .independent_table_snapshots, .resident_bytes = "16777216", .spill_bytes = "16777216", .result_bytes = "8388608", .output_rows = "1000", .work_steps = "100000", .source_pins = 2, .requests = "100000", .spill_work = "100000" } };
    const key = try q.protocol.Ed25519.KeyPair.generateDeterministic(@splat(1));
    const caller = try q.RelationalCaller.create(t.allocator, t.io, &wire, key, config);
    defer caller.destroy();
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const workspace = try create(t.allocator, t.io, caller, path);
    var first_destroyed = false;
    defer if (!first_destroyed) workspace.destroy();
    try t.expectError(error.RelationalWorkspaceInUse, create(t.allocator, t.io, caller, path));
    const native = try connection.native();
    const binding: c.DirectTableBinding = .{
        .definition = q.protocol.Growth.current_definition,
        .connection = native,
        .namespace = 1,
        .name = try c.TableAuthority.Name.init("items"),
        .interpretation = .{ .kind = .table, .interpretation = .{ .object = .{ .scope = native.scope, .branch = 1, .object = std.math.maxInt(u64) }, .revision = 1, .digest = @splat(2) }, .content = .{ .bytes = 300, .sha256 = @splat(2) }, .schema_fingerprint = @splat(3), .retired = false },
    };
    const source: b.Source = .{ .alias = "items", .binding = try h.PreparedBinding.foreign(allocator, binding), .position = .{ .partition = "1", .next_lsn = "9" } };
    var pins = [_]Pin{.{ .operation = std.math.maxInt(u64), .handle = null, .released = false }};
    const input: Open = .{ .id = "00000000000000000000000000000001", .statement = .{ .sql = "SELECT id FROM items", .routes = &.{0} }, .sources = &.{source} };
    var record: Record = .{ .definition = q.protocol.Growth.current_definition, .profile = workspace.profile, .input = input, .pins = &pins, .reference = null, .state = .acquiring };
    try workspace.write(record);
    const original = (try workspace.read(allocator)).?;
    try t.expect(try sameInput(input, original.input));
    try t.expectEqual(std.math.maxInt(u64), original.pins[0].operation);
    workspace.destroy();
    first_destroyed = true;
    const replacement = try create(t.allocator, t.io, caller, path);
    defer replacement.destroy();
    record = (try replacement.read(allocator)).?;
    try t.expectEqual(.closing, record.state);
    try t.expect(try sameInput(input, record.input));
    try t.expectEqual(null, record.pins[0].handle);
    var diagnostic: ?q.protocol.Diagnostic = null;
    try t.expectError(error.RelationalRecoveryRequired, replacement.applyStructured(allocator, .{ .query = .{ .open = input } }, &diagnostic));
    try t.expectEqualStrings("query.relational_recovery_required", diagnostic.?.code.slice());
    try t.expectError(error.QueryIdentityMismatch, replacement.applyStructured(allocator, .{ .recover = .{ .id = "00000000000000000000000000000002" } }, &diagnostic));
    // A corrupt or foreign record cannot be silently replaced by a new query.
    record.profile[0] ^= 1;
    try t.expectError(error.InvalidRelationalRecovery, replacement.write(record));
    const bytes = try q.protocol.Json.valueAlloc(allocator, record);
    try tmp.dir.writeFile(t.io, .{ .sub_path = "relational.json", .data = bytes });
    try t.expectError(error.InvalidRelationalRecovery, replacement.read(allocator));
}

test "relational workspace open binds every source and accepted position" {
    const t = std.testing;
    try t.expectError(error.InvalidQueryRequest, nonce("00000000000000000000000000000000"));
    try t.expectError(error.InvalidQueryRequest, nonce("ABCDEF00000000000000000000000001"));
    const input: Open = .{ .id = "00000000000000000000000000000001", .statement = .{ .sql = "SELECT id FROM items", .routes = &.{0} }, .sources = &.{} };
    var other = input;
    other.statement.routes = &.{1};
    try t.expect(!try sameInput(input, other));
    other = input;
    other.statement.sql = "SELECT COUNT(*) FROM items";
    try t.expect(!try sameInput(input, other));
}

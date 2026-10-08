//! Bounded transport for exact typed commands. Publication completion does not
//! apply SQL. The retained binding survives body collection and owner restart.
const std = @import("std");
const c = @import("root.zig");
const s = c.station;
const p = c.protocol;
const Pub = s.Publication;
const Command = c.TableCommand;
const Self = @This();
catalog: c.TableCatalog,
pub const part_bytes = 128;
pub const status_bytes = 239;
const limits: Pub.Limits = .{ .record_bytes = Command.max_bytes, .staging_bytes = Command.max_bytes, .staging_records = 1 };
pub const Status = struct {
    header: Command.Header,
    namespace: u64,
    spec: Pub.Spec,
    phase: enum(u8) { uploading = 1, sealed = 2, ready = 3, cancelled = 4 } = .uploading,
    received: u32 = 0,
    admitted_input: u64,
    digest: [32]u8 = @splat(0),
    route: enum(u8) { none = 0, ddl = 1, point = 2, statement = 3 } = .none,
    pub fn validate(self: Status) !void {
        try self.header.validate();
        try validSpec(self.spec);
        if (self.namespace == 0 or self.admitted_input == 0 or self.admitted_input > p.max_counter or self.received > self.spec.length) return error.InvalidTableUpload;
        if (self.received != self.spec.length and self.received % part_bytes != 0) return error.InvalidTableUpload;
        if ((self.phase == .sealed or self.phase == .ready) and self.received != self.spec.length) return error.InvalidTableUpload;
        if (self.phase == .ready and self.route == .none) return error.InvalidTableUpload;
        if ((self.phase == .uploading or self.phase == .sealed) and self.route != .none) return error.InvalidTableUpload;
        if (self.route == .none) {
            if (!std.mem.eql(u8, &self.digest, &@as([32]u8, @splat(0)))) return error.InvalidTableUpload;
        } else {
            if (self.received != self.spec.length) return error.InvalidTableUpload;
            const ddl = self.header.kind == .create or self.header.kind == .alter or self.header.kind == .rename or self.header.kind == .drop;
            if (ddl != (self.route == .ddl)) return error.InvalidTableUpload;
        }
    }
    pub fn reference(self: Status) !s.TableWrite.Reference {
        try self.validate();
        if (self.route != .point and self.route != .statement) return error.InvalidTableUpload;
        return .{ .resource = self.header.scope.resource, .object = self.header.object, .principal = self.header.principal, .operation = self.header.operation, .digest = self.digest };
    }
    pub fn encode(self: Status) !p.Value {
        try self.validate();
        var bytes: [status_bytes]u8 = undefined;
        var out: std.Io.Writer = .fixed(&bytes);
        try out.writeAll("TCU1");
        try out.writeAll(&try self.header.encode());
        try out.writeInt(u64, self.namespace, .little);
        try out.writeInt(u32, self.spec.format, .little);
        try out.writeInt(u32, self.spec.length, .little);
        try out.writeAll(&self.spec.digest);
        try out.writeByte(@backingInt(self.phase));
        try out.writeInt(u32, self.received, .little);
        try out.writeInt(u64, self.admitted_input, .little);
        try out.writeAll(&self.digest);
        try out.writeByte(@backingInt(self.route));
        std.debug.assert(out.buffered().len == status_bytes);
        return p.Value.init(out.buffered());
    }
    pub fn decode(value: p.Value) !Status {
        try value.validate();
        if (value.len != status_bytes) return error.InvalidTableUpload;
        var input: std.Io.Reader = .fixed(value.slice());
        if (!std.mem.eql(u8, try input.take(4), "TCU1")) return error.InvalidTableUpload;
        const result: Status = .{
            .header = try Command.inspect(try input.take(Command.header_bytes)),
            .namespace = try input.takeInt(u64, .little),
            .spec = .{ .format = try input.takeInt(u32, .little), .length = try input.takeInt(u32, .little), .digest = (try input.take(32))[0..32].* },
            .phase = std.enums.fromInt(@FieldType(Status, "phase"), try input.takeByte()) orelse return error.InvalidTableUpload,
            .received = try input.takeInt(u32, .little),
            .admitted_input = try input.takeInt(u64, .little),
            .digest = (try input.take(32))[0..32].*,
            .route = std.enums.fromInt(@FieldType(Status, "route"), try input.takeByte()) orelse return error.InvalidTableUpload,
        };
        try result.validate();
        return result;
    }
};
fn validSpec(spec: Pub.Spec) !void {
    if (spec.format != Command.format or spec.length <= Command.header_bytes or spec.length > Command.max_bytes) return error.InvalidTableUpload;
}
fn publication(self: Self, namespace: u64) Pub {
    return .{ .resource = self.catalog.configuration.scope.resource, .domain = .table_mutation, .namespace = namespace };
}
pub fn key(self: Self, namespace: u64) p.Value {
    return self.catalog.key('U', namespace, 0);
}
fn halfKey(self: Self, namespace: u64) p.Value {
    return self.catalog.key('u', namespace, 0);
}
fn headerCheck(self: Self, source: anytype, who: u64, header: Command.Header, execute: bool) !void {
    try header.validate();
    if (!std.meta.eql(header.scope, self.catalog.configuration.scope) or header.owner != self.catalog.configuration.owner) return error.CatalogScopeChanged;
    if (who != header.principal) return error.CatalogDenied;
    _ = try self.catalog.authorize(source, who, .inspect);
    if (execute) _ = try self.catalog.authorize(source, who, header.right());
}
fn actor(self: Self, turn: *s.Turn, header: Command.Header, continuation: bool) !void {
    if (turn.delivery.realm != header.scope.realm or turn.delivery.pid != self.catalog.configuration.owner or turn.view.resource != header.scope.resource) return error.CatalogOwnerChanged;
    switch (turn.delivery.input.origin) {
        .external => |origin| if (origin.principal != header.principal) return error.CatalogDenied,
        .process => |origin| if (!continuation or origin.pid != self.catalog.configuration.owner) return error.CatalogDenied,
        else => return error.CatalogDenied,
    }
}
fn load(self: Self, source: anytype, namespace: u64) !Status {
    if (namespace == 0) return error.InvalidTableUpload;
    const result = try Status.decode((try source.read(self.key(namespace))) orelse return error.TableUploadNotFound);
    if (result.namespace != namespace or !std.meta.eql(result.header.scope, self.catalog.configuration.scope) or result.header.owner != self.catalog.configuration.owner) return error.CatalogIdentityConflict;
    return result;
}
pub fn status(self: Self, source: anytype, who: u64, namespace: u64) !Status {
    _ = try self.catalog.authorize(source, who, .inspect);
    const result = try self.load(source, namespace);
    try self.headerCheck(source, who, result.header, false);
    return result;
}
fn accepted(self: Self, turn: *s.Turn, namespace: u64, continuation: bool, execute: bool) !Status {
    const result = try self.load(turn, namespace);
    try self.actor(turn, result.header, continuation);
    try self.headerCheck(turn, result.header.principal, result.header, execute);
    return result;
}
pub fn executionStatus(self: Self, turn: *s.Turn, namespace: u64) !Status {
    const result = try self.accepted(turn, namespace, true, false);
    // Do not let a private bind supply the proof for process-origin admission.
    var committed = turn.committed();
    if (!std.meta.eql(try self.load(&committed, namespace), result)) return error.QueryAfterMutation;
    return result;
}
pub fn begin(self: Self, turn: *s.Turn, header: Command.Header, namespace: u64, spec: Pub.Spec) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    try self.actor(turn, header, false);
    try self.headerCheck(turn, header.principal, header, true);
    var result: Status = .{ .header = header, .namespace = namespace, .spec = spec, .admitted_input = turn.delivery.input.position };
    try result.validate();
    if (try turn.read(self.key(namespace)) != null) {
        result = try self.load(turn, namespace);
        if (!std.meta.eql(result.header, header) or !std.meta.eql(result.spec, spec)) return error.CatalogIdentityConflict;
        return result;
    }
    // A publication namespace is resource-global, including across catalogs.
    // Existing bytes without our exact retained status are never adopted.
    if (try turn.read(self.halfKey(namespace)) != null) return error.CatalogAlreadyPopulated;
    const full = Pub.key(.table_mutation, namespace, 0, 0, 0);
    const prefix = try p.Value.init(full.data[0..14]);
    for (turn.decision.mutations) |slot| if (slot) |entry| {
        if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.QueryAfterMutation;
    };
    var committed = turn.committed();
    const page = try committed.page(prefix);
    try c.Inspection.validatePage(page, prefix, turn.view.revision);
    if (page.entries[0]) |entry| if (std.mem.startsWith(u8, entry.key.slice(), prefix.slice())) return error.CatalogAlreadyPopulated;
    const pubn = try Pub.create(turn, .table_mutation, namespace, limits);
    _ = try pubn.begin(turn, 1, spec);
    try turn.write(self.key(namespace), try result.encode());
    return result;
}
pub fn append(self: Self, turn: *s.Turn, namespace: u64, offset: u32, bytes: []const u8) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    var result = try self.accepted(turn, namespace, false, true);
    if (result.phase == .cancelled) return error.TableUploadClosed;
    if (offset >= result.spec.length or offset % part_bytes != 0 or bytes.len != @min(part_bytes, result.spec.length - offset)) return error.InvalidTableUploadPart;
    if (offset > result.received) return error.TableUploadGap;
    const pubn = self.publication(namespace);
    const descriptor = try pubn.inspect(turn, 1);
    if (!std.meta.eql(descriptor.spec, result.spec)) return error.CatalogIdentityConflict;
    if (descriptor.state == .abandoned or descriptor.state == .retired) return error.TableUploadClosed;
    const index = offset / Pub.chunk_bytes;
    const half = self.halfKey(namespace);
    if (offset < result.received) {
        const location = if (index < descriptor.written) Pub.key(.table_mutation, namespace, 'c', 1, index) else half;
        const previous = (try turn.read(location)) orelse return error.InvalidTableUpload;
        const start: usize = if (index < descriptor.written) offset % Pub.chunk_bytes else 0;
        if (start > previous.len or bytes.len > previous.len - start or !std.mem.eql(u8, previous.slice()[start..][0..bytes.len], bytes)) return error.CatalogIdentityConflict;
        return result;
    }
    if (result.phase != .uploading or descriptor.state != .staging or index != descriptor.written) return error.InvalidTableUpload;
    const size = try result.spec.size(index);
    if (offset % Pub.chunk_bytes == 0) {
        if (try turn.read(half) != null) return error.InvalidTableUpload;
        if (size <= part_bytes) _ = try pubn.append(turn, 1, index, bytes) else try turn.write(half, try p.Value.init(bytes));
    } else {
        const first = (try turn.read(half)) orelse return error.InvalidTableUpload;
        if (first.len != part_bytes or first.len + bytes.len != size) return error.InvalidTableUpload;
        var chunk: [Pub.chunk_bytes]u8 = undefined;
        @memcpy(chunk[0..part_bytes], first.slice());
        @memcpy(chunk[part_bytes..][0..bytes.len], bytes);
        _ = try pubn.append(turn, 1, index, chunk[0..size]);
        try turn.write(half, null);
    }
    result.received += @intCast(bytes.len);
    try turn.write(self.key(namespace), try result.encode());
    return result;
}
pub fn seal(self: Self, turn: *s.Turn, namespace: u64) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    var result = try self.accepted(turn, namespace, false, true);
    if (result.phase == .cancelled) return error.TableUploadClosed;
    if (result.phase != .uploading) return result;
    if (result.received != result.spec.length or try turn.read(self.halfKey(namespace)) != null) return error.IncompletePublication;
    _ = try self.publication(namespace).publish(turn, 1);
    result.phase = .sealed;
    try turn.write(self.key(namespace), try result.encode());
    return result;
}
/// Caller has already authenticated this exact retained status. All schema and
/// body reads use one committed cut; the decoded owner retains no input bytes.
fn readCommand(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, upload: Status) !Command.Owned {
    var committed = turn.committed();
    var basis = try self.catalog.commandBasis(allocator, &committed, upload.header.principal, upload.header, .execute);
    defer if (basis) |*value| value.deinit();
    const pubn = self.publication(upload.namespace);
    var cursor = try pubn.open(&committed, 1);
    if (!std.meta.eql(cursor.spec, upload.spec)) return error.CatalogIdentityConflict;
    const bytes = try allocator.alloc(u8, upload.spec.length);
    defer allocator.free(bytes);
    var offset: usize = 0;
    while (true) {
        const part = try pubn.read(&committed, cursor);
        if (part.bytes.len > bytes.len - offset) return error.InvalidTableUpload;
        @memcpy(bytes[offset..][0..part.bytes.len], part.bytes.slice());
        offset += part.bytes.len;
        cursor = part.next orelse break;
    }
    if (offset != bytes.len or !std.meta.eql(try Command.inspect(bytes), upload.header)) return error.CatalogIdentityConflict;
    return Command.decode(allocator, bytes, if (basis) |*value| value.borrow() else null) catch |err| switch (err) {
        error.OutOfMemory => return err,
        else => return error.InvalidTableCommand,
    };
}
fn binding(allocator: std.mem.Allocator, upload: Status, command: Command.Body) !Status {
    if (!std.meta.eql(command.header, upload.header)) return error.CatalogIdentityConflict;
    var result = upload;
    switch (command.request) {
        .ddl => |request| {
            result.digest = try request.digest(upload.header.scope);
            result.route = .ddl;
        },
        .dml => |request| {
            var scratch: [c.fuze.TableSchema.max_columns]c.fuze.Types.Values.Cell = undefined;
            const route = try request.route(allocator, upload.header.scope, &scratch);
            result.digest = (try route.reference(allocator)).digest;
            result.route = if (route == .point) .point else .statement;
        },
    }
    result.phase = .ready;
    try result.validate();
    return result;
}
/// Persist the exact SQL operation reference in its own turn before applying
/// rows. SQL publication keeps all four native mutation slots available.
pub fn bind(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, namespace: u64) !Status {
    const before = turn.decision;
    errdefer turn.decision = before;
    const result = try self.accepted(turn, namespace, true, true);
    if (result.phase == .ready) return result;
    if (result.phase != .sealed) return error.TableUploadNotSealed;
    var command = try self.readCommand(allocator, turn, result);
    defer command.deinit();
    const ready = try binding(allocator, result, command.body);
    try turn.write(self.key(namespace), try ready.encode());
    return ready;
}
/// Native execution consumes only an authenticated, committed, exact ready body.
/// This proves the original external intent for a later self-message admission.
pub fn resolve(self: Self, allocator: std.mem.Allocator, turn: *s.Turn, namespace: u64) !Command.Owned {
    const upload = try self.accepted(turn, namespace, true, true);
    if (upload.phase != .ready) return error.TableUploadNotReady;
    var command = try self.readCommand(allocator, turn, upload);
    errdefer command.deinit();
    if (!std.meta.eql(try binding(allocator, upload, command.body), upload)) return error.CatalogIdentityConflict;
    return command;
}
pub const Application = enum { absent, pending, terminal };
pub fn application(self: Self, source: anytype, upload: Status) !Application {
    try upload.validate();
    try self.headerCheck(source, upload.header.principal, upload.header, false);
    if (upload.route == .none) return .absent;
    if (upload.route == .ddl) {
        const result = (try self.catalog.status(source, upload.header.principal, upload.header.operation, upload.digest)) orelse return .absent;
        return if (result.terminal()) .terminal else .pending;
    }
    // A ready command may precede CREATE for its object only if the body was
    // invalid. Binding already verified an accepted immutable definition.
    const result = (try self.catalog.mutationReceipt(source, upload.header.principal, try upload.reference())) orelse return .absent;
    if (result.route != (if (upload.route == .point) s.TableWrite.Status.Route.point else .statement)) return error.CatalogIdentityConflict;
    return if (result.state == .building) .pending else .terminal;
}
/// Cancellation of an unadmitted body closes transport only. An admitted body
/// delegates to its existing coordinator; no fifth upload write is added.
pub fn cancel(self: Self, turn: *s.Turn, namespace: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    var upload = try self.accepted(turn, namespace, false, false);
    if (upload.phase == .cancelled) return true;
    switch (try self.application(turn, upload)) {
        .terminal => return true,
        .pending => return if (upload.route == .ddl) (try self.catalog.cancel(turn, upload.header.principal, upload.header.operation, upload.digest)).terminal() else (try self.catalog.cancelMutationReference(turn, try upload.reference())).state != .building,
        .absent => {
            upload.phase = .cancelled;
            try turn.write(self.key(namespace), try upload.encode());
            return true;
        },
    }
}
/// Only a closed unadmitted upload or terminal SQL receipt permits collection.
/// Identity, body commitment and SQL reference remain permanently inspectable.
pub fn collect(self: Self, turn: *s.Turn, namespace: u64) !bool {
    const before = turn.decision;
    errdefer turn.decision = before;
    const upload = try self.accepted(turn, namespace, false, false);
    if (upload.phase != .cancelled and try self.application(turn, upload) != .terminal) return error.TableUploadStillActive;
    const pubn = self.publication(namespace);
    const descriptor = try pubn.inspect(turn, 1);
    if (!std.meta.eql(descriptor.spec, upload.spec)) return error.CatalogIdentityConflict;
    switch (descriptor.state) {
        .staging => {
            _ = try pubn.abandon(turn, 1);
            if (try turn.read(self.halfKey(namespace)) != null) try turn.write(self.halfKey(namespace), null);
        },
        .published => _ = try pubn.retire(turn, 1),
        .abandoned, .retired => return pubn.collect(turn, 1),
    }
    return false;
}

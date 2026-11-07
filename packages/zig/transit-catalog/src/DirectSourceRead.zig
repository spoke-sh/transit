//! Published raw capture reads. A descriptor authenticates provenance; only a
//! live original Stream pin and current destination policy permit disclosure.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const d = p.DataLifecycle;
const w = c.DirectTableProtocol;
const Capture = c.DirectSourceCapture;
const Stream = c.DirectStream;

pub const Publication = struct {
    reference: p.SourceCapture.Reference,
    evidence: p.SourceCapture.Evidence,
    decision: p.Transaction.Decision,
    append: p.StreamQueue.AppendReceipt,
    pub fn validate(self: Publication) !void {
        try self.reference.validate();
        try self.evidence.validate();
        try self.decision.validate();
        try self.append.validate();
        const attachment = self.append.append.capture orelse return error.InvalidSourcePublication;
        if (self.decision.outcome != .committed or self.decision.attempt.writes != 1 or self.decision.attempt.last_statement != 1 or
            !std.meta.eql(self.reference, attachment.reference) or !std.meta.eql(self.decision.attempt.transaction, attachment.transaction) or
            !std.meta.eql(self.reference.destination, self.evidence.destination)) return error.InvalidSourcePublication;
    }
    pub fn target(self: Publication) p.StreamQueue.Partition {
        return self.append.append.target;
    }
};
pub const Open = struct {
    reference: p.SourceCapture.Reference,
    operation: d.Operation,
};
pub const Handle = struct {
    definition: p.Growth.Definition,
    connection: w.Connection,
    role: ?u64,
    publication: Publication,
    read: p.StreamRead.Receipt,
    pub fn validate(self: Handle) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.connection.validate();
        if (self.role) |role| try p.Authorization.roleId(role);
        if (self.connection.role != null and self.connection.role != self.role) return error.InvalidSourceCaptureReader;
        try self.publication.validate();
        try self.read.validate();
        try self.connection.owner(self.read.request.operation);
        const request = self.read.request;
        if (request.group != null or request.timestamp != null or request.from != self.publication.append.first or
            request.until != self.publication.append.next or !std.meta.eql(request.target, self.publication.target())) return error.InvalidSourceCaptureReader;
    }
};
pub const Cursor = struct {
    handle: Handle,
    offset: u64,
    authentication: [32]u8,
    pub fn validate(self: Cursor) !void {
        try self.handle.validate();
        const total = self.handle.publication.evidence.body.bytes;
        if (self.offset > total or (self.offset != total and self.offset % Capture.storage.chunk_bytes != 0)) return error.InvalidSourceCaptureReader;
    }
    fn signature(self: Cursor, authority: c.storage.LogRead.Authority) ![32]u8 {
        try self.validate();
        if (std.mem.allEqual(u8, &authority.secret, 0)) return error.InvalidStreamReadAuthority;
        var buffer: [16 * 1024]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        try writer.writeAll("transit.source.capture.cursor.v1\x00");
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(.{ .handle = self.handle, .offset = self.offset }, &encoder);
        var mac: [32]u8 = undefined;
        std.crypto.auth.hmac.sha2.HmacSha256.create(&mac, writer.buffered(), &authority.secret);
        return mac;
    }
    fn issue(handle: Handle, offset: u64, authority: c.storage.LogRead.Authority) !Cursor {
        var result: Cursor = .{ .handle = handle, .offset = offset, .authentication = undefined };
        result.authentication = try result.signature(authority);
        return result;
    }
    fn verify(self: Cursor, authority: c.storage.LogRead.Authority) !void {
        if (!std.crypto.timing_safe.eql([32]u8, try self.signature(authority), self.authentication)) return error.SourceCaptureCursorUnauthenticated;
    }
};
pub const Request = union(enum) {
    inspect: p.SourceCapture.Reference,
    open: Open,
    inspect_open: Open,
    cancel_open: Open,
    next: Cursor,
    close: struct { handle: Handle, operation: d.Operation },
    pub fn reference(self: Request) p.SourceCapture.Reference {
        return switch (self) {
            .inspect => |value| value,
            .open, .inspect_open, .cancel_open => |value| value.reference,
            .next => |value| value.handle.publication.reference,
            .close => |value| value.handle.publication.reference,
        };
    }
    pub fn mutation(self: Request) bool {
        return self == .open or self == .cancel_open or self == .close;
    }
    pub fn identity(self: Request) ?d.Operation {
        return switch (self) {
            .open, .cancel_open => |value| value.operation,
            .close => |value| value.operation,
            else => null,
        };
    }
    pub fn control(self: Request) bool {
        return self == .inspect or self == .inspect_open or self == .cancel_open or self == .close;
    }
    pub fn validate(self: Request, connection: w.Connection) !void {
        try connection.validate();
        try self.reference().validate();
        try connection.object(self.reference().destination.object);
        switch (self) {
            .inspect => {},
            .open, .inspect_open, .cancel_open => |value| try connection.owner(value.operation),
            .next => |value| {
                try value.validate();
                if (!std.meta.eql(value.handle.connection, connection)) return error.CatalogDenied;
            },
            .close => |value| {
                try value.handle.validate();
                try connection.owner(value.operation);
                if (!std.meta.eql(value.handle.connection, connection) or std.meta.eql(value.operation, value.handle.read.request.operation)) return error.InvalidSourceCaptureReader;
            },
        }
    }
};
pub const Page = struct {
    offset: u64,
    bytes: w.Binary,
    next: Cursor,
    complete: bool,
};
pub const Result = union(enum) {
    publication: Publication,
    opened: Cursor,
    original: ?Handle,
    abandoned: struct { publication: Publication, closure: p.LogWorkload.Closure },
    page: Page,
    closed: p.StreamRead.ReleaseReceipt,
    recovering: c.storage.StreamPartition.Recovery,
    pub fn deinit(self: Result, allocator: std.mem.Allocator) void {
        if (self == .page) {
            @memset(@constCast(self.page.bytes.base64), 0);
            allocator.free(self.page.bytes.base64);
        }
    }
};
pub fn validateResult(allocator: std.mem.Allocator, connection: w.Connection, request: Request, result: Result) !void {
    try request.validate(connection);
    if (result == .recovering) {
        try result.recovering.position.validate();
        if (result.recovering.complete or result.recovering.examined == 0 or result.recovering.examined > 256 or result.recovering.position.next_lsn == 0) return error.InvalidSourceCaptureReader;
        return;
    }
    switch (request) {
        .inspect => |reference| {
            if (result != .publication) return error.InvalidSourceCaptureReader;
            try result.publication.validate();
            if (!std.meta.eql(result.publication.reference, reference)) return error.InvalidSourceCaptureReader;
        },
        .open, .inspect_open, .cancel_open => |original| {
            if (result == .abandoned) {
                const abandoned = result.abandoned;
                try abandoned.publication.validate();
                if (!std.meta.eql(abandoned.publication.reference, original.reference)) return error.InvalidSourceCaptureReader;
                try abandoned.closure.requireStream(.{ .consume = .{ .target = abandoned.publication.target(), .operation = original.operation, .group = null, .from = abandoned.publication.append.first, .until = abandoned.publication.append.next, .timestamp = null } });
                return;
            }
            if (request != .open) {
                if (result != .original) return error.InvalidSourceCaptureReader;
                if (result.original) |handle| {
                    try handle.validate();
                    if (!std.meta.eql(handle.connection, connection) or !std.meta.eql(handle.publication.reference, original.reference) or
                        !std.meta.eql(handle.read.request.operation, original.operation)) return error.InvalidSourceCaptureReader;
                } else if (request != .inspect_open) return error.InvalidSourceCaptureReader;
                return;
            }
            if (result != .opened) return error.InvalidSourceCaptureReader;
            try result.opened.validate();
            if (result.opened.offset != 0 or !std.meta.eql(result.opened.handle.connection, connection) or
                !std.meta.eql(result.opened.handle.publication.reference, original.reference) or
                !std.meta.eql(result.opened.handle.read.request.operation, original.operation)) return error.InvalidSourceCaptureReader;
        },
        .next => |cursor| {
            if (result != .page) return error.InvalidSourceCaptureReader;
            const page = result.page;
            try page.next.validate();
            if (!std.meta.eql(page.next.handle, cursor.handle) or page.offset != cursor.offset) return error.InvalidSourceCaptureReader;
            const bytes = try page.bytes.decode(allocator, Capture.storage.chunk_bytes);
            defer allocator.free(bytes);
            const total = cursor.handle.publication.evidence.body.bytes;
            if (bytes.len != @min(Capture.storage.chunk_bytes, total - cursor.offset) or
                page.next.offset != try std.math.add(u64, cursor.offset, bytes.len) or page.complete != (page.next.offset == total)) return error.InvalidSourceCaptureReader;
        },
        .close => |value| {
            if (result != .closed) return error.InvalidSourceCaptureReader;
            try result.closed.requireRelease(.{ .operation = value.operation, .target = value.handle.publication.target(), .read = value.handle.read.handle() });
        },
    }
}

/// The service serializes this with Stream release/maintenance and provides its
/// private cursor key. All returned bytes own output allocations.
pub fn apply(scratch: std.mem.Allocator, output: std.mem.Allocator, catalog: *c.DirectCatalog, slot: *?Stream.Cached, options: c.storage.StreamPartition.Options, environment: Stream.Environment, connection: w.Connection, request: Request, policy: c.DirectCatalog.Policy) !Result {
    try request.validate(connection);
    if (connection.principal != policy.subject.principal() or (connection.role != null and connection.role != policy.effective_role)) return error.CatalogDenied;
    const publication = try catalog.capturePublication(request.reference(), policy);
    if (request == .inspect) return .{ .publication = publication };
    const authorization = try catalog.logAuthorization(scratch, .stream, publication.target(), .read, policy);
    const current = authorization.guard;
    if (request == .open or request == .inspect_open or request == .cancel_open) {
        const original = switch (request) {
            inline .open, .inspect_open, .cancel_open => |value| value,
            else => unreachable,
        };
        const read: p.StreamRead.Request = .{ .target = publication.target(), .operation = original.operation, .group = null, .from = publication.append.first, .until = publication.append.next, .timestamp = null };
        const action: Stream.Request = switch (request) {
            .open => .{ .mutate = .{ .work = .{ .consume = read }, .payload = null } },
            .inspect_open => .{ .operation = .{ .consume = read } },
            .cancel_open => .{ .cancel = .{ .consume = read } },
            else => unreachable,
        };
        const result = try Stream.apply(scratch, output, catalog, slot, options, environment, action, policy);
        if (result == .recovering) return .{ .recovering = result.recovering };
        if (result == .operation and result.operation == null and request == .inspect_open) return .{ .original = null };
        if (result == .operation and result.operation != null and result.operation.? == .closed) return .{ .abandoned = .{ .publication = publication, .closure = result.operation.?.closed } };
        if (result != .operation or result.operation == null or result.operation.? != .consume) return error.InvalidSourceCaptureReader;
        const handle: Handle = .{ .definition = p.Growth.current_definition, .connection = connection, .role = policy.effective_role, .publication = publication, .read = result.operation.?.consume };
        if (request != .open) {
            try check(current);
            return .{ .original = handle };
        }
        const live = try Stream.apply(scratch, output, catalog, slot, options, environment, .{ .cursor = .{ .target = publication.target(), .read = handle.read.handle() } }, policy);
        if (live == .recovering) return .{ .recovering = live.recovering };
        if (live != .cursor) return error.InvalidSourceCaptureReader;
        const cursor = try Cursor.issue(handle, 0, environment.authority);
        try check(current);
        return .{ .opened = cursor };
    }
    const handle = if (request == .next) request.next.handle else request.close.handle;
    if (handle.role != policy.effective_role) return error.CatalogDenied;
    if (!std.meta.eql(publication, handle.publication)) return error.InvalidSourceCaptureReader;
    if (request == .close) {
        const result = try Stream.apply(scratch, output, catalog, slot, options, environment, .{ .mutate = .{ .work = .{ .release = .{ .operation = request.close.operation, .target = publication.target(), .read = handle.read.handle() } }, .payload = null } }, policy);
        if (result == .recovering) return .{ .recovering = result.recovering };
        if (result != .operation or result.operation == null or result.operation.? != .release) return error.InvalidSourceCaptureReader;
        try check(current);
        return .{ .closed = result.operation.?.release };
    }
    try request.next.verify(environment.authority);
    // Liveness is checked even for repeated and empty terminal requests. The
    // supplied read receipt is compared to its retained authoritative basis.
    const live = try Stream.apply(scratch, output, catalog, slot, options, environment, .{ .cursor = .{ .target = publication.target(), .read = handle.read.handle() } }, policy);
    if (live == .recovering) return .{ .recovering = live.recovering };
    if (live != .cursor) return error.InvalidSourceCaptureReader;
    const basis = try c.storage.LogRead.load(scratch, catalog.data_objects, handle.read.handle());
    if (!std.meta.eql(try basis.receipt(handle.read.source), handle.read)) return error.InvalidSourceCaptureReader;
    const manifest = try Capture.Manifest.load(scratch, catalog.data_objects, publication.reference);
    if (!std.meta.eql(manifest.evidence, publication.evidence)) return error.InvalidSourceCapture;
    var raw: [Capture.storage.chunk_bytes]u8 = undefined;
    defer @memset(&raw, 0);
    const bytes = if (request.next.offset == manifest.evidence.body.bytes) raw[0..0] else blk: {
        const chunk = try Capture.storage.lookup(&catalog.store.index, manifest.inventory, request.next.offset, manifest.evidence.body.bytes);
        break :blk try Capture.storage.read(catalog.data_objects, manifest.candidate, chunk, &raw);
    };
    const encoded = try w.Binary.encode(output, bytes);
    errdefer {
        @memset(@constCast(encoded.base64), 0);
        output.free(encoded.base64);
    }
    const after = try std.math.add(u64, request.next.offset, bytes.len);
    const next = try Cursor.issue(handle, after, environment.authority);
    try check(current);
    return .{ .page = .{ .offset = request.next.offset, .bytes = encoded, .next = next, .complete = after == manifest.evidence.body.bytes } };
}
fn check(guard: c.storage.PublicationGuard) !void {
    _ = try guard.acquire(guard.context);
    guard.release(guard.context);
}

test "SOURCE reader consumes independent signed continuation and rejects tampering" {
    const t = std.testing;
    const Fixture = struct {
        saved: struct { definition: p.Growth.Definition, connection: w.Connection, open: Open, release: d.Operation },
        cursor: Cursor,
        request: w.Request,
        public_key: [32]u8,
    };
    const parsed = try p.Json.parseFromSlice(Fixture, t.allocator, @embedFile("fixtures/source-capture-read-v1.json"));
    defer parsed.deinit();
    const fixture = parsed.value;
    try fixture.request.validate(t.allocator);
    try fixture.request.proof.verify(fixture.public_key);
    const authority = try c.storage.LogRead.Authority.init(@splat(4));
    try fixture.cursor.verify(authority);
    try t.expectEqualDeep(fixture.cursor, fixture.request.action.capture_read.next);
    var changed = fixture.cursor;
    changed.offset = Capture.storage.chunk_bytes;
    try t.expectError(error.SourceCaptureCursorUnauthenticated, changed.verify(authority));
    changed = fixture.cursor;
    changed.authentication[0] ^= 1;
    try t.expectError(error.SourceCaptureCursorUnauthenticated, changed.verify(authority));
    var request = fixture.request;
    request.action.capture_read.next = changed;
    try t.expectError(error.InvalidAuthorizationCredential, request.validate(t.allocator));
    changed = fixture.cursor;
    changed.handle.connection.principal += 1;
    try t.expectError(error.CatalogDenied, (Request{ .next = changed }).validate(fixture.saved.connection));
    const encoded = try p.Json.valueAlloc(t.allocator, fixture.cursor);
    defer t.allocator.free(encoded);
    const at = std.mem.indexOf(u8, encoded, @tagName(p.Growth.current_definition)).?;
    encoded[at] = '0';
    try t.expectError(error.InvalidJsonShape, p.Json.parseFromSlice(Cursor, t.allocator, encoded));
}

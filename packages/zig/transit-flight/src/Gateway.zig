//! Specialized finite serving adapter. Durable query identity and result reads
//! stay in transit-query; credentials select fixed scopes, never request fields.
const std = @import("std");
const root = @import("root.zig");
const q = root.query;
const p = q.protocol;
const f = q.fuze;
const s = root.serving;
const w = root.Wire;
const pb = root.grpc.protobuf;
const server = root.grpc.Server;
const Io = std.Io;
const Self = @This();
pub const max_callers = 8;
pub const request_bytes = 8 * 1024 * 1024;
pub const arrow_bytes = root.Metadata.working_bytes;
pub const Connection = struct { realm: u64, principal: u64, source: u64, resource: u64, table: u32, name: []const u8, requester: u64, requests: u64 };
pub const Caller = struct {
    /// Hash of a private high-entropy Bearer credential; raw tokens never persist
    /// in gateway state, telemetry or durable query payloads.
    credential: [32]u8,
    connection: Connection,
    key: p.Ed25519.KeyPair,
    service: u64,
    ingress_resource: u64,
    binding_revision: u64,
    schema: f.model.Schema,
    pub fn scope(self: Caller) root.Ticket.Scope {
        const c = self.connection;
        return .{ .realm = c.realm, .principal = c.principal, .service = self.service, .binding_revision = self.binding_revision, .ingress = c.requester, .requests = c.requests, .source = c.source, .resource = c.resource, .table = c.table };
    }
};
pub const Configuration = struct {
    url: []const u8,
    inspector: u64,
    inspector_key: p.Ed25519.KeyPair,
    ticket_key: p.Ed25519.KeyPair,
    ticket_ttl_ms: u32 = 60000,
    clock_error_ms: u32 = 1000,
    native_timeout_ms: u32 = 5000,
    callers: []const Caller,
    pub fn validate(self: Configuration) !void {
        if (self.callers.len == 0 or self.callers.len > max_callers or self.inspector == 0 or self.inspector > p.max_counter or self.ticket_ttl_ms < 1000 or self.ticket_ttl_ms > 300000 or self.clock_error_ms > 5000 or self.native_timeout_ms == 0 or self.native_timeout_ms > 30000) return error.InvalidFlightConfiguration;
        for (self.callers, 0..) |caller, index| {
            try caller.schema.validate();
            _ = try f.model.Name.init(caller.connection.name);
            if (caller.schema.value_type != .int64 or caller.ingress_resource != caller.connection.requests) return error.InvalidFlightConfiguration;
            const scope = caller.scope();
            inline for (@typeInfo(root.Ticket.Scope).@"struct".field_names) |name| try s.Model.identity(@field(scope, name));
            for (self.callers[0..index]) |previous| if (std.mem.eql(u8, &caller.credential, &previous.credential) or caller.connection.principal == previous.connection.principal or caller.connection.requester == previous.connection.requester) return error.InvalidFlightConfiguration;
        }
    }
};
config: Configuration,
active: [max_callers]std.atomic.Value(u8) = @splat(.init(0)),
diagnostics: ?*q.wire.observability.telemetry.Runtime = null,

pub fn credentialHash(token: []const u8) ![32]u8 {
    if (token.len < 32 or token.len > 128) return error.FlightUnauthenticated;
    for (token) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-' and byte != '_') return error.FlightUnauthenticated;
    return digest(token);
}
fn authenticate(self: *Self, request: server.Request) !usize {
    // Scope is deployment configuration, never a forwarded identity claim.
    for ([_][]const u8{ "x-transit-principal", "x-transit-realm", "x-transit-resource", "x-transit-upstream", "x-transit-service" }) |name| {
        if (try request.header(name) != null) return error.InvalidFlightCommand;
    }
    const authorization = (try request.header("authorization")) orelse return error.FlightUnauthenticated;
    if (!std.mem.startsWith(u8, authorization, "Bearer ")) return error.FlightUnauthenticated;
    const hash = try credentialHash(authorization[7..]);
    var matched: ?usize = null;
    for (self.config.callers, 0..) |caller, index| if (std.crypto.timing_safe.eql([32]u8, hash, caller.credential)) {
        matched = index;
    };
    return matched orelse error.FlightUnauthenticated;
}
pub fn isControl(_: *Self, request: server.Request) bool {
    const method = request.method() catch return false;
    return std.mem.eql(u8, method, root.method_prefix ++ "GetSchema") or std.mem.eql(u8, method, root.method_prefix ++ "ListActions");
}
pub fn connectionError(self: *Self, err: anyerror, _: bool) void {
    if (self.diagnostics) |diagnostics| diagnostics.event(.{ .name = "flight.connection", .level = .warn, .outcome = .failed, .error_type = @errorName(err) });
}
pub fn handle(self: *Self, io: Io, allocator: std.mem.Allocator, request: server.Request, response: *server.Response) !void {
    // Finite enum/tag telemetry only, never SQL, ticket, credential or result.
    var observation = q.wire.observability.begin(self.diagnostics, .client_request, "flight", null);
    defer observation.finish();
    var sql_diagnostic: ?f.SqlDiagnostic = null;
    var query_diagnostic: ?root.Diagnostic = null;
    var attempt_diagnostic: ?p.Diagnostic = null;
    self.handleOnce(io, allocator, request, response, &sql_diagnostic, &query_diagnostic, &attempt_diagnostic) catch |err| {
        observation.fail(err);
        if (err == error.Canceled or err == error.GrpcCancelled or response.finished) return err;
        if (query_diagnostic) |diagnostic| {
            var buffer: [128]u8 = undefined;
            var message: std.Io.Writer = .fixed(&buffer);
            try diagnostic.render(&message);
            return root.DiagnosticDetail.finish(response, diagnostic.status(), message.buffered(), diagnostic.structured() catch null);
        }
        if (sql_diagnostic) |diagnostic| {
            var buffer: [128]u8 = undefined;
            var message: std.Io.Writer = .fixed(&buffer);
            try diagnostic.renderRemote(&message);
            const status: u8 = switch (diagnostic.kind) {
                .unsupported, .grammar_only, .interface => 12,
                .syntax, .binding, .limit => 3,
            };
            return root.DiagnosticDetail.finish(response, status, message.buffered(), diagnostic.structured() catch null);
        }
        const status = root.DiagnosticDetail.statusFor(err);
        return root.DiagnosticDetail.finish(response, status, switch (status) {
            16 => "credential required",
            7 => "current access denied",
            9 => "result or service unavailable",
            12 => "Flight supports finite read-only queries and metadata; writes require an authorized mutation client. See console .help INSERT",
            8 => "bounded capacity exhausted",
            10 => "admission conflict; retain request identity",
            14 => "unavailable; retain request identity",
            15 => "invalid result evidence; retain request identity",
            3 => "invalid request",
            else => "finite query failed",
        }, attempt_diagnostic orelse (root.DiagnosticDetail.attempt(err, status) catch null));
    };
}
fn handleOnce(self: *Self, io: Io, allocator: std.mem.Allocator, request: server.Request, response: *server.Response, sql_diagnostic: *?f.SqlDiagnostic, query_diagnostic: *?root.Diagnostic, attempt_diagnostic: *?p.Diagnostic) !void {
    const index = try self.authenticate(request);
    const control = self.isControl(request);
    // Independent metadata/control capacity: a data stream cannot own this slot.
    if (!control) {
        const previous = self.active[index].fetchAdd(1, .acquire);
        if (previous >= 2) {
            _ = self.active[index].fetchSub(1, .release);
            return error.FlightCallerCapacity;
        }
    }
    defer if (!control) {
        _ = self.active[index].fetchSub(1, .release);
    };
    const memory = try allocator.alloc(u8, request_bytes);
    defer allocator.free(memory);
    defer std.crypto.secureZero(u8, memory);
    var bounded: std.heap.FixedBufferAllocator = .init(memory);
    const alloc = bounded.allocator();
    const workspace = try allocator.alloc(u8, arrow_bytes);
    defer allocator.free(workspace);
    defer std.crypto.secureZero(u8, workspace);
    var wire = q.wire.Client.init(alloc, io, self.config.url);
    defer wire.deinit();
    wire.timeout_ms = self.config.native_timeout_ms;
    wire.observer = self.diagnostics;
    const caller = self.config.callers[index];
    var client: q.UnifiedClient = .{ .wire = &wire, .connection = .{ .realm = caller.connection.realm, .principal = caller.connection.principal, .source = caller.connection.source, .resource = caller.connection.resource, .requester = caller.connection.requester, .requests = caller.connection.requests }, .key = caller.key };
    const adapter: s.Adapter = .{ .service = caller.service, .ingress = caller.connection.requester, .resource = caller.ingress_resource, .resources = .{ .wire = &wire, .realm = caller.connection.realm, .principal = self.config.inspector, .key = self.config.inspector_key } };
    var call: Call = .{ .gateway = self, .io = io, .allocator = alloc, .caller = caller, .client = &client, .adapter = adapter, .response = response, .workspace = workspace, .sql_diagnostic = sql_diagnostic, .query_diagnostic = query_diagnostic, .attempt_diagnostic = attempt_diagnostic };
    return call.run(request) catch |err| {
        if (sql_diagnostic.* == null and query_diagnostic.* == null) {
            if (attempt_diagnostic.* == null) attempt_diagnostic.* = root.DiagnosticDetail.attempt(err, root.DiagnosticDetail.statusFor(err)) catch null;
            if (attempt_diagnostic.*) |*detail| {
                // A denied read discloses no retained query identity. A selected
                // first sequence is caller context only after current access.
                if (detail.category != .access and detail.identity == null) if (call.first_sequence) |sequence| {
                    detail.identity = .{ .domain = .query, .id = .init(sequence), .realm = .init(caller.connection.realm), .resource = .init(caller.connection.requests) };
                    for (&detail.actions) |*slot| if (slot.*) |*action| {
                        action.target = detail.identity;
                    };
                };
                if (wire.last_rejection) |cause| {
                    var present = false;
                    for (detail.facts) |slot| if (slot) |fact| {
                        if (fact.field == .native_cause) present = true;
                    };
                    if (!present) detail.text(.native_cause, .authority, @tagName(cause)) catch {};
                }
            }
        }
        return err;
    };
}
fn digest(bytes: []const u8) [32]u8 {
    var value: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &value, .{});
    return value;
}
const Call = struct {
    gateway: *Self,
    io: Io,
    allocator: std.mem.Allocator,
    caller: Caller,
    client: *q.UnifiedClient,
    adapter: s.Adapter,
    response: *server.Response,
    sql_diagnostic: *?f.SqlDiagnostic,
    query_diagnostic: *?root.Diagnostic,
    attempt_diagnostic: *?p.Diagnostic,
    first_sequence: ?u64 = null,
    workspace: []u8,
    output: [f.Unified.Arrow.segment_bytes]u8 = undefined,
    next_sequence: ?u64 = null,
    ticket_buffer: [root.Ticket.max_bytes]u8 = undefined,
    fn run(self: *Call, request: server.Request) !void {
        const method = try request.method();
        if (std.mem.eql(u8, method, root.method_prefix ++ "DoGet")) {
            var ticket = try pb.decode(w.Ticket, self.allocator, request.message, .{ .max_arena_bytes = 65536 });
            defer ticket.deinit();
            return self.get(ticket.value.ticket);
        }
        if (std.mem.eql(u8, method, root.method_prefix ++ "GetFlightInfo") or std.mem.eql(u8, method, root.method_prefix ++ "GetSchema")) {
            var descriptor = try pb.decode(w.FlightDescriptor, self.allocator, request.message, .{ .max_arena_bytes = 65536 });
            defer descriptor.deinit();
            if (descriptor.value.type != .CMD or descriptor.value.path.len != 0 or descriptor.value.cmd.len == 0 or descriptor.value.cmd.len > 8192) return error.InvalidFlightCommand;
            return self.describe(request, descriptor.value, std.mem.endsWith(u8, method, "/GetSchema"));
        }
        if (std.mem.eql(u8, method, root.method_prefix ++ "ListActions")) {
            var empty = try pb.decode(w.Empty, self.allocator, request.message, .{ .max_arena_bytes = 65536 });
            defer empty.deinit();
            try self.authorize(false);
            return; // No supported actions, especially no prepare/transaction action.
        }
        return error.UnsupportedFlightCommand;
    }
    fn now(self: *Call) !u64 {
        const time = Io.Clock.real.now(self.io).toMilliseconds();
        if (time < 0 or time > p.max_counter) return error.ClockUnavailable;
        return advanceTime(@intCast(time), self.gateway.config.clock_error_ms);
    }
    fn authorize(self: *Call, admission: bool) !void {
        try self.response.check();
        const caller = self.caller;
        const signed = try s.Model.SignedRead.sign(.{ .realm = caller.connection.realm, .principal = caller.connection.principal, .service = caller.service, .ingress = caller.connection.requester, .kind = .discovery }, caller.key);
        const discovery = try self.adapter.read(signed, caller.key.public_key.toBytes());
        if (admission) {
            const binding = discovery.binding orelse return error.ServiceUnpublished;
            if (!binding.published or binding.revision != caller.binding_revision or binding.target != caller.connection.source or binding.active_limit != 1) return error.ServiceUnpublished;
            const policy = try self.adapter.readerFor(caller.connection.principal, &.{});
            if (!policy.policy.commands) return error.ServingDenied;
        }
        // Inspection alone is insufficient, including metadata and empty rows.
        inline for (.{ "resource", "requests" }) |field| {
            const access = (self.client.resources().query(.{ .read_access = @field(caller.connection, field) }) catch |err| {
                if (err == error.Rejected) switch (self.client.wire.last_rejection orelse return err) {
                    .StateResourceExpired, .UnknownStateResource, .RetiredProcess => return error.ResourceUnavailable,
                    else => {},
                };
                return err;
            }).body.read_access;
            if (access.phase != .active) return error.QuerySourceUnavailable;
        }
        _ = try self.client.describe(self.definition());
        try self.response.check();
    }
    fn send(self: *Call, value: anytype) !void {
        var bytes: [16384]u8 = undefined;
        defer std.crypto.secureZero(u8, &bytes);
        const size = try pb.encodeInto(&bytes, value, .{});
        try self.response.send(bytes[0..size]);
    }
    fn decodeCommand(self: *Call, bytes: []const u8) !pb.Decoded(w.Any) {
        return pb.decode(w.Any, self.allocator, bytes, .{ .max_arena_bytes = 65536 });
    }
    fn describe(self: *Call, request: server.Request, descriptor: w.FlightDescriptor, schema_only: bool) !void {
        var command = try self.decodeCommand(descriptor.cmd);
        defer command.deinit();
        const statement = std.mem.eql(u8, command.value.type_url, root.command_prefix ++ "CommandStatementQuery");
        try self.authorize(statement and !schema_only);
        var schema: []const u8 = undefined;
        var reference: root.Ticket.Reference = undefined;
        var rows: u64 = 0;
        var total_bytes: i64 = 0;
        if (statement) {
            var decoded = try pb.decode(w.CommandStatementQuery, self.allocator, command.value.value, .{ .max_arena_bytes = 65536 });
            defer decoded.deinit();
            if (decoded.value.transaction_id != null) return error.UnsupportedFlightCommand;
            if (schema_only) {
                var detail: f.Sql.Binding = .{};
                schema = root.Metadata.querySchemaDiagnostic(self.caller.connection.name, self.caller.schema, decoded.value.query, &self.output, self.workspace, &detail) catch |err| {
                    self.sql_diagnostic.* = f.SqlDiagnostic.bound(decoded.value.query, err, false, detail);
                    return err;
                };
            } else {
                const raw_sequence = (try request.header("x-transit-request-sequence")) orelse return error.InvalidQueryIdentity;
                if (raw_sequence.len == 0 or raw_sequence.len > 16 or raw_sequence[0] == '0') return error.InvalidQueryIdentity;
                for (raw_sequence) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidQueryIdentity;
                const sequence = std.fmt.parseInt(u64, raw_sequence, 10) catch return error.InvalidQueryIdentity;
                const correlation = sequence; // Upload namespace is the caller's first native sequence.
                self.next_sequence = try self.upload(decoded.value.query, sequence);
                const manifest = try self.awaitResult(correlation);
                // Qualify within the existing finite transport profile before
                // issuing access; no hidden whole-result buffer or raised bound.
                if (manifest.checkpoint.progress.segments == 0 or manifest.checkpoint.progress.segments > 63 or manifest.checkpoint.bytes > 240 * 1024) return error.GrpcBudgetExceeded;
                var decoded_rows: f.Unified.Inspect.Batch = undefined;
                const captured = try self.client.page(correlation, null, self.allocator, self.workspace, &self.output, &decoded_rows);
                if (!std.meta.eql(captured.manifest, manifest)) return error.InvalidResultManifest;
                schema = (try self.tableParts(captured, &decoded_rows)).schema_message;
                reference = .{ .statement = .{ .correlation = correlation, .manifest = try manifestDigest(manifest) } };
                rows = manifest.checkpoint.progress.rows;
                // Wire bytes differ from the verified durable cell encoding.
                total_bytes = -1;
            }
        } else {
            if (descriptor.cmd.len > root.Ticket.max_command_bytes) return error.InvalidFlightCommand;
            const bytes = try root.Metadata.encode(command.value, self.caller.connection.name, self.caller.schema, &self.output, self.workspace);
            const ipc = try root.Ipc.parts(bytes, self.workspace);
            schema = ipc.schema_message;
            rows = ipc.rows;
            total_bytes = @intCast(bytes.len);
            reference = .{ .metadata = .{ .command = descriptor.cmd, .digest = digest(bytes) } };
        }
        try self.authorize(false);
        if (schema_only) return self.send(w.SchemaResult{ .schema = schema });
        const expires = try advanceTime(try self.now(), self.gateway.config.ticket_ttl_ms);
        const bytes = try (root.Ticket{ .scope = self.caller.scope(), .expires_ms = expires, .reference = reference }).issue(self.gateway.config.ticket_key, &self.ticket_buffer);
        // Flight SQL requires TicketStatementQuery in a protobuf Any envelope.
        var statement_buffer: [2048]u8 = undefined;
        var ticket_envelope: [2304]u8 = undefined;
        const ticket_bytes = if (statement) blk: {
            const size = try pb.encodeInto(&statement_buffer, w.TicketStatementQuery{ .statement_handle = bytes }, .{});
            const envelope_size = try pb.encodeInto(&ticket_envelope, w.Any{ .type_url = root.command_prefix ++ "TicketStatementQuery", .value = statement_buffer[0..size] }, .{});
            break :blk ticket_envelope[0..envelope_size];
        } else bytes;
        const endpoint: w.FlightEndpoint = .{ .ticket = .{ .ticket = ticket_bytes }, .expiration_time = .{ .seconds = @intCast(expires / 1000), .nanos = @intCast((expires % 1000) * 1000000) } };
        const metadata = if (self.next_sequence) |next| try std.json.Stringify.valueAlloc(self.allocator, .{ .version = @as(u8, 1), .next_sequence = next }, .{}) else "";
        try self.send(w.FlightInfo{ .app_metadata = metadata, .schema = schema, .flight_descriptor = descriptor, .endpoint = &.{endpoint}, .total_records = @intCast(rows), .total_bytes = @intCast(total_bytes), .ordered = true });
    }
    fn definition(self: *Call) q.SourceDefinition {
        return .{ .resource = self.caller.connection.resource, .source = .{ .table = .{ .id = self.caller.connection.table, .schema = self.caller.schema } } };
    }
    fn manifestDigest(manifest: q.UnifiedRecords.Manifest) ![32]u8 {
        var bytes: [q.UnifiedRecords.Manifest.max_bytes]u8 = undefined;
        return digest(try manifest.encode(&bytes));
    }
    /// Freeze a deterministic sequence of current upload commands. A repeated
    /// HTTP request recreates the same bytes, including after host loss; it never
    /// reads a new native sequence or substitutes a different operation.
    fn upload(self: *Call, sql: []const u8, first: u64) !u64 {
        if (first == 0 or first > p.max_counter) return error.InvalidQueryIdentity;
        const limits: q.Bundle.Limits = .{ .pages = 4096, .segments = 63, .result_bytes = 240 * 1024 };
        const description = try self.client.describe(self.definition());
        if (!description.limits.permits(limits)) {
            self.attempt_diagnostic.* = root.DiagnosticDetail.budget(description.limits, limits) catch null;
            return error.QueryBudgetExceeded;
        }
        var detail: f.Sql.Binding = .{};
        const bundle = q.Bundle.fromSqlDiagnostic(self.allocator, self.definition(), try .init(self.caller.connection.name), sql, limits, &detail) catch |err| {
            self.sql_diagnostic.* = f.SqlDiagnostic.bound(sql, err, false, detail);
            return err;
        };
        const reference = try bundle.reference(self.caller.connection.requests, first);
        var encoded: [q.Bundle.max_bytes]u8 = undefined;
        const bytes = try bundle.encode(&encoded);
        const parts = (bytes.len + q.UnifiedRequest.part_bytes - 1) / q.UnifiedRequest.part_bytes;
        if (first > p.max_counter - parts - 3) return error.InvalidQueryIdentity;
        self.first_sequence = first;
        var sequence = first;
        try self.uploadStep(sequence, .{ .begin = reference });
        sequence += 1;
        var offset: usize = 0;
        while (offset < bytes.len) {
            const ordinal: u32 = @intCast(offset / q.station.Publication.chunk_bytes);
            const second = offset % q.station.Publication.chunk_bytes != 0;
            const end = @min(bytes.len, offset + q.UnifiedRequest.part_bytes);
            try self.uploadStep(sequence, .{ .part = .{ .namespace = first, .ordinal = ordinal, .second = second, .bytes = bytes[offset..end] } });
            sequence += 1;
            offset = end;
        }
        try self.uploadStep(sequence, .{ .seal = first });
        try self.uploadStep(sequence + 1, .{ .submit = first });
        return sequence + 2;
    }
    fn uploadStep(self: *Call, sequence: u64, command: q.UnifiedRequest.Command) !void {
        try self.authorize(true);
        const prepared: q.UnifiedClient.Prepared = .{ .signed = try p.Growth.sign(.{ .realm = self.caller.connection.realm, .principal = self.caller.connection.principal, .sequence = sequence, .command = .{ .send = .{ .pid = self.caller.connection.requester, .value = try (q.station.Frame{ .kind = .cast, .payload = try command.encode() }).encode() } } }, self.caller.key) };
        const receipt = self.client.submit(prepared) catch |err| {
            const identity: p.Diagnostic.Identity = .{ .domain = .query, .id = .init(self.first_sequence.?), .sequence = .init(sequence), .realm = .init(self.caller.connection.realm), .resource = .init(self.caller.connection.requests) };
            self.attempt_diagnostic.* = q.ApiDiagnostic.attempt("Flight query upload", .submit, null, err, .{}, true, identity) catch null;
            if (self.attempt_diagnostic.*) |*detail| if (self.client.wire.last_rejection) |reason| {
                detail.text(.native_cause, .authority, @tagName(reason)) catch {};
            };
            if (self.attempt_diagnostic.*) |*detail| if (detail.outcome == .unknown) {
                detail.message = p.Diagnostic.Message.init("The upload command outcome is unknown. Reconcile with the identical original GetFlightInfo SQL and first x-transit-request-sequence; do not submit a replacement statement.") catch unreachable;
            };
            if (err == error.Rejected or err == error.Conflict) switch (self.client.wire.last_rejection orelse return err) {
                .ConflictingRetry, .SequenceGap, .RetryHorizonExceeded => return error.FlightSequenceConflict,
                else => {},
            };
            return err;
        };
        while (true) {
            try self.response.check();
            switch (try self.client.observe(receipt.position)) {
                .committed => return,
                .rejected => return error.QuerySourceUnavailable,
                .pending => try self.io.sleep(.fromMilliseconds(100), .awake),
            }
        }
    }
    fn awaitResult(self: *Call, namespace: u64) !q.UnifiedRecords.Manifest {
        while (true) {
            try self.response.check();
            const status = self.client.status(namespace) catch |err| {
                if (q.wire.Client.unavailable(err) or self.client.readConflict(err)) {
                    try self.io.sleep(.fromMilliseconds(100), .awake);
                    continue;
                }
                return err;
            };
            if (status) |current| switch (current.phase) {
                .complete => {
                    const opened = try q.UnifiedResult.open(current.manifest orelse return error.InvalidResultManifest, .{ .resource = self.caller.connection.resource, .source = self.caller.connection.source, .requester = self.caller.connection.requester, .correlation = current.correlation, .request = current.reference }, self.client.resources(), self.allocator);
                    return opened.manifest;
                },
                .denied, .cancelled, .retired, .rejected => {
                    try self.authorize(false);
                    self.query_diagnostic.* = .{ .namespace = namespace, .phase = current.phase, .failure = current.failure };
                    return error.TerminalQueryFailure;
                },
                else => {},
            };
            try self.io.sleep(.fromMilliseconds(100), .awake);
        }
    }
    fn get(self: *Call, encoded: []const u8) !void {
        var bytes = encoded;
        var envelope: ?pb.Decoded(w.Any) = null;
        defer if (envelope) |*value| value.deinit();
        var statement: ?pb.Decoded(w.TicketStatementQuery) = null;
        defer if (statement) |*value| value.deinit();
        if (!std.mem.startsWith(u8, bytes, "FTK1")) {
            envelope = try self.decodeCommand(bytes);
            if (!std.mem.eql(u8, envelope.?.value.type_url, root.command_prefix ++ "TicketStatementQuery")) return error.InvalidFlightTicket;
            statement = try pb.decode(w.TicketStatementQuery, self.allocator, envelope.?.value.value, .{ .max_arena_bytes = 65536 });
            bytes = statement.?.value.statement_handle;
        }
        const ticket = try root.Ticket.decode(bytes, self.caller.scope(), try self.now(), self.gateway.config.ticket_key.public_key);
        try self.authorize(false);
        switch (ticket.reference) {
            .metadata => |value| {
                var command = try self.decodeCommand(value.command);
                defer command.deinit();
                const ipc_bytes = try root.Metadata.encode(command.value, self.caller.connection.name, self.caller.schema, &self.output, self.workspace);
                if (!std.mem.eql(u8, &digest(ipc_bytes), &value.digest)) return error.InvalidFlightTicket;
                const ipc = try root.Ipc.parts(ipc_bytes, self.workspace);
                try self.disclose(ticket, w.FlightData{ .data_header = ipc.schema_header });
                try self.disclose(ticket, w.FlightData{ .data_header = ipc.batch_header, .data_body = ipc.batch_body });
            },
            .statement => |value| {
                self.first_sequence = value.correlation;
                var cursor: ?q.UnifiedResult.Cursor = null;
                while (true) {
                    try self.response.check();
                    // Each page's decoded data and source metadata have bounded
                    // lifetime; long results cannot grow the RPC arena.
                    var page_arena = std.heap.ArenaAllocator.init(self.allocator);
                    defer page_arena.deinit();
                    var decoded_rows: f.Unified.Inspect.Batch = undefined;
                    const captured = try self.client.page(value.correlation, cursor, page_arena.allocator(), self.workspace, &self.output, &decoded_rows);
                    if (!std.mem.eql(u8, &try manifestDigest(captured.manifest), &value.manifest)) return error.InvalidFlightTicket;
                    const ipc = try self.tableParts(captured, &decoded_rows);
                    if (cursor == null) try self.disclose(ticket, w.FlightData{ .data_header = ipc.schema_header });
                    try self.disclose(ticket, w.FlightData{ .data_header = ipc.batch_header, .data_body = ipc.batch_body });
                    cursor = captured.next;
                    if (cursor == null) break;
                }
            },
        }
        // Success only after complete ordered coverage and final current access.
        try self.authorize(false);
        if (try self.now() >= ticket.expires_ms) return error.FlightTicketExpired;
    }
    fn tableParts(self: *Call, captured: q.UnifiedResult.Page, rows: *const f.Unified.Inspect.Batch) !root.Ipc.Parts {
        const layout = try root.TableResult.init(self.caller.schema, captured.plan);
        try layout.checkSchema(captured.schema);
        const bytes = try layout.encodeDiagnostic(rows, &self.output, self.workspace, self.attempt_diagnostic);
        return root.Ipc.parts(bytes, self.workspace);
    }
    fn disclose(self: *Call, ticket: root.Ticket, value: w.FlightData) !void {
        try self.authorize(false);
        if (try self.now() >= ticket.expires_ms) return error.FlightTicketExpired;
        try self.send(value);
    }
};

test "credential selection is per RPC and never a connection identity" {
    const t = std.testing;
    const first = try credentialHash("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa");
    const second = try credentialHash("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
    try t.expect(!std.crypto.timing_safe.eql([32]u8, first, second));
    try t.expectError(error.FlightUnauthenticated, credentialHash("short"));
    _ = &handle;
}

/// Server-generated clock/skew/expiry values must fit the ticket counter domain.
/// A bad host clock is not an invalid credential supplied by a caller.
fn advanceTime(now_ms: u64, increment_ms: u32) !u64 {
    if (now_ms > p.max_counter or increment_ms > p.max_counter - now_ms) return error.ClockUnavailable;
    return now_ms + increment_ms;
}

test "server ticket time bounds cannot become caller credential failures" {
    const t = std.testing;
    try t.expectEqual(@as(u64, 0), try advanceTime(0, 0));
    try t.expectEqual(p.max_counter, try advanceTime(p.max_counter - 1000, 1000));
    for ([_]u64{ p.max_counter, p.max_counter + 1, std.math.maxInt(u64) }) |value| {
        try t.expectError(error.ClockUnavailable, advanceTime(value, 1));
    }
    try t.expectError(error.ClockUnavailable, advanceTime(p.max_counter + 1, 0));
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(37));
    const scope: root.Ticket.Scope = .{ .realm = 49, .principal = 65536, .service = 1, .binding_revision = 2, .ingress = 7, .requests = 11, .source = 3, .resource = 9, .table = 1 };
    const ticket: root.Ticket = .{ .scope = scope, .expires_ms = try advanceTime(p.max_counter - 1000, 1000), .reference = .{ .statement = .{ .correlation = 123, .manifest = @splat(5) } } };
    var buffer: [root.Ticket.max_bytes]u8 = undefined;
    const bytes = try ticket.issue(key, &buffer);
    try t.expectEqualDeep(ticket, try root.Ticket.decode(bytes, scope, p.max_counter - 1, key.public_key));
    try t.expectError(error.FlightTicketExpired, root.Ticket.decode(bytes, scope, p.max_counter, key.public_key));
    const status = root.DiagnosticDetail.statusFor(error.ClockUnavailable);
    try t.expectEqual(@as(u8, 14), status);
    const detail = try root.DiagnosticDetail.attempt(error.ClockUnavailable, status);
    try t.expectEqualStrings("flight.clock_unavailable", detail.code.slice());
    try t.expectEqual(.not_applicable, detail.outcome);
    try t.expect(detail.identity == null);
}

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
pub const Caller = struct {
    /// Hash of a private high-entropy Bearer credential; raw tokens never persist
    /// in gateway state, telemetry or durable query payloads.
    credential: [32]u8,
    connection: q.Model.Connection,
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
    self.handleOnce(io, allocator, request, response) catch |err| {
        observation.fail(err);
        if (err == error.Canceled or err == error.GrpcCancelled or response.finished) return err;
        const status: u8 = switch (err) {
            error.FlightUnauthenticated => 16,
            error.AccessDenied, error.QueryAccessDenied, error.ServingDenied, error.FlightTicketScope, error.SignatureVerificationFailed => 7,
            error.FlightTicketExpired, error.ResourceUnavailable, error.QuerySourceUnavailable, error.ServiceUnpublished => 9,
            error.UnsupportedFlightCommand, error.UnsupportedFlightMetadata, error.UnsupportedQuery, error.UnsupportedFlightType => 12,
            error.FlightCallerCapacity, error.OutOfMemory, error.GrpcBudgetExceeded => 8,
            error.QueryBusy, error.FlightSequenceConflict => 10,
            error.QueryChanged, error.ServiceReadConflict => 14,
            error.InvalidFlightTicket, error.InvalidFlightCommand, error.InvalidFlightMetadata, error.InvalidQueryIdentity, error.DuplicateGrpcHeader, error.Truncated, error.VarintOverflow, error.FieldNumberZero, error.FieldNumberOutOfRange, error.UnsupportedWireType, error.NonMinimalTag, error.DepthExceeded, error.InvalidUtf8, error.InvalidEnumValue, error.UnknownField => 3,
            else => if (q.wire.Client.unavailable(err)) 14 else 13,
        };
        return response.finish(status, switch (status) {
            16 => "credential required",
            7 => "current access denied",
            9 => "result or service unavailable",
            12 => "operation unsupported",
            8 => "bounded capacity exhausted",
            10 => "admission conflict; retain request identity",
            14 => "unavailable; retain request identity",
            3 => "invalid request",
            else => "finite query failed",
        });
    };
}
fn handleOnce(self: *Self, io: Io, allocator: std.mem.Allocator, request: server.Request, response: *server.Response) !void {
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
    var client: q.Client = .{ .wire = &wire, .connection = caller.connection, .key = caller.key };
    const adapter: s.Adapter = .{ .service = caller.service, .ingress = caller.connection.requester, .resource = caller.ingress_resource, .resources = .{ .wire = &wire, .realm = caller.connection.realm, .principal = self.config.inspector, .key = self.config.inspector_key } };
    var call: Call = .{ .gateway = self, .io = io, .allocator = alloc, .caller = caller, .client = &client, .adapter = adapter, .response = response, .workspace = workspace };
    const method = try request.method();
    if (std.mem.eql(u8, method, root.method_prefix ++ "DoGet")) {
        var ticket = try pb.decode(w.Ticket, alloc, request.message, .{ .max_arena_bytes = 65536 });
        defer ticket.deinit();
        return call.get(ticket.value.ticket);
    }
    if (std.mem.eql(u8, method, root.method_prefix ++ "GetFlightInfo") or std.mem.eql(u8, method, root.method_prefix ++ "GetSchema")) {
        var descriptor = try pb.decode(w.FlightDescriptor, alloc, request.message, .{ .max_arena_bytes = 65536 });
        defer descriptor.deinit();
        if (descriptor.value.type != .CMD or descriptor.value.path.len != 0 or descriptor.value.cmd.len == 0 or descriptor.value.cmd.len > 8192) return error.InvalidFlightCommand;
        return call.describe(request, descriptor.value, std.mem.endsWith(u8, method, "/GetSchema"));
    }
    if (std.mem.eql(u8, method, root.method_prefix ++ "ListActions")) {
        var empty = try pb.decode(w.Empty, alloc, request.message, .{ .max_arena_bytes = 65536 });
        defer empty.deinit();
        try call.authorize(false);
        return; // No supported actions, especially no prepare/transaction action.
    }
    return error.UnsupportedFlightCommand;
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
    client: *q.Client,
    adapter: s.Adapter,
    response: *server.Response,
    workspace: []u8,
    output: [16384]u8 = undefined,
    ticket_buffer: [root.Ticket.max_bytes]u8 = undefined,
    fn now(self: *Call) !u64 {
        const time = Io.Clock.real.now(self.io).toMilliseconds();
        if (time < 0 or time > p.max_counter) return error.ClockUnavailable;
        return std.math.add(u64, @intCast(time), self.gateway.config.clock_error_ms);
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
            const access = (try self.client.query(.{ .read_access = @field(caller.connection, field) })).body.read_access;
            if (access.phase != .active) return error.QuerySourceUnavailable;
        }
        const source = try self.client.describe();
        if (!std.mem.eql(u8, &(try source.schema.fingerprint()), &(try caller.schema.fingerprint()))) return error.QuerySourceUnavailable;
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
        var total_bytes: u64 = 0;
        if (statement) {
            var decoded = try pb.decode(w.CommandStatementQuery, self.allocator, command.value.value, .{ .max_arena_bytes = 65536 });
            defer decoded.deinit();
            if (decoded.value.transaction_id != null) return error.UnsupportedFlightCommand;
            if (schema_only) {
                schema = root.Metadata.querySchema(self.caller.connection.name, self.caller.schema, decoded.value.query, &self.output, self.workspace) catch return error.UnsupportedQuery;
            } else {
                const raw_sequence = (try request.header("x-transit-request-sequence")) orelse return error.InvalidQueryIdentity;
                if (raw_sequence.len == 0 or raw_sequence.len > 16 or raw_sequence[0] == '0') return error.InvalidQueryIdentity;
                for (raw_sequence) |byte| if (!std.ascii.isDigit(byte)) return error.InvalidQueryIdentity;
                const sequence = std.fmt.parseInt(u64, raw_sequence, 10) catch return error.InvalidQueryIdentity;
                const signed = try self.client.prepareSequence(decoded.value.query, self.caller.schema, sequence);
                const receipt = self.client.submitSequence(signed) catch |err| {
                    if (err == error.Rejected or err == error.Conflict) switch (self.client.wire.last_rejection orelse return err) {
                        .ConflictingRetry, .SequenceGap, .RetryHorizonExceeded => return error.FlightSequenceConflict,
                        else => {},
                    };
                    return err; // No automatic mutation retry or replacement sequence.
                };
                const correlation = receipt.position;
                const manifest = try self.awaitResult(correlation);
                // Qualify within the existing finite transport profile before
                // issuing access; no hidden whole-result buffer or raised bound.
                if (manifest.segments == 0 or manifest.segments > 63 or manifest.bytes > 240 * 1024) return error.GrpcBudgetExceeded;
                const captured = try self.client.segment(correlation, 0, &self.output, self.workspace);
                if (!std.meta.eql(captured.result, manifest)) return error.InvalidResultManifest;
                schema = (try root.Ipc.parts(captured.bytes, self.workspace)).schema_message;
                reference = .{ .statement = .{ .correlation = correlation, .manifest = digest((try manifest.encode()).slice()) } };
                rows = manifest.rows;
                total_bytes = manifest.bytes;
            }
        } else {
            if (descriptor.cmd.len > root.Ticket.max_command_bytes) return error.InvalidFlightCommand;
            const bytes = try root.Metadata.encode(command.value, self.caller.connection.name, self.caller.schema, &self.output, self.workspace);
            const ipc = try root.Ipc.parts(bytes, self.workspace);
            schema = ipc.schema_message;
            rows = ipc.rows;
            total_bytes = bytes.len;
            reference = .{ .metadata = .{ .command = descriptor.cmd, .digest = digest(bytes) } };
        }
        try self.authorize(false);
        if (schema_only) return self.send(w.SchemaResult{ .schema = schema });
        const expires = try std.math.add(u64, try self.now(), self.gateway.config.ticket_ttl_ms);
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
        try self.send(w.FlightInfo{ .schema = schema, .flight_descriptor = descriptor, .endpoint = &.{endpoint}, .total_records = @intCast(rows), .total_bytes = @intCast(total_bytes), .ordered = true });
    }
    fn awaitResult(self: *Call, correlation: u64) !q.station.GrowingQuery.Manifest {
        while (true) {
            try self.response.check();
            const status = self.client.status(correlation) catch |err| {
                if (q.wire.Client.unavailable(err) or err == error.QueryChanged) {
                    try self.io.sleep(.fromMilliseconds(100), .awake);
                    continue;
                }
                return err;
            };
            switch (status.phase) {
                .complete => return status.manifest orelse error.InvalidResultManifest,
                .busy => return error.QueryBusy,
                .denied => return error.QueryAccessDenied,
                .cancelled, .expired, .failed, .rejected => return error.QuerySourceUnavailable,
                else => {},
            }
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
                var ordinal: u64 = 0;
                var rows: u64 = 0;
                var byte_count: u64 = 0;
                var chain: [32]u8 = @splat(0);
                while (true) {
                    try self.response.check();
                    const captured = try self.client.segment(value.correlation, ordinal, &self.output, self.workspace);
                    const manifest = captured.result;
                    if (!std.mem.eql(u8, &digest((try manifest.encode()).slice()), &value.manifest)) return error.InvalidFlightTicket;
                    const ipc = try root.Ipc.parts(captured.bytes, self.workspace);
                    if (ordinal == 0) try self.disclose(ticket, w.FlightData{ .data_header = ipc.schema_header });
                    chain = try captured.segment.extend(chain);
                    rows = try std.math.add(u64, rows, captured.segment.rows);
                    byte_count = try std.math.add(u64, byte_count, captured.bytes.len);
                    try self.disclose(ticket, w.FlightData{ .data_header = ipc.batch_header, .data_body = ipc.batch_body });
                    ordinal += 1;
                    if (ordinal == manifest.segments) {
                        if (rows != manifest.rows or byte_count != manifest.bytes or !std.mem.eql(u8, &chain, &manifest.chain)) return error.InvalidResultCoverage;
                        break;
                    }
                }
            },
        }
        // Success only after complete ordered coverage and final current access.
        try self.authorize(false);
        if (try self.now() >= ticket.expires_ms) return error.FlightTicketExpired;
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

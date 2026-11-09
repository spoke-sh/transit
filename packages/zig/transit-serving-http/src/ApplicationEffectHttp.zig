//! Private, bounded HTTP rendering for frozen application effect operands.
//! This adapter grants no dispatch permission and performs no I/O. Its owner
//! keeps the request reservation borrowed and checks current authority at send.
const std = @import("std");
const q = @import("transit_query_direct");
const connector = @import("transit_station_http");
const R = @import("ApplicationReservation.zig");
const a = q.fuze.ApplicationProgram;
const Self = @This();

pub const max_body_bytes = 64 * 1024;
profile: q.protocol.Source.Sink,
operands: q.ApplicationEffectRequest,
reservation: *R,
access: R.Access,
body: []u8,
body_len: usize,
headers: [connector.Request.maximum_headers]connector.Request.Header,
pieces: [connector.Request.maximum_headers][1]connector.Request.Piece,
header_count: usize,
target: [1]connector.Request.Piece,

/// Initialize at its final address: request slices refer to this object's
/// arrays. All borrowed inputs and private body storage outlive transport.
pub fn init(self: *Self, profile: q.protocol.Source.Sink, operands: q.ApplicationEffectRequest, reservation: *R, access: R.Access, body: []u8, host: []const u8, port: u16) !void {
    std.crypto.secureZero(u8, body);
    try profile.validate();
    if (body.len > max_body_bytes or operands.fields.len > a.max_arguments or
        (profile.request_encoding == .form) != (operands.kind == .form)) return error.InvalidSinkEncoding;
    self.* = .{ .profile = profile, .operands = operands, .reservation = reservation, .access = access, .body = body, .body_len = 0, .headers = undefined, .pieces = undefined, .header_count = 0, .target = .{.{ .literal = profile.path }} };
    errdefer self.deinit();
    try self.header("accept", .{ .literal = profile.accept });
    if (profile.user_agent) |agent| try self.header("user-agent", .{ .literal = agent });
    if (operands.kind == .form) {
        try self.header("content-type", .{ .literal = "application/x-www-form-urlencoded" });
        var writer: std.Io.Writer = .fixed(body);
        for (operands.fields, 0..) |field, index| {
            try distinct(operands.fields[0..index], field.name, false);
            if (index != 0) try writer.writeByte('&');
            try encode(&writer, field.name);
            try writer.writeByte('=');
            try encode(&writer, try self.value(field.value, .form));
        }
        self.body_len = writer.end;
    } else {
        for (operands.fields, 0..) |field, index| {
            try distinct(operands.fields[0..index], field.name, true);
            // These values belong to the immutable sink definition. Typed
            // protected operands cannot silently replace its public policy.
            for ([_][]const u8{ "accept", "user-agent", "content-type" }) |name|
                if (std.ascii.eqlIgnoreCase(name, field.name)) return error.InvalidSinkHeader;
            const piece: connector.Request.Piece = switch (field.value) {
                .text => |text| blk: {
                    if (std.ascii.eqlIgnoreCase(field.name, "authorization")) return error.ProtectedProgramValue;
                    break :blk .{ .literal = text };
                },
                .secret => blk: {
                    _ = try self.value(field.value, .header);
                    // An ephemeral render slot, not a persisted credential
                    // revision. The resolver checks the actual opaque handle.
                    break :blk .{ .secret = .{ .binding = field.name, .version = 1 } };
                },
                else => return error.ProtectedProgramValue,
            };
            try self.header(field.name, piece);
        }
    }
    // Reject reserved headers, malformed targets and oversized public heads
    // before admission. Actual secret widths are checked again at rendering.
    var head: [connector.Request.maximum_head_bytes]u8 = undefined;
    defer std.crypto.secureZero(u8, &head);
    _ = try self.request().render(host, port, &head, null, false);
}
pub fn deinit(self: *Self) void {
    std.crypto.secureZero(u8, self.body);
    std.crypto.secureZero(u8, std.mem.asBytes(self));
}
fn distinct(previous: []const a.Values.Field, name: []const u8, insensitive: bool) !void {
    if (name.len == 0) return error.InvalidSinkHeader;
    for (previous) |field| if (if (insensitive) std.ascii.eqlIgnoreCase(field.name, name) else std.mem.eql(u8, field.name, name)) return error.DuplicateProgramField;
}
fn header(self: *Self, name: []const u8, piece: connector.Request.Piece) !void {
    if (self.header_count == self.headers.len) return error.HttpHeadersOversize;
    const index = self.header_count;
    self.pieces[index] = .{piece};
    self.headers[index] = .{ .name = name, .value = &self.pieces[index] };
    self.header_count += 1;
}
fn value(self: *Self, operand: a.Values.Value, use: R.Use) ![]const u8 {
    return switch (operand) {
        .text => |text| text,
        .secret => (try self.reservation.read(self.access, operand, use)).secret.bytes,
        else => error.ProtectedProgramValue,
    };
}
fn encode(writer: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| {
        if (std.ascii.isAlphanumeric(byte) or std.mem.indexOfScalar(u8, "-._~", byte) != null)
            try writer.writeByte(byte)
        else
            try writer.print("%{X:0>2}", .{byte});
    }
}
/// Recheck every protected input after preparation, including cached form
/// bytes. The surrounding worker also rechecks its complete native read set.
pub fn requireCurrent(self: *Self, now_ms: u64) !void {
    self.access.now_ms = now_ms;
    try self.reservation.request(self.access, .{ .capability = self.reservation.reference });
    for (self.operands.fields) |field| if (field.value == .secret) {
        _ = try self.value(field.value, if (self.operands.kind == .form) .form else .header);
    };
}
pub fn request(self: *Self) connector.Request {
    return .{ .method = if (self.profile.method == .GET) .GET else .POST, .target = &self.target, .headers = self.headers[0..self.header_count], .body_bytes = self.body_len };
}
pub fn resolver(self: *Self) connector.Request.Resolver {
    return .{ .context = self, .resolve = resolve };
}
fn resolve(context: *anyopaque, secret: connector.Request.Secret) ![]const u8 {
    const self: *Self = @ptrCast(@alignCast(context));
    if (secret.version != 1 or self.operands.kind != .headers) return error.InvalidHttpSecret;
    for (self.operands.fields) |field| if (std.mem.eql(u8, field.name, secret.binding) and field.value == .secret)
        return self.value(field.value, .header);
    return error.InvalidHttpSecret;
}

/// Keep provider bytes transient; only a verified complete transport result
/// can produce response metadata. The caller seals the body in its reservation.
pub const Capture = struct {
    memory: []u8,
    used: usize = 0,
    pub fn callback(self: *Capture) connector.Transport.Capture {
        return .{ .context = self, .segment = segment };
    }
    pub fn deinit(self: *Capture) void {
        std.crypto.secureZero(u8, self.memory);
        self.* = undefined;
    }
    fn segment(context: *anyopaque, kind: connector.Kind, bytes: []const u8) !void {
        const self: *Capture = @ptrCast(@alignCast(context));
        if (kind != .response_body) return;
        const limit = @min(self.memory.len, max_body_bytes);
        if (self.used > limit or bytes.len > limit - self.used) return error.HttpResponseTooLarge;
        @memcpy(self.memory[self.used..][0..bytes.len], bytes);
        self.used += bytes.len;
    }
    pub fn response(self: *const Capture, result: connector.Transport.Result) !q.ApplicationEffect.Response {
        if (result.bytes != self.used or result.bytes > max_body_bytes) return error.IncompleteHttpBody;
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(self.memory[0..self.used], &digest, .{});
        const value_: q.ApplicationEffect.Response = .{ .status = result.status, .bytes = @intCast(result.bytes), .sha256 = digest, .body = null };
        try value_.validate();
        return value_;
    }
};

/// Bind protected response bytes to the complete native effect result. Only
/// this public metadata enters the observation commitment; never body bytes.
pub fn responseObservation(descriptor: q.ApplicationEffect.Descriptor, response: q.ApplicationEffect.Response) !R.Observation {
    try descriptor.validate();
    try response.validate();
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.application.effect.response.v1\x00");
    hash.update(&try descriptor.digest());
    var encoded: [6]u8 = undefined;
    std.mem.writeInt(u16, encoded[0..2], response.status, .big);
    std.mem.writeInt(u32, encoded[2..6], response.bytes, .big);
    hash.update(&encoded);
    hash.update(&response.sha256);
    return .{ .step = descriptor.step, .node = descriptor.instruction, .arguments = hash.finalResult() };
}
fn requireResponseOwner(descriptor: q.ApplicationEffect.Descriptor, access: R.Access) !void {
    try descriptor.invocation.requireSame(access.owner);
    if (!std.meta.eql(descriptor.input, access.input)) return error.ApplicationRequestOwnerMismatch;
}
fn requireBody(response: q.ApplicationEffect.Response, bytes: []const u8) !void {
    if (response.bytes != bytes.len) return error.IncompleteHttpBody;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    if (!std.crypto.timing_safe.eql([32]u8, digest, response.sha256)) return error.ProtectedObservationChanged;
}
/// The caller first retains known completion metadata, then optionally seals
/// its body. Failure leaves that response known with body=null; it cannot turn
/// a complete exchange into unknown, unsent, or permission for another attempt.
pub fn sealResponse(io: std.Io, reservation: *R, access: R.Access, descriptor: q.ApplicationEffect.Descriptor, response: *q.ApplicationEffect.Response, bytes: []const u8) !void {
    const observation = try responseObservation(descriptor, response.*);
    try requireResponseOwner(descriptor, access);
    if (response.body != null) return error.InvalidApplicationEffect;
    try requireBody(response.*, bytes);
    const retained = try reservation.retain(io, access, observation, .{ .json = bytes });
    if (retained != .protected_json) return error.ProtectedProgramValue;
    response.body = retained.protected_json;
}
/// Adoption rechecks current owner/authority, the exact response observation,
/// handle, byte count and digest. A copied valid JSON handle is insufficient.
pub fn verifyResponse(reservation: *R, access: R.Access, descriptor: q.ApplicationEffect.Descriptor, response: q.ApplicationEffect.Response) !void {
    const observation = try responseObservation(descriptor, response);
    try requireResponseOwner(descriptor, access);
    const reference = response.body orelse return error.ApplicationReservationLost;
    const retained = try reservation.find(access, observation) orelse return error.ApplicationReservationLost;
    if (retained != .protected_json or !std.crypto.timing_safe.eql([32]u8, retained.protected_json.id, reference.id)) return error.ProtectedObservationChanged;
    const body = try reservation.read(access, retained, .json_projection);
    if (body != .json) return error.ProtectedProgramValue;
    try requireBody(response, body.json);
}

const Proof = struct {
    allowed: bool = true,
    fn check(context: *anyopaque, _: R.Evidence) !void {
        const self: *Proof = @ptrCast(@alignCast(context));
        if (!self.allowed) return error.AccessDenied;
    }
    fn access() R.Access {
        const scope: q.protocol.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
        return .{
            .owner = .{ .definition = q.protocol.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 4, .principal = 5, .role = 6 }, .account = @splat(7), .token = @splat(8) },
            .input = .{ .target = .{ .definition = q.protocol.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 9 }, .revision = 1, .digest = @splat(10) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 5, .operation = 11 }, .ordinal = 0 },
            .now_ms = 1,
        };
    }
    fn profile() q.protocol.Source.Sink {
        return .{ .method = .POST, .path = "/token", .request_encoding = .form, .accept = "application/json", .user_agent = "test", .response = .protected_json, .capture = .redacted_metadata, .request_timeout_ms = 5000, .response_max_bytes = 65536, .follow_redirects = false, .max_attempts = 1, .unknown_outcome = .retain };
    }
    fn descriptor() q.ApplicationEffect.Descriptor {
        const caller = access();
        var program = caller.input.target.interpretation;
        program.object.object += 1;
        var sink = program;
        sink.object.object += 1;
        return .{ .definition = q.protocol.Growth.current_definition, .invocation = caller.owner, .program = program, .input = caller.input, .request = .{ .scope = .{ .definition = q.protocol.Growth.current_definition, .connection = caller.owner.connection, .account = @splat(3) }, .format = q.catalog.DirectOwnedRecord.format, .content = .{ .bytes = 100, .sha256 = @splat(4) } }, .namespace = 1, .step = 1, .instruction = 3, .sink = sink, .operation = @splat(8) };
    }
};

test "application HTTP response adoption binds exact original metadata and protected bytes" {
    const t = std.testing;
    var authority: Proof = .{};
    const access = Proof.access();
    const descriptor = Proof.descriptor();
    var retained: [1024]u8 = undefined;
    var slots: [4]R.Slot = undefined;
    var reservation = try R.init(t.io, &retained, &slots, @splat(12), access.input, 1, 1000, .{ .context = &authority, .check = Proof.check });
    defer reservation.deinit();
    var bytes: [128]u8 = undefined;
    const body = "{\"access_token\":\"private\"}";
    @memcpy(bytes[0..body.len], body);
    var capture: Capture = .{ .memory = &bytes, .used = body.len };
    defer capture.deinit();
    var response = try capture.response(.{ .status = 200, .bytes = body.len, .omitted_headers = 0 });
    try sealResponse(t.io, &reservation, access, descriptor, &response, body);
    try verifyResponse(&reservation, access, descriptor, response);
    var other = response;
    other.status = 201;
    try t.expectError(error.ProtectedObservationChanged, verifyResponse(&reservation, access, descriptor, other));
    other = response;
    other.body.?.id[0] ^= 1;
    try t.expectError(error.ProtectedObservationChanged, verifyResponse(&reservation, access, descriptor, other));
    var changed = descriptor;
    changed.operation[0] ^= 1;
    try t.expectError(error.ProtectedObservationChanged, verifyResponse(&reservation, access, changed, response));
    var stolen = access;
    stolen.input.ordinal += 1;
    try t.expectError(error.ApplicationRequestOwnerMismatch, verifyResponse(&reservation, stolen, descriptor, response));
    authority.allowed = false;
    try t.expectError(error.AccessDenied, verifyResponse(&reservation, access, descriptor, response));
    authority.allowed = true;
    retained[0] ^= 1;
    try t.expectError(error.ProtectedObservationChanged, verifyResponse(&reservation, access, descriptor, response));
}

test "application HTTP body sealing failure preserves known response metadata" {
    const t = std.testing;
    var authority: Proof = .{};
    const access = Proof.access();
    var retained: [1]u8 = undefined;
    var slots: [1]R.Slot = undefined;
    var reservation = try R.init(t.io, &retained, &slots, @splat(12), access.input, 1, 1000, .{ .context = &authority, .check = Proof.check });
    defer reservation.deinit();
    var bytes: [2]u8 = .{ '{', '}' };
    var capture: Capture = .{ .memory = &bytes, .used = bytes.len };
    defer capture.deinit();
    var response = try capture.response(.{ .status = 200, .bytes = bytes.len, .omitted_headers = 0 });
    const original = response;
    try t.expectError(error.ApplicationReservationCapacity, sealResponse(t.io, &reservation, access, Proof.descriptor(), &response, &bytes));
    try t.expectEqualDeep(original, response);
    try t.expect(response.body == null);
    try t.expectEqual(@as(usize, 0), reservation.used);
    try t.expectError(error.IncompleteHttpBody, sealResponse(t.io, &reservation, access, Proof.descriptor(), &response, bytes[0..1]));
    try t.expectEqualDeep(original, response);
}

test "application HTTP operands use exact form escaping and current protected redemptions" {
    const t = std.testing;
    var authority: Proof = .{};
    const access = Proof.access();
    var retained: [1024]u8 = undefined;
    var slots: [4]R.Slot = undefined;
    var reservation = try R.init(t.io, &retained, &slots, @splat(12), access.input, 1, 1000, .{ .context = &authority, .check = Proof.check });
    defer reservation.deinit();
    const secret = try reservation.retain(t.io, access, .{ .step = 0, .node = 1, .arguments = @splat(1) }, .{ .secret = .{ .bytes = "a+ /&é", .revision = "request", .origin = .request_query, .revision_kind = .transient } });
    const fields: [2]a.Values.Field = .{ .{ .name = "client_id", .value = .{ .text = "public+id" } }, .{ .name = "code", .value = secret } };
    const operands: q.ApplicationEffectRequest = .{ .sink = "token", .operation = @splat(1), .kind = .form, .fields = &fields };
    var body: [256]u8 = undefined;
    var self: Self = undefined;
    try self.init(Proof.profile(), operands, &reservation, access, &body, "example.com", 443);
    try t.expectEqualStrings("client_id=public%2Bid&code=a%2B%20%2F%26%C3%A9", body[0..self.body_len]);
    try self.requireCurrent(2);
    authority.allowed = false;
    try t.expectError(error.AccessDenied, self.requireCurrent(3));
    self.deinit();
    try t.expect(std.mem.allEqual(u8, &body, 0));
    authority.allowed = true;
    var small: [4]u8 = @splat(0x55);
    try t.expectError(error.WriteFailed, self.init(Proof.profile(), operands, &reservation, access, &small, "example.com", 443));
    try t.expect(std.mem.allEqual(u8, &small, 0));
}

test "application HTTP headers preserve typed bearer references and reject policy substitution" {
    const t = std.testing;
    var authority: Proof = .{};
    const access = Proof.access();
    var retained: [1024]u8 = undefined;
    var slots: [4]R.Slot = undefined;
    var reservation = try R.init(t.io, &retained, &slots, @splat(12), access.input, 1, 1000, .{ .context = &authority, .check = Proof.check });
    defer reservation.deinit();
    const bearer = try reservation.retain(t.io, access, .{ .step = 0, .node = 1, .arguments = @splat(1) }, .{ .secret = .{ .bytes = "Bearer private", .revision = "provider", .origin = .bearer, .revision_kind = .transient } });
    var fields: [1]a.Values.Field = .{.{ .name = "Authorization", .value = bearer }};
    var profile = Proof.profile();
    profile.method = .GET;
    profile.request_encoding = .none;
    profile.path = "/user";
    const operands: q.ApplicationEffectRequest = .{ .sink = "profile", .operation = @splat(1), .kind = .headers, .fields = &fields };
    var body: [32]u8 = undefined;
    var self: Self = undefined;
    try self.init(profile, operands, &reservation, access, &body, "example.com", 443);
    var head: [8192]u8 = undefined;
    defer std.crypto.secureZero(u8, &head);
    const redacted = try self.request().render("example.com", 443, &head, null, false);
    try t.expect(std.mem.indexOf(u8, redacted, "private") == null);
    try t.expect(std.mem.indexOf(u8, redacted, "{{secrets.Authorization@1}}") != null);
    const actual = try self.request().render("example.com", 443, &head, self.resolver(), false);
    try t.expect(std.mem.indexOf(u8, actual, "Authorization: Bearer private\r\n") != null);
    authority.allowed = false;
    try t.expectError(error.AccessDenied, self.request().render("example.com", 443, &head, self.resolver(), false));
    self.deinit();
    authority.allowed = true;
    fields[0] = .{ .name = "aCcEpT", .value = .{ .text = "different" } };
    try t.expectError(error.InvalidSinkHeader, self.init(profile, operands, &reservation, access, &body, "example.com", 443));
    fields[0].name = "Host";
    try t.expectError(error.ReservedHttpHeader, self.init(profile, operands, &reservation, access, &body, "example.com", 443));
    fields[0].name = "Authorization";
    try t.expectError(error.ProtectedProgramValue, self.init(profile, operands, &reservation, access, &body, "example.com", 443));
}

test "application HTTP capture refuses incomplete coverage and erases private bytes" {
    const t = std.testing;
    var memory: [8]u8 = @splat(0);
    var capture: Capture = .{ .memory = &memory };
    const callback = capture.callback();
    try callback.segment(callback.context, .response_head, "HTTP/1.1 200 OK\r\n\r\n");
    try callback.segment(callback.context, .response_body, "{}");
    try t.expectError(error.IncompleteHttpBody, capture.response(.{ .status = 200, .bytes = 3, .omitted_headers = 0 }));
    const response = try capture.response(.{ .status = 200, .bytes = 2, .omitted_headers = 0 });
    try t.expectEqual(@as(u16, 200), response.status);
    try t.expect(response.body == null);
    try t.expectEqualStrings("44136fa355b3678a1146ad16f7e8649e94fb4fc21fe77e8310c060f61caaff8a", &std.fmt.bytesToHex(response.sha256, .lower));
    try t.expectError(error.HttpResponseTooLarge, callback.segment(callback.context, .response_body, "overflow"));
    try t.expectEqual(@as(usize, 2), capture.used);
    capture.deinit();
    try t.expect(std.mem.allEqual(u8, &memory, 0));
}

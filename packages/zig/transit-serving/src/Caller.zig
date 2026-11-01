//! Shared signed Serving caller. Host adapters own scheduling and durable storage;
//! this owner freezes native work, verifies recovery scope and performs one attempt.
const std = @import("std");
const root = @import("root.zig");
const wire = root.station.client;
const p = root.protocol;
pub const max_request_bytes = 64 * 1024;
pub const max_response_bytes = 1024 * 1024;
pub const Configuration = struct {
    definition: p.Growth.Definition,
    origin: []const u8,
    realm: u64,
    principal: u64,
    credential_epoch: u64,
    role: ?u64 = null,
    ingress: u64,
    service: u64,
    seed_file: []const u8,
    ca_file: ?[]const u8 = null,
    timeout_ms: u32 = 10000,
    development_allow_insecure_http: bool = false,
    pub fn validate(self: Configuration) !void {
        inline for (.{ "realm", "principal", "credential_epoch", "ingress", "service" }) |name| try root.Model.identity(@field(self, name));
        if (self.origin.len > 2048 or self.seed_file.len > 4096 or !std.fs.path.isAbsolute(self.seed_file) or self.timeout_ms == 0 or self.timeout_ms > 60000) return error.InvalidServingCaller;
        if (self.ca_file) |file| if (file.len > 4096 or !std.fs.path.isAbsolute(file)) return error.InvalidServingCaller;
        if (self.role) |role| if (role > p.max_counter) return error.InvalidServingCaller;
        const uri = try std.Uri.parse(self.origin);
        if (uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null or uri.path.percent_encoded.len != 0) return error.InvalidServingOrigin;
        if (std.mem.eql(u8, uri.scheme, "https")) return;
        if (!self.development_allow_insecure_http or !std.mem.eql(u8, uri.scheme, "http") or self.ca_file != null) return error.InvalidServingOrigin;
        if (!std.mem.eql(u8, uri.host.?.percent_encoded, "127.0.0.1") and !std.mem.eql(u8, uri.host.?.percent_encoded, "[::1]")) return error.InvalidServingOrigin;
    }
};
pub const Prepared = struct {
    version: u8,
    definition: p.Growth.Definition,
    origin: []const u8,
    service: u64,
    signed: p.Growth.SignedRequest,
};
pub const Prepare = struct { sequence: u64, command: root.Model.Submit };
pub const Observe = struct { kind: @FieldType(root.Model.Read, "kind"), operation: u64 = 0 };
pub const ApplicationRead = struct { path: []const u8, context: [32]u8, read: std.json.Value };
pub const Action = union(enum) { prepare: Prepare, inspect: []const u8, dispatch: []const u8, observe: Observe, application_read: ApplicationRead };
pub const Request = struct { configuration: Configuration, action: Action };
pub const Result = struct {
    definition: p.Growth.Definition = p.Growth.current_definition,
    status: enum { ok, invalid, unavailable, unknown } = .ok,
    http_status: u16 = 0,
    value: std.json.Value = .null,
    err: ?[]const u8 = null,
};

pub fn prepare(config: Configuration, input: Prepare, key: p.Ed25519.KeyPair) !Prepared {
    try config.validate();
    try input.command.validate();
    const frame = try (root.station.Frame{ .kind = .cast, .payload = try (root.Model.Command{ .submit = input.command }).encode() }).encode();
    return .{ .version = 1, .definition = p.Growth.current_definition, .origin = config.origin, .service = config.service, .signed = try p.Growth.sign(.{ .realm = config.realm, .principal = config.principal, .sequence = input.sequence, .command = .{ .send = .{ .pid = config.ingress, .role = config.role, .value = frame } } }, key) };
}
pub fn inspect(alloc: std.mem.Allocator, config: Configuration, saved: []const u8) !std.json.Parsed(Prepared) {
    try config.validate();
    if (saved.len == 0 or saved.len > max_request_bytes) return error.InvalidServingRecovery;
    const parsed = try p.Json.parseFromSlice(Prepared, alloc, saved);
    errdefer parsed.deinit();
    const original = parsed.value;
    if (original.version != 1 or original.service != config.service or !std.mem.eql(u8, original.origin, config.origin)) return error.ServingRecoveryScope;
    const request = original.signed.request;
    try p.Growth.validate(request);
    if (request.realm != config.realm or request.principal != config.principal or request.command != .send or request.command.send.pid != config.ingress or request.command.send.role != config.role) return error.ServingRecoveryScope;
    const frame = try root.station.Frame.decode(request.command.send.value);
    if (frame.kind != .cast) return error.InvalidServingRecovery;
    const command = try root.Model.Command.decode(frame.payload);
    if (command != .submit) return error.InvalidServingRecovery;
    try command.submit.validate();
    const canonical = try p.Json.valueAlloc(alloc, original);
    defer alloc.free(canonical);
    if (!std.mem.eql(u8, saved, canonical)) return error.NoncanonicalServingRecovery;
    return parsed;
}

/// Explicit raw HTTP status is available only to a domain caller which owns its
/// response/error schema. The shared client still bounds and joins transport.
const JsonRequest = struct {
    value: std.json.Value,
    mutation: bool,
    pub fn jsonStringify(self: JsonRequest, out: *std.json.Stringify) !void {
        try out.write(self.value);
    }
    pub fn transport(self: JsonRequest) struct { operation: []const u8, mutation: bool, control: ?[]const u8, raw_status: bool } {
        return .{ .operation = if (self.mutation) "serving_submit" else "serving_read", .mutation = self.mutation, .control = null, .raw_status = true };
    }
};
fn value(alloc: std.mem.Allocator, input: anytype) !std.json.Value {
    const bytes = try p.Json.valueAlloc(alloc, input);
    return (try std.json.parseFromSlice(std.json.Value, alloc, bytes, .{})).value;
}
fn exchange(alloc: std.mem.Allocator, client: *wire.Client, path: []const u8, input: anytype, mutation: bool) !Result {
    const response = try client.callOwned(std.json.Value, path, JsonRequest{ .value = try value(alloc, input), .mutation = mutation }, .{ .request_bytes = max_request_bytes, .response_bytes = max_response_bytes });
    defer response.deinit();
    return .{ .http_status = @backingInt(client.last_status orelse return error.InvalidServingResponse), .value = try value(alloc, response.value) };
}
pub fn process(alloc: std.mem.Allocator, io: std.Io, request: Request) !Result {
    const config = request.configuration;
    try config.validate();
    switch (request.action) {
        .prepare => |input| {
            var key = try wire.readKey(alloc, io, config.seed_file);
            defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
            return .{ .value = try value(alloc, try p.Json.valueAlloc(alloc, try prepare(config, input, key))) };
        },
        .inspect => |saved| {
            const original = try inspect(alloc, config, saved);
            defer original.deinit();
            const command = try root.Model.Command.decode((try root.station.Frame.decode(original.value.signed.request.command.send.value)).payload);
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(saved, &digest, .{});
            return .{ .value = try value(alloc, .{ .identity = digest, .sequence = original.value.signed.request.sequence, .command = command.submit }) };
        },
        else => {},
    }
    var client = wire.Client.init(alloc, io, config.origin);
    defer client.deinit();
    client.timeout_ms = config.timeout_ms;
    if (config.ca_file) |file| {
        const now = std.Io.Clock.real.now(io);
        try client.http.ca_bundle.addCertsFromFilePathAbsolute(alloc, io, now, file);
        client.http.now = now;
    }
    if (request.action == .dispatch) {
        const original = try inspect(alloc, config, request.action.dispatch);
        defer original.deinit();
        const result = exchange(alloc, &client, "/serving/v1/command", original.value.signed, true) catch |err| return .{ .status = .unknown, .err = @errorName(err) };
        if (result.http_status == 202) {
            const receipt = std.json.parseFromValue(root.Adapter.Receipt, alloc, result.value, .{}) catch return .{ .status = .unknown, .err = "InvalidServingReceipt" };
            defer receipt.deinit();
            if (receipt.value.stage != .ingress_accepted or receipt.value.receipt.position == 0 or receipt.value.receipt.position > p.max_counter) return .{ .status = .unknown, .err = "InvalidServingReceipt" };
        }
        return result;
    }
    var key = try wire.readKey(alloc, io, config.seed_file);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    if (request.action == .observe) {
        const input = request.action.observe;
        const read: root.Model.Read = .{ .realm = config.realm, .principal = config.principal, .service = config.service, .ingress = config.ingress, .kind = input.kind, .operation = input.operation };
        const signed = try root.Model.SignedRead.sign(read, key, config.credential_epoch, config.role);
        const result = try exchange(alloc, &client, "/serving/v1/read", signed, false);
        if (result.http_status == 200) {
            const response = try std.json.parseFromValue(root.Adapter.ReadResult, alloc, result.value, .{});
            defer response.deinit();
            const observed = response.value;
            if (observed.service != config.service or observed.resource == 0 or observed.revision == 0 or observed.policy_revision == 0) return error.InvalidServingResponse;
            if (observed.operation) |operation| {
                try operation.validate();
                if (operation.principal != config.principal or operation.operation != input.operation) return error.InvalidServingResponse;
            }
        }
        return result;
    }
    const input = request.action.application_read;
    if (input.path.len == 0 or input.path.len > 1024 or input.path[0] != '/' or std.mem.startsWith(u8, input.path, "//") or std.mem.indexOfAny(u8, input.path, "?#\\\r\n") != null) return error.InvalidServingRead;
    const proof = try p.Authorization.Proof.sign(.{ .definition = p.Growth.current_definition, .realm = config.realm, .principal = config.principal, .credential_epoch = config.credential_epoch, .role = config.role, .audience = config.ingress, .context = input.context }, key);
    return exchange(alloc, &client, input.path, .{ .read = input.read, .proof = proof }, false);
}

test "Serving preparation preserves exact native work and rejects recovery substitution" {
    const t = std.testing;
    var arena = std.heap.ArenaAllocator.init(t.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const config: Configuration = .{ .definition = p.Growth.current_definition, .origin = "https://service.test", .realm = 49, .principal = 65536, .credential_epoch = 1, .ingress = 3, .service = 1, .seed_file = "/private/key" };
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const frozen = try prepare(config, .{ .sequence = 3, .command = .{ .operation = 8, .binding = 1, .codec = 2, .deadline_ms = 3000, .payload = try p.Value.init("hello") } }, key);
    try p.Ed25519.Signature.fromBytes(frozen.signed.signature).verify(&try p.Growth.digest(frozen.signed.request), key.public_key);
    const saved = try p.Json.valueAlloc(alloc, frozen);
    const restored = try inspect(alloc, config, saved);
    defer restored.deinit();
    try t.expectEqualDeep(frozen.signed, restored.value.signed);
    var other = config;
    other.origin = "https://another.test";
    try t.expectError(error.ServingRecoveryScope, inspect(alloc, other, saved));
    other = config;
    other.principal += 1;
    try t.expectError(error.ServingRecoveryScope, inspect(alloc, other, saved));
    try t.expectError(error.NoncanonicalServingRecovery, inspect(alloc, config, try std.fmt.allocPrint(alloc, " {s}", .{saved})));
}

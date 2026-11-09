//! Protected expressions over one live request reservation. The native binder
//! supplies fresh scoped authority and the public observation host. Scratch is
//! private to this serialized call and erased before returning; only public
//! results or non-authorizing reservation handles leave the host.
const std = @import("std");
const c = @import("transit_catalog");
const a = c.fuze.ApplicationProgram;
const p = c.protocol;
const R = @import("ApplicationReservation.zig");
const V = a.Values.Value;
const Self = @This();

pub const Secrets = struct {
    context: *anyopaque,
    /// Resolve the current authorized native declaration and its immutable
    /// mounted version. The revision must identify that native read guard.
    lookup: *const fn (*anyopaque, std.mem.Allocator, []const u8) anyerror!R.Material,
    /// The native implementation joins this read to the current transaction
    /// when one exists. A preliminary metadata comparison is insufficient.
    current: *const fn (*anyopaque, []const u8) anyerror!bool,
};
pub const Request = struct {
    query: []const u8,
    headers: []const c.DeclarativeIngress.HeaderPair,
};
reservation: *R,
access: R.Access,
step: u32,
io: std.Io,
output: std.mem.Allocator,
/// Must not overlap reservation storage or the public output allocator.
private_memory: []u8,
request: Request,
secrets: Secrets,
ordinary: a.Evaluation.Host,

pub fn host(self: *Self) a.Evaluation.Host {
    return .{ .context = self, .lookup = lookup, .evaluate = evaluate, .condition = condition };
}
fn lookup(context: *anyopaque, name: []const u8) !V {
    const self: *Self = @ptrCast(@alignCast(context));
    return self.ordinary.lookup(self.ordinary.context, name);
}
fn condition(context: *anyopaque, value: V) !bool {
    const self: *Self = @ptrCast(@alignCast(context));
    const resolved = try self.scalar(value);
    if (resolved == .null) return false;
    if (resolved != .boolean) return error.ProgramTypeMismatch;
    return resolved.boolean;
}
fn scalar(self: *Self, value: V) !V {
    if (value == .sealed) return (try self.reservation.read(self.access, value, .scalar)).scalar;
    try value.public();
    return value;
}
fn materialBytes(self: *Self, value: V, use: R.Use) ![]const u8 {
    if (value == .secret) return (try self.reservation.read(self.access, value, use)).secret.bytes;
    try value.public();
    return switch (value) {
        .text, .binary => |bytes| bytes,
        else => error.ProgramTypeMismatch,
    };
}
fn observation(self: *Self, scratch: std.mem.Allocator, node: a.Id, operation: a.Evaluation.Operation, args: []const V) !R.Observation {
    const bytes = try p.Json.valueAllocBounded(scratch, .{ .owner = self.access.owner, .input = self.access.input, .step = self.step, .node = node, .operation = operation, .arguments = args }, a.Codec.max_bytes);
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.application.protected-observation.v1\x00");
    hash.update(bytes);
    return .{ .step = self.step, .node = node, .arguments = hash.finalResult() };
}
fn cached(self: *Self, site: R.Observation) !?V {
    const value = try self.reservation.find(self.access, site) orelse return null;
    // Access to the request alone is not permission to redeem a named secret
    // or a provider response. Recheck the cached material's current authority.
    _ = try self.reservation.read(self.access, value, switch (value) {
        .secret => .derive,
        .protected_json => .json_projection,
        .sealed => .scalar,
        else => return error.ProtectedProgramValue,
    });
    return value;
}
fn protect(self: *Self, site: R.Observation, value: V) !V {
    if (value == .null) return .null;
    return self.reservation.retain(self.io, self.access, site, .{ .scalar = value });
}
fn secret(self: *Self, site: R.Observation, bytes: []const u8, revision: []const u8, origin: R.Origin) !V {
    return self.reservation.retain(self.io, self.access, site, .{ .secret = .{ .bytes = bytes, .revision = revision, .origin = origin } });
}
fn evaluate(context: *anyopaque, node: a.Id, operation: a.Evaluation.Operation, args: []const V) !V {
    const self: *Self = @ptrCast(@alignCast(context));
    if (self.private_memory.len == 0) return error.ApplicationReservationCapacity;
    var private = std.heap.FixedBufferAllocator.init(self.private_memory);
    defer std.crypto.secureZero(u8, self.private_memory);
    return self.run(private.allocator(), node, operation, args) catch |err| switch (err) {
        error.OutOfMemory, error.WriteFailed => error.ApplicationReservationCapacity,
        else => err,
    };
}
fn run(self: *Self, scratch: std.mem.Allocator, node: a.Id, operation: a.Evaluation.Operation, args: []const V) !V {
    const site = try self.observation(scratch, node, operation, args);
    switch (operation) {
        .protect => {
            if (args.len != 1) return error.ProgramArgumentMismatch;
            try args[0].public();
            return self.protect(site, args[0]);
        },
        .unary => |operator| {
            if (args.len != 1) return error.ProgramArgumentMismatch;
            if ((operator == .is_null or operator == .is_not_null) and (args[0] == .secret or args[0] == .protected_json)) {
                _ = try self.reservation.read(self.access, args[0], if (args[0] == .secret) .comparison else .json_projection);
                return self.protect(site, .{ .boolean = operator == .is_not_null });
            }
            const result = try a.Evaluation.applyUnary(operator, try self.scalar(args[0]));
            return self.protect(site, result);
        },
        .binary => |operator| {
            if (args.len != 2) return error.ProgramArgumentMismatch;
            const evaluation: a.Evaluation = .{ .scratch = scratch, .bound = &.{}, .host = self.ordinary };
            const result = try evaluation.applyBinary(operator, try self.scalar(args[0]), try self.scalar(args[1]));
            return self.protect(site, result);
        },
        .function => {},
    }
    const function = operation.function;
    switch (function) {
        .secret => {
            if (args.len != 1 or args[0] != .text) return error.ProgramArgumentMismatch;
            if (args[0].text.len == 0 or args[0].text.len > 255 or !std.unicode.utf8ValidateSlice(args[0].text)) return error.ProgramArgumentMismatch;
            if (try self.cached(site)) |value| return value;
            const material = try self.secrets.lookup(self.secrets.context, scratch, args[0].text);
            if (material != .secret or material.secret.origin != .named) return error.ProtectedProgramValue;
            return self.reservation.retain(self.io, self.access, site, material);
        },
        .secret_current => {
            if (args.len != 1 or args[0] != .secret) return error.ProgramArgumentMismatch;
            const material = (try self.reservation.read(self.access, args[0], .current)).secret;
            return .{ .boolean = try self.secrets.current(self.secrets.context, material.revision) };
        },
        .random_secret => {
            if (args.len != 1 or args[0] != .integer or args[0].integer < 16 or args[0].integer > 64) return error.ProgramArgumentMismatch;
            if (try self.cached(site)) |value| return value;
            var entropy: [64]u8 = undefined;
            defer std.crypto.secureZero(u8, &entropy);
            const selected = entropy[0..@intCast(args[0].integer)];
            try self.io.randomSecure(selected);
            const encoder = std.base64.url_safe_no_pad.Encoder;
            const bytes = try scratch.alloc(u8, encoder.calcSize(selected.len));
            return self.secret(site, encoder.encode(bytes, selected), &site.arguments, .random);
        },
        .derive_secret => {
            if (args.len != 3 or args[0] != .secret or args[1] != .text or args[2] != .text) return error.ProgramArgumentMismatch;
            const parent = (try self.reservation.read(self.access, args[0], .derive)).secret;
            if (try self.cached(site)) |value| return value;
            var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(parent.bytes);
            hmac.update("transit.application.derive-secret.v1\x00");
            var length: [8]u8 = undefined;
            for ([_][]const u8{ args[1].text, args[2].text }) |part| {
                std.mem.writeInt(u64, &length, part.len, .little);
                hmac.update(&length);
                hmac.update(part);
            }
            var digest: [32]u8 = undefined;
            defer std.crypto.secureZero(u8, &digest);
            hmac.final(&digest);
            var encoded: [43]u8 = undefined;
            defer std.crypto.secureZero(u8, &encoded);
            return self.secret(site, std.base64.url_safe_no_pad.Encoder.encode(&encoded, &digest), parent.revision, .derived);
        },
        .commitment, .s256 => {
            if (args.len != 1) return error.ProgramArgumentMismatch;
            if (args[0] == .null) return .null;
            var digest: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(try self.materialBytes(args[0], if (function == .commitment) .commitment else .s256), &digest, .{});
            if (function == .commitment) return .{ .binary = try self.output.dupe(u8, &digest) };
            const result = try self.output.alloc(u8, 43);
            return .{ .text = std.base64.url_safe_no_pad.Encoder.encode(result, &digest) };
        },
        .secure_equal => {
            if (args.len != 2) return error.ProgramArgumentMismatch;
            if (args[0] == .null or args[1] == .null) return .{ .boolean = false };
            const left = try self.materialBytes(args[0], .comparison);
            const right = try self.materialBytes(args[1], .comparison);
            return .{ .boolean = left.len == right.len and std.crypto.timing_safe.compare(u8, left, right, .big) == .eq };
        },
        .http_query, .http_query_unique, .http_secret_query_unique, .http_secret_cookie_unique => {
            if (args.len != 2 or args[1] != .text) return error.ProgramArgumentMismatch;
            try self.reservation.request(self.access, args[0]);
            const name = args[1].text;
            const ordinary = function == .http_query or function == .http_query_unique;
            if (ordinary and !std.mem.eql(u8, name, "state") and !std.mem.eql(u8, name, "error")) return error.ProtectedProgramValue;
            if (!ordinary) if (try self.cached(site)) |value| return value;
            if (self.request.query.len > 8192 or self.request.headers.len > 64) return error.ProgramTooComplex;
            const found = if (function == .http_secret_cookie_unique)
                try c.DeclarativeIngress.InboundBoundaryPolicy.extractUniqueCookie(self.request.headers, name)
            else if (self.request.query.len == 0)
                null
            else
                try @import("BrowserRequest.zig").parameter(scratch, self.request.query, name);
            const bytes = found orelse return .null;
            if (ordinary) {
                if (!std.unicode.utf8ValidateSlice(bytes)) return error.ProgramTypeMismatch;
                return .{ .text = try self.output.dupe(u8, bytes) };
            }
            return self.secret(site, bytes, &site.arguments, if (function == .http_secret_cookie_unique) .request_cookie else .request_query);
        },
        .json_value, .json_integer, .secret_json_value => {
            if (args.len != 2 or args[1] != .text) return error.ProgramArgumentMismatch;
            if (args[0] == .null) return .null;
            if (function != .secret_json_value and args[0] != .protected_json)
                return self.ordinary.evaluate(self.ordinary.context, node, operation, args);
            const bytes = if (args[0] == .protected_json)
                (try self.reservation.read(self.access, args[0], .json_projection)).json
            else if (args[0] == .json)
                args[0].json
            else
                return error.ProgramTypeMismatch;
            if (function == .json_integer and !std.mem.eql(u8, args[1].text, "$.id")) return error.ProtectedProgramValue;
            const result = try a.Json.project(scratch, bytes, args[1].text, if (function == .json_integer) .integer else if (function == .secret_json_value) .string else .text);
            if (result == .null or function == .json_integer) return result;
            if (function == .secret_json_value) return self.secret(site, result.text, &site.arguments, .provider_token);
            return self.protect(site, result);
        },
        .bearer => {
            if (args.len != 1 or args[0] != .secret) return error.ProgramArgumentMismatch;
            const parent = (try self.reservation.read(self.access, args[0], .bearer)).secret;
            if (!validBearer(parent.bytes)) return error.ProtectedProgramValue;
            if (try self.cached(site)) |value| return value;
            return self.secret(site, try std.mem.concat(scratch, u8, &.{ "Bearer ", parent.bytes }), parent.revision, .bearer);
        },
        .length => if (args.len == 1 and args[0] == .sealed) {
            const value = try self.scalar(args[0]);
            if (value != .text) return error.ProgramTypeMismatch;
            return self.protect(site, .{ .integer = @intCast(try std.unicode.utf8CountCodepoints(value.text)) });
        },
        else => {},
    }
    for (args) |arg| try arg.public();
    return self.ordinary.evaluate(self.ordinary.context, node, operation, args);
}
fn validBearer(bytes: []const u8) bool {
    if (bytes.len == 0 or bytes.len > 8192 or bytes[0] == '=') return false;
    var padding = false;
    for (bytes) |byte| {
        if (byte == '=') {
            padding = true;
        } else if (padding or (!std.ascii.isAlphanumeric(byte) and std.mem.indexOfScalar(u8, "-._~+/", byte) == null)) return false;
    }
    return true;
}

const Proof = struct {
    allowed: bool = true,
    current: bool = true,
    lookups: usize = 0,
    fn check(context: *anyopaque, evidence: R.Evidence) !void {
        const self: *@This() = @ptrCast(@alignCast(context));
        if (!self.allowed) return error.AccessDenied;
        if (evidence == .redemption and evidence.redemption.use != .current and !self.current) return error.AccessDenied;
    }
    fn named(context: *anyopaque, _: std.mem.Allocator, name: []const u8) !R.Material {
        const self: *@This() = @ptrCast(@alignCast(context));
        if (!std.mem.eql(u8, name, "browser.cookie_key")) return error.UnknownProgramResource;
        self.lookups += 1;
        return .{ .secret = .{ .bytes = "testing-cookie-key", .revision = "native-secret-revision", .origin = .named } };
    }
    fn isCurrent(context: *anyopaque, revision: []const u8) !bool {
        const self: *@This() = @ptrCast(@alignCast(context));
        return self.current and std.mem.eql(u8, revision, "native-secret-revision");
    }
    fn ordinaryLookup(_: *anyopaque, _: []const u8) !V {
        return error.UnknownProgramVariable;
    }
    fn ordinaryEvaluate(_: *anyopaque, _: a.Id, _: a.Evaluation.Operation, _: []const V) !V {
        return error.UnsupportedProgramInstruction;
    }
    fn ordinaryCondition(_: *anyopaque, _: V) !bool {
        return error.ProtectedProgramValue;
    }
    fn access() R.Access {
        const scope: p.DataLifecycle.Scope = .{ .realm = 1, .resource = 2, .catalog = 3 };
        return .{
            .owner = .{ .definition = p.Growth.current_definition, .connection = .{ .scope = scope, .branch = 1, .audience = 5, .principal = 17, .role = 19 }, .account = @splat(1), .token = @splat(2) },
            .input = .{ .target = .{ .definition = p.Growth.current_definition, .interpretation = .{ .object = .{ .scope = scope, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(3) }, .partition = 0 }, .operation = .{ .scope = scope, .principal = 23, .operation = 29 }, .ordinal = 0 },
            .now_ms = 100,
        };
    }
    fn make(self: *@This(), reservation: *R, output: std.mem.Allocator, private_memory: []u8) Self {
        return .{
            .reservation = reservation,
            .access = access(),
            .step = 1,
            .io = std.testing.io,
            .output = output,
            .private_memory = private_memory,
            .request = .{ .query = "state=public-state&code=private-code", .headers = &.{.{ .name = "Cookie", .value = "__Host-transit_login=private-cookie" }} },
            .secrets = .{ .context = self, .lookup = named, .current = isCurrent },
            .ordinary = .{ .context = self, .lookup = ordinaryLookup, .evaluate = ordinaryEvaluate, .condition = ordinaryCondition },
        };
    }
};

test "protected application helpers retain original entropy and domain separated derivation with erased scratch" {
    const t = std.testing;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const private = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(private);
    var memory: [8192]u8 = undefined;
    var slots: [16]R.Slot = undefined;
    var proof: Proof = .{};
    var reservation = try R.init(t.io, &memory, &slots, @splat(1), Proof.access().input, 100, 200, .{ .context = &proof, .check = Proof.check });
    defer reservation.deinit();
    var self = proof.make(&reservation, output.allocator(), private);
    const secret_ = try evaluate(&self, 1, .{ .function = .secret }, &.{.{ .text = "browser.cookie_key" }});
    try t.expectEqualDeep(secret_, try evaluate(&self, 1, .{ .function = .secret }, &.{.{ .text = "browser.cookie_key" }}));
    try t.expectEqual(@as(usize, 1), proof.lookups);
    const derived = try evaluate(&self, 2, .{ .function = .derive_secret }, &.{ secret_, .{ .text = "public-state" }, .{ .text = "pkce" } });
    try t.expectEqualStrings("9L2Bs3buHqs7Xj0baRm4L-zFgv0nYq770PWL-4G_QLg", (try reservation.read(self.access, derived, .cookie)).secret.bytes);
    const commitment = try evaluate(&self, 3, .{ .function = .commitment }, &.{derived});
    try t.expectEqualStrings("856071766098956578cc9222fea92e69df5d6d2897ea07f5055c43031d21e666", try std.fmt.allocPrint(output.allocator(), "{x}", .{commitment.binary}));
    const random = try evaluate(&self, 4, .{ .function = .random_secret }, &.{.{ .integer = 32 }});
    const retained = reservation.used;
    try t.expectEqualDeep(random, try evaluate(&self, 4, .{ .function = .random_secret }, &.{.{ .integer = 32 }}));
    try t.expectEqual(retained, reservation.used);
    try t.expectEqual(@as(usize, 43), (try reservation.read(self.access, random, .cookie)).secret.bytes.len);
    try t.expectError(error.ProtectedObservationChanged, evaluate(&self, 4, .{ .function = .random_secret }, &.{.{ .integer = 16 }}));
    try t.expect((try evaluate(&self, 5, .{ .function = .secret_current }, &.{secret_})).boolean);
    proof.current = false;
    try t.expect(!(try evaluate(&self, 5, .{ .function = .secret_current }, &.{secret_})).boolean);
    try t.expectError(error.AccessDenied, evaluate(&self, 1, .{ .function = .secret }, &.{.{ .text = "browser.cookie_key" }}));
    try t.expect(std.mem.allEqual(u8, private, 0));
    reservation.close();
    try t.expect(std.mem.allEqual(u8, &memory, 0));
}

test "protected request helpers enforce unique fields exact input ownership and cache revocation" {
    const t = std.testing;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const private = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(private);
    var memory: [8192]u8 = undefined;
    var slots: [16]R.Slot = undefined;
    var proof: Proof = .{};
    var reservation = try R.init(t.io, &memory, &slots, @splat(1), Proof.access().input, 100, 200, .{ .context = &proof, .check = Proof.check });
    defer reservation.deinit();
    var self = proof.make(&reservation, output.allocator(), private);
    const request_: V = .{ .capability = reservation.reference };
    try t.expectEqualStrings("public-state", (try evaluate(&self, 1, .{ .function = .http_query_unique }, &.{ request_, .{ .text = "state" } })).text);
    try t.expectError(error.ProtectedProgramValue, evaluate(&self, 2, .{ .function = .http_query }, &.{ request_, .{ .text = "code" } }));
    const code = try evaluate(&self, 3, .{ .function = .http_secret_query_unique }, &.{ request_, .{ .text = "code" } });
    try t.expectEqualStrings("private-code", (try reservation.read(self.access, code, .form)).secret.bytes);
    const present = try evaluate(&self, 6, .{ .unary = .is_not_null }, &.{code});
    try t.expect(present == .sealed);
    try t.expect(try condition(&self, present));
    try t.expectError(error.ProtectedProgramValue, reservation.read(self.access, code, .cookie));
    self.request.query = "state=one&st%61te=two";
    try t.expectError(error.DuplicateBrowserParameter, evaluate(&self, 4, .{ .function = .http_query_unique }, &.{ request_, .{ .text = "state" } }));
    self.request.query = "state=%FF";
    try t.expectError(error.ProgramTypeMismatch, evaluate(&self, 4, .{ .function = .http_query_unique }, &.{ request_, .{ .text = "state" } }));
    self.request.headers = &.{ .{ .name = "Cookie", .value = "__Host-transit_login=a" }, .{ .name = "cookie", .value = "__Host-transit_login=b" } };
    try t.expectError(error.DuplicateOrEmptyCookie, evaluate(&self, 5, .{ .function = .http_secret_cookie_unique }, &.{ request_, .{ .text = "__Host-transit_login" } }));
    self.access.input.ordinal += 1;
    try t.expectError(error.ApplicationRequestOwnerMismatch, evaluate(&self, 3, .{ .function = .http_secret_query_unique }, &.{ request_, .{ .text = "code" } }));
    self.access = Proof.access();
    proof.allowed = false;
    try t.expectError(error.AccessDenied, evaluate(&self, 3, .{ .function = .http_secret_query_unique }, &.{ request_, .{ .text = "code" } }));
    try t.expect(std.mem.allEqual(u8, private, 0));
}

test "protected helper scratch exhaustion preserves accepted material and erases partial work" {
    const t = std.testing;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const private = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(private);
    var memory: [8192]u8 = undefined;
    var slots: [16]R.Slot = undefined;
    var proof: Proof = .{};
    var reservation = try R.init(t.io, &memory, &slots, @splat(1), Proof.access().input, 100, 200, .{ .context = &proof, .check = Proof.check });
    defer reservation.deinit();
    var self = proof.make(&reservation, output.allocator(), private);
    const secret_ = try evaluate(&self, 1, .{ .function = .secret }, &.{.{ .text = "browser.cookie_key" }});
    var too_small: [64]u8 = @splat(0x7f);
    self.private_memory = &too_small;
    const retained = reservation.used;
    try t.expectError(error.ApplicationReservationCapacity, evaluate(&self, 2, .{ .function = .random_secret }, &.{.{ .integer = 32 }}));
    try t.expectEqual(retained, reservation.used);
    try t.expect(std.mem.allEqual(u8, &too_small, 0));
    try t.expectEqualStrings("testing-cookie-key", (try reservation.read(self.access, secret_, .commitment)).secret.bytes);
}

test "protected JSON projections preserve exact subjects and keep scalar operations sealed" {
    const t = std.testing;
    var output = std.heap.ArenaAllocator.init(t.allocator);
    defer output.deinit();
    const private = try t.allocator.alloc(u8, 1024 * 1024);
    defer t.allocator.free(private);
    var memory: [8192]u8 = undefined;
    var slots: [16]R.Slot = undefined;
    var proof: Proof = .{};
    var reservation = try R.init(t.io, &memory, &slots, @splat(1), Proof.access().input, 100, 200, .{ .context = &proof, .check = Proof.check });
    defer reservation.deinit();
    var self = proof.make(&reservation, output.allocator(), private);
    const body = try reservation.retain(t.io, self.access, .{ .step = 0, .node = 1, .arguments = @splat(4) }, .{ .json = "{\"id\":9007199254740993,\"error\":\"private error\",\"access_token\":\"gho_abc\"}" });
    const subject = try evaluate(&self, 1, .{ .function = .json_integer }, &.{ body, .{ .text = "$.id" } });
    try t.expectEqual(@as(i64, 9007199254740993), subject.integer);
    try t.expectError(error.ProtectedProgramValue, evaluate(&self, 2, .{ .function = .json_integer }, &.{ body, .{ .text = "$.error" } }));
    const message = try evaluate(&self, 3, .{ .function = .json_value }, &.{ body, .{ .text = "$.error" } });
    try t.expect(message == .sealed);
    const encoded = try p.Json.valueAllocBounded(output.allocator(), message, 4096);
    try t.expect(std.mem.indexOf(u8, encoded, "private error") == null);
    const same_ = try evaluate(&self, 4, .{ .binary = .equal }, &.{ message, .{ .text = "private error" } });
    try t.expect(same_ == .sealed);
    try t.expect(try condition(&self, same_));
    try t.expectError(error.ProtectedProgramValue, evaluate(&self, 5, .{ .function = .json_object }, &.{ .{ .text = "leak" }, message }));
    const token = try evaluate(&self, 6, .{ .function = .secret_json_value }, &.{ body, .{ .text = "$.access_token" } });
    try t.expectError(error.ProtectedProgramValue, reservation.read(self.access, token, .cookie));
    const bearer = try evaluate(&self, 7, .{ .function = .bearer }, &.{token});
    try t.expectEqualStrings("Bearer gho_abc", (try reservation.read(self.access, bearer, .header)).secret.bytes);
    try t.expect(!validBearer("bad\r\nAuthorization: forged"));
    try t.expect(!validBearer("bad=paddingX"));
    try t.expect(!validBearer("==="));
    try t.expect(std.mem.allEqual(u8, private, 0));
}

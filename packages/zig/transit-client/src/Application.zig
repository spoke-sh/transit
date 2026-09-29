//! Language-neutral local application declarations and authenticated management.
//! Physical placement is owned by the CLI; these values confer no native rights.
const std = @import("std");
const p = @import("transit_protocol");
const g = p.Growth;
pub const max_bytes = 65536;
pub const max_roles = 8;
pub const max_resources = 16;
pub const max_callers = 8;
pub const worker_permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish);
pub const read_permissions = p.State.permission(.inspect) | p.State.permission(.read);
pub const Artifact = struct { path: []const u8, sha256: [32]u8 = @splat(0) };
pub const Access = struct { name: []const u8, resource: []const u8, permissions: u8, required: bool = true };
pub const Role = struct {
    name: []const u8,
    contract: []const u8,
    artifact: Artifact,
    configuration: []const u8 = "{}",
    accesses: []const Access,
    depends_on: []const []const u8 = &.{},
};
pub const Resource = struct { name: []const u8, writer: []const u8 };
pub const Read = struct { resource: []const u8, permissions: u8 = read_permissions };
pub const Caller = struct { name: []const u8, send_to: ?[]const u8 = null, reads: []const Read = &.{} };
pub const Initialize = struct { role: []const u8, caller: []const u8, value: p.Value };
pub const Declaration = struct {
    pub const json_schema_fields = .{ .version = .{ .type = "integer", .minimum = 1, .maximum = 2 } };
    version: u32 = 1,
    application: []const u8,
    roles: []const Role,
    resources: []const Resource,
    callers: []const Caller,
    initialize: []const Initialize = &.{},
    inspection: []const Read = &.{},
    /// Preserve the original v1 signed representation and retained digest.
    /// Explicit inspection declarations select v2; omitted v1 defaults stay v1.
    pub fn jsonStringify(self: Declaration, out: *std.json.Stringify) std.Io.Writer.Error!void {
        try out.beginObject();
        inline for (@typeInfo(Declaration).@"struct".field_names) |field| {
            if (comptime std.mem.eql(u8, field, "inspection")) {
                if (self.version == 2) {
                    try out.objectField(field);
                    try p.Json.write(self.inspection, out);
                }
            } else {
                try out.objectField(field);
                try p.Json.write(@field(self, field), out);
            }
        }
        try out.endObject();
    }
    pub fn validate(self: Declaration) !void {
        if (self.version != 1 and self.version != 2) return error.UnsupportedApplicationVersion;
        if (self.version == 1 and self.inspection.len != 0) return error.UnsupportedApplicationVersion;
        try name(self.application);
        if (self.roles.len == 0 or self.roles.len > max_roles or self.resources.len > max_resources or self.callers.len > max_callers or self.initialize.len > 16) return error.ApplicationLimit;
        try unique(self.roles);
        try unique(self.resources);
        try unique(self.callers);
        for (self.roles, 0..) |role, i| {
            try name(role.contract);
            try artifact(role.artifact);
            try configuration(role.configuration);
            if (role.accesses.len > max_resources or role.depends_on.len > max_roles) return error.ApplicationLimit;
            try unique(role.accesses);
            for (role.depends_on, 0..) |dependency, j| {
                _ = index(Role, self.roles[0..i], dependency) orelse return error.InvalidStartupDependency;
                for (role.depends_on[0..j]) |previous| if (std.mem.eql(u8, dependency, previous)) return error.InvalidStartupDependency;
            }
            for (role.accesses, 0..) |access, access_index| {
                if (access.name.len > g.key_bytes) return error.InvalidApplicationName;
                for (role.accesses[0..access_index]) |previous| if (std.mem.eql(u8, previous.resource, access.resource)) return error.InvalidApplicationGrant;
                const resource = self.resources[index(Resource, self.resources, access.resource) orelse return error.UnknownApplicationResource];
                if (access.permissions == 0 or access.permissions & ~p.State.all_permissions != 0 or
                    (access.permissions & p.State.permission(.write) != 0 and !std.mem.eql(u8, resource.writer, role.name))) return error.InvalidApplicationGrant;
            }
        }
        for (self.resources) |resource| _ = index(Role, self.roles, resource.writer) orelse return error.UnknownApplicationRole;
        for (self.callers) |caller| {
            if (caller.send_to) |target| _ = index(Role, self.roles, target) orelse return error.UnknownApplicationRole;
            if (caller.reads.len > max_resources) return error.ApplicationLimit;
            for (caller.reads, 0..) |read, i| {
                _ = index(Resource, self.resources, read.resource) orelse return error.UnknownApplicationResource;
                if (read.permissions == 0 or read.permissions & ~read_permissions != 0) return error.InvalidApplicationGrant;
                for (caller.reads[0..i]) |previous| if (std.mem.eql(u8, previous.resource, read.resource)) return error.InvalidApplicationGrant;
                // A PID-scoped sender can read only resources associated with that PID.
                if (caller.send_to) |target| {
                    const role = self.roles[index(Role, self.roles, target).?];
                    var associated = false;
                    for (role.accesses) |access| if (std.mem.eql(u8, access.resource, read.resource)) {
                        associated = true;
                    };
                    if (!associated) return error.InvalidApplicationGrant;
                }
            }
        }
        if (self.inspection.len > max_resources) return error.ApplicationLimit;
        for (self.inspection, 0..) |read, i| {
            _ = index(Resource, self.resources, read.resource) orelse return error.UnknownApplicationResource;
            if (read.permissions == 0 or read.permissions & ~read_permissions != 0) return error.InvalidApplicationGrant;
            for (self.inspection[0..i]) |previous| if (std.mem.eql(u8, previous.resource, read.resource)) return error.InvalidApplicationGrant;
        }
        for (self.initialize) |initial| {
            _ = index(Role, self.roles, initial.role) orelse return error.UnknownApplicationRole;
            const caller = self.callers[index(Caller, self.callers, initial.caller) orelse return error.UnknownApplicationCaller];
            if (caller.send_to == null or !std.mem.eql(u8, caller.send_to.?, initial.role)) return error.InvalidApplicationGrant;
            try initial.value.validate();
        }
    }
};
pub const Replacement = struct {
    application: []const u8,
    role: []const u8,
    expected_revision: [32]u8,
    contract: []const u8,
    artifact: Artifact,
    configuration: []const u8 = "{}",
};
pub const Request = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u32 = 1,
    installation: [16]u8,
    realm: u64,
    principal: u64,
    operation: []const u8,
    command: union(enum) {
        install: Declaration,
        replace: Replacement,
        status: struct { application: []const u8, after: u32 = 0 },
        connect: struct { application: []const u8, caller: []const u8 },
    },
    pub fn application(self: Request) []const u8 {
        return switch (self.command) {
            inline else => |value| value.application,
        };
    }
    pub fn validate(self: Request) !void {
        if (self.version != 1 or self.realm == 0 or self.realm > p.max_counter or self.principal == 0 or self.principal > p.max_counter or std.mem.allEqual(u8, &self.installation, 0)) return error.InvalidApplicationRequest;
        try name(self.operation);
        try name(self.application());
        switch (self.command) {
            .install => |value| try value.validate(),
            .replace => |value| {
                try name(value.role);
                try name(value.contract);
                try artifact(value.artifact);
                try configuration(value.configuration);
                if (std.mem.allEqual(u8, &value.expected_revision, 0)) return error.InvalidApplicationRequest;
            },
            .connect => |value| try name(value.caller),
            .status => {},
        }
    }
};
pub const Signed = struct { request: Request, public_key: [32]u8, identity: g.SignedQuery, signature: [64]u8 };
pub fn digest(allocator: std.mem.Allocator, value: anytype) ![32]u8 {
    const bytes = try p.Json.valueAlloc(allocator, value);
    defer allocator.free(bytes);
    if (bytes.len > max_bytes) return error.ApplicationLimit;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    hash.update("transit.application.v1\x00");
    hash.update(bytes);
    return hash.finalResult();
}
pub fn sign(allocator: std.mem.Allocator, request: Request, key: p.Ed25519.KeyPair) !Signed {
    try request.validate();
    return .{ .request = request, .public_key = key.public_key.toBytes(), .identity = try g.signQuery(.{ .realm = request.realm, .principal = request.principal, .kind = .identity }, key), .signature = (try key.sign(&try digest(allocator, request), null)).toBytes() };
}
/// Cryptographic binding only. The host MUST submit identity to the current
/// authority and check its permissions before any management action/disclosure.
pub fn verify(allocator: std.mem.Allocator, signed: Signed) !void {
    try signed.request.validate();
    const query = signed.identity.query;
    if (query.realm != signed.request.realm or query.principal != signed.request.principal or query.kind != .identity) return error.InvalidApplicationIdentity;
    const key = try p.Ed25519.PublicKey.fromBytes(signed.public_key);
    try p.Ed25519.Signature.fromBytes(signed.identity.signature).verify(&try g.queryDigest(query), key);
    try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try digest(allocator, signed.request), key);
}
pub const Binding = struct { name: []const u8, id: u64 };
pub const Bootstrap = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u32 = 1,
    application: []const u8,
    role: []const u8,
    contract: []const u8,
    revision: [32]u8,
    url: []const u8,
    realm: u64,
    principal: u64,
    pid: u64,
    generation: u64,
    activation_directory: []const u8,
    roles: []const Binding,
    resources: []const Binding,
    callers: []const Binding,
    configuration: []const u8,
    pub fn validate(self: Bootstrap) !void {
        if (self.version != 1 or self.realm == 0 or self.realm > p.max_counter or self.principal == 0 or self.principal > p.max_counter or self.pid == 0 or self.pid > p.max_counter or self.generation == 0 or self.generation > p.max_counter) return error.InvalidApplicationBootstrap;
        try name(self.application);
        try name(self.role);
        try name(self.contract);
        if (self.roles.len > max_roles or self.resources.len > max_resources or self.callers.len > max_callers) return error.ApplicationLimit;
        for ([_][]const Binding{ self.roles, self.resources, self.callers }) |bindings| {
            try unique(bindings);
            for (bindings) |entry| if (entry.id == 0 or entry.id > p.max_counter) return error.InvalidApplicationBootstrap;
        }
        if (try binding(self.roles, self.role) != self.pid or self.activation_directory.len == 0) return error.InvalidApplicationBootstrap;
        try endpoint(self.url);
        try path(self.activation_directory);
        if (std.mem.allEqual(u8, &self.revision, 0)) return error.InvalidApplicationBootstrap;
        try configuration(self.configuration);
    }
};
pub const Connection = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u32 = 1,
    application: []const u8,
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    roles: []const Binding,
    resources: []const Binding,
    callers: []const Binding,
    pub fn validate(self: Connection) !void {
        if (self.version != 1) return error.InvalidApplicationResponse;
        try name(self.application);
        try endpoint(self.url);
        try identifier(self.realm, false);
        try identifier(self.principal, false);
        try path(self.seed_file);
        try validateBindings(self.roles, max_roles, false);
        try validateBindings(self.resources, max_resources, false);
        try validateBindings(self.callers, max_callers, false);
        var present = false;
        for (self.callers) |caller| if (caller.id == self.principal) {
            present = true;
        };
        if (!present) return error.InvalidApplicationResponse;
    }
};
pub const Management = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u32 = 1,
    url: []const u8,
    realm: u64,
    installation: [16]u8,
    principal: u64,
    seed_file: []const u8,
    recovery_directory: []const u8,
};
pub const RoleStatus = struct { name: []const u8, pid: u64, principal: u64, generation: u64, revision: [32]u8, state: enum { pending, starting, ready, stopped, failed }, error_name: ?[]const u8 = null };
pub const Receipt = struct { index: u32, principal: u64, sequence: u64, position: u64, digest: [32]u8 };
pub const Status = struct {
    pub const json_schema_fields = .{ .version = .{ .@"const" = 1 } };
    version: u32 = 1,
    application: []const u8,
    declaration: [32]u8,
    installed: bool,
    roles: []const RoleStatus,
    resources: []const Binding,
    receipts: []const Receipt,
    next: ?u32 = null,
    pub fn validate(self: Status, after: u32) !void {
        if (self.version != 1 or self.roles.len == 0 or self.roles.len > max_roles or self.receipts.len > 8 or std.mem.allEqual(u8, &self.declaration, 0)) return error.InvalidApplicationResponse;
        try name(self.application);
        try unique(self.roles);
        try validateBindings(self.resources, max_resources, !self.installed);
        for (self.roles) |role| {
            try identifier(role.pid, !self.installed);
            try identifier(role.principal, false);
            try identifier(role.generation, role.state != .ready);
            if (std.mem.allEqual(u8, &role.revision, 0)) return error.InvalidApplicationResponse;
            if (role.state == .ready and !self.installed) return error.InvalidApplicationResponse;
            if (role.error_name) |err| try name(err);
        }
        for (self.receipts, 0..) |receipt, i| {
            if (receipt.index != @as(u64, after) + i or std.mem.allEqual(u8, &receipt.digest, 0)) return error.InvalidApplicationResponse;
            try identifier(receipt.principal, true);
            try identifier(receipt.sequence, false);
            try identifier(receipt.position, false);
            if (i > 0 and self.receipts[i - 1].position >= receipt.position) return error.InvalidApplicationResponse;
        }
        if (self.next) |next| if (self.receipts.len != 8 or @as(u64, after) + self.receipts.len != next) return error.InvalidApplicationResponse;
    }
};
fn identifier(value: u64, zero: bool) !void {
    if ((!zero and value == 0) or value > p.max_counter) return error.InvalidApplicationResponse;
}
fn path(value: []const u8) !void {
    if (!std.fs.path.isAbsolute(value) or value.len > 4096 or std.mem.indexOfScalar(u8, value, 0) != null) return error.InvalidApplicationPath;
}
fn endpoint(value: []const u8) !void {
    const prefix = "http://127.0.0.1:";
    if (!std.mem.startsWith(u8, value, prefix)) return error.InvalidApplicationEndpoint;
    const port = std.fmt.parseInt(u16, value[prefix.len..], 10) catch return error.InvalidApplicationEndpoint;
    if (port < 1024) return error.InvalidApplicationEndpoint;
}
fn validateBindings(values: []const Binding, limit: usize, zero: bool) !void {
    if (values.len > limit) return error.ApplicationLimit;
    try unique(values);
    for (values, 0..) |entry, i| {
        try identifier(entry.id, zero);
        for (values[0..i]) |previous| if (entry.id != 0 and entry.id == previous.id) return error.InvalidApplicationResponse;
    }
}
pub fn binding(bindings: []const Binding, target: []const u8) !u64 {
    return (bindings[index(Binding, bindings, target) orelse return error.UnknownApplicationBinding]).id;
}
pub fn index(comptime T: type, values: []const T, target: []const u8) ?usize {
    for (values, 0..) |value, i| if (std.mem.eql(u8, value.name, target)) return i;
    return null;
}
pub fn name(value: []const u8) !void {
    if (value.len == 0 or value.len > 64 or !std.ascii.isAlphanumeric(value[0])) return error.InvalidApplicationName;
    for (value) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-' and byte != '_') return error.InvalidApplicationName;
}
fn unique(values: anytype) !void {
    for (values, 0..) |value, i| {
        try name(value.name);
        for (values[0..i]) |previous| if (std.mem.eql(u8, value.name, previous.name)) return error.DuplicateApplicationName;
    }
}
pub fn artifact(value: Artifact) !void {
    if (!std.fs.path.isAbsolute(value.path) or value.path.len > 4096 or std.mem.indexOfScalar(u8, value.path, 0) != null or std.mem.allEqual(u8, &value.sha256, 0)) return error.InvalidApplicationArtifact;
}
fn configuration(value: []const u8) !void {
    if (value.len > 8192 or !std.unicode.utf8ValidateSlice(value)) return error.InvalidApplicationConfiguration;
}

test "management signatures bind deployment identity and complete command" {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(7));
    const request: Request = .{ .installation = @splat(1), .realm = 42, .principal = 9, .operation = "status-1", .command = .{ .status = .{ .application = "items" } } };
    var signed = try sign(std.testing.allocator, request, key);
    try verify(std.testing.allocator, signed);
    signed.request.installation[0] ^= 1;
    try std.testing.expectError(error.SignatureVerificationFailed, verify(std.testing.allocator, signed));
}
test "declarations reject grants outside writer ownership and dependency cycles" {
    var roles = [_]Role{ .{ .name = "data", .contract = "items-v1", .artifact = .{ .path = "/worker", .sha256 = @splat(1) }, .accesses = &.{.{ .name = "state", .resource = "data", .permissions = 7 }} }, .{ .name = "reader", .contract = "reader-v1", .artifact = .{ .path = "/reader", .sha256 = @splat(2) }, .accesses = &.{.{ .name = "data", .resource = "data", .permissions = 3 }}, .depends_on = &.{"data"} } };
    const declaration: Declaration = .{ .application = "items", .roles = &roles, .resources = &.{.{ .name = "data", .writer = "data" }}, .callers = &.{} };
    try declaration.validate();
    roles[1].accesses = &.{.{ .name = "data", .resource = "data", .permissions = 7 }};
    try std.testing.expectError(error.InvalidApplicationGrant, declaration.validate());
    roles[1].accesses = &.{.{ .name = "data", .resource = "data", .permissions = 3 }};
    roles[0].depends_on = &.{"reader"};
    try std.testing.expectError(error.InvalidStartupDependency, declaration.validate());
}

/// One bounded attempt. The caller owns the exact signed mutation and any
/// persistence/retry policy. Returned parsed values own their string/array data.
pub const Client = struct {
    http: std.http.Client,
    url: []const u8,
    timeout_ms: u32 = 5000,
    last_error: [64]u8 = undefined,
    last_error_length: usize = 0,
    pub fn init(allocator: std.mem.Allocator, io: std.Io, url: []const u8) !Client {
        try endpoint(url);
        return .{ .http = .{ .allocator = allocator, .io = io }, .url = url };
    }
    pub fn deinit(self: *Client) void {
        self.http.deinit();
    }
    pub fn call(self: *Client, comptime T: type, signed: Signed) !std.json.Parsed(T) {
        if (self.timeout_ms == 0 or self.timeout_ms > 60000) return error.InvalidApplicationDeadline;
        try signed.request.validate();
        self.last_error_length = 0;
        const Result = union(enum) { response: anyerror!std.json.Parsed(T), timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(self.http.io, &results);
        defer while (select.cancel()) |result| switch (result) {
            .response => |response| {
                if (response) |parsed| parsed.deinit() else |_| {}
            },
            .timeout => {},
        };
        try select.concurrent(.timeout, timeout, .{ self.http.io, self.timeout_ms });
        const Task = struct {
            fn run(client: *Client, request: Signed) anyerror!std.json.Parsed(T) {
                return client.perform(T, request);
            }
        };
        try select.concurrent(.response, Task.run, .{ self, signed });
        return switch (try select.await()) {
            .response => |response| response,
            .timeout => |result| value: {
                try result;
                break :value error.ApplicationOutcomeUnknown;
            },
        };
    }
    fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
        try io.sleep(.fromMilliseconds(milliseconds), .awake);
    }
    fn perform(self: *Client, comptime T: type, signed: Signed) !std.json.Parsed(T) {
        const allocator = self.http.allocator;
        const url = try std.fmt.allocPrint(allocator, "{s}/applications/v1", .{self.url});
        defer allocator.free(url);
        const body = try p.Json.valueAlloc(allocator, signed);
        defer allocator.free(body);
        if (body.len > max_bytes) return error.ApplicationLimit;
        const buffer = try allocator.alloc(u8, max_bytes);
        defer allocator.free(buffer);
        var writer = std.Io.Writer.fixed(buffer);
        const response = try self.http.fetch(.{ .location = .{ .url = url }, .method = .POST, .payload = body, .headers = .{ .content_type = .{ .override = "application/json" } }, .redirect_behavior = .not_allowed, .keep_alive = false, .response_writer = &writer });
        if (response.status != .ok) {
            const failure = try std.json.parseFromSlice(struct { err: []const u8 }, allocator, writer.buffered(), .{});
            defer failure.deinit();
            if (failure.value.err.len > self.last_error.len) return error.InvalidApplicationResponse;
            for (failure.value.err) |byte| if (!std.ascii.isAlphanumeric(byte)) return error.InvalidApplicationResponse;
            @memcpy(self.last_error[0..failure.value.err.len], failure.value.err);
            self.last_error_length = failure.value.err.len;
            if (response.status == .service_unavailable) return error.ApplicationOutcomeUnknown;
            return error.ApplicationRejected;
        }
        const parsed = try p.Json.parseFromSliceOwned(T, allocator, writer.buffered());
        errdefer parsed.deinit();
        if (parsed.value.version != 1 or !std.mem.eql(u8, parsed.value.application, signed.request.application())) return error.InvalidApplicationResponse;
        if (T == Status) try parsed.value.validate(if (signed.request.command == .status) signed.request.command.status.after else 0) else if (T == Connection) {
            try parsed.value.validate();
            if (parsed.value.realm != signed.request.realm) return error.InvalidApplicationResponse;
        } else @compileError("Unsupported application response type");
        return parsed;
    }
};

test "public results reject duplicate bindings and non-advancing receipt cursors" {
    const connection: Connection = .{ .application = "items", .url = "http://127.0.0.1:8000", .realm = 42, .principal = 9, .seed_file = "/private/caller.seed", .roles = &.{.{ .name = "data", .id = 1 }}, .resources = &.{}, .callers = &.{ .{ .name = "operator", .id = 9 }, .{ .name = "alias", .id = 9 } } };
    try std.testing.expectError(error.InvalidApplicationResponse, connection.validate());
    var status: Status = .{ .application = "items", .declaration = @splat(1), .installed = false, .roles = &.{.{ .name = "data", .pid = 0, .principal = 9, .generation = 0, .revision = @splat(2), .state = .pending }}, .resources = &.{}, .receipts = &.{} };
    try status.validate(0);
    status.next = 0;
    try std.testing.expectError(error.InvalidApplicationResponse, status.validate(0));
}

test "inspection requires v2, explicit read scopes and stable v1 signatures" {
    const allocator = std.testing.allocator;
    var declaration: Declaration = .{ .application = "items", .roles = &.{.{ .name = "data", .contract = "items-v1", .artifact = .{ .path = "/worker", .sha256 = @splat(1) }, .accesses = &.{} }}, .resources = &.{.{ .name = "data", .writer = "data" }}, .callers = &.{} };
    const legacy = .{ .version = declaration.version, .application = declaration.application, .roles = declaration.roles, .resources = declaration.resources, .callers = declaration.callers, .initialize = declaration.initialize };
    try std.testing.expectEqual(try digest(allocator, legacy), try digest(allocator, declaration));
    declaration.inspection = &.{.{ .resource = "data", .permissions = 3 }};
    try std.testing.expectError(error.UnsupportedApplicationVersion, declaration.validate());
    declaration.version = 2;
    try declaration.validate();
    declaration.inspection = &.{.{ .resource = "data", .permissions = 7 }};
    try std.testing.expectError(error.InvalidApplicationGrant, declaration.validate());
    declaration.inspection = &.{.{ .resource = "hidden", .permissions = 1 }};
    try std.testing.expectError(error.UnknownApplicationResource, declaration.validate());
    declaration.inspection = &.{ .{ .resource = "data", .permissions = 1 }, .{ .resource = "data", .permissions = 3 } };
    try std.testing.expectError(error.InvalidApplicationGrant, declaration.validate());
}

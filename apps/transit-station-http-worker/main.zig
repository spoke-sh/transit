//! Finite, explicitly activated HTTP worker. Caller preparation, dispatch and
//! capture use the public client; no provider or raw journal access exists here.
const std = @import("std");
const http = @import("transit_station_http");
const telemetry = @import("telemetry");
const x = http.exchange;
const s = x.station;
const p = s.protocol;
const g = p.Growth;
const Server = s.GenServer;
const Turn = s.Turn;
const Credential = struct { binding: []const u8, version: u64, header: []const u8, file: []const u8 };
const RetryPolicy = http.Policy.Retry;
const Config = struct {
    url: []const u8,
    realm: u64,
    principal: u64,
    seed_file: []const u8,
    pid: u64,
    generation: u64,
    activation_directory: []const u8,
    association: []const u8 = "state",
    exchange: u64,
    endpoint_revision: u64,
    endpoint: http.Transport.Endpoint,
    mode: enum { prepare, accept, execute, release, poll },
    admission: ?struct { caller: u64, resource: u64, scope: http.Service.Scope } = null,
    cleanup_steps: u32 = 64,
    request: ?http.Request = null,
    body_file: ?[]const u8 = null,
    reconcile_before_ms: ?u64 = null,
    credentials: []const Credential = &.{},
    max_attempts: u32 = 1,
    retry_policy: ?RetryPolicy = null,
    redirect_policy: ?http.Policy.Reference = null,
    reconcile_policy: ?http.Policy.Action = null,
    cancel_policy: ?http.Policy.Action = null,
    followup: ?http.Service.FollowupTarget = null,
};
const Secrets = struct {
    gpa: std.mem.Allocator,
    io: std.Io,
    config: Config,
    values: [16]?[]u8 = @splat(null),
    fn deinit(self: *Secrets) void {
        for (self.values) |value| if (value) |bytes| {
            std.crypto.secureZero(u8, bytes);
            self.gpa.free(bytes);
        };
    }
    fn validate(config: Config, request: http.Request) !void {
        if (config.credentials.len > 16) return error.HttpCredentialCapacity;
        for (config.credentials, 0..) |credential, i| {
            if (credential.version == 0 or credential.binding.len == 0 or credential.file.len == 0) return error.InvalidHttpCredential;
            try http.validateHeader(credential.header, "");
            for (config.credentials[0..i]) |previous| if (std.mem.eql(u8, previous.binding, credential.binding)) return error.DuplicateHttpCredential;
        }
        for (request.headers) |header| for (header.value) |piece| if (piece == .secret) {
            if (!config.endpoint.tls) return error.HttpCredentialRequiresTls;
            const secret = piece.secret;
            const binding = for (config.credentials) |credential| {
                if (std.mem.eql(u8, credential.binding, secret.binding) and credential.version == secret.version) break credential;
            } else return error.HttpCredentialNotGranted;
            if (!std.ascii.eqlIgnoreCase(header.name, binding.header)) return error.HttpCredentialNotGranted;
        };
        for (request.headers) |header| {
            var credential_header = false;
            for ([_][]const u8{ "authorization", "cookie", "x-api-key" }) |name| if (std.ascii.eqlIgnoreCase(header.name, name)) {
                credential_header = true;
            };
            for (config.credentials) |credential| if (std.ascii.eqlIgnoreCase(header.name, credential.header)) {
                credential_header = true;
            };
            const has_reference = for (header.value) |piece| {
                if (piece == .secret) break true;
            } else false;
            if (credential_header and !has_reference) return error.HttpCredentialReferenceRequired;
        }
    }
    fn resolve(raw: *anyopaque, secret: http.Request.Secret) ![]const u8 {
        const self: *Secrets = @ptrCast(@alignCast(raw));
        for (self.config.credentials, 0..) |credential, i| if (credential.version == secret.version and std.mem.eql(u8, credential.binding, secret.binding)) {
            if (self.values[i] == null) self.values[i] = try std.Io.Dir.cwd().readFileAlloc(self.io, credential.file, self.gpa, .limited(4096));
            // Exact credential file bytes: implicit trimming would alter secrets.
            return self.values[i].?;
        };
        return error.HttpCredentialNotGranted;
    }
};
const Prepared = http.Policy.Prepared;
fn trustDigest(gpa: std.mem.Allocator, io: std.Io, endpoint: http.Transport.Endpoint) !?[32]u8 {
    if (!endpoint.tls) return null;
    // Freeze the explicit CA bundle, not a machine-local path or ambient roots.
    const path = endpoint.ca_file orelse return error.HttpExplicitTrustRequired;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .limited(1048576));
    defer gpa.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
const Driver = struct {
    const Engine = x.Worker(@This(), http, .{ .tick = "http.tick.v1", .admission_missing = error.HttpAdmissionNotConfigured, .followup_missing = error.HttpFollowupNotGranted, .request_oversize = error.HttpRequestTooLarge, .limits = .{ .segment_bytes = 8192, .capture_bytes = 262144, .segments = 256 } });
    const Operation = Engine.Operation;
    server: Server,
    reader: x.Client,
    config: Config,
    io: std.Io,
    gpa: std.mem.Allocator,
    operation: Operation = .idle,
    capture_failure: ?x.Failure = null,
    pub const admission = Engine.admission;
    pub const exchange = Engine.exchange;
    pub const command = Engine.command;
    pub const handle = Engine.handle;
    pub const drive = Engine.drive;
    pub const driveUntil = Engine.driveUntil;
    pub const apply = Engine.apply;
    pub const stage = Engine.stage;
    pub const stageAt = Engine.stageAt;
    pub const capture = Engine.capture;
    pub const effect = Engine.effect;
    pub const effectFor = Engine.effectFor;
    pub const load = Engine.load;
    pub const loadFrom = Engine.loadFrom;
    fn capturedLocation(self: *Driver, parent: x.Exchange, descriptor: x.Descriptor, buffer: []u8) !?[]const u8 {
        var used: usize = 0;
        var segment_buffer: [8192]u8 = undefined;
        for (0..descriptor.segments) |ordinal| {
            var source = try self.reader.reader(parent.resource);
            if ((try parent.member(&source, @intCast(ordinal))).kind != @backingInt(http.Kind.response_head)) continue;
            const bytes = try self.loadFrom(parent, @intCast(ordinal), &segment_buffer);
            for (bytes) |byte| {
                if (used == buffer.len) return error.HttpHeadersOversize;
                buffer[used] = byte;
                used += 1;
                if (!std.mem.endsWith(u8, buffer[0..used], "\r\n\r\n")) continue;
                if (used < 17 or !std.mem.startsWith(u8, buffer[0..used], "HTTP/1.1 ")) return error.InvalidHttpCapture;
                const status = try std.fmt.parseInt(u16, buffer[9..12], 10);
                if (status < 200) {
                    used = 0;
                    continue;
                }
                if (status != descriptor.terminal_code) return error.InvalidHttpCapture;
                var location: ?[]const u8 = null;
                var lines = std.mem.splitSequence(u8, buffer[0..used], "\r\n");
                _ = lines.next();
                while (lines.next()) |line| {
                    if (line.len == 0) break;
                    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return error.InvalidHttpCapture;
                    if (!std.ascii.eqlIgnoreCase(line[0..colon], "location")) continue;
                    if (location != null) return error.AmbiguousHttpRedirect;
                    location = std.mem.trim(u8, line[colon + 1 ..], " \t");
                }
                if (location) |target| if (std.mem.eql(u8, target, "{{omitted}}")) return error.HttpReplayGap;
                return location;
            }
        }
        return error.HttpReplayGap;
    }
    pub fn validateAdmission(self: *Driver, follow: http.Service.Followup) !http.Service.FollowupValidation {
        const reference = try follow.reference();
        const policy = self.config.admission orelse return error.HttpAdmissionNotConfigured;
        const input_resource = (try self.reader.query(.{ .resource = reference.resource })).body.resource;
        if (input_resource.writer != policy.caller) return .{ .rejected = .denied };
        var request_buffer: [8192]u8 = undefined;
        const request_bytes = try http.RequestRecord.read(&self.reader, reference, http.RequestRecord.metadata_id, &request_buffer);
        const parsed = std.json.parseFromSlice(http.Request, self.gpa, request_bytes, .{}) catch return .{ .rejected = .invalid_request };
        defer parsed.deinit();
        const request = parsed.value;
        if (request.body_bytes != reference.body_bytes or request.body_bytes > self.config.endpoint.request_bytes) return .{ .rejected = .invalid_request };
        Secrets.validate(self.config, request) catch return .{ .rejected = .denied };
        var header: [http.Request.maximum_head_bytes]u8 = undefined;
        const rendered = request.render(self.config.endpoint.host, self.config.endpoint.port, &header, null, false) catch return .{ .rejected = .invalid_request };
        http.Service.validateRequest(policy.scope, request, rendered) catch return .{ .rejected = .denied };
        const prepared = try self.prepareMetadata(request);
        var metadata_buffer: [8192]u8 = undefined;
        var metadata_writer = std.Io.Writer.fixed(&metadata_buffer);
        std.json.Stringify.value(prepared, .{}, &metadata_writer) catch return .{ .rejected = .invalid_request };
        const body = try self.gpa.alloc(u8, reference.body_bytes);
        defer self.gpa.free(body);
        _ = try http.RequestRecord.read(&self.reader, reference, http.RequestRecord.body_id, body);
        const decision = self.validateFollowup(self.gpa, prepared, body) catch |err| switch (err) {
            error.HttpRedirectNotCaptured,
            error.HttpFollowupNotSettled,
            error.ExpiredReconciliation,
            error.HttpFollowupNotGranted,
            error.InvalidHttpIdempotencyKey,
            error.HttpRedirectScope,
            error.HttpRedirectChanged,
            error.UnsupportedHttpRedirect,
            error.HttpFollowupTargetChanged,
            error.UnsupportedHttpReconciliation,
            error.UnsupportedHttpCancellation,
            error.HttpFollowupChanged,
            error.HttpRetryChanged,
            error.HttpReplayGap,
            => return .{ .rejected = .denied },
            else => return err,
        };
        return .{ .accepted = decision orelse return error.HttpFollowupNotGranted };
    }
    fn prepareMetadata(self: *Driver, request: http.Request) !Prepared {
        const config = self.config;
        return .{ .endpoint_revision = config.endpoint_revision, .host = config.endpoint.host, .address = config.endpoint.address, .port = config.endpoint.port, .tls = config.endpoint.tls, .timeout_ms = config.endpoint.timeout_ms, .request_bytes = config.endpoint.request_bytes, .response_bytes = config.endpoint.response_bytes, .response_headers = config.endpoint.response_headers, .trust_digest = try trustDigest(self.gpa, self.io, config.endpoint), .retry_policy = config.retry_policy, .redirect_policy = config.redirect_policy, .reconcile_policy = config.reconcile_policy, .cancel_policy = config.cancel_policy, .request = request };
    }
    fn validateFollowup(self: *Driver, gpa: std.mem.Allocator, prepared_value: Prepared, body: []const u8) !?http.Policy.Reference {
        const follow = self.config.followup orelse return null;
        const ex = try self.exchange();
        const parent: x.Exchange = .{ .resource = ex.resource, .id = follow.parent };
        const descriptor = try self.reader.inspect(parent.resource, parent.id);
        const parent_effect = try self.effectFor(parent);
        if (follow.reason == .redirect) {
            if (descriptor.phase != .complete or parent_effect.phase != .observed) return error.HttpRedirectNotCaptured;
        } else if (descriptor.phase != .unknown or parent_effect.phase != .closed_unknown) return error.HttpFollowupNotSettled;
        if (now(self.io) >= descriptor.reconcile_before_ms) return error.ExpiredReconciliation;
        var previous: [8192]u8 = undefined;
        const parsed = try std.json.parseFromSlice(Prepared, gpa, try self.loadFrom(parent, 0, &previous), .{});
        defer parsed.deinit();
        var head_buffer: [8192]u8 = undefined;
        const location = if (follow.reason == .redirect) try self.capturedLocation(parent, descriptor, &head_buffer) else null;
        const policy = try http.Policy.followup(gpa, follow.reason, parsed.value, prepared_value, if (follow.reason == .redirect) @intCast(descriptor.terminal_code) else null, location);
        if (follow.reason == .reconcile or follow.reason == .cancel) {
            if (body.len != 0) return error.HttpFollowupChanged;
            return policy;
        }
        var offset: usize = 0;
        var ordinal: u32 = 2;
        while (true) : (ordinal += 1) {
            var source = try self.reader.reader(ex.resource);
            if ((try parent.member(&source, ordinal)).kind != @backingInt(http.Kind.request_body)) return error.HttpRetryChanged;
            const bytes = try self.loadFrom(parent, ordinal, &previous);
            if (bytes.len > body.len - offset or !std.mem.eql(u8, bytes, body[offset..][0..bytes.len])) return error.HttpRetryChanged;
            offset += bytes.len;
            if (offset == body.len) break;
            if (bytes.len == 0) return error.HttpRetryChanged;
        }
        return policy;
    }
};
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-station-http-worker", try telemetry.Config.environment(init.environ_map));
    diagnostics.start();
    defer diagnostics.stop();
    defer diagnostics.event(.{ .name = "service.stopped" });
    diagnostics.event(.{ .name = "service.starting" });
    run(init, &diagnostics) catch |err| {
        diagnostics.event(.{ .name = "service.failed", .level = .err, .outcome = .failed, .error_type = @errorName(err) });
        return err;
    };
}
fn run(init: std.process.Init, diagnostics: *telemetry.Runtime) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 2) return error.ExpectedConfiguration;
    const data = try std.Io.Dir.cwd().readFileAlloc(init.io, args[1], init.gpa, .limited(65536));
    defer init.gpa.free(data);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, data, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.principal == 0 or config.pid == 0 or config.generation == 0 or config.exchange == 0 or config.endpoint_revision == 0 or config.cleanup_steps == 0 or config.cleanup_steps > 128) return error.InvalidConfiguration;
    try config.endpoint.validate();
    const key = try s.client.readKey(init.gpa, init.io, config.seed_file);
    var wire = s.client.Client.init(init.gpa, init.io, config.url);
    defer wire.deinit();
    wire.timeout_ms = 5000;
    wire.observer = diagnostics;
    var driver: Driver = .{ .server = try Server.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, config.association), .reader = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key }, .config = config, .io = init.io, .gpa = init.gpa };
    // Admission may read caller publications under revocable grants. An I/O
    // failure must leave the call pending for a fresh activation, not commit a
    // permanent framework block that prevents ownership recovery.
    driver.server.failure_policy = .stop;
    _ = try driver.server.session.receive();
    const marker = try std.fmt.allocPrint(init.gpa, "{s}/{d}-{d}-{d}.activation", .{ config.activation_directory, config.realm, config.pid, config.generation });
    defer init.gpa.free(marker);
    const file = try std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true });
    file.close(init.io);
    const ex = try driver.exchange();
    const capture_resource = (try driver.reader.query(.{ .resource = ex.resource })).body.resource;
    if (capture_resource.owner != null or capture_resource.deadline_ms != null) return error.IncompatibleExchangeLifetime;
    // Only report configured identities after current ownership and resource
    // reads have authenticated them. Operation names come from the finite enum.
    diagnostics.event(.{ .name = "service.ready", .realm = config.realm, .pid = config.pid, .generation = config.generation });
    var operation = diagnostics.begin(.application, null);
    errdefer operation.finish(.{ .name = "http.worker.operation", .operation = @tagName(config.mode), .level = .err, .outcome = .failed, .realm = config.realm, .pid = config.pid, .generation = config.generation });
    wire.parent_context = operation.context;
    defer wire.parent_context = null;
    // Dispose self-ticks left before an interrupted commit without reconstructing
    // lost network bytes. Capture state remains authoritative and incomplete.
    for (0..64) |_| {
        if (try driver.server.session.receive() == null) break;
        try driver.drive();
    } else return error.WorkerMailboxBusy;
    if (config.mode == .prepare or config.mode == .accept) {
        var request_buffer: [http.Request.maximum_head_bytes]u8 = undefined;
        var public_request: ?std.json.Parsed(http.Request) = null;
        defer if (public_request) |value| value.deinit();
        var public_reference: ?http.RequestRecord.Reference = null;
        if (config.mode == .accept) {
            var source = try driver.reader.reader(ex.resource);
            const route = (try http.Service.route(ex, &source)) orelse return error.MissingHttpCall;
            if (!http.Service.allowed(route, try driver.admission())) return error.HttpAdmissionDenied;
            const reference = try route.reference();
            const input_resource = (try driver.reader.query(.{ .resource = reference.resource })).body.resource;
            if (input_resource.writer != route.caller) return error.HttpAdmissionDenied;
            public_request = try std.json.parseFromSlice(http.Request, init.gpa, try http.RequestRecord.read(&driver.reader, reference, http.RequestRecord.metadata_id, &request_buffer), .{});
            public_reference = reference;
        }
        const request = if (public_request) |value| value.value else config.request orelse return error.MissingHttpRequest;
        if (request.body_bytes > 65536 or request.body_bytes > config.endpoint.request_bytes) return error.HttpRequestTooLarge;
        try Secrets.validate(config, request);
        const prior = driver.reader.inspect(ex.resource, ex.id) catch |err| if (err == error.ExchangeNotFound) null else return err;
        if (prior) |d| if (d.phase != .preparing and d.phase != .ready) return error.ExchangeClosed;
        const deadline = if (prior) |d| d.reconcile_before_ms else config.reconcile_before_ms orelse return error.MissingReconciliationDeadline;
        if (deadline <= now(init.io)) return error.ExpiredReconciliation;
        var header: [http.Request.maximum_head_bytes]u8 = undefined;
        const rendered = try request.render(config.endpoint.host, config.endpoint.port, &header, null, false);
        if (public_reference != null) try http.Service.validateRequest(config.admission.?.scope, request, rendered);
        // Prepare metadata before creating any durable obligation.
        const prepared = try driver.prepareMetadata(request);
        const metadata = try std.json.Stringify.valueAlloc(init.gpa, prepared, .{});
        defer init.gpa.free(metadata);
        if (metadata.len > 8192) return error.HttpRequestTooLarge;
        const body = if (public_reference) |reference| blk: {
            const buffer = try init.gpa.alloc(u8, reference.body_bytes);
            errdefer init.gpa.free(buffer);
            _ = try http.RequestRecord.read(&driver.reader, reference, http.RequestRecord.body_id, buffer);
            break :blk buffer;
        } else if (config.body_file) |path| try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536)) else try init.gpa.dupe(u8, "");
        defer init.gpa.free(body);
        if (body.len != request.body_bytes) return error.InvalidHttpBodyLength;
        const followup_policy = try driver.validateFollowup(init.gpa, prepared, body);
        try driver.apply(.{ .create = .{ .deadline = deadline, .limits = .{ .segment_bytes = 8192, .capture_bytes = 262144, .segments = 256 }, .policy = followup_policy } });
        if (config.followup == null) try driver.apply(.{ .attempts = if (public_reference) |reference| reference.max_attempts else config.max_attempts });
        try driver.stageAt(0, .request_template, metadata);
        try driver.stageAt(1, .request_head, rendered);
        var offset: usize = 0;
        var ordinal: u32 = 2;
        while (offset < body.len) {
            const end = offset + @min(http.Transport.segment_bytes, body.len - offset);
            try driver.stageAt(ordinal, .request_body, body[offset..end]);
            offset = end;
            ordinal += 1;
        }
        if (body.len == 0) try driver.stageAt(2, .request_body, "");
        try driver.apply(.intent);
    } else if (config.mode == .release) {
        // Explicit trusted-controller disposal, never inferred from elapsed
        // time, quota pressure, observation acceptance or caller termination.
        var current = try driver.reader.inspect(ex.resource, ex.id);
        if (current.phase == .preparing) {
            try driver.apply(.{ .unknown = .{ .reason = .controller_release } });
            current = try driver.reader.inspect(ex.resource, ex.id);
        }
        try driver.apply(.publish);
        var source = try driver.reader.reader(ex.resource);
        if ((try ex.control(&source)).disposition != .no_intent) try driver.apply(.{ .release_caller = current.caller });
        try driver.apply(.retire);
        for (0..config.cleanup_steps) |_| {
            current = try driver.reader.inspect(ex.resource, ex.id);
            if (current.collected == @as(u64, current.segments) + @intFromBool(current.pending_kind != 0)) break;
            try driver.apply(.collect);
        }
    } else if (config.mode == .execute) {
        var route_source = try driver.reader.reader(ex.resource);
        if (try http.Service.route(ex, &route_source)) |route| if (!http.Service.allowed(route, try driver.admission())) return error.HttpAdmissionDenied;
        var effect = try driver.effect();
        var descriptor = try driver.reader.inspect(ex.resource, ex.id);
        if (descriptor.phase == .ready and effect.phase == .pending) {
            var metadata_buffer: [8192]u8 = undefined;
            const metadata = try std.json.parseFromSlice(Prepared, init.gpa, try driver.load(0, &metadata_buffer), .{});
            defer metadata.deinit();
            const prepared = metadata.value;
            if (prepared.version != 1 or prepared.endpoint_revision != config.endpoint_revision or prepared.port != config.endpoint.port or prepared.tls != config.endpoint.tls or !std.mem.eql(u8, prepared.host, config.endpoint.host) or !std.mem.eql(u8, prepared.address, config.endpoint.address)) return error.HttpEndpointChanged;
            if (prepared.timeout_ms != config.endpoint.timeout_ms or prepared.request_bytes != config.endpoint.request_bytes or prepared.response_bytes != config.endpoint.response_bytes or prepared.response_headers.len != config.endpoint.response_headers.len or !std.meta.eql(prepared.trust_digest, try trustDigest(init.gpa, init.io, config.endpoint))) return error.HttpEndpointChanged;
            for (prepared.response_headers, config.endpoint.response_headers) |frozen, current| if (!std.mem.eql(u8, frozen, current)) return error.HttpEndpointChanged;
            // Explicit finite request buffer in this first executable profile;
            // neither response buffering nor durable group count scales with it.
            if (prepared.request.body_bytes > 65536) return error.HttpRequestTooLarge;
            try Secrets.validate(config, prepared.request);
            if (config.admission) |policy| {
                var header: [http.Request.maximum_head_bytes]u8 = undefined;
                try http.Service.validateRequest(policy.scope, prepared.request, try prepared.request.render(config.endpoint.host, config.endpoint.port, &header, null, false));
            }
            var body_buffer: [65536]u8 = undefined;
            var count: usize = 0;
            for (2..descriptor.segments) |ordinal| {
                const bytes = try driver.load(@intCast(ordinal), body_buffer[count..]);
                count += bytes.len;
            }
            if (count != prepared.request.body_bytes) return error.InvalidHttpBodyLength;
            const receipt = try driver.command(.{ .dispatch = .{ .pid = config.pid, .effect = effect.id, .reconcile_before_ms = descriptor.reconcile_before_ms, .max_observations = 1 } });
            effect = try driver.effect();
            if (effect.attempt != receipt.position or effect.executor != config.principal) return error.InvalidExchangeAttempt;
            try driver.apply(.{ .bind = effect });
            var body: std.Io.Reader = .fixed(body_buffer[0..count]);
            var secrets: Secrets = .{ .gpa = init.gpa, .io = init.io, .config = config };
            defer secrets.deinit();
            var endpoint = config.endpoint;
            const remaining = descriptor.reconcile_before_ms -| now(init.io);
            endpoint.timeout_ms = @intCast(@min(endpoint.timeout_ms, remaining));
            var transport = diagnostics.begin(.application, operation.context);
            const result = if (remaining == 0) @as(anyerror!http.Transport.Result, error.ExpiredReconciliation) else http.Transport.execute(init.gpa, init.io, endpoint, prepared.request, &body, .{ .context = &secrets, .resolve = Secrets.resolve }, .{ .context = &driver, .segment = Driver.capture });
            if (result) |response| {
                transport.finish(.{ .name = "http.transport.completed", .operation = "execute", .status = response.status, .realm = config.realm, .pid = config.pid, .generation = config.generation, .position = receipt.position });
                try driver.apply(.{ .finish = response.status });
            } else |err| {
                transport.finish(.{ .name = "http.transport.completed", .operation = "execute", .level = .warn, .outcome = .uncertain, .error_type = @errorName(err), .realm = config.realm, .pid = config.pid, .generation = config.generation, .position = receipt.position });
                try driver.apply(.{ .unknown = driver.capture_failure orelse x.Failure.failed(.transport_failure, err) });
            }
            descriptor = try driver.reader.inspect(ex.resource, ex.id);
        } else if (descriptor.phase == .ready or descriptor.phase == .capturing) {
            // An authorized predecessor may have sent. A fresh activation closes
            // uncertainty; it cannot repeat that request, even before first capture.
            try driver.apply(.{ .unknown = .{ .reason = .recovered_incomplete } });
            descriptor = try driver.reader.inspect(ex.resource, ex.id);
        }
        effect = try driver.effect();
        if (effect.phase == .authorized or effect.phase == .unknown) {
            if (descriptor.phase == .complete) {
                const reference: x.Client.Reference = .{ .resource = ex.resource, .exchange = ex.id, .chain = descriptor.chain };
                _ = try driver.command(.{ .observe = .{ .pid = config.pid, .effect = effect.id, .attempt = effect.attempt.?, .result = try (s.Frame{ .kind = .cast, .payload = try reference.encode() }).encode() } });
                try driver.drive();
            } else _ = try driver.command(.{ .close_effect = .{ .pid = config.pid, .effect = effect.id, .attempt = effect.attempt.?, .reason = .abandoned } });
        }
        effect = try driver.effect();
        if (effect.phase == .observed or effect.phase == .cancelled or effect.phase == .closed_unknown) {
            try driver.apply(.{ .settle = effect });
            try driver.apply(.publish);
        }
    }
    const descriptor = driver.reader.inspect(ex.resource, ex.id) catch |err| if (config.mode == .poll and err == error.ExchangeNotFound) null else return err;
    const effect = if (descriptor != null) driver.effect() catch |err| if (err == error.UnknownEffect) null else return err else null;
    var output_buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    const capture_failure = if (descriptor != null) try driver.reader.failure(ex.resource, ex.id) else null;
    var exchange_buffer: [20]u8 = undefined;
    const effect_diagnostic: ?p.Diagnostic = if (effect) |value| blk: {
        const observed = driver.reader.query(.{ .capabilities = {} }) catch break :blk null;
        break :blk p.EffectDiagnostic.from(config.realm, observed.position, value) catch null;
    } else null;
    try std.json.Stringify.value(.{
        .exchange = try std.fmt.bufPrint(&exchange_buffer, "{d}", .{ex.id}),
        .phase = if (descriptor) |value| @tagName(value.phase) else "not_admitted",
        .outcome = if (effect) |value| @tagName(value.phase) else "not_committed",
        .segments = if (descriptor) |value| value.segments else 0,
        .bytes = if (descriptor) |value| value.bytes else 0,
        .capture_diagnostic = if (capture_failure) |failure| failure.diagnostic(config.realm) catch null else null,
        .effect_diagnostic = effect_diagnostic,
    }, .{}, &output.interface);
    try output.interface.writeByte('\n');
    try output.interface.flush();
    const uncertain = if (effect) |value| value.phase == .closed_unknown or value.phase == .unknown else false;
    operation.finish(.{ .name = "http.worker.operation", .operation = @tagName(config.mode), .level = if (uncertain) .warn else .info, .outcome = if (uncertain) .uncertain else .ok, .realm = config.realm, .pid = config.pid, .generation = config.generation });
}

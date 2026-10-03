//! Finite RPC worker. Shared Exchange/Station own durable lifecycle and fencing;
//! only a fresh explicit dispatch may invoke the independent transport.
const std = @import("std");
const rpc = @import("transit_station_grpc");
const telemetry = @import("telemetry");
const x = rpc.exchange;
const s = x.station;
const p = x.p;
const g = p.Growth;
const Server = s.GenServer;
const capture_limits: x.Limits = .{ .segment_bytes = 8192, .capture_bytes = 393216, .segments = 256 };
const Credential = struct { binding: []const u8, version: u64, metadata: []const u8, file: []const u8 };
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
    endpoint: rpc.transport.Endpoint,
    mode: enum { prepare, accept, execute, release, poll },
    admission: ?struct { caller: u64, resource: u64, scope: rpc.Service.Scope } = null,
    cleanup_steps: u32 = 64,
    request_file: ?[]const u8 = null,
    batch_file: ?[]const u8 = null,
    reconcile_before_ms: ?u64 = null,
    credentials: []const Credential = &.{},
    response_metadata: []const []const u8 = &.{},
    max_attempts: u32 = 1,
    retry_policy: ?rpc.Policy.Retry = null,
    followup: ?rpc.Service.FollowupTarget = null,
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
    fn resolve(raw: *anyopaque, secret: rpc.Request.Secret) ![]const u8 {
        const self: *Secrets = @ptrCast(@alignCast(raw));
        for (self.config.credentials, 0..) |credential, index| if (credential.version == secret.version and std.mem.eql(u8, credential.binding, secret.binding)) {
            if (self.values[index] == null) self.values[index] = try std.Io.Dir.cwd().readFileAlloc(self.io, credential.file, self.gpa, .limited(4096));
            return self.values[index].?;
        };
        return error.GrpcCredentialNotGranted;
    }
};
const Input = struct {
    request: rpc.Request.Owned,
    metadata: []const u8,
    batch: []const u8,
    fn deinit(self: *Input) void {
        self.request.deinit();
    }
};
const Driver = struct {
    const Engine = x.Worker(@This(), rpc, .{ .tick = "grpc.tick.v1", .admission_missing = error.GrpcAdmissionNotConfigured, .followup_missing = error.GrpcFollowupNotGranted, .request_oversize = error.GrpcRequestTooLarge, .limits = capture_limits });
    server: Server,
    reader: x.Client,
    config: Config,
    io: std.Io,
    gpa: std.mem.Allocator,
    operation: Engine.Operation = .idle,
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
    fn validationFailure(failure: ?*?rpc.Service.Rejection, detail: rpc.Service.Rejection, err: anyerror) anyerror {
        if (err != error.OutOfMemory) if (failure) |slot| if (slot.* == null) {
            slot.* = detail;
        };
        return err;
    }
    fn prepared(self: *Driver, input: Input, credentials: *[16]rpc.Policy.Credential) !rpc.Policy.Prepared {
        return self.preparedDiagnostic(input, credentials, null);
    }
    fn preparedDiagnostic(self: *Driver, input: Input, credentials: *[16]rpc.Policy.Credential, failure: ?*?rpc.Service.Rejection) !rpc.Policy.Prepared {
        const config = self.config;
        if (config.credentials.len > credentials.len) return validationFailure(failure, rpc.Service.Rejection.detail(.denied, .maximum, "policy.credentials", .{ .unsigned = credentials.len }, .{ .unsigned = config.credentials.len }, error.GrpcCredentialCapacity), error.GrpcCredentialCapacity);
        for (config.credentials, 0..) |credential, index| {
            if (credential.file.len == 0) return validationFailure(failure, rpc.Service.Rejection.detail(.denied, .policy, "policy.credentials", .redacted, .redacted, error.InvalidGrpcCredential), error.InvalidGrpcCredential);
            credentials[index] = .{ .binding = credential.binding, .version = credential.version, .metadata = credential.metadata };
        }
        const request = input.request.request;
        const result: rpc.Policy.Prepared = .{ .endpoint_revision = config.endpoint_revision, .host = config.endpoint.host, .address = config.endpoint.address, .port = config.endpoint.port, .tls = config.endpoint.tls, .timeout_ms = config.endpoint.timeout_ms, .limits = config.endpoint.limits, .response_metadata = config.response_metadata, .credentials = credentials[0..config.credentials.len], .trust_digest = try trustDigest(self.gpa, self.io, config.endpoint), .method = request.method, .shape = request.shape, .descriptor_digest = request.descriptor_digest, .metadata_digest = (try x.Publication.Digest.of(2, input.metadata)).digest, .batch_digest = (try x.Publication.Digest.of(2, input.batch)).digest, .retry_policy = config.retry_policy };
        result.validateRequestDiagnostic(request, failure) catch |err| return validationFailure(failure, rpc.Service.Rejection.detail(.denied, .policy, "request.policy", .unrecorded, .unrecorded, err), err);
        _ = rpc.Batch.decode(input.batch, request.shape, config.endpoint.limits) catch |err| return validationFailure(failure, rpc.Service.Rejection.detail(.invalid_request, .decode, "request.batch", .unrecorded, .{ .unsigned = input.batch.len }, err), err);
        if (config.admission) |policy| try rpc.Service.validateRequestDiagnostic(policy.scope, request, failure);
        return result;
    }
    fn readRequest(self: *Driver, reference: rpc.RequestRecord.Reference, metadata: []u8, batch: []u8) !Input {
        return self.readRequestDiagnostic(reference, metadata, batch, null);
    }
    fn readRequestDiagnostic(self: *Driver, reference: rpc.RequestRecord.Reference, metadata: []u8, batch: []u8, failure: ?*?rpc.Service.Rejection) !Input {
        const policy = self.config.admission orelse return error.GrpcAdmissionNotConfigured;
        const resource = (try self.reader.query(.{ .resource = reference.resource })).body.resource;
        if (resource.writer != policy.caller) return validationFailure(failure, rpc.Service.Rejection.detail(.denied, .equal, "request.resource.writer", .{ .unsigned = policy.caller }, .redacted, error.GrpcAdmissionDenied), error.GrpcAdmissionDenied);
        const meta_bytes = try rpc.RequestRecord.read(&self.reader, reference, rpc.RequestRecord.metadata_id, metadata);
        const batch_bytes = try rpc.RequestRecord.read(&self.reader, reference, rpc.RequestRecord.batch_id, batch);
        const request = rpc.RequestRecord.validateContentDiagnostic(self.gpa, reference, meta_bytes, batch_bytes, failure) catch |err| return validationFailure(failure, rpc.Service.Rejection.detail(.invalid_request, .decode, "request.content", .unrecorded, .unrecorded, err), err);
        return .{ .request = request, .metadata = meta_bytes, .batch = batch_bytes };
    }
    fn policyOrdinal(self: *Driver, ex: x.Exchange) !u32 {
        var source = try self.reader.reader(ex.resource);
        const descriptor = try ex.inspect(&source);
        if (descriptor.segments < 3 or descriptor.segments > capture_limits.segments) return error.InvalidGrpcCapture;
        if ((try ex.member(&source, 0)).kind != @backingInt(rpc.Kind.request_metadata)) return error.InvalidGrpcCapture;
        for (1..descriptor.segments) |ordinal| {
            const kind = (try ex.member(&source, @intCast(ordinal))).kind;
            if (kind == @backingInt(rpc.Kind.endpoint_policy)) return @intCast(ordinal);
            if (kind != @backingInt(rpc.Kind.request_batch)) return error.InvalidGrpcCapture;
        }
        return error.GrpcReplayGap;
    }
    fn validateFollowup(self: *Driver, prepared_value: rpc.Policy.Prepared, request: rpc.Request) !?rpc.Policy.Reference {
        return self.validateFollowupDiagnostic(prepared_value, request, null);
    }
    fn validateFollowupDiagnostic(self: *Driver, prepared_value: rpc.Policy.Prepared, request: rpc.Request, failure: ?*?rpc.Service.Rejection) !?rpc.Policy.Reference {
        const follow = self.config.followup orelse return null;
        const ex = try self.exchange();
        const parent: x.Exchange = .{ .resource = ex.resource, .id = follow.parent };
        const descriptor = try self.reader.inspect(parent.resource, parent.id);
        const parent_effect = try self.effectFor(parent);
        if (descriptor.phase != .unknown) return validationFailure(failure, rpc.Service.Rejection.detail(.denied, .state, "parent.phase", .{ .text = "unknown" }, .{ .text = @tagName(descriptor.phase) }, error.GrpcFollowupNotSettled), error.GrpcFollowupNotSettled);
        if (parent_effect.phase != .closed_unknown) return validationFailure(failure, rpc.Service.Rejection.detail(.denied, .state, "parent.effect.phase", .{ .text = "closed_unknown" }, .{ .text = @tagName(parent_effect.phase) }, error.GrpcFollowupNotSettled), error.GrpcFollowupNotSettled);
        const observed_clock = now(self.io);
        if (observed_clock >= descriptor.reconcile_before_ms) {
            if (failure) |slot| slot.* = rpc.Service.Rejection.detail(.denied, .before, "followup.clock_ms", .{ .unsigned = descriptor.reconcile_before_ms }, .{ .unsigned = observed_clock }, error.ExpiredReconciliation);
            return error.ExpiredReconciliation;
        }
        var buffer: [8192]u8 = undefined;
        var original = try rpc.Policy.parse(self.gpa, try self.loadFrom(parent, try self.policyOrdinal(parent), &buffer));
        defer original.deinit();
        return try rpc.Policy.followupDiagnostic(follow.reason, original.policy, prepared_value, request, failure);
    }
    pub fn validateAdmission(self: *Driver, follow: rpc.Service.Followup) !rpc.Service.FollowupValidation {
        var metadata: [8192]u8 = undefined;
        var batch: [rpc.Batch.maximum_bytes]u8 = undefined;
        var failure: ?rpc.Service.Rejection = null;
        var input = self.readRequestDiagnostic(try follow.reference(), &metadata, &batch, &failure) catch |err| {
            if (failure) |detail| return .{ .rejected = detail };
            return err;
        };
        defer input.deinit();
        var credentials: [16]rpc.Policy.Credential = undefined;
        const policy = self.preparedDiagnostic(input, &credentials, &failure) catch |err| {
            if (failure) |detail| return .{ .rejected = detail };
            return err;
        };
        const decision = self.validateFollowupDiagnostic(policy, input.request.request, &failure) catch |err| switch (err) {
            error.GrpcFollowupNotSettled, error.ExpiredReconciliation, error.GrpcFollowupNotGranted, error.InvalidGrpcIdempotencyKey, error.GrpcFollowupChanged, error.GrpcRequestNotGranted, error.GrpcRequestChanged, error.GrpcCredentialNotGranted => return .{ .rejected = failure orelse rpc.Service.Rejection.detail(.denied, .policy, "followup.policy", .unrecorded, .unrecorded, err) },
            else => return err,
        };
        return .{ .accepted = decision orelse return error.GrpcFollowupNotGranted };
    }
};
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
fn trustDigest(gpa: std.mem.Allocator, io: std.Io, endpoint: rpc.transport.Endpoint) !?[32]u8 {
    if (!endpoint.tls) return null;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, endpoint.ca_file orelse return error.GrpcExplicitTrustRequired, gpa, .limited(1048576));
    defer gpa.free(bytes);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return digest;
}
fn readFileBounded(io: std.Io, path: []const u8, buffer: []u8) ![]const u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var reader = file.reader(io, &.{});
    const len = try reader.interface.readSliceShort(buffer);
    var extra: [1]u8 = undefined;
    if (try reader.interface.readSliceShort(&extra) != 0) return error.GrpcRequestTooLarge;
    return buffer[0..len];
}
fn prepare(driver: *Driver) !void {
    const config = driver.config;
    const ex = try driver.exchange();
    var metadata_buffer: [8192]u8 = undefined;
    var batch_buffer: [rpc.Batch.maximum_bytes]u8 = undefined;
    var reference: ?rpc.RequestRecord.Reference = null;
    var input: Input = undefined;
    if (config.mode == .accept) {
        var source = try driver.reader.reader(ex.resource);
        const route = (try rpc.Service.route(ex, &source)) orelse return error.MissingGrpcCall;
        if (!rpc.Service.allowed(route, try driver.admission())) return error.GrpcAdmissionDenied;
        reference = try route.reference();
        input = try driver.readRequest(reference.?, &metadata_buffer, &batch_buffer);
    } else {
        const metadata = try readFileBounded(driver.io, config.request_file orelse return error.MissingGrpcRequest, &metadata_buffer);
        const batch = try readFileBounded(driver.io, config.batch_file orelse return error.MissingGrpcBatch, &batch_buffer);
        input = .{ .request = try rpc.Request.parse(driver.gpa, metadata), .metadata = metadata, .batch = batch };
    }
    defer input.deinit();
    var credentials: [16]rpc.Policy.Credential = undefined;
    const prepared = try driver.prepared(input, &credentials);
    var policy_buffer: [8192]u8 = undefined;
    const policy_bytes = try prepared.encode(&policy_buffer);
    const prior = driver.reader.inspect(ex.resource, ex.id) catch |err| if (err == error.ExchangeNotFound) null else return err;
    if (prior) |descriptor| if (descriptor.phase != .preparing) return;
    const deadline = if (prior) |descriptor| descriptor.reconcile_before_ms else config.reconcile_before_ms orelse return error.MissingReconciliationDeadline;
    if (reference) |ref| if (deadline != ref.reconcile_before_ms) return error.GrpcRequestChanged;
    const followup = try driver.validateFollowup(prepared, input.request.request);
    try driver.apply(.{ .create = .{ .deadline = deadline, .limits = capture_limits, .policy = followup } });
    if (config.followup == null) try driver.apply(.{ .attempts = if (reference) |ref| ref.max_attempts else config.max_attempts });
    try driver.stageAt(0, .request_metadata, input.metadata);
    var offset: usize = 0;
    var ordinal: u32 = 1;
    while (offset < input.batch.len) {
        const len = @min(4096, input.batch.len - offset);
        try driver.stageAt(ordinal, .request_batch, input.batch[offset..][0..len]);
        ordinal += 1;
        offset += len;
    }
    try driver.stageAt(ordinal, .endpoint_policy, policy_bytes);
    try driver.apply(.intent);
}
fn perform(driver: *Driver, input: Input, descriptor: x.Descriptor) !rpc.Capture.Completion {
    var endpoint = driver.config.endpoint;
    const remaining = descriptor.reconcile_before_ms -| now(driver.io);
    if (remaining == 0) return error.ExpiredReconciliation;
    endpoint.timeout_ms = @intCast(@min(endpoint.timeout_ms, remaining));
    const batch = try rpc.Batch.decode(input.batch, input.request.request.shape, endpoint.limits);
    var secrets: Secrets = .{ .gpa = driver.gpa, .io = driver.io, .config = driver.config };
    defer secrets.deinit();
    var fields: [64]rpc.transport.Entry = undefined;
    const request = try input.request.request.render(batch.messages(), &fields, .{ .context = &secrets, .resolve = Secrets.resolve }, endpoint.limits);
    var secret_count: u32 = 0;
    for (input.request.request.metadata) |field| if (field.value == .secret) {
        secret_count += 1;
    };
    var capture: rpc.Capture = .{ .sink = .{ .context = driver, .append = Driver.capture }, .planned = .{ .messages = @intCast(batch.count), .wire_bytes = batch.wire_bytes }, .allowlist = driver.config.response_metadata, .request_secrets = secret_count };
    const start = std.Io.Clock.awake.now(driver.io);
    const started_ms = now(driver.io);
    const response = try rpc.transport.execute(driver.gpa, driver.io, endpoint, request, .{ .context = &capture, .emit = rpc.Capture.emit });
    return capture.finish(response, .{ .started_ms = started_ms, .elapsed_ns = @intCast(start.durationTo(std.Io.Clock.awake.now(driver.io)).toNanoseconds()) });
}
fn execute(driver: *Driver, diagnostics: *telemetry.Runtime, parent: ?telemetry.Context) !void {
    const config = driver.config;
    const ex = try driver.exchange();
    var source = try driver.reader.reader(ex.resource);
    if (try rpc.Service.route(ex, &source)) |route| if (!rpc.Service.allowed(route, try driver.admission())) return error.GrpcAdmissionDenied;
    var effect = try driver.effect();
    var descriptor = try driver.reader.inspect(ex.resource, ex.id);
    if (descriptor.phase == .ready and effect.phase == .pending) {
        var metadata_buffer: [8192]u8 = undefined;
        var batch_buffer: [rpc.Batch.maximum_bytes]u8 = undefined;
        var policy_buffer: [8192]u8 = undefined;
        const ordinal = try driver.policyOrdinal(ex);
        if (ordinal + 1 != descriptor.segments) return error.InvalidGrpcCapture;
        const metadata = try driver.load(0, &metadata_buffer);
        var count: usize = 0;
        for (1..ordinal) |index| {
            const bytes = try driver.load(@intCast(index), batch_buffer[count..]);
            if (bytes.len == 0 or bytes.len > 4096) return error.InvalidGrpcCapture;
            count += bytes.len;
        }
        var input: Input = .{ .request = try rpc.Request.parse(driver.gpa, metadata), .metadata = metadata, .batch = batch_buffer[0..count] };
        defer input.deinit();
        const frozen = try driver.load(ordinal, &policy_buffer);
        var current_buffer: [8192]u8 = undefined;
        var credentials: [16]rpc.Policy.Credential = undefined;
        const current = try driver.prepared(input, &credentials);
        if (!std.mem.eql(u8, frozen, try current.encode(&current_buffer))) return error.GrpcEndpointChanged;
        const receipt = try driver.command(.{ .dispatch = .{ .pid = config.pid, .effect = effect.id, .reconcile_before_ms = descriptor.reconcile_before_ms, .max_observations = 1 } });
        effect = try driver.effect();
        if (effect.attempt != receipt.position or effect.executor != config.principal) return error.InvalidExchangeAttempt;
        try driver.apply(.{ .bind = effect });
        var span = diagnostics.begin(.application, parent);
        if (perform(driver, input, descriptor)) |completion| {
            span.finish(.{ .name = "grpc.transport.completed", .operation = "execute", .status = @intCast(completion.status), .realm = config.realm, .pid = config.pid, .generation = config.generation, .position = receipt.position });
            try driver.apply(.{ .finish = try completion.terminalCode() });
        } else |err| {
            span.finish(.{ .name = "grpc.transport.completed", .operation = "execute", .level = .warn, .outcome = .uncertain, .error_type = @errorName(err), .realm = config.realm, .pid = config.pid, .generation = config.generation, .position = receipt.position });
            try driver.apply(.{ .unknown = driver.capture_failure orelse x.Failure.failed(.transport_failure, err) });
        }
        descriptor = try driver.reader.inspect(ex.resource, ex.id);
    } else if (descriptor.phase == .ready or descriptor.phase == .capturing) {
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
pub fn main(init: std.process.Init) !void {
    var diagnostics = telemetry.Runtime.init(init.io, "transit-station-grpc-worker", try telemetry.Config.environment(init.environ_map));
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
    errdefer operation.finish(.{ .name = "grpc.worker.operation", .operation = @tagName(config.mode), .level = .err, .outcome = .failed, .realm = config.realm, .pid = config.pid, .generation = config.generation });
    wire.parent_context = operation.context;
    defer wire.parent_context = null;
    // Dispose self-ticks left before an interrupted commit without reconstructing
    // lost network bytes. Capture state remains authoritative and incomplete.
    for (0..64) |_| {
        if (try driver.server.session.receive() == null) break;
        try driver.drive();
    } else return error.WorkerMailboxBusy;
    if (config.mode == .prepare or config.mode == .accept) {
        try prepare(&driver);
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
        try execute(&driver, diagnostics, operation.context);
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
    operation.finish(.{ .name = "grpc.worker.operation", .operation = @tagName(config.mode), .level = if (uncertain) .warn else .info, .outcome = if (uncertain) .uncertain else .ok, .realm = config.realm, .pid = config.pid, .generation = config.generation });
}

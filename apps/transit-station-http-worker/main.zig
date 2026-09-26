//! Finite, explicitly activated HTTP worker. Caller preparation, dispatch and
//! capture use the public client; no provider or raw journal access exists here.
const std = @import("std");
const http = @import("transit_station_http");
const x = http.exchange;
const s = x.station;
const p = s.protocol;
const g = p.Growth;
const Server = s.GrowingGenServer;
const Turn = s.GrowingTurn;
const Credential = struct { binding: []const u8, version: u64, header: []const u8, file: []const u8 };
const RetryPolicy = struct { id: u64, revision: u64, key_header: []const u8 };
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
    mode: enum { prepare, execute, release },
    cleanup_steps: u32 = 64,
    request: ?http.Request = null,
    body_file: ?[]const u8 = null,
    reconcile_before_ms: ?u64 = null,
    credentials: []const Credential = &.{},
    max_attempts: u32 = 1,
    retry_policy: ?RetryPolicy = null,
    retry_parent: ?u64 = null,
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
const Prepared = struct { version: u32 = 1, endpoint_revision: u64, host: []const u8, address: []const u8, port: u16, tls: bool, timeout_ms: u32, request_bytes: u64, response_bytes: u64, response_headers: []const []const u8, trust_digest: ?[32]u8, retry_policy: ?RetryPolicy = null, request: http.Request };
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
const Operation = union(enum) {
    idle,
    create: struct { deadline: u64, limits: x.Limits },
    begin: struct { ordinal: u32, kind: http.Kind, spec: x.Publication.Spec },
    append: struct { ordinal: u32, chunk: u32, bytes: p.Value },
    seal: u32,
    intent,
    attempts: u32,
    bind: g.Effect,
    settle: g.Effect,
    release_caller: u64,
    retire,
    collect,
    finish: u32,
    unknown,
};
const Driver = struct {
    server: Server,
    reader: x.Client,
    config: Config,
    io: std.Io,
    operation: Operation = .idle,
    fn exchange(self: *Driver) !x.Exchange {
        const association = (try self.server.session.association(try p.Value.init(self.config.association))) orelse return error.MissingStateAssociation;
        return .{ .resource = association.resource, .id = self.config.exchange };
    }
    fn command(self: *Driver, command_value: g.Command) !p.Receipt {
        const sequence = (try self.reader.query(.{ .capabilities = {} })).principal_sequence + 1;
        const signed = try g.sign(.{ .realm = self.config.realm, .principal = self.config.principal, .sequence = sequence, .command = command_value }, self.reader.key);
        // Retry only identical Transit bytes. Returning uncertainty terminates
        // this activation; a new OS worker must obtain fresh fenced ownership.
        for (0..3) |_| {
            return self.reader.wire.submitGrowing(signed) catch |err| {
                if (err == error.Rejected or err == error.Conflict or err == error.AccessDenied) return err;
                continue;
            };
        }
        return error.AuthorityOutcomeUnknown;
    }
    fn handle(raw: ?*anyopaque, turn: *Turn, frame: s.Frame) !void {
        const self: *Driver = @ptrCast(@alignCast(raw.?));
        const ex: x.Exchange = .{ .resource = turn.view.resource, .id = self.config.exchange };
        // This first worker owns a private control mailbox. Application ingress
        // is a separately scoped service obligation, not arbitrary callback data.
        switch (turn.delivery.input.origin) {
            .external => |origin| if (origin.principal != self.config.principal or frame.kind != .cast or !std.mem.eql(u8, frame.payload.slice(), "http.tick.v1")) return error.UnexpectedWorkerInput,
            .effect => |origin| {
                const descriptor = try ex.inspect(turn);
                if (origin.id != descriptor.effect or origin.attempt != descriptor.attempt or origin.executor != descriptor.executor) return error.InvalidExchangeAttempt;
                if (frame.kind != .cast) return error.UnexpectedWorkerInput;
                const reference = try x.Client.Reference.decode(frame.payload);
                if (!std.meta.eql(reference, try ex.reference(turn))) return error.InvalidExchangeCoverage;
                return;
            },
            .process => return error.UnexpectedWorkerInput,
        }
        switch (self.operation) {
            .idle => {},
            .create => |c| {
                if (self.config.retry_parent) |parent_id| {
                    const parent: x.Exchange = .{ .resource = turn.view.resource, .id = parent_id };
                    const policy = self.config.retry_policy orelse return error.HttpRetryNotGranted;
                    _ = try parent.followup(turn, ex.id, .retry, policy.id, policy.revision, c.limits);
                } else _ = try x.Exchange.create(turn, ex.id, .{ .caller = turn.delivery.pid, .input = turn.delivery.input.position, .protocol = http.protocol_format }, c.limits, c.deadline);
            },
            .begin => |b| {
                _ = try ex.beginSegment(turn, b.ordinal, @backingInt(b.kind), b.spec);
            },
            .append => |a| {
                _ = try ex.append(turn, a.ordinal, a.chunk, a.bytes.slice());
            },
            .seal => |ordinal| {
                _ = try ex.sealSegment(turn, ordinal);
            },
            .intent => {
                _ = try ex.commitIntent(turn);
            },
            .attempts => |limit| try ex.configureAttempts(turn, limit),
            .bind => |authorized| {
                _ = try ex.bind(turn, authorized);
            },
            .settle => |terminal| {
                _ = try ex.settle(turn, terminal);
            },
            .release_caller => |caller| {
                _ = try ex.releaseCaller(turn, caller);
            },
            .retire => {
                _ = try ex.retire(turn);
            },
            .collect => {
                _ = try ex.collect(turn);
            },
            .finish => |code| {
                _ = try ex.finish(turn, code);
            },
            .unknown => {
                _ = try ex.closeUnknown(turn);
            },
        }
    }
    fn drive(self: *Driver) !void {
        const handler: Server.Handler = .{ .context = self, .handle = handle };
        for (0..32) |_| {
            const result = self.server.step(handler, now(self.io) + 30000) catch |err| {
                if (err == error.Rejected or err == error.Conflict or err == error.AccessDenied or self.server.pending == null) return err;
                continue;
            };
            switch (result) {
                .committed, .idle => return,
                .progress => {},
                .blocked => return self.server.handler_error orelse error.BehaviorBlocked,
            }
        }
        return error.AuthorityOutcomeUnknown;
    }
    fn apply(self: *Driver, operation: Operation) !void {
        if (try self.server.session.receive() != null) return error.WorkerMailboxBusy;
        self.operation = operation;
        defer self.operation = .idle;
        _ = try self.command(.{ .send = .{ .pid = self.config.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("http.tick.v1") }).encode() } });
        try self.drive();
    }
    fn stage(self: *Driver, kind: http.Kind, bytes: []const u8) !void {
        const ex = try self.exchange();
        const ordinal = (try self.reader.inspect(ex.resource, ex.id)).segments;
        const spec = try x.Publication.Digest.of(http.protocol_format, bytes);
        try self.apply(.{ .begin = .{ .ordinal = ordinal, .kind = kind, .spec = spec } });
        for (0..spec.chunks()) |i| try self.apply(.{ .append = .{ .ordinal = ordinal, .chunk = @intCast(i), .bytes = try p.Value.init(bytes[i * 256 ..][0..try spec.size(@intCast(i))]) } });
        try self.apply(.{ .seal = ordinal });
    }
    fn capture(raw: *anyopaque, kind: http.Kind, bytes: []const u8) !void {
        const self: *Driver = @ptrCast(@alignCast(raw));
        try self.stage(kind, bytes);
    }
    fn effect(self: *Driver) !g.Effect {
        const ex = try self.exchange();
        var after: ?u64 = null;
        var position: ?u64 = null;
        while (true) {
            const page = try self.reader.query(.{ .effects = .{ .pid = self.config.pid, .after = after, .position = position } });
            for (page.body.effects.entries) |slot| if (slot) |effect_value| {
                const intent = x.Intent.decode(effect_value.payload) catch continue;
                if (intent.resource == ex.resource and intent.exchange == ex.id) return effect_value;
            };
            after = page.body.effects.next;
            if (after == null) return error.UnknownEffect;
            position = page.position;
        }
    }
    fn load(self: *Driver, ordinal: u32, buffer: []u8) ![]const u8 {
        return self.loadFrom(try self.exchange(), ordinal, buffer);
    }
    fn loadFrom(self: *Driver, ex: x.Exchange, ordinal: u32, buffer: []u8) ![]const u8 {
        var source = try self.reader.reader(ex.resource);
        const member = try ex.member(&source, ordinal);
        if (member.length > buffer.len) return error.HttpRequestTooLarge;
        var cursor = try ex.publication().open(&source, @as(u64, ordinal) + 1);
        if (!std.meta.eql(cursor.spec, member.spec())) return error.InvalidExchangeCoverage;
        var count: usize = 0;
        while (true) {
            const part = try ex.publication().read(&source, cursor);
            @memcpy(buffer[count..][0..part.bytes.len], part.bytes.slice());
            count += part.bytes.len;
            cursor = part.next orelse break;
        }
        return buffer[0..count];
    }
    fn validateRetry(self: *Driver, metadata: []const u8, body: []const u8, request: http.Request) !void {
        const parent_id = self.config.retry_parent orelse return;
        const policy = self.config.retry_policy orelse return error.HttpRetryNotGranted;
        if (policy.id == 0 or policy.revision == 0) return error.HttpRetryNotGranted;
        const key = for (request.headers) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, policy.key_header)) break header;
        } else return error.MissingHttpIdempotencyKey;
        var keys: usize = 0;
        for (request.headers) |header| if (std.ascii.eqlIgnoreCase(header.name, policy.key_header)) {
            keys += 1;
        };
        if (keys != 1) return error.InvalidHttpIdempotencyKey;
        if (key.value.len != 1 or key.value[0] != .literal or key.value[0].literal.len == 0 or key.value[0].literal.len > 128) return error.InvalidHttpIdempotencyKey;
        const ex = try self.exchange();
        const parent: x.Exchange = .{ .resource = ex.resource, .id = parent_id };
        const descriptor = try self.reader.inspect(parent.resource, parent.id);
        if (descriptor.phase != .unknown) return error.HttpRetryNotUnknown;
        var previous: [8192]u8 = undefined;
        // Exact canonical metadata preserves endpoint, method, credential
        // versions, idempotency key and original policy. A retry is not a way
        // to silently change the remote operation or forward credentials.
        if (!std.mem.eql(u8, try self.loadFrom(parent, 0, &previous), metadata)) return error.HttpRetryChanged;
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
        if (now(self.io) >= descriptor.reconcile_before_ms) return error.ExpiredReconciliation;
    }
};
fn now(io: std.Io) u64 {
    return @intCast(std.Io.Clock.real.now(io).toMilliseconds());
}
pub fn main(init: std.process.Init) !void {
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
    var driver: Driver = .{ .server = try Server.init(.{ .client = &wire, .realm = config.realm, .principal = config.principal, .pid = config.pid, .generation = config.generation, .key = key }, config.association), .reader = .{ .wire = &wire, .realm = config.realm, .principal = config.principal, .key = key }, .config = config, .io = init.io };
    _ = try driver.server.session.receive();
    const marker = try std.fmt.allocPrint(init.gpa, "{s}/{d}-{d}-{d}.activation", .{ config.activation_directory, config.realm, config.pid, config.generation });
    defer init.gpa.free(marker);
    const file = try std.Io.Dir.cwd().createFile(init.io, marker, .{ .exclusive = true });
    file.close(init.io);
    // Dispose self-ticks left before an interrupted commit without reconstructing
    // lost network bytes. Capture state remains authoritative and incomplete.
    for (0..64) |_| {
        if (try driver.server.session.receive() == null) break;
        try driver.drive();
    } else return error.WorkerMailboxBusy;
    const ex = try driver.exchange();
    if (config.mode == .prepare) {
        const request = config.request orelse return error.MissingHttpRequest;
        if (request.body_bytes > 65536 or request.body_bytes > config.endpoint.request_bytes) return error.HttpRequestTooLarge;
        try Secrets.validate(config, request);
        const deadline = config.reconcile_before_ms orelse return error.MissingReconciliationDeadline;
        if (deadline <= now(init.io)) return error.ExpiredReconciliation;
        var header: [http.Request.maximum_head_bytes]u8 = undefined;
        const rendered = try request.render(config.endpoint.host, config.endpoint.port, &header, null, false);
        // Prepare metadata before creating any durable obligation.
        const metadata = try std.json.Stringify.valueAlloc(init.gpa, Prepared{ .endpoint_revision = config.endpoint_revision, .host = config.endpoint.host, .address = config.endpoint.address, .port = config.endpoint.port, .tls = config.endpoint.tls, .timeout_ms = config.endpoint.timeout_ms, .request_bytes = config.endpoint.request_bytes, .response_bytes = config.endpoint.response_bytes, .response_headers = config.endpoint.response_headers, .trust_digest = try trustDigest(init.gpa, init.io, config.endpoint), .retry_policy = config.retry_policy, .request = request }, .{});
        defer init.gpa.free(metadata);
        if (metadata.len > 8192) return error.HttpRequestTooLarge;
        const body = if (config.body_file) |path| try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536)) else try init.gpa.dupe(u8, "");
        defer init.gpa.free(body);
        if (body.len != request.body_bytes) return error.InvalidHttpBodyLength;
        try driver.validateRetry(metadata, body, request);
        try driver.apply(.{ .create = .{ .deadline = deadline, .limits = .{ .segment_bytes = 8192, .capture_bytes = 262144, .segments = 256 } } });
        if (config.retry_parent == null) try driver.apply(.{ .attempts = config.max_attempts });
        try driver.stage(.request_template, metadata);
        try driver.stage(.request_head, rendered);
        var offset: usize = 0;
        while (offset < body.len) {
            const end = offset + @min(http.Transport.segment_bytes, body.len - offset);
            try driver.stage(.request_body, body[offset..end]);
            offset = end;
        }
        if (body.len == 0) try driver.stage(.request_body, "");
        try driver.apply(.intent);
    } else if (config.mode == .release) {
        // Explicit trusted-controller disposal, never inferred from elapsed
        // time, quota pressure, observation acceptance or caller termination.
        try driver.apply(.{ .release_caller = (try driver.reader.inspect(ex.resource, ex.id)).caller });
        try driver.apply(.retire);
        for (0..config.cleanup_steps) |_| {
            const current = try driver.reader.inspect(ex.resource, ex.id);
            if (current.collected == @as(u64, current.segments) + @intFromBool(current.pending_kind != 0)) break;
            try driver.apply(.collect);
        }
    } else {
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
            const result = if (remaining == 0) @as(anyerror!http.Transport.Result, error.ExpiredReconciliation) else http.Transport.execute(init.gpa, init.io, endpoint, prepared.request, &body, .{ .context = &secrets, .resolve = Secrets.resolve }, .{ .context = &driver, .segment = Driver.capture });
            if (result) |response| try driver.apply(.{ .finish = response.status }) else |_| try driver.apply(.unknown);
            descriptor = try driver.reader.inspect(ex.resource, ex.id);
        } else if (descriptor.phase == .ready or descriptor.phase == .capturing) {
            // An authorized predecessor may have sent. A fresh activation closes
            // uncertainty; it cannot repeat that request, even before first capture.
            try driver.apply(.unknown);
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
        if (effect.phase == .observed or effect.phase == .cancelled or effect.phase == .closed_unknown) try driver.apply(.{ .settle = effect });
    }
    const descriptor = try driver.reader.inspect(ex.resource, ex.id);
    var output_buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    try output.interface.print("{{\"exchange\":\"{d}\",\"phase\":\"{s}\",\"segments\":{d},\"bytes\":{d}}}\n", .{ ex.id, @tagName(descriptor.phase), descriptor.segments, descriptor.bytes });
    try output.interface.flush();
}

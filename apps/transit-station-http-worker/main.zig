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
    mode: enum { prepare, accept, execute, release },
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
    followup: ?struct { parent: u64, reason: http.Policy.Reason } = null,
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
const Operation = union(enum) {
    idle,
    create: struct { deadline: u64, limits: x.Limits, policy: ?http.Policy.Reference = null },
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
    publish,
    finish: u32,
    unknown,
};
const Driver = struct {
    server: Server,
    reader: x.Client,
    config: Config,
    io: std.Io,
    operation: Operation = .idle,
    fn admission(self: *Driver) !http.Service.Admission {
        const policy = self.config.admission orelse return error.HttpAdmissionNotConfigured;
        return .{ .caller = policy.caller, .resource = policy.resource, .endpoint_revision = self.config.endpoint_revision, .reconcile_before_ms = self.config.reconcile_before_ms orelse return error.MissingReconciliationDeadline, .max_attempts = self.config.max_attempts };
    }
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
            .process => {
                _ = try http.Service.admit(turn, ex.id, try self.admission(), .{ .segment_bytes = 8192, .capture_bytes = 262144, .segments = 256 });
                return;
            },
        }
        switch (self.operation) {
            .idle => {},
            .create => |c| {
                if (self.config.followup) |follow| {
                    const parent: x.Exchange = .{ .resource = turn.view.resource, .id = follow.parent };
                    const policy = c.policy orelse return error.HttpFollowupNotGranted;
                    _ = try parent.followup(turn, ex.id, follow.reason, policy.id, policy.revision, c.limits);
                } else {
                    const prior = if (try turn.read(x.Exchange.key(ex.id, 'd', 0))) |value| try x.Descriptor.decode(value) else null;
                    _ = try x.Exchange.create(turn, ex.id, .{ .caller = if (prior) |d| d.caller else turn.delivery.pid, .input = if (prior) |d| d.input else turn.delivery.input.position, .protocol = http.protocol_format }, c.limits, c.deadline);
                }
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
            .publish => {
                _ = try http.Service.publish(turn, ex);
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
        return self.driveUntil(null);
    }
    fn driveUntil(self: *Driver, input: ?u64) !void {
        const handler: Server.Handler = .{ .context = self, .handle = handle };
        for (0..32) |_| {
            const result = self.server.step(handler, now(self.io) + 30000) catch |err| {
                if (err == error.Rejected or err == error.Conflict or err == error.AccessDenied or self.server.pending == null) return err;
                continue;
            };
            switch (result) {
                .committed => {
                    if (input == null) return;
                    if (self.server.confirmation) |confirmed| if (confirmed.kind == .commit and confirmed.input == input.?) return;
                },
                .idle => return if (input == null) {} else error.WorkerMailboxBusy,
                .progress => {},
                .blocked => return self.server.handler_error orelse error.BehaviorBlocked,
            }
        }
        return error.AuthorityOutcomeUnknown;
    }
    fn apply(self: *Driver, operation: Operation) !void {
        if (self.server.pending != null) return error.AuthorityOutcomeUnknown;
        self.operation = operation;
        defer self.operation = .idle;
        const sent = try self.command(.{ .send = .{ .pid = self.config.pid, .value = try (s.Frame{ .kind = .cast, .payload = try p.Value.init("http.tick.v1") }).encode() } });
        try self.driveUntil(sent.position);
    }
    fn stage(self: *Driver, kind: http.Kind, bytes: []const u8) !void {
        const ex = try self.exchange();
        const ordinal = (try self.reader.inspect(ex.resource, ex.id)).segments;
        return self.stageAt(ordinal, kind, bytes);
    }
    fn stageAt(self: *Driver, ordinal: u32, kind: http.Kind, bytes: []const u8) !void {
        const ex = try self.exchange();
        const spec = try x.Publication.Digest.of(http.protocol_format, bytes);
        var source = try self.reader.reader(ex.resource);
        if (ordinal < (try ex.inspect(&source)).segments) {
            const member = try ex.member(&source, ordinal);
            if (member.kind != @backingInt(kind) or !std.meta.eql(member.spec(), spec)) return error.ExchangeIdentityConflict;
            return;
        }
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
        return self.effectFor(ex);
    }
    fn effectFor(self: *Driver, ex: x.Exchange) !g.Effect {
        const source = try self.reader.reader(ex.resource);
        const page = try self.reader.query(.{ .entries = .{ .resource = ex.resource, .revision = source.view.revision, .key = x.Exchange.key(ex.id, 'i', 0) } });
        const record = page.body.entries.page.entries[0] orelse return error.UnknownEffect;
        // Growing v3 gives entries and the same-turn effect their publication
        // position. The immutable intent is therefore a durable exact lookup
        // anchor, avoiding a scan through all of this PID's earlier effects.
        if (record.revision == 0) return error.InvalidExchangeAttempt;
        const effect_value = (try self.reader.query(.{ .effects = .{ .pid = self.config.pid, .after = record.revision - 1, .position = page.position } })).body.effects.entries[0] orelse return error.UnknownEffect;
        if (effect_value.id != record.revision or !effect_value.payload.eql(record.value)) return error.InvalidExchangeAttempt;
        const intent = try x.Intent.decode(effect_value.payload);
        if (intent.resource != ex.resource or intent.exchange != ex.id) return error.InvalidExchangeAttempt;
        return effect_value;
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
    fn validateFollowup(self: *Driver, gpa: std.mem.Allocator, prepared: Prepared, body: []const u8) !?http.Policy.Reference {
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
        const policy = try http.Policy.followup(gpa, follow.reason, parsed.value, prepared, if (follow.reason == .redirect) @intCast(descriptor.terminal_code) else null, location);
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
    const ex = try driver.exchange();
    const capture_resource = (try driver.reader.query(.{ .resource = ex.resource })).body.resource;
    if (capture_resource.owner != null or capture_resource.deadline_ms != null) return error.IncompatibleExchangeLifetime;
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
        const prepared: Prepared = .{ .endpoint_revision = config.endpoint_revision, .host = config.endpoint.host, .address = config.endpoint.address, .port = config.endpoint.port, .tls = config.endpoint.tls, .timeout_ms = config.endpoint.timeout_ms, .request_bytes = config.endpoint.request_bytes, .response_bytes = config.endpoint.response_bytes, .response_headers = config.endpoint.response_headers, .trust_digest = try trustDigest(init.gpa, init.io, config.endpoint), .retry_policy = config.retry_policy, .redirect_policy = config.redirect_policy, .reconcile_policy = config.reconcile_policy, .cancel_policy = config.cancel_policy, .request = request };
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
            try driver.apply(.unknown);
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
    } else {
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
        if (effect.phase == .observed or effect.phase == .cancelled or effect.phase == .closed_unknown) {
            try driver.apply(.{ .settle = effect });
            try driver.apply(.publish);
        }
    }
    const descriptor = try driver.reader.inspect(ex.resource, ex.id);
    const effect = driver.effect() catch |err| if (err == error.UnknownEffect) null else return err;
    var output_buffer: [1024]u8 = undefined;
    var output = std.Io.File.stdout().writerStreaming(init.io, &output_buffer);
    try output.interface.print("{{\"exchange\":\"{d}\",\"phase\":\"{s}\",\"outcome\":\"{s}\",\"segments\":{d},\"bytes\":{d}}}\n", .{ ex.id, @tagName(descriptor.phase), if (effect) |value| @tagName(value.phase) else "not_committed", descriptor.segments, descriptor.bytes });
    try output.interface.flush();
}

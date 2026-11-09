//! Physical execution of one original application HTTP effect. The task pool
//! owns admission; native progress owns dispatch identity and terminal outcome.
const std = @import("std");
const q = @import("transit_query_direct");
const c = q.catalog;
const p = q.protocol;
const X = q.ApplicationExecution;
const E = q.ApplicationEffect;
const Http = @import("ApplicationEffectHttp.zig");
const Tasks = @import("ApplicationEffectTasks.zig");
const Requests = @import("ApplicationRequestHost.zig");
const R = @import("ApplicationReservation.zig");
const Secrets = @import("ApplicationSecrets.zig");
const Transport = @import("transit_station_http").Transport;
const Memory = @import("transit_memory");
const Self = @This();

/// A deployment opens task-private native clients in the task's bounded
/// allocator. Its current configuration must admit the exact original caller.
pub const Clients = struct {
    context: *anyopaque,
    open: *const fn (*anyopaque, std.mem.Allocator, std.Io, c.DirectTableProtocol.Connection) anyerror!Client,
};
pub const Client = struct {
    value: c.DirectTableClient,
    context: *anyopaque,
    close: *const fn (*anyopaque) void,
    pub fn deinit(self: *Client) void {
        self.close(self.context);
        std.crypto.secureZero(u8, std.mem.asBytes(self));
    }
};
/// Exact declared connection plus deployment-owned numeric address/TLS trust.
/// Neither placement nor this private factory creates catalog permissions.
pub const Placement = struct {
    connection: p.DataLifecycle.Definition,
    endpoint: Transport.Endpoint,
    pub fn validate(self: Placement, declared: []const u8) !void {
        try self.connection.validate();
        try self.endpoint.validate();
        try p.Source.validateEndpoint(declared);
        const uri = try std.Uri.parse(declared);
        const secure = std.mem.eql(u8, uri.scheme, "https");
        if (secure != self.endpoint.tls or (uri.port orelse @as(u16, if (secure) 443 else 80)) != self.endpoint.port or
            !std.mem.eql(u8, uri.host.?.percent_encoded, self.endpoint.host)) return error.InvalidHttpEndpoint;
    }
};
requests: *Requests,
clients: Clients,
placements: []const Placement,
/// Part of each task's existing scratch reserve, never additional backing.
/// Native replies have independent lifetimes and must reuse freed buffers.
native_bytes: usize,

pub fn executor(self: *Self) Tasks.Executor {
    return .{ .context = self, .run = run };
}
/// Stable deployment composition. The pool and this I/O runtime outlive every
/// scheduled task; the request factory supplies a fresh borrow per evaluation.
pub const Host = struct {
    runtime: *Self,
    pool: *Tasks,
    io: std.Io,
    pub fn host(self: *Host) X.Host {
        return .{ .context = self, .ready = ready, .bind = bind, .effects = .{ .context = self, .poll = poll, .status = status, .join = join, .release = release, .response = adopt } };
    }
    fn ready(context: *anyopaque, allocator: std.mem.Allocator, declaration: q.ManagedApplication.Declaration) !void {
        const self: *Host = @ptrCast(@alignCast(context));
        var facilities = Requests.available();
        facilities.features.insert(.effects);
        facilities.features.insert(.deadline);
        try self.runtime.requests.requireFacilities(allocator, declaration, facilities);
        for (declaration.resources) |resource| if (resource.value == .sink) {
            const selected = try self.runtime.placement(resource.value.sink.profile.connection);
            try selected.endpoint.validate();
        };
    }
    fn bind(context: *anyopaque, scope: X.Context) !X.BoundHost {
        const self: *Host = @ptrCast(@alignCast(context));
        const factory = self.runtime.requests.host();
        return factory.bind(factory.context, scope);
    }
    fn poll(context: *anyopaque, job: X.EffectJob) !X.EffectPoll {
        const self: *Host = @ptrCast(@alignCast(context));
        return self.pool.poll(self.io, job);
    }
    fn status(context: *anyopaque, job: X.EffectJob) !?X.EffectPoll {
        const self: *Host = @ptrCast(@alignCast(context));
        return self.pool.status(self.io, job);
    }
    fn join(context: *anyopaque, descriptor: E.Descriptor) !X.EffectJoin {
        const self: *Host = @ptrCast(@alignCast(context));
        return self.pool.join(self.io, descriptor);
    }
    fn release(context: *anyopaque, descriptor: E.Descriptor) void {
        const self: *Host = @ptrCast(@alignCast(context));
        self.pool.release(self.io, descriptor);
    }
    fn adopt(context: *anyopaque, scope: X.Context, descriptor: E.Descriptor, result: E.Response) !void {
        const self: *Host = @ptrCast(@alignCast(context));
        try self.runtime.response(scope, descriptor, result);
    }
};
pub fn placement(self: Self, connection: p.DataLifecycle.Definition) !Placement {
    var found: ?Placement = null;
    for (self.placements) |entry| if (std.meta.eql(entry.connection, connection)) {
        if (found != null) return error.InvalidHttpEndpoint;
        found = entry;
    };
    return found orelse error.ApplicationHostUnavailable;
}
/// Coordinator adoption uses a fresh current request borrow after the physical
/// task has joined. No raw provider body crosses this callback.
pub fn response(self: *Self, scope: X.Context, descriptor: E.Descriptor, value: E.Response) !void {
    var scratch: std.heap.ArenaAllocator = .init(scope.scratch);
    defer scratch.deinit();
    var reads: q.ApplicationReadSet = .{ .connection = scope.client.connection };
    var current = scope;
    current.scratch = scratch.allocator();
    current.reads = &reads;
    var request = try self.requests.borrowEffect(current, null);
    defer request.deinit();
    const view = try request.view();
    var deadline = try q.ApplicationDeadline.init(scope.input.claim, scope.declaration.program.deadline, try q.ApplicationDeadline.now(scope.client.service.http.io), 300000, view.reservation.expires_ms);
    _ = try deadline.refresh(scope.client);
    try Http.verifyResponse(view.reservation, view.access, descriptor, value);
    try reads.verify(scope.client);
    _ = try deadline.remaining(try q.ApplicationDeadline.now(scope.client.service.http.io));
}
fn metadata(client: c.DirectTableClient, definition: p.DataLifecycle.Definition) !c.DirectTableClient.OwnedResponse {
    const result = try client.call(.{ .source = .{ .inspect = definition } });
    errdefer result.deinit();
    if (result.value.result != .source or result.value.result.source != .metadata or result.value.result.source.metadata == null)
        return error.InvalidSourceDeclaration;
    const value = result.value.result.source.metadata.?;
    if (value.state.dropped or value.dependency_state != .current or !std.meta.eql(value.state.declaration.interpretation, definition))
        return error.TableDefinitionChanged;
    return result;
}
fn refusal(err: anyerror) E.Refusal {
    return switch (err) {
        error.ApplicationGuardRefused => .guard,
        error.ApplicationReservationExpired, error.ClockUnavailable, error.QueueTimeUnavailable, error.LogTimeUnavailable, error.LogTimeRegression => .deadline,
        error.ApplicationReservationLost, error.ApplicationRequestOwnerMismatch => .request_lost,
        error.OutOfMemory, error.ApplicationReservationCapacity, error.InvalidTableReadBudget, error.HttpRequestTooLarge, error.HttpResponseTooLarge => .budget,
        error.AccessDenied, error.CatalogDenied, error.DataflowLeaseFenced, error.InvalidSourceControl, error.SecretRevisionChanged, error.TransactionAuthorityChanged, error.TransactionConflict, error.TransactionReadChanged, error.TableDefinitionChanged => .authority,
        else => .incomplete_dispatch,
    };
}
fn run(context: *anyopaque, task: *Tasks.Task) !void {
    const self: *Self = @ptrCast(@alignCast(context));
    const bytes = try task.allocator().alignedAlloc(u8, .fromByteUnits(Memory.Slab.granule), self.native_bytes);
    var native = try Memory.Slab.fromBuffer(bytes);
    defer native.deinit();
    var client = try self.clients.open(self.clients.context, native.allocator(), task.io, task.job.declaration.scope.connection);
    defer client.deinit();
    var worker = try X.openEffect(.{ .client = client.value }, task.job);
    defer worker.deinit();
    var output: std.heap.ArenaAllocator = .init(task.allocator());
    defer output.deinit();
    worker.owner.scope.scratch = output.allocator();
    execute(self, task, &worker) catch |err| {
        // A failed/lost begin grants no fresh Attempt. Refusal observes that
        // existing original and cannot replace a dispatching/known outcome.
        if (err != error.Canceled) _ = worker.owner.refuse(refusal(err)) catch {};
        return err;
    };
}
fn execute(self: *Self, task: *Tasks.Task, worker: *X.EffectWorker) !void {
    // Reopening retained work is observation only, regardless of current
    // request material or placement. The coordinator settles that original.
    if (try worker.owner.observe() != null) return;
    const client = worker.owner.scope.client;
    const sink_reply = try metadata(client, worker.owner.descriptor.sink);
    defer sink_reply.deinit();
    const sink = sink_reply.value.result.source.metadata.?;
    if (sink.definition.payload != .sink) return error.ProgramResourceKindMismatch;
    const control = sink.state.control orelse return error.InvalidSourceControl;
    if (control.state != .active) return error.InvalidSourceControl;
    const role = control.executor_role orelse return error.InvalidSourceControl;
    const declared = sink.definition.payload.sink;
    const connection_reply = try metadata(client, declared.connection);
    defer connection_reply.deinit();
    const connection = connection_reply.value.result.source.metadata.?;
    if (connection.definition.payload != .connection) return error.ProgramResourceKindMismatch;
    const placed = try self.placement(declared.connection);
    try placed.validate(connection.definition.payload.connection.endpoint);
    var dispatch = client;
    defer std.crypto.secureZero(u8, std.mem.asBytes(&dispatch));
    dispatch.connection.role = role;
    var state: Exchange = .{
        .task = task,
        .worker = worker,
        .dispatch = dispatch,
        .reads = .{ .connection = client.connection },
        .dispatch_reads = .{ .connection = dispatch.connection },
        .sink = .{ .interpretation = worker.owner.descriptor.sink, .kind = .sink, .control = control, .access = .inspect },
        .connection = .{ .interpretation = declared.connection, .kind = .connection, .control = null, .access = .inspect },
        .endpoint = placed.endpoint,
        .guard_scratch = .init(client.allocator),
    };
    defer std.crypto.secureZero(u8, std.mem.asBytes(&state));
    defer state.guard_scratch.deinit();
    var scope = worker.owner.scope;
    scope.reads = &state.reads;
    state.request = try self.requests.borrowEffect(scope, .{ .context = &state, .check = Exchange.redemption });
    defer state.request.deinit();
    state.secrets = try state.request.sinkSecrets(dispatch, &state.dispatch_reads);
    defer if (state.secrets) |*secret| std.crypto.secureZero(u8, std.mem.asBytes(secret));
    const view = try state.request.view();
    const timeout: u32 = @intCast(@min(placed.endpoint.timeout_ms, declared.http.request_timeout_ms));
    state.budget = .{ .deadline = try q.ApplicationDeadline.init(scope.input.claim, scope.declaration.program.deadline, try q.ApplicationDeadline.now(task.io), timeout, view.reservation.expires_ms) };
    state.endpoint.response_bytes = @min(state.endpoint.response_bytes, declared.http.response_max_bytes);
    const body = try task.allocator().alloc(u8, Http.max_body_bytes);
    defer std.crypto.secureZero(u8, body);
    state.http = undefined;
    try state.http.init(declared.http, worker.request.value.action.effect, view.reservation, view.access, body, state.endpoint.host, state.endpoint.port);
    defer state.http.deinit();
    const response_body = try task.allocator().alloc(u8, @intCast(state.endpoint.response_bytes));
    state.capture = .{ .memory = response_body };
    defer state.capture.deinit();
    // Current metadata observations do not authorize dispatch. Both roles'
    // complete checks run again after TLS under the same original request.
    try state.reads.policy(sink_reply.value.policy_revision);
    try state.reads.policy(connection_reply.value.policy_revision);
    try state.check(false);
    const begun = try worker.owner.begin(task.io);
    if (begun != .fresh) return;
    // The callback is non-cancelable internally. All child work joins before
    // this completion is published and before any private buffer is erased.
    defer task.complete(.{ .attempt = begun.fresh, .outcome = state.outcome }) catch unreachable;
    state.exchange() catch |err| {
        if (state.outcome != .response) state.outcome = if (state.write_permitted) .unknown else .{ .not_dispatched = refusal(err) };
        return err;
    };
}

const Budget = struct {
    deadline: q.ApplicationDeadline,
    mutex: std.Io.Mutex = .init,
    changed: std.Io.Condition = .init,
    fn refresh(self: *Budget, client: c.DirectTableClient) !void {
        const io = client.service.http.io;
        try self.mutex.lock(io);
        var next = self.deadline;
        self.mutex.unlock(io);
        _ = try next.refresh(client);
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        self.deadline = next;
        self.changed.signal(io);
    }
    fn remaining(self: *Budget, io: std.Io) !u32 {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        return self.deadline.remaining(try q.ApplicationDeadline.now(io));
    }
    fn wait(self: *Budget, io: std.Io) !void {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        while (true) {
            const now = try q.ApplicationDeadline.now(io);
            if (now < self.deadline.last_local_ms) return error.ClockUnavailable;
            if (now >= self.deadline.local_until_ms) return error.ApplicationReservationExpired;
            const milliseconds = std.math.cast(i64, self.deadline.local_until_ms - now) orelse return error.InvalidApplicationDeadline;
            self.changed.waitTimeout(io, &self.mutex, .{ .duration = .{ .raw = .fromMilliseconds(milliseconds), .clock = .awake } }) catch |err| switch (err) {
                error.Timeout => return error.ApplicationReservationExpired,
                else => return err,
            };
        }
    }
};
const Exchange = struct {
    task: *Tasks.Task,
    worker: *X.EffectWorker,
    dispatch: c.DirectTableClient,
    reads: q.ApplicationReadSet,
    dispatch_reads: q.ApplicationReadSet,
    sink: c.DirectTableProtocol.CurrentConnector,
    connection: c.DirectTableProtocol.CurrentConnector,
    endpoint: Transport.Endpoint,
    guard_scratch: std.heap.ArenaAllocator,
    request: Requests.EffectBorrow = undefined,
    secrets: ?Secrets = null,
    budget: Budget = undefined,
    http: Http = undefined,
    capture: Http.Capture = undefined,
    write_permitted: bool = false,
    outcome: E.Outcome = .unknown,

    fn redemption(context: *anyopaque, evidence: R.Evidence) !void {
        const self: *Exchange = @ptrCast(@alignCast(context));
        if (evidence != .redemption) return;
        const value = evidence.redemption;
        if (value.use != .form and value.use != .header) return;
        if (value.revision_kind == .native) {
            const secrets = self.secrets orelse return error.MissingProgramNativeBinding;
            if (value.handle != .secret or !try secrets.isCurrent(value.handle.secret.revision)) return error.SecretRevisionChanged;
        }
    }
    fn check(self: *Exchange, reset: bool) !void {
        const client = self.worker.owner.scope.client;
        if (reset) {
            self.reads = .{ .connection = client.connection };
            self.dispatch_reads = .{ .connection = self.dispatch.connection };
        }
        try self.budget.refresh(client);
        // Rebinding/type-checking the frozen guard owns only temporary data.
        // Reuse it across the preflight and final-write checks rather than
        // retaining freed subarenas in the request host's output arena.
        _ = self.guard_scratch.reset(.retain_capacity);
        if (!try self.worker.evaluateBoundGuard(self.guard_scratch.allocator(), self.request.bound.expressions, &self.reads)) return error.ApplicationGuardRefused;
        try self.http.requireCurrent(try q.ApplicationDeadline.now(self.task.io));
        // A observes the exact connector state; B additionally checks current
        // use and the selected executor role. Both verify one policy revision.
        const revision = self.reads.policy_revision orelse return error.TransactionAuthorityChanged;
        for ([_]c.DirectTableProtocol.CurrentConnector{ self.sink, self.connection }) |check_| {
            try self.reads.add(.{ .current_connector = check_ }, revision);
            var use = check_;
            use.access = .use;
            try self.dispatch_reads.add(.{ .current_connector = use }, revision);
        }
        try self.dispatch_reads.verify(self.dispatch);
        try self.reads.policy(self.dispatch_reads.policy_revision.?);
        try self.reads.verify(client);
        _ = try self.budget.remaining(self.task.io);
    }
    fn write(context: *anyopaque) !void {
        const self: *Exchange = @ptrCast(@alignCast(context));
        try self.check(true);
        // Any later transport failure may have emitted bytes. Overestimating
        // uncertainty never grants a second attempt under this original.
        self.write_permitted = true;
    }
    fn send(self: *Exchange) !void {
        self.endpoint.timeout_ms = @min(self.endpoint.timeout_ms, try self.budget.remaining(self.task.io));
        var body: std.Io.Reader = .fixed(self.http.body[0..self.http.body_len]);
        const result = try Transport.execute(self.task.allocator(), self.task.io, self.endpoint, self.http.request(), &body, self.http.resolver(), self.capture.callback(), .{ .context = self, .check = write });
        // No cancellation point separates verified completion and known outcome.
        self.outcome = .{ .response = try self.capture.response(result) };
        _ = try self.budget.remaining(self.task.io);
        const view = try self.request.view();
        try Http.sealResponse(self.task.io, view.reservation, view.access, self.worker.owner.descriptor, &self.outcome.response, self.capture.memory[0..self.capture.used]);
    }
    fn exchange(self: *Exchange) !void {
        const Choice = union(enum) { response: anyerror!void, deadline: anyerror!void };
        var choices: [2]Choice = undefined;
        var selection: std.Io.Select(Choice) = .init(self.task.io, &choices);
        defer selection.cancelDiscard();
        try selection.concurrent(.deadline, Budget.wait, .{ &self.budget, self.task.io });
        try selection.concurrent(.response, send, .{self});
        switch (try selection.await()) {
            inline else => |value| try value,
        }
    }
};

test "application effect placement cannot replace the declared origin or definition" {
    const t = std.testing;
    const connection: p.DataLifecycle.Definition = .{ .object = .{ .scope = .{ .realm = 1, .resource = 2, .catalog = 3 }, .branch = 1, .object = 4 }, .revision = 1, .digest = @splat(1) };
    const entry: Placement = .{ .connection = connection, .endpoint = .{ .host = "example.test", .address = "127.0.0.1", .port = 443, .tls = true } };
    try entry.validate("https://example.test/");
    for ([_][]const u8{ "http://example.test", "https://other.test", "https://example.test:444", "https://example.test/path", "https://user@example.test" }) |invalid|
        t.expectError(if (std.mem.indexOf(u8, invalid, "/path") != null or std.mem.indexOf(u8, invalid, "user@") != null) error.InvalidSourceEndpoint else error.InvalidHttpEndpoint, entry.validate(invalid)) catch return error.FixtureFailure;
    var self: Self = .{ .requests = undefined, .clients = undefined, .placements = &.{entry}, .native_bytes = 12 * 1024 * 1024 };
    _ = try self.placement(connection);
    var foreign = connection;
    foreign.digest[0] ^= 1;
    try t.expectError(error.ApplicationHostUnavailable, self.placement(foreign));
    self.placements = &.{ entry, entry };
    try t.expectError(error.InvalidHttpEndpoint, self.placement(connection));
    // Materialize the physical callback so this package checks its full native
    // composition; live dispatch is qualified by the native interface suite.
    try t.expect(@intFromPtr(self.executor().run) != 0);
}

test "application effect deadline watcher joins after a shortened remaining budget" {
    const t = std.testing;
    var runtime: std.Io.Threaded = .init(t.allocator, .{ .concurrent_limit = .limited(4), .async_limit = .limited(4) });
    defer runtime.deinit();
    const io = runtime.io();
    const start = try q.ApplicationDeadline.now(io);
    var budget: Budget = .{ .deadline = .{ .original = undefined, .absolute_ms = null, .local_until_ms = start + 60000, .last_local_ms = start, .last_upper_ms = 0 } };
    var future = try io.concurrent(Budget.wait, .{ &budget, io });
    defer future.cancel(io) catch {};
    try io.sleep(.fromMilliseconds(5), .awake);
    try budget.mutex.lock(io);
    budget.deadline.local_until_ms = (try q.ApplicationDeadline.now(io)) + 10;
    budget.changed.signal(io);
    budget.mutex.unlock(io);
    try t.expectError(error.ApplicationReservationExpired, future.await(io));
    try t.expect(try q.ApplicationDeadline.now(io) - start < 5000);
}

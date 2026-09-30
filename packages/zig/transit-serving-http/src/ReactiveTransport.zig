//! Shared host composition. Durable semantics stay in transit-serving; RFC
//! framing stays in transit-http-server. Every task owns bounded upstream I/O.
const std = @import("std");
const serving = @import("transit_serving");
const http = @import("transit_http_server");
const r = serving.ReactiveModel;
const wire = serving.ReactiveWire;
const p = serving.protocol;
const Io = std.Io;
const Context = @import("root.zig").Context;
const memory_bytes = 2 * 1024 * 1024;
const challenge_ms = 2000;
pub const Challenges = struct {
    mutex: Io.Mutex = .init,
    entries: [16]?struct { principal: u64, session: u64, generation: u64, nonce: [16]u8, expires: i64 } = @splat(null),
    fn issue(self: *Challenges, io: Io, scope: r.Scope) ![16]u8 {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        const now = Io.Clock.awake.now(io).toMilliseconds();
        var free: ?usize = null;
        var caller: usize = 0;
        for (&self.entries, 0..) |*slot, index| {
            if (slot.*) |value| if (value.expires <= now) {
                slot.* = null;
            };
            if (slot.*) |value| {
                if (value.principal == scope.principal) caller += 1;
            } else if (free == null) {
                free = index;
            }
        }
        if (caller >= 2 or free == null) return error.ServingCallerCapacity;
        var nonce: [16]u8 = undefined;
        try io.randomSecure(&nonce);
        self.entries[free.?] = .{ .principal = scope.principal, .session = scope.session, .generation = scope.generation, .nonce = nonce, .expires = now + challenge_ms };
        return nonce;
    }
    fn consume(self: *Challenges, io: Io, read: r.Read) !void {
        try self.mutex.lock(io);
        defer self.mutex.unlock(io);
        const now = Io.Clock.awake.now(io).toMilliseconds();
        for (&self.entries) |*slot| if (slot.*) |value| {
            if (value.principal == read.scope.principal and value.session == read.scope.session and value.generation == read.scope.generation and std.mem.eql(u8, &value.nonce, &read.nonce)) {
                slot.* = null;
                if (value.expires <= now) return error.ServingDenied;
                return;
            }
        };
        return error.ServingDenied;
    }
};
const Task = struct {
    host: *Context,
    io: Io,
    allocator: std.mem.Allocator,
    fn upper(raw: ?*anyopaque) !u64 {
        const self: *Task = @ptrCast(@alignCast(raw.?));
        const now = Io.Clock.real.now(self.io).toMilliseconds();
        if (now < 0) return error.ClockUnavailable;
        return std.math.add(u64, @intCast(now), self.host.config.gateway.clock_error_ms);
    }
    fn newClient(self: *Task) serving.station.client.Client {
        var result = serving.station.client.Client.init(self.allocator, self.io, self.host.config.url);
        result.timeout_ms = self.host.config.request_timeout_ms;
        result.observer = self.host.diagnostics;
        return result;
    }
    fn adapter(self: *Task, client: *serving.station.client.Client) serving.ReactiveAdapter {
        const host = self.host;
        const config = host.config.gateway;
        return .{ .base = .{ .resources = .{ .wire = client, .realm = host.config.realm, .principal = host.config.principal, .key = host.key }, .service = config.service, .ingress = config.ingress, .resource = config.resource }, .clock = .{ .context = self, .upper = upper } };
    }
    fn read(self: *Task, signed: r.SignedRead, key: [32]u8) !serving.ReactiveAdapter.Response {
        const start = Io.Clock.awake.now(self.io);
        while (true) {
            var client = self.newClient();
            defer client.deinit();
            return self.adapter(&client).read(signed, key) catch |err| {
                if (!self.retryRead(start, err)) return err;
                try self.io.sleep(.fromMilliseconds(20), .awake);
                continue;
            };
        }
    }
    fn check(self: *Task, signed: r.SignedRead, key: [32]u8) !void {
        const start = Io.Clock.awake.now(self.io);
        while (true) {
            var client = self.newClient();
            defer client.deinit();
            self.adapter(&client).check(signed, key) catch |err| {
                if (!self.retryRead(start, err)) return err;
                try self.io.sleep(.fromMilliseconds(20), .awake);
                continue;
            };
            return;
        }
    }
    fn retryRead(self: *Task, start: Io.Timestamp, err: anyerror) bool {
        // No event or heartbeat is released until a complete fresh read and
        // authority check succeed. Sustained unavailability still interrupts.
        return (err == error.AuthorityUnavailable or err == error.ServiceReadConflict) and
            start.durationTo(Io.Clock.awake.now(self.io)).toMilliseconds() < 500;
    }
    fn attach(self: *Task, bootstrap: wire.Bootstrap, key: [32]u8, fixed: *std.heap.FixedBufferAllocator) !void {
        const start = Io.Clock.awake.now(self.io);
        while (true) {
            fixed.reset();
            var client = self.newClient();
            defer client.deinit();
            _ = self.adapter(&client).attach(bootstrap, key) catch |err| {
                // The socket challenge has already been consumed. Keep this
                // task and the identical signed admission while retrying finite
                // upstream capacity loss; never issue another attachment.
                if ((err != error.AuthorityUnavailable and err != error.AuthorityTimeout and err != error.ServiceReadConflict) or
                    start.durationTo(Io.Clock.awake.now(self.io)).toMilliseconds() >= 10000) return err;
                try self.io.sleep(.fromMilliseconds(20), .awake);
                continue;
            };
            break;
        }
        // Native acceptance and owner commit are separate. A two-second window
        // can repeatedly abandon already accepted attachments during capture,
        // creating control churn and starving lease renewal on slower hosts.
        // This finite wait still fits the declared 30-second joined HTTP task.
        while (start.durationTo(Io.Clock.awake.now(self.io)).toMilliseconds() < 10000) {
            fixed.reset();
            // Observe the committed attachment and current source authority.
            // Acquiring an event/cursor here would duplicate the stream's first
            // read and consume the finite attachment observation budget.
            self.check(bootstrap.read, key) catch |err| {
                if (err != error.ReactiveAttachmentConflict and err != error.ServiceReadConflict and err != error.Conflict and
                    err != error.AuthorityUnavailable and err != error.AuthorityTimeout) return err;
                try self.io.sleep(.fromMilliseconds(20), .awake);
                continue;
            };
            return;
        }
        return error.AuthorityTimeout;
    }
    fn submit(self: *Task, signed: r.SignedSend, key: [32]u8, control: bool) !serving.Adapter.Receipt {
        const native = signed.native();
        const frame = try serving.station.Frame.decode(native.request.command.send.value);
        const command = try serving.Model.Command.decode(frame.payload);
        if (control and !wire.isControl(command)) return error.InvalidServingCommand;
        var client = self.newClient();
        defer client.deinit();
        return self.adapter(&client).base.submit(native, key);
    }
};
fn json(value: anytype, bytes: []u8) ![]const u8 {
    var writer: Io.Writer = .fixed(bytes);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(value, &encoder);
    return writer.buffered();
}
fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    const decoded = try p.Json.parseFromSlice(T, allocator, bytes);
    defer decoded.deinit();
    return decoded.value; // All public reactive envelopes own fixed-size fields.
}
fn publicKey(host: *Context, principal: u64) ![32]u8 {
    return host.config.gateway.callers[try host.callerIndex(principal)].public_key;
}
pub fn handle(host: *Context, io: Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    const description = if (std.mem.eql(u8, request.head.target, "/reactive/v1/openapi.json")) serving.Api.Format.openapi else if (std.mem.eql(u8, request.head.target, "/reactive/v1/asyncapi.json")) serving.Api.Format.asyncapi else null;
    if (description) |format| {
        if (request.head.method != .GET) return http.respond(request, .not_found, "{}");
        const buffer = try allocator.alloc(u8, serving.Api.description_bytes);
        defer allocator.free(buffer);
        var output: Io.Writer = .fixed(buffer);
        try serving.Api.write(format, &output);
        return http.respond(request, .ok, output.buffered());
    }
    const discovery = std.mem.eql(u8, request.head.target, "/reactive/v1/discovery");
    const ws = std.mem.eql(u8, request.head.target, "/reactive/v1/websocket");
    if (ws) return websocket(host, io, allocator, request);
    const control = std.mem.eql(u8, request.head.target, "/reactive/v1/control");
    const challenge = std.mem.eql(u8, request.head.target, "/reactive/v1/challenge");
    const events = std.mem.eql(u8, request.head.target, "/reactive/v1/events");
    const read = std.mem.eql(u8, request.head.target, "/reactive/v1/read");
    if (request.head.method != .POST or (!control and !challenge and !events and !read and !discovery)) return http.respond(request, .not_found, "{}");
    if (!std.mem.eql(u8, (try http.header(request, "content-type")) orelse "", "application/json")) return error.InvalidServingCommand;
    var resume_id: [512]u8 = undefined;
    const last = if (try http.header(request, "last-event-id")) |id| blk: {
        if (!events or id.len > resume_id.len) return error.InvalidReactiveCursor;
        @memcpy(resume_id[0..id.len], id);
        break :blk resume_id[0..id.len];
    } else null;
    const memory = try allocator.alloc(u8, memory_bytes);
    defer allocator.free(memory);
    var fixed = std.heap.FixedBufferAllocator.init(memory);
    const alloc = fixed.allocator();
    var task: Task = .{ .host = host, .io = io, .allocator = alloc };
    const body = try request.readerExpectNone(&.{}).allocRemaining(alloc, .limited(r.max_message_bytes));
    if (events) {
        const bootstrap = try parse(wire.Bootstrap, alloc, body);
        const key = try publicKey(host, bootstrap.read.read.scope.principal);
        try bootstrap.read.verify(key);
        if (last) |id| {
            const cursor = bootstrap.read.read.cursor orelse return error.InvalidReactiveCursor;
            const encoded = try cursor.encode();
            var text: [512]u8 = undefined;
            const hex = try std.fmt.bufPrint(&text, "{x}", .{encoded.slice()});
            if (!std.mem.eql(u8, id, hex)) return error.InvalidReactiveCursor;
        }
        const index = try host.callerIndex(bootstrap.read.read.scope.principal);
        if (!host.callers[index].acquire(false, host.config.gateway.per_caller_requests)) return error.ServingCallerCapacity;
        defer host.callers[index].release(false);
        try host.challenges.consume(io, bootstrap.read.read);
        try task.attach(bootstrap, key, &fixed);
        fixed.reset();
        return sse(&task, &fixed, request, bootstrap.read, key);
    }
    var output: [r.max_message_bytes]u8 = undefined;
    if (discovery) {
        const signed = try parse(serving.Model.SignedRead, alloc, body);
        const key = try publicKey(host, signed.read.principal);
        try signed.verify(key);
        const index = try host.callerIndex(signed.read.principal);
        if (!host.callers[index].acquire(false, host.config.gateway.per_caller_requests)) return error.ServingCallerCapacity;
        defer host.callers[index].release(false);
        var client = task.newClient();
        defer client.deinit();
        return http.respond(request, .ok, try json(try task.adapter(&client).discovery(signed, key, alloc), &output));
    }
    if (control) {
        const signed = try parse(r.SignedSend, alloc, body);
        const index = try host.callerIndex(signed.request.principal);
        const key = host.config.gateway.callers[index].public_key;
        try p.Ed25519.Signature.fromBytes(signed.signature).verify(&try p.Growth.digest(signed.native().request), try p.Ed25519.PublicKey.fromBytes(key));
        if (!host.callers[index].acquire(true, 1)) return error.ServingCallerCapacity;
        defer host.callers[index].release(true);
        return http.respond(request, .accepted, try json(try task.submit(signed, key, true), &output));
    }
    const signed = try parse(r.SignedRead, alloc, body);
    const index = try host.callerIndex(signed.read.scope.principal);
    const key = host.config.gateway.callers[index].public_key;
    try signed.verify(key);
    if (!host.callers[index].acquire(false, host.config.gateway.per_caller_requests)) return error.ServingCallerCapacity;
    defer host.callers[index].release(false);
    const observed = try task.read(signed, key);
    if (challenge) {
        if (signed.read.kind != .session or observed.session.phase != .open) return error.InvalidReactiveScope;
        const nonce = try host.challenges.issue(io, signed.read.scope);
        return http.respond(request, .ok, try json(wire.ServerMessage{ .challenge = .{ .nonce = nonce } }, &output));
    }
    return http.respond(request, .ok, try json(observed, &output));
}
fn sseWrite(body: *std.http.BodyWriter, message: wire.ServerMessage) anyerror!void {
    var encoded: [r.max_message_bytes]u8 = undefined;
    const bytes = try json(message, &encoded);
    var id: [512]u8 = undefined;
    const item: wire.SseItem = .{
        .event = std.meta.stringToEnum(wire.SseKind, @tagName(message)) orelse return error.InvalidServingCommand,
        .data = bytes,
        .id = if (message == .event) try std.fmt.bufPrint(&id, "{x}", .{(try message.event.cursor.encode()).slice()}) else null,
    };
    if (item.id) |value| try body.writer.print("id: {s}\n", .{value});
    try body.writer.print("event: {s}\ndata: {s}\n\n", .{ @tagName(item.event), item.data });
    try body.writer.flush();
    try body.http_protocol_output.flush();
}
fn sse(task: *Task, fixed: *std.heap.FixedBufferAllocator, request: *std.http.Server.Request, signed: r.SignedRead, key: [32]u8) !void {
    var buffer: [4096]u8 = undefined;
    var body = request.respondStreaming(&buffer, .{ .respond_options = .{ .keep_alive = false, .extra_headers = &.{
        .{ .name = "content-type", .value = "text/event-stream; charset=utf-8" },
        .{ .name = "cache-control", .value = "no-store" },
        .{ .name = "x-accel-buffering", .value = "no" },
        .{ .name = "x-content-type-options", .value = "nosniff" },
    } } }) catch |err| {
        // Header writes may have started; never append a second HTTP response.
        task.host.connectionError(err, true);
        return;
    };
    sseLoop(task, fixed, &body, signed, key) catch |err| {
        // Headers already committed: a typed terminal or interrupted socket,
        // never a second HTTP status. Writes themselves have a finite deadline.
        http.deadline(task.io, 1000, sseWrite, .{ &body, wire.ServerMessage{ .terminal = .{ .reason = wire.terminal(err) } } }) catch return;
        http.deadline(task.io, 1000, sseEnd, .{&body}) catch {};
        return;
    };
}
fn sseLoop(task: *Task, fixed: *std.heap.FixedBufferAllocator, body: *std.http.BodyWriter, signed: r.SignedRead, key: [32]u8) !void {
    try http.deadline(task.io, 1000, sseWrite, .{ body, wire.ServerMessage{ .attached = .{ .session = signed.read.scope.session, .generation = signed.read.scope.generation, .attachment = signed.read.attachment } } });
    var previous = signed.read.cursor;
    while (true) {
        fixed.reset();
        const result = try task.read(signed, key);
        const current = result.cursor.?;
        const changed = previous == null or !std.meta.eql(previous.?.position, current.position);
        fixed.reset();
        try task.check(signed, key);
        if (changed and result.event != null) try http.deadline(task.io, 1000, sseWrite, .{ body, wire.ServerMessage{ .event = .{ .cursor = current, .event = result.event.? } } }) else try http.deadline(task.io, 1000, sseWrite, .{ body, wire.ServerMessage{ .heartbeat = .{} } });
        previous = current;
        try task.io.sleep(.fromMilliseconds(500), .awake);
    }
}
const Socket = struct {
    host: *Context,
    io: Io,
    allocator: std.mem.Allocator,
    ws: *std.http.Server.WebSocket,
    signed: r.SignedRead,
    key: [32]u8,
    mutex: Io.Mutex = .init,
    closed: bool = false,
    fn send(self: *Socket, message: wire.ServerMessage, task: ?*Task) !void {
        try http.deadline(self.io, 1000, write, .{ self, message, task });
    }
    fn write(self: *Socket, message: wire.ServerMessage, task: ?*Task) anyerror!void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        if (self.closed) return error.WebSocketConnectionClosed;
        if (task) |context| try context.check(self.signed, self.key);
        var encoded: [r.max_message_bytes]u8 = undefined;
        try self.ws.writeMessage(try json(message, &encoded), .text);
    }
    fn control(self: *Socket, bytes: []const u8, close: bool) anyerror!void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        if (self.closed) return error.WebSocketConnectionClosed;
        if (close) self.closed = true;
        try self.ws.writeMessage(bytes, if (close) .connection_close else .pong);
    }
    fn receive(self: *Socket) anyerror!void {
        const memory = try self.allocator.alloc(u8, memory_bytes);
        defer self.allocator.free(memory);
        var fixed = std.heap.FixedBufferAllocator.init(memory);
        var task: Task = .{ .host = self.host, .io = self.io, .allocator = fixed.allocator() };
        var decoder: http.WebSocket.Decoder = .{};
        while (true) {
            const message = try decoder.next(self.ws.input);
            fixed.reset();
            // Revalidate controls too. A ping does not extend the logical lease.
            try task.check(self.signed, self.key);
            fixed.reset();
            switch (message.opcode) {
                .close => return http.deadline(self.io, 1000, control, .{ self, message.bytes, true }),
                .ping => try http.deadline(self.io, 1000, control, .{ self, message.bytes, false }),
                .pong => {},
                .text => {
                    const incoming = try parse(wire.ClientMessage, fixed.allocator(), message.bytes);
                    fixed.reset();
                    const result: wire.ServerMessage = switch (incoming) {
                        .attach => return error.InvalidReactiveScope,
                        .command, .control => |signed| blk: {
                            if (signed.request.principal != self.signed.read.scope.principal) return error.ServingDenied;
                            break :blk .{ .receipt = try task.submit(signed, self.key, incoming == .control) };
                        },
                        .read => |signed| blk: {
                            if (!std.meta.eql(signed.read.scope, self.signed.read.scope) or signed.read.attachment != self.signed.read.attachment or !std.mem.eql(u8, &signed.read.nonce, &self.signed.read.nonce)) return error.InvalidReactiveScope;
                            break :blk .{ .observation = try task.read(signed, self.key) };
                        },
                    };
                    fixed.reset();
                    try self.send(result, &task);
                },
            }
        }
    }
    fn events(self: *Socket) anyerror!void {
        const memory = try self.allocator.alloc(u8, memory_bytes);
        defer self.allocator.free(memory);
        var fixed = std.heap.FixedBufferAllocator.init(memory);
        var task: Task = .{ .host = self.host, .io = self.io, .allocator = fixed.allocator() };
        var previous = self.signed.read.cursor;
        while (true) {
            fixed.reset();
            const result = try task.read(self.signed, self.key);
            const current = result.cursor.?;
            const changed = previous == null or !std.meta.eql(previous.?.position, current.position);
            fixed.reset();
            if (changed and result.event != null) try self.send(.{ .event = .{ .cursor = current, .event = result.event.? } }, &task) else try self.send(.{ .heartbeat = .{} }, &task);
            previous = current;
            try self.io.sleep(.fromMilliseconds(500), .awake);
        }
    }
    fn run(self: *Socket) !void {
        const Result = union(enum) { input: anyerror!void, events: anyerror!void };
        var messages: [2]Result = undefined;
        var select: Io.Select(Result) = .init(self.io, &messages);
        defer select.cancelDiscard();
        try select.concurrent(.input, receive, .{self});
        try select.concurrent(.events, events, .{self});
        switch (try select.await()) {
            inline else => |result| try result,
        }
    }
};
fn first(ws: *std.http.Server.WebSocket, allocator: std.mem.Allocator, output: *wire.Bootstrap) anyerror!void {
    var decoder: http.WebSocket.Decoder = .{};
    // Bound the unauthenticated exchange by both elapsed time and frame count.
    for (0..4) |_| {
        const message = try decoder.next(ws.input);
        switch (message.opcode) {
            .text => {
                const value = try parse(wire.ClientMessage, allocator, message.bytes);
                if (value != .attach) return error.InvalidReactiveScope;
                output.* = value.attach;
                return;
            },
            .ping => try ws.writeMessage(message.bytes, .pong),
            .pong => {},
            .close => return error.WebSocketConnectionClosed,
        }
    }
    return error.InvalidReactiveScope;
}
fn websocket(host: *Context, io: Io, allocator: std.mem.Allocator, request: *std.http.Server.Request) !void {
    if (!std.mem.eql(u8, (try http.header(request, "origin")) orelse "", host.config.gateway.public_origin)) return error.ServingDenied;
    const key = try http.WebSocket.handshake(request, r.subprotocol);
    var ws = request.respondWebSocket(.{ .key = key, .extra_headers = &.{.{ .name = "sec-websocket-protocol", .value = r.subprotocol }} }) catch |err| {
        host.connectionError(err, true);
        return;
    };
    websocketRun(host, io, allocator, &ws) catch |err| {
        host.connectionError(err, true);
        // Work has been joined before the closing frame. No HTTP response can
        // follow a successful upgrade; delivery failure remains interruption.
        var code: [2]u8 = undefined;
        std.mem.writeInt(u16, &code, http.WebSocket.closeCode(err), .big);
        http.deadline(io, 1000, closeSocket, .{ &ws, code }) catch {};
    };
}
fn closeSocket(ws: *std.http.Server.WebSocket, code: [2]u8) anyerror!void {
    try ws.writeMessage(&code, .connection_close);
}
fn websocketRun(host: *Context, io: Io, allocator: std.mem.Allocator, ws: *std.http.Server.WebSocket) !void {
    const memory = try allocator.alloc(u8, memory_bytes);
    defer allocator.free(memory);
    var fixed = std.heap.FixedBufferAllocator.init(memory);
    var task: Task = .{ .host = host, .io = io, .allocator = fixed.allocator() };
    var nonce: [16]u8 = undefined;
    try io.randomSecure(&nonce);
    var encoded: [256]u8 = undefined;
    try ws.writeMessage(try json(wire.ServerMessage{ .challenge = .{ .nonce = nonce } }, &encoded), .text);
    var bootstrap: wire.Bootstrap = undefined;
    try http.deadline(io, challenge_ms, first, .{ ws, fixed.allocator(), &bootstrap });
    if (!std.mem.eql(u8, &bootstrap.read.read.nonce, &nonce)) return error.ServingDenied;
    const index = try host.callerIndex(bootstrap.read.read.scope.principal);
    const public_key = host.config.gateway.callers[index].public_key;
    try bootstrap.read.verify(public_key);
    if (!host.callers[index].acquire(false, host.config.gateway.per_caller_requests)) return error.ServingCallerCapacity;
    defer host.callers[index].release(false);
    fixed.reset();
    try task.attach(bootstrap, public_key, &fixed);
    var socket: Socket = .{ .host = host, .io = io, .allocator = allocator, .ws = ws, .signed = bootstrap.read, .key = public_key };
    fixed.reset();
    try socket.send(.{ .attached = .{ .session = bootstrap.read.read.scope.session, .generation = bootstrap.read.read.scope.generation, .attachment = bootstrap.read.read.attachment } }, &task);
    socket.run() catch |err| {
        socket.send(.{ .terminal = .{ .reason = wire.terminal(err) } }, null) catch {};
        return err;
    };
}

fn sseEnd(body: *std.http.BodyWriter) anyerror!void {
    try body.end();
}

//! Executes a pure session's requests against its authenticated owner. One
//! borrower is active at a time. The outer host joins cancellation before deinit.
const std = @import("std");
const s = @import("transit_postgres").wire.Session;
pub fn Driver(comptime Session: type, comptime Host: type, comptime Transport: type) type {
    return struct {
        const Self = @This();
        session: Session,
        host: *Host,
        transport: *Transport,
        // MySQL permits a temporary simple query alongside its 64 prepared IDs.
        prepared: [65]?struct { id: s.Handle, value: *Host.Prepared } = @splat(null),
        reads: [8]?struct { id: s.Handle, value: *Host.Read } = @splat(null),
        next_handle: s.Handle = 1,
        disclosure: s.Guard = .none,
        completion: ?struct { prepared: s.Handle, value: @import("transit_postgres").wire.results.CommandCompletion } = null,
        pub fn init(host: *Host, transport: *Transport, session: Session) Self {
            return .{ .host = host, .transport = transport, .session = session };
        }
        pub fn deinit(self: *Self) void {
            self.session.abort(error.WireSessionClosed);
            // Reads may borrow bound values and prepared metadata. Their owner
            // closes first; only then may the pure session release its arenas.
            for (self.reads) |slot| if (slot) |entry| self.host.closeRead(entry.value);
            for (self.prepared) |slot| if (slot) |prepared| self.host.destroy(prepared.value);
            self.host.end();
            self.session.deinit();
            self.* = undefined;
        }
        fn handle(self: *Self) !s.Handle {
            if (self.next_handle == std.math.maxInt(u64)) return error.WireSessionExhausted;
            const id = self.next_handle;
            self.next_handle += 1;
            return id;
        }
        fn preparation(self: *Self, id: s.Handle) !*Host.Prepared {
            for (self.prepared) |slot| if (slot) |entry| if (entry.id == id) return entry.value;
            return error.UnknownWireHostHandle;
        }
        fn read(self: *Self, id: s.Handle) !*Host.Read {
            for (self.reads) |slot| if (slot) |entry| if (entry.id == id) return entry.value;
            return error.UnknownWireHostHandle;
        }
        fn authorize(self: *Self, guard: s.Guard) !void {
            if (guard == .none or std.meta.eql(guard, self.disclosure)) return;
            switch (guard) {
                .none => {},
                .prepared => |id| try self.host.validate(try self.preparation(id)),
                .read => |id| try (try self.read(id)).validateDisclosure(),
                .completion => |id| {
                    const value = self.completion orelse return error.InvalidWireCompletion;
                    if (value.prepared != id) return error.InvalidWireCompletion;
                    const prepared = try self.preparation(id);
                    if (@hasDecl(Host, "validateWireCompletion")) try self.host.validateWireCompletion(prepared, value.value) else try self.host.validate(prepared);
                },
            }
            self.disclosure = guard;
        }
        fn invalidateObservations(self: *Self) void {
            self.disclosure = .none;
            if (@hasDecl(Host, "resumeWire")) self.host.resumeWire();
            if (@hasDecl(Host.Read, "resumeWire")) {
                for (self.reads) |slot| if (slot) |entry| entry.value.resumeWire();
            }
        }
        pub fn perform(self: *Self, request: s.Request) !s.Result {
            self.invalidateObservations();
            return self.performImmediate(request);
        }
        // The installed blocking adapter drains each request directly into the
        // next. Explicitly scheduled callers use perform, invalidating cached
        // observations before resuming an operation or disclosing buffered data.
        fn performImmediate(self: *Self, request: s.Request) !s.Result {
            // Consecutive outputs from one bounded batch share one disclosure.
            // Pulling more rows or scheduling any other owner work ends it.
            if (request == .bind) {
                if (!std.meta.eql(self.disclosure, s.Guard{ .prepared = request.bind.prepared })) self.disclosure = .none;
            } else if (request != .output and request != .status) self.disclosure = .none;
            return switch (request) {
                .begin => blk: {
                    try self.host.begin();
                    break :blk .{ .status = self.host.transactionStatus() };
                },
                .end => blk: {
                    self.host.end();
                    break :blk .{ .status = self.host.transactionStatus() };
                },
                .status => .{ .status = self.host.transactionStatus() },
                .prepare => |sql| blk: {
                    const index = for (self.prepared, 0..) |slot, i| {
                        if (slot == null) break i;
                    } else return error.TooManyWireStatements;
                    const id = try self.handle();
                    const value = try self.host.prepare(sql);
                    self.prepared[index] = .{ .id = id, .value = value };
                    self.disclosure = .{ .prepared = id };
                    break :blk .{ .prepared = .{ .handle = id, .parameters = value.parameters(), .fields = value.fields(), .mutation = value.mutation(), .empty = value.empty() } };
                },
                .destroy => |id| blk: {
                    for (&self.prepared) |*slot| if (slot.*) |entry| if (entry.id == id) {
                        self.host.destroy(entry.value);
                        slot.* = null;
                        break :blk .ok;
                    };
                    return error.UnknownWireHostHandle;
                },
                .validate => |id| blk: {
                    try self.host.validate(try self.preparation(id));
                    self.disclosure = .{ .prepared = id };
                    break :blk .ok;
                },
                .bind => |bound| blk: {
                    try self.host.bind(try self.preparation(bound.prepared), bound.values);
                    break :blk .ok;
                },
                .open_read => |bound| blk: {
                    const index = for (self.reads, 0..) |slot, i| {
                        if (slot == null) break i;
                    } else return error.TooManyWirePortals;
                    const id = try self.handle();
                    const value = try self.host.openRead(try self.preparation(bound.prepared), bound.values);
                    self.reads[index] = .{ .id = id, .value = value };
                    self.disclosure = .{ .prepared = bound.prepared };
                    break :blk .{ .read = id };
                },
                .close_read => |id| blk: {
                    for (&self.reads) |*slot| if (slot.*) |entry| if (entry.id == id) {
                        self.host.closeRead(entry.value);
                        slot.* = null;
                        break :blk .ok;
                    };
                    return error.UnknownWireHostHandle;
                },
                .next_batch => |batch| .{ .batch = try (try self.read(batch.read)).nextBatch(batch.maximum) },
                .write => |bound| blk: {
                    const completion = try self.host.write(try self.preparation(bound.prepared), bound.values);
                    self.completion = .{ .prepared = bound.prepared, .value = completion };
                    self.disclosure = .{ .completion = bound.prepared };
                    break :blk .{ .completion = completion };
                },
                .select_database => |name| blk: {
                    if (@hasDecl(Host, "selectDatabase")) try self.host.selectDatabase(name) else return error.UnsupportedWireOperation;
                    break :blk .ok;
                },
                .reset => blk: {
                    if (@hasDecl(Host, "reset")) try self.host.reset() else return error.UnsupportedWireOperation;
                    break :blk .ok;
                },
                .diagnostic => |err| blk: {
                    const diagnostic = self.host.diagnostic(err);
                    break :blk .{ .diagnostic = .{ .state = diagnostic.state, .message = diagnostic.message, .detail = diagnostic.detail } };
                },
                .output => |output| blk: {
                    self.authorize(output.guard) catch |err| break :blk .{ .refused = err };
                    try self.transport.writeAll(output.bytes);
                    break :blk .{ .written = output.bytes.len };
                },
            };
        }
        pub fn run(self: *Self, args: anytype) !bool {
            errdefer self.session.abort(error.WireSessionClosed);
            // Receiving another command may have parked indefinitely, including
            // consecutive Describe messages within one extended cycle.
            self.invalidateObservations();
            try @call(.auto, Session.start, .{&self.session} ++ args);
            while (true) switch (try self.session.poll()) {
                .done => |open| return open,
                .request => |event| {
                    const result = self.performImmediate(event.request) catch |err| s.Result{ .failed = err };
                    try self.session.complete(event.token, result);
                },
            };
        }
    };
}

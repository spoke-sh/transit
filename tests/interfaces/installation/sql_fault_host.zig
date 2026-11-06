//! Test-only decoration of the real node's typed SQL endpoint. The installed
//! schedules retain an accepted binding while both native control and reads run.
const std = @import("std");
const real = @import("sql_host");
const g = @import("transit_sql_service");
const c = g.query.catalog;
pub const Crypto = real.Crypto;
pub const Deployment = struct {
    pub const Config = real.Deployment.Config;
    pub const enablePerformance = real.Deployment.enablePerformance;
    pub fn serve(init: std.process.Init, config: Config, endpoint: real.LocalEndpoint, diagnostics: *g.wire.observability.telemetry.Runtime) !void {
        const directory = init.environ_map.get("TEST_TRANSIT_DIRECT_BOUNDARY") orelse return real.Deployment.serve(init, config, endpoint, diagnostics);
        var boundary: Boundary = .{ .io = init.io, .allocator = init.gpa, .directory = directory, .endpoint = endpoint };
        return real.Deployment.serve(init, config, .{ .context = &boundary, .invoke = Boundary.invoke }, diagnostics);
    }
};
const Boundary = struct {
    io: std.Io,
    allocator: std.mem.Allocator,
    directory: []const u8,
    endpoint: real.LocalEndpoint,
    mutex: std.Io.Mutex = .init,
    fn invoke(raw: *anyopaque, invocation: *real.LocalEndpoint.Invocation) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (std.mem.eql(u8, invocation.path, "/table/v1")) {
            const request = try invocation.request(c.DirectTableProtocol.Request);
            switch (request.action) {
                .operation => |value| if (value.command == .execute) try self.block(invocation, value.binding),
                .namespace_operation => |value| if (value.command == .execute) try self.block(invocation, value.binding),
                .commit_saved => |value| try self.block(invocation, value.binding),
                .client_progress => |value| if (value == .update) {
                    if (value.update.record) |record| if (record.format == 0x53514131) {
                        if (try self.dropActivation(invocation, request)) return;
                    };
                },
                else => {},
            }
        }
        return self.endpoint.invoke(self.endpoint.context, invocation);
    }
    // The SQL owner invokes this endpoint directly; an HTTP proxy cannot
    // interrupt activation. Capture the real committed result before withholding
    // its return. The flag is consumed first so replacement is never faulted as
    // another activation attempt merely because this process was killed.
    fn dropActivation(self: *@This(), invocation: *real.LocalEndpoint.Invocation, request: c.DirectTableProtocol.Request) !bool {
        const directory = try std.Io.Dir.cwd().openDir(self.io, self.directory, .{});
        defer directory.close(self.io);
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const bytes = directory.readFileAlloc(self.io, "drop-activation.json", self.allocator, .limited(128)) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
        defer self.allocator.free(bytes);
        const selection = try std.json.parseFromSlice(struct { principal: u64 }, self.allocator, bytes, .{});
        defer selection.deinit();
        if (request.connection.principal != selection.value.principal) return false;
        try directory.deleteFile(self.io, "drop-activation.json");
        const response = try real.LocalEndpoint.call(self.endpoint, invocation.client, invocation.allocator, c.DirectTableProtocol.Response, invocation.path, request, invocation.deadline);
        const state = response.result.client_progress.state orelse return error.MissingAcceptedActivation;
        const evidence = try g.wire.protocol.Json.valueAlloc(self.allocator, .{ .key = request.action.client_progress.update.key, .state = state });
        defer self.allocator.free(evidence);
        try directory.writeFile(self.io, .{ .sub_path = "activation.pending", .data = evidence });
        try directory.rename("activation.pending", directory, "dropped-activation.json", self.io);
        const started = std.Io.Clock.awake.now(self.io);
        while (started.durationTo(std.Io.Clock.awake.now(self.io)).toMilliseconds() < 8000) {
            if (directory.access(self.io, "release-activation", .{})) |_| break else |err| {
                if (err != error.FileNotFound) return err;
            }
            try self.io.sleep(.fromMilliseconds(20), .awake);
        }
        return invocation.client.reject(.service_unavailable, .AuthorityUnavailable);
    }
    fn block(self: *@This(), invocation: *real.LocalEndpoint.Invocation, binding: anytype) !void {
        var directory = try std.Io.Dir.cwd().openDir(self.io, self.directory, .{});
        defer directory.close(self.io);
        const flag = directory.openFile(self.io, "block-execute", .{}) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        flag.close(self.io);
        // Serialize only the already accepted operation binding. No payload,
        // signing key, request proof or credential enters the evidence file.
        const bytes = try g.wire.protocol.Json.valueAlloc(self.allocator, binding);
        defer self.allocator.free(bytes);
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        try directory.writeFile(self.io, .{ .sub_path = "observed.pending", .data = bytes });
        try directory.rename("observed.pending", directory, "observed.json", self.io);
        return invocation.client.reject(.service_unavailable, .AuthorityUnavailable);
    }
};

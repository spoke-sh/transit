//! Test-only decoration of the real node's typed SQL endpoint. The installed
//! schedules retain an accepted binding while both native control and reads run.
const std = @import("std");
const real = @import("sql_host");
const g = @import("transit_sql_service");
const c = g.query.catalog;
pub const Crypto = real.Crypto;
pub const Deployment = struct {
    pub const Config = real.Deployment.Config;
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
                else => {},
            }
        }
        return self.endpoint.invoke(self.endpoint.context, invocation);
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

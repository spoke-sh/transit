//! Test-only decoration of the production browser's public native reads.
//! Evidence contains counts only; no rows, credentials or request proofs.
const std = @import("std");
const real = @import("serving_http").BrowserRuntime;
const c = real.catalog;
pub const BrowserRuntime = struct {
    pub const Config = real.Config;
    pub const Running = struct {
        delegate: real.Running,
        boundary: *Boundary,
        pub fn open(init: std.process.Init, config: Config, endpoint: c.client.LocalEndpoint) !Running {
            const boundary = try init.gpa.create(Boundary);
            errdefer init.gpa.destroy(boundary);
            const directory = try std.fs.path.join(init.gpa, &.{ std.fs.path.dirname(config.secret_directory) orelse return error.MissingTestBoundary, "browser-boundary" });
            errdefer init.gpa.free(directory);
            boundary.* = .{ .init = init, .endpoint = endpoint, .directory = directory };
            return .{ .delegate = try real.Running.open(init, config, .{ .context = boundary, .invoke = Boundary.invoke }), .boundary = boundary };
        }
        pub fn run(self: *Running) !void {
            try self.delegate.run();
        }
        pub fn deinit(self: *Running) void {
            self.delegate.deinit();
            self.boundary.init.gpa.free(self.boundary.directory);
            self.boundary.init.gpa.destroy(self.boundary);
        }
    };
};
const Boundary = struct {
    init: std.process.Init,
    endpoint: c.client.LocalEndpoint,
    directory: []const u8,
    mutex: std.Io.Mutex = .init,
    reads: u64 = 0,
    fn take(self: *@This(), flag: []const u8) !bool {
        var directory = try std.Io.Dir.cwd().openDir(self.init.io, self.directory, .{});
        defer directory.close(self.init.io);
        directory.deleteFile(self.init.io, flag) catch |err| switch (err) {
            error.FileNotFound => return false,
            else => return err,
        };
        return true;
    }
    fn invoke(raw: *anyopaque, invocation: *c.client.LocalEndpoint.Invocation) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        const action = if (std.mem.eql(u8, invocation.path, "/table/v1")) (try invocation.request(c.DirectTableProtocol.Request)).action else null;
        const read = if (action) |value| value == .read_current else false;
        const progress = if (action) |value| value == .client_progress and value.client_progress == .update else false;
        if (progress and try self.take("conflict-before")) return invocation.client.reject(.conflict, .Conflict);
        self.endpoint.invoke(self.endpoint.context, invocation) catch |err| {
            var directory = try std.Io.Dir.cwd().openDir(self.init.io, self.directory, .{});
            defer directory.close(self.init.io);
            var buffer: [256]u8 = undefined;
            try directory.writeFile(self.init.io, .{ .sub_path = "refusal", .data = try std.fmt.bufPrint(&buffer, "{s}: {s}", .{ @errorName(err), if (invocation.client.last_rejection) |code| @tagName(code) else "no_native_refusal" }) });
            return err;
        };
        if (progress and try self.take("conflict-after")) return invocation.client.reject(.conflict, .Conflict);
        if (!read) return;
        var directory = try std.Io.Dir.cwd().openDir(self.init.io, self.directory, .{});
        defer directory.close(self.init.io);
        {
            try self.mutex.lock(self.init.io);
            defer self.mutex.unlock(self.init.io);
            self.reads += 1;
            var buffer: [32]u8 = undefined;
            try directory.writeFile(self.init.io, .{ .sub_path = "reads.pending", .data = try std.fmt.bufPrint(&buffer, "{d}", .{self.reads}) });
            try directory.rename("reads.pending", directory, "reads", self.init.io);
        }
        // This fixture has two pages. Pause the final native page so the
        // schedule exercises authorization after buffering the whole result,
        // independently of the work-budget check before the next page.
        if (action.?.read_current.selection.rows.after == null) return;
        const flag = directory.openFile(self.init.io, "hold", .{}) catch |err| switch (err) {
            error.FileNotFound => return,
            else => return err,
        };
        flag.close(self.init.io);
        try directory.writeFile(self.init.io, .{ .sub_path = "buffered", .data = "read completed" });
        while (true) {
            const held = directory.openFile(self.init.io, "hold", .{}) catch |err| switch (err) {
                error.FileNotFound => return,
                else => return err,
            };
            held.close(self.init.io);
            try self.init.io.sleep(.fromMilliseconds(10), .awake);
        }
    }
};

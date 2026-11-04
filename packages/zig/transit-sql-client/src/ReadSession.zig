//! Stable connection owner for finite read consumers. The caller releases all
//! outcomes before closing this owner. Admission remains Executor.read.
const std = @import("std");
const s = @import("root.zig");
const Self = @This();
allocator: std.mem.Allocator,
client: s.Client,
control: s.Client,
executor: s.Executor,
pub fn open(allocator: std.mem.Allocator, io: std.Io, config: s.Client.Config) !*Self {
    const self = try allocator.create(Self);
    errdefer allocator.destroy(self);
    self.* = .{ .allocator = allocator, .client = try s.Client.init(allocator, io, config), .control = undefined, .executor = undefined };
    errdefer self.client.deinit();
    var password: ?[]u8 = null;
    defer if (password) |bytes| {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    };
    if (config.password_file) |path| password = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(4096));
    try self.client.open(config, if (password) |bytes| std.mem.trim(u8, bytes, "\r\n") else null);
    errdefer if (self.client.call(.close)) |reply| reply.deinit() else |_| {};
    self.control = try self.client.observationClient(config);
    self.control.session = self.client.session;
    self.control.instance = self.client.instance;
    self.control.account = self.client.account;
    self.executor = .{ .client = &self.client, .control = &self.control, .config = config };
    return self;
}
pub fn close(self: *Self) void {
    self.executor.release(.close);
    self.control.deinit();
    self.client.deinit();
    self.allocator.destroy(self);
}

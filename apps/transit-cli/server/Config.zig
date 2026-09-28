const std = @import("std");
const Files = @import("Files.zig");
const Self = @This();
version: u8,
installation: []const u8,
realm: u64,
admission_ceiling: u64 = 65536,
control_reserve: u64 = 4096,
ports: Ports,
executables: Executables,
applications: ?Applications = null,
gateway_allowed_hosts: []const []const u8 = &.{},
pub const Applications = struct { port: u16, max_applications: u16 = 8, max_roles: u16 = 32 };
pub const Ports = struct { cold: u16, cold_console: u16, store: u16, node: u16, gateway: u16 };
pub const Executables = struct { minio: []const u8, ursula: []const u8, node: []const u8, query_host: []const u8 };
pub const Identity = struct { config: [32]u8, cli: [32]u8, minio: [32]u8, ursula: [32]u8, node: [32]u8, query_host: [32]u8 };
pub fn load(init: std.process.Init, path: []const u8) !Self {
    const allocator = init.arena.allocator();
    const absolute = try std.Io.Dir.cwd().realPathFileAlloc(init.io, path, allocator);
    var self = try Files.read(Self, init.io, allocator, absolute);
    if ((self.version != 1 and self.version != 2) or (self.version == 1 and self.applications != null) or (self.version == 2 and self.applications == null) or self.realm == 0 or self.realm > @import("transit_query").protocol.max_counter or @import("builtin").os.tag != .linux) return error.InvalidConfiguration;
    if (self.applications) |apps| {
        if (apps.port < 1024 or apps.max_applications == 0 or apps.max_applications > 64 or apps.max_roles == 0 or apps.max_roles > 256) return error.InvalidConfiguration;
        inline for (@typeInfo(Ports).@"struct".field_names) |name| if (apps.port == @field(self.ports, name)) return error.InvalidConfiguration;
    }
    if (self.admission_ceiling < 128 or self.admission_ceiling > 65536 or self.control_reserve > 65536) return error.InvalidConfiguration;
    try @import("Hosts.zig").validate(self.gateway_allowed_hosts);
    const base = std.fs.path.dirname(absolute).?;
    self.installation = try std.fs.path.resolve(allocator, &.{ base, self.installation });
    if (std.mem.indexOfAny(u8, self.installation, "\x00\n\r\"\\") != null or std.mem.eql(u8, self.installation, "/")) return error.InvalidConfiguration;
    inline for (@typeInfo(Executables).@"struct".field_names) |name| {
        const configured = @field(self.executables, name);
        if (configured.len == 0) return error.InvalidConfiguration;
        @field(self.executables, name) = try std.Io.Dir.cwd().realPathFileAlloc(init.io, try std.fs.path.resolve(allocator, &.{ base, configured }), allocator);
    }
    const fields = @typeInfo(Ports).@"struct".field_names;
    inline for (fields, 0..) |name, i| {
        if (@field(self.ports, name) < 1024) return error.InvalidConfiguration;
        inline for (fields[0..i]) |previous| if (@field(self.ports, name) == @field(self.ports, previous)) return error.InvalidConfiguration;
    }
    return self;
}
pub fn identities(self: Self, init: std.process.Init, executable: []const u8) !Identity {
    var result: Identity = undefined;
    const bytes = try std.json.Stringify.valueAlloc(init.gpa, self, .{});
    defer init.gpa.free(bytes);
    std.crypto.hash.sha2.Sha256.hash(bytes, &result.config, .{});
    result.cli = try digest(init, executable);
    inline for (@typeInfo(Executables).@"struct".field_names) |name| @field(result, name) = try digest(init, @field(self.executables, name));
    return result;
}
pub fn digest(init: std.process.Init, path: []const u8) ![32]u8 {
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    if (stat.kind != .file or stat.size == 0 or stat.size > 256 * 1024 * 1024 or stat.permissions.toMode() & 0o6000 != 0 or stat.permissions.toMode() & 0o111 == 0) return error.InvalidExecutable;
    var hash = std.crypto.hash.sha2.Sha256.init(.{});
    var storage: [65536]u8 = undefined;
    var reader = file.reader(init.io, &storage);
    while (true) {
        const bytes = reader.interface.peekGreedy(1) catch |err| {
            if (err == error.EndOfStream) break;
            return err;
        };
        hash.update(bytes);
        reader.interface.toss(bytes.len);
    }
    return hash.finalResult();
}
pub fn preflight(self: Self, io: std.Io) !void {
    var listeners: [6]?std.Io.net.Server = @splat(null);
    defer for (&listeners) |*listener| if (listener.*) |*server| server.deinit(io);
    inline for (@typeInfo(Ports).@"struct".field_names, 0..) |name, i| listeners[i] = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", @field(self.ports, name))).listen(io, .{ .reuse_address = true });
    if (self.applications) |apps| listeners[5] = try (try std.Io.net.IpAddress.parseIp4("127.0.0.1", apps.port)).listen(io, .{ .reuse_address = true });
}

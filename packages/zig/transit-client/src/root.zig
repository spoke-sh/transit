//! Bounded protocol HTTP client. No storage or provider credentials.
const std = @import("std");
pub const transit = @import("transit");
pub const max_body = 64 * 1024;
pub const Input = struct { position: u64, value: i64 };
pub const View = struct {
    position: u64,
    principal_sequence: u64,
    process: transit.Process,
    input: ?Input,
    effects: [transit.max_effects]?transit.Effect = @splat(null),
};
pub const Receipt = struct { position: u64 };

pub const Client = struct {
    http: std.http.Client,
    url: []const u8,
    timeout_ms: u32 = 5000,

    pub fn init(allocator: std.mem.Allocator, io: std.Io, url: []const u8) Client {
        return .{ .http = .{ .allocator = allocator, .io = io }, .url = url };
    }
    pub fn deinit(self: *Client) void {
        self.http.deinit();
    }

    /// The caller owns deadlines and retry policy. Never follow redirects with
    /// signed requests; the configured endpoint is the trusted authority.
    pub fn call(self: *Client, comptime T: type, path: []const u8, signed: transit.SignedRequest) !T {
        const Result = union(enum) { response: anyerror!T, timeout: anyerror!void };
        var results: [2]Result = undefined;
        var select: std.Io.Select(Result) = .init(self.http.io, &results);
        defer select.cancelDiscard();
        try select.concurrent(.timeout, timeout, .{ self.http.io, self.timeout_ms });
        const Task = struct {
            fn run(client: *Client, route: []const u8, command: transit.SignedRequest) anyerror!T {
                return client.perform(T, route, command);
            }
        };
        select.async(.response, Task.run, .{ self, path, signed });
        return switch (try select.await()) {
            .response => |result| result,
            .timeout => error.AuthorityTimeout,
        };
    }

    fn timeout(io: std.Io, milliseconds: u32) anyerror!void {
        try io.sleep(.fromMilliseconds(milliseconds), .awake);
    }

    fn perform(self: *Client, comptime T: type, path: []const u8, signed: transit.SignedRequest) anyerror!T {
        const allocator = self.http.allocator;
        const url = try allocator.print("{s}{s}", .{ self.url, path });
        defer allocator.free(url);
        const body = try std.json.Stringify.valueAlloc(allocator, signed, .{});
        defer allocator.free(body);
        var buffer: [max_body]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&buffer);
        const response = try self.http.fetch(.{
            .location = .{ .url = url },
            .method = .POST,
            .payload = body,
            .headers = .{ .content_type = .{ .override = "application/json" } },
            .redirect_behavior = .not_allowed,
            .keep_alive = false,
            .response_writer = &writer,
        });
        switch (response.status) {
            .ok => {},
            .forbidden => return error.AccessDenied,
            .conflict => return error.Conflict,
            .unprocessable_entity => return error.Rejected,
            else => return error.AuthorityUnavailable,
        }
        var parsed = try std.json.parseFromSlice(T, allocator, writer.buffered(), .{});
        defer parsed.deinit();
        return parsed.value;
    }

    pub fn view(self: *Client, request: transit.Request, key: transit.Ed25519.KeyPair) !View {
        if (request.command != .inspect or request.sequence != 0) return error.InvalidRead;
        return self.call(View, "/v1/view", try transit.sign(request, key));
    }
    pub fn submit(self: *Client, signed: transit.SignedRequest) !Receipt {
        return self.call(Receipt, "/v1/command", signed);
    }
};

/// Private seeds are read from an explicitly supplied file, never argv or logs.
pub fn readKey(allocator: std.mem.Allocator, io: std.Io, path: []const u8) !transit.Ed25519.KeyPair {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(256));
    defer {
        std.crypto.secureZero(u8, bytes);
        allocator.free(bytes);
    }
    var seed: [32]u8 = undefined;
    defer std.crypto.secureZero(u8, &seed);
    const hex = std.mem.trim(u8, bytes, " \r\n\t");
    if (hex.len != 64) return error.InvalidSeed;
    _ = try std.fmt.hexToBytes(&seed, hex);
    return transit.Ed25519.KeyPair.generateDeterministic(seed);
}

//! Bounded protocol HTTP client. No storage or provider credentials.
const std = @import("std");
pub const protocol = @import("transit_protocol");
const transit = protocol;
pub const max_body = protocol.max_body;
pub const Input = protocol.Input;
pub const View = protocol.View;
pub const Receipt = protocol.Receipt;

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
        // async permits inline execution, which would defeat the timeout when
        // no async worker is available. Fail if concurrency cannot be supplied.
        try select.concurrent(.response, Task.run, .{ self, path, signed });
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

fn largestFields(comptime T: type) T {
    return switch (@typeInfo(T)) {
        .int => |info| if (info.signedness == .signed) std.math.minInt(T) else std.math.maxInt(T),
        .bool => false,
        .optional => |info| largestFields(info.child),
        .array => |info| @splat(largestFields(info.child)),
        .@"struct" => |info| blk: {
            var value: T = undefined;
            inline for (info.field_names, info.field_types) |name, Field| @field(value, name) = largestFields(Field);
            break :blk value;
        },
        .@"enum" => |info| blk: {
            comptime var longest: usize = 0;
            inline for (info.field_names, 0..) |name, index| {
                if (comptime name.len > info.field_names[longest].len) longest = index;
            }
            break :blk @fromBackingInt(@intCast(info.field_values[longest]));
        },
        else => @compileError("Extend the wire-bound fixture for this type"),
    };
}

test "a full metadata view fits the bounded HTTP response" {
    // All optional metadata is present, all slots filled, every enum uses its
    // longest tag and integers use their widest decimal form (even wider than
    // legal protocol counters). Leave slack for shorter optional scalars/nulls.
    const value = largestFields(View);
    const bytes = try std.json.Stringify.valueAlloc(std.testing.allocator, value, .{});
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(bytes.len + 1024 <= max_body);
}

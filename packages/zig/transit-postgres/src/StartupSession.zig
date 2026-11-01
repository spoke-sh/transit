//! Pure startup, TLS negotiation and authentication continuation. The host
//! supplies effects and admits all command resources before successful login.
const std = @import("std");
const pg = @import("root.zig");
const w = pg.wire.Startup;
const Self = @This();
pub const Options = struct { tls: w.Tls, generation: u64, id: u32, secret: u32, cancellation_only: bool = false };
const State = enum { start, header, startup, upgrade, upgraded, lookup, selected, mechanisms, initial_header, initial_body, challenge, final_header, final_body, verified, admission, admitted, final, ok, parameters, key, ready, output, cancelled, failed, done };
options: Options,
continuation: w.Continuation,
backend: pg.Backend,
state: State = .start,
after_output: State = .done,
header: [8]u8 = @splat(0),
bytes: [8192]u8 = @splat(0),
length: usize = 0,
code: u32 = 0,
secure: bool = false,
gss_seen: bool = false,
ssl_seen: bool = false,
account: w.Name = .{},
database: w.Name = .{},
application: [256]u8 = @splat(0),
application_len: u16 = 0,
method: w.Method = .trust,
proof: [46]u8 = @splat(0),
parameter: usize = 0,
failure: ?anyerror = null,
pub fn init(allocator: std.mem.Allocator, options: Options) !Self {
    var result: Self = .{ .options = options, .continuation = try .init(options.generation), .backend = .{ .allocator = allocator, .maximum = 8192 } };
    result.backend.bytes = try .initCapacity(allocator, 2048);
    return result;
}
pub fn deinit(self: *Self) void {
    self.abort(error.WireSessionClosed);
    self.erase();
    self.backend.deinit();
}
pub fn erase(self: *Self) void {
    std.crypto.secureZero(u8, &self.bytes);
    std.crypto.secureZero(u8, &self.proof);
}
pub fn abort(self: *Self, err: anyerror) void {
    self.continuation.abort(err);
}
pub fn complete(self: *Self, token: w.Token, result: w.Result) !void {
    try self.continuation.complete(token, result);
}
fn send(self: *Self, bytes: []const u8, next: State) !void {
    self.after_output = next;
    self.state = .output;
    try self.continuation.issue(.{ .output = bytes });
}
fn fail(self: *Self, err: anyerror, state: [5]u8, message: []const u8) !void {
    self.failure = err;
    try self.send(try self.backend.failure(true, state, message, null), .failed);
}
fn input(self: *Self, bytes: []u8, next: State) !void {
    self.state = next;
    try self.continuation.issue(.{ .input = bytes });
}
fn passwordHeader(self: *Self, next: State) !void {
    self.erase();
    try self.input(self.header[0..5], next);
}
fn passwordBody(self: *Self, next: State) !void {
    try self.continuation.ok();
    if (self.header[0] != 'p') return error.InvalidAuthentication;
    const length = try pg.Frame.frameSize(self.header[0..5], 1024);
    self.length = length - 5;
    if (self.length == 0) return error.InvalidAuthentication;
    try self.input(self.bytes[0..self.length], next);
}
pub fn poll(self: *Self) !?w.Event {
    return self.advance() catch |err| {
        self.abort(err);
        return err;
    };
}
fn advance(self: *Self) !?w.Event {
    while (true) {
        if (try self.continuation.event()) |event| return event;
        switch (self.state) {
            .start => try self.input(&self.header, .header),
            .header => {
                try self.continuation.ok();
                self.length = try pg.Startup.frameSize(&self.header) - 8;
                self.code = std.mem.readInt(u32, self.header[4..8], .big);
                self.state = .startup;
                if (self.length != 0) try self.continuation.issue(.{ .input = self.bytes[0..self.length] });
            },
            .startup => {
                if (self.length != 0) try self.continuation.ok();
                if (self.code == pg.Frame.gss_request and !self.gss_seen and !self.ssl_seen) {
                    self.gss_seen = true;
                    try self.send("N", .start);
                    continue;
                }
                if (self.code == pg.Frame.ssl_request and !self.ssl_seen) {
                    self.ssl_seen = true;
                    try self.send(if (self.options.tls == .disabled) "N" else "S", if (self.options.tls == .disabled) .start else .upgrade);
                    continue;
                }
                if (self.options.tls == .required and !self.secure) {
                    try self.fail(error.TlsRequired, "28000".*, "TLS is required");
                    continue;
                }
                if (self.code == pg.Frame.cancel_request) {
                    self.state = .cancelled;
                    try self.continuation.issue(.{ .cancel = self.bytes[0..8].* });
                    continue;
                }
                if (self.options.cancellation_only) return error.GatewayConnectionCapacity;
                const startup = try pg.Startup.decode(self.code, self.bytes[0..self.length]);
                var unsupported: [pg.Startup.max_parameters][]const u8 = undefined;
                var count: usize = 0;
                for (startup.parameters[0..startup.count]) |parameter| {
                    if (std.mem.startsWith(u8, parameter.name, "_pq_.")) {
                        unsupported[count] = parameter.name;
                        count += 1;
                    } else if (std.mem.eql(u8, parameter.name, "user") or std.mem.eql(u8, parameter.name, "database") or std.mem.eql(u8, parameter.name, "application_name")) {} else if (std.mem.eql(u8, parameter.name, "client_encoding") and std.ascii.eqlIgnoreCase(parameter.value, "UTF8")) {} else return error.UnsupportedStartupSetting;
                }
                try self.account.set(startup.get("user").?);
                try self.database.set(startup.database());
                const application = startup.get("application_name") orelse "";
                @memcpy(self.application[0..application.len], application);
                self.application_len = @intCast(application.len);
                self.state = .lookup;
                if (startup.minor != 0 or count != 0) try self.send(try self.backend.negotiate(unsupported[0..count]), .lookup);
            },
            .upgrade => {
                self.state = .upgraded;
                try self.continuation.issue(.upgrade);
            },
            .upgraded => {
                try self.continuation.ok();
                self.secure = true;
                self.state = .start;
            },
            .lookup => {
                self.erase();
                self.state = .selected;
                try self.continuation.issue(.{ .lookup = .{ .account = self.account.slice(), .database = self.database.slice() } });
            },
            .selected => {
                const result = try self.continuation.take();
                if (result == .failed) {
                    try self.fail(result.failed, "28P01".*, "Authentication failed");
                    continue;
                }
                self.method = result.method;
                self.state = if (self.method == .password) .mechanisms else .admission;
            },
            .mechanisms => try self.send(try self.backend.authenticate(.mechanisms, ""), .initial_header),
            .initial_header => try self.passwordHeader(.initial_body),
            .initial_body => try self.passwordBody(.challenge),
            .challenge => {
                try self.continuation.ok();
                self.state = .final_header;
                try self.continuation.issue(.{ .scram_start = try pg.Frontend.saslInitial(self.bytes[0..self.length]) });
            },
            .final_header => {
                const result = try self.continuation.take();
                if (result == .failed) {
                    self.erase();
                    try self.fail(result.failed, "28P01".*, "Authentication failed");
                    continue;
                }
                self.erase();
                try self.send(try self.backend.authenticate(.challenge, result.challenge), .final_body);
            },
            .final_body => try self.passwordHeader(.verified),
            .verified => try self.passwordBody(.final),
            .final => {
                try self.continuation.ok();
                self.state = .admission;
                try self.continuation.issue(.{ .scram_finish = self.bytes[0..self.length] });
            },
            .admission => {
                if (self.method == .password) {
                    const result = try self.continuation.take();
                    self.erase();
                    if (result == .failed) {
                        try self.fail(result.failed, "28P01".*, "Authentication failed");
                        continue;
                    }
                    self.proof = result.proof;
                }
                self.state = .admitted;
                try self.continuation.issue(.admit);
            },
            .admitted => {
                const result = try self.continuation.take();
                if (result == .failed) {
                    try self.fail(result.failed, "28000".*, "Account or database access denied");
                    continue;
                }
                self.state = .ok;
                if (self.method == .password) try self.send(try self.backend.authenticate(.final, &self.proof), .ok);
            },
            .ok => try self.send(try self.backend.authenticate(.ok, ""), .parameters),
            .parameters => {
                const parameters = [_][2][]const u8{ .{ "server_version", "18.0-Transit" }, .{ "server_encoding", "UTF8" }, .{ "client_encoding", "UTF8" }, .{ "standard_conforming_strings", "on" }, .{ "integer_datetimes", "on" }, .{ "application_name", self.application[0..self.application_len] } };
                if (self.parameter == parameters.len) {
                    self.state = .key;
                    continue;
                }
                const parameter = parameters[self.parameter];
                self.parameter += 1;
                try self.send(try self.backend.parameter(parameter[0], parameter[1]), .parameters);
            },
            .key => try self.send(try self.backend.key(self.options.id, self.options.secret), .ready),
            .ready => try self.send(try self.backend.ready(.idle), .done),
            .output => {
                try self.continuation.ok();
                self.state = self.after_output;
            },
            .cancelled => {
                try self.continuation.ok();
                self.state = .done;
            },
            .failed => return self.failure.?,
            .done => {
                self.erase();
                return null;
            },
        }
    }
}

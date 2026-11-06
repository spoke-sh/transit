//! HTTP ingestion declarations and deterministic lifecycle. Values are evidence
//! bindings, never dispatch authority or a replacement for an owner's decision.
const std = @import("std");
const p = @import("root.zig");
const d = p.DataLifecycle;

pub const State = enum { published, authorized, active, suspended, retired };
pub const Command = enum { authorize, activate, suspend_source, resume_source, retire };
pub const Blocked = enum { none, authorization, definition_changed, unavailable_executor, storage, budget, unknown_attempt, incomplete_capture };
pub const Method = enum { GET };
pub const max_endpoint_bytes = 2048;
pub const max_path_bytes = 8192;

pub const Connection = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    endpoint: []const u8,
    pub const json_schema_fields = .{
        .endpoint = .{ .type = "string", .minLength = 1, .maxLength = max_endpoint_bytes },
    };
    pub fn validate(self: Connection) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        if (self.interpretation.object.branch != 1) return error.InvalidSourceDefinition;
        try validateEndpoint(self.endpoint);
    }
};

pub const Http = struct {
    method: Method,
    path: []const u8,
    poll_interval_ms: u64,
    request_timeout_ms: u64,
    response_max_bytes: u64,
    pub const json_schema_fields = .{
        .path = .{ .type = "string", .minLength = 1, .maxLength = max_path_bytes },
    };

    pub fn validate(self: Http) !void {
        if (self.poll_interval_ms == 0 or self.request_timeout_ms == 0 or self.response_max_bytes == 0)
            return error.InvalidSourceBudget;
        try validatePath(self.path);
    }
};

/// An origin is configuration, not permission or a DNS/transport route.
pub fn validateEndpoint(endpoint: []const u8) !void {
    if (endpoint.len == 0 or endpoint.len > max_endpoint_bytes) return error.InvalidSourceEndpoint;
    for (endpoint) |byte| if (byte <= 0x20 or byte >= 0x7f or byte == '\\') return error.InvalidSourceEndpoint;
    const uri = std.Uri.parse(endpoint) catch return error.InvalidSourceEndpoint;
    if ((!std.mem.eql(u8, uri.scheme, "https") and !std.mem.eql(u8, uri.scheme, "http")) or
        uri.host == null or uri.host.?.percent_encoded.len == 0 or uri.user != null or uri.password != null or
        uri.query != null or uri.fragment != null or (uri.path.percent_encoded.len != 0 and !std.mem.eql(u8, uri.path.percent_encoded, "/")))
        return error.InvalidSourceEndpoint;
}

pub fn validatePath(path: []const u8) !void {
    if (path.len == 0 or path.len > max_path_bytes or path[0] != '/' or (path.len > 1 and path[1] == '/')) return error.InvalidSourcePath;
    for (path) |byte| if (byte <= 0x20 or byte >= 0x7f or byte == '#' or byte == '\\') return error.InvalidSourcePath;
    // Retain exact origin-form bytes; never resolve an absolute URL or fragment.
    var i: usize = 0;
    while (i < path.len) : (i += 1) if (path[i] == '%') {
        if (i + 2 >= path.len or !std.ascii.isHex(path[i + 1]) or !std.ascii.isHex(path[i + 2])) return error.InvalidSourcePath;
        i += 2;
    };
}

pub const Definition = struct {
    definition: p.Growth.Definition,
    interpretation: d.Definition,
    connection: d.Definition,
    destination: d.Definition,
    executor: u64,
    http: Http,
    /// IDs in the destination schema, ordered by the capture envelope contract.
    columns: [7]u64,

    pub fn validate(self: Definition) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.interpretation.validate();
        try self.connection.validate();
        try self.destination.validate();
        try self.http.validate();
        const object = self.interpretation.object;
        if (object.branch != 1 or self.executor == 0) return error.InvalidSourceDefinition;
        for ([_]d.Definition{ self.connection, self.destination }) |dependency| {
            if (!std.meta.eql(object.scope, dependency.object.scope) or object.branch != dependency.object.branch or
                std.meta.eql(object, dependency.object)) return error.InvalidSourceDefinition;
        }
        if (std.meta.eql(self.connection.object, self.destination.object)) return error.InvalidSourceDefinition;
        for (self.columns, 0..) |column, i| {
            if (column == 0) return error.InvalidSourceDefinition;
            for (self.columns[0..i]) |previous| if (previous == column) return error.InvalidSourceDefinition;
        }
    }
};

pub const Control = struct {
    state: State,
    epoch: u64,
    pub fn initial() Control {
        return .{ .state = .published, .epoch = 1 };
    }
    pub fn validate(self: Control) !void {
        if (self.epoch == 0) return error.InvalidSourceControl;
    }
    pub fn apply(self: Control, command: Command) !Control {
        try self.validate();
        if (self.state == .retired) return error.SourceRetired;
        const state: State = switch (command) {
            .authorize => if (self.state == .published) .authorized else return error.InvalidSourceTransition,
            .activate => if (self.state == .authorized) .active else return error.InvalidSourceTransition,
            .suspend_source => if (self.state == .active) .suspended else return error.InvalidSourceTransition,
            .resume_source => if (self.state == .suspended) .active else return error.InvalidSourceTransition,
            .retire => .retired,
        };
        return .{ .state = state, .epoch = try std.math.add(u64, self.epoch, 1) };
    }
};

pub const AttemptState = enum { scheduled, dispatching, captured, incomplete, unknown, closed_unknown, published, retired };
pub const Poll = struct {
    definition: p.Growth.Definition,
    source: d.Definition,
    operation: d.Operation,
    capture_id: [16]u8,
    sequence: u64,
    control_epoch: u64,
    due_ms: u64,
    state: AttemptState,

    pub fn validate(self: Poll) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.source.validate();
        try self.operation.validate();
        if (self.sequence == 0 or self.control_epoch == 0 or std.mem.allEqual(u8, &self.capture_id, 0) or
            !std.meta.eql(self.source.object.scope, self.operation.scope)) return error.InvalidSourcePoll;
    }
    pub fn requireDispatch(self: Poll, source: d.Definition, current: Control) !void {
        try self.validate();
        try source.validate();
        try current.validate();
        if (!std.meta.eql(self.source, source) or current.state != .active or current.epoch != self.control_epoch) return error.SourceFenced;
        if (self.state != .scheduled) return error.SourceAttemptAlreadyStarted;
    }
    /// Durable owners record the transition before dispatch. Transport recovery
    /// cannot move dispatching/unknown back to scheduled or authorize a resend.
    pub fn transition(self: Poll, next: AttemptState) !Poll {
        try self.validate();
        const allowed = switch (self.state) {
            .scheduled => next == .dispatching or next == .retired,
            .dispatching => next == .captured or next == .incomplete or next == .unknown,
            .captured => next == .published or next == .retired,
            .unknown => next == .closed_unknown,
            .incomplete, .closed_unknown, .published, .retired => false,
        };
        if (!allowed) return error.InvalidSourceAttemptTransition;
        var result = self;
        result.state = next;
        return result;
    }
    pub fn settled(self: Poll) bool {
        return switch (self.state) {
            .incomplete, .closed_unknown, .published, .retired => true,
            .scheduled, .dispatching, .captured, .unknown => false,
        };
    }
    /// Reconciliation may recover an already sealed original capture, never
    /// resend. The owner must separately verify its retained terminal evidence.
    pub fn reconcileCapture(self: Poll, source: Definition, capture: Capture) !Poll {
        try self.validate();
        if (self.state != .unknown) return error.InvalidSourceAttemptTransition;
        var result = self;
        result.state = .captured;
        try capture.requirePoll(source, result);
        return result;
    }
    pub fn nextDue(self: Poll, terminal_ms: u64, interval_ms: u64) !u64 {
        try self.validate();
        if (!self.settled() or self.state == .retired) return error.SourcePollUnsettled;
        if (interval_ms == 0 or terminal_ms < self.due_ms) return error.InvalidSourceTime;
        return std.math.add(u64, terminal_ms, interval_ms) catch error.InvalidSourceTime;
    }
};

/// Only a fully verified body can produce an observation. The storage owner
/// must retain its paged manifest; this descriptor alone does not retain bytes.
pub const Capture = struct {
    definition: p.Growth.Definition,
    source: d.Definition,
    connection: d.Definition,
    destination: d.Definition,
    operation: d.Operation,
    capture_id: [16]u8,
    sequence: u64,
    observed_at_ms: u64,
    http_status: u16,
    body_bytes: u64,
    body_sha256: [32]u8,
    manifest: d.Content,

    pub fn validate(self: Capture) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.source.validate();
        try self.connection.validate();
        try self.destination.validate();
        try self.operation.validate();
        try self.manifest.validate();
        if (self.http_status < 200 or self.http_status > 599 or self.sequence == 0 or self.manifest.bytes == 0 or
            std.mem.allEqual(u8, &self.capture_id, 0)) return error.InvalidSourceCapture;
        for ([_]d.Object{ self.source.object, self.connection.object, self.destination.object }) |object| {
            if (!std.meta.eql(object.scope, self.operation.scope) or object.branch != self.source.object.branch) return error.InvalidSourceCapture;
        }
        if (self.body_bytes == 0) {
            var empty: [32]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash("", &empty, .{});
            if (!std.mem.eql(u8, &empty, &self.body_sha256)) return error.InvalidSourceCapture;
        }
    }
    pub fn requirePoll(self: Capture, source: Definition, poll: Poll) !void {
        try self.validate();
        try source.validate();
        try poll.validate();
        if (poll.state != .captured or !std.meta.eql(self.source, source.interpretation) or
            !std.meta.eql(self.source, poll.source) or !std.meta.eql(self.connection, source.connection) or
            !std.meta.eql(self.destination, source.destination) or !std.meta.eql(self.operation, poll.operation) or
            !std.mem.eql(u8, &self.capture_id, &poll.capture_id) or self.sequence != poll.sequence or
            self.body_bytes > source.http.response_max_bytes or self.observed_at_ms < poll.due_ms)
            return error.InvalidSourceCapture;
    }
};

pub const SchemaTypes = struct {
    connection: Connection,
    declaration: Definition,
    control: Control,
    poll: Poll,
    capture: Capture,
};

test "source neutral fixture binds complete capture to original poll and exact definitions" {
    const t = std.testing;
    const parsed = try p.Json.parseFromSlice(SchemaTypes, t.allocator, @embedFile("fixtures/source-v1.json"));
    defer parsed.deinit();
    const value = parsed.value;
    try value.connection.validate();
    try value.declaration.validate();
    try value.control.validate();
    try value.capture.requirePoll(value.declaration, value.poll);
    var changed = value.capture;
    changed.operation.operation += 1;
    try t.expectError(error.InvalidSourceCapture, changed.requirePoll(value.declaration, value.poll));
    changed = value.capture;
    changed.destination.revision += 1;
    try t.expectError(error.InvalidSourceCapture, changed.requirePoll(value.declaration, value.poll));
    changed = value.capture;
    changed.body_bytes = value.declaration.http.response_max_bytes + 1;
    try t.expectError(error.InvalidSourceCapture, changed.requirePoll(value.declaration, value.poll));
    changed = value.capture;
    changed.body_sha256[0] ^= 1;
    try t.expectError(error.InvalidSourceCapture, changed.validate());
    var poll = value.poll;
    poll.state = .unknown;
    try t.expectError(error.InvalidSourceCapture, value.capture.requirePoll(value.declaration, poll));
}

test "source original attempt never returns to scheduled and unknown blocks successors" {
    const t = std.testing;
    const parsed = try p.Json.parseFromSlice(SchemaTypes, t.allocator, @embedFile("fixtures/source-v1.json"));
    defer parsed.deinit();
    var poll = parsed.value.poll;
    poll.state = .scheduled;
    try poll.requireDispatch(parsed.value.declaration.interpretation, parsed.value.control);
    try t.expectError(error.SourceFenced, poll.requireDispatch(parsed.value.declaration.interpretation, try parsed.value.control.apply(.suspend_source)));
    var replaced = parsed.value.declaration.interpretation;
    replaced.revision += 1;
    try t.expectError(error.SourceFenced, poll.requireDispatch(replaced, parsed.value.control));
    poll = try poll.transition(.dispatching);
    try t.expectError(error.SourceAttemptAlreadyStarted, poll.requireDispatch(parsed.value.declaration.interpretation, parsed.value.control));
    try t.expectError(error.InvalidSourceAttemptTransition, poll.transition(.scheduled));
    poll = try poll.transition(.unknown);
    try t.expectError(error.SourcePollUnsettled, poll.nextDue(10000, 300000));
    try t.expectError(error.InvalidSourceAttemptTransition, poll.transition(.captured));
    try t.expectEqual(AttemptState.captured, (try poll.reconcileCapture(parsed.value.declaration, parsed.value.capture)).state);
    var foreign = parsed.value.capture;
    foreign.sequence += 1;
    try t.expectError(error.InvalidSourceCapture, poll.reconcileCapture(parsed.value.declaration, foreign));
    poll = try poll.transition(.closed_unknown);
    try t.expectEqual(@as(u64, 310000), try poll.nextDue(10000, 300000));
    try t.expectError(error.InvalidSourceTime, poll.nextDue(poll.due_ms - 1, 1));
    try t.expectError(error.InvalidSourceTime, poll.nextDue(std.math.maxInt(u64), 1));
}

test "source controls fence workers and retirement is permanent" {
    const t = std.testing;
    // Rows: published, authorized, active, suspended, retired.
    // Columns: authorize, activate, suspend, resume, retire.
    const expected = [_][5]?State{
        .{ .authorized, null, null, null, .retired },
        .{ null, .active, null, null, .retired },
        .{ null, null, .suspended, null, .retired },
        .{ null, null, null, .active, .retired },
        .{ null, null, null, null, null },
    };
    inline for (std.meta.tags(State), 0..) |state, row| {
        inline for (std.meta.tags(Command), 0..) |command, column| {
            const before: Control = .{ .state = state, .epoch = 9 };
            if (expected[row][column]) |next| {
                try t.expectEqual(Control{ .state = next, .epoch = 10 }, try before.apply(command));
            } else try t.expectError(if (state == .retired) error.SourceRetired else error.InvalidSourceTransition, before.apply(command));
        }
    }
    var control: Control = .initial();
    try t.expectError(error.InvalidSourceTransition, control.apply(.activate));
    control = try control.apply(.authorize);
    control = try control.apply(.activate);
    try t.expectEqual(@as(u64, 3), control.epoch);
    control = try control.apply(.suspend_source);
    control = try control.apply(.resume_source);
    control = try control.apply(.retire);
    inline for (@typeInfo(Command).@"enum".field_names) |name| try t.expectError(error.SourceRetired, control.apply(@field(Command, name)));
    try t.expectError(error.Overflow, (Control{ .state = .active, .epoch = std.math.maxInt(u64) }).apply(.retire));
}

test "HTTP source endpoint and path cannot replace the origin or inject headers" {
    try validateEndpoint("https://earthquake.usgs.gov");
    try validateEndpoint("http://127.0.0.1:8080/");
    for ([_][]const u8{ "https://user:secret@example.com", "https://example.com/path", "https://example.com?x=1", "https://example.com#x", "https://", "file:///tmp/feed", "https://a\\b" }) |value|
        try std.testing.expectError(error.InvalidSourceEndpoint, validateEndpoint(value));
    try validatePath("/feed?q=a%20b");
    for ([_][]const u8{ "", "//elsewhere/feed", "https://elsewhere/feed", "/feed#fragment", "/a\r\nInjected: value", "/bad%", "/bad%xx", "/a\\b" }) |value|
        try std.testing.expectError(error.InvalidSourcePath, validatePath(value));
}

test "HTTP source text bounds agree with the declared schema capacities" {
    // A long, zero-padded port keeps the host within URI's independent bound.
    var endpoint: [2049]u8 = @splat('0');
    @memcpy(endpoint[0..9], "http://a:");
    endpoint[2046] = '8';
    try validateEndpoint(endpoint[0..2048]);
    try std.testing.expectError(error.InvalidSourceEndpoint, validateEndpoint(&endpoint));
    var path: [8193]u8 = @splat('a');
    path[0] = '/';
    try validatePath(path[0..8192]);
    try std.testing.expectError(error.InvalidSourcePath, validatePath(&path));
}

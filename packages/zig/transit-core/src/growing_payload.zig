//! Standalone immutable payload intents and durable deletion evidence.
const p = @import("root.zig").protocol;
const g = p.Growth;
const growth = @import("growing.zig");
const c = @import("catalog.zig");
pub fn get(engine: anytype, ref: p.PayloadRef) !g.Payload {
    var current = try engine.state();
    const value = (try current.get(g.Payload, growth.address(.payload, ref.payload))) orelse return error.UnknownPayload;
    if (value.pid != ref.pid) return error.Forbidden;
    return value;
}
pub fn apply(engine: anytype, candidate: anytype, request: g.Request, now: ?@import("Time.zig").Sample) !void {
    const position = engine.head.position;
    switch (request.command) {
        .declare_payload => |command| {
            const process = try engine.process(command.pid);
            try engine.executable(process, now, false);
            if (process.work_before_ms != null) return error.UnsupportedPayloadLifetime;
            if (command.bytes == 0 or command.bytes > p.max_payload_bytes) return error.InvalidPayload;
            try candidate.put(growth.address(.payload, position), g.Payload{ .id = position, .pid = command.pid, .publisher = request.principal, .sha256 = command.sha256, .bytes = command.bytes, .allow_delete = command.allow_delete });
            try candidate.put(try c.key(.payloads_by_pid, command.pid, position, ""), position);
        },
        .payload_ready, .retire_payload, .payload_deleted => |ref| {
            var value = try get(engine, ref);
            switch (request.command) {
                .payload_ready => {
                    if (value.publisher != request.principal) return error.Forbidden;
                    if (value.phase != .creating) return error.PayloadPhase;
                    value.phase = .ready;
                },
                .retire_payload => {
                    if (!value.allow_delete) return error.RetentionNotEnabled;
                    if ((try engine.process(ref.pid)).lifecycle == .running) return error.PayloadInUse;
                    if (value.phase != .ready) return error.PayloadPhase;
                    value.phase = .retiring;
                    value.retired_at = position;
                },
                .payload_deleted => {
                    if (value.phase != .retiring) return error.PayloadPhase;
                    value.phase = .deleted;
                    value.deleted_at = position;
                },
                else => unreachable,
            }
            try candidate.put(growth.address(.payload, value.id), value);
        },
        else => unreachable,
    }
}

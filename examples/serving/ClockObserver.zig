//! Explicit deployment clock and bounded expired-session maintenance. At most
//! one frozen native send is outstanding; no target-wide quiescence is required.
const std = @import("std");
const serving = @import("transit_serving");
const p = serving.protocol;
const client = serving.station.client;
pub const Configuration = struct { ingress: u64, resource: u64, interval_ms: u32 = 5000 };
const State = struct {
    pending: ?p.Growth.SignedRequest = null,
    position: ?u64 = null,
    restart_fence: ?u64 = null,
    next_sample: i64 = 0,
    maintenance: bool = false,
};
pub fn run(io: std.Io, wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, configuration: Configuration) !void {
    if (configuration.interval_ms < 1000 or configuration.interval_ms > 5000) return error.InvalidClockInterval;
    try serving.Model.identity(configuration.ingress);
    try serving.Model.identity(configuration.resource);
    var state: State = .{};
    while (true) {
        step(wire, realm, principal, key, configuration, &state, io) catch |err| {
            if (err == error.AccessDenied or err == error.InvalidClockInterval or err == error.RetiredProcess) return err;
            if ((err == error.Rejected or err == error.Conflict) and wire.last_rejection != .StaleStateResource and wire.last_rejection != .QueryExpired and wire.last_rejection != .AuthorityUnavailable) return err;
            // Retain exactly one frozen command through unavailable/unknown I/O.
        };
        // Receipt polling cannot double the sampling interval when an owner is
        // briefly busy. Sampling has its own deadline, independent of polling.
        const remaining = state.next_sample - std.Io.Clock.awake.now(io).toMilliseconds();
        try io.sleep(.fromMilliseconds(if (state.position != null or state.pending != null or state.maintenance or remaining <= 0) 250 else @min(remaining, configuration.interval_ms)), .awake);
    }
}
fn expired(resources: client.ResourceReader, config: Configuration, now: u64) !?serving.ReactiveModel.Command {
    const active = try resources.readBatch(config.resource, null, &.{serving.Model.key('L', 0, 0)});
    if (active.resource.writer != config.ingress) return error.AccessDenied;
    const slots = (try serving.ReactiveService.active(&active)).slots;
    var keys: [serving.ReactiveModel.max_sessions]p.Value = undefined;
    var count: usize = 0;
    for (slots) |slot| if (slot.session != 0) {
        keys[count] = serving.Model.key('S', slot.principal, slot.session);
        count += 1;
    };
    if (count == 0) return null;
    const sessions = try resources.readBatch(config.resource, active.resource.revision, keys[0..count]);
    for (slots) |slot| if (slot.session != 0) {
        const session = (try serving.ReactiveService.session(&sessions, slot.principal, slot.session)) orelse return error.InvalidServingRecord;
        if (session.phase == .open and session.lease_before_ms <= now) return .{ .expire = .{ .principal = slot.principal, .identity = .{ .session = session.session, .generation = session.generation }, .observed_ms = now } };
    };
    return null;
}
fn step(wire: *client.Client, realm: u64, principal: u64, key: p.Ed25519.KeyPair, config: Configuration, state: *State, io: std.Io) !void {
    if (state.pending) |signed| {
        state.position = (try wire.submit(signed)).position;
        state.pending = null;
    }
    const resources: client.ResourceReader = .{ .wire = wire, .realm = realm, .principal = principal, .key = key };
    const observed = try resources.query(.{ .process = config.ingress });
    const process = observed.body.process;
    if (process.process.lifecycle != .running) return error.RetiredProcess;
    // Capture the restart prefix once. Later controls cannot move this fence.
    if (state.restart_fence == null) state.restart_fence = observed.position;
    if (process.input) |input| if (input.position <= (state.position orelse state.restart_fence.?)) return;
    state.position = null;
    const now = std.Io.Clock.real.now(io).toMilliseconds();
    if (now <= 0) return error.ClockUnavailable;
    const awake = std.Io.Clock.awake.now(io).toMilliseconds();
    const command: serving.ReactiveModel.Command = if (awake >= state.next_sample) blk: {
        break :blk .{ .observe_clock = @intCast(now) };
    } else if (state.maintenance) blk: {
        // At most four active slots; each expiry is a separate conditional turn.
        // A concurrent renewal wins through ReactiveService's deadline check.
        // Clock progress takes priority over further maintenance next iteration.
        break :blk (try expired(resources, config, @intCast(now))) orelse {
            state.maintenance = false;
            return;
        };
    } else return;
    const identity = try resources.query(.identity);
    if (identity.body.identity.pid != config.ingress) return error.AccessDenied;
    const payload = try (serving.Model.Command{ .reactive = command }).encode();
    state.pending = try p.Growth.sign(.{ .realm = realm, .principal = principal, .sequence = try std.math.add(u64, identity.principal_sequence, 1), .command = .{ .send = .{ .pid = config.ingress, .value = try (serving.station.Frame{ .kind = .cast, .payload = payload }).encode() } } }, key);
    if (command == .observe_clock) {
        state.next_sample = awake + config.interval_ms;
        state.maintenance = true;
    }
    state.position = (try wire.submit(state.pending.?)).position;
    state.pending = null;
}

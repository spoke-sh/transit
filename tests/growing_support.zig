//! Public-client provisioning shared by growing service proofs.
const std = @import("std");
const client = @import("transit_station").client;
const p = client.protocol;
const g = p.Growth;
pub fn Admin(comptime realm: u64) type {
    return struct {
        const Self = @This();
        pub const Provision = struct { pid: u64, resource: u64, generation: u64 };
        wire: *client.Client,
        key: p.Ed25519.KeyPair,
        sequence: u64 = 0,
        pub fn query(self: *Self, kind: @FieldType(g.Query, "kind")) !g.Response {
            const io = self.wire.http.io;
            const start = std.Io.Clock.awake.now(io);
            while (true) return self.wire.query(.{ .realm = realm, .principal = 0, .kind = kind }, self.key) catch |err| {
                if (!client.Client.unavailable(err) or start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() >= 10000) return err;
                try io.sleep(.fromMilliseconds(25), .awake);
                continue;
            };
        }
        pub fn submit(self: *Self, command: g.Command) !u64 {
            // An uncertain admission keeps exactly the same signed request.
            const frozen = try g.sign(.{ .realm = realm, .principal = 0, .sequence = self.sequence + 1, .command = command }, self.key);
            const io = self.wire.http.io;
            const start = std.Io.Clock.awake.now(io);
            const receipt = while (true) {
                break self.wire.submit(frozen) catch |err| {
                    if (!client.Client.unavailable(err) or start.durationTo(std.Io.Clock.awake.now(io)).toMilliseconds() >= 10000) return err;
                    try io.sleep(.fromMilliseconds(25), .awake);
                    continue;
                };
            };
            self.sequence += 1;
            return receipt.position;
        }
        pub fn send(self: *Self, pid: u64, index: i64) !void {
            _ = try self.submit(.{ .send = .{ .pid = pid, .value = try (@import("transit_station").Frame{ .kind = .cast, .payload = p.Value.integer(index) }).encode() } });
        }
        pub fn provision(self: *Self, principal: u64, key: p.Ed25519.KeyPair) !Provision {
            return self.provisionReader(principal, key, null);
        }
        /// Establish a scoped reader's optional foreign association before its
        /// first activation. The association never replaces the resource grant.
        pub fn provisionReader(self: *Self, principal: u64, key: p.Ed25519.KeyPair, read_resource: ?u64) !Provision {
            const pid = try self.submit(.{ .spawn = .{} });
            _ = try self.submit(.{ .grant = .{ .subject = principal, .public_key = key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.execute) | p.permission(.publish), .pid = pid } });
            const resource = try self.submit(.{ .create_resource = .{ .writer = pid } });
            for ([_]u64{ 0, principal }) |subject| _ = try self.submit(.{ .grant_resource = .{ .resource = resource, .subject = subject, .permissions = p.State.all_permissions } });
            _ = try self.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("state"), .resource = resource } });
            if (read_resource) |id| {
                _ = try self.submit(.{ .grant_resource = .{ .resource = id, .subject = principal, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
                _ = try self.submit(.{ .associate = .{ .pid = pid, .name = try p.Value.init("requests"), .resource = id, .required = false } });
            }
            const generation: u64 = if (read_resource != null) 2 else 1;
            _ = try self.submit(.{ .own = .{ .pid = pid, .expected_generation = generation, .worker = principal } });
            return .{ .pid = pid, .resource = resource, .generation = generation + 1 };
        }
    };
}

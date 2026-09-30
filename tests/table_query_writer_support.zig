//! Native fixture provisioning through the same public owners used by callers.
const std = @import("std");
const q = @import("transit_query");
const s = @import("transit_station");
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(46);
const limits: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };
fn path(init: std.process.Init, directory: []const u8, name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(init.arena.allocator(), "{s}/{s}", .{ directory, name });
}
fn save(init: std.process.Init, directory: []const u8, name: []const u8, value: anytype) !void {
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try path(init, directory, name), .data = try std.json.Stringify.valueAlloc(init.arena.allocator(), value, .{}) });
}
fn seed(init: std.process.Init, directory: []const u8, name: []const u8, byte: u8) ![]const u8 {
    const location = try path(init, directory, name);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = location, .data = &std.fmt.bytesToHex(@as([32]u8, @splat(byte)), .lower) });
    return location;
}
pub fn print(init: std.process.Init, value: anytype) !void {
    var buffer: [4096]u8 = undefined;
    var out = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(value, .{}, &out.interface);
    try out.interface.writeByte('\n');
    try out.interface.flush();
}
fn send(wire: *s.client.Client, pid: u64, payload: p.Value) !p.Receipt {
    const key = try p.Ed25519.KeyPair.generateDeterministic(@splat(12));
    const current = try wire.query(.{ .realm = 46, .principal = 42, .kind = .capabilities }, key);
    return wire.submit(try p.Growth.sign(.{ .realm = 46, .principal = 42, .sequence = current.principal_sequence + 1, .command = .{ .send = .{ .pid = pid, .value = try (s.Frame{ .kind = .cast, .payload = payload }).encode() } } }, key));
}
pub fn provision(init: std.process.Init, url: []const u8, wire: *s.client.Client, admin: *Admin, directory: []const u8) !void {
    const writer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(8));
    const requester_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(9));
    const caller_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(10));
    const courier_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(11));
    const initializer_key = try p.Ed25519.KeyPair.generateDeterministic(@splat(12));
    const requester = try admin.provision(65537, requester_key);
    const writer = try admin.provisionReader(65536, writer_key, requester.resource);
    _ = try admin.submit(.{ .grant = .{ .subject = 1234, .public_key = caller_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) } });
    _ = try admin.submit(.{ .grant = .{ .subject = 65538, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
    _ = try admin.submit(.{ .grant = .{ .subject = 42, .public_key = initializer_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send), .pid = writer.pid } });
    for ([_]u64{ writer.resource, requester.resource }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = 1234, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
    const config: q.TableQueryWriter.Configuration = .{ .writer = .{ .resource = writer.resource, .initializer = 42, .principal = 1234, .permissions = 7, .value_type = .utf8 }, .peer = requester.pid, .requests = requester.resource, .allow = true, .limits = limits };
    const connection: q.UnifiedClient.Connection = .{ .realm = 46, .principal = 1234, .source = writer.pid, .resource = writer.resource, .requester = requester.pid, .requests = requester.resource };
    try save(init, directory, "combined.json", config);
    var bundle_bytes: [q.Bundle.max_bytes]u8 = undefined;
    const bundle: q.Bundle = .{ .source = try config.definition(), .plan = .{ .projection = &.{ 0, 1 } }, .limits = limits };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = try path(init, directory, "bundle.bin"), .data = try bundle.encode(&bundle_bytes) });
    try save(init, directory, "client.json", .{ .url = url, .connection = connection, .kind = "table" });
    try save(init, directory, "source.json", .{ .url = url, .realm = 46, .principal = 65536, .pid = writer.pid, .generation = writer.generation, .seed_file = try seed(init, directory, "source.seed", 8), .activation_directory = directory, .interval_ms = 10, .role = .{ .table_query_writer = config } });
    try save(init, directory, "requester.json", .{ .url = url, .realm = 46, .principal = 65537, .pid = requester.pid, .generation = requester.generation, .seed_file = try seed(init, directory, "requester.seed", 9), .activation_directory = directory, .interval_ms = 10, .role = .{ .unified_requester = .{ .principal = @as(u64, 1234), .source = writer.pid } } });
    try save(init, directory, "courier.json", .{ .url = url, .realm = 46, .principal = 65538, .seed_file = try seed(init, directory, "courier.seed", 11), .interval_ms = 10, .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
    try save(init, directory, "shell.json", .{ .url = url, .seed_file = try seed(init, directory, "caller.seed", 10), .connection = connection, .workspace = q.Workspace.Config{ .name = "items", .source = try q.Values.Source.fromNative(init.arena.allocator(), try config.definition()), .limits = try q.Values.Limits.fromNative(init.arena.allocator(), limits) } });
    _ = try send(wire, writer.pid, try config.initializeCommand());
    _ = try wire.submit(try p.Growth.sign(.{ .realm = 46, .principal = 1234, .sequence = 1, .command = .{ .send = .{ .pid = requester.pid, .value = try (s.Frame{ .kind = .cast, .payload = try q.UnifiedRequest.Command.encode(.initialize) }).encode() } } }, caller_key));
    return print(init, connection);
}
pub fn execute(init: std.process.Init, wire: *s.client.Client, admin: *Admin, directory: []const u8, command: []const u8, connection: q.UnifiedClient.Connection) !void {
    if (std.mem.eql(u8, command, "combined-progress")) {
        // Progress polling needs the current input only. Reading Table policies
        // here opens a resource view that the very turn being polled may change.
        const process = (try admin.query(.{ .process = connection.source })).body.process;
        return print(init, .{ .pending = if (process.input) |value| value.position else @as(?u64, null) });
    }
    if (std.mem.eql(u8, command, "combined-deliver")) {
        for (0..32) |_| {
            var after: ?u64 = null;
            const basis = (try admin.query(.capabilities)).position;
            for (0..4096) |_| {
                const response = admin.query(.{ .outputs = .{ .after = after, .position = basis } }) catch |err| {
                    // Like the real courier, restart only an expired read. No
                    // signed delivery has been prepared or sent at this point.
                    if (err == error.Conflict and wire.last_rejection == .QueryExpired) break;
                    return err;
                };
                const page = response.body.outputs;
                for (page.entries) |slot| if (slot) |output| {
                    if (output.phase == .pending and (output.destination == connection.source or output.destination == connection.requester)) return print(init, .{ .delivered = try admin.submit(.{ .deliver = output.id }) });
                };
                after = page.next orelse return print(init, .{ .delivered = @as(?u64, null) });
            } else return error.ProofDeliveryBudgetExceeded;
        }
        return error.ProofDeliveryReadConflict;
    }
    const encoded = try std.Io.Dir.cwd().readFileAlloc(init.io, try path(init, directory, "combined.json"), init.arena.allocator(), .limited(8192));
    const config = try std.json.parseFromSliceLeaky(q.TableQueryWriter.Configuration, init.arena.allocator(), encoded, .{});
    var reader = try (s.client.ResourceReader{ .wire = wire, .realm = 46, .principal = 0, .key = admin.key }).open(connection.resource);
    if (std.mem.eql(u8, command, "combined-state")) {
        var source: q.UnifiedBehavior.Source = .{ .peer = config.peer, .initializer = config.writer.initializer, .resources = undefined, .adapter = &.{}, .workspace = &.{}, .cancellation = undefined };
        var owner: q.TableQueryWriter = .{ .configuration = config, .source = &source };
        const process = (try admin.query(.{ .process = connection.source })).body.process;
        return print(init, .{ .phase = try owner.phase(&reader), .pending = if (process.input) |value| value.position else @as(?u64, null), .query = try q.UnifiedCapture.policy(&reader, config.peer), .mutation = try q.TableMutationAdmission.policy(&reader, config.writer.principal, config.writer.table) });
    }
    if (std.mem.eql(u8, command, "combined-initialize")) return print(init, try send(wire, connection.source, try config.initializeCommand()));
    if (std.mem.eql(u8, command, "combined-query-revoke") or std.mem.eql(u8, command, "combined-query-restore")) {
        var policy = (try q.UnifiedCapture.policy(&reader, config.peer)).?;
        const expected = policy.revision;
        policy.revision += 1;
        policy.allow = std.mem.eql(u8, command, "combined-query-restore");
        return print(init, try send(wire, connection.source, try (q.TableQueryWriter.QueryPolicyChange{ .resource = connection.resource, .expected_revision = expected, .policy = policy }).encode()));
    }
    if (std.mem.eql(u8, command, "combined-mutation-revoke") or std.mem.eql(u8, command, "combined-mutation-restore")) {
        var policy = (try q.TableMutationAdmission.policy(&reader, config.writer.principal, config.writer.table)).?;
        const expected = policy.revision;
        policy.revision += 1;
        policy.permissions = if (std.mem.eql(u8, command, "combined-mutation-restore")) 7 else 0;
        return print(init, try send(wire, connection.source, try (q.TableMutationWriter.PolicyChange{ .resource = connection.resource, .expected_revision = expected, .policy = policy }).encode()));
    }
    return error.InvalidCombinedCommand;
}

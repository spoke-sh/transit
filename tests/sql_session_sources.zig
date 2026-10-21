//! Real KV and Document owners for native-session deployment proofs. Reuses
//! the established source seed; only public provisioning operations run here.
const std = @import("std");
const g = @import("transit_sql");
const q = g.query;
const s = g.station;
const p = s.protocol;
const Admin = @import("growing_support.zig").Admin(46);
const support = @import("typed_table_native.zig");
const unified = @import("unified_query.zig");
const drive = @import("catalog_query_support.zig").drive;
const budgets: q.Bundle.Limits = .{ .pages = 1000, .segments = 100, .result_bytes = 1048576 };

pub fn provision(init: std.process.Init, wire: *s.client.Client, admin: *Admin, directory: []const u8, login_role: u64, selected_role: ?u64) !void {
    // Source callers inspect the public requester head themselves. The Table
    // SQL fixture normally delegates that inspection to its private reader.
    _ = try admin.authorization(.{ .grant = .{ .object = .{ .kind = .realm, .id = 0 }, .grantee = login_role, .privileges = p.permission(.inspect) } });
    var sources: [2]g.Configuration.Source = undefined;
    inline for (.{ .{ unified.Kind.kv, @as(u64, 3000), @as(u8, 31) }, .{ unified.Kind.document, @as(u64, 3100), @as(u8, 41) } }, 0..) |entry, index| {
        const kind = entry[0];
        const principal = entry[1];
        const seed_byte = entry[2];
        const writer_key = try support.key(seed_byte);
        const requester_key = try support.key(seed_byte + 1);
        const caller_key = try support.key(seed_byte + 2);
        const courier_key = try support.key(seed_byte + 3);
        const requester = try admin.provision(principal + 1, requester_key);
        const writer = try admin.provisionReader(principal, writer_key, requester.resource);
        _ = try admin.authorization(.{ .bind_credential = .{ .principal = principal + 2, .role = login_role, .public_key = caller_key.public_key.toBytes() } });
        for ([_]u64{ writer.resource, requester.resource }) |resource| _ = try admin.submit(.{ .grant_resource = .{ .resource = resource, .subject = principal + 2, .permissions = p.State.permission(.inspect) | p.State.permission(.read) } });
        _ = try admin.submit(.{ .grant = .{ .subject = principal + 3, .public_key = courier_key.public_key.toBytes(), .permissions = p.permission(.inspect) | p.permission(.send) | p.permission(.delivery) } });
        var server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = principal, .pid = writer.pid, .generation = writer.generation, .key = writer_key }, "state");
        var seed: unified.Seed = .{ .kind = kind, .rows = 41, .peer = requester.pid, .requests = requester.resource, .initializer = principal };
        const handler: s.GenServer.Handler = .{ .context = &seed, .initialize = unified.Seed.initialize, .handle = unified.Seed.handle };
        try admin.send(writer.pid, -1);
        try drive(init, &server, handler);
        if (kind == .document) {
            for (1..14) |job| {
                std.debug.print("Seeding native session Document change {d}/13\n", .{job});
                try admin.send(writer.pid, @intCast(10000 + job));
                try drive(init, &server, handler);
                for ([_]usize{ 20000, 30000 }) |stage| for (0..10000) |_| {
                    try admin.send(writer.pid, @intCast(stage + job));
                    try drive(init, &server, handler);
                    if (seed.done) break;
                } else return error.DocumentDidNotFinish;
            }
        } else for (0..11) |part| {
            try admin.send(writer.pid, @intCast(part * 4));
            try drive(init, &server, handler);
        }
        try admin.send(writer.pid, -2);
        try drive(init, &server, handler);
        var request_server = try s.GenServer.init(.{ .client = wire, .realm = 46, .principal = principal + 1, .pid = requester.pid, .generation = requester.generation, .key = requester_key }, "state");
        var behavior: q.UnifiedBehavior.Requester = .{ .principal = principal + 2, .source = writer.pid };
        const connection: q.UnifiedClient.Connection = .{ .realm = 46, .principal = principal + 2, .source = writer.pid, .resource = writer.resource, .requester = requester.pid, .requests = requester.resource, .role = selected_role };
        var caller: q.UnifiedClient = .{ .wire = wire, .connection = connection, .key = caller_key };
        _ = try caller.submit(try caller.prepare(.initialize));
        try drive(init, &request_server, behavior.interface());
        _ = try admin.submit(.{ .own = .{ .pid = writer.pid, .expected_generation = writer.generation, .worker = principal } });
        _ = try admin.submit(.{ .own = .{ .pid = requester.pid, .expected_generation = requester.generation, .worker = principal + 1 } });
        const prefix = "session-" ++ @tagName(kind);
        inline for (.{ .{ "source", seed_byte }, .{ "requester", seed_byte + 1 }, .{ "caller", seed_byte + 2 }, .{ "courier", seed_byte + 3 } }) |key| try support.saveBytes(init, directory, prefix ++ "-" ++ key[0] ++ ".seed", &std.fmt.bytesToHex(@as([32]u8, @splat(key[1])), .lower));
        try support.save(init, directory, prefix ++ "-source.json", .{ .url = wire.url, .realm = 46, .principal = principal, .pid = writer.pid, .generation = writer.generation + 1, .seed_file = try support.path(init, directory, prefix ++ "-source.seed"), .activation_directory = directory, .role = .{ .unified_source = .{ .peer = requester.pid, .initializer = principal } } });
        try support.save(init, directory, prefix ++ "-requester.json", .{ .url = wire.url, .realm = 46, .principal = principal + 1, .pid = requester.pid, .generation = requester.generation + 1, .seed_file = try support.path(init, directory, prefix ++ "-requester.seed"), .activation_directory = directory, .role = .{ .unified_requester = behavior } });
        try support.save(init, directory, prefix ++ "-courier.json", .{ .url = wire.url, .realm = 46, .principal = principal + 3, .seed_file = try support.path(init, directory, prefix ++ "-courier.seed"), .role = .{ .courier = .{ .destinations = .{ writer.pid, requester.pid } } } });
        sources[index] = .{ .name = @tagName(kind), .database = "data", .connection = connection, .key_file = try support.path(init, directory, prefix ++ "-caller.seed"), .workspace = .{ .name = "items", .source = try q.Values.Source.fromNative(init.arena.allocator(), try unified.definition(kind, writer.resource)), .limits = try q.Values.Limits.fromNative(init.arena.allocator(), budgets) } };
    }
    try support.save(init, directory, "session-sources.json", sources);
}

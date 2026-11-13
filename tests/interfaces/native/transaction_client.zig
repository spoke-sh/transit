//! Independent data-only executable using the same exported public Zig module.
//! The build traverses every import and rejects Station, including in fixtures.
const std = @import("std");
const data = @import("transit_data_client");
const c = data.catalog;
const fixture = @import("fixture_direct_state_transaction");
const Profile = struct { definition: c.protocol.Growth.Definition, catalog: c.DirectCatalog.Configuration, role: u64 };

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.ExpectedUrlPhaseProfile;
    const bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, args[3], init.arena.allocator(), .limited(1024 * 1024));
    // The harness profile also has unrelated scenario fields. The three
    // mandatory fields here are never defaulted or inferred from an old profile.
    const parsed = try std.json.parseFromSlice(Profile, init.gpa, bytes, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();
    const profile = parsed.value;
    if (profile.definition != c.protocol.Growth.current_definition) return error.IncompatibleDefinition;
    var native = c.client.Client.init(init.gpa, init.io, args[1]);
    defer native.deinit();
    native.timeout_ms = 30000;
    var service = c.client.Client.init(init.gpa, init.io, args[1]);
    defer service.deinit();
    service.timeout_ms = 30000;
    const client: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &native, .service = &service, .connection = .{ .scope = profile.catalog.scope, .branch = 1, .audience = profile.catalog.audience, .principal = 101, .role = null }, .key = try c.protocol.Ed25519.KeyPair.generateDeterministic(@splat(29)) };
    var admin: @import("fixture_direct_client_admin").Admin = .{ .client = &native };
    const mixed = std.mem.startsWith(u8, args[2], "mixed-transaction-");
    const prefix = if (mixed) "mixed-transaction" else "state-transaction";
    const path = try std.fmt.allocPrint(init.arena.allocator(), "{s}.{s}", .{ args[3], prefix });
    if (std.mem.eql(u8, args[2], try std.fmt.allocPrint(init.arena.allocator(), "{s}-prepare", .{prefix}))) {
        try fixture.prepare(init, client, profile.role, path, mixed);
    } else if (std.mem.eql(u8, args[2], try std.fmt.allocPrint(init.arena.allocator(), "{s}-recover", .{prefix}))) {
        try fixture.recover(init, client, path);
    } else if (std.mem.eql(u8, args[2], try std.fmt.allocPrint(init.arena.allocator(), "{s}-verify", .{prefix}))) {
        try fixture.verify(init, client, path);
    } else if (std.mem.eql(u8, args[2], try std.fmt.allocPrint(init.arena.allocator(), "{s}-reads", .{prefix}))) {
        try @import("fixture_direct_transaction_reads").run(init, client, &admin, profile.role, path);
    } else return error.UnexpectedPhase;
}

//! Private proof adapter for direct catalog name resolution. The public CLI
//! remains server/console; native authorization owns publication of the plan.
const std = @import("std");
const c = @import("transit_catalog");
const p = c.protocol;
const Diagnostic = @import("cli_support").Diagnostic;
const Profile = struct {
    version: u8,
    definition: p.Growth.Definition,
    connection: c.DirectTableProtocol.Connection,
    namespace: u64,
    url: []const u8,
    seed_file: []const u8,
    request_timeout_ms: u32 = 5000,
};
pub fn run(init: std.process.Init, args: []const []const u8, diagnostic: *Diagnostic) !void {
    const options = try @import("fixture_operations_catalog_options").parse(args, diagnostic);
    if (options.mode != .@"compile-authorization" or options.flags.operation != null or options.flags.schema != null) return error.InvalidInvocation;
    const allocator = init.arena.allocator();
    diagnostic.atFile(options.flags.config.?);
    const absolute = try std.Io.Dir.cwd().realPathFileAlloc(init.io, options.flags.config.?, allocator);
    const tree = try @import("cli_support").Settings.read(init, absolute, diagnostic);
    const bytes = try std.json.Stringify.valueAlloc(allocator, tree, .{});
    const parsed = try p.Json.parseFromSlice(Profile, allocator, bytes);
    defer parsed.deinit();
    const profile = parsed.value;
    if (profile.version != 1 or profile.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
    try profile.connection.validate();
    try c.Model.nativeId(profile.namespace);
    const uri = try std.Uri.parse(profile.url);
    if (!(std.mem.eql(u8, uri.scheme, "http") or std.mem.eql(u8, uri.scheme, "https")) or uri.host == null or uri.user != null or uri.password != null or uri.query != null or uri.fragment != null or profile.url.len > 2048 or profile.request_timeout_ms == 0 or profile.request_timeout_ms > 60000 or profile.seed_file.len == 0) return error.InvalidConfiguration;
    const seed = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(absolute).?, profile.seed_file });
    var key = try c.client.readKey(init.gpa, init.io, seed);
    defer std.crypto.secureZero(u8, std.mem.asBytes(&key));
    var transport = c.client.Client.init(init.gpa, init.io, profile.url);
    defer transport.deinit();
    transport.timeout_ms = profile.request_timeout_ms;
    const client: c.DirectTableClient = .{ .allocator = init.gpa, .authority = &transport, .service = &transport, .connection = profile.connection, .key = key };
    diagnostic.atFile(options.flags.file.?);
    const sql = try std.Io.Dir.cwd().readFileAlloc(init.io, options.flags.file.?, allocator, .limited(4096));
    const result = .{ .authorization_plan = try c.TableValues.AuthorizationPlan.foreign(allocator, try c.DirectAuthorizationSql.compile(client, profile.namespace, sql, .{}, null)) };
    diagnostic.atFile(options.flags.output.?);
    try @import("fixture_operations_recovery_files").createBounded(init, options.flags.output.?, result, c.DirectTableBridge.max_input_bytes);
    var buffer: [8192]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer.interface };
    try p.Json.write(result, &encoder);
    try writer.interface.writeByte('\n');
    try writer.interface.flush();
}

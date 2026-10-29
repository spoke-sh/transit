const std = @import("std");
const Catalog = @import("Catalog.zig");
const c = @import("transit_catalog");
const t = std.testing;
const connection: c.DirectTableProtocol.Connection = .{
    .scope = .{ .realm = 46, .resource = 7, .catalog = std.math.maxInt(u64) },
    .branch = 1,
    .audience = 3,
    .principal = 17,
    .role = null,
};
const config: Catalog.Config = .{ .url = "http://127.0.0.1:1", .connection = connection, .timeout_ms = 100 };

fn binding(operation: u64) c.NameAssertion.Binding {
    return .{
        .definition = c.protocol.Growth.current_definition,
        .connection = connection,
        .operation = operation,
        .namespace = 1,
        .name = c.TableAuthority.Name.init("absent") catch unreachable,
        .action = .drop_if_exists,
        .expected = null,
        .intent = @splat(9),
    };
}

test "catalog constructor owns endpoint inputs and unwinds every allocation failure" {
    try t.checkAllAllocationFailures(t.allocator, struct {
        fn run(allocator: std.mem.Allocator) !void {
            var url = "http://127.0.0.1:1".*;
            var options = config;
            options.url = &url;
            var caller = try Catalog.init(allocator, t.io, options, @splat(10));
            defer caller.deinit();
            @memset(&url, 'x');
            try t.expectEqualStrings(config.url, caller.authority_url);
            try t.expectEqualStrings(config.url, caller.service_url);
        }
    }.run, .{});
}

test "catalog construction rejects invalid configuration without dispatch" {
    for ([_][]const u8{ "", "file:///tmp/a", "http://user@host", "http://host/?q=x", "http://host/#fragment" }) |url| {
        var options = config;
        options.url = url;
        try t.expectError(error.InvalidArgument, Catalog.init(t.allocator, t.io, options, @splat(10)));
        options = config;
        options.service_url = url;
        try t.expectError(error.InvalidArgument, Catalog.init(t.allocator, t.io, options, @splat(10)));
    }
    for ([_]u32{ 0, 60001 }) |timeout| {
        var options = config;
        options.timeout_ms = timeout;
        try t.expectError(error.InvalidArgument, Catalog.init(t.allocator, t.io, options, @splat(10)));
    }
}

test "catalog local work owns inputs and outcomes outlive replacement and client close" {
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    var caller = try Catalog.init(t.allocator, t.io, config, @splat(10));
    var retained: c.DirectTableBridge.Summary = undefined;
    {
        defer caller.deinit();
        const first = local: {
            var input: std.heap.ArenaAllocator = .init(t.allocator);
            defer input.deinit();
            const saved = try c.DirectTableValues.NameAssertion.foreign(input.allocator(), binding(std.math.maxInt(u64)));
            break :local try caller.call(&output, .{ .load = .{ .name_assertion = saved } });
        };
        try t.expect(!first.mutationAttempted());
        const loaded = first.value.result.loaded;
        retained = loaded;
        try t.expectEqualStrings("18446744073709551615", loaded.binding.name_assertion.operation);
        // Foreign scope must not replace the current local intent.
        var foreign = try c.DirectTableValues.NameAssertion.foreign(output.allocator(), binding(2));
        foreign.connection.principal = 18;
        const rejected = try caller.call(&output, .{ .load = .{ .name_assertion = foreign } });
        try t.expectEqual(error.CatalogIdentityConflict, rejected.value.failure.cause);
        try t.expect(!rejected.mutationAttempted());
        const forgotten = try caller.call(&output, .{ .forget = loaded.id });
        try t.expect(forgotten.value.result == .forgotten);
        try t.expectEqualStrings("absent", loaded.binding.name_assertion.name);
    }
    // Validate actual retained strings after native owner destruction.
    // The output arena, not the transport or active intent, owns their storage.
    try t.expectEqualStrings("18446744073709551615", retained.binding.name_assertion.operation);
    try t.expectEqualStrings("absent", retained.binding.name_assertion.name);
}

test "catalog output allocation failure preserves the previously selected intent" {
    var caller = try Catalog.init(t.allocator, t.io, config, @splat(10));
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const original = try c.DirectTableValues.NameAssertion.foreign(output.allocator(), binding(1));
    const replacement = try c.DirectTableValues.NameAssertion.foreign(output.allocator(), binding(2));
    const loaded = try caller.call(&output, .{ .load = .{ .name_assertion = original } });
    var failing: t.FailingAllocator = .init(t.allocator, .{ .fail_index = 0 });
    var exhausted: std.heap.ArenaAllocator = .init(failing.allocator());
    defer exhausted.deinit();
    const refused = try caller.call(&exhausted, .{ .load = .{ .name_assertion = replacement } });
    try t.expectEqual(error.OutOfMemory, refused.value.failure.cause);
    try t.expect(!refused.mutationAttempted());
    const forgotten = try caller.call(&output, .{ .forget = loaded.value.result.loaded.id });
    try t.expect(forgotten.value.result == .forgotten);
    try t.expectEqualStrings("1", loaded.value.result.loaded.binding.name_assertion.operation);
}

test "catalog concurrent call refuses and later calls do not inherit attempt diagnostics" {
    var caller = try Catalog.init(t.allocator, t.io, config, @splat(10));
    defer caller.deinit();
    var output: std.heap.ArenaAllocator = .init(t.allocator);
    defer output.deinit();
    const saved = try c.DirectTableValues.NameAssertion.foreign(output.allocator(), binding(1));
    caller.busy.store(true, .release);
    try t.expectError(error.Busy, caller.call(&output, .{ .load = .{ .name_assertion = saved } }));
    caller.busy.store(false, .release);
    const unavailable = try caller.call(&output, .{ .admit = .{ .name_assertion = saved } });
    try t.expect(unavailable.value == .failure);
    try t.expect(!unavailable.mutationAttempted()); // Credential read fails before submission.
    try t.expectEqual(.not_submitted, unavailable.value.failure.diagnostic.?.outcome);
    const loaded = try caller.call(&output, .{ .load = .{ .name_assertion = saved } });
    try t.expect(loaded.value == .result);
    try t.expect(!loaded.mutationAttempted());
}

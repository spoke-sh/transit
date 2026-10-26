//! Compile and use the actual offline generated helper source.
const std = @import("std");
const rpc = @import("transit_station_grpc");
const methods = @import("fixture_fixtures_grpc_methods");
pub fn main() !void {
    const t = std.testing;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(@embedFile("grpc_descriptor"), &digest, .{});
    try t.expectEqual(digest, methods.descriptor_digest);
    inline for (.{
        .{ "/test.Peer/Unary", rpc.Shape.unary },
        .{ "/test.Peer/Server", rpc.Shape.server_streaming },
        .{ "/test.Peer/Client", rpc.Shape.client_streaming },
        .{ "/test.Peer/Bidi", rpc.Shape.bidi },
    }) |method| {
        const request = @field(methods, method[0])(&.{.{ .name = "authorization", .value = .{ .secret = .{ .binding = "api", .version = 7 } } }});
        try request.validate();
        try t.expectEqualStrings(method[0], request.method);
        try t.expectEqual(method[1], request.shape);
        try t.expectEqual(digest, request.descriptor_digest);
        try t.expectEqual(@as(usize, 1), request.metadata.len);
        try t.expectEqual(@as(u64, 7), request.metadata[0].value.secret.version);
    }
}

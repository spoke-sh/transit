// Generated from a pinned FileDescriptorSet by transit-grpc-bindings.
// Message codecs remain application-owned; no network operations are generated.
const rpc = @import("transit_station_grpc");
pub const descriptor_digest: [32]u8 = .{ 154, 87, 122, 38, 190, 225, 129, 157, 142, 131, 191, 92, 200, 112, 230, 16, 148, 24, 123, 120, 238, 234, 116, 93, 90, 175, 147, 94, 201, 158, 37, 250 };
pub fn @"/test.Peer/Unary"(metadata: []const rpc.Request.Entry) rpc.Request {
    return .{ .method = "/test.Peer/Unary", .shape = .unary, .descriptor_digest = descriptor_digest, .metadata = metadata };
}
pub fn @"/test.Peer/Server"(metadata: []const rpc.Request.Entry) rpc.Request {
    return .{ .method = "/test.Peer/Server", .shape = .server_streaming, .descriptor_digest = descriptor_digest, .metadata = metadata };
}
pub fn @"/test.Peer/Client"(metadata: []const rpc.Request.Entry) rpc.Request {
    return .{ .method = "/test.Peer/Client", .shape = .client_streaming, .descriptor_digest = descriptor_digest, .metadata = metadata };
}
pub fn @"/test.Peer/Bidi"(metadata: []const rpc.Request.Entry) rpc.Request {
    return .{ .method = "/test.Peer/Bidi", .shape = .bidi, .descriptor_digest = descriptor_digest, .metadata = metadata };
}

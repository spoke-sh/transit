//! Single-attempt JSON POST with bounded caller-owned output and joined I/O.
const std = @import("std");

pub const Options = struct {
    url: []const u8,
    body: []const u8,
    headers: []const std.http.Header = &.{},
    keep_alive: bool,
    output: *std.Io.Writer,
};

pub fn send(client: *std.http.Client, options: Options) !std.http.Client.FetchResult {
    var request = try client.request(.POST, try std.Uri.parse(options.url), .{
        .headers = .{ .content_type = .{ .override = "application/json" } },
        .extra_headers = options.headers,
        .redirect_behavior = .not_allowed,
        .keep_alive = options.keep_alive,
    });
    defer request.deinit();
    request.transfer_encoding = .{ .content_length = options.body.len };
    var body = try request.sendBodyUnflushed(&.{});
    try body.writer.writeAll(options.body);
    try body.end();
    try request.connection.?.flush();
    var response = try request.receiveHead(&.{});
    const decompression: []u8 = switch (response.head.content_encoding) {
        .identity => &.{},
        .deflate, .gzip => try client.allocator.alloc(u8, std.compress.flate.max_window_len),
        // These encodings are not advertised by the standard request profile.
        .zstd, .compress => return error.UnsupportedCompressionMethod,
    };
    defer if (decompression.len != 0) client.allocator.free(decompression);
    var transfer: [64]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    const reader = response.readerDecompressing(&transfer, &decompress, decompression);
    _ = reader.streamRemaining(options.output) catch |err| switch (err) {
        // Pinned std.http.fetch unwraps bodyErr here. A socket read failure or
        // deadline cancellation can leave it null. Preserve the I/O failure;
        // the caller's deadline owner joins this task before releasing output.
        error.ReadFailed => return response.bodyErr() orelse error.ReadFailed,
        else => return err,
    };
    // EOF is valid for a close-delimited response. For framed bodies, a valid
    // JSON prefix cannot substitute for the declared HTTP message completion.
    if (request.reader.state != .ready and request.reader.state != .body_none)
        return error.EndOfStream;
    return .{ .status = response.head.status };
}

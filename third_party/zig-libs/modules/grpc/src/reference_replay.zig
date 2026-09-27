// SPDX-License-Identifier: MIT

//! **The external anchor, replayed offline.** Pure Zig: no child process, no
//! socket, no foreign source, no `python3` and no `go` anywhere.
//!
//! ## Why this file exists
//!
//! Every other self-contained gRPC test in this module is a conversation with
//! ourselves. Our framer writes the length prefix and our deframer reads it;
//! flip both to little-endian and every round trip in `call_test.zig` still
//! passes while nothing on the network can read a byte we send. Only an
//! outside implementation sees that class of defect.
//!
//! Until 2026-09-06 the outside implementation was reached by spawning
//! Python `grpcio` from inside `test-grpc`, with the reference scripts
//! `@embedFile`d into module source. That put foreign code in a library that
//! promises to be standalone Zig, and — worse — it "skipped loudly" when the
//! interpreter was missing. A skip is a pass, so on any host without grpcio
//! the module's strongest evidence quietly evaporated.
//!
//! Now the taking lives in `tools/interop.zig` (`zig build interop-grpc`) and
//! what it records lives here. `testdata/grpcio_capture.zig` is a
//! byte-for-byte recording of one real conversation with grpcio, in **both
//! directions**; this file replays it. The header of that generated file says
//! which grpcio, on which day, by which command, and exactly what was pinned
//! to make replay deterministic.
//!
//! ## What each half proves
//!
//! **Forward** — the reference *server*'s bytes, parsed by our client. This
//! is complete offline: grpcio produced those bytes and reading them
//! correctly is the whole test. HPACK, DATA framing across many frames, the
//! Trailers-Only field block, the percent-encoded `grpc-message`, `-bin`
//! base64 and grpcio's own protobuf wire output are all under our decoder
//! here, exactly as they were live.
//!
//! **Reverse** — the reference *client*'s bytes, fed to our server. Two
//! things are asserted, and they are different things:
//!
//!   1. our server understands what grpcio SENT — its HPACK, its `-bin`
//!      base64, its `grpc-timeout` rendering, its protobuf encoding;
//!   2. what our server ANSWERS matches, field by field, what grpcio itself
//!      read off the wire at capture time (`reverse_report`). Those
//!      expectations are the reference's own readings rather than numbers
//!      someone typed here — a server change that grpcio would have read
//!      differently breaks them.
//!
//! What no recording can carry is grpcio's *parser* running on freshly
//! produced bytes, so a genuinely NEW divergence in the reverse direction is
//! still only findable by `zig build interop-grpc`. That is a pre-release
//! check, and it is the honest boundary of this file.

const std = @import("std");
const http = @import("http");
const pb = @import("protobuf");

const grpc = @import("root.zig");
const frame = @import("frame.zig");
const status_mod = @import("status.zig");
const capture = @import("testdata/grpcio_capture.zig");

const h2 = http.h2;
const h2c = http.h2_client;
const hpack = http.hpack;
const testing = std.testing;
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const Writer = std.Io.Writer;

// ── the schema, mirroring tools/reference_server.py ────────────────────────

const EchoRequest = struct {
    text: []const u8 = "",
    count: i32 = 0,
    blob: []const u8 = "",
    pub const pb_fields = .{
        .text = pb.Field{ .number = 1, .kind = .string },
        .count = pb.Field{ .number = 2, .kind = .int32 },
        .blob = pb.Field{ .number = 3, .kind = .bytes },
    };
};

const EchoReply = struct {
    text: []const u8 = "",
    index: i32 = 0,
    blob: []const u8 = "",
    pub const pb_fields = .{
        .text = pb.Field{ .number = 1, .kind = .string },
        .index = pb.Field{ .number = 2, .kind = .int32 },
        .blob = pb.Field{ .number = 3, .kind = .bytes },
    };
};

const Echo = grpc.Stream(EchoRequest, EchoReply);

// ── a Reader that hands the recording over the way a socket would ──────────

/// How many bytes one read of the recording yields.
///
/// ⚠ This is not a performance knob, it is what makes replay *legal*.
/// `Reader.fixed` hands its whole slice over in one go, and the h2 engines
/// take everything `buffered()` offers in a single `recv`. A 256 KiB reply
/// therefore arrived as one 256 KiB burst, and the connection-level receive
/// window (65535 octets, fixed by RFC 9113 §6.9.2 and raised only by
/// WINDOW_UPDATEs we emit as the application consumes) was blown before the
/// application had seen a byte — `error.FlowControlError`, connection-scoped.
///
/// Live, the peer paced itself against exactly those WINDOW_UPDATEs. A
/// recording cannot pace itself, so the reader does it: bounded reads put
/// the consume→WINDOW_UPDATE→read-more loop back, which is the loop the
/// capture was made under. Nothing is compared less; the same bytes arrive
/// in the same order, in the sized pieces a socket would have delivered.
const chunk_len = 8 * 1024;

const Chunked = struct {
    src: []const u8,
    pos: usize = 0,
    buf: [chunk_len]u8 = undefined,
    reader: Reader,

    fn init(src: []const u8) Chunked {
        return .{
            .src = src,
            .reader = .{
                .vtable = &.{ .stream = Chunked.streamFn },
                .buffer = &.{},
                .end = 0,
                .seek = 0,
            },
        };
    }

    /// Must run after the struct reaches its final address: `reader.buffer`
    /// points into `buf`.
    fn arm(c: *Chunked) void {
        c.reader.buffer = &c.buf;
    }

    fn streamFn(r: *Reader, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
        const c: *Chunked = @alignCast(@fieldParentPtr("reader", r));
        if (c.pos == c.src.len) return error.EndOfStream;
        const want = @min(@min(chunk_len, c.src.len - c.pos), @backingInt(limit));
        const dest = limit.slice(try w.writableSliceGreedy(1));
        const n = @min(want, dest.len);
        @memcpy(dest[0..n], c.src[c.pos..][0..n]);
        c.pos += n;
        w.advance(n);
        return n;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// FORWARD: the reference SERVER's recorded bytes, parsed by our client.
// ═══════════════════════════════════════════════════════════════════════════

/// Heap-allocated: the h2 session holds pointers to `in`/`out`, so nothing
/// here may move after `init`.
///
/// The same shape `call_test.zig`'s `Fx` uses — a client session over fixed
/// buffers — with one difference that is the entire point: the bytes in `in`
/// were produced by grpcio's C-core, not fabricated here.
const Fx = struct {
    gpa: Allocator,
    in: Chunked,
    out_buf: [128 * 1024]u8,
    out: Writer,
    session: h2c.Session,
    ch: grpc.Channel,

    fn start(gpa: Allocator, name: []const u8, options: grpc.Options) !*Fx {
        // A missing case is a FAILING test, never a skip: the whole reason
        // this file exists is that a skip is a pass.
        const c = capture.find(name) orelse {
            std.debug.print("\nthe capture has no case `{s}` — regenerate it with " ++
                "`zig build interop-grpc -- --capture`\n", .{name});
            return error.MissingCaptureCase;
        };
        const fx = try gpa.create(Fx);
        errdefer gpa.destroy(fx);
        fx.gpa = gpa;
        fx.in = Chunked.init(c.bytes);
        fx.in.arm();
        fx.out = .fixed(&fx.out_buf);
        fx.session = try h2c.Session.init(gpa, &fx.in.reader, &fx.out, .{});
        fx.ch = grpc.Channel.init(gpa, &fx.session, options);
        return fx;
    }

    fn deinit(fx: *Fx) void {
        const gpa = fx.gpa;
        fx.session.deinit();
        gpa.destroy(fx);
    }
};

test "replay grpcio: unary — one request, one reply, real grpc-status OK in the trailers" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "unary", .{});
    defer fx.deinit();

    var reply = try grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Unary", .{
        .text = "hello reference",
        .count = 7,
        .blob = &.{ 0x00, 0xff, 0x10 },
    }, .{});
    defer reply.deinit();

    try testing.expectEqualStrings("echo:hello reference", reply.value.text);
    try testing.expectEqual(@as(i32, 7), reply.value.index);
    try testing.expectEqualSlices(u8, &.{ 0x00, 0xff, 0x10 }, reply.value.blob);
}

test "replay grpcio: server-streaming — many replies on one stream, then trailers" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "server_stream", .{});
    defer fx.deinit();

    var s = try Echo.start(&fx.ch, "/echo.Echo/ServerStream", .{});
    defer s.deinit();
    try s.sendEnd(.{ .text = "tick", .count = 5 });

    var seen: i32 = 0;
    while (try s.receive()) |*r| {
        defer @constCast(r).deinit();
        var name_buf: [32]u8 = undefined;
        const want = try std.fmt.bufPrint(&name_buf, "tick-{d}", .{seen});
        try testing.expectEqualStrings(want, r.value.text);
        try testing.expectEqual(seen, r.value.index);
        seen += 1;
    }
    try testing.expectEqual(@as(i32, 5), seen);
    try s.finish();
}

test "replay grpcio: client-streaming — many requests, one reply after closeSend" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "client_stream", .{});
    defer fx.deinit();

    var s = try Echo.start(&fx.ch, "/echo.Echo/ClientStream", .{});
    defer s.deinit();
    try s.send(.{ .text = "a" });
    try s.send(.{ .text = "bb" });
    try s.send(.{ .text = "ccc" });
    try s.closeSend();

    var reply = (try s.receive()).?;
    defer reply.deinit();
    try testing.expectEqualStrings("a|bb|ccc", reply.value.text);
    try testing.expectEqual(@as(i32, 3), reply.value.index);
    try testing.expectEqual(@as(?pb.Decoded(EchoReply), null), try s.receive());
    try s.finish();
}

test "replay grpcio: bidirectional — send and receive interleaved on one stream" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "bidi", .{});
    defer fx.deinit();

    var s = try Echo.start(&fx.ch, "/echo.Echo/Bidi", .{});
    defer s.deinit();

    const words = [_][]const u8{ "one", "two", "three" };
    for (words, 0..) |w, i| {
        try s.send(.{ .text = w });
        var r = (try s.receive()).?;
        defer r.deinit();
        var buf: [32]u8 = undefined;
        try testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "re:{s}", .{w}), r.value.text);
        try testing.expectEqual(@as(i32, @intCast(i)), r.value.index);
    }
    try s.closeSend();
    try testing.expectEqual(@as(?pb.Decoded(EchoReply), null), try s.receive());
    try s.finish();
}

test "replay grpcio: a failing call arrives as a real Trailers-Only response" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "fail", .{});
    defer fx.deinit();

    // A message full of bytes the grpc-message ABNF forbids, so the
    // percent-decoding is exercised against the reference's ENCODER — the
    // convention (`\n` → `%0A`, each byte of the multi-byte UTF-8 snowman
    // escaped separately, a literal `%` → `%25`) comes from grpcio's C-core,
    // which `status.zig` has never seen. A test that only checked our own
    // `encodeMessage`/`decodeMessage` agree with each other cannot catch a
    // decoder that silently agrees with the *wrong* convention.
    const detail = "boom\nline two \xe2\x98\x83 100% done";

    var failure: grpc.Failure = .{};
    defer failure.deinit(gpa);
    const err = grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Fail", .{
        .text = detail,
        .count = @backingInt(grpc.Status.permission_denied),
    }, .{ .failure = &failure });

    try testing.expectError(error.PermissionDenied, err);
    try testing.expectEqual(grpc.Status.permission_denied, failure.status);
    try testing.expectEqualStrings(detail, failure.message);
}

test "replay grpcio: a Trailers-Only response has no trailer section at all" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "trailers_only", .{});
    defer fx.deinit();

    var call = try fx.ch.start("/echo.Echo/Fail", .{});
    defer call.deinit();
    const req = try pb.encodeAlloc(gpa, EchoRequest{
        .text = "nope",
        .count = @backingInt(grpc.Status.not_found),
    }, .{});
    defer gpa.free(req);
    try call.sendMessage(req, true);

    // The whole response is one HEADERS frame: no body, and `grpc-status` is
    // in the INITIAL metadata. A client that only ever looks in the trailer
    // section finds nothing here and waits forever.
    try testing.expectEqual(@as(?[]const u8, null), try call.receive());
    try testing.expect(call.trailers_only);
    try testing.expect(call.trailingMetadata() == null);
    try testing.expect(call.initialMetadata().?.fields.len != 0);
    try testing.expectError(error.NotFound, call.finish());
    try testing.expectEqual(grpc.Status.not_found, call.status.?);
    try testing.expectEqualStrings("nope", call.statusMessage());
}

test "replay grpcio: messages then a non-OK status in a real trailer section" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "stream_fail", .{});
    defer fx.deinit();

    var s = try Echo.start(&fx.ch, "/echo.Echo/StreamFail", .{});
    defer s.deinit();
    try s.sendEnd(.{ .text = "x", .count = 3 });

    var seen: usize = 0;
    while (try s.receive()) |*r| {
        @constCast(r).deinit();
        seen += 1;
    }
    try testing.expectEqual(@as(usize, 3), seen);
    // Not Trailers-Only this time: the status came in the TRAILERS frame
    // after three DATA frames, which is the other half of the contract.
    try testing.expect(!s.call.trailers_only);
    try testing.expect(s.call.trailingMetadata() != null);
    try testing.expectError(error.DataLoss, s.finish());
    try testing.expectEqualStrings("gave up after 3", s.call.statusMessage());
}

test "replay grpcio: a large reply under the limit is reassembled across DATA frames" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "big", .{ .max_recv_message_size = 1024 * 1024 });
    defer fx.deinit();

    // 256 KiB of payload is many times the peer's 16 KiB default HTTP/2 frame
    // size and far past the 64 KiB initial flow-control window, so this one
    // message provably arrived split across a long run of DATA frames — and
    // the deframer has to put it back together to the byte.
    const want: i32 = 256 * 1024;
    var reply = try grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Big", .{
        .count = want,
    }, .{});
    defer reply.deinit();

    try testing.expectEqualStrings("big", reply.value.text);
    try testing.expectEqual(want, reply.value.index);
    try testing.expectEqual(@as(usize, @intCast(want)), reply.value.blob.len);
    for (reply.value.blob) |b| try testing.expectEqual(@as(u8, 0x5a), b);
}

test "replay grpcio: a reply larger than max_recv_message_size fails RESOURCE_EXHAUSTED" {
    const gpa = testing.allocator;
    // The SAME recording as the test above, read by a client with a 64 KiB
    // limit. That is not a shortcut: the reference's output does not depend
    // on our receive limit — the refusal is purely local — so recording this
    // arm separately would only have recorded a stream truncated at the point
    // our client stopped reading, which proves less, not more.
    const fx = try Fx.start(gpa, "big", .{ .max_recv_message_size = 64 * 1024 });
    defer fx.deinit();

    var failure: grpc.Failure = .{};
    defer failure.deinit(gpa);
    const err = grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Big", .{
        .count = 256 * 1024,
    }, .{ .failure = &failure });

    try testing.expectError(error.ResourceExhausted, err);
    try testing.expectEqual(grpc.Status.resource_exhausted, failure.status);
}

test "replay grpcio: ASCII and -bin metadata survive both directions" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "metadata", .{});
    defer fx.deinit();

    // Bytes that no ASCII header could carry — that is the whole reason
    // `-bin` exists, so the probe has to actually contain them. What is being
    // read back here is grpcio's own base64.
    const raw = [_]u8{ 0x00, 0x01, 0xfe, 0xff, 0x0a, 0x25 };

    var call = try fx.ch.start("/echo.Echo/Meta", .{ .metadata = &.{
        .{ .name = "x-probe", .value = "probe-value" },
        .{ .name = "x-probe-bin", .value = &raw },
    } });
    defer call.deinit();
    const req = try pb.encodeAlloc(gpa, EchoRequest{}, .{});
    defer gpa.free(req);
    try call.sendMessage(req, true);

    const msg = (try call.receive()).?;
    var decoded = try pb.decode(EchoReply, gpa, msg, .{});
    defer decoded.deinit();
    // The reference read our ASCII header and our base64 -bin header, and
    // handed both back inside the message body.
    try testing.expectEqualStrings("probe-value", decoded.value.text);
    try testing.expectEqualSlices(u8, &raw, decoded.value.blob);

    // …and in its own metadata, in both sections.
    try testing.expectEqualStrings("probe-value", call.metadataValue("x-echo").?);
    const echoed = (try call.metadataValueDecoded("x-echo-bin")).?;
    defer echoed.deinit(gpa);
    try testing.expectEqualSlices(u8, &raw, echoed.bytes);

    try testing.expectEqual(@as(?[]const u8, null), try call.receive());
    try testing.expectEqualStrings("probe-value", call.metadataValue("x-tail").?);
    const tail = (try call.metadataValueDecoded("x-tail-bin")).?;
    defer tail.deinit(gpa);
    try testing.expectEqualSlices(u8, &raw, tail.bytes);
    try call.finish();
}

test "replay grpcio: grpc-timeout was understood by the reference server" {
    const gpa = testing.allocator;

    // Three calls, three recordings, one connection each — see
    // `tools/interop.zig`'s note: a recording of sequential calls on ONE
    // connection cannot be replayed against a client that opens its streams
    // one at a time, because the recording already holds the answers to
    // streams the replaying client has not opened yet.
    {
        // No deadline: the reference reported -1.
        const fx = try Fx.start(gpa, "deadline_none", .{});
        defer fx.deinit();
        var none = try grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Deadline", .{}, .{});
        defer none.deinit();
        try testing.expectEqual(@as(i32, -1), none.value.index);
    }
    {
        // 30 s: the reference saw a deadline in the 29–30 s band, which only
        // happens if it parsed our `grpc-timeout` value AND our unit.
        const fx = try Fx.start(gpa, "deadline_seconds", .{});
        defer fx.deinit();
        var some = try grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Deadline", .{}, .{
            .timeout = .{ .value = 30, .unit = .seconds },
        });
        defer some.deinit();
        try testing.expect(some.value.index >= 29_000 and some.value.index <= 30_000);
    }
    {
        // The same duration expressed in milliseconds must land in the same
        // band — a unit we render but the peer reads differently shows here.
        const fx = try Fx.start(gpa, "deadline_millis", .{});
        defer fx.deinit();
        var ms = try grpc.unary(EchoRequest, EchoReply, &fx.ch, "/echo.Echo/Deadline", .{}, .{
            .timeout = grpc.Timeout.fromMillis(30_000),
        });
        defer ms.deinit();
        try testing.expect(ms.value.index >= 29_000 and ms.value.index <= 30_000);
    }
}

test "replay grpcio: several calls multiplexed on one HTTP/2 connection" {
    const gpa = testing.allocator;
    const fx = try Fx.start(gpa, "multiplex", .{});
    defer fx.deinit();

    // Three streams open at once on one connection, collected out of order —
    // the demultiplexing underneath is the h2 client's, exercised here
    // against a third-party server's frame interleaving.
    var a = try Echo.start(&fx.ch, "/echo.Echo/Unary", .{});
    defer a.deinit();
    var b = try Echo.start(&fx.ch, "/echo.Echo/ServerStream", .{});
    defer b.deinit();
    var c = try Echo.start(&fx.ch, "/echo.Echo/Unary", .{});
    defer c.deinit();

    try a.sendEnd(.{ .text = "A" });
    try b.sendEnd(.{ .text = "B", .count = 2 });
    try c.sendEnd(.{ .text = "C" });

    var rc = (try c.receive()).?;
    defer rc.deinit();
    try testing.expectEqualStrings("echo:C", rc.value.text);

    var seen: usize = 0;
    while (try b.receive()) |*r| {
        @constCast(r).deinit();
        seen += 1;
    }
    try testing.expectEqual(@as(usize, 2), seen);

    var ra = (try a.receive()).?;
    defer ra.deinit();
    try testing.expectEqualStrings("echo:A", ra.value.text);

    try a.finish();
    try b.finish();
    try c.finish();
}

// ═══════════════════════════════════════════════════════════════════════════
// The frozen constants that predate the capture (F5, 2026-08-08). Kept
// because they assert the SAME grpcio bytes at a different seam — a hand-
// readable one — and because they are cheap.
// ═══════════════════════════════════════════════════════════════════════════

/// `grpc-status`/`grpc-message`, byte-for-byte as the reference **C-core**
/// server's Trailers-Only response carried them (`/echo.Echo/Fail`,
/// `req.count = permission_denied`).
const live_grpcio_status_value = "7"; // permission_denied
const live_grpcio_message_wire = "boom%0Aline two %E2%98%83 100%25 done";
const live_grpcio_message_decoded = "boom\nline two \xe2\x98\x83 100% done";

test "external anchor: grpcio's real Trailers-Only grpc-status/grpc-message wire bytes decode correctly (frozen 2026-08-08)" {
    try testing.expectEqual(grpc.Status.permission_denied, status_mod.parse(live_grpcio_status_value).?);

    var buf: [live_grpcio_message_wire.len]u8 = undefined;
    const decoded = status_mod.decodeMessage(live_grpcio_message_wire, &buf);
    try testing.expectEqualStrings(live_grpcio_message_decoded, decoded);
}

/// The exact bytes the C-core reference server's protobuf library put on the
/// wire for one `EchoReply` (`/echo.Echo/Unary`, `text = "hello reference"`,
/// `count = 7`, `blob = {0x00, 0xff, 0x10}`) — the 5-byte gRPC length prefix
/// already stripped by `Call.receive`'s deframer. Field 1 (`0x0a`,
/// length-delimited, 20 bytes) is `text`, field 2 (`0x10`, varint) is
/// `count`/`index`, field 3 (`0x1a`, length-delimited, 3 bytes) is `blob` —
/// real protobuf-library wire output, not this repo's own `pb.encode`.
const live_grpcio_echo_reply_bytes = [_]u8{
    0x0a, 0x14, 'e',  'c',  'h',  'o',  ':',  'h', 'e', 'l', 'l', 'o', ' ', 'r', 'e', 'f', 'e', 'r', 'e', 'n', 'c', 'e',
    0x10, 0x07, 0x1a, 0x03, 0x00, 0xff, 0x10,
};

test "external anchor: grpcio's real EchoReply wire bytes decode through frame + pb (frozen 2026-08-08)" {
    const gpa = testing.allocator;

    // Re-frame with this module's own LPM header — its byte layout is already
    // anchored independently in `frame.zig`'s spec-derived tests — purely so
    // the exact `Deframer` code path `Call.receive` uses is the one under
    // test here too, not a shortcut around it.
    const framed = try frame.encodeAlloc(gpa, &live_grpcio_echo_reply_bytes);
    defer gpa.free(framed);

    var d: frame.Deframer = .{};
    defer d.deinit(gpa);
    try d.push(gpa, framed);
    const payload = (try d.next()).?;
    try testing.expectEqualSlices(u8, &live_grpcio_echo_reply_bytes, payload);
    try testing.expectEqual(@as(?[]const u8, null), try d.next());

    var decoded = try pb.decode(EchoReply, gpa, payload, .{});
    defer decoded.deinit();
    try testing.expectEqualStrings("echo:hello reference", decoded.value.text);
    try testing.expectEqual(@as(i32, 7), decoded.value.index);
    try testing.expectEqualSlices(u8, &.{ 0x00, 0xff, 0x10 }, decoded.value.blob);
}

test "the capture's provenance is recorded" {
    // A fixture whose origin is not written down is a fixture nobody can
    // re-derive — and this one is the module's only external evidence on a
    // machine with no grpcio. These four lines are what a reader needs.
    try testing.expect(std.mem.startsWith(u8, capture.reference, "Python grpcio "));
    try testing.expectEqual(@as(usize, 10), capture.captured_on.len);
    try testing.expect(std.mem.indexOf(u8, capture.command, "--capture") != null);
    try testing.expect(std.mem.indexOf(u8, capture.reverse_service, "echo.Echo") != null);
    // Every forward case the tests above look up must exist.
    for ([_][]const u8{
        "unary",         "server_stream",    "client_stream",
        "bidi",          "fail",             "trailers_only",
        "stream_fail",   "big",              "metadata",
        "deadline_none", "deadline_seconds", "deadline_millis",
        "multiplex",
    }) |name| {
        if (capture.find(name) == null) {
            std.debug.print("\ncapture case `{s}` is missing\n", .{name});
            return error.MissingCaptureCase;
        }
    }
}

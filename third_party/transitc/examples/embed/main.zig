//! Compile captured buffers; the returned product outlives those input buffers.
const std = @import("std");
const compiler = @import("transitc_compiler");
const protocol = @import("transit_protocol");
pub fn main(init: std.process.Init) !void {
    var diagnostic: ?protocol.Diagnostic = null;
    const source = try init.gpa.dupe(u8, "CREATE TARGET default AS BEGIN CREATE PUBLIC TABLE items (id BIGINT); END;");
    const product = compiler.compile(init.gpa, &.{.{ .path = "build.transit", .text = source }}, .{ .compiler_revision = "embedding-example" }, &diagnostic) catch |err| {
        init.gpa.free(source);
        return err;
    };
    init.gpa.free(source);
    defer product.deinit();
    if (product.steps.len != 1 or !std.mem.eql(u8, product.sql, "CREATE TABLE ITEMS ( ID BIGINT );\n")) return error.UnexpectedCompilerProduct;
    try std.Io.File.stdout().writeStreamingAll(init.io, product.sql);
}

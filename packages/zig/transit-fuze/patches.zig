//! Narrow compatibility fixes over the immutable upstream package. Generated
//! copies live in the build cache; the fetched package is never modified.
const std = @import("std");

pub fn apply(b: *std.Build, dependency: *std.Build.Dependency, module: *std.Build.Module) !void {
    const path = "src/ipc/stream_writer.zig";
    b.dependOnFileContents(dependency.path(path));
    var dir = try dependency.builder.root.openDir(b.graph.io, ".", .{});
    defer dir.close(b.graph.io);
    const original = try dir.readFileAlloc(b.graph.io, path, b.allocator, .limited(512 * 1024));
    // MessageT owns and frees SchemaT after construction. Its normal defer
    // already runs on output failure; the earlier errdefer must not free twice.
    const guard = "errdefer self.allocator.destroy(schema_ptr);";
    const transfer = "            try writeMessage(self.allocator, self.writer, msg, &.{});";
    if (std.mem.count(u8, original, guard) != 1 or std.mem.count(u8, original, transfer) != 1)
        return error.UpstreamPatchMismatch;
    const guarded = try std.mem.replaceOwned(u8, b.allocator, original, guard, "var schema_transferred = false;\n            errdefer if (!schema_transferred) self.allocator.destroy(schema_ptr);");
    const patched = try std.mem.replaceOwned(u8, b.allocator, guarded, transfer, "            schema_transferred = true;\n" ++ transfer);
    const files = b.addWriteFiles();
    const source = files.addCopyDirectory(dependency.path("src"), "src", .{ .exclude_extensions = &.{ "ipc/stream_writer.zig", "fbs_runtime/Builder.zig" } });
    _ = files.add("src/ipc/stream_writer.zig", patched);
    module.root_source_file = source.path(b, "root.zig");
    // FlatBuffer byte/string tracing discloses schemas and executes log I/O
    // inside encoding. Instrumentation belongs to the caller's domain boundary.
    const builder_path = "src/fbs_runtime/Builder.zig";
    b.dependOnFileContents(dependency.path(builder_path));
    const builder = try dir.readFileAlloc(b.graph.io, builder_path, b.allocator, .limited(512 * 1024));
    const log = "    std.log.debug(fmt, args);";
    if (std.mem.count(u8, builder, log) != 1) return error.UpstreamPatchMismatch;
    _ = files.add(builder_path, try std.mem.replaceOwned(u8, b.allocator, builder, log, "    _ = fmt;\n    _ = args;"));
    module.import_table.get("fbs_runtime").?.root_source_file = source.path(b, "fbs_runtime/lib.zig");
}

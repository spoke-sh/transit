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
    const guarded_schema = try std.mem.replaceOwned(u8, b.allocator, guarded, transfer, "            schema_transferred = true;\n" ++ transfer);
    // The batch message takes over its metadata lists only after construction.
    // Keep partial lists and the header private until that transfer, including
    // failures while growing array metadata or serializing the message.
    const batch_start = std.mem.indexOf(u8, guarded_schema, "        pub fn writeRecordBatch(") orelse return error.UpstreamPatchMismatch;
    const batch_end = std.mem.indexOfPos(u8, guarded_schema, batch_start, "\n        pub fn writeEnd(") orelse return error.UpstreamPatchMismatch;
    var batch: []const u8 = guarded_schema[batch_start..batch_end];
    const nodes = "            var nodes = try std.ArrayList(fbs.FieldNodeT).initCapacity(self.allocator, 0);";
    batch = try replaceOnce(b.allocator, batch, nodes, "            var metadata_transferred = false;\n" ++ nodes ++ "\n            defer if (!metadata_transferred) nodes.deinit(self.allocator);");
    const buffers = "            var buffers = try std.ArrayList(fbs.BufferT).initCapacity(self.allocator, 0);";
    batch = try replaceOnce(b.allocator, batch, buffers, buffers ++ "\n            defer if (!metadata_transferred) buffers.deinit(self.allocator);");
    const counts = "            var variadic_buffer_counts = try std.ArrayList(i64).initCapacity(self.allocator, 0);";
    batch = try replaceOnce(b.allocator, batch, counts, counts ++ "\n            defer if (!metadata_transferred) variadic_buffer_counts.deinit(self.allocator);");
    batch = try replaceOnce(b.allocator, batch, "            errdefer self.allocator.destroy(record_batch_ptr);", "            defer if (!metadata_transferred) self.allocator.destroy(record_batch_ptr);");
    batch = try replaceOnce(b.allocator, batch, "            defer msg.deinit(self.allocator);", "            defer msg.deinit(self.allocator);\n            metadata_transferred = true;");
    const patched = try std.fmt.allocPrint(b.allocator, "{s}{s}{s}", .{ guarded_schema[0..batch_start], batch, guarded_schema[batch_end..] });
    const files = b.addWriteFiles();
    const source = files.addCopyDirectory(dependency.path("src"), "src", .{ .exclude_extensions = &.{ "ipc/stream_writer.zig", "ipc/stream_reader.zig", "fbs_runtime/Builder.zig", "ffi/c_data.zig" } });
    _ = files.add("src/ipc/stream_writer.zig", patched);
    // Empty primitive RecordBatches legitimately have a zero-byte body. The
    // upstream reader requires a SharedBuffer even for that valid empty body;
    // keep schema messages body-less and let array validation reject bad batches.
    const reader_path = "src/ipc/stream_reader.zig";
    b.dependOnFileContents(dependency.path(reader_path));
    const reader = try dir.readFileAlloc(b.graph.io, reader_path, b.allocator, .limited(512 * 1024));
    const body_guard = "    if (body_len > 0) {\n        var body_buf = try OwnedBuffer.init(self.allocator, body_len);";
    if (std.mem.count(u8, reader, body_guard) != 1) return error.UpstreamPatchMismatch;
    _ = files.add(reader_path, try std.mem.replaceOwned(u8, b.allocator, reader, body_guard, "    if (body_len > 0 or msg_t.header == .RecordBatch or msg_t.header == .DictionaryBatch) {\n        var body_buf = try OwnedBuffer.init(self.allocator, body_len);"));
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
    // C export retains the array before allocating its pointer directories.
    // A failure at any later allocation must release that retain and every
    // completed child; block-scoped errdefers do not cover later failures.
    const c_path = "src/ffi/c_data.zig";
    b.dependOnFileContents(dependency.path(c_path));
    const c_source = try dir.readFileAlloc(b.graph.io, c_path, b.allocator, .limited(512 * 1024));
    const start = std.mem.indexOf(u8, c_source, "fn exportArrayRecursive(") orelse return error.UpstreamPatchMismatch;
    const end = std.mem.indexOfPos(u8, c_source, start, "\nfn releaseExportedArray(") orelse return error.UpstreamPatchMismatch;
    var function: []const u8 = c_source[start..end];
    function = try replaceOnce(b.allocator, function, "    errdefer allocator.destroy(priv);\n", "");
    function = try replaceOnce(b.allocator, function, "    const n_buffers = data.buffers.len;", "    var failed_array: ArrowArray = std.mem.zeroes(ArrowArray);\n    failed_array.release = releaseExportedArray;\n    failed_array.private_data = priv;\n    errdefer releaseExportedArray(&failed_array);\n\n    const n_buffers = data.buffers.len;");
    function = try replaceOnce(b.allocator, function, "        errdefer allocator.free(priv.buffers_ptrs);\n", "");
    function = try replaceOnce(b.allocator, function, "        errdefer allocator.free(priv.children_storage);", "        for (priv.children_storage) |*child| child.release = null;");
    function = try replaceOnce(b.allocator, function, "        errdefer allocator.free(priv.children_ptrs);\n", "");
    function = try replaceOnce(b.allocator, function, "        errdefer allocator.destroy(priv.dict_storage.?);", "        priv.dict_storage.?.release = null;");
    _ = files.add(c_path, try std.fmt.allocPrint(b.allocator, "{s}{s}{s}", .{ c_source[0..start], function, c_source[end..] }));
}

fn replaceOnce(allocator: std.mem.Allocator, source: []const u8, before: []const u8, after: []const u8) ![]const u8 {
    if (std.mem.count(u8, source, before) != 1) return error.UpstreamPatchMismatch;
    return std.mem.replaceOwned(u8, allocator, source, before, after);
}

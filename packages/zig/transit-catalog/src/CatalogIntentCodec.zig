//! Shared bounded immutable request envelope. Request validation remains with
//! its lifecycle owner; staged bytes alone cannot publish a declaration.
const std = @import("std");
const c = @import("root.zig");
const p = c.protocol;
const r = @import("DirectCatalogRecords.zig");
const Objects = c.storage.TransitObjectStore;
const header_bytes = 40;

pub fn Codec(comptime Request: type, comptime directory: []const u8, comptime magic: *const [8]u8) type {
    return struct {
        pub const Owned = std.json.Parsed(Request);

        pub fn key(content: p.DataLifecycle.Content, output: *[96]u8) ![]const u8 {
            try content.validate();
            return std.fmt.bufPrint(output, directory ++ "/{x}.data", .{&content.sha256});
        }

        pub fn stage(allocator: std.mem.Allocator, objects: Objects.ObjectStore, configuration: r.Configuration, request: Request) !p.DataLifecycle.Content {
            try request.validate(allocator, configuration);
            const bytes = try allocator.alloc(u8, r.max_intent_bytes);
            defer allocator.free(bytes);
            bytes[0..8].* = magic.*;
            bytes[8..40].* = p.Growth.definition_bytes;
            var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
            try std.json.Stringify.value(request, .{}, &writer);
            const encoded = bytes[0 .. header_bytes + writer.end];
            const content: p.DataLifecycle.Content = .{ .bytes = encoded.len, .sha256 = r.hash(encoded) };
            var name: [96]u8 = undefined;
            const stored = try objects.putImmutable(try key(content, &name), encoded, content.sha256);
            if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidDirectCatalogIntent;
            return content;
        }

        pub fn stageInTree(allocator: std.mem.Allocator, index: *c.storage.TreeStore, configuration: r.Configuration, request: Request) !p.DataLifecycle.Content {
            try request.validate(allocator, configuration);
            const bytes = try allocator.alloc(u8, r.max_intent_bytes);
            defer allocator.free(bytes);
            bytes[0..8].* = magic.*;
            bytes[8..40].* = p.Growth.definition_bytes;
            var writer: std.Io.Writer = .fixed(bytes[header_bytes..]);
            try std.json.Stringify.value(request, .{}, &writer);
            const encoded = bytes[0 .. header_bytes + writer.end];
            const content: p.DataLifecycle.Content = .{ .bytes = encoded.len, .sha256 = r.hash(encoded) };
            var name: [96]u8 = undefined;
            if (encoded.len <= c.storage.TreeStore.max_batch_object_bytes) {
                const stored = try index.stageObject(try key(content, &name), encoded, content.sha256);
                if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidDirectCatalogIntent;
            } else {
                const stored = try index.store.putImmutable(try key(content, &name), encoded, content.sha256);
                if (stored.size != content.bytes or !std.mem.eql(u8, &stored.sha256, &content.sha256)) return error.InvalidDirectCatalogIntent;
            }
            return content;
        }

        pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, configuration: r.Configuration, content: p.DataLifecycle.Content) !Owned {
            if (content.bytes < header_bytes or content.bytes > r.max_intent_bytes) return error.InvalidDirectCatalogIntent;
            var name: [96]u8 = undefined;
            const object_key = try key(content, &name);
            const metadata = try objects.head(object_key) orelse return error.CatalogIntentMissing;
            if (metadata.size != content.bytes or !std.mem.eql(u8, &metadata.sha256, &content.sha256)) return error.InvalidDirectCatalogIntent;
            const bytes = try allocator.alloc(u8, @intCast(content.bytes));
            defer allocator.free(bytes);
            if ((try objects.getRange(object_key, 0, @intCast(bytes.len), bytes)).len != bytes.len or !std.mem.eql(u8, &r.hash(bytes), &content.sha256)) return error.InvalidDirectCatalogIntent;
            if (!std.mem.eql(u8, bytes[0..8], magic)) return error.InvalidDirectCatalogIntent;
            if (!std.mem.eql(u8, bytes[8..40], &p.Growth.definition_bytes)) return error.IncompatibleDefinition;
            var parsed = try std.json.parseFromSlice(Request, allocator, bytes[header_bytes..], .{ .allocate = .alloc_always });
            errdefer parsed.deinit();
            try parsed.value.validate(allocator, configuration);
            return parsed;
        }
    };
}

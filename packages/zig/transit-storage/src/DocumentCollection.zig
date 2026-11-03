//! Immutable retained partition-head directories and authenticated pagination.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;
const c = doc.Read.Collection;
const Objects = @import("TransitObjectStore.zig");
const Evidence = @import("DocumentEvidence.zig");
const pages = @import("TreeStore.zig").pages;

pub const magic = "DCOLL001";
const header_bytes = 40;
pub const max_bytes = 16384;

pub const Source = struct {
    definition: p.Growth.Definition,
    request: c.Request,
    cut: c.Cut,
    heads_root: ?pages.Reference,

    pub fn validate(self: Source) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.request.validate();
        try self.cut.validate();
        try self.request.target.requireSame(self.cut.target);
        if ((self.heads_root != null) != (self.cut.heads_digest != null)) return error.InvalidDocumentCollection;
        if (self.heads_root) |root| {
            if (std.mem.allEqual(u8, &root.location, 0) or
                !std.mem.eql(u8, &root.digest, &self.cut.heads_digest.?)) return error.InvalidDocumentCollection;
        }
    }
};

pub fn sign(secret: [32]u8, read: doc.Read.Handle, coverage: c.Coverage) !c.Cursor {
    try read.validate();
    try coverage.validate();
    if (std.mem.allEqual(u8, &secret, 0)) return error.InvalidDocumentReadSecret;
    var buffer: [4096]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    const Body = struct { read: doc.Read.Handle, coverage: c.Coverage };
    try p.Json.write(Body{ .read = read, .coverage = coverage }, &encoder);
    var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(&secret);
    hmac.update("transit.document.collection.coverage.v1\x00");
    hmac.update(&p.Growth.definition_bytes);
    hmac.update(writer.buffered());
    var authentication: [32]u8 = undefined;
    hmac.final(&authentication);
    return .{ .read = read, .coverage = coverage, .authentication = authentication };
}

pub fn verify(secret: [32]u8, cursor: c.Cursor) !void {
    try cursor.validate();
    const expected = try sign(secret, cursor.read, cursor.coverage);
    if (!std.crypto.timing_safe.eql([32]u8, expected.authentication, cursor.authentication)) return error.InvalidDocumentCursor;
}

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidDocumentCollection;
    return std.fmt.bufPrint(output, "document-collections/{x}.data", .{&content.sha256});
}

pub fn encode(source: Source, output: *[max_bytes]u8) ![]const u8 {
    try source.validate();
    output[0..8].* = magic.*;
    output[8..40].* = p.Growth.definition_bytes;
    var writer: std.Io.Writer = .fixed(output[header_bytes..]);
    var encoder: std.json.Stringify = .{ .writer = &writer };
    try p.Json.write(source, &encoder);
    return output[0 .. header_bytes + writer.buffered().len];
}

pub fn stage(objects: Objects.ObjectStore, source: Source) !d.Content {
    var buffer: [max_bytes]u8 = undefined;
    const bytes = try encode(source, &buffer);
    const content: d.Content = .{ .bytes = bytes.len, .sha256 = Evidence.hash(bytes) };
    var name: [96]u8 = undefined;
    const accepted = try objects.putImmutable(try key(content, &name), bytes, content.sha256);
    if (accepted.size != content.bytes or !std.mem.eql(u8, &accepted.sha256, &content.sha256)) {
        return error.InvalidDocumentCollection;
    }
    return content;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content) !Source {
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const meta = (try objects.head(object_key)) orelse return error.DocumentReadMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) {
        return error.InvalidDocumentCollection;
    }
    var buffer: [max_bytes]u8 = undefined;
    const slice = buffer[0..@intCast(content.bytes)];
    if ((try objects.getRange(object_key, 0, @intCast(slice.len), slice)).len != slice.len) {
        return error.InvalidDocumentCollection;
    }
    if (!std.mem.eql(u8, &Evidence.hash(slice), &content.sha256) or !std.mem.eql(u8, slice[0..8], magic)) {
        return error.InvalidDocumentCollection;
    }
    if (!std.mem.eql(u8, slice[8..40], &p.Growth.definition_bytes)) {
        return error.IncompatibleDefinition;
    }
    const parsed = try p.Json.parseFromSlice(Source, allocator, slice[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, slice, try encode(parsed.value, &canonical))) {
        return error.InvalidDocumentCollection;
    }
    return parsed.value;
}

//! Retained Document read bases (`DREAD001` in `document-reads/{sha256}.data`)
//! and HMAC-SHA-256 cumulative coverage cursor authentication.
const std = @import("std");
const p = @import("transit_protocol");
const d = p.DataLifecycle;
const doc = p.DocumentOperation;
const Objects = @import("TransitObjectStore.zig");
const Evidence = @import("DocumentEvidence.zig");

pub const magic = "DREAD001";
const header_bytes = 40;
pub const max_bytes = 16384;
const mac_domain = "transit.document.read.coverage.v1\x00";

pub const Source = struct {
    definition: p.Growth.Definition,
    request: doc.Read.Request,
    cut: doc.Cut,
    through_revision: u64,

    pub fn validate(self: Source) !void {
        if (self.definition != p.Growth.current_definition) return error.IncompatibleDefinition;
        try self.request.validate();
        try self.cut.validate();
        try self.request.target.requireSame(self.cut.target);
        try self.cut.requireRevision(self.request.from_revision);
        try self.cut.requireRevision(self.through_revision);
        if (self.through_revision < self.request.from_revision or
            self.through_revision != (self.request.through_revision orelse self.cut.accepted_revision))
        {
            return error.InvalidDocumentRead;
        }
    }
};

pub const Authority = struct {
    secret: [32]u8,

    const Body = struct {
        read: doc.Read.Handle,
        coverage: doc.Read.Coverage,
    };

    pub fn init(secret: [32]u8) !Authority {
        if (std.mem.allEqual(u8, &secret, 0)) return error.InvalidDocumentReadSecret;
        return .{ .secret = secret };
    }

    pub fn sign(self: Authority, read: doc.Read.Handle, coverage: doc.Read.Coverage) !doc.Read.Cursor {
        try read.validate();
        try coverage.validate();
        try coverage.cut.target.requireOperation(read.owner);
        const mac = try self.computeMac(read, coverage);
        const cursor: doc.Read.Cursor = .{
            .read = read,
            .coverage = coverage,
            .authentication = mac,
        };
        try cursor.validate();
        return cursor;
    }

    pub fn verify(self: Authority, cursor: doc.Read.Cursor) !void {
        try cursor.validate();
        const expected = try self.computeMac(cursor.read, cursor.coverage);
        if (!std.crypto.timing_safe.eql([32]u8, expected, cursor.authentication)) {
            return error.InvalidDocumentCursor;
        }
    }

    fn computeMac(self: Authority, read: doc.Read.Handle, coverage: doc.Read.Coverage) ![32]u8 {
        var json_buf: [8192]u8 = undefined;
        var writer: std.Io.Writer = .fixed(&json_buf);
        var encoder: std.json.Stringify = .{ .writer = &writer };
        try p.Json.write(Body{ .read = read, .coverage = coverage }, &encoder);
        var hmac = std.crypto.auth.hmac.sha2.HmacSha256.init(&self.secret);
        hmac.update(mac_domain);
        hmac.update(&p.Growth.definition_bytes);
        hmac.update(writer.buffered());
        var out: [32]u8 = undefined;
        hmac.final(&out);
        return out;
    }
};

pub fn key(content: d.Content, output: *[96]u8) ![]const u8 {
    try content.validate();
    if (content.bytes <= header_bytes or content.bytes > max_bytes) return error.InvalidDocumentRead;
    return std.fmt.bufPrint(output, "document-reads/{x}.data", .{&content.sha256});
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
        return error.InvalidDocumentRead;
    }
    return content;
}

pub fn load(allocator: std.mem.Allocator, objects: Objects.ObjectStore, content: d.Content) !Source {
    var name: [96]u8 = undefined;
    const object_key = try key(content, &name);
    const meta = (try objects.head(object_key)) orelse return error.DocumentReadMissing;
    if (meta.size != content.bytes or !std.mem.eql(u8, &meta.sha256, &content.sha256)) {
        return error.InvalidDocumentRead;
    }
    var buffer: [max_bytes]u8 = undefined;
    const slice = buffer[0..@intCast(content.bytes)];
    if ((try objects.getRange(object_key, 0, @intCast(slice.len), slice)).len != slice.len) {
        return error.InvalidDocumentRead;
    }
    if (!std.mem.eql(u8, &Evidence.hash(slice), &content.sha256) or !std.mem.eql(u8, slice[0..8], magic)) {
        return error.InvalidDocumentRead;
    }
    if (!std.mem.eql(u8, slice[8..40], &p.Growth.definition_bytes)) {
        return error.IncompatibleDefinition;
    }
    const parsed = try p.Json.parseFromSlice(Source, allocator, slice[header_bytes..]);
    defer parsed.deinit();
    try parsed.value.validate();
    var canonical: [max_bytes]u8 = undefined;
    if (!std.mem.eql(u8, slice, try encode(parsed.value, &canonical))) {
        return error.InvalidDocumentRead;
    }
    return parsed.value;
}

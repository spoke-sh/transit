//! Signed wire bodies require their definition even when unsigned authoring
//! types supply it for newly constructed requests. Reflection and decoding use
//! the same derived type, preserving every other field and default.
const std = @import("std");
const Json = @import("Json.zig");

pub fn Wire(comptime Envelope: type, comptime body_field: []const u8) type {
    const info = @typeInfo(Envelope).@"struct";
    var types = info.field_types[0..info.field_types.len].*;
    for (info.field_names, 0..) |name, index| {
        if (!std.mem.eql(u8, name, body_field)) continue;
        const body = @typeInfo(types[index]).@"struct";
        var attrs = body.field_attrs[0..body.field_attrs.len].*;
        for (body.field_names, 0..) |field, i| {
            if (std.mem.eql(u8, field, "definition")) attrs[i].default_value_ptr = null;
        }
        types[index] = @Struct(.auto, null, body.field_names, body.field_types, &attrs);
    }
    return @Struct(.auto, null, info.field_names, &types, info.field_attrs);
}

pub fn parse(comptime Envelope: type, comptime body_field: []const u8, allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) std.json.ParseError(@TypeOf(source.*))!Envelope {
    return fromValue(Envelope, body_field, allocator, try std.json.innerParse(std.json.Value, allocator, source, options), options);
}

pub fn fromValue(comptime Envelope: type, comptime body_field: []const u8, allocator: std.mem.Allocator, value: std.json.Value, options: std.json.ParseOptions) std.json.ParseFromValueError!Envelope {
    const Raw = Wire(Envelope, body_field);
    // Custom JSON hooks otherwise bypass the shared fixed-array/integer shape
    // check. Apply it to the derived ordinary struct before typed decoding.
    Json.validateShape(Raw, value) catch return error.UnexpectedToken;
    const raw = try std.json.innerParseFromValue(Raw, allocator, value, options);
    var result: Envelope = undefined;
    inline for (@typeInfo(Envelope).@"struct".field_names) |name| {
        if (comptime std.mem.eql(u8, name, body_field)) {
            inline for (@typeInfo(@FieldType(Envelope, body_field)).@"struct".field_names) |field| {
                @field(@field(result, body_field), field) = @field(@field(raw, body_field), field);
            }
        } else @field(result, name) = @field(raw, name);
    }
    return result;
}

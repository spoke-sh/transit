//! The measured boundary that stopped local decoding. `required` can be the
//! next prefix amount, not the size of an input we deliberately did not finish.
const Self = @This();
pub const Dimension = enum {
    record_bytes,
    record_fields,
    header_name_bytes,
    field_name_bytes,
    scan_records,
    schema_fields,
    json_bytes,
    json_depth,
    json_tokens,
    json_fields,
    output_record_bytes,
};
dimension: Dimension,
required: u64,
limit: u64,
minimum: bool = false,
pub fn unit(self: Self) []const u8 {
    return switch (self.dimension) {
        .record_bytes, .header_name_bytes, .field_name_bytes, .json_bytes, .output_record_bytes => "bytes",
        .record_fields, .schema_fields, .json_fields => "fields",
        .scan_records => "records",
        .json_depth => "levels",
        .json_tokens => "tokens",
    };
}
pub fn save(target: ?*?Self, value: Self) void {
    if (target) |slot| slot.* = value;
}

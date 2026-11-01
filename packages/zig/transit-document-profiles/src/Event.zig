const profile = @import("Profile.zig").contract;

pub const Event = struct {
    kind: enum {
        object_start,
        object_end,
        array_start,
        array_end,
        key,
        string,
        number,
        boolean,
        null_value,
        element_start,
        element_end,
        attribute,
        text,
        comment,
        processing_instruction,
    },
    span: profile.Span,
    depth: u32,
    /// Borrowed until the next parser call. Copy to independently owned output
    /// if it must survive. For JSON numbers these are exact source lexemes.
    value: []const u8 = "",
    /// Attribute value / processing-instruction body when applicable.
    detail: []const u8 = "",
};

pub const Step = struct {
    consumed: usize,
    result: union(enum) {
        event: Event,
        need_input,
        yield,
        complete,
    },
};

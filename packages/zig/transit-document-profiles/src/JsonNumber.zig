//! Shared lexical number state for parsing and construction. No float conversion.
pub const State = enum {
    const Self = @This();
    minus,
    zero,
    integer,
    dot,
    fraction,
    exponent_mark,
    exponent_sign,
    exponent,

    pub fn start(c: u8) !Self {
        return switch (c) {
            '-' => .minus,
            '0' => .zero,
            '1'...'9' => .integer,
            else => error.InvalidJsonNumber,
        };
    }

    pub fn next(self: *Self, c: u8) !void {
        self.* = switch (self.*) {
            .minus => switch (c) {
                '0' => .zero,
                '1'...'9' => .integer,
                else => return error.InvalidJsonNumber,
            },
            .zero => switch (c) {
                '.' => .dot,
                'e', 'E' => .exponent_mark,
                else => return error.InvalidJsonNumber,
            },
            .integer => switch (c) {
                '0'...'9' => .integer,
                '.' => .dot,
                'e', 'E' => .exponent_mark,
                else => return error.InvalidJsonNumber,
            },
            .dot => switch (c) {
                '0'...'9' => .fraction,
                else => return error.InvalidJsonNumber,
            },
            .fraction => switch (c) {
                '0'...'9' => .fraction,
                'e', 'E' => .exponent_mark,
                else => return error.InvalidJsonNumber,
            },
            .exponent_mark => switch (c) {
                '+', '-' => .exponent_sign,
                '0'...'9' => .exponent,
                else => return error.InvalidJsonNumber,
            },
            .exponent_sign => switch (c) {
                '0'...'9' => .exponent,
                else => return error.InvalidJsonNumber,
            },
            .exponent => switch (c) {
                '0'...'9' => .exponent,
                else => return error.InvalidJsonNumber,
            },
        };
    }

    pub fn finish(self: Self) !void {
        switch (self) {
            .zero, .integer, .fraction, .exponent => {},
            else => return error.InvalidJsonNumber,
        }
    }

    pub fn validate(bytes: []const u8) !void {
        if (bytes.len == 0) return error.InvalidJsonNumber;
        var state = try start(bytes[0]);
        for (bytes[1..]) |byte| try state.next(byte);
        try state.finish();
    }
};

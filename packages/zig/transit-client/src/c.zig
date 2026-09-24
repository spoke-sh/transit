const abi = @import("Abi.zig");
comptime {
    for (@typeInfo(abi.Api).@"struct".decl_names) |name| {
        @export(&@field(abi.Api, name), .{ .name = name });
    }
}

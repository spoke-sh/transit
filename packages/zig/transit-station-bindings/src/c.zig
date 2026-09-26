const abi = @import("station_abi");
comptime {
    for (@typeInfo(abi.Api).@"struct".decl_names) |name| @export(&@field(abi.Api, name), .{ .name = name });
}

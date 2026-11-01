//! Pure, bounded byte-to-event Document interpretation. Events remain provisional
//! until explicit completion; they are not database acceptance or effect evidence.
pub const Profile = @import("Profile.zig");
pub const Reader = @import("Reader.zig");
pub const Xml = @import("Xml.zig");
pub const Json = @import("Json.zig");
pub const Event = @import("Event.zig").Event;
pub const Step = @import("Event.zig").Step;
test {
    _ = Reader;
    _ = @import("json_test.zig");
    _ = @import("xml_test.zig");
}

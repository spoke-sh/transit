//! Pure, bounded byte-to-event Document interpretation. Events remain provisional
//! until explicit completion; they are not database acceptance or effect evidence.
pub const OrderedInput = @import("OrderedInput.zig");
pub const Container = @import("Container.zig");
pub const Candidate = @import("Candidate.zig");
pub const Profile = @import("Profile.zig");
pub const Reader = @import("Reader.zig");
pub const XmlWriter = @import("XmlWriter.zig");
pub const Xml = @import("Xml.zig");
pub const JsonWriter = @import("JsonWriter.zig");
pub const Json = @import("Json.zig");
pub const Mime = @import("Mime.zig");
pub const MimeWriter = @import("MimeWriter.zig");
pub const Event = @import("Event.zig").Event;
pub const Step = @import("Event.zig").Step;
test {
    _ = @import("ordered_input_test.zig");
    _ = Reader;
    _ = @import("candidate_test.zig");
    _ = @import("container_test.zig");
    _ = @import("json_test.zig");
    _ = @import("json_writer_test.zig");
    _ = @import("xml_test.zig");
    _ = @import("xml_writer_test.zig");
    _ = @import("mime_test.zig");
    _ = @import("mime_writer_test.zig");
}

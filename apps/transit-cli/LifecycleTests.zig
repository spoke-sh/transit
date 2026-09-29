//! Application-owned process mechanics, independent of native protocol tests.
test {
    _ = @import("Options.zig");
    _ = @import("Settings.zig");
    _ = @import("Show.zig");
    _ = @import("server/Process.zig");
    _ = @import("server/Applications.zig");
    _ = @import("server/Hosts.zig");
}

//! TLS client with complete certificate-path verification, pinned to the compiler.
pub const Client = @import("Client.zig");
pub const verify = @import("verify.zig");
comptime {
    if (!@import("std").mem.eql(u8, @import("builtin").zig_version_string, "0.17.0-dev.2267+48abf1a34"))
        @compileError("Rebase and qualify transit-tls before changing the pinned compiler");
}
test {
    _ = verify;
    @import("std").testing.refAllDecls(Client);
}

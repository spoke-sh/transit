// SPDX-License-Identifier: MIT
//! Selected byte-transport HTTP/2 client surface; see compatibility.patch.
pub const Method = enum {
    get,
    head,
    post,
    put,
    delete,
    patch,
    options,

    /// The on-wire token, e.g. `.get` → "GET".
    pub fn token(m: Method) []const u8 {
        return switch (m) {
            .get => "GET",
            .head => "HEAD",
            .post => "POST",
            .put => "PUT",
            .delete => "DELETE",
            .patch => "PATCH",
            .options => "OPTIONS",
        };
    }
};

pub const Header = struct { name: []const u8, value: []const u8 };

pub const h1 = @import("h1.zig");
pub const hpack = @import("hpack.zig");
pub const h2 = @import("h2.zig");
pub const h2_client = @import("h2_client.zig");
test { _ = h1; _ = hpack; _ = h2; _ = h2_client; }

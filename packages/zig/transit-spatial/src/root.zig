//! Deterministic spatial interpretation and geometry. No I/O or authority.
pub const Reference = @import("Reference.zig");
pub const Predicates = @import("Predicates.zig");
pub const Planar = @import("Planar.zig");

test {
    _ = Reference;
    _ = Predicates;
    _ = Planar;
}

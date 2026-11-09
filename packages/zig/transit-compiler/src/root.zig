//! Pure source compilation. Tooling supplies immutable resolved buffers.
pub const Syntax = @import("Syntax.zig");
pub const Graph = @import("Graph.zig");
pub const Compiler = @import("Compiler.zig");
pub const compile = Compiler.compile;
pub const Source = Graph.Source;
pub const Options = Compiler.Options;
pub const Product = Compiler.Product;
test {
    _ = @import("tests.zig");
}

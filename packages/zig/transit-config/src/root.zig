//! Shared typed configuration input and domain-owned setting descriptions.
pub const Input = @import("Input.zig");
pub const Registry = @import("Registry.zig");
pub const Contract = @import("Contract.zig");
test {
    _ = Input;
    _ = Registry;
    _ = Contract;
}

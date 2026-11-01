//! Frozen Queue work in the catalog's common operation namespace. An identity
//! reservation grants no rights and establishes no Queue acceptance.
const workload = @import("root.zig").protocol.LogWorkload;
pub const Request = workload.QueueRequest;
pub const Binding = workload.QueueBinding;

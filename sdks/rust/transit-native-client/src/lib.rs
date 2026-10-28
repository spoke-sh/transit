//! Version-matched native bytes. No initialization or ambient credential reads.
pub const VERSION: &str = "0.0.1";
pub const LIBRARY: &[u8] = include_bytes!(env!("TRANSIT_EMBEDDED_CLIENT"));

//! Version-matched native bytes; loading this crate starts no work.
pub const VERSION: &str = "0.0.1";
pub const LIBRARY: &[u8] = include_bytes!(env!("TRANSIT_EMBEDDED_STATION"));

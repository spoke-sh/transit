//! Thin Rust client bindings for talking to a running `transit` server.
//!
//! This crate gives external Rust callers a native entry point without
//! re-implementing protocol or storage semantics outside the shared engine
//! workspace.

mod client;

pub use client::{ClientResult, TransitClient};

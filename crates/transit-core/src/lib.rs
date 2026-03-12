//! Shared bootstrap and storage-facing interfaces for `transit`.
//!
//! The first slice keeps the CLI thin and concentrates reusable workspace,
//! mission, and object-store concerns in the core crate.

pub mod bootstrap;
pub mod kernel;
pub mod object_store_support;

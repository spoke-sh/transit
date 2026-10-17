//! Independent typed Transit client. The public controlling API is blocking.
#[rustfmt::skip]
mod abi;
mod client;
mod error;
mod library;
mod native;
mod types;
mod worker;
pub use client::{
    Client, ClientShutdown, DispatchError, MutationInfo, PendingMutation, PendingSend, SendInfo,
};
pub use error::{Error, ErrorKind, Result};
pub use types::{
    AdmissionReceipt, Capabilities, ClientConfig, Correlation, Counter, Credential,
    MutationReceipt, OperationIdentity, ProcessRef, ResourceRef, Sequence,
};
pub use worker::StopToken;

/// Version-matched package interface for the Station SDK; no protocol duplication.
#[doc(hidden)]
pub mod internal {
    pub use crate::abi::{MAX_BODY, MAX_COUNTER, MINIMUM_STACK_BYTES, VALUE_BYTES};
    pub use crate::library::Artifact;
    pub use crate::native::{Native, Seed, boolean, hex, number, string, unhex};
    pub use crate::worker::Worker;
    pub fn mutation_info(value: &serde_json::Value) -> crate::Result<crate::MutationInfo> {
        crate::client::info(value)
    }
    pub fn native_error(
        status: u32,
        value: Option<&serde_json::Value>,
        phase: &'static str,
    ) -> crate::Error {
        crate::Error::native(status, value, phase)
    }
    pub fn settings(config: &crate::ClientConfig) -> (&str, u32, Option<&std::path::Path>) {
        (
            &config.url,
            config.timeout_ms,
            config.native_directory.as_deref(),
        )
    }
    pub fn credential_seed(credential: &crate::Credential) -> crate::Result<Seed> {
        Seed::read(credential.seed_file())
    }
}

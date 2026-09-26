//! Typed categories without credentials, payloads or retry bytes in diagnostics.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ErrorKind {
    InvalidArgument,
    Busy,
    Closed,
    IncompatibleNative,
    UnsupportedCapability,
    Rejected,
    AccessDenied,
    StaleOwnership,
    ProcessRetired,
    HistoryUnavailable,
    ReadFailed,
    TurnExpired,
    Codec,
    Handler,
    MissingValue,
    UnknownOutcome,
    WorkerPanic,
}
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Error {
    pub kind: ErrorKind,
    pub status: Option<u32>,
    pub code: Option<String>,
    pub phase: &'static str,
}
pub type Result<T> = std::result::Result<T, Error>;
impl Error {
    pub fn new(kind: ErrorKind, phase: &'static str) -> Self {
        Self {
            kind,
            status: None,
            code: None,
            phase,
        }
    }
    pub(crate) fn native(
        status: u32,
        value: Option<&serde_json::Value>,
        phase: &'static str,
    ) -> Self {
        let code = value
            .and_then(|v| {
                v.get("protocol_error")
                    .and_then(serde_json::Value::as_str)
                    .or_else(|| v.get("err").and_then(serde_json::Value::as_str))
            })
            .filter(|s| s.len() <= 256)
            .map(str::to_owned);
        let kind = match code.as_deref() {
            Some("ProcessExpired" | "ProcessTerminated") => ErrorKind::ProcessRetired,
            Some("HistoryReclaimed" | "QueryExpired") => ErrorKind::HistoryUnavailable,
            Some("StaleActivation") => ErrorKind::StaleOwnership,
            _ => match status {
                3 | 5 => ErrorKind::Rejected,
                4 => ErrorKind::AccessDenied,
                6 => ErrorKind::UnknownOutcome,
                7 | 8 => ErrorKind::ReadFailed,
                9 => ErrorKind::Busy,
                10 => ErrorKind::IncompatibleNative,
                11 => ErrorKind::StaleOwnership,
                13 => ErrorKind::TurnExpired,
                _ => ErrorKind::InvalidArgument,
            },
        };
        Self {
            kind,
            status: Some(status),
            code,
            phase,
        }
    }
}
impl std::fmt::Display for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Transit {:?} during {}", self.kind, self.phase)?;
        if let Some(status) = self.status {
            write!(f, " (status {status})")?;
        }
        if self.kind == ErrorKind::IncompatibleNative {
            write!(
                f,
                "; install the matching native 0.2.0 artifact or supply a valid native directory"
            )?;
        }
        Ok(())
    }
}
impl std::error::Error for Error {}

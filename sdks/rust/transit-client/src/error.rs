//! Typed categories with owned caller detail excluded from Display and Debug.
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
#[derive(Clone, Eq, PartialEq)]
pub struct Error {
    pub kind: ErrorKind,
    pub status: Option<u32>,
    pub code: Option<String>,
    pub phase: &'static str,
    pub diagnostic: Option<serde_json::Value>,
    pub diagnostic_invalid: bool,
}
pub type Result<T> = std::result::Result<T, Error>;
impl Error {
    pub fn new(kind: ErrorKind, phase: &'static str) -> Self {
        Self {
            kind,
            status: None,
            code: None,
            phase,
            diagnostic: None,
            diagnostic_invalid: false,
        }
    }
    /// Optional detail never changes the primary native status or uncertainty.
    pub fn with_diagnostic(
        mut self,
        value: &serde_json::Value,
        valid: impl FnOnce(&[u8]) -> bool,
    ) -> Self {
        if let Some(detail) = value.get("diagnostic").filter(|v| !v.is_null()) {
            match serde_json::to_vec(detail) {
                Ok(bytes) if bytes.len() <= 32768 && valid(&bytes) => {
                    self.diagnostic = Some(detail.clone())
                }
                _ => self.diagnostic_invalid = true,
            }
        }
        self
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
        let kind = if status == 6 {
            ErrorKind::UnknownOutcome
        } else {
            match code.as_deref() {
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
            }
        };
        Self {
            kind,
            status: Some(status),
            code,
            phase,
            diagnostic: None,
            diagnostic_invalid: false,
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
                "; install the matching native 0.0.1 artifact or supply a valid native directory"
            )?;
        }
        Ok(())
    }
}
impl std::error::Error for Error {}

impl std::fmt::Debug for Error {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Error")
            .field("kind", &self.kind)
            .field("status", &self.status)
            .field("code", &self.code)
            .field("phase", &self.phase)
            .field("diagnostic_present", &self.diagnostic.is_some())
            .field("diagnostic_invalid", &self.diagnostic_invalid)
            .finish()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn optional_detail_cannot_replace_unknown_outcome_or_enter_debug_text() {
        let detail = serde_json::json!({"err":"ProcessExpired", "diagnostic":{"message":"private SQL context"}});
        let error = Error::native(6, Some(&detail), "submit").with_diagnostic(&detail, |_| false);
        assert_eq!(ErrorKind::UnknownOutcome, error.kind);
        assert!(error.diagnostic_invalid && error.diagnostic.is_none());
        let retained = Error::native(6, Some(&detail), "submit").with_diagnostic(&detail, |_| true);
        assert_eq!(retained.diagnostic, Some(detail["diagnostic"].clone()));
        assert!(!format!("{retained:?}").contains("private SQL"));
        assert!(!retained.to_string().contains("private SQL"));
    }
}

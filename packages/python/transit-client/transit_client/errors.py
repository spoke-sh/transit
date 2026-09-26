"""Errors preserve native status, authority code and attempt phase, without data."""
from __future__ import annotations


class TransitError(Exception):
    def __init__(self, message: str, *, status: int | None = None, code: str | None = None,
                 phase: str = "preflight") -> None:
        self.status, self.code, self.phase = status, code, phase
        super().__init__(message)


class Busy(TransitError): pass
class Closed(TransitError): pass
class IncompatibleNative(TransitError): pass
class UnsupportedCapability(TransitError): pass
class AuthorityRejected(TransitError): pass
class AccessDenied(AuthorityRejected): pass
class StaleOwnership(AuthorityRejected): pass
class ProcessRetired(AuthorityRejected): pass
class HistoryUnavailable(TransitError): pass
class ReadFailed(TransitError): pass
class TurnExpired(TransitError): pass
class CodecError(TransitError): pass
class MissingValue(TransitError): pass
class HandlerError(TransitError): pass


class UncertainOperation(TransitError):
    def __init__(self, *, recovery: bytes, code: str | None = None, phase: str = "dispatch") -> None:
        self.recovery = bytes(recovery)
        super().__init__("Mutation outcome is unknown; retain exact recovery material", status=6,
                         code=code, phase=phase)


def native_error(status: int, detail: object = None, *, phase: str = "native",
                 recovery: bytes = b"") -> TransitError:
    code = None
    if isinstance(detail, dict):
        candidate = detail.get("protocol_error") or detail.get("err")
        if isinstance(candidate, str):
            code = candidate
    if status == 6:
        return UncertainOperation(recovery=recovery, code=code, phase=phase)
    category: type[TransitError]
    if code in ("ProcessExpired", "ProcessTerminated"):
        category = ProcessRetired
    elif code in ("HistoryReclaimed", "QueryExpired"):
        category = HistoryUnavailable
    elif status == 4:
        category = AccessDenied
    elif status == 11 or code == "StaleActivation":
        category = StaleOwnership
    else:
        category = {3: AuthorityRejected, 5: AuthorityRejected, 7: ReadFailed, 8: ReadFailed,
                    9: Busy, 10: IncompatibleNative, 13: TurnExpired}.get(status, TransitError)
    return category(f"Transit {phase} failed (status {status}, code {code or 'unavailable'})",
                    status=status, code=code, phase=phase)

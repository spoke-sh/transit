namespace Transit.Client;

public enum ErrorKind
{
    Busy, Closed, IncompatibleNative, UnsupportedCapability, AuthorityRejected,
    AccessDenied, StaleOwnership, ProcessRetired, HistoryUnavailable, ReadFailed,
    TurnExpired, Codec, Handler, MissingValue, UnknownOutcome, Blocked, BudgetExceeded, Cleanup
}

/// <summary>Bounded diagnostics, excluding credentials, paths and signed bodies.</summary>
public sealed class TransitException(ErrorKind kind, string phase, uint? status = null, string? code = null)
    : Exception($"Transit {phase} failed ({kind})" + (kind == ErrorKind.IncompatibleNative
        ? "; install matching Transit 0.2.0 packages or provide a compatible native directory" : ""))
{
    public ErrorKind Kind { get; } = kind;
    public string Phase { get; } = phase;
    public uint? Status { get; } = status;
    public string? Code { get; } = code;
    public bool Rejected => Kind is ErrorKind.AuthorityRejected or ErrorKind.AccessDenied or ErrorKind.StaleOwnership or ErrorKind.ProcessRetired;
}

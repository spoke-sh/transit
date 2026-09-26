package io.transit.client;

/** Bounded diagnostics; never includes request bodies, seed paths or native payloads. */
public final class TransitException extends RuntimeException {
    private static final long serialVersionUID = 1L;
    public enum Kind {
        BUSY, CLOSED, INCOMPATIBLE_NATIVE, UNSUPPORTED_CAPABILITY, AUTHORITY_REJECTED,
        ACCESS_DENIED, STALE_OWNERSHIP, PROCESS_RETIRED, HISTORY_UNAVAILABLE,
        READ_FAILED, TURN_EXPIRED, CODEC, HANDLER, MISSING_VALUE, UNKNOWN_OUTCOME, CLEANUP
    }
    private final Kind kind;
    private final int status;
    private final String code;
    private final String phase;
    public TransitException(Kind kind, int status, String code, String phase) {
        super("Transit " + phase + " failed (" + kind + ")" + (kind == Kind.INCOMPATIBLE_NATIVE ?
            "; install matching Transit 0.2.0 JARs or provide a compatible native executable" : ""));
        this.kind = kind; this.status = status; this.code = code; this.phase = phase;
    }
    public TransitException(Kind kind, String phase) { this(kind, -1, null, phase); }
    public Kind kind() { return kind; }
    public int status() { return status; }
    public String code() { return code; }
    public String phase() { return phase; }
    public boolean rejected() {
        return switch (kind) {
            case AUTHORITY_REJECTED, ACCESS_DENIED, STALE_OWNERSHIP, PROCESS_RETIRED -> true;
            default -> false;
        };
    }
}

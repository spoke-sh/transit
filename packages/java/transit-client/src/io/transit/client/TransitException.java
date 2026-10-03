package io.transit.client;

import com.google.gson.JsonObject;
import io.transit.client.internal.Values;
import java.io.IOException;
import java.nio.charset.StandardCharsets;

/** Owned optional caller diagnostics; ordinary exception text excludes their content. */
public final class TransitException extends RuntimeException {
    private static final long serialVersionUID = 1L;
    public enum Kind {
        BUSY, CLOSED, INCOMPATIBLE_NATIVE, UNSUPPORTED_CAPABILITY, AUTHORITY_REJECTED,
        ACCESS_DENIED, STALE_OWNERSHIP, PROCESS_RETIRED, HISTORY_UNAVAILABLE,
        READ_FAILED, TURN_EXPIRED, CODEC, HANDLER, MISSING_VALUE, UNKNOWN_OUTCOME, BLOCKED, BUDGET_EXCEEDED, CLEANUP
    }
    private final Kind kind;
    private final int status;
    private final String code;
    private final String phase;
    private final String diagnostic;
    private final boolean diagnosticInvalid;
    public TransitException(Kind kind, int status, String code, String phase) {
        this(kind, status, code, phase, null, false);
    }
    public TransitException(Kind kind, int status, String code, String phase, JsonObject diagnostic, boolean diagnosticInvalid) {
        super("Transit " + phase + " failed (" + kind + ")" + (kind == Kind.INCOMPATIBLE_NATIVE ?
            "; install matching Transit 0.2.0 JARs or provide a compatible native executable" : ""));
        this.kind = kind; this.status = status; this.code = code; this.phase = phase;
        this.diagnostic = diagnostic == null ? null : diagnostic.toString(); this.diagnosticInvalid = diagnosticInvalid;
    }
    public TransitException(Kind kind, String phase) { this(kind, -1, null, phase); }
    public Kind kind() { return kind; }
    public int status() { return status; }
    public String code() { return code; }
    public String phase() { return phase; }
    public JsonObject diagnostic() {
        if (diagnostic == null) return null;
        try { return Values.object(Values.parse(diagnostic.getBytes(StandardCharsets.UTF_8))); }
        catch (IOException error) { throw new IllegalStateException("Invalid retained diagnostic", error); }
    }
    public boolean diagnosticInvalid() { return diagnosticInvalid; }
    public boolean rejected() {
        return switch (kind) {
            case AUTHORITY_REJECTED, ACCESS_DENIED, STALE_OWNERSHIP, PROCESS_RETIRED -> true;
            default -> false;
        };
    }
}

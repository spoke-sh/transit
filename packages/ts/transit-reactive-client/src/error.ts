import { ownedDiagnostic, type Diagnostic } from "@rey/transit-diagnostics";

export class ReactiveError extends Error {
  readonly diagnostic?: Diagnostic;
  readonly diagnosticInvalid: boolean;
  /** A later current-scope read can fail independently of the original rejection. */
  scopeFailure?: ReactiveError;
  constructor(
    readonly status: number,
    readonly reason: string,
    detail?: unknown,
  ) {
    super(reason);
    const owned = ownedDiagnostic(detail);
    this.diagnostic = owned.diagnostic;
    this.diagnosticInvalid = owned.invalid;
  }
  get clearsProtectedState(): boolean {
    return (
      this.status === 403 ||
      (this.status === 410 && this.reason !== "unavailable") ||
      this.reason === "denied" ||
      this.reason === "expired" ||
      this.reason === "closed" ||
      this.reason === "ReactiveSessionClosed" ||
      this.reason === "ReactiveSessionExpired" ||
      this.reason === "ServingDenied" ||
      this.reason === "AccessDenied" ||
      this.scopeFailure?.clearsProtectedState === true
    );
  }
}

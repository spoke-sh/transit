import { ownedDiagnostic } from "./diagnostics";
import type { Diagnostic } from "./types";
export class QueryError extends Error {
  readonly diagnostic: Diagnostic | undefined;
  readonly diagnosticInvalid: boolean;
  constructor(
    readonly status: number,
    readonly code: string,
    detail?: unknown,
  ) {
    super(code);
    const owned = ownedDiagnostic(detail);
    this.diagnostic = owned.diagnostic;
    this.diagnosticInvalid = owned.invalid;
  }
}

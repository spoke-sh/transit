import { ownedDiagnostic, type Diagnostic } from "@transit/diagnostics";
export class ApplicationTransportError extends Error {
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
export function diagnosticOf(value: unknown): unknown {
  return typeof value === "object" && value !== null && "diagnostic" in value
    ? value.diagnostic
    : undefined;
}

/** Native categories, with no payloads or signed recovery bytes in diagnostics. */
export class TransitError extends Error {
  readonly status: number | undefined;
  readonly code: string | undefined;
  readonly phase: string;
  constructor(message: string, options: { status?: number; code?: string; phase?: string } = {}) {
    super(message);
    this.name = new.target.name;
    this.status = options.status;
    this.code = options.code;
    this.phase = options.phase ?? "preflight";
  }
}
export class Busy extends TransitError {}
export class Closed extends TransitError {}
export class IncompatibleNative extends TransitError {}
export class UnsupportedCapability extends TransitError {}
export class AuthorityRejected extends TransitError {}
export class AccessDenied extends AuthorityRejected {}
export class StaleOwnership extends AuthorityRejected {}
export class ProcessRetired extends AuthorityRejected {}
export class HistoryUnavailable extends TransitError {}
export class ReadFailed extends TransitError {}
export class TurnExpired extends TransitError {}
export class CodecError extends TransitError {}
export class HandlerError extends TransitError {}
export class MissingValue extends TransitError {}
export class UnknownOutcome extends TransitError {}

export function nativeError(status: number, value: unknown, phase: string): TransitError {
  let code: string | undefined;
  if (value !== null && typeof value === "object") {
    const fields = value as Record<string, unknown>;
    const candidate = fields.protocol_error ?? fields.err;
    if (typeof candidate === "string") code = candidate;
  }
  let category: typeof TransitError = TransitError;
  if (code === "ProcessExpired" || code === "ProcessTerminated") category = ProcessRetired;
  else if (code === "HistoryReclaimed" || code === "QueryExpired") category = HistoryUnavailable;
  else if (status === 4) category = AccessDenied;
  else if (status === 11 || code === "StaleActivation") category = StaleOwnership;
  else {
    category =
      (
        {
          3: AuthorityRejected,
          5: AuthorityRejected,
          6: UnknownOutcome,
          7: ReadFailed,
          8: ReadFailed,
          9: Busy,
          10: IncompatibleNative,
          13: TurnExpired,
        } as Record<number, typeof TransitError>
      )[status] ?? TransitError;
  }
  return new category(`Transit ${phase} failed`, { status, code, phase });
}

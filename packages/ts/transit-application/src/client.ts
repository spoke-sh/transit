import { acquireCaller, type AcquireCaller } from "@rey/transit-reactive-client";
import { ownedDiagnostic, type Diagnostic } from "@rey/transit-query-client";
import * as validate from "./validators.js";
import type {
  Command,
  Compiled,
  HostRequest,
  HostResponse,
  Observation,
  PreparedRead,
  Scope,
  Signed,
} from "./types";

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
export type Transport = (request: HostRequest) => Promise<HostResponse>;
export async function request(value: HostRequest): Promise<HostResponse> {
  if (!validate.HostRequest(value)) throw new Error("Invalid application request");
  for (let attempt = 0; ; attempt++) {
    const response = await fetch("/api/v1/application", {
      method: "POST",
      headers: { "content-type": "application/json" },
      credentials: "same-origin",
      cache: "no-store",
      redirect: "error",
      body: JSON.stringify(value),
    });
    // This endpoint rejects before native admission when throttled. Reuse the
    // entire request, including any frozen native signature.
    if (response.status === 429 && attempt < 4) {
      await new Promise((resolve) => setTimeout(resolve, 250));
      continue;
    }
    const result: unknown = await response.json();
    if (!response.ok) {
      const code =
        typeof result === "object" &&
        result !== null &&
        "err" in result &&
        typeof result.err === "string"
          ? result.err
          : "Unavailable";
      throw new ApplicationTransportError(response.status, code, diagnosticOf(result));
    }
    if (!validate.HostResponse(result)) throw new Error("Invalid application response");
    return result as HostResponse;
  }
}
export async function compile(source: string, transport: Transport = request): Promise<Compiled> {
  const result = await transport({ compile: { source } });
  if (!("compiled" in result)) throw new Error("Missing complete definition");
  return result.compiled;
}
export async function importOperatorKey(pkcs8: ArrayBuffer): Promise<CryptoKey> {
  return crypto.subtle.importKey("pkcs8", pkcs8, "Ed25519", false, ["sign"]);
}
export type Signer = (digest: number[]) => Promise<number[]>;
export const keySigner =
  (key: CryptoKey): Signer =>
  async (digest) =>
    Array.from(new Uint8Array(await crypto.subtle.sign("Ed25519", key, new Uint8Array(digest))));
const ordered = (value: unknown): unknown => {
  if (Array.isArray(value)) return value.map(ordered);
  if (value !== null && typeof value === "object")
    return Object.fromEntries(
      Object.entries(value)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([key, item]) => [key, ordered(item)]),
    );
  return value;
};
const same = (a: unknown, b: unknown) => JSON.stringify(ordered(a)) === JSON.stringify(ordered(b));

/** One bounded outstanding native submission. Keep this owner across UI route
 * and definition changes. A transport failure never allocates a new identity. */
export class OperatorSession {
  pending: Signed | null = null;
  lastAdmission: number | null = null;
  private busy = false;
  private release: (() => void) | null = null;
  constructor(
    readonly scope: Scope,
    readonly principal: number,
    private sign: Signer,
    private transport: Transport = request,
    private coordinate: AcquireCaller = acquireCaller,
  ) {}
  async read(selection: PreparedRead["selection"]): Promise<Observation> {
    const prepared = await this.transport({
      prepare_read: { principal: this.principal, selection },
    });
    if (
      !("prepared_read" in prepared) ||
      !same(prepared.prepared_read.scope, this.scope) ||
      prepared.prepared_read.principal !== this.principal ||
      !same(prepared.prepared_read.selection, selection)
    )
      throw new Error("Application read scope changed");
    const result = await this.transport({
      read: {
        prepared: prepared.prepared_read,
        signature: await this.sign(prepared.prepared_read.digest),
      },
    });
    if (!("observation" in result)) throw new Error("Missing signed observation");
    return result.observation;
  }
  async submit(command: Command): Promise<number> {
    if (this.busy || this.pending) throw new Error("Recover the outstanding operation first");
    this.busy = true;
    try {
      this.release ??= await this.coordinate(
        { realm: this.scope.realm, principal: this.principal },
        AbortSignal.timeout(5000),
      );
      const identity = await this.read({ identity: {} });
      if (!("identity" in identity) || identity.identity.principal !== this.principal)
        throw new Error("Operator identity changed");
      const sequence = (BigInt(identity.identity.sequence) + 1n).toString();
      const response = await this.transport({
        prepare: { principal: this.principal, sequence, command },
      });
      if (
        !("prepared" in response) ||
        !same(response.prepared.scope, this.scope) ||
        response.prepared.principal !== this.principal ||
        response.prepared.sequence !== sequence ||
        !same(response.prepared.command, command)
      )
        throw new Error("Application command changed");
      const frozen = {
        prepared: response.prepared,
        signature: await this.sign(response.prepared.digest),
      };
      this.pending = structuredClone(frozen);
      return await this.forward();
    } finally {
      if (!this.pending) {
        this.release?.();
        this.release = null;
      }
      this.busy = false;
    }
  }
  async retry(): Promise<number> {
    if (this.busy || !this.pending) throw new Error("No recoverable submission");
    this.busy = true;
    try {
      this.release ??= await this.coordinate(
        { realm: this.scope.realm, principal: this.principal },
        AbortSignal.timeout(5000),
      );
      return await this.forward();
    } finally {
      if (!this.pending) {
        this.release?.();
        this.release = null;
      }
      this.busy = false;
    }
  }
  private async forward(): Promise<number> {
    if (!this.pending) throw new Error("No frozen submission");
    // Retain on every failure, including known denial: inspect/review before
    // discarding. This also prevents a generic HTTP error pretending to settle
    // the earlier native operation.
    const response = await this.transport({ submit: structuredClone(this.pending) });
    if (!("admitted" in response) || response.admitted.position <= 0)
      throw new Error("Missing admission receipt");
    this.lastAdmission = response.admitted.position;
    this.pending = null;
    return response.admitted.position;
  }
  exportPending(): string {
    if (!this.pending) throw new Error("No frozen submission");
    return JSON.stringify(this.pending);
  }
  restorePending(source: string): void {
    if (this.busy || this.pending || source.length > 16 * 1024)
      throw new Error("Cannot restore pending submission");
    const value: unknown = JSON.parse(source);
    if (!validate.Signed(value)) throw new Error("Invalid pending submission");
    const signed = value as Signed;
    if (!same(signed.prepared.scope, this.scope) || signed.prepared.principal !== this.principal)
      throw new Error("Pending submission has another scope");
    this.pending = structuredClone(signed);
  }
}

export type Review = {
  scope: Scope;
  principal: number;
  compiled: Compiled;
  proposal: import("./types").Proposal;
  lastInput: number;
};
const randomIdentity = (): string => {
  const bytes = crypto.getRandomValues(new Uint32Array(2));
  return ((BigInt(bytes[0]!) << 32n) | BigInt(bytes[1]!) | 1n).toString();
};
export async function reviewPublication(
  session: OperatorSession,
  compiled: Compiled,
  transport: Transport = request,
): Promise<Review> {
  const observed = await session.read({ state: { operation: "0", record: "0", input: 0 } });
  if (!("state" in observed)) throw new Error("Missing application state");
  const head = observed.state.head;
  const definition = {
    ...compiled.definition,
    realm: session.scope.realm,
    revision: (BigInt(head?.revision ?? "0") + 1n).toString(),
  };
  const normalized = await transport({ format: definition });
  if (!("compiled" in normalized)) throw new Error("Missing complete definition");
  return {
    scope: structuredClone(session.scope),
    principal: session.principal,
    compiled: normalized.compiled,
    lastInput: 0,
    proposal: {
      operation: randomIdentity(),
      record: randomIdentity(),
      expected: head?.revision ?? "0",
      expected_digest: head?.spec.digest ?? Array(32).fill(0),
      revision: definition.revision,
      spec: normalized.compiled.spec,
    },
  };
}
/** Bounded host scheduling only. Zig selects each continuation and the durable
 * owner revalidates policy, proposal and body at every admitted command. */
export async function publish(
  session: OperatorSession,
  review: Review,
  progress: (text: string) => void,
  transport: Transport = request,
): Promise<void> {
  return advancePublication(session, review, progress, transport, false);
}

/** Explicit abandonment never rolls back an applied interface. Collection only
 * releases this upload's reservation; permanent receipts and history survive. */
export async function abandonPublication(
  session: OperatorSession,
  review: Review,
  progress: (text: string) => void,
  transport: Transport = request,
): Promise<void> {
  return advancePublication(session, review, progress, transport, true);
}

async function advancePublication(
  session: OperatorSession,
  review: Review,
  progress: (text: string) => void,
  transport: Transport,
  cleanup: boolean,
): Promise<void> {
  if (!same(review.scope, session.scope) || review.principal !== session.principal)
    throw new Error("Reviewed plan has another operator or scope");
  if (session.pending) throw new Error("Retry the exact pending submission first");
  let previous = "";
  let unchanged = 0;
  // A prior publication denial does not forbid an explicit attempt to abandon.
  // Every input admitted by this invocation still requires its own observation.
  let input = cleanup ? 0 : review.lastInput;
  for (let steps = 0; steps < 520;) {
    const observation = await session.read({
      state: {
        operation: review.proposal.operation,
        record: review.proposal.record,
        input,
      },
    });
    if (!("state" in observation)) throw new Error("Missing application state");
    const state = observation.state;
    if (state.disposition !== null)
      throw new Error(
        "The application retained a rejected input; review current policy and operation status",
      );
    const response = await transport(
      cleanup
        ? { next_cleanup: { proposal: review.proposal, state } }
        : {
            next_upload: { proposal: review.proposal, canonical: review.compiled.canonical, state },
          },
    );
    const next =
      cleanup && "next_cleanup" in response
        ? response.next_cleanup
        : !cleanup && "next_upload" in response
          ? response.next_upload
          : undefined;
    if (next === undefined) throw new Error("Missing publication continuation");
    if (next === null) {
      progress(
        cleanup
          ? "Upload abandoned; staging reservation released. History retained."
          : `Published revision ${review.proposal.revision}`,
      );
      return;
    }
    const current = JSON.stringify([next, state.upload, state.receipt?.phase]);
    if (current === previous) {
      if (++unchanged > 80)
        throw new Error(
          "Accepted input is still awaiting progress. Resume this reviewed operation later.",
        );
      await new Promise((resolve) => setTimeout(resolve, 250));
      continue;
    }
    unchanged = 0;
    progress(
      cleanup
        ? `Cleaning abandoned upload · ${state.upload?.collected ?? 0} of ${state.upload?.written ?? 0} chunks collected`
        : `Staging revision ${review.proposal.revision} · ${state.upload?.written ?? 0} committed chunks`,
    );
    review.lastInput = input = await session.submit(next);
    steps++;
    previous = current;
  }
  throw new Error("Upload step budget reached; inspect this operation before resuming");
}

export type InterfaceView = Extract<HostResponse, { builtin: unknown } | { published: unknown }>;
export async function readInterface(signal?: AbortSignal): Promise<InterfaceView> {
  for (let attempt = 0; ; attempt++) {
    const response = await fetch("/api/v1/interface", {
      cache: "no-store",
      redirect: "error",
      signal,
    });
    if (response.status === 429 && attempt < 4 && !signal?.aborted) {
      await response.body?.cancel();
      await new Promise((resolve) => setTimeout(resolve, 250));
      continue;
    }
    if (!response.ok) {
      const failure: unknown = await response.json().catch(() => null);
      const code =
        typeof failure === "object" &&
        failure !== null &&
        "err" in failure &&
        typeof failure.err === "string" &&
        /^[A-Za-z][A-Za-z0-9_]{0,127}$/.test(failure.err)
          ? failure.err
          : "InterfaceUnavailable";
      if (
        response.status === 503 &&
        (code === "AuthorityUnavailable" || code === "AuthorityTimeout") &&
        attempt < 4 &&
        !signal?.aborted
      ) {
        await new Promise((resolve) => setTimeout(resolve, 250));
        continue;
      }
      throw new ApplicationTransportError(response.status, code, diagnosticOf(failure));
    }
    const result: unknown = await response.json();
    if (
      !validate.HostResponse(result) ||
      typeof result !== "object" ||
      result === null ||
      !("builtin" in result || "published" in result)
    )
      throw new Error("Invalid interface observation");
    return result as InterfaceView;
  }
}

function diagnosticOf(value: unknown): unknown {
  return typeof value === "object" && value !== null && "diagnostic" in value
    ? value.diagnostic
    : undefined;
}

export function restoreReview(source: string, session: OperatorSession): Review {
  if (source.length > 1024 * 1024) throw new Error("Reviewed plan too large");
  const value: unknown = JSON.parse(source);
  if (
    typeof value !== "object" ||
    value === null ||
    Object.keys(value).sort().join(",") !== "compiled,lastInput,principal,proposal,scope" ||
    !("compiled" in value) ||
    !("proposal" in value) ||
    !("lastInput" in value) ||
    !("scope" in value) ||
    !("principal" in value) ||
    !validate.Scope(value.scope) ||
    value.principal !== session.principal ||
    !same(value.scope, session.scope) ||
    !validate.Compiled(value.compiled) ||
    !validate.Proposal(value.proposal) ||
    typeof value.lastInput !== "number" ||
    !Number.isSafeInteger(value.lastInput) ||
    value.lastInput < 0
  )
    throw new Error("Invalid reviewed plan");
  return value as Review;
}

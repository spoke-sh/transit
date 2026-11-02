import { scheduleRequest } from "@transit/reactive-client/request-scheduling";
import { ApplicationTransportError, diagnosticOf } from "./error";
import type { HostResponse } from "./types";
import * as validate from "./validators.js";
export type InterfaceView = Extract<HostResponse, { builtin: unknown } | { published: unknown }>;
export function readInterface(signal?: AbortSignal): Promise<InterfaceView> {
  return scheduleRequest("read", () => interfaceRequest(signal), signal);
}
async function interfaceRequest(signal?: AbortSignal): Promise<InterfaceView> {
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
    let result: unknown;
    try {
      result = await response.json();
    } catch (cause) {
      if (signal?.aborted) throw cause;
      throw new ApplicationTransportError(0, "InvalidResponse");
    }
    if (
      !validate.HostResponse(result) ||
      typeof result !== "object" ||
      result === null ||
      !("builtin" in result || "published" in result)
    )
      throw new ApplicationTransportError(0, "InvalidResponse");
    return result as InterfaceView;
  }
}

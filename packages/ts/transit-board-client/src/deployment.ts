import type { Deployment, Capabilities } from "./types";
import { readDefinition } from "@transit/query-client/definition";
import {
  Deployment as deploymentValidator,
  Capabilities as capabilitiesValidator,
} from "./host-validators.js";
import { request } from "./request";
export const validateCapabilities = (value: unknown): value is Capabilities =>
  capabilitiesValidator(value);
export const validateDeployment = (value: unknown): value is Deployment =>
  deploymentValidator(value) && (value as Deployment).definition === readDefinition;
export const deployment = (signal?: AbortSignal): Promise<Deployment> =>
  request("/api/v1/deployment", validateDeployment, { signal });
export const capabilities = (signal?: AbortSignal) =>
  request("/api/v1/capabilities", validateCapabilities, { signal });

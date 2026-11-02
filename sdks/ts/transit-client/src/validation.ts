// Generated functions validate immediately without runtime schema compilation.
import type { ValidateFunction } from "ajv";
import * as compiled from "./validators.js";

// Standalone validators expose the predicate and complete error details. They
// do not carry the runtime compiler's schema/environment objects.
export type Validator = Pick<ValidateFunction, "errors"> & ((value: unknown) => boolean);
export const validation: Record<string, Validator> = compiled;

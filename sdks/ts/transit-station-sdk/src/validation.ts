// One eagerly compiled schema collection for the package. Sharing validators
// removes repeated compilation without moving validation into the first call.
import { validators } from "@transit/client/internal";
import schemas from "./schemas.json" with { type: "json" };

export const validation = validators(schemas);

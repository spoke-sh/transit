import { currentDefinition, LiveView, ReactiveError, Session } from "@transit/reactive-client";
import { RefreshPreparation } from "@transit/query-client";
import type { Transport as QueryTransport } from "@transit/query-client";

type Saved = {
  version: 1;
  definition: typeof currentDefinition;
  session: string;
  preparation: string | null;
  view: string | null;
};
type Owners<T> = { session: Session; preparation: RefreshPreparation; view: LiveView<T> };
type Storage = Pick<globalThis.Storage, "getItem" | "setItem">;
const key = "transit.query.follow.v1";
const maxBytes = 1179648;

/** Tab-local persistence composes shared owners; it never interprets commands,
 * signs requests or saves result rows. Every write precedes remote dispatch. */
export class FollowRecovery {
  error: string | null = null;
  constructor(private readonly storage: () => Storage) {}
  save<T>(owners: Owners<T>) {
    if (this.error) throw new ReactiveError(0, "follow_recovery_unavailable");
    const saved: Saved = {
      version: 1,
      definition: currentDefinition,
      session: owners.session.exportRecovery(),
      preparation: owners.preparation.recoveryIdentity ? owners.preparation.exportRecovery() : null,
      view: owners.view.exportRecovery(),
    };
    const bytes = JSON.stringify(saved);
    try {
      if (new TextEncoder().encode(bytes).length > maxBytes) throw new Error();
      const storage = this.storage();
      // Hiding a manual worksheet can pause an unused Follow owner. That has
      // no recovery obligation. A reset still replaces an existing saved intent.
      if (
        saved.preparation === null &&
        saved.view === null &&
        owners.session.description === null &&
        owners.session.pending === null &&
        owners.session.scope === null &&
        owners.session.selection === null &&
        storage.getItem(key) === null
      )
        return;
      storage.setItem(key, bytes);
    } catch {
      throw new ReactiveError(0, "follow_recovery_storage_unavailable");
    }
  }
  restore<T>(owners: Owners<T>, query: QueryTransport) {
    try {
      const source = this.storage().getItem(key);
      if (source === null) return;
      if (source.length > maxBytes || new TextEncoder().encode(source).length > maxBytes)
        throw new Error();
      const saved = JSON.parse(source) as Saved;
      if (
        !saved ||
        Object.keys(saved).sort().join(",") !== "definition,preparation,session,version,view" ||
        saved.version !== 1 ||
        saved.definition !== currentDefinition ||
        typeof saved.session !== "string" ||
        (saved.preparation !== null && typeof saved.preparation !== "string") ||
        (saved.view !== null && typeof saved.view !== "string")
      )
        throw new Error();
      // Validate the complete composition on unused, inert owners first. A
      // malformed component cannot leave a half-restored operational caller.
      const session = new Session();
      const preparation = new RefreshPreparation(query);
      const view = new LiveView(session, async () => {
        throw new Error("Inert validation");
      });
      session.restoreRecovery(saved.session);
      if (saved.preparation !== null) preparation.restoreRecovery(saved.preparation);
      if (saved.view !== null) view.restoreRecovery(saved.view);
      const intent = view.recoveryIdentity,
        prepared = preparation.recoveryIdentity;
      if ((session.pending || session.scope || session.selection) && !intent) throw new Error();
      if (
        intent?.captures &&
        (!prepared ||
          prepared.key !== intent.key ||
          prepared.template !== intent.template ||
          prepared.limit !== intent.limit ||
          prepared.captures.some((id, i) => id !== intent.captures![i]))
      )
        throw new Error();
      owners.session.restoreRecovery(saved.session);
      if (saved.preparation !== null) owners.preparation.restoreRecovery(saved.preparation);
      if (saved.view !== null) owners.view.restoreRecovery(saved.view);
    } catch {
      this.error =
        "Saved Follow could not be restored. Its recovery data remains in this tab’s storage.";
    }
  }
}

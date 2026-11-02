import type { CatalogEntry } from "@transit/board-client";
export function datasetLink(entry: CatalogEntry) {
  const object = entry.interpretation.object;
  return {
    object: [
      object.scope.realm,
      object.scope.resource,
      object.scope.catalog,
      object.branch,
      object.object,
    ].join("."),
    search: {
      namespace: entry.namespace,
      name: entry.name,
      revision: entry.interpretation.revision,
      digest: entry.interpretation.digest,
    },
  };
}
export type DatasetSearch = { namespace: number; name: string; revision: string; digest: string };
export function datasetSelection(
  object: string,
  search: DatasetSearch,
): CatalogEntry["interpretation"] {
  const parts = object.split(".");
  if (
    parts.length !== 5 ||
    parts.some((part) => !/^[1-9][0-9]*$/.test(part)) ||
    !Number.isSafeInteger(search.namespace) ||
    search.namespace < 1 ||
    !/^[1-9][0-9]*$/.test(search.revision) ||
    !/^[0-9a-f]{64}$/.test(search.digest)
  )
    throw new Error("Invalid dataset identity");
  const realm = Number(parts[0]),
    resource = Number(parts[1]);
  if (!Number.isSafeInteger(realm) || !Number.isSafeInteger(resource))
    throw new Error("Invalid dataset scope");
  return {
    object: {
      scope: { realm, resource, catalog: parts[2]! },
      branch: parts[3]!,
      object: parts[4]!,
    },
    revision: search.revision,
    digest: search.digest,
  };
}

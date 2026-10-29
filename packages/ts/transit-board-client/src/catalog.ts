import type { CatalogRequest, CatalogResponse } from "./types";
import {
  CatalogRequest as validRequest,
  CatalogResponse as validResponse,
} from "./catalog-validators.js";
import { readDefinition, QueryError, boundedQueryJson } from "@transit/query-client";
import { request } from "./index";
export type { CatalogRequest } from "./types";
type Catalog = Extract<CatalogResponse, { catalog: unknown }>["catalog"];
export type CatalogDescription = Extract<Catalog, { description: unknown }>["description"];
export type CatalogTables = Extract<Catalog, { tables: unknown }>["tables"];
export type CatalogNamespaces = Extract<Catalog, { namespaces: unknown }>["namespaces"];
export type CatalogTable = Extract<CatalogResponse, { table: unknown }>["table"];
export type CatalogEntry = NonNullable<CatalogTables["entries"][number]>;
export type CatalogDependencies = Extract<CatalogResponse, { dependencies: unknown }>["dependencies"];

/** Authorized, bounded metadata. None of these operations starts a data query. */
export class DataCatalog {
  private async call(
    action: CatalogRequest["action"],
    signal?: AbortSignal,
  ): Promise<CatalogResponse> {
    const body: CatalogRequest = { definition: readDefinition, action };
    if (!boundedQueryJson(body) || !validRequest(body))
      throw new QueryError(0, "InvalidCatalogRequest");
    return request(
      "/api/v1/catalog",
      (value: unknown): value is CatalogResponse =>
        boundedQueryJson(value, 262144) && validResponse(value),
      { body, signal },
    );
  }
  async describe(signal?: AbortSignal): Promise<CatalogDescription> {
    const value = await this.call({ describe: {} }, signal);
    if (!("catalog" in value) || !("description" in value.catalog))
      throw new QueryError(0, "InvalidResponse");
    return value.catalog.description;
  }
  async namespaces(
    cursor: CatalogNamespaces["next"] = null,
    signal?: AbortSignal,
  ): Promise<CatalogNamespaces> {
    const value = await this.call({ namespaces: cursor }, signal);
    if (!("catalog" in value) || !("namespaces" in value.catalog))
      throw new QueryError(0, "InvalidResponse");
    return value.catalog.namespaces;
  }
  async tables(
    namespace: number,
    cursor: CatalogTables["next"] = null,
    signal?: AbortSignal,
  ): Promise<CatalogTables> {
    const value = await this.call({ tables: { namespace, cursor } }, signal);
    if (!("catalog" in value) || !("tables" in value.catalog))
      throw new QueryError(0, "InvalidResponse");
    return value.catalog.tables;
  }
  async table(
    namespace: number,
    name: string,
    expected: CatalogEntry["interpretation"],
    signal?: AbortSignal,
  ): Promise<CatalogTable> {
    const value = await this.call({ table: { namespace, name, expected } }, signal);
    if (!("table" in value)) throw new QueryError(0, "InvalidResponse");
    return value.table;
  }
  async dependencies(
    selection: Extract<
      CatalogRequest["action"],
      { dependencies: unknown }
    >["dependencies"]["selection"],
    signal?: AbortSignal,
    cursor: CatalogDependencies["next"] = null,
  ) {
    const value = await this.call(
      { dependencies: { selection, authority: "dependent", cursor } },
      signal,
    );
    if (!("dependencies" in value)) throw new QueryError(0, "InvalidResponse");
    return value.dependencies;
  }
}

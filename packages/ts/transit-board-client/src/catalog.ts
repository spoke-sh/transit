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
export type CatalogDependencies = Extract<
  CatalogResponse,
  { dependencies: unknown }
>["dependencies"];

type HistoryResult = Extract<CatalogResponse, { history: unknown }>["history"];
export type HistoricalSource = Extract<HistoryResult, { source: unknown }>["source"];
export type HistoricalTables = Extract<HistoryResult, { listing: unknown }>["listing"];
export type HistoricalCoverage = Extract<HistoryResult, { coverage: unknown }>["coverage"];
export type HistoricalRead = Extract<CatalogRequest["action"], { history: unknown }>["history"];

type DefinitionsResult = Extract<CatalogResponse, { definitions: unknown }>["definitions"];
export type CatalogDefinitions = Extract<DefinitionsResult, { page: unknown }>["page"];
export type HistoricalDefinition = Extract<
  DefinitionsResult,
  { historical: unknown }
>["historical"];

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
  async historical(action: HistoricalRead, signal?: AbortSignal): Promise<HistoryResult> {
    const value = await this.call({ history: action }, signal);
    if (!("history" in value)) throw new QueryError(0, "InvalidResponse");
    return value.history;
  }
  async historicalTables(
    selector: string,
    namespace: number,
    after: HistoricalTables["next"] = null,
    signal?: AbortSignal,
  ): Promise<HistoricalTables> {
    const value = await this.historical({ list: { selector, namespace, after } }, signal);
    if (!("listing" in value)) throw new QueryError(0, "InvalidResponse");
    return value.listing;
  }
  async historicalSource(
    selector: string,
    object: string,
    signal?: AbortSignal,
  ): Promise<HistoricalSource> {
    const value = await this.historical({ source: { selector, object } }, signal);
    if (!("source" in value)) throw new QueryError(0, "InvalidResponse");
    return value.source;
  }
  async historicalCoverage(
    selector: string,
    object: string,
    kind: "definitions" | "locations",
    after: HistoricalCoverage["next"] = null,
    signal?: AbortSignal,
  ): Promise<HistoricalCoverage> {
    const input = { selector, object, after };
    const value = await this.historical(
      kind === "definitions" ? { definitions: input } : { locations: input },
      signal,
    );
    if (!("coverage" in value)) throw new QueryError(0, "InvalidResponse");
    return value.coverage;
  }
  async definitions(
    namespace: number,
    selector: string | null,
    cursor: CatalogDefinitions["next"] = null,
    signal?: AbortSignal,
  ): Promise<CatalogDefinitions> {
    const value = await this.call(
      { definitions: { list: { namespace, selector, cursor } } },
      signal,
    );
    if (!("definitions" in value) || !("page" in value.definitions))
      throw new QueryError(0, "InvalidResponse");
    return value.definitions.page;
  }
  async historicalDefinition(
    selector: string,
    namespace: number,
    name: string,
    signal?: AbortSignal,
  ): Promise<HistoricalDefinition> {
    const value = await this.call(
      { definitions: { historical: { selector, namespace, name } } },
      signal,
    );
    if (!("definitions" in value) || !("historical" in value.definitions))
      throw new QueryError(0, "InvalidResponse");
    return value.definitions.historical;
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

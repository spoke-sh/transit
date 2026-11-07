import includeDefaultLanguages from "@theme-original/prism-include-languages";
import type includeLanguages from "@theme/prism-include-languages";

const includeTransitLanguages: typeof includeLanguages = (PrismObject) => {
  includeDefaultLanguages(PrismObject);

  // TransitExtensions.g4 owns these declaration and workload words. Keep the
  // standard SQL rules for comments, strings and quoted identifiers ahead of them.
  const sql = PrismObject.languages.sql;
  if (!sql?.keyword) throw new Error("Transit highlighting requires the standard SQL grammar.");
  sql.keyword = [
    /\b(?:ACK|ACTIVATE|AUTHORIZE|CLAIM|CONNECTIONS?|CONSUME|DATAFLOW|DOCUMENT|ENQUEUE|EXTEND|FLOAT64|INT64|KV|LEASE|NACK|PARTITIONS|PRODUCE|PRODUCER|PROJECTING|QUEUES?|RECEIPT|REFRESH|RESUME|RETIRE|REVISION|SINKS?|SOURCES?|STREAMS?|SUSPEND|UINT64|UTF8|VISIBLE_AT|WAIT)\b/i,
    ...(Array.isArray(sql.keyword) ? sql.keyword : [sql.keyword]),
  ];
};

export default includeTransitLanguages;

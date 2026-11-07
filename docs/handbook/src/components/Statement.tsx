import type { ReactElement } from "react";
import CodeBlock from "@theme/CodeBlock";
import type { Statement as StatementExample } from "../stories";

export default function Statement({
  example,
  caption,
}: {
  example: StatementExample;
  caption: string;
}): ReactElement {
  return (
    <figure className="transit-statement">
      <div className="transit-statement-label">
        {example.intent === "target"
          ? "TARGET SQL"
          : example.language === "sql"
            ? "SQL"
            : "TERMINAL"}
        <span>{example.intent === "target" ? "deliveries / proposed" : "tasks / walkthrough"}</span>
      </div>
      <CodeBlock language={example.language}>{example.code}</CodeBlock>
      <figcaption>
        <span aria-hidden="true">↳ </span>
        {caption}
      </figcaption>
    </figure>
  );
}

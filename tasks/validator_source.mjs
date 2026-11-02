import { parse } from "acorn";

/**
 * These generated interfaces expose booleans, with diagnostics owned by the
 * typed caller. Omit AJV's unused error descriptions while retaining every
 * validation branch, error count and error-array entry used by combinators.
 * Parse generated code so schema constants, quoted property names and strings
 * cannot be mistaken for generated error objects. Public schemas stay intact.
 */
export function booleanValidatorSource(source) {
  const ast = parse(source, { ecmaVersion: "latest", sourceType: "module" });
  const replacements = [];
  function visit(node) {
    if (!node || typeof node !== "object") return;
    if (node.type === "ObjectExpression") {
      const names = node.properties.map((property) =>
        property.type === "Property" &&
        !property.computed &&
        !property.method &&
        property.key.type === "Identifier" &&
        (!property.shorthand || property.key.name === "instancePath")
          ? property.key.name
          : null,
      );
      // messages and verbose are disabled by the owning generators. A new
      // generator shape remains untouched until explicitly qualified here.
      if (
        names.length === 4 &&
        ["instancePath", "schemaPath", "keyword", "params"].every((name) => names.includes(name))
      ) {
        replacements.push([node.start, node.end]);
        return;
      }
    }
    for (const child of Object.values(node)) {
      if (Array.isArray(child)) child.forEach(visit);
      else if (child && typeof child === "object") visit(child);
    }
  }
  visit(ast);
  let offset = 0;
  const parts = [];
  for (const [start, end] of replacements.sort((a, b) => a[0] - b[0])) {
    parts.push(source.slice(offset, start), "{}");
    offset = end;
  }
  parts.push(source.slice(offset));
  return parts.join("");
}

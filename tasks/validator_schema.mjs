// Build-time sharing for reflected schemas that repeat complete nested types.
// Public schemas stay unchanged; only AJV's compilation input uses these refs.
export function shareValidatorSchemas(ajv, schemas) {
  const counts = new Map();
  const references = new Map();
  const definitions = new Map();
  let nestedPointer = false;
  const maps = new Set(["properties", "$defs", "patternProperties"]);
  const lists = new Set(["anyOf", "oneOf", "allOf", "prefixItems"]);
  const singles = new Set([
    "items",
    "additionalProperties",
    "contains",
    "not",
    "if",
    "then",
    "else",
  ]);

  function children(schema, visit) {
    return Object.fromEntries(
      Object.entries(schema).map(([key, value]) => {
        if (maps.has(key))
          return [
            key,
            Object.fromEntries(Object.entries(value).map(([name, child]) => [name, visit(child)])),
          ];
        if (lists.has(key)) return [key, value.map(visit)];
        if (singles.has(key)) return [key, visit(value)];
        return [key, value];
      }),
    );
  }

  function keyOf(schema) {
    const key = JSON.stringify(schema);
    // Moving a schema with references, identifiers or anchors can change its
    // resolution scope. Keep those scopes in place; only closed children may be shared.
    return key.length >= 40 &&
      !/"\$(?:schema|ref|id|anchor|dynamicRef|dynamicAnchor|recursiveRef|recursiveAnchor)"\s*:/.test(
        key,
      )
      ? key
      : null;
  }

  function count(schema) {
    if (typeof schema !== "object" || schema === null) return schema;
    if (typeof schema.$ref === "string") {
      const fragment = schema.$ref.split("#")[1];
      if (fragment?.startsWith("/") && !/^\/\$defs\/[^/]+$/.test(fragment)) nestedPointer = true;
    }
    const key = keyOf(schema);
    if (key) counts.set(key, (counts.get(key) ?? 0) + 1);
    children(schema, count);
    return schema;
  }
  function rewrite(schema) {
    if (typeof schema !== "object" || schema === null) return schema;
    const key = keyOf(schema);
    const shared = key && counts.get(key) > 1;
    if (shared && references.has(key)) return { $ref: references.get(key) };
    const rewritten = children(schema, rewrite);
    if (!shared) return rewritten;
    const id = `https://transit.invalid/generated-validator/${references.size}`;
    references.set(key, id);
    definitions.set(id, rewritten);
    return { $ref: id };
  }
  for (const schema of Object.values(schemas)) count(schema);
  // A pointer into a type's interior relies on its original tree shape. Our
  // reflected contracts reference named roots; leave other schemas untouched.
  if (nestedPointer) return schemas;
  const rewritten = Object.fromEntries(
    Object.entries(schemas).map(([name, schema]) => [
      name,
      typeof schema === "boolean" ? schema : children(schema, rewrite),
    ]),
  );
  for (const [id, schema] of definitions) ajv.addSchema(schema, id);
  return rewritten;
}

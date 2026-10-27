using System.Reflection;
using System.Runtime.ExceptionServices;
using System.Text.Json.Nodes;
using Transit.Client;

internal static class SchemaValues
{
    private static readonly MethodInfo Validator = typeof(Client).Assembly.GetType("Transit.Client.Internal.Schema")!.GetMethods(BindingFlags.NonPublic | BindingFlags.Static).Single(method => method.Name == "Valid" && method.GetParameters().Length == 2);
    private static bool Valid(JsonObject schema, JsonNode? value)
    {
        try { return (bool)Validator.Invoke(null, [schema, value])!; }
        catch (TargetInvocationException error) { ExceptionDispatchInfo.Capture(error.InnerException!).Throw(); throw; }
    }
    private static void Check(bool value) { if (!value) throw new InvalidOperationException("Recursive schema assertion"); }
    internal static void Run()
    {
        JsonObject root = JsonNode.Parse("""
            {"$ref":"#/$defs/Cell","$defs":{"Cell":{"oneOf":[
              {"type":"null"},{"type":"integer","minimum":-128,"maximum":127},
              {"type":"array","items":{"$ref":"#/$defs/Cell"},"maxItems":4}
            ]}}}
            """)!.AsObject();
        Check(Valid(root, JsonNode.Parse("[1,[null,[-128,127]],[]]")));
        foreach (string value in new[] { "128", "-129", "\"1\"", "[1,2,3,4,5]", "[1,[true]]" }) Check(!Valid(root, JsonNode.Parse(value)));
        JsonObject other = JsonNode.Parse("""
            {"$ref":"#/$defs/Cell","$defs":{"Cell":{"type":"object","properties":{},"additionalProperties":false}}}
            """)!.AsObject();
        Check(Valid(other, new JsonObject()) && !Valid(other, JsonValue.Create(1)) && !Valid(root, new JsonObject()));
        foreach (string invalid in new[] {
            """{"$ref":"https://example.invalid/schema"}""",
            """{"$ref":"#/$defs/Missing","$defs":{}}""",
            """{"$ref":"#/$defs/Cell","$defs":{"Cell":{}},"type":"object"}""",
            """{"$ref":"#/$defs/Cell","$defs":{"Cell":{"$ref":"#/$defs/Cell"}}}""",
            """{"$ref":"#/$defs/A","$defs":{"A":{"$ref":"#/$defs/B"},"B":{"$ref":"#/$defs/A"}}}""",
            """{"invented":true}""", """{"oneOf":[]}""", """{"anyOf":[]}""",
            """{"$defs":{},"anyOf":[{"$defs":{},"type":"object"}]}"""
        }) Check(!Valid(JsonNode.Parse(invalid)!.AsObject(), null));
        JsonNode deep = JsonValue.Create(1)!;
        for (int i = 0; i < 129; i++) deep = new JsonArray(deep);
        Check(!Valid(root, deep));
        JsonObject definitions = new();
        for (int i = 0; i < 200; i++) definitions.Add($"N{i}", new JsonObject { ["$ref"] = $"#/$defs/N{i + 1}" });
        definitions.Add("N200", new JsonObject { ["type"] = "null" });
        Check(!Valid(new JsonObject { ["$ref"] = "#/$defs/N0", ["$defs"] = definitions }, null));
    }
}

using System.Globalization;
using System.Text;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace Transit.Client.Internal;

/// <summary>The validation keywords emitted by Zig; unknown keywords fail closed.</summary>
internal static class Schema
{
    private static readonly HashSet<string> Keywords = new(StringComparer.Ordinal) {
        "type", "properties", "additionalProperties", "required", "maxProperties", "anyOf", "oneOf", "enum",
        "minimum", "maximum", "maxLength", "pattern", "items", "minItems", "maxItems"
    };
    internal static void Require(JsonObject schema, JsonNode? value)
    {
        if (!Valid(schema, value)) throw Value.Incompatible("native-schema");
    }
    internal static bool Valid(JsonObject schema, JsonNode? value)
    {
        // x-transit fields describe signing/layout metadata, not validation rules.
        if (schema.Any(item => !Keywords.Contains(item.Key) && !item.Key.StartsWith("x-transit-", StringComparison.Ordinal))) return false;
        foreach (string union in new[] { "anyOf", "oneOf" }) {
            if (schema[union] is not JsonArray branches) continue;
            int matches = branches.Count(branch => Valid(Value.Object(branch), value));
            if (matches == 0 || (union == "oneOf" && matches != 1)) return false;
        }
        if (schema["enum"] is JsonArray choices && !choices.Any(choice => JsonNode.DeepEquals(choice, value))) return false;
        if (schema["type"] is null) return true;
        return Value.String(schema["type"]) switch {
            "null" => value is null,
            "boolean" => value is JsonValue boolean && boolean.TryGetValue<bool>(out _),
            "integer" or "number" => Number(schema, value),
            "string" => String(schema, value),
            "array" => Array(schema, value),
            "object" => Object(schema, value),
            _ => false
        };
    }
    private static bool Number(JsonObject schema, JsonNode? value)
    {
        if (value is not JsonValue) return false;
        string text = value.ToJsonString();
        // The ABI emits integral JSON numbers canonically. Do not round tiny
        // fractions, long mantissas or exponents into an apparently valid integer.
        if (text.Length > 21 || !Regex.IsMatch(text, "\\A-?(?:0|[1-9][0-9]*)\\z", RegexOptions.NonBacktracking) ||
            !decimal.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var number)) return false;
        return (schema["minimum"] is null || number >= decimal.Parse(schema["minimum"]!.ToJsonString(), CultureInfo.InvariantCulture)) &&
            (schema["maximum"] is null || number <= decimal.Parse(schema["maximum"]!.ToJsonString(), CultureInfo.InvariantCulture));
    }
    private static bool String(JsonObject schema, JsonNode? value)
    {
        if (value is not JsonValue item || !item.TryGetValue<string>(out var text)) return false;
        if (schema["maxLength"] is not null && text.EnumerateRunes().Count() > (int)Value.Number(schema["maxLength"])) return false;
        return schema["pattern"] is null || Regex.IsMatch(text, "\\A(?:" + Value.String(schema["pattern"]) + ")\\z", RegexOptions.CultureInvariant | RegexOptions.NonBacktracking, TimeSpan.FromSeconds(1));
    }
    private static bool Array(JsonObject schema, JsonNode? value)
    {
        if (value is not JsonArray array) return false;
        if (schema["minItems"] is not null && array.Count < (int)Value.Number(schema["minItems"])) return false;
        if (schema["maxItems"] is not null && array.Count > (int)Value.Number(schema["maxItems"])) return false;
        return array.All(item => Valid(Value.Object(schema["items"]), item));
    }
    private static bool Object(JsonObject schema, JsonNode? value)
    {
        if (value is not JsonObject item) return false;
        if (schema["maxProperties"] is not null && item.Count > (int)Value.Number(schema["maxProperties"])) return false;
        JsonObject properties = schema["properties"] as JsonObject ?? new();
        if (schema["additionalProperties"] is not null && !Value.Boolean(schema["additionalProperties"]) && item.Any(field => !properties.ContainsKey(field.Key))) return false;
        if (schema["required"] is JsonArray required && required.Any(name => !item.ContainsKey(Value.String(name)))) return false;
        return properties.All(field => !item.TryGetPropertyValue(field.Key, out var child) || Valid(Value.Object(field.Value), child));
    }
}

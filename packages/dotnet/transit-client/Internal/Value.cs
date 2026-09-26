using System.Reflection;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace Transit.Client.Internal;

internal static class Value
{
    internal static readonly UTF8Encoding Utf8 = new(false, true);
    internal static readonly JsonObject Contract = ReadContract(typeof(Value).Assembly, "transit.client.contract.json");
    internal static readonly int MaxBody = checked((int)Number(Object(Contract["limits"])["max_body"], 1, ulong.MaxValue));
    internal static readonly ulong MaxCounter = Number(Object(Contract["limits"])["max_counter"], 1, ulong.MaxValue);
    internal static readonly int MaxLine = checked((int)Number(Object(Contract["limits"])["host_line_bytes"], 1, ulong.MaxValue));
    internal static TransitException Incompatible(string phase) => new(ErrorKind.IncompatibleNative, phase);
    internal static JsonObject ReadContract(Assembly assembly, string name)
    {
        using Stream input = assembly.GetManifestResourceStream(name) ?? throw Incompatible("contract-resource");
        using MemoryStream bytes = new(); input.CopyTo(bytes);
        return Object(Parse(bytes.ToArray()));
    }
    internal static ulong Counter(ulong value, ulong minimum = 1)
    {
        if (value < minimum || value > MaxCounter) throw new ArgumentOutOfRangeException(nameof(value), "Counter exceeds its bound");
        return value;
    }
    internal static string Text(string value, int bound)
    {
        ArgumentNullException.ThrowIfNull(value);
        if (Utf8.GetByteCount(value) > bound) throw new ArgumentException("Text exceeds its bound");
        return value;
    }
    internal static byte[] Bytes(byte[] value, int bound)
    {
        ArgumentNullException.ThrowIfNull(value);
        if (value.Length > bound) throw new ArgumentException("Bytes exceed their bound");
        return (byte[])value.Clone();
    }
    internal static JsonObject Object(JsonNode? value) => value as JsonObject ?? throw Incompatible("native-object");
    internal static string String(JsonNode? value) => value is JsonValue item && item.TryGetValue<string>(out var text) ? text : throw Incompatible("native-string");
    internal static bool Boolean(JsonNode? value) => value is JsonValue item && item.TryGetValue<bool>(out var flag) ? flag : throw Incompatible("native-boolean");
    internal static ulong Number(JsonNode? value, ulong minimum = 0, ulong? maximum = null)
    {
        if (value is not JsonValue item || !item.TryGetValue<ulong>(out var number) || number < minimum || number > (maximum ?? MaxCounter)) throw Incompatible("native-number");
        return number;
    }
    internal static string Hex(byte[] bytes) => Convert.ToHexString(bytes).ToLowerInvariant();
    internal static byte[] Unhex(JsonNode? value, int bound)
    {
        string text = String(value);
        if (text.Length > bound * 2 || text.Length % 2 != 0 || text.Any(c => c is not (>= '0' and <= '9') and not (>= 'a' and <= 'f'))) throw Incompatible("native-bytes");
        return Convert.FromHexString(text);
    }
    internal static JsonNode? Parse(byte[] bytes)
    {
        try {
            // Reject duplicate members before constructing the ordinary owned tree.
            Utf8JsonReader reader = new(bytes, new JsonReaderOptions { MaxDepth = 64 });
            Stack<HashSet<string>?> scopes = new();
            while (reader.Read()) {
                switch (reader.TokenType) {
                    case JsonTokenType.StartObject: scopes.Push(new(StringComparer.Ordinal)); break;
                    case JsonTokenType.StartArray: scopes.Push(null); break;
                    case JsonTokenType.EndObject:
                    case JsonTokenType.EndArray: scopes.Pop(); break;
                    case JsonTokenType.PropertyName:
                        if (!scopes.Peek()!.Add(reader.GetString()!)) throw Incompatible("duplicate-json-member");
                        break;
                }
            }
            // Strict decoder rejects invalid UTF-8; JsonDocument otherwise replaces it.
            string text = Utf8.GetString(bytes);
            return JsonNode.Parse(text, documentOptions: new JsonDocumentOptions { MaxDepth = 64 });
        } catch (JsonException) { throw Incompatible("native-json"); }
        catch (DecoderFallbackException) { throw Incompatible("native-utf8"); }
    }
    internal static byte[] Json(JsonNode value) => Utf8.GetBytes(value.ToJsonString());
    internal static JsonObject Obj(params (string Key, object? Value)[] fields)
    {
        JsonObject value = new();
        foreach (var field in fields) value.Add(field.Key, field.Value switch {
            null => null, JsonNode node => node, string text => JsonValue.Create(text),
            bool flag => JsonValue.Create(flag), ulong number => JsonValue.Create(number), long number => JsonValue.Create(number),
            uint number => JsonValue.Create(number), int number => JsonValue.Create(number),
            _ => throw new ArgumentException("Unsupported internal JSON value")
        });
        return value;
    }
    internal static TransitException NativeError(uint status, JsonNode? value, string phase)
    {
        string? code = null;
        if (value is JsonObject detail && (detail["protocol_error"] ?? detail["err"]) is JsonValue field && field.TryGetValue<string>(out var name) && name.Length <= 256) code = name;
        ErrorKind kind = status switch {
            3 or 5 => ErrorKind.AuthorityRejected, 4 => ErrorKind.AccessDenied, 6 => ErrorKind.UnknownOutcome,
            7 or 8 => ErrorKind.ReadFailed, 9 => ErrorKind.Busy, 10 => ErrorKind.IncompatibleNative,
            11 => ErrorKind.StaleOwnership, 12 => ErrorKind.Blocked, 13 => ErrorKind.TurnExpired,
            14 => ErrorKind.BudgetExceeded, _ => ErrorKind.Handler
        };
        kind = code switch {
            "StaleActivation" => ErrorKind.StaleOwnership, "ProcessExpired" or "ProcessTerminated" => ErrorKind.ProcessRetired,
            "HistoryReclaimed" or "QueryExpired" => ErrorKind.HistoryUnavailable, _ => kind
        };
        return new TransitException(kind, phase, status, code);
    }
}

using System.Globalization;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;

namespace Transit.Station.Sdk.Internal;

internal static class NativeValues
{
    internal static TransitException Normalize(Exception error, string phase) => error as TransitException ?? new TransitException(ErrorKind.Handler, phase);
    internal static void SynchronousCallbacks(object implementation, Type contract)
    {
        foreach (MethodInfo method in implementation.GetType().GetInterfaceMap(contract).TargetMethods) {
            if (method.GetCustomAttribute<AsyncStateMachineAttribute>() is not null) throw new TransitException(ErrorKind.Handler, "async-void-callback");
        }
    }
    internal static int Bound<T>(ICodec<T> codec, int bound) where T : notnull
    {
        try {
            if (Value.Text(codec.TypeId, 256).Length == 0 || codec.Version == 0 || codec.MaxEncodedBytes < 1 || codec.MaxEncodedBytes > bound) throw new ArgumentException("Invalid codec contract");
            return codec.MaxEncodedBytes;
        } catch (Exception) { throw new TransitException(ErrorKind.Codec, "application-codec"); }
    }
    internal static byte[] Encode<T>(ICodec<T> codec, T value, int bound) where T : notnull
    {
        try { int maximum = Bound(codec, bound); return Value.Bytes(codec.Encode(value), maximum); }
        catch (Exception) { throw new TransitException(ErrorKind.Codec, "application-codec"); }
    }
    internal static T Decode<T>(ICodec<T> codec, byte[] bytes, int bound) where T : notnull
    {
        try { T value = codec.Decode(Value.Bytes(bytes, Bound(codec, bound))); ArgumentNullException.ThrowIfNull(value); return value; }
        catch (Exception) { throw new TransitException(ErrorKind.Codec, "application-codec"); }
    }
    internal static ulong Wide(JsonNode? value, bool nonzero = false)
    {
        string text = Value.String(value);
        if (!ulong.TryParse(text, NumberStyles.None, CultureInfo.InvariantCulture, out var parsed) || text != parsed.ToString(CultureInfo.InvariantCulture) || (nonzero && parsed == 0)) throw Value.Incompatible("native-u64");
        return parsed;
    }
    internal static long Signed(JsonNode? value)
    {
        string text = Value.String(value);
        if (!long.TryParse(text, NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture, out var parsed) || text != parsed.ToString(CultureInfo.InvariantCulture)) throw Value.Incompatible("native-i64");
        return parsed;
    }
    internal static Bytes Digest(JsonNode? value)
    {
        if (value is not JsonArray array || array.Count != 32) throw Value.Incompatible("native-digest");
        return new Bytes(array.Select(item => checked((byte)Value.Number(item))).ToArray());
    }
    internal static Basis Basis(JsonNode? value, ulong realm)
    {
        JsonObject item = Value.Object(value);
        return new(new ResourceRef(realm, Value.Number(item["resource"], 1)), Value.Number(item["revision"]), Digest(item["schema"]));
    }
    internal static ReadVersion ReadVersion(JsonNode? value)
    {
        JsonObject item = Value.Object(value);
        return new(Value.Number(item["pid"], 1), Value.Number(item["input"], 1), checked((byte)Value.Number(item["index"])));
    }
    internal static JsonObject Wire(ReadVersion version) => Value.Obj(("pid", version.Pid), ("input", version.Input), ("index", (uint)version.Index));
    internal static Cursor? Cursor(JsonNode? value) => value is null ? null : new(Value.String(value));
    internal static Origin Origin(JsonNode? value, ulong realm)
    {
        JsonObject origin = Value.Object(value);
        if (origin["external"] is JsonObject external) return new ExternalOrigin(Value.Number(external["principal"]), Value.Number(external["policy_revision"]));
        if (origin["process"] is JsonObject process) return new ProcessOrigin(new ProcessRef(realm, Value.Number(process["pid"], 1)), Value.Number(process["turn"], 1), Value.Number(process["output"]));
        if (origin["effect"] is JsonObject effect) return new EffectOrigin(Value.Number(effect["id"], 1), Value.Number(effect["attempt"], 1), Value.Number(effect["executor"]));
        throw Value.Incompatible("native-origin");
    }
}

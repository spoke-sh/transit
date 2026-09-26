using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;

namespace Transit.Station.Sdk;

public sealed class State
{
    private readonly Turn turn;
    private readonly ReadVersion? version;
    internal State(Turn turn, ReadVersion? version) { this.turn = turn; this.version = version; }
    private string Name<T>(Key<T> key) where T : notnull => Value.Hex(Value.Bytes(key.Name.Copy(), turn.Limit("key_bytes")));
    public Found<T>? Find<T>(Key<T> key) where T : notnull => turn.Access(true, () => {
        string name = Name(key);
        JsonObject request = version is null ? Value.Obj(("get", name)) : Value.Obj(("version_get", Value.Obj(("id", NativeValues.Wire(version)), ("key", name))));
        JsonNode? value = turn.Raw(request)["value"];
        return value is null ? null : new Found<T>(NativeValues.Decode(key.Codec, Value.Unhex(value, turn.Limit("value_bytes")), turn.Limit("value_bytes")));
    });
    public T Require<T>(Key<T> key) where T : notnull => Find(key) is { } found ? found.Value : throw new TransitException(ErrorKind.MissingValue, "state-require");
    private void Writable() { if (version is not null) throw new TransitException(ErrorKind.Handler, "retained-source-read-only"); }
    public void Put<T>(Key<T> key, T value) where T : notnull => turn.Access(false, () => {
        Writable(); string name = Name(key); byte[] bytes = NativeValues.Encode(key.Codec, value, turn.Limit("value_bytes"));
        turn.Raw(Value.Obj(("put", Value.Obj(("key", name), ("value", Value.Hex(bytes)))))); return true;
    });
    public void Delete<T>(Key<T> key) where T : notnull => turn.Access(false, () => { Writable(); turn.Raw(Value.Obj(("delete", Name(key)))); return true; });
    public Page<KVEntry> Page(Cursor? cursor = null) => turn.Access(true, () => {
        JsonObject request = version is null ? Value.Obj(("page", cursor?.Opaque)) : Value.Obj(("version_page", Value.Obj(("id", NativeValues.Wire(version)), ("cursor", cursor?.Opaque))));
        JsonObject value = Value.Object(turn.Raw(request)["page"]);
        if (value["entries"] is not JsonArray entries || entries.Count > turn.Limit("page_entries")) throw Value.Incompatible("native-page");
        List<KVEntry> result = [];
        foreach (JsonNode? entry in entries) {
            if (entry is null) continue;
            JsonObject item = Value.Object(entry);
            result.Add(new KVEntry(new Bytes(Value.Unhex(item["key"], turn.Limit("key_bytes"))), new Bytes(Value.Unhex(item["value"], turn.Limit("value_bytes"))), Value.Number(item["revision"])));
        }
        return new Page<KVEntry>(result, NativeValues.Cursor(value["next"]), null);
    });
}

public sealed class Source
{
    private readonly Turn turn;
    public ReadVersion Identity { get; }
    internal Source(Turn turn, ReadVersion identity) { this.turn = turn; Identity = identity; }
    public State State { get { turn.Check(); return new State(turn, Identity); } }
    public Table<T> Table<T>(TableSchema<T> schema) => turn.Access(true, () => Sdk.Table<T>.Open(turn, schema, Identity));
}

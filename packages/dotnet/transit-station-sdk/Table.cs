using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Client.Internal;
using Transit.Station.Sdk.Internal;

namespace Transit.Station.Sdk;

public sealed class CellType<T>
{
    internal string WireName { get; }
    internal CellType(string name) { WireName = name; }
    internal JsonObject Encode(T value, int bound)
    {
        if (value is null) return Value.Obj(("null", Value.Obj()));
        object encoded = WireName switch {
            "int64" when value is long number => Turn.Decimal(number),
            "boolean" when value is bool flag => flag,
            "utf8" when value is string text => Value.Text(text, bound),
            "binary" when value is Bytes bytes => Value.Hex(Value.Bytes(bytes.Copy(), bound)),
            _ => throw new ArgumentException("Unexpected Table cell type")
        };
        return Value.Obj((WireName, encoded));
    }
    internal T Decode(JsonNode? node, int bound)
    {
        JsonObject value = Value.Object(node);
        if (value.ContainsKey("null")) return default!;
        if (!value.ContainsKey(WireName)) throw Value.Incompatible("table-cell-type");
        object decoded = WireName switch {
            "int64" => NativeValues.Signed(value[WireName]), "boolean" => Value.Boolean(value[WireName]),
            "utf8" => Value.Text(Value.String(value[WireName]), bound), "binary" => new Bytes(Value.Unhex(value[WireName], bound)),
            _ => throw Value.Incompatible("table-cell-type")
        };
        return (T)decoded;
    }
}
public static class Cells
{
    public static CellType<long?> Int64 { get; } = new("int64");
    public static CellType<bool?> Boolean { get; } = new("boolean");
    public static CellType<string?> Utf8 { get; } = new("utf8");
    public static CellType<Bytes?> Binary { get; } = new("binary");
}
public sealed record TableSchema<T>
{
    public uint Id { get; }
    public CellType<T> Cell { get; }
    public string KeyName { get; }
    public string ValueName { get; }
    public TableSchema(uint id, CellType<T> cell, string keyName = "id", string valueName = "value")
    {
        ArgumentNullException.ThrowIfNull(cell);
        if (id == 0) throw new ArgumentOutOfRangeException(nameof(id));
        Id = id; Cell = cell; KeyName = Value.Text(keyName, 256); ValueName = Value.Text(valueName, 256);
    }
}
public sealed record TableRow<T>(long Key, T Value);
public sealed class Table<T>
{
    private readonly Turn turn;
    private readonly ReadVersion? version;
    public TableSchema<T> Schema { get; }
    public Basis Basis { get; }
    private Table(Turn turn, TableSchema<T> schema, ReadVersion? version, Basis basis) { this.turn = turn; Schema = schema; this.version = version; Basis = basis; }
    internal static Table<T> Open(Turn turn, TableSchema<T> schema, ReadVersion? version)
    {
        ArgumentNullException.ThrowIfNull(schema);
        JsonObject request = Value.Obj(("id", schema.Id));
        if (version is not null) request.Add("version", NativeValues.Wire(version));
        JsonObject value = Value.Object(turn.Raw(Value.Obj(("table_schema", request)))["schema"]);
        if (Value.String(value["key_name"]) != schema.KeyName || Value.String(value["value_name"]) != schema.ValueName || Value.String(value["value_type"]) != schema.Cell.WireName)
            throw new TransitException(ErrorKind.Handler, "table-schema", code: "TableSchemaChanged");
        return new(turn, schema, version, NativeValues.Basis(value["basis"], turn.ProcessRef.Realm));
    }
    private JsonObject Request()
    {
        JsonObject value = Value.Obj(("id", Schema.Id));
        if (version is not null) value.Add("version", NativeValues.Wire(version));
        return value;
    }
    private TableRow<T> Row(JsonNode? value)
    {
        JsonObject row = Value.Object(value);
        return new(NativeValues.Signed(row["key"]), Schema.Cell.Decode(row["value"], turn.Limit("table_cell_bytes")));
    }
    public TableRow<T>? Get(long key) => turn.Access(true, () => {
        JsonObject request = Request(); request.Add("key", Turn.Decimal(key));
        JsonNode? value = turn.Raw(Value.Obj((version is null ? "table_get" : "version_table_get", request)))["row"];
        return value is null ? null : Row(value);
    });
    private void Writable() { if (version is not null) throw new TransitException(ErrorKind.Handler, "retained-table-read-only"); }
    private void Write(string mode, TableRow<T> row) => turn.Access(false, () => {
        Writable(); ArgumentNullException.ThrowIfNull(row);
        turn.Raw(Value.Obj(("table_write", Value.Obj(("id", Schema.Id), ("mode", mode),
            ("row", Value.Obj(("key", Turn.Decimal(row.Key)), ("value", Schema.Cell.Encode(row.Value, turn.Limit("table_cell_bytes"))))))))); return true;
    });
    public void Insert(TableRow<T> row) => Write("insert", row);
    public void Update(TableRow<T> row) => Write("update", row);
    public void Upsert(TableRow<T> row) => Write("upsert", row);
    public void Delete(long key) => turn.Access(false, () => { Writable(); turn.Raw(Value.Obj(("table_delete", Value.Obj(("id", Schema.Id), ("key", Turn.Decimal(key)))))); return true; });
    public Page<TableRow<T>> Page(Cursor? cursor = null) => turn.Access(true, () => {
        JsonObject request = Request(); request.Add("cursor", cursor?.Opaque);
        JsonObject value = Value.Object(turn.Raw(Value.Obj(("table_page", request)))["rows"]);
        if (value["rows"] is not JsonArray rows || rows.Count > turn.Limit("page_entries")) throw Value.Incompatible("native-page");
        return new Page<TableRow<T>>(rows.Where(row => row is not null).Select(Row), NativeValues.Cursor(value["next"]), NativeValues.Basis(value["basis"], turn.ProcessRef.Realm));
    });
}

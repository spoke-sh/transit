using System.Buffers.Binary;
using System.Collections;
using System.Globalization;
using System.Text.Json.Nodes;
using V = Transit.Client.Internal.Value;

namespace Transit.Station.Sdk;

/// <summary>Owned logical values; shared Zig owns domain semantics and storage.</summary>
public static class Logical
{
    internal const int DataBytes = 1024 * 1024;
    public enum ScalarKind { Int8, Int16, Int32, Int64, Int128, Uint8, Uint16, Uint32, Uint64, Uint128, Float32, Float64, Boolean, Utf8, Binary, Date, Time, Interval, Uuid, Json }
    public enum Kind { Int8, Int16, Int32, Int64, Int128, Uint8, Uint16, Uint32, Uint64, Uint128, Float32, Float64, Decimal, Boolean, Utf8, Binary, Date, Time, Timestamp, Interval, Uuid, Structure, TaggedUnion, List, Array, Map, Json }
    public enum Zone { Civil, Utc }
    public abstract record Descriptor;
    public sealed record Scalar : Descriptor {
        public ScalarKind Kind { get; }
        public Scalar(ScalarKind kind) { EnumName(kind); Kind = kind; }
    }
    public sealed record Decimal : Descriptor {
        public byte Precision { get; }
        public byte Scale { get; }
        public Decimal(byte precision, byte scale) { if (precision is < 1 or > 38 || scale > precision) throw Invalid("decimal descriptor"); Precision = precision; Scale = scale; }
    }
    public sealed record Timestamp : Descriptor {
        public Zone Zone { get; }
        public Timestamp(Zone zone) { EnumName(zone); Zone = zone; }
    }
    public sealed record Field {
        public string Name { get; }
        public Descriptor Type { get; }
        public bool Nullable { get; }
        public bool Optional { get; }
        public Field(string name, Descriptor type, bool nullable = false, bool optional = false) { Name = V.Text(name, 4096); ArgumentNullException.ThrowIfNull(type); Type = type; Nullable = nullable; Optional = optional; }
    }
    public sealed record Element {
        public Descriptor Type { get; }
        public bool Nullable { get; }
        public Element(Descriptor type, bool nullable = false) { ArgumentNullException.ThrowIfNull(type); Type = type; Nullable = nullable; }
    }
    public sealed record Structure : Descriptor {
        public IReadOnlyList<Field> Fields { get; }
        public Structure(IReadOnlyList<Field> fields) { Fields = Own(fields, 256); }
    }
    public sealed record Union : Descriptor {
        public IReadOnlyList<Field> Fields { get; }
        public Union(IReadOnlyList<Field> fields) { Fields = Own(fields, 256); }
    }
    public sealed record ListType : Descriptor {
        public Element Element { get; }
        public ListType(Element element) { ArgumentNullException.ThrowIfNull(element); Element = element; }
    }
    public sealed record ArrayType : Descriptor {
        public Element Element { get; }
        public uint Length { get; }
        public ArrayType(Element element, uint length) { ArgumentNullException.ThrowIfNull(element); if (length == 0) throw Invalid("array length"); Element = element; Length = length; }
    }
    public sealed record MapType : Descriptor {
        public Descriptor Key { get; }
        public Element Value { get; }
        public MapType(Descriptor key, Element value) { ArgumentNullException.ThrowIfNull(key); ArgumentNullException.ThrowIfNull(value); Key = key; Value = value; }
    }
    public sealed class BinaryData : IEquatable<BinaryData> {
        private readonly byte[] bytes;
        public BinaryData(byte[] bytes) { this.bytes = V.Bytes(bytes, DataBytes); }
        public int Length => bytes.Length;
        public byte[] Copy() => (byte[])bytes.Clone();
        public bool Equals(BinaryData? other) => other is not null && bytes.AsSpan().SequenceEqual(other.bytes);
        public override bool Equals(object? other) => other is BinaryData value && Equals(value);
        public override int GetHashCode() { HashCode hash = new(); hash.AddBytes(bytes); return hash.ToHashCode(); }
        public override string ToString() => $"BinaryData[Length={bytes.Length}]";
    }
    public abstract record Value;
    public abstract record Atom : Value;
    public sealed record Signed(Int128 Number) : Atom;
    public sealed record Unsigned(UInt128 Number) : Atom;
    public sealed record DecimalValue(Int128 Coefficient) : Atom;
    public sealed record Float32 : Atom {
        public float Number { get; }
        public Float32(float number) { if (!float.IsFinite(number)) throw Invalid("nonfinite float32"); Number = number; }
        public bool Equals(Float32? other) => other is not null && BitConverter.SingleToInt32Bits(Number) == BitConverter.SingleToInt32Bits(other.Number);
        public override int GetHashCode() => BitConverter.SingleToInt32Bits(Number);
    }
    public sealed record Float64 : Atom {
        public double Number { get; }
        public Float64(double number) { if (!double.IsFinite(number)) throw Invalid("nonfinite float64"); Number = number; }
        public bool Equals(Float64? other) => other is not null && BitConverter.DoubleToInt64Bits(Number) == BitConverter.DoubleToInt64Bits(other.Number);
        public override int GetHashCode() => BitConverter.DoubleToInt64Bits(Number).GetHashCode();
    }
    public sealed record BooleanValue(bool Boolean) : Atom;
    public sealed record Utf8 : Atom { public string Text { get; } public Utf8(string text) { Text = V.Text(text, DataBytes); } }
    public sealed record Binary : Atom { public BinaryData Bytes { get; } public Binary(BinaryData bytes) { ArgumentNullException.ThrowIfNull(bytes); Bytes = bytes; } }
    public sealed record Uuid : Atom { public BinaryData Bytes { get; } public Uuid(BinaryData bytes) { ArgumentNullException.ThrowIfNull(bytes); if (bytes.Length != 16) throw Invalid("UUID width"); Bytes = bytes; } }
    public sealed record DateDays(int Days) : Atom;
    public sealed record TimeNanos(ulong Nanos) : Atom;
    public sealed record TimestampMicros(long Micros) : Atom;
    public sealed record Interval(int Months, int Days, long Nanos) : Atom;
    public enum SequenceKind { Structure, List, Array }
    public sealed record Sequence : Value {
        public SequenceKind Kind { get; }
        public IReadOnlyList<Cell> Cells { get; }
        public Sequence(SequenceKind kind, IReadOnlyList<Cell> cells) { EnumName(kind); Kind = kind; Cells = Own(cells, 65536); }
    }
    public sealed record MapEntry {
        public Atom Key { get; }
        public Cell Value { get; }
        public MapEntry(Atom key, Cell value) { ArgumentNullException.ThrowIfNull(key); ArgumentNullException.ThrowIfNull(value); Key = key; Value = value; }
    }
    public sealed record MapValue : Value {
        public IReadOnlyList<MapEntry> Entries { get; }
        public MapValue(IReadOnlyList<MapEntry> entries) { Entries = Own(entries, 32767); }
    }
    public sealed record Tagged : Value {
        public byte Index { get; }
        public Cell Value { get; }
        public Tagged(byte index, Cell value) { ArgumentNullException.ThrowIfNull(value); Index = index; Value = value; }
    }
    public sealed record Json : Value { public string Text { get; } public Json(string text) { Text = V.Text(text, DataBytes); } }
    public abstract record Cell;
    public sealed record Missing : Cell;
    public sealed record Null : Cell;
    public sealed record SourceTypeError : Cell { public Kind Actual { get; } public SourceTypeError(Kind actual) { EnumName(actual); Actual = actual; } }
    public sealed record Present : Cell { public Value Value { get; } public Present(Value value) { ArgumentNullException.ThrowIfNull(value); Value = value; } }
    public sealed record Alternative {
        public ulong Counter { get; }
        public ulong Replica { get; }
        public Cell Value { get; }
        public Alternative(ulong counter, ulong replica, Cell value) {
            if (counter == 0 || replica == 0 || value is not (Null or SourceTypeError or Present)) throw Invalid("conflict alternative");
            Counter = counter; Replica = replica; Value = value;
        }
    }
    public sealed record Conflict : Cell {
        public IReadOnlyList<Alternative> Alternatives { get; }
        public Conflict(IReadOnlyList<Alternative> alternatives) {
            Alternatives = Own(alternatives, 8); if (Alternatives.Count < 2) throw Invalid("conflict count");
            for (int i = 1; i < Alternatives.Count; i++) {
                var a = Alternatives[i - 1]; var b = Alternatives[i];
                if (a.Counter > b.Counter || (a.Counter == b.Counter && a.Replica >= b.Replica)) throw Invalid("conflict order");
            }
        }
    }
    // Structural equality for owned sequence fields in language-native records.
    private sealed class OwnedSequence<T> : IReadOnlyList<T>, IEquatable<OwnedSequence<T>> {
        private readonly T[] values;
        internal OwnedSequence(IReadOnlyList<T> source) { values = source.ToArray(); }
        public T this[int index] => values[index];
        public int Count => values.Length;
        public IEnumerator<T> GetEnumerator() => ((IEnumerable<T>)values).GetEnumerator();
        IEnumerator IEnumerable.GetEnumerator() => GetEnumerator();
        public bool Equals(OwnedSequence<T>? other) => other is not null && values.SequenceEqual(other.values);
        public override bool Equals(object? other) => other is OwnedSequence<T> value && Equals(value);
        public override int GetHashCode() { HashCode hash = new(); foreach (var value in values) hash.Add(value); return hash.ToHashCode(); }
    }
    internal static IReadOnlyList<T> Own<T>(IReadOnlyList<T> values, int maximum) {
        ArgumentNullException.ThrowIfNull(values);
        if (values.Count > maximum || values.Any(value => value is null)) throw Invalid("collection bound"); return new OwnedSequence<T>(values);
    }
    internal static ArgumentException Invalid(string what) => new("Invalid logical " + what);
    internal static string EnumName<T>(T value) where T : struct, Enum {
        if (!Enum.IsDefined(value)) throw Invalid("variant");
        return string.Concat(value.ToString().Select((c, i) => (i > 0 && char.IsUpper(c) ? "_" : "") + char.ToLowerInvariant(c)));
    }
    internal static T EnumValue<T>(JsonNode? value) where T : struct, Enum {
        string name = V.String(value); foreach (T item in Enum.GetValues<T>()) if (EnumName(item) == name) return item; throw Invalid("variant");
    }
    internal static JsonObject Fields(JsonNode? value, params string[] names) {
        var result = V.Object(value); if (result.Count != names.Length || names.Any(name => !result.ContainsKey(name))) throw Invalid("fields"); return result;
    }
    private static KeyValuePair<string, JsonNode?> Variant(JsonNode? value) {
        var result = V.Object(value); if (result.Count != 1) throw Invalid("variant count"); return result.First();
    }
    private sealed class Budget(int maximum) {
        private int nodes, data, names;
        internal void Enter(int depth) { if (depth >= 16 || ++nodes > maximum) throw Invalid("depth/child bound"); }
        internal void Data(int length) { data = checked(data + length); if (data > DataBytes) throw Invalid("aggregate data bound"); }
        internal string Name(string value) { V.Text(value, 4096); names += V.Utf8.GetByteCount(value); if (names > 4096) throw Invalid("aggregate name bound"); return value; }
    }
    public static JsonObject TypeWire(Descriptor value) => TypeWire(value, new(256), 0);
    private static JsonObject ElementWire(Element value, Budget budget, int depth) => V.Obj(("type", TypeWire(value.Type, budget, depth + 1)), ("nullable", value.Nullable));
    private static JsonArray FieldsWire(IReadOnlyList<Field> fields, Budget budget, int depth) => new(fields.Select(f => (JsonNode?)V.Obj(("name", budget.Name(f.Name)), ("type", TypeWire(f.Type, budget, depth + 1)), ("nullable", f.Nullable), ("optional", f.Optional))).ToArray());
    private static JsonObject TypeWire(Descriptor value, Budget budget, int depth) {
        budget.Enter(depth);
        return value switch {
            Scalar scalar => V.Obj((EnumName(scalar.Kind), V.Obj())),
            Decimal dec => V.Obj(("decimal", V.Obj(("precision", (ulong)dec.Precision), ("scale", (ulong)dec.Scale)))),
            Timestamp timestamp => V.Obj(("timestamp", EnumName(timestamp.Zone))),
            Structure structure => V.Obj(("structure", FieldsWire(structure.Fields, budget, depth))),
            Union union => V.Obj(("tagged_union", FieldsWire(union.Fields, budget, depth))),
            ListType list => V.Obj(("list", ElementWire(list.Element, budget, depth))),
            ArrayType array => V.Obj(("array", V.Obj(("element", ElementWire(array.Element, budget, depth)), ("length", (ulong)array.Length)))),
            MapType map => V.Obj(("map", V.Obj(("key", TypeWire(map.Key, budget, depth + 1)), ("value", ElementWire(map.Value, budget, depth))))),
            _ => throw Invalid("descriptor")
        };
    }
    public static Descriptor TypeFromWire(JsonNode? value) => TypeFromWire(value, new(256), 0);
    private static Element ElementFromWire(JsonNode? value, Budget budget, int depth) { var v = Fields(value, "type", "nullable"); return new(TypeFromWire(v["type"], budget, depth + 1), V.Boolean(v["nullable"])); }
    private static Descriptor TypeFromWire(JsonNode? value, Budget budget, int depth) {
        budget.Enter(depth); var (kind, payload) = Variant(value);
        foreach (ScalarKind scalar in Enum.GetValues<ScalarKind>()) if (EnumName(scalar) == kind) { Fields(payload); return new Scalar(scalar); }
        switch (kind) {
            case "decimal": { var v = Fields(payload, "precision", "scale"); return new Decimal(checked((byte)V.Number(v["precision"], 1)), checked((byte)V.Number(v["scale"]))); }
            case "timestamp": return new Timestamp(EnumValue<Zone>(payload));
            case "structure": case "tagged_union": {
                var fields = (payload as JsonArray ?? throw Invalid("fields")).Select(item => {
                    var v = Fields(item, "name", "type", "nullable", "optional"); return new Field(budget.Name(V.String(v["name"])), TypeFromWire(v["type"], budget, depth + 1), V.Boolean(v["nullable"]), V.Boolean(v["optional"]));
                }).ToArray(); return kind == "structure" ? new Structure(fields) : new Union(fields);
            }
            case "list": return new ListType(ElementFromWire(payload, budget, depth));
            case "array": { var v = Fields(payload, "element", "length"); return new ArrayType(ElementFromWire(v["element"], budget, depth), checked((uint)V.Number(v["length"], 1))); }
            case "map": { var v = Fields(payload, "key", "value"); return new MapType(TypeFromWire(v["key"], budget, depth + 1), ElementFromWire(v["value"], budget, depth)); }
            default: throw Invalid("descriptor variant");
        }
    }
    public static JsonObject AtomWire(Atom value) => AtomWire(value, new(65536));
    private static string Exact<T>(T value) where T : IFormattable => value.ToString(null, CultureInfo.InvariantCulture);
    private static string TextData(string value, Budget budget) { budget.Data(V.Utf8.GetByteCount(value)); return value; }
    private static string BinaryWire(byte[] value, Budget budget) { budget.Data(value.Length); return V.Hex(value); }
    private static byte[] FloatBits(float value) { byte[] bytes = new byte[4]; BinaryPrimitives.WriteSingleLittleEndian(bytes, value); return bytes; }
    private static byte[] FloatBits(double value) { byte[] bytes = new byte[8]; BinaryPrimitives.WriteDoubleLittleEndian(bytes, value); return bytes; }
    private static JsonObject AtomWire(Atom value, Budget budget) => value switch {
        Signed atom => V.Obj(("signed", Exact(atom.Number))), Unsigned atom => V.Obj(("unsigned", Exact(atom.Number))), DecimalValue atom => V.Obj(("decimal", Exact(atom.Coefficient))),
        Float32 atom => V.Obj(("float_bits", BinaryWire(FloatBits(atom.Number), budget))), Float64 atom => V.Obj(("float_bits", BinaryWire(FloatBits(atom.Number), budget))),
        BooleanValue atom => V.Obj(("boolean", atom.Boolean)), Utf8 atom => V.Obj(("utf8", TextData(atom.Text, budget))),
        Binary atom => V.Obj(("binary", BinaryWire(atom.Bytes.Copy(), budget))), Uuid atom => V.Obj(("uuid", BinaryWire(atom.Bytes.Copy(), budget))),
        DateDays atom => V.Obj(("date_days", Exact(atom.Days))), TimeNanos atom => V.Obj(("time_nanos", Exact(atom.Nanos))), TimestampMicros atom => V.Obj(("timestamp_micros", Exact(atom.Micros))),
        Interval atom => V.Obj(("interval", V.Obj(("months", Exact(atom.Months)), ("days", Exact(atom.Days)), ("nanos", Exact(atom.Nanos))))),
        _ => throw Invalid("atom")
    };
    private static string IntegerText(JsonNode? value) {
        string text = V.String(value);
        if (text.Length is < 1 or > 40) throw Invalid("integer length");
        if (text == "0") return text;
        int start = text[0] == '-' ? 1 : 0;
        if (start == text.Length || text[start] is < '1' or > '9' || text[(start + 1)..].Any(c => c is < '0' or > '9')) throw Invalid("canonical integer"); return text;
    }
    private static Int128 SignedInteger(JsonNode? value) => Int128.Parse(IntegerText(value), NumberStyles.AllowLeadingSign, CultureInfo.InvariantCulture);
    private static UInt128 UnsignedInteger(JsonNode? value) => UInt128.Parse(IntegerText(value), NumberStyles.None, CultureInfo.InvariantCulture);
    public static Atom AtomFromWire(JsonNode? value) => AtomFromWire(value, new(65536));
    private static Atom AtomFromWire(JsonNode? value, Budget budget) {
        var (kind, payload) = Variant(value);
        switch (kind) {
            case "signed": return new Signed(SignedInteger(payload)); case "unsigned": return new Unsigned(UnsignedInteger(payload)); case "decimal": return new DecimalValue(SignedInteger(payload));
            case "date_days": return new DateDays(checked((int)SignedInteger(payload))); case "time_nanos": return new TimeNanos(checked((ulong)UnsignedInteger(payload))); case "timestamp_micros": return new TimestampMicros(checked((long)SignedInteger(payload)));
            case "boolean": return new BooleanValue(V.Boolean(payload)); case "utf8": return new Utf8(TextData(V.String(payload), budget));
            case "binary": case "uuid": case "float_bits": {
                byte[] bytes = V.Unhex(payload, kind == "float_bits" ? 8 : kind == "uuid" ? 16 : DataBytes); budget.Data(bytes.Length);
                if (kind == "binary") return new Binary(new BinaryData(bytes)); if (kind == "uuid") return new Uuid(new BinaryData(bytes));
                return bytes.Length switch { 4 => new Float32(BinaryPrimitives.ReadSingleLittleEndian(bytes)), 8 => new Float64(BinaryPrimitives.ReadDoubleLittleEndian(bytes)), _ => throw Invalid("float width") };
            }
            case "interval": { var v = Fields(payload, "months", "days", "nanos"); return new Interval(checked((int)SignedInteger(v["months"])), checked((int)SignedInteger(v["days"])), checked((long)SignedInteger(v["nanos"]))); }
            default: throw Invalid("atom variant");
        }
    }
    public static JsonObject CellWire(Cell value) => CellWire(value, new(65536), 0);
    private static JsonObject CellWire(Cell value, Budget budget, int depth) {
        budget.Enter(depth);
        return value switch {
            Missing => V.Obj(("missing", V.Obj())), Null => V.Obj(("null", V.Obj())), SourceTypeError error => V.Obj(("type_error", EnumName(error.Actual))),
            Conflict conflict => V.Obj(("conflict", new JsonArray(conflict.Alternatives.Select(a => (JsonNode?)V.Obj(("counter", Exact(a.Counter)), ("replica", Exact(a.Replica)), ("value", CellWire(a.Value, budget, depth)))).ToArray()))),
            Present present => V.Obj(("value", ValueWire(present.Value, budget, depth))), _ => throw Invalid("cell")
        };
    }
    private static JsonObject ValueWire(Value value, Budget budget, int depth) => value switch {
        Atom atom => V.Obj(("atom", AtomWire(atom, budget))),
        Sequence sequence => V.Obj((EnumName(sequence.Kind), new JsonArray(sequence.Cells.Select(c => (JsonNode?)CellWire(c, budget, depth + 1)).ToArray()))),
        MapValue map => V.Obj(("map", new JsonArray(map.Entries.Select(e => { budget.Enter(depth + 1); return (JsonNode?)V.Obj(("key", AtomWire(e.Key, budget)), ("value", CellWire(e.Value, budget, depth + 1))); }).ToArray()))),
        Tagged tagged => V.Obj(("tagged_union", V.Obj(("index", (ulong)tagged.Index), ("value", CellWire(tagged.Value, budget, depth + 1))))),
        Json json => V.Obj(("json", TextData(json.Text, budget))), _ => throw Invalid("value")
    };
    public static Cell CellFromWire(JsonNode? value) => CellFromWire(value, new(65536), 0);
    private static Cell CellFromWire(JsonNode? value, Budget budget, int depth) {
        budget.Enter(depth); var (kind, payload) = Variant(value);
        switch (kind) {
            case "missing": Fields(payload); return new Missing(); case "null": Fields(payload); return new Null(); case "type_error": return new SourceTypeError(EnumValue<Kind>(payload));
            case "conflict": {
                var alternatives = payload as JsonArray ?? throw Invalid("conflict"); if (alternatives.Count is < 2 or > 8) throw Invalid("conflict count");
                return new Conflict(alternatives.Select(a => { var v = Fields(a, "counter", "replica", "value"); return new Alternative(checked((ulong)UnsignedInteger(v["counter"])), checked((ulong)UnsignedInteger(v["replica"])), CellFromWire(v["value"], budget, depth)); }).ToArray());
            }
            case "value": return new Present(ValueFromWire(payload, budget, depth)); default: throw Invalid("cell variant");
        }
    }
    private static Value ValueFromWire(JsonNode? value, Budget budget, int depth) {
        var (kind, payload) = Variant(value);
        switch (kind) {
            case "atom": return AtomFromWire(payload, budget);
            case "structure": case "list": case "array": {
                var values = payload as JsonArray ?? throw Invalid("sequence"); return new Sequence(kind switch { "structure" => SequenceKind.Structure, "list" => SequenceKind.List, _ => SequenceKind.Array }, values.Select(c => CellFromWire(c, budget, depth + 1)).ToArray());
            }
            case "map": {
                var entries = payload as JsonArray ?? throw Invalid("map"); return new MapValue(entries.Select(e => { budget.Enter(depth + 1); var v = Fields(e, "key", "value"); return new MapEntry(AtomFromWire(v["key"], budget), CellFromWire(v["value"], budget, depth + 1)); }).ToArray());
            }
            case "tagged_union": { var v = Fields(payload, "index", "value"); return new Tagged(checked((byte)V.Number(v["index"])), CellFromWire(v["value"], budget, depth + 1)); }
            case "json": return new Json(TextData(V.String(payload), budget)); default: throw Invalid("value variant");
        }
    }
}

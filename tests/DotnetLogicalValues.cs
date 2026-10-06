using System.Text.Json.Nodes;
using L = Transit.Station.Sdk.Logical;

internal static class LogicalValues
{
    private static void Check(bool value) { if (!value) throw new InvalidOperationException("Logical value assertion"); }
    private static void Reject(Action work) { try { work(); } catch (Exception error) when (error is ArgumentException or FormatException or OverflowException or Transit.Client.TransitException) { return; } throw new InvalidOperationException("Expected invalid logical value"); }
    private static L.Present Present(L.Atom value) => new(value);
    internal static void Run()
    {
        byte[] input = [0,128,255]; L.BinaryData binary = new(input); input[0] = 1; binary.Copy()[0] = 2; Check(binary.Copy()[0] == 0);
        List<L.Cell> cells = [Present(new L.Binary(binary))]; L.Sequence sequence = new(L.SequenceKind.Structure, cells); cells.Clear(); Check(sequence.Cells.Count == 1);
        List<L.Descriptor> types = Enum.GetValues<L.ScalarKind>().Select(kind => (L.Descriptor)new L.Scalar(kind)).ToList();
        types.AddRange([new L.Decimal(38,2), new L.Timestamp(L.Zone.Civil), new L.Timestamp(L.Zone.Utc), new L.Structure([new L.Field("東京", new L.Scalar(L.ScalarKind.Binary), true, true)]), new L.Union([new L.Field("amount", new L.Decimal(38,2))]), new L.ListType(new L.Element(new L.Scalar(L.ScalarKind.Int8))), new L.ArrayType(new L.Element(new L.Scalar(L.ScalarKind.Uuid), true), 2), new L.MapType(new L.Scalar(L.ScalarKind.Utf8), new L.Element(new L.Decimal(38,2)))]);
        foreach (var type in types) { var copy = L.TypeFromWire(L.TypeWire(type)); Check(copy == type && copy.GetHashCode() == type.GetHashCode()); }
        L.Cell[] values = [new L.Missing(), new L.Null(), new L.SourceTypeError(L.Kind.Map), Present(new L.Signed(Int128.MinValue)), Present(new L.Unsigned(UInt128.MaxValue)), Present(new L.DecimalValue(Int128.Parse("123456789012345678901234567890", System.Globalization.CultureInfo.InvariantCulture))),
            Present(new L.Float32(-0.0f)), Present(new L.Float64(-0.0)), Present(new L.BooleanValue(false)), Present(new L.Utf8("東京")), Present(new L.Binary(binary)), Present(new L.Uuid(new L.BinaryData(new byte[16]))), Present(new L.DateDays(-100)), Present(new L.TimeNanos(123)), Present(new L.TimestampMicros(-1000)), Present(new L.Interval(-1,2,-3000)),
            new L.Present(new L.Json("{\"n\":123}")), new L.Present(sequence), new L.Present(new L.Sequence(L.SequenceKind.Array, [new L.Null()])), new L.Present(new L.MapValue([new L.MapEntry(new L.Signed(1), new L.Null())])), new L.Present(new L.Tagged(1, new L.Null()))];
        foreach (var value in values) { var copy = L.CellFromWire(L.CellWire(value)); Check(copy == value && copy.GetHashCode() == value.GetHashCode()); }
        Check(L.AtomWire(new L.Float32(-0.0f))["float_bits"]!.GetValue<string>() == "00000080"); Check(new L.Float32(-0.0f) != new L.Float32(0.0f)); Check(new L.Float64(-0.0) != new L.Float64(0.0));
        Reject(() => new L.Float32(float.PositiveInfinity)); Reject(() => new L.Float64(double.NaN));
        Reject(() => L.AtomFromWire(JsonNode.Parse("{\"signed\":\"01\"}"))); Reject(() => L.AtomFromWire(JsonNode.Parse("{\"uuid\":\"00\"}")));
        L.Conflict conflict = new([new L.Alternative(1,1,Present(new L.BooleanValue(true))), new L.Alternative(1,2,new L.Null())]); L.Cell deep = conflict;
        for (int i = 0; i < 15; i++) deep = new L.Present(new L.Sequence(L.SequenceKind.List, [deep]));
        Check(L.CellFromWire(L.CellWire(deep)) == deep); L.Cell extra = new L.Present(new L.Sequence(L.SequenceKind.List, [deep])); Reject(() => L.CellWire(extra));
        Reject(() => new L.Conflict(conflict.Alternatives.Reverse().ToArray())); Reject(() => new L.Alternative(0,1,new L.Null()));
        L.MapEntry pair = new(new L.Signed(1), new L.Null()); L.Cell map = new L.Present(new L.MapValue(Enumerable.Repeat(pair, 32767).ToArray())); Check(L.CellFromWire(L.CellWire(map)) == map);
        Reject(() => new L.MapValue(Enumerable.Repeat(pair,32768).ToArray()));
        L.Cell large = new L.Present(new L.Sequence(L.SequenceKind.List, Enumerable.Repeat<L.Cell>(Present(new L.Utf8(new string('x',600000))), 2).ToArray())); Reject(() => L.CellWire(large));
        JsonObject wire = JsonNode.Parse("{\"value\":{\"list\":[]}}")!.AsObject(); var children = wire["value"]!["list"]!.AsArray();
        for (int i = 0; i < 2; i++) children.Add(L.CellWire(Present(new L.Utf8(new string('x',600000))))); Reject(() => L.CellFromWire(wire));
        Reject(() => L.TypeWire(new L.Structure(Enumerable.Repeat(new L.Field("n", new L.Scalar(L.ScalarKind.Int8)),256).ToArray())));
        Reject(() => L.TypeWire(new L.Structure(Enumerable.Repeat(new L.Field(new string('x',2100), new L.Scalar(L.ScalarKind.Int8)),2).ToArray())));
        L.Cell floatBudget = new L.Present(new L.Sequence(L.SequenceKind.List, [Present(new L.Utf8(new string('x',1024*1024-2))), Present(new L.Float32(1.0f))])); Reject(() => L.CellWire(floatBudget));
        L.Cell owned = Present(new L.Binary(new L.BinaryData(new byte[300000]))); Check(L.CellFromWire(L.CellWire(owned)) == owned);
    }
}

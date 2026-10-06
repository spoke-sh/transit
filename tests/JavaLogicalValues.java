package io.transit.sdk.station;

import com.google.gson.*;
import static io.transit.sdk.station.Logical.*;
import java.math.BigInteger;
import java.util.*;

/** Owned logical families and aggregate bounds, independently of Table storage. */
public final class JavaLogicalValues {
    private JavaLogicalValues() {}
    private static void check(boolean value) { if (!value) throw new AssertionError("Logical value assertion"); }
    private static void rejects(Runnable work) { try { work.run(); } catch (RuntimeException expected) { return; } throw new AssertionError("Expected invalid logical value"); }
    private static BigInteger n(long value) { return BigInteger.valueOf(value); }
    private static Present present(Atom value) { return new Present(value); }
    public static void run() {
        byte[] data = {0, (byte)128, (byte)255}; BinaryData owned = new BinaryData(data); data[0] = 1; owned.copy()[0] = 2; check(owned.copy()[0] == 0);
        List<Cell> input = new ArrayList<>(List.of(present(new Binary(owned)))); Sequence sequence = new Sequence(SequenceKind.STRUCTURE, input); input.clear(); check(sequence.cells().size() == 1); rejects(() -> sequence.cells().clear());
        List<Descriptor> types = new ArrayList<>(List.of(Scalar.values()));
        types.addAll(List.of(new Decimal(38, 2), new Timestamp(Zone.CIVIL), new Timestamp(Zone.UTC), new Structure(List.of(new Field("東京", Scalar.BINARY, true, true))), new Union(List.of(new Field("amount", new Decimal(38, 2)))), new ListType(new Element(Scalar.INT8)), new ArrayType(new Element(Scalar.UUID, true), 2), new MapType(Scalar.UTF8, new Element(new Decimal(38, 2)))));
        for (Descriptor type : types) check(typeFromWire(typeWire(type)).equals(type));
        List<Cell> values = List.of(new Missing(), new Null(), new SourceTypeError(Kind.MAP),
            new SourceTypeError(Kind.UNKNOWN), new SourceTypeError(Kind.NULL_VALUE), new SourceTypeError(Kind.TEXT), new SourceTypeError(Kind.CHARACTER),
            present(new Signed(BigInteger.ONE.shiftLeft(127).negate())), present(new Unsigned(BigInteger.ONE.shiftLeft(128).subtract(BigInteger.ONE))), present(new DecimalValue(new BigInteger("123456789012345678901234567890"))),
            present(new Float32(-0.0f)), present(new Float64(-0.0)), present(new BooleanValue(false)), present(new Utf8("東京")), present(new Binary(owned)), present(new Uuid(new BinaryData(new byte[16]))),
            present(new DateDays(-100)), present(new TimeNanos(n(123))), present(new TimestampMicros(-1000)), present(new Interval(-1, 2, -3000)), new Present(new Json("{\"n\":123}")),
            new Present(sequence), new Present(new Sequence(SequenceKind.ARRAY, List.of(new Null()))), new Present(new MapValue(List.of(new MapEntry(new Signed(n(1)), new Null())))), new Present(new Tagged(1, new Null())));
        for (Cell value : values) check(cellFromWire(cellWire(value)).equals(value));
        check(atomWire(new Float32(-0.0f)).get("float_bits").getAsString().equals("00000080"));
        check(Float.floatToRawIntBits(((Float32)atomFromWire(atomWire(new Float32(-0.0f)))).value()) == 0x80000000);
        rejects(() -> new Float32(Float.POSITIVE_INFINITY)); rejects(() -> new Float64(Double.NaN)); rejects(() -> new Signed(BigInteger.ONE.shiftLeft(127)));
        rejects(() -> atomFromWire(new Gson().fromJson("{\"signed\":\"01\"}", JsonObject.class))); rejects(() -> atomFromWire(new Gson().fromJson("{\"uuid\":\"00\"}", JsonObject.class)));
        Conflict conflict = new Conflict(List.of(new Alternative(n(1), n(1), present(new BooleanValue(true))), new Alternative(n(1), n(2), new Null())));
        Cell deep = conflict;
        for (int i = 0; i < 15; i++) deep = new Present(new Sequence(SequenceKind.LIST, List.of(deep)));
        check(cellFromWire(cellWire(deep)).equals(deep)); Cell extra = new Present(new Sequence(SequenceKind.LIST, List.of(deep))); rejects(() -> cellWire(extra));
        rejects(() -> new Conflict(conflict.alternatives().reversed())); rejects(() -> new Alternative(n(0), n(1), new Null()));
        MapEntry pair = new MapEntry(new Signed(n(1)), new Null()); Cell map = new Present(new MapValue(Collections.nCopies(32767, pair))); check(cellFromWire(cellWire(map)).equals(map));
        rejects(() -> new MapValue(Collections.nCopies(32768, pair)));
        Cell large = new Present(new Sequence(SequenceKind.LIST, Collections.nCopies(2, present(new Utf8("x".repeat(600000)))))); rejects(() -> cellWire(large));
        JsonObject wire = new Gson().fromJson("{\"value\":{\"list\":[]}}", JsonObject.class); JsonArray children = wire.getAsJsonObject("value").getAsJsonArray("list");
        for (int i = 0; i < 2; i++) children.add(cellWire(present(new Utf8("x".repeat(600000))))); rejects(() -> cellFromWire(wire));
        rejects(() -> typeWire(new Structure(Collections.nCopies(256, new Field("n", Scalar.INT8)))));
        rejects(() -> typeWire(new Structure(Collections.nCopies(2, new Field("x".repeat(2100), Scalar.INT8)))));
        Cell floatBudget = new Present(new Sequence(SequenceKind.LIST, List.of(present(new Utf8("x".repeat(1024 * 1024 - 2))), present(new Float32(1.0f))))); rejects(() -> cellWire(floatBudget));
        // Valid large hex is decoded without a regex frame per byte.
        Cell binary = present(new Binary(new BinaryData(new byte[300000]))); check(cellFromWire(cellWire(binary)).equals(binary));
        Cell maps = present(new BooleanValue(true));
        for (int i = 0; i < 15; i++) maps = new Present(new MapValue(List.of(new MapEntry(new Signed(n(1)), maps))));
        check(cellFromWire(cellWire(maps)).equals(maps));
        JsonObject nested = cellWire(maps);
        for (int i = 0; i < 5; i++) nested = io.transit.client.internal.Values.obj("envelope", nested);
        byte[] encoded = nested.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
        try {
            check(io.transit.client.internal.Values.parse(encoded, 96).equals(nested));
        } catch (java.io.IOException error) { throw new AssertionError("Catalog JSON rejected logical nesting", error); }
        try { io.transit.client.internal.Values.parse(encoded); throw new AssertionError("Raw JSON depth bound changed"); }
        catch (java.io.IOException expected) { }
    }
    public static void main(String[] args) { run(); System.out.println("Java logical ownership, recursive families and aggregate budgets passed."); }
}

package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import static io.transit.client.internal.Values.obj;
import java.math.BigInteger;
import java.util.*;

/** Owned handler values and recovery boundaries; authority dispatch is tested separately. */
public final class JavaHandlerTables {
    private JavaHandlerTables() {}
    private static final BigInteger MAX = BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    private static final ResourceRef RESOURCE = new ResourceRef(46, 7);
    private static int rejected;
    private static BigInteger n(long value) { return BigInteger.valueOf(value); }
    private static void check(boolean value) { if (!value) throw new AssertionError("Handler Table assertion failed"); }
    private static void rejects(Runnable work) {
        try { work.run(); } catch (RuntimeException expected) { rejected++; return; }
        throw new AssertionError("Expected rejection");
    }
    private static JsonObject json(String value) { return new Gson().fromJson(value, JsonObject.class); }
    private static Logical.Cell signed(long value) { return new Logical.Present(new Logical.Signed(n(value))); }
    private static Catalog.Schema schema() {
        return new Catalog.Schema(MAX, n(1), n(5), List.of(
            new Catalog.Column(n(1), "id", Logical.Scalar.INT64, false, Optional.empty(), Optional.empty(), Catalog.Encoding.PLAIN, Catalog.Collation.NONE),
            new Catalog.Column(n(2), "amount", new Logical.Decimal(20, 2)),
            new Catalog.Column(n(3), "data", Logical.Scalar.BINARY),
            new Catalog.Column(n(4), "tags", new Logical.ListType(new Logical.Element(Logical.Scalar.UTF8, true)))), List.of(n(1)));
    }
    private static JsonObject reference() {
        return obj("definition", Catalog.DEFINITION, "realm", 46, "resource", 7, "object", MAX.toString(), "principal", 17, "operation", MAX.toString(), "digest", "ab".repeat(32));
    }
    private static JsonObject status() {
        return obj("reference", reference(), "state", "applied", "route", "statement", "admitted_input", 9,
            "completed_input", 11, "counts", obj("matched", "1", "changed", "1"), "rejection", "none", "witness", null);
    }
    public static void main(String[] args) throws java.io.IOException {
        byte[] bytes = {1, 2, 3};
        List<Logical.Cell> tags = new ArrayList<>(List.of(new Logical.Present(new Logical.Utf8("red")), new Logical.Null()));
        List<Catalog.Assignment> assignments = new ArrayList<>(List.of(
            new Catalog.Assignment(n(1), signed(7)),
            new Catalog.Assignment(n(2), new Logical.Present(new Logical.DecimalValue(n(12345)))),
            new Catalog.Assignment(n(3), new Logical.Present(new Logical.Binary(new Logical.BinaryData(bytes)))),
            new Catalog.Assignment(n(4), new Logical.Present(new Logical.Sequence(Logical.SequenceKind.LIST, tags)))));
        List<List<Catalog.Assignment>> rows = new ArrayList<>(List.of(assignments));
        Table.Mutation mutation = Table.Mutation.prepare(RESOURCE, 17, MAX, schema(), new Catalog.Insert(rows));
        String saved = mutation.save(); bytes[0] = 9; tags.clear(); assignments.clear(); rows.clear();
        check(mutation.save().equals(saved)); check(mutation.schema().equals(schema())); check(mutation.operation().equals(MAX));
        check(Table.Mutation.load(saved).save().equals(saved));
        Logical.Descriptor nestedType = Logical.Scalar.INT64; Logical.Cell nested = signed(1);
        for (int i = 0; i < 15; i++) {
            nestedType = new Logical.MapType(Logical.Scalar.INT64, new Logical.Element(nestedType, false));
            nested = new Logical.Present(new Logical.MapValue(List.of(new Logical.MapEntry(new Logical.Signed(n(0)), nested))));
        }
        var nestedIntent = Table.Mutation.prepare(RESOURCE, 0, n(1), new Catalog.Schema(n(1), n(1), n(2), List.of(new Catalog.Column(n(1), "deep", nestedType))), new Catalog.Insert(List.of(List.of(new Catalog.Assignment(n(1), nested)))));
        check(Table.Mutation.load(nestedIntent.save()).schema().columns().getFirst().type().equals(nestedType));
        byte[] envelope = obj("table", obj("mutate", json(nestedIntent.save()))).toString().getBytes(java.nio.charset.StandardCharsets.UTF_8);
        check(io.transit.client.internal.Values.parse(envelope, 96).isJsonObject());
        try { io.transit.client.internal.Values.parse(envelope, 64); throw new AssertionError("Expected shallow transport rejection"); }
        catch (java.io.IOException expected) { rejected++; }
        Catalog.Mutation decoded = CatalogValues.mutation(json(saved).get("mutation"));
        var stored = ((Catalog.Insert)decoded).rows().getFirst();
        check(((Logical.Binary)((Logical.Present)((Catalog.CellValue)stored.get(2).value()).cell()).value()).value().copy()[0] == 1);
        rejects(() -> stored.clear());
        byte[] identityBytes = new byte[20]; identityBytes[0] = 3;
        Table.RowIdentity identity = new Table.RowIdentity(identityBytes); identityBytes[0] = 0; identity.bytes().copy()[0] = 0;
        List<Logical.Cell> cells = new ArrayList<>(List.of(signed(7), new Logical.Null()));
        Table.Row row = new Table.Row(identity, cells); cells.clear();
        check(row.cells().size() == 2 && row.identity().bytes().copy()[0] == 3);
        rejects(() -> row.cells().clear()); rejects(() -> new Table.RowIdentity(new byte[19]));
        rejects(() -> new Table.Page(Collections.nCopies(9, row), Optional.empty()));
        for (int i = 0; i < 11; i++) {
            JsonObject bad = json(saved); JsonObject definition = bad.getAsJsonObject("schema");
            switch (i) {
                case 0 -> definition.remove("definition");
                case 1 -> definition.addProperty("definition", "00".repeat(32));
                case 2 -> bad.addProperty("operation", "0");
                case 3 -> bad.addProperty("operation", "01");
                case 4 -> bad.addProperty("operation", MAX.add(n(1)).toString());
                case 5 -> bad.addProperty("realm", 0);
                case 6 -> bad.addProperty("unknown", true);
                case 7 -> definition.addProperty("object", "0");
                case 8 -> bad.getAsJsonObject("mutation").getAsJsonObject("action").getAsJsonArray("insert").get(0).getAsJsonArray().get(0).getAsJsonObject().addProperty("column", "0");
                case 9 -> bad.getAsJsonObject("mutation").getAsJsonObject("action").getAsJsonArray("insert").get(0).getAsJsonArray().get(0).getAsJsonObject().add("value", obj("cell", obj("value", obj("atom", obj("signed", "01")))));
                case 10 -> bad.getAsJsonObject("mutation").getAsJsonObject("action").getAsJsonArray("insert").get(0).getAsJsonArray().get(0).getAsJsonObject().add("value", obj("cell", obj("value", obj("atom", obj("signed", BigInteger.ONE.shiftLeft(127).toString())))));
                default -> throw new AssertionError();
            }
            rejects(() -> Table.Mutation.load(bad.toString()));
        }
        rejects(() -> Table.Mutation.load(" " + saved));
        rejects(() -> Table.Mutation.load("[".repeat(97) + "0" + "]".repeat(97)));
        rejects(() -> Table.Mutation.load(saved.replace("\"realm\":46", "\"realm\":46,\"realm\":46")));
        List<Catalog.Column> columns = new ArrayList<>(); List<Catalog.Assignment> wide = new ArrayList<>();
        for (int i = 1; i <= 128; i++) { columns.add(new Catalog.Column(n(i), "c" + i, Logical.Scalar.INT64)); wide.add(new Catalog.Assignment(n(i), signed(i))); }
        Table.Mutation.prepare(RESOURCE, 0, n(1), new Catalog.Schema(n(1), n(1), n(129), columns), new Catalog.Insert(List.of(wide)));
        Table.Mutation.prepare(RESOURCE, 0, n(1), schema(), new Catalog.Insert(Collections.nCopies(1024, List.of(new Catalog.Assignment(n(1), signed(1))))));
        rejects(() -> new Catalog.Insert(Collections.nCopies(1025, List.of())));
        rejects(() -> new Catalog.Insert(List.of(Collections.nCopies(129, new Catalog.Assignment(n(1), signed(1))))));
        rejects(() -> Table.Mutation.prepare(RESOURCE, 0, n(1), schema(), new Catalog.Insert(List.of(List.of(new Catalog.Assignment(n(3), new Logical.Present(new Logical.Binary(new Logical.BinaryData(new byte[140000])))))))));
        Catalog.Update update = new Catalog.Update(List.of(new Catalog.Assignment(n(2), Catalog.Default.VALUE)), Optional.of(List.of(
            new Catalog.Comparison(n(1), Catalog.CompareOperator.GT, new Logical.Signed(n(0))),
            new Catalog.StatePredicate(n(2), Catalog.CellState.NULL), Catalog.BooleanOperator.DISJUNCTION)));
        check(CatalogValues.mutation(update.wire()).equals(update)); check(CatalogValues.mutation(new Catalog.Delete().wire()).equals(new Catalog.Delete()));
        check(Table.Mutation.load(Table.Mutation.prepare(RESOURCE, 0, n(1), schema(), update).save()).schema().equals(schema()));
        Table.Reference reference = Table.Reference.load(reference().toString());
        check(reference.save().equals(reference().toString()));
        for (int i = 0; i < 4; i++) {
            JsonObject bad = reference();
            switch (i) { case 0 -> bad.remove("definition"); case 1 -> bad.addProperty("digest", "ab"); case 2 -> bad.addProperty("digest", "AB".repeat(32)); case 3 -> bad.addProperty("object", "0"); default -> throw new AssertionError(); }
            rejects(() -> Table.Reference.load(bad.toString()));
        }
        Table.MutationStatus complete = Table.status(status());
        check(complete.counts().orElseThrow().changed().equals(n(1)) && complete.completedInput().orElseThrow() == 11);
        for (int i = 0; i < 5; i++) {
            JsonObject bad = status();
            switch (i) { case 0 -> bad.add("counts", JsonNull.INSTANCE); case 1 -> bad.addProperty("state", "building"); case 2 -> bad.addProperty("completed_input", 8); case 3 -> bad.addProperty("rejection", "row_exists"); case 4 -> bad.getAsJsonObject("counts").addProperty("changed", "2"); default -> throw new AssertionError(); }
            rejects(() -> Table.status(bad));
        }
        JsonObject building = status(); building.addProperty("state", "building"); building.add("counts", JsonNull.INSTANCE); building.add("completed_input", JsonNull.INSTANCE);
        check(Table.status(building).counts().isEmpty());
        Turn foreign = new Turn(null, obj("scope", 1, "resource", 8), new ProcessRef(46, 3), new Types.StopToken());
        rejects(() -> mutation.step(foreign)); rejects(() -> reference.status(foreign));
        Turn expired = new Turn(null, obj("scope", 1, "resource", 7), new ProcessRef(46, 3), new Types.StopToken()); expired.endScope();
        rejects(() -> mutation.step(expired)); rejects(() -> reference.cancel(expired));
        List<Integer> projection = new ArrayList<>(List.of(3, 1, 127));
        List<Optional<String>> names = new ArrayList<>(List.of(Optional.of("tags"), Optional.empty(), Optional.of("last")));
        Query.Plan query = new Query.Plan(new UnifiedQuery.Plan(projection, new UnifiedQuery.Compare(1, Query.Comparison.GT, new Logical.DecimalValue(n(123))), Query.Aggregate.ROWS, Optional.of(MAX), Optional.of(names)));
        JsonObject original = query.wire(); projection.clear(); names.clear(); query.wire().add("projection", new JsonArray());
        check(query.wire().equals(original)); check(original.getAsJsonArray("projection").get(2).getAsInt() == 127);
        check(original.get("limit").getAsString().equals(MAX.toString()));
        System.out.println("Java handler Tables: owned recursive values, exact saved identities, schema/row/byte bounds, scoped access, applied counts and frozen general query plans passed (" + rejected + " rejections).");
    }
}

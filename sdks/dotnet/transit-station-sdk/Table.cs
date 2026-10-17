using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk.Internal;
using V = Transit.Client.Internal.Value;
using static Transit.Station.Sdk.Logical;

namespace Transit.Station.Sdk;

public sealed record RowIdentity
{
    public Bytes Bytes { get; }
    public RowIdentity(Bytes bytes) { ArgumentNullException.ThrowIfNull(bytes); if (bytes.Length != 20) throw new ArgumentException("Expected 20-byte row identity"); Bytes = bytes; }
    public RowIdentity(byte[] bytes) : this(new Bytes(bytes)) { }
}
public sealed record TableRow
{
    public RowIdentity Identity { get; }
    public IReadOnlyList<Logical.Cell> Cells { get; }
    public TableRow(RowIdentity identity, IReadOnlyList<Logical.Cell> cells) {
        ArgumentNullException.ThrowIfNull(identity); Identity = identity; Cells = Own(cells, 128);
        if (Cells.Count == 0) throw new ArgumentException("Expected row cells");
    }
}
public sealed record TableBasis
{
    public ResourceRef Resource { get; }
    public ulong Revision { get; }
    public ulong ObjectId { get; }
    public Bytes Head { get; }
    public TableBasis(ResourceRef resource, ulong revision, ulong objectId, Bytes head) {
        ArgumentNullException.ThrowIfNull(resource); Resource = resource; Revision = V.Counter(revision);
        ObjectId = Catalog.Positive(objectId); Head = Catalog.Digest(head);
    }
}
public sealed record TablePage
{
    public IReadOnlyList<TableRow> Rows { get; }
    public Cursor? Next { get; }
    public TablePage(IReadOnlyList<TableRow> rows, Cursor? next) { Rows = Own(rows, 8); Next = next; }
}
public enum TableCreationState { Building, Applied }
public sealed record TableCreation(TableCreationState State, ulong AdmittedInput, ulong? CompletedInput);
public enum TableMutationState { Building, Applied, Rejected, Cancelled }
public enum TableMutationRoute { Point, Statement, Alter }
public enum TableRejection { None, RowExists, RowIdentityExists, NullNotAllowed, MissingRequiredField, CharacterLimitExceeded, Overflow, Inexact }
public enum TableWitnessSource { Input, Stored, Withheld }
public sealed record TableWitness(TableWitnessSource Source, RowIdentity? Row, ulong Column, string Text, bool Truncated);
public sealed record TableMutationStatus(TableMutationReference Reference, TableMutationState State, TableMutationRoute Route,
    ulong AdmittedInput, ulong? CompletedInput, Catalog.Counts? Counts, TableRejection Rejection, TableWitness? Witness);

internal static class TableValues
{
    private static readonly JsonObject Action = V.Object(V.Object(Catalog.Contract["schemas"])["GrowingAction"]);
    internal static string Json(JsonNode value) => value.ToJsonString(Catalog.CatalogJson);
    internal static JsonObject Parse(string data) => V.Object(V.Parse(V.Utf8.GetBytes(data), 96));
    internal static JsonObject Saved(string data, string tag) {
        V.Text(data, Catalog.Limit("handler_action_bytes")); JsonObject value = Parse(data);
        if (Json(value) != data) throw V.Incompatible("saved-table-canonical");
        JsonObject envelope = V.Obj(("table", V.Obj((tag, value.DeepClone()))));
        V.Text(Json(envelope), Catalog.Limit("handler_action_bytes"));
        Transit.Client.Internal.Schema.Require(Action, envelope); return value;
    }
    internal static Bytes Exact(JsonNode? value, int size) {
        byte[] bytes = V.Unhex(value, size); if (bytes.Length != size) throw V.Incompatible("table-bytes"); return new(bytes);
    }
    internal static void SameResource(Turn turn, JsonObject value) {
        var resource = new ResourceRef(V.Number(value["realm"], 1), V.Number(value["resource"], 1));
        if (turn.ResourceRef != resource) throw new TransitException(ErrorKind.Handler, "foreign-table-resource");
    }
    internal static JsonNode? Raw(Turn turn, string tag, JsonNode request, string expected) => Fields(Fields(turn.Raw(V.Obj(("table", V.Obj((tag, request))))), "table")["table"], expected)[expected];
    internal static TableMutationStatus Status(JsonNode? value) {
        var v = Fields(value, "reference", "state", "route", "admitted_input", "completed_input", "counts", "rejection", "witness");
        var state = EnumValue<TableMutationState>(v["state"]); var route = EnumValue<TableMutationRoute>(v["route"]); var rejection = EnumValue<TableRejection>(v["rejection"]);
        ulong admitted = V.Number(v["admitted_input"], 1); ulong? completed = v["completed_input"] is {} c ? V.Number(c, 1) : null;
        if ((completed is null) != (state == TableMutationState.Building) || completed < admitted || (rejection != TableRejection.None) != (state == TableMutationState.Rejected)) throw V.Incompatible("table-mutation-completion");
        Catalog.Counts? counts = null;
        if (v["counts"] is {} rawCounts) { var cs = Fields(rawCounts, "matched", "changed"); counts = new(NativeValues.Wide(cs["matched"]), NativeValues.Wide(cs["changed"])); }
        if ((counts is not null) != (state == TableMutationState.Applied)) throw V.Incompatible("table-mutation-counts");
        TableWitness? witness = null;
        if (v["witness"] is {} rawWitness) {
            var w = Fields(rawWitness, "source", "row", "column", "text", "truncated");
            witness = new(EnumValue<TableWitnessSource>(w["source"]), w["row"] is {} r ? new RowIdentity(Exact(r, 20)) : null,
                NativeValues.Wide(w["column"]), V.Text(V.String(w["text"]), 256), V.Boolean(w["truncated"]));
        }
        return new(TableMutationReference.Load(Json(V.Object(v["reference"]))), state, route, admitted, completed, counts, rejection, witness);
    }
}

public sealed class TableMutationReference
{
    private readonly string data;
    private TableMutationReference(string data) { this.data = data; }
    public static TableMutationReference Load(string data) {
        var value = TableValues.Saved(data, "status"); Catalog.Current(V.String(value["definition"]));
        _ = new ResourceRef(V.Number(value["realm"], 1), V.Number(value["resource"], 1));
        NativeValues.Wide(value["object"], true); NativeValues.Wide(value["operation"], true); TableValues.Exact(value["digest"], 32);
        return new(data);
    }
    public string Save() => data;
    private TableMutationStatus? Read(Turn turn, string tag) {
        JsonObject request = TableValues.Parse(data); TableValues.SameResource(turn, request);
        return turn.Access(tag == "status", () => {
            JsonNode? value = TableValues.Raw(turn, tag, request, "mutation"); if (value is null) return null;
            TableMutationStatus result = TableValues.Status(value);
            if (!JsonNode.DeepEquals(TableValues.Parse(result.Reference.Save()), request)) throw V.Incompatible("foreign-table-outcome");
            return result;
        });
    }
    public TableMutationStatus? Status(Turn turn) => Read(turn, "status");
    public TableMutationStatus Cancel(Turn turn) => Read(turn, "cancel") ?? throw V.Incompatible("missing-cancelled-table-mutation");
}

public sealed class TableMutation
{
    private readonly string data;
    private TableMutation(string data) { this.data = data; }
    public static TableMutation Prepare(ResourceRef resource, ulong principal, ulong operation, Catalog.Schema schema, Catalog.Mutation mutation) {
        ArgumentNullException.ThrowIfNull(resource); V.Counter(principal, 0); Catalog.Positive(operation);
        return Load(TableValues.Json(V.Obj(("realm", resource.Realm), ("resource", resource.Resource), ("principal", principal), ("operation", Turn.Decimal(operation)), ("schema", schema.Wire()), ("mutation", mutation.Wire()))));
    }
    public static TableMutation Load(string data) {
        var value = TableValues.Saved(data, "mutate"); Catalog.ParseSchema(value["schema"]); Catalog.ParseMutation(value["mutation"]);
        _ = new ResourceRef(V.Number(value["realm"], 1), V.Number(value["resource"], 1)); NativeValues.Wide(value["operation"], true);
        return new(data);
    }
    public string Save() => data;
    public Catalog.Schema Schema => Catalog.ParseSchema(TableValues.Parse(data)["schema"]);
    public ulong Operation => NativeValues.Wide(TableValues.Parse(data)["operation"], true);
    public TableMutationStatus Step(Turn turn) {
        JsonObject request = TableValues.Parse(data); TableValues.SameResource(turn, request);
        return turn.Access(false, () => {
            TableMutationStatus result = TableValues.Status(TableValues.Raw(turn, "mutate", request, "mutation"));
            JsonObject identity = TableValues.Parse(result.Reference.Save());
            foreach (string key in new[] { "realm", "resource", "principal", "operation" }) if (!JsonNode.DeepEquals(identity[key], request[key])) throw V.Incompatible("foreign-table-outcome");
            if (!JsonNode.DeepEquals(identity["object"], V.Object(request["schema"])["object"])) throw V.Incompatible("foreign-table-outcome");
            return result;
        });
    }
}

/// <summary>General application-owned Tables. Each mutation step prepares one private turn.</summary>
public sealed class Table
{
    private readonly Turn turn;
    private readonly ReadVersion? version;
    public Catalog.Schema Schema { get; }
    public TableBasis Basis { get; }
    private Table(Turn turn, Catalog.Schema schema, ReadVersion? version, TableBasis basis) { this.turn = turn; Schema = schema; this.version = version; Basis = basis; }
    internal static Table Open(Turn turn, ulong objectId, ReadVersion? version) {
        Catalog.Positive(objectId);
        var value = Fields(TableValues.Raw(turn, "schema", V.Obj(("object", Turn.Decimal(objectId)), ("version", version is null ? null : NativeValues.Wire(version))), "schema"), "schema", "basis");
        Catalog.Schema schema = Catalog.ParseSchema(value["schema"]); var b = Fields(value["basis"], "resource", "revision", "object", "head");
        TableBasis basis = new(new ResourceRef(turn.ProcessRef.Realm, V.Number(b["resource"], 1)), V.Number(b["revision"], 1), NativeValues.Wide(b["object"], true), TableValues.Exact(b["head"], 32));
        if (schema.ObjectId != objectId || basis.ObjectId != objectId) throw V.Incompatible("foreign-table-definition");
        return new(turn, schema, version, basis);
    }
    internal static TableCreation Create(Turn turn, Catalog.Schema schema, Catalog.TableLimits limits) {
        var value = Fields(TableValues.Raw(turn, "create", V.Obj(("realm", turn.ResourceRef.Realm), ("resource", turn.ResourceRef.Resource), ("schema", schema.Wire()), ("limits", limits.Wire())), "created"), "state", "admitted_input", "completed_input");
        var state = EnumValue<TableCreationState>(value["state"]); ulong admitted = V.Number(value["admitted_input"], 1), completed = V.Number(value["completed_input"]);
        if ((completed == 0) != (state == TableCreationState.Building) || (completed != 0 && completed < admitted)) throw V.Incompatible("table-creation-completion");
        return new(state, admitted, completed == 0 ? null : completed);
    }
    private JsonObject Source() => V.Obj(("object", Turn.Decimal(Schema.ObjectId)), ("version", version is null ? null : NativeValues.Wire(version)));
    private void CheckBasis(JsonNode? value) {
        var b = Fields(Fields(value, "schema", "basis")["basis"], "resource", "revision", "object", "head");
        if (V.Number(b["resource"], 1) != Basis.Resource.Resource || V.Number(b["revision"], 1) != Basis.Revision || NativeValues.Wide(b["object"], true) != Basis.ObjectId || !TableValues.Exact(b["head"], 32).Equals(Basis.Head)) throw V.Incompatible("changed-table-basis");
    }
    private static TableRow Row(JsonNode? value) {
        var v = Fields(value, "identity", "cells");
        if (v["cells"] is not JsonArray { Count: > 0 and <= 128 } cells) throw V.Incompatible("table-row-width");
        return new(new RowIdentity(TableValues.Exact(v["identity"], 20)), cells.Select(Logical.CellFromWire).ToArray());
    }
    private TableRow? ReadRow(string tag, JsonObject request) => turn.Access(true, () => {
        var value = Fields(TableValues.Raw(turn, tag, request, "row"), "definition", "row"); CheckBasis(value["definition"]);
        return value["row"] is {} row ? Row(row) : null;
    });
    public TableRow? Get(RowIdentity identity) => ReadRow("get", V.Obj(("source", Source()), ("identity", V.Hex(identity.Bytes.Copy()))));
    public TableRow? GetKey(IReadOnlyList<Logical.Cell> key) {
        if (key.Count is < 1 or > 128) throw new ArgumentException("Expected primary-key cells");
        return ReadRow("get_key", V.Obj(("source", Source()), ("key", new JsonArray(key.Select(v => (JsonNode?)Logical.CellWire(v)).ToArray()))));
    }
    public TablePage Page(Cursor? cursor = null, int limit = 8) {
        if (limit is < 1 or > 8) throw new ArgumentException("Expected one to eight rows"); if (cursor is not null) V.Text(cursor.Opaque, 2048);
        return turn.Access(true, () => {
            var value = Fields(TableValues.Raw(turn, "page", V.Obj(("source", Source()), ("cursor", cursor?.Opaque), ("limit", limit)), "page"), "definition", "rows", "next"); CheckBasis(value["definition"]);
            if (value["rows"] is not JsonArray rows || rows.Count > limit) throw V.Incompatible("table-page-bound");
            return new TablePage(rows.Select(Row).ToArray(), NativeValues.Cursor(value["next"]));
        });
    }
    public TableMutation Prepare(ulong principal, ulong operation, Catalog.Mutation mutation) {
        turn.Check(); if (version is not null) throw new TransitException(ErrorKind.Handler, "retained-table-read-only");
        return TableMutation.Prepare(Basis.Resource, principal, operation, Schema, mutation);
    }
}

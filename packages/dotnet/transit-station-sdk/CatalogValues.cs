using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk.Internal;
using V = Transit.Client.Internal.Value;

namespace Transit.Station.Sdk;

public static partial class Catalog
{
    private static T Decode<T>(Func<T> decode) {
        try { return decode(); }
        catch (Exception error) when (error is ArgumentException or InvalidOperationException or OverflowException or FormatException) { throw V.Incompatible("catalog-response"); }
    }
    private static T Variant<T>(JsonNode? value) where T : struct, Enum {
        string name = V.String(value); foreach (T item in Enum.GetValues<T>()) if (Logical.EnumName(item) == name) return item;
        throw V.Incompatible("catalog-variant");
    }
    private static JsonObject Fields(JsonNode? value, params string[] names) {
        var result = V.Object(value);
        if (result.Count != names.Length || names.Any(name => !result.ContainsKey(name))) throw V.Incompatible("catalog-fields"); return result;
    }
    private static JsonNode? Result(JsonNode? value, string key) => Fields(value, key)[key];
    private static ulong Wide(JsonNode? value) => NativeValues.Wide(value, true);
    private static ulong Zero(JsonNode? value) => NativeValues.Wide(value, false);
    private static uint Small(JsonNode? value, ulong minimum = 0) => checked((uint)V.Number(value, minimum));
    private static Scope ParseScope(JsonNode? value) {
        var v = Fields(value, "realm", "resource", "catalog"); return new(new ResourceRef(V.Number(v["realm"], 1), V.Number(v["resource"], 1)), Wide(v["catalog"]));
    }
    private static Configuration ParseConfiguration(JsonNode? value) {
        var v = Fields(value, "scope", "owner", "administrator", "table_limits"); var scope = ParseScope(v["scope"]); var l = Fields(v["table_limits"], "record_bytes", "staging_bytes", "staging_records");
        return new(scope, new ProcessRef(scope.Resource.Realm, V.Number(v["owner"], 1)), V.Number(v["administrator"], 1), new(Small(l["record_bytes"], 1), Wide(l["staging_bytes"]), Small(l["staging_records"], 1)));
    }
    private static Policy ParsePolicy(JsonNode? value) {
        var v = Fields(value, "scope", "principal", "revision", "inspect", "create", "read", "insert", "update", "delete", "alter", "drop");
        return new(ParseScope(v["scope"]), V.Number(v["principal"]), Wide(v["revision"]), new(V.Boolean(v["inspect"]), V.Boolean(v["create"]), V.Boolean(v["read"]), V.Boolean(v["insert"]), V.Boolean(v["update"]), V.Boolean(v["delete"]), V.Boolean(v["alter"]), V.Boolean(v["drop"])));
    }
    private static Schema ParseSchema(JsonNode? value) {
        var v = Fields(value, "definition", "object", "revision", "next_column", "columns", "primary_key"); Current(V.String(v["definition"]));
        if (v["columns"] is not JsonArray { Count: > 0 and <= 128 } cols || v["primary_key"] is not JsonArray keys || keys.Count > cols.Count) throw V.Incompatible("catalog-schema-bound");
        List<Column> columns = [];
        foreach (var col in cols) {
            var c = Fields(col, "id", "name", "type", "nullable", "default", "max_characters");
            columns.Add(new(Wide(c["id"]), V.String(c["name"]), Logical.TypeFromWire(c["type"]), V.Boolean(c["nullable"]), c["default"] is {} d ? Logical.CellFromWire(d) : null, c["max_characters"] is {} m ? Small(m, 1) : null));
        }
        Schema result = new(Wide(v["object"]), Wide(v["revision"]), Wide(v["next_column"]), columns, keys.Select(Wide).ToArray()); result.Wire(); return result;
    }
    private static MetadataCommitment ParseCommitment(JsonNode? value) {
        var v=Fields(value,"format","length","digest");
        if(V.Number(v["format"],1)!=0x54434d01) throw V.Incompatible("catalog-metadata-format");
        return new(checked((int)V.Number(v["length"],1)),NativeValues.Digest(v["digest"]));
    }
    private static Metadata ParseMetadata(JsonNode? value) {
        var v = Fields(value, "scope", "object", "revision", "name", "schema_fingerprint", "principal", "operation", "admitted_input", "commitment");
        return new(ParseScope(v["scope"]), Wide(v["object"]), Wide(v["revision"]), V.String(v["name"]), new Bytes(V.Unhex(v["schema_fingerprint"], 32)), V.Number(v["principal"]), Wide(v["operation"]), V.Number(v["admitted_input"], 1),ParseCommitment(v["commitment"]));
    }
    private static Head ParseHead(JsonNode? value) { var v = Fields(value, "revision", "rows", "pending"); return new(Wide(v["revision"]), Zero(v["rows"]), Zero(v["pending"])); }
    internal static Definition? Resolved(JsonNode? value, Scope scope, string name) {
        if (value is null) return null;
        var v = Fields(value, "metadata", "head", "schema"); Definition found = new(ParseMetadata(v["metadata"]), ParseHead(v["head"]), ParseSchema(v["schema"]));
        if (found.Metadata.Scope != scope || found.Metadata.Name != name || found.Schema.ObjectId != found.Metadata.ObjectId) throw V.Incompatible("catalog-definition-identity"); return found;
    }
    internal static HistoricalDefinition? Historical(JsonNode? value, Scope scope, ulong objectId, ulong revision) {
        if (value is null) return null;
        var v = Fields(value, "metadata", "schema"); HistoricalDefinition found = new(ParseMetadata(v["metadata"]), ParseSchema(v["schema"]));
        if (found.Metadata.Scope != scope || found.Metadata.ObjectId != objectId || found.Metadata.Revision != revision || found.Schema.ObjectId != objectId) throw V.Incompatible("catalog-historical-identity"); return found;
    }
    private static Cursor? ParseCursor(JsonNode? value) {
        if (value is null) return null; var v = Fields(value, "definition", "scope", "resource_revision", "after_object");
        return new(V.String(v["definition"]), ParseScope(v["scope"]), V.Number(v["resource_revision"]), Wide(v["after_object"]));
    }
    internal static Page ParsePage(JsonNode? value, Scope scope, Cursor? previous) {
        var v = Fields(value, "resource_revision", "entries", "next");
        if (v["entries"] is not JsonArray { Count: 8 } slots) throw V.Incompatible("catalog-page-slots");
        List<Entry> entries = []; bool ended = false;
        foreach (var slot in slots) {
            if (slot is null) ended = true;
            else { var entry = Fields(slot, "metadata", "head"); Entry item = new(ParseMetadata(entry["metadata"]), ParseHead(entry["head"])); if (ended || item.Metadata.Scope != scope) throw V.Incompatible("catalog-page-scope"); entries.Add(item); }
        }
        Page page = new(V.Number(v["resource_revision"]), entries, ParseCursor(v["next"]));
        if (page.Next is not null && page.Next.Scope != scope) throw V.Incompatible("catalog-cursor-scope");
        if (previous is not null && (page.ResourceRevision != previous.ResourceRevision || (entries.Count > 0 && entries[0].Metadata.ObjectId <= previous.AfterObject) || (page.Next is not null && page.Next.AfterObject <= previous.AfterObject))) throw V.Incompatible("catalog-page-continuation");
        return page;
    }
    internal static Intent ParseIntent(JsonNode? value, Connection connection, ulong principal) {
        var v = Fields(value, "reference", "scope", "owner", "principal", "operation", "namespace", "object", "kind"); var r = Fields(v["reference"], "definition", "digest"); var scope = ParseScope(v["scope"]);
        Intent result = new(new(V.String(r["definition"]), new Bytes(V.Unhex(r["digest"], 32))), scope, new ProcessRef(scope.Resource.Realm, V.Number(v["owner"], 1)), V.Number(v["principal"]), new(Wide(v["operation"]), Wide(v["namespace"])), Zero(v["object"]), Variant<Kind>(v["kind"]));
        if (result.Scope != connection.Scope || result.Owner != connection.Owner || result.Principal != principal) throw V.Incompatible("catalog-intent-connection"); return result;
    }
    internal static Compiled ParseCompiled(JsonNode? value, Connection connection, ulong principal, Identity identity, Kind? kind, ulong? objectId) {
        var v = Fields(value, "intent", "saved"); var s = Fields(v["saved"], "definition", "bytes");
        Compiled result = new(ParseIntent(v["intent"], connection, principal), new(V.String(s["definition"]), V.Unhex(s["bytes"], Limit("catalog_intent_bytes"))));
        if (result.Intent.Identity != identity || (kind.HasValue && result.Intent.Kind != kind) || (objectId.HasValue && result.Intent.ObjectId != objectId)) throw V.Incompatible("catalog-compiled-identity"); return result;
    }
    internal static Outcome? ParseOutcome(JsonNode? value) {
        if (value is null) return null;
        var v = Fields(value, "kind", "operation", "object", "actual_object", "phase", "terminal", "counts", "admitted_input", "completed_input", "diagnostic");
        Kind kind = Variant<Kind>(v["kind"]); Phase phase = Variant<Phase>(v["phase"]); bool terminal = V.Boolean(v["terminal"]); Counts? counts = null;
        if (v["counts"] is {} c) { var n = Fields(c, "matched", "changed"); counts = new(Zero(n["matched"]), Zero(n["changed"])); }
        if (terminal != (phase is Phase.Applied or Phase.Unchanged or Phase.Rejected or Phase.Cancelled)) throw V.Incompatible("catalog-terminal");
        if ((counts is not null) != (phase == Phase.Applied && kind is Kind.Insert or Kind.Update or Kind.Delete)) throw V.Incompatible("catalog-counts");
        return new(kind, Wide(v["operation"]), Zero(v["object"]), v["actual_object"] is {} a ? Zero(a) : null, phase, terminal, counts, V.Number(v["admitted_input"], 1), v["completed_input"] is {} p ? V.Number(p, 1) : null, new Diagnostic(V.Object(v["diagnostic"])));
    }
    private static Upload? ParseUpload(JsonNode? value) {
        if (value is null) return null;
        var v = Fields(value, "phase", "received", "total"); uint received = Small(v["received"]), total = Small(v["total"], 1);
        if (received > total || total > Limit("catalog_intent_bytes")) throw V.Incompatible("catalog-upload-bounds"); return new(Variant<UploadPhase>(v["phase"]), received, total);
    }
    private static State ParseState(JsonNode? value) { var v = Fields(value, "outcome", "upload"); return new(ParseOutcome(v["outcome"]), ParseUpload(v["upload"])); }
    private static Disposition? ParseDisposition(JsonNode? value) {
        if (value is null) return null; var v = Fields(value, "input", "outcome", "diagnostic"); return new(V.Number(v["input"], 1), Variant<DispositionOutcome>(v["outcome"]), new Diagnostic(V.Object(v["diagnostic"])));
    }
    private static Prepared ParsePrepared(JsonNode? value) => new(new Bytes(V.Utf8.GetBytes(V.Text(V.String(value), Limit("catalog_prepared_bytes")))));
    private static Next ParseNext(JsonNode? value) {
        var v = V.Object(value); if (v.Count != 1) throw V.Incompatible("catalog-next"); var entry = v.Single();
        switch (entry.Key) {
            case "send": return new(NextKind.Send, ParsePrepared(entry.Value));
            case "terminal": var result = ParseOutcome(entry.Value); if (result is null || !result.Terminal) throw V.Incompatible("catalog-terminal"); return new(NextKind.Terminal, Outcome: result);
            case "running": Fields(entry.Value); return new(NextKind.Running);
            case "upload_cancelled": Fields(entry.Value); return new(NextKind.UploadCancelled);
            default: throw V.Incompatible("catalog-next");
        }
    }
    private static Progress ParseProgress(JsonNode? value) {
        var v = V.Object(value); if (v.Count != 1) throw V.Incompatible("catalog-progress");
        if (v.ContainsKey("pending")) { Fields(v["pending"]); return new(Observation.Pending); }
        var p = Fields(Result(v, "processed"), "disposition", "outcome", "upload"); return new(Observation.Processed, ParseDisposition(p["disposition"]), ParseOutcome(p["outcome"]), ParseUpload(p["upload"]));
    }
    internal static Capabilities ParseCapabilities(JsonNode? value) {
        var v = Fields(value, "version", "definition", "max_columns", "max_rows", "max_sql_bytes", "max_intent_bytes", "max_action_bytes", "max_prepared_bytes", "resident_intents"); Current(V.String(v["definition"]));
        return new(Small(v["version"], 1), ContractDefinition, Small(v["max_columns"], 1), Small(v["max_rows"], 1), Small(v["max_sql_bytes"], 1), Small(v["max_intent_bytes"], 1), Small(v["max_action_bytes"], 1), Small(v["max_prepared_bytes"], 1), Small(v["resident_intents"], 1));
    }
    internal static bool Supported(Capabilities c) => c.Version == 1 && c.MaxColumns == 128 && c.MaxRows == 1024 && c.MaxSqlBytes == 4096 && c.MaxIntentBytes == Limit("catalog_intent_bytes") && c.MaxActionBytes == Limit("catalog_action_bytes") && c.MaxPreparedBytes == Limit("catalog_prepared_bytes") && c.ResidentIntents == 1;
    private static Description ParseDescription(JsonNode? value, Connection connection, ulong principal) {
        var v = Fields(value, "configuration", "policy", "resource_revision"); Description result = new(ParseConfiguration(v["configuration"]), ParsePolicy(v["policy"]), V.Number(v["resource_revision"]));
        if (result.Configuration.Scope != connection.Scope || result.Configuration.Owner != connection.Owner || result.Policy.Scope != connection.Scope || result.Policy.Principal != principal) throw V.Incompatible("catalog-description"); return result;
    }
}

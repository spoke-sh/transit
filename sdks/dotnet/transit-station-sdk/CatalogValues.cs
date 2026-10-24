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
    internal static Scope ParseScope(JsonNode? value) {
        var v = Fields(value, "realm", "resource", "catalog"); return new(new ResourceRef(V.Number(v["realm"], 1), V.Number(v["resource"], 1)), Wide(v["catalog"]));
    }
    private static AuthorityProfile ParseAuthority(JsonNode? value) {
        var v = Fields(value, "database_domain", "schema_domain", "table_domain", "database", "initial_schema", "initial_schema_authority");
        return new(V.Number(v["database_domain"], 1), V.Number(v["schema_domain"], 1), V.Number(v["table_domain"], 1),
            V.Number(v["database"], 1), V.Number(v["initial_schema"], 1), V.Number(v["initial_schema_authority"], 1));
    }
    private static Subject ParseSubject(JsonNode? value) {
        var v = Fields(value, "principal", "login_role", "role", "credential_epoch", "audience", "context");
        return new(V.Number(v["principal"]), V.Number(v["login_role"]), V.Number(v["role"]),
            V.Number(v["credential_epoch"], 1), V.Number(v["audience"], 1), NativeValues.Digest(v["context"]));
    }
    internal static Schema ParseSchema(JsonNode? value) {
        var v = Fields(value, "definition", "object", "revision", "next_column", "columns", "primary_key"); Current(V.String(v["definition"]));
        if (v["columns"] is not JsonArray { Count: > 0 and <= 128 } cols || v["primary_key"] is not JsonArray keys || keys.Count > cols.Count) throw V.Incompatible("catalog-schema-bound");
        List<Column> columns = [];
        foreach (var col in cols) {
            var c = Fields(col, "id", "name", "type", "nullable", "default", "max_characters", "encoding", "collation");
            columns.Add(new(Wide(c["id"]), V.String(c["name"]), Logical.TypeFromWire(c["type"]), V.Boolean(c["nullable"]), c["default"] is {} d ? Logical.CellFromWire(d) : null, c["max_characters"] is {} m ? Small(m, 1) : null, Variant<Encoding>(c["encoding"]), Variant<Collation>(c["collation"])));
        }
        Schema result = new(Wide(v["object"]), Wide(v["revision"]), Wide(v["next_column"]), columns, keys.Select(Wide).ToArray()); result.Wire(); return result;
    }
    private static IReadOnlyList<Assignment> ParseAssignments(JsonNode? value) {
        if (value is not JsonArray { Count: <= 128 } array) throw V.Incompatible("catalog-assignment-bound");
        return array.Select(item => {
            var v = Fields(item, "column", "value"); var cell = V.Object(v["value"]);
            if (cell.ContainsKey("default")) { Fields(Fields(cell, "default")["default"]); return new Assignment(Wide(v["column"]), new Default()); }
            return new Assignment(Wide(v["column"]), Logical.CellFromWire(Fields(cell, "cell")["cell"]));
        }).ToArray();
    }
    private static Predicate ParsePredicate(JsonNode? value) {
        var v = V.Object(value);
        if (v.ContainsKey("atom")) {
            var atom = V.Object(Fields(v, "atom")["atom"]);
            if (atom.ContainsKey("all")) { Fields(Fields(atom, "all")["all"]); return new BooleanPredicate(BooleanOperator.All); }
            if (atom.ContainsKey("state")) {
                var state = Fields(Fields(atom, "state")["state"], "column", "value");
                return new StatePredicate(Wide(state["column"]), Variant<CellState>(state["value"]));
            }
            var compare = Fields(Fields(atom, "compare")["compare"], "column", "op", "value");
            return new Comparison(Wide(compare["column"]), Variant<CompareOperator>(compare["op"]), Logical.AtomFromWire(compare["value"]));
        }
        if (v.Count != 1) throw V.Incompatible("catalog-predicate");
        var entry = v.Single(); Fields(entry.Value);
        var op = Variant<BooleanOperator>(JsonValue.Create(entry.Key));
        if (op == BooleanOperator.All) throw V.Incompatible("catalog-predicate");
        return new BooleanPredicate(op);
    }
    internal static Mutation ParseMutation(JsonNode? value) {
        var v = Fields(value, "action", "predicate"); var action = V.Object(v["action"]);
        IReadOnlyList<Predicate>? predicates = null;
        if (v["predicate"] is {} p) {
            if (p is not JsonArray { Count: <= 64 } array) throw V.Incompatible("catalog-predicate-bound");
            predicates = array.Select(ParsePredicate).ToArray();
        }
        if (action.Count != 1) throw V.Incompatible("catalog-mutation");
        Mutation result;
        if (action.ContainsKey("insert")) {
            if (predicates is not null || action["insert"] is not JsonArray { Count: > 0 and <= 1024 } rows) throw V.Incompatible("catalog-insert-bound");
            result = new Insert(rows.Select(ParseAssignments).ToArray());
        } else if (action.ContainsKey("update")) result = new Update(ParseAssignments(action["update"]), predicates);
        else { Fields(Fields(action, "delete")["delete"]); result = new Delete(predicates); }
        if (!JsonNode.DeepEquals(result.Wire(), value)) throw V.Incompatible("catalog-mutation-canonical");
        return result;
    }
    private static readonly JsonObject CatalogSchemas = V.Object(Contract["schemas"]);
    internal static JsonObject ParseSaved(string data) => V.Object(V.Parse(V.Utf8.GetBytes(V.Text(data, Limit("catalog_action_bytes"))), 96));
    private static void ValidateAction(JsonObject value) => Transit.Client.Internal.Schema.Require(V.Object(CatalogSchemas["CatalogAction"]), value);
    private static void ValidateResponse(JsonObject value) => Transit.Client.Internal.Schema.Require(V.Object(CatalogSchemas["CatalogResult"]), value);
    private static JsonNode? Path(JsonNode? value, string[] fields) { foreach (string field in fields) value = Result(value, field); return value; }
    private static string Tag(JsonObject value) => value.Count == 1 ? value.Single().Key : throw V.Incompatible("catalog-variant");
    private static Bytes DigestHex(JsonNode? value) => Digest(new Bytes(V.Unhex(value, 32)));
    private static Connection ParseConnection(JsonNode? value) {
        var v = Fields(value, "scope", "branch", "audience", "principal", "role"); V.Number(v["principal"]);
        return new(ParseScope(v["scope"]), V.Number(v["audience"], 1), Wide(v["branch"]), v["role"] is {} role ? V.Number(role) : null);
    }
    private static ObjectIdentity ParseObject(JsonNode? value) { var v = V.Object(value); return new(ParseScope(v["scope"]), Wide(v["branch"]), Wide(v["object"])); }
    private static Interpretation ParseInterpretation(JsonNode? value) { var v = V.Object(value); return new(ParseObject(v["object"]), Wide(v["revision"]), DigestHex(v["digest"])); }
    private static Content ParseContent(JsonNode? value) { var v = V.Object(value); return new(Wide(v["bytes"]), DigestHex(v["sha256"])); }
    private static StoredDefinition ParseStored(JsonNode? value) {
        var v = V.Object(value); var interpretation = ParseInterpretation(v["interpretation"]); var content = ParseContent(v["content"]);
        if (!interpretation.Digest.Equals(content.Sha256)) throw V.Incompatible("catalog-definition-content");
        return new(interpretation, content, DigestHex(v["schema_fingerprint"]), V.Boolean(v["retired"]));
    }
    private static Position ParsePosition(JsonNode? value) { var v = V.Object(value); return new(Wide(v["partition"]), Zero(v["next_lsn"])); }
    private static void Owns(Connection c, ObjectIdentity target) { if (c.Scope != target.Scope || c.Branch != target.Branch) throw new ArgumentException("Foreign catalog object"); }
    private static void CheckBinding(JsonObject value, Connection c, ulong principal) {
        Current(V.String(value["definition"])); var identity = V.Object(value["identity"]); Wide(identity["operation"]);
        var target = ParseObject(value["target"]); Owns(c, target); DigestHex(value["intent"]);
        if (ParseScope(identity["scope"]) != c.Scope || V.Number(identity["principal"]) != principal) throw new ArgumentException("Foreign original caller");
        var expected = value["expected_definition"] is {} d ? ParseInterpretation(d) : null;
        if (expected is not null && expected.Object != target) throw new ArgumentException("Foreign expected definition");
        if (value["expected_data"] is {} p) ParsePosition(p);
        if (V.String(value["action"]) == "create" ? expected is not null || value["expected_data"] is not null : expected is null) throw new ArgumentException("Invalid definition expectations");
    }
    private static void CheckAssertion(JsonObject value) {
        Current(V.String(value["definition"])); var c = ParseConnection(value["connection"]);
        V.Number(value["namespace"], 1); Identifier(V.String(value["name"])); Wide(value["operation"]); DigestHex(value["intent"]);
        var expected = value["expected"] is {} d ? ParseInterpretation(d) : null; if (expected is not null) Owns(c, expected.Object);
        if ((V.String(value["action"]) == "create_if_not_exists") != (expected is not null)) throw new ArgumentException("Invalid name assertion");
    }
    internal static Capabilities ParseCapabilities(JsonNode? value) {
        var v = V.Object(value); Current(V.String(v["definition"]));
        Capabilities c = new(Small(v["version"],1), ContractDefinition, Small(v["max_columns"],1), Small(v["max_rows"],1), Small(v["max_sql_bytes"],1), Small(v["max_intent_bytes"],1), Small(v["max_action_bytes"],1), Small(v["metadata_page_entries"],1), Small(v["resident_intents"],1));
        if (c.Version != 1 || c.MaxColumns != 128 || c.MaxRows != 1024 || c.MaxSqlBytes != 4096 || c.MaxIntentBytes != Limit("catalog_intent_bytes") || c.MaxActionBytes != Limit("catalog_action_bytes") || c.MetadataPageEntries != 8 || c.ResidentIntents != 1) throw new TransitException(ErrorKind.UnsupportedCapability,"catalog-capabilities");
        return c;
    }
    private static Description ParseDescription(JsonNode? value, Connection c, ulong principal) {
        var v = V.Object(value); var raw = V.Object(v["configuration"]);
        Configuration config = new(ParseScope(raw["scope"]), Wide(raw["branch"]), Wide(raw["partition"]), V.Number(raw["audience"],1), ParseAuthority(raw["authority"]), Identifier(V.String(raw["database_name"])), Identifier(V.String(raw["initial_schema_name"])));
        var subject = ParseSubject(v["subject"]);
        if (config.Scope != c.Scope || config.Branch != c.Branch || config.Audience != c.Audience || subject.Principal != principal || subject.Audience != c.Audience || c.Role is {} role && role != subject.Role) throw V.Incompatible("catalog-description");
        return new(config, subject, V.Number(v["policy_revision"]));
    }
    private static Namespace ParseNamespace(JsonNode? value) {
        var v = V.Object(value); return new(ParseScope(v["scope"]), V.Number(v["id"],1), V.Number(v["authorization"],1), Identifier(V.String(v["name"])), V.Number(v["revision"],1), V.Boolean(v["retired"]));
    }
    private static Page<T> ParsePage<T>(JsonNode? value, Connection c, ulong principal, JsonObject selection, Cursor? previous, Func<JsonNode?,T> decode, Func<T,ulong> identity) {
        var v = V.Object(value); var position = ParsePosition(v["position"]); List<T> entries = []; bool ended = false; ulong after = previous?.After ?? 0;
        if (v["entries"] is not JsonArray { Count: 8 } slots) throw V.Incompatible("catalog-page-bound");
        foreach (var raw in slots) {
            if (raw is null) { ended = true; continue; } if (ended) throw V.Incompatible("catalog-page-hole");
            var entry = decode(raw); ulong id = identity(entry); if (id <= after) throw V.Incompatible("catalog-page-order"); after = id; entries.Add(entry);
        }
        var next = v["next"] is JsonObject n ? Cursor.Restore(n.ToJsonString(CatalogJson)) : null;
        if (next is not null) {
            next.Check(c, principal, selection);
            if (next.Position != position || next.After < after || next.After <= (previous?.After ?? 0)) throw V.Incompatible("catalog-page-continuation");
        }
        if (previous is not null && previous.Position != position) throw V.Incompatible("catalog-directory-changed");
        return new(position, entries, next, selection.ContainsKey("tables") ? Consistency.Independent : null);
    }
    private static Page<Namespace> ParseNamespaces(JsonNode? value, Connection c, ulong principal, Cursor? cursor) => ParsePage(value, c, principal, V.Obj(("namespaces", V.Obj())), cursor, raw => {
        var found = ParseNamespace(raw); if (found.Scope != c.Scope) throw V.Incompatible("catalog-namespace-scope"); return found;
    }, item => item.Id);
    private static Page<Entry> ParseTables(JsonNode? value, Connection c, ulong principal, ulong schemaNamespace, Cursor? cursor) => ParsePage(value, c, principal, V.Obj(("tables", schemaNamespace)), cursor, raw => {
        var v = V.Object(raw); var interpretation = ParseInterpretation(v["interpretation"]); Owns(c, interpretation.Object); ulong ns = V.Number(v["namespace"],1);
        if (ns != schemaNamespace) throw V.Incompatible("catalog-page-namespace");
        return new Entry(interpretation, ns, Identifier(V.String(v["name"])), ParsePosition(v["position"]), Zero(v["changed_lsn"]));
    }, item => item.Interpretation.Object.ObjectId);
    private static Metadata ParseMetadata(JsonNode? value, Connection c, ulong principal, ulong schemaNamespace, string name) {
        var v = V.Object(value); var basis = Basis.Restore(V.Object(v["binding"]).ToJsonString(CatalogJson)); var schema = ParseSchema(v["schema"]);
        if (basis.Connection != c || basis.Principal != principal || basis.Namespace != schemaNamespace || basis.Name != name || basis.ObjectId != schema.ObjectId) throw V.Incompatible("catalog-lookup-identity");
        return new(basis, V.Number(v["authorization"],1), ParsePosition(v["position"]), Zero(v["changed_lsn"]), Zero(v["row_count"]), schema);
    }
    private static Intent ParseSummary(JsonNode? value, SavedIntent saved, Connection c, ulong principal, Identity? expected) {
        var v = V.Object(value); var id = V.Object(v["id"]); var tagged = V.Object(v["binding"]); Current(V.String(id["definition"])); DigestHex(id["digest"]);
        ulong ns = V.Number(v["namespace"],1); string kind = Tag(tagged); var binding = V.Object(tagged[kind]); ulong operation;
        if (kind == "table") { CheckBinding(binding,c,principal); operation = Wide(V.Object(binding["identity"])["operation"]); }
        else {
            CheckAssertion(binding); operation = Wide(binding["operation"]);
            if (!JsonNode.DeepEquals(binding["connection"],c.Wire(principal)) || V.Number(binding["namespace"],1) != ns) throw V.Incompatible("catalog-name-binding");
        }
        Identity identity = new(operation,ns); if (expected is not null && expected != identity) throw V.Incompatible("catalog-prepared-identity");
        var savedWire = saved.Wire(); if (savedWire[kind] is not JsonObject raw || V.Number(raw["namespace"],1) != ns || kind == "name_assertion" && !JsonNode.DeepEquals(raw,binding)) throw V.Incompatible("catalog-saved-binding");
        return new(id,binding,Variant<WorkKind>(JsonValue.Create(kind)),identity,saved);
    }
    private static ObservationKind ExpectedKind(WorkKind kind, JsonObject binding) => kind == WorkKind.NameAssertion ? ObservationKind.NameAssertion : V.String(binding["action"]) is "insert" or "update" or "delete" ? ObservationKind.Rows : ObservationKind.Ddl;
    private static Observation ParseObservation(JsonNode? value, Reference original) {
        var tagged = V.Object(value); string kind = Tag(tagged); var state = V.Object(tagged[kind]); string tag = Tag(state); var raw = V.Object(state[tag]); var observed = Variant<ObservationKind>(JsonValue.Create(kind));
        if (observed != ExpectedKind(original.Kind,original.Binding())) throw V.Incompatible("catalog-observation-kind");
        if (tag == "not_observed") return new(observed,OperationState.NotObserved,original);
        if (!JsonNode.DeepEquals(raw["binding"],original.Binding())) throw V.Incompatible("catalog-original-binding");
        if (observed == ObservationKind.NameAssertion) return new(observed,Variant<OperationState>(raw["state"]),original,Reason: Variant<Reason>(raw["reason"]),Position: ParsePosition(raw["position"]));
        if (tag == "committed") {
            var stored = ParseStored(raw["resulting"]); var outcome = V.Object(raw["outcome"]); ulong matched = Zero(outcome["matched"]), affected = Zero(outcome["affected"]);
            if (affected > matched || stored.Interpretation.Object != ParseObject(original.Binding()["target"])) throw V.Incompatible("catalog-commit-evidence");
            return new(observed,OperationState.Committed,original,new(stored,ParsePosition(outcome["position"]),matched,affected,Zero(outcome["live_rows"])));
        }
        ParseContent(raw["intent"]); string phase = V.String(raw["phase"]);
        if (tag == "admitted" ? phase is not ("admitted" or "ready" or "settled") : phase != tag) throw V.Incompatible("catalog-operation-phase");
        if (observed == ObservationKind.Rows) { var basis = V.Object(raw["basis"]); ParseInterpretation(basis["interpretation"]); ParsePosition(basis["position"]); Zero(basis["changed_lsn"]); }
        return new(observed,Variant<OperationState>(JsonValue.Create(tag)),original,Phase: Variant<Phase>(raw["phase"]),Reason: Variant<Reason>(raw["reason"]));
    }
    private static Preview ParsePreview(JsonNode? value, Intent intent) {
        var tagged = V.Object(value); string kind = Tag(tagged); var raw = V.Object(tagged[kind]); var observed = Variant<ObservationKind>(JsonValue.Create(kind));
        if (observed != ExpectedKind(intent.Kind,intent.Binding()) || !JsonNode.DeepEquals(raw["binding"],intent.Binding())) throw V.Incompatible("catalog-preview-binding");
        if (observed == ObservationKind.NameAssertion) return new(observed,intent,ParsePosition(raw["position"]), raw["current"] is {} named ? new CurrentName(ParseInterpretation(named)) : null, Matches: V.Boolean(raw["matches"]));
        CurrentBasis? current = null;
        if (raw["current"] is JsonObject v) current = new(ParseStored(v["interpretation"]),ParsePosition(v["position"]),Zero(v["changed_lsn"]),Zero(v["row_count"]));
        bool ddl = observed == ObservationKind.Ddl;
        return new(observed,intent,ParsePosition(raw["directory_position"]),current,Variant<Reason>(raw["reason"]),
            ddl && raw["work"] is {} w ? Variant<EvolutionWork>(w) : null, ddl ? V.Boolean(raw["rebuild_key"]) : null, ddl && raw["schema_fingerprint"] is {} f ? DigestHex(f) : null);
    }
    private static ReadAuthority ParseReadAuthority(JsonNode? value) {
        var v = V.Object(value); ulong database = V.Number(v["database"],1), schema = V.Number(v["schema"],1), table = V.Number(v["table"],1);
        if (database == schema || database == table || schema == table) throw V.Incompatible("catalog-read-authority"); return new(database,schema,table);
    }
    private static SnapshotStatus ParseSnapshotStatus(JsonNode? value, SnapshotOwner owner) {
        var v = V.Object(value); var current = ParseInterpretation(v["current_interpretation"]);
        if (!JsonNode.DeepEquals(v["owner"],owner.Wire()) || current.Object != owner.Object) throw V.Incompatible("catalog-retention-owner");
        var snapshot = v["snapshot"] is JsonObject s ? Snapshot.Restore(s.ToJsonString(CatalogJson)) : null;
        if (snapshot is not null && !snapshot.Owner.Equals(owner)) throw V.Incompatible("catalog-original-snapshot");
        return new(owner,current,ParsePosition(v["current_position"]),V.Boolean(v["retired"]),snapshot,V.Boolean(v["released"]),ParseReadAuthority(v["authority"]));
    }
    private static SnapshotMetadata ParseSnapshotMetadata(JsonNode? value, Snapshot snapshot) {
        var v = V.Object(value); var stored = ParseStored(v["interpretation"]); var schema = ParseSchema(v["schema"]);
        if (!JsonNode.DeepEquals(v["snapshot"],snapshot.Wire()) || stored.Interpretation.Object != snapshot.Owner.Object || schema.ObjectId != snapshot.Owner.Object.ObjectId) throw V.Incompatible("catalog-retained-definition");
        return new(snapshot,stored,ParsePosition(v["accepted"]),Zero(v["changed_lsn"]),Zero(v["row_count"]),schema,ParseReadAuthority(v["authority"]));
    }
}

package io.transit.sdk.station;

import com.google.gson.*;
import io.transit.client.*;
import io.transit.client.internal.Worker;
import static io.transit.client.internal.Values.*;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.util.*;
import java.util.concurrent.CompletableFuture;

/** Explicit v1 callers; shared Zig owns query, authorization and recovery semantics. */
public final class UnifiedQuery {
    private UnifiedQuery() {}
    private static String name(Enum<?> value) { return Objects.requireNonNull(value).name().toLowerCase(Locale.ROOT); }
    private static BigInteger positive(BigInteger v) { u64(v); if(v.signum()==0)throw new IllegalArgumentException("Expected positive query identity/budget"); return v; }
    private static BigInteger wide(JsonElement v) { return NativeValues.wide(v,false); }
    private static String hex(Bytes v) { return HexFormat.of().formatHex(v.copy()); }
    private static Bytes encoded(JsonElement v,int limit) { return new Bytes(unhex(v,limit)); }
    private static List<JsonElement> array(JsonElement v,int limit) {
        if(v==null || !v.isJsonArray() || v.getAsJsonArray().size()>limit)throw incompatible("query-array"); return v.getAsJsonArray().asList();
    }
    private static JsonArray path(List<String> values) { JsonArray a=new JsonArray(); if(values.size()>8)throw new IllegalArgumentException("Query path exceeds eight names"); values.forEach(v -> a.add(text(v,64))); return a; }
    private static JsonObject local(JsonObject action,Path host) {
        try(Worker<Bridge,Void> worker=new Worker<>(() -> Bridge.local(host))) { return Worker.await(worker.submit(b -> b.unifiedCodec(action))); }
    }
    public enum Type { INT64, UINT64, FLOAT64, BOOLEAN, UTF8, BINARY }
    public enum State { MISSING, NULL, TYPE_ERROR, VALUE, CONFLICT }
    public sealed interface Scalar permits Signed, Unsigned, Floating, BooleanValue, Text, Binary {}
    public record Signed(long value) implements Scalar {}
    public record Unsigned(BigInteger value) implements Scalar { public Unsigned { u64(value); } }
    public record Floating(double value) implements Scalar { public Floating { if(!Double.isFinite(value))throw new IllegalArgumentException("Non-finite query scalar"); } }
    public record BooleanValue(boolean value) implements Scalar {}
    public record Text(String value) implements Scalar { public Text { text(value,4096); } }
    public record Binary(Bytes value) implements Scalar { public Binary { Objects.requireNonNull(value); if(value.size()>4096)throw new IllegalArgumentException("Query scalar exceeds 4096 bytes"); } }
    private static JsonObject wire(Scalar scalar) {
        return switch(scalar) {
            case Signed v -> obj("int64",Long.toString(v.value()));
            case Unsigned v -> obj("uint64",v.value().toString());
            case Floating v -> obj("float_bits",HexFormat.of().formatHex(ByteBuffer.allocate(8).order(ByteOrder.LITTLE_ENDIAN).putDouble(v.value()).array()));
            case BooleanValue v -> obj("boolean",v.value());
            case Text v -> obj("utf8",v.value());
            case Binary v -> obj("binary",hex(v.value()));
        };
    }
    private static Scalar scalar(JsonElement value) {
        JsonObject v=object(value); if(v.size()!=1)throw incompatible("query-scalar"); var e=v.entrySet().iterator().next();
        return switch(e.getKey()) {
            case "int64" -> new Signed(NativeValues.signed(e.getValue()));
            case "uint64" -> new Unsigned(wide(e.getValue()));
            case "float_bits" -> { byte[] b=unhex(e.getValue(),8); if(b.length!=8)throw incompatible("query-float"); yield new Floating(ByteBuffer.wrap(b).order(ByteOrder.LITTLE_ENDIAN).getDouble()); }
            case "boolean" -> new BooleanValue(bool(e.getValue())); case "utf8" -> new Text(string(e.getValue()));
            case "binary" -> new Binary(encoded(e.getValue(),4096)); default -> throw incompatible("query-scalar");
        };
    }
    public record Column(String name,Type type) {
        public Column { text(name,64); Objects.requireNonNull(type); }
        JsonObject wire() { return obj("name",name,"type",UnifiedQuery.name(type)); }
        static Column parse(JsonElement value) { JsonObject v=object(value); return new Column(string(v.get("name")),Type.valueOf(string(v.get("type")).toUpperCase(Locale.ROOT))); }
    }
    public record Decoder(Type type,int version) {
        public Decoder(Type type) { this(type,1); }
        public Decoder { Objects.requireNonNull(type); if(version<0 || version>255)throw new IllegalArgumentException("Expected decoder version byte"); }
        JsonObject wire() { return obj("version",version,"type",name(type)); }
    }
    public enum ProjectionMode { SCALAR, TEXT, ELEMENT_COUNTER, ELEMENT_REPLICA }
    public record Projection(Column column,List<String> path,boolean relative,ProjectionMode mode,int textBytes,int textSteps) {
        public Projection(Column column,List<String> path) { this(column,path,false,ProjectionMode.SCALAR,4096,4096); }
        public Projection { Objects.requireNonNull(column); path=List.copyOf(path); UnifiedQuery.path(path); Objects.requireNonNull(mode); if(textBytes<0 || textBytes>65535 || textSteps<0 || textSteps>65535)throw new IllegalArgumentException("Expected projection u16 budgets"); }
        JsonObject wire() { return obj("column",column.wire(),"path",UnifiedQuery.path(path),"relative",relative,"mode",name(mode),"text_bytes",textBytes,"text_steps",textSteps); }
    }
    public sealed interface Source permits KvSource, TableSource, DocumentSource { ResourceRef resource(); }
    public record KvSource(ResourceRef resource,Bytes prefix,Decoder key,Decoder value) implements Source {
        public KvSource { Objects.requireNonNull(resource); Objects.requireNonNull(prefix); Objects.requireNonNull(key); Objects.requireNonNull(value); if(prefix.size()>32)throw new IllegalArgumentException("Query prefix exceeds 32 bytes"); }
    }
    public record TableSource(ResourceRef resource,long id,List<String> names,Type valueType) implements Source {
        public TableSource { Objects.requireNonNull(resource); Objects.requireNonNull(valueType); names=List.copyOf(names); if(id<1 || id>0xffffffffL || names.size()!=2)throw new IllegalArgumentException("Invalid query Table declaration"); names.forEach(v -> text(v,64)); }
    }
    public record DocumentSource(Document.Reference reference,List<Projection> projections,Optional<List<String>> expand) implements Source {
        public DocumentSource { Objects.requireNonNull(reference); projections=List.copyOf(projections); expand=expand.map(List::copyOf); expand.ifPresent(UnifiedQuery::path); if(projections.isEmpty() || projections.size()>8)throw new IllegalArgumentException("Expected 1..8 projections"); }
        @Override public ResourceRef resource() { return reference.resource(); }
    }
    private static JsonObject source(Source source) {
        JsonObject value=switch(source) {
            case KvSource v -> obj("kv",obj("prefix",hex(v.prefix()),"key",v.key().wire(),"value",v.value().wire()));
            case TableSource v -> { JsonArray names=new JsonArray(); v.names().forEach(names::add); yield obj("table",obj("id",v.id(),"names",names,"value_type",name(v.valueType()))); }
            case DocumentSource v -> {
                var r=v.reference(); JsonArray projections=new JsonArray(); v.projections().forEach(p -> projections.add(p.wire()));
                yield obj("document",obj("reference",obj("resource",r.resource().resource(),"document",r.document().toString(),"epoch",r.epoch().toString(),"type_revision",r.typeRevision(),"revision",r.revision().toString()),"change_format",1,"expand",v.expand().map(UnifiedQuery::path).orElse(null),"projections",projections));
            }
        };
        return obj("version",1,"resource",source.resource().resource(),"source",value);
    }
    public sealed interface Predicate permits PredicateAtom, PredicateProgram {}
    public sealed interface PredicateAtom extends Predicate permits All, IsState, Compare {}
    public record All() implements PredicateAtom {}
    public record IsState(int column,State state) implements PredicateAtom { public IsState { columnIndex(column); Objects.requireNonNull(state); } }
    public record Compare(int column,Query.Comparison comparison,Scalar value) implements PredicateAtom { public Compare { columnIndex(column); Objects.requireNonNull(comparison); Objects.requireNonNull(value); } }
    public sealed interface PredicateInstruction permits PredicateAtomInstruction, PredicateOperator {}
    public record PredicateAtomInstruction(PredicateAtom atom) implements PredicateInstruction { public PredicateAtomInstruction { Objects.requireNonNull(atom); } }
    public enum PredicateOperator implements PredicateInstruction, InspectedInstruction { NEGATE, CONJUNCTION, DISJUNCTION }
    public record PredicateProgram(List<PredicateInstruction> instructions) implements Predicate {
        public PredicateProgram { if(instructions.isEmpty() || instructions.size()>64)throw new IllegalArgumentException("Expected 1..64 predicate instructions"); instructions=List.copyOf(instructions); }
    }
    private static JsonObject atomWire(PredicateAtom atom) {
        return switch(atom) { case All ignored -> obj("all",obj()); case IsState v -> obj("state",obj("column",v.column(),"value",name(v.state()))); case Compare v -> obj("compare",obj("column",v.column(),"op",name(v.comparison()),"value",UnifiedQuery.wire(v.value()))); };
    }
    private static JsonObject predicateWire(Predicate predicate) {
        if(predicate instanceof PredicateAtom atom)return atomWire(atom);
        var program=(PredicateProgram)predicate; JsonArray instructions=new JsonArray();
        for(var instruction:program.instructions())instructions.add(switch(instruction) {
            case PredicateAtomInstruction atom -> obj("atom",atomWire(atom.atom()));
            case PredicateOperator operator -> obj(name(operator),obj());
        });
        return obj("program",instructions);
    }
    private static void columnIndex(int n) { if(n<0 || n>=8)throw new IllegalArgumentException("Query column outside 0..7"); }
    public record Plan(List<Integer> projection,Predicate predicate,Query.Aggregate aggregate,Optional<BigInteger> limit,Optional<List<Optional<String>>> outputNames) {
        public Plan { projection=List.copyOf(projection); if(projection.isEmpty() || projection.size()>8)throw new IllegalArgumentException("Expected 1..8 query columns"); projection.forEach(UnifiedQuery::columnIndex); Objects.requireNonNull(predicate); Objects.requireNonNull(aggregate); limit.ifPresent(v -> u64(v));
            outputNames=outputNames.map(List::copyOf); if(outputNames.isPresent()){var names=outputNames.get();if(names.size()!=projection.size())throw new IllegalArgumentException("Output names must match the projection width");names.forEach(n -> n.ifPresent(v -> text(v,32)));} }
        JsonObject wire() {
            JsonArray columns=new JsonArray(); projection.forEach(columns::add);
            JsonArray names=outputNames.map(values -> {JsonArray out=new JsonArray();values.forEach(v -> out.add(v.orElse(null)));return out;}).orElse(null);
            JsonObject p=predicateWire(predicate);
            return obj("version",1,"projection",columns,"output_names",names,"predicate",p,"aggregate",name(aggregate),"limit",limit.map(BigInteger::toString).orElse(null));
        }
    }
    public record Budgets(BigInteger pages,BigInteger segments,BigInteger resultBytes) {
        public Budgets { positive(pages); positive(segments); positive(resultBytes); }
        JsonObject wire() { return obj("pages",pages.toString(),"segments",segments.toString(),"result_bytes",resultBytes.toString()); }
    }
    public record Bundle(Bytes bytes) {
        public Bundle { Objects.requireNonNull(bytes); if(bytes.size()==0 || bytes.size()>16384)throw new IllegalArgumentException("Expected finite query bundle"); }
        public static Bundle prepare(Source source,Plan plan,Budgets budgets) { return prepare(source,plan,budgets,null); }
        public static Bundle prepare(Source source,Plan plan,Budgets budgets,Path host) { return new Bundle(encoded(object(local(obj("prepare",obj("source",UnifiedQuery.source(source),"plan",plan.wire(),"limits",budgets.wire())),host).get("prepared")).get("bytes"),16384)); }
    }
    public record Prepared(Bytes bytes) {
        public Prepared { Objects.requireNonNull(bytes); if(bytes.size()==0 || bytes.size()>8192)throw new IllegalArgumentException("Expected bounded prepared query command"); text(bytes.copy()); }
    }
    public record Cursor(String opaque) { public Cursor { text(opaque,4096); if(opaque.isEmpty())throw new IllegalArgumentException("Empty query cursor"); } }
    public sealed interface Cell permits Missing, Null, TypeError, Value, Conflict {}
    public record Missing() implements Cell {}
    public record Null() implements Cell {}
    public record TypeError(String actualKind) implements Cell { public TypeError { text(actualKind,16); } }
    public record Value(Scalar value) implements Cell { public Value { Objects.requireNonNull(value); } }
    public record Alternative(BigInteger counter,BigInteger replica,Cell value) {
        public Alternative { positive(counter); positive(replica); if(!(value instanceof Null || value instanceof TypeError || value instanceof Value))throw new IllegalArgumentException("Invalid conflict alternative"); }
    }
    public record Conflict(List<Alternative> alternatives) implements Cell { public Conflict { alternatives=List.copyOf(alternatives); if(alternatives.size()<2 || alternatives.size()>8)throw new IllegalArgumentException("Expected 2..8 alternatives"); } }
    private static Cell cell(JsonElement value) {
        JsonObject v=object(value); if(v.size()!=1)throw incompatible("query-cell"); var e=v.entrySet().iterator().next();
        return switch(e.getKey()) {
            case "missing" -> new Missing(); case "null" -> new Null(); case "type_error" -> new TypeError(string(e.getValue())); case "value" -> new Value(scalar(e.getValue()));
            case "conflict" -> new Conflict(array(e.getValue(),8).stream().map(item -> { JsonObject a=object(item); return new Alternative(wide(a.get("counter")),wide(a.get("replica")),cell(a.get("value"))); }).toList());
            default -> throw incompatible("query-cell");
        };
    }
    public static List<List<Cell>> decodeArrow(List<Column> columns,Bytes ipc,int rows) { return decodeArrow(columns,ipc,rows,null); }
    public static List<List<Cell>> decodeArrow(List<Column> columns,Bytes ipc,int rows,Path host) {
        if(rows<0 || rows>8 || columns.isEmpty() || columns.size()>8 || ipc.size()>65536)throw new IllegalArgumentException("Query Arrow bounds exceeded");
        JsonArray schema=new JsonArray(); columns.forEach(v -> schema.add(v.wire()));
        List<List<Cell>> out=array(local(obj("inspect_arrow",obj("columns",schema,"rows",rows,"ipc",hex(ipc))),host).get("rows"),8).stream().map(row -> array(row,8).stream().map(UnifiedQuery::cell).toList()).toList();
        if(out.size()!=rows || out.stream().anyMatch(row -> row.size()!=columns.size()))throw incompatible("query-shape"); return out;
    }
    public record Connection(ProcessRef source,ResourceRef resource,ProcessRef requester,ResourceRef requests) {
        public Connection { Objects.requireNonNull(source); Objects.requireNonNull(resource); Objects.requireNonNull(requester); Objects.requireNonNull(requests); if(source.realm()!=resource.realm() || source.realm()!=requester.realm() || source.realm()!=requests.realm())throw new IllegalArgumentException("Different query realms"); }
        JsonObject wire(Credential identity) { if(identity.realm()!=source.realm())throw new IllegalArgumentException("Different credential realm"); return obj("realm",source.realm(),"principal",identity.principal(),"source",source.pid(),"resource",resource.resource(),"requester",requester.pid(),"requests",requests.resource()); }
    }
    public record Description(long resourceRevision,BigInteger policyRevision,Budgets budgets,Optional<BigInteger> active,int bundleBytes,int segmentBytes,int batchRows) {}
    public enum InspectionOperator { SCAN, FILTER, LIMIT, PROJECT, COUNT, SUM, COUNT_VALUES }
    public sealed interface InspectedPredicate permits InspectedAtom, InspectedProgram {}
    public sealed interface InspectedAtom extends InspectedPredicate permits InspectedAll, InspectedState, InspectedComparison {}
    public record InspectedAll() implements InspectedAtom {}
    public record InspectedState(String column,State state) implements InspectedAtom {}
    public record InspectedComparison(String column,Query.Comparison comparison,Type type) implements InspectedAtom {}
    public sealed interface InspectedInstruction permits InspectedAtomInstruction, PredicateOperator {}
    public record InspectedAtomInstruction(InspectedAtom atom) implements InspectedInstruction { public InspectedAtomInstruction { Objects.requireNonNull(atom); } }
    public record InspectedProgram(List<InspectedInstruction> instructions) implements InspectedPredicate {
        public InspectedProgram { if(instructions.isEmpty() || instructions.size()>64)throw incompatible("inspection-program-size"); instructions=List.copyOf(instructions); }
    }
    private static InspectedAtom inspectedAtom(JsonElement value) {
        JsonObject atom=object(value); if(atom.size()!=1)throw incompatible("inspection-atom");
        var selected=atom.entrySet().iterator().next(); JsonObject data=object(selected.getValue());
        return switch(selected.getKey()) {
            case "all" -> { if(!data.isEmpty())throw incompatible("inspection-atom"); yield new InspectedAll(); }
            case "state" -> new InspectedState(text(string(data.get("column")),32),State.valueOf(string(data.get("value")).toUpperCase(Locale.ROOT)));
            case "compare" -> new InspectedComparison(text(string(data.get("column")),32),Query.Comparison.valueOf(string(data.get("op")).toUpperCase(Locale.ROOT)),Type.valueOf(string(data.get("type")).toUpperCase(Locale.ROOT)));
            default -> throw incompatible("inspection-atom");
        };
    }
    private static InspectedPredicate inspectedPredicate(JsonElement value) {
        JsonObject predicate=object(value); if(predicate.size()!=1)throw incompatible("inspection-predicate");
        if(!predicate.has("program"))return inspectedAtom(predicate);
        List<InspectedInstruction> instructions=new ArrayList<>(); int depth=0;
        for(var v:array(predicate.get("program"),64)) {
            JsonObject instruction=object(v); if(instruction.size()!=1)throw incompatible("inspection-instruction");
            var entry=instruction.entrySet().iterator().next();
            if(entry.getKey().equals("atom")) { instructions.add(new InspectedAtomInstruction(inspectedAtom(entry.getValue()))); depth++; }
            else {
                PredicateOperator operator=switch(entry.getKey()) { case "negate" -> PredicateOperator.NEGATE; case "conjunction" -> PredicateOperator.CONJUNCTION; case "disjunction" -> PredicateOperator.DISJUNCTION; default -> throw incompatible("inspection-operator"); };
                int needed=operator==PredicateOperator.NEGATE?1:2;
                if(!object(entry.getValue()).isEmpty() || depth<needed)throw incompatible("inspection-program-shape");
                depth-=needed-1; instructions.add(operator);
            }
        }
        if(depth!=1)throw incompatible("inspection-program-shape");
        return new InspectedProgram(instructions);
    }
    public sealed interface InspectionDetails permits SourceDescription, TableListing, Explanation {}
    public record SourceDescription(List<Column> columns) implements InspectionDetails {
        public SourceDescription { columns=List.copyOf(columns); }
    }
    public record TableListing(List<String> names) implements InspectionDetails {
        public TableListing { names=List.copyOf(names); }
    }
    public record Explanation(List<InspectionOperator> operators,InspectedPredicate predicate,List<String> projection,
        Optional<BigInteger> limit,Query.Aggregate aggregate,List<Column> columns,Budgets budgets) implements InspectionDetails {
        public Explanation { operators=List.copyOf(operators); projection=List.copyOf(projection); columns=List.copyOf(columns); limit.ifPresent(v->u64(v)); }
    }
    public record Inspection(String name,ResourceRef resource,SourceKind sourceKind,Bytes sourceDigest,Bytes schemaDigest,long resourceRevision,BigInteger policyRevision,InspectionDetails details) {}
    private static List<Column> inspectedColumns(JsonElement value) { return array(value,8).stream().map(Column::parse).toList(); }
    private static List<String> inspectedNames(JsonElement value,int max) { return array(value,max).stream().map(v->text(string(v),32)).toList(); }
    private static Inspection inspection(JsonElement value,ResourceRef resource) {
        JsonObject v=object(value);
        if(number(v.get("version"),1)!=1 || !string(v.get("scope")).equals("configured_source") || number(v.get("resource"),1)!=resource.resource())throw incompatible("inspection-scope");
        JsonObject details=object(v.get("details")); if(details.size()!=1)throw incompatible("inspection-details"); var entry=details.entrySet().iterator().next();
        InspectionDetails parsed=switch(entry.getKey()) {
            case "description" -> new SourceDescription(inspectedColumns(object(entry.getValue()).get("columns")));
            case "tables" -> new TableListing(inspectedNames(entry.getValue(),1));
            case "explanation" -> {
                JsonObject plan=object(entry.getValue()), limits=object(plan.get("budgets"));
                InspectedPredicate p=inspectedPredicate(plan.get("predicate"));
                List<InspectionOperator> operators=array(plan.get("operators"),4).stream().map(o->InspectionOperator.valueOf(string(o).toUpperCase(Locale.ROOT))).toList();
                if(operators.size()<2)throw incompatible("inspection-operators");
                yield new Explanation(operators,p,inspectedNames(plan.get("projection"),8),plan.get("limit").isJsonNull()?Optional.empty():Optional.of(wide(plan.get("limit"))),
                    Query.Aggregate.valueOf(string(plan.get("aggregate")).toUpperCase(Locale.ROOT)),inspectedColumns(plan.get("columns")),new Budgets(wide(limits.get("pages")),wide(limits.get("segments")),wide(limits.get("result_bytes"))));
            }
            default -> throw incompatible("inspection-details");
        };
        return new Inspection(text(string(v.get("name")),32),resource,SourceKind.valueOf(string(v.get("source_kind")).toUpperCase(Locale.ROOT)),NativeValues.digest(v.get("contract")),NativeValues.digest(v.get("schema")),number(v.get("resource_revision"),0),positive(wide(v.get("policy_revision"))),parsed);
    }
    public enum Phase { UPLOADING, SEALED, ADMITTED, COMPLETE, CANCELLED, DENIED, REJECTED, RETIRED }
    public record Status(Phase phase,BigInteger correlation,Bytes reference,Optional<Bytes> manifest,boolean collected) {}
    public enum Observed { PENDING, COMMITTED, REJECTED }
    public record Observation(Observed state,Optional<Bytes> reason) {}
    public enum Control { CANCEL, RETIRE, COLLECT }
    public enum SourceKind { KV, TABLE, DOCUMENT }
    public enum Finished { SOURCE_END, LIMIT }
    public record Manifest(long job,Types.ReadVersion source,ProcessRef requester,BigInteger correlation,BigInteger policyRevision,Bytes request,
        SourceKind kind,ResourceRef resource,long revision,Bytes sourceDigest,Bytes schemaDigest,Bytes planDigest,
        BigInteger pages,BigInteger scanned,BigInteger selected,BigInteger valueCount,BigInteger segments,BigInteger rows,BigInteger byteCount,Optional<Long> sum,Finished finished,Bytes chain) {}
    public record Page(Manifest manifest,List<Column> columns,BigInteger ordinal,int rows,Bytes ipc,Optional<Cursor> next) {
        public Page { columns=List.copyOf(columns); Objects.requireNonNull(ipc); if(rows<0 || rows>8 || ipc.size()>65536)throw incompatible("query-page-bound"); }
        public List<List<Cell>> decode() { return decodeArrow(columns,ipc,rows); }
        public List<List<Cell>> decode(Path host) { return decodeArrow(columns,ipc,rows,host); }
    }
    private static Bytes fixed(JsonElement v,int size) { Bytes out=encoded(v,size); if(out.size()!=size)throw incompatible("query-reference"); return out; }
    private static Manifest manifest(JsonElement value,long realm) {
        JsonObject v=object(value), b=object(v.get("basis"));
        return new Manifest(number(v.get("job"),1),NativeValues.version(v.get("source")),new ProcessRef(realm,number(v.get("requester"),1)),wide(v.get("correlation")),wide(v.get("policy_revision")),fixed(v.get("request"),72),
            SourceKind.valueOf(string(b.get("kind")).toUpperCase(Locale.ROOT)),new ResourceRef(realm,number(b.get("resource"),1)),number(b.get("revision"),0),NativeValues.digest(b.get("contract")),NativeValues.digest(b.get("schema")),NativeValues.digest(v.get("plan")),
            wide(v.get("pages")),wide(v.get("scanned")),wide(v.get("selected")),wide(v.get("value_count")),wide(v.get("segments")),wide(v.get("rows")),wide(v.get("bytes")),v.get("sum").isJsonNull()?Optional.empty():Optional.of(NativeValues.signed(v.get("sum"))),Finished.valueOf(string(v.get("finished")).toUpperCase(Locale.ROOT)),NativeValues.digest(v.get("chain")));
    }
    /** One admitted operation; cancelling a future retains ownership until join. */
    public static final class Client implements AutoCloseable {
        private final Worker<Bridge,Void> worker;
        private final Connection connection;
        private Client(ClientConfig config,Credential identity,Connection connection) {
            connection.wire(identity); this.connection=connection;
            worker=new Worker<>(() -> {
                Bridge b=Bridge.query(config,identity,connection);
                try { JsonObject caps=object(b.unifiedQuery(obj("capabilities",obj()),false).get("capabilities")); if(number(caps.get("version"),1)!=1)throw incompatible("query-version"); for(String kind:List.of("kv","table","document"))if(!bool(caps.get(kind)))throw incompatible("query-source"); return b; }
                catch(RuntimeException | Error error) { b.close(); throw error; }
            });
        }
        public static Client open(ClientConfig config,Credential identity,Connection connection) { return new Client(config,identity,connection); }
        public CompletableFuture<Description> describe(Source source) {
            if(!source.resource().equals(connection.resource()))throw new IllegalArgumentException("Different query resource"); JsonObject action=obj("describe",UnifiedQuery.source(source));
            return worker.submit(b -> { JsonObject v=object(b.unifiedQuery(action,false).get("description")), limits=object(v.get("limits")), caps=object(v.get("capabilities")); return new Description(number(v.get("resource_revision"),0),wide(v.get("policy_revision")),new Budgets(wide(limits.get("pages")),wide(limits.get("segments")),wide(limits.get("result_bytes"))),v.get("active").isJsonNull()?Optional.empty():Optional.of(wide(v.get("active"))),Math.toIntExact(number(caps.get("bundle_bytes"),1)),Math.toIntExact(number(caps.get("segment_bytes"),1)),Math.toIntExact(number(caps.get("batch_rows"),1))); });
        }
        public CompletableFuture<Inspection> inspectSql(Source source,String name,String sql,Budgets budgets) {
            if(!source.resource().equals(connection.resource()))throw new IllegalArgumentException("Different query resource");
            JsonObject action=obj("inspect",obj("scope",obj("source",UnifiedQuery.source(source),"name",text(name,32),"limits",budgets.wire()),"sql",text(sql,4096)));
            return worker.submit(b->inspection(b.unifiedQuery(action,false).get("inspection"),connection.resource()));
        }
        public CompletableFuture<Bundle> compileSql(Source source,String name,String sql,Budgets budgets) {
            return compileSql(source,name,sql,budgets,null);
        }
        /** New owned finite bundle; this operation performs no upload or admission. */
        public CompletableFuture<Bundle> compileSql(Source source,String name,String sql,Budgets budgets,List<Scalar> parameters) {
            if(!source.resource().equals(connection.resource()))throw new IllegalArgumentException("Different query resource");
            JsonElement values=JsonNull.INSTANCE;
            if(parameters!=null) {
                if(parameters.size()>3)throw new IllegalArgumentException("Expected at most three parameter scalars");
                JsonArray bound=new JsonArray();for(Scalar value:parameters)bound.add(wire(Objects.requireNonNull(value)));values=bound;
            }
            JsonObject action=obj("compile",obj("scope",obj("source",UnifiedQuery.source(source),"name",text(name,32),"limits",budgets.wire()),"sql",text(sql,4096),"parameters",values));
            return worker.submit(b -> new Bundle(encoded(object(b.unifiedQuery(action,false).get("compiled")).get("bundle"),16384)));
        }
        public CompletableFuture<Optional<Prepared>> prepareNext(BigInteger namespace,Bundle bundle) {
            JsonObject action=obj("next",obj("namespace",positive(namespace).toString(),"bundle",hex(bundle.bytes())));
            return worker.submit(b -> { JsonElement v=b.unifiedQuery(action,false).get("prepared"); return v.isJsonNull()?Optional.empty():Optional.of(new Prepared(new Bytes(string(v).getBytes(StandardCharsets.UTF_8)))); });
        }
        public CompletableFuture<Prepared> prepareControl(Control control,BigInteger namespace) {
            JsonObject action=obj("prepare",obj(name(control),positive(namespace).toString()));
            return worker.submit(b -> new Prepared(new Bytes(string(b.unifiedQuery(action,false).get("prepared")).getBytes(StandardCharsets.UTF_8))));
        }
        public CompletableFuture<Outcomes.AdmissionReceipt> submit(Prepared prepared) {
            JsonObject action=obj("submit",text(prepared.bytes().copy()));
            return worker.submit(b -> { JsonObject v=b.unifiedQuery(action,true); try { return new Outcomes.AdmissionReceipt(number(object(v.get("receipt")).get("position"),1)); }catch(RuntimeException error) { throw new TransitException(TransitException.Kind.UNKNOWN_OUTCOME,6,null,"query-receipt"); } });
        }
        public CompletableFuture<Observation> observe(long input) {
            JsonObject action=obj("observe",counter(input,1));
            return worker.submit(b -> { JsonObject v=object(b.unifiedQuery(action,false).get("observation")); if(v.has("pending"))return new Observation(Observed.PENDING,Optional.empty()); if(v.has("committed"))return new Observation(Observed.COMMITTED,Optional.empty()); return new Observation(Observed.REJECTED,Optional.of(encoded(v.get("rejected"),256))); });
        }
        public CompletableFuture<Optional<Status>> status(BigInteger namespace) {
            JsonObject action=obj("status",positive(namespace).toString());
            return worker.submit(b -> { JsonElement result=b.unifiedQuery(action,false).get("status"); if(result.isJsonNull())return Optional.empty(); JsonObject v=object(result); return Optional.of(new Status(Phase.valueOf(string(v.get("phase")).toUpperCase(Locale.ROOT)),wide(v.get("correlation")),fixed(v.get("reference"),72),v.get("manifest").isJsonNull()?Optional.empty():Optional.of(fixed(v.get("manifest"),72)),bool(v.get("collected")))); });
        }
        public CompletableFuture<Page> page(BigInteger namespace,Optional<Cursor> cursor) {
            JsonObject action=obj("page",obj("namespace",positive(namespace).toString(),"cursor",cursor.map(Cursor::opaque).orElse(null)));
            return worker.submit(b -> { JsonObject v=object(b.unifiedQuery(action,false).get("page")); return new Page(manifest(v.get("manifest"),connection.source().realm()),array(v.get("columns"),8).stream().map(Column::parse).toList(),wide(v.get("ordinal")),Math.toIntExact(number(v.get("rows"),0)),encoded(v.get("ipc"),65536),v.get("next").isJsonNull()?Optional.empty():Optional.of(new Cursor(string(v.get("next"))))); });
        }
        @Override public void close() { worker.close(); }
    }
}

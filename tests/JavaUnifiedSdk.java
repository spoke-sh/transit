import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.Document;
import io.transit.sdk.station.Bytes;
import io.transit.sdk.station.Query;
import io.transit.sdk.station.UnifiedQuery;
import static io.transit.sdk.station.UnifiedQuery.*;
import java.math.BigInteger;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

public final class JavaUnifiedSdk {
    private JavaUnifiedSdk() {}
    private static final BigInteger MAX=BigInteger.ONE.shiftLeft(64).subtract(BigInteger.ONE);
    private static BigInteger n(long v) { return BigInteger.valueOf(v); }
    private static void check(boolean v) { if(!v)throw new AssertionError("Unified Java assertion failed"); }
    private static String hex(Bytes v) { return HexFormat.of().formatHex(v.copy()); }
    private static JsonObject object(String v) { return new Gson().fromJson(v,JsonObject.class); }
    private static String string(JsonObject v,String key) { return v.get(key).getAsString(); }
    private static JsonObject json(Object... fields) { JsonObject v=new JsonObject(); for(int i=0;i<fields.length;i+=2) { Object a=fields[i+1]; v.add((String)fields[i],a==null?JsonNull.INSTANCE:a instanceof JsonElement j?j:a instanceof Boolean b?new JsonPrimitive(b):a instanceof Number number?new JsonPrimitive(number):new JsonPrimitive((String)a)); } return v; }
    private static <T> T await(CompletableFuture<T> f) {
        try { return f.join(); }catch(CompletionException e) { if(e.getCause() instanceof RuntimeException r)throw r; throw e; }
    }
    private static Document.Reference reference(ResourceRef r,BigInteger document,long epoch,long revision) {
        byte[] bytes=ByteBuffer.allocate(40).order(ByteOrder.LITTLE_ENDIAN).put(new byte[]{'S','D','R','1'}).putLong(r.resource()).putLong(document.longValue()).putLong(epoch).putInt(1).putLong(revision).array();
        return Document.Reference.decode(r.realm(),bytes);
    }
    private static Projection projection(String name,Type type,List<String> path,boolean relative,ProjectionMode mode) { return new Projection(new Column(name,type),path,relative,mode,4096,4096); }
    private static Source source(ResourceRef r,String kind,boolean golden) {
        return switch(kind) {
            case "kv" -> new KvSource(r,new Bytes((golden?"data/":"k").getBytes(StandardCharsets.UTF_8)),new Decoder(Type.BINARY),new Decoder(golden?Type.UINT64:Type.UTF8));
            case "table" -> new TableSource(r,golden?9:1,List.of("id",golden?"label":"value"),Type.UTF8);
            default -> golden?new DocumentSource(reference(r,MAX,3,42),List.of(new Projection(new Column("title",Type.UTF8),List.of("title")),projection("body",Type.UTF8,List.of("body"),false,ProjectionMode.TEXT)),Optional.empty())
                : new DocumentSource(reference(r,n(17),1,13),List.of(projection("value",Type.UTF8,List.of(),true,ProjectionMode.SCALAR),projection("counter",Type.UINT64,List.of(),true,ProjectionMode.ELEMENT_COUNTER),projection("replica",Type.UINT64,List.of(),true,ProjectionMode.ELEMENT_REPLICA),new Projection(new Column("optional",Type.UTF8),List.of("optional"))),Optional.of(List.of("items")));
        };
    }
    private static Bundle bundle(Source source,String kind,boolean golden) { return bundle(source,kind,golden,false); }
    private static Bundle bundle(Source source,String kind,boolean golden,boolean named) {
        return bundle(source,kind,golden,named,false);
    }
    private static Bundle bundle(Source source,String kind,boolean golden,boolean named,boolean compound) {
        boolean doc=kind.equals("document");
        int column=golden?1:doc?0:1;
        var comparison=new Compare(column,Query.Comparison.NE,golden&&kind.equals("kv")?new Unsigned(MAX):new Text("x".repeat(512)));
        Predicate predicate=comparison;
        if(compound){
            check(!golden);String ceiling="東京🙂/"+"x".repeat(doc?64:128)+(doc?"/10":"/39");
            predicate=new PredicateProgram(List.of(atom(comparison),atom(new Compare(column,Query.Comparison.GE,new Text(ceiling))),
                atom(new IsState(column,State.NULL)),PredicateOperator.DISJUNCTION,PredicateOperator.NEGATE,PredicateOperator.CONJUNCTION));
        }
        return Bundle.prepare(source,new Plan(golden?List.of(1,0):doc?List.of(0,1,2,3):List.of(1),predicate,Query.Aggregate.ROWS,golden?Optional.of(MAX):Optional.empty(),named?Optional.of(java.util.stream.IntStream.range(0,golden?2:doc?4:1).mapToObj(i -> i==0?Optional.of("Result"):Optional.<String>empty()).toList()):Optional.empty()),new Budgets(n(1000),n(golden?500:100),n(1048576)));
    }
    private static Bytes read(JsonObject config,String key) throws Exception { return new Bytes(Files.readAllBytes(Path.of(string(config,key)))); }
    private static PredicateAtomInstruction atom(PredicateAtom value) { return new PredicateAtomInstruction(value); }
    private static void booleanCodecs(JsonObject config) throws Exception {
        var fixtures=new Gson().fromJson(Files.readString(Path.of(string(config,"boolean"))),JsonArray.class);
        List<Scalar> values=List.of(new Signed(Long.MIN_VALUE),new Unsigned(MAX),new Floating(-0.0),new BooleanValue(true),new Text("café é 🙂"),new Binary(new Bytes(new byte[]{0,(byte)255,(byte)128})),new Text("x".repeat(512)));
        for(int i=0;i<fixtures.size();i++) {
            var fixture=fixtures.get(i).getAsJsonObject();
            Source source=new KvSource(new ResourceRef(46,7),new Bytes(new byte[0]),new Decoder(Type.values()[fixture.get("type").getAsInt()-1]),new Decoder(Type.UINT64));
            List<PredicateInstruction> instructions=new ArrayList<>();
            if(i<7)instructions.addAll(List.of(atom(new Compare(0,Query.Comparison.EQ,values.get(i))),PredicateOperator.NEGATE,atom(new IsState(0,State.NULL)),PredicateOperator.DISJUNCTION));
            else if(string(fixture,"name").equals("all-and-not-null"))instructions.addAll(List.of(atom(new All()),atom(new IsState(0,State.NULL)),PredicateOperator.NEGATE,PredicateOperator.CONJUNCTION));
            else { instructions.add(atom(new All())); instructions.addAll(Collections.nCopies(63,PredicateOperator.NEGATE)); }
            var program=new PredicateProgram(instructions); instructions.clear();
            var bundle=Bundle.prepare(source,new Plan(List.of(0),program,Query.Aggregate.ROWS,Optional.empty(),Optional.empty()),new Budgets(n(1000),n(500),n(1048576)));
            check(hex(bundle.bytes()).equals(string(fixture,"wire_hex")));
        }
        Source source=new KvSource(new ResourceRef(46,7),new Bytes(new byte[0]),new Decoder(Type.INT64),new Decoder(Type.UINT64));
        List<PredicateInstruction> oversized=new ArrayList<>(); oversized.add(atom(new All())); oversized.addAll(Collections.nCopies(64,PredicateOperator.NEGATE));
        List<List<PredicateInstruction>> invalid=List.of(List.of(),List.of(PredicateOperator.NEGATE),List.of(atom(new All()),atom(new All())),oversized,
            List.of(atom(new IsState(7,State.NULL))),List.of(atom(new Compare(0,Query.Comparison.EQ,new Text("wrong type")))));
        for(var instructions:invalid) {
            boolean rejected=false;
            try { Bundle.prepare(source,new Plan(List.of(0),new PredicateProgram(instructions),Query.Aggregate.ROWS,Optional.empty(),Optional.empty()),new Budgets(n(1),n(1),n(1024))); }
            catch(IllegalArgumentException|TransitException e) { rejected=true; }
            check(rejected);
        }
    }
    private static void codecs(JsonObject config) throws Exception {
        var fixtures=new Gson().fromJson(Files.readString(Path.of(string(config,"bundles"))),JsonArray.class);
        for(int i=0;i<3;i++) { String kind=List.of("kv","table","document").get(i); check(hex(bundle(source(new ResourceRef(46,7),kind,true),kind,true).bytes()).equals(fixtures.get(i).getAsJsonObject().get("wire_hex").getAsString())); check(hex(bundle(source(new ResourceRef(46,7),kind,true),kind,true,true).bytes()).equals(fixtures.get(i).getAsJsonObject().get("named_wire_hex").getAsString()));
            var counted=Bundle.prepare(source(new ResourceRef(46,7),kind,true),new Plan(List.of(1),new All(),Query.Aggregate.COUNT_VALUES,Optional.empty(),Optional.of(List.of(Optional.of("present")))),new Budgets(n(1000),n(500),n(1048576)));
            check(hex(counted.bytes()).equals(fixtures.get(i).getAsJsonObject().get("counted_wire_hex").getAsString())); }
        booleanCodecs(config);
        List<Column> columns=Arrays.stream(Type.values()).map(type -> new Column(type.name().toLowerCase(Locale.ROOT),type)).toList();
        byte[] input=read(config,"arrow").copy(); var rows=UnifiedQuery.decodeArrow(columns,new Bytes(input),5); Arrays.fill(input,(byte)0);
        List<Scalar> expected=List.of(new Signed(Long.MIN_VALUE),new Unsigned(MAX),new Floating(-0.0),new BooleanValue(false),new Text("café é 東京🙂"),new Binary(new Bytes(new byte[]{0,(byte)255,(byte)128})));
        check(rows.size()==5);
        for(int i=0;i<6;i++) {
            check(rows.get(0).get(i) instanceof Missing && rows.get(1).get(i) instanceof Null && ((TypeError)rows.get(2).get(i)).actualKind().equals("map"));
            check(((Value)rows.get(3).get(i)).value().equals(expected.get(i)));
            var alternatives=((Conflict)rows.get(4).get(i)).alternatives(); check(alternatives.size()==2);
            check(alternatives.get(0).counter().equals(MAX) && alternatives.get(0).replica().equals(n(1)) && ((Value)alternatives.get(0).value()).value().equals(expected.get(i)));
            check(alternatives.get(1).counter().equals(MAX) && alternatives.get(1).replica().equals(n(2)) && alternatives.get(1).value() instanceof Null);
        }
        check(Double.doubleToRawLongBits(((Floating)((Value)rows.get(3).get(2)).value()).value())==Long.MIN_VALUE);
        check(UnifiedQuery.decodeArrow(columns,read(config,"empty"),0).isEmpty());
        boolean rejected=false; try { UnifiedQuery.decodeArrow(columns,read(config,"malformed"),5); }catch(TransitException e) { rejected=true; } check(rejected);
        System.out.println("Java installed unified codecs: three sources, nine Boolean bundles, six types, five states, immutable values and malformed rejection passed");
    }
    private static String name(Enum<?> v) { return v.name().toLowerCase(Locale.ROOT); }
    private static JsonArray columns(List<Column> values) { JsonArray a=new JsonArray(); values.forEach(v->a.add(json("name",v.name(),"type",name(v.type())))); return a; }
    private static JsonArray names(List<String> values) { JsonArray a=new JsonArray(); values.forEach(a::add); return a; }
    private static JsonArray digest(Bytes bytes) { JsonArray a=new JsonArray(); for(byte b:bytes.copy())a.add(Byte.toUnsignedInt(b)); return a; }
    private static JsonObject inspectedPredicate(InspectedPredicate value) {
        return switch(value) {
            case InspectedAll ignored -> json("all",json());
            case InspectedState p -> json("state",json("column",p.column(),"value",name(p.state())));
            case InspectedComparison p -> json("compare",json("column",p.column(),"op",name(p.comparison()),"type",name(p.type())));
            case InspectedProgram p -> {
                JsonArray instructions=new JsonArray();
                for(var instruction:p.instructions())instructions.add(switch(instruction) {
                    case InspectedAtomInstruction a -> json("atom",inspectedPredicate(a.atom()));
                    case PredicateOperator op -> json(name(op),json());
                });
                yield json("program",instructions);
            }
        };
    }
    private static JsonObject inspection(Inspection value) {
        JsonObject details=switch(value.details()) {
            case SourceDescription d -> json("description",json("columns",columns(d.columns())));
            case TableListing d -> json("tables",names(d.names()));
            case Explanation d -> {
                JsonObject predicate=inspectedPredicate(d.predicate());
                yield json("explanation",json("operators",names(d.operators().stream().map(JavaUnifiedSdk::name).toList()),"predicate",predicate,"projection",names(d.projection()),
                    "limit",d.limit().map(BigInteger::toString).orElse(null),"aggregate",name(d.aggregate()),"columns",columns(d.columns()),
                    "budgets",json("pages",d.budgets().pages().toString(),"segments",d.budgets().segments().toString(),"result_bytes",d.budgets().resultBytes().toString())));
            }
        };
        return json("inspection",json("version",1,"scope","configured_source","name",value.name(),"resource",value.resource().resource(),"source_kind",name(value.sourceKind()),
            "contract",digest(value.sourceDigest()),"schema",digest(value.schemaDigest()),"resource_revision",value.resourceRevision(),"policy_revision",value.policyRevision().toString(),"details",details));
    }
    private static void serve(JsonObject config) throws Exception {
        var c=config.getAsJsonObject("connection"); long realm=c.get("realm").getAsLong(); ResourceRef resource=new ResourceRef(realm,c.get("resource").getAsLong());
        var connection=new Connection(new ProcessRef(realm,c.get("source").getAsLong()),resource,new ProcessRef(realm,c.get("requester").getAsLong()),new ResourceRef(realm,c.get("requests").getAsLong()));
        String kind=string(config,"kind"); Source source=source(resource,kind,false); check(bundle(source,kind,false,true,config.get("compound").getAsBoolean()).bytes().equals(read(config,"bundle")));
        Page saved=null;
        try(var client=UnifiedQuery.Client.open(new ClientConfig(java.net.URI.create(string(config,"url")),ClientConfig.Profile.NATIVE_V1,10000,null),new Credential(realm,c.get("principal").getAsLong(),Path.of(string(config,"seed_file"))),connection)) {
            var description=await(client.describe(source)); check(description.bundleBytes()==16384 && description.batchRows()==8);
            System.out.println("{\"ready\":true}");
            try(var reader=new java.io.BufferedReader(new java.io.InputStreamReader(System.in,StandardCharsets.UTF_8))) {
                for(String line;(line=reader.readLine())!=null;) {
                    JsonObject action=object(line); if(action.has("close"))break;
                    try {
                        JsonObject result;
                        if(action.has("compile")) {
                            var request=action.getAsJsonObject("compile"); var scope=request.getAsJsonObject("scope"); var limits=scope.getAsJsonObject("limits");
                            List<Scalar> parameters=null;
                            if(request.has("parameters")&&!request.get("parameters").isJsonNull()) {
                                parameters=new ArrayList<>();
                                for(var item:request.getAsJsonArray("parameters")) {
                                    var entry=item.getAsJsonObject().entrySet().iterator().next(); var v=entry.getValue();
                                    parameters.add(switch(entry.getKey()) {
                                        case "int64" -> new Signed(Long.parseLong(v.getAsString()));
                                        case "uint64" -> new Unsigned(new BigInteger(v.getAsString()));
                                        case "float_bits" -> new Floating(ByteBuffer.wrap(HexFormat.of().parseHex(v.getAsString())).order(ByteOrder.LITTLE_ENDIAN).getDouble());
                                        case "boolean" -> new BooleanValue(v.getAsBoolean());
                                        case "utf8" -> new Text(v.getAsString());
                                        case "binary" -> new Binary(new Bytes(HexFormat.of().parseHex(v.getAsString())));
                                        default -> throw new AssertionError("Unknown parameter type");
                                    });
                                }
                            }
                            var pending=client.compileSql(source,string(scope,"name"),string(request,"sql"),new Budgets(new BigInteger(string(limits,"pages")),new BigInteger(string(limits,"segments")),new BigInteger(string(limits,"result_bytes"))),parameters);
                            if(parameters!=null)parameters.clear();
                            var compiled=await(pending);
                            result=json("compiled",json("bundle",hex(compiled.bytes())));
                        } else if(action.has("inspect")) {
                            var request=action.getAsJsonObject("inspect"); var scope=request.getAsJsonObject("scope"); var limits=scope.getAsJsonObject("limits");
                            var value=await(client.inspectSql(source,string(scope,"name"),string(request,"sql"),new Budgets(new BigInteger(string(limits,"pages")),new BigInteger(string(limits,"segments")),new BigInteger(string(limits,"result_bytes")))));
                            check(value.resource().equals(resource) && name(value.sourceKind()).equals(kind)); result=inspection(value);
                        }
                        else if(action.has("next")) { var v=action.getAsJsonObject("next"); var p=await(client.prepareNext(new BigInteger(string(v,"namespace")),new Bundle(new Bytes(HexFormat.of().parseHex(string(v,"bundle")))))); result=json("prepared",p.map(item -> new String(item.bytes().copy(),StandardCharsets.UTF_8)).orElse(null)); }
                        else if(action.has("submit")) {
                            var prepared=new Prepared(new Bytes(string(action,"submit").getBytes(StandardCharsets.UTF_8))); Bytes before=prepared.bytes();
                            try { result=json("receipt",json("position",await(client.submit(prepared)).position())); }catch(TransitException e) { check(prepared.bytes().equals(before)); throw e; }
                        }else if(action.has("observe")) { var v=await(client.observe(action.get("observe").getAsLong())); result=json("observation",json(v.state().name().toLowerCase(Locale.ROOT),v.reason().isEmpty()?json():hex(v.reason().orElseThrow()))); }
                        else if(action.has("status")) { var v=await(client.status(new BigInteger(string(action,"status")))); result=json("status",v.map(item -> json("phase",item.phase().name().toLowerCase(Locale.ROOT),"correlation",item.correlation().toString())).orElse(null)); }
                        else {
                            var v=action.getAsJsonObject("page"); Page page=await(client.page(new BigInteger(string(v,"namespace")),!v.has("cursor")||v.get("cursor").isJsonNull()?Optional.empty():Optional.of(new Cursor(string(v,"cursor")))));
                            check(page.manifest().resource().equals(resource) && page.manifest().kind().name().equalsIgnoreCase(kind)); check(page.decode().size()==page.rows()); saved=page;
                            result=json("page",json("ordinal",page.ordinal().toString(),"ipc",hex(page.ipc()),"manifest",json("segments",page.manifest().segments().toString(),"selected",page.manifest().selected().toString(),"value_count",page.manifest().valueCount().toString()),"next",page.next().map(Cursor::opaque).orElse(null)));
                        }
                        System.out.println(json("status",0,"value",result));
                    }catch(TransitException e) { check(e.status()>=0); System.out.println(json("status",e.status(),"value",json("err",e.code()))); }
                }
            }
        }
        if(saved!=null)check(saved.decode().size()==saved.rows());
        System.out.println("{\"closed\":true}");
    }
    public static void main(String[] args) throws Exception { JsonObject config=object(Files.readString(Path.of(args[1]))); if(args[0].equals("codecs"))codecs(config);else serve(config); }
}

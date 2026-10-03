import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.Bytes;
import io.transit.sdk.station.Catalog;
import static io.transit.sdk.station.Catalog.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Installed public Java catalog consumer; saved commands remain opaque. */
public final class JavaCatalogSdk {
    private JavaCatalogSdk() {}
    private static JsonObject json(Object... pairs) {
        JsonObject out=new JsonObject();for(int i=0;i<pairs.length;i+=2){Object v=pairs[i+1];out.add((String)pairs[i],v==null?JsonNull.INSTANCE:v instanceof JsonElement j?j:v instanceof Number n?new JsonPrimitive(n):v instanceof Boolean b?new JsonPrimitive(b):new JsonPrimitive((String)v));}return out;
    }
    private static String text(JsonObject v,String key) { return v.get(key).getAsString(); }
    private static BigInteger wide(JsonObject v,String key) { return new BigInteger(text(v,key)); }
    private static String tag(Enum<?> v) { return v.name().toLowerCase(Locale.ROOT); }
    private static <T> T await(CompletableFuture<T> value) {
        try{return value.join();}catch(CompletionException e){if(e.getCause() instanceof RuntimeException r)throw r;throw e;}
    }
    private static Scope scope(JsonObject v) { return new Scope(new ResourceRef(v.get("realm").getAsLong(),v.get("resource").getAsLong()),wide(v,"catalog")); }
    private static JsonObject json(Scope v) { return json("realm",v.resource().realm(),"resource",v.resource().resource(),"catalog",v.catalog().toString()); }
    private static Configuration configuration(JsonObject v) { Scope s=scope(v.getAsJsonObject("scope"));return new Configuration(s,new ProcessRef(s.resource().realm(),v.get("owner").getAsLong()),v.get("administrator").getAsLong()); }
    private static JsonObject json(Configuration v) { return json("scope",json(v.scope()),"owner",v.owner().pid(),"administrator",v.administrator()); }
    private static Policy policy(JsonObject v) { return new Policy(scope(v.getAsJsonObject("scope")),v.get("principal").getAsLong(),wide(v,"revision"),v.get("inspect").getAsBoolean(),v.get("create").getAsBoolean()); }
    private static JsonObject json(Policy v) { return json("scope",json(v.scope()),"principal",v.principal(),"revision",v.revision().toString(),"inspect",v.inspect(),"create",v.create()); }
    private static CreateTable request(JsonObject v) {
        JsonObject schema=v.getAsJsonObject("schema");return new CreateTable(scope(v.getAsJsonObject("scope")),wide(v,"operation"),wide(v,"object"),v.get("table").getAsLong(),text(v,"name"),new Schema(schema.getAsJsonArray("names").asList().stream().map(JsonElement::getAsString).toList(),Type.valueOf(text(schema,"value_type").toUpperCase(Locale.ROOT))));
    }
    private static JsonObject json(CreateTable v) {
        JsonArray names=new JsonArray();v.schema().names().forEach(names::add);return json("scope",json(v.scope()),"operation",v.operation().toString(),"object",v.object().toString(),"table",v.table(),"name",v.name(),"schema",json("names",names,"value_type",tag(v.schema().valueType())));
    }
    private static Cursor cursor(JsonObject v) { return new Cursor(text(v,"definition"),scope(v.getAsJsonObject("scope")),v.get("resource_revision").getAsLong(),text(v,"after")); }
    private static JsonObject json(Cursor v) { return json("definition",v.definition(),"scope",json(v.scope()),"resource_revision",v.resourceRevision(),"after",v.after()); }
    private static JsonObject json(Definition v) {
        JsonArray names=new JsonArray();v.source().schema().names().forEach(names::add);
        return json("scope",json(v.scope()),"object",v.object().toString(),"revision",v.revision().toString(),"name",v.name(),"source",json("table",json("id",v.source().table(),"schema",json("names",names,"value_type",tag(v.source().schema().valueType())))),"principal",v.principal(),"operation",v.operation().toString(),"input",v.input());
    }
    private static JsonObject json(Page v) {
        JsonArray entries=new JsonArray();v.entries().forEach(item -> entries.add(json(item)));while(entries.size()<8)entries.add(JsonNull.INSTANCE);
        return json("resource_revision",v.resourceRevision(),"entries",entries,"next",v.next().map(JavaCatalogSdk::json).orElse(null));
    }
    private static Prepared prepared(String text) { return new Prepared(new Bytes(text.getBytes(StandardCharsets.UTF_8))); }
    private static String saved(Prepared v) { return new String(v.bytes().copy(),StandardCharsets.UTF_8); }
    private static JsonObject call(Catalog.Client client,JsonObject action) {
        String name=action.keySet().iterator().next();JsonElement value=action.get(name);
        return switch(name) {
            case "capabilities" -> {var v=await(client.capabilities());yield json("capabilities",json("version",v.version(),"definition",v.definition(),"initialize",v.initialize(),"create_table",v.createTable(),"conditional_policy",v.conditionalPolicy(),"current_metadata",v.currentMetadata(),"max_saved_bytes",v.maxSavedBytes(),"table_columns",v.tableColumns()));}
            case "describe" -> {var v=await(client.describe());yield json("description",json("configuration",json(v.configuration()),"policy",json(v.policy()),"resource_revision",v.resourceRevision()));}
            case "lookup" -> json("definition",await(client.lookup(value.getAsString())).map(JavaCatalogSdk::json).orElse(null));
            case "definition" -> {var v=value.getAsJsonObject();yield json("definition",await(client.definition(wide(v,"object"),wide(v,"revision"))).map(JavaCatalogSdk::json).orElse(null));}
            case "list" -> json("page",json(await(client.list(value.isJsonNull()?Optional.empty():Optional.of(cursor(value.getAsJsonObject()))))));
            case "compile" -> {var v=value.getAsJsonObject();var r=await(client.compileSql(text(v,"sql"),wide(v,"operation"),wide(v,"object"),v.get("table").getAsLong()));yield json("compiled",json("request",json(r.request()),"canonical",HexFormat.of().formatHex(r.canonical().copy())));}
            case "prepare_initialize" -> json("prepared",saved(await(client.prepareInitialize(configuration(value.getAsJsonObject())))));
            case "prepare_create" -> json("prepared",saved(await(client.prepareCreate(request(value.getAsJsonObject())))));
            case "prepare_policy" -> {var v=value.getAsJsonObject();yield json("prepared",saved(await(client.preparePolicy(new PolicyChange(wide(v,"expected_revision"),policy(v.getAsJsonObject("policy")))))));}
            case "submit" -> {String original=value.getAsString();var p=prepared(original);try{yield json("receipt",json("position",await(client.submit(p)).position()));}finally{if(!saved(p).equals(original))throw new AssertionError("Changed recovery bytes");}}
            case "observe" -> {var v=value.getAsJsonObject();yield json("observation",tag(await(client.observe(prepared(text(v,"prepared")),v.get("input").getAsLong()))));}
            case "input_disposition" -> {var v=value.getAsJsonObject();yield json("disposition",await(client.inputDisposition(prepared(text(v,"prepared")),v.get("input").getAsLong())).map(r -> json("scope",json(r.scope()),"origin",tag(r.origin()),"principal",r.principal(),"input",r.input(),"payload",HexFormat.of().formatHex(r.payload().copy()),"outcome",tag(r.outcome()))).orElse(null));}
            case "status" -> json("status",await(client.status(request(value.getAsJsonObject()))).map(r -> json("request",json(r.request()),"principal",r.principal(),"input",r.input(),"outcome",tag(r.outcome()))).orElse(null));
            default -> throw new AssertionError("Unknown catalog action");
        };
    }
    public static void main(String[] args) throws Exception {
        JsonObject cfg=new Gson().fromJson(Files.readString(Path.of(args[0])),JsonObject.class);var c=cfg.getAsJsonObject("connection");var s=scope(c.getAsJsonObject("scope"));
        var connection=new Connection(new ProcessRef(s.resource().realm(),c.get("owner").getAsLong()),s);
        try(var client=Catalog.Client.open(new ClientConfig(java.net.URI.create(text(cfg,"url")),ClientConfig.Profile.NATIVE_V1,10000,null),new Credential(s.resource().realm(),c.get("principal").getAsLong(),Path.of(text(cfg,"seed_file"))),connection)) {
            System.out.println("{\"ready\":true}");var reader=new java.io.BufferedReader(new java.io.InputStreamReader(System.in,StandardCharsets.UTF_8));
            for(String line;(line=reader.readLine())!=null;) {
                JsonObject action=new Gson().fromJson(line,JsonObject.class);if(action.has("close"))break;
                try{System.out.println(json("status",0,"value",call(client,action)));}
                catch(TransitException e){System.out.println(json("status",e.status()>=0?e.status():e.kind()==TransitException.Kind.UNKNOWN_OUTCOME?6:1,"value",json("err",e.code(),"diagnostic",e.diagnostic(),"diagnostic_invalid",e.diagnosticInvalid())));}
            }
        }
        System.out.println("{\"closed\":true}");
    }
}

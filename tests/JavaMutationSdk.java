import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.Bytes;
import io.transit.sdk.station.Mutations;
import static io.transit.sdk.station.Mutations.*;
import java.math.BigInteger;
import java.nio.charset.StandardCharsets;
import java.nio.file.*;
import java.util.*;
import java.util.concurrent.*;

/** Installed public Java consumer; test framing does not interpret saved commands. */
public final class JavaMutationSdk {
    private JavaMutationSdk() {}
    private static void check(boolean value) { if(!value)throw new AssertionError("Mutation caller assertion failed"); }
    private static String text(JsonObject v,String key) { return v.get(key).getAsString(); }
    private static JsonObject json(Object... fields) {
        JsonObject out=new JsonObject();for(int i=0;i<fields.length;i+=2){Object v=fields[i+1];out.add((String)fields[i],v==null?JsonNull.INSTANCE:v instanceof JsonElement j?j:v instanceof Number n?new JsonPrimitive(n):v instanceof Boolean b?new JsonPrimitive(b):new JsonPrimitive((String)v));}return out;
    }
    private static <T> T await(CompletableFuture<T> future) {
        try { return future.join(); }catch(CompletionException error){if(error.getCause() instanceof RuntimeException cause)throw cause;throw error;}
    }
    private static String tag(Enum<?> v) { return v.name().toLowerCase(Locale.ROOT); }
    private static String hex(Bytes v) { return HexFormat.of().formatHex(v.copy()); }
    private static Bytes unhex(String value) { return new Bytes(HexFormat.of().parseHex(value)); }
    private static Reference reference(String value) { return new Reference(unhex(value)); }
    private static Prepared prepared(String value) { return new Prepared(new Bytes(value.getBytes(StandardCharsets.UTF_8))); }
    private static String saved(Prepared value) { return new String(value.bytes().copy(),StandardCharsets.UTF_8); }
    private static JsonObject call(Mutations.Client client,JsonObject action) {
        if(action.has("capabilities"))return json("capabilities",json("max_rows",3));
        if(action.has("describe")) {
            var v=await(client.describe());JsonArray names=new JsonArray();v.names().forEach(names::add);
            try {v.names().add("changed");throw new AssertionError("Mutable names");}catch(UnsupportedOperationException expected) { }
            return json("description",json("resource",v.resource().resource(),"table",v.table(),"names",names,"value_type",tag(v.valueType()),"resource_revision",v.resourceRevision(),"policy_revision",Long.toString(v.policyRevision()),"declaration",hex(v.declaration()),"permissions",v.permissions().stream().mapToInt(Permission::bit).sum(),"active",v.active().map(BigInteger::toString).orElse(null)));
        }
        if(action.has("compile")) {
            var v=action.getAsJsonObject("compile");var compiled=await(client.compileSql(text(v,"name"),text(v,"sql"),new BigInteger(text(v,"namespace"))));
            return json("compiled",json("request",hex(compiled.request()),"reference",hex(compiled.reference().bytes())));
        }
        if(action.has("next")) {
            var v=action.getAsJsonObject("next");byte[] input=HexFormat.of().parseHex(text(v,"request"));var compiled=new Compiled(new Bytes(input),reference(text(v,"reference")));
            Arrays.fill(input,(byte)0);var exposed=compiled.request().copy();Arrays.fill(exposed,(byte)0);check(hex(compiled.request()).equals(text(v,"request")));
            var next=await(client.prepareNext(compiled));return json("prepared",next.map(JavaMutationSdk::saved).orElse(null));
        }
        if(action.has("prepare")) {
            var v=action.getAsJsonObject("prepare").entrySet().iterator().next();return json("prepared",saved(await(client.prepareControl(Control.valueOf(v.getKey().toUpperCase(Locale.ROOT)),reference(v.getValue().getAsString())))));
        }
        if(action.has("submit")) {
            String original=text(action,"submit");var p=prepared(original);
            try {return json("receipt",json("position",await(client.submit(p)).position()));}
            finally {check(saved(p).equals(original));}
        }
        if(action.has("observe")) {
            var v=action.getAsJsonObject("observe");return json("observation",tag(await(client.observe(prepared(text(v,"prepared")),v.get("input").getAsLong()))));
        }
        if(action.has("rejection")) {
            var v=action.getAsJsonObject("rejection");return json("rejection",await(client.rejection(prepared(text(v,"prepared")),v.get("input").getAsLong())).map(JavaMutationSdk::tag).orElse(null));
        }
        check(action.has("status"));return json("status",await(client.status(reference(text(action,"status")))).map(v -> json("reference",hex(v.reference().bytes()),"principal",v.principal(),"table",v.table(),"declaration",hex(v.declaration()),"policy_revision",Long.toString(v.policyRevision()),"phase",tag(v.phase()),"affected_rows",v.affectedRows(),"reason",tag(v.reason()),"input",v.input(),"conflict",v.conflict().map(c -> json("key",Long.toString(c.key()),"row",c.row())).orElse(null))).orElse(null));
    }
    public static void main(String[] args) throws Exception {
        JsonObject config=new Gson().fromJson(Files.readString(Path.of(args[0])),JsonObject.class);var c=config.getAsJsonObject("connection");long realm=c.get("realm").getAsLong();
        var connection=new Connection(new ProcessRef(realm,c.get("writer").getAsLong()),new ResourceRef(realm,c.get("resource").getAsLong()),c.get("table").getAsLong());
        try(var client=Mutations.Client.open(new ClientConfig(java.net.URI.create(text(config,"url")),ClientConfig.Profile.NATIVE_V1,10000,null),new Credential(realm,c.get("principal").getAsLong(),Path.of(text(config,"seed_file"))),connection)) {
            System.out.println("{\"ready\":true}");
            var reader=new java.io.BufferedReader(new java.io.InputStreamReader(System.in,StandardCharsets.UTF_8));
            for(String line;(line=reader.readLine())!=null;) {
                JsonObject action=new Gson().fromJson(line,JsonObject.class);if(action.has("close"))break;
                try {System.out.println(json("status",0,"value",call(client,action)));}
                catch(TransitException error){System.out.println(json("status",error.status()>=0?error.status():error.kind()==TransitException.Kind.UNKNOWN_OUTCOME?6:1,"value",json("err",error.code())));}
            }
        }
        System.out.println("{\"closed\":true}");
    }
}

import com.google.gson.*;
import io.transit.client.*;
import io.transit.sdk.station.*;
import static io.transit.sdk.station.UnifiedQuery.*;
import java.math.BigInteger;
import java.net.URI;
import java.nio.file.*;
import java.nio.file.attribute.PosixFilePermissions;
import java.util.*;

/** Installed public caller against the direct owner's fault/restart schedule. */
public final class JavaDirectCapture {
    private JavaDirectCapture() {}
    private static void check(boolean value) { if(!value)throw new AssertionError("Direct capture mismatch"); }
    private static BigInteger wide(JsonObject value,String key) { return new BigInteger(value.get(key).getAsString()); }
    public static void main(String[] args) throws Exception {
        var profilePath=Path.of(args[1]); String phase=args[2];
        var profile=new Gson().fromJson(Files.readString(profilePath),JsonObject.class).getAsJsonObject("captured");
        var route=profile.getAsJsonObject("connection"); long realm=route.get("realm").getAsLong();
        var declaration=profile.getAsJsonObject("declaration").getAsJsonObject("source").getAsJsonObject("table");
        var scopeValue=declaration.getAsJsonObject("scope");
        var resource=new ResourceRef(realm,scopeValue.get("resource").getAsLong());
        var scope=new Catalog.Scope(resource,wide(scopeValue,"catalog"));
        var connection=new Connection(new ProcessRef(realm,route.get("source").getAsLong()),new ResourceRef(realm,route.get("resource").getAsLong()),
            new ProcessRef(realm,route.get("requester").getAsLong()),new ResourceRef(realm,route.get("requests").getAsLong()),Optional.empty());
        check(!resource.equals(connection.resource()));
        var seed=profilePath.resolveSibling("java-capture.seed");
        Files.writeString(seed,(phase.equals("prepare")?"1d":"3b").repeat(32));
        Files.setPosixFilePermissions(seed,PosixFilePermissions.fromString("rw-------"));
        var identity=new Credential(realm,route.get("principal").getAsLong(),seed);
        var config=new ClientConfig(URI.create(args[0]),ClientConfig.Profile.NATIVE_V1,10000,null);
        var tables=new Tables(args[0],scope,wide(declaration,"branch"),declaration.get("owner").getAsLong());
        var bundle=new Bundle(new Bytes(Base64.getDecoder().decode(profile.getAsJsonObject("bundle").get("base64").getAsString())));
        try(var client=UnifiedQuery.Client.open(config,identity,connection,tables)) {
            if(phase.equals("prepare")) {
                check(client.lookupTable(1,"missing_capture_input").join().isEmpty());
                var definition=client.lookupTable(1,"captured_input").join().orElseThrow();
                var saved=profile.getAsJsonObject("capture"); var expected=saved.getAsJsonObject("expected");
                check(definition.partition().equals(wide(expected,"partition")) && definition.nextLsn().equals(wide(expected,"next_lsn")));
                var compiled=client.compileSql(definition.source(),"captured_input","SELECT COUNT(*) AS n FROM captured_input",new Budgets(BigInteger.valueOf(64),BigInteger.valueOf(64),BigInteger.valueOf(1048576))).join();
                check(client.authorizeBundle(compiled,definition.capture(saved.get("executor").getAsLong(),wide(saved,"operation"))).join().equals(bundle));
            } else {
                check(client.lookupTable(1,"captured_input").join().isEmpty());
                var definition=client.lookupTable(1,"captured_renamed").join().orElseThrow();
                check(definition.source().interpretation().revision().equals(BigInteger.TWO) && definition.source().schema().revision().equals(BigInteger.ONE));
                var page=client.page(BigInteger.ONE,Optional.empty()).join(); var manifest=page.manifest();
                check(page.next().isEmpty() && page.rows()==1 && manifest.resource().equals(resource));
                check(manifest.source().equals(new TableRetention(connection.source())) && manifest.cut() instanceof TableCut);
                check(manifest.pages().equals(BigInteger.valueOf(3)) && manifest.scanned().equals(BigInteger.valueOf(19)));
                var rows=page.decode(); check(rows.size()==1 && rows.getFirst().getFirst().equals(new Logical.Present(new Logical.Unsigned(BigInteger.valueOf(19)))));
                check(client.prepareCleanup(BigInteger.ONE,bundle).join()!=null);
            }
        }
        System.out.println("Java installed direct capture "+phase+": public API passed");
    }
}

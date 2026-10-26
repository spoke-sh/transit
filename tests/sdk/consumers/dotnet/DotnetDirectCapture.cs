using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;
using Q=Transit.Station.Sdk.UnifiedQuery;
using C=Transit.Station.Sdk.Catalog;
using L=Transit.Station.Sdk.Logical;

static class DirectCapture {
    static void Check(bool value) { if(!value)throw new Exception("Direct capture mismatch"); }
    static ulong Wide(JsonNode value,string key)=>ulong.Parse(value[key]!.GetValue<string>(),System.Globalization.CultureInfo.InvariantCulture);
    public static async Task Main(string[] args) {
        string profilePath=args[1],phase=args[2];
        var profile=JsonNode.Parse(File.ReadAllText(profilePath))!["captured"]!;
        var route=profile["connection"]!; ulong realm=route["realm"]!.GetValue<ulong>();
        var declaration=profile["declaration"]!["source"]!["table"]!; var scopeValue=declaration["scope"]!;
        var resource=new ResourceRef(realm,scopeValue["resource"]!.GetValue<ulong>());
        var scope=new C.Scope(resource,Wide(scopeValue,"catalog"));
        var connection=new Q.Connection(new(realm,route["source"]!.GetValue<ulong>()),new(realm,route["resource"]!.GetValue<ulong>()),
            new(realm,route["requester"]!.GetValue<ulong>()),new(realm,route["requests"]!.GetValue<ulong>()));
        Check(resource!=connection.Resource);
        var seed=Path.Combine(Path.GetDirectoryName(profilePath)!,"dotnet-capture.seed");
        File.WriteAllText(seed,string.Concat(Enumerable.Repeat(phase=="prepare"?"1d":"3b",32)));
        if(!OperatingSystem.IsWindows())File.SetUnixFileMode(seed,UnixFileMode.UserRead|UnixFileMode.UserWrite);
        var identity=new Credential(realm,route["principal"]!.GetValue<ulong>(),seed);
        var config=new ClientConfig(new(args[0]),Profile.NativeV1,10000);
        var tables=new Q.Tables(args[0],scope,Wide(declaration,"branch"),declaration["owner"]!.GetValue<ulong>());
        var bundle=new Q.Bundle(new Bytes(Convert.FromBase64String(profile["bundle"]!["base64"]!.GetValue<string>())));
        await using var client=await Q.Client.OpenAsync(config,identity,connection,tables);
        if(phase=="prepare") {
            Check(await client.LookupTableAsync(1,"missing_capture_input") is null);
            var definition=await client.LookupTableAsync(1,"captured_input") ?? throw new Exception("Missing Table");
            var saved=profile["capture"]!; var expected=saved["expected"]!;
            Check(definition.Partition==Wide(expected,"partition") && definition.NextLsn==Wide(expected,"next_lsn"));
            var compiled=await client.CompileSqlAsync(definition.Source,"captured_input","SELECT COUNT(*) AS n FROM captured_input",new(64,64,1048576));
            Check((await client.AuthorizeBundleAsync(compiled,definition.Capture(saved["executor"]!.GetValue<ulong>(),Wide(saved,"operation")))).Bytes.Equals(bundle.Bytes));
        } else {
            Check(await client.LookupTableAsync(1,"captured_input") is null);
            var definition=await client.LookupTableAsync(1,"captured_renamed") ?? throw new Exception("Missing renamed Table");
            Check(definition.Source.Interpretation.Revision==2 && definition.Source.Schema.Revision==1);
            var page=await client.PageAsync(1); var manifest=page.Manifest;
            Check(page.Next is null && page.Rows==1 && manifest.Resource==resource);
            Check(manifest.Source==new Q.TableRetention(connection.Source) && manifest.Cut is Q.TableCut);
            Check(manifest.Pages==3 && manifest.Scanned==19);
            var rows=await page.DecodeAsync(); Check(rows.Count==1 && rows[0][0]==new L.Present(new L.Unsigned(19)));
            Check(await client.PrepareCleanupAsync(1,bundle) is not null);
        }
        Console.WriteLine($".NET installed direct capture {phase}: public API passed");
    }
}

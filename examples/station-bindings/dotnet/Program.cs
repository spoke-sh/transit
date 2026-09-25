using System.Text.Json.Nodes;
using Transit.Station;

if (args.Length == 1 && args[0] == "--boundary-proof") { await BoundaryProof.Run(); return; }
var config = JsonNode.Parse(await File.ReadAllTextAsync(args[0]))!;
ulong peer = ulong.Parse(args[2]);
var seed = Convert.FromHexString((await File.ReadAllTextAsync(config["seed_file"]!.GetValue<string>())).Trim());
await using var server = await GenServer.OpenAsync(Environment.GetEnvironmentVariable("TRANSIT_LIBRARY_DIR")!, config["url"]!.GetValue<string>(), seed, config["server"]!);
Array.Clear(seed);
JsonNode J(string value) => JsonNode.Parse(value)!;
for (;;) {
    var message = (await server.NextAsync())!;
    string state = message["event"]!.GetValue<string>();
    if (state == "committed") return;
    if (state is "idle" or "blocked") throw new InvalidOperationException(state);
    if (state != "ready") continue;
    if (message["initializing"]!.GetValue<bool>()) {
        await server.ApplyAsync(J("""{"table_create":{"id":1,"key_name":"id","value_name":"value","value_type":"int64"}}"""));
        if (args[1] == "service") {
            await server.ApplyAsync(new JsonObject { ["query_policy"] = new JsonObject {
                ["peer"] = peer, ["table"] = 1, ["expected_revision"] = 0, ["allow"] = true } });
            await server.ApplyAsync(J("""{"table_write":{"id":1,"mode":"insert","row":{"key":"1","value":{"int64":"9007199254740993"}}}}"""));
        }
    }
    var input = message["input"]!;
    if (input["payload"]!.GetValue<string>() == "696e6974") {}
    else switch (input["kind"]!.GetValue<string>()) {
        case "cast": await server.ApplyAsync(new JsonObject { ["call"] = new JsonObject {
            ["pid"] = peer, ["value"] = "7175657279" } }); break;
        case "call": await server.ApplyAsync(J("""{"query_reply":{"id":1}}""")); break;
        case "result_complete":
            var query = new JsonObject { ["query_result"] = input["correlation"]!.GetValue<string>() };
            var result = (await server.ApplyAsync(query))!;
            var ipc = Convert.FromHexString(result["arrow"]!.GetValue<string>());
            var cell = (await server.ArrowCellAsync(ipc, 0, 1))!;
            if (long.Parse(cell["value"]!["int64"]!.GetValue<string>()) != 9007199254740993L) throw new InvalidOperationException("Lost integer precision");
            await server.ApplyAsync(J("""{"put":{"key":"6f62736572766564","value":"39303037313939323534373430393933"}}"""));
            break;
        default: throw new InvalidOperationException("Unexpected Station input");
    }
    await server.FinishAsync();
}

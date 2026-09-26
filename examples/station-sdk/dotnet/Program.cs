using System.Text.Json.Nodes;
using Transit.Client;
using Transit.Station.Sdk;

namespace Transit.Sdk.Examples;

public static class CounterMain
{
    public static async Task Main(string[] args)
    {
        if (args.Length is not (2 or 4) || (args.Length == 4 && args[2] != "--commits")) throw new ArgumentException("CONFIG service|requester [--commits COUNT]");
        int remaining = args.Length == 4 ? int.Parse(args[3], System.Globalization.CultureInfo.InvariantCulture) : 1;
        if (remaining < 1) throw new ArgumentException("Commit count must be positive");
        byte[] bytes = new byte[8193]; int size = 0;
        await using (FileStream input = File.OpenRead(args[0])) {
            while (size < bytes.Length) { int read = await input.ReadAsync(bytes.AsMemory(size)); if (read == 0) break; size += read; }
        }
        if (size > 8192) throw new ArgumentException("Configuration exceeds its bound");
        JsonObject cfg = JsonNode.Parse(bytes.AsSpan(0, size))!.AsObject();
        if (cfg["profile"]!.GetValue<string>() != "growing_v3") throw new ArgumentException("Select growing_v3");
        ulong realm = cfg["realm"]!.GetValue<ulong>();
        ClientConfig client = new(new Uri(cfg["url"]!.GetValue<string>()), Profile.GrowingV3);
        Activation activation = new(new ProcessRef(realm, cfg["pid"]!.GetValue<ulong>()), cfg["generation"]!.GetValue<ulong>(),
            new Credential(realm, cfg["principal"]!.GetValue<ulong>(), cfg["seed_file"]!.GetValue<string>()));
        ProcessRef peer = new(realm, cfg["peer"]!.GetValue<ulong>());
        IHandler<ICounterMessage> handler;
        ICodec<ICounterMessage> codec;
        if (args[1] == "service") { handler = new Counter(); codec = Codecs.Counter; }
        else if (args[1] == "requester") { handler = new Requester(peer); codec = Codecs.Requester; }
        else throw new ArgumentException("Select service or requester");
        await using var runner = await Runner<ICounterMessage>.OpenAsync(new ServiceConfig(client, activation), handler, codec, FailurePolicy.Stop, new Recovery.FreshOwnership());
        while (remaining > 0) {
            RunnerEvent value = await runner.NextAsync();
            if (value is Committed committed) {
                Console.WriteLine(new JsonObject { ["input"] = committed.Input, ["committed"] = committed.Receipt.Position }.ToJsonString()); remaining--;
            } else if (value is Idle) await Task.Delay(20);
            else if (value is not Progress) throw new InvalidOperationException("Runner stopped before requested commitment; inspect recovery evidence");
        }
    }
}

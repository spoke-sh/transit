using System.Text;
using System.Text.Json.Nodes;
using Transit.Client;
using SdkClient = Transit.Client.Client;

internal static class Program
{
    private static void Check(bool condition) { if (!condition) throw new InvalidOperationException("Public .NET SDK proof failed"); }
    private static async Task Expect(ErrorKind kind, Func<Task> action)
    {
        try { await action(); }
        catch (TransitException error) { Check(error.Kind == kind); return; }
        throw new InvalidOperationException($"Expected {kind}");
    }
    private static void Invalid(Action action)
    {
        try { action(); } catch (ArgumentException) { return; }
        throw new InvalidOperationException("Expected invalid argument");
    }
    public static async Task Main(string[] args)
    {
        SchemaValues.Run();
        string mode = args[0];
        JsonObject cfg = JsonNode.Parse(await File.ReadAllTextAsync(args[1]))!.AsObject();
        string root = Path.GetDirectoryName(args[1])!;
        var config = new ClientConfig(new Uri(cfg["url"]!.GetValue<string>()), Profile.NativeV1, 3000);
        var credential = new Credential(72, 65536, cfg["seed"]!.GetValue<string>());
        var peer = new ProcessRef(72, cfg["pid"]!.GetValue<ulong>());
        string pendingFile = cfg["pending"]!.GetValue<string>();
        Check(typeof(SdkClient).Assembly.Location.StartsWith(root, StringComparison.Ordinal));
        Check(!Directory.GetFiles(AppContext.BaseDirectory, "*Station*").Any());
        Invalid(() => new ProcessRef(72, 1UL << 53));
        Invalid(() => new ResourceRef(72, 0));
        await Expect(ErrorKind.IncompatibleNative, () => SdkClient.OpenAsync(new ClientConfig(config.Endpoint, config.Profile, 3000, "/missing-transit")));
        if (mode == "missing-artifact") {
            await Expect(ErrorKind.IncompatibleNative, () => SdkClient.OpenAsync(config)); return;
        }
        if (mode == "native-capacity") {
            for (int image = 0; image < 17; image++) {
                string directory = Path.Combine(root, "capacity-" + image);
                Directory.CreateDirectory(directory);
                string path = Path.Combine(directory, "libtransit_client.so");
                File.Copy(Path.Combine(root, "bad-native", "libtransit_client.so"), path);
                await Expect(ErrorKind.IncompatibleNative, () => SdkClient.OpenAsync(new ClientConfig(config.Endpoint, config.Profile, 3000, directory)));
                Check(NativeLifetime.Maps(path) == (image < 16));
            }
            return;
        }
        if (mode == "first") {
            HashSet<string>? images = null;
            for (int repeat = 0; repeat < 16; repeat++) {
                var probe = await SdkClient.OpenAsync(config);
                await probe.CapabilitiesAsync(credential);
                images ??= NativeLifetime.Mappings();
                Check(images.Count == 1);
                await probe.CloseAsync();
                NativeLifetime.Retained(images);
            }
            await Expect(ErrorKind.IncompatibleNative, () => SdkClient.OpenAsync(new ClientConfig(config.Endpoint, config.Profile, 3000, Path.Combine(root, "bad-native"))));
            string nativeDirectory = Path.Combine(root, "native-override");
            var overridden = new ClientConfig(config.Endpoint, config.Profile, 3000, nativeDirectory);
            for (int repeat = 0; repeat < 2; repeat++) {
                await using var probe = await SdkClient.OpenAsync(overridden);
                await probe.CapabilitiesAsync(credential);
            }
            string original = Path.Combine(nativeDirectory, "libtransit_client.so");
            string replacement = Path.Combine(nativeDirectory, "replacement.so");
            File.Copy(original, replacement);
            using (var changed = new FileStream(replacement, FileMode.Append)) changed.WriteByte(0);
            File.Move(replacement, original, true);
            await Expect(ErrorKind.IncompatibleNative, () => SdkClient.OpenAsync(overridden));
            File.Delete(original);
            await Expect(ErrorKind.IncompatibleNative, () => SdkClient.OpenAsync(overridden));
            await using var client = await SdkClient.OpenAsync(config);
            var missingCredential = new Credential(72, 65536, Path.Combine(root, "private-missing-credential"));
            try { await client.CapabilitiesAsync(missingCredential); throw new InvalidOperationException("Missing credential accepted"); }
            catch (TransitException error) { Check(error.Kind == ErrorKind.ReadFailed && !error.Message.Contains(missingCredential.SeedFile, StringComparison.Ordinal) && error.InnerException is null); }
            Capabilities caps = await client.CapabilitiesAsync(credential);
            Check(caps.PrincipalSequence == 0 && caps.PageSize == 8 && caps.RetainedVersions);
            byte[] payload = Encoding.ASCII.GetBytes("wide");
            var pending = await client.PrepareSendAsync(peer, payload, credential, 1);
            byte[] bytes = pending.Export(); payload[0] = 0; pending.Export()[0] = 0;
            Check(bytes.SequenceEqual(pending.Export()));
            Check(!pending.ToString().Contains("signature", StringComparison.Ordinal) && !credential.ToString().Contains(credential.SeedFile, StringComparison.Ordinal));
            await File.WriteAllBytesAsync(pendingFile, bytes);
            ISendOutcome result = await client.DispatchAsync(pending);
            Check(result is Uncertain);
            var uncertain = (Uncertain)result;
            Check(uncertain.Error.Status == 6 && uncertain.Recovery().SequenceEqual(bytes));
            pending.Dispose();
            await Expect(ErrorKind.Closed, () => { pending.Export(); return Task.CompletedTask; });
        } else if (mode == "recover") {
            Check(!File.Exists(credential.SeedFile));
            await using var client = await SdkClient.OpenAsync(config);
            using var pending = await client.RecoverSendAsync(await File.ReadAllBytesAsync(pendingFile));
            AdmissionReceipt receipt = ((Admitted)await client.DispatchAsync(pending)).Receipt;
            Check((await client.EvidenceAsync()).LastAdmission == receipt && ((Admitted)await client.DispatchAsync(pending)).Receipt == receipt);
            byte[] spawn = await File.ReadAllBytesAsync(cfg["spawn"]!.GetValue<string>());
            await Expect(ErrorKind.UnsupportedCapability, () => client.RecoverSendAsync(spawn));
            try {
                await client.RecoverSendAsync(Encoding.UTF8.GetBytes(" " + Encoding.UTF8.GetString(pending.Export())));
                throw new InvalidOperationException("Noncanonical recovery accepted");
            } catch (TransitException) { }
            Console.WriteLine(new JsonObject { ["position"] = receipt.Position }.ToJsonString());
        } else if (mode == "async") {
            await using var client = await SdkClient.OpenAsync(config);
            using var pending = await client.PrepareSendAsync(peer, Encoding.ASCII.GetBytes("async"), credential, 2);
            byte[] bytes = pending.Export();
            using CancellationTokenSource cancel = new();
            Task<ISendOutcome> dispatch = client.DispatchAsync(pending, cancel.Token);
            var deadline = DateTime.UtcNow.AddSeconds(15);
            while (!File.Exists(cfg["accepted"]!.GetValue<string>())) { Check(DateTime.UtcNow < deadline); await Task.Delay(5); }
            await Expect(ErrorKind.Busy, () => client.CapabilitiesAsync(credential));
            cancel.Cancel();
            try { await dispatch; throw new InvalidOperationException("Expected cancelled await"); } catch (OperationCanceledException) { }
            Task<Shutdown> closing = client.CloseAsync();
            using CancellationTokenSource cancelClose = new(); cancelClose.Cancel();
            try { await closing.WaitAsync(cancelClose.Token); throw new InvalidOperationException("Expected cancelled close view"); } catch (OperationCanceledException) { }
            int beats = 0;
            while (!closing.IsCompleted) { beats++; await Task.Delay(10); }
            Shutdown evidence = await closing;
            Check(beats > 5 && evidence.LastAdmission is not null && client.RetainedEvidence == evidence);
            await Expect(ErrorKind.Closed, () => client.RecoverSendAsync(bytes));
            await using (var fresh = await SdkClient.OpenAsync(config)) {
                using var retry = await fresh.RecoverSendAsync(bytes);
                Check(((Admitted)await fresh.DispatchAsync(retry)).Receipt == evidence.LastAdmission);
            }
            Console.WriteLine(new JsonObject { ["await_cancelled"] = true, ["overlap_rejected"] = true, ["responsive_during_join"] = beats > 5, ["disposed_handle_rejected"] = true }.ToJsonString());
        } else if (mode == "denied") {
            await using var client = await SdkClient.OpenAsync(config);
            using var pending = await client.RecoverSendAsync(await File.ReadAllBytesAsync(pendingFile));
            ISendOutcome result = await client.DispatchAsync(pending);
            Check(result is Rejected);
            TransitException error = ((Rejected)result).Error;
            Check(error.Kind == ErrorKind.AccessDenied && error.Status == 4);
        } else throw new ArgumentException("Unknown proof mode");
    }
}

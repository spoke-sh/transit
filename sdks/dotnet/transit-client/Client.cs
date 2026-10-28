using Transit.Client.Internal;

namespace Transit.Client;

/// <summary>Independent raw client. Native work stays owned after await cancellation.</summary>
public sealed class Client : IDisposable, IAsyncDisposable
{
    public const string Version = "0.0.1";
    private sealed class State(ClientConfig config) : IWorkerState<Shutdown>
    {
        internal readonly Bridge Bridge = new(config);
        internal AdmissionReceipt? LastAdmission;
        internal MutationReceipt? LastMutation;
        public Shutdown Evidence() => new(LastAdmission, LastMutation);
        public void Dispose() => Bridge.Dispose();
    }
    private readonly Worker<State, Shutdown> worker;
    private Client(Worker<State, Shutdown> worker) { this.worker = worker; }
    /// <summary>Observe acquisition before disposing. Startup has no cancellation parameter.</summary>
    public static async Task<Client> OpenAsync(ClientConfig config)
    {
        ArgumentNullException.ThrowIfNull(config);
        return new Client(await Worker<State, Shutdown>.OpenAsync(() => new State(config), NativeApi.MinimumStackBytes).ConfigureAwait(false));
    }
    public static Client Open(ClientConfig config) => OpenAsync(config).GetAwaiter().GetResult();
    public Task<Capabilities> CapabilitiesAsync(Credential credential, CancellationToken cancellation = default)
    {
        ArgumentNullException.ThrowIfNull(credential);
        return worker.Invoke(state => state.Bridge.Capabilities(credential), cancellation);
    }
    public Task<PendingSend> PrepareSendAsync(ProcessRef peer, byte[] value, Credential credential, ulong sequence, CancellationToken cancellation = default)
    {
        ArgumentNullException.ThrowIfNull(peer); ArgumentNullException.ThrowIfNull(credential); Value.Counter(sequence);
        if (peer.Realm != credential.Realm) throw new ArgumentException("Peer and credential must share a realm");
        return worker.InvokePrepared<PendingSend>(() => {
            byte[] payload = Value.Bytes(value, checked((int)Value.Number(Value.Object(Value.Contract["limits"])["value_bytes"], 1)));
            return state => state.Bridge.RecoverSend(state.Bridge.Prepare(6, credential, Value.Obj(("realm", credential.Realm), ("principal", credential.Principal),
                ("sequence", sequence), ("command", Value.Obj(("send", Value.Obj(("pid", peer.Pid), ("value", Value.Hex(payload)))))))));
        }, cancellation);
    }
    public Task<PendingSend> RecoverSendAsync(byte[] value, CancellationToken cancellation = default) => worker.InvokePrepared<PendingSend>(() => {
        byte[] frozen = Value.Bytes(value, Value.MaxBody); return state => state.Bridge.RecoverSend(frozen);
    }, cancellation);
    public Task<PendingMutation> RecoverMutationAsync(byte[] value, CancellationToken cancellation = default) => worker.InvokePrepared<PendingMutation>(() => {
        byte[] frozen = Value.Bytes(value, Value.MaxBody); return state => state.Bridge.RecoverMutation(frozen);
    }, cancellation);
    public Task<ISendOutcome> DispatchAsync(PendingSend pending, CancellationToken cancellation = default)
    {
        ArgumentNullException.ThrowIfNull(pending);
        return worker.InvokePrepared<ISendOutcome>(() => {
            byte[] frozen = pending.Export();
            return state => {
                using var checkedPending = state.Bridge.RecoverSend(frozen);
                if (checkedPending.Info != pending.Info) throw new ArgumentException("Pending metadata mismatch");
                state.LastAdmission = null;
                try {
                    var result = state.Bridge.Call(frozen, true);
                    state.LastAdmission = new AdmissionReceipt(Value.Number(result["position"], 1));
                    return new Admitted(state.LastAdmission);
                } catch (TransitException error) when (error.Rejected) { return new Rejected(error); }
                catch (TransitException error) when (error.Kind == ErrorKind.UnknownOutcome) { return new Uncertain(frozen, error); }
                catch (Exception) { return new Uncertain(frozen, new TransitException(ErrorKind.UnknownOutcome, "receipt", 6)); }
            };
        }, cancellation);
    }
    public Task<IMutationOutcome> DispatchMutationAsync(PendingMutation pending, CancellationToken cancellation = default)
    {
        ArgumentNullException.ThrowIfNull(pending);
        return worker.InvokePrepared<IMutationOutcome>(() => {
            byte[] frozen = pending.Export();
            return state => {
                using var checkedPending = state.Bridge.RecoverMutation(frozen);
                if (checkedPending.Info != pending.Info) throw new ArgumentException("Pending metadata mismatch");
                state.LastMutation = null;
                try {
                    var result = state.Bridge.Call(frozen, true);
                    state.LastMutation = new MutationReceipt(Value.Number(result["position"], 1));
                    return new Confirmed(state.LastMutation);
                } catch (TransitException error) when (error.Rejected) { return new Rejected(error); }
                catch (TransitException error) when (error.Kind == ErrorKind.UnknownOutcome) { return new Uncertain(frozen, error); }
                catch (Exception) { return new Uncertain(frozen, new TransitException(ErrorKind.UnknownOutcome, "receipt", 6)); }
            };
        }, cancellation);
    }
    public Task<Shutdown> EvidenceAsync(CancellationToken cancellation = default) => worker.Invoke(state => state.Evidence(), cancellation);
    public Task<Shutdown> CloseAsync() => worker.CloseAsync();
    public Shutdown? RetainedEvidence => worker.RetainedEvidence;
    public Shutdown CloseSnapshot() => worker.CloseSnapshot();
    public void Dispose() { worker.CloseSnapshot(); }
    public async ValueTask DisposeAsync() { await worker.CloseAsync().ConfigureAwait(false); }
}

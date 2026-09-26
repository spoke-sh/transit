alias Transit.Client
alias Transit.Client.{Error, Shutdown}

[mode, path] = System.argv()
cfg = path |> File.read!() |> :json.decode()
true = String.starts_with?(to_string(:code.which(:transit_client)), Path.dirname(path))
:non_existing = :code.which(:transit_station)
{:ok, config} = Client.config(cfg["url"], :growing_v3, %{timeout_ms: 3000})
{:ok, credential} = Client.credential(72, 65536, cfg["seed"])
{:ok, peer} = Client.process(72, cfg["pid"])
{:error, _} = Client.process(72, true)
{:error, _} = Client.process(72, 9_007_199_254_740_992)

{:error, %Error{kind: :incompatible_native}} =
  Client.open(%{config | native_host: "/missing-transit"})

wait_file = fn path ->
  deadline = System.monotonic_time(:millisecond) + 15_000

  Stream.repeatedly(fn ->
    if System.monotonic_time(:millisecond) >= deadline, do: raise("Timed out")
    Process.sleep(5)
    File.exists?(path)
  end)
  |> Enum.find(& &1)
end

case mode do
  "first" ->
    {:ok, supervised} = Supervisor.start_link([{Client, config}], strategy: :one_for_one)
    [{_, bridge, _, _}] = Supervisor.which_children(supervised)
    {:ok, supervised_client} = Client.handle(bridge)
    {:ok, _} = Client.close(supervised_client)
    Supervisor.stop(supervised)
    {:ok, client} = Client.open(config)
    {:ok, caps} = Client.capabilities(client, credential)
    true = caps.principal_sequence == 0 and caps.page_size == 8 and caps.retained_versions
    {:ok, pending} = Client.prepare_send(client, peer, "wide", credential, 1)
    bytes = Client.export(pending)
    false = String.contains?(inspect(pending), "signature")
    false = String.contains?(inspect(credential), cfg["seed"])
    File.write!(cfg["pending"], bytes)

    {:uncertain,
     %Client.Uncertain{recovery: ^bytes, error: %Error{kind: :unknown_outcome, status: 6}}} =
      Client.dispatch(client, pending)

    {:ok, _} = Client.close(client)

  "recover" ->
    false = File.exists?(cfg["seed"])
    {:ok, client} = Client.open(config)
    {:ok, pending} = Client.recover_send(client, File.read!(cfg["pending"]))
    {:admitted, receipt} = Client.dispatch(client, pending)
    {:ok, %Shutdown{last_admission: ^receipt}} = Client.evidence(client)
    {:admitted, ^receipt} = Client.dispatch(client, pending)

    {:error, %Error{kind: :unsupported_capability}} =
      Client.recover_send(client, File.read!(cfg["spawn"]))

    {:error, _} = Client.recover_send(client, " " <> Client.export(pending))
    {:ok, _} = Client.close(client)
    IO.puts(:json.encode(%{position: receipt.position}))

  "async" ->
    {:ok, client} = Client.open(config)
    {:ok, pending} = Client.prepare_send(client, peer, "async", credential, 2)
    # Unlinked task cancellation loses only its wait; the SDK still owns dispatch.
    {:ok, supervisor} = Task.Supervisor.start_link()
    task = Task.Supervisor.async_nolink(supervisor, fn -> Client.dispatch(client, pending) end)
    wait_file.(cfg["accepted"])
    {:error, %Error{kind: :busy}} = Client.capabilities(client, credential)
    Task.shutdown(task, :brutal_kill)
    closing = Task.Supervisor.async_nolink(supervisor, fn -> Client.close(client) end)

    {beats, {:ok, evidence}} =
      Stream.iterate(0, &(&1 + 1))
      |> Enum.reduce_while(nil, fn count, _ ->
        case Task.yield(closing, 10) do
          nil ->
            if count > 3000, do: raise("Cleanup stalled")
            {:cont, nil}

          {:ok, result} ->
            {:halt, {count, result}}
        end
      end)

    true = beats > 5
    {:error, %Error{kind: :closed}} = Client.recover_send(client, Client.export(pending))
    {:ok, fresh} = Client.open(config)
    {:ok, same} = Client.recover_send(fresh, Client.export(pending))
    {:admitted, receipt} = Client.dispatch(fresh, same)
    true = evidence.last_admission == receipt
    {:ok, _} = Client.close(fresh)
    Supervisor.stop(supervisor)

    IO.puts(
      :json.encode(%{
        scenario: "blocking-owner-disposal",
        observations: %{
          controller_wait_abandoned: true,
          responsive_during_join: true,
          owned_work_joined: true,
          receipt_recovered: true
        }
      })
    )

  "denied" ->
    {:ok, client} = Client.open(config)
    {:ok, pending} = Client.recover_send(client, File.read!(cfg["pending"]))
    {:rejected, %Error{kind: :access_denied, status: 4}} = Client.dispatch(client, pending)
    {:ok, _} = Client.close(client)
end

defmodule Transit.SdkExamples.CounterMain do
  alias Transit.Client
  alias Transit.Station.Sdk.{Activation, ServiceConfig, Runner, Committed}
  alias Transit.SdkExamples.{Counter, Requester, CounterCodec, RequesterCodec}
  def main(args \\ System.argv())
  def main([path, role, "--commits", count]), do: run(path, role, String.to_integer(count))
  def main([path, role]), do: run(path, role, 1)

  defp run(path, role, count) when count > 0 do
    {:ok, input} = File.open(path, [:read, :binary])

    bytes =
      try do
        IO.binread(input, 8193)
      after
        File.close(input)
      end

    true = is_binary(bytes) and byte_size(bytes) <= 8192
    cfg = :json.decode(bytes)
    "growing_v3" = cfg["profile"]
    {:ok, client} = Client.config(cfg["url"], :growing_v3)
    {:ok, process} = Client.process(cfg["realm"], cfg["pid"])
    {:ok, peer} = Client.process(cfg["realm"], cfg["peer"])
    {:ok, credential} = Client.credential(cfg["realm"], cfg["principal"], cfg["seed_file"])

    service = %ServiceConfig{
      client: client,
      activation: %Activation{
        process: process,
        generation: cfg["generation"],
        credential: credential
      }
    }

    {handler, codec} =
      case role do
        "service" -> {Counter, CounterCodec}
        "requester" -> {Requester, RequesterCodec}
      end

    {:ok, runner} =
      Runner.open(service, handler, %{peer: peer}, codec,
        failure_policy: :stop,
        recovery: :fresh_ownership
      )

    try do
      advance(runner, count)
    after
      Runner.close(runner)
    end
  end

  defp advance(_, 0), do: :ok

  defp advance(runner, count) do
    case Runner.next(runner) do
      {:ok, %Committed{input: input, receipt: receipt}} ->
        IO.puts(:json.encode(%{input: input, committed: receipt.position}))
        advance(runner, count - 1)

      {:ok, :idle} ->
        Process.sleep(20)
        advance(runner, count)

      {:ok, :progress} ->
        advance(runner, count)

      _ ->
        raise "Runner stopped; recovery evidence must be inspected"
    end
  end
end

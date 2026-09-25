defmodule StationExample do
  alias Transit.Station

  def run([config, role, peer]) do
    {:ok, host} = Station.open(System.fetch_env!("TRANSIT_HOST"), config)

    try do
      loop(host, role, String.to_integer(peer))
    after
      Station.close(host)
    end
  end

  defp action(host, value) do
    {:ok, result} = Station.apply(host, value)
    result
  end

  defp loop(host, role, peer) do
    {:ok, event} = Station.next(host)

    case event["event"] do
      "committed" ->
        :ok

      "progress" ->
        loop(host, role, peer)

      "ready" ->
        if event["initializing"] do
          action(host, %{
            "table_create" => %{
              "id" => 1,
              "key_name" => "id",
              "value_name" => "value",
              "value_type" => "int64"
            }
          })

          if role == "service" do
            action(host, %{
              "query_policy" => %{
                "peer" => peer,
                "table" => 1,
                "expected_revision" => 0,
                "allow" => true
              }
            })

            action(host, %{
              "table_write" => %{
                "id" => 1,
                "mode" => "insert",
                "row" => %{"key" => "1", "value" => %{"int64" => "9007199254740993"}}
              }
            })
          end
        end

        handle(host, event["input"], peer)
        {:ok, _} = Station.finish(host, false)
        loop(host, role, peer)

      other ->
        raise "Unexpected event: #{other}"
    end
  end

  defp handle(_, %{"payload" => "696e6974"}, _), do: :ok

  defp handle(host, %{"kind" => "cast"}, peer),
    do: action(host, %{"call" => %{"pid" => peer, "value" => "7175657279"}})

  defp handle(host, %{"kind" => "call"}, _), do: action(host, %{"query_reply" => %{"id" => 1}})

  defp handle(host, %{"kind" => "result_complete", "correlation" => correlation}, _) do
    %{"arrow" => hex} = action(host, %{"query_result" => correlation})
    ipc = Base.decode16!(hex, case: :lower)
    {:ok, %{"value" => %{"int64" => text}}} = Station.arrow_cell(host, ipc, 0, 1)
    9_007_199_254_740_993 = String.to_integer(text)

    action(host, %{
      "put" => %{"key" => "6f62736572766564", "value" => Base.encode16(text, case: :lower)}
    })
  end
end

StationExample.run(System.argv())
